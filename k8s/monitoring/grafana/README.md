# Grafana Dashboards as Code

Dashboard JSON files stored here are exported from Grafana and committed to Git.
If Grafana is wiped or rebuilt, import these manually via:

Dashboards -> Import -> Upload JSON file

## Dashboards

- k3s-cluster.json — k3s cluster overview (based on dashboard ID 16450)
- node-exporter.json — Node Exporter Full (based on dashboard ID 1860)

## Data Sources Required

- Prometheus: http://192.168.1.25:9090
- Loki: http://192.168.1.27:3100

## Restoring After Wipe

1. Add Prometheus data source
2. Add Loki data source
3. Import k3s-cluster.json
4. Import node-exporter.json
5. Add Pi-hole local DNS records: argocd.home.lab and grafana.home.lab to 192.168.1.41
