---
description: DEPRECATED — use /workflows:raise-a-ticket instead. Forwards to the cross-product, Linear-routed intake command that files bugs and ideas/feedback as needs-triage for /triage.
---

# Bug Report — DEPRECATED

> **This command is deprecated.** It has been superseded by
> **`/workflows:raise-a-ticket`**, which does everything bug-report did and more:
> cross-product routing (resolves the right Linear team + project instead of asking
> every time), a Bug **or** Idea/Feedback fork, canonical CDR-016 labels
> (`type:bug` / `type:task`, not the legacy `"Bug"` label), a `needs-triage` handoff
> to `/triage`, and an adaptive developer/operator intake.

**Do not run this flow.** Instead, read and follow
[`raise-a-ticket.md`](./raise-a-ticket.md) and run that procedure end-to-end, passing
along any `$ARGUMENTS` as the starting description.

If you typed `/workflows:bug-report` out of habit: switch to `/workflows:raise-a-ticket`.
This shim is retained only so existing muscle memory and links still land somewhere useful;
it will be removed in a future release.
