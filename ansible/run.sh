#!/usr/bin/env bash
ansible-playbook -i inventory.yaml playbook.yaml --extra-vars "vm_ip_address=${VM_IP_ADDRESS}" --tags ${ANSIBLE_TAG}
