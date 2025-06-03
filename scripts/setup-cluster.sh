set -euo pipefail

source "$(dirname "$0")/colors.sh"

# =============================================================================
#
# Usage:
#   ./scripts/setup-cluster.sh us    # only us cluster
#   ./scripts/setup-cluster.sh eu    # only eu cluster
#   ./scripts/setup-cluster.sh all   # both clusters
#
# This script:
#   1) Generates certs (if missing) for the requested region(s)
#   2) Creates the Kind cluster(s)
#   3) Loads the local foobar-api:latest image
#   4) Installs Traefik (Helm) in each requested cluster
#   5) Deploys the foobar app (namespaces, PVC/RBAC, secrets, Deployment, Service, IngressRouteTCP)
#   6) Creates the traefik-metrics Service so Prometheus can scrape
#   7) Waits for each Deployment to finish rolling out
# =============================================================================

US_CLUSTER_NAME="foobar-us"
EU_CLUSTER_NAME="foobar-eu"
US_HOST_HTTPS_PORT=9443
EU_HOST_HTTPS_PORT=9444

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

function gen_certs() {
    local region=$1
    local cert_dir="k8s/certs/${region}"
    mkdir -p "$cert_dir"
    if [[ ! -f "$cert_dir/cert.pem" || ! -f "$cert_dir/key.pem" ]]; then
        echo "Generating $region cert (CN=${region}.foobar.local)..."
        openssl req -newkey rsa:2048 -nodes -keyout "$cert_dir/key.pem" \
            -x509 -days 365 -out "$cert_dir/cert.pem" \
            -subj "/CN=${region}.foobar.local/O=foobar" \
            -addext "subjectAltName = DNS:${region}.foobar.local"
    else
        echo -e "${COLOR_YELLOW} $region cert already exists; skipping."
    fi
}

function create_cluster_and_deploy() {
    local ctx_name=$1  # foobar-us / foobar-eu
    local region=$2    # us / eu
    local host_port=$3 # 9443 / 9444

    local region_upper
    region_upper=$(echo "$region" | tr '[:lower:]' '[:upper:]')

    echo "[${region_upper}] Creating Kind cluster \"${ctx_name}\"..."
    export "${region_upper}_HOST_HTTPS_PORT"="$host_port"
    envsubst <"k8s/kind-config-${region}.yaml.tpl" | kind create cluster --name "$ctx_name" --config=-

    echo "[${region_upper}] Loading foobar-api:latest into ${ctx_name}..."
    kind load docker-image foobar-api:latest --name "$ctx_name"

    local K8S_CTX="kind-${ctx_name}"

    echo "[${region_upper}] Deploying Traefik via Helm in \"${ctx_name}\"..."
    kubectl --context="$K8S_CTX" create namespace traefik || true
    helm upgrade --install traefik traefik/traefik \
        --namespace=traefik \
        --values k8s/manifests/traefik-values.yaml \
        --kube-context="$K8S_CTX"

    echo "[${region_upper}] Deploying foobar app in \"${ctx_name}\"..."
    kubectl --context="$K8S_CTX" apply -f k8s/manifests/namespace.yaml
    kubectl --context="$K8S_CTX" apply -f k8s/manifests/pv-pvc.yaml
    kubectl --context="$K8S_CTX" apply -f k8s/manifests/rbac.yaml

    echo "[${region_upper}] Creating TLS secret..."
    kubectl --context="$K8S_CTX" -n foobar-app create secret tls foobar-tls \
        --cert="k8s/certs/${region}/cert.pem" \
        --key="k8s/certs/${region}/key.pem" \
        --dry-run=client -o yaml | kubectl apply -f -

    kubectl --context="$K8S_CTX" -n foobar-app apply -f k8s/manifests/deployment.yaml
    kubectl --context="$K8S_CTX" -n foobar-app apply -f k8s/manifests/service.yaml

    echo "[${region_upper}] Applying IngressRouteTCP..."
    sed "s/HostSNI(\`us.foobar.local\`)/HostSNI(\`${region}.foobar.local\`)/" \
        k8s/manifests/ingressroutetcp.yaml |
        kubectl --context="$K8S_CTX" -n foobar-app apply -f -

    echo "[${region_upper}] Exposing Traefik metrics..."
    kubectl --context="$K8S_CTX" -n traefik apply -f k8s/manifests/traefik-metrics-service.yaml

    echo "[${region_upper}] Waiting for Traefik to finish rolling out..."
    kubectl --context="$K8S_CTX" -n traefik rollout status deployment/traefik --timeout=120s

    echo "[${region_upper}] Waiting for foobar app to finish rolling out..."
    kubectl --context="$K8S_CTX" -n foobar-app rollout status deployment/foobar-deployment --timeout=120s
}

if [[ "$REGION" == "us" || "$REGION" == "all" ]]; then
    gen_certs us
    create_cluster_and_deploy "$US_CLUSTER_NAME" "us" "$US_HOST_HTTPS_PORT"
fi

if [[ "$REGION" == "eu" || "$REGION" == "all" ]]; then
    gen_certs eu
    create_cluster_and_deploy "$EU_CLUSTER_NAME" "eu" "$EU_HOST_HTTPS_PORT"
fi

echo -e "${COLOR_GREEN} setup-cluster.sh ($REGION) complete."
