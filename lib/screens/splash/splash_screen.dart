import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../main_app.dart';
import '../onboarding/account_onboarding_screen.dart';
import '../../services/accounts_repository.dart';
import '../../gen_l10n/app_localizations.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppConstants.longAnimation,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();

    Future.delayed(AppConstants.splashDuration, () async {
      final repo = await AccountsRepository.create();
      final hasAny = await repo.hasAny();
      if (!mounted) return;
      if (!hasAny) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AccountOnboardingScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainApp()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Material(
                      color: theme.colorScheme.primaryContainer,
                      shape: const CircleBorder(),
                      child: SizedBox(
                        width: 120,
                        height: 120,
                        child: Icon(
                          Icons.hub_outlined,
                          size: 60,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    Text(
                      l10n.appName,
                      style: theme.textTheme.displayMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      l10n.appTagline,
                      style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w400,
                      ),
                    ),

                    const SizedBox(height: 60),

                    SizedBox(
                      width: 32,
                      height: 32,
                      child: const CircularProgressIndicator(strokeWidth: 2.5),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      l10n.initializingNode,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
