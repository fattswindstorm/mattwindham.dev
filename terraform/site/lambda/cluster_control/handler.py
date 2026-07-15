# ---------------------------------------------------------------
# Admin-only trigger for the on-demand EKS/ArgoCD demo, plus a public
# read-only status endpoint that the site-wide "easter egg" polls.
# ---------------------------------------------------------------

import json
import os
import urllib.request
from datetime import datetime, timezone

import boto3

dynamodb = boto3.resource("dynamodb")
secretsmanager = boto3.client("secretsmanager")

STATUS_TABLE = os.environ["STATUS_TABLE"]
GITHUB_TOKEN_SECRET_ARN = os.environ["GITHUB_TOKEN_SECRET_ARN"]
GITHUB_REPO = os.environ.get("GITHUB_REPO", "fattswindstorm/mattwindham.dev")
COOLDOWN_SECONDS = int(os.environ.get("COOLDOWN_SECONDS", "600"))

status_table = dynamodb.Table(STATUS_TABLE)

CORS_HEADERS = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "https://mattwindham.dev",
}

STATUS_ITEM_ID = "cluster"


def handler(event, context):
    method = event.get("requestContext", {}).get("http", {}).get("method", "")
    path = event.get("rawPath", "")

    if method == "GET" and path == "/lab/status":
        return _get_status()

    # Everything else is admin-only.
    claims = _claims(event)
    if "admins" not in (claims.get("cognito:groups") or ""):
        return _response(403, {"error": "Forbidden"})

    if method == "POST" and path == "/lab/trigger":
        return _trigger("spin-up-eks-demo.yml", expected_status="idle", new_status="provisioning")
    if method == "POST" and path == "/lab/teardown":
        return _trigger("teardown-eks-demo.yml", expected_status="active", new_status="destroying")

    return _response(404, {"error": "Not found"})


def _claims(event):
    return event.get("requestContext", {}).get("authorizer", {}).get("jwt", {}).get("claims", {}) or {}


def _response(status, body):
    return {"statusCode": status, "headers": CORS_HEADERS, "body": json.dumps(body)}


def _get_status():
    item = status_table.get_item(Key={"id": STATUS_ITEM_ID}).get("Item") or {"status": "idle"}
    # Public route - only ever return non-sensitive fields (never
    # requested_by/timestamps/workflow_run_id).
    return _response(
        200,
        {
            "status": item.get("status", "idle"),
            "demo_url": item.get("demo_url"),
            "argocd_url": item.get("argocd_url"),
        },
    )


def _trigger(workflow_file, expected_status, new_status):
    now = datetime.now(timezone.utc)
    item = status_table.get_item(Key={"id": STATUS_ITEM_ID}).get("Item") or {}

    last_triggered_at = item.get("last_triggered_at")
    if last_triggered_at:
        elapsed = (now - datetime.fromisoformat(last_triggered_at)).total_seconds()
        if elapsed < COOLDOWN_SECONDS:
            return _response(429, {"error": f"Cooldown active, try again in {int(COOLDOWN_SECONDS - elapsed)}s"})

    # Atomic lock: only proceed if status is exactly what we expect. Two
    # near-simultaneous clicks can't both pass this.
    try:
        status_table.update_item(
            Key={"id": STATUS_ITEM_ID},
            UpdateExpression="SET #s = :new, last_triggered_at = :now",
            ConditionExpression="attribute_not_exists(#s) OR #s = :expected",
            ExpressionAttributeNames={"#s": "status"},
            ExpressionAttributeValues={
                ":new": new_status,
                ":expected": expected_status,
                ":now": now.isoformat(),
            },
        )
    except dynamodb.meta.client.exceptions.ConditionalCheckFailedException:
        return _response(409, {"error": f"Cluster is not in '{expected_status}' state"})

    _dispatch_workflow(workflow_file)
    return _response(202, {"status": new_status})


def _dispatch_workflow(workflow_file):
    token = secretsmanager.get_secret_value(SecretId=GITHUB_TOKEN_SECRET_ARN)["SecretString"]
    url = f"https://api.github.com/repos/{GITHUB_REPO}/actions/workflows/{workflow_file}/dispatches"
    body = json.dumps({"ref": "main"}).encode()
    req = urllib.request.Request(
        url,
        data=body,
        method="POST",
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "User-Agent": "resume-site-cluster-control",
        },
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        resp.read()
