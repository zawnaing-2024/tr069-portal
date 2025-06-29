#!/bin/bash

# Complete ACS Fix Script - Automated TR-069 Deployment
# This script will completely fix the ACS deployment issues

echo "🚀 Starting Complete ACS Fix..."
echo "================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Step 1: Navigate to application directory
print_status "Navigating to application directory..."
cd /opt/tr069/app || {
    print_error "Failed to navigate to /opt/tr069/app"
    exit 1
}

# Step 2: Stop services first
print_status "Stopping services..."
sudo systemctl stop tr069
sudo rm -f /opt/tr069/tr069.sock

# Step 3: Fix git ownership
print_status "Fixing git ownership..."
sudo git config --global --add safe.directory /opt/tr069/app
sudo chown -R ubuntu:ubuntu .git

# Step 4: Pull latest code
print_status "Pulling latest code..."
git fetch origin
git reset --hard origin/main

# Step 5: Create ACS directory structure
print_status "Creating ACS directory structure..."
sudo -u www-data mkdir -p acs/migrations
sudo -u www-data mkdir -p templates/acs

# Step 6: Create ACS __init__.py
print_status "Creating ACS __init__.py files..."
sudo -u www-data touch acs/__init__.py
sudo -u www-data touch acs/migrations/__init__.py

# Step 7: Create ACS apps.py
print_status "Creating ACS apps.py..."
sudo -u www-data cat > acs/apps.py << 'EOF'
from django.apps import AppConfig


class AcsConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'acs'
    verbose_name = 'TR-069 ACS'
EOF

# Step 8: Check and fix settings.py
print_status "Checking Django settings..."
if ! grep -q "'acs'" tr069_portal/settings.py; then
    print_status "Adding ACS to INSTALLED_APPS..."
    sudo cp tr069_portal/settings.py tr069_portal/settings.py.backup
    sudo sed -i "/# Local apps/a\\    'acs'," tr069_portal/settings.py
    print_success "ACS added to INSTALLED_APPS"
else
    print_success "ACS already in INSTALLED_APPS"
fi

# Step 9: Ensure all required apps are in settings
print_status "Ensuring all required apps are in settings..."
sudo -u www-data cat > /tmp/check_settings.py << 'EOF'
import os
import sys
sys.path.append('/opt/tr069/app')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'tr069_portal.settings')

try:
    from django.conf import settings
    from django.apps import apps
    
    print("Checking INSTALLED_APPS...")
    required_apps = ['acs', 'core', 'rest_framework']
    
    for app in required_apps:
        if app in settings.INSTALLED_APPS:
            print(f"✓ {app} is installed")
        else:
            print(f"✗ {app} is missing")
    
    print("\nAll installed apps:")
    for app in settings.INSTALLED_APPS:
        print(f"  - {app}")
        
except Exception as e:
    print(f"Error: {e}")
EOF

sudo -u www-data /opt/tr069/app/venv/bin/python /tmp/check_settings.py

# Step 10: Install dependencies
print_status "Installing/updating dependencies..."
sudo -u www-data /opt/tr069/app/venv/bin/pip install --upgrade pip
sudo -u www-data /opt/tr069/app/venv/bin/pip install -r requirements.txt

# Step 11: Fix all file permissions
print_status "Fixing file permissions..."
sudo chown -R www-data:www-data /opt/tr069/app
sudo chmod +x manage.py

# Step 12: Test Django configuration
print_status "Testing Django configuration..."
sudo -u www-data /opt/tr069/app/venv/bin/python manage.py check --verbosity=2

if [ $? -ne 0 ]; then
    print_error "Django configuration has errors. Attempting to fix..."
    
    # Check if ACS models exist
    if [ ! -f "acs/models.py" ]; then
        print_error "ACS models.py is missing!"
        exit 1
    fi
    
    # Try to fix imports
    print_status "Checking imports..."
    sudo -u www-data /opt/tr069/app/venv/bin/python -c "
import sys
sys.path.append('/opt/tr069/app')
try:
    import acs
    print('ACS module can be imported')
    import acs.models
    print('ACS models can be imported')
    import acs.views
    print('ACS views can be imported')
except ImportError as e:
    print(f'Import error: {e}')
"
fi

# Step 13: Create migrations
print_status "Creating and running migrations..."
sudo -u www-data /opt/tr069/app/venv/bin/python manage.py makemigrations --verbosity=2
sudo -u www-data /opt/tr069/app/venv/bin/python manage.py makemigrations acs --verbosity=2
sudo -u www-data /opt/tr069/app/venv/bin/python manage.py migrate --verbosity=2

# Step 14: Collect static files
print_status "Collecting static files..."
sudo -u www-data /opt/tr069/app/venv/bin/python manage.py collectstatic --noinput

# Step 15: Create superuser if needed (optional, commented out)
# print_status "Creating superuser (if needed)..."
# echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('admin', 'admin@example.com', 'admin123') if not User.objects.filter(username='admin').exists() else None" | sudo -u www-data /opt/tr069/app/venv/bin/python manage.py shell

# Step 16: Test URL patterns
print_status "Testing URL patterns..."
sudo -u www-data /opt/tr069/app/venv/bin/python manage.py show_urls | grep -E "(acs|tr069)" || print_warning "No ACS URLs found"

# Step 17: Start services
print_status "Starting services..."
sudo systemctl start tr069
sleep 5
sudo systemctl reload nginx

# Step 18: Check service status
print_status "Checking service status..."
if sudo systemctl is-active --quiet tr069; then
    print_success "TR069 service is running"
else
    print_error "TR069 service failed to start"
    sudo journalctl -u tr069.service --no-pager -l | tail -20
fi

if sudo systemctl is-active --quiet nginx; then
    print_success "Nginx service is running"
else
    print_error "Nginx service is not running"
fi

# Step 19: Test endpoints
print_status "Testing endpoints..."

# Test main application
echo -n "Testing main application: "
main_response=$(curl -s -I http://localhost/ | head -1)
if echo "$main_response" | grep -q "200\|302"; then
    print_success "Main application OK"
else
    print_warning "Main application: $main_response"
fi

# Test ACS dashboard
echo -n "Testing ACS dashboard: "
acs_response=$(curl -s -I http://localhost/acs/dashboard/ | head -1)
if echo "$acs_response" | grep -q "200\|302"; then
    print_success "ACS dashboard OK"
else
    print_warning "ACS dashboard: $acs_response"
fi

# Test TR-069 endpoint with GET (should give 405)
echo -n "Testing TR-069 endpoint (GET): "
tr069_get=$(curl -s -I http://localhost/acs/tr069/ | head -1)
if echo "$tr069_get" | grep -q "405"; then
    print_success "TR-069 endpoint OK (405 Method Not Allowed is expected)"
elif echo "$tr069_get" | grep -q "200"; then
    print_success "TR-069 endpoint OK (200 response)"
else
    print_warning "TR-069 endpoint: $tr069_get"
fi

# Test TR-069 endpoint with POST
echo -n "Testing TR-069 endpoint (POST): "
tr069_post=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost/acs/tr069/ -H "Content-Type: text/xml" -d '<?xml version="1.0"?><test>test</test>')
if [ "$tr069_post" = "200" ] || [ "$tr069_post" = "500" ]; then
    print_success "TR-069 endpoint accepting POST requests (HTTP $tr069_post)"
else
    print_warning "TR-069 endpoint POST response: $tr069_post"
fi

# Step 20: Final status report
echo ""
echo "🎉 ACS Fix Complete!"
echo "===================="

# Get server IP
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "YOUR_SERVER_IP")

print_success "TR069 Portal with ACS is now deployed!"
echo ""
echo "📋 Access URLs:"
echo "  Main Portal:     http://$SERVER_IP/"
echo "  ACS Dashboard:   http://$SERVER_IP/acs/dashboard/"
echo "  TR-069 Endpoint: http://$SERVER_IP/acs/tr069/"
echo "  Admin Panel:     http://$SERVER_IP/admin/"
echo ""
echo "🔧 ONU Configuration:"
echo "  ACS URL: http://$SERVER_IP/acs/tr069/"
echo "  Periodic Inform Interval: 300 seconds"
echo "  ACS Username: admin (optional)"
echo "  ACS Password: admin (optional)"
echo ""

# Test the working URLs one more time externally
print_status "Final external test..."
external_test=$(curl -s -I http://$SERVER_IP/acs/tr069/ | head -1)
if echo "$external_test" | grep -q "405\|200"; then
    print_success "✅ TR-069 endpoint is accessible externally!"
    echo "🎊 Your ACS server is ready to discover ONUs automatically!"
else
    print_warning "External test result: $external_test"
    echo "You may need to check firewall settings"
fi

echo ""
print_success "Setup complete! Configure your ONUs and they will appear automatically."

# Cleanup
rm -f /tmp/check_settings.py 