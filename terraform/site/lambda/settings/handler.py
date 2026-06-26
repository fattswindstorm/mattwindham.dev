import json
import os
from datetime import datetime, timezone

import boto3
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource("dynamodb")
cognito = boto3.client("cognito-idp", region_name="us-east-1")

USER_SETTINGS_TABLE = os.environ["USER_SETTINGS_TABLE"]
OPPORTUNITIES_TABLE = os.environ["OPPORTUNITIES_TABLE"]
MESSAGES_TABLE = os.environ["MESSAGES_TABLE"]
USER_POOL_ID = os.environ["USER_POOL_ID"]

user_settings = dynamodb.Table(USER_SETTINGS_TABLE)
opportunities = dynamodb.Table(OPPORTUNITIES_TABLE)
messages = dynamodb.Table(MESSAGES_TABLE)

CORS_HEADERS = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "https://mattwindham.dev",
}

DEFAULT_SETTINGS = {
    "email_notifications": True,
}


def handler(event, context):
    method = event.get("requestContext", {}).get("http", {}).get("method", "")
    path = event.get("rawPath", "")

    claims = _claims(event)
    sub = claims.get("sub")
    if not sub:
        return _response(401, {"error": "Unauthorized"})

    if method == "GET" and path == "/settings":
        return _get_settings(sub)
    if method == "PUT" and path == "/settings":
        return _put_settings(event, sub)
    if method == "DELETE" and path == "/settings/account":
        username = claims.get("cognito:username")
        return _delete_account(sub, username)

    return _response(404, {"error": "Not found"})


def _claims(event):
    return event.get("requestContext", {}).get("authorizer", {}).get("jwt", {}).get("claims", {}) or {}


def _response(status, body):
    return {"statusCode": status, "headers": CORS_HEADERS, "body": json.dumps(body)}


def _get_settings(sub):
    item = user_settings.get_item(Key={"sub": sub}).get("Item")
    if not item:
        item = {**DEFAULT_SETTINGS, "sub": sub, "created_at": datetime.now(timezone.utc).isoformat()}
        user_settings.put_item(Item=item)
    return _response(200, {"settings": {k: v for k, v in item.items() if k != "sub"}})


def _put_settings(event, sub):
    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return _response(400, {"error": "Invalid JSON"})

    updates = {}
    if "email_notifications" in body:
        val = body["email_notifications"]
        if not isinstance(val, bool):
            return _response(400, {"error": "email_notifications must be a boolean"})
        updates["email_notifications"] = val

    if not updates:
        return _response(400, {"error": "No valid fields to update"})

    item = user_settings.get_item(Key={"sub": sub}).get("Item") or {
        **DEFAULT_SETTINGS,
        "sub": sub,
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    item.update(updates)
    user_settings.put_item(Item=item)

    return _response(200, {"settings": {k: v for k, v in item.items() if k != "sub"}})


def _delete_account(sub, username):
    # 1. Delete all messages for this user's threads
    threads = opportunities.query(
        IndexName="owner_sub-index",
        KeyConditionExpression=Key("owner_sub").eq(sub),
    ).get("Items", [])

    for thread in threads:
        thread_id = thread["id"]
        msgs = messages.query(
            KeyConditionExpression=Key("thread_id").eq(thread_id),
        ).get("Items", [])
        for msg in msgs:
            messages.delete_item(Key={"thread_id": msg["thread_id"], "created_at": msg["created_at"]})
        opportunities.delete_item(Key={"id": thread_id})

    # 2. Delete user settings
    user_settings.delete_item(Key={"sub": sub})

    # 3. Delete Cognito user
    if username:
        try:
            cognito.admin_delete_user(UserPoolId=USER_POOL_ID, Username=username)
        except cognito.exceptions.UserNotFoundException:
            pass

    return _response(200, {"ok": True})
