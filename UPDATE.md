# TR069 Portal - Update Guide

This guide explains how to update your TR069 Portal installation with new features and fixes.

## Quick Update (Recommended)

If you've followed the production installation guide, you can use the automated update script:

```bash
sudo /opt/tr069/update.sh
```

## Manual Update Steps

If you prefer to update manually or the automated script isn't available:

### Step 1: Navigate to Application Directory
```bash
cd /opt/tr069/app
```

### Step 2: Pull Latest Changes
```bash
git pull origin main
```

### Step 3: Update Python Dependencies
```bash
sudo -u www-data /opt/tr069/app/venv/bin/pip install -r requirements.txt
sudo -u www-data /opt/tr069/app/venv/bin/pip install cryptography  # Ensures MySQL compatibility
```

### Step 4: Run Database Migrations
```bash
sudo -u www-data /opt/tr069/app/venv/bin/python manage.py migrate
```

### Step 5: Collect Static Files
```bash
sudo -u www-data /opt/tr069/app/venv/bin/python manage.py collectstatic --noinput
```

### Step 6: Restart Services
```bash
sudo systemctl restart tr069
sudo systemctl reload nginx
```

### Step 7: Verify Update
```bash
sudo systemctl status tr069 --no-pager
curl -I http://localhost/
```

## Update from Windows to Ubuntu

If you're updating from a Windows development environment to Ubuntu production:

### Step 1: Push Changes from Windows
```bash
# On Windows machine
git add .
git commit -m "Your update message"
git push origin main
```

### Step 2: Pull and Update on Ubuntu
```bash
# On Ubuntu server
cd /opt/tr069/app
git pull origin main
sudo -u www-data /opt/tr069/app/venv/bin/pip install -r requirements.txt
sudo -u www-data /opt/tr069/app/venv/bin/python manage.py migrate
sudo -u www-data /opt/tr069/app/venv/bin/python manage.py collectstatic --noinput
sudo systemctl restart tr069
```

## Adding New Features

When new features are added that require additional setup:

### Database Changes
If new models are added:
```bash
sudo -u www-data /opt/tr069/app/venv/bin/python manage.py makemigrations
sudo -u www-data /opt/tr069/app/venv/bin/python manage.py migrate
```

### New Dependencies
If new Python packages are required:
```bash
sudo -u www-data /opt/tr069/app/venv/bin/pip install package-name
# Or update requirements.txt and run:
sudo -u www-data /opt/tr069/app/venv/bin/pip install -r requirements.txt
```

### Configuration Changes
If settings need to be updated:
```bash
sudo -u www-data nano /opt/tr069/app/.env
# Or
sudo -u www-data nano /opt/tr069/app/tr069_portal/settings.py
```

## Rollback Procedure

If an update causes issues:

### Step 1: Check Git History
```bash
cd /opt/tr069/app
git log --oneline -10
```

### Step 2: Rollback to Previous Version
```bash
git checkout PREVIOUS_COMMIT_HASH
sudo systemctl restart tr069
```

### Step 3: If Database Rollback is Needed
```bash
# This is more complex and depends on the changes
# Best practice: Always backup database before updates
sudo mysqldump tr069_db > /backup/tr069_db_backup.sql
```

## Monitoring After Update

### Check Application Status
```bash
sudo systemctl status tr069
sudo systemctl status nginx
```

### Check Application Logs
```bash
sudo tail -f /var/log/tr069/error.log
sudo tail -f /var/log/nginx/error.log
```

### Test Key Functionality
```bash
# Test main page
curl -I http://localhost/

# Test admin page
curl -I http://localhost/admin/

# Check database connectivity
sudo -u www-data /opt/tr069/app/venv/bin/python manage.py check --database default
```

## Troubleshooting Common Update Issues

### 1. Service Won't Start After Update
```bash
# Check service logs
sudo journalctl -u tr069.service -f

# Try manual start to see errors
cd /opt/tr069/app
sudo -u www-data /opt/tr069/app/venv/bin/python manage.py runserver 0.0.0.0:8001
```

### 2. Database Migration Errors
```bash
# Check migration status
sudo -u www-data /opt/tr069/app/venv/bin/python manage.py showmigrations

# Try fake migration if needed (be careful!)
sudo -u www-data /opt/tr069/app/venv/bin/python manage.py migrate --fake
```

### 3. Permission Issues
```bash
# Fix ownership
sudo chown -R www-data:www-data /opt/tr069

# Fix permissions
sudo chmod -R 755 /opt/tr069/app
sudo chmod +x /opt/tr069/update.sh
```

### 4. Static Files Not Loading
```bash
# Recollect static files
sudo -u www-data /opt/tr069/app/venv/bin/python manage.py collectstatic --clear --noinput

# Check nginx configuration
sudo nginx -t
sudo systemctl reload nginx
```

### 5. Database Connection Issues
```bash
# Test MySQL connection
sudo mysql -u tr069_user -p tr069_db

# Install missing packages
sudo -u www-data /opt/tr069/app/venv/bin/pip install cryptography PyMySQL
```

## Backup Before Updates

Always backup before major updates:

### Database Backup
```bash
sudo mysqldump tr069_db > /backup/tr069_db_$(date +%Y%m%d_%H%M%S).sql
```

### Application Backup
```bash
sudo tar -czf /backup/tr069_app_$(date +%Y%m%d_%H%M%S).tar.gz /opt/tr069/app
```

## Version History

### v2.0 - ONU Credentials Management
- Added username/password fields to ONU model
- Enhanced ONU detail view with credential display
- Updated admin interface with organized fieldsets
- Added show/hide password functionality
- Improved security with role-based access

### v1.0 - Initial Release
- Basic ONU management
- Customer management
- Role-based dashboards
- MySQL/nginx production setup

## Getting Help

If you encounter issues during updates:

1. Check the troubleshooting section above
2. Review application logs: `/var/log/tr069/error.log`
3. Check nginx logs: `/var/log/nginx/error.log`
4. Verify service status: `sudo systemctl status tr069`
5. Test database connectivity: `python manage.py check --database default`

## Best Practices for Updates

1. **Always backup** before updates
2. **Test in development** environment first
3. **Update during maintenance windows**
4. **Monitor logs** after updates
5. **Keep documentation** up to date
6. **Use the automated update script** when possible
7. **Verify functionality** after each update 