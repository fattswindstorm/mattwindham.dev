from django import forms

from .models import Message, Opportunity


class OpportunityForm(forms.ModelForm):
    class Meta:
        model = Opportunity
        fields = [
            "company",
            "recruiter_role",
            "job_title",
            "job_description",
            "employment_type",
            "compensation_range",
            "contract_length",
            "notes",
        ]
        labels = {
            "recruiter_role": "Your role",
            "job_title": "Position title",
        }
        widgets = {
            "job_description": forms.Textarea(attrs={"rows": 6}),
            "notes": forms.Textarea(attrs={"rows": 3}),
        }


class MessageForm(forms.ModelForm):
    class Meta:
        model = Message
        fields = ["body"]
        labels = {"body": ""}
        widgets = {
            "body": forms.Textarea(attrs={"rows": 4, "placeholder": "Write a reply…"})
        }
