package at.todoliste.todo_liste

import android.content.Intent
import at.todoliste.todo_liste.update.AppUpdate
import at.todoliste.todo_liste.widgets.HabitToggles
import at.todoliste.todo_liste.widgets.Widgets
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

class MainActivity : FlutterActivity() {
    // Kanal zur Flutter-App für die Startbildschirm-Widgets (lib/services/home_widgets.dart).
    private var widgetChannel: MethodChannel? = null
    private var pendingAction: String? = null

    // Auto-Update (lib/services/update_platform.dart).
    private var appUpdate: AppUpdate? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pendingAction = takeAction(intent)
        running = WeakReference(this)
        widgetChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "todo_liste/widgets").also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    // Die App hat neue Daten geschrieben: Widgets neu zeichnen (nur wenn sich etwas geändert hat).
                    "update" -> {
                        Widgets.updateAll(applicationContext, onlyIfChanged = true)
                        result.success(null)
                    }
                    // Wurde die App über „+“ im Widget gestartet?
                    "initialAction" -> {
                        result.success(pendingAction)
                        pendingAction = null
                    }
                    // Im Widget abgehakte Gewohnheiten abholen (und den Merkzettel leeren).
                    "takeHabitToggles" -> result.success(HabitToggles.take(applicationContext))
                    else -> result.notImplemented()
                }
            }
        }
        appUpdate = AppUpdate(this).also {
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AppUpdate.CHANNEL).setMethodCallHandler(it)
        }
    }

    // Rückkehr aus „Unbekannte Apps installieren“ oder aus dem Installer.
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (appUpdate?.onActivityResult(requestCode) != true) super.onActivityResult(requestCode, resultCode, data)
    }

    // App wird beendet: Der Kanal führt ins Leere, das Widget soll ihn nicht mehr benutzen.
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        widgetChannel = null
        appUpdate = null
        if (running?.get() === this) running = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    // App läuft schon und wird über das Widget nach vorne geholt.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        takeAction(intent)?.let { widgetChannel?.invokeMethod("action", it) }
    }

    companion object {
        private var running: WeakReference<MainActivity>? = null

        /** Im Widget wurde eine Gewohnheit abgehakt: Läuft die App noch, übernimmt sie es sofort. */
        fun habitsChanged() {
            running?.get()?.widgetChannel?.invokeMethod("action", "habits")
        }
    }

    /** Liest die Aktion und entfernt sie, damit sie nach einem Neuaufbau nicht noch einmal auslöst. */
    private fun takeAction(intent: Intent?): String? {
        val action = intent?.getStringExtra(Widgets.EXTRA_ACTION)
        intent?.removeExtra(Widgets.EXTRA_ACTION)
        return action
    }
}
