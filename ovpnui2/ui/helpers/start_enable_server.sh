#!/bin/bash

# Secure OpenVPN server installer for Debian, Ubuntu, CentOS, Fedora and Arch Linux
# https://github.com/angristan/openvpn-install

function isRoot () {
	if [ "$EUID" -ne 0 ]; then
		return 1
	fi
}

function tunAvailable () {
	if [ ! -e /dev/net/tun ]; then
		return 1
	fi
}

function checkOS () {
	if [[ -e /etc/debian_version ]]; then
		OS="debian"
		source /etc/os-release

		if [[ "$ID" == "debian" ]]; then
			if [[ ! $VERSION_ID =~ (8|9) ]]; then
				echo "⚠️ Your version of Debian is not supported."
				echo ""
				echo "However, if you're using Debian >= 9 or unstable/testing then you can continue."
				echo "Keep in mind they are not supported, though."
				echo ""
				until [[ $CONTINUE =~ (y|n) ]]; do
					read -rp "Continue? [y/n]: " -e CONTINUE
				done
				if [[ "$CONTINUE" = "n" ]]; then
					exit 1
				fi
			fi
		elif [[ "$ID" == "ubuntu" ]];then
			OS="ubuntu"
			if [[ ! "$(echo $VERSION_ID | cut -d'.' -f 1)" -ge 16 ]]; then
				echo "⚠️ Your version of Ubuntu is not supported."
				echo ""
				echo "However, if you're using Ubuntu > 17 or beta, then you can continue."
				echo "Keep in mind they are not supported, though."
				echo ""
			fi
		fi
	elif [[ -e /etc/fedora-release ]]; then
		OS=fedora
	elif [[ -e /etc/centos-release ]]; then
		if ! grep -qs "^CentOS Linux release 7" /etc/centos-release; then
			echo "Your version of CentOS is not supported."
			echo "The script only support CentOS 7."
			echo ""
		fi
		OS=centos
	elif [[ -e /etc/arch-release ]]; then
		OS=arch
	else
		echo "Looks like you aren't running this installer on a Debian, Ubuntu, Fedora, CentOS or Arch Linux system"
		exit 1
	fi
}

function initialCheck () {
	if ! isRoot; then
		echo "Sorry, you need to run this as root"
		exit 1
	fi
	if ! tunAvailable; then
		echo "TUN is not available"
		exit 1
	fi
	checkOS
}

function startServer () {
	# Get OpenVPN port from the configuration
	PORT=$(grep '^port ' /etc/openvpn/$SERVER_NAME/server.conf | cut -d " " -f 2)

	# Stop OpenVPN
	if [[ "$OS" =~ (fedora|arch) ]]; then
		systemctl enable openvpn-server@$SERVER_NAME
		systemctl start openvpn-server@$SERVER_NAME
	elif [[ "$OS" == "ubuntu" ]] && [[ "$VERSION_ID" == "16.04" ]]; then
		systemctl enable openvpn
		systemctl start openvpn
	else
		systemctl enable openvpn@$SERVER_NAME
		systemctl start openvpn@$SERVER_NAME
	fi

	systemctl start iptables-openvpn-$SERVER_NAME
	systemctl enable iptables-openvpn-$SERVER_NAME
}

# Check for root, TUN, OS...
# initialCheck

checkOS
startServer

# # Check if OpenVPN is already installed
# if [[ -e /etc/openvpn/$SERVER_NAME/server.conf ]]; then
# 	manageMenu
# else
# 	installOpenVPN
# fi