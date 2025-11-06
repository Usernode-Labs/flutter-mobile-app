# CI/CD Pipeline - Quick Start

This document provides a quick overview of the CI/CD pipeline that has been implemented for the Usernode mobile application.

## 🎉 What's Been Implemented

A complete CI/CD pipeline for building and deploying your Flutter app to both iOS and Android across four release tracks: Internal, Alpha, Beta, and Production.

## 📋 Quick Summary

### Version Format
- **Internal/Alpha/Beta**: `1.0.0.123-internal` (includes build number)
- **Production**: `1.0.0` (clean semantic version)

### Bundle ID
- **All Flavors**: `org.usernode.app` (single bundle ID across all environments)

### Branch Strategy
- **`main`**: Production releases, reflects latest production version
- **`develop`**: Development work, auto-deploys to internal track
- **Tags**: Created automatically for production releases (e.g., `v1.0.0`)

### Release Tracks
- **Internal**: Auto-deployed from `develop` branch
- **Alpha**: Manual workflow dispatch
- **Beta**: Manual workflow dispatch
- **Production**: Manual workflow dispatch with version bump options

## 📁 Files Created

### Configuration Files
- ✅ `version.json` - Version and build number tracking
- ✅ `.env.internal`, `.env.alpha`, `.env.beta`, `.env.production` - Environment configs
- ✅ `android/app/build.gradle` - Updated with build flavors
- ✅ `ios/ExportOptions-*.plist` - iOS export configurations (4 files)
- ✅ `fastlane/Fastfile` - Fastlane automation
- ✅ `fastlane/Appfile` - Fastlane app configuration

### Scripts
- ✅ `scripts/version_manager.sh` - Version and build number management
- ✅ `scripts/generate_release_notes.sh` - Automated release notes generation

### GitHub Actions Workflows
- ✅ `.github/workflows/release.yml` - Manual release workflow
- ✅ `.github/workflows/auto-deploy-develop.yml` - Auto-deploy from develop
- ✅ `.github/workflows/pr-checks.yml` - Pull request validation
- ✅ `.github/workflows/test.yml` - Automated testing

### Documentation
- ✅ `DEPLOYMENT.md` - Complete deployment guide
- ✅ `ROLLBACK.md` - Rollback and hotfix procedures
- ✅ `CI-CD-SETUP.md` - Initial CI/CD setup instructions
- ✅ `VERSION-MANAGEMENT.md` - Version management guide
- ✅ `README-CICD.md` - This file

## 🚀 Next Steps

### 1. Configure GitHub Secrets (Required)

Before the CI/CD pipeline can work, you need to set up GitHub Secrets. See `CI-CD-SETUP.md` for detailed instructions.

**Required Secrets**:
- `ANDROID_KEYSTORE_BASE64`
- `KEYSTORE_PASSWORD`
- `KEY_ALIAS`
- `KEY_PASSWORD`
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`
- `CERTIFICATES_P12`
- `CERTIFICATES_PASSWORD`
- `PROVISIONING_PROFILES`
- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY`
- `APPLE_ID`

**Optional Secrets**:
- `FIREBASE_APP_DISTRIBUTION_TOKEN`
- `FIREBASE_APP_ID_ANDROID`
- `FIREBASE_APP_ID_IOS`
- `SLACK_WEBHOOK_URL`

### 2. Update Environment Variables

Edit the `.env.*` files with your actual API endpoints and configuration:

```bash
# .env.production
API_BASE_URL=https://api.usernode.app  # Update with your actual API
SENTRY_DSN=https://your-sentry-dsn...   # Add your Sentry DSN
GITHUB_TOKEN=ghp_...                     # For feedback system
```

### 3. Configure iOS Schemes in Xcode

You need to create 4 schemes in Xcode:

1. Open `ios/Runner.xcworkspace` in Xcode
2. Product → Scheme → Manage Schemes
3. Create schemes: Internal, Alpha, Beta, Production
4. Configure signing for each scheme

See `CI-CD-SETUP.md` section "iOS Setup" for details.

### 4. Set Up Google Play Console

1. Create a service account
2. Generate JSON key
3. Link to Play Console
4. Create release tracks (Internal, Alpha, Beta, Production)

See `CI-CD-SETUP.md` section "Android Setup" for details.

### 5. Set Up App Store Connect

1. Create the app in App Store Connect
2. Generate API key
3. Set up TestFlight groups
4. Create provisioning profiles

See `CI-CD-SETUP.md` section "iOS Setup" for details.

## 🎯 How to Use

### Automatic Internal Deployment

Simply push to the `develop` branch:

```bash
git checkout develop
git add .
git commit -m "feat: new feature"
git push origin develop
```

The CI/CD pipeline will:
1. Auto-increment internal build number
2. Build Android and iOS
3. Upload to Google Play Internal track
4. Upload to TestFlight internal testing
5. Send team notification

### Manual Release (Alpha/Beta/Production)

1. Go to GitHub repository → Actions
2. Select "Release Build and Deploy"
3. Click "Run workflow"
4. Choose:
   - **Branch**: `develop` (for internal/alpha) or `main` (for beta/production)
   - **Flavor**: internal, alpha, beta, or production
   - **Platform**: both, android, or ios
   - **Version Bump**: none, patch, minor, or major (production only)
5. Click "Run workflow"

### Check Version Information

```bash
# View current version info
./scripts/version_manager.sh info

# Get specific flavor version
./scripts/version_manager.sh get production

# Get build number
./scripts/version_manager.sh get-build internal
```

## 📊 Workflows

### Release Workflow (Manual)
**Trigger**: Manual dispatch
**What it does**:
- Builds signed app for selected platform(s)
- Uploads to appropriate store track
- Generates release notes
- Creates GitHub release (production only)
- Creates git tag (production only)
- Sends notifications

### Auto-Deploy Develop (Automatic)
**Trigger**: Push to `develop` branch
**What it does**:
- Builds internal flavor
- Uploads to Google Play Internal & TestFlight
- Sends notifications

### PR Checks (Automatic)
**Trigger**: Pull requests to `main` or `develop`
**What it does**:
- Runs tests and code analysis
- Builds debug versions
- Ensures code quality

### Test Suite (Automatic)
**Trigger**: Push to `main` or `develop`, daily schedule
**What it does**:
- Runs unit tests
- Runs widget tests
- Runs integration tests
- Generates coverage reports

## 🔧 Common Tasks

### Release a Hotfix

```bash
# Create hotfix branch from production tag
git checkout -b hotfix/1.0.1 v1.0.0

# Make fixes
git commit -m "fix: critical bug"

# Bump version
./scripts/version_manager.sh bump patch

# Push and release via GitHub Actions
git push origin hotfix/1.0.1
# Then use Release workflow
```

### Rollback a Release

See `ROLLBACK.md` for complete procedures.

**Quick steps**:
1. For Android: Promote previous version in Play Console
2. For iOS: Build and submit previous version with higher build number

## 📚 Documentation

- **`DEPLOYMENT.md`**: Complete deployment procedures and workflows
- **`ROLLBACK.md`**: Emergency rollback and hotfix procedures
- **`CI-CD-SETUP.md`**: Detailed setup instructions for CI/CD
- **`VERSION-MANAGEMENT.md`**: Version numbering and management guide

## ✅ Features

- ✅ Single bundle ID across all environments (`org.usernode.app`)
- ✅ Version format: `1.0.0.XXX-flavor` (production: `1.0.0`)
- ✅ Auto-incrementing build numbers
- ✅ Automated release notes from Git commits
- ✅ Signed Android builds → Google Play Console
- ✅ iOS builds → TestFlight & App Store Connect
- ✅ GitHub releases with artifacts and tags
- ✅ Team notifications via Slack
- ✅ Rollback procedures documented and tested
- ✅ Branch strategy: `main` = production, `develop` = development
- ✅ Automated testing and code quality checks

## 🐛 Troubleshooting

### Build Fails
1. Check GitHub Actions logs
2. Verify all secrets are configured
3. Check `CI-CD-SETUP.md` for setup steps
4. Ensure environment variables are correct

### Upload to Store Fails
1. Verify API keys are valid
2. Check build number is incrementing
3. Ensure bundle ID matches store configuration
4. Check service account permissions

For more help, see the troubleshooting sections in each documentation file.

## 📞 Support

For issues or questions:
1. Check the documentation files listed above
2. Review GitHub Actions workflow logs
3. Consult with the engineering team
4. Open an issue in the repository

## 🎓 Learning Resources

- [Semantic Versioning](https://semver.org/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Fastlane Documentation](https://docs.fastlane.tools/)
- [Flutter Deployment](https://docs.flutter.dev/deployment)

---

**Status**: ✅ Implementation Complete
**Last Updated**: 2025-11-05
**Next Steps**: Configure secrets and test the pipeline

**Happy Deploying! 🚀**
