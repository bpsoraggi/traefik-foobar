# foobar-deploy

A demonstration of deploying the [foobar-api](https://github.com/containous/foobar-api) Go service across two Kubernetes clusters (US and EU data centers) with HTTPS certificates stored in PVCs. This repo was created as a technical assignment to showcase:

- End-to-end TLS using certificates in a PVC
- Two distinct “datacenters” (kind clusters)
- Cross-cluster load-balancing via a local Traefik proxy
- Kubernetes best practices and SOC 2–style controls (least privilege, network isolation, non-root containers)
- Basic monitoring with Prometheus & Grafana
- Liveness/readiness probes, resource limits, and secure defaults

---

## Prerequisites

- OpenSSL
- Kind
- Docker
- Kubernetes

---

## Quickstart

1. **Build Docker Image Locally**

   ```bash
   docker build -t foobar-api:latest .
   ```

2. **Run Setup Script**

   ```bash
   make setup
   ```

3. **Access Local Metrics**

   |               |                                                                  |
   | ------------- | ---------------------------------------------------------------- |
   | Grafana       | [http://localhost:3000](http://localhost:3000)                   |
   | Local Traefik | [http://localhost:9100/metrics](http://localhost:9100/metrics)   |
   | US Cluster    | [http://localhost:31883/metrics](http://localhost:31883/metrics) |
   | EU Cluster    | [http://localhost:31884/metrics](http://localhost:31884/metrics) |

   Test with curl:

   - **US Direct Test**

     ```bash
     curl -vk \
       --resolve us.foobar.local:9443:127.0.0.1 \
       https://us.foobar.local:9443/health
     ```

   - **EU Direct Test**

     ```bash
     curl -vk \
       --resolve eu.foobar.local:9444:127.0.0.1 \
       https://eu.foobar.local:9444/health
     ```

   - **Cross-Cluster Load-Balance**

     ```bash
     curl -vk \
       --resolve api.foobar.local:9445:127.0.0.1 \
       https://api.foobar.local:9445/health
     # Repeat to observe round-robin between US and EU
     ```

---

## Monitoring

- **Prometheus**: Scrapes Traefik’s `/metrics`. Deployed via Helm in each cluster
- **Grafana**: Preconfigured to use the local Prometheus

---

## SOC 2 & Security Highlights

- **Non-Root Containers**: Both Traefik and foobar-api run as non-root users (UID 65532 and UID 1000, respectively)
- **Network Isolation**: A `NetworkPolicy` in `foobar-app` allows only pods running in the Traefik namespace to reach the application pods
- **Least Privilege**: `foobar-sa` ServiceAccount has no extra RBAC roles
- **Encryption In Transit**: All ingress is TLS (self-signed for demo). Certificates live on a PVC (hostPath in kind), then imported into a Kubernetes TLS Secret

---

## Next Steps & Improvements

- Integrate **cert-manager** for automated certificate issuance/renewal (Let’s Encrypt or internal CA)
- Add **mTLS** between Traefik and application pods (via Traefik’s `serversTransport` or a service mesh)
- Build a **CI/CD pipeline** (GitOps) to lint, test, scan images, and deploy via Argo CD or Flux
- Enable **persistent storage** for Prometheus & Grafana with encryption at rest and scheduled backups
- Instrument `foobar-api` with **Prometheus client libraries** for business-level metrics

---

## Acknowledgments

- Original Go code by [containous/foobar-api](https://github.com/containous/foobar-api)
