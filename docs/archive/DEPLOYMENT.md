# Deployment Guide

This document describes the deployment process for the Usernode mobile application.

## Table of Contents

- [Overview](#overview)
- [Version Format](#version-format)
- [Release Tracks](#release-tracks)
- [Deployment Workflows](#deployment-workflows)
- [Manual Release](#manual-release)
- [Automatic Deployment](#automatic-deployment)
- [Pre-Deployment Checklist](#pre-deployment-checklist)
- [Post-Deployment](#post-deployment)

## Overview

The Usernode app uses a multi-track release strategy with four environments:
- **Internal**: Development builds for internal testing
- **Alpha**: Early testing builds for a wider internal audience
- **Beta**: Pre-release builds for external testers
- **Production**: Public releases on App Store and Google Play

All environments use the same bundle ID: `org.usernode.app`

## Version Format

### Version Naming Convention

- **Internal**: `MAJOR.MINOR.PATCH.BUILD-internal` (e.g., `1.0.0.123-internal`)
- **Alpha**: `MAJOR.MINOR.PATCH.BUILD-alpha` (e.g., `1.0.0.45-alpha`)
- **Beta**: `MAJOR.MINOR.PATCH.BUILD-beta` (e.g., `1.0.0.12-beta`)
- **Production**: `MAJOR.MINOR.PATCH` (e.g., `1.0.0`)

### Version Management

Version information is stored in `version.json`:

```json
{
  "major": 1,
  "minor": 0,
  "patch": 0,
  "build": {
    "internal": 123,
    "alpha": 45,
    "beta": 12,
    "production": 67
  }
}
```

Use the `scripts/version_manager.sh` script to manage versions:

```bash
# Get current version for a flavor
./scripts/version_manager.sh get production

# Get build number
./scripts/version_manager.sh get-build internal

# Increment build number
./scripts/version_manager.sh increment alpha

# Bump version (major, minor, or patch)
./scripts/version_manager.sh bump patch

# Display version info
./scripts/version_manager.sh info
```

## Release Tracks

### Android (Google Play Console)

- **Internal Track**: Internal testing, automatic deployment from `develop` branch
- **Alpha Track**: Closed testing for internal team
- **Beta Track**: Open or closed testing for external users
- **Production Track**: Public release

### iOS (TestFlight & App Store)

- **Internal Testing**: Automatic deployment from `develop` branch
- **External Testing**: Beta testing via TestFlight
- **Production**: App Store release

## Deployment Workflows

### 1. Manual Release Workflow

**File**: `.github/workflows/release.yml`

**Trigger**: Manual workflow dispatch

**Inputs**:
- `flavor`: internal, alpha, beta, or production
- `platform`: both, android, or ios
- `version_bump`: none, patch, minor, or major (for production only)

**What it does**:
1. Bumps version if requested (production only)
2. Increments build number for the selected flavor
3. Builds signed Android AAB and/or iOS IPA
4. Uploads to Google Play Console and/or TestFlight
5. Creates GitHub Release (production only)
6. Creates git tag (production only)
7. Sends team notification

### 2. Auto-Deploy Develop Workflow

**File**: `.github/workflows/auto-deploy-develop.yml`

**Trigger**: Push to `develop` branch

**What it does**:
1. Increments internal build number
2. Builds Android AAB and APK
3. Builds iOS IPA
4. Uploads to Google Play Internal track
5. Uploads to TestFlight Internal testing
6. Optionally uploads to Firebase App Distribution
7. Sends team notification

### 3. PR Checks Workflow

**File**: `.github/workflows/pr-checks.yml`

**Trigger**: Pull requests to `main` or `develop`

**What it does**:
1. Runs code formatting checks
2. Runs static code analysis
3. Runs unit tests
4. Builds debug versions for all flavors
5. Reports coverage

## Manual Release

### Step-by-Step Guide

1. **Navigate to GitHub Actions**:
   - Go to your repository on GitHub
   - Click on the "Actions" tab
   - Select "Release Build and Deploy" workflow

2. **Trigger the Workflow**:
   - Click "Run workflow" button
   - Select the branch (usually `main` for production, `develop` for others)
   - Choose parameters:
     - **Flavor**: Select the release track (internal/alpha/beta/production)
     - **Platform**: Select the platform to build (both/android/ios)
     - **Version Bump**: For production only, select version bump type

3. **Monitor the Build**:
   - Watch the workflow progress in the Actions tab
   - Check for any failures in the build process

4. **Verify the Release**:
   - **Android**: Check Google Play Console for the new build
   - **iOS**: Check App Store Connect/TestFlight for the new build
   - **Production**: Verify GitHub Release was created with proper tag

### Release Examples

**Internal Release (Auto-deployed)**:
- Simply push to `develop` branch
- Build automatically triggers
- Available on Internal track within 30 minutes

**Alpha Release**:
```
1. Go to Actions → Release Build and Deploy → Run workflow
2. Branch: develop
3. Flavor: alpha
4. Platform: both
5. Version Bump: none
6. Click "Run workflow"
```

**Beta Release**:
```
1. Go to Actions → Release Build and Deploy → Run workflow
2. Branch: main
3. Flavor: beta
4. Platform: both
5. Version Bump: none
6. Click "Run workflow"
```

**Production Release**:
```
1. Ensure all changes are merged to main
2. Go to Actions → Release Build and Deploy → Run workflow
3. Branch: main
4. Flavor: production
5. Platform: both
6. Version Bump: patch (or minor/major as needed)
7. Click "Run workflow"
8. After successful build, manually submit to stores
```

## Automatic Deployment

### Develop Branch → Internal Track

Every push to the `develop` branch automatically:
1. Increments the internal build number
2. Builds and signs the app
3. Uploads to Google Play Internal track
4. Uploads to TestFlight Internal testing
5. Notifies the team via Slack (if configured)

This enables continuous delivery for development builds.

## Pre-Deployment Checklist

Before triggering a production release:

- [ ] All critical bugs are fixed
- [ ] All tests are passing
- [ ] Code has been reviewed and approved
- [ ] Changes have been tested on both iOS and Android
- [ ] Release notes have been prepared
- [ ] Marketing/product team has been notified
- [ ] App Store/Play Store metadata is up to date
- [ ] Screenshots are current (if needed)
- [ ] Privacy policy is up to date (if needed)
- [ ] Version number bump is appropriate (major/minor/patch)

## Post-Deployment

### After Internal/Alpha Deployment

1. Monitor crash reports in Sentry
2. Gather feedback from testers
3. Track key metrics
4. Fix critical issues before promoting to next track

### After Beta Deployment

1. Monitor crash rates and user feedback
2. Verify all features work as expected
3. Conduct final QA testing
4. Prepare for production release

### After Production Deployment

1. **Monitor the Release**:
   - Check crash rates in Sentry
   - Monitor analytics for unusual patterns
   - Track app store reviews
   - Monitor performance metrics

2. **Gradual Rollout** (Google Play):
   - Start with 10% rollout
   - Monitor for 24 hours
   - Increase to 50% if stable
   - Complete rollout to 100%

3. **Communication**:
   - Announce release to users (if major release)
   - Update documentation
   - Notify support team of changes

4. **Track Performance**:
   - Monitor crash-free rate (target: >99%)
   - Check ANR (Application Not Responding) rate
   - Verify feature adoption
   - Track user retention

### Emergency Response

If critical issues are discovered:
1. Immediately halt store rollout
2. Follow the [Rollback Guide](ROLLBACK.md)
3. Communicate status to stakeholders
4. Prepare hotfix following the hotfix procedure

## Store Submission Notes

### Google Play Console

- Builds are automatically uploaded to the appropriate track
- You may need to manually submit to production
- Ensure release notes are filled in
- Set rollout percentage (start with 10-20% for production)

### App Store Connect

- Builds are automatically uploaded to TestFlight
- Production requires manual submission for App Store review
- Fill in "What's New" section
- Submit for review through App Store Connect
- Typical review time: 1-2 days

## Environment Variables

Each flavor uses different environment configurations from `.env.[flavor]` files:

- **API_BASE_URL**: Backend API endpoint
- **SENTRY_DSN**: Sentry project DSN for error tracking
- **GITHUB_TOKEN**: For feedback system integration
- **ENABLED_FEATURES**: Feature flags for the build

Ensure these are properly configured before deployment.

## Troubleshooting

### Build Fails on Android

- Check keystore configuration
- Verify `key.properties` secrets are set correctly
- Check Gradle build errors in the logs

### Build Fails on iOS

- Verify provisioning profiles are valid
- Check certificate expiration
- Ensure Bundle ID matches provisioning profile
- Check CocoaPods installation

### Upload to Store Fails

- Verify API keys are valid and not expired
- Check that build number is higher than previous
- Ensure track/group exists in store console
- Check service account permissions (Android)

## Support

For issues with the CI/CD pipeline:
1. Check the workflow logs in GitHub Actions
2. Review the [CI/CD Setup Guide](CI-CD-SETUP.md)
3. Consult the team in #engineering Slack channel
4. Open an issue in the repository

---

**Last Updated**: 2025-11-05
