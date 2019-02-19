#!/bin/bash

if [ "$(id -u)" != "0" ]; then
	echo "Sorry, you need to run this as root"
	exit 1
fi

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

function installOpenVPN () {
	if [[ "$OS" =~ (debian|ubuntu) ]]; then
		apt-get update
		apt-get -y install ca-certificates gnupg
		# We add the OpenVPN repo to get the latest version.
		if [[ "$VERSION_ID" = "8" ]]; then
			echo "deb http://build.openvpn.net/debian/openvpn/stable jessie main" > /etc/apt/sources.list.d/openvpn.list
			wget -O - https://swupdate.openvpn.net/repos/repo-public.gpg | apt-key add -
			apt-get update
		fi
		if [[ "$VERSION_ID" = "16.04" ]]; then
			echo "deb http://build.openvpn.net/debian/openvpn/stable trusty main" > /etc/apt/sources.list.d/openvpn.list
			wget -O - https://swupdate.openvpn.net/repos/repo-public.gpg | apt-key add -
			apt-get update
		fi
		# Ubuntu > 16.04 and Debian > 8 have OpenVPN >= 2.4 without the need of a third party repository.
		apt-get install -y openvpn iptables openssl wget ca-certificates curl policycoreutils-python
	elif [[ "$OS" = 'centos' ]]; then
		yum install -y epel-release
		yum install -y openvpn iptables openssl wget ca-certificates curl policycoreutils-python
	elif [[ "$OS" = 'fedora' ]]; then
		dnf install -y openvpn iptables openssl wget ca-certificates curl policycoreutils-python
	elif [[ "$OS" = 'arch' ]]; then
		echo ""
		echo "WARNING: As you're using ArchLinux, I need to update the packages on your system to install those I need."
		echo "Not doing that could cause problems between dependencies, or missing files in repositories (Arch Linux does not support partial upgrades)."
		echo "As this operation is not performed automatically you have to run the following command manually: "
		echo "pacman --needed --noconfirm -Syu openvpn iptables openssl wget ca-certificates curl policycoreutils-python"
	fi

	# An old version of easy-rsa was available by default in some openvpn packages
	if [[ -d /etc/openvpn/easy-rsa/ ]]; then
		rm -rf /etc/openvpn/easy-rsa/
	fi

	# Install the latest version of easy-rsa from source
	local version="3.0.5"
	wget -O ~/EasyRSA-nix-${version}.tgz https://github.com/OpenVPN/easy-rsa/releases/download/v${version}/EasyRSA-nix-${version}.tgz
	tar xzf ~/EasyRSA-nix-${version}.tgz -C ~/
	mv ~/EasyRSA-${version}/ /etc/openvpn/
	mv /etc/openvpn/EasyRSA-${version}/ /etc/openvpn/easy-rsa/
	chown -R root:root /etc/openvpn/easy-rsa/
	rm -f ~/EasyRSA-nix-${version}.tgz
}

checkOS
installOpenVPN