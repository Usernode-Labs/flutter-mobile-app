# Old Workflows (Archived)

## Notice

The following workflows have been removed in favor of the "Build Once, Promote Many" approach:

### Removed Workflows

1. **`auto-deploy-develop.yml`** - Auto-deploy from develop branch
   - **Reason for removal**: Built separate binaries per environment
   - **Replaced by**: `build-and-promote.yml` (builds once, promotes many)

2. **`release.yml`** - Manual release workflow
   - **Reason for removal**: Rebuilt binaries for each track
   - **Replaced by**: `build-and-promote.yml` promotion feature

## Why Changed?

### Old Approach Problems
- Different binaries per environment (internal ≠ production)
- 4x build time (built separately for each track)
- Production binary never actually tested
- Higher risk of environment-specific bugs

### New Approach Benefits
- Same binary across all tracks
- 75% faster (build once, promote in seconds)
- True end-to-end testing
- Lower cost (less CI/CD minutes)

## Migration

The new workflow (`build-and-promote.yml`) provides:
- Automatic builds on push to `develop`
- Manual promotions through tracks
- Same binary guarantee
- Faster deployments

See [BUILD-ONCE-PROMOTE.md](../BUILD-ONCE-PROMOTE.md) for complete documentation.

## Retrieving Old Workflows

If you need to reference the old workflow implementations, you can find them in git history:

```bash
# View auto-deploy-develop.yml from git history
git show HEAD~1:.github/workflows/auto-deploy-develop.yml

# View release.yml from git history
git show HEAD~1:.github/workflows/release.yml
```

Or checkout a previous commit:

```bash
# Find the last commit with the old workflows
git log --all --oneline -- .github/workflows/auto-deploy-develop.yml

# Checkout specific file from that commit
git show <commit-hash>:.github/workflows/auto-deploy-develop.yml > old-workflow.yml
```

---

**Date Archived**: 2025-11-06
**Archived By**: CI/CD Optimization
**Status**: Deprecated - Use build-and-promote.yml instead
