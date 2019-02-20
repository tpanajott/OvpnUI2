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