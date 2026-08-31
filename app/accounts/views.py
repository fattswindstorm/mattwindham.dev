from django.contrib import messages
from django.contrib.auth import logout
from django.contrib.auth.decorators import login_required
from django.shortcuts import redirect, render


@login_required
def settings_view(request):
    if request.method == "POST":
        if "delete_account" in request.POST:
            user = request.user
            logout(request)
            user.delete()
            return redirect("core:index")

        request.user.email_notifications = "email_notifications" in request.POST
        request.user.save(update_fields=["email_notifications"])
        messages.success(request, "Settings updated.")
        return redirect("opportunities:settings")

    return render(request, "accounts/settings.html")
