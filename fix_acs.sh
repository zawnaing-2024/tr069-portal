#!/bin/bash

echo "Fixing ACS App Installation..."

# Navigate to app directory
cd /opt/tr069/app

# Create ACS apps.py if missing
if [ ! -f "acs/apps.py" ]; then
    echo "Creating acs/apps.py..."
    sudo -u www-data cat > acs/apps.py << 'EOF'
from django.apps import AppConfig


class AcsConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'acs'
    verbose_name = 'TR-069 ACS'
EOF
fi

# Create migrations directory
sudo -u www-data mkdir -p acs/migrations
sudo -u www-data touch acs/migrations/__init__.py

# Check if ACS is in INSTALLED_APPS
if ! grep -q "'acs'" tr069_portal/settings.py; then
    echo "Adding ACS to INSTALLED_APPS..."
    sudo sed -i "/# Local apps/a\\    'acs'," tr069_portal/settings.py
fi

# Fix permissions
sudo chown -R www-data:www-data acs/

# Test Django configuration
echo "Testing Django configuration..."
sudo -u www-data /opt/tr069/app/venv/bin/python manage.py check

# If check passes, run migrations
if [ $? -eq 0 ]; then
    echo "Running migrations..."
    sudo -u www-data /opt/tr069/app/venv/bin/python manage.py makemigrations acs
    sudo -u www-data /opt/tr069/app/venv/bin/python manage.py migrate
    
    # Restart services
    echo "Restarting services..."
    sudo systemctl restart tr069
    sudo systemctl reload nginx
    
    echo "Testing endpoints..."
    sleep 3
    curl -I http://localhost/acs/tr069/
else
    echo "Django configuration has errors. Please check the output above."
fi 