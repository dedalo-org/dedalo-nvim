# dedalo.nvim

Attribution where the code is.

[Dedalo](https://github.com/dedalo-org/dedalo) turns git merges into
contributor payouts — see [the handbook](https://dedalo-org.github.io/dedalo/)
for how. This shows, next to the lines in front of you, who earns from them.

```text
  local function split(total, weights)      ▏ ada · 50.0%
    local shares = {}                       ▏ ada · 50.0%
    ...
  end

  local function verify(plan)               ▏ Bea · 50.0% — no wallet, would not be paid
    ...
  end
```

## Why an editor plugin

The first line is information. The second is the point.

An author with a contribution score and **no wallet on file** lands in a
payout plan's `unresolved` list and is paid nothing. Dedalo reports it
faithfully — but only in a plan, which someone has to sit down and read.
Here it is on the line, while you are looking at their code.

Three states are worth telling apart, and the annotation does:

| | |
| --- | --- |
| `ada · 50.0%` | linked to a wallet |
| `Bea · 50.0% — no wallet, would not be paid` | earned a share, nowhere to send it |
| `bot — excluded from payouts` | deliberately unpaid, not a mistake |
| `Old — outside this round` | no score in the pending range, usually already paid |
| `uncommitted — earns nothing yet` | not committed, so worth nothing yet |

The share is of the **contributor pool for the pending round**, not an amount:
the size of a round is not decided until someone decides it. What a share is
computed from — merges, lines, the per-merge cap, co-authors — is
[the handbook's job to explain][attribution], and this README deliberately does
not repeat it. One explanation that stays right beats two that drift.

[attribution]: https://dedalo-org.github.io/dedalo/concepts/attribution.html

## Requirements

Neovim **0.10+**, `git`, and [`dedalo`](https://github.com/dedalo-org/dedalo)
**0.0.1+** on `PATH`, in a repository that has a `dedalo.toml`.

`:checkhealth dedalo` checks all five — including whether the `dedalo` on
`PATH` is new enough — and names the one that is missing. See
[version compatibility](#version-compatibility) for why the floor exists.

## Install

`setup()` is optional everywhere below — the defaults work, and the plugin
loads nothing until `:Dedalo` is run.

<details open>
<summary><b>lazy.nvim</b></summary>

```lua
{
  "dedalo-org/dedalo-nvim",
  version = "*",        -- follow tagged releases rather than main
  cmd = "Dedalo",
  opts = {},
}
```
</details>

<details>
<summary><b>packer.nvim</b></summary>

```lua
use({
  "dedalo-org/dedalo-nvim",
  tag = "*",
  config = function()
    require("dedalo").setup()
  end,
})
```
</details>

<details>
<summary><b>vim-plug</b></summary>

```vim
Plug 'dedalo-org/dedalo-nvim', { 'tag': '*' }
```

```lua
lua require("dedalo").setup()
```
</details>

<details>
<summary><b>mini.deps</b></summary>

```lua
local add = require("mini.deps").add
add({ source = "dedalo-org/dedalo-nvim", checkout = "v0.1.0" })
require("dedalo").setup()
```
</details>

<details>
<summary><b>Built-in packages (<code>:help packages</code>)</b></summary>

```sh
git clone https://github.com/dedalo-org/dedalo-nvim \
  ~/.local/share/nvim/site/pack/dedalo/start/dedalo-nvim
nvim -c 'helptags ~/.local/share/nvim/site/pack/dedalo/start/dedalo-nvim/doc' -c q
```
</details>

**Pin to a tag rather than to `main`.** `main` is where work lands; a tag is a
commit somebody decided was good.

Then check the install with **`:checkhealth dedalo`**. It is the first thing to
run when the annotation is blank, and it names the one thing that is missing —
Neovim's version, `git`, `dedalo` and its version, the repository, and
`dedalo.toml`.

## Use

```vim
:Dedalo            " toggle on the current buffer
:Dedalo attach
:Dedalo detach
:Dedalo refresh    " after a `dedalo identity link`
:Dedalo profile    " what the last attach cost, in milliseconds
```

Everything is asynchronous. `git blame` on a large file in a large repository
is not fast, and attribution is a nicety — blocking the editor for it would be
a poor trade.

## Configuration

Every key, with its default:

| Key | Default | What it does |
| --- | --- | --- |
| `cmd` | `"dedalo"` | The executable to run. A name is looked up on `PATH`; an absolute path is used as given. |
| `auto_attach` | `false` | Annotate a buffer as soon as it is opened in a Dedalo project. See [what it costs](#what-it-costs) before turning it on. |
| `debounce_ms` | `150` | Quiet period before an auto-attach fires, in milliseconds. `0` attaches immediately. Only used when `auto_attach` is on. |
| `min_share` | `0.1` | Hide the percentage below this many per cent. The author is still shown; only the number is dropped, because below a tenth of a per cent it says nothing. |
| `virt_text_pos` | `"eol"` | Where the annotation sits: `"eol"`, `"right_align"` or `"inline"`. |
| `highlights.linked` | `"DedaloLinked"` | Group for an author with a wallet. |
| `highlights.unlinked` | `"DedaloUnlinked"` | Group for an author who would not be paid. |
| `highlights.uncommitted` | `"DedaloUncommitted"` | Group for uncommitted, excluded and out-of-round lines. |
| `icons.linked` | `"▏"` | Prefix for a linked author. |
| `icons.unlinked` | `"▏"` | Prefix for an unlinked author. |
| `icons.uncommitted` | `"▏"` | Prefix for the rest. |

```lua
require("dedalo").setup({
  cmd = "dedalo",
  auto_attach = false,
  min_share = 0.1,
  virt_text_pos = "eol",
})
```

The three highlight groups link to existing ones (`Comment`, `WarningMsg`,
`NonText`), so the plugin follows your colourscheme rather than fighting it.
Override `DedaloLinked`, `DedaloUnlinked` and `DedaloUncommitted` to taste.

`:help dedalo-config` has the same table, and `:help dedalo` the rest.

## What it costs

The plugin shells out. That is worth being straight about, because a
blame-style annotation that runs a subprocess at the wrong moment is a thing
people notice and then uninstall.

**What runs, and what it measured.** Four commands per attach. Median of five
runs against [dedalo][dedalo] itself — 29 unpaid changes, a 700-line file:

| Command | Cold | Warm |
| --- | --- | --- |
| `git rev-parse HEAD` | 1 ms | 1 ms |
| `dedalo contributors --json` | **118 ms** | cached |
| `dedalo identity list --json` | 3 ms | cached |
| `git blame --line-porcelain` | 11 ms | cached |
| **total** | **~133 ms** | **~1 ms** |

Measure it on your own repository rather than trusting the table:

```vim
:Dedalo attach
:Dedalo profile
```

`dedalo contributors` is essentially the whole cost, and the number above is
for a project with a short unpaid range — see
[what scales badly](#what-scales-badly).

[dedalo]: https://github.com/dedalo-org/dedalo

**When it runs.** Only when asked: `:Dedalo`, `:Dedalo attach`, or
`:Dedalo refresh`. **Not** on `CursorHold`, not on `CursorMoved`, and not on
`TextChanged` — moving the cursor never costs anything.

With `auto_attach = true` it also runs on `BufReadPost` and `BufWritePost`, for
buffers backed by a real file inside a Dedalo project — **debounced by
`debounce_ms`** (150 ms). Those two events are not chatty on their own;
`:bufdo`, a session restore and holding `]q` through a quickfix list are, and
each opens buffers faster than four subprocesses can finish.

**What is cached, and against what.** Both caches are keyed on the commit at
`HEAD`, because history is the only thing that changes either answer:

| | Key | Dropped by |
| --- | --- | --- |
| attribution | repository + `HEAD` | a commit, or `:Dedalo refresh` |
| blame | repository + `HEAD` + file | a commit, or `:Dedalo refresh` |

So the second buffer in a repository pays for `git blame` alone, and reopening
a file you already annotated costs nothing. `:Dedalo refresh` drops both — for
the things that happen outside git, like `dedalo identity link` or an edit to
`dedalo.toml`.

**Nothing blocks.** Every subprocess goes through `vim.system` with a callback.
A slow repository makes the annotation appear late; it does not make Neovim
stop.

### What scales badly

`dedalo contributors` reads **every landed change since the last settled
round**, which on a project that has never settled is the whole history. The
118 ms above is a project with 29 of them; a repository with ten thousand
unpaid merges is a different proposition. That is a property of Dedalo rather
than of this plugin, and it is measured
[in the main repository](https://github.com/dedalo-org/dedalo/blob/main/tests/performance.rs).

If that is your situation, leave `auto_attach` off and run `:Dedalo` when you
want it. The first attach pays; every one after it is cached until the next
commit.

## Version compatibility

| | |
| --- | --- |
| Neovim | **0.10 or newer** — `vim.system` and the extmark API |
| `dedalo` | **0.0.1 or newer**, on `PATH` or named by `cmd` |
| git | any |

The `dedalo` floor is not decoration. This plugin parses
`dedalo contributors --json` and `dedalo identity list --json`, and those shapes
are a contract in the main repository — a renamed field breaks this plugin
*silently*, and a silent break here tells somebody the author in front of them
would be paid when they would not. `:checkhealth dedalo` compares the version on
`PATH` against the floor and says so.

## How it works

Three sources, joined:

```text
git blame --line-porcelain   →  line → author email
dedalo contributors --json   →  email → score, and the total
dedalo identity list --json  →  email → handle, wallet, excluded
```

Blame uses `--line-porcelain` rather than the default format because the
default gives the author's *name*, and Dedalo matches identities on **email**.
Two people can share a name.

Attribution is cached per repository against the commit at `HEAD`: it changes
only when history does. `:Dedalo refresh` is for the things that happen
outside git — linking an identity, editing `dedalo.toml`.

## Tests

```sh
nvim --headless -u tests/minimal_init.lua -l tests/run.lua
```

The unit tests cover the blame parser and the join — the two places a wrong
answer would be silent rather than loud. Set `DEDALO_TEST_REPO` to a Dedalo
project and the end-to-end test runs too: it builds a repository with two
contributors, links one, and asserts the annotation says the other would not
be paid. That sentence is the whole reason this exists, so CI checks it
against the real CLI rather than a fixture.

## Licence

MIT.
