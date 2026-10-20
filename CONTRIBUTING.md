# Contributing

Issues are welcome. Pull requests are reviewed by Unico.

## The docs come first

The docs at [developer.unico.io](https://developer.unico.io) are the source of truth. When an app and the docs disagree, open an issue that names the docs page and the file in the app.

## Keep data out

Never paste credentials, `.pem` keys, tokens, CPFs or real process data into an issue or pull request. Use placeholder values instead.

## Running and testing

Each app's README says how to run and test it: [`web/`](web/README.md), [`android/`](android/README.md), [`ios/`](ios/README.md), [`flutter/`](flutter/README.md). CI runs the checks for each stack you change.

## Using a coding agent

Start it at [`AGENTS.md`](AGENTS.md) and the skills in [`.claude/skills/`](.claude/skills/): [`integrator-review`](.claude/skills/integrator-review/SKILL.md) to review a change, [`technical-writer`](.claude/skills/technical-writer/SKILL.md) to write docs.
