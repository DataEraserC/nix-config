# 下游（DataEraserC）特有规则

本文件存放 DataEraserC
fork 特有、上游 ryan4yin/nix-config 中没有的规则，分开存放以尽量减少同步上游时的合并冲突。

## 并行修改：优先使用 worktree

多个 agent 可能同时修改本仓库。为避免并发编辑同一工作区导致提交冲突或历史异常，修改应优先在独立的 git
worktree 中完成（例如通过 `worktree_create`
工具）：在该 worktree 内编辑、提交，再合并回主仓库，不要直接修改主工作区。仅在确认没有并发修改时，才可直接编辑主工作区。
