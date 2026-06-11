---
name: usernode-frb-codegen
description: Run Usernode Flutter Rust Bridge codegen with the matching upstream flutter_rust_bridge revision. Use when Rust APIs or FRB bindings change.
---

# Usernode FRB Codegen

Run Flutter Rust Bridge generation against the `../usernode` checkout.

## Workflow

1. Pull latest usernode:

   ```bash
   cd ../usernode && git pull
   ```

2. Extract the `flutter_rust_bridge` `rev` from `../usernode/crates/usernode/Cargo.toml`.

3. Check whether installed codegen already matches:

   ```bash
   cargo install --list | grep -A1 '^flutter_rust_bridge_codegen' | head -2
   ```

   If it clearly contains the target rev, skip reinstalling.

4. Install only if needed:

   ```bash
   cargo install flutter_rust_bridge_codegen --git https://github.com/Usernode-Labs/flutter_rust_bridge --rev <HASH> --force
   ```

5. Verify:

   ```bash
   flutter_rust_bridge_codegen --version
   ```

6. Generate from the flutter-mobile-app root:

   ```bash
   flutter_rust_bridge_codegen generate
   ```

7. If sibling worktrees need reseeding, offer:

   ```bash
   for wt in $(git worktree list --porcelain | awk '/^worktree/ {print $2}' | tail -n +2); do
     rsync -a --delete lib/src/rust/ "$wt/lib/src/rust/"
   done
   ```

Report the FRB rev, whether install was skipped, generation status, and any worktree reseed.
