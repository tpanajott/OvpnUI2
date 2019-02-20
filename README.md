- [How to setup](#how-to-setup)
  - [Prerequisites](#prerequisites)
  - [Download and setup](#download-and-setup)
    - [Locking down allowed hosts](#locking-down-allowed-hosts)
    - [Installing base software](#installing-base-software)
- [Goals](#goals)

# How to setup

## Prerequisites
1. Access to root account.
2. Python 3 installed.
3. Basic Linux knowledge.

## Download and setup
Run the following commands to download the repository into the current users home directory.
```
git pull https://github.com/vpklotar/OvpnUI2.git ~/OvpnUI2
```
The application currently requiers it to be run as root user in order to manage systemctl services.

### Locking down allowed hosts
This application comes predefined to allow any host to connect. If you want to specify this more strictly the settings.json file is located in the `ovpnui2/ovpnui2/` directory. Look for the `ALLOWED_HOSTS` setting around line 28. To se configuration examples please look at Djangos offical website https://docs.djangoproject.com/en/2.1/ref/settings/#allowed-hosts

### Installing base software
In order for this software to work properly it needs to have packages installed. Easiest way to do this is to run the script located at `ovpnui2/ui/helpers/install_openvpn.sh`.  
If that script does not work, make sure you install appropriate packages for the following applications/utilities:
* openvpn
* semanage
* wget
* ca-certificates
* curl

To become root, run `su` or `sudo su`. Then start the application be running the following commands
```
cd ~/OvpnUI2/ovpnui2/
./manage.py
```

# Goals
The goal of this application is to ease the use and setup of OpenVPN and hopefully other VPN services later on.