from django.db import migrations

# Mirrors the existing Cognito "admins" group's name and semantics: members
# see all opportunity threads (not just their own) and can trigger the
# eks-demo lifecycle. Assigning it is the stock groups widget already on
# Django's UserChangeForm - no custom UI needed.
ADMINS_GROUP = "admins"


def create_admins_group(apps, schema_editor):
    Group = apps.get_model("auth", "Group")
    Group.objects.get_or_create(name=ADMINS_GROUP)


def remove_admins_group(apps, schema_editor):
    Group = apps.get_model("auth", "Group")
    Group.objects.filter(name=ADMINS_GROUP).delete()


class Migration(migrations.Migration):
    dependencies = [
        ("accounts", "0001_initial"),
        ("auth", "0012_alter_user_first_name_max_length"),
    ]

    operations = [
        migrations.RunPython(create_admins_group, remove_admins_group),
    ]
