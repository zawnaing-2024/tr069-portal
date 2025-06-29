from django.shortcuts import render, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.http import JsonResponse
from django.core.paginator import Paginator
from django.db.models import Q, Count
from django.utils import timezone
from datetime import timedelta
from .models import DeviceInform, DeviceParameter, DeviceTask, DeviceSession


@login_required
def acs_dashboard(request):
    """ACS Dashboard with device statistics"""
    # Device statistics
    total_devices = DeviceInform.objects.count()
    online_devices = DeviceInform.objects.filter(is_online=True).count()
    auto_discovered = DeviceInform.objects.filter(auto_discovered=True).count()
    
    # Recent discoveries (last 24 hours)
    recent_cutoff = timezone.now() - timedelta(hours=24)
    recent_discoveries = DeviceInform.objects.filter(
        first_contact__gte=recent_cutoff
    ).count()
    
    # Vendor breakdown
    vendor_stats = DeviceInform.objects.values('manufacturer').annotate(
        count=Count('id')
    ).order_by('-count')[:5]
    
    # Recent devices
    recent_devices = DeviceInform.objects.order_by('-last_inform')[:10]
    
    # Active sessions
    active_sessions = DeviceSession.objects.filter(is_active=True).count()
    
    context = {
        'total_devices': total_devices,
        'online_devices': online_devices,
        'offline_devices': total_devices - online_devices,
        'auto_discovered': auto_discovered,
        'recent_discoveries': recent_discoveries,
        'vendor_stats': vendor_stats,
        'recent_devices': recent_devices,
        'active_sessions': active_sessions,
    }
    
    return render(request, 'acs/dashboard.html', context)


@login_required
def discovered_devices(request):
    """List all auto-discovered devices"""
    devices = DeviceInform.objects.all().order_by('-last_inform')
    
    # Search functionality
    search = request.GET.get('search')
    if search:
        devices = devices.filter(
            Q(device_id__icontains=search) |
            Q(serial_number__icontains=search) |
            Q(manufacturer__icontains=search) |
            Q(model_name__icontains=search) |
            Q(ip_address__icontains=search)
        )
    
    # Filter by status
    status = request.GET.get('status')
    if status == 'online':
        devices = devices.filter(is_online=True)
    elif status == 'offline':
        devices = devices.filter(is_online=False)
    
    # Filter by manufacturer
    manufacturer = request.GET.get('manufacturer')
    if manufacturer:
        devices = devices.filter(manufacturer=manufacturer)
    
    # Pagination
    paginator = Paginator(devices, 25)
    page_number = request.GET.get('page')
    page_obj = paginator.get_page(page_number)
    
    # Get available manufacturers for filter
    manufacturers = DeviceInform.objects.values_list(
        'manufacturer', flat=True
    ).distinct().exclude(manufacturer='')
    
    context = {
        'page_obj': page_obj,
        'search': search,
        'status': status,
        'manufacturer': manufacturer,
        'manufacturers': manufacturers,
    }
    
    return render(request, 'acs/discovered_devices.html', context)


@login_required
def device_detail(request, device_id):
    """Detailed view of a discovered device"""
    device = get_object_or_404(DeviceInform, id=device_id)
    
    # Get device parameters
    parameters = DeviceParameter.objects.filter(
        device_inform=device
    ).order_by('parameter_name')
    
    # Get device tasks
    tasks = DeviceTask.objects.filter(
        device_inform=device
    ).order_by('-created_at')[:10]
    
    context = {
        'device': device,
        'parameters': parameters,
        'tasks': tasks,
    }
    
    return render(request, 'acs/device_detail.html', context)


@login_required
def device_parameters(request, device_id):
    """View device parameters in detail"""
    device = get_object_or_404(DeviceInform, id=device_id)
    parameters = DeviceParameter.objects.filter(
        device_inform=device
    ).order_by('parameter_name')
    
    # Search in parameters
    search = request.GET.get('search')
    if search:
        parameters = parameters.filter(
            Q(parameter_name__icontains=search) |
            Q(parameter_value__icontains=search)
        )
    
    # Pagination
    paginator = Paginator(parameters, 50)
    page_number = request.GET.get('page')
    page_obj = paginator.get_page(page_number)
    
    context = {
        'device': device,
        'page_obj': page_obj,
        'search': search,
    }
    
    return render(request, 'acs/device_parameters.html', context)


@login_required
def real_time_status(request):
    """API endpoint for real-time device status updates"""
    if request.method == 'GET':
        # Get devices with their online status
        devices = DeviceInform.objects.values(
            'id', 'device_id', 'manufacturer', 'model_name', 
            'is_online', 'last_inform', 'ip_address'
        )
        
        device_list = []
        for device in devices:
            device_list.append({
                'id': device['id'],
                'device_id': device['device_id'],
                'manufacturer': device['manufacturer'],
                'model_name': device['model_name'],
                'is_online': device['is_online'],
                'last_inform': device['last_inform'].isoformat() if device['last_inform'] else None,
                'ip_address': device['ip_address'],
            })
        
        return JsonResponse({
            'devices': device_list,
            'timestamp': timezone.now().isoformat()
        })


@login_required
def create_device_task(request, device_id):
    """Create a new task for a device"""
    device = get_object_or_404(DeviceInform, id=device_id)
    
    if request.method == 'POST':
        task_type = request.POST.get('task_type')
        parameters = {}
        
        if task_type == 'GetParameterValues':
            param_names = request.POST.get('parameter_names', '').split('\n')
            parameters['parameter_names'] = [name.strip() for name in param_names if name.strip()]
        
        elif task_type == 'SetParameterValues':
            # Parse parameter name-value pairs
            param_data = request.POST.get('parameter_data', '')
            param_dict = {}
            for line in param_data.split('\n'):
                if '=' in line:
                    name, value = line.split('=', 1)
                    param_dict[name.strip()] = value.strip()
            parameters['parameters'] = param_dict
        
        elif task_type == 'Reboot':
            parameters['command_key'] = request.POST.get('command_key', '')
        
        # Create task
        task = DeviceTask.objects.create(
            device_inform=device,
            task_type=task_type,
            parameters=parameters,
            status='pending'
        )
        
        return JsonResponse({
            'success': True,
            'task_id': task.id,
            'message': f'Task {task_type} created successfully'
        })
    
    return JsonResponse({'success': False, 'message': 'Invalid request method'})


@login_required
def device_statistics(request):
    """API endpoint for device statistics"""
    # Device counts by status
    total = DeviceInform.objects.count()
    online = DeviceInform.objects.filter(is_online=True).count()
    
    # Device counts by manufacturer
    manufacturers = DeviceInform.objects.values('manufacturer').annotate(
        count=Count('id')
    ).order_by('-count')
    
    # Recent activity (last 7 days)
    week_ago = timezone.now() - timedelta(days=7)
    daily_stats = []
    for i in range(7):
        day = week_ago + timedelta(days=i)
        day_start = day.replace(hour=0, minute=0, second=0, microsecond=0)
        day_end = day_start + timedelta(days=1)
        
        count = DeviceInform.objects.filter(
            first_contact__gte=day_start,
            first_contact__lt=day_end
        ).count()
        
        daily_stats.append({
            'date': day_start.strftime('%Y-%m-%d'),
            'count': count
        })
    
    return JsonResponse({
        'total_devices': total,
        'online_devices': online,
        'offline_devices': total - online,
        'manufacturers': list(manufacturers),
        'daily_discoveries': daily_stats
    }) 