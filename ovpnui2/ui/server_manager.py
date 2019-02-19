import os
import subprocess

class Server:
    
    def __init__(self, name):
        # Get all the values from the server.conf file
        self.NAME = name
        self.PATH = '/etc/openvpn/%s' % self.NAME
        self.CONFIG_PATH = '%s/server.conf' % self.PATH
        self.SERVICE_NAME = 'openvpn@%s' % self.NAME
        self.read_config()

        self.PROTOCOL = str(self.get_value('proto', 'UDP')).upper()


        self.STATUS = self.get_status()
        if type(self.CONFIG['status']) == str:
            self.STATUS_LOG_PATH = self.CONFIG['status']
        else:
            self.STATUS_LOG_PATH = self.CONFIG['status'][0]
        self.CONFIG['local'] = self.get_bind_address()
        self.gather_status_info()
        self.gather_clients()
    
    def get_value(self, name, default=None):
        if name in self.CONFIG:
            return self.CONFIG[name]
        else:
            return default
    
    def read_config(self):
        self.CONFIG = {}
        with open(self.CONFIG_PATH, 'r') as f:
            for line in f:
                name, value = self.process_argument(line)
                self.CONFIG[name] = value

    def process_argument(self, argument_line):
        split = argument_line.strip().split(" ")
        if len(split) == 1:
            return [split[0], True]
        elif len(split) == 2:
            return split
        elif len(split) > 2:
            name = split[0]
            split.remove(name)
            return [name, split]
    
    # Go though status log file for connected clients and gather their data
    def gather_status_info(self):
        self.CONNECTED_CLIENTS = list()
        if os.path.isfile(self.STATUS_LOG_PATH):
            with open(self.STATUS_LOG_PATH) as f:
                # Read mode 1: first part of status file
                # Read mode 2: second part of status file
                read_mode = 1
                for line in f.readlines()[3:]:
                    if line.strip() == "ROUTING TABLE":
                        read_mode = 2
                        continue
                    split = line.strip().split(',')
                    if read_mode == 1:
                        self.CONNECTED_CLIENTS.append({
                            'name': split[0],
                            'sourceip': split[1],
                            'recived': split[2],
                            'sent': split[3],
                            'connected': split[4],
                        })
                    elif read_mode == 2:
                        if len(split) > 2:
                            for client in self.CONNECTED_CLIENTS:
                                if client['sourceip'] == split[2]:
                                    client['virtualip'] = split[0]
        else:
            print("ERROR! Status log file '%s' does not exist!" % self.STATUS_LOG_PATH)
    
    def get_status(self):
        output = subprocess.getoutput("systemctl is-active %s" % self.SERVICE_NAME)
        return output

    def restart(self):
        subprocess.getoutput("systemctl restart %s" % self.SERVICE_NAME)
    
    def get_bind_address(self):
        if "local" in self.CONFIG:
            return self.CONFIG['local']
        else:
            return "0.0.0.0"
    
    def gather_clients(self):
        self.CLIENTS = list()
        for item in os.listdir("/etc/openvpn/%s/clients/" % self.NAME):
            if os.path.isfile("/etc/openvpn/%s/clients/%s" % (self.NAME, item)):
                self.CLIENTS.append(item[:-5])


def get_servers():
    servers = list()
    for item in os.listdir('/etc/openvpn/'):
        if os.path.isdir("/etc/openvpn/%s" % item):
            servers.append(Server(item))
    return servers

def get_servers_named():
    servers = {}
    for item in os.listdir('/etc/openvpn/'):
        if os.path.isdir("/etc/openvpn/%s" % item):
            server = Server(item)
            servers[server.NAME] = server
    return servers