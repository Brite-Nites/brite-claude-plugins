# Holden's Command Toolkit — Overview & Handbook Notes

> Notes from **"New Tricks by Holden"**, 6/1/2026. Captured from the session recording.
> Audience: the team (esp. folks who got Holden's "100 notes" and want to know how this fits together).
> Status: working notes meant to share — not a spec, not final docs.
> Scope: covers exactly the 13 commands Holden walked through — nothing added beyond that list.

---

## TL;DR

Holden has been dogfooding a set of slash-commands that turn "talking to Claude" into a
repeatable, durable workflow. The big mental shift:

- **These are a *toolkit*, not a project lifecycle.** There's no "create a project" step here.
  They assume a repo already exists, and they help you *think → crystallize → build → verify*
  inside it. Greenfield scaffolding is deliberately out of scope (that's what FDA /
  `project-start` is for — a different problem).
- **Commands are atomic and chainable.** The trend Holden is following (from Twitter/Discord
  practitioners) is *don't be over-prescriptive*. Each command does one small thing; you chain
  them together for a flow. He's actively experimenting with **prompt-chaining** (one command's
  output becomes the prompt that boots the next session).
- **Continuous sessions beat cold starts.** Instead of "pick issue → work → close → repeat," you
  keep one rich session alive across related issues and **hand off** context into fresh sessions
  so each new one starts ~5–10% context-full but fully oriented. Holden has chained ~9 sessions
  back-to-back this way.

> ⚠️ **Where these live:** most of these commands are Holden's *personal* skill toolkit (adapted
> from an external practitioner's skills). They're installed and available to the team as top-level
> `/commands`, **not** part of the `brite-claude-plugins` repo. The one exception is
> `marketing:capture-idea`, which he's adding *into* the marketing plugin.

---

## Status legend

| Marker | Meaning |
|--------|---------|
| 🟢 **Live** | Available now as a `/command` and in active use |
| 🟡 **In progress** | Holden is building / refining it; not fully baked |

---

## The commands

### Think & scope

| Command | Status | What it does |
|---------|--------|--------------|
| `/grill-me` | 🟢 | Interviews you relentlessly with questions to sharpen your thinking on any decision. Works in **any** project (not code-specific). Holden uses it for non-code decisions too (e.g. weighing tradeoffs on the SEC stuff). |
| `/grill-with-docs` | 🟢 | Same grilling, but **code-base-aware and writes things down.** Uncovers undiscussed requirements and edge cases ("you don't know what you don't know"), gets you + Claude + the work on the same page, then **lazily writes ADRs** (Architecture Decision Records) into `docs/adrs/` as you agree on things. Often asks 15–50 questions. Doubles as a **scoping** command — start with "I have this idea / this bug, help me scope it." Must be run **inside the repo** so it's scoped to that space. |
| `/zoom-out` | 🟢 | "I'm lost / walking away — show me where we are." Draws an ASCII diagram of what's shipped, what's next, where you fit, and why it matters. Great mid-grill when you've lost the thread, or end-of-day so you can re-enter easily. |
| `/deep-research` | 🟢 ⚠️ | Spins up an **agent swarm** to answer hard technical questions with best practices. **Eats tokens, runs long, spawns many agents without asking.** Use when a wrong answer has big downstream cost: "I don't know enough to answer this — go research, then `/grill-me` on the findings." |
| `/teach` | 🟢 | Builds an **HTML page** explaining any concept with **quiz questions** at the bottom. You answer; responses get injected back into the session; it detects misunderstandings and re-explains. Temp files **auto-expire after ~36h** and are git-ignored (no cleanup needed). Holden uses it mid-grill: "teach me these concepts until I can give an informed answer." |

### Crystallize into work

| Command | Status | What it does |
|---------|--------|--------------|
| `/to-prd` | 🟢 | At the end of a session, turns the **current conversation context** into a PRD → a Linear doc. Does **not** interview you — it synthesizes what's already been discussed. Asks which milestone to file under. Leave it as a parked requirements doc, or proceed to issues. |
| `/to-issues` | 🟢 | Breaks a PRD into many small, well-scoped Linear issues following our issue conventions. Uses **vertical slices / tracer bullets** (thin end-to-end functionality) rather than horizontal layers — the TDD-friendly shape. Looks for a requirements doc first. *(Suggested improvement: if it has nothing to reference, kick back and ask.)* |

### Build

| Command | Status | What it does |
|---------|--------|--------------|
| `/tdd` | 🟢 | Test-driven build loop (red-green-refactor) through a full vertical slice. Already exists inside `workflows:session-start`, but as a standalone it **keeps the existing conversation context** instead of cold-pulling a Linear issue — so after `/to-prd` → `/to-issues` you can just `/tdd` and jump straight into building. Auto-builds an in-session task checklist. (Continues into the existing review + ship flow, unchanged.) |
| `/handoff` | 🟢 | The keystone of the continuous-session workflow. Compresses the **entire session** into a big (~3k word) handoff doc — codebase review, who you're talking to, issues shipped, open questions, edge cases, gotchas — **plus a prompt** to boot the next session. Holden's chain prompt has the new session start by running `/grill-with-docs` and emit a verification blurb you paste back to confirm the handoff landed. |

### Bugs & triage

| Command | Status | What it does |
|---------|--------|--------------|
| `/bug-report` | 🟡 (almost done) | File a bug from **anywhere**. Uses `/grill-me` internally to capture screenshots, repro steps, who's involved, tradeoffs. Then files a Linear issue labeled `bug` and asks which milestone. **Lazy-loading pattern:** if you're in a repo it reads `CONTEXT.md` for the Linear-project + GitHub links (and saves them back if missing); if you're not in a repo it asks where to file. Built specifically so non-engineers (e.g. the BriteBase folks) can file clean bugs. *Next: make it FDA-milestone-aware so it self-assigns.* |
| `/triage` | 🟢 | Routes issues through a decision flow. Holden triages a handed-off bug into: `bug` / `enhancement` / `needs-info` / `ready-for-agent` / `ready-for-human` / `won't-fix`. `needs-info` drafts clarifying questions back to the reporter. |

### Cleanup

| Command | Status | What it does |
|---------|--------|--------------|
| `/improve-codebase-architecture` | 🟢 | "Trash cleanup." Premise: AI-generated code is garbage by default, so you run cleanup **independently on a regular cadence**, not in your normal flow. Outputs a list of fixes; tag each `needs-triage` and shape into real issues. **Great cron-job candidate** — run nightly, auto-file improvement issues. Won't relitigate decisions already in `docs/adrs/`. |

### Idea capture

| Command | Status | What it does |
|---------|--------|--------------|
| `marketing:capture-idea` | 🟡 | Lightweight campaign-brief capture, added to the **marketing plugin**. Drops the idea into a Linear "ideas" milestone; `marketing:plan-campaign` then offers to pick from that bucket. Can prompt for a Salesforce deal link / past-customer example. Runs **anywhere** (even the desktop app) — repo-independent. Good fit for Dean. |

---

## The two flows Holden walked

He framed everything as **a toolkit you enter from two directions**, illustrated with an LMS example
(continue a half-finished training module / a mobile quiz bug).

### Push — top-down (you have an idea)
```
talk to Claude  →  /grill-with-docs (resolve intent, write CONTEXT.md + ADRs)
                →  (lean on /grill-me, /teach, /deep-research, /zoom-out as needed)
                →  /to-prd  →  /to-issues (vertical-slice tracer bullets, labeled ready-for-agent)
                →  /tdd (build the slice red→green→refactor; then your normal review + ship)
                →  /handoff (boot the next session with full context)
```

### Pull — bottom-up (a bug hits you)
```
/bug-report  →  lands as needs-triage
             →  /triage (bug? enhancement? needs-info? ready-for-agent/human? won't-fix?)
             →  ready-for-agent  →  /tdd  →  (your normal review + ship)
```

### On a cadence
```
/improve-codebase-architecture  →  scan → file improvement issues (good nightly cron job)
```

Both flows share state through a few **files in the repo** — primarily `CONTEXT.md` (lazy-loaded
context: Linear project link, GitHub link, "when the user says X they mean Y" notes) and
`docs/adrs/` (decision records written lazily as you agree on things).

**Real example Holden gave:** a teammate's data-hub project mentioned "an MCP server to call the
enrichment provider." A cold agent would see the existing **Snowflake** MCP server and wrongly
assume that's the one. Because `/grill-with-docs` had been run, it asked "is *this* the MCP server
you mean? it's read-only" — caught the mismatch, and wrote an ADR so future sessions load that
context and don't repeat the mistake.

---

## Key mechanisms worth internalizing

- **`CONTEXT.md` lazy-loading** — commands look for it in the repo; if links (Linear/GitHub) are
  missing they ask once and save them for next time. If you're not in a repo, they ask where to file.
- **ADRs written lazily** — agreements during grilling become decision records in `docs/adrs/`,
  auto-split into reference files when one gets too big. Future sessions read them and won't
  relitigate.
- **Vertical slices / tracer bullets** — issues are thin end-to-end pieces, not horizontal layers.
  Maps cleanly onto TDD.
- **Continuous sessions + handoff chaining** — keep one session alive across related work; hand
  off into fresh sessions that start oriented. The new session emits a verification blurb you paste
  back to the old session to confirm the handoff "took." Holden's record: ~9 chained sessions.
- **Auto-expiring temp files** — `/teach` artifacts self-delete after ~36h and are git-ignored.

---

## Potential future handbook notes (drafts for discussion)

These are candidate handbook entries / decisions surfaced in the session. **Not decided yet** —
flagged for the team to ratify.

1. **"Toolkit, not lifecycle" framing.** Document that these commands assume an existing repo and
   are explicitly *not* for greenfield scaffolding (that's FDA / `project-start`). Set expectations
   so people don't reach for the wrong tool.

2. **`CONTEXT.md` is a required, standard artifact.** Every project "pretty much needs one." Define
   its minimum contents: Linear project link, GitHub repo link, domain-term clarifications. It's the
   backbone of the lazy-loading pattern.

3. **Run cleanup on a cadence, not inline.** Establish `/improve-codebase-architecture` as a
   **scheduled** practice — candidate for a nightly cron that auto-files `needs-triage` improvement
   issues. Decide cadence + who triages the output.

4. **"If you have an idea, grill-docs it and push it over the fence."** Holden's ask: anyone with an
   idea in any repo should `/grill-with-docs` → scope → `/to-prd` → `/to-issues` and hand it off,
   rather than dropping loose notes. Worth codifying as the expected intake path.

5. **Prompt-chaining as a first-class pattern.** Capture the handoff-chain prompt (new session runs
   `/grill-with-docs`, emits a verification blurb to paste back). Possibly bake the chaining
   directly into `/handoff`.

6. **Bug intake for non-engineers.** `/bug-report` works from anywhere and is designed so BriteBase /
   non-eng folks can file clean, triage-ready bugs. Document the path: `/bug-report` → assign/mention
   → engineer `/triage`s → `ready-for-agent` → `/tdd`. (Pending: FDA-milestone awareness.)

7. **A meta "teach me the toolkit" layer.** Holden + the room agreed there should be an onboarding
   skill that *teaches you how to use these skills* with worked examples — i.e. `/teach` pointed at
   the toolkit itself. Tie into new-hire onboarding (ship a personal site to GH Pages, pick up &
   ship a real Linear ticket, "you're hired after you do XYZ").

8. **Open questions to resolve**
   - Should `/grill-with-docs` and `/grill-me` merge into one ADR-aware command? (ADRs are a coding
     concept; could retrofit so there's a single grill that understands context.)
   - How do we let `/teach` learnings *persist* beyond the 36h temp window when they're worth keeping?
   - Should `/to-issues` hard-fail (kick back & ask) when it has no requirements doc to reference?

---

## Source

- Recording: `New Tricks by Holden — 2026_06_01 15_52 MDT`
- Full transcript: `holden_recording/transcript.txt` (sibling of this repo; auto-transcribed, so light
  cleanup may be needed before quoting verbatim).
- Holden is also preparing his own docs + will share the command-stack screenshot.
