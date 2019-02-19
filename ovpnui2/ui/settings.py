from ui.models import Settings

# Will create or update an existsting setting with the value specified
def set(name, value):
    if exists(name):
        setting = Settings.objects.all().filter(name=name).first()
        setting.value = value
        setting.save()
    else:
        setting = Settings(name=name, value=value)
        setting.save()

# Get the value of a setting
def get(name, default):
    if exists(name):
        setting = Settings.objects.all().filter(name=name).first()
        return setting.value
    else:
        return default

# Checks if the setting exists
def exists(name):
    exists = Settings.objects.all().filter(name=name).exists()
    return exists