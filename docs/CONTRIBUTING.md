# Contributing Guide

Thanks for contributing! This guide covers project structure, coding patterns, and expectations to help you get productive quickly.

## Project Structure

- `lib/core`: cross-cutting utilities (logging, Sentry, theme, feature flags, errors, routing, DI)
- `lib/features/<feature>`: feature-first directories
  - `domain`: entities, value objects, repository interfaces, usecases (pure Dart)
  - `data`: models/DTOs, mappers, datasources, repository implementations
  - `presentation`: screens, widgets, controllers/providers
- `lib/gen_l10n`: generated localization files
- `docs/`: architecture and contributor docs

See `docs/ARCHITECTURE.md` for details.

## Development Workflow

1. Pick a feature/task and scope it clearly.
2. Start with Domain: define interfaces and entities.
3. Implement Data: repositories + mappers; keep IO and platforms here.
4. Wire Presentation: providers/controllers read domain interfaces.
5. Add or update tests as appropriate.

### Configuration

- Use `core/config/app_config.dart` for environment-aware values.
- Pass values via `--dart-define` when running/building:
  - `--dart-define=APP_ENV=staging`
  - `--dart-define=API_BASE_URL=https://api.example.com`
  - `--dart-define=VERBOSE_LOGGING=true`
  - `--dart-define=SENTRY_DSN=your_sentry_dsn` (optional; defaults to disabled)

### Feature Toggles

- Node Result providers (mempool + scheduled slots):
  - `--dart-define=USE_RESULT_PROVIDERS=true` to enable
  - Default is false (keeps AsyncNotifier providers)

### Theming

- ThemeMode is persisted via `themeModeProvider`.
- Change it in Settings (`/settings`) or using the quick toggle in Node Status.

### DI and State

- Use Riverpod providers from `core/di/providers.dart`.
- Add feature controllers under `features/<feature>/presentation/controllers` using `AsyncNotifier`.
- Screens access data via `ref.watch(yourProvider)` and trigger actions via `ref.read(yourProvider.notifier)`.

### Navigation

- Router lives in `core/routing/app_router.dart` using `go_router`.
- Access via `ref.watch(appRouterProvider)` indirectly through `MaterialApp.router`.
- In widgets, navigate with `context.go('/path')` or `context.push('/path')`.

## Patterns and Conventions

- Favor immutability and small, testable units.
- Keep UI declarative; no heavy logic in Widgets.
- Map DTOs to Domain entities before reaching the UI.
- Use typed errors (`core/errors/app_error.dart`) or `Result` (`core/result.dart`) at repo/usecase boundaries.
- Centralize configuration and feature flags in `core/`.
- Add `const` where possible and prefer composition over inheritance.

## Adding a New Feature (Checklist)

- Create domain interfaces/entities under `features/<feature>/domain`.
- Implement data repositories/datasources under `features/<feature>/data`.
- Expose a controller/provider under `features/<feature>/presentation/controllers`.
- Build screens/widgets under `features/<feature>/presentation`.
- Add tests: provider unit tests and widget tests using provider overrides.
- Wire navigation in `core/routing/app_router.dart`.
- Document flags and config if needed in `RUNNING.md`.

## Examples

Below are concrete examples to help you make changes confidently.

### Example: Add a New Feature (e.g., Notifications)

1) Domain (pure Dart)

```
features/notifications/domain/entities/notification.dart
features/notifications/domain/repositories/notifications_repository.dart
```

2) Data (adapters + datasources)

```
features/notifications/data/repositories/notifications_repository_impl.dart
features/notifications/data/datasources/local_notifications_ds.dart
```

Implement `NotificationsRepository` and map any plugin/IO exceptions to `AppError`.

3) Presentation (providers + screens)

```
features/notifications/presentation/controllers/notifications_controller.dart
features/notifications/presentation/screens/notifications_screen.dart
```

Expose an `AsyncNotifier` or `Notifier` and read it from the screen using `ref.watch(...)`.

4) Routing

Add a route in `core/routing/app_router.dart`:

```
GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
```

5) Tests

- Provider test: override the repository and assert controller behavior
- Widget test: override providers and assert the screen renders expected content

### Example: Convert a Screen to Providers (Wallet)

- Create `WalletController` (AsyncNotifier) that loads balance + recents
- Replace imperative calls in the screen with:

```
final walletAsync = ref.watch(walletProvider);
walletAsync.when(data: ..., loading: ..., error: ...);
```

- Add a `refresh()` method to the controller and use `onRefresh: ref.read(walletProvider.notifier).refresh`.

### Example: Add a Toggle in Settings (ThemeMode)

- Persist value in `ThemeModeStorage` (SharedPreferences)
- Expose `themeModeProvider` (StateNotifierProvider)
- Wire to `MaterialApp.router(themeMode: ref.watch(themeModeProvider))`
- Add a Settings tile to change the value and a quick toggle on an app bar

### Example: Write a Widget Test with Provider Overrides

```
final container = ProviderContainer(overrides: [
  myProvider.overrideWith(() => FakeController()),
]);
await tester.pumpWidget(UncontrolledProviderScope(
  container: container,
  child: const MaterialApp(home: MyScreen()),
));
await tester.pumpAndSettle();
expect(find.text('Expected'), findsOneWidget);
```

Use `overrideWith(() => SubclassController())` for `AsyncNotifierProvider`s.

## Code Quality

- Run: `flutter analyze` and `dart format .` before sending PRs.
- Keep changes focused; avoid drive-by fixes unless trivial.
- Follow existing style; be consistent with file/identifier names.

## Testing

- Unit: domain entities/usecases and repository implementations (with fakes/mocks).
- Widget: screens/components with provider overrides.
- Integration: critical app flows (e.g., splash → onboarding → main).

## Continuous Integration

- A GitHub Actions workflow is included at `.github/workflows/flutter_ci.yml`.
- It runs on pushes and PRs to main/master and executes:
  - `dart format` (check only)
  - `flutter analyze`
  - `flutter test`


## Commit and PR Practices

- Small, cohesive commits with clear messages.
- PRs should describe the problem, approach, and tradeoffs.
- Include screenshots/GIFs for UI changes when possible.

## Getting Help

- Architectural questions: `docs/ARCHITECTURE.md`.
- Patterns and examples: check existing feature modules (Wallet, Node).

Happy building!
