#!/bin/bash

# Add HashiCorp repository for Vagrant
if [ ! -f /usr/share/keyrings/hashicorp-archive-keyring.gpg ]; then
  apt update
  apt install -y gnupg
  wget -O - https://apt.releases.hashicorp.com/gpg | gpg --yes --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list
  apt update
fi

# Accept virtualbox-ext-pack license
echo virtualbox-ext-pack virtualbox-ext-pack/license select true | debconf-set-selections
echo virtualbox-ext-pack virtualbox-ext-pack/license seen true | debconf-set-selections

# Install Vagrant and provider
apt install -y \
  vagrant \
  build-essential \
  nfs-kernel-server \
  virtualbox \
  virtualbox-dkms \
  virtualbox-qt \
  virtualbox-guest-additions-iso \
  virtualbox-guest-utils \
  virtualbox-ext-pack

# Make sure nfs kernel server is running
systemctl start nfs-kernel-server
