# Setup VM

## Download xubuntu

https://xubuntu.fr/ 

* Store in `~/sgoinfre`
* VM folder should be `~/goinfre/vbox`
* Username: `triou` Password: `changeme`
* Check GuestAdditions checkbox
* Set 8 CPUs and 8192MB of RAM
* Set 25 gb of storage
* Install Xubuntu minimal flavor

* In vm settings, enable System>Processor>Nested VT-x/AMD-V and General > Advanced > Shared Clipboard > Bidirectional

## Install base dependencies

```shell
sudo apt install -y git vim firefox
```

# P1 & P2

* Install vagrant and virtualbox with `sudo bash p1/scripts/setup.sh`

To run `vagrant up`
To halt `vagrant halt`
To destroy `vagrant destroy triouS triouSW`

* Cleanup with `sudo bash p2/scripts/cleanup.sh`

# P3

```shell
sudo su
bash p3/scripts/setup.sh
```

## Install docker

## Configure your ssh connection

* Generate a new ssh key pair in `~/.ssh`
* Create ssh config file `~/.ssh/docker_config` and add the following configuration:
```text
Host *
  IdentityFile ~/.ssh/<private_key>
```
* Add your public key to the VM (`/root/.ssh/authorized_keys`)

## Run setup

```shell
# FIXME: use Makefile and add tag option
docker build -t ansible --platform linux/amd64 --build-arg vm_ip_address="<vm_ip_address>" --build-arg ansible_tag="<tag>" . 
docker run -it --rm -v $(dirname $SSH_AUTH_SOCK):/ssh-agent -v ~/.ssh:/root/.ssh -v ~/.ssh/docker_config:/root/.ssh/config -e SSH_AUTH_SOCK=/ssh-agent/Listeners ansible
```

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
