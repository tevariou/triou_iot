# P1 and  P2
## Setup Vagrant
### Install vagrant (2.4.3)

https://developer.hashicorp.com/vagrant/install
```shell
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install vagrant build-essential
```

### Install qemu-kvm and libvirt (Not needed for virtualbox)

```shell
sudo apt install qemu-system qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils libvirt-dev
sudo systemctl enable --now libvirtd
sudo systemctl start libvirtd
sudo usermod -aG kvm $USER
sudo usermod -aG libvirt $USER
vagrant plugin install vagrant-qemu
vagrant plugin install vagrant-libvirt
```

### Install virtualbox

```shell
sudo apt install virtualbox virtualbox-qt virtualbox-dkms virtualbox-guest-additions-iso virtualbox-guest-utils virtualbox-ext-pack
```

### Install nfs for sync folders

```shell
sudo apt install nfs-kernel-server
sudo systemctl start nfs-kernel-server.service
```

# Part 3

## Install ansible
    
```shell
sudo apt update
sudo apt install pipx
pipx ensurepath

pipx install --include-deps ansible
```

## Install k3d

### Install docker
```shell
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### Install kubectl

```shell
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

### Install k3d
```shell
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
```

## Install helm
```shell
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm
```

## Create k3d cluster
```shell
sudo k3d cluster create triouS -p "8888:80@loadbalancer"
```

## Install argocd with helm (argocd namespace)

```shell
sudo helm repo add argo https://argoproj.github.io/argo-helm

sudo helm install argocd argo/argo-cd -f ./p3/confs/argocd/values.yaml --namespace=argocd --create-namespace
sudo kubectl apply -f ./p3/confs/argocd/ingress.yaml
```

## Access argocd via port forwarding (optional)
    
```shell
sudo kubectl port-forward svc/argocd-server -n argocd 8080:80 --address="0.0.0.0"
```
Then access http://64.226.99.156:8080/argocd in your browser

## Install argocd cli
```shell
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64
```

## Argocd credentials

```shell
sudo argocd admin initial-password -n argocd
```

## Create argocd app

```shell
sudo kubectl apply -f ./p3/confs/argocd/app.yaml
``` 
