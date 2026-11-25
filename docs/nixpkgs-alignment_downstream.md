# Downstream nixpkgs alignment roster

These repositories build against the same nixpkgs revision that this repository locks, so a package
built here and a package built there resolve to identical store paths. When nix-config moves
`nixpkgs`, the repositories below move with it in one mechanical commit per repo.

## Reading the target revision

`flake.lock` can hide the effective revision behind a `follows` chain, so ask Nix instead of
grepping:

```sh
nix eval --raw --impure \
  --expr 'let f = builtins.getFlake "/home/nixos/nix-config"; in f.inputs.nixpkgs.rev'
```

## Tracked repositories

| Repository                  | Local path                                     | Branch         | Notes                                                                                           |
| --------------------------- | ---------------------------------------------- | -------------- | ----------------------------------------------------------------------------------------------- |
| nur-packages                | `~/Documents/code/nur-packages`                | `main`         | Regenerate `README.md` with `nix run .#readme`: rows that take their version from nixpkgs move. |
| AgentChatBridge             | `~/Documents/code/AgentChatBridge`             | `dev_20261025` |                                                                                                 |
| FileClassificationSolutions | `~/Documents/code/FileClassificationSolutions` | `rust_new`     |                                                                                                 |
| AppCast                     | `~/Documents/code/AppCast`                     | `main`         |                                                                                                 |
| PoaceaeFS                   | `~/Documents/code/PoaceaeFS`                   | `poc`          | Upstream lives in a third-party org; the branch here is the fork's.                             |
| oray-tools                  | `~/Documents/code/oray-tools`                  | `main`         | Was rev-pinned in `flake.nix`; un-pinned to `nixos-unstable` on 2026-11-26.                     |
| bas-remote                  | `~/Documents/code/bas-remote`                  | `main`         | Effective nixpkgs is reached through a `follows` node (`nixpkgs_2`).                            |
| cpolar-status               | `~/Documents/code/cpolar-status`               | `main`         | Was rev-pinned in `flake.nix`; un-pinned to `nixos-unstable` on 2026-11-26.                     |
| video-login                 | `~/Documents/code/video-login`                 | `main`         | Remote is `DataEraserC/content-extractor`.                                                      |
| agent2api.nix               | `~/Documents/code/agent2api.nix`               | `main`         | `origin` is an HTTPS URL without stored credentials; push with the SSH URL.                     |
| IntentModifier              | `~/AndroidStudioProjects/IntentModifier`       | `java_engine`  | Fork of a third-party app.                                                                      |
| fcitx5-android              | `~/AndroidStudioProjects/fcitx5-android`       | `dev20261105`  | Fork of a third-party app.                                                                      |

## Procedure

Run it per repository, not with a recursive sweep, so each diff stays reviewable:

```sh
cd <repo>
nix flake lock --override-input nixpkgs github:NixOS/nixpkgs/<rev>
git add flake.lock && git commit -m "chore: update nixpkgs with nix-config"
git push origin HEAD:<branch>
```

The override changes three fields of one lock node (`lastModified`, `narHash`, `rev`) and keeps
`original.ref`, which is what the earlier alignment commits in these repositories contain. Confirm
`git status --porcelain` shows nothing but `flake.lock` before committing; these trees often hold
untracked build output from other agents.

An input pinned to a revision inside `flake.nix` cannot be aligned by the lock alone — the next
`nix flake update` would revert it. Un-pin such an input to `nixos-unstable` in the same commit and
ship both files.

nur-packages regenerates `README.md` from its own package set (`nix run .#readme`), so run that
before committing and stage the regenerated file in the same commit.

## Not tracked

- `AgentChatBridge-rewrite`, `AgentChatBridge-backup`: working copies of a repository already in the
  roster, not separate deliverables.
- Clones whose default branch belongs to someone else (`StarRailCopilot`, `deepseek-harness.nix`,
  `robotnix`, `pip2nix`, `poetry2nix`, `kernel-module-flake`, `browser-previews`, `regedit`,
  `nix-config-ryan`): rewriting their lock to a personal revision diverges from that project.
- Every other flake under `~/Documents/code` and `~/AndroidStudioProjects` was checked on 2026-11-26
  and is deliberately left alone; add it to the table above when it starts shipping packages that
  this host installs.

## Last alignment

2026-11-26 to `1c872b8c508bbbfebc1b0b74777ff391ce0a574c` (nixpkgs 2026-11-15) across all twelve
repositories. `oray-tools` and `cpolar-status` also lost their revision pins in `flake.nix` in that
pass. Checked with `just eval-host ai-gnome-wayland`; the aligned repositories were not rebuilt.
