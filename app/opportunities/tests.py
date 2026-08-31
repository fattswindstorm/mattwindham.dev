from django.contrib.auth import get_user_model
from django.contrib.auth.models import Group
from django.core import mail
from django.test import TestCase
from django.urls import reverse

from .models import Message, Opportunity

User = get_user_model()


class OpportunityIntakeTests(TestCase):
    def setUp(self):
        self.recruiter = User.objects.create_user(email="recruiter@example.com", password="pw", name="Rec Ruiter")
        self.client.force_login(self.recruiter)

    def test_submit_creates_opportunity_and_notifies_admin(self):
        with self.settings(NOTIFY_EMAIL="matt@example.com"):
            response = self.client.post(
                reverse("opportunities:intake"),
                {
                    "company": "Acme",
                    "recruiter_role": "Technical Recruiter",
                    "job_title": "DevOps Engineer",
                    "job_description": "Do DevOps things.",
                    "employment_type": "full-time",
                    "compensation_range": "50-150k",
                    "contract_length": "",
                    "notes": "",
                },
            )
        self.assertRedirects(response, reverse("opportunities:dashboard"))
        opp = Opportunity.objects.get(company="Acme")
        self.assertEqual(opp.owner, self.recruiter)
        self.assertEqual(opp.name, "Rec Ruiter")
        self.assertEqual(opp.email, "recruiter@example.com")
        self.assertTrue(opp.low_comp, "full-time + 50-150k must flag low_comp")
        self.assertEqual(len(mail.outbox), 1)
        self.assertIn("[LOW COMP]", mail.outbox[0].subject)
        self.assertEqual(mail.outbox[0].to, ["matt@example.com"])

    def test_contract_role_never_flagged_low_comp(self):
        self.client.post(
            reverse("opportunities:intake"),
            {
                "company": "Acme",
                "recruiter_role": "Technical Recruiter",
                "job_title": "DevOps Engineer",
                "job_description": "Do DevOps things.",
                "employment_type": "contract",
                "compensation_range": "50-150k",
                "contract_length": "6 months",
                "notes": "",
            },
        )
        opp = Opportunity.objects.get(company="Acme")
        self.assertFalse(opp.low_comp)


class ThreadAuthorizationTests(TestCase):
    def setUp(self):
        self.recruiter = User.objects.create_user(email="recruiter@example.com", password="pw")
        self.other_recruiter = User.objects.create_user(email="other@example.com", password="pw")
        self.admin = User.objects.create_user(email="admin@example.com", password="pw")
        self.admin.groups.add(Group.objects.get(name="admins"))

        self.thread = Opportunity.objects.create(
            owner=self.recruiter,
            name="Rec Ruiter",
            email="recruiter@example.com",
            company="Acme",
            recruiter_role="Recruiter",
            job_title="DevOps Engineer",
            job_description="desc",
            employment_type="contract",
            compensation_range="200-500k",
        )

    def test_owner_can_view_own_thread(self):
        self.client.force_login(self.recruiter)
        response = self.client.get(reverse("opportunities:thread_detail", args=[self.thread.pk]))
        self.assertEqual(response.status_code, 200)

    def test_other_recruiter_forbidden(self):
        self.client.force_login(self.other_recruiter)
        response = self.client.get(reverse("opportunities:thread_detail", args=[self.thread.pk]))
        self.assertEqual(response.status_code, 403)

    def test_admin_can_view_any_thread(self):
        self.client.force_login(self.admin)
        response = self.client.get(reverse("opportunities:thread_detail", args=[self.thread.pk]))
        self.assertEqual(response.status_code, 200)

    def test_admin_reply_notifies_recruiter_but_recruiter_reply_does_not_notify_admin(self):
        self.client.force_login(self.recruiter)
        self.client.post(reverse("opportunities:thread_detail", args=[self.thread.pk]), {"body": "hello"})
        self.assertEqual(len(mail.outbox), 0, "recruiter reply must not notify the admin")

        self.client.force_login(self.admin)
        self.client.post(reverse("opportunities:thread_detail", args=[self.thread.pk]), {"body": "hi back"})
        self.assertEqual(len(mail.outbox), 1)
        self.assertEqual(mail.outbox[0].to, ["recruiter@example.com"])

        messages = list(Message.objects.order_by("created_at"))
        self.assertEqual(messages[0].sender_role, "recruiter")
        self.assertEqual(messages[1].sender_role, "owner")

    def test_dashboard_redirects_admin_to_admin_inbox(self):
        self.client.force_login(self.admin)
        response = self.client.get(reverse("opportunities:dashboard"))
        self.assertRedirects(response, reverse("opportunities:admin_inbox"))

    def test_non_admin_forbidden_from_admin_inbox(self):
        self.client.force_login(self.recruiter)
        response = self.client.get(reverse("opportunities:admin_inbox"))
        self.assertEqual(response.status_code, 403)


class DeleteAccountTests(TestCase):
    def test_delete_account_cascades_opportunities_and_messages(self):
        recruiter = User.objects.create_user(email="recruiter@example.com", password="pw")
        admin = User.objects.create_user(email="admin@example.com", password="pw")
        admin.groups.add(Group.objects.get(name="admins"))

        thread = Opportunity.objects.create(
            owner=recruiter,
            name="Rec Ruiter",
            email="recruiter@example.com",
            company="Acme",
            recruiter_role="Recruiter",
            job_title="DevOps Engineer",
            job_description="desc",
            employment_type="contract",
            compensation_range="200-500k",
        )
        Message.objects.create(thread=thread, sender=recruiter, sender_role="recruiter", body="hi")
        Message.objects.create(thread=thread, sender=admin, sender_role="owner", body="hi back")

        self.client.force_login(recruiter)
        response = self.client.post(reverse("opportunities:settings"), {"delete_account": "1"})
        self.assertRedirects(response, reverse("core:index"))

        self.assertFalse(User.objects.filter(email="recruiter@example.com").exists())
        self.assertFalse(Opportunity.objects.filter(pk=thread.pk).exists())
        self.assertEqual(Message.objects.count(), 0)

    def test_settings_toggle_updates_notification_preference(self):
        recruiter = User.objects.create_user(email="recruiter@example.com", password="pw", email_notifications=True)
        self.client.force_login(recruiter)
        self.client.post(reverse("opportunities:settings"), {})
        recruiter.refresh_from_db()
        self.assertFalse(recruiter.email_notifications)
