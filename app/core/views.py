from django.http import HttpResponse
from django.shortcuts import render


def healthz(request):
    return HttpResponse("ok")


def index(request):
    return render(request, "core/index.html")


def about(request):
    return render(request, "core/about.html")


RESUME_CERTIFICATIONS = [
    {
        "name": "Terraform Associate (004)",
        "authority": "HashiCorp",
        "date": "Mar 2026",
        "url": "https://www.credly.com/badges/9c69824c-dd8b-4614-8b29-0e97719d5787/linked_in_profile",
    },
    {
        "name": "AWS Certified Cloud Practitioner",
        "authority": "Amazon Web Services",
        "date": "Apr 2021",
        "url": "http://aws.amazon.com/verification",
    },
    {
        "name": "CompTIA A+ ce",
        "authority": "CompTIA",
        "date": "Jun 2018",
        "url": "https://www.youracclaim.com/badges/464fad64-7b44-4961-bb5d-016a1ce0d9bb/linked_in_profile",
    },
]

RESUME_EXPERIENCE = [
    {
        "company": "Ren",
        "title": "DevOps Engineer",
        "location": "Austin, TX",
        "start": "Jun 2024",
        "end": "Present",
        "bullets": [
            "Migrated on-premise infrastructure to AWS, expanding the cloud footprint across multiple production environments.",
            "Provisioned and managed cloud infrastructure as code using Terraform.",
            "Leading migration of TeamCity CI/CD pipelines to GitHub Actions, modernizing the team's delivery toolchain.",
            "Managed application release pipelines in Octopus Deploy across multiple deployment targets.",
            "Deployed Datadog as the team's observability platform and automated its configuration via PowerShell modules.",
            "Incorporated AI coding tools into daily infrastructure workflows to increase development velocity.",
        ],
    },
    {
        "company": "Ren",
        "title": "Senior Site Reliability Engineer",
        "location": "Austin, TX",
        "start": "Feb 2023",
        "end": "Jun 2024",
        "bullets": [
            "Developed PowerShell modules to automate Windows Server administration, reducing recurring manual workload.",
            "Built operational dashboards in the Elastic Stack to surface system health and key performance metrics.",
            "Implemented Microsoft Endpoint Manager to standardize and automate Windows Server patch management across on-premise infrastructure.",
        ],
    },
    {
        "company": "Stellar Technology Solutions (acq. by Ren)",
        "title": "Senior Site Reliability Engineer",
        "location": "Austin, TX",
        "start": "Nov 2022",
        "end": "May 2023",
        "bullets": [
            "Led migration of on-premise workloads to AWS, transitioning core infrastructure to the cloud.",
            "Maintained on-premise infrastructure stability throughout the migration, ensuring continuity of service.",
            "Developed internal monitoring tools and automation scripts to reduce operational overhead.",
        ],
    },
    {
        "company": "Stellar Technology Solutions (acq. by Ren)",
        "title": "Site Reliability Engineer",
        "location": "Austin, TX",
        "start": "Apr 2021",
        "end": "Nov 2022",
        "bullets": [
            "Owned reliability across on-premise and cloud environments - provisioning, configuring, and maintaining OS, application, and system management infrastructure.",
            "Collaborated with Engineering, Security, QA, and Product to improve reliability, availability, and security of shared infrastructure.",
            "Wrote runbooks and automated recurring operational tasks to eliminate manual toil.",
            "Planned and executed security patching across applications and infrastructure on a recurring cycle.",
            "Drove initial AWS integration into company infrastructure, improving scalability and laying groundwork for full cloud migration.",
            "Participated in on-call rotation covering incident response, service requests, maintenance, and server provisioning.",
        ],
    },
    {
        "company": "Stellar Technology Solutions (acq. by Ren)",
        "title": "Junior Systems Administrator",
        "location": "Austin, TX",
        "start": "Oct 2019",
        "end": "Apr 2021",
        "bullets": [
            "Supported day-to-day IT operations and systems administration in a growing engineering organization.",
        ],
    },
    {
        "company": "Cummings Electrical",
        "title": "Systems Administrator",
        "location": "Dallas/Fort Worth, TX",
        "start": "May 2016",
        "end": "Aug 2019",
        "bullets": [
            "Managed hardware and software systems for the business as part of a small IT team.",
            "Owned remote access tooling, data backup and restore, Windows Server administration, and mobile device management.",
            "Built a standardized IT environment that scaled to support 350+ employees across 15+ locations as the company grew.",
        ],
    },
]

RESUME_SKILL_GROUPS = [
    {
        "label": "Cloud & DevOps",
        "items": ["AWS", "Terraform", "GitHub Actions", "Octopus Deploy", "TeamCity", "Datadog", "Elastic Stack"],
    },
    {
        "label": "Infrastructure",
        "items": [
            "Windows Server", "Active Directory", "VMware ESXi", "Hyper-V",
            "Nutanix", "IIS", "Cisco Systems", "DNS", "VPN",
        ],
    },
    {"label": "Scripting & Automation", "items": ["PowerShell", "Python", "Bash"]},
    {
        "label": "Operations",
        "items": ["Incident Response", "Server Management", "Microsoft Exchange", "Troubleshooting", "Team Leadership"],
    },
]

RESUME_SE_EXPERIENCE = [
    {
        "company": "Ren",
        "title": "DevOps Engineer",
        "location": "Austin, TX",
        "start": "Jun 2024",
        "end": "Present",
        "bullets": [
            "Deployed Datadog as the team's observability platform end-to-end - configuration, integrations, and rollout - giving firsthand implementer experience with the exact product category Datadog SEs sell.",
            "Led migration of CI/CD pipelines from TeamCity to GitHub Actions, evaluating tooling tradeoffs and presenting the migration plan to stakeholders.",
            "Migrated on-premise infrastructure to AWS, regularly explaining architecture decisions and tradeoffs to engineering and leadership audiences.",
            "Provisioned cloud infrastructure as code using Terraform across production environments.",
            "Adopted AI coding tools into daily workflows, evaluating and pitching new tooling to the team.",
        ],
    },
    {
        "company": "Ren",
        "title": "Senior Site Reliability Engineer",
        "location": "Austin, TX",
        "start": "Feb 2023",
        "end": "Jun 2024",
        "bullets": [
            "Built operational dashboards in the Elastic Stack that translated raw system telemetry into findings non-technical stakeholders could act on.",
            "Developed PowerShell automation modules, reducing manual workload and freeing time for higher-value technical conversations with internal teams.",
            "Standardized Windows Server patch management via Microsoft Endpoint Manager, presenting the rollout plan across teams.",
        ],
    },
    {
        "company": "Stellar Technology Solutions (acq. by Ren)",
        "title": "Senior Site Reliability Engineer",
        "location": "Austin, TX",
        "start": "Nov 2022",
        "end": "May 2023",
        "bullets": [
            "Led migration of on-premise workloads to AWS, acting as the technical point of contact across the transition.",
            "Maintained infrastructure stability throughout a major migration - the kind of technical trust-building a POC or pilot depends on.",
            "Built internal monitoring tools and automation scripts, then walked teams through how and why they worked.",
        ],
    },
    {
        "company": "Stellar Technology Solutions (acq. by Ren)",
        "title": "Site Reliability Engineer",
        "location": "Austin, TX",
        "start": "Apr 2021",
        "end": "Nov 2022",
        "bullets": [
            "Partnered daily with Engineering, Security, QA, and Product - the same cross-functional muscle an SE uses bridging sales and engineering.",
            "Wrote runbooks that turned tribal knowledge into documentation other teams could self-serve from.",
            "Drove the company's initial AWS integration, scoping and pitching the technical case for cloud adoption internally.",
            "Participated in on-call incident response - deep, first-hand familiarity with the operational pain points technical buyers are trying to solve.",
        ],
    },
    {
        "company": "Stellar Technology Solutions (acq. by Ren)",
        "title": "Junior Systems Administrator",
        "location": "Austin, TX",
        "start": "Oct 2019",
        "end": "Apr 2021",
        "bullets": [
            "Supported day-to-day IT operations and systems administration in a growing engineering organization.",
        ],
    },
    {
        "company": "Cummings Electrical",
        "title": "Systems Administrator",
        "location": "Dallas/Fort Worth, TX",
        "start": "May 2016",
        "end": "Aug 2019",
        "bullets": [
            "Built and scaled a standardized IT environment supporting 350+ employees across 15+ locations.",
            "Owned remote access tooling, backup/restore, and Windows Server administration for a small IT team.",
        ],
    },
]

RESUME_SE_SKILL_GROUPS = [
    {
        "label": "Customer-Facing Technical Skills",
        "items": [
            "Technical demos & walkthroughs",
            "Dashboard & findings presentation",
            "Cross-functional stakeholder communication",
            "Runbook & documentation writing",
            "Discovery & requirements translation",
        ],
    },
    {
        "label": "Cloud & Observability",
        "items": ["AWS", "Terraform", "Datadog", "Elastic Stack", "GitHub Actions", "Octopus Deploy"],
    },
    {
        "label": "Infrastructure",
        "items": ["Windows Server", "Active Directory", "VMware ESXi", "Hyper-V", "Nutanix", "Networking (DNS/VPN/Cisco)"],
    },
    {"label": "Scripting & Automation", "items": ["PowerShell", "Python", "Bash"]},
]


def resume(request):
    return render(
        request,
        "core/resume.html",
        {
            "heading": "Resume",
            "show_opportunity_cta": True,
            "summary": None,
            "experience": RESUME_EXPERIENCE,
            "skill_groups": RESUME_SKILL_GROUPS,
            "certifications": RESUME_CERTIFICATIONS,
        },
    )


def resume_se(request):
    return render(
        request,
        "core/resume.html",
        {
            "heading": "Resume — Sales Engineer track",
            "show_opportunity_cta": False,
            "summary": (
                "DevOps/SRE engineer pivoting into Sales/Solutions Engineering. Nine years "
                "building and operating the infrastructure that SE teams sell - AWS "
                "migrations, Terraform, CI/CD, and observability tooling. Deployed Datadog "
                "in production as an end user before ever pitching it, and spent years "
                "translating system behavior into dashboards and findings for "
                "non-specialist stakeholders."
            ),
            "experience": RESUME_SE_EXPERIENCE,
            "skill_groups": RESUME_SE_SKILL_GROUPS,
            "certifications": RESUME_CERTIFICATIONS,
        },
    )


PROJECTS = [
    {
        "name": "mattwindham.dev",
        "description": (
            "This site - a personal portfolio and blog built on AWS. Django app running "
            "on ECS Fargate behind CloudFront, RDS Postgres for storage. Infrastructure "
            "managed entirely in Terraform, deployed via GitHub Actions with an "
            "environment-gated approval before any real apply."
        ),
        "stack": ["Django", "PostgreSQL", "AWS", "Terraform", "ECS Fargate", "CloudFront", "GitHub Actions"],
        "url": "https://mattwindham.dev",
        "repo": "https://github.com/fattswindstorm/mattwindham.dev",
    },
    {
        "name": "On-demand EKS + ArgoCD demo",
        "description": (
            "A full-lifecycle GitOps pipeline: an admin-triggered EKS cluster running "
            "ArgoCD deploys a containerized copy of this site, with anonymous read-only "
            "dashboard access. No idle spend - the cluster is created and destroyed per "
            "session, with a scheduled nightly teardown as a hard cost safety net "
            "independent of manual action. Built to go deeper on the Kubernetes/GitOps "
            "side while studying for KCNA."
        ),
        "stack": ["EKS", "ArgoCD", "Helm", "Kubernetes", "Terraform", "GitHub Actions", "Docker"],
        "url": None,
        "repo": "https://github.com/fattswindstorm/mattwindham.dev/tree/main/terraform/eks-demo",
    },
]

CERT_PATH = [
    {
        "name": "CompTIA A+",
        "status": "done",
        "date": "Jun 2018",
        "note": "Foundation in hardware, OS, networking, and troubleshooting.",
    },
    {
        "name": "AWS Certified Cloud Practitioner",
        "status": "done",
        "date": "Apr 2021",
        "note": "Cloud fundamentals - core AWS services, pricing, and architecture.",
    },
    {
        "name": "HashiCorp Terraform Associate (004)",
        "status": "done",
        "date": "Mar 2026",
        "note": "Infrastructure as Code - validated hands-on Terraform experience.",
    },
    {
        "name": "Kubernetes and Cloud Native Associate (KCNA)",
        "status": "next",
        "date": None,
        "note": (
            "Foundational Kubernetes concepts - cloud native architecture, containers, "
            "scheduling, and observability. Currently in progress."
        ),
    },
    {
        "name": "Microsoft Azure Fundamentals (AZ-900)",
        "status": "target",
        "date": None,
        "note": (
            "Azure cloud fundamentals - core services, pricing, and architecture. Fast "
            "ramp-up that mirrors what I already know in AWS. First step into the Azure "
            "side of Ren's multi-cloud stack."
        ),
    },
    {
        "name": "Certified Kubernetes Administrator (CKA)",
        "status": "target",
        "date": None,
        "note": (
            "Hands-on cluster administration. Plan to study using AKS (Azure Kubernetes "
            "Service) - gets K8s and Azure hands-on in one track. The primary "
            "differentiator between DevOps Engineer and Senior DevOps Engineer at Ren."
        ),
    },
    {
        "name": "Microsoft Azure DevOps Engineer Expert (AZ-400)",
        "status": "target",
        "date": None,
        "note": "Azure DevOps pipelines, IaC, monitoring, and security. Most role-relevant Azure cert given Ren's use of Azure alongside AWS.",
    },
]

BUILDING_TOWARD = [
    {"label": "Azure", "note": "Terraform azurerm provider, AKS, Blob Storage, Azure Functions - mirrors existing AWS work"},
    {"label": "Container Security", "note": "Trivy, Checkov, pod security policies"},
    {"label": "FinOps", "note": "Rightsizing, spot instances, cost visibility dashboards"},
]

CERT_MARKERS = {"done": "✓", "next": "→", "target": "◎"}


def projects(request):
    cert_path = [dict(c, marker=CERT_MARKERS[c["status"]]) for c in CERT_PATH]
    return render(
        request,
        "core/projects.html",
        {
            "projects": PROJECTS,
            "cert_path": cert_path,
            "building_toward": BUILDING_TOWARD,
        },
    )
