# server
calcofi.io server setup for R Shiny apps, RStudio IDE, R Plumber API, temporary PostGIS database, pg_tileserv


## Domain: calcofi.io

* [Google Domains - DNS](https://domains.google.com/registrar/calcofi.io/dns) as bdbest@gmail.com; authorized ben@ecoquants.com

### Setup SubDomains

Type: A; Data: 34.123.152.210; Name:

- 
- api
- tile
- rstudio
- shiny

Type: CNAME, Data: calcofi.io., Name: www.calcofi.io

TODO:
- erddap
- ckan
- geo
- ipt
- www-dev
- drupal

## Machine: Google Cloud VM instance-1

* [VM instances – Compute Engine – calcofi – Google Cloud Platform](https://console.cloud.google.com/compute/instances?project=calcofi) as ben@ecoquants.com

- Hostname: instance1.calcofi.io
- Creation time: Apr 13, 2022
- Machine configuration
  - Machine type: e2-medium
- Networking
  - Public DNS PTR Record: calcofi.io.
- Storage
  - 20 GB SCSI

## `SSH`

### browser; OR

* [VM instances – Compute Engine – calcofi – Google Cloud Platform](https://console.cloud.google.com/compute/instances?project=calcofi) as ben@ecoquants.com

* `SSH` buttton

### Terminal

* [Quickstart: Install the Google Cloud CLI  |  Google Cloud CLI Documentation](https://cloud.google.com/sdk/docs/install-sdk)

* [gcloud compute  |  Compute Engine Documentation  |  Google Cloud](https://cloud.google.com/compute/docs/gcloud-compute)


In Terminal on Mac:

```bash
gcloud auth login
gcloud config set project calcofi
gcloud compute ssh instance-1
```

Connected to instance-1:

```
bbest@instance1:~$ pwd
/home/bbest
```

Or now directly with:

```bash
ssh -i ~/.ssh/google_compute_engine bbest@instance1.calcofi.io
```


### Cyberduck

* [Transferring files to Linux VMs  |  Compute Engine Documentation  |  Google Cloud](https://cloud.google.com/compute/docs/instances/transfer-files#scp)
* [Firewall – VPC network – calcofi – Google Cloud Platform](https://console.cloud.google.com/networking/firewalls/list?_ga=2.206034068.649621881.1649877354-1246367375.1647519755&project=calcofi)

Created firewall `allow-sftp` on port 22.

<img width="492" alt="image" src="https://user-images.githubusercontent.com/2837257/167685879-d74b5165-da3a-4642-9419-b7ba53123b9e.png">

## `/share`

```bash
sudo mkdir /share
sudo chmod -R 775 /share
ln -s /share ~/share
```

### `/share/github`

```bash
cd /share
sudo mkdir github
sudo chown -R bbest github 
cd github
git clone https://github.com/CalCOFI/server.git 
```

## Test Docker

* [Creating and configuring instances  |  Container-Optimized OS  |  Google Cloud](https://cloud.google.com/container-optimized-os/docs/how-to/create-configure-instance)
* [Install Docker Engine on Ubuntu | Docker Documentation](https://docs.docker.com/engine/install/ubuntu/)

```bash
# Update the apt package index and install packages to allow apt to use a repository over HTTPS
sudo apt-get update

sudo apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker’s official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Use the following command to set up the stable repository

 echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update the apt package index, and install the latest version of Docker Engine and containerd, or go to the next step to install a specific versio
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io

# Verify that Docker Engine is installed correctly by running the hello-world image.
sudo docker run hello-world
```

* [Install Docker Compose | Docker Documentation](https://docs.docker.com/compose/install/)

```bash
# Run this command to download the current stable release of Docker Compose:
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# Apply executable permissions to the binary:
sudo chmod +x /usr/local/bin/docker-compose

# Test the installation.
docker-compose --version
# docker-compose version 1.29.2, build 5becea4c
```

```bash
sudo docker run --name test-web -p 80:80 -d nginx

# confirm working
sudo docker ps
curl http://localhost
```

Test: http://instance1.calcofi.io

```bash
sudo docker stop test-web
# sudo docker rm test-web
sudo docker ps -a
```

## Docker with Caddy

* [caddy + rstudio | Rocker Project](https://www.rocker-project.org/use/networking/)

```bash
cd /share/github
# get latest docker-compose files
git clone https://github.com/CalCOFI/server.git
cd server

# set environment variables: echo echo
echo 'PASSWORD=C*******!' > .env

# docker launch as daemon
sudo docker-compose up -d

# To rebuild this image you must use:
#   docker-compose up --build
```

### Rebuild caddy 

eg after updating caddy/Caddyfile

```bash
docker stop caddy
docker rm caddy
docker-compose up -d
docker logs caddy
```

## Access db remotely


* [Firewall – VPC network – calcofi – Google Cloud Platform](https://console.cloud.google.com/networking/firewalls/list?_ga=2.206034068.649621881.1649877354-1246367375.1647519755&project=calcofi)

Created firewall `allow-postgresql` on port 5432.


## Add user(s)

### host

On host machine (see SSH above).

```bash
sudo su 
echo 'umask 002' >> /etc/profile

# user=bbest
# user=cdobbelaere
user=superjai
pass=S3cretpass!

# userdel $user; groupdel $user

# add user inside rstudio docker container from host
useradd -m -p $(openssl passwd -crypt $pass) $user

# change password for existing user
# echo usermod -p "$pass" $user
# usermod -p $(openssl passwd -crypt $pass) $user

# setup (every user) primary group to staff
usermod -aG staff $user
usermod -aG sudo $user
usermod -g staff $user
groups $user
# confirm groups of user and record uid for next step on rstudio instance
id $user
```

### rstudio

In Terminal as admin logged into [rstudio.calcofi.io](https://rstudio.calcofi.io).

```bash
# setup (once) staff to be shared by admin, and default permissions 775
sudo su 
gpasswd -ag admin staff
usermod -aG staff admin
usermod -g staff admin # set default group to staff for user admin
echo 'umask 002' >> /etc/profile

# override RStudio's default group read only with group read & write
printf "Sys.umask('2')\n" >> /usr/local/lib/R/etc/Rprofile.site
# vs quick fix in Terminal of rstudio.marineenergy.app: sudo chmod -R g+w *

# Add shiny to staff so has permission to install libraries into `/usr/local/lib/R/site-library` and write files
usermod -aG staff shiny

# set primary group to staff
usermod -g staff shiny
#confirm primary group set to staff
id shiny
# uid=998(shiny) gid=50(staff) groups=50(staff)

# enter user name and id matched from host
# user=bbest; uid=1001
# user=cdobbelaere; uid=1003
user=superjai; uid=1004
pass=S3cretpass!

# usermod -g $user $user
# userdel $user; groupdel $user

# add user inside rstudio docker container from host
useradd -m -p $(openssl passwd -crypt $pass) -u $uid $user

# change password for existing user
# echo usermod -p "$pass" $user
# usermod -p $(openssl passwd -crypt $pass) $user

# setup (every user) primary group to staff
usermod -aG staff $user
usermod -aG sudo $user
usermod -aG shiny $user
usermod -g staff $user
groups $user
# confirm groups of user
id $user

# setup symbolic links in home dir
ln -s /share                /home/$user/share
ln -s /share/data           /home/$user/data
ln -s /share/github         /home/$user/github
ln -s /srv/shinyapps        /home/$user/shiny-apps
ln -s /var/log/shiny-server /home/$user/shiny-logs
```


