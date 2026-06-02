# Holden's Claude Code Toolkit — A Walkthrough

*Catch-up notes from "New Tricks by Holden" (6/1). Written for someone who wasn't in the room.*

> Scope note: this covers exactly the commands Holden walked through in the session.

---

## First, a quick vocabulary note (skills vs. plugins)

People use both words, so here's the clean version:

- **A skill** = one command you type, like `/grill-me` or `/to-prd`. It does **one job**. Most of
  what Holden demoed are skills.
- **A plugin** = a *bundle* of related skills, commands, and config shipped together — e.g. our
  `marketing` plugin or `revops` plugin. A plugin is the box; skills are the tools inside it.

**So Holden's demo was mostly about skills** — small, single-purpose commands. The important nuance:
most of these skills are his **personal toolkit** (adapted from an external practitioner's work) that
he's been refining for weeks and has installed for the team. They are **not** part of our
`brite-claude-plugins` repo — they're available everywhere as `/commands`. The one thing he's adding
*into* a plugin is `capture-idea`, which goes into our marketing plugin.

---

## The one big idea

Holden's mental model flipped. The old way: *pick a Linear issue → start a fresh session → work it →
close → repeat.* Every session starts cold and the context you built up evaporates.

The new way treats these commands as a **toolkit you compose**, not a fixed process:

1. **They're a toolkit, not a lifecycle.** They assume a repo (codebase) already exists and help you
   *think → write it down → build → verify*. They are deliberately **not** for starting brand-new
   projects — that's a different tool (FDA / project-start). Don't reach for these to scaffold
   greenfield work.

2. **Each command is small and chainable.** The philosophy (borrowed from how the best AI
   practitioners online work): *don't over-prescribe.* Each command does one atomic thing, and you
   **chain** them — sometimes literally feeding one command's output as the prompt that boots the
   next session.

3. **Keep context alive across work; hand it off cleanly.** Instead of throwing away your session
   context, you **hand off** a rich summary into the next session, so the new one starts already
   oriented (~5–10% "full" but fully briefed). Holden has chained ~9 sessions back-to-back this way
   without losing the thread.

A repeating theme: *"None of us are really programmers."* These commands exist partly to surface the
things you don't know you don't know — the hidden requirements and edge cases — and to write them
down so a future session (or a teammate) doesn't trip over them.

---

## The commands, explained

### 1. Thinking & scoping — *figure out what you actually want*

**`/grill-me`**
Interviews you relentlessly with sharp questions until your thinking is clear. Works in **any**
context, not just code — Holden uses it to weigh personal/business tradeoffs too. *Reach for it when:*
"I have two options and I don't really know which I want." It'll ask questions that surface what you
actually care about (speed vs. correctness, etc.).

**`/grill-with-docs`**
The same relentless interview, but **code-aware and it writes things down.** As you and Claude agree
on things, it quietly creates **decision records** (ADR files) in the repo so the reasoning is
captured forever. It's designed to **expose hidden requirements and edge cases** before you build the
wrong thing. Often asks 15–50 questions. Doubles as a **scoping** tool: "I have an idea / found a bug,
help me scope it." *Must be run inside the repo* so it attaches to that project.
> Real example: a teammate's project mentioned "an MCP server for the enrichment provider." A cold
> agent would've grabbed the existing Snowflake server and gotten it wrong. Because grill-with-docs
> had run, it asked "wait — is *this* the server you mean? it's read-only," caught the mismatch, and
> wrote it down so no future session repeats the mistake.

**`/zoom-out`**
"I'm lost / stepping away — show me the big picture." Draws an **ASCII map** of what's been shipped,
what's next, and where you currently are, plus *why it matters*. Great when you've gone 12 questions
deep in a grill session and lost the plot, or end-of-day so tomorrow-you can re-enter easily.

**`/deep-research`** ⚠️
Spins up a **swarm of agents** to deeply research a hard technical question and come back with best
practices. **Warning: it's expensive, slow, and spawns many agents on its own.** *Reach for it when:*
getting the answer wrong has real consequences — "I genuinely don't know enough to decide this; go
research it, then grill me on what you found."

**`/teach`**
Builds an **interactive HTML page** that explains any concept and includes a **quiz** at the bottom.
You answer; it reads your answers, detects where you're confused, and re-explains. The files
auto-delete after ~36 hours (no cleanup, not saved to the repo). *Reach for it when:* mid-scoping you
hit a concept you don't understand well enough to make a good call — "teach me this until I can answer
intelligently."

### 2. Crystallizing — *turn the conversation into real work*

**`/to-prd`**
At the end of a working conversation, this turns **everything you just discussed** into a proper
requirements document (a PRD) and files it in Linear. Key point: it does **not** re-interview you — it
just synthesizes what you already worked out. You can park it there for later, or keep going. It'll
ask which milestone to file under.

**`/to-issues`**
Takes that PRD and **breaks it into many small, well-scoped Linear issues** that already follow our
issue-writing conventions. It slices work into **"vertical slices" / tracer bullets** — thin pieces
that each go end-to-end (research → build → test for one bit of functionality) rather than "do all the
backend, then all the frontend." This is the shape that plays nicely with test-driven development.

### 3. Building — *actually ship it*

**`/tdd`**
Test-driven build loop (write the test, make it pass, clean up). It already exists inside our
session-start workflow, but as a standalone it **keeps your current conversation context** instead of
cold-loading a Linear issue. So after grill → to-prd → to-issues, you just run `/tdd` and start
building — it even auto-creates an in-session checklist from what you described. (From here you
continue into your normal review and ship flow, which is unchanged.)

**`/handoff` — the keystone**
This is what makes continuous, chained sessions possible. It compresses your **entire session** into a
big (~3,000-word) handoff document — a review of the codebase, who you're working with, what shipped
this session, open questions, edge cases, and gotchas — **plus a ready-to-paste prompt** to launch the
next session. Holden's chaining trick: open a new tab, paste the handoff prompt, the new session boots
(and is instructed to start by running `/grill-with-docs`), it emits a little verification blurb, you
paste that back into the old session, and the old session confirms the handoff "took" (or flags what
got missed). Result: a brand-new session that's already deeply oriented.

### 4. Bugs & triage — *catch and route problems*

**`/bug-report`**
File a bug from **anywhere** — you don't even need to be in the codebase. It uses `/grill-me` under the
hood to capture screenshots, repro steps, who's involved, and tradeoffs, then files a labeled Linear
issue and asks which milestone. Smart context handling: if you're in a repo it auto-detects the
project; if not, it asks where to file. **Built specifically so non-engineers can file clean bugs** —
Holden made it with the BriteBase folks in mind.

**`/triage`**
Routes incoming issues through a decision flow. Someone hands you a bug; you triage it into one of:
**bug · enhancement · needs-info · ready-for-agent · ready-for-human · won't-fix.** If it's
needs-info, it even drafts the follow-up questions to send back to the reporter.

### 5. Cleanup — *fight the entropy*

**`/improve-codebase-architecture`**
The premise is blunt: *AI-generated code is messy by default,* so you do **"trash cleanup" on a
regular cadence** rather than inline. It scans the codebase and outputs a list of improvements; you tag
each one and shape the good ones into real issues. **Strong candidate to run as a nightly cron job**
that auto-files cleanup issues. It respects existing decision records so it won't re-argue settled
choices.

### 6. Idea capture — *don't lose the good ones*

**`capture-idea` (marketing plugin)**
A lightweight way to log a campaign idea from anywhere (even the desktop app). It drops the idea into a
Linear "ideas" milestone, and later the campaign-planning command offers to pick one up. Can prompt for
a Salesforce deal link or a past-customer example. Repo-independent.

---

## How it all fits together

Holden frames the whole toolkit as something you enter from **two directions**.

### Push — top-down (you have an idea you want to build)

```
   talk to Claude about the idea
            │
            ▼
   /grill-with-docs ........... resolve intent, surface edge cases, write CONTEXT.md + ADRs
            │                   (lean on /grill-me, /teach, /deep-research, /zoom-out as needed)
            ▼
   /to-prd ................... crystallize the conversation into a requirements doc in Linear
            │
            ▼
   /to-issues ................ slice it into small vertical "tracer bullet" issues (ready for agent)
            │
            ▼
   /tdd ...................... build a slice red → green → refactor
            │                  (continue into your normal review + ship — unchanged)
            ▼
   /handoff ................. package the session + a prompt to boot the next one  ──┐
            └──────────────────────────────────────────────────────────────────────┘
                              (chain into the next related piece of work)
```

### Pull — bottom-up (a bug or problem finds you)

```
   /bug-report .............. file it from anywhere; lands as "needs-triage"
            │
            ▼
   /triage .................. bug? enhancement? needs-info? ready-for-agent? ready-for-human? won't-fix?
            │
            ▼ (ready-for-agent)
   /tdd ..................... build the fix (then your normal review + ship)
```

### On a cadence (independent of either flow)

```
   /improve-codebase-architecture ... scan for messes → file improvement issues (good nightly cron)
```

**The glue underneath both flows:** a couple of files that live *in the repo* and carry state between
commands and sessions —

- **`CONTEXT.md`** — the project's memory: its Linear link, its GitHub link, and notes like "when the
  user says X they actually mean Y." Commands read it automatically; if it's missing the links, they
  ask once and save them for next time.
- **`docs/adrs/`** — decision records, written *lazily* as you agree on things during grilling, so
  future sessions load the reasoning and don't relitigate it.

---

## Why this matters (the payoff)

- **Less wasted context.** Chaining + handoff means you stop starting from zero every session.
- **Fewer wrong turns.** The grill-and-write-it-down loop catches the hidden requirements *before* the
  codebase gets "all screwed up."
- **Non-engineers can contribute cleanly.** `/bug-report` and `capture-idea` let anyone file
  well-formed work from anywhere — no need to live in the codebase.
- **Entropy gets fought on a schedule.** `/improve-codebase-architecture` makes cleanup routine, not
  heroics.

Holden's standing ask: **if you have an idea for anything in any repo, don't drop loose notes — run
`/grill-with-docs`, scope it, `/to-prd`, `/to-issues`, and hand it over the fence already shaped.**

---

*Holden is writing his own docs and will share the screenshot of his command stack. Happy to walk
anyone through a live example.*
