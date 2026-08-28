# Agent support roadmap

Plan for making `alex` a first-class tool for AI coding agents (the `flutter-dev`,
`flutter-reviewer`, `flutter-tester`, `flutter-qa`, `flutter-designer` role agents and
their skills: `gates`, `qa-screens`, `agent-profile-init`).

Status legend: `[ ]` not started · `[~]` in progress · `[x]` done

## Why

Agents currently keep project knowledge in three places that drift apart:

- `CLAUDE.md` / `AGENTS.md` — conventions as prose;
- `.claude/profile/*.md` — per-role facts (locales, doc paths, gate command);
- bash scripts in global skills (`gates.sh`, `qa_*.sh`) — which re-derive things
  `alex` already knows (repo root, `fvm` vs plain `flutter`, output noise filtering,
  the project's locale list).

Meanwhile `alex.yaml` is already the single source of truth for locales, l10n paths,
branch names, build naming and workspace mode, and `FlutterCmd` already resolves `fvm`.

Two systemic blockers on top of that:

1. **No machine-readable output.** Nothing supports `--format=json`, so agents parse
   human-oriented text — expensive in tokens and unreliable.
2. **Interactive prompts.** `feature finish`, `pubspec update`, `custom add` read from
   stdin (`readLineSync`), so an agent either hangs or fails on them.

The goal of this roadmap: everything an agent must verify becomes a deterministic
`alex` command with a stable exit code and a JSON report, instead of prose rules the
agent re-derives with greps each run.

---

## Backlog

### Tier 1 — highest leverage

#### 1. `[x] alex code check` — the quality gates command

Replaces the global `gates.sh` skill script. **Done** (see `CHANGELOG.md`).

- Runs analyze + test (+ platform debug build with `--build`) with the project's runner
  (`fvm flutter` via `FlutterCmd`; plain `dart` for a non-Flutter package).
- De-noises output (update banners, dependency chatter, third-party deprecations,
  SwiftPM chatter, box-drawing borders); extendable via `code.check.noise`.
- Structured results: analyze issues are parsed into `{severity, file, line, column,
  message, rule}`; tests run with `--reporter=json` so failures come with the test name,
  suite and (trimmed) message — including suite compilation failures.
- Exit codes: `10` analyze, `11` test, `12` build.
- Flags: `--analyze-only`, `--test-only`, `--build`, `--build-target`, `--fail-fast`,
  `--format=json`, args after `--` passed to the test command.

Left for later: `--changed` (only tests affected by the working-tree diff); running the
gates per package in a pub workspace (now only the root is checked).

#### 2. `[x] --format=json` for everything agents read

Done: `code check`, `info`, `agents guide`, `agents init`, `l10n check_translations`.

The contract lives in `AlexCommand` now: `addFormatOption()` on the parser,
`jsonResult()` builds the common envelope (alex version, the full command name from the
commands tree, `ok`, `exitCode`, `summary`) so no command repeats it, and a command that
fails with an error before printing a result still prints an error object — a script
always has JSON to parse. Messages are routed to stderr in `alex_command_runner`.

Done for every command that has something to report: `code check`, `info`,
`agents guide`, `agents init`, `l10n check_translations`, `changelog add`,
`changelog update-issue-links`, `pubspec get`, `pubspec update`, `pubspec version`.
The rest are groups and interactive wizards, which have no result to give to a script.

#### 3. `[ ] alex lint` — house conventions as code

The checks `flutter-reviewer` currently performs by grep:

- `bloc.add(` / `context.read<` / `BlocProvider.of` at call sites (must go through
  context + bloc extension methods);
- day arithmetic via `.inDays` / `Duration.add|subtract` instead of DTU;
- hardcoded `Color(...)` / `Colors.*` (except `transparent`) instead of theme tokens;
- raw route strings instead of `AppRoutes` extensions;
- hardcoded UI strings instead of `context.l`;
- edits to generated files (`*.g.dart`, `*.freezed.dart`, generated l10n).

Rules configured in `alex.yaml` (enable/disable, severity, path excludes). JSON output
+ non-zero exit on blockers. This is the item that turns half of code review from
probabilistic into deterministic — and shrinks the reviewer's prompt.

#### 4. `[x] Non-interactive mode`

`--non-interactive` is added automatically to every command whose `isInteractive` is
`true`, so a new interactive command can't forget it. With the flag a command fails with
the name of the option that answers the question instead of blocking on stdin.

- `feature finish` — gained `--section` (`added`/`fixed`/`pre-release`); with the flag it
  validates `--issue` and `--changelog` **before** any git operation, so it fails before
  the merge, not after it. Also fixed a real hang: the issue id prompt looped forever
  when stdin was closed.
- `pubspec update` — fails naming `--dependency`.
- `custom add` — an interactive wizard by nature, so it points to the config file to
  edit directly.

The guide (`agents guide`) prints the flag for every `[INTERACTIVE]` command.

#### 5. `[x] Agent onboarding: how an agent learns that alex exists`

The blocker before every other item: an agent working in a consumer project has no
reason to call a CLI it doesn't know about. A static `llms.txt` in this repository does
not solve it — the canonical `llms.txt` lives at the root of a documentation site (ours
is pub.dev, which we don't control), and a local agent doesn't browse the web anyway:
it has the installed binary and the project's files.

The real risk is drift: hand-written prose about a CLI goes stale on the first new flag,
and an agent follows it literally. So the source of truth must be the `ArgParser` tree
plus the exit-code table, with everything else generated from it.

One generator, three outputs:

- `[x] alex agents guide` — a compact digest built from the command tree: what alex is,
  the rules (config discovery, `--format=json` contract, exit codes, which commands are
  still interactive), then per command: invocation, one-line summary, options, exit
  codes. `--format=json` for a structured index; a command path argument
  (`alex agents guide l10n`) narrows it. Must stay short — an agent's context is a
  resource.
- `[-] llms.txt` in the repository — dropped: the canonical `llms.txt` is for
  web-capable agents fetching a docs site, while `agents guide` (local) and
  `agents init` (in the consumer project) already cover the agents that matter here.
- `[x] alex agents init` — writes the alex section into the consumer project's
  `CLAUDE.md` / `AGENTS.md` (or any files listed in `agents.files` / `--file`, e.g.
  `.claude/profile/shared.md`) with the project facts from `alex.yaml` and
  `pubspec.yaml` instead of the guesses `agent-profile-init` makes today. This is the
  strongest channel: role agents read those files FIRST, before anything else. Only the
  content between the `<!-- alex:begin -->` / `<!-- alex:end -->` markers is touched;
  `--check` fails with exit code `10` for CI.
- `[x] alex info --format=json` — project facts in one call instead of reading five
  files: root and config path, package and version, Flutter vs Dart, packages of a
  multi-package project, fvm version, locales (by the ARB files), l10n paths, branches.
  Shares the `ProjectFacts` collector with `agents init`, so the two can't disagree.
  Left for later: whether the generated code is out of sync (see #8).

### Tier 2 — meaningful simplification

#### 6. `[ ] alex l10n sync`

One pipeline instead of "extract → generate → to_xml in the right order", with a report
of what changed. Agents should not have to remember the order.

#### 7. `[ ] ICU plural completeness validator`

`lib/src/l10n/validators/` currently holds only `require_latin_validator`. Add a
validator asserting every locale has all CLDR plural forms it requires (RU `few`/`many`,
SL dual `two`) — a hard rule repeated in three agent prompts today. Wire it into
`check_translations`.

#### 8. `[x] Codegen sync gate` (`alex code check --gen`)

Runs build_runner as the first gate and fails (exit code `13`) if it changed anything.
Closes the classic failure: model changed, regeneration forgotten, tester hits a
confusing error. The generation logic is shared with `alex code gen` through
`CodeGenerationMixin`, so subprojects and pub workspaces are handled the same way.
Works on a dirty tree: the changed files are compared by the hash of their content,
not by the list of the changed files - a file that was already modified stays in the
list, so only its content can tell that the generation has rewritten it.

#### 9. `[x] alex changelog add "…" --section=added`

Agents edit `CHANGELOG.md` by hand and put entries in the wrong place; the "new entry
goes into the unreleased section" rule lived only as prose in `CLAUDE.md`. The command
creates that section itself when the changelog starts with a released version — which is
exactly the moment the rule is broken. `--format=json` included.

### Tier 3 — to discuss

#### 10. `[ ] alex db check-migration`

From the git diff: `getCreateTablesSql` changed without a `version` bump and an additive
`upgrade` migration → blocker. The most expensive project rule (irreplaceable user
data), currently checked by grep.

#### 11. `[ ] alex qa screens`

Port `qa_sim.sh` / `qa_run.sh` / `qa_batch.sh` (scenario × locale × appearance matrix,
`SHOT:` markers) into alex, taking the locale list from config. Downside: heavily
iOS/simulator-specific, pulls a macOS dependency into a cross-platform CLI — may be
better left as a skill.

#### 12. `[ ] Locks on shared resources`

Parallel dev + tester agents collide on simultaneous `build_runner` / `pub get`. A
simple lock file inside `alex code gen` / `alex pubspec get`.

---

## JSON output conventions (settled while implementing #1)

- Opt-in via `--format=json` (`addFormatOption()` on the command's `argParser`);
  the default stays `text` — the human output of existing commands never changes.
- JSON goes to **stdout only**: exactly one object, nothing else. Every other message —
  progress, warnings, the update banner — goes to stderr. This is enforced centrally:
  `AlexCommandRunner` detects the option (at any nesting level) and calls
  `print.setMessagesOutputToStdErr()`; the result is printed with `print.result()`.
- Exit code stays the contract for success/failure; JSON carries the detail.
- Envelope:

```json
{
  "alex": "1.15.0",
  "command": "code check",
  "ok": false,
  "exitCode": 11,
  "summary": "analyze: no issues | test: 61 passed, 1 failed | build: skipped",
  "gates": [{ "name": "test", "status": "failed", "summary": "…", "durationMs": 25350 }]
}
```

- `alex` (version), `command`, `ok`, `exitCode`, `summary` are common for every command;
  the payload key (`gates` here) is command-specific.
- Long free-form text (test failure messages, raw output of a failed command) is trimmed
  before it gets into the report — an agent's context is a resource.

## Order of work

1. ~~`alex code check` (#1)~~ — done.
2. `--format=json` for `l10n check_translations` (#2).
2b. Agent onboarding (#5) — done: `agents guide`, `agents init`, `info`.
3. Non-interactive mode (#4).
4. `alex lint` (#3) — largest, needs a decision on how configurable the rules are.
5. Then Tier 2 in listed order.
