import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'app_services.dart';
import 'data/cloud.dart';
import 'data/local_db.dart';
import 'data/settings_store.dart';
import 'data/store.dart';
import 'data/sync_service.dart';
import 'services/reminders.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = Store(LocalDb());
  final reminders = Reminders();
  // Unabhängige Vorbereitungen gleichzeitig.
  final (_, prefs, _, _) = await (
    initializeDateFormatting(),
    SharedPreferences.getInstance(),
    store.load(),
    reminders.init(appName: 'Todo-Liste'),
  ).wait;
  final settings = SettingsStore(prefs);
  final cloud = Cloud();

  final services = AppServices(
    settings: settings,
    store: store,
    cloud: cloud,
    sync: SyncService(store: store, settings: settings, cloud: cloud),
    reminders: reminders,
  );
  await services.boot();

  runApp(TodoApp(services: services));
}
