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
  await initializeDateFormatting();

  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsStore(prefs);
  final store = Store(LocalDb());
  await store.load();
  final cloud = Cloud();
  final reminders = Reminders();
  await reminders.init(appName: 'Todo-Liste');

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
