import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_auth_config.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/bloc/auth_cubit.dart';
import 'features/auth/presentation/widgets/auth_gate.dart';
import 'features/sync/presentation/bloc/sync_status_cubit.dart';
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
    authOptions: kSupabaseFlutterAuthOptions,
  );

  await di.init();

  runApp(const LifeTimeApp());
}

class LifeTimeApp extends StatelessWidget {
  const LifeTimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(
          create: (_) {
            final c = di.sl<AuthCubit>();
            c.listenToSupabaseAuth();
            c.checkCurrentUser();
            return c;
          },
        ),
        BlocProvider<SyncStatusCubit>.value(
          value: di.sl<SyncStatusCubit>(),
        ),
      ],
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
        home: const AuthGate(),
      ),
    );
  }
}
