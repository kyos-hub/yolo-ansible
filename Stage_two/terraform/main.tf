# This Terraform configuration provisions the Stage 2 environment by
# invoking Vagrant (to create the VM) and then Ansible (to configure it
# and deploy the application), chaining both tools together so that a
# single 'terraform apply' handles the entire process.

variable "vagrant_dir" {
  description = "Path to the directory containing the Stage 2 Vagrantfile"
  type        = string
  default     = ".."
}

variable "inventory_file" {
  description = "Path to the Ansible inventory file for this stage"
  type        = string
  default     = "../inventory.ini"
}

variable "playbook_file" {
  description = "Path to the Ansible playbook for this stage"
  type        = string
  default     = "../playbook.yml"
}

resource "null_resource" "provision_vm" {
  provisioner "local-exec" {
    command     = "vagrant up"
    working_dir = var.vagrant_dir
  }
}

resource "null_resource" "configure_with_ansible" {
  depends_on = [null_resource.provision_vm]

  provisioner "local-exec" {
    command = "wsl bash /mnt/c/Users/allan/Downloads/yolo-ansible/Stage_two/run_ansible.sh"
  }
}
