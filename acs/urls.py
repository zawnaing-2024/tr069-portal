from django.urls import path
from . import views
from .tr069 import TR069ACSView

app_name = 'acs'

urlpatterns = [
    # TR-069 ACS endpoint for devices
    path('tr069/', TR069ACSView.as_view(), name='tr069_endpoint'),
    
    # ACS Management Views
    path('dashboard/', views.acs_dashboard, name='dashboard'),
    path('devices/', views.discovered_devices, name='discovered_devices'),
    path('devices/<int:device_id>/', views.device_detail, name='device_detail'),
    path('devices/<int:device_id>/parameters/', views.device_parameters, name='device_parameters'),
    path('devices/<int:device_id>/tasks/create/', views.create_device_task, name='create_device_task'),
    
    # API endpoints
    path('api/status/', views.real_time_status, name='real_time_status'),
    path('api/statistics/', views.device_statistics, name='device_statistics'),
] 