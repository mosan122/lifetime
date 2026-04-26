import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'features/milestones/presentation/pages/timeline_page.dart';
import 'injection_container.dart' as di;

// Pass credentials via --dart-define at build/run time:
//   flutter run \
//     --dart-define=SUPABASE_URL=https://your-ref.supabase.co \
//     --dart-define=SUPABASE_ANON_KEY=your-anon-key
const _supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://your-project-ref.supabase.co',
);
const _supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'your-anon-key',
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
    return MaterialApp(
      title: 'LifeTime',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const TimelinePage(),
    );
  }
}
