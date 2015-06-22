# airbot
========

> Bash script and resources to set up a Hubot server on a blank Ubuntu AMI with a blank Volume attached.

## Usage

1. Install packages
```bash
./install.sh
```
2. Install hubot library
```bash
npm install
```
3. Modify the file *.airbotrc* and configure the Hubot API token
4. Open a screen session
```bash
screen -S airbot
```
5. Launch Hubot server
```bash
./bin/airbot
```
6. Quit the screen session
```bash
ctrl a+d
```
