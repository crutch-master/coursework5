from django.contrib import admin
from django.urls import include, path

from accounts.views import RegisterView

urlpatterns = [
    path("admin/", admin.site.urls),
    path("", include("schedules.urls")),
    path("teams/", include("teams.urls")),
    path("accounts/", include("django.contrib.auth.urls")),
    path("accounts/register/", RegisterView.as_view(), name="register"),
]
