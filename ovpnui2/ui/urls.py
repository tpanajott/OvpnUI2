from django.contrib import admin
from django.urls import path, include
from django.views.generic.base import RedirectView

from . import views
from . import setup
from . import view_server

urlpatterns = [
    path('', RedirectView.as_view(url='servers'), name='login'),
    path('login', views.login_view, name='login'),
    path('logout', views.logout_view, name='logout'),
    path('home', views.index_view, name='home'),
    path('new_ca', views.new_ca_view, name='new_ca'),
    path('cas', views.cas_view, name='cas'),
    path('new_ca', views.new_server_view, name='new_server'),
    path('servers', views.servers_view, name='servers'),
    path('servers/<str:SERVER_NAME>', views.server_view, name='view_server'),
    path('servers/<str:SERVER_NAME>/clients', view_server.clients, name='server_clients'),
    path('servers/<str:SERVER_NAME>/clients/download/<str:CLIENT>', view_server.download_client, name='download_client'),
    path('new_server', view_server.new, name='new_server'),
    path('servers/<str:SERVER_NAME>/new_client', view_server.new_client, name='new_client'),
    path('setup/index', setup.index, name='setup_index'),
]