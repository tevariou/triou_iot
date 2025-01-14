## Setup Vagrant
### Install vagrant (2.4.3)

https://developer.hashicorp.com/vagrant/install
```shell
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install vagrant build-essential
```

### Install qemu-kvm and libvirt


```shell
sudo apt install qemu-system qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils libvirt-dev
sudo systemctl enable --now libvirtd
sudo systemctl start libvirtd
sudo usermod -aG kvm $USER
sudo usermod -aG libvirt $USER
vagrant plugin install vagrant-qemu
vagrant plugin install vagrant-libvirt
```

### Install nfs for sync folders

```shell
sudo apt install nfs-kernel-server
sudo systemctl start nfs-kernel-server.service
```

### Install vagrant box (image): Ubuntu LTS 22.04

`vagrant init generic/ubuntu2204 --box-version 4.3.12`

#### Edit vagrantfile

```text
Vagrant.configure("2") do |config|
  config.vm.box = "cloud-image/ubuntu-24.04"
  config.vm.box_version = "20240822.0.0"
end
```