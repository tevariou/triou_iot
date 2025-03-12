#!/bin/bash

# Install docker
echo "Installing docker..."
apt-get update
apt-get install -y ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Install kubectl
echo "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install k3d
echo "Installing k3d..."
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Install helm
echo "Installing helm..."
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | tee /usr/share/keyrings/helm.gpg > /dev/null
apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
apt-get update
apt-get install helm

# Install and configure k3d cluster
echo "Creating k3d cluster..."
k3d cluster delete "triouS" || true
k3d cluster create "triouS" --api-port 6550 --k3s-arg "--disable=traefik@server:0" --k3s-arg "--disable=servicelb@server:0" --no-lb --wait

# Install and configure MetalLB
echo "Installing MetalLB..."
curl -fsSL https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml -o ~/metallb-native.yaml
chmod 0664 ~/metallb-native.yaml
kubectl apply -f ~/metallb-native.yaml
sleep 10

# Wait for MetalLB pods to be running
while [ "$(kubectl get pods -n metallb-system --no-headers | grep -c 'Running')" -ne "$(kubectl get pods -n metallb-system --no-headers | wc -l)" ]; do
  echo "Waiting for MetalLB pods to be running..."
  sleep 30
done

# Wait for ingress to be created
until kubectl get svc metallb-webhook-service -n metallb-system; do
  echo "Waiting for metallb svc to be created..."
  sleep 30
done

# Get the CIDR block of the cluster
cluster_name="k3d-triouS"
cidr_block=$(docker network inspect $cluster_name | jq -r '.[0].IPAM.Config[0].Subnet')
cidr_base_addr=${cidr_block%???}
ingress_first_addr=$(echo $cidr_base_addr | awk -F'.' '{print $1,$2,0,2}' OFS='.')
ingress_last_addr=$(echo $cidr_base_addr | awk -F'.' '{print $1,$2,0,8}' OFS='.')
ingress_range=$ingress_first_addr-$ingress_last_addr

# Configure MetalLB
INGRESS_RANGE=$ingress_range envsubst < p3/confs/metallb-config.yml | kubectl apply -f -

# Install NGINX ingress controller
echo "Installing NGINX ingress controller..."
curl -fsSL https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.0/deploy/static/provider/aws/deploy.yaml -o ~/nginx-deploy.yaml
chmod 0664 ~/nginx-deploy.yaml
kubectl apply -f ~/nginx-deploy.yaml
sleep 10

# Wait for nginx services to be created
until kubectl get svc ingress-nginx-controller -n ingress-nginx; do
  echo "Waiting for ingress-nginx service to be created..."
  sleep 30
done
until kubectl get svc ingress-nginx-controller-admission -n ingress-nginx; do
  echo "Waiting for ingress-nginx service to be created..."
  sleep 30
done

# Install ArgoCD
echo "Installing ArgoCD..."
helm repo add argo https://argoproj.github.io/argo-helm
kubectl apply -k "https://github.com/argoproj/argo-cd/manifests/crds?ref=v2.13.3"
kubectl create namespace argocd
helm install argocd argo/argo-cd --namespace argocd --version 7.8.0 --set crds.install=false --set configs.params."server\.insecure"=true
sleep 10

# Add ArgoCD ingress
kubectl apply -f p3/confs/argocd-ingress.yml

# Install ArgoCD CLI
echo "Installing ArgoCD CLI..."
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
install -m 555 argocd-linux-amd64 /usr/local/bin/argocd

# Wait for ingress to be created
until kubectl get ingress argocd-server-ingress -n argocd; do
  echo "Waiting for argocd ingress to be created..."
  sleep 60
done

# Wait for ingress IP to be assigned
until [ "$(kubectl get ingress argocd-server-ingress -n argocd -o jsonpath="{.status.loadBalancer.ingress[0].ip}")" != "" ]; do
  echo "Waiting for argocd ingress IP to be assigned..."
  sleep 60
done

# Add argocd ip to /etc/hosts
sed -i '/argocd.example.com/d' /etc/hosts
kubectl get ingress argocd-server-ingress -n argocd -o jsonpath="{.status.loadBalancer.ingress[0].ip}" | xargs -I {} echo {} argocd.example.com >> /etc/hosts

# Create dev namespace
echo "Creating dev namespace..."
kubectl create namespace dev

# Install Wil's app
echo "Installing Wil's app..."
kubectl apply -f p3/confs/wil-app.yml
sleep 10

# Wait for Wil's app to be ready
until kubectl get svc playground-service -n dev; do
  echo "Waiting for playground ingress to be created..."
  sleep 30
done

# Wait for ingress IP to be assigned
until [ "$(kubectl get svc playground-service -n dev -o jsonpath="{.status.loadBalancer.ingress[0].ip}")" != "" ]; do
  echo "Waiting for playground ingress IP to be assigned..."
  sleep 30
done

sysctl -w net.ipv4.conf.all.route_localnet=1
playground_svc=$(kubectl get svc -n dev playground-service -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
iptables -t nat -A OUTPUT -m addrtype --src-type LOCAL --dst-type LOCAL -p tcp --dport 8888 -j DNAT --to-destination "${playground_svc}"
iptables -t nat -A POSTROUTING -m addrtype --src-type LOCAL --dst-type UNICAST -j MASQUERADE
