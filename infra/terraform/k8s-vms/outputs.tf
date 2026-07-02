output "control_plane_ip" {
  value = "192.168.1.30"
}

output "worker_ips" {
  value = {
    "k3s-w-01" = "192.168.1.31"
    "k3s-w-02" = "192.168.1.32"
  }
}
