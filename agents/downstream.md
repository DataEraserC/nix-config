# Downstream (DataEraserC) Specific Rules

These rules are specific to the DataEraserC fork and do not exist in the upstream ryan4yin/nix-config repository. They are kept separate to minimize merge conflicts when syncing with upstream.

## AI Contribution Attribution

When an agent materially contributes to a commit (authoring or editing code, configuration, scripts, or documentation), that commit MUST carry an `Assisted-by` trailer in the form `Assisted-by: <agent>:<model>`, for example `Assisted-by: dsh:deepseek-v4-flash`. Agents MUST NOT claim a model they did not run; when the model is unknown, `Assisted-by: <agent>` alone is acceptable. Agents MUST NOT use `Co-authored-by` to attribute AI involvement, or record it in fields whose semantics are ownership, accountability, or contact.
