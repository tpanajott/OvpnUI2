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

function CreateServer () {
    print $PATH
    # Create new server directory and easy_rsa set
    mkdir -p /etc/openvpn/$SERVER_NAME/easy-rsa
    cd /tmp/
    
    # Download and install EasyRSA into the new server directory
    local version="3.0.5"
	wget -O ~/EasyRSA-nix-${version}.tgz https://github.com/OpenVPN/easy-rsa/releases/download/v${version}/EasyRSA-nix-${version}.tgz
	tar xzf ~/EasyRSA-nix-${version}.tgz -C ~/
	mv ~/EasyRSA-${version}/* /etc/openvpn/$SERVER_NAME/easy-rsa/
	chown -R root:root /etc/openvpn/$SERVER_NAME/easy-rsa/
	rm -f ~/EasyRSA-nix-${version}.tgz
	rm -f ~/EasyRSA-${version}

	# Find out if the machine uses nogroup or nobody for the permissionless group
	if grep -qs "^nogroup:" /etc/group; then
		NOGROUP=nogroup
	else
		NOGROUP=nobody
	fi

	cd /etc/openvpn/$SERVER_NAME/easy-rsa/
	case $CERT_TYPE in
		"ECDSA")
			echo "set_var EASYRSA_ALGO ec" > vars
			echo "set_var EASYRSA_CURVE $CERT_CURVE" >> vars
		;;
		"RSA")
			echo "set_var EASYRSA_KEY_SIZE $RSA_KEY_SIZE" > vars
		;;
	esac

	# Generate a random, alphanumeric identifier of 16 characters for CN and one for server name
	SERVER_CN="cn_$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)"
	# SERVER_NAME="server_$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)"
	echo "set_var EASYRSA_REQ_CN $SERVER_CN" >> vars
	# Create the PKI, set up the CA, the DH params and the server certificate
	./easyrsa init-pki
	./easyrsa --batch build-ca nopass

	if [[ $DH_TYPE == "DH" ]]; then
		# ECDH keys are generated on-the-fly so we don't need to generate them beforehand
		openssl dhparam -out dh.pem $DH_KEY_SIZE
	fi
	
	./easyrsa build-server-full "$SERVER_NAME" nopass
	EASYRSA_CRL_DAYS=3650 ./easyrsa gen-crl
	
	# Create server files directory
	mkdir -p /etc/openvpn/$SERVER_NAME

	case $TLS_SIG in
		"tls-crypt")
			# Generate tls-crypt key
			openvpn --genkey --secret /etc/openvpn/$SERVER_NAME/tls-crypt.key
		;;
		"tls-auth")
			# Generate tls-auth key
			openvpn --genkey --secret /etc/openvpn/$SERVER_NAME/tls-auth.key
		;;
	esac
	
	# Move all the generated files
	cp pki/ca.crt pki/private/ca.key "pki/issued/$SERVER_NAME.crt" "pki/private/$SERVER_NAME.key" /etc/openvpn/$SERVER_NAME/easy-rsa/pki/crl.pem /etc/openvpn/$SERVER_NAME
	if [[ $DH_TYPE == "DH" ]]; then
		cp dh.pem /etc/openvpn/$SERVER_NAME/
	fi
	
	# Make cert revocation list readable for non-root
	chmod 644 /etc/openvpn/$SERVER_NAME/crl.pem

	# Generate server.conf
	echo "port $PORT" > /etc/openvpn/$SERVER_NAME/server.conf

	echo "dev tun
user nobody
group $NOGROUP
persist-key
persist-tun
keepalive 10 120
topology subnet
server $SUBNET $SUBNET_MASK
ifconfig-pool-persist ipp.txt" >> /etc/openvpn/$SERVER_NAME/server.conf

	# Needed for systems running systemd-resolved
	if grep -q "127.0.0.53" "/etc/resolv.conf"; then
		RESOLVCONF='/run/systemd/resolve/resolv.conf'
	else
		RESOLVCONF='/etc/resolv.conf'
	fi
	# Obtain the resolvers from resolv.conf and use them for OpenVPN
	grep -v '#' $RESOLVCONF | grep 'nameserver' | grep -E -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | while read -r line; do
		echo "push \"dhcp-option DNS $line\"" >> /etc/openvpn/$SERVER_NAME/server.conf
	done
	echo 'push "redirect-gateway def1 bypass-dhcp"' >> /etc/openvpn/$SERVER_NAME/server.conf

	if [[ $COMPRESSION_ENABLED == "Yes"  ]]; then
		echo "compress $COMPRESSION_ALG" >> /etc/openvpn/$SERVER_NAME/server.conf
	fi

	if [[ $DH_TYPE == "ECDH" ]]; then
		echo "dh none" >> /etc/openvpn/$SERVER_NAME/server.conf
		echo "ecdh-curve $DH_CURVE" >> /etc/openvpn/$SERVER_NAME/server.conf
	elif [[ $DH_TYPE == "DH" ]]; then
		echo "dh dh.pem" >> /etc/openvpn/$SERVER_NAME/server.conf
	fi

	case $TLS_SIG in
		"tls-crypt")
			echo "tls-crypt tls-crypt.key 0" >> /etc/openvpn/$SERVER_NAME/server.conf
		;;
		"tls-auth")
			echo "tls-auth tls-auth.key 0" >> /etc/openvpn/$SERVER_NAME/server.conf
		;;
	esac

	echo "crl-verify crl.pem
ca ca.crt
cert $SERVER_NAME.crt
key $SERVER_NAME.key 
auth $HMAC_ALG
cipher $CIPHER
ncp-ciphers $CIPHER
tls-server
tls-version-min 1.2
tls-cipher $CC_CIPHER
status /var/log/openvpn/"$SERVER_NAME"_status.log 5
verb 3" >> /etc/openvpn/$SERVER_NAME/server.conf

	# Create log dir
	mkdir -p /var/log/openvpn/

	# Enable routing if not already done
    if [ -e "/etc/sysctl.d/20-openvpn.conf" ]; then
        if [ "$(egrep '^net.ipv4.ip_forward=1$' /etc/sysctl.d/20-openvpn.conf | wc -l)" == "0" ]; then
            echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.d/20-openvpn.conf
        fi
    else
        echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.d/20-openvpn.conf
    fi

	# Avoid an unneeded reboot by enabling routing right away
	sysctl --system

	# If SELinux is enabled and a custom port was selected, we need this
	if hash sestatus 2>/dev/null; then
		if sestatus | grep "Current mode" | grep -qs "enforcing"; then
			if [[ "$PORT" != '1194' ]]; then
				proto="$(echo $PROTOCOL | tr '[:upper:]' '[:lower:]')"
				echo "Setting SELinux policy to allow openvpn on $proto port $PORT"
				semanage port -a -t openvpn_port_t -p "$proto" "$PORT"
			fi
		fi
	fi

	# Finally, restart and enable OpenVPN
	if [[ "$OS" = 'arch' || "$OS" = 'fedora' ]]; then
		# Don't modify package-provided service
		cp /usr/lib/systemd/system/openvpn-server@.service /etc/systemd/system/openvpn-server@.service
		
		# Workaround to fix OpenVPN service on OpenVZ
		sed -i 's|LimitNPROC|#LimitNPROC|' /etc/systemd/system/openvpn-server@.service
		# Another workaround to keep using /etc/openvpn/
		sed -i "s|/etc/openvpn/server|/etc/openvpn/$SERVER_NAME|" /etc/systemd/system/openvpn-server_$SERVER_NAME@.service
		# On fedora, the service hardcodes the ciphers. We want to manage the cipher ourselves, so we remove it from the service
		if [[ "$OS" == "fedora" ]];then
			sed -i 's|--cipher AES-256-GCM --ncp-ciphers AES-256-GCM:AES-128-GCM:AES-256-CBC:AES-128-CBC:BF-CBC||' /etc/systemd/system/openvpn-server_$SERVER_NAME@.service
		fi

		systemctl daemon-reload
		systemctl restart openvpn-server@server
		systemctl enable openvpn-server@server
	elif [[ "$OS" == "ubuntu" ]] && [[ "$VERSION_ID" == "16.04" ]]; then
		# On Ubuntu 16.04, we use the package from the OpenVPN repo
		# This package uses a sysvinit service
		systemctl enable openvpn
		systemctl start openvpn
	else
		# Don't modify package-provided service
		cp /lib/systemd/system/openvpn\@.service /etc/systemd/system/openvpn\@.service

        # Set correct working path
        sed -i "s|--cd /etc/openvpn/|--cd /etc/openvpn/%i/|" /etc/systemd/system/openvpn\@.service
        sed -i "s|--config %i.conf|--config server.conf|" /etc/systemd/system/openvpn\@.service

		# Workaround to fix OpenVPN service on OpenVZ
		sed -i 's|LimitNPROC|#LimitNPROC|' /etc/systemd/system/openvpn@.service
		# Another workaround to keep using /etc/openvpn/
		sed -i "s|/etc/openvpn/server|/etc/openvpn/$SERVER_NAME|" /etc/systemd/system/openvpn\@.service
		
		systemctl daemon-reload
		systemctl restart openvpn@$SERVER_NAME
		systemctl enable openvpn@$SERVER_NAME
	fi

	# Add iptables rules in two scripts
	mkdir -p /etc/iptables

    # Get network interface that default gateway is located on
    NIC=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)

	# Script to add rules
	echo "#!/bin/sh
iptables -t nat -A POSTROUTING -s $SUBNET/$SUBNET_MASK -o $NIC -j MASQUERADE
iptables -A INPUT -i tun0 -j ACCEPT
iptables -A FORWARD -i $NIC -o tun0 -j ACCEPT
iptables -A FORWARD -i tun0 -o $NIC -j ACCEPT
iptables -A INPUT -i $NIC -p $PROTOCOL --dport $PORT -j ACCEPT" > /etc/iptables/add-openvpn-rules-$SERVER_NAME.sh

	# Script to remove rules
	echo "#!/bin/sh
iptables -t nat -D POSTROUTING -s $SUBNET/$SUBNET_MASK -o $NIC -j MASQUERADE
iptables -D INPUT -i tun0 -j ACCEPT
iptables -D FORWARD -i $NIC -o tun0 -j ACCEPT
iptables -D FORWARD -i tun0 -o $NIC -j ACCEPT
iptables -D INPUT -i $NIC -p $PROTOCOL --dport $PORT -j ACCEPT" > /etc/iptables/rm-openvpn-rules-$SERVER_NAME.sh

	chmod +x /etc/iptables/add-openvpn-rules-$SERVER_NAME.sh
	chmod +x /etc/iptables/rm-openvpn-rules-$SERVER_NAME.sh

	# Handle the rules via a systemd script
	echo "[Unit]
Description=iptables rules for OpenVPN server $SERVER_NAME
Before=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/etc/iptables/add-openvpn-rules-$SERVER_NAME.sh
ExecStop=/etc/iptables/rm-openvpn-rules-$SERVER_NAME.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/iptables-openvpn-$SERVER_NAME.service

	# Enable service and apply rules
	systemctl daemon-reload
	systemctl enable iptables-openvpn-$SERVER_NAME
	systemctl start iptables-openvpn-$SERVER_NAME

	# Create clients directory for server
	mkdir -p /etc/openvpn/$SERVER_NAME/clients/

	# client-template.txt is created so we have a template to add further users later
	echo "client" > /etc/openvpn/$SERVER_NAME/client-template.txt
	if [[ "$PROTOCOL" = 'udp' ]]; then
		echo "proto udp" >> /etc/openvpn/$SERVER_NAME/client-template.txt
	elif [[ "$PROTOCOL" = 'tcp' ]]; then
		echo "proto tcp-client" >> /etc/openvpn/$SERVER_NAME/client-template.txt
	fi
	echo "remote $PUBLICIP $PORT
dev tun
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
verify-x509-name $SERVER_NAME name
auth $HMAC_ALG
auth-nocache
cipher $CIPHER
tls-client
tls-version-min 1.2
tls-cipher $CC_CIPHER
setenv opt block-outside-dns # Prevent Windows 10 DNS leak
verb 3" >> /etc/openvpn/$SERVER_NAME/client-template.txt

if [[ $COMPRESSION_ENABLED == "y"  ]]; then
	echo "compress $COMPRESSION_ALG" >> /etc/openvpn/$SERVER_NAME/client-template.txt
fi
}

function newClient () {
	echo ""
	echo "Tell me a name for the client."
	echo "Use one word only, no special characters."

	if [ -z "$SERVER_NAME" ]; then
		echo "Error: No SERVER_NAME speficied. Exiting!"
		exit 1
	fi
	if [ -z "$CLIENT_NAME" ]; then
		echo "Error: No CLIENT_NAME speficied. Exiting!"
		exit 1
	fi

	echo ""
	echo "Do you want to protect the configuration file with a password?"
	echo "(e.g. encrypt the private key with a password)"
	echo "   1) Add a passwordless client"
	echo "   2) Use a password for the client"

	until [[ "$PASS" =~ ^[1-2]$ ]]; do
		read -rp "Select an option [1-2]: " -e -i 1 PASS
	done

	cd /etc/openvpn/$SERVER_NAME/easy-rsa/ || return
	case $PASS in
		1)
			./easyrsa build-client-full "$CLIENT" nopass
		;;
		2)
		echo "⚠️ You will be asked for the client password below ⚠️"
			./easyrsa build-client-full "$CLIENT"
		;;
	esac

	# Home directory of the user, where the client configuration (.ovpn) will be written
	if [ -e "/home/$CLIENT" ]; then  # if $1 is a user name
		homeDir="/home/$CLIENT"
	elif [ "${SUDO_USER}" ]; then   # if not, use SUDO_USER
		homeDir="/home/${SUDO_USER}"
	else  # if not SUDO_USER, use /root
		homeDir="/root"
	fi

	# Determine if we use tls-auth or tls-crypt
	if grep -qs "^tls-crypt" /etc/openvpn/$SERVER_NAME/server.conf; then
		TLS_SIG="1"
	elif grep -qs "^tls-auth" /etc/openvpn/$SERVER_NAME/server.conf; then
		TLS_SIG="2"
	fi

	# Generates the custom client.ovpn
	cp /etc/openvpn/client-template.txt "$homeDir/$CLIENT.ovpn"
	{
		echo "<ca>"
		cat "/etc/openvpn/easy-rsa/pki/ca.crt"
		echo "</ca>"

		echo "<cert>"
		awk '/BEGIN/,/END/' "/etc/openvpn/easy-rsa/pki/issued/$CLIENT.crt"
		echo "</cert>"

		echo "<key>"
		cat "/etc/openvpn/easy-rsa/pki/private/$CLIENT.key"
		echo "</key>"

		case $TLS_SIG in
			1)
				echo "<tls-crypt>"
				cat /etc/openvpn/tls-crypt.key
				echo "</tls-crypt>"
			;;
			2)
				echo "key-direction 1"
				echo "<tls-auth>"
				cat /etc/openvpn/tls-auth.key
				echo "</tls-auth>"
			;;
		esac
	} >> "$homeDir/$CLIENT.ovpn"

	echo ""
	echo "Client $CLIENT added, the configuration file is available at $homeDir/$CLIENT.ovpn."
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
CreateServer

# # Check if OpenVPN is already installed
# if [[ -e /etc/openvpn/$SERVER_NAME/server.conf ]]; then
# 	manageMenu
# else
# 	installOpenVPN
# fi