import json
import os
import uuid
import boto3
from datetime import datetime, timezone

dynamodb = boto3.resource("dynamodb")
ses = boto3.client("ses", region_name="us-east-1")

TABLE_NAME = os.environ["OPPORTUNITIES_TABLE"]
NOTIFY_EMAIL = os.environ["NOTIFY_EMAIL"]
FROM_EMAIL = os.environ["FROM_EMAIL"]

REQUIRED = [
    "name", "email", "company", "role",
    "job_title", "job_description", "employment_type", "compensation_range",
]

LOW_COMP_RANGES = {"50-150k"}

COMP_LABELS = {
    "50-150k":  "$50k–$150k/yr",
    "150-200k": "$150k–$200k/yr",
    "200-500k": "$200k–$500k/yr",
    "500k+":    "$500k+/yr",
}

TYPE_LABELS = {
    "full-time": "Full Time",
    "contract":  "Contract",
    "c2h":       "Contract-to-Hire",
}


def handler(event, context):
    headers = {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "https://mattwindham.dev",
    }

    if event.get("requestContext", {}).get("http", {}).get("method") == "OPTIONS":
        return {"statusCode": 200, "headers": headers, "body": ""}

    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return {"statusCode": 400, "headers": headers, "body": json.dumps({"error": "Invalid JSON"})}

    missing = [f for f in REQUIRED if not body.get(f, "").strip()]
    if missing:
        return {
            "statusCode": 400,
            "headers": headers,
            "body": json.dumps({"error": f"Missing fields: {', '.join(missing)}"}),
        }

    emp_type = body["employment_type"]
    comp_range = body["compensation_range"]
    low_comp = emp_type in ("full-time", "c2h") and comp_range in LOW_COMP_RANGES

    record = {
        "id":                 str(uuid.uuid4()),
        "submitted_at":       datetime.now(timezone.utc).isoformat(),
        "name":               body["name"].strip(),
        "email":              body["email"].strip().lower(),
        "company":            body["company"].strip(),
        "recruiter_role":     body["role"],
        "job_title":          body["job_title"].strip(),
        "job_description":    body["job_description"].strip(),
        "employment_type":    emp_type,
        "compensation_range": comp_range,
        "contract_length":    body.get("contract_length", "").strip(),
        "notes":              body.get("notes", "").strip(),
        "low_comp":           low_comp,
    }

    dynamodb.Table(TABLE_NAME).put_item(Item=record)
    _send_notification(record)

    return {
        "statusCode": 200,
        "headers": headers,
        "body": json.dumps({"ok": True, "low_comp": low_comp}),
    }


def _send_notification(r):
    comp_label = COMP_LABELS.get(r["compensation_range"], r["compensation_range"])
    type_label = TYPE_LABELS.get(r["employment_type"], r["employment_type"])
    flag = " [LOW COMP]" if r["low_comp"] else ""

    subject = f"[mattwindham.dev] Opportunity from {r['company']}{flag}"
    body = f"""New opportunity submission from mattwindham.dev

From:     {r['name']} ({r['email']})
Company:  {r['company']}
Role:     {r['recruiter_role']}
Position: {r['job_title']}
Type:     {type_label}
Comp:     {comp_label}
Length:   {r['contract_length'] or 'N/A'}

--- Job Description ---
{r['job_description']}

--- Notes ---
{r['notes'] or '(none)'}

Record ID: {r['id']}
Submitted: {r['submitted_at']}
"""
    ses.send_email(
        Source=FROM_EMAIL,
        Destination={"ToAddresses": [NOTIFY_EMAIL]},
        Message={
            "Subject": {"Data": subject},
            "Body": {"Text": {"Data": body}},
        },
    )
