import uuid

from django.conf import settings
from django.db import models

EMPLOYMENT_TYPE_CHOICES = [
    ("full-time", "Full Time"),
    ("contract", "Contract"),
    ("c2h", "Contract-to-Hire"),
]

COMP_RANGE_CHOICES = [
    ("50-150k", "$50k–$150k/yr"),
    ("150-200k", "$150k–$200k/yr"),
    ("200-500k", "$200k–$500k/yr"),
    ("500k+", "$500k+/yr"),
]

# Mirrors the old Lambda's rule exactly: only full-time/contract-to-hire
# roles in the bottom comp band get flagged - contract roles never do,
# regardless of rate, since day rates don't compare to salary bands.
LOW_COMP_EMPLOYMENT_TYPES = {"full-time", "c2h"}
LOW_COMP_RANGES = {"50-150k"}


class Opportunity(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="opportunities"
    )
    submitted_at = models.DateTimeField(auto_now_add=True)
    name = models.CharField(max_length=255)
    email = models.EmailField()
    company = models.CharField(max_length=255)
    recruiter_role = models.CharField(max_length=255)
    job_title = models.CharField(max_length=255)
    job_description = models.TextField()
    employment_type = models.CharField(max_length=20, choices=EMPLOYMENT_TYPE_CHOICES)
    compensation_range = models.CharField(max_length=20, choices=COMP_RANGE_CHOICES)
    contract_length = models.CharField(max_length=255, blank=True, default="")
    notes = models.TextField(blank=True, default="")
    # Computed once at creation, not a live property - editing an old
    # record's comp band later doesn't retroactively relabel it.
    low_comp = models.BooleanField(default=False)

    class Meta:
        ordering = ["-submitted_at"]

    def __str__(self):
        return f"{self.company} — {self.job_title}"

    def compute_low_comp(self):
        return (
            self.employment_type in LOW_COMP_EMPLOYMENT_TYPES
            and self.compensation_range in LOW_COMP_RANGES
        )

    def save(self, *args, **kwargs):
        if self._state.adding:
            self.low_comp = self.compute_low_comp()
        super().save(*args, **kwargs)


class Message(models.Model):
    SENDER_ROLE_CHOICES = [("owner", "owner"), ("recruiter", "recruiter")]

    thread = models.ForeignKey(Opportunity, on_delete=models.CASCADE, related_name="messages")
    created_at = models.DateTimeField(auto_now_add=True)
    sender = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True
    )
    sender_role = models.CharField(max_length=10, choices=SENDER_ROLE_CHOICES)
    body = models.TextField()

    class Meta:
        ordering = ["created_at"]

    def __str__(self):
        return f"{self.sender_role} reply on {self.thread_id}"
