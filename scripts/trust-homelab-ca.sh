#!/bin/bash
# trust-homelab-ca.sh
# Exports the homelab CA cert and installs it in Chrome/system trust store
# Run this on any Linux machine that needs to trust homelab.lab certificates

set -e

echo "==> Exporting homelab CA cert from cluster..."
kubectl get secret homelab-ca-secret -n cert-manager \
  -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/homelab-ca.crt

echo "==> Installing in system trust store..."
sudo cp /tmp/homelab-ca.crt /usr/local/share/ca-certificates/homelab-ca.crt
sudo update-ca-certificates

echo "==> Installing in Chrome NSS store..."
mkdir -p ~/.pki/nssdb
certutil -N --empty-password -d sql:$HOME/.pki/nssdb 2>/dev/null || true
certutil -A -n "Homelab CA" \
  -t "CT,C,C" \
  -i /tmp/homelab-ca.crt \
  -d sql:$HOME/.pki/nssdb

echo "==> Done. Restart Chrome: chrome://restart"
