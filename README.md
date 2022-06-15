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
