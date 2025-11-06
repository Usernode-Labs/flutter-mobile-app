# Version Management Guide

This document explains the versioning strategy and version management practices for the Usernode mobile application.

## Table of Contents

- [Version Format](#version-format)
- [Versioning Strategy](#versioning-strategy)
- [Version Components](#version-components)
- [Build Numbers](#build-numbers)
- [Version Manager Tool](#version-manager-tool)
- [Best Practices](#best-practices)
- [Examples](#examples)

## Version Format

Usernode uses a flavor-specific version format:

### Format Structure

**Non-Production Flavors** (Internal, Alpha, Beta):
```
MAJOR.MINOR.PATCH.BUILD-flavor
```
Example: `1.2.3.456-internal`

**Production Flavor**:
```
MAJOR.MINOR.PATCH
```
Example: `1.2.3`

### Components

- **MAJOR**: Major version number (breaking changes, major features)
- **MINOR**: Minor version number (new features, backward compatible)
- **PATCH**: Patch version number (bug fixes, small improvements)
- **BUILD**: Build number (auto-incrementing per flavor)
- **flavor**: Environment identifier (internal, alpha, beta)

## Versioning Strategy

We follow [Semantic Versioning 2.0.0](https://semver.org/) with extensions for our multi-environment setup.

### When to Increment

#### MAJOR Version (X.0.0)

Increment when making incompatible changes:
- Major UI/UX redesign
- Breaking API changes
- Fundamental architecture changes
- Removal of deprecated features
- Changes requiring user re-authentication or data migration

**Examples**:
- `1.5.2` → `2.0.0` (Complete app redesign)
- `2.1.0` → `3.0.0` (New blockchain backend, breaking compatibility)

#### MINOR Version (0.X.0)

Increment when adding functionality in a backward compatible manner:
- New features
- New screens or major UI components
- New integrations
- Significant performance improvements
- Non-breaking API changes

**Examples**:
- `1.2.3` → `1.3.0` (Added DApp browser feature)
- `1.3.0` → `1.4.0` (Integrated new wallet provider)

#### PATCH Version (0.0.X)

Increment for backward compatible bug fixes:
- Bug fixes
- Performance improvements
- UI polish
- Security patches
- Dependency updates (minor)
- Text/copy changes

**Examples**:
- `1.2.3` → `1.2.4` (Fixed crash on transaction history)
- `1.2.4` → `1.2.5` (Improved loading performance)

## Version Components

### Semantic Version (MAJOR.MINOR.PATCH)

Stored in `version.json`:
```json
{
  "major": 1,
  "minor": 2,
  "patch": 3,
  ...
}
```

**Characteristics**:
- Shared across all flavors
- Only incremented for production releases (typically)
- Follows semantic versioning rules
- Displayed to end users

### Build Numbers

Stored per-flavor in `version.json`:
```json
{
  ...
  "build": {
    "internal": 456,
    "alpha": 123,
    "beta": 89,
    "production": 67
  }
}
```

**Characteristics**:
- Auto-incremented on each build
- Unique per flavor
- Used by app stores for version identification
- Must always increase (cannot go backward)

**Platform Specifics**:
- **Android**: Maps to `versionCode` in build.gradle
- **iOS**: Maps to `CFBundleVersion` in Info.plist

## Build Numbers

### Independent Build Counters

Each flavor maintains its own build counter:

```
Internal:   1.2.3.456-internal  (build 456)
Alpha:      1.2.3.123-alpha     (build 123)
Beta:       1.2.3.89-beta       (build 89)
Production: 1.2.3               (build 67, internal only)
```

### Why Separate Counters?

1. **Flexibility**: Deploy to different tracks at different rates
2. **Independence**: Internal can have many builds without affecting production
3. **Clarity**: Easy to identify which build is in which environment
4. **Rollback**: Can rollback individual tracks without affecting others

### Build Number Rules

- Build numbers **always increase**
- Cannot reuse a build number (store requirement)
- Each deployment increments the build number
- Build numbers are independent across flavors
- Production build number is tracked but not displayed in version string

## Version Manager Tool

The `scripts/version_manager.sh` script manages all version operations.

### Usage

#### Get Current Version

```bash
# Get full version string
./scripts/version_manager.sh get production
# Output: 1.2.3

./scripts/version_manager.sh get internal
# Output: 1.2.3.456-internal
```

#### Get Build Number

```bash
./scripts/version_manager.sh get-build alpha
# Output: 123
```

#### Increment Build Number

```bash
./scripts/version_manager.sh increment internal
# Output: 457
# Updates version.json automatically
```

#### Bump Semantic Version

```bash
# Patch bump (X.X.N → X.X.N+1)
./scripts/version_manager.sh bump patch
# Output: 1.2.4

# Minor bump (X.N.X → X.N+1.0)
./scripts/version_manager.sh bump minor
# Output: 1.3.0

# Major bump (N.X.X → N+1.0.0)
./scripts/version_manager.sh bump major
# Output: 2.0.0
```

#### Display Version Info

```bash
./scripts/version_manager.sh info
# Output:
# Current Version: 1.2.3
# Build Numbers:
#   - Internal:   1.2.3.456-internal
#   - Alpha:      1.2.3.123-alpha
#   - Beta:       1.2.3.89-beta
#   - Production: 1.2.3
```

### Automated Version Management

The CI/CD pipeline automatically manages versions:

1. **Auto-increment build numbers**: Every deployment increments the appropriate build number
2. **Manual version bumps**: Production releases can optionally bump MAJOR/MINOR/PATCH
3. **Git commits**: Version changes are committed back to the repository
4. **Git tags**: Production releases create annotated tags (e.g., `v1.2.3`)

## Best Practices

### 1. Version Incrementing Workflow

**For Regular Development**:
```bash
# Make changes
git commit -m "feat: add new feature"

# Push to develop (auto-increments internal build)
git push origin develop
```

**For Production Release**:
```bash
# Ensure develop is merged to main
git checkout main
git merge develop

# Use GitHub Actions workflow
# - Select "bump minor" or "bump patch" as needed
# - Workflow will auto-increment production build
# - Tag will be created automatically
```

### 2. Version Consistency

- **Always** use the version manager script
- **Never** manually edit version numbers in platform-specific files
- **Never** manually edit `version.json` except for initialization
- **Always** commit version changes
- **Always** tag production releases

### 3. Release Notes

Link version bumps to release notes:
- Major bumps: Comprehensive release notes, migration guide
- Minor bumps: Feature announcements, what's new
- Patch bumps: Bug fix list, improvements

### 4. Communication

When bumping versions:
- **Major**: Announce to all stakeholders, prepare marketing materials
- **Minor**: Announce new features to users
- **Patch**: Include in release notes, notify support team

### 5. Testing Strategy

Different testing depths for different version bumps:
- **Major**: Full QA cycle, beta testing period, gradual rollout
- **Minor**: Standard QA, beta testing
- **Patch**: Focused testing on fixes, quick turnaround

## Examples

### Example 1: Regular Development Cycle

```bash
# Current: 1.0.0
# Internal: 1.0.0.100-internal

# Day 1: Push to develop
git push origin develop
# Auto-increments to 1.0.0.101-internal

# Day 2: Another push
git push origin develop
# Auto-increments to 1.0.0.102-internal

# Ready for alpha testing
# Manually trigger alpha release
# Result: 1.0.0.50-alpha (separate counter)

# Continue development...
# Internal is now at 1.0.0.110-internal
# Alpha is still at 1.0.0.50-alpha
```

### Example 2: Production Release Flow

```bash
# Current production: 1.0.0
# Ready to release new features

# Merge to main
git checkout main
git merge develop
git push origin main

# Trigger production release via GitHub Actions
# Select "bump minor"
# Result: 1.1.0 (build number increments automatically)
# Git tag created: v1.1.0

# Continue development on develop
# Version remains 1.1.0 for all flavors
# Build numbers increment independently
```

### Example 3: Hotfix Release

```bash
# Production is at: 1.2.0
# Critical bug found

# Create hotfix branch
git checkout -b hotfix/1.2.1 v1.2.0

# Fix the bug
git commit -m "fix: critical crash on startup"

# Bump patch version
./scripts/version_manager.sh bump patch
# Result: 1.2.1

git commit -m "chore: bump version to 1.2.1"

# Deploy via GitHub Actions
# Trigger production release from hotfix branch
# Result: 1.2.1

# Merge back
git checkout main
git merge hotfix/1.2.1
git push origin main

git checkout develop
git merge hotfix/1.2.1
git push origin develop
```

### Example 4: Parallel Track Releases

```bash
# Current state:
# Production: 1.5.0
# Internal: 1.5.0.200-internal (testing features for 1.6.0)
# Alpha: 1.5.0.50-alpha (testing 1.6.0 candidates)
# Beta: 1.5.0.10-beta (final testing of 1.5.0)

# Scenario: Need to release 1.5.1 hotfix while developing 1.6.0

# 1. Create hotfix from v1.5.0
git checkout -b hotfix/1.5.1 v1.5.0

# 2. Fix and bump to 1.5.1
./scripts/version_manager.sh bump patch

# 3. Release 1.5.1 to production
# Production: 1.5.1

# 4. Meanwhile, continue developing 1.6.0 on develop
# Internal: 1.5.1.201-internal (version updated from merge)

# 5. When 1.6.0 is ready, bump minor
./scripts/version_manager.sh bump minor
# Result: 1.6.0

# Each track maintains independent builds at their respective versions
```

## Version Display

### In the App

Display version information in Settings/About screen:

```dart
// For non-production builds
Text('Version: 1.2.3.456-internal')

// For production builds
Text('Version: 1.2.3')

// Optional: Include build number internally
Text('Build: 456')
```

### In Store Listings

**Google Play**:
- Version name: `1.2.3` (production) or `1.2.3.456-internal` (internal)
- Version code: `456` (the build number)

**App Store**:
- Version: `1.2.3` (short version string)
- Build: `456` (bundle version)

### In Crash Reports

Always include both version and build:
```
Version: 1.2.3.456-internal
Build: 456
Environment: internal
```

## Migration Guide

### Migrating from Old Versioning

If migrating from a different versioning scheme:

1. **Determine Current Version**:
   - Review current production version
   - Set as starting point in `version.json`

2. **Initialize Build Numbers**:
   ```json
   {
     "major": 1,
     "minor": 5,
     "patch": 2,
     "build": {
       "internal": 1,
       "alpha": 1,
       "beta": 1,
       "production": 150  // Use current build if available
     }
   }
   ```

3. **Update Platform Files**:
   - Android: Ensure `build.gradle` reads from version script
   - iOS: Ensure Info.plist is updated by build scripts

4. **Test Version Script**:
   ```bash
   ./scripts/version_manager.sh info
   ./scripts/version_manager.sh get production
   ./scripts/version_manager.sh increment internal
   ```

## Troubleshooting

### Build Number Conflicts

**Problem**: Store rejects build (version code must be higher)

**Solution**:
```bash
# Manually increment build number
./scripts/version_manager.sh increment production
# Commit the change
git add version.json
git commit -m "chore: increment build number"
```

### Version Mismatch

**Problem**: Platform files show different version than expected

**Solution**:
- Ensure CI/CD passes version flags correctly
- Rebuild with explicit version parameters
- Check that version_manager.sh is being used

### Merge Conflicts in version.json

**Problem**: Git merge conflicts in version.json

**Solution**:
```bash
# Keep the higher build numbers
# Manually resolve in version.json
# Run version manager to verify
./scripts/version_manager.sh info
```

## References

- [Semantic Versioning 2.0.0](https://semver.org/)
- [Apple App Store Version Numbers](https://developer.apple.com/documentation/bundleresources/information_property_list/cfbundleshortversionstring)
- [Android Versioning](https://developer.android.com/studio/publish/versioning)

---

**Last Updated**: 2025-11-05

**Maintained By**: Engineering Team
