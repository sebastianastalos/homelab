# CLAUDE.md

## Start with AGENTS.md

**[AGENTS.md](AGENTS.md) holds the working instructions for this repository** –
what the project is, how to deploy it (there is no local anything), the hard
rules, and the map of which document to read when. Read it first. Everything
below is specific to Claude Code and adds to it rather than repeating it.

---

## Establish which shell you are in – first, every time

This repo is edited from two places with very different powers. In the
code-server container there is no `docker`, no `zfs`, no `midclt`, and `sudo`
prompts for a password; on the TrueNAS host all of those work. **Half of what
you might reasonably try to run is unavailable in one of them.**

```bash
hostname; ls /.dockerenv 2>/dev/null && echo "in container"; which docker zfs midclt
```

The full comparison is in
[AGENTS.md § Two shells](AGENTS.md#two-shells-very-different-powers).

Two rules follow from it:

- **Never present a container-side check as the state of the running system.**
  If you cannot reach Docker, say so and hand the command over.
- **Never guess at the output of a command you could not run.** An invented
  port, container status or GID is worse than an admitted gap.

## Before you start: interview me

**Interview me before you start, and ask any questions you need to do the work
well.** Don't infer what a request means when you could simply find out. Work
out what the thing is for, what "done" looks like, and – where a request could
reasonably be read two ways – which reading I actually meant.

How to ask:

- **Ask up front, in one batch**, rather than drip-feeding questions through
  the work or discovering the real requirement halfway in.
- **Ask about the decisions that change what you build.** Skip the ones you can
  answer yourself from the compose files, the docs, or an obvious convention.
- **Recommend an option where you have one.** A question with a sensible
  default attached is far easier to answer than an open one.
- **Read the repo first.** [ARCHITECTURE.md](ARCHITECTURE.md) records the
  reasoning behind most decisions, including several reversals – questions it
  already answers waste a turn; questions informed by what you found are the
  useful kind.

The signal to stop and ask is the moment you are about to write "I'll assume".

The one exception is a genuinely unambiguous small change – a typo, an image tag
bump, a fix I have already specified in full. Everything else, ask first.

## Walk me through it one step at a time

For anything with more than a couple of steps – a migration, a new service, a
host change – **give me one step, wait for the result, then give me the next.**
Do not hand over a wall of commands to run in sequence. The output of step one
regularly changes what step two should be, and on a live system a batch that
half-worked is harder to unpick than a batch that never ran.

## Tool use in this repo

- Use **Read / Grep / Glob** rather than `cat`, `grep`, `find`, `head`, or
  `sed` through a shell.
- When searching, prefer `git grep` over plain `grep -r`. It respects
  `.gitignore`, so it stays out of the runtime `config/` and `data/`
  directories – which hold databases, logs and media metadata and will bury a
  useful result under thousands of lines.
- Reference files as clickable markdown links –
  [sonarr/docker-compose.yml](sonarr/docker-compose.yml), or with a line number
  [qbittorrent/docker-compose.yml:5](qbittorrent/docker-compose.yml#L5) – not in
  backticks.
- Read-only inspection commands are pre-approved in
  [.claude/settings.json](.claude/settings.json); anything that changes state
  will prompt. That is deliberate – do not work around it by reaching for a
  different spelling of the same command.

## Local environment notes

@HOMELAB.md

Concrete values for this machine – IP addresses, the real domain, port
assignments, credential locations, host quirks – live in **HOMELAB.md**, which
is gitignored and loaded above when present. Keep them out of this file and out
of AGENTS.md and ARCHITECTURE.md: those three are committed to a **public**
repository.

Before adding a value to a committed file, ask whether it belongs in HOMELAB.md
instead.

## Docs: ask before editing

Before changing [README.md](README.md), [ARCHITECTURE.md](ARCHITECTURE.md) or
[AGENTS.md](AGENTS.md), **ask first**, listing the specific edits you would
make. Don't edit them silently, and don't skip asking because the change looks
small. The reasoning in ARCHITECTURE.md exists because decisions were reversed
and dead ends were hit – trimming it for length deletes the evidence the next
decision needs.

## Commits

Use [Conventional Commits](https://gist.github.com/qoomon/5dfcdf8eec66a051ecd85625518cfd13):

```
<type>(<optional scope>): <description>

<optional body>

<optional footer>
```

**Description**: imperative present tense ("add", not "added" or "adds"), no
capital first letter, no full stop.

| Type | For |
| --- | --- |
| `feat` | a new service, or a new capability for an existing one |
| `fix` | correcting something broken – a wrong path, port, permission or flag |
| `refactor` | restructuring that does not change what runs |
| `perf` | a change specifically for speed or resource use |
| `style` | formatting only – whitespace, key order, quoting |
| `docs` | documentation only |
| `build` | image version bumps and dependency pinning |
| `ops` | deployment, CI/CD, monitoring, backups, host configuration |
| `chore` | maintenance – `.gitignore`, tooling config |

`ops` and `build` carry most of the traffic here; `test` is unused, since there
is no test suite. `chore(deps)` is Renovate's – don't write it by hand.

**Breaking changes** take a `!` before the colon, and an explanation in the
footer when the description alone is not enough:

```
ops(deploy)!: drop the compose-path copy from the deploy workflow

BREAKING CHANGE: apps must be re-added in the Apps UI before the next deploy.
```

Scope is optional and names the app or area affected – `jellyfin`, `sonarr`,
`caddy`, `deploy`, `monitoring`. Never use an issue number as a scope.

Examples from this project:

```
fix: move prowlarr off gluetun network, expose its own port 9696
refactor: migrate all app config datasets from storage to app pool
ops: add secrets validation workflow using 1Password service account
docs: add agent and architecture documentation
```

### Do not add a Co-Authored-By trailer

No `Co-Authored-By: Claude` and no generated-with footer. Commits should read
as my own work.

### Before committing

Validate any compose file you touched, the same way CI will:

```bash
docker compose -f <app>/docker-compose.yml config --quiet
```

If you added a `${VAR}` reference, add it to that app's `.env.example` too –
[validate.yml](.github/workflows/validate.yml) builds a throwaway `.env` from
that file and will fail the PR without it.

**Never commit a `.env`.** They hold live VPN, API and database credentials and
are gitignored; check they stay that way. Verify a key is set by testing for
presence, never by printing its value.

### Pushing deploys

A push to `main` that touches any `**/docker-compose.yml` **deploys to the live
system**. Treat it as such: confirm before pushing, and check the app is not on
the deploy workflow's exclusion list, or the push will look successful and
change nothing.

## Scope discipline

This is a live home server that a household depends on. Build what is asked;
where you see something worth fixing beyond that, raise it rather than folding
it in – a review finding is a gift, an unrequested refactor in the same commit
is a cost.

Corollary for a repo that is also the live configuration directory: **editing a
file here changes the host immediately, but does not restart anything.** Don't
leave the repo and the running containers describing different systems without
saying so.
