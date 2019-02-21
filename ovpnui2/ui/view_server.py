from django.shortcuts import render, redirect

# Create your views here.

from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.decorators import login_required
from django.contrib.auth.models import User

from django.http import HttpResponse
from django.http import HttpResponseNotFound

import subprocess
import sys
import os


from . import utils
from . import enums
from . import backend

@login_required
def new(request):
    if request.method == "GET":
        address1 = utils.get_ip_address()[0]
        is_public_ip = utils.is_ip_public_ip(address1)
        context = {
            'PUBLICIP': address1,
            'ISPUBLICIP': is_public_ip,
            'title': 'Create Server'
        }
        return render(request, "create_new_server.html", context=context)
    elif request.method == "POST":
        env = request.POST.copy()
        # Load all fields and set an environment variable to its value
        for item, value in os.environ.items():
            if (item not in env):
                env[item] = value
        print("Creating new server: %s" % env['SERVER_NAME'])
        new_server_script = "%s/helpers/create_new_server.sh" % os.path.dirname(os.path.realpath(__file__))
        p = subprocess.Popen(new_server_script, env=env)
        p.communicate()
        return redirect("servers")

@login_required
def new_client(request, SERVER_NAME):
    if request.method == "GET":
        # Get subdirectories ie. servers in /etc/openvpn directory
        servers = list()
        for item in os.listdir('/etc/openvpn/'):
            if os.path.isdir("/etc/openvpn/%s" % item):
                servers.append(item)
        context = {
            'SERVER_NAME': SERVER_NAME,
            'SERVERS': servers,
            'title': "New Client @ %s" % SERVER_NAME
        }
        return render(request, "create_new_client.html", context=context)
    elif request.method == "POST":
        env = request.POST.copy()
        for item, value in os.environ.items():
            if (item not in env):
                env[item] = value
        print("Creating new client: %s" % env['CLIENT_NAME'])
        new_server_script = "%s/helpers/create_new_client.sh" % os.path.dirname(os.path.realpath(__file__))
        p = subprocess.Popen(new_server_script, env=env)
        p.communicate()
        return redirect("view_server", env['SERVER_NAME'])

@login_required
def download_client(request, SERVER_NAME, CLIENT):
    file_path = "/etc/openvpn/%s/clients/%s.ovpn" % (SERVER_NAME, CLIENT)
    print("Downloading client config from '%s'" % file_path)
    if os.path.exists(file_path):
        with open(file_path, 'rb') as fh:
            response = HttpResponse(fh.read(), content_type="application/openvpn")
            response['Content-Disposition'] = 'inline; filename=' + "%s_%s.ovpn" % (SERVER_NAME, CLIENT)
            return response
    return HttpResponseNotFound('<h1>Client configuration not found!</h1>')

@login_required
def delete(request, SERVER_NAME):
    print("Deleting server '%s'" % SERVER_NAME)
    new_server_script = "%s/helpers/delete_server.sh" % os.path.dirname(os.path.realpath(__file__))
    env = request.POST.copy()
    env['SERVER_NAME'] = SERVER_NAME
    p = subprocess.Popen(new_server_script, env=env)
    p.communicate()
    return redirect("servers")


@login_required
def stop(request, SERVER_NAME):
    print("Stopping server '%s'" % SERVER_NAME)
    new_server_script = "%s/helpers/stop_disable_server.sh" % os.path.dirname(os.path.realpath(__file__))
    env = request.POST.copy()
    env['SERVER_NAME'] = SERVER_NAME
    p = subprocess.Popen(new_server_script, env=env)
    p.communicate()
    return redirect("servers")


@login_required
def start(request, SERVER_NAME):
    print("Starting server '%s'" % SERVER_NAME)
    new_server_script = "%s/helpers/start_enable_server.sh" % os.path.dirname(os.path.realpath(__file__))
    env = request.POST.copy()
    env['SERVER_NAME'] = SERVER_NAME
    p = subprocess.Popen(new_server_script, env=env)
    p.communicate()
    return redirect("servers")