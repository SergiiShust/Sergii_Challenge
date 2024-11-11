#!/bin/bash
# Update and install Nginx
apt update
apt install -y nginx openssl

# Create self-signed SSL certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/nginx-selfsigned.key -out /etc/ssl/certs/nginx-selfsigned.crt -subj "/C=US/ST=State/L=City/O=Organization/OU=IT/CN=localhost"

# Create Nginx SSL config
cat << 'EOL' > /etc/nginx/snippets/self-signed.conf
ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;
EOL

# Configure Nginx for HTTPS and redirect HTTP to HTTPS
cat << 'EOL' > /etc/nginx/sites-available/default
server {
    listen 80;
    server_name localhost;

    # Redirect HTTP to HTTPS
    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name localhost;

    include snippets/self-signed.conf;

    location / {
        root /var/www/html;
        index index.html;
    }
}
EOL

# Create Hello World HTML page
mkdir -p /var/www/html
cat << 'EOL' > /var/www/html/index.html
<html>
<head><title>Hello World</title></head>
<body><h1>Hello World!</h1></body>
</html>
EOL

# Start and enable Nginx
systemctl restart nginx
systemctl enable nginx

# start in container
# service nginx restart
# service nginx enable