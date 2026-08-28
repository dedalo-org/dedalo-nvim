# Fixtures

The exact `--json` shapes this plugin reads, captured from a real `dedalo`.

**Captured from `dedalo` 0.0.1.** When one of these stops matching, the failure
should say *what changed* rather than "no annotation appeared" — which is why
they are files with a version on them rather than tables inlined in a test.

| File | Command |
| --- | --- |
| `contributors.json` | `dedalo contributors --json` |
| `identities.json` | `dedalo identity list --json` |

## What the plugin actually depends on

Less than the whole shape, and being precise about it is the point — a field
this plugin never reads can change without breaking anything here.

From `contributors.json`:

- `total_score` — the denominator of every share;
- `contributions[].author.email` — the join key. **Email, not name**: two
  people can share a name;
- `contributions[].author.name` — shown when no handle resolves;
- `contributions[].score` — the numerator.

From `identities.json`:

- `handle` — shown instead of the git name when it resolves;
- `emails[]` — the other half of the join;
- `excluded` — the difference between *"deliberately unpaid"* and *"nobody
  noticed"*, which is the distinction this plugin exists to draw.

Note what is **not** here: `unresolved`. This plugin does not read it. A
contributor "would not be paid" because no identity in `identity list` claims
their email, which is derived rather than reported — so a change to
`unresolved` in `dedalo` does not affect this plugin, and a change to
`identity list` does.
