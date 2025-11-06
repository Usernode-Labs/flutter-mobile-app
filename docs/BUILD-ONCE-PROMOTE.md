# Build Once, Promote Many Strategy

This document explains the "build once, promote many" deployment strategy and how to use it.

## Overview

Instead of building separate binaries for each environment (internal, alpha, beta, production), we:
1. **Build once** from the `develop` branch
2. **Test** in internal track
3. **Promote** the same binary through tracks (alpha → beta → production)

This ensures the exact binary tested in lower environments is what goes to production.

## Benefits

### ✅ Consistency
- Same binary across all environments
- No "works in beta, fails in prod" surprises
- What you test is what you ship

### ✅ Speed
- No rebuild time when promoting
- Promotions take seconds, not minutes

### ✅ Reliability
- Reduced CI/CD failures (build once)
- Less room for build-time errors
- True end-to-end testing

### ✅ Cost Efficiency
- ~75% less CI/CD minutes
- One build instead of four

### ✅ Traceability
- Same version code across tracks
- Clear promotion history
- Easy rollback to known-good builds

## How It Works

### 1. Automatic Build (on push to develop)

```bash
git push origin develop
```

**What happens:**
1. Increments production build number
2. Builds single release AAB/IPA
3. Uploads to Internal track (Android) and TestFlight Internal (iOS)
4. Stores artifact in GitHub for 90 days
5. Notifies team

**Result:** Build #123 in Internal track, ready for testing

### 2. Promote to Alpha

After internal testing passes:

1. Go to GitHub Actions → "Build Once, Promote Many"
2. Click "Run workflow"
3. Select:
   - `promote_to`: **alpha**
   - `build_number`: leave empty (uses latest) or specify build number
4. Click "Run workflow"

**What happens:**
- Takes existing build from Internal
- Promotes to Alpha track
- Same binary, different track

### 3. Promote to Beta

After alpha testing passes:

1. Run workflow again
2. Select `promote_to`: **beta**

### 4. Promote to Production

After beta testing passes:

1. Run workflow again
2. Select `promote_to`: **production**

**Additional actions for production:**
- Creates git tag (e.g., `v1.2.3`)
- Creates GitHub Release
- Generates release notes

## Workflow Usage

### Scenario 1: New Build for Testing

**Trigger:** Push to `develop` branch (automatic)

```bash
git checkout develop
git pull origin develop
# Make changes
git commit -m "feat: new feature"
git push origin develop
```

**Result:** New build deployed to Internal track

### Scenario 2: Promote Latest Build

**When:** Internal testing passed, ready for wider audience

**Steps:**
1. GitHub Actions → "Build Once, Promote Many" → "Run workflow"
2. `promote_to`: Select track (alpha/beta/production)
3. `build_number`: Leave empty (promotes latest)
4. Run workflow

**Result:** Latest build promoted to selected track

### Scenario 3: Promote Specific Build

**When:** Want to promote a specific older build

**Steps:**
1. Check build number: `./scripts/version_manager.sh get-build production`
2. GitHub Actions → "Build Once, Promote Many" → "Run workflow"
3. `promote_to`: Select track
4. `build_number`: Enter specific build number (e.g., `123`)
5. Run workflow

**Result:** Specified build promoted to selected track

### Scenario 4: Production Release

**When:** Beta testing passed, ready for production

**Steps:**
1. Ensure all testing complete
2. GitHub Actions → "Build Once, Promote Many" → "Run workflow"
3. `promote_to`: **production**
4. `build_number`: Leave empty or specify
5. Run workflow

**Result:**
- Build promoted to Production track
- Git tag created (`v1.2.3`)
- GitHub Release created with notes
- Team notified

## Configuration

### Environment Configuration

Since all tracks use the same binary, environment-specific configuration must be handled at runtime, not build-time.

**Current approach:**
```dart
// ❌ Don't do this - build-time configuration
const apiUrl = String.fromEnvironment('API_URL');
```

**Better approach:**
```dart
// ✅ Runtime configuration based on track
String getApiUrl() {
  if (isProduction) return 'https://api.prod.com';
  if (isBeta) return 'https://api.beta.com';
  if (isAlpha) return 'https://api.alpha.com';
  return 'https://api.internal.com';
}
```

### Feature Flags

Use feature flags for environment-specific features:

```dart
// Enable feature only in certain environments
if (FeatureFlags.isEnabled('new_feature') && !isProduction) {
  // Show new feature
}
```

### Build Configuration

All builds use **production configuration** (`.env.production`):
- Production API endpoints
- Production Sentry DSN
- Production feature flags

Track-specific behavior controlled at runtime via:
- App version checking
- Remote config (Firebase Remote Config)
- Feature flags
- A/B testing frameworks

## Version Management

### Build Numbers

- Single shared counter across all tracks
- Increments only on new builds
- Promotions reuse same build number

**Example flow:**
```
Build #120 → Internal (day 1)
          ↓
          Promote to Alpha (day 2) - still build #120
          ↓
          Promote to Beta (day 3) - still build #120
          ↓
          Promote to Production (day 5) - still build #120

Build #121 → Internal (day 6) - new build
```

### Version Numbers

Semantic version (1.2.3) only changes for production releases:

```bash
# Regular promotion - version stays same
Promote #120 to Production → 1.2.3 (build 120)

# Next build - still 1.2.3, but build 121
Build #121 → 1.2.3 (build 121)

# Production release with version bump
Manual release workflow → 1.3.0 (build 121)
```

## Testing Strategy

### Internal Track Testing

**Who:** Developers, QA team
**Duration:** 1-2 days
**Focus:**
- Functionality testing
- Critical bug detection
- Performance verification

**Criteria to promote to Alpha:**
- [ ] No crashes on startup
- [ ] Core features working
- [ ] No critical bugs
- [ ] Performance acceptable

### Alpha Track Testing

**Who:** Internal team, stakeholders
**Duration:** 2-3 days
**Focus:**
- Broader feature testing
- Integration testing
- UI/UX validation

**Criteria to promote to Beta:**
- [ ] All features working as expected
- [ ] No major bugs
- [ ] Stakeholder approval
- [ ] Crash-free rate > 98%

### Beta Track Testing

**Who:** External beta testers, power users
**Duration:** 3-7 days
**Focus:**
- Real-world usage
- Edge case discovery
- User feedback
- Scale testing

**Criteria to promote to Production:**
- [ ] Crash-free rate > 99%
- [ ] Positive user feedback
- [ ] All reported issues resolved or acceptable
- [ ] Performance metrics within targets
- [ ] Security review passed

### Production

**Rollout strategy:**
- Start at 10% of users
- Monitor for 24 hours
- Increase to 50% if stable
- Complete rollout to 100%

## Rollback Strategy

### Rolling Back a Promotion

**Scenario:** Just promoted to Beta, but found critical bug

**Google Play Console:**
1. Go to Beta track
2. Find previous stable version
3. Click "Promote to Beta"
4. Set to 100% rollout

**Result:** Previous build restored to Beta

### Rolling Back Production

**iOS (App Store):**
- Apple doesn't allow direct rollbacks
- Must submit previous build as new version (increment build number)
- Use expedited review for critical issues

**Android (Google Play):**
1. Go to Production track
2. Find last stable version
3. Promote to Production at 100%

**Alternative:**
- Halt current rollout
- Fix issue
- Build new version
- Deploy fix

## Monitoring

### Track What Matters

**For each promotion, monitor:**
- Crash-free rate
- ANR (Application Not Responding) rate
- User reviews/ratings
- Key performance metrics
- Feature adoption rates

**Set alerts for:**
- Crash rate spike (> 2%)
- ANR rate spike (> 1%)
- Significant negative reviews
- Performance degradation

### Gradual Rollout Monitoring

When promoting to production, use staged rollout:

**Day 1:** 10% rollout
- Monitor crash rates
- Check for critical bugs
- Review initial feedback

**Day 2:** If stable → 50% rollout
- Continue monitoring
- Address any issues quickly

**Day 3:** If stable → 100% rollout
- Complete deployment
- Monitor for 48 hours

## Comparison: Old vs New Workflow

### Old Workflow (Build Per Environment)

```
Develop → CI build (15 min)
          ↓
          Internal track

Manual trigger → CI build (15 min)
                 ↓
                 Alpha track

Manual trigger → CI build (15 min)
                 ↓
                 Beta track

Manual trigger → CI build (15 min)
                 ↓
                 Production track

Total: 60 minutes of build time
Risk: Different binaries per environment
```

### New Workflow (Build Once, Promote)

```
Develop → CI build (15 min)
          ↓
          Internal track
          ↓
          Store artifact

Manual trigger → Promote (30 sec)
                 ↓
                 Alpha track

Manual trigger → Promote (30 sec)
                 ↓
                 Beta track

Manual trigger → Promote (30 sec)
                 ↓
                 Production track

Total: 16.5 minutes (vs 60 minutes)
Benefit: Same binary, tested and promoted
```

## Migration from Old Workflow

### Step 1: Test New Workflow

1. Keep old workflows enabled
2. Use new workflow for next release cycle
3. Verify promotions work correctly
4. Compare binaries and behavior

### Step 2: Switch Over

1. Update team documentation
2. Train team on new promotion process
3. Disable old per-environment workflows
4. Use new workflow exclusively

### Step 3: Clean Up

1. Archive old workflow files
2. Update CI/CD documentation
3. Remove environment-specific build configs

## Troubleshooting

### Problem: Can't find artifact to promote

**Cause:** Artifact retention expired (90 days)

**Solution:**
- Build new version
- Or increase artifact retention in workflow

### Problem: Promotion fails

**Cause:** Build not found in source track

**Solution:**
- Verify build exists in Internal/previous track
- Check build number is correct
- Ensure sufficient time passed for Google Play to process

### Problem: Want different config per environment

**Solution:**
- Use runtime configuration
- Implement feature flags
- Use remote config (Firebase)
- Don't use build-time environment variables

## Best Practices

### 1. Always Test Before Promoting

- Never promote without testing previous track
- Use automated tests where possible
- Manual testing for critical flows

### 2. Document Promotion Decisions

- Why promoting to next track?
- What testing was done?
- Any known issues?
- Who approved?

### 3. Monitor After Promotion

- Set alerts for crash rates
- Watch user feedback
- Review performance metrics
- Be ready to rollback

### 4. Use Gradual Rollout for Production

- Start with 10%
- Monitor for 24 hours
- Increase gradually
- Complete only if stable

### 5. Keep Artifact History

- Don't reduce artifact retention
- Maintain build number tracking
- Document which builds were promoted when

## FAQs

**Q: Can I still build for specific environments?**
A: Yes, use the old `release.yml` workflow if needed for emergency cases.

**Q: What if I need environment-specific features?**
A: Use feature flags and runtime configuration instead of build-time configuration.

**Q: How do I know which build is in production?**
A: Check Google Play Console or App Store Connect, or use `./scripts/version_manager.sh info`

**Q: Can I promote multiple builds in one day?**
A: Yes, but ensure adequate testing between promotions.

**Q: What if promotion fails?**
A: The workflow will report the error. Common causes: build not found, insufficient permissions, or Google Play processing delays.

**Q: How do I revert a bad promotion?**
A: Promote a previous stable build to the same track (see Rollback Strategy section).

## Resources

- [Google Play Track Management](https://support.google.com/googleplay/android-developer/answer/9845334)
- [App Store TestFlight Groups](https://developer.apple.com/testflight/)
- [Feature Flag Best Practices](https://martinfowler.com/articles/feature-toggles.html)

---

**Last Updated:** 2025-11-06
**Status:** ✅ Active - Recommended approach

For questions or issues with this workflow, check GitHub Actions logs or contact the engineering team.
