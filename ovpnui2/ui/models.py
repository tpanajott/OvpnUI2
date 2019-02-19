from django.db import models

# Create your models here.

class Server(models.Model):
    id = models.AutoField(primary_key=True)
    name = models.CharField(max_length=200, default='OpenVPN')
    listen_ip = models.CharField(max_length=20, default='0.0.0.0')
    listen_port = models.IntegerField(default=1194)
    path = models.CharField(max_length=200, default='-')
    service_name = models.CharField(max_length=200, default='-')

class Settings(models.Model):
    id = models.AutoField(primary_key=True)
    name = models.CharField(max_length=200, default='')
    value = models.CharField(max_length=5000, default='')