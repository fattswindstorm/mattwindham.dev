from django.urls import path

from . import views

urlpatterns = [
    path("healthz/", views.healthz, name="healthz"),
    path("", views.index, name="index"),
    path("about/", views.about, name="about"),
    path("resume/", views.resume, name="resume"),
    path("resume-se/", views.resume_se, name="resume_se"),
    path("projects/", views.projects, name="projects"),
]
