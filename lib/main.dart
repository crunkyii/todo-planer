import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'app_services.dart';
import 'data/cloud.dart';
import 'data/local_db.dart';
import 'data/settings_store.dart';
import 'data/store.dart';
import 'data/sync_service.dart';
import 'screens/widget_config_screen.dart';
import 'services/home_widgets.dart';
import 'services/launch_commands.dart';
import 'services/reminders.dart';
import 'services/updater.dart';
import 'services/widget_config.dart';

/// [args]: Start-Argumente – unter Windows z. B. `todoplaner://add`, wenn die App über einen Link
/// (Launcher Flick) gestartet wurde.
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Sofort auf den Kanal hören: Ein zweiter Start reicht seinen Link an dieses Fenster weiter.
  final launch = LaunchCommands(args)..attach();
  final store = Store(LocalDb());
  final reminders = Reminders();
  // Unabhängige Vorbereitungen gleichzeitig.
  final (_, prefs, _, _, updater) = await (
    initializeDateFormatting(),
    SharedPreferences.getInstance(),
    store.load(),
    reminders.init(appName: 'ToDo Planer'),
    PackageInfo.fromPlatform().then((info) => Updater.forDevice(info.version)),
  ).wait;
  final settings = SettingsStore(prefs);
  final cloud = Cloud();

  final services = AppServices(
    settings: settings,
    store: store,
    cloud: cloud,
    sync: SyncService(store: store, settings: settings, cloud: cloud),
    reminders: reminders,
    updater: updater,
    launch: launch,
  );
  await services.boot();

  runApp(TodoApp(services: services));
}

/// Zweiter Einstieg: das Einstellungsfenster eines Startbildschirm-Widgets (Android startet ihn
/// über `WidgetConfigActivity.kt`). Läuft ohne Datenbank und Anmeldung – die Kategorien stehen
/// in der Zusammenfassung, die die App für die Widgets schreibt.
@pragma('vm:entry-point')
Future<void> widgetConfigMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  final (_, prefs, start) = await (
    initializeDateFormatting(),
    SharedPreferences.getInstance(),
    WidgetConfigChannel.init(),
  ).wait;
  final settings = SettingsStore(prefs);
  runApp(
    WidgetConfigApp(
      lang: settings.lang,
      themeId: settings.theme,
      mode: settings.mode,
      kind: start.kind,
      initial: start.config,
      categories: widgetCategories(prefs.getString(HomeWidgets.prefsKey)),
      onSave: WidgetConfigChannel.save,
      onCancel: WidgetConfigChannel.cancel,
    ),
  );
}
