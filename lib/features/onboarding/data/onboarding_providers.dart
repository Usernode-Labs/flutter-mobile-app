import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Temp storage for onboarding-specific UI state, such as the user handle
/// entered on the Verify Access screen.
final onboardingUserIdProvider = StateProvider<String?>((ref) => null);


