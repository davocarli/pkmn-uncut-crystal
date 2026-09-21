---
name: init-partner-coding
description: Start partner-coding mode for a codebase or stack the user does not know well. Captures a one-line goal, surveys the repo, assesses familiarity, and writes a private profile to .partner-coding/ (gitignored). Must run before /code-feature.
argument-hint: one-sentence goal, optionally
---

Initialize **partner coding**.

The user wants to contribute to a codebase, stack, or both that they are not fluent in. Over the
project, you teach them how to work inside it while they do the writing. This skill only sets up
the ground: goal, stack, what they know, what to anchor explanations to. No code is written here.

Everything you learn is saved to `.partner-coding/` in the project root. That directory is private
to the user and never committed.

Requested goal: **$ARGUMENTS**

---

## Step 1 — The goal, in one sentence

If `$ARGUMENTS` is empty, ask one question: what are they trying to accomplish in this project,
at the highest level? One sentence is enough. Do not ask them to break it into sub-tasks, and do
not do that yourself. The goal is allowed to be broad ("restore cut content into a retail
cartridge through the save file"); features get scoped later, one at a time, by `/code-feature`.

## Step 2 — Explore the codebase

Read enough to know what you are both working in, before asking anything about familiarity.
Cover:

- **Purpose and shape** — README / top-level docs, directory layout, what the deliverables are.
- **Language and stack** — manifests (`pyproject.toml`, `package.json`, `Makefile`, `Cargo.toml`,
  …), toolchain versions, build and test commands, submodules or vendored dependencies.
- **Implementation details** — two or three representative source files per language in use;
  the conventions they follow (naming, comment style, file layout, how modules find each other).
- **What already exists that resembles the goal** — prior features, helpers, tools. These become
  the "look at this similar spot" references in later sessions.

If there is no codebase yet, say so, and ask what stack the project will use, then research that
stack instead. Use subagents for a broad survey if the repo is large; you need the conclusions,
not file dumps.

Give the user a short summary (a paragraph, no more) so they can correct anything you got wrong.

## Step 3 — What they already know about _this_ stack

Use **AskUserQuestion**, with options grounded in what Step 2 found. Never ask "how well do you
know programming"; ask about the specific things the goal will require. Typically two to four
questions:

- **The language(s)** — never used / can read it / wrote some a while ago / comfortable.
- **The framework, toolchain, or platform** — the assembler, the web framework, the hardware,
  whatever the repo is actually built on.
- **Specific things the goal will touch** — the build system, the test setup, the memory model,
  the async story, the deployment path. Only the ones you expect to hit.

Take the answers at face value. Do not quiz or re-test.

If the user asks you to fill this in from earlier sessions, notes, or memory instead of asking,
do that: answer Steps 3 and 4 from the record, fold the answers into the Step 2 summary so they
can correct them, and ask only about what the record does not cover.

## Step 4 — What they _are_ fluent in

Ask what languages, frameworks, and tools they know well. Offer concrete options (by name) with
room for free text. Then ask which of those they want explanations anchored to. These anchors are
the most valuable thing this skill collects: every later explanation is phrased as "this is X's
version of _that thing you already know_", so a weak anchor makes every session worse.

Also ask for any prior exposure that is adjacent even if it is not a language: cheat devices,
config formats, a tutorial they followed, a tool they have used. Those work as anchors too.

## Step 5 — Write the profile

Ensure `.partner-coding/` is ignored by git: if `.gitignore` exists and lacks the entry, append
`.partner-coding/` to it; if there is no `.gitignore`, create one with that line. Then write
`.partner-coding/profile.md`:

```markdown
# Partner coding — profile

Started: <YYYY-MM-DD>
Goal: <the one sentence from Step 1>

## Stack (from the repo)

- Languages: …
- Toolchain / framework / platform: …
- Build: `…` Test: `…`
- Conventions worth matching: …
- Existing code that resembles the goal: <path> — <why>

## Familiarity with this stack

- <language>: <their answer>
- <toolchain>: <their answer>
- <specific thing>: <their answer>

## Anchors (what to ground explanations in)

- Fluent: …
- Adjacent exposure: …
- Preferred anchor(s): …

## Project rules (never re-litigated)

<hard constraints the user has settled: files never touched, behaviours never changed, budgets>

## Working agreements

<how they like the loop to run: dictation cadence, what "check my work" means, who commits>

## Finish checklist (run at the end of every feature)

<project-specific steps: measure, ledger, regenerate test data, offer the commit>

## Owed walkthroughs (Claude-written, not yet explained line by line)

<blank at first>

## Teaching notes

<blank at first; /code-feature appends what lands and what needs a second pass>

## Deferred / next

<blank at first; /code-feature keeps it current>
```

The last five sections start mostly empty on a fresh project; fill them from the record when one
exists.

Tell the user the path in one line. Do not paste the profile into chat.

## Step 6 — Hand off

Close with two or three sentences: what the project is, what they know and don't, what you will
anchor to. Then say that `/code-feature` starts the first feature and will read this profile.

Do not start writing code, plans, or scaffolding here.
