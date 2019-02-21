from django.shortcuts import render, redirect

# Create your views here.

from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.decorators import login_required

import os
from . import server_manager

def login_view(request):
    if request.method == "GET":
        return render(request, "login.html")
    elif request.method == "POST":
        user = authenticate(username=request.POST['username'], password=request.POST['password'])
        if user is not None:
            login(request, user)
            return redirect('home')
        else:
            return render(request, "login.html", context={'login_failed': True})

@login_required
def logout_view(request):
    logout(request)
    return redirect('login')

@login_required
def index_view(request):
    return render(request, 'index.html')

@login_required
def servers_view(request):
    servers = server_manager.get_servers()
    return render(request, 'servers.html', context={
        'title': 'Servers',
        'servers': servers
    })

@login_required
def server_view(request, SERVER_NAME):
    servers = server_manager.get_servers_named()
    return render(request, 'view_server.html', context={
        'title': SERVER_NAME,
        'server': servers[SERVER_NAME]
    })