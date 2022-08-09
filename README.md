# server
calcofi.io server setup for R Shiny apps, RStudio IDE, R Plumber API, temporary PostGIS database, pg_tileserv

## TODO

- [ ] update `pg_restore` instructions
- [ ] `rclone` install & configure for db bkups to Gdrive
- [ ] add groups and users, eg bebest & mfrants

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

## Virtual machine instance

### OLD: Google Cloud VM instance-1

* [VM instances – Compute Engine – calcofi – Google Cloud Platform](https://console.cloud.google.com/compute/instances?project=calcofi) as ben@ecoquants.com

- Hostname: instance1.calcofi.io
- Creation time: Apr 13, 2022
- Machine configuration
  - Machine type: e2-medium
- Networking
  - Public DNS PTR Record: calcofi.io.
- Storage
  - 20 GB SCSI

### NEW: Contabo instance

## `SSH`

### NEW: Contabo instance

#### SSH setup

On personal Mac:

```bash
# generate private and public keys
ssh-keygen -t rsa

# update host key
ssh-keygen -t rsa -R 154.53.57.44


ssh root@154.53.57.44

# show public key (for later copying into clipboard)
cat /root/.ssh/id_rsa.pub
```

On server:

After running `ssh root@ssh.calcofi.io` and entering password in Google Drive calcofi/private/[root@shell.calcofi.io_pass.txt](https://drive.google.com/file/d/1G1rPnDX0ijlYACHsdFA9srP77kHHHHTq/view?usp=sharing) (only Ben, Erin, Marina have access for now):

```bash
# add public key (from clipboard above) to end of this file
vi /root/.ssh/authorized_keys
```

Further reference:

* [How to Use SSH Keys with Your VPS? | Contabo Blog](https://contabo.com/blog/how-to-use-ssh-keys-with-your-vps/#linux)

#### SSH setup

Now login to server is as simple as:

```bash
ssh root@ssh.calcofi.io
```

## OLD: Google instance

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
# install docker, now with docker-compose-plugin
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Verify that Docker Engine is installed correctly by running the hello-world image.
sudo docker run hello-world
```

### OLD `docker-compose`

Newer `docker compose` installed above with:

```bash
sudo apt-get install docker-compose-plugin
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

### New `docker compose`

```bash
# Test the installation.
docker compose version
# Docker Compose version v2.6.0
```

```bash
docker run --name test-web -p 80:80 -d nginx

# confirm working
docker ps
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
docker compose up -d

# To rebuild this image you must use:
#   docker compose up --build
```

### Rebuild caddy 

eg after updating caddy/Caddyfile

```bash
docker stop caddy
docker rm caddy
docker compose up -d
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
gpasswd -a admin -g staff
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

<<<<<<< HEAD
## Database update to Marina's latest

```bash
dropdb -U admin gis
createdb -U admin gis
psql -U admin -d gis --command='CREATE ROLE mfrants WITH SUPERUSER';

cd /share/db_bkup
psql -U admin -d gis --echo-errors < calcofidb_2022-06-14.sql
```

and locally on Mac:

```bash
psql -d gis --command='CREATE ROLE mfrants WITH SUPERUSER'
psql -d gis --command='CREATE ROLE admin WITH SUPERUSER'
psql -d gis --echo-errors < calcofidb.sql
```


Ben restoring from pg_dump

```bash
dropdb gis

createdb gis

dump='/Users/bbest/My Drive/projects/calcofi/db_backup/gis_2022-06-20.dump'
echo $dump

pg_restore --verbose --create --dbname=gis $dump
```


## Database backups

### `rclone`: install and configure 

Installed `rclone` on host instance with:

```bash
apt install rclone
```

Configured with:

```bash
rclone config
```

to look like Google Drive calcofi/private/[rclone_config](https://docs.google.com/document/d/1jhKpTWiEvy8ZdaYyR1oucOuu0v8KXy8AFRsVXCQwGYw/edit) Google Doc.

See `rclone` documentation:

* [Install](https://rclone.org/install/)
* [Usage](https://rclone.org/docs/)
* [Google drive](https://rclone.org/drive/)
* [rclone config](https://rclone.org/commands/rclone_config/)
* [rclone config show](https://rclone.org/commands/rclone_config_show/)
* [rclone sync](https://rclone.org/commands/rclone_sync/)

### `cron`

```bash
# check crontab status

# run 
crontab -e

47 11 * * 1-5 /root/backup_db.sh
```

```
echo "test" > /share/db_backup/test_$(date +%Y-%m-%d).tmp
```

`vi /root/backup_db.sh`:

```bash
#!/bin/bash

# execute in postgis container the postgres dump of the gis database using a zipped output and date stamp in the filename
docker exec postgis pg_dump -Fc gis -U admin > /share/db_backup/gis_$(date +%Y-%m-%d).dump

# synchronize database backup folder with destination Google Drive folder
rclone sync /share/db_backup remote:db_backup

# remove all files (type f) modified longer than 30 days ago under /share/db_backup
find /share/db_backup -name "*.dump" -type f -mtime +30 -delete
```

```bash
chmod +x /root/backup_db.sh 
crontab -e
```

```
# m h  dom mon dow   command
0 0 * * 1-5 /root/backup_db.sh
```

## 🛣️ Roadmap

Marina and Renae are both UCSD staff and we are in the process of defining longer-term maintenance along with any training needed.

There are a four tiers of software ranging from most critical now (1) to ideal someday (4):

1. **Database API**\
The most flexible, secure way to provide the public access to the CalCOFI database is through an application programming interface (API), which can parse input arguments, execute the database query and format the results. You can visit the current prototype at [api.calcofi.io](https://api.calcofi.io/) (source code: [plumber.R](https://github.com/CalCOFI/api/blob/main/plumber.R)). We are currently using the R-based library Plumber ([rplumber.io](https://www.rplumber.io/)) to generate the API, and evaluating whether to migrate to a Python-based API generator like [Flask](https://flask.palletsprojects.com/) given Marina's comfort with Python over R. A Postgresql (version 13.5) database with PostGIS spatial extension (version 3.1) is already running on the calcofiweb server that Marina is administering. The hope here is that we can also host this API on the calcofiweb server, e.g. [api.calcofi.org](http://api.calcofi.org/) (versus the interim instance that I am temporarily hosting at [calcofi.io](http://calcofi.io/)). See [docker-compose.yml](https://github.com/CalCOFI/server/blob/e9d6cb41a298af99424e038adaa6fe26ae16d107/docker-compose.yml#L23-L38) for Docker install using the `rstudio` service.

1. **Spatial API**\
The makers of the PostGIS database have created very lightweight web services with the Go programming language to provide vector tiles with [pg_tileserv](https://github.com/CrunchyData/pg_tileserv) and GeoJSON with [pg_featureserv](https://github.com/CrunchyData/pg_featureserv). Try [tile.calcofi.io](https://tile.calcofi.io/) to see the default vector tile rendering of spatial layers. These services are especially powerful APIs for developing interactive online mapping applications and reports. See [docker-compose.yml](https://github.com/CalCOFI/server/blob/e9d6cb41a298af99424e038adaa6fe26ae16d107/docker-compose.yml#L57-L70) for Docker install of the `pg_tileserv` service.

1. **Apps**\
The [Shiny](https://shiny.rstudio.com/) web framework makes it very easy to create applications to visualize data using [htmlwidgets](http://www.htmlwidgets.org/) and responsive to user inputs and interactions. For instance, check out the app being developed by UCSB undergrads at [shiny.calcofi.io/capstone](https://shiny.calcofi.io/capstone/). The [RStudio Server](https://www.rstudio.com/products/rstudio/#rstudio-server) provides a fully mature IDE for creating and debugging these applications, including installing required R libraries. See [docker-compose.yml](https://github.com/CalCOFI/server/blob/e9d6cb41a298af99424e038adaa6fe26ae16d107/docker-compose.yml#L23-L38) for Docker install of the `rstudio` service.

1. **Portal**\
Eventually, we hope to showcase how CalCOFI datasets interoperate with all the relevant portals for maximizing discovery and use across the marine oceanographic and ecological communities. By installing server node software to slice tabular and gridded datasets with [ERDDAP](https://coastwatch.pfeg.noaa.gov/erddap/index.html) as well as [IPT](https://www.gbif.org/ipt) for biogeographic searches, we can also highlight full metadata and all endpoints for a given dataset with [CKAN](https://ckan.org/). Links to the [IOOS](https://ioos.noaa.gov/) curated Docker instances and recipes for spinning these services up have been added to [github.com/CalCOFI/server/issues](https://github.com/CalCOFI/server/issues).

## Rebuild with Marina 2022-07-06

### Creat Virtual Machine

Create Virtual Machine (VM) Instance on Google Cloud Console.

```
gcloud compute instances create shiny-server --project=ucsd-sio-calcofi --zone=us-central1-a --machine-type=e2-standard-2 --network-interface=network-tier=PREMIUM,subnet=default --maintenance-policy=MIGRATE --provisioning-model=STANDARD --service-account=199066946721-compute@developer.gserviceaccount.com --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append --tags=http-server,https-server --create-disk=auto-delete=yes,boot=yes,device-name=shiny-server,image=projects/debian-cloud/global/images/debian-11-bullseye-v20220621,mode=rw,size=40,type=projects/ucsd-sio-calcofi/zones/us-central1-a/diskTypes/pd-balanced --no-shielded-secure-boot --shielded-vtpm --shielded-integrity-monitoring --reservation-affinity=any
```

### Install docker & git

```bash
# check version of Linux
uname -a
# Linux shiny-server 5.10.0-15-cloud-amd64 #1 SMP Debian 5.10.120-1 (2022-06-09) x86_64 GNU/Linux

# install git
sudo apt update
sudo apt install git
git --version
# git version 2.30.2

# install docker per https://docs.docker.com/engine/install/debian/
sudo apt-get remove docker docker-engine docker.io containerd runc
sudo apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

### Launch docker instance

Setup folders:
- `/share` for sharing across docker containers and host machine
- `/share/github` for storing Github repositories
- `/share/github` for storing Github repositories

```bash
sudo mkdir /share
sudo mkdir /share/github

# permissions before 
ls -la
# drwxr-xr-x  2 root root 4096 Jul  6 16:37 github

# check groups
sudo groups bebest
# bebest adm dip video plugdev google-sudoers
sudo groups mfrants
# mfrants adm dip video plugdev

# change group writable
sudo chmod g+w /share/github
sudo chgrp adm /share/github

# permissions after
ls -la
# drwxrwxr-x  2 root adm  4096 Jul  6 16:37 github

# get repo with docker configs:
cd /share/github
git clone https://github.com/CalCOFI/server.git

cd /share/github/server

# set env variable for password
echo 'PASSWORD=*secrethere*' > .env

sudo docker compose up -d

sudo docker ps -a
```

## DNS

* [Reserving a static external IP address | Compute Engine Documentation | Google Cloud](https://cloud.google.com/compute/docs/ip-addresses/reserve-static-external-ip-address#:~:text=To%20reserve%20a%20static%20external,used%20with%20global%20load%20balancers.)

```
POST https://www.googleapis.com/compute/v1/projects/ucsd-sio-calcofi/regions/us-central1/addresses
{
  "description": "IP address for Shiny & Postgres server",
  "name": "shiny-server-ip",
  "networkTier": "PREMIUM",
  "region": "projects/ucsd-sio-calcofi/regions/us-central1"
}
```

- Permanent IP: 34.123.163.255

* [Google Domains - DNS](https://domains.google.com/registrar/calcofi.io/dns)


## Setup SSH access

* [Quickstart: Install the Google Cloud CLI | Google Cloud CLI Documentation](https://cloud.google.com/sdk/docs/install-sdk)

```bash
gcloud init
```

Ben's configuration

```
Settings from your current configuration [default] are:
compute:
  region: us-central1
  zone: us-central1-a
core:
  account: bebest@ucsd.edu
  disable_usage_reporting: 'False'
  project: ucsd-sio-calcofi
```

Add the keys per:

1. [Create SSH keys | Compute Engine Documentation | Google Cloud](https://cloud.google.com/compute/docs/connect/create-ssh-keys)
2. [Add SSH keys to VMs | Compute Engine Documentation | Google Cloud](https://cloud.google.com/compute/docs/connect/add-ssh-keys#os-login)

First, create the local key:

```bash
# ssh-keygen -t rsa -f ~/.ssh/KEY_FILENAME -C USERNAME -b 2048
ssh-keygen -t rsa -f ~/.ssh/calcofi.io_bebest_key -C bebest -b 2048
```


```bash
# gcloud compute os-login ssh-keys add \
#    --key-file=KEY_FILE_PATH \
#    --project=PROJECT \
#    --ttl=EXPIRE_TIME
gcloud compute os-login ssh-keys add \
    --key-file=/Users/bbest/.ssh/calcofi.io_bebest_key.pub \
    --project=ucsd-sio-calcofi \
    --ttl=365d
```

- [Step 1: Enable or disable OS Login](https://cloud.google.com/compute/docs/oslogin/set-up-oslogin#enable_oslogin)

```
ssh -i /Users/bbest/.ssh/calcofi.io_bebest_key bebest@ssh.calcofi.io
```

...

## 2022-07-12 BB

### Restore database from bkup dump

After spinning up a fresh postgis instance from the docker-compose.yml (`sudo docker compose up -d`), we restore from the latest `gis_YYYY-MM-DD.dump` in [db_backup - Google Drive](https://drive.google.com/drive/u/0/folders/12Z2J6S9xD1E0BO15O7yqyQBRm2M3LgW5).

From [rstudio.calcofi.io](https://rstudio.calcofi.io), in Files pane, uploaded the following db dump from [db_backup - Google Drive](https://drive.google.com/drive/u/0/folders/12Z2J6S9xD1E0BO15O7yqyQBRm2M3LgW5):

```
/share/data/gis_2022-07-12.dump
```

From [VM instances – Compute Engine – ucsd-sio-calcofi – Google Cloud console](https://console.cloud.google.com/compute/instances?project=ucsd-sio-calcofi), SSH console:

Then restored 
Ben restoring from pg_dump

```bash
# execute bash with interactive terminal on host postgis
# this will give access to psql, createdb and all other postgres-related commands
sudo docker exec -it postgis bash

# recreate fresh database
dropdb -U admin gis
createdb -U admin gis

# create roles for mfrants and root
psql -U admin -d gis --command='CREATE ROLE mfrants WITH SUPERUSER LOGIN';
psql -U admin -d gis --command='ALTER ROLE mfrants WITH LOGIN;'
psql -U admin -d gis --command='CREATE ROLE root WITH SUPERUSER LOGIN';
psql -U admin -d gis --command='ALTER ROLE root WITH LOGIN;'


# restore from dump
pg_restore --verbose --create --dbname=gis '/share/data/gis_2022-07-12.dump'
```

### add db password, git repos

From [rstudio.calcofi.io](https://rstudio.calcofi.io), in Terminal pane as user admin...

Paste contents of [admin@db.calcofi.io_pass.txt](https://drive.google.com/file/d/1G-qphDLhWuBGqJyrmEHwGrKodM8hdEz4/view?usp=sharing) into `/share/.calcofi_db_pass.txt`

```bash
# write password to file
echo 'secret' > /share/.calcofi_db_pass.txt

# symbolic link for user shiny so apps find passwords
sudo ln -s /share/.calcofi_db_pass.txt /home/shiny/.calcofi_db_pass.txt
```

```bash
# change to home directory, ie /home/admin
cd ~

# symbolic link db password from home drive
ln -s /share/.calcofi_db_pass.txt ~/.calcofi_db_pass.txt

# create symbolic links from home dir for easier navigation
ln -s /share                share
ln -s /share/github         github
ln -s /srv/shiny-server     shiny-apps
ln -s /var/log/shiny-server shiny-logs

# get Github repos
cd /share/github
sudo chown -R admin /share
git clone https://github.com/CalCOFI/api.git
git clone https://github.com/CalCOFI/apps.git
git clone https://github.com/CalCOFI/scripts.git
git clone https://github.com/CalCOFI/capstone.git
git clone https://github.com/CalCOFI/calcofi4r.git
```

From [rstudio.calcofi.io](https://rstudio.calcofi.io)...

Open `/share/github/apps/oceano/libs/db.R` and Source all followed by `dbListTables(con)` into Console to test database connection.

### get api.calcofi.io up

Get [api.calcofi.io](https://api.calcofi.io) up and running. From [rstudio.calcofi.io](https://rstudio.calcofi.io), File -> Open Project... `/share/github/api/api.Rproj`. Open `README.md`, and install `pm2` per instructions.

### setup git

```bash
git config --global user.email "ben@ecoquants.com"
git config --global user.name "Ben Best"
```

### get oceano app up

Open `/share/github/apps/oceano/global.R` and run lines there similar to the following to install custom calcofi4r R package and any other missing R packages:

```r
devtools::install_local("/share/github/calcofi4r")

librarian::shelf(
  calcofi/calcofi4r,
  digest, dygraphs, glue, geojsonio, here, httr2, leaflet, leaflet.extras, 
  raster, readr, sf, shiny)
```

With `/share/github/apps/oceano/global.R` open in the Source pane, click the **Run App** button to test app.

### turn on app links

```bash
# turn on apps listed at https://calcofi.io
cd /srv/shiny-server
sudo ln -s /share/github/apps/oceano oceano
sudo ln -s /share/github/apps/dashboard dashboard
sudo ln -s /share/github/capstone/scripts/shiny capstone
```

### turn on tile.calcofi.io

Now that database is populated, SSH into host and rerun to get tile container started.

```bash
# docker (re)launch as daemon
docker compose up -d
```
