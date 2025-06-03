set -euo pipefail

source "$(dirname "$0")/colors.sh"

# =============================================================================
#
# Usage:
#   ./scripts/teardown-cluster.sh us    # delete us cluster only
#   ./scripts/teardown-cluster.sh eu    # delete eu cluster only
#   ./scripts/teardown-cluster.sh all   # delete both clusters
#
# Deletes the specified Kind cluster(s)
# =============================================================================

US_CLUSTER_NAME="foobar-us"
EU_CLUSTER_NAME="foobar-eu"

function usage() {
    echo "Usage: $0 [us|eu|all]"
    exit 1
}

if [[ $# -ne 1 ]]; then
    usage
fi

REGION="$1"

if [[ "$REGION" != "us" && "$REGION" != "eu" && "$REGION" != "all" ]]; then
    usage
fi

if [[ "$REGION" == "us" || "$REGION" == "all" ]]; then
    echo "Deleting Kind cluster: $US_CLUSTER_NAME"
    kind delete cluster --name "$US_CLUSTER_NAME"
fi

if [[ "$REGION" == "eu" || "$REGION" == "all" ]]; then
    echo "Deleting Kind cluster: $EU_CLUSTER_NAME"
    kind delete cluster --name "$EU_CLUSTER_NAME"
fi

echo -e "${COLOR_GREEN} teardown-cluster.sh ($REGION) complete. ${COLOR_RESET}"
