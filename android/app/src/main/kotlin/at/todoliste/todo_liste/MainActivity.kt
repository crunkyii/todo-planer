package at.todoliste.todo_liste

import android.content.Intent
import at.todoliste.todo_liste.widgets.Widgets
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Kanal zur Flutter-App für die Startbildschirm-Widgets (lib/services/home_widgets.dart).
    private var widgetChannel: MethodChannel? = null
    private var pendingAction: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pendingAction = takeAction(intent)
        widgetChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "todo_liste/widgets").also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    // Die App hat neue Daten geschrieben: Widgets neu zeichnen.
                    "update" -> {
                        Widgets.updateAll(applicationContext)
                        result.success(null)
                    }
                    // Wurde die App über „+“ im Widget gestartet?
                    "initialAction" -> {
                        result.success(pendingAction)
                        pendingAction = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    // App läuft schon und wird über das Widget nach vorne geholt.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        takeAction(intent)?.let { widgetChannel?.invokeMethod("action", it) }
    }

    /** Liest die Aktion und entfernt sie, damit sie nach einem Neuaufbau nicht noch einmal auslöst. */
    private fun takeAction(intent: Intent?): String? {
        val action = intent?.getStringExtra(Widgets.EXTRA_ACTION)
        intent?.removeExtra(Widgets.EXTRA_ACTION)
        return action
    }
}
