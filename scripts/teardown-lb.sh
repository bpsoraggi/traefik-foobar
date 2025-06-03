set -euo pipefail

source "$(dirname "$0")/colors.sh"

# =============================================================================
#
# 1) Stops/removes Prometheus & Grafana (Docker)
# 2) Reads PIDs from scripts/managed-pids.txt and kills exactly those
# 3) Removes scripts/managed-pids.txt when done
#
# Usage: ./scripts/shutdown-all.sh
# =============================================================================

PID_FILE="$(pwd)/scripts/managed-pids.txt"

echo "Stopping & removing Prometheus & Grafana containers…"
docker stop prom-local grafana-local 2>/dev/null || true
docker rm prom-local grafana-local 2>/dev/null || true
echo "Docker containers 'prom-local' and 'grafana-local' removed (if they existed)."

if [[ -f "$PID_FILE" ]]; then
    echo
    echo "⛔️  Killing processes started by start-lb.sh…"

    while read -r pid; do
        if kill -0 "$pid" &>/dev/null; then
            echo "   • Killing PID $pid"
            kill "$pid" || true
        else
            echo "   • PID $pid is not running; skipping."
        fi
    done <"$PID_FILE"

    echo "All PIDs from $PID_FILE have been handled."
    rm -f "$PID_FILE"
    echo "Removed $PID_FILE."
else
    echo
    echo "No PID file found at $PID_FILE; nothing to kill."
fi

echo
echo -e "${COLOR_GREEN} shutdown-all.sh complete. No services are running from this repo. ${COLOR_RESET}"
