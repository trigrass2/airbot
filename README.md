AirBot
========
> AirBot is the Slack productivity friend for AirVantage engineering team

## How can he help me?
>He will contact you at various occasions

* Someone assigns you a Github issue
* Someone assigns you a Github Pull Request
* Someone mentions you in a Github comment
* Someone add a comment in a Github issue or pull request you created
* Every morning at 9am to give you your planning

You can contact him and ask various things.

### planning
>He will compute and return your planning

* Github issues & PR assigned to you
* JIRA issues assigned to you

### team reminder
> He will remind what you want to a specific user.

How to use:
remind [username] in [X seconds/minutes/hours] to [do something]

## Setup
> Bash script and resources to set up a Hubot server on a blank Ubuntu AMI with a blank Volume attached.

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
