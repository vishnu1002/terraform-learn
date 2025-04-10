#!/bin/bash
apt update -y
apt install -y python3 python3-pip
pip3 install -r /home/ubuntu/app/requirements.txt

# Start the Flask app
cd /home/ubuntu/app
nohup python3 app.py > app.log 2>&1 &
