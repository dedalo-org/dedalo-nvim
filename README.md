# dedalo.nvim

Attribution where the code is.

[Dedalo](https://github.com/dedalo-org/dedalo) turns git merges into
contributor payouts. This shows, next to the lines in front of you, who earns
from them.

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
the size of a round is not decided until someone decides it.

## Requirements

Neovim 0.10+, `git`, and [`dedalo`](https://github.com/dedalo-org/dedalo) on
`PATH`, in a repository that has a `dedalo.toml`.

`:checkhealth dedalo` checks all four and names the one that is missing.

## Install

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "dedalo-org/dedalo-nvim",
  cmd = "Dedalo",
  opts = {},
}
```

With [packer](https://github.com/wbthomason/packer.nvim):

```lua
use({ "dedalo-org/dedalo-nvim", config = function() require("dedalo").setup() end })
```

`setup()` is optional — the defaults work.

## Use

```vim
:Dedalo            " toggle on the current buffer
:Dedalo attach
:Dedalo detach
:Dedalo refresh    " after a `dedalo identity link`
```

Everything is asynchronous. `git blame` on a large file in a large repository
is not fast, and attribution is a nicety — blocking the editor for it would be
a poor trade.

## Configuration

```lua
require("dedalo").setup({
  cmd = "dedalo",
  -- Annotate every buffer in a Dedalo project on open. Off by default: a
  -- plugin that shells out to git blame on every BufEnter without being asked
  -- is a plugin people uninstall.
  auto_attach = false,
  min_share = 0.1,
  virt_text_pos = "eol",
})
```

Highlights link to existing groups (`Comment`, `WarningMsg`, `NonText`), so
the plugin follows your colourscheme rather than fighting it. Override
`DedaloLinked`, `DedaloUnlinked` and `DedaloUncommitted` to taste.

`:help dedalo` has the rest.

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
