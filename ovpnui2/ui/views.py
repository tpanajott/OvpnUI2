from django.shortcuts import render, redirect

# Create your views here.

from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.decorators import login_required

import os
from . import server_manager

from . import enums
from . import backend

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
def new_ca_view(request):
    if request.method == "GET":
        return render(request, 'new_ca.html', context={
            'countries': enums.COUNTRY_CHOICES
        })
    elif request.method == "POST":
        # backend.create_new_ca(values=request.POST)

        return render(request, 'new_ca.html', context={
            'countries': enums.COUNTRY_CHOICES
        })

@login_required
def cas_view(request):
    return render(request, 'cas.html', context={
        'cas': backend.get_cas()
    })

@login_required
def new_server_view(request):
    return render(request, 'cas.html', context={
        'cas': backend.get_cas()
    })

@login_required
def servers_view(request):
    servers = server_manager.get_servers()
    return render(request, 'servers.html', context={
        'servers': servers
    })

@login_required
def server_view(request, SERVER_NAME):
    servers = server_manager.get_servers_named()
    return render(request, 'view_server.html', context={
        'server': servers[SERVER_NAME]
    })