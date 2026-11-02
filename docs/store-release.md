# Store release

Releases are built from `develop`. The same build testers tried is the one that
goes to production, so nothing is rebuilt for the stores.

| | App Store | Google Play |
| --- | --- | --- |
| App | ID `6814786047` | ID `4971982934440602402` |
| Package | `com.onhomeroom.app` | `com.onhomeroom.app` |
| CI uploads to | TestFlight | Internal track, as a draft |
| Goes live by | Choosing the build, then App Review | Promoting to production, then Google's review |

Run **Build and Deploy** on `develop`. A `develop` build uses the `NONPROD_*`
secrets, which only changes logging and which Sentry project gets its reports.
It talks to the production backend.

## Before each release

1. Bump `version` in `pubspec.yaml` if the last version has shipped. The App
   Store version must match it exactly (`1.0.0`, not `1.0`).
2. Run the workflow, then test sign-in, push, deep links, wallet, dictation and
   account deletion on both platforms.

## App Store

1. Fill in the listing from `fastlane/metadata/en-US/`, and add screenshots.
2. Check App Privacy, the age rating and EU trader status.
3. Select the build and paste the notes from `app-review-notes.md`. Make the
   reviewer account just before submitting.
4. Choose manual release, submit, and release by hand once approved.

## Google Play

1. Finish the App content section, including the wallet declaration. Background
   block production is off, so there are no exact-alarm or foreground-service
   declarations. Remove any left over from open testing.
2. Pick countries, then promote the tested build to production.
3. Start the rollout at 10–20% and watch Sentry and Android vitals.

## After approval

In the Homeroom admin's app version settings:

1. Set `update_url` to each store listing. The install banner, waitlist release
   emails and the update dialog all read it.
2. Raise the recommended build number to move testers to the store version.

Leave the required build number alone unless an old build has to stop working.

## Listing URLs

- Support: https://onhomeroom.com/contact
- Privacy: https://onhomeroom.com/legal/privacy-notice
- Account deletion: https://onhomeroom.com/legal/account-deletion
- Terms: https://onhomeroom.com/legal/terms-of-service

## Android deep links

`assetlinks.json` is served by social-vibecoding and has to list Play's app
signing certificate. It matched on 2 Nov 2026. Check again if the key changes.
