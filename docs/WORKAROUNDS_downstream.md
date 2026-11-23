# Downstream Workarounds

Fork-only pins and carried upstream fixes live here so the upstream
[WORKAROUNDS.md](./WORKAROUNDS.md) can remain byte-identical.

| ID      | What & where                                                                              | Why                                                                                                 | Removal condition                                                                               | Added      | Revisit               | Status |
| ------- | ----------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- | ---------- | --------------------- | ------ |
| DWA-001 | sccache NVCC inherited-PATH fix `0362a03` — `outputs/pkgs-cuda/torch-sccache-overlay.nix` | sccache 0.19.0 panics when CUDA 13.5 omits PATH from `nvcc --dryrun`; upstream merged the exact fix | Drop the scoped patch once nixpkgs' sccache contains `0362a03bf3b36dbed2e606c257ac1f0bdb06f300` | 2026-11-23 | on every sccache bump | active |
