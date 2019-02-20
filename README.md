- [How to setup](#how-to-setup)
  - [Prerequisites](#prerequisites)
  - [Download and startup](#download-and-startup)
    - [Locking down allowed hosts](#locking-down-allowed-hosts)
- [Goals](#goals)

# How to setup

## Prerequisites
1. Access to root account.
2. Python 3 installed.
3. Basic Linux knowledge.

## Download and startup
Run the following commands to download the repository into the current users home directory.
```
git pull https://github.com/vpklotar/OvpnUI2.git ~/OvpnUI2
```
The application currently requiers it to be run as root user in order to manage systemctl services.

### Locking down allowed hosts
This application comes predefined to allow any host to connect. If you want to specify this more strictly the settings.json file is located in the `ovpnui2/ovpnui2/` directory. Look for the `ALLOWED_HOSTS` setting around line 28. To se configuration examples please look at Djangos offical website https://docs.djangoproject.com/en/2.1/ref/settings/#allowed-hosts

To become root, run `su` or `sudo su`. Then start the application be running the following commands
```
cd ~/OvpnUI2/ovpnui2/
./manage.py
```

# Goals
The goal of this application is to ease the use and setup of OpenVPN and hopefully other VPN services later on.