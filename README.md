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

## Argocd credentials

Username: `admin`

```shell
argocd admin initial-password -n argocd
```

# Bonus

```shell
sudo su
bash bonus/scripts/setup.sh
```

## Get gitlab root password

Username: `root`

```shell
kubectl -n gitlab get secret gitlab-gitlab-initial-root-password -o jsonpath="{.data.password}" | base64 --decode | xargs
```

## Setup gitlab repository
* Create a new project
* Create a user access token
* Allow force push on the main branch

```shell
git config --global http.sslVerify false
git remote add gitlab https://gitlab.example.com/root/<repo_name>.git
git push -f gitlab main
```
