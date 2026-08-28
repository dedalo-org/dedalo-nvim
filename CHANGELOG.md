# Changelog

All notable changes to dedalo.nvim are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
The plugin is one Lua package with one version and one tag.

<!-- New sections are prepended here by `git cliff` during a release. -->

## Unreleased

Nothing yet. `v0.1.0` will be the first tagged release; everything below
describes what will be in it.

### Added

- The annotation itself: who earns from the lines in front of you, joined from
  `git blame`, `dedalo contributors --json` and `dedalo identity list --json`.
- Five states told apart — linked, **no wallet and would not be paid**,
  excluded, outside this round, and uncommitted. The second is the reason this
  plugin exists.
- `:Dedalo` with `attach`, `detach`, `toggle`, `refresh` and `profile`.
- `:checkhealth dedalo`, which checks Neovim's version, `git`, the `dedalo`
  executable **and whether it is new enough**, the repository, and
  `dedalo.toml`.
- Install snippets for five plugin managers, every configuration key with its
  default, and what the plugin costs — measured, not asserted.
- `:help dedalo`, with per-option tags.
