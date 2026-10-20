---
name: technical-writer
description: Write or revise documentation in this repo, the READMEs, AGENTS.md files and code comments of the reference apps (web, Android, iOS, Flutter). Use when a change in an app leaves its docs stale, when adding docs for a new app or journey mode, when asked to improve or proofread a doc here, or when drafting a correction for a developer.unico.io page.
---

# Technical writer

Every doc here has one **reader**, and the doc is done when that reader can act on it without guessing:

- `README.md` → the **integrator**: a developer at a Unico customer who has never seen this repo, has developer.unico.io open in another tab, and wants to run the app and learn from it.
- `AGENTS.md` → a **coding agent** reading or porting the app into another stack.
- A code comment → whoever reads that line next to the code.

The docs at https://developer.unico.io/llms.txt are the source of truth for the API and SDKs. This repo's docs **link** to them and only add what they can't say: how this app runs, where each piece lives, and the gotchas found running it.

## Steps

1. **Scope.** List the files to write or revise and the reader of each. On a code change, run `git fetch` and diff against the PR's base on the remote, then find every doc that names a changed path, field, command or behaviour, in this app and in the sibling apps (all four share one layout, so one fact often lives in four places). Done when every affected doc is listed with its reader.

2. **Sources.** Trace every claim the doc will make to a source: a `file:line` in the repo, or a developer.unico.io page (add `.md` to a page URL for the raw text). When code and the docs site disagree, the code is wrong: report it instead of describing the wrong behaviour. When the docs site is wrong, draft the correction for it first and say so. Done when every claim has a source, and every claim without one is cut or flagged to the user.

3. **Write.** Apply every rule below. Done when each rule holds for every file in scope.

4. **Verify.** Run every command block as written, in order, from the folder the doc implies; with dummy credentials up to the point where Unico would be called. Open every link, including anchors. Check that every path in a table or sentence exists. Done when every command, link and path was checked or listed as needing real credentials.

5. **Trim.** Reread the changed prose and cut filler and hedges ("simply", "just", "it's worth noting", "may potentially"), hype words ("robust", "seamless", "leverage", "powerful"), chains of em dashes, and any sentence that repeats its heading. Done when every sentence left tells the reader something to know or do.

6. **Report.** What changed and why, claims you couldn't source, code/docs mismatches from step 2, and what still needs real credentials to check. Leave unrelated docs untouched.

## Rules

**Link, don't restate.** An endpoint, field, error code or SDK call gets a link to its developer.unico.io page next to it. Restate only what the reader needs at that spot to act; the full contract stays on the docs site, where it can't go stale here.

**Plain and concrete.** Short sentences, present tense, "you" for the integrator. Say what happens and what to do: "The server exits with a message if a value is missing", not "robust validation is performed". Name UI elements the way the app labels them (Customize, Get started, Verify credentials).

**Exact names.** Field names, paths, values, commands and file names go in code font, spelled exactly as the API or the repo spells them (`webAppToken`, `/client/v1/process/{id}`, `PROCESS_RESULT_OK`). Endpoint mentions show the full path from the docs, so grepping finds both.

**Same shape across stacks.** A README has, in order: what the app is, Run, Test, Using `<reference unit>` as a reference, Code (the pointer to `AGENTS.md`). An `AGENTS.md` has: What it is, Where each piece is (table of Path / What it does / How to use it), The flow end to end, Building your own integration, Docs behind each piece. A new app's docs follow its siblings section by section; a fact that differs between stacks is stated in each.

**Reference, not copy.** Docs point to what to learn from each piece and the docs page behind it, never to copying a file. Demo-only code (credentials on the device, the API credentials step of setup) is called demo where it's described, with what production does instead.

**Gotchas earn their place.** A warning is worth writing when the reader would otherwise lose time on it: the error code they'll see, what it means, the fix (`73303`: the SDK key isn't linked to this `applicationId`). Put it where the reader hits it.

**Commands run as written.** Each block runs copy-pasted from the stated folder. A long-running command (`npm start`, `flutter run`) ends its block. Examples use placeholder values in the shape of real ones (`my-account@abc123.iam.acesso.io`, CPF `12345678909`), never real credentials or keys.

**Comments say why.** One line, on what the code can't say: why a guard exists and where its value comes from. Comments describe the code as it is now; history belongs in the commit message.

**The hard rules hold.** Every doc stays consistent with the [hard rules in `AGENTS.md`](../../../AGENTS.md#hard-rules): server-side keys in production, one `GET` after the callback, native SDK on mobile, the API's response shown as returned.
