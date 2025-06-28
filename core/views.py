from django.contrib.auth.decorators import login_required
from django.shortcuts import render, get_object_or_404, redirect
from django.contrib import messages
from django.core.paginator import Paginator
from django.db.models import Q
from .models import ONU, CustomerInfo
from .forms import ONUForm, CustomerForm


@login_required
def dashboard(request):
    """Role-aware dashboard with ONU statistics."""
    # Get basic stats
    total_onus = ONU.objects.count()
    online_onus = ONU.objects.filter(online=True).count()
    offline_onus = total_onus - online_onus
    
    # Vendor breakdown
    huawei_count = ONU.objects.filter(vendor='Huawei').count()
    zte_count = ONU.objects.filter(vendor='ZTE').count()
    other_count = ONU.objects.filter(vendor='Other').count()
    
    context = {
        'total_onus': total_onus,
        'online_onus': online_onus,
        'offline_onus': offline_onus,
        'huawei_count': huawei_count,
        'zte_count': zte_count,
        'other_count': other_count,
    }
    
    if request.user.is_superuser or request.user.groups.filter(name='Admin').exists():
        template_name = 'dashboard/admin_dashboard.html'
    elif request.user.groups.filter(name='Operator').exists():
        template_name = 'dashboard/operator_dashboard.html'
    else:
        template_name = 'dashboard/readonly_dashboard.html'

    return render(request, template_name, context)


@login_required
def onu_list(request):
    """List all ONUs with search and filtering."""
    onus = ONU.objects.select_related('customer').all()
    
    # Search functionality
    search = request.GET.get('search')
    if search:
        onus = onus.filter(
            Q(serial_number__icontains=search) |
            Q(mac_address__icontains=search) |
            Q(ip_address__icontains=search) |
            Q(model_name__icontains=search)
        )
    
    # Filter by vendor
    vendor = request.GET.get('vendor')
    if vendor:
        onus = onus.filter(vendor=vendor)
    
    # Filter by status
    status = request.GET.get('status')
    if status == 'online':
        onus = onus.filter(online=True)
    elif status == 'offline':
        onus = onus.filter(online=False)
    
    # Pagination
    paginator = Paginator(onus, 25)
    page_number = request.GET.get('page')
    page_obj = paginator.get_page(page_number)
    
    context = {
        'page_obj': page_obj,
        'search': search,
        'vendor': vendor,
        'status': status,
    }
    return render(request, 'onus/list.html', context)


@login_required
def onu_detail(request, pk):
    """Show detailed ONU information."""
    onu = get_object_or_404(ONU, pk=pk)
    return render(request, 'onus/detail.html', {'onu': onu})


@login_required
def onu_add(request):
    """Add new ONU."""
    if not (request.user.is_superuser or request.user.groups.filter(name__in=['Admin', 'Operator']).exists()):
        messages.error(request, 'Permission denied.')
        return redirect('onu_list')
    
    if request.method == 'POST':
        form = ONUForm(request.POST)
        if form.is_valid():
            form.save()
            messages.success(request, 'ONU added successfully.')
            return redirect('onu_list')
    else:
        form = ONUForm()
    
    return render(request, 'onus/form.html', {'form': form, 'title': 'Add ONU'})


@login_required
def onu_edit(request, pk):
    """Edit existing ONU."""
    if not (request.user.is_superuser or request.user.groups.filter(name__in=['Admin', 'Operator']).exists()):
        messages.error(request, 'Permission denied.')
        return redirect('onu_list')
    
    onu = get_object_or_404(ONU, pk=pk)
    
    if request.method == 'POST':
        form = ONUForm(request.POST, instance=onu)
        if form.is_valid():
            form.save()
            messages.success(request, 'ONU updated successfully.')
            return redirect('onu_detail', pk=pk)
    else:
        form = ONUForm(instance=onu)
    
    return render(request, 'onus/form.html', {'form': form, 'title': 'Edit ONU', 'onu': onu})


@login_required
def onu_delete(request, pk):
    """Delete ONU."""
    if not (request.user.is_superuser or request.user.groups.filter(name='Admin').exists()):
        messages.error(request, 'Permission denied.')
        return redirect('onu_list')
    
    onu = get_object_or_404(ONU, pk=pk)
    
    if request.method == 'POST':
        onu.delete()
        messages.success(request, 'ONU deleted successfully.')
        return redirect('onu_list')
    
    return render(request, 'onus/confirm_delete.html', {'onu': onu})


@login_required
def customer_list(request):
    """List all customers."""
    customers = CustomerInfo.objects.prefetch_related('onus').all()
    
    # Search functionality
    search = request.GET.get('search')
    if search:
        customers = customers.filter(
            Q(name__icontains=search) |
            Q(phone__icontains=search) |
            Q(email__icontains=search)
        )
    
    # Pagination
    paginator = Paginator(customers, 25)
    page_number = request.GET.get('page')
    page_obj = paginator.get_page(page_number)
    
    return render(request, 'customers/list.html', {'page_obj': page_obj, 'search': search})


@login_required
def customer_add(request):
    """Add new customer."""
    if not (request.user.is_superuser or request.user.groups.filter(name__in=['Admin', 'Operator']).exists()):
        messages.error(request, 'Permission denied.')
        return redirect('customer_list')
    
    if request.method == 'POST':
        form = CustomerForm(request.POST)
        if form.is_valid():
            form.save()
            messages.success(request, 'Customer added successfully.')
            return redirect('customer_list')
    else:
        form = CustomerForm()
    
    return render(request, 'customers/form.html', {'form': form, 'title': 'Add Customer'}) 