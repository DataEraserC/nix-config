# Downstream (DataEraserC) Specific Rules

This file holds rules specific to the DataEraserC fork that do not exist upstream in
ryan4yin/nix-config; keeping them separate minimizes merge conflicts when syncing from upstream.

## Concurrent edits: prefer worktrees

Several agents may modify this repository at the same time. To avoid commit conflicts or a corrupted
history caused by concurrent edits to one working tree, make changes in a dedicated git worktree
(for example via the `worktree_create` tool): edit and commit inside that worktree, then merge the
result back into the main repository, rather than touching the main working tree directly. Editing
the main working tree directly is acceptable only when no concurrent modification is expected.
