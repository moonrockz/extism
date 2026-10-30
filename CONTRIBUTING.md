# Contributing to moonrockz/extism

Read [the README](README.md) first to set up the toolchain. This guide tells you how to plan a
change, track it, and get it ready for review.

## How work moves

1. Write or update an OpenSpec change. It holds the requirements and the design.
2. Track the implementation in the shared Morphir beads tracker. Each task group in the change has
   one bead with the label `repo:extism`.
3. Implement one task group at a time. Write the failing test first. Tick its tasks in the change.
4. Run the checks and open a pull request. The pull request that lands the last task group also
   archives the change.
5. After the merge, the beads are closed with the pull request and the merge commit.

A typo fix, a dependency bump or a build-only change does not need an OpenSpec change. A change to
public behavior, a public API or a requirement needs one.

## OpenSpec

[OpenSpec](https://github.com/Fission-AI/OpenSpec) is pinned in `.config/mise/config.toml`.
`mise install` installs it. Run it through mise:

```shell
mise exec -- openspec list                  # changes in progress
mise exec -- openspec list --specs          # accepted specifications
mise exec -- openspec show <change>         # one change
mise run openspec:validate                  # the schema, then every change and spec, strict
```

| Path | Contents |
| --- | --- |
| `openspec/config.yaml` | Project context and rules that every change follows |
| `openspec/schemas/html-design/` | The schema: Markdown proposal, specs and tasks, and an HTML design |
| `openspec/specs/<capability>/spec.md` | Accepted requirements, one folder for each capability |
| `openspec/changes/<change>/` | A change in progress |
| `openspec/changes/archive/` | Changes that are complete |

A change folder has these files:

| File | Contents |
| --- | --- |
| `proposal.md` | Why the change is necessary, what it changes, what is out of scope, and its beads |
| `design.html` | How the change works, as a copy of `docs/templates/agent-document.html`. Each decision has an ID such as `ENG-1` and a label: "Owner" for a maintainer decision, or "Call" for a decision of the author |
| `specs/<capability>/spec.md` | Requirement changes under `## ADDED`, `## MODIFIED` or `## REMOVED Requirements`. Each `### Requirement:` uses SHALL or MUST and has one or more `#### Scenario:` blocks with **WHEN** and **THEN** lines |
| `tasks.md` | Task groups. Each group heading ends with its bead ID |

Use kebab-case names that start with a verb, for example `host-extism-plugins`. With an agent, use
the `openspec-*` skills that `mise run openspec:setup` writes. Without an agent, run
`mise exec -- openspec new change <name>`, then `mise exec -- openspec instructions <artifact>
--change <name>` for the template and the rules of each file.

Rules:

- Write in ASD-STE100 Simplified Technical English.
- Make each scenario specific enough that a test can check it.
- If a decision depends on something nobody has tried yet, make the first task group a spike or a
  gate that tries it.
- Run `mise run openspec:validate` before you ask for review.

## Beads

This repository has no beads database. The work is in the shared Morphir tracker:

```shell
bd dolt pull                                 # before you start
bd ready --label repo:extism                 # unblocked work
bd update <id> --claim                       # start a task group
bd comments add <id> "<evidence>"            # commits, pull request, test commands and results
bd dolt push                                 # after you change the tracker
```

Run these commands from a checkout that is set up for the shared tracker, for example
finos/morphir-moonbit. Do not close a bead before its pull request merges.

## Commits and pull requests

- Use [Conventional Commits](https://www.conventionalcommits.org/), for example
  `feat(engine): add the js engine` or `docs(openspec): propose host-extism-plugins`.
- Do not add AI attribution lines to commits, pull requests or issues.
- Install the hooks with `mise run hooks:install`. Pre-commit checks formatting, compiler warnings
  and the generated interfaces of the staged files. Pre-push runs lint, validate, tests, task script
  tests and OpenSpec validation. Do not skip them with `--no-verify`.
- Commit the `pkg.generated.mbti` file of each package. `mise run lint` writes these files and fails
  when one is new or changed and not staged.
- CI must pass. The `ci-ok` job is the aggregate check.

## Releases

A release needs the maintainer's approval. Never publish to Mooncakes from a workstation, and never
move a tag.

The Release workflow (`.github/workflows/release.yml`) publishes. To release version `X.Y.Z`:

1. Set `version = "X.Y.Z"` in the root `moon.mod` and in every member (`mise run validate` checks
   them), and add the section `## X.Y.Z` to `CHANGELOG.md`. Merge this to `main`.
2. After the approval, the maintainer pushes the tag `vX.Y.Z` on that commit of `main`.

The workflow then plans the run (the tag must name the `moon.mod` version and a commit of `main`),
runs every CI job, packages and audits the module (`mise run release:package`), publishes it
(`release:publish`), checks that the public archive has the approved SHA-256 (`check:published`)
and creates the GitHub release. It never replaces a release or a tag. A pull request that changes a
release file, or a manual run with `dry_run`, runs the plan and the package audit and does not
publish.
