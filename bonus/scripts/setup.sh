#!/bin/bash

# Set swapiness as recommended
echo "Setting swapiness..."
sysctl vm.swappiness=10

# Create gitlab namespace
echo "Creating gitlab namespace..."
kubectl create namespace gitlab

# Install GitLab
echo "Installing GitLab..."
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: gitlab
  namespace: argocd
spec:
  project: default
  sources:
    - repoURL: "https://charts.gitlab.io/"
      chart: gitlab
      targetRevision: 8.8.1
      helm:
        parameters:
          - name: "global.hosts.domain"
            value: "example.com"
          - name: "certmanager-issuer.email"
            value: "triou@student.42.fr"
          - name: "global.edition"
            value: "ce"
          - name: "upgradeCheck.enabled"
            value: "false"
        values: |
          prometheus:
            install: false
          registry:
            enabled: false
          gitlab-runner:
            install: false
          gitlab:
            webservice:
              resources:
                requests:
                  memory: 512Mi
          global:
            upgradeCheck.enabled: false
            rails:
              extraEnv:
                MALLOC_CONF: "dirty_decay_ms:1000,muzzy_decay_ms:1000"
            monitoring:
              enabled: false
            appConfig:
              lfs:
                enabled: false
              artifact:
                enabled: false
              object_store:
                enabled: false
              sidekiq:
                memoryKiller:
                  maxRss: 2000000
                concurrency: 10
              gitaly:
                memory:
                  limit: 500Mi
                shell.concurrency:
                  - rpc: "/gitaly.SmartHTTPService/PostReceivePack"
                    max_per_repo: 13
                  - rpc: "/gitaly.SSHService/SSHUploadPack"
                    max_per_repo: 3
                cgroups:
                  repositories.count: 2
                  mountpoint: "/sys/fs/cgroup"
                  hierarchyRoot: "gitaly"
                  memoryBytes: 500000
                  cpuShares: 512
                extraEnv:
                  MALLOC_CONF: "dirty_decay_ms:1000,muzzy_decay_ms:1000"
                  GITALY_COMMAND_SPAWN_MAX_PARALLEL: 2
  destination:
    server: "https://kubernetes.default.svc"
    namespace: gitlab
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: true
    syncOptions:
      - CreateNamespace=true
EOF

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

# Upgrade ArgoCD to add GitLab host alias
echo "Upgrading ArgoCD to add GitLab host alias..."
helm upgrade argocd argo/argo-cd -n argocd --reuse-values --set "global.hostAliases[0].ip=${gitlab_addr}" --set "global.hostAliases[0].hostnames[0]=gitlab.example.com" --wait
