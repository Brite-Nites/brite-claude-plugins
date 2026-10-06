"""Real adapters for the ads creative pipeline (BC-28221). Tests use fakes; see creative.py.

Each adapter reads its secret from the environment when it is built, never at import, so a
missing secret fails the one adapter that needs it. Secrets reach a session through
`bws run` (ADR-044) and the Railway runner as service variables.

  PLACID_API_TOKEN       PlacidClient   — static ads from Placid templates
  IMAGEKIT_PRIVATE_KEY   ImageKitPhotos — read brand-hub photos (read-only use)
  ANTHROPIC_API_KEY      ClaudeJudge    — the taste judge (via the anthropic SDK)

Not built yet (no account, or an open hosting question — see the BC-28221 handoff):
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


class ImageKitPhotos:
    """brand-hub's photo library, read through ImageKit's file-details API. Never writes."""

    def __init__(self, private_key=None):
        token = base64.b64encode(f"{private_key or _env('IMAGEKIT_PRIVATE_KEY')}:".encode()).decode()
        self.headers = {"Authorization": f"Basic {token}"}

    def photo(self, file_id):
        d = _call(f"https://api.imagekit.io/v1/files/{urllib.parse.quote(file_id)}/details", self.headers)
        # brand-hub's approval convention: customMetadata.approval_status == "Approved".
        approved = (d.get("customMetadata") or {}).get("approval_status") == "Approved"
        return {"url": d["url"], "approved": approved}


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

_JUDGE_INSTRUCTIONS = """You judge one paid ad against Brite's brand rules below.
Judge only taste: on-brand look, legibility, contrast, layout, a premium feel, copy tone, and
the brand's don'ts. Code has already checked the exact text, phone number, fonts, colors and
logo, so do not re-check those. Fail the ad if any taste rule is broken, with one short reason
per broken rule.

Brand rules:
"""

_VERDICT_SCHEMA = {
    "type": "object",
    "properties": {"pass": {"type": "boolean"}, "reasons": {"type": "array", "items": {"type": "string"}}},
    "required": ["pass", "reasons"],
    "additionalProperties": False,
}


class ClaudeJudge:
    def __init__(self, client=None):
        if client is None:
            import anthropic  # lazy: the CI python-units job installs only pytest

            client = anthropic.Anthropic()  # reads ANTHROPIC_API_KEY
        self.client = client

    def review(self, image_url, rules):
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
            messages=[{"role": "user", "content": [
                {"type": "image", "source": {"type": "url", "url": image_url}},
                {"type": "text", "text": "Judge this ad."},
            ]}],
            output_config={"format": {"type": "json_schema", "schema": _VERDICT_SCHEMA}},
        )
        if response.stop_reason == "refusal":
            # A judge that would not look has not passed the ad.
            return {"pass": False, "reasons": ["the judge declined to review this ad"]}
        return json.loads(next(b.text for b in response.content if b.type == "text"))
