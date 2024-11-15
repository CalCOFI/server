# setup staff to be shared by admin
gpasswd -a admin staff
# setup default permissions 775
sh -c "echo 'umask 002' >> /etc/profile"
# override RStudio's default group read only with group read & write
sh -c "echo 'Sys.umask('2')\n' >> /usr/local/lib/R/etc/Rprofile.site"
# Add shiny to staff so has permission to install libraries into `/usr/local/lib/R/site-library` and write files
usermod -aG staff shiny
# set primary group to staff
usermod -g staff shiny
# setup permissions for group writable
chmod g+w -R /share/github
chgrp -R staff /share/github
