# LXC Container Provisioning Runbook

## Overview

This document describes the complete provisioning pipeline for LXC containers on the Proxmox edge node (NUC5, 192.168.1.20).

## Architecture & Design

### Network Topology

```
Proxmox Host (192.168.1.20)
├── Pi-hole Container      (CT 100, 192.168.1.21)
├── Tailscale Container    (CT 101, 192.168.1.22)
├── Uptime Kuma Container  (CT 102, 192.168.1.23)
└── PBS Container          (CT 103, 192.168.1.24)

Real Gateway: 192.168.1.254 (not 192.168.1.1)
DNS Servers: 8.8.8.8, 8.8.4.4
```

### Provisioning Phases

The provisioning pipeline is split into distinct phases because of a **chicken-and-egg problem**: Ansible requires SSH to reach containers, but SSH isn't installed by default on fresh Debian containers.

| Phase | What | Where | How | Tools |
|-------|------|-------|-----|-------|
| **Phase 0** | Create container (LVM, network config, OS) | Proxmox UI / Terraform | Manual or IaC | Proxmox Web UI / Terraform |
| **Phase 1** | Install & enable SSH server | Proxmox Host | `pct exec` direct commands | Shell script (`bootstrap-lxc-ssh.sh`) |
| **Phase 2** | Configure networking, DNS, repos, packages | Containers | SSH / Ansible plays | Ansible (`lxc-baseline.yml`) |
| **Phase 3** | Configure Proxmox container state (auto-start, nesting, TUN) | Proxmox Host | `pct` commands | Ansible play (first play of `lxc-baseline.yml`) |

## Provisioning Checklist

### Pre-Requisites

- [ ] Proxmox VE 8.x running on NUC5 (192.168.1.20)
- [ ] Containers created with static IPs (192.168.1.21-24)
- [ ] Containers are powered on and running
- [ ] You have SSH access to the Proxmox host as root
- [ ] You have an SSH public key (for passwordless Ansible access)

### Step 1: Create Containers

Create LXC containers on the Proxmox host. You can use the Proxmox UI, `pct create`, or Terraform.

**Minimal LXC container spec** (example for Pi-hole, CT 100):

```bash
pct create 100 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  --hostname pihole \
  --cores 2 \
  --memory 512 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.1.21/24,gw=192.168.1.1 \
  --rootfs local:10 \
  --onboot 1
```

After creation, **DO NOT start the containers yet** — wait until after SSH bootstrap.

### Step 2: SSH Bootstrap (One-Time)

Run the SSH bootstrap script on the Proxmox host. This installs openssh-server on each container using `pct exec`, which does NOT require SSH to be running yet.

**From your control machine (ThinkPad):**

```bash
ssh root@192.168.1.20 'bash -s' < scripts/bootstrap-lxc-ssh.sh
```

Or **directly on the Proxmox host:**

```bash
cd /root/homelab  # or wherever the repo is cloned
bash scripts/bootstrap-lxc-ssh.sh
```

**What this script does:**
- Updates package cache on each container (via `pct exec`)
- Installs `openssh-server` on each container
- Enables and starts the SSH service
- Waits for SSH to be reachable on each container IP

**Expected output:**
```
==================================
LXC SSH Bootstrap Script
==================================

[VMID 100] Starting bootstrap...
[VMID 100] Updating package cache...
[VMID 100] Installing openssh-server...
[VMID 100] Enabling SSH service...
[VMID 100] Starting SSH service...
[VMID 100] ✓ SSH service is running
...
==================================
✓ SSH Bootstrap Complete!
==================================
```

### Step 3: SSH Key Distribution

Set up passwordless SSH access from your control machine to the containers.

```bash
# For each container, copy your SSH public key
for ip in 192.168.1.21 192.168.1.22 192.168.1.23 192.168.1.24; do
  ssh-copy-id -i ~/.ssh/id_rsa.pub root@$ip
done

# Verify you can reach them without a password
ssh root@192.168.1.21 'echo "✓ SSH access confirmed"'
```

### Step 4: Run Ansible Baseline Playbook

Now Ansible can take over. The `lxc-baseline.yml` playbook configures everything inside the containers and on the Proxmox host.

**Dry-run first (recommended):**

```bash
cd infra/ansible
ansible-playbook -i inventory/hosts.yml playbooks/lxc-baseline.yml --check
```

**Run the playbook:**

```bash
cd infra/ansible
ansible-playbook -i inventory/hosts.yml playbooks/lxc-baseline.yml -v
```

**What the playbook does:**

1. **Proxmox Host Play** (targeting `proxmox_hosts` group):
   - Enables auto-start on all containers (`pct set <vmid> --onboot 1`)
   - Enables nesting feature on all containers (`pct set <vmid> --features nesting=1`)
   - Configures TUN device for Tailscale container (edits `/etc/pve/lxc/101.conf`)

2. **Container Baseline Play** (targeting `edge_lxc` group):
   - Configures DNS nameservers (`/etc/resolv.conf`)
   - Sets correct default route (192.168.1.254, not 192.168.1.1)
   - Installs core packages (curl, wget, dnsutils, etc.)
   - Verifies SSH service is running and enabled
   - Handles repository file format (deb822 `.sources` vs old `.list`)
   - Sets hostnames

### Step 5: Verify

Check that everything is working:

```bash
# Test DNS resolution in a container
ansible pihole -i infra/ansible/inventory/hosts.yml -m shell -a "dig google.com +short"

# Test ping to verify network connectivity
ansible edge_lxc -i infra/ansible/inventory/hosts.yml -m ping

# Check default routes
ansible edge_lxc -i infra/ansible/inventory/hosts.yml -m shell -a "ip route show | grep default"

# Verify hostnames
ansible edge_lxc -i infra/ansible/inventory/hosts.yml -m shell -a "hostname"
```

## Troubleshooting

### SSH Bootstrap Fails

**Symptom:** `pct exec` commands fail or containers don't respond

**Solutions:**
1. Verify containers are running: `pct list` on Proxmox host
2. Check container logs: `pct logs 100` (for CT 100)
3. Manually test: `pct exec 100 -- ls /` should list root directory
4. If `apt-get` fails due to DNS, containers need DNS configured first:
   ```bash
   pct exec 100 -- bash -c 'echo nameserver 8.8.8.8 > /etc/resolv.conf'
   ```

### Ansible Can't Reach Containers

**Symptom:** `SSH: Could not resolve hostname` or `Permission denied`

**Solutions:**
1. Verify SSH is running: `pct exec 100 -- systemctl status ssh`
2. Check if container has an IP: `pct exec 100 -- ip addr show eth0`
3. Verify SSH public key is copied: `ssh-copy-id -i ~/.ssh/id_rsa.pub root@192.168.1.21`
4. Test SSH manually: `ssh -v root@192.168.1.21` (check for errors)

### DNS Not Working

**Symptom:** `dig google.com` fails, `ping google.com` times out

**This is expected before Step 4.** The Ansible playbook configures DNS via `/etc/resolv.conf`.

If DNS fails *after* running the playbook:
1. Verify `dig` returns results: `dig @8.8.8.8 google.com +short`
2. Check `/etc/resolv.conf`: `cat /etc/resolv.conf` should show nameserver entries
3. Re-run the playbook to fix it: `ansible-playbook -i inventory/hosts.yml playbooks/lxc-baseline.yml`

### Default Route Points to Wrong Gateway

**Symptom:** `ip route show` shows `default via 192.168.1.1 ...` (incorrect)

**This is expected from LXC provisioning.** The Ansible playbook corrects it to 192.168.1.254.

If it still shows the wrong gateway after the playbook:
1. Verify the playbook ran: Check for task output mentioning "Update default route"
2. Re-run the playbook: `ansible-playbook -i inventory/hosts.yml playbooks/lxc-baseline.yml`
3. Manually verify: `ip route show | grep default` should show `via 192.168.1.254`

### TUN Device Not Available (Tailscale Container)

**Symptom:** Tailscale fails to start, logs show `Cannot open /dev/net/tun`

**This is expected before the playbook runs.** The first play configures TUN in `/etc/pve/lxc/101.conf` and restarts the container.

If TUN still fails after the playbook:
1. Verify container config: `cat /etc/pve/lxc/101.conf | grep tun`
2. Container should be running; if not, restart it: `pct start 101`
3. Re-run the playbook, paying attention to Tailscale container restart output

### Container Doesn't Auto-Start After Reboot

**Symptom:** Container is stopped after Proxmox host reboots

**This is expected before Step 4.** The Ansible playbook enables auto-start.

If containers are still stopped after the playbook:
1. Verify the setting: `pct config 100 | grep onboot`
2. Should show: `onboot: 1`
3. Re-run the Proxmox host play if needed: `ansible-playbook -i inventory/hosts.yml playbooks/lxc-baseline.yml --check`

## Re-Running the Playbook (Idempotency)

The Ansible playbook is fully idempotent. You can re-run it safely without side effects:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/lxc-baseline.yml
```

This is useful for:
- Fixing configuration drift (if someone manually changes a container)
- Applying updates to the baseline configuration
- Verifying all containers are in the desired state

## Advanced: Customizing Container Configuration

### Adding a New Container

1. Create the container on Proxmox (see Step 1)
2. Add an entry to `infra/ansible/inventory/hosts.yml` under `edge_lxc` group
3. If the container needs VPN (TUN device), also add it to `lxc_vpn` group
4. Run the SSH bootstrap script: `bash scripts/bootstrap-lxc-ssh.sh`
5. Copy SSH keys: `ssh-copy-id -i ~/.ssh/id_rsa.pub root@<container-ip>`
6. Run the Ansible playbook: `ansible-playbook -i inventory/hosts.yml playbooks/lxc-baseline.yml`

### Disabling Enterprise Repository

The playbook automatically disables the Proxmox Enterprise repository in containers (to avoid auth errors when running updates).

If you need to re-enable it:
1. Edit container config: `/etc/apt/sources.list.d/pve-enterprise.sources` or `/etc/apt/sources.list.d/pve-enterprise.list`
2. Uncomment the line (remove the `#` at the start)
3. Run `apt-get update`

### Persistent IP Assignment

Containers in this setup use static IPs (192.168.1.21-24) set via Proxmox LXC configuration. If you need to change an IP:

1. Stop the container: `pct stop 100`
2. Edit its config: `pct set 100 --net0 name=eth0,bridge=vmbr0,ip=192.168.1.25/24,gw=192.168.1.254`
3. Update the Ansible inventory
4. Start the container: `pct start 100`
5. Update SSH keys if the IP changed
6. Re-run the playbook

## Related Documents

- **Provisioning Errors Log**: [docs/postmortems/lxc-provisioning-issues.md](../postmortems/lxc-provisioning-issues.md)
- **Proxmox Host Configuration**: See Proxmox VE documentation for your version
- **Ansible Configuration**: [infra/ansible/](../../infra/ansible/)

## References

- Proxmox LXC Documentation: https://pve.proxmox.com/wiki/LXC
- Debian Container DNS: https://wiki.debian.org/NetworkConfiguration
- Tailscale on LXC: https://tailscale.com/kb/1048/install-linux/
- Ansible Best Practices: https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html
