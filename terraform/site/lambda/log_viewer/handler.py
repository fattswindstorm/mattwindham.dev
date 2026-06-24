import base64
import gzip
import hmac
import html
import os
import urllib.parse

import boto3

s3 = boto3.client("s3")

BUCKET = os.environ["LOGS_BUCKET"]
PREFIX = os.environ.get("LOGS_PREFIX", "cloudfront/")
USERNAME = os.environ["DASHBOARD_USERNAME"]
PASSWORD = os.environ["DASHBOARD_PASSWORD"]
MAX_FILES = 6
MAX_ROWS = 200

PAGE_STYLE = """
<style>
  :root { --bg:#0b0e14; --bg-raised:#11151d; --border:#1f2733; --text:#e6e9ef; --text-dim:#92a0b3; --accent:#ff9900; --mono:"SFMono-Regular",Consolas,"Liberation Mono",Menlo,monospace; }
  * { box-sizing: border-box; }
  body { margin:0; padding:2rem; background:var(--bg); color:var(--text); font-family:var(--mono); }
  h1 { font-size:1.4rem; margin:0 0 1rem; color:#fff; }
  table { width:100%; border-collapse:collapse; font-size:0.85rem; }
  th, td { text-align:left; padding:0.5rem 0.75rem; border-bottom:1px solid var(--border); white-space:nowrap; }
  th { color:var(--text-dim); font-weight:600; }
  tr:hover { background:var(--bg-raised); }
  .empty { color:var(--text-dim); }
</style>
"""


def _unauthorized():
    return {
        "statusCode": 401,
        "headers": {
            "WWW-Authenticate": 'Basic realm="mattwindham.dev"',
            "Content-Type": "text/plain",
        },
        "body": "Unauthorized",
    }


def _check_auth(headers):
    auth = headers.get("authorization") or headers.get("Authorization") or ""
    if not auth.startswith("Basic "):
        return False
    try:
        decoded = base64.b64decode(auth[len("Basic "):]).decode("utf-8")
        user, _, pwd = decoded.partition(":")
    except Exception:
        return False
    return hmac.compare_digest(user, USERNAME) and hmac.compare_digest(pwd, PASSWORD)


def _list_recent_log_keys():
    paginator = s3.get_paginator("list_objects_v2")
    objects = []
    for page in paginator.paginate(Bucket=BUCKET, Prefix=PREFIX):
        objects.extend(page.get("Contents", []))
    objects.sort(key=lambda o: o["LastModified"], reverse=True)
    return [o["Key"] for o in objects[:MAX_FILES]]


def _parse_log_file(key):
    obj = s3.get_object(Bucket=BUCKET, Key=key)
    raw = gzip.decompress(obj["Body"].read()).decode("utf-8")

    fields = []
    rows = []
    for line in raw.splitlines():
        if line.startswith("#Fields:"):
            fields = line[len("#Fields:"):].strip().split(" ")
            continue
        if line.startswith("#"):
            continue
        values = line.split("\t")
        if len(values) != len(fields):
            continue
        rows.append(dict(zip(fields, values)))
    return rows


def _render_table(rows):
    if not rows:
        return '<p class="empty">No visits logged yet.</p>'

    columns = ("Time (UTC)", "Client IP", "Method", "Path", "Status", "Referer", "User-Agent")
    head = "".join(f"<th>{c}</th>" for c in columns)

    body_rows = []
    for row in rows:
        timestamp = f"{row.get('date', '')} {row.get('time', '')}".strip()
        values = (
            timestamp,
            row.get("c-ip", "-"),
            row.get("cs-method", "-"),
            urllib.parse.unquote(row.get("cs-uri-stem", "-")),
            row.get("sc-status", "-"),
            urllib.parse.unquote(row.get("cs(Referer)", "-")),
            urllib.parse.unquote(row.get("cs(User-Agent)", "-")),
        )
        cells = "".join(f"<td>{html.escape(v)}</td>" for v in values)
        body_rows.append(f"<tr>{cells}</tr>")

    return f"<table><thead><tr>{head}</tr></thead><tbody>{''.join(body_rows)}</tbody></table>"


def handler(event, context):
    headers = event.get("headers") or {}
    if not _check_auth(headers):
        return _unauthorized()

    rows = []
    for key in _list_recent_log_keys():
        rows.extend(_parse_log_file(key))

    rows.sort(key=lambda r: (r.get("date", ""), r.get("time", "")), reverse=True)
    rows = rows[:MAX_ROWS]

    body = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Visitor Log</title>
{PAGE_STYLE}
</head>
<body>
<h1>Recent Visitors ({len(rows)})</h1>
{_render_table(rows)}
</body>
</html>"""

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "text/html; charset=utf-8"},
        "body": body,
    }
