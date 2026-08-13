#!/bin/bash
source ~/ansible-env/bin/activate
cd /mnt/c/Users/allan/Downloads/yolo-ansible/Stage_two
export ANSIBLE_ROLES_PATH=../roles
ansible-playbook -i inventory.ini playbook.yml
