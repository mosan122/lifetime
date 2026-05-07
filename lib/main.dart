import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/bloc/auth_cubit.dart';
import 'features/milestones/presentation/pages/timeline_page.dart';
import 'injection_container.dart' as di;

// Pass credentials via --dart-define at build/run time:
//   flutter run \
//     --dart-define=SUPABASE_URL=https://your-ref.supabase.co \
//     --dart-define=SUPABASE_ANON_KEY=your-anon-key
const _supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://aqewwnwytdjoxzhqvbbn.supabase.co',
);
const _supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'sb_publishable_9PAm7_0UJjJ0Alu1posmyg_AQ4iYDZH',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: _supabaseUrl,
    anonKey: _supabaseAnonKey,
  );

  await di.init();

  runApp(const LifeTimeApp());
}

class LifeTimeApp extends StatelessWidget {
  const LifeTimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthCubit>(
      create: (_) => di.sl<AuthCubit>()..checkCurrentUser(),
      child: MaterialApp(
        title: 'LifeTime',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        locale: const Locale('es', 'ES'),
        supportedLocales: const [
          Locale('es', 'ES'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // Local-first: the timeline can render immediately using cached data;
        // auth / premium refresh happens in the background via AuthCubit.
        home: const TimelinePage(),
      ),
    );
  }
}
