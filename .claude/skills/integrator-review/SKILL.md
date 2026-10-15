---
name: integrator-review
description: Review code in this repo as an integrator would, a developer who reads it as a reference to build their own Unico integration. Use when adding a new reference app or stack, when reviewing a PR, a diff or an app folder here (web, Android, iOS, Flutter), or when asked whether the code is simple enough to integrate with.
---

# Integrator review

Read the code as the **integrator**: a developer at a Unico customer who has never seen this repo, has the docs open in another tab, and will write the integration in a codebase that uses a different framework, using this code as a reference. The question to answer is whether they can run it, understand it and carry each piece over to their own stack without guessing.

## Steps

1. **Scope.** Run `git fetch`, then review the diff against the PR's base on the remote (`gh pr view --json baseRefName`, usually `origin/main`), or the path the user named. A stale local `main` drags unrelated files into the diff. Read the PR description too: every claim in it is something to verify. Sort the files in scope:
   - **Reference units** are what an integrator learns from: each app's `api/` (on web, the Unico client in `web/api/`), each `journey/<mode>/` folder, plus the README and config examples (`.env.example`) that explain them.
   - **Glue** only serves the demo app or the repo: HTTP routing, UI state, settings screens, tests, lockfiles, CI workflows. Review glue lightly.

   Done when every changed file is labelled reference unit or glue.

2. **Docs check.** For every Unico endpoint, field, claim or SDK call the code touches, open its page from https://developer.unico.io/llms.txt (add `.md` to a page URL for the raw text). The docs are the source of truth. Compare path, field names, request and response shapes, the library the docs' example uses, and error codes and error body shapes. Check the test fakes against the same pages: a fake that answers in a shape Unico never sends hides bugs. Done when every call and every fake in scope is matched to a docs page, with each mismatch noted.

3. **Rules.** Apply every rule below, plus the hard rules in [`AGENTS.md`](../../../AGENTS.md#hard-rules), to every reference unit. Keep a verdict per rule per unit (holds, broken at `file:line`, or not applicable) as working notes; each broken one becomes a finding. Done when every rule has a verdict for every unit.

4. **Run it.** Install dependencies with the versions the repo pins (`.node-version`, lockfiles, Gradle wrapper, `pubspec.lock`), run the tests, then every command the README gives the integrator, in the order the README gives them. When a command needs real Unico credentials, run it with dummy ones up to the point where Unico would be called (startup, validation, local error paths), and note that the rest needs a real service account. Done when every README command was run or listed as needing real credentials.

5. **Report.**
   - **Verdict** in one line: *simple enough to integrate with*, or *not yet* when any finding is a blocker, with the main reason.
   - **Findings**, worst first. Each one has a severity label (**blocker**: the integrator can't run it or can't tell how a piece works; **should fix**: they'll stumble or carry over something wrong; **nit**: polish), says where it is (`file:line`) and what the integrator trips over, and gives the concrete change, with a short snippet when it helps.
   - **Docs mismatches** from step 2 that didn't already become findings.
   - **Run results** from step 4, including what still needs real credentials.
   - **What works** and should stay.

   Leave the code unchanged until the user picks which findings to apply.

## Rules

**Framework-free.** A reference unit reads the same in any stack: no framework API in it, so nothing the integrator ports depends on the demo's framework. It takes and returns plain values in the API's own shape (`const { process } = await createProcess({ flow, ... })`). Anything shaped for the demo app, such as raw response text, status wrappers or UI state, stays in the glue.

**Mirrors the docs.** Each call maps to one docs page and links to it next to the code. Names match the API's field names, and each endpoint line shows the full path from the docs (`/client/v1/process/{id}/selfie`), so grepping the docs path finds the code. Libraries are the ones the docs' own examples use, for example `jsonwebtoken` for the JWT in Node.

**Explicit over DRY.** One visible call per endpoint beats a helper that hides which URL gets hit. A shared transport helper (auth header, JSON parsing, error check) is fine when every endpoint still shows its own method and full path at the call site.

**One error path.** Every failure reaches the caller the same way. Errors from Unico carry its status and body as returned. Errors the code detects itself (bad input, missing config) use a different error type with its own message, so a body that looks like Unico's always came from Unico. In JavaScript, async functions reject rather than throw synchronously, so `.catch()` sees every failure.

**Guardrails explained.** Each security or correctness guard (id validation, body size limit, CORS origin, token renewal margin) has a one-line comment saying why it exists and where its value comes from (a docs page, or an explicit judgment call), so an integrator keeps it and can tune it. Other comments only add what the code can't say.

**README answers first questions.** In order: how to run it, how to test it, a sample request with the response shape, and how to use the reference unit as a guide for your own code. Each command block runs as written; a long-running command like `npm start` ends its block.

**Reference, not copy.** No README, `AGENTS.md` or code comment tells the integrator to copy a file or folder as is. They point to what to learn from each piece and link the docs page behind it.

**No secrets in logs.** Beyond the `AGENTS.md` rules on keys, nothing logs a key, token, assertion or full request body. Demo-mode code that keeps credentials on a device is marked as demo where it lives.

**Modes stay isolated.** Deleting one `journey/<mode>/` folder leaves the others building and running.

**Tests through the public interface.** Tests exercise the reference unit the way an integrator calls it, against a local fake of the Unico endpoints, and cover the failure paths an integrator will hit: token errors, API errors, malformed input, non-JSON error bodies and network failures.
