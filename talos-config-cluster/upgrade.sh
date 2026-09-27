#!/usr/bin/env bash
#
# Rolling Talos upgrade for the homelab cluster.
#
# The naive `for ip in $(kubectl get nodes ...); do talosctl upgrade; done` loop
# reliably stalls on worker-05/worker-06 because of two stacked drain blockers:
#
#   1. Single-instance CloudNativePG clusters (money-match, n8n-postgres,
#      ranch-management, diaper-party) get a `<name>-primary` PDB with
#      minAvailable:1. With exactly one pod that is ALLOWED DISRUPTIONS = 0
#      forever, so the eviction API can never succeed. A longer --drain-timeout
#      does not help; this is PDB arithmetic, not slowness.
#   2. Because those pods never leave, their Longhorn volumes stay attached, so
#      the node's instance-manager keeps running engine processes and Longhorn
#      keeps its instance-manager PDB at 0 allowed disruptions too.
#
# `kubectl delete pod` bypasses PDBs (unlike eviction), so this script cordons
# the node, deletes the pods that are structurally un-evictable, waits for
# Longhorn to release the node, and only then calls talosctl upgrade.
#
# Control planes are done first, one at a time, with an API-health gate between
# them -- back-to-back control plane reboots are what produced the
# "connection reset by peer" and "client rate limiter ... would exceed context
# deadline" errors in the old script's worker phase.
#
# Usage:
#   ./upgrade.sh                  # upgrade every node not already on target
#   ./upgrade.sh --dry-run        # show the plan, change nothing
#   ./upgrade.sh -n worker-05     # only nodes whose name matches this substring
#   ./upgrade.sh --evict-replicas # also drain Longhorn replicas off each node
#                                 # first (slow, forces full rebuilds; only
#                                 # needed if a drain blocks on a last replica)

set -euo pipefail

# qemu, scsi, linux-tools
IMAGE="${IMAGE:-factory.talos.dev/nocloud-installer/88d1f7a5c4f1d3aba7df787c448c1d3d008ed29cfb34af53fa0df4336a56040b:v1.14.1}"
TALOSCONFIG_PATH="${TALOSCONFIG:-$HOME/.talos/config}"
DRAIN_TIMEOUT="${DRAIN_TIMEOUT:-15m}"
TARGET_VERSION="${IMAGE##*:}"

DRY_RUN=0
EVICT_REPLICAS=0
NODE_FILTER=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)        DRY_RUN=1; shift ;;
        --evict-replicas) EVICT_REPLICAS=1; shift ;;
        -n|--node)        NODE_FILTER="$2"; shift 2 ;;
        -h|--help)        sed -n '2,33p' "$0"; exit 0 ;;
        *) echo "unknown argument: $1" >&2; exit 1 ;;
    esac
done

log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '\033[1;33m    ! %s\033[0m\n' "$*"; }
run()  { if (( DRY_RUN )); then printf '\033[2m    [dry-run] %s\033[0m\n' "$*"; else "$@"; fi; }

talos() { talosctl --talosconfig "$TALOSCONFIG_PATH" "$@"; }

# ---------------------------------------------------------------------------
# Wait until the API server is serving and every node is Ready again.
# ---------------------------------------------------------------------------
wait_for_cluster() {
    local deadline=$((SECONDS + 600))
    info "waiting for API server and all nodes Ready..."
    while (( SECONDS < deadline )); do
        if kubectl get --raw /readyz >/dev/null 2>&1 \
           && ! kubectl get nodes --no-headers 2>/dev/null | grep -qv ' Ready'; then
            info "cluster healthy"
            return 0
        fi
        sleep 10
    done
    warn "cluster did not report healthy within 10m"
    return 1
}

# ---------------------------------------------------------------------------
# Delete pods on $1 that are covered by a PDB allowing 0 disruptions. These can
# never be evicted, so the drain would spin until it times out. Longhorn's own
# instance-manager PDBs are skipped -- they clear on their own once the volumes
# these pods hold open get detached.
# ---------------------------------------------------------------------------
delete_unevictable_pods() {
    local node="$1" quiet="${2:-}" ns selector pods pod found=0

    while IFS=$'\t' read -r ns selector; do
        [[ -z "$ns" ]] && continue
        [[ "$ns" == "longhorn-system" ]] && continue
        pods=$(kubectl get pods -n "$ns" -l "$selector" \
                 --field-selector "spec.nodeName=$node" \
                 -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)
        for pod in $pods; do
            found=1
            warn "$ns/$pod is behind a PDB with 0 allowed disruptions -- deleting it directly"
            info "(single-replica workload: expect ~1-2 min of downtime while it reschedules)"
            run kubectl delete pod -n "$ns" "$pod" --wait=false
        done
    done < <(kubectl get pdb -A -o json | jq -r '
        .items[]
        | select(.status.disruptionsAllowed == 0)
        | select(.spec.selector.matchLabels != null)
        | [ .metadata.namespace,
            (.spec.selector.matchLabels | to_entries
             | map("\(.key)=\(.value)") | join(",")) ]
        | @tsv')

    (( found )) || [[ -n "$quiet" ]] || info "no PDB-blocked pods on this node"
}

# ---------------------------------------------------------------------------
# Deleting a singleton pod off node A can land it on node B -- and if B is the
# next node queued for upgrade, it arrives after B's pre-drain scan and blocks
# B's drain. (Exactly how n8n-postgres-1 hopped worker-05 -> worker-06.) So keep
# reaping un-evictable pods for as long as the drain is running. The node is
# already cordoned, so nothing we delete can land back on it.
# ---------------------------------------------------------------------------
reap_unevictable_pods() {
    local node="$1"
    while true; do
        sleep 15
        delete_unevictable_pods "$node" quiet || true
    done
}

# ---------------------------------------------------------------------------
# Longhorn: wait for the node to stop hosting engine/replica processes so its
# instance-manager PDB goes away. With --evict-replicas, actively migrate
# replicas off first (needed only when a drain blocks on a last replica).
# ---------------------------------------------------------------------------
longhorn_release_node() {
    local node="$1" deadline

    kubectl get nodes.longhorn.io -n longhorn-system "$node" >/dev/null 2>&1 || {
        info "not a Longhorn node, skipping"
        return 0
    }

    if (( EVICT_REPLICAS )); then
        info "requesting Longhorn replica eviction off $node"
        # allowScheduling:false must land first or Longhorn rejects evictionRequested
        run kubectl patch nodes.longhorn.io "$node" -n longhorn-system --type merge \
            -p '{"spec":{"allowScheduling":false,"evictionRequested":true}}'
        deadline=$((SECONDS + 1800))
        while (( SECONDS < deadline )); do
            local left
            left=$(kubectl get replicas.longhorn.io -n longhorn-system -o json \
                   | jq -r --arg n "$node" '[.items[] | select(.spec.nodeID==$n)] | length')
            [[ "$left" == "0" ]] && break
            info "  $left replica(s) still on $node..."
            sleep 20
        done
    fi

    # Give Longhorn a head start detaching the volumes whose pods we just
    # deleted. This is a courtesy wait, not a gate: an instance-manager PDB also
    # sits at 0 allowed disruptions when it holds engines for perfectly
    # evictable pods, and those only clear once the drain itself evicts them.
    # So we bound this short and let --drain-timeout handle the rest.
    info "waiting for Longhorn to release instance-manager on $node"
    (( DRY_RUN )) && { info "(skipped in dry run)"; return 0; }
    deadline=$((SECONDS + 180))
    while (( SECONDS < deadline )); do
        local blocked engines
        # The instance-manager PDB carries no labels of its own -- the node name
        # only appears inside its selector, so match on that.
        blocked=$(kubectl get pdb -n longhorn-system -o json 2>/dev/null \
                  | jq -r --arg n "$node" '[.items[]
                      | select(.spec.selector.matchLabels["longhorn.io/node"] == $n)
                      | select(.status.disruptionsAllowed == 0)] | length')
        [[ "$blocked" == "0" ]] && { info "instance-manager is evictable"; return 0; }
        engines=$(kubectl get engines.longhorn.io -n longhorn-system -o json \
                  | jq -r --arg n "$node" '[.items[] | select(.spec.nodeID==$n)] | length')
        info "  instance-manager still pinned ($engines engine(s) attached)..."
        sleep 15
    done

    info "instance-manager still holds engines; letting the drain evict them"
    return 0
}

longhorn_restore_scheduling() {
    local node="$1"
    (( EVICT_REPLICAS )) || return 0
    info "restoring Longhorn scheduling on $node"
    run kubectl patch nodes.longhorn.io "$node" -n longhorn-system --type merge \
        -p '{"spec":{"allowScheduling":true,"evictionRequested":false}}'
}

# ---------------------------------------------------------------------------
upgrade_node() {
    local name="$1" ip="$2" role="$3"

    log "$name ($ip, $role)"

    if [[ "$role" == "worker" ]]; then
        info "cordoning"
        run kubectl cordon "$name"
        delete_unevictable_pods "$name"
        longhorn_release_node "$name"
    fi

    local watcher="" rc=0
    if [[ "$role" == "worker" ]] && (( ! DRY_RUN )); then
        info "reaping pods that reschedule onto $name mid-drain"
        reap_unevictable_pods "$name" &
        watcher=$!
    fi

    info "upgrading to $TARGET_VERSION (drain timeout $DRAIN_TIMEOUT)"
    run talos upgrade -n "$ip" --image "$IMAGE" --drain-timeout "$DRAIN_TIMEOUT" || rc=$?

    if [[ -n "$watcher" ]]; then
        kill "$watcher" 2>/dev/null || true
        wait "$watcher" 2>/dev/null || true
    fi

    if (( rc != 0 )); then
        warn "upgrade of $name FAILED -- leaving it cordoned and stopping"
        warn "investigate, then re-run; already-upgraded nodes are skipped"
        return 1
    fi

    if [[ "$role" == "worker" ]]; then
        longhorn_restore_scheduling "$name"
        info "uncordoning"
        run kubectl uncordon "$name"
    fi

    wait_for_cluster || return 1
}

# ---------------------------------------------------------------------------
log "target: $TARGET_VERSION"
info "image: $IMAGE"
(( DRY_RUN )) && warn "dry run -- nothing will be changed"

nodes=$(kubectl get nodes -o json | jq -r '
    .items[]
    | [ .metadata.name,
        (.status.addresses[] | select(.type=="InternalIP") | .address),
        (if .metadata.labels["node-role.kubernetes.io/control-plane"] then "cp" else "worker" end),
        (.status.nodeInfo.osImage | capture("(?<v>v[0-9]+\\.[0-9]+\\.[0-9]+)").v) ]
    | @tsv')

# Any node left cordoned by a previous failed run needs picking back up.
while IFS=$'\t' read -r name ip role version; do
    [[ -n "$NODE_FILTER" && "$name" != *"$NODE_FILTER"* ]] && continue
    if [[ "$version" == "$TARGET_VERSION" ]] \
       && [[ "$(kubectl get node "$name" -o jsonpath='{.spec.unschedulable}')" == "true" ]]; then
        warn "$name is already on $TARGET_VERSION but still cordoned -- uncordoning"
        run kubectl uncordon "$name"
    fi
done <<< "$nodes"

pending=0
# Control planes first, one at a time, then workers.
for want_role in cp worker; do
    while IFS=$'\t' read -r name ip role version; do
        [[ "$role" == "$want_role" ]] || continue
        [[ -n "$NODE_FILTER" && "$name" != *"$NODE_FILTER"* ]] && continue
        if [[ "$version" == "$TARGET_VERSION" ]]; then
            info "skip $name -- already on $TARGET_VERSION"
            continue
        fi
        pending=$((pending + 1))
        upgrade_node "$name" "$ip" "$role" || exit 1
    done <<< "$nodes"
done

log "done"
if (( pending == 0 )); then
    info "every node was already on $TARGET_VERSION"
fi
kubectl get nodes -o wide
