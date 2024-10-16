#!/bin/bash

# Variables
APP_DIR="/home/udacityadmin/azure-vote"
REPO_URL="https://github.com/nguyendangthaoit/azure-vote.git"

# Update and install necessary packages
sudo apt-get update
sudo apt-get install -y python3-pip python3-dev nginx git

# Clone the GitHub repository
if [ -d "$APP_DIR" ]; then
    sudo rm -rf $APP_DIR
fi
git clone $REPO_URL $APP_DIR

# Navigate to the app directory
cd $APP_DIR

# Install the application dependencies
pip3 install -r requirements.txt

# Create a systemd service to run the Flask app
sudo bash -c 'cat <<EOF > /etc/systemd/system/azure-vote.service
[Unit]
Description=Gunicorn instance to serve azure-vote Flask app
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=/home/udacityadmin/azure-vote
ExecStart=/usr/bin/python3 /home/udacityadmin/azure-vote/main.py

[Install]
WantedBy=multi-user.target
EOF'

# Start the Flask app service
sudo systemctl daemon-reload
sudo systemctl start azure-vote
sudo systemctl enable azure-vote

# Configure Nginx to reverse proxy to the Flask app
sudo bash -c 'cat <<EOF > /etc/nginx/sites-available/azure-vote
server {
    listen 80;
    server_name localhost;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF'

# Enable the Nginx configuration
sudo ln -s /etc/nginx/sites-available/azure-vote /etc/nginx/sites-enabled
sudo rm /etc/nginx/sites-enabled/default
sudo systemctl restart nginx
