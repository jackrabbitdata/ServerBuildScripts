#! /bin/bash
# Set up a LAMP stack on a new AWS Ubuntu 22.04 server

# Use curl to transfer this file from Github
# curl -O https://raw.githubusercontent.com/jackrabbitdata/ServerBuildScripts/master/newLAMP.sh

# Run chmod 744 newLAMP.sh
# Run it by typing ./newLAMP.sh

#Set server/domain name variable that will be used throughout the script
echo "Please enter server name. Ex: example.com"
read -p 'Server name: ' srv_domain

# Set time zone
# Check with timedatectl
sudo timedatectl set-timezone America/Chicago
timedatectl

# Set hostname
sudo hostnamectl set-hostname $srv_domain
hostnamectl

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

#Upgrade apt
sudo apt update
sudo apt --assume-yes upgrade

# Install Fuzzy Finder
sudo apt install fzf

# Install the Kakoune editor
sudo apt install kakoune
mkdir -p /home/ubuntu/.config/kak
cd /home/ubuntu/.config/kak/
curl -O https://raw.githubusercontent.com/jackrabbitdata/dot-files/master/kakrc
cd

# Remove any existing and add my dot files
rm .bashrc
curl -O https://raw.githubusercontent.com/jackrabbitdata/dot-files/master/.bashrc
rm .vimrc
curl -O https://raw.githubusercontent.com/jackrabbitdata/dot-files/master/.vimrc

# Source the new .bashrc
source ~/.bashrc

# Remove if exists and add Vundle
sudo rm -r ~/.vim/bundle
git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
cd

# The following command will install the latest Vundle plugins without any user interaction with Vim.
# The -c option allows one to run a command before Vim starts up, and you can have up to 32 -c commands, according to the man page. So this snippet tells Vim to run the PluginInstall command (from Vundle) and then qa! to quit all windows.
vim -c 'PluginInstall' -c 'qa!'

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

# Install Web Server, Database, PHP, and common PHP libraries
sudo apt --assume-yes install apache2 mysql-server mysql-client php libapache2-mod-php php-mysql php-curl php-gd php-imagick php-intl php-common php-mbstring php-xml php-zip

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

# Set mysql root password
echo "Please enter a password to set root password in mysql."
read -p 'New Password: ' mysql_password
sql_script = "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password by '"$mysql_password"'"
sudo mysql $mysql_script

# Secure mysql
echo
echo "================================================================="
echo "If you want to secure mysql you will need to: "
echo "1. Answer if you want to set up VALIDATE PASSWORD component (No)"
echo "2. Change password for root? (No)"
echo "3. Remove anonymous users? (Yes)"
echo "4. Disallow root login remotely? (No) This is the only way to connect remote client with root"
echo "5. Remove test database and access to it? (Yes)"
echo "6. Reload privilege tables now? (Yes)"
echo "================================================================="
echo "You will need to use sudo to login. example: sudo mysql -u root -p"
echo -n " Secure mysql? (y/n)? "
read answer
if [ "$answer" != "${answer#[Yy]}" ] ;then
    sudo mysql_secure_installation
else
    echo Continuing...
fi

# Change bind-address to listen on all interfaces instead of 127.0.0.1 which is localhost only.
# If you need to restrict access to certain users from specific IP addresses, utilize create/grant user like this CREATE USER 'bobdole'@'192.168.10.221';
# Or possibly even better, use the AWS security groups functionality.
sudo sed -i '/bind-address/c\bind-address = 0.0.0.0' /etc/mysql/mysql.conf.d/mysqld.cnf
sudo systemctl restart mysql

# Install Composer https://getcomposer.org/doc/faqs/how-to-install-composer-programmatically.md
# It needs unzip
sudo apt --assume-yes install unzip
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php composer-setup.php --quiet
rm composer-setup.php
sudo mv composer.phar /usr/local/bin/composer

# Install web log analyzer GoAccess
sudo apt --assume-yes install goaccess

# Uninstall package version off certbot and install snap
sudo apt remove certbot
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot

# Finished
echo "Script finished"
