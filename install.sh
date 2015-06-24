#!/bin/bash
#
# Script to setup a Airbot server from a blank Ubuntu AMI with a blank attached volume

echo "******** Install packages *********"

sudo apt-get update -qqy
sudo apt-get install -qqy --no-install-recommends \
        curl \
        git \
        screen

echo "******** Install nodejs and npm ********"
export NODE_VERSION=0.12.4
export NPM_VERSION=2.11.2
curl -SLO "http://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.gz"
sudo tar -xzf "node-v$NODE_VERSION-linux-x64.tar.gz" -C /usr/local --strip-components=1
sudo rm "node-v$NODE_VERSION-linux-x64.tar.gz"
sudo npm install -g npm@"$NPM_VERSION"

echo "******** Install Coffee script and Forever ********"
npm install -g coffee-script forever
