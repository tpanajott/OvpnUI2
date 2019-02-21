- [How to setup](#how-to-setup)
  - [Prerequisites](#prerequisites)
  - [Download and setup](#download-and-setup)
    - [Limiting allowed hosts](#limiting-allowed-hosts)
    - [Installing base software](#installing-base-software)
    - [Helpers permissions](#helpers-permissions)
    - [Install python modules](#install-python-modules)
  - [Load inital data](#load-inital-data)
  - [Start of the application](#start-of-the-application)
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

### Limiting allowed hosts
This application comes predefined to allow any host to connect. If you want to specify this more strictly the settings.json file is located in the `ovpnui2/ovpnui2/` directory. Look for the `ALLOWED_HOSTS` setting around line 28. To se configuration examples please look at Djangos offical website https://docs.djangoproject.com/en/2.1/ref/settings/#allowed-hosts

### Installing base software
In order for this software to work properly it needs to have packages installed. Easiest way to do this is to run the script located at `ovpnui2/ui/helpers/install_openvpn.sh`.  
If that script does not work, make sure you install appropriate packages for the following applications/utilities:
* openvpn
* semanage
* wget
* ca-certificates
* curl
  
### Helpers permissions
Make sure all the scripts in `ovpnui2/ui/helpers/` have (at least) permissions to be executable as root user

### Install python modules
In order for this application to work it needs to have Django install via pip for Python 3. This is easiest done by running the command `pip3 install django`. This application is writting using Django 2.1.7 and python 3.6 but might work with older/newer releases.

To become root, run `su` or `sudo su`. Then start the application be running the following commands
```
cd ~/OvpnUI2/ovpnui2/
./manage.py
```

## Load inital data
To load the inital login data run the following commands
```
# This will flush the existing database of users
./manage.py flush
# The will load the default fixture (set) of users
./manage.py loaddata fixtures/users.json
```

If migrations fail, run the commands `./manage.py makemigrations` and `./manage.py migrate` to setup the database.

## Start of the application
The application can be run using the included `run.sh` script or by issuing the command `./manage.py runserver <listenip>:<port>`.

# Goals
The goal of this application is to ease the use and setup of OpenVPN and hopefully other VPN services later on.