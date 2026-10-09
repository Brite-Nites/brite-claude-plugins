"""Real adapters for the ads creative pipeline (BC-28221, BC-28299). Tests use fakes; see
creative.py. None of them has been run against a live account yet.

Each adapter reads its secret from the environment when it is built, never at import, so a
missing secret fails the one adapter that needs it. Secrets reach a session through
`bws run` (ADR-044) and the Railway runner as service variables.

  PLACID_API_TOKEN               PlacidClient   — static ads from Placid templates
  IMAGEKIT_PRIVATE_KEY           ImageKitPhotos — read brand-hub photos; store AI edits in the
                                                  ads folder only
  ANTHROPIC_API_KEY              ClaudeJudge    — the Claude review (via the anthropic SDK)
  ADS_CREATIVE_SLACK_BOT_TOKEN   SlackApprovals — approve or reject by the Head of GTM; needs a
                                                  Slack app that does not exist yet

Not built yet (no account, or an open hosting question — see the BC-28221 handoff):
  Text recognition (ocr)    Google Cloud Vision or Tesseract (research record, step 4)
  Render inspector          overlay colors (k-means) and logo match (OpenCV), steps 5-6
  Vertex AI photo edits     GOOGLE_APPLICATION_CREDENTIALS, VERTEX_PROJECT_ID, VERTEX_LOCATION
  Higgsfield photo edits    HIGGSFIELD_API_KEY (unattended API access unconfirmed, BC-26436)
  Hyperframes video         no key; needs Node 22+ and FFmpeg wherever it runs
Each must match the editor / renderer shape documented in creative.py.
"""

from __future__ import annotations

import base64
import json
import os
import urllib.parse
import urllib.request
import uuid

from .creative import AI_EDITED_FOLDER, AI_EDITED_TAG, BLOCKED_CONTENT


def _env(name):
    value = os.environ.get(name)
    if not value:
        raise RuntimeError(f"{name} is not set")
    return value


def _call(url, headers, payload=None):
    data = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(
        url, data=data, headers={**headers, "Content-Type": "application/json"},
        method="GET" if payload is None else "POST",
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        return json.load(resp)


def _post_form(url, headers, fields):
    """POST multipart/form-data text fields; returns the JSON reply."""
    boundary = uuid.uuid4().hex
    body = "".join(
        f'--{boundary}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'
        for k, v in fields.items()
    ) + f"--{boundary}--\r\n"
    req = urllib.request.Request(
        url, data=body.encode(), method="POST",
        headers={**headers, "Content-Type": f"multipart/form-data; boundary={boundary}"},
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        return json.load(resp)


class ImageKitPhotos:
    """brand-hub's photo library, read through ImageKit's file-details API. The one write is
    upload_ai_edit, and it can only write to the ads folder."""

    def __init__(self, private_key=None):
        token = base64.b64encode(f"{private_key or _env('IMAGEKIT_PRIVATE_KEY')}:".encode()).decode()
        self.headers = {"Authorization": f"Basic {token}"}

    def photo(self, file_id):
        d = _call(f"https://api.imagekit.io/v1/files/{urllib.parse.quote(file_id)}/details", self.headers)
        # brand-hub's approval convention: customMetadata.approval_status == "Approved".
        approved = (d.get("customMetadata") or {}).get("approval_status") == "Approved"
        return {"url": d["url"], "approved": approved}

    def upload_ai_edit(self, image_url, *, file_name):
        """Store an AI-edited photo in AI_EDITED_FOLDER, tagged AI_EDITED_TAG. The folder is fixed
        here, not an argument, and no approval metadata is set, so an edit can never land in or
        pass as brand-hub's approved library. ImageKit fetches the file from image_url."""
        d = _post_form("https://upload.imagekit.io/api/v1/files/upload", self.headers, {
            "file": image_url,
            "fileName": file_name,
            "folder": AI_EDITED_FOLDER,
            "tags": AI_EDITED_TAG,
            "useUniqueFileName": "true",
        })
        return {"file_id": d["fileId"], "url": d["url"]}


class PlacidClient:
    def __init__(self, token=None):
        self.headers = {"Authorization": f"Bearer {token or _env('PLACID_API_TOKEN')}"}

    def create_image(self, payload):
        d = _call("https://api.placid.app/api/rest/images", self.headers, payload)
        if d.get("status") != "finished":
            raise RuntimeError(f"Placid render {d.get('id')} ended {d.get('status')!r}")
        return {"id": str(d["id"]), "image_url": d["image_url"]}


# Research record (brite-gtm docs/research/2026-10-04-paid-ads-landscape-ai-creative.md): the
# judge is Claude Sonnet 5.5, a different model family from the photo editors.
JUDGE_MODEL = "claude-sonnet-5-5"

_JUDGE_INSTRUCTIONS = """You review one paid ad against Brite's brand rules below. Return three
things.

fonts: name the typeface of each block of text in the ad. Skip the logo; it is artwork. Use a
name from the fonts the template locks, given with the ad, or "other" when the text is set in
none of them.

blocked: list every face, house number and license plate you can see in the image, with where
it is. These identify a client's family, home or car. Return an empty list when there are none.

pass and reasons: judge taste only: on-brand look, legibility, contrast, layout, a premium
feel, copy tone, the color pairings, and the brand's don'ts. Code has already checked the exact
text, phone number, overlay colors and logo, so do not re-check those. Fail the ad if any taste
rule is broken, with one short reason per broken rule.

Brand rules:
"""

_VERDICT_SCHEMA = {
    "type": "object",
    "properties": {
        "pass": {"type": "boolean"},
        "reasons": {"type": "array", "items": {"type": "string"}},
        "fonts": {"type": "array", "items": {"type": "string"}},
        "blocked": {"type": "array", "items": {
            "type": "object",
            "properties": {"kind": {"type": "string", "enum": list(BLOCKED_CONTENT)},
                           "detail": {"type": "string"}},
            "required": ["kind", "detail"],
            "additionalProperties": False,
        }},
    },
    "required": ["pass", "reasons", "fonts", "blocked"],
    "additionalProperties": False,
}


class ClaudeJudge:
    def __init__(self, client=None):
        if client is None:
            import anthropic  # lazy: the CI python-units job installs only pytest

            client = anthropic.Anthropic()  # reads ANTHROPIC_API_KEY
        self.client = client

    def review(self, image_url, rules, locked):
        response = self.client.beta.messages.create(
            model=JUDGE_MODEL,
            max_tokens=16000,
            betas=["server-side-fallback-2026-07-01"],
            fallbacks="default",
            # Same rules on every check: keep them first and cached.
            system=[{
                "type": "text",
                "text": _JUDGE_INSTRUCTIONS + json.dumps(rules, sort_keys=True, indent=1),
                "cache_control": {"type": "ephemeral"},
            }],
            # The locked fonts and colors change per template, so they go after the cached rules.
            messages=[{"role": "user", "content": [
                {"type": "image", "source": {"type": "url", "url": image_url}},
                {"type": "text", "text": "Review this ad. The template locks these fonts and colors:\n"
                                         + json.dumps(locked, sort_keys=True)},
            ]}],
            output_config={"format": {"type": "json_schema", "schema": _VERDICT_SCHEMA}},
        )
        if response.stop_reason == "refusal":
            # A judge that would not look has not passed the ad.
            return {"pass": False, "reasons": ["the judge declined to review this ad"], "fonts": [], "blocked": []}
        return json.loads(next(b.text for b in response.content if b.type == "text"))


class SlackApprovals:
    """Sends one AI-edited ad to the Head of GTM as a Slack direct message and reads the answer
    from the thread: the first reply from that person that says approve or reject. Replies from
    anyone else are ignored. Needs a bot token with chat:write and im:history; no Slack app
    exists yet. approver_user_id and approver_name come from the private runner config."""

    def __init__(self, approver_user_id, approver_name, token=None):
        self.approver_user_id = approver_user_id
        self.approver_name = approver_name
        self.headers = {"Authorization": f"Bearer {token or _env('ADS_CREATIVE_SLACK_BOT_TOKEN')}"}

    def _api(self, method, payload=None, query=None):
        url = f"https://slack.com/api/{method}" + (f"?{urllib.parse.urlencode(query)}" if query else "")
        d = _call(url, self.headers, payload)
        if not d.get("ok"):
            raise RuntimeError(f"Slack {method} failed: {d.get('error')}")
        return d

    def request(self, text, image_url):
        # A user id as the channel posts to the app's direct message with that person.
        d = self._api("chat.postMessage", {"channel": self.approver_user_id, "text": f"{text}\n{image_url}"})
        return f"{d['channel']}:{d['ts']}"

    def decision(self, request_id):
        channel, ts = request_id.split(":", 1)
        replies = self._api("conversations.replies", query={"channel": channel, "ts": ts})["messages"][1:]
        for m in replies:
            answer = (m.get("text") or "").strip().lower()
            if m.get("user") == self.approver_user_id and answer in ("approve", "reject"):
                return {"decision": answer, "by": self.approver_name}
        return None
