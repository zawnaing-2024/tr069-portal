from django.contrib.auth.decorators import login_required
from django.shortcuts import render


@login_required
def dashboard(request):
    """Simple role-aware landing page."""
    if request.user.is_superuser or request.user.groups.filter(name='Admin').exists():
        template_name = 'dashboard/admin_dashboard.html'
    elif request.user.groups.filter(name='Operator').exists():
        template_name = 'dashboard/operator_dashboard.html'
    else:
        template_name = 'dashboard/readonly_dashboard.html'

    return render(request, template_name) 