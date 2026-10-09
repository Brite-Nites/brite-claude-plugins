"""Fakes for the ads-agent run seam. Each records every call so tests assert on calls.

Same method names as the real adapters in `adapters.py`. Later tickets reuse these:
act mode (BC-28216) asserts on `FakeGoogleAds.write_calls`; Meta (BC-28218) adds a
fake with the same shape.
"""

from __future__ import annotations

import copy


class FakeGoogleAds:
    platform = "google_ads"

    def __init__(self, settings):
        self._settings = copy.deepcopy(settings)
        self.calls: list[tuple] = []

    def read_settings(self, account_ids):
        self.calls.append(("read_settings", tuple(account_ids)))
        return [s for s in copy.deepcopy(self._settings) if s["account_id"] in account_ids]

    def apply(self, change):
        self.calls.append(("apply", change["key"]))

    @property
    def write_calls(self):
        return [c for c in self.calls if c[0] != "read_settings"]


class FakeWarehouse:
    def __init__(self, snapshot):
        self._snapshot = copy.deepcopy(snapshot)
        self.change_log: list[dict] = []
        self.calls: list[tuple] = []

    def read_snapshot(self):
        self.calls.append(("read_snapshot",))
        return copy.deepcopy(self._snapshot)

    def read_logged_keys(self, run_date):
        self.calls.append(("read_logged_keys", run_date))
        return {r["key"] for r in self.change_log if r["run_date"] == run_date}

    def write_change_log(self, rows):
        """Insert rows whose key is not logged yet, like the real MERGE."""
        self.calls.append(("write_change_log", len(rows)))
        logged = {r["key"] for r in self.change_log}
        self.change_log += [copy.deepcopy(r) for r in rows if r["key"] not in logged]


class FakeSlack:
    def __init__(self):
        self.posts: list[str] = []

    def post(self, text):
        self.posts.append(text)


# ── creative pipeline (creative.py) ─────────────────────────────────────────


class FakeImageKit:
    """brand-hub's library plus the ads folder. `library` holds the approved photos and must
    never change; AI edits land in `files` under the folder the caller gave."""

    def __init__(self, library):
        self.library = copy.deepcopy(library)
        self.files: dict[str, dict] = {}  # file id -> {"url", "approved", "folder", "tags"}
        self.uploads: list[dict] = []

    def photo(self, file_id):
        if file_id in self.library:
            return copy.deepcopy(self.library[file_id])
        f = self.files[file_id]
        return {"url": f["url"], "approved": f["approved"]}

    def upload_ai_edit(self, image_url, *, file_name):
        # Same contract as the real adapter: the folder and tag are fixed, never the library.
        from .creative import AI_EDITED_FOLDER, AI_EDITED_TAG

        file_id = f"fake-upload-{len(self.uploads) + 1}"
        upload = {"source_url": image_url, "file_name": file_name,
                  "folder": AI_EDITED_FOLDER, "tags": [AI_EDITED_TAG]}
        self.uploads.append(upload)
        url = f"https://example.invalid{AI_EDITED_FOLDER}{file_name}.jpg"
        self.files[file_id] = {"url": url, "approved": False, "folder": upload["folder"], "tags": upload["tags"]}
        return {"file_id": file_id, "url": url}


class FakeRenderer:
    """Stands in for Placid (create_image) and Hyperframes (render_video)."""

    def __init__(self, url="https://example.invalid/render-1.png"):
        self.requests: list[dict] = []
        self.url = url

    def create_image(self, payload):
        self.requests.append(payload)
        return {"id": "render-1", "image_url": self.url}

    def render_video(self, payload):
        self.requests.append(payload)
        return {"id": "video-1", "url": self.url}


class FakeEditor:
    """Stands in for Vertex AI or Higgsfield."""

    model = "fake-editor:image-v1"

    def __init__(self):
        self.calls: list[tuple] = []

    def edit(self, image_url, prompt, settings):
        self.calls.append((image_url, prompt, settings))
        return "https://example.invalid/editor-output/fake-photo-1-edited.jpg"


class FakeOCR:
    """Text recognition: returns what it was told the render says."""

    def __init__(self, text, confidence=0.98):
        self.result = {"text": text, "confidence": confidence}
        self.calls: list[str] = []

    def read_text(self, image_url):
        self.calls.append(image_url)
        return dict(self.result)


class FakeInspector:
    """Pixel read of the render: overlay colors and the logo found."""

    def __init__(self, overlay_colors, logo):
        self.result = {"overlay_colors": list(overlay_colors), "logo": logo}
        self.calls: list[str] = []

    def inspect(self, image_url):
        self.calls.append(image_url)
        return copy.deepcopy(self.result)


class FakeJudge:
    """Stands in for the Claude review: fonts named, blocked content, and taste."""

    def __init__(self, fonts=("GT Eesti", "Peclet"), blocked=(), passed=True, reasons=()):
        self.verdict = {"pass": passed, "reasons": list(reasons), "fonts": list(fonts),
                        "blocked": [dict(b) for b in blocked]}
        self.calls: list[tuple] = []

    def review(self, image_url, rules, locked):
        self.calls.append((image_url, copy.deepcopy(locked)))
        return copy.deepcopy(self.verdict)


class FakeSlackApprovals:
    """The Slack approval thread to the Head of GTM. reply() is a person answering; only the
    approver's approve or reject counts, like the real adapter."""

    def __init__(self, approver="fake.head-of-gtm"):
        self.approver = approver
        self.requests: list[dict] = []
        self.replies: dict[str, list[tuple]] = {}

    def request(self, text, image_url):
        request_id = f"fake-dm:{len(self.requests) + 1}"
        self.requests.append({"id": request_id, "text": text, "image_url": image_url})
        self.replies[request_id] = []
        return request_id

    def reply(self, request_id, text, by):
        self.replies[request_id].append((by, text))

    def decision(self, request_id):
        for by, text in self.replies.get(request_id, []):
            if by == self.approver and text.strip().lower() in ("approve", "reject"):
                return {"decision": text.strip().lower(), "by": by}
        return None
