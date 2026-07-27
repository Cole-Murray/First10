# Working on First10

This is a solo-maintained project, so this is deliberately lightweight — just enough
structure that history stays readable and `main` stays trustworthy.

## Branching (GitHub Flow, not GitFlow)

`main` should always compile and reflect the current working state of the app. There's no
`develop`/`release` branching — that's overhead built for coordinating multiple people across
parallel releases, which doesn't apply here.

- **Trivial fixes** (typo, one-line bug fix, config tweak) can go straight to `main`.
- **Anything larger** (a new screen, a behavior change, a refactor) gets a short-lived branch:
  ```sh
  git checkout -b feature/<short-description>   # e.g. feature/custom-numeral-font
  git checkout -b fix/<short-description>        # e.g. fix/snooze-cap-off-by-one
  ```
- Open a PR even if you're merging it yourself — it gives you a diff view before it lands in
  `main` and a place for review notes if you ever want a second pair of eyes later.
- Prefer **squash merge** for feature/fix branches so `main`'s history is one commit per
  logical change, not every intermediate "wip" commit.
- Before merging, `git rebase main` on your branch (not the other way around) to fold in
  anything new on `main` and keep history linear — resolve conflicts there rather than via a
  merge commit.
- Delete the branch after merging.

## Commit messages

Lead with the *why*, not a restatement of the diff. Reference the file/behavior only if it
disambiguates. No strict conventional-commits prefix requirement, but grouping by kind
(`fix:`, `feat:`, `chore:`, `docs:`) in the subject line is welcome when it's not obvious from
context — it makes `git log --oneline` and any future changelog generation easier.

## Tagging releases

Use annotated tags with [semantic versioning](https://semver.org/):

```sh
git tag -a v0.2.0 -m "Short summary of what shipped in this tag"
git push origin v0.2.0
```

- `v0.x.y` while pre-store / still stabilizing the core loop.
- `v1.0.0` at first store submission.
- Bump the minor version for new features (a new difficulty preset, a settings option), the
  patch version for fixes, and tag *before* sideloading a build you intend to keep using, so
  you can always get back to "the version that was actually on my watch."

## Before compiling/pushing

Both device targets should compile clean before anything lands on `main`:

```powershell
monkeyc -f monkey.jungle -d fr265  -o bin/First10.prg  -y developer_key.der
monkeyc -f monkey.jungle -d fr265s -o bin/First10s.prg -y developer_key.der
```

Compiling clean is necessary but not sufficient — Connect IQ's type checker won't catch visual
layout bugs (text overlap, off-screen content). Actually run changed screens in the simulator
before merging a UI change.
