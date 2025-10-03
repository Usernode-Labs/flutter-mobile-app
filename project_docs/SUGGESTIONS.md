# AI Suggestions & Decisions

## 2025-10-03: Architecture Improvements

### 🤖 AI Suggested
**Topic**: Feature-oriented architecture with third-party dApp support

**Rationale**:
- App will evolve into app store for dApps
- Need isolation between first-party and third-party code
- Scalability for multiple independent dApps

**Proposed Structure**:
```
lib/
├── core/      # Shared infrastructure
├── features/  # First-party features
├── dapps/     # Third-party dApps (isolated)
└── app/       # App-level config
```

**Status**: ✅ **ACCEPTED & IMPLEMENTED**

**Decision Notes**:
- Chose feature-first over layer-first for better scalability
- dApps directory allows third-party isolation
- Clean architecture layers (data/domain/presentation) prepared but not enforced yet

---

### 🤖 AI Suggested
**Topic**: Riverpod for state management

**Rationale**:
- Compile-time safety for blockchain/financial app
- Better than Provider for multi-dApp architecture
- Native async/stream support for blockchain subscriptions
- Easy feature isolation and testing

**Status**: ⏳ **DEFERRED**

**Decision Notes**:
- Will implement after architecture stabilizes
- Good fit for app store model
- Allows per-dApp provider scoping

---

### 🤖 AI Suggested
**Topic**: Remove dead code (NFC constants, unused imports, etc.)

**Findings**:
- 2 unused files (~30 lines)
- 50+ lines of unused constants
- 10 lines of commented code
- 14 Gallery-Mobile*.png images (1.6 MB, potentially unused)

**Status**: ✅ **ACCEPTED & IMPLEMENTED**

**Impact**:
- Removed ~90 lines of dead code
- Improved codebase cleanliness
- Images kept pending investigation

---

## 2025-10-03: Security Issues

### 🔴 AI Identified Issue
**Topic**: Hardcoded Sentry DSN

**Location**: `lib/core/utils/sentry.dart:20`

**Issue**: API key hardcoded in source code

**Status**: ⚠️ **TODO - HIGH PRIORITY**

**Suggested Fix**:
```dart
// Use environment variable or secret manager
const sentryDsn = String.fromEnvironment('SENTRY_DSN');
```

---

## Template for Future Suggestions

### 🤖 AI Suggested
**Topic**: [Title]

**Rationale**:
- [Why this suggestion was made]

**Status**: [PENDING / ACCEPTED / REJECTED / DEFERRED]

**Decision Notes**:
- [Your decision and reasoning]
