# CI/CD Complete Guide

Complete guide for CI/CD pipeline, deployment, version management, and emergency procedures for the Usernode mobile application.

## Table of Contents

- [Quick Start](#quick-start)
- [Overview](#overview)
- [Initial Setup](#initial-setup)
- [Version Management](#version-management)
- [Deployment](#deployment)
- [Rollback & Hotfix Procedures](#rollback--hotfix-procedures)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

---

## Quick Start

### What's Implemented

A complete CI/CD pipeline for building and deploying the Flutter app to both iOS and Android across four release tracks: Internal, Alpha, Beta, and Production.

### Version Format

- **Internal/Alpha/Beta**: `1.0.0.123-internal` (includes build number)
- **Production**: `1.0.0` (clean semantic version)

### Bundle ID

**All Flavors**: `org.usernode.app` (single bundle ID across all environments)

### Branch Strategy & Environment Mapping

The project uses a **branch-based environment strategy** where configuration secrets are automatically selected based on the branch:

| Branch | Secrets | Initial Track | Promotion Path |
|--------|---------|---------------|----------------|
| **`develop`** | `NONPROD_*` | Internal | Internal → Alpha → Beta |
| **`main`** | `PROD_*` | Production | (Direct to production) |

**Workflow:**
1. **Push to `develop`** → Builds with non-production config → Deploys to internal → Manually promote through alpha/beta
2. **Push to `main`** → Builds with production config → Deploys directly to production track
3. **PR to `develop`** → Validates with non-production secrets
4. **PR to `main`** → Validates with production secrets

**Tags**: Created automatically for production releases (e.g., `v1.0.0`)

### Release Tracks

- **Internal**: Auto-deployed from `develop` branch (non-prod config)
- **Alpha**: Manual promotion of develop builds
- **Beta**: Manual promotion of develop builds
- **Production**: Auto-deployed from `main` branch (prod config)

### Quick Commands

```bash
# View current version info
./scripts/version_manager.sh info

# Get specific flavor version
./scripts/version_manager.sh get production

# Increment build number
./scripts/version_manager.sh increment internal

# Bump semantic version
./scripts/version_manager.sh bump patch
```

---

## Overview

### Architecture

The Usernode app uses a multi-track release strategy with four environments:

- **Internal**: Development builds for internal testing
- **Alpha**: Early testing builds for a wider internal audience
- **Beta**: Pre-release builds for external testers
- **Production**: Public releases on App Store and Google Play

### Workflows

Three main GitHub Actions workflows:

1. **PR Checks** (`.github/workflows/pr-checks.yml`)
   - **Trigger**: Pull requests to `main` or `develop`
   - **Behavior**: Automatically selects secrets based on target branch
     - PR to `develop` → Uses `NONPROD_*` secrets
     - PR to `main` → Uses `PROD_*` secrets
   - **Actions**: Runs tests, code analysis, and debug builds

2. **Build Once, Promote Many** (`.github/workflows/build-and-promote.yml`)
   - **Trigger**: Push to `develop` or `main` branch, OR manual promotion
   - **Behavior**: Automatically selects secrets based on source branch
     - Push to `develop` → Uses `NONPROD_*` secrets → Builds for internal/alpha/beta
     - Push to `main` → Uses `PROD_*` secrets → Builds for production
   - **Strategy**: Builds once per environment, promotes same binary through tracks
   - **See**: [Build Once, Promote Many Guide](BUILD-ONCE-PROMOTE.md)

3. **Test Suite** (`.github/workflows/test.yml`)
   - **Trigger**: Push to any branch
   - **Actions**: Runs unit and integration tests

**Key Concept**: Each branch builds with its own environment configuration:
- `develop` builds use non-production URLs/settings (for testing)
- `main` builds use production URLs/settings (for real users)
- Same binary promoted through tracks within each environment

### Files Structure

```
flutter-mobile-app/
├── .github/workflows/          # GitHub Actions workflows
│   ├── build-and-promote.yml  # Build once, promote many (branch-based)
│   ├── pr-checks.yml          # PR validation (branch-based)
│   └── test.yml               # Test suite
├── docs/                       # Documentation
│   ├── CICD-GUIDE.md          # This file
│   ├── SECRETS.md             # GitHub Secrets configuration guide
│   └── BUILD-ONCE-PROMOTE.md  # Promotion strategy guide
├── scripts/                    # Automation scripts
│   ├── version_manager.sh     # Version management
│   └── generate_release_notes.sh
├── fastlane/                   # Fastlane configuration
│   ├── Fastfile
│   └── Appfile
├── android/app/                # Android configuration
│   └── build.gradle           # Flavor configurations
├── ios/                        # iOS configuration
│   └── ExportOptions-*.plist  # Export options per flavor
├── version.json               # Version tracking
└── .env.example               # Environment template (for local dev only)
                               # CI/CD uses GitHub Secrets
```

---

## Initial Setup

### Prerequisites

Before starting, ensure you have:

- [ ] GitHub repository with admin access
- [ ] Google Play Developer account
- [ ] Apple Developer account (with Admin role)
- [ ] Access to Google Play Console
- [ ] Access to App Store Connect
- [ ] Signing keys and certificates
- [ ] (Optional) Slack workspace for notifications
- [ ] (Optional) Firebase project for App Distribution

### 1. Install Required Tools Locally

```bash
# Install Flutter
# Follow: https://docs.flutter.dev/get-started/install

# Install Fastlane
sudo gem install fastlane

# Install jq (for version management)
brew install jq  # macOS
# or
sudo apt-get install jq  # Ubuntu

# Verify installations
flutter --version
fastlane --version
jq --version
```

### 2. Clone and Setup Repository

```bash
# Clone the repository
git clone https://github.com/Usernode-Labs/flutter-mobile-app.git
cd flutter-mobile-app

# Install Flutter dependencies
flutter pub get

# Make scripts executable
chmod +x scripts/version_manager.sh
chmod +x scripts/generate_release_notes.sh
```

### 3. Configure GitHub Secrets

Navigate to your GitHub repository → Settings → Secrets and variables → Actions.

#### Android Secrets

1. **ANDROID_KEYSTORE_BASE64**
   ```bash
   # Create if you don't have a keystore
   keytool -genkey -v -keystore usernode-release.jks \
     -keyalg RSA -keysize 2048 -validity 10000 \
     -alias usernode-key

   # Convert to base64
   base64 -i usernode-release.jks | pbcopy  # macOS
   # or
   base64 -w 0 usernode-release.jks  # Linux
   ```

2. **KEYSTORE_PASSWORD** - The password you used when creating the keystore
3. **KEY_ALIAS** - The alias you used (e.g., `usernode-key`)
4. **KEY_PASSWORD** - The key password
5. **GOOGLE_PLAY_SERVICE_ACCOUNT_JSON** - See [Google Play Setup](#google-play-console-setup)

#### iOS Secrets

1. **CERTIFICATES_P12**
   ```bash
   # Export certificate from Keychain
   # Then convert to base64
   base64 -i certificate.p12 | pbcopy  # macOS
   ```

2. **CERTIFICATES_PASSWORD** - Password used when exporting the certificate
3. **PROVISIONING_PROFILES**
   ```bash
   # Download from Apple Developer Portal
   base64 -i UserNodeApp.mobileprovision | pbcopy
   ```

4. **APP_STORE_CONNECT_API_KEY_ID** - From App Store Connect → Users and Access → Keys
5. **APP_STORE_CONNECT_ISSUER_ID** - Found on the same page
6. **APP_STORE_CONNECT_API_KEY**
   ```bash
   # Download the .p8 file, then convert
   base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy
   ```

7. **APPLE_ID** - Your Apple Developer account email

#### Optional Secrets

- **FIREBASE_APP_DISTRIBUTION_TOKEN** - For Firebase App Distribution
- **FIREBASE_APP_ID_ANDROID** - From Firebase Console
- **FIREBASE_APP_ID_IOS** - From Firebase Console
- **SLACK_WEBHOOK_URL** - For team notifications

### 4. Google Play Console Setup

1. **Create Service Account**:
   - Go to Google Cloud Console
   - Create a new project or select existing
   - Enable Google Play Android Developer API
   - Go to IAM & Admin → Service Accounts
   - Create Service Account: `github-actions-deploy`

2. **Generate JSON Key**:
   - Click on the service account → Keys tab
   - "Add Key" → "Create new key" → JSON format
   - Save the file securely

3. **Link to Play Console**:
   - Go to Google Play Console → Setup → API access
   - Link the service account
   - Grant permissions: View, Create and edit releases

4. **Add as GitHub Secret**: Copy entire JSON as `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`

### 5. App Store Connect Setup

1. **Create App**:
   - Go to App Store Connect → My Apps → "+" → New App
   - Bundle ID: org.usernode.app

2. **Create API Key**:
   - App Store Connect → Users and Access → Keys
   - Create new key with App Manager or Admin access
   - Download the .p8 file (only available once!)
   - Note the Key ID and Issuer ID

3. **Create Provisioning Profiles**:
   - Go to Apple Developer Portal → Certificates, Identifiers & Profiles
   - Create App ID: `org.usernode.app`
   - Create iOS Distribution certificate
   - Create Provisioning Profiles for each flavor
   - Download all profiles

4. **Configure in Xcode**:
   - Open `ios/Runner.xcworkspace`
   - Create 4 schemes: Internal, Alpha, Beta, Production
   - Configure signing for each scheme

### 6. Configure Environment Secrets

The project uses **GitHub Secrets** for environment configuration instead of committing `.env` files. You need to configure two sets of secrets: Production (`PROD_*`) and Non-Production (`NONPROD_*`).

#### Production Secrets (PROD_*)

Used when building from the `main` branch:

```bash
PROD_APP_ENV=production
PROD_API_BASE_URL=https://api.usernode.app
PROD_VERBOSE_LOGGING=false
PROD_SENTRY_DSN=https://your-prod-sentry-dsn@sentry.io/project-id
PROD_GITHUB_TOKEN=ghp_your_production_github_token
PROD_USE_RESULT_PROVIDERS=true
PROD_ENABLED_FEATURES=home,wallet,dapps,profile,node
PROD_DISABLED_FEATURES=
```

#### Non-Production Secrets (NONPROD_*)

Used when building from the `develop` branch:

```bash
NONPROD_APP_ENV=staging
NONPROD_API_BASE_URL=https://api-staging.usernode.app
NONPROD_VERBOSE_LOGGING=true
NONPROD_SENTRY_DSN=https://your-staging-sentry-dsn@sentry.io/project-id
NONPROD_GITHUB_TOKEN=ghp_your_staging_github_token
NONPROD_USE_RESULT_PROVIDERS=true
NONPROD_ENABLED_FEATURES=home,wallet,dapps,profile,node
NONPROD_DISABLED_FEATURES=
```

**📚 For complete details**, see [SECRETS.md](SECRETS.md) - comprehensive guide on configuring all GitHub Secrets.

### 7. Test the Pipeline

```bash
# Test version manager
./scripts/version_manager.sh info

# Test a build locally
flutter build apk --flavor internal --release
flutter build ios --flavor internal --release

# Create a test PR to verify PR checks workflow
# Push to develop to verify auto-deploy workflow
```

---

## Version Management

### Version Format

We follow [Semantic Versioning 2.0.0](https://semver.org/) with extensions for multi-environment setup.

**Non-Production Flavors**:
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

- **MAJOR**: Breaking changes, major features
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes, small improvements
- **BUILD**: Auto-incrementing per flavor
- **flavor**: Environment identifier (internal, alpha, beta)

### When to Increment

#### MAJOR Version (X.0.0)

Increment for incompatible changes:
- Major UI/UX redesign
- Breaking API changes
- Fundamental architecture changes
- Removal of deprecated features
- Changes requiring user re-authentication or data migration

**Example**: `1.5.2` → `2.0.0` (Complete app redesign)

#### MINOR Version (0.X.0)

Increment for backward compatible features:
- New features
- New screens or major UI components
- New integrations
- Significant performance improvements

**Example**: `1.2.3` → `1.3.0` (Added DApp browser feature)

#### PATCH Version (0.0.X)

Increment for backward compatible bug fixes:
- Bug fixes
- Performance improvements
- UI polish
- Security patches
- Text/copy changes

**Example**: `1.2.3` → `1.2.4` (Fixed crash on transaction history)

### Build Numbers

Each flavor maintains its own build counter stored in `version.json`:

```json
{
  "major": 1,
  "minor": 2,
  "patch": 3,
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
- Must always increase (cannot go backward)
- Used by app stores for version identification

### Version Manager Tool

The `scripts/version_manager.sh` script manages all version operations.

#### Usage

```bash
# Get current version
./scripts/version_manager.sh get production
# Output: 1.2.3

./scripts/version_manager.sh get internal
# Output: 1.2.3.456-internal

# Get build number
./scripts/version_manager.sh get-build alpha
# Output: 123

# Increment build number
./scripts/version_manager.sh increment internal
# Output: 457

# Bump semantic version
./scripts/version_manager.sh bump patch    # 1.2.3 → 1.2.4
./scripts/version_manager.sh bump minor    # 1.2.3 → 1.3.0
./scripts/version_manager.sh bump major    # 1.2.3 → 2.0.0

# Display version info
./scripts/version_manager.sh info
```

### Best Practices

1. **Always use the version manager script** - Never manually edit version numbers
2. **Commit version changes** - All version updates should be committed to git
3. **Tag production releases** - Use annotated tags (e.g., `v1.2.3`)
4. **Link to release notes** - Document what changed in each version
5. **Test before incrementing** - Ensure builds work before bumping versions

### Version Examples

#### Example 1: Regular Development

```bash
# Current: 1.0.0, Internal: 1.0.0.100-internal
git push origin develop
# Auto-increments to 1.0.0.101-internal

# Ready for alpha
# Manually trigger alpha release → 1.0.0.50-alpha (separate counter)
```

#### Example 2: Production Release

```bash
# Current production: 1.0.0
# Merge develop to main
git checkout main
git merge develop
git push origin main

# Trigger production release via GitHub Actions
# Select "bump minor" → Result: 1.1.0
# Git tag created: v1.1.0
```

#### Example 3: Hotfix Release

```bash
# Production: 1.2.0, critical bug found
git checkout -b hotfix/1.2.1 v1.2.0

# Fix the bug
git commit -m "fix: critical crash on startup"

# Bump version
./scripts/version_manager.sh bump patch  # → 1.2.1
git commit -m "chore: bump version to 1.2.1"

# Deploy via GitHub Actions
# Merge back to main and develop
```

---

## Deployment

### Pre-Deployment Checklist

Before triggering a production release:

- [ ] All critical bugs are fixed
- [ ] All tests are passing
- [ ] Code has been reviewed and approved
- [ ] Changes tested on both iOS and Android
- [ ] Release notes prepared
- [ ] Marketing/product team notified
- [ ] App Store/Play Store metadata up to date
- [ ] Screenshots current (if needed)
- [ ] Privacy policy up to date (if needed)
- [ ] Version number bump appropriate

### Automatic Deployment (Internal)

Simply push to the `develop` branch:

```bash
git checkout develop
git add .
git commit -m "feat: new feature"
git push origin develop
```

**What happens**:
1. Auto-increments production build number
2. Builds single release AAB and IPA (production config)
3. Uploads to Google Play Internal track
4. Uploads to TestFlight Internal testing
5. Stores artifact in GitHub (90 days retention)
6. Sends team notification

**Result**: A new build is available in Internal track for testing.

### Manual Promotion

#### Promote to Alpha

After internal testing passes:

1. **Navigate to GitHub Actions**:
   - Go to repository on GitHub
   - Click "Actions" tab
   - Select "Build Once, Promote Many" workflow

2. **Trigger Promotion**:
   - Click "Run workflow"
   - `promote_to`: **alpha**
   - `build_number`: leave empty (uses latest) or specify build number
   - Click "Run workflow"

3. **Verify**:
   - Check Google Play Console → Alpha track
   - Check TestFlight → Alpha group

#### Promote to Beta

After alpha testing passes:

1. Go to GitHub Actions → "Build Once, Promote Many"
2. Click "Run workflow"
3. `promote_to`: **beta**
4. `build_number`: leave empty
5. Click "Run workflow"

#### Promote to Production

After beta testing passes:

1. Go to GitHub Actions → "Build Once, Promote Many"
2. Click "Run workflow"
3. `promote_to`: **production**
4. `build_number`: leave empty
5. Click "Run workflow"

**Additional actions for production**:
- Creates git tag (e.g., `v1.2.3`)
- Creates GitHub Release with notes
- Sends team notification

> **Important**: The same binary tested in internal/alpha/beta is what goes to production. No rebuild, just promotion.

#### Promotion Examples

**Promote Latest Build to Alpha**:
```
1. Actions → Build Once, Promote Many → Run workflow
2. promote_to: alpha
3. build_number: (leave empty)
4. Click "Run workflow"
```

**Promote Specific Build to Production**:
```
1. Check build: ./scripts/version_manager.sh get-build production
2. Actions → Build Once, Promote Many → Run workflow
3. promote_to: production
4. build_number: 123 (specific build)
5. Click "Run workflow"
```

**Complete Flow Example**:
```
Day 1: Push to develop
       → Build #120 deployed to Internal

Day 3: Internal testing passed
       → Promote #120 to Alpha

Day 5: Alpha testing passed
       → Promote #120 to Beta

Day 10: Beta testing passed
        → Promote #120 to Production
        → Git tag v1.2.3 created
        → GitHub Release created
```

### Post-Deployment

#### After Internal/Alpha Deployment

1. Monitor crash reports in Sentry
2. Gather feedback from testers
3. Track key metrics
4. Fix critical issues before promoting

#### After Beta Deployment

1. Monitor crash rates and user feedback
2. Verify all features work as expected
3. Conduct final QA testing
4. Prepare for production release

#### After Production Deployment

1. **Monitor the Release**:
   - Check crash rates in Sentry
   - Monitor analytics
   - Track app store reviews
   - Monitor performance metrics

2. **Gradual Rollout** (Google Play):
   - Start with 10% rollout
   - Monitor for 24 hours
   - Increase to 50% if stable
   - Complete rollout to 100%

3. **Communication**:
   - Announce release to users (if major)
   - Update documentation
   - Notify support team

4. **Track Performance**:
   - Monitor crash-free rate (target: >99%)
   - Check ANR rate
   - Verify feature adoption
   - Track user retention

### Store Submission Notes

#### Google Play Console

- Builds automatically uploaded to appropriate track
- May need to manually submit to production
- Ensure release notes filled in
- Set rollout percentage (start with 10-20%)

#### App Store Connect

- Builds automatically uploaded to TestFlight
- Production requires manual submission for review
- Fill in "What's New" section
- Submit through App Store Connect
- Typical review time: 1-2 days

---

## Rollback & Hotfix Procedures

### When to Rollback

Consider rolling back when:

- **Critical Bug**: App crashes on launch for significant portion of users
- **Data Loss**: Users experiencing data corruption or loss
- **Security Issue**: Security vulnerability discovered
- **High Crash Rate**: Crash-free rate drops below 95%
- **Business Critical**: Core feature completely broken
- **User Impact**: Significant negative feedback

**Do NOT rollback for**:
- Minor bugs not impacting core functionality
- Low-frequency crashes (<1% of users)
- UI/UX issues that are annoying but not blocking
- Issues that can be fixed with quick hotfix

### Rollback Procedures

#### Assessment Phase (15 minutes)

1. **Identify the Issue**:
   - Check Sentry for crash reports
   - Review user reports and app store reviews
   - Check analytics for unusual patterns
   - Determine scope of impact

2. **Decision to Rollback**:
   - Severity: Is this critical?
   - Impact: What % of users affected?
   - Alternative: Can we hotfix instead?
   - Timeline: How long to fix properly?

3. **Notify Team**:
   - Alert #engineering and #product channels
   - Notify customer support team
   - Prepare user communication if needed

#### Android Rollback (Google Play Console)

**Option 1: Promote Previous Version (Recommended)**

1. Log in to Google Play Console
2. Navigate to Production (or affected track)
3. Find previous stable version
4. Click "Promote to Production"
5. Set rollout to 100%
6. Add release notes explaining rollback
7. Halt current problematic release

**Option 2: Manual Rollback via CI/CD**

```bash
# Find the last stable tag
git tag -l "v*" | sort -V | tail -5

# Trigger release workflow with that version
# Go to GitHub Actions → Release Build and Deploy
# Select the stable git tag/commit
# Deploy to production track
```

#### iOS Rollback (App Store)

**Important**: Apple does not allow direct rollbacks. You must submit a new build.

**Quick Rollback Process**:

1. **Identify Last Stable Version**:
   ```bash
   git tag -l "v*" | sort -V | tail -5
   ```

2. **Checkout Stable Version**:
   ```bash
   git checkout tags/v1.0.0  # Replace with stable version
   ```

3. **Increment Build Number**:
   - Update `version.json` to have higher build number than current
   - Keep the same version number

4. **Build and Submit**:
   ```bash
   ./scripts/version_manager.sh increment production
   # Then run the release workflow
   ```

5. **Submit for Expedited Review**:
   - Go to App Store Connect
   - Submit the build
   - Request expedited review (explain it's critical fix)
   - Typical expedited review: 1-2 hours

### Hotfix Procedures

Use hotfixes when:
- Issue can be fixed quickly (< 4 hours)
- Fix is well-understood and low-risk
- Rolling back would cause more problems

#### Hotfix Workflow

**1. Create Hotfix Branch**

```bash
# Ensure you're on latest production tag
git fetch --tags
git checkout tags/v1.0.0  # Replace with current production

# Create hotfix branch
git checkout -b hotfix/1.0.1

# Make your fixes
# ... edit files ...

# Test thoroughly
flutter test
flutter build apk --release
flutter build ios --release
```

**2. Update Version**

```bash
# Bump patch version
./scripts/version_manager.sh bump patch

# Commit version bump
git add version.json
git commit -m "chore: bump version to 1.0.1"
```

**3. Test the Hotfix**

```bash
# Run all tests
flutter test

# Build for both platforms
flutter build apk --flavor production --release
flutter build ios --flavor production --release

# Manual testing
# - Install on test devices
# - Verify fix works
# - Ensure no new issues introduced
```

**4. Deploy Hotfix**

```bash
# Push hotfix branch
git push origin hotfix/1.0.1

# Go to GitHub Actions → Release Build and Deploy
# Run workflow:
#   - Branch: hotfix/1.0.1
#   - Flavor: production
#   - Platform: both
#   - Version Bump: none (already bumped)
```

**5. Merge Hotfix Back**

```bash
# Merge to main
git checkout main
git merge hotfix/1.0.1
git push origin main

# Merge to develop
git checkout develop
git merge hotfix/1.0.1
git push origin develop

# Delete hotfix branch
git branch -d hotfix/1.0.1
git push origin --delete hotfix/1.0.1
```

### Hotfix Checklist

- [ ] Hotfix branch created from production tag
- [ ] Issue identified and fix implemented
- [ ] All tests passing
- [ ] Manual testing completed on both platforms
- [ ] Version bumped appropriately
- [ ] Hotfix deployed to production
- [ ] Monitoring confirms issue resolved
- [ ] Hotfix merged back to main and develop
- [ ] Post-mortem scheduled

### Post-Incident

#### Immediate (Within 1 hour)

1. **Verify Resolution**:
   - Check Sentry crash rates
   - Monitor app analytics
   - Review user feedback
   - Confirm store metrics improving

2. **Communicate**:
   - Notify all stakeholders
   - Update status page if applicable
   - Respond to user inquiries

#### Short-term (Within 24 hours)

1. **User Communication**:
   - Update app store description if needed
   - Send push notification if appropriate
   - Update support documentation

2. **Internal Review**:
   - What went wrong?
   - Why didn't we catch it earlier?
   - What were the warning signs?

#### Long-term (Within 1 week)

1. **Post-Mortem**:
   - Schedule blameless post-mortem meeting
   - Document timeline of events
   - Identify root causes
   - Create action items to prevent recurrence

2. **Process Improvements**:
   - Update testing procedures
   - Enhance monitoring/alerting
   - Improve rollout strategy
   - Update documentation

### Post-Mortem Template

```markdown
# Incident Post-Mortem: [Date] - [Brief Description]

## Summary
- **Date**: YYYY-MM-DD
- **Duration**: X hours
- **Impact**: X% of users affected
- **Resolution**: Rollback/Hotfix

## Timeline
- HH:MM - Issue first detected
- HH:MM - Decision to rollback made
- HH:MM - Rollback initiated
- HH:MM - Rollback completed
- HH:MM - Issue resolved

## Root Cause
[Detailed explanation]

## Detection
[How was the issue discovered?]

## Response
[What actions were taken?]

## Lessons Learned
### What Went Well
- Item 1
- Item 2

### What Could Be Improved
- Item 1
- Item 2

## Action Items
- [ ] Action item 1 - Owner - Due date
- [ ] Action item 2 - Owner - Due date
```

### Rollback Metrics

Track these metrics:
- **Detection Time**: How long until we noticed?
- **Decision Time**: How long to decide to rollback?
- **Execution Time**: How long did rollback take?
- **Recovery Time**: Total time from detection to resolution
- **User Impact**: How many users affected?

**Target Metrics**:
- Detection: < 15 minutes
- Decision: < 15 minutes
- Execution: < 30 minutes
- Total Recovery: < 1 hour

### Prevention

To minimize rollbacks:

1. **Gradual Rollouts**:
   - Start at 10% for production
   - Monitor for 24 hours
   - Increase gradually

2. **Better Testing**:
   - Comprehensive test coverage
   - Beta testing period (minimum 1 week)
   - Dogfooding (use internal builds)

3. **Monitoring**:
   - Set alerts for crash rate spikes
   - Monitor key metrics in real-time
   - Track user feedback closely

4. **Feature Flags**:
   - Use feature flags for risky features
   - Ability to disable features remotely
   - Gradual feature rollouts

---

## Best Practices

### 1. Development Workflow

```bash
# Feature development
git checkout develop
git checkout -b feature/new-feature

# Make changes and commit
git commit -m "feat: add new feature"

# Push and create PR to develop
git push origin feature/new-feature

# After PR approval and merge, delete branch
git branch -d feature/new-feature
```

### 2. Release Workflow

```bash
# Prepare for release
git checkout main
git merge develop

# Trigger release via GitHub Actions
# Monitor the deployment
# Verify in stores
```

### 3. Testing Strategy

- **Unit Tests**: Run on every commit
- **Widget Tests**: Run on every PR
- **Integration Tests**: Run before releases
- **Manual Testing**: Beta track before production
- **Gradual Rollout**: Start at 10% for production

### 4. Monitoring

- **Crash Reports**: Sentry integration
- **Analytics**: Track user behavior
- **Performance**: Monitor ANR rates
- **User Feedback**: App store reviews, in-app feedback

### 5. Communication

- **Internal**: Team notifications via Slack
- **External**: Release notes, changelogs
- **Support**: Keep support team informed
- **Users**: In-app announcements for major releases

### 6. Version Management

- Use semantic versioning
- Auto-increment build numbers
- Tag production releases
- Document changes in release notes

### 7. Security

- Rotate secrets regularly
- Use least-privilege access
- Monitor for security issues
- Keep dependencies updated

---

## Troubleshooting

### GitHub Actions Failing

**Problem**: Workflow fails immediately
- **Solution**: Check if all required secrets are set
- Verify secret names match exactly

**Problem**: "Keystore not found"
- **Solution**: Verify `ANDROID_KEYSTORE_BASE64` is correctly encoded
- Test locally: `echo "$KEYSTORE_BASE64" | base64 -d > test.jks`

**Problem**: iOS build fails with signing error
- **Solution**:
  - Verify certificates are valid and not expired
  - Check provisioning profile matches bundle ID
  - Ensure Team ID is correct

### Build Issues

**Problem**: Build fails on Android
- Check keystore configuration
- Verify `key.properties` secrets set correctly
- Check Gradle build errors in logs

**Problem**: Build fails on iOS
- Verify provisioning profiles are valid
- Check certificate expiration
- Ensure Bundle ID matches provisioning profile
- Check CocoaPods installation

### Store Upload Issues

**Problem**: "Version code must be higher than previous"
- **Solution**: Increment build number manually in `version.json`

**Problem**: Upload to store fails
- Verify API keys valid and not expired
- Check build number higher than previous
- Ensure track/group exists in store console
- Check service account permissions (Android)

**Problem**: "Package name mismatch"
- **Solution**: Verify bundle ID/package name in:
  - `android/app/build.gradle`
  - `ios/Runner.xcodeproj`
  - Google Play Console
  - App Store Connect

### Version Management Issues

**Problem**: Build number conflicts
- **Solution**: Manually increment with `./scripts/version_manager.sh increment [flavor]`

**Problem**: Version mismatch
- **Solution**: Ensure CI/CD passes version flags correctly
- Rebuild with explicit version parameters
- Check version_manager.sh is being used

**Problem**: Merge conflicts in version.json
- **Solution**: Keep higher build numbers, manually resolve
- Run `./scripts/version_manager.sh info` to verify

### Common Questions

**Q: Can I skip a version number?**
A: For semantic versions (MAJOR.MINOR.PATCH), yes. For build numbers, no - they must always increase.

**Q: Can I deploy the same version to multiple tracks?**
A: Yes, but each track will have different build numbers (e.g., `1.0.0.100-internal`, `1.0.0.50-alpha`).

**Q: How do I test the CI/CD pipeline without deploying?**
A: Use PR checks workflow, or run builds locally with `flutter build` commands.

**Q: Can I rollback automatically?**
A: No, rollbacks require manual intervention through store consoles or redeployment.

---

## Support & Resources

### Documentation

- [Semantic Versioning](https://semver.org/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Fastlane Documentation](https://docs.fastlane.tools/)
- [Flutter Deployment](https://docs.flutter.dev/deployment)

### Getting Help

1. Check workflow logs in GitHub Actions
2. Review this guide for missed steps
3. Consult team documentation
4. Open an issue in the repository
5. Contact #engineering in Slack

### Maintenance Tasks

**Monthly**:
- [ ] Verify certificates valid (check expiration dates)
- [ ] Test rollback procedure
- [ ] Review and update secrets if needed
- [ ] Check for Fastlane/dependency updates

**Quarterly**:
- [ ] Review and optimize workflows
- [ ] Update documentation
- [ ] Audit access permissions
- [ ] Review store metadata

**Annually**:
- [ ] Renew Apple Developer Program membership
- [ ] Rotate signing keys if needed
- [ ] Review and update privacy policies
- [ ] Update screenshots and metadata

---

**Status**: ✅ Implementation Complete
**Last Updated**: 2025-11-06
**Maintained By**: Engineering Team

For questions or updates to this guide, please open an issue or PR.

**Happy Deploying! 🚀**
