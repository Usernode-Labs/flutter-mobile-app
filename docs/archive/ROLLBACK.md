# Rollback and Hotfix Guide

This document provides procedures for rolling back problematic releases and deploying emergency hotfixes.

## Table of Contents

- [When to Rollback](#when-to-rollback)
- [Rollback Procedures](#rollback-procedures)
- [Hotfix Procedures](#hotfix-procedures)
- [Emergency Contacts](#emergency-contacts)
- [Post-Incident](#post-incident)

## When to Rollback

Consider rolling back a release when:

- **Critical Bug**: App crashes on launch for a significant portion of users
- **Data Loss**: Users are experiencing data corruption or loss
- **Security Issue**: A security vulnerability has been discovered
- **High Crash Rate**: Crash-free rate drops below 95%
- **Business Critical**: A core feature is completely broken
- **User Impact**: Significant negative user feedback or app store reviews

**Do NOT rollback for**:
- Minor bugs that don't impact core functionality
- Low-frequency crashes affecting <1% of users
- UI/UX issues that are annoying but not blocking
- Issues that can be fixed with a quick hotfix

## Rollback Procedures

### Assessment Phase (15 minutes)

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

### Android Rollback (Google Play Console)

#### Option 1: Promote Previous Version (Recommended)

1. **Log in to Google Play Console**:
   - Navigate to https://play.google.com/console
   - Select the Usernode app

2. **Go to Release Management**:
   - Click "Production" (or affected track)
   - Find the previous stable version

3. **Promote Previous Version**:
   - Click on the last known good release
   - Select "Promote to Production"
   - Set rollout to 100%
   - Add release notes explaining the rollback

4. **Halt Current Release**:
   - Go to the problematic release
   - Click "Halt rollout"
   - Confirm the action

5. **Monitor**:
   - Watch crash rates return to normal
   - Typical propagation time: 2-4 hours

#### Option 2: Manual Rollback via CI/CD

```bash
# Find the last stable tag
git tag -l "v*" | sort -V | tail -5

# Trigger release workflow with that version
# Go to GitHub Actions → Release Build and Deploy
# Select the stable git tag/commit
# Deploy to production track
```

### iOS Rollback (App Store)

**Important**: Apple does not allow direct rollbacks. You must submit a new build.

#### Quick Rollback Process

1. **Identify Last Stable Version**:
   ```bash
   git tag -l "v*" | sort -V | tail -5
   ```

2. **Checkout Stable Version**:
   ```bash
   git checkout tags/v1.0.0  # Replace with stable version
   ```

3. **Increment Build Number**:
   - Update `version.json` to have a higher build number than current
   - Keep the same version number

4. **Build and Submit**:
   ```bash
   # Trigger release workflow from the stable tag
   # or manually build:
   ./scripts/version_manager.sh increment production
   # Then run the release workflow
   ```

5. **Submit for Expedited Review**:
   - Go to App Store Connect
   - Submit the build
   - Request expedited review (explain it's a critical fix)
   - Typical expedited review: 1-2 hours

6. **Communicate**:
   - Update app description to mention the rollback
   - Notify users via support channels

### TestFlight/Internal Rollback

For internal, alpha, or beta tracks:

**Android**:
- Simply upload the previous stable build to the track
- Users will receive the update automatically

**iOS**:
- Upload previous stable build to TestFlight
- Change which build is available to testers
- Notify testers via TestFlight release notes

## Hotfix Procedures

Use hotfixes when:
- Issue can be fixed quickly (< 4 hours)
- Fix is well-understood and low-risk
- Rolling back would cause more problems than fixing

### Hotfix Workflow

#### 1. Create Hotfix Branch

```bash
# Ensure you're on the latest production tag
git fetch --tags
git checkout tags/v1.0.0  # Replace with current production version

# Create hotfix branch
git checkout -b hotfix/1.0.1

# Make your fixes
# ... edit files ...

# Test thoroughly
flutter test
flutter build apk --release
flutter build ios --release
```

#### 2. Update Version

```bash
# Bump patch version
./scripts/version_manager.sh bump patch

# Commit version bump
git add version.json
git commit -m "chore: bump version to 1.0.1"
```

#### 3. Test the Hotfix

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

#### 4. Deploy Hotfix

**Using GitHub Actions**:
1. Push hotfix branch to GitHub
2. Go to Actions → Release Build and Deploy
3. Run workflow:
   - Branch: `hotfix/1.0.1`
   - Flavor: `production`
   - Platform: `both`
   - Version Bump: `none` (already bumped)

**Manual Deploy**:
```bash
# Android
fastlane android production

# iOS
fastlane ios production
```

#### 5. Merge Hotfix Back

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
- [ ] Monitoring confirms issue is resolved
- [ ] Hotfix merged back to main and develop
- [ ] Post-mortem scheduled

## Emergency Contacts

### Escalation Path

1. **Engineering Lead**: [Name/Slack]
2. **CTO**: [Name/Slack]
3. **On-Call Engineer**: [PagerDuty/Phone]

### Service Accounts

- **Google Play Console**: engineering@usernode.com
- **Apple Developer**: developer@usernode.com
- **Sentry**: engineering@usernode.com

### Store Support

- **Google Play Support**: https://support.google.com/googleplay/android-developer
- **Apple Developer Support**: https://developer.apple.com/contact/

## Testing Rollback Procedures

### Monthly Rollback Drill

Perform a test rollback on the beta track monthly:

1. Deploy a beta build
2. Immediately "rollback" to previous version
3. Verify the process works smoothly
4. Document any issues or improvements needed
5. Update this guide if needed

### Checklist

- [ ] Google Play rollback tested in last 30 days
- [ ] TestFlight rollback tested in last 30 days
- [ ] All team members know rollback procedure
- [ ] Emergency contact list is up to date
- [ ] Monitoring alerts are properly configured

## Post-Incident

After any rollback or hotfix:

### Immediate (Within 1 hour)

1. **Verify Resolution**:
   - Check Sentry crash rates
   - Monitor app analytics
   - Review user feedback
   - Confirm store metrics are improving

2. **Communicate**:
   - Notify all stakeholders
   - Update status page if applicable
   - Respond to user inquiries

### Short-term (Within 24 hours)

1. **User Communication**:
   - Update app store description if needed
   - Send push notification if appropriate
   - Update support documentation

2. **Internal Review**:
   - What went wrong?
   - Why didn't we catch it earlier?
   - What were the warning signs?

### Long-term (Within 1 week)

1. **Post-Mortem**:
   - Schedule blameless post-mortem meeting
   - Document timeline of events
   - Identify root causes
   - Create action items to prevent recurrence

2. **Process Improvements**:
   - Update testing procedures
   - Enhance monitoring/alerting
   - Improve rollout strategy
   - Update this documentation

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
[Detailed explanation of what caused the issue]

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

## Rollback Metrics

Track these metrics for each rollback:

- **Detection Time**: How long until we noticed the issue?
- **Decision Time**: How long to decide to rollback?
- **Execution Time**: How long did the rollback take?
- **Recovery Time**: Total time from detection to resolution
- **User Impact**: How many users were affected?
- **Data Loss**: Any data lost or corrupted?

**Target Metrics**:
- Detection: < 15 minutes
- Decision: < 15 minutes
- Execution: < 30 minutes
- Total Recovery: < 1 hour

## Prevention

To minimize the need for rollbacks:

1. **Gradual Rollouts**:
   - Start at 10% for production
   - Monitor for 24 hours
   - Increase gradually

2. **Better Testing**:
   - Comprehensive test coverage
   - Beta testing period (minimum 1 week)
   - Dogfooding (use internal builds)

3. **Monitoring**:
   - Set up alerts for crash rate spikes
   - Monitor key metrics in real-time
   - Track user feedback closely

4. **Feature Flags**:
   - Use feature flags for risky features
   - Ability to disable features remotely
   - Gradual feature rollouts

---

**Last Updated**: 2025-11-05

**Note**: This is a living document. Update it after each incident to reflect learnings and improve processes.
