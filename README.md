# server
calcofi.io server setup for R Shiny apps, RStudio IDE, R Plumber API, temporary PostGIS database, pg_tileserv

## TODO

- [ ] update `pg_restore` instructions

```bash
# from host server log into postgis container
docker exec -it postgis bash

# switch to user postgres
su - postgres

# drop database
dropdb gis
createdb -U postgres gis

# change dir to folder of backups
cd /share/db_backup; ls

# restore given date; [c]lean and [C]reate
dropdb -U admin -f gis
createdb -U admin gis

PASSWORD=$(cat /share/.calcofi_db_pass.txt)

createuser -U admin -s -i -d -r -l -w root
psql -U admin -d postgres -c "ALTER ROLE root WITH PASSWORD '$PASSWORD';"

createuser -U admin -s -i -d -r -l -w mfrants
psql -U admin -d postgres -c "ALTER ROLE root WITH PASSWORD '$PASSWORD';"

PASSWORD=$(cat /share/.calcofi_db_pass.txt)

vi .env
PASSWORD=s@Cr3t!
ROPASS=s@Cr3t!2

pg_restore -U admin -d gis gis_2024-10-18.dump
```

```sql
CREATE USER ro_user WITH PASSWORD 'Calcof1';
GRANT CONNECT ON DATABASE gis TO ro_user;
GRANT USAGE ON SCHEMA public TO ro_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO ro_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO ro_user;
ALTER ROLE ro_user WITH PASSWORD 'new_password';

SELECT version();
-- "PostgreSQL 17.1 (Debian 17.1-1.pgdg110+1) on x86_64-pc-linux-gnu, compiled by gcc (Debian 10.2.1-6) 10.2.1 20210110, 64-bit"

SELECT PostGIS_Version();
-- "3.5 USE_GEOS=1 USE_PROJ=1 USE_STATS=1"
```

```bash
sudo crontab -u root -l
# 47 11 * * 1-5 /root/backup_db.sh

cat /root/backup_db.sh 
```

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
# config on host at ~/.config/rclone/rclone.conf
#                  /share/rclone/rclone.conf
# data on host at ~/data
#                 /share/pg_backups

# login as root
sudo su -

# add a remote interactively
docker run --rm -it \
    --volume /share/rclone:/config/rclone \
    --user $(id -u):$(id -g) \
    rclone/rclone \
    config
```    

## rclone to backup database dumps

https://rclone.org/install/#docker

https://rclone.org/drive/

https://rclone.org/remote_setup/

Options:
- type: drive
- scope: drive
- service_account_file: /config/rclone/calcofi-ee9f51172ce7.json
- team_drive: 
- root_folder_id: 13pWB5x59WSBR0mr9jJjkx7rri9hlUsMv


```bash
# make sure the config is ok by listing the remotes
sudo su -
docker run --rm \
    --volume /share/rclone:/config/rclone \
    --volume /share:/share \
    --user $(id -u):$(id -g) \
    rclone/rclone \
    sync --dry-run /share/pg_backups remote:db_backups
    
rclone sync --dry-run /share/pg_backups remote:db_backups

git pull
docker stop pg_backups rclone
docker compose up -d --build pg_backups 
docker exec pg_backups env
docker exec pg_backups date
docker exec pg_backups /backup.sh
```

```
Creating dump of gis database from postgis...
Replacing daily backup /backups/daily/gis-20241119.sql.gz file this last backup...
'/backups/daily/gis-20241119.sql.gz' => '/backups/last/gis-20241119-164503.sql.gz'
Replacing weekly backup /backups/weekly/gis-202447.sql.gz file this last backup...
'/backups/weekly/gis-202447.sql.gz' => '/backups/last/gis-20241119-164503.sql.gz'
Replacing monthly backup /backups/monthly/gis-202411.sql.gz file this last backup...
'/backups/monthly/gis-202411.sql.gz' => '/backups/last/gis-20241119-164503.sql.gz'
Point last backup file to this last backup...
'/backups/last/gis-latest.sql.gz' -> 'gis-20241119-164503.sql.gz'
Point latest daily backup to this last backup...
'/backups/daily/gis-latest.sql.gz' -> 'gis-20241119.sql.gz'
Point latest weekly backup to this last backup...
'/backups/weekly/gis-latest.sql.gz' -> 'gis-202447.sql.gz'
Point latest monthly backup to this last backup...
'/backups/monthly/gis-latest.sql.gz' -> 'gis-202411.sql.gz'
Cleaning older files for gis database from postgis...
SQL backup created successfully
```

```bash
ls -latr /share/pg_backups

docker compose up -d --no-deps --build rclone

docker exec -it rclone sh

docker exec -it rclone date
docker exec -it rclone cat /etc/crontabs/root
cat /share/logs/rclone
docker exec -it rclone sh
grep CRON /var/log/syslog
docker exec -it rclone pidof cron
docker exec -it rclone "pstree -apl `pidof cron`"
docker exec -it rclone /backup.sh >> /share/logs/rclone 2>&1

cat /share/logs/rclone
```

```
Use 'docker scan' to run Snyk tests against images to find vulnerabilities and learn how to fix them

    sync -i /share/pg_backups/ remote:db_backups/
    
    
    lsd remote:
    ls remote:projects/calcofi/db_backup
    lsd remote:projects/calcofi
    
    rclone lsd remote:projects/calcofi
    
    
    rclone sync --interactive SOURCE remote:DESTINATION
```
   
```bash
# perform mount inside Docker container, expose result to host
mkdir -p /share/google_drive
# --rm \

docker run -it \
    --volume /share/rclone:/config/rclone \
    --volume /share:/share \
    --volume /share:/data \
    --user $(id -u):$(id -g) \
    rclone/rclone \
    lsd remote:projects/calco
    sh
    modprobe fuse
    mount remote:projects/calcofi /data/google_drive &
ls ~/data/mount
kill %1    
```

- [ ] `rclone` install & configure for db bkups to Gdrive

- [db\_backup - Google Drive](https://drive.google.com/drive/u/0/folders/12Z2J6S9xD1E0BO15O7yqyQBRm2M3LgW5)

- [ ] add groups and users, eg bebest & mfrants

### rclone fix

```bash
docker logs rclone
```

```
...
crond: USER root pid 674 cmd /backup.sh >> /share/logs/rclone 2>&1
```

```bash
docker exec rclone cat /share/logs/rclone
```


```
2025/01/22 16:40:02 NOTICE: last/gis-latest.sql.gz: Can't follow symlink without -L/--copy-links
2025/01/22 16:40:02 NOTICE: weekly/gis-latest.sql.gz: Can't follow symlink without -L/--copy-links
2025/01/22 16:40:02 NOTICE: daily/gis-latest.sql.gz: Can't follow symlink without -L/--copy-links
2025/01/22 16:40:02 NOTICE: monthly/gis-latest.sql.gz: Can't follow symlink without -L/--copy-links
2025/01/22 16:40:02 INFO  : There was nothing to transfer
2025/01/22 16:40:02 INFO  : 
Transferred:   	          0 B / 0 B, -, 0 B/s, ETA -
Checks:                 8 / 8, 100%
Elapsed time:         1.4s
```

```bash
docker logs pg_backups
```

```
2024/11/19 16:37:22 Running version: v0.0.11
2024/11/19 16:37:22 new cron: '39 16 0 * * *'
2024/11/19 16:37:22 Opening port 8000 for health checking
```


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

### Google Cloud VM `shiny-server`

* [VM instances – Compute Engine – calcofi – Google Cloud Platform](https://console.cloud.google.com/compute/instances?project=calcofi) as ben@ecoquants.com

- Name: shiny-server
- Creation time: Jul 6, 2022
- Zone: us-central1-a
- Machine configuration
  - Machine type: e2-medium
- Networking
  - Public DNS PTR Record: calcofi.io.
- Storage
  - 20 GB SCSI

## Google instance

### browser; OR

* [VM instances – Compute Engine – calcofi – Google Cloud Platform](https://console.cloud.google.com/compute/instances?project=ucsd-sio-calcofi&authuser=3) as bebest@ucsd.edu

* `SSH` buttton

### Terminal

* [Quickstart: Install the Google Cloud CLI  |  Google Cloud CLI Documentation](https://cloud.google.com/sdk/docs/install-sdk)

* [gcloud compute  |  Compute Engine Documentation  |  Google Cloud](https://cloud.google.com/compute/docs/gcloud-compute)


In Terminal on Mac:

```bash
gcloud auth login # choose bebest@ucsd.edu
gcloud config set project ucsd-sio-calcofi
gcloud compute ssh shiny-server
```

Connected to shiny-server:

```
bebest_ucsd_edu@shiny-server:~$ pwd
/home/bebest_ucsd_edu
```

Or now directly with:

```bash
ssh -i ~/.ssh/google_compute_engine bebest_ucsd_edu@ssh.calcofi.io
```

## Setup permissions on server and rstudio container

```bash
# setup (once) staff to be shared by admin, and default permissions 775
docker exec rstudio gpasswd -a admin staff
docker exec rstudio sh -c "echo 'umask 002' >> /etc/profile"

# override RStudio's default group read only with group read & write
docker exec rstudio sh -c "echo 'Sys.umask('2')\n' >> /usr/local/lib/R/etc/Rprofile.site"
# vs quick fix in Terminal of rstudio.calcofi.io: sudo chmod -R g+w *

# log into rstudio container
docker exec -it rstudio bash

# Add shiny to staff so has permission to install libraries into `/usr/local/lib/R/site-library` and write files
usermod -aG staff shiny

# set primary group to staff
usermod -g staff shiny
#confirm primary group set to staff
id shiny
# uid=998(shiny) gid=50(staff) groups=50(staff)

# setup permissions for group writable
chmod g+w -R /share/github
chgrp -R staff /share/github
```

## Add user

```bash
# set user and pass
USER=edweber
USER=mfrants
USER=bebest
PASS=secretp@ssHere

# check
echo "USER: $USER; PASS: $PASS"

# delete user
# sudo userdel $USER; groupdel $USER

# add user to host
exit
sudo useradd -m -p $(openssl passwd -crypt $PASS) $USER
sudo usermod -aG sudo $USER

# add user to docker group
sudo usermod -aG docker $USER

# log into rstudio container
docker exec -it rstudio bash

# set user and pass
USER=edweber
USER=mfrants
USER=bebest
PASS=secretp@ssHere

# check
echo "USER: $USER; PASS: $PASS"

# add user inside rstudio docker container from host
useradd -m -p $(openssl passwd -crypt $PASS) $USER
# echo usermod -p "$pass" $USER
# usermod -p $(openssl passwd -crypt $pass) $USER

# setup (every user) primary group to staff
usermod -aG staff $USER
usermod -aG sudo $USER
usermod -aG shiny $USER
usermod -g staff $USER
groups $USER

# setup symbolic links in home dir
ln -s /share                /home/$USER/share
ln -s /share/data           /home/$USER/data
ln -s /share/github         /home/$USER/github
ln -s /srv/shiny-server     /home/$USER/shiny-apps
ln -s /var/log/shiny-server /home/$USER/shiny-logs

# copy over database password 
cp /home/admin/.calcofi_db_pass.txt /home/$USER/.calcofi_db_pass.txt

# check in container
docker exec -it rstudio-shiny bash
cat /etc/passwd
exit
```

### SSH Tunnel connection to postgis DB

* [Secure TCP/IP Connections with SSH Tunnels | PostgreSQL docs](https://www.postgresql.org/docs/current/ssh-tunnels.html)

In order for to connect to the Postgres database as if it were on your local machine by tunneling, you will need:



```bash
ssh \
  -i ~/.ssh/google_compute_engine \
  -L 5432:localhost:5432 bebest_ucsd_edu@ssh.calcofi.io
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

## setup PostgREST

- create read only user:

```sql
CREATE USER ro_user WITH PASSWORD 'your_password';
GRANT CONNECT ON DATABASE gis TO ro_user;
GRANT USAGE ON SCHEMA public TO ro_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO ro_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO ro_user;
ALTER ROLE ro_user WITH PASSWORD 'new_password';
```

## Added disk `ssd` [@bebest 2024-11-15]

Since ran out of room on server, added second 100 GB disk called `ssd` to `shiny-server` in the Google Cloud Console.

- [Create a new Persistent Disk volume | Compute Engine Documentation | Google Cloud](https://cloud.google.com/compute/docs/disks/add-persistent-disk)
- [Format and mount a non-boot disk on a Linux VM | Compute Engine Documentation | Google Cloud](https://cloud.google.com/compute/docs/disks/format-mount-disk-linux)


```bash
# show device names
ls -l /dev/disk/by-id/google-*
```

```
lrwxrwxrwx 1 root root  9 Sep  1 06:35 /dev/disk/by-id/google-shiny-server -> ../../sda
lrwxrwxrwx 1 root root 10 Sep  1 06:35 /dev/disk/by-id/google-shiny-server-part1 -> ../../sda1
lrwxrwxrwx 1 root root 11 Sep  1 06:35 /dev/disk/by-id/google-shiny-server-part14 -> ../../sda14
lrwxrwxrwx 1 root root 11 Sep  1 06:35 /dev/disk/by-id/google-shiny-server-part15 -> ../../sda15
lrwxrwxrwx 1 root root  9 Nov 15 20:12 /dev/disk/by-id/google-ssd -> ../../sdb
```

```bash
# format new disk
sudo mkfs.ext4 -m 0 -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/disk/by-id/google-ssd

# create dir as mount point
sudo mkdir -p /ssd

# mount disk to dir
sudo mount -o discard,defaults /dev/disk/by-id/google-ssd /ssd

# configure permissions
sudo chmod a+w /ssd


# Configure automatic mounting on VM restart ----

# backup fstab
sudo cp /etc/fstab /etc/fstab.backup

# list the UUID for the disk
sudo blkid /dev/disk/by-id/google-ssd
```

```
/dev/disk/by-id/google-ssd: UUID="60d94214-11c6-4d05-9c26-41e81a81e2fa" BLOCK_SIZE="4096" TYPE="ext4"
```

```bash
# add to fstab
echo 'UUID=60d94214-11c6-4d05-9c26-41e81a81e2fa /ssd ext4 discard,defaults,nofail 0 2' | sudo tee -a /etc/fstab
cat /etc/fstab
```

```
# /etc/fstab: static file system information
UUID=148ccc9b-f935-4a9a-8353-1a3f5f9c9d0f / ext4 rw,discard,errors=remount-ro,x-systemd.growfs 0 1
UUID=D516-7559 /boot/efi vfat defaults 0 0
UUID=60d94214-11c6-4d05-9c26-41e81a81e2fa /ssd ext4 discard,defaults,nofail 0 2
```

### Move `/share` and `/var/lib/docker` to `/ssd/docker`

Extra disk added because we ran out of disk trying to upgrade docker images per:

- [How to update existing images with docker-compose? - Stack Overflow](https://stackoverflow.com/questions/49316462/how-to-update-existing-images-with-docker-compose)

```bash
# before: disk free, human readable units
df -h
```

```
Filesystem      Size  Used Avail Use% Mounted on
udev            3.9G     0  3.9G   0% /dev
tmpfs           796M  1.1M  795M   1% /run
/dev/sda1        40G   38G     0 100% /
tmpfs           3.9G     0  3.9G   0% /dev/shm
tmpfs           5.0M     0  5.0M   0% /run/lock
/dev/sda15      124M   11M  114M   9% /boot/efi
tmpfs           796M     0  796M   0% /run/user/1320671979
```

Note: `/` has `0` available space.

So let's use symbolic link in new location after moving contents. Stop and start with 
docker compose. Note that per our [docker-compose.yml](https://github.com/CalCOFI/server/blob/b810a07ce3a6ca4428f7b522f84681341f6d6e55/docker-compose.yml#L48), the database is in the
Docker volume `postgis_data`.

```bash
# stop docker compose
docker compose down

# move contents
sudo mv /var/lib/docker /ssd/docker
sudo mv /share /ssd/share

# create symbolic links
sudo ln -s /ssd/docker /var/lib/docker
sudo ln -s /ssd/share /share
```

```bash
# after: disk free, human readable units
df -h
```

```
Filesystem      Size  Used Avail Use% Mounted on
udev            3.9G     0  3.9G   0% /dev
tmpfs           796M  468K  796M   1% /run
/dev/sda1        40G  8.8G   29G  24% /
tmpfs           3.9G     0  3.9G   0% /dev/shm
tmpfs           5.0M     0  5.0M   0% /run/lock
/dev/sda15      124M   11M  114M   9% /boot/efi
tmpfs           796M     0  796M   0% /run/user/1320671979
/dev/sdb         98G   27G   72G  28% /ssd
```

Note: `/` now has `29G` available space and the new disk mounted at `/ssd` has `72G` available.

If we were only restarting docker, we'd use:

```bash
# start docker compose (if only restarting)
docker compose up -d
```

But we're not just restarting, we're upgrading images, per:

- [How to update existing images with docker-compose? - Stack Overflow](https://stackoverflow.com/questions/49316462/how-to-update-existing-images-with-docker-compose)

So instead, running:

```bash
# change dir to local git clone of https://github.com/CalCOFI/server
cd /share/github/server

# confirm .env file present (not on Github) with variables set for PASSWORD and ROPASS
cat .env

# pull latest images
docker compose pull
docker compose up --force-recreate --build -d
docker image prune -f
```

```bash
