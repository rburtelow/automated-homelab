#!/bin/bash
# Quick fix script to remove old incorrect labels and apply correct Longhorn labels
# This fixes nodes that were labeled with the wrong label name

set -e

echo "Fixing Longhorn node labels..."
echo ""

# Remove old incorrect label if it exists
echo "Removing old incorrect label (longhorn.io/node-disk)..."
kubectl label nodes --all longhorn.io/node-disk- 2>/dev/null || echo "  (No old labels found, skipping)"

echo ""
echo "Applying correct label to worker nodes..."
echo ""

# Get all nodes and filter for worker nodes
ALL_NODES=$(kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')

if [ -z "$ALL_NODES" ]; then
    echo "No nodes found!"
    exit 1
fi

LABELED_COUNT=0
SKIPPED_COUNT=0

for node in $ALL_NODES; do
    # Check if node has control-plane taint
    HAS_CONTROL_PLANE_TAINT=$(kubectl get node "$node" -o jsonpath='{.spec.taints[?(@.key=="node-role.kubernetes.io/control-plane")].key}' 2>/dev/null || echo "")
    
    if [ -n "$HAS_CONTROL_PLANE_TAINT" ]; then
        echo "Skipping control plane node: $node"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    else
        echo "Labeling worker node: $node"
        kubectl label node "$node" node.longhorn.io/create-default-disk=true --overwrite
        LABELED_COUNT=$((LABELED_COUNT + 1))
    fi
done

echo ""
echo "Summary:"
echo "  - Labeled $LABELED_COUNT worker node(s) with correct label"
echo "  - Skipped $SKIPPED_COUNT control plane node(s)"
echo ""
echo "Verification:"
kubectl get nodes --show-labels | grep -E "NAME|node.longhorn.io/create-default-disk" || echo "  (No labels found - this is normal if grep doesn't match)"
echo ""
echo "Longhorn should detect these labels and create disks within 1-2 minutes."
echo "Check the Longhorn UI - nodes should become enabled and storage should appear."
