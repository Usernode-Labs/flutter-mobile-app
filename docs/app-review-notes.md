# App Review notes

Paste the "Notes for App Review" section into App Store Connect with each
submission or consultation request. The store listing copy lives in
[`fastlane/metadata/en-US/`](../fastlane/metadata/en-US/). Guideline numbers
are from Apple's [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/),
read 4 Oct 2026.

## Notes for App Review

**What Homeroom is (4.7).** Homeroom is a community app. Groups of friends make
and share small web apps inside it. Every change to an app is proposed, tried by
the app's members and voted in before it goes live.

**Previews (2.5.2, 4.7).** A proposed change runs as a preview inside Homeroom
before the vote. Only that app's members can see it, and it is held to the same
rules as the live app.

**Moderation (1.2, 4.7.1).** People can report apps, messages and other people,
and can block apps and people. Reports go to a moderation queue, where staff can
hide a message and suspend an app or a person. Every proposed change also gets an
automated check of its text and code against Homeroom's content rules, and a
change it flags cannot merge. The app's members then vote on the change before it
goes live. Contact: https://onhomeroom.com/contact

**Content and age (4.7.5).** Homeroom is for people aged 13 and over. Every app is
held to the "None" content rule in Homeroom's app conventions, so no app exceeds
Homeroom's age rating. Age is also covered in the terms of service. Wallet, token,
staking, node and passport features ask "Are you 18 or older?" the first time, and
the server refuses those actions until the person says yes.

**Wallet (4.7.2, 3.1.5).** Homeroom has a built-in testnet wallet. Its tokens are
non-transferable, have no monetary value and cannot be redeemed, and it cannot
hold mainnet tokens or currency. An app can ask it to sign or send. Only an app's
own frames can ask; previews and pages nested inside an app cannot. The wallet is
Homeroom's own code, not an iOS API exposed to apps.

**Payments (3.1.1, 4.7.1).** No app sells digital goods.

**Identity (4.7.3, 5.1).** Apps receive the viewer's username, user ID, wallet
public key and language, as the privacy policy describes.

**Index of apps (4.7.4).** Discover lists the apps. Each app has a link,
`https://app.onhomeroom.com/app/<slug>`, that opens it in Homeroom.

**Sign-in (4.8).** People sign in with Apple, Google or a username and password.

**Reviewer account (2.1).** Sign in with username and password:

- Username: `<from create_test_account>`
- Password: `<from create_test_account>`

Make the account with the admin connector's `create_test_account` just before
submitting. Do not commit the password here.

## Questions for the consultation

Status: not sent as of 2 Nov 2026. Send this before the first submission.

We would like Apple to confirm our reading on four points.

1. **Built-in wallet (4.7.2).** Does it count as exposing native technology to
   mini apps? Our position: no. It is Homeroom's own code, not an iOS API, and
   only an app's own frames can reach it.
2. **Member-only previews (2.5.2, 4.7).** Is it fine to run an unvoted change as
   a preview inside the app? Our position: yes. A preview is the next version
   of a mini app, held to the same rules as the live one.
3. **Age (4.7.5).** Are a 13+ rating and the terms enough? Our position: yes. No
   app exceeds the rating, so no separate age check is needed at sign-up. Wallet,
   token, staking and node features are limited to people who say they are 18 or
   older.
4. **Identity sharing (4.7.3).** Is the privacy policy enough for sharing a
   viewer's username and ID with apps? Our position: yes, for now. If Apple asks
   for consent, a one-time "this app will see your username" notice is designed
   and ready to build.
