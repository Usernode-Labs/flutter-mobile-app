# CI/CD Setup Guide

This guide will help you set up the complete CI/CD pipeline for the Usernode mobile application.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Initial Setup](#initial-setup)
- [GitHub Secrets Configuration](#github-secrets-configuration)
- [Android Setup](#android-setup)
- [iOS Setup](#ios-setup)
- [Store Configuration](#store-configuration)
- [Testing the Pipeline](#testing-the-pipeline)
- [Troubleshooting](#troubleshooting)

## Prerequisites

Before starting, ensure you have:

- [ ] GitHub repository with admin access
- [ ] Google Play Developer account
- [ ] Apple Developer account (with Admin role)
- [ ] Access to Google Play Console
- [ ] Access to App Store Connect
- [ ] Signing keys and certificates
- [ ] (Optional) Slack workspace for notifications
- [ ] (Optional) Firebase project for App Distribution

## Initial Setup

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

### 3. Verify Configuration Files

Ensure these files exist:
- `version.json` - Version tracking
- `.env.internal`, `.env.alpha`, `.env.beta`, `.env.production` - Environment configs
- `android/app/build.gradle` - Android build configuration with flavors
- `ios/ExportOptions-*.plist` - iOS export options
- `fastlane/Fastfile` - Fastlane configuration
- `.github/workflows/*.yml` - GitHub Actions workflows

## GitHub Secrets Configuration

Navigate to your GitHub repository → Settings → Secrets and variables → Actions.

### Required Secrets

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
   Paste the output as the secret value.

2. **KEYSTORE_PASSWORD**
   - The password you used when creating the keystore

3. **KEY_ALIAS**
   - The alias you used (e.g., `usernode-key`)

4. **KEY_PASSWORD**
   - The key password (often same as keystore password)

5. **GOOGLE_PLAY_SERVICE_ACCOUNT_JSON**
   - See [Google Play Setup](#google-play-console-setup) section

#### iOS Secrets

1. **CERTIFICATES_P12**
   ```bash
   # Export certificate from Keychain
   # 1. Open Keychain Access
   # 2. Find your distribution certificate
   # 3. Right-click → Export
   # 4. Save as .p12 file

   # Convert to base64
   base64 -i certificate.p12 | pbcopy  # macOS
   ```

2. **CERTIFICATES_PASSWORD**
   - Password used when exporting the certificate

3. **PROVISIONING_PROFILES**
   ```bash
   # Download from Apple Developer Portal
   # Convert to base64
   base64 -i UserNodeApp.mobileprovision | pbcopy
   ```

4. **APP_STORE_CONNECT_API_KEY_ID**
   - From App Store Connect → Users and Access → Keys

5. **APP_STORE_CONNECT_ISSUER_ID**
   - Found on the same page as API Key ID

6. **APP_STORE_CONNECT_API_KEY**
   ```bash
   # Download the .p8 file from App Store Connect
   # Convert to base64
   base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy
   ```

7. **APPLE_ID**
   - Your Apple Developer account email

#### Optional Secrets

1. **FIREBASE_APP_DISTRIBUTION_TOKEN**
   ```bash
   # Install Firebase CLI
   npm install -g firebase-tools

   # Login and get token
   firebase login:ci
   ```

2. **FIREBASE_APP_ID_ANDROID**
   - From Firebase Console → Project Settings → Your Apps

3. **FIREBASE_APP_ID_IOS**
   - From Firebase Console → Project Settings → Your Apps

4. **SLACK_WEBHOOK_URL**
   - Create incoming webhook in Slack
   - https://api.slack.com/messaging/webhooks

## Android Setup

### 1. Google Play Console Setup

1. **Create Service Account**:
   - Go to Google Cloud Console
   - Create a new project or select existing
   - Enable Google Play Android Developer API
   - Create Service Account:
     - Go to IAM & Admin → Service Accounts
     - Click "Create Service Account"
     - Name: `github-actions-deploy`
     - Click "Create and Continue"
   - Grant roles:
     - Service Account User
   - Click "Done"

2. **Generate JSON Key**:
   - Click on the service account
   - Go to "Keys" tab
   - "Add Key" → "Create new key"
   - Choose JSON format
   - Save the file securely

3. **Link to Play Console**:
   - Go to Google Play Console
   - Select your app
   - Setup → API access
   - Link the service account
   - Grant permissions:
     - Releases: View, Create and edit releases
     - Release to production, exclude devices, and use Play App Signing

4. **Add as GitHub Secret**:
   ```bash
   # Copy the entire JSON file content
   cat service-account-key.json | pbcopy
   ```
   - Add as `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` secret

### 2. Configure Android Signing

The keystore configuration is already set up in `android/app/build.gradle`.

Verify the configuration:
```gradle
signingConfigs {
    release {
        if (keystorePropertiesFile.exists()) {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
}
```

### 3. Update Bundle ID

The bundle ID is set to `org.usernode.app`. If you need to change it:
- Update in `android/app/build.gradle`
- Update in Google Play Console
- Update in `fastlane/Appfile`

## iOS Setup

### 1. App Store Connect Setup

1. **Create App**:
   - Go to App Store Connect
   - My Apps → "+" → New App
   - Platform: iOS
   - Name: Usernode
   - Bundle ID: org.usernode.app
   - SKU: usernode-app
   - User Access: Full Access

2. **Create API Key**:
   - App Store Connect → Users and Access
   - Keys tab (under Integrations)
   - "+" to create new key
   - Name: GitHub Actions
   - Access: App Manager or Admin
   - Download the .p8 file (only available once!)
   - Note the Key ID and Issuer ID

3. **Set Up TestFlight**:
   - App Store Connect → TestFlight
   - Create Internal Testing group
   - Add testers
   - Configure beta app information

### 2. Create Provisioning Profiles

You need provisioning profiles for each environment:

1. **Go to Apple Developer Portal**:
   - Certificates, Identifiers & Profiles

2. **Create App IDs** (if not exists):
   - Identifier: `org.usernode.app`
   - Description: Usernode App
   - Enable required capabilities (e.g., Push Notifications, NFC)

3. **Create Certificates**:
   - iOS Distribution certificate
   - Download and install in Keychain

4. **Create Provisioning Profiles**:
   - Type: App Store
   - App ID: org.usernode.app
   - Certificate: Your distribution certificate
   - Name:
     - `Usernode Internal`
     - `Usernode Alpha`
     - `Usernode Beta`
     - `Usernode Production`
   - Download all profiles

5. **Configure in Xcode**:
   - Open `ios/Runner.xcworkspace`
   - Create 4 schemes: Internal, Alpha, Beta, Production
   - For each scheme:
     - Edit Scheme → Build Configuration
     - Archive → Release
     - Signing & Capabilities:
       - Team: Usernode Labs
       - Provisioning Profile: [Corresponding profile]

### 3. Update iOS Configuration

Verify `ios/ExportOptions-*.plist` files have correct provisioning profile names:
```xml
<key>provisioningProfiles</key>
<dict>
    <key>org.usernode.app</key>
    <string>Usernode Production</string>  <!-- Must match exactly -->
</dict>
```

## Store Configuration

### Google Play Console

1. **Create Release Tracks**:
   - Testing → Internal testing → Create new release
   - Testing → Closed testing → Create new track "Alpha"
   - Testing → Closed testing → Create new track "Beta"
   - Production → Create new release

2. **Add Testers**:
   - Internal testing: Add email list
   - Alpha/Beta: Create email lists or use Google Groups

3. **Configure App Content**:
   - Privacy Policy URL
   - Data safety section
   - Content rating
   - Target audience

### App Store Connect

1. **Configure App Information**:
   - App Information → General Information
   - Privacy Policy URL
   - Category
   - Content Rights

2. **Set Up TestFlight**:
   - TestFlight → Internal Testing
   - TestFlight → External Testing (Beta)
   - Configure beta app information
   - Add What to Test notes

3. **Prepare for Production**:
   - App Store → Prepare for Submission
   - Add screenshots
   - Description
   - Keywords
   - Support URL

## Testing the Pipeline

### 1. Test Version Management

```bash
# Test version manager script
./scripts/version_manager.sh info

# Test increment
./scripts/version_manager.sh increment internal

# Test version retrieval
./scripts/version_manager.sh get internal

# Reset if needed (edit version.json manually)
```

### 2. Test Release Notes Generation

```bash
# Create some test commits
git commit --allow-empty -m "feat: test feature"
git commit --allow-empty -m "fix: test fix"

# Generate release notes
./scripts/generate_release_notes.sh generate
```

### 3. Test GitHub Actions Workflows

**Test PR Checks**:
1. Create a feature branch
2. Make a small change
3. Open a PR to `develop`
4. Verify workflow runs and completes

**Test Auto-Deploy (Internal)**:
1. Push a commit to `develop` branch
2. Monitor GitHub Actions
3. Verify build completes
4. Check Google Play Console Internal track
5. Check TestFlight for new build

**Test Manual Release**:
1. Go to Actions → Release Build and Deploy
2. Run workflow with:
   - Branch: `develop`
   - Flavor: `internal`
   - Platform: `android` (for testing)
3. Monitor the build
4. Verify successful upload

### 4. Verify Notifications

If Slack is configured:
1. Trigger a build
2. Check for notification in Slack channel
3. Verify message format and content

## Environment Variables

Update `.env.*` files with your actual values:

```bash
# .env.production
APP_ENV=production
API_BASE_URL=https://api.usernode.app
VERBOSE_LOGGING=false
SENTRY_DSN=https://your-sentry-dsn@sentry.io/project-id
GITHUB_TOKEN=ghp_your_github_token
USE_RESULT_PROVIDERS=true
ENABLED_FEATURES=home,wallet,dapps,profile,node,feedback
DISABLED_FEATURES=
```

Repeat for all environment files.

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

### Fastlane Issues

**Problem**: "Could not find certificate"
- **Solution**:
  - Verify certificate is installed in Keychain
  - Check certificate is not expired
  - Ensure it's a Distribution certificate

**Problem**: Upload to TestFlight fails
- **Solution**:
  - Verify App Store Connect API key is valid
  - Check app exists in App Store Connect
  - Ensure bundle ID matches

### Store Upload Issues

**Problem**: "Version code must be higher than previous"
- **Solution**: Increment build number manually in `version.json`

**Problem**: "Package name mismatch"
- **Solution**: Verify bundle ID/package name in:
  - `android/app/build.gradle`
  - `ios/Runner.xcodeproj`
  - Google Play Console
  - App Store Connect

## Next Steps

After setup is complete:

1. **Test the Full Pipeline**:
   - [ ] Internal build deploys automatically from `develop`
   - [ ] Manual release workflow works
   - [ ] Notifications are received
   - [ ] Apps appear in respective stores

2. **Configure Monitoring**:
   - [ ] Set up Sentry error tracking
   - [ ] Configure analytics
   - [ ] Set up crash reporting alerts

3. **Team Training**:
   - [ ] Share deployment guide with team
   - [ ] Practice rollback procedure
   - [ ] Document any project-specific quirks

4. **Create Release Checklist**:
   - [ ] Customize for your team's needs
   - [ ] Add approval requirements
   - [ ] Define release cadence

## Support

If you encounter issues:

1. Check workflow logs in GitHub Actions
2. Review this guide for missed steps
3. Consult team documentation
4. Open an issue in the repository

## Maintenance

### Regular Tasks

**Monthly**:
- [ ] Verify all certificates are valid (check expiration dates)
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

**Last Updated**: 2025-11-05

**Maintainers**: Engineering Team

For questions or updates to this guide, please open an issue or PR.
