RESOLVE="-k --resolve api.foobar.local:9445:127.0.0.1"

source "$(dirname "$0")/colors.sh"

# =============================================================================
# Performs a series of API calls to the local Traefik load balancer
# =============================================================================

echo "1) /bench ${COLOR_RED} > ${COLOR_YELLOW} expect '1' ${COLOR_RESET}"
curl $RESOLVE https://api.foobar.local:9445/bench
echo
echo
echo "2) /data?size=8&unit=kb ${COLOR_RED} > ${COLOR_YELLOW} expect 8192 bytes ${COLOR_RESET}"
curl -s $RESOLVE -G \
    --data-urlencode "size=8" \
    --data-urlencode "unit=kb" \
    https://api.foobar.local:9445/data | wc -c
echo
echo
echo "3) /data?size=1&unit=mb&attachment=true ${COLOR_RED} > ${COLOR_YELLOW} download 1 MiB ${COLOR_RESET}"
curl $RESOLVE -G \
    --data-urlencode "size=1" \
    --data-urlencode "unit=mb" \
    --data-urlencode "attachment=true" \
    https://api.foobar.local:9445/data -o /tmp/out.dat
ls -lh /tmp/out.dat
echo
echo
echo "4) / (whoami) no wait"
curl $RESOLVE https://api.foobar.local:9445/ | head -n 6
echo
echo "5) /?wait=1s ${COLOR_RED} > ${COLOR_YELLOW} delayed ~1 s ${COLOR_RESET}"
time curl $RESOLVE "https://api.foobar.local:9445/?wait=1s" >/dev/null
echo
echo "6) /api ${COLOR_RED} > ${COLOR_YELLOW} JSON ${COLOR_RESET}"
curl $RESOLVE https://api.foobar.local:9445/api | jq .
echo
echo "7) /health GET ${COLOR_YELLOW} (should be 200) ${COLOR_RESET}"
curl -s $RESOLVE -o /dev/null -w "%{http_code}\n" https://api.foobar.local:9443/health
echo
echo "8) /health POST 500 ${COLOR_RED} > ${COLOR_YELLOW} set to 500 ${COLOR_RESET}"
curl -s $RESOLVE -X POST -H "Content-Type: application/json" --data '500' https://api.foobar.local:9443/health
echo
echo "9) /health GET ${COLOR_YELLOW} (should be 500) ${COLOR_RESET}"
curl -s $RESOLVE -o /dev/null -w "%{http_code}\n" https://api.foobar.local:9443/health
echo
echo "10) /health POST 200 ${COLOR_RED} > ${COLOR_YELLOW} reset ${COLOR_RESET}"
curl -s $RESOLVE -X POST -H "Content-Type: application/json" --data '200' https://api.foobar.local:9443/health
echo
echo "11) /echo WebSocket (send 'ping')"
echo '"ping"' | websocat --insecure "wss://api.foobar.local:9445/echo"
echo
echo "${COLOR_GREEN} All done. ${COLOR_RESET}"
