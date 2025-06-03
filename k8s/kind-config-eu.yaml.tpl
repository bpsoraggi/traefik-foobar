kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 30443
        hostPort: 9444
        protocol: TCP
      - containerPort: 31883 # traefik-metrics
        hostPort: 31884
        protocol: TCP
    extraMounts:
      - hostPath: "${PWD}/k8s/certs/eu"
        containerPath: "/cert"
