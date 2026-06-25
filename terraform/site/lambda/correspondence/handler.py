import json
import os
from datetime import datetime, timezone

import boto3
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource("dynamodb")
ses = boto3.client("ses", region_name="us-east-1")

OPPORTUNITIES_TABLE = os.environ["OPPORTUNITIES_TABLE"]
MESSAGES_TABLE = os.environ["MESSAGES_TABLE"]
FROM_EMAIL = os.environ["FROM_EMAIL"]
SITE_URL = os.environ["SITE_URL"]

opportunities = dynamodb.Table(OPPORTUNITIES_TABLE)
messages = dynamodb.Table(MESSAGES_TABLE)

CORS_HEADERS = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "https://mattwindham.dev",
}


class _Forbidden(Exception):
    pass


class _NotFound(Exception):
    pass


def handler(event, context):
    method = event.get("requestContext", {}).get("http", {}).get("method", "")
    thread_id = (event.get("pathParameters") or {}).get("id")

    claims = _claims(event)
    sub = claims.get("sub")
    if not sub:
        return _response(401, {"error": "Unauthorized"})

    is_admin = _is_admin(claims)

    try:
        if method == "GET" and thread_id is None:
            return _list_threads(sub, is_admin)
        if method == "GET" and thread_id is not None:
            return _thread_detail(thread_id, sub, is_admin)
        if method == "POST" and thread_id is not None:
            return _post_message(event, thread_id, sub, is_admin)
    except _NotFound:
        return _response(404, {"error": "Not found"})
    except _Forbidden:
        return _response(403, {"error": "Forbidden"})

    return _response(404, {"error": "Not found"})


def _claims(event):
    return event.get("requestContext", {}).get("authorizer", {}).get("jwt", {}).get("claims", {}) or {}


def _is_admin(claims):
    # HTTP API JWT authorizers flatten array claims like cognito:groups into
    # a stringified list (e.g. "[admins]"), not real JSON - substring check.
    return "admins" in (claims.get("cognito:groups") or "")


def _response(status, body):
    return {"statusCode": status, "headers": CORS_HEADERS, "body": json.dumps(body)}


def _get_thread(thread_id):
    item = opportunities.get_item(Key={"id": thread_id}).get("Item")
    if not item:
        raise _NotFound()
    return item


def _authorize_thread(item, sub, is_admin):
    if not is_admin and item.get("owner_sub") != sub:
        raise _Forbidden()


def _list_threads(sub, is_admin):
    if is_admin:
        items = opportunities.scan().get("Items", [])
    else:
        items = opportunities.query(
            IndexName="owner_sub-index",
            KeyConditionExpression=Key("owner_sub").eq(sub),
        ).get("Items", [])
    items.sort(key=lambda i: i.get("submitted_at", ""), reverse=True)
    return _response(200, {"threads": items})


def _thread_detail(thread_id, sub, is_admin):
    item = _get_thread(thread_id)
    _authorize_thread(item, sub, is_admin)
    thread_messages = messages.query(
        KeyConditionExpression=Key("thread_id").eq(thread_id),
        ScanIndexForward=True,
    ).get("Items", [])
    return _response(200, {"submission": item, "messages": thread_messages})


def _post_message(event, thread_id, sub, is_admin):
    item = _get_thread(thread_id)
    _authorize_thread(item, sub, is_admin)

    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return _response(400, {"error": "Invalid JSON"})

    text = (body.get("body") or "").strip()
    if not text:
        return _response(400, {"error": "Message body is required"})

    message = {
        "thread_id": thread_id,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "sender_sub": sub,
        "sender_role": "owner" if is_admin else "recruiter",
        "body": text,
    }
    messages.put_item(Item=message)

    if message["sender_role"] == "owner":
        _notify_reply(item)

    return _response(200, {"message": message})


def _notify_reply(item):
    subject = "[mattwindham.dev] Reply to your opportunity submission"
    body = (
        f"Matthew Windham replied to your opportunity submission "
        f"({item.get('job_title', 'your role')} at {item.get('company', 'your company')}).\n\n"
        f"Log in to view and reply: {SITE_URL}/portal/dashboard\n"
    )
    ses.send_email(
        Source=FROM_EMAIL,
        Destination={"ToAddresses": [item["email"]]},
        Message={
            "Subject": {"Data": subject},
            "Body": {"Text": {"Data": body}},
        },
    )
