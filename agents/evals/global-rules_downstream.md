# Downstream (DataEraserC) Specific Rules

These rules are specific to the DataEraserC fork and do not exist in the upstream
ryan4yin/nix-config repository. They are kept separate to minimize merge conflicts when syncing with
upstream.

## AI Contribution Attribution

Upstream [AI Disclosure](../../AGENTS.md#ai-disclosure) and the Nixpkgs Automation/AI policy it
cites apply unchanged and take precedence; this file does not restate or weaken them. It only pins
what the `Assisted-by:` trailer must never lose: both halves of the identity, in upstream's form -
the harness that produced the change and the model that harness actually ran, e.g.
`Assisted-by: WorkBuddy (<model>)`. A trailer with no model, a model the agent did not run, or a
guessed identifier violates the upstream rule. `Co-authored-by` and fields whose semantics are
ownership, accountability, or contact never carry AI attribution.

## Concurrent edits: prefer worktrees

Multiple agents may modify this repository at the same time. To avoid conflicting concurrent edits
to a single working tree — which can break commits or corrupt history — agents SHOULD make changes
in a dedicated git worktree (e.g. via the `worktree_create` tool), commit there, and then merge the
result back into the main repository, instead of editing the main working tree directly. Editing the
main working tree directly is acceptable only when no concurrent modification is expected.
