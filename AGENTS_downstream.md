# Downstream (DataEraserC) Specific Rules

This file holds rules specific to the DataEraserC fork that do not exist upstream in
ryan4yin/nix-config; keeping them separate minimizes merge conflicts when syncing from upstream.

## AI contribution disclosure

Upstream [AI Disclosure](./AGENTS.md#ai-disclosure) and the Nixpkgs Automation/AI policy it cites
stay authoritative: keep upstream's `Assisted-by:` trailer, its scope, and its "record the actual
identifiers" rule instead of introducing a second scheme. Downstream only pins what that trailer
must never lose: the harness that produced the change (`DeepSeek Harness`, `WorkBuddy`, `CodeBuddy`,
or similar) together with the model it actually ran, in upstream's form -
`Assisted-by: WorkBuddy (<model>)`. Dropping either half - a bare `Assisted-by: AI`, a harness with
no model, or a guessed model - violates the upstream rule rather than being a formatting preference.

## Concurrent edits: prefer worktrees

Several agents may modify this repository at the same time. To avoid commit conflicts or a corrupted
history caused by concurrent edits to one working tree, make changes in a dedicated git worktree
(for example via the `worktree_create` tool): edit and commit inside that worktree, then merge the
result back into the main repository, rather than touching the main working tree directly. Editing
the main working tree directly is acceptable only when no concurrent modification is expected.

## Keep downstream maintenance small

Every line added here is a line upstream will not maintain for us and a conflict to resolve on the
next merge. Push work outward, in this order, before writing it down here.

1. **Fix it upstream first.** A bug, a missing option, or a wrong default belongs in
   ryan4yin/nix-config or the upstream package. Report or patch it there; a local workaround costs a
   merge conflict every sync. When a workaround is unavoidable, it goes in
   [WORKAROUNDS_downstream.md](./WORKAROUNDS_downstream.md) with a removal condition, not buried in
   a module. Upstream's [WORKAROUNDS.md](./WORKAROUNDS.md) stays identical to upstream and only
   points at that file, so row edits never collide.
2. **Put packages in `nur-DataEraserC`, not here.** Derivations, `release.json` data and update
   scripts live in the NUR input ([flake.nix](./flake.nix)); this repository only consumes
   `nur-DataEraserC.packages.${system}.<name>`. That keeps `nix-update`, the auto-update workflow
   and the packaging notes in one place, and upgrades reach us through a lock bump.
3. **Prefer the upstream module to a local one.** If upstream already ships a NixOS or Home Manager
   module, import it and expose only the options we actually set - do not re-implement the service.
   A local module is for wiring, not for behaviour upstream already owns.
4. **One tool, one module, one `enable`.** Small modules under `modules/nixos/base/custom/` that
   each own a single package are cheap to merge and cheap to drop; a combined module makes hosts
   share a switch they may not want together. Hosts opt in with one line
   (`modules.<name>.enable = true;`), and the package list stays out of `hosts/`.
5. **Persist data in the host's preservation file, unconditionally.** `tmpfs` root means state is
   lost on reboot, so the directories a tool writes belong in
   `hosts/<host>/preservation-downstream.nix` next to its siblings - never inside a
   `lib.mkIf cfg.enable` block. Tying persistence to the switch deletes a user's logins and history
   the moment a module is disabled; keep the two independent so re-enabling a tool finds its state
   intact.
6. **Verify with the host, then park it.** Build and run the tool through the host configuration
   (`nix build .#nixosConfigurations.<host>...`, then the binary with a throwaway `$HOME` to observe
   which directories it creates) before enabling it, and comment the switch out afterwards when it
   is not needed yet. A commented switch documents a verified capability; an enabled one is a
   standing build and maintenance cost.
