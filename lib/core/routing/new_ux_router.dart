import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/core/utils/sentry.dart';
import 'package:crypto_mobile_app/core/routing/app_router.dart' show appNavigatorKey;
import 'package:crypto_mobile_app/features/new_ux/presentation/screens/onboarding_import_api_screen.dart';
import 'package:crypto_mobile_app/features/new_ux/presentation/screens/permission1_screen.dart';
import 'package:crypto_mobile_app/features/new_ux/presentation/screens/permission2_screen.dart';
import 'package:crypto_mobile_app/features/new_ux/presentation/screens/permission3_screen.dart';
import 'package:crypto_mobile_app/features/new_ux/presentation/screens/new_ux_home_shell.dart';
import 'package:crypto_mobile_app/features/new_ux/presentation/screens/welcome_claim_screen.dart';
import 'package:crypto_mobile_app/features/new_ux/presentation/screens/slot_assignments_screen.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';

String _initialNewUxLocation(Ref ref, bool hasAccount) {
  print('RustBackendService.instance.isRunning: ${RustBackendService.instance.isRunning}');
  if (hasAccount) {
    return '/newux/main';
  } else {
    return '/newux/onboarding/welcome';
  }
}

Provider<GoRouter> newUxRouterProvider(hasAccount) { 
  return Provider<GoRouter>((ref) {
    return GoRouter(
      navigatorKey: appNavigatorKey,
      observers: SentryUtil.navigatorObservers(),
      initialLocation: _initialNewUxLocation(ref, hasAccount),
      routes: [
        GoRoute(
          path: '/newux/onboarding/welcome',
          builder: (context, state) => const WelcomeClaimScreen(),
        ),
        GoRoute(
          path: '/newux/onboarding/import-api',
          builder: (context, state) => const NewUxOnboardingImportApiScreen(),
        ),
        GoRoute(
          path: '/newux/onboarding/permission1',
          builder: (context, state) => const Permission1Screen(),
        ),
        GoRoute(
          path: '/newux/onboarding/permission2',
          builder: (context, state) => const Permission2Screen(),
        ),
        GoRoute(
          path: '/newux/onboarding/permission3',
          builder: (context, state) => const Permission3Screen(),
        ),
        GoRoute(
          path: '/newux/main',
          builder: (context, state) => const NewUxHomeShell(),
        ),
      GoRoute(
        path: '/newux/produced/slot-assignments',
        builder: (context, state) => const SlotAssignmentsScreen(),
      ),
      ],
    );
  });
}


