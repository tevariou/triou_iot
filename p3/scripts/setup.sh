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
k3d cluster create "triouS" --api-port 6550 -p "8888:30888@server:0" --k3s-arg "--disable=traefik@server:0" --k3s-arg "--disable=servicelb@server:0" --no-lb --wait

# Install and configure MetalLB
echo "Installing MetalLB..."
curl -fsSL https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml -o ~/metallb-native.yaml
chmod 0664 ~/metallb-native.yaml
kubectl apply -f ~/metallb-native.yaml
sleep 30

# Wait for MetalLB pods to be running
while [ "$(kubectl get pods -n metallb-system --no-headers | grep -c 'Running')" -ne "$(kubectl get pods -n metallb-system --no-headers | wc -l)" ]; do
  echo "Waiting for MetalLB pods to be running..."
  sleep 60
done

# Wait for ingress to be created
until kubectl get svc metallb-webhook-service -n metallb-system; do
  echo "Waiting for metallb svc to be created..."
  sleep 60
done

# Get the CIDR block of the cluster
cluster_name="k3d-triouS"
cidr_block=$(docker network inspect $cluster_name | jq -r '.[0].IPAM.Config[0].Subnet')
cidr_base_addr=${cidr_block%???}
ingress_first_addr=$(echo $cidr_base_addr | awk -F'.' '{print $1,$2,255,2}' OFS='.')
ingress_last_addr=$(echo $cidr_base_addr | awk -F'.' '{print $1,$2,255,254}' OFS='.')
ingress_range=$ingress_first_addr-$ingress_last_addr

# Configure MetalLB
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default
  namespace: metallb-system
spec:
  addresses:
    - "$ingress_range"
  autoAssign: true
  avoidBuggyIPs: true
EOF

cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
    - default
EOF

# Install NGINX ingress controller
echo "Installing NGINX ingress controller..."
curl -fsSL https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.0/deploy/static/provider/aws/deploy.yaml -o ~/nginx-deploy.yaml
chmod 0664 ~/nginx-deploy.yaml
kubectl apply -f ~/nginx-deploy.yaml

# Install ArgoCD
echo "Installing ArgoCD..."
helm repo add argo https://argoproj.github.io/argo-helm
kubectl apply -k "https://github.com/argoproj/argo-cd/manifests/crds?ref=v2.13.3"
kubectl create namespace argocd
helm install argocd argo/argo-cd --namespace argocd --version 7.8.0 --set crds.install=false --set configs.params."server\.insecure"=true
sleep 30

# Add ArgoCD ingress
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    nginx.ingress.kubernetes.io/force-ssl-redirect: "false"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
spec:
  ingressClassName: nginx
  rules:
    - host: argocd.example.com
      http:
        paths:
          - pathType: Prefix
            path: /
            backend:
              service:
                name: argocd-server
                port:
                  number: 80
EOF

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
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/tevariou/triou_iot.git
    path: p3/confs/
    targetRevision: main
  destination:
    server: "https://kubernetes.default.svc"
    namespace: dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: true
    syncOptions:
      - CreateNamespace=true
EOF
