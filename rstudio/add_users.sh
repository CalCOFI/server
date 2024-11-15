#!/bin/bash

# Create users from CSV file
while IFS=, read -r username uid || [ -n "$username" ]; do
    # Skip header row
    if [ "$username" != "user" ]; then
        # Remove any carriage return from uid
        uid=$(echo "$uid" | tr -d '\r')
        
        # Create user with specific UID and set password
        useradd -s /bin/bash -m -u "$uid" "$username"
        
        # Set password from environment variable
        echo "$username:$PASSWORD" | chpasswd
        
        # Add user to groups: staff, sudo, shiny
        usermod -aG staff "$username"
        usermod -aG sudo "$username"
        usermod -aG shiny "$username"
        
        # Make default group: staff
        usermod -g staff "$username"
        
        # RStudio settings
        mkdir -p "/home/${username}/.config/rstudio/"
        cat <<EOF >"/home/${username}/.config/rstudio/rstudio-prefs.json"
{
    "save_workspace": "never",
    "always_save_history": false,
    "reuse_sessions_for_project_links": true,
    "posix_terminal_shell": "bash",
    "editor_theme": "Tomorrow Night"
}
EOF
        chown -R "${username}:${username}" "/home/${username}"
   
        # configure git not to request password each time
        git config --system credential.helper 'cache --timeout=3600'
        git config --system push.default simple
        
        # setup symbolic links in home dir
        ln -s /share                /home/$username/share
        ln -s /share/data           /home/$username/data
        ln -s /share/github         /home/$username/github
        ln -s /srv/shiny-server     /home/$username/shiny-apps
        ln -s /var/log/shiny-server /home/$username/shiny-logs

        echo "Added user $username with UID $uid"
    fi
done < /tmp/users.csv