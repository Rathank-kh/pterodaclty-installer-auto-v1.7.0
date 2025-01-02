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
curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/1.7.0/download/panel.tar.gz
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

# Set up Pterodactyl Admin User
echo -e "${GREEN}Creating Pterodactyl Admin User...${NC}"
read -p "Enter Pterodactyl Admin Username: " ADMIN_USER
read -p "Enter Pterodactyl Admin Email: " ADMIN_EMAIL
read -p "Enter Pterodactyl Admin Password: " ADMIN_PASS

php artisan p:user:make --email="$ADMIN_EMAIL" --username="$ADMIN_USER" --password="$ADMIN_PASS" --admin

# Set up Node for Pterodactyl
echo -e "${GREEN}Setting up Node...${NC}"
read -p "Enter Node Name: " NODE_NAME
read -p "Enter Node FQDN (Fully Qualified Domain Name) or IP: " NODE_FQDN

php artisan p:node:add --name="$NODE_NAME" --location="Default" --fqdn="$NODE_FQDN" --daemon

# Set up Wing for Pterodactyl
echo -e "${GREEN}Setting up Wing...${NC}"
curl -Lo /usr/local/bin/wing https://github.com/pterodactyl/wing/releases/download/v1.0.0/wing-linux-amd64
chmod +x /usr/local/bin/wing

# Start Wing
systemctl enable wing
systemctl start wing

# Configure Nginx Web Server for Pterodactyl Panel
echo -e "${GREEN}Setting up Nginx Web Server...${NC}"
read -p "Enter your server's domain or IP address for Nginx configuration: " SERVER_DOMAIN
cat > /etc/nginx/sites-available/pterodactyl <<EOF
server {
    listen 80;
    server_name $SERVER_DOMAIN;

    root /var/www/pterodactyl/public;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

ln -s /etc/nginx/sites-available/pterodactyl /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

# Set up SSL (Optional, uses Let's Encrypt)
echo -e "${GREEN}Setting up SSL with Let's Encrypt...${NC}"
read -p "Do you want to enable SSL (Y/N)? " SSL_CHOICE
if [ "$SSL_CHOICE" == "Y" ] || [ "$SSL_CHOICE" == "y" ]; then
    apt install -y certbot python3-certbot-nginx
    certbot --nginx -d $SERVER_DOMAIN --agree-tos --no-eff-email --redirect
fi

echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}Visit your panel at http://$SERVER_DOMAIN or https://$SERVER_DOMAIN (with SSL enabled)${NC}"
