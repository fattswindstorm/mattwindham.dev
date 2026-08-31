from django.urls import path

from accounts import views as account_views

from . import views

app_name = "opportunities"

urlpatterns = [
    path("", views.dashboard, name="dashboard"),
    path("opportunity/", views.intake, name="intake"),
    path("admin/", views.admin_inbox, name="admin_inbox"),
    path("threads/<uuid:pk>/", views.thread_detail, name="thread_detail"),
    path("settings/", account_views.settings_view, name="settings"),
]
