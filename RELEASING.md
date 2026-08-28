# Releasing dedalo.nvim

A release is a tag and a GitHub release. There is nothing to compile and
nothing to upload — Neovim plugin managers install from git.

## Why tags matter here

This repository has never been tagged, which is fine for something nobody
depends on and stops being fine the moment somebody adds it to their plugin
manager. **Every plugin manager in Neovim pins by tag or by commit**, so
without tags everyone is pinned to whatever `main` was that day — including the
morning somebody pushed a refactor.

The README tells people to pin a tag. That instruction needs tags to exist.

## Versioning policy

Semantic versioning, with the same shape as [`dedalo`][dedalo-releasing] and
deliberately **not** its strictness: nothing here decides what anybody is paid.

| Change | Bump |
| --- | --- |
| A configuration key is removed or renamed | major (minor pre-1.0) |
| **The annotation states something different about who is paid** | minor |
| New options, new commands | minor |
| Fixes, documentation, internals | patch |

The second row is the one to watch, and it is why this table is not just
copied from a template. This plugin's whole purpose is telling somebody that
the author of the line in front of them **would not be paid**. A change that
alters when that is displayed changes what a user believes about money, even
though no money moves and no interface changed. Treat it as a feature, describe
it in the changelog, and say what the annotation used to claim.

## What version of `dedalo` this speaks to

`lua/dedalo/health.lua` names a floor — `minimum_dedalo` — and
`:checkhealth dedalo` **errors** below it rather than reporting a version
string and hoping.

That floor is not decoration. This plugin parses `dedalo contributors --json`
and `dedalo identity list --json`, and those shapes are a contract in the main
repository. A renamed field there breaks this plugin **silently**: no error, an
annotation that is simply wrong about who would be paid. `tests/fixtures/`
holds the exact shapes with the version they came from, so a break says *which
field*.

**Raise the floor when the shapes change**, in the same pull request that
adapts to them, and say so in the changelog. A user on an older `dedalo` should
be told to upgrade, not shown a wrong annotation.

## The changelog is your pull request title

`CHANGELOG.md` is generated from Conventional Commit subjects with `git-cliff`,
and pull requests are squash merged with the title as the subject. **The title
becomes the release note.**

```text
feat(annotation): show why a line scores what it does
fix(cache): drop blame when the head moves
docs: say what the plugin costs on a large repository
```

## Cutting one

Two workflow runs and one review. Nothing is run locally.

1. **Version** — dispatch it with a bump level. It runs
   `scripts/bump-version.sh`, folds the pending changes into `CHANGELOG.md`
   with `git-cliff`, and opens a release pull request.
2. **Read the changelog diff the way a user would.** Edit the branch directly
   if a generated line is unclear; the file is the published record, not the
   workflow.
3. **Merge it.** **Tag** fires on the merge, creates `v<version>`, and calls
   **Release**, which creates the GitHub release with that version's changelog
   section as its notes.

> **Careful** — never edit the version by hand. `scripts/bump-version.sh` is
> the only thing allowed to change `lua/dedalo/version.lua`, and a version that
> disagrees with its tag is worse than no version, because it is believed.

**Never move a published tag.** Fix forward with a new version; somebody's
plugin manager has already locked to it.

## What is deliberately not done

**LuaRocks.** Neovim plugin managers install from git, so publishing there
would be a second distribution channel to keep correct for an audience that is
not asking for it. If that changes — if a manager people actually use starts
requiring it — this is the paragraph to delete.

**Binaries and signing.** There are none. A release here is a tag and a page of
notes, and pretending otherwise would be ceremony.

[dedalo-releasing]: https://github.com/dedalo-org/dedalo/blob/main/RELEASING.md
