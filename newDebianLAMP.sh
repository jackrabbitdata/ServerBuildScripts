#! /bin/bash
# Set up a LAMP stack on a new Debian 13 (Trixie) server

# Use curl to transfer this file from Github
# curl -O https://raw.githubusercontent.com/jackrabbitdata/ServerBuildScripts/master/newDebianLAMP.sh

# Run chmod 744 newDebianLAMP.sh
# Run it by typing ./newDebianLAMP.sh

echo -n "Set the hostname? (y/n)? "
read answer
if [ "$answer" != "${answer#[Yy]}" ] ;then
    # Set hostname
    echo "Please enter server name. Ex: example.com"
    read -p 'Server name: ' srv_domain
    sudo hostnamectl set-hostname $srv_domain
    hostnamectl
else
    echo Continuing...
fi

# Set time zone
# Check with timedatectl
sudo timedatectl set-timezone America/Chicago
timedatectl

# Install swap file if needed
echo -n "On instances with less than 1G of memory, a swap file will likely be needed to run composer. Add a 1GB swap file? (y/n)? "
read answer
if [ "$answer" != "${answer#[Yy]}" ] ;then
    sudo /bin/dd if=/dev/zero of=/var/swap.1 bs=1M count=1024;
    sudo /sbin/mkswap /var/swap.1;
    sudo chmod 600 /var/swap.1;
    sudo /sbin/swapon /var/swap.1;
    sudo sed -i '$a /var/swap.1 swap swap defaults 0 0' /etc/fstab
else
    echo Continuing...
fi

# Remove any existing and add my .bashrc
rm .bashrc
curl -O https://raw.githubusercontent.com/jackrabbitdata/dot-files/master/.bashrc
# Source the new .bashrc
source ~/.bashrc

#Upgrade apt
sudo apt update
sudo apt --assume-yes upgrade

# Install git
sudo apt install git
# Set git defaults
git config --global init.defaultBranch master
git config --global user.name "Patrick Kehn"
git config --global user.email kehnpatrick@gmail.com

echo -n "Install Fuzzy Finder and Kakoune editor? (y/n)? "
read answer
if [ "$answer" != "${answer#[Yy]}" ] ;then
    # Install Fuzzy Finder
    sudo apt install fzf

    # Install the Kakoune editor
    sudo apt install kakoune
    mkdir -p /home/admin/.config/kak
    cd /home/admin/.config/kak/
    curl -O https://raw.githubusercontent.com/jackrabbitdata/dot-files/master/kakrc
    cd
else
    echo Continuing...
fi


echo -n "Install Vendle and .vimrc? (y/n)? "
read answer
if [ "$answer" != "${answer#[Yy]}" ] ;then
    # Remove if exists and add Vundle
    rm .vimrc
    curl -O https://raw.githubusercontent.com/jackrabbitdata/dot-files/master/.vimrc
    sudo rm -r ~/.vim/bundle
    git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
    cd

    # The following command will install the latest Vundle plugins without any user interaction with Vim.
    # The -c option allows one to run a command before Vim starts up, and you can have up to 32 -c commands, according to the man page. So this snippet tells Vim to run the PluginInstall command (from Vundle) and then qa! to quit all windows.
    vim -c 'PluginInstall' -c 'qa!'
else
    echo Continuing...
fi

# Install node and Emmet if wanted
echo -n "Install node and command line emmet? (y/n)? "
read answer
if [ "$answer" != "${answer#[Yy]}" ] ;then
    # Install node.js
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y nodejs
    # Install command line emmet
    sudo npm i -g emmet-cli
else
    echo Continuing...
fi

echo 'Install Subversion if wanted'
echo 'Used to export git repositories when versioning is not wanted'
echo 'Ex: Wordpress installations'
echo -n "Install Subversion? (y/n)? "
read answer
if [ "$answer" != "${answer#[Yy]}" ] ;then
    sudo apt --assume-yes install subversion
else
    echo Continuing...
fi

echo 'Install Ledger-cli if wanted'
echo -n "Install Ledger-cli? (y/n)? "
read answer
if [ "$answer" != "${answer#[Yy]}" ] ;then
    sudo apt --assume-yes install ledger
else
    echo Continuing...
fi

# Install Web Server, MariaDB, PHP, and common PHP libraries
sudo apt --assume-yes install apache2 mariadb-server mariadb-client php libapache2-mod-php php-mysql php-curl php-gd php-imagick php-intl php-common php-mbstring php-xml php-zip

# Install Postgres database
sudo apt --assume-yes install postgresql postgresql-contrib postgresql-client php-pdo-pgsql

# Enable some apache modules
sudo a2enmod rewrite
sudo a2enmod vhost_alias
sudo a2enmod expires
sudo a2enmod headers

cat <<EOF | sudo tee -a /etc/apache2/apache2.conf

<IfModule mod_expires.c>
ExpiresActive on
AddType image/x-icon .ico
ExpiresDefault "access plus 2 hours"
ExpiresByType text/html "access plus 15 days"
ExpiresByType image/gif "access plus 1 months"
ExpiresByType image/jpg "access plus 1 months"
ExpiresByType image/jpeg "access plus 1 months"
ExpiresByType image/png "access plus 1 months"
ExpiresByType text/js "access plus 1 months"
ExpiresByType text/javascript "access plus 1 months"
ExpiresByType text/plain "access plus 30 days"
ExpiresByType image/x-icon "access plus 30 days"
ExpiresByType image/ico "access plus 30 days"
</IfModule>
EOF

# Restart Apache
sudo systemctl restart apache2

# Set MariaDB root password
echo "Please enter a password to set root password in MariaDB. Do not leave blank! PK"
read -p 'New Password: ' mariadb_password
sql_script="ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password by '"$mariadb_password"';"
sudo mariadb <<EOF
$sql_script
EOF

# Secure MariaDB
echo
echo "================================================================="
echo "If you want to secure MariaDB you will need to: "
echo "1. Answer if you want to set up VALIDATE PASSWORD component (No)"
echo "2. Change password for root? (No)"
echo "3. Remove anonymous users? (Yes)"
echo "4. Disallow root login remotely? (No) This is the only way to connect remote client with root"
echo "5. Remove test database and access to it? (Yes)"
echo "6. Reload privilege tables now? (Yes)"
echo "================================================================="
echo "You will need to use sudo to login. example: sudo mariadb -u root -p"
echo -n " Secure MariaDB? (y/n)? "
read answer
if [ "$answer" != "${answer#[Yy]}" ] ;then
    sudo mariadb-secure-installation
else
    echo Continuing...
fi

# Change bind-address to listen on all interfaces instead of 127.0.0.1 which is localhost only.
# If you need to restrict access to certain users from specific IP addresses, utilize create/grant user like this CREATE USER 'bobdole'@'192.168.10.221';
# Or possibly even better, use the AWS security groups functionality.
sudo sed -i '/bind-address/c\bind-address = 0.0.0.0' /etc/mysql/mariadb.conf.d/50-server.cnf
sudo systemctl restart mariadb

# Install Composer https://getcomposer.org/doc/faqs/how-to-install-composer-programmatically.md
# It needs unzip
sudo apt --assume-yes install unzip
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php composer-setup.php --quiet
rm composer-setup.php
sudo mv composer.phar /usr/local/bin/composer

# Install web log analyzer GoAccess
sudo apt --assume-yes install goaccess

# Install certbot
sudo apt install certbot python3-certbot-apache -y

# Option to increase php parameters
echo "Option to increase session timeout from 1440 seconds to 28800"
echo "and max file upload size from 2M to 18M"
echo -n " Increase php parameters? (y/n)? "
read answer
if [ "$answer" != "${answer#[Yy]}" ] ;then
    # Change the session timeout so users can stay logged in all day.
    sudo sed -i 's/session.gc_maxlifetime = 1440/session.gc_maxlifetime = 28800/' /etc/php/8.4/apache2/php.ini

    # Change the upload file size limit to larger than default
    sudo sed -i 's/post_max_size = 8/post_max_size = 18/' /etc/php/8.4/apache2/php.ini
    sudo sed -i 's/upload_max_filesize = 2/upload_max_filesize = 18/' /etc/php/8.4/apache2/php.ini
else
    echo Continuing...
fi

# Install and configure Postfix for send only
echo "Fat Free Framework has an SMTP plug-in to prepare e-mail messages (headers & attachments) and send them through a socket connection."
echo "So postfix is often not needed"
echo -n " Install postfix for send only email? (y/n)? "
read answer
if [ "$answer" != "${answer#[Yy]}" ] ;then
    echo "Please enter relay host for postfix. Ex: [smtp.pobox.com]:587"
    read -p 'Relay Host: ' postfix_relayhost
    echo "Please enter relay host login credentials for postfix. Ex: smtp.pobox.com ACCOUNT@pobox.com:PASSWORD"
    read -p 'Login Credentials: ' postfix_password
    echo "Please enter email destination for test email. Ex: person@example.com"
    read -p 'Destination email: ' send_to_email
    sudo debconf-set-selections <<< "postfix postfix/mailname string $srv_domain"
    sudo debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
    sudo apt install --assume-yes mailutils
    sudo postconf -e smtp_tls_security_level=encrypt
    sudo postconf -e smtp_sasl_auth_enable=yes
    sudo postconf -e smtp_sasl_password_maps=hash:/etc/postfix/smtp_passwd
    sudo postconf -e smtp_sasl_security_options=noanonymous
    sudo postconf -e smtp_sasl_tls_security_options=noanonymous
    sudo postconf -e relayhost=$postfix_relayhost
    postconf -n
    if [[ ! -f /etc/postfix/smtp_passwd ]]; then
        echo $postfix_password | sudo tee /etc/postfix/smtp_passwd
        sudo postmap hash:/etc/postfix/smtp_passwd
        sudo chown root:root /etc/postfix/smtp_passwd
        sudo chmod 600 /etc/postfix/smtp_passwd
    fi
    sudo systemctl restart postfix

    #Send test email
    echo "The postfix email setup script for $srv_domain has ran." | mail -s "Setup script for $srv_domain postfix ran successfully" $send_to_email
    echo "Verify email was successfully sent"
else
    echo Continuing...
fi

echo 'Install Docker if wanted'
echo -n "Install Docker? (y/n)? "
read answer
if [ "$answer" != "${answer#[Yy]}" ] ;then
    # Add Docker's official GPG key:
    sudo apt install ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    sudo tee /etc/apt/sources.list.d/docker.sources <<-EOF
    Types: deb
    URIs: https://download.docker.com/linux/debian
    Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
    Components: stable
    Architectures: $(dpkg --print-architecture)
    Signed-By: /etc/apt/keyrings/docker.asc
    EOF

    sudo apt update
    sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
echo Continuing...
fi

# Finished
echo "Script finished"
