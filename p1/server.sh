#!/usr/bin/env bash

set -x

# configure firewall
ufw disable
#ufw allow 6443/tcp #apiserver
#ufw allow from 10.42.0.0/16 to any #pods
#ufw allow from 10.43.0.0/16 to any #services

# install k3s for master
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode \"0644\" --tls-san triouS --node-name triouS --node-ip 192.168.56.110 --bind-address 192.168.56.110 --advertise-address 192.168.56.110 --cluster-init" sh -s -

# Store the token for the workers to use
echo "Storing the k3s token..."

NODE_TOKEN=$(cat /var/lib/rancher/k3s/server/node-token)
echo "$NODE_TOKEN" > /vagrant/k3s-token
