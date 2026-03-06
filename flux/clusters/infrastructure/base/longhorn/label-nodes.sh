#!/bin/bash
# Script to label worker nodes (non-control-plane) with node.longhorn.io/create-default-disk=true
# This enables Longhorn to automatically create disks on worker nodes
# when createDefaultDiskLabeledNodes is set to true

set -e

echo "Labeling worker nodes with node.longhorn.io/create-default-disk=true..."
echo ""

# Get all nodes and filter for worker nodes (nodes without control-plane taint)
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
echo "  - Labeled $LABELED_COUNT worker node(s)"
echo "  - Skipped $SKIPPED_COUNT control plane node(s)"
echo ""
echo "You can verify by running:"
echo "  kubectl get nodes --show-labels | grep node.longhorn.io/create-default-disk"
echo ""
echo "Longhorn should automatically create disks on these worker nodes within a few minutes."
echo "Check the Longhorn UI to see if nodes become enabled and storage becomes available."
