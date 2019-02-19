import subprocess
import os

from . import models

def get_openssl():
    output = subprocess.check_output(['which', 'openssl'])
    return output.decode('utf-8').strip()

def get_openvpn():
    output = subprocess.check_output(['which', 'openvpn'])
    return output.decode('utf-8').strip()

# Will create a base dictionary with environment variables to be used
def get_base_environment(values={}):
    return_dict = {}

    return_dict['CA_ROOT_DIR'] = '/openvpn/%s/cas' % values['name']
    return_dict['CA_CERTS_DIR'] = '/openvpn/%s/certs' % values['name']
    return_dict['CA_COMMON_DIR'] = '/openvpn/%s/common' % values['name']
    return_dict['CA_CLIENTS_DIR'] = '/openvpn/%s/clients' % values['name']
    return_dict['CA_SERVER_DIR'] = '/openvpn/%s/servers' % values['name']

    return_dict['OPENSSL_BIN'] = get_openssl()
    return_dict['OPENSSL_CONF'] = '%s/openssl.conf' % return_dict['CA_ROOT_DIR']
    return_dict['OPENSSL_CONF_X509_V3_EXT_SERVER'] = '%s/x509v3_server_%s.ext' % (return_dict['CA_COMMON_DIR'], values['name'])
    return_dict['OPENSSL_CONF_X509_V3_EXT_CLIENT'] = '%s/x509v3_client_%s.ext' % (return_dict['CA_COMMON_DIR'], values['name'])

    return_dict['KEY_BITSIZE'] = '4096'
    return_dict['DH_KEYSIZE'] = '2048'

    return_dict['CERTIFICATE_LIFETIME'] = '3650'
    
    return_dict['OPENVPN_BIN'] = get_openvpn()
    return_dict['OPENVPN_CONF'] = '%s/openvpn.conf' % return_dict['CA_ROOT_DIR']

    return_dict['CA_NAME'] = values['name']
    return_dict['CA_PASSWORD'] = 'password'
    return_dict['CA_CRL'] = '%s/crl_%s.pem' % (return_dict['CA_COMMON_DIR'], values['name'])

    return_dict['KEY_CN'] = values['name']
    return_dict['KEY_COUNTRY'] = values['country']
    return_dict['KEY_PROVINCE'] = values['province']
    return_dict['KEY_CITY'] = values['city']
    return_dict['KEY_ORG'] = values['organization']
    return_dict['KEY_OU'] = values['organization_unit']
    return_dict['KEY_EMAIL'] = values['email']

    for key,value in values.items():
        return_dict[key] = value

    return return_dict

def setup_base_environment(environment):
    dir_path = os.path.dirname(os.path.realpath(__file__))  # Current path
    proc = subprocess.Popen(['/bin/bash', 'create_base_environment.sh'],env=environment , cwd='%s/helpers/' % dir_path)
    proc.wait()

def create_base_ca(environment):
    dir_path = os.path.dirname(os.path.realpath(__file__))  # Current path
    proc = subprocess.Popen(['/bin/bash', 'create_base_ca.sh'], env=environment, cwd='%s/helpers/' % dir_path)
    proc.wait()

def create_new_ca(values):
    environment = get_base_environment(values)
    setup_base_environment(environment)
    create_base_ca(environment)

def get_cas():
    cas = list()
    for ca in os.listdir('/openvpn'):
        cas.append(ca)
    return cas