from django.contrib import admin
from django.urls import path, include
from django.contrib.auth import views as auth_views
from core import views as core_views

urlpatterns = [
    path('admin/', admin.site.urls),
    # Authentication
    path('accounts/login/', auth_views.LoginView.as_view(template_name='registration/login.html'), name='login'),
    path('accounts/logout/', auth_views.LogoutView.as_view(), name='logout'),
    # Dashboard
    path('', core_views.dashboard, name='dashboard'),
    # ONU Management
    path('onus/', core_views.onu_list, name='onu_list'),
    path('onus/add/', core_views.onu_add, name='onu_add'),
    path('onus/<int:pk>/', core_views.onu_detail, name='onu_detail'),
    path('onus/<int:pk>/edit/', core_views.onu_edit, name='onu_edit'),
    path('onus/<int:pk>/delete/', core_views.onu_delete, name='onu_delete'),
    # Customer Management
    path('customers/', core_views.customer_list, name='customer_list'),
    path('customers/add/', core_views.customer_add, name='customer_add'),
] 