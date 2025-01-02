#!/bin/bash

# Colors for output
GREEN="\033[0;32m"
RED="\033[0;31m"
NC="\033[0m" # No Color

echo -e "${GREEN}Starting Pterodactyl Installation...${NC}"

# Update system and install dependencies
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl zip unzip tar wget git nginx mysql-server php-cli php-mbstring php-xml php-bcmath php-curl php-zip composer nodejs redis-server

# Install Pterodactyl
echo -e "${GREEN}Downloading Pterodactyl Panel...${NC}"
mkdir -p /var/www/pterodactyl
cd /var/www/pterodactyl
curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
tar -xzvf panel.tar.gz && rm panel.tar.gz

echo -e "${GREEN}Installing Composer Dependencies...${NC}"
composer install --no-dev --optimize-autoloader

echo -e "${GREEN}Setting File Permissions...${NC}"
chown -R www-data:www-data /var/www/pterodactyl
chmod -R 755 /var/www/pterodactyl/storage /var/www/pterodactyl/bootstrap/cache

echo -e "${GREEN}Setting up Environment...${NC}"
cp .env.example .env
php artisan key:generate --force

echo -e "${GREEN}Configuring Database...${NC}"
read -p "Enter MySQL root password: " MYSQL_ROOT_PASSWORD
read -p "Enter Pterodactyl Database Name: " DB_NAME
read -p "Enter Pterodactyl Database User: " DB_USER
read -p "Enter Pterodactyl Database Password: " DB_PASSWORD

mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "CREATE DATABASE $DB_NAME;"
mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"
mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "FLUSH PRIVILEGES;"

sed -i "s/DB_DATABASE=.*/DB_DATABASE=$DB_NAME/" .env
sed -i "s/DB_USERNAME=.*/DB_USERNAME=$DB_USER/" .env
sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=$DB_PASSWORD/" .env

php artisan migrate --seed --force

echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}Visit your panel at http://<your-server-ip>${NC}"
