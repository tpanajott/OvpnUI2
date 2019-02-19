import subprocess

# Get a list of current IP addresses to this machine
def get_ip_address():
    data = subprocess.getoutput("ip addr | egrep -oe 'inet [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}.[0-9]{1,3}'")
    addresses = list()
    for line in data.splitlines():
        cleaned_address = line.replace("inet ", "").strip()
        if cleaned_address.startswith("127."):
            pass
        else:
            addresses.append(cleaned_address)
    return addresses

def is_ip_public_ip(address):
    if address.startswith("10."):
        return False
    elif address.startswith("172.1") or address.startswith("172.2"):
        return False
    elif address.startswith("192.168."):
        return False
    return True
