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

function newClient () {
	echo ""
	echo "Tell me a name for the client."
	echo "Use one word only, no special characters."

	if [ -z "$SERVER_NAME" ]; then
		echo "Error: No SERVER_NAME speficied. Exiting!"
		exit 1
	fi
	CLIENT=$CLIENT_NAME

	cd /etc/openvpn/$SERVER_NAME/easy-rsa/ || return
	# Create client certificates
	./easyrsa build-client-full "$CLIENT" nopass

	# Determine if we use tls-auth or tls-crypt
	if grep -qs "^tls-crypt" /etc/openvpn/$SERVER_NAME/server.conf; then
		TLS_SIG="1"
	elif grep -qs "^tls-auth" /etc/openvpn/$SERVER_NAME/server.conf; then
		TLS_SIG="2"
	fi

	# Create clients directory for server if it does not exist
	mkdir -p /etc/openvpn/$SERVER_NAME/clients/

	# Generates the custom client.ovpn
	cp /etc/openvpn/$SERVER_NAME/client-template.txt "/etc/openvpn/$SERVER_NAME/clients/$CLIENT.ovpn"
	{
		echo "<ca>"
		cat "/etc/openvpn/$SERVER_NAME/easy-rsa/pki/ca.crt"
		echo "</ca>"

		echo "<cert>"
		awk '/BEGIN/,/END/' "/etc/openvpn/$SERVER_NAME/easy-rsa/pki/issued/$CLIENT.crt"
		echo "</cert>"

		echo "<key>"
		cat "/etc/openvpn/$SERVER_NAME/easy-rsa/pki/private/$CLIENT.key"
		echo "</key>"

		case $TLS_SIG in
			1)
				echo "<tls-crypt>"
				cat /etc/openvpn/$SERVER_NAME/tls-crypt.key
				echo "</tls-crypt>"
			;;
			2)
				echo "key-direction 1"
				echo "<tls-auth>"
				cat /etc/openvpn/$SERVER_NAME/tls-auth.key
				echo "</tls-auth>"
			;;
		esac
	} >> "/etc/openvpn/$SERVER_NAME/clients/$CLIENT.ovpn"

	echo ""
	echo "Client $CLIENT added, the configuration file is available at /etc/openvpn/$SERVER_NAME/clients/$CLIENT.ovpn."
	echo "Download the .ovpn file and import it in your OpenVPN client."
}

function revokeClient () {
	NUMBEROFCLIENTS=$(tail -n +2 /etc/openvpn/easy-rsa/pki/index.txt | grep -c "^V")
	if [[ "$NUMBEROFCLIENTS" = '0' ]]; then
		echo ""
		echo "You have no existing clients!"
		exit 1
	fi

	echo ""
	echo "Select the existing client certificate you want to revoke"
	tail -n +2 /etc/openvpn/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 | nl -s ') '
	if [[ "$NUMBEROFCLIENTS" = '1' ]]; then
		read -rp "Select one client [1]: " CLIENTNUMBER
	else
		read -rp "Select one client [1-$NUMBEROFCLIENTS]: " CLIENTNUMBER
	fi

	CLIENT=$(tail -n +2 /etc/openvpn/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 | sed -n "$CLIENTNUMBER"p)
	cd /etc/openvpn/easy-rsa/
	./easyrsa --batch revoke "$CLIENT"
	EASYRSA_CRL_DAYS=3650 ./easyrsa gen-crl
	# Cleanup
	rm -f "pki/reqs/$CLIENT.req"
	rm -f "pki/private/$CLIENT.key"
	rm -f "pki/issued/$CLIENT.crt"
	rm -f /etc/openvpn/crl.pem
	cp /etc/openvpn/easy-rsa/pki/crl.pem /etc/openvpn/crl.pem
	chmod 644 /etc/openvpn/crl.pem
	find /home/ -maxdepth 2 -name "$CLIENT.ovpn" -delete
	rm -f "/root/$CLIENT.ovpn"
	sed -i "s|^$CLIENT,.*||" /etc/openvpn/ipp.txt

	echo ""
	echo "Certificate for client $CLIENT revoked."
}

function removeUnbound () {
	# Remove OpenVPN-related config
	sed -i 's|include: \/etc\/unbound\/openvpn.conf||' /etc/unbound/unbound.conf
	rm /etc/unbound/openvpn.conf
	systemctl restart unbound

	until [[ $REMOVE_UNBOUND =~ (y|n) ]]; do
		echo ""
		echo "If you were already using Unbound before installing OpenVPN, I removed the configuration related to OpenVPN."
		read -rp "Do you want to completely remove Unbound? [y/n]: " -e REMOVE_UNBOUND
	done

	if [[ "$REMOVE_UNBOUND" = 'y' ]]; then
		# Stop Unbound
		systemctl stop unbound

		if [[ "$OS" =~ (debian|ubuntu) ]]; then
			apt-get autoremove --purge -y unbound
		elif [[ "$OS" = 'arch' ]]; then
			pacman --noconfirm -R unbound
		elif [[ "$OS" = 'centos' ]]; then
			yum remove -y unbound
		elif [[ "$OS" = 'fedora' ]]; then
			dnf remove -y unbound
		fi

		rm -rf /etc/unbound/

		echo ""
		echo "Unbound removed!"
	else
		echo ""
		echo "Unbound wasn't removed."
	fi
}

function removeOpenVPN () {
	echo ""
	read -rp "Do you really want to remove OpenVPN? [y/n]: " -e -i n REMOVE
	if [[ "$REMOVE" = 'y' ]]; then
		# Get OpenVPN port from the configuration
		PORT=$(grep '^port ' /etc/openvpn/$SERVER_NAME/server.conf | cut -d " " -f 2)

		# Stop OpenVPN
		if [[ "$OS" =~ (fedora|arch) ]]; then
			systemctl disable openvpn-server@server
			systemctl stop openvpn-server@server
			# Remove customised service
			rm /etc/systemd/system/openvpn-server_$SERVER_NAME@.service
		elif [[ "$OS" == "ubuntu" ]] && [[ "$VERSION_ID" == "16.04" ]]; then
			systemctl disable openvpn
			systemctl stop openvpn
		else
			systemctl disable openvpn@server
			systemctl stop openvpn@server
			# Remove customised service
			rm /etc/systemd/system/openvpn_$SERVER_NAME\@.service
		fi

		# Remove the iptables rules related to the script
		systemctl stop iptables-openvpn
		# Cleanup
		systemctl disable iptables-openvpn
		rm /etc/systemd/system/iptables-openvpn.service
		systemctl daemon-reload
		rm /etc/iptables/add-openvpn-rules.sh
		rm /etc/iptables/rm-openvpn-rules.sh

		# SELinux
		if hash sestatus 2>/dev/null; then
			if sestatus | grep "Current mode" | grep -qs "enforcing"; then
				if [[ "$PORT" != '1194' ]]; then
					semanage port -d -t openvpn_port_t -p udp "$PORT"
				fi
			fi
		fi

		if [[ "$OS" =~ (debian|ubuntu) ]]; then
			apt-get autoremove --purge -y openvpn
			if [[ -e /etc/apt/sources.list.d/openvpn.list ]];then
				rm /etc/apt/sources.list.d/openvpn.list
				apt-get update
			fi
		elif [[ "$OS" = 'arch' ]]; then
			pacman --noconfirm -R openvpn
		elif [[ "$OS" = 'centos' ]]; then
			yum remove -y openvpn
		elif [[ "$OS" = 'fedora' ]]; then
			dnf remove -y openvpn
		fi

		# Cleanup
		find /home/ -maxdepth 2 -name "*.ovpn" -delete
		find /root/ -maxdepth 1 -name "*.ovpn" -delete
		rm -rf /etc/openvpn
		rm -rf /usr/share/doc/openvpn*
		rm -f /etc/sysctl.d/20-openvpn.conf
		rm -rf /var/log/openvpn

		# Unbound
		if [[ -e /etc/unbound/openvpn.conf ]]; then
			removeUnbound
		fi
		echo ""
		echo "OpenVPN removed!"
	else
		echo ""
		echo "Removal aborted!"
	fi
}

function manageMenu () {
	clear
	echo "Welcome to OpenVPN-install!"
	echo "The git repository is available at: https://github.com/angristan/openvpn-install"
	echo ""
	echo "It looks like OpenVPN is already installed."
	echo ""
	echo "What do you want to do?"
	echo "   1) Add a new user"
	echo "   2) Revoke existing user"
	echo "   3) Remove OpenVPN"
	echo "   4) Exit"
	until [[ "$MENU_OPTION" =~ ^[1-4]$ ]]; do
		read -rp "Select an option [1-4]: " MENU_OPTION
	done

	case $MENU_OPTION in
		1)
			newClient
		;;
		2)
			revokeClient
		;;
		3)
			removeOpenVPN
		;;
		4)
			exit 0
		;;
	esac
}

# Check for root, TUN, OS...
# initialCheck

checkOS
newClient

# # Check if OpenVPN is already installed
# if [[ -e /etc/openvpn/$SERVER_NAME/server.conf ]]; then
# 	manageMenu
# else
# 	installOpenVPN
# fi