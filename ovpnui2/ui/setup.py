from django.shortcuts import render, redirect

# Create your views here.

from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.decorators import login_required
from django.contrib.auth.models import User

from ui.models import Settings

from . import utils
from . import settings
from . import enums
from . import backend


def index(request):
    if request.method == "GET":
        return render(request, "setup_index.html")
    elif request.method == "POST":
        if request.POST['password'] != request.POST['passwordRepeat']:
            return render(request, "setup_index.html", context={'password_match_failed': True})
        else:
            User.objects.create_user(username=request.POST['username'],
                                 email='',
                                 password=request.POST['password'])
        return redirect("setup_address")

def address(request):
    if request.method == "GET":
        context = {}
        addresses = utils.get_ip_address()
        if utils.is_ip_public_ip(addresses[0]):
            context['public_ip'] = True
        else:
            context['public_ip'] = False
        context['address'] = addresses[0]
        return render(request, "setup_address.html", context=context)
    elif request.method == "POST":
        settings.set('public_address', value=request.POST['address'])
        settings.set('public_port', value=request.POST['port'])
        settings.set('protocol', value=request.POST['protocol'])
        return redirect("setup_general")

def general(request):
    if request.method == "GET":
        return render(request, "setup_general.html")
    elif request.method == "POST":
        settings.set('compression', request.POST['compression'])
        settings.set('compression_alg', request.POST['compression_alg'])
        settings.set('digest_alg', request.POST['digest_alg'])
        settings.set('curve', request.POST['curve'])
        settings.set('dh_type', request.POST['dh_type'])
        settings.set('cert_type', request.POST['cert_type'])
        settings.set('tls_sig', request.POST['tls_sig'])
        settings.set('cipher', request.POST['cipher'])
        settings.set('control_channel', request.POST['control_channel'])
        settings.set('rsa_size', request.POST['rsa_size'])
        settings.set('ecdh_curve_type', request.POST['ecdh_curve_type'])
        return render(request, "setup_general.html")