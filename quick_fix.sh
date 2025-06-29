#!/bin/bash

echo "Quick Fix for TR-069 ACS Not Found Issue"
echo "========================================"

# Navigate to app directory
cd /opt/tr069/app

# Fix git ownership
sudo git config --global --add safe.directory /opt/tr069/app

# Pull latest changes
git pull origin main

# Check if ACS directory exists
if [ ! -d "acs" ]; then
    echo "ERROR: ACS directory does not exist!"
    exit 1
fi

# Check if key ACS files exist
echo "Checking ACS files..."
ls -la acs/

# Create missing files
sudo -u www-data touch acs/__init__.py
sudo -u www-data mkdir -p acs/migrations
sudo -u www-data touch acs/migrations/__init__.py

# Create apps.py
echo "Creating acs/apps.py..."
sudo -u www-data cat > acs/apps.py << 'EOF'
from django.apps import AppConfig


class AcsConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'acs'
    verbose_name = 'TR-069 ACS'
EOF

# Check current INSTALLED_APPS
echo "Current INSTALLED_APPS:"
grep -A 20 "INSTALLED_APPS" tr069_portal/settings.py

# Add ACS to INSTALLED_APPS if not present
if ! grep -q "'acs'" tr069_portal/settings.py; then
    echo "Adding ACS to INSTALLED_APPS..."
    sudo cp tr069_portal/settings.py tr069_portal/settings.py.backup
    sudo sed -i "/# Local apps/a\\    'acs'," tr069_portal/settings.py
    echo "ACS added to INSTALLED_APPS"
else
    echo "ACS is already in INSTALLED_APPS"
fi

# Show updated INSTALLED_APPS
echo "Updated INSTALLED_APPS:"
grep -A 20 "INSTALLED_APPS" tr069_portal/settings.py

# Test if Django can import ACS
echo "Testing Django ACS import..."
sudo -u www-data /opt/tr069/app/venv/bin/python -c "
import os
import sys
sys.path.append('/opt/tr069/app')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'tr069_portal.settings')

import django
django.setup()

try:
    from acs.models import DeviceInform
    print('✓ ACS models imported successfully')
except ImportError as e:
    print(f'✗ ACS import failed: {e}')
"

# Run migrations
echo "Running migrations..."
sudo -u www-data /opt/tr069/app/venv/bin/python manage.py makemigrations acs
sudo -u www-data /opt/tr069/app/venv/bin/python manage.py migrate

# Check URL patterns
echo "Checking URL patterns..."
sudo -u www-data /opt/tr069/app/venv/bin/python manage.py shell -c "
from django.urls import get_resolver
resolver = get_resolver()
print('Available URL patterns:')
for pattern in resolver.url_patterns:
    print(f'  {pattern}')
"

# Fix permissions
sudo chown -R www-data:www-data /opt/tr069/app

# Restart services
echo "Restarting services..."
sudo systemctl stop tr069
sudo rm -f /opt/tr069/tr069.sock
sudo systemctl start tr069
sleep 3
sudo systemctl reload nginx

# Test endpoints
echo "Testing endpoints..."

# Main app
main_test=$(curl -s -I http://localhost/ | head -1)
echo "Main app: $main_test"

# ACS dashboard
acs_test=$(curl -s -I http://localhost/acs/dashboard/ | head -1)
echo "ACS dashboard: $acs_test"

# TR-069 endpoint
tr069_test=$(curl -s -I http://localhost/acs/tr069/ | head -1)
echo "TR-069 endpoint: $tr069_test"

# Service status
echo "Service status:"
sudo systemctl is-active tr069 && echo "TR069 service: RUNNING" || echo "TR069 service: FAILED"
sudo systemctl is-active nginx && echo "Nginx service: RUNNING" || echo "Nginx service: FAILED"

echo "Quick fix completed!"
echo "TR-069 endpoint should now be available at: http://18.142.243.199/acs/tr069/" 