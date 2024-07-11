#!/bin/bash
#install requirements
sudo apt update
sudo apt install -y nginx
curl -sSL https://get.docker.com | sh

#docker login
DOCKER_USERNAME='evitey'
DOCKER_PASSWORD='$t@rt2023!'
echo "$DOCKER_PASSWORD" | sudo docker login --username "$DOCKER_USERNAME" --password-stdin

# Cleanup Docker containers and images
sudo docker ps -aq | xargs sudo docker stop | xargs sudo docker rm
sudo docker rmi $(sudo docker images -a -q)

# Create directories and set permissions
sudo mkdir -p /app/hosting/evitey/mysql
sudo chmod -R a+rwx /app/
sudo chown evitey-test-01:evitey-test-01 /app

# Pull Docker images
sudo docker pull evitey/evitey-demo:evitey_fe_new
sudo docker pull evitey/evitey-demo:evitey_taskman_new
sudo docker pull evitey/evitey-demo:evitey_redis_new
sudo docker pull evitey/evitey-demo:evitey_sql_new

# MySQL configuration
cd /app/hosting/evitey/mysql
sudo touch ./taskman.cnf
sudo chmod +x ./taskman.cnf
sudo chown evitey-trail:evitey-trail ./taskman.cnf
cat << EOF > ./taskman.cnf
[mysqld]
character-set-server=utf8

innodb_buffer_pool_size = 1G
innodb_log_file_size = 256M
innodb_flush_log_at_trx_commit = 1
innodb_flush_method = O_DIRECT

#slow-query-log=1
#slow-query-log-file=/var/log/mysql/mysql-slow.log
#long_query_time=.5
#log-queries-not-using-indexes = 1

sql_mode='STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION'

[client]
default-character-set=utf8
EOF

# Start Docker containers and configure networking
sleep 5
sudo docker network create deployment_default
sudo docker run --restart=always -e ALLOW_EMPTY_PASSWORD=yes --name redis -d evitey/evitey-demo:evitey_redis_new
sudo docker network connect deployment_default redis
sleep 5
sudo docker run --restart=always -it \
-e TZ="Asia/Kolkata" \
-e MYSQL_ROOT_PASSWORD=thisismysql \
-e MYSQL_DATABASE=ResourceManagement \
-e MYSQL_USER=RM \
-e MYSQL_PASSWORD=resources \
-v /app/hosting/evitey/storage/rmmysql:/var/lib/mysql \
-v /app/hosting/evitey/mysql/taskman.cnf:/etc/mysql/conf.d/taskman.cnf \
--name mysql -dp  127.0.0.1:3306:3306 evitey/evitey-demo:evitey_sql_new
sudo docker network connect deployment_default mysql

sleep 10
sudo docker run \
 --network deployment_default \
 -e MYSQL_HOST=mysql \
 -e MYSQL_PORT=3306 \
 -e MYSQL_USER=root \
 -e MYSQL_DATABASE_NAME=ResourceManagement \
 -e MYSQL_PASSWORD=thisismysql \
 -e APP_BIND_ADDRESS=0.0.0.0 \
 -e APP_BIND_PORT=8080 \
 -e REDIS_HOST=redis \
 -e DATA_PATH=/appdata \
 -e APP_QUEUE_POLICY=BY_LOCATION \
 -e ASSET_TRACKING_ENABLED=NO \
 -e CE_DELETE_IN_MINUTE=4320 \
 -e CE_INVALID_DELETE_IN_MINUTE=1440 \
 -e AE_DELETE_IN_MINUTE=4320 \
 -e AE_INVALID_DELETE_IN_MINUTE=1440 \
 -e REQUEST_DELETE_IN_MINUTE=525600 \
 -e REQUEST_ELAPSED_SEND_ALL_IN_MINUTE=3 \
 -e AVAILABLE_WIFI=CONNECTED \
--rm evitey/evitey-demo:evitey_taskman_new /app/TaskManagement  -reset -seed -migrate &
DOCKER_PID=$!
sleep 20
sudo kill $DOCKER_PID
wait $DOCKER_PID
sudo docker run -d --name taskman --restart=always \
 --network deployment_default \
 -e MYSQL_HOST=mysql \
 -e MYSQL_PORT=3306 \
 -e MYSQL_USER=root \
 -e MYSQL_DATABASE_NAME=ResourceManagement \
 -e MYSQL_PASSWORD=thisismysql \
 -e APP_BIND_ADDRESS=0.0.0.0 \
 -e APP_BIND_PORT=8080 \
 -e REDIS_HOST=redis \
 -e DATA_PATH=/appdata \
 -e APP_QUEUE_POLICY=BY_LOCATION \
 -e ASSET_TRACKING_ENABLED=NO \
 -e CE_DELETE_IN_MINUTE=4320 \
 -e CE_INVALID_DELETE_IN_MINUTE=1440 \
 -e AE_DELETE_IN_MINUTE=4320 \
 -e AE_INVALID_DELETE_IN_MINUTE=1440 \
 -e REQUEST_DELETE_IN_MINUTE=525600 \
 -e REQUEST_ELAPSED_SEND_ALL_IN_MINUTE=3 \
 -e AVAILABLE_WIFI=CONNECTED \
 evitey/evitey-demo:evitey_taskman_new
sleep 20
sudo docker run --restart=always --name evitey_fe -d -p 81:80 -p 8443:443 evitey/evitey-demo:evitey_fe_new
sudo docker network connect deployment_default evitey_fe
sleep 10
sudo docker exec -it mysql bash -c 'cd /etc/mysql/conf.d/ && chmod 644 taskman.cnf'

sudo docker restart $(sudo docker ps -q)
sudo docker ps

sudo apt-get update
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
sudo docker exec -it evitey_fe sh -c 'cat << EOF > /etc/nginx/conf.d/default.conf
server {
    listen 81;
    server_name test.evitey.com;

    location / {
        return 301 https://test.evitey.com\$request_uri;
    }
}
EOF'

# Reload NGINX configuration inside Docker container
sudo docker exec -it evitey_fe nginx -s reload

# Restart Docker container
sudo docker restart evitey_fe

# Restart all Docker containers
sudo docker restart $(sudo docker ps -q)

# Final message
echo "EVITEY SETUP COMPLETED"
