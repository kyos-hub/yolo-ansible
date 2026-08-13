# Yolo - Ansible Configuration Management (Stage 1)

Automates provisioning of a Vagrant-managed Ubuntu 20.04 VM and deployment of the Yolo e-commerce application (React frontend, Node/Express backend, MongoDB) entirely via Ansible roles.

## Prerequisites

- Vagrant
- VirtualBox
- Ansible (control machine - WSL/Linux)

## Usage

1. Bring up the VM:
   ```
   vagrant up
   ```

2. Run the playbook:
   ```
   ansible-playbook -i inventory.ini playbook.yml
   ```

3. Visit the app:
   ```
   http://localhost:3000
   ```

## Structure

- `Vagrantfile` - defines the VM and forwarded ports (22, 3000, 5000)
- `inventory.ini` - Ansible inventory pointing at the Vagrant VM
- `group_vars/all.yml` - shared variables (image tags, container names, ports)
- `roles/docker` - installs Docker Engine and creates the app network
- `roles/app_repo` - clones the application source code
- `roles/mongodb` - runs the MongoDB container with a persistent volume
- `roles/backend` - builds and runs the backend API container
- `roles/frontend` - builds and runs the frontend container
- `playbook.yml` - orchestrates all roles in order

See `explanation.md` for detailed reasoning behind the playbook's structure and execution order.
