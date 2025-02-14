# Setup VM

## Install requirements

```shell
sudo apt install -y git python3-venv python3-pip vim build-essential curl
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

## Edit the inventory file

In the `inventory.yaml` file, replace the `ansible_host` value with the IP address of your VM.

## Rdp access

Login: `triou`
Get password
```shell
kubectl get secret current-user-password -o jsonpath="{.data.password}" | base64 --decode | xargs
```

# Part 1

```shell
ansible-playbook -i inventory.yaml playbook.yaml --ask-become-pass --tags "p1"
```

# Part 2

```shell
ansible-playbook -i inventory.yaml playbook.yaml --ask-become-pass --tags "p2"
```

# Part 3

```shell
ansible-playbook -i inventory.yaml playbook.yaml --ask-become-pass --tags "p3"
```

## Argocd credentials

Username: `admin`

```shell
argocd admin initial-password -n argocd
```

# Bonus

```shell
ansible-playbook -i inventory.yaml playbook.yaml --ask-become-pass --tags "bonus"
```

## Get gitlab root password

Username: `root`

```shell
kubectl -n gitlab get secret gitlab-gitlab-initial-root-password -o jsonpath="{.data.password}" | base64 --decode | xargs
```
