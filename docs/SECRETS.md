# GitHub Secrets Configuration Guide

This document explains how to configure GitHub Secrets for CI/CD workflows. The project uses a **branch-based environment strategy** where secrets are selected based on the target branch.

## Table of Contents

- [Overview](#overview)
- [Branch-Based Environment Strategy](#branch-based-environment-strategy)
- [Required Secrets](#required-secrets)
- [Setting Up Secrets](#setting-up-secrets)
- [Secret Values Reference](#secret-values-reference)
- [Local Development](#local-development)
- [Troubleshooting](#troubleshooting)

---

## Overview

This project uses **GitHub Secrets** instead of committing `.env` files to the repository for improved security. Secrets are dynamically loaded into workflows based on the branch being built.

### Why GitHub Secrets?

✅ **More Secure** - Sensitive values never stored in repository
✅ **Centralized Management** - All environments managed from GitHub Settings
✅ **No Accidental Commits** - No risk of committing API keys or tokens
✅ **Per-Environment Control** - Separate configurations for production and non-production

---

## Branch-Based Environment Strategy

The CI/CD workflows automatically select the appropriate secrets based on the branch:

| Branch | Secrets Used | Track | Purpose |
|--------|--------------|-------|---------|
| `develop` | `NONPROD_*` | internal → alpha → beta | Testing and staging builds |
| `main` | `PROD_*` | production | Production releases |

### Workflow Behavior

**When you push to `develop`:**
1. Build workflow runs with `NONPROD_*` secrets
2. Creates build with non-production configuration
3. Deploys to internal track
4. Can be manually promoted to alpha → beta

**When you push to `main`:**
1. Build workflow runs with `PROD_*` secrets
2. Creates build with production configuration
3. Deploys directly to production track
4. Creates GitHub release

**When you create a PR:**
- PR to `develop` → Uses `NONPROD_*` secrets for validation
- PR to `main` → Uses `PROD_*` secrets for validation

---

## Required Secrets

You need to configure **two sets of secrets**: one for production (`PROD_*`) and one for non-production (`NONPROD_*`).

### Environment Configuration Secrets

These secrets configure the application's runtime behavior:

#### Production Secrets (PROD_*)

| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `PROD_APP_ENV` | Environment name | `production` |
| `PROD_API_BASE_URL` | Production API endpoint | `https://api.usernode.app` |
| `PROD_VERBOSE_LOGGING` | Enable verbose logging | `false` |
| `PROD_SENTRY_DSN` | Sentry error tracking DSN | `https://xxx@sentry.io/xxx` |
| `PROD_GITHUB_TOKEN` | GitHub PAT for feedback | `ghp_xxxxxxxxxxxx` |
| `PROD_USE_RESULT_PROVIDERS` | Use Result providers | `true` |
| `PROD_ENABLED_FEATURES` | Enabled features list | `home,wallet,dapps,profile,node` |
| `PROD_DISABLED_FEATURES` | Disabled features list | `` (empty) |

#### Non-Production Secrets (NONPROD_*)

| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `NONPROD_APP_ENV` | Environment name | `staging` or `development` |
| `NONPROD_API_BASE_URL` | Staging API endpoint | `https://api-staging.usernode.app` |
| `NONPROD_VERBOSE_LOGGING` | Enable verbose logging | `true` |
| `NONPROD_SENTRY_DSN` | Sentry staging DSN | `https://yyy@sentry.io/yyy` |
| `NONPROD_GITHUB_TOKEN` | GitHub PAT for feedback | `ghp_yyyyyyyyyyyy` |
| `NONPROD_USE_RESULT_PROVIDERS` | Use Result providers | `true` |
| `NONPROD_ENABLED_FEATURES` | Enabled features list | `home,wallet,dapps,profile,node` |
| `NONPROD_DISABLED_FEATURES` | Disabled features list | `` (empty) |

### Build & Signing Secrets

These secrets are required for building and signing the applications (not environment-specific):

#### Android Signing

| Secret Name | Description | How to Get |
|-------------|-------------|------------|
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded keystore file | `base64 -i keystore.jks` |
| `KEYSTORE_PASSWORD` | Keystore password | From your keystore creation |
| `KEY_PASSWORD` | Key password | From your keystore creation |
| `KEY_ALIAS` | Key alias | From your keystore creation |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | Google Play service account JSON | From Google Play Console |

#### iOS Signing

| Secret Name | Description | How to Get |
|-------------|-------------|------------|
| `CERTIFICATES_P12` | Base64-encoded P12 certificate | `base64 -i certificate.p12` |
| `CERTIFICATES_PASSWORD` | P12 certificate password | From certificate export |
| `PROVISIONING_PROFILES` | Base64-encoded provisioning profile | `base64 -i profile.mobileprovision` |
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect API Key ID | From App Store Connect |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect Issuer ID | From App Store Connect |
| `APP_STORE_CONNECT_API_KEY` | Base64-encoded API Key | `base64 -i AuthKey_XXX.p8` |

#### Optional Notifications

| Secret Name | Description | Required? |
|-------------|-------------|-----------|
| `SLACK_WEBHOOK_URL` | Slack webhook for notifications | No (workflow checks if empty) |

---

## Setting Up Secrets

### Step 1: Navigate to Repository Settings

1. Go to your GitHub repository
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**

### Step 2: Add Environment Configuration Secrets

For **Production** (`PROD_*` secrets):

```bash
# Example values - replace with your actual values
PROD_APP_ENV=production
PROD_API_BASE_URL=https://api.usernode.app
PROD_VERBOSE_LOGGING=false
PROD_SENTRY_DSN=https://your-sentry-dsn@sentry.io/project
PROD_GITHUB_TOKEN=ghp_your_github_personal_access_token
PROD_USE_RESULT_PROVIDERS=true
PROD_ENABLED_FEATURES=home,wallet,dapps,profile,node
PROD_DISABLED_FEATURES=
```

For **Non-Production** (`NONPROD_*` secrets):

```bash
# Example values - replace with your actual staging values
NONPROD_APP_ENV=staging
NONPROD_API_BASE_URL=https://api-staging.usernode.app
NONPROD_VERBOSE_LOGGING=true
NONPROD_SENTRY_DSN=https://your-staging-sentry-dsn@sentry.io/project
NONPROD_GITHUB_TOKEN=ghp_your_staging_github_token
NONPROD_USE_RESULT_PROVIDERS=true
NONPROD_ENABLED_FEATURES=home,wallet,dapps,profile,node
NONPROD_DISABLED_FEATURES=
```

### Step 3: Add Build & Signing Secrets

**Android Signing:**

```bash
# Generate base64 keystore
base64 -i android/app/keystore.jks | pbcopy

# Then add to GitHub Secrets:
ANDROID_KEYSTORE_BASE64=<paste the base64 output>
KEYSTORE_PASSWORD=your_keystore_password
KEY_PASSWORD=your_key_password
KEY_ALIAS=your_key_alias
```

**iOS Signing:**

```bash
# Generate base64 certificate
base64 -i certificate.p12 | pbcopy
# Add as CERTIFICATES_P12

# Generate base64 provisioning profile
base64 -i profile.mobileprovision | pbcopy
# Add as PROVISIONING_PROFILES

# Generate base64 API key
base64 -i AuthKey_XXX.p8 | pbcopy
# Add as APP_STORE_CONNECT_API_KEY
```

---

## Secret Values Reference

### APP_ENV

**Purpose:** Identifies the environment for conditional logic and logging.

**Valid Values:**
- `development` - Local development
- `staging` - Staging/testing environment
- `production` - Production environment

**Recommendation:**
- `PROD_APP_ENV=production`
- `NONPROD_APP_ENV=staging`

---

### API_BASE_URL

**Purpose:** Base URL for all API requests.

**Format:** `https://domain.com` (no trailing slash)

**Examples:**
- Production: `https://api.usernode.app`
- Staging: `https://api-staging.usernode.app`
- Local Dev: `http://localhost:8080`

**Recommendation:**
- Use production URL for `PROD_API_BASE_URL`
- Use staging URL for `NONPROD_API_BASE_URL`

---

### VERBOSE_LOGGING

**Purpose:** Enable detailed debug logging.

**Valid Values:**
- `true` - Enable verbose logging (development/staging)
- `false` - Disable verbose logging (production)

**Recommendation:**
- `PROD_VERBOSE_LOGGING=false` (reduce log noise in production)
- `NONPROD_VERBOSE_LOGGING=true` (help with debugging)

---

### SENTRY_DSN

**Purpose:** Sentry Data Source Name for error tracking.

**Format:** `https://<key>@<org>.ingest.sentry.io/<project>`

**How to Get:**
1. Go to Sentry.io
2. Create/select project
3. Go to Settings → Client Keys (DSN)
4. Copy the DSN

**Recommendation:**
- Create separate Sentry projects for production and staging
- Use different DSNs for `PROD_SENTRY_DSN` and `NONPROD_SENTRY_DSN`

**Optional:** Leave empty to disable Sentry

---

### GITHUB_TOKEN

**Purpose:** GitHub Personal Access Token for in-app feedback system (creating GitHub Issues).

**How to Create:**
1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Select scopes: `repo` (full control of private repositories)
4. Copy token

**Recommendation:**
- Use separate tokens for production and non-production
- Set appropriate expiration dates

**Optional:** Leave empty to disable GitHub feedback integration

---

### USE_RESULT_PROVIDERS

**Purpose:** Toggle between Result-based providers and AsyncNotifier providers.

**Valid Values:**
- `true` - Use Result type for better error handling
- `false` - Use standard AsyncNotifier providers

**Recommendation:**
- `true` for both production and non-production (better error handling)

---

### ENABLED_FEATURES / DISABLED_FEATURES

**Purpose:** Control which app features are enabled at runtime.

**Format:** Comma-separated list (no spaces)

**Available Features:**
- `home` - Home dashboard screen
- `wallet` - Wallet screen
- `dapps` - dApps marketplace screen
- `profile` - Profile/settings screen
- `node` - Node status screen

**Examples:**
```bash
# Enable all features
ENABLED_FEATURES=home,wallet,dapps,profile,node
DISABLED_FEATURES=

# Enable only home and wallet
ENABLED_FEATURES=home,wallet
DISABLED_FEATURES=

# Disable dapps feature
ENABLED_FEATURES=home,wallet,dapps,profile,node
DISABLED_FEATURES=dapps
```

**Recommendation:**
- Enable all features in production
- Use `DISABLED_FEATURES` to temporarily disable features without rebuilding

---

## Local Development

For local development, you **don't need GitHub Secrets**. Instead:

1. **Copy the template:**
   ```bash
   cp .env.example .env
   ```

2. **Fill in your local values:**
   ```bash
   # Edit .env with your development configuration
   vim .env
   ```

3. **Run with .env file:**
   ```bash
   flutter run --dart-define-from-file=.env
   ```

4. **Never commit .env:**
   The `.env` file is already in `.gitignore` to prevent accidental commits.

---

## Troubleshooting

### Build Fails with "Missing Secret" Error

**Problem:** Workflow fails because a required secret is not configured.

**Solution:**
1. Check the workflow logs to identify which secret is missing
2. Go to repository Settings → Secrets and variables → Actions
3. Add the missing secret
4. Re-run the workflow

---

### Wrong Environment Configuration in Build

**Problem:** Build uses wrong API URL or environment settings.

**Solution:**
1. Verify you're targeting the correct branch:
   - Pushes to `develop` should use `NONPROD_*` secrets
   - Pushes to `main` should use `PROD_*` secrets
2. Check workflow logs for "Building for PRODUCTION" or "Building for NON-PRODUCTION" message
3. Verify secrets are named correctly (exact prefix: `PROD_` or `NONPROD_`)

---

### Secrets Not Updating in Build

**Problem:** Changed a secret but workflow still uses old value.

**Solution:**
1. Secrets are cached per workflow run
2. Start a new workflow run (push a commit or manually trigger)
3. Old workflow runs will continue using old secrets

---

### Cannot See Secret Values

**Problem:** Need to verify what value is configured for a secret.

**Solution:**
1. GitHub intentionally hides secret values for security
2. You cannot view secret values after setting them
3. To verify: delete the secret and recreate it with the correct value
4. Consider keeping a secure note of secret values (e.g., 1Password, LastPass)

---

### Local Development Not Working

**Problem:** App doesn't work locally even though CI works.

**Solution:**
1. Ensure you created `.env` file: `cp .env.example .env`
2. Fill in values in `.env` (use staging/development values, not production)
3. Run with: `flutter run --dart-define-from-file=.env`
4. Check `.env` is not empty and has valid values

---

## Security Best Practices

1. **Never commit secrets to git** - Always use GitHub Secrets or local `.env` files (gitignored)
2. **Use separate secrets for production and non-production** - Limit production secret exposure
3. **Rotate secrets regularly** - Update tokens and keys periodically
4. **Use minimal permissions** - GitHub tokens should have only required scopes
5. **Monitor secret usage** - Check GitHub Actions logs for unauthorized access attempts
6. **Delete unused secrets** - Remove old or unused secrets from repository settings

---

## Related Documentation

- [CI/CD Guide](CICD-GUIDE.md) - Complete CI/CD workflow documentation
- [Build Once, Promote Many](BUILD-ONCE-PROMOTE.md) - Promotion strategy guide
- [.env.example](../.env.example) - Local development template

---

**Last Updated:** 2025-11-06
**Maintained By:** Development Team
