from django.contrib import admin
from django.urls import include, path

# Django's own admin site is intentionally NOT at /admin/ - CloudFront
# already routes /admin* to the existing log_viewer Lambda (Basic-Auth
# visitor-log dashboard, out of scope of this rewrite). Mounting here
# instead avoids that collision.
urlpatterns = [
    path("django-admin/", admin.site.urls),
    path("accounts/", include("allauth.urls")),
    path("", include("core.urls")),
    path("portal/", include("opportunities.urls")),
]
