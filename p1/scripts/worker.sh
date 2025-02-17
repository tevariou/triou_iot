#!/usr/bin/env bash

set -x

# install k3s for agent
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="agent --token $(cat /vagrant/k3s-token) --server https://192.168.56.110:6443 --node-name triouSW --node-ip=192.168.56.111" sh -s -

# Remove the token file
rm /vagrant/k3s-token
