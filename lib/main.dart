import 'package:flutter/widgets.dart';
import 'app.dart';
import 'migrations/storage_migrations.dart';
import 'utils/app_version.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Both before runApp: services read storage lazily on first use, and the
  // migration needs to know which build it is running as.
  await AppVersion.load();
  await StorageMigrations.run();
  runApp(const Transportia());
}
