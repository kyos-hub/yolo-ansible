# Explanation - Stage 2: Terraform + Ansible

## Approach

Stage 2 builds on Stage 1 by adding Terraform as the entry point for the entire pipeline, so that a single terraform apply provisions the VM and configures/deploys the application, without any manual intervention between steps.

Since Stage 1's environment is a local VirtualBox VM (not a cloud resource), and Terraform does not have an official provider for VirtualBox/Vagrant directly, Stage 2 uses Terraform's built-in null_resource with local-exec provisioners to invoke both tools in sequence:

1. null_resource.provision_vm runs vagrant up inside the Stage 2 directory, which brings up a fresh Ubuntu 20.04 VM (using the same box and Docker/Ansible pipeline as Stage 1, but with a separate Vagrantfile and different forwarded ports - 2200/3001/5001 - so both stages can run side by side without port conflicts).

2. null_resource.configure_with_ansible depends explicitly on the first resource (depends_on = [null_resource.provision_vm]), guaranteeing Terraform only attempts to configure the VM after it is confirmed up. This resource shells out (via WSL, since Ansible is Linux-only) to run the same Ansible playbook and roles used in Stage 1, reusing them directly through a shared roles/ path rather than duplicating role logic for Stage 2.

## Why roles are reused rather than duplicated

Stage 2's playbook.yml references the exact same five roles (docker, app_repo, mongodb, backend, frontend) as Stage 1, resolved via an ANSIBLE_ROLES_PATH environment variable pointing back at the Stage 1 roles/ directory. This avoids maintaining two copies of the same configuration logic - if a role needs to change, it only needs to change in one place, and both stages pick up the update automatically.

## Terraform resource ordering

Terraform resources do not execute in the order they are written in the file by default - ordering is inferred from dependencies. The explicit depends_on on configure_with_ansible is what guarantees the correct sequence (VM first, then configuration), rather than relying on Terraform's default graph-based parallelism, which could otherwise attempt both local-exec blocks concurrently and fail since Ansible would try to connect to a VM that is not ready yet.

## Debugging notes

Several real infrastructure issues came up while getting Stage 2's toolchain working end-to-end, beyond the application logic itself:

- Quoting across shells: the initial local-exec command tried to pass a single-quoted, multi-part bash command directly through Windows' cmd /C, which mishandled the nested quotes. This was resolved by moving the Ansible invocation into a standalone shell script (run_ansible.sh) and having Terraform simply call that script, avoiding shell-in-shell quoting entirely.
- Line-ending and encoding issues: a script initially written via PowerShell's Out-File included a byte-order mark and Windows-style line endings, which broke its shebang line when executed inside WSL. Rewriting the script directly from within WSL (which produces native Unix line endings) resolved this.
- SSH key staleness after VM recreation: destroying and recreating the VM generates a new host key pair each time; the copy of the private key used by Ansible had to be refreshed to match, since it is copied out of the .vagrant/ machine-state folder into WSL's native filesystem (required because SSH refuses to use key files with overly permissive permissions, which NTFS-mounted paths under /mnt/c/ cannot properly restrict).
- VM auto-pause under host memory pressure: with two VMs and Docker Desktop's WSL2 backend all running simultaneously, VirtualBox automatically paused the Stage 2 VM at one point. This was resolved by resuming the VM (VBoxManage controlvm <name> resume) and, when that left the network in a stale state, performing a full vagrant reload to cleanly reboot networking before retrying.

None of these issues stemmed from the Terraform or Ansible configuration logic itself - they were all environment/tooling integration problems specific to running this stack locally on Windows via WSL2, and are documented here as the debugging measures applied called for by the assessment objectives.
