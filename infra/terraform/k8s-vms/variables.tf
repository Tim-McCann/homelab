variable "proxmox_endpoint" {
  description = "Proxmox API endpoint"
  type        = string
  default     = "https://192.168.1.10:8006"
}

variable "proxmox_api_token" {
  description = "Proxmox API token in format root@pam!tokenid=secret"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
}

variable "template_vm_id" {
  description = "VM ID of the Ubuntu cloud-init template"
  type        = number
  default     = 9000
}
