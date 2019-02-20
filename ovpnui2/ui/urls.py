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
    path('servers', views.servers_view, name='servers'),
    path('servers/<str:SERVER_NAME>', views.server_view, name='view_server'),
    path('servers/<str:SERVER_NAME>/clients/download/<str:CLIENT>', view_server.download_client, name='download_client'),
    path('servers/<str:SERVER_NAME>/new_client', view_server.new_client, name='new_client'),
    path('servers/<str:SERVER_NAME>/delete', view_server.delete, name='delete_server'),
    path('servers/<str:SERVER_NAME>/start', view_server.start, name='start_server'),
    path('servers/<str:SERVER_NAME>/stop', view_server.stop, name='stop_server'),
    path('new_server', view_server.new, name='new_server'),
    path('setup/index', setup.index, name='setup_index'),
]