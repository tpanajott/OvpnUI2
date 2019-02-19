#!/bin/bash

# Many thankes to "Michael Albert" and his blog,
# Specificly https://michlstechblog.info/blog/openvpn-built-a-certification-authority-from-scratch-with-openssl/
# For his information on settings up OpenVPN certificates from scrach without EasyRSA

echo "Building new CA in ${CA_ROOT_DIR}"

# Create base directories
mkdir -p "${CA_ROOT_DIR}"
mkdir -p "${CA_COMMON_DIR}"
mkdir -p "${CA_CLIENTS_DIR}"
mkdir -p "${CA_SERVER_DIR}"

# Create database index
touch "${CA_COMMON_DIR}/index.txt"

# Create first serial
echo 1 > "${CA_COMMON_DIR}/serial"


# Create OpenVPN config file
cat > $OPENSSL_CONF <<EOF
dir                 = .

[ ca ]
default_ca      = ${CA_NAME}            # The default ca section

####################################################################
[ $CA_NAME ]

# dir             = ./CA              # Where everything is kept
dir             = ${CA_ROOT_DIR}
certs           = ${CA_CERTS_DIR}            # Where the issued certs are kept
crl_dir         = ${CA_COMMON_DIR}             # Where the issued crl are kept
database        = ${CA_COMMON_DIR}/index.txt        # database index file.
#unique_subject = no                    # Set to 'no' to allow creation of
                                        # several ctificates with same subject.
new_certs_dir   = ${CA_CERTS_DIR}/newcerts         # default place for new certs.

certificate     = ${CA_COMMON_DIR}/ca.cer       # The CA certificate
serial          = ${CA_COMMON_DIR}/serial           # The current serial number
# crlnumber       = \$dir/crlnumber        # the current crl number
                                        # must be commented out to leave a V1 CRL
crl             = ${CA_COMMON_DIR}/crl.pem          # The current CRL
private_key     = ${CA_COMMON_DIR}/ca.key    # The private key
RANDFILE        = ${CA_COMMON_DIR}/.rand    # private random number file

default_days    = ${CERTIFICATE_LIFETIME}                  # how long to certify for
default_crl_days= 30                    # how long before next CRL
default_md  = default                   # use public key default MD
preserve    = no                        # keep passed DN ordering
policy      = policy_match

[ policy_match ]
countryName                 = match
stateOrProvinceName         = match
organizationName            = match
organizationalUnitName      = optional
commonName                  = supplied
emailAddress                = optional

[ req ]
default_bits                = ${KEY_BITSIZE}          # Size of keys
default_keyfile             = key.pem       # name of generated keys
default_md                  = sha256        # message digest algorithm
string_mask                 = nombstr       # permitted characters
distinguished_name          = req_distinguished_name
req_extensions              = v3_req

[ req_distinguished_name ]
# Variable name               Prompt string
#-------------------------    ----------------------------------
0.organizationName          = ${KEY_ORG}
organizationalUnitName      = ${KEY_ORG}
emailAddress                = ${KEY_EMAIL}
emailAddress_max            = 40
localityName                = ${KEY_COUNTRY}
stateOrProvinceName         = ${KEY_PROVINCE}
countryName                 = ${KEY_COUNTRY}
countryName_min             = 2
countryName_max             = 2
commonName                  = ${KEY_CN}
commonName_max              = 64

# Default values for the above, for consistency and less typing.
# Variable name                 Value
#------------------------       ------------------------------
0.organizationName_default      = ${KEY_ORG}
localityName_default            = ${KEY_PROVINCE}
stateOrProvinceName_default     = ${KEY_PROVINCE}
countryName_default             = ${KEY_COUNTRY}

[ v3_server ]
basicConstraints       = CA:FALSE
nsCertType             = server
nsComment              = "Server Certificate for $CA_NAME"
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid,issuer:always
extendedKeyUsage       = serverAuth
keyUsage               = digitalSignature, keyEncipherment

[ v3_client ]
basicConstraints       = CA:FALSE
nsComment              = "Client Certificate for $CA_NAME"
nsCertType             = client
extendedKeyUsage       = clientAuth

[ v3_ca ]
basicConstraints                = CA:TRUE
subjectKeyIdentifier            = hash
authorityKeyIdentifier          = keyid:always,issuer:always

[ v3_req ]
basicConstraints                = CA:FALSE
subjectKeyIdentifier            = hash

EOF

# Create self-signed CA
$OPENSSL_BIN req -new -x509 -days ${CERTIFICATE_LIFETIME} -extensions v3_ca -newkey rsa:${KEY_BITSIZE} -keyout "${CA_COMMON_DIR}/ca.key" -out "${CA_COMMON_DIR}/ca.cer" -batch  -passout pass:"$CA_PASSWORD"

echo "---- Reached target 1 -----"

# Create server .key
$OPENSSL_BIN genrsa -out "${CA_SERVER_DIR}/server.key" ${KEY_BITSIZE} -aes256

echo "---- Reached target 2 -----"

# Create signing request for server
$OPENSSL_BIN req -nodes -new -key "${CA_SERVER_DIR}/server.key" -out "${CA_SERVER_DIR}/server.req" -extensions v3_server -batch -subj "/C=$KEY_COUNTRY/ST=$KEY_PROVINCE/L=$KEY_CITY/O=$KEY_ORG/OU=$KEY_OU/CN=$KEY_CN/emailAddress=$KEY_EMAIL"

echo "---- Reached target 3 -----"

# Sign the server certificate
$OPENSSL_BIN x509 -req -days ${CERTIFICATE_LIFETIME} -extfile $OPENSSL_CONF -extensions v3_server -in "${CA_SERVER_DIR}/server.req" -CA "${CA_COMMON_DIR}/ca.cer" -CAkey "${CA_COMMON_DIR}/ca.key" -CAcreateserial -out "${CA_SERVER_DIR}/server.cer" -passin pass:"$CA_PASSWORD"

echo "---- Reached target 4 -----"

## Check if x509v3 extension is set
# $OPENSSL_BIN x509 -text -in "${CA_SERVER_DIR}/server.cer"|grep "X509v3 extensions" -A 15

$OPENSSL_BIN pkcs12 -password pass:"" -export -in "${CA_SERVER_DIR}/server.cer" -inkey "${CA_SERVER_DIR}/server.key" -certfile "${CA_COMMON_DIR}/ca.cer" -out "${CA_SERVER_DIR}/server.p12"

echo "---- Reached target 5 -----"

# Generate CRL
$OPENSSL_BIN ca -gencrl -out ${CA_CRL} -passin pass:$CA_PASSWORD

echo "---- Reached target 6 -----"

# Generate diffe-hellman key
$OPENSSL_BIN dhparam -outform PEM -out "${CA_COMMON_DIR}/dh.pem" $DH_KEYSIZE

echo "---- Reached target 7 -----"

# Generate ta.key
$OPENVPN_BIN --genkey --secret "${CA_COMMON_DIR}/ta.key"

echo "---- Reached target 8 -----"