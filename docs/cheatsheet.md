
### MetalLB IP announcement stuck after cluster disruption

Symptoms: Service has correct IP but connections fail, ARP resolves to wrong node

Fix:
    kubectl delete servicel2status -A --all
    kubectl rollout restart daemonset/speaker -n metallb-system
    kubectl rollout restart deployment/controller -n metallb-system
