# Store answers

Draft answers for the App Store Connect and Play Console forms, written on
2 Nov 2026 from the [privacy notice](https://onhomeroom.com/legal/privacy-notice),
the [terms](https://onhomeroom.com/legal/terms-of-service) and the app's
permissions. They have not been checked against the live forms, whose wording may
differ. **To confirm** marks an answer that needs a decision.

## Listing

The text is in [`fastlane/metadata/en-US/`](../fastlane/metadata/en-US/).

| Field | Value |
| --- | --- |
| App Store name | Homeroom |
| Play name | Homeroom: Apps with friends (as the privacy notice names it) |
| Subtitle (Apple) | Small apps with your groups |
| Short description (Play) | Make and share small apps with friends and groups. |
| Category | Social networking |
| Support | https://onhomeroom.com/contact |
| Privacy | https://onhomeroom.com/legal/privacy-notice |
| Account deletion | https://onhomeroom.com/legal/account-deletion |
| Child safety standards (Play) | https://onhomeroom.com/legal/child-safety-standards |
| Copyright | 2026 Usernode Labs AG |

## Screenshots

Take these from the final build, signed in to a test account with made-up data.

| Store | Needed |
| --- | --- |
| App Store, iPhone | Largest iPhone size |
| App Store, iPad | 13-inch iPad, because the app runs on iPad |
| Play | At least 2 phone screenshots, a 1024x500 feature graphic and a 512x512 icon |

Suggested screens: Home, an app open inside Homeroom, a proposed change with its
preview and vote, group chat, Discover.

## Age rating

The target is 13+. Both stores work the rating out from these answers.

| Question | Answer |
| --- | --- |
| Sexual content, nudity, violence, gambling, drugs, mature themes | None |
| User-generated content | Yes |
| Messaging and chat | Yes |
| Advertising | No |
| Unrestricted web access | **To confirm:** no, if outside links open in the system browser |
| Digital purchases | No |
| Shares a person's location | No |
| Play target age groups | 13-15, 16-17 and 18+ |

## App Store: App Privacy

Tracking: **no**. The app has no ad SDK. None of this data is used for third-party
advertising.

| Data type | Why | Linked to the person |
| --- | --- | --- |
| Email address | App functionality | Yes |
| Phone number | App functionality (phone sign-in) | Yes |
| Name (display name) | App functionality | Yes |
| User ID | App functionality | Yes |
| Device ID (installation ID, hashed device ID) | App functionality | Yes |
| Photos or videos | App functionality (attachments) | Yes |
| Audio data | App functionality (dictation) | Yes |
| Other user content (messages, prompts, code, proposals) | App functionality | Yes |
| Product interaction | Analytics | **To confirm** |
| Crash data, performance data | App functionality (Sentry) | **To confirm** |

**To confirm:**

- **Marketing:** section 2.11 of the privacy notice mentions marketing. If any of
  this data is used for it, add "Developer's advertising or marketing".
- **Sensitive info:** the optional ZKPassport check shares the identity attributes
  a person selects. Does the attribute count as sensitive?
- **Coarse location:** the privacy notice lists "region" with each server request.
  Is it stored per person?

## Google Play: App content

| Form | Answer |
| --- | --- |
| Privacy policy | https://onhomeroom.com/legal/privacy-notice |
| Ads | No ads |
| App access | Sign-in needed. Give the reviewer account from `app-review-notes.md` |
| Government, health, news | No |
| Financial features | **To confirm:** see below |
| Exact alarm, foreground service | Not used. Remove any left over from open testing |

**Financial features:** I suggest declaring none and explaining in the review notes
that the wallet only holds testnet tokens that are non-transferable, have no
monetary value and cannot be redeemed. Check this against the form's options, and
with whoever handles legal, because Play has specific rules for crypto wallets.

## Google Play: Data safety

The data types match the App Privacy table above.

| Question | Answer |
| --- | --- |
| Encrypted in transit | Yes |
| Can people ask for their data to be deleted | Yes, in the app and at the account deletion URL |
| Is collection required | Required: account data. Optional: phone number, photos, audio, identity check |
| Is data shared | **To confirm:** see below |

**Sharing:** service providers such as Sentry, Firebase, OpenRouter and Anthropic
don't normally count as sharing. Apps made by other people receive a viewer's
username, user ID, wallet public key and language, and that may count, so I suggest
declaring it.

## App Store: other

- **EU trader status:** trader, Usernode Labs AG, Bahnhofstrasse 7, 6300 Zug,
  Switzerland. Apple shows the trader's address, phone and email on the listing, so
  choose which ones to publish.
- **Release:** manual, as in `store-release.md`.
