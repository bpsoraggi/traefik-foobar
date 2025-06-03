set -euo pipefail

source "$(dirname "$0")/colors.sh"

# =============================================================================
#
# 1) Starts Prometheus & Grafana via Docker Compose (if not already running)
# 2) Starts the local Traefik (load-balancer) from local-proxy/traefik.yml
# 3) Port-forwards US-cluster Traefik metrics > localhost:31883
# 4) Port-forwards EU-cluster Traefik metrics > localhost:31884
# 5) Writes all started PIDs to scripts/managed-pids.txt
# 6) Prints all relevant URLs
#
# Usage: ./scripts/start-lb.sh
# =============================================================================

PID_FILE="$(pwd)/scripts/managed-pids.txt"
: >"$PID_FILE"

# Prometheus & Grafana Docker Compose setup

if ! docker ps --format="{{.Names}}" | grep -q "^prom-local$"; then
    echo "Starting Prometheus & Grafana via Docker Compose…"
    docker-compose up -d prometheus grafana
    sleep 5
else
    echo -e "${COLOR_YELLOW} Prometheus & Grafana appear to already be running. ${COLOR_RESET}"
fi

# Local Traefik LB setup

PROXY_CFG="$(pwd)/local-proxy/traefik.yml"
if [[ ! -f "$PROXY_CFG" ]]; then
    echo -e "${COLOR_RED} ERROR: local-proxy/traefik.yml not found! Make sure you cloned the repo correctly. ${COLOR_RESET}"
    exit 1
fi

if ! lsof -i TCP:9445 &>/dev/null; then
    echo "Starting local Traefik (load balancer) from local-proxy/traefik.yml…"
    (cd local-proxy && traefik --configFile=traefik.yml) &
    TRAEFIK_PID=$!
    echo "$TRAEFIK_PID" >>"$PID_FILE"
    sleep 2
else
    echo -e "${COLOR_YELLOW} local Traefik already appears to be listening on port 9445. ${COLOR_RESET}"
fi

# Port-forwarding

if ! lsof -i TCP:31883 &>/dev/null; then
    echo "Port-forwarding US cluster Traefik metrics to localhost:31883…"
    kubectl --context=kind-foobar-us -n traefik port-forward svc/traefik 31883:8082 >/dev/null 2>&1 &
    PF_US_PID=$!
    echo "$PF_US_PID" >>"$PID_FILE"
    sleep 1
else
    echo -e "${COLOR_YELLOW} Port 31883 is already forwarded or in use. ${COLOR_RESET}"
fi

if ! lsof -i TCP:31884 &>/dev/null; then
    echo "Port-forwarding EU cluster Traefik metrics to localhost:31884…"
    kubectl --context=kind-foobar-eu -n traefik port-forward svc/traefik 31884:8082 >/dev/null 2>&1 &
    PF_EU_PID=$!
    echo "$PF_EU_PID" >>"$PID_FILE"
    sleep 1
else
    echo -e "${COLOR_YELLOW} Port 31884 is already forwarded or in use. ${COLOR_RESET}"
fi

cat <<EOF

✅ metrics ready!
   • Grafana:                http://localhost:3000
   • local Traefik metrics:  http://localhost:9100/metrics
   • US Traefik metrics:     http://localhost:31883/metrics
   • EU Traefik metrics:     http://localhost:31884/metrics

EOF

# keep script alive so port-forwards and traefik stay up
read -n 1 -s -r -p "Press any key to exit this script (services keep running)…" && echo
