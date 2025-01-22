#!/usr/bin/env bash

set -x

# configure firewall

ufw disable
#ufw allow 6443/tcp #apiserver
#ufw allow from 10.42.0.0/16 to any #pods
#ufw allow from 10.43.0.0/16 to any #services

TIMEOUT=300  # 5 minutes
ELAPSED=0
INTERVAL=5

while [ ! -f /vagrant/k3s-token ]; do
  if [ $ELAPSED -ge $TIMEOUT ]; then
      echo "Timeout reached. Unable to retrieve the k3s token. Exiting..."
      exit 1
  fi

  echo "Waiting for k3s token..."
  sleep $INTERVAL
  ELAPSED=$((ELAPSED + INTERVAL))
done

echo "k3s token found!"

# install k3s for agent
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="agent --token $(cat /vagrant/k3s-token) --server https://192.168.56.110:6443 --node-name triouSW --node-ip=192.168.56.111" sh -s -

# Remove the token file
rm /vagrant/k3s-token
