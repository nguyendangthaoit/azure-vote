#!/bin/bash
set -e  # Exit on error

# Install necessary packages
sudo apt-get update
sudo apt-get install -y python3 python3-pip git redis-server

# Start Redis server
sudo systemctl start redis-server
sudo systemctl enable redis-server

# Clone your GitHub repo
git clone https://github.com/nguyendangthaoit/azure-vote.git

# Change directory to your app
cd azure-vote/azure-vote

# Install Flask app dependencies from the repo
pip3 install -r requirements.txt

# Run Flask app using gunicorn for production
gunicorn --workers 3 --bind 0.0.0.0:80 main:app
