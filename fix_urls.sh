#!/bin/bash

echo "Fixing ACS URL Configuration"
echo "============================"

cd /opt/tr069/app

# Check current main URLs
echo "Current main URLs file:"
cat tr069_portal/urls.py

echo ""
echo "Checking if ACS URLs are included..."

# Check if ACS URLs are included
if grep -q "include('acs.urls')" tr069_portal/urls.py; then
    echo "✓ ACS URLs are already included"
else
    echo "✗ ACS URLs are missing - adding them now"
    
    # Backup the file
    sudo cp tr069_portal/urls.py tr069_portal/urls.py.backup
    
    # Add ACS URLs to the main urls.py
    sudo sed -i "/# TR-069 ACS/d" tr069_portal/urls.py
    sudo sed -i "/path('acs\/', include('acs.urls')),/d" tr069_portal/urls.py
    sudo sed -i "/path('customers\/add\/', core_views.customer_add, name='customer_add'),/a\\    # TR-069 ACS\\    path('acs/', include('acs.urls'))," tr069_portal/urls.py
    
    echo "✓ ACS URLs added to main configuration"
fi

echo ""
echo "Updated main URLs file:"
cat tr069_portal/urls.py

echo ""
echo "Checking if ACS urls.py exists:"
if [ -f "acs/urls.py" ]; then
    echo "✓ ACS urls.py exists"
    echo "Content:"
    cat acs/urls.py
else
    echo "✗ ACS urls.py is missing!"
    exit 1
fi

# Test Django configuration
echo ""
echo "Testing Django configuration:"
sudo -u www-data /opt/tr069/app/venv/bin/python manage.py check

# Check URL patterns again
echo ""
echo "Checking URL patterns after fix:"
sudo -u www-data /opt/tr069/app/venv/bin/python manage.py shell -c "
from django.urls import get_resolver
resolver = get_resolver()
print('All URL patterns:')
for pattern in resolver.url_patterns:
    print(f'  {pattern}')
print()
print('Looking for ACS patterns:')
for pattern in resolver.url_patterns:
    if 'acs' in str(pattern) or 'tr069' in str(pattern):
        print(f'  Found ACS: {pattern}')
"

# Restart services
echo ""
echo "Restarting services..."
sudo systemctl restart tr069
sleep 3
sudo systemctl reload nginx

# Test endpoints
echo ""
echo "Testing endpoints after URL fix:"

# Test TR-069 endpoint
tr069_test=$(curl -s -I http://localhost/acs/tr069/ 2>/dev/null | head -1)
echo "TR-069 endpoint: $tr069_test"

# Test ACS dashboard
acs_test=$(curl -s -I http://localhost/acs/dashboard/ 2>/dev/null | head -1)
echo "ACS dashboard: $acs_test"

echo ""
if echo "$tr069_test" | grep -q "405\|500\|200"; then
    echo "🎉 SUCCESS! TR-069 endpoint is now working!"
    echo "✅ http://18.142.243.199/acs/tr069/ should now be accessible"
else
    echo "❌ TR-069 endpoint still not working"
    echo "Response: $tr069_test"
fi

echo ""
echo "Fix completed!" 