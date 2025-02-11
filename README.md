# Setup VM

## Configure your ssh connection
    
* In your `~/.ssh/config` file, add the following configuration:
```text
Host do
HostName <host_domain or host_ip>
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
pip install ansible-core passlib
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
ansible-playbook -i inventory.yaml playbook.yaml --tags "p1"
```

# Part 2

```shell
ansible-playbook -i inventory.yaml playbook.yaml --tags "p2"
```

# Part 3

```shell
ansible-playbook -i inventory.yaml playbook.yaml --tags "p3"
```

## Argocd credentials

Username: `admin`

```shell
argocd admin initial-password -n argocd
```

# Bonus

```shell
ansible-playbook -i inventory.yaml playbook.yaml --tags "bonus"
```

## Get gitlab root password

Username: `root`

```shell
kubectl -n gitlab get secret gitlab-gitlab-initial-root-password -o jsonpath="{.data.password}" | base64 --decode | xargs
```
