from django.contrib import admin

from .models import Message, Opportunity


class MessageInline(admin.TabularInline):
    model = Message
    extra = 0
    readonly_fields = ("created_at", "sender", "sender_role")


@admin.register(Opportunity)
class OpportunityAdmin(admin.ModelAdmin):
    list_display = ("company", "job_title", "owner", "employment_type", "compensation_range", "low_comp", "submitted_at")
    list_filter = ("employment_type", "compensation_range", "low_comp")
    search_fields = ("company", "job_title", "name", "email")
    readonly_fields = ("id", "submitted_at", "low_comp")
    inlines = [MessageInline]
