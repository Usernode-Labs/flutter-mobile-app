# Architecture Decision Records (ADR)

## ADR-001: Feature-Oriented Architecture

**Date**: 2025-10-03
**Status**: ✅ Accepted
**Deciders**: Development Team

### Context
The app is evolving from a simple wallet app to an app store platform hosting multiple dApps (DEX, NFT marketplace, governance, etc.). Need architecture that supports:
- Third-party dApp integration
- Feature isolation
- Independent development and testing
- Clear boundaries between first-party and third-party code

### Decision
Adopt **feature-oriented clean architecture** with three main directories:

```
lib/
├── core/       # Shared infrastructure (only for first-party)
├── features/   # First-party features (wallet, node, home)
└── dapps/      # Third-party dApps (completely isolated)
```

Each feature/dApp follows clean architecture layers:
- **Data**: models, repositories, datasources
- **Domain**: entities, usecases (business logic)
- **Presentation**: screens, widgets

### Alternatives Considered

1. **Layer-first architecture**
   - ❌ Hard to scale with multiple dApps
   - ❌ No clear isolation between features
   - ❌ Third-party code mixed with first-party

2. **Modular monolith with packages**
   - ❌ Too complex for current team size
   - ❌ Overhead of managing multiple packages
   - ✅ Good for future if team grows

3. **Flat structure (current)**
   - ❌ No scalability
   - ❌ No dApp isolation
   - ❌ Hard to maintain as app grows

### Consequences

**Positive:**
- ✅ Clear separation of concerns
- ✅ Easy to add new features/dApps
- ✅ Third-party dApps completely isolated
- ✅ Better testability
- ✅ Prepared for team scaling

**Negative:**
- ⚠️ More directories to navigate
- ⚠️ Longer import paths
- ⚠️ Need to train developers on structure

**Neutral:**
- 🔄 One-time migration effort (completed)
- 🔄 Need to document guidelines for third-party devs (completed)

---

## ADR-002: Deferred Riverpod Migration

**Date**: 2025-10-03
**Status**: ⏳ Deferred
**Deciders**: Development Team

### Context
Current app uses direct service calls (singleton pattern). As app grows and adds state management needs, need to choose solution.

### Decision
**Defer Riverpod migration** until architecture stabilizes, but design structure with Riverpod in mind.

**When to implement**: After current refactoring proves stable in production (~2-4 weeks).

### Rationale
- Architecture just changed (need stability period)
- Current singleton pattern works for now
- Riverpod is the right long-term choice for:
  - Compile-time safety (critical for financial app)
  - Multi-dApp support (provider scoping)
  - Async blockchain operations
  - Better than Provider/Bloc for our use case

### Consequences

**Positive:**
- ✅ Architecture is already prepared for Riverpod
- ✅ Can test current refactoring first
- ✅ Team learns new structure before adding complexity

**Negative:**
- ⚠️ Will need another refactoring pass later
- ⚠️ Some boilerplate code remains (singletons)

---

## ADR-003: Absolute Imports Only

**Date**: 2025-10-03
**Status**: ✅ Accepted
**Deciders**: Development Team

### Context
With deeper directory nesting, relative imports (`../../../core/`) become hard to read and maintain.

### Decision
Use **absolute imports** exclusively:

```dart
// ✅ Good
import 'package:crypto_mobile_app/core/theme/theme.dart';

// ❌ Bad
import '../../../core/theme/theme.dart';
```

### Consequences

**Positive:**
- ✅ Easier to refactor (move files without breaking imports)
- ✅ More readable
- ✅ IDE auto-complete works better
- ✅ Consistent across codebase

**Negative:**
- ⚠️ Longer import statements
- ⚠️ Need to enforce in code reviews

---

## ADR-004: dApp Isolation Policy

**Date**: 2025-10-03
**Status**: ✅ Accepted
**Deciders**: Development Team

### Context
Third-party dApps need clear boundaries to prevent security issues and ensure maintainability.

### Decision
**Strict import rules:**

```
dApps can ONLY import from:
- ✅ core/* (shared infrastructure)
- ✅ Same dApp's own code
- ❌ features/* (first-party features)
- ❌ Other dApps
```

Enforced via:
1. Documentation in `dapps/README.md`
2. Code review process
3. Future: Custom lint rules

### Consequences

**Positive:**
- ✅ Complete isolation of third-party code
- ✅ Security boundary
- ✅ Can remove dApp without affecting others
- ✅ Third-party devs can't access wallet internals

**Negative:**
- ⚠️ Some code duplication across dApps
- ⚠️ Need good `core/` APIs

---

## Template for Future ADRs

## ADR-XXX: [Title]

**Date**: YYYY-MM-DD
**Status**: [Proposed / Accepted / Rejected / Deprecated / Superseded]
**Deciders**: [Who made this decision]

### Context
[What is the issue we're seeing that motivates this decision or change?]

### Decision
[What is the change that we're actually proposing or doing?]

### Alternatives Considered
1. **Option A**
   - Pros
   - Cons

2. **Option B**
   - Pros
   - Cons

### Consequences

**Positive:**
- What becomes easier

**Negative:**
- What becomes harder

**Neutral:**
- Other changes
