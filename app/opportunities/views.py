from django.conf import settings as django_settings
from django.contrib import messages
from django.contrib.auth.decorators import login_required
from django.core.mail import send_mail
from django.http import HttpResponseForbidden
from django.shortcuts import get_object_or_404, redirect, render

from .forms import MessageForm, OpportunityForm
from .models import Opportunity


@login_required
def intake(request):
    if request.method == "POST":
        form = OpportunityForm(request.POST)
        if form.is_valid():
            opportunity = form.save(commit=False)
            opportunity.owner = request.user
            opportunity.name = request.user.get_full_name()
            opportunity.email = request.user.email
            opportunity.save()
            _notify_new_opportunity(opportunity)
            messages.success(request, "Thanks for reaching out — I'll be in touch soon.")
            return redirect("opportunities:dashboard")
    else:
        form = OpportunityForm()
    return render(request, "opportunities/intake.html", {"form": form})


@login_required
def dashboard(request):
    if request.user.is_admin:
        return redirect("opportunities:admin_inbox")
    threads = Opportunity.objects.filter(owner=request.user)
    return render(request, "opportunities/dashboard.html", {"threads": threads})


@login_required
def admin_inbox(request):
    if not request.user.is_admin:
        return HttpResponseForbidden()
    threads = Opportunity.objects.all()
    return render(request, "opportunities/admin_inbox.html", {"threads": threads})


@login_required
def thread_detail(request, pk):
    thread = get_object_or_404(Opportunity, pk=pk)
    if not request.user.is_admin and thread.owner_id != request.user.id:
        return HttpResponseForbidden()

    if request.method == "POST":
        form = MessageForm(request.POST)
        if form.is_valid():
            message = form.save(commit=False)
            message.thread = thread
            message.sender = request.user
            message.sender_role = "owner" if request.user.is_admin else "recruiter"
            message.save()
            # Parity with the old Lambda: only the site owner's reply
            # notifies the recruiter by email - a recruiter's reply doesn't
            # page the owner, who works the inbox directly instead.
            if message.sender_role == "owner":
                _notify_reply(thread)
            return redirect("opportunities:thread_detail", pk=thread.pk)
    else:
        form = MessageForm()

    return render(
        request,
        "opportunities/thread_detail.html",
        {"thread": thread, "thread_messages": thread.messages.all(), "form": form},
    )


def _notify_new_opportunity(opportunity):
    if not django_settings.NOTIFY_EMAIL:
        return
    subject = f"[mattwindham.dev] Opportunity from {opportunity.company}"
    if opportunity.low_comp:
        subject += " [LOW COMP]"
    body = (
        f"From: {opportunity.name} <{opportunity.email}>\n"
        f"Company: {opportunity.company}\n"
        f"Role: {opportunity.recruiter_role}\n"
        f"Position: {opportunity.job_title}\n"
        f"Type: {opportunity.get_employment_type_display()}\n"
        f"Compensation: {opportunity.get_compensation_range_display()}\n"
        f"Contract length: {opportunity.contract_length or '—'}\n\n"
        f"{opportunity.job_description}\n\n"
        f"Notes:\n{opportunity.notes or '—'}\n\n"
        f"Record ID: {opportunity.id}\n"
        f"Submitted: {opportunity.submitted_at:%Y-%m-%d %H:%M UTC}\n"
    )
    send_mail(subject, body, None, [django_settings.NOTIFY_EMAIL])


def _notify_reply(thread):
    if not thread.owner.email_notifications:
        return
    subject = "[mattwindham.dev] Reply to your opportunity submission"
    body = (
        f"You have a new reply regarding {thread.job_title} at {thread.company}.\n\n"
        f"View it at {django_settings.SITE_URL}/portal/\n"
        f"Manage notification preferences at {django_settings.SITE_URL}/portal/settings/\n"
    )
    send_mail(subject, body, None, [thread.email])
