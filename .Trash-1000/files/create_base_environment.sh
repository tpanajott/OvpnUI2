#!/bin/bash
# This script will setup the base directories and all things expected by the other scripts

echo "Creating base environment for OpenVPN UI 2"

mkdir -p $CA_ROOT_DIR
mkdir -p $CA_CERTS_DIR
mkdir -p $CA_COMMON_DIR
mkdir -p $CA_CLIENTS_DIR
mkdir -p $CA_SERVER_DIR

echo "Done!"