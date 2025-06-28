"""WSGI config for tr069_portal project."""

import os
from django.core.wsgi import get_wsgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'tr069_portal.settings')

application = get_wsgi_application() 