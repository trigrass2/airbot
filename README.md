AirBot
========
> AirBot is a Slack productivity friend for AirVantage engineering team

## Setup
> Bash script and resources to set up a Hubot server on a blank Ubuntu AMI with a blank Volume attached.

## Usage

1. Install packages
  ```bash
  ./install.sh
  ```

2. Install Hubot library
  ```bash
  npm install
  ```

3. Modify the file *.airbotrc* and configure the Hubot API token

4. Launch Hubot server
  ```bash
  forever start --uid "airbot" -a -c "/bin/bash" ./bin/airbot start
  ```

5. List all running forever scripts
  ```bash
  forever list
  ```

6. Stop Hubot server
  ```bash
  forever stop airbot
  ```
