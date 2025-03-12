#!/bin/bash

# Set swapiness as recommended
echo "Setting swapiness..."
sysctl vm.swappiness=10

# Delete previous GitLab installation if exists
echo "Deleting previous GitLab installation..."
kubectl patch app gitlab  -n argocd -p '{"metadata": {"finalizers": ["resources-finalizer.argocd.argoproj.io"]}}' --type merge
kubectl delete app gitlab -n argocd
kubectl delete namespace gitlab

# Create gitlab namespace
echo "Creating gitlab namespace..."
kubectl create namespace gitlab

# Wait for gitlab pods to be deleted
until [ "$(kubectl get pods -n gitlab --no-headers | wc -l)" == "0" ]; do
  echo "Waiting for GitLab pods to be deleted..."
  sleep 60
done

# Install GitLab
echo "Installing GitLab..."
kubectl apply -f bonus/confs/gitlab-app.yml

# Wait for GitLab to be ready
until kubectl get ingress gitlab-webservice-default -n gitlab; do
  echo "Waiting for GitLab ingress to be created..."
  sleep 60
done

# Wait for ingress IP to be assigned
until [ "$(kubectl get ingress gitlab-webservice-default -n gitlab -o jsonpath="{.status.loadBalancer.ingress[0].ip}")" != "" ]; do
  echo "Waiting for GitLab ingress IP to be assigned..."
  sleep 60
done

sed -i '/gitlab.example.com/d' /etc/hosts
gitlab_addr=$(kubectl -n gitlab get ingress gitlab-webservice-default -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
echo "${gitlab_addr}" | xargs -I {} echo {} gitlab.example.com >> /etc/hosts

# Edit core-dns configmap to add GitLab domain
echo "Editing core-dns configmap to add GitLab domain..."
kubectl -n kube-system delete configmap coredns-custom
GITLAB_ADDR=$gitlab_addr envsubst < bonus/confs/coredns-config.yml | kubectl apply -f -
kubectl rollout restart deployment coredns -n kube-system
