#!/usr/bin/env bash

set -x

# install k3s for master
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode \"0644\" --tls-san triouS --node-name triouS --node-ip 192.168.56.110 --bind-address 192.168.56.110 --advertise-address 192.168.56.110 --cluster-init" sh -s -

# Store the token for the workers to use
echo "Storing the k3s token..."

# Remove old token file if it exists
if [ -f /vagrant/k3s-token ]; then
  rm /vagrant/k3s-token
fi

NODE_TOKEN=$(cat /var/lib/rancher/k3s/server/node-token)
echo "$NODE_TOKEN" > /vagrant/k3s-token

# Resolve app hosts
echo "192.168.56.110 app1.com app2.com app3.com" >> /etc/hosts

kubectl apply -f /vagrant/confs/app.yml
