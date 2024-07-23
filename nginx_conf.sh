#!/bin/bash
sudo apt-get update
sudo apt install -y nginx
sudo apt-get install -y certbot python3-certbot-nginx
sudo certbot certonly --nginx -d test.evitey.com


# Comment all lines in the existing Nginx configuration file
sudo sed -i 's/^/#/' /etc/nginx/sites-available/default

# NGINX configuration outside Docker
sudo bash -c 'cat << EOF > /etc/nginx/sites-available/default
server {
    listen 80;
    server_name test.evitey.com;
    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name test.evitey.com;

    ssl_certificate /etc/letsencrypt/live/test.evitey.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/test.evitey.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        proxy_pass http://localhost:81;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF'

# Restart NGINX service
sudo systemctl restart nginx.service

# NGINX configuration inside Docker container
sudo docker exec -it deployment_lb_1 sh -c 'cat << EOF > /etc/nginx/conf.d/default.conf
server {
    listen 81;
    server_name test.evitey.com;

    location / {
        return 301 https://test.evitey.com\$request_uri;
    }
}
EOF'

# Reload NGINX configuration inside Docker container
sudo docker exec -it deployment_lb_1 nginx -s reload

# Restart Docker container
sudo docker restart deployment_lb_1

# Restart all Docker containers
sudo docker restart $(sudo docker ps -q)
