# Setup VM

## Configure your ssh connection
    
* In your `~/.ssh/config` file, add the following configuration:
```text
Host do
HostName 64.226.99.156
User triou
AddKeysToAgent yes
UseKeychain yes
IdentityFile ~/.ssh/do_ed25519
```

## Install Ansible

* Requires python 3.12 on your system

```shell
cd ./<path_to_ansible_directory>
python -m venv .venv
source .venv/bin/activate
pip install ansible-core
ansible-galaxy install -r requirements.yaml
```

## Run the playbook

```shell
ansible-playbook -i inventory.yaml playbook.yaml 
```

# Part 3

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
sudo k3d cluster create triouS --api-port 6550 --k3s-arg "--disable=traefik@server:0" --k3s-arg "--disable=servicelb@server:0" --no-lb
```

### Install metallb
```shell
sudo kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml
```

#### Configure metallb
```shell
cluster_name=k3d-triouS
cidr_block=$(sudo docker network inspect $cluster_name | jq -r '.[0].IPAM.Config[0].Subnet')
cidr_base_addr=${cidr_block%???}
ingress_first_addr=$(echo $cidr_base_addr | awk -F'.' '{print $1,$2,255,2}' OFS='.')
ingress_last_addr=$(echo $cidr_base_addr | awk -F'.' '{print $1,$2,255,254}' OFS='.')
ingress_range=$ingress_first_addr-$ingress_last_addr
cat <<EOF | sudo kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default
  namespace: metallb-system
spec:
  addresses:
   - $ingress_range
  autoAssign: true
  avoidBuggyIPs: true
EOF
cat <<EOF | sudo kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
  - default
EOF
```

## Install nginx ingress controller

```shell
sudo kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.0/deploy/static/provider/aws/deploy.yaml
```

## Install argocd with helm (argocd namespace)

```shell
sudo helm repo add argo https://argoproj.github.io/argo-helm
sudo kubectl apply -k "https://github.com/argoproj/argo-cd/manifests/crds?ref=v2.13.3"
sudo helm install argocd argo/argo-cd -f ./p3/confs/argocd/values.yaml --namespace=argocd --create-namespace
sudo kubectl apply -f p3/confs/argocd/ingress.yaml
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

## Create argocd app (P3)

```shell
sudo kubectl apply -f ./p3/confs/argocd/app.yaml
``` 

# Bonus

## Install Gitlab

### References

https://docs.gitlab.com/omnibus/settings/memory_constrained_envs.html
https://docs.gitlab.com/omnibus/settings/rpi.html

### Set VM swap memory

Configure it in the current session:
```shell
sudo sysctl vm.swappiness=10
```

Edit /etc/sysctl.conf to make it permanent:
```
vm.swappiness=10
``` 

### Create gitlab app

On your local machine, add the following line to your `/etc/hosts` file:
```shell
echo "64.226.99.156 gitlab.example.com argocd.example.com" | sudo tee -a /etc/hosts
```

```shell
sudo kubectl apply -f ./bonus/confs/argocd/app.yaml
```

## Setup NAT with iptables

```shell
sudo iptables -t nat -A PREROUTING -p tcp -i eth0 --dport 80 -j DNAT --to-destination 172.18.255.2
sudo iptables -A FORWARD -p tcp -d 172.18.255.2 -j ACCEPT
```

To make it permanent
```shell
sudo iptables-save > /etc/iptables/rules.v4
```

## Get gitlab root password
    
```shell
kubectl -n gitlab get secret gitlab-gitlab-initial-root-password -o jsonpath="{.data.password}" | base64 --decode
```