import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';
import 'features/settings/providers/settings_providers.dart';
import 'features/settings/screens/first_run_setup_screen.dart';
import 'l10n/l10n.dart';

/// Root widget: Arabic/RTL by default, language taken from the settings.
/// Shows the first-run setup until it is completed, then the home screen.
class DukanApp extends ConsumerWidget {
  const DukanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final locale = Locale(settings.value?.language ?? 'ar');

    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: settings.when(
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Scaffold(
          body: Center(child: Text('$error')),
        ),
        data: (s) =>
            s.isConfigured ? const HomeScreen() : const FirstRunSetupScreen(),
      ),
    );
  }
}
