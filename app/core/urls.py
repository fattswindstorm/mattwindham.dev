from django.urls import path

from . import views

app_name = "core"

urlpatterns = [
    path("healthz/", views.healthz, name="healthz"),
    path("", views.index, name="index"),
    path("about/", views.about, name="about"),
    path("resume/", views.resume, name="resume"),
    path("resume-se/", views.resume_se, name="resume_se"),
    path("projects/", views.projects, name="projects"),
]
