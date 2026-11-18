package at.todoliste.todo_liste.widgets

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Einstellungsfenster eines Widgets (Widget gedrückt halten → „Einstellungen“).
 *
 * Zeigt eine kleine Flutter-Oberfläche (Einstieg `widgetConfigMain` in lib/main.dart) und
 * speichert das Ergebnis für genau dieses eine Widget.
 */
class WidgetConfigActivity : FlutterActivity() {
    private val widgetId: Int
        get() = intent?.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            ?: AppWidgetManager.INVALID_APPWIDGET_ID

    override fun getDartEntrypointFunctionName(): String = "widgetConfigMain"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Wird das Fenster einfach geschlossen, gilt das als „abgebrochen“.
        setResult(Activity.RESULT_CANCELED, result())
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) finish()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "todo_liste/widget_config")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "init" -> result.success(
                        mapOf("kind" to kind(), "config" to WidgetConfig.raw(applicationContext, widgetId)),
                    )
                    "save" -> {
                        val json = call.arguments as? String
                        if (json == null || !WidgetConfig.save(applicationContext, widgetId, json)) {
                            result.error("invalid", "Einstellungen nicht gespeichert", null)
                        } else {
                            Widgets.updateAll(applicationContext)
                            setResult(Activity.RESULT_OK, result())
                            result.success(null)
                            finish()
                        }
                    }
                    "cancel" -> {
                        result.success(null)
                        finish()
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun result() = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)

    /** Welche Art Widget das ist – danach richtet sich, was man einstellen kann. */
    private fun kind(): String {
        val provider = AppWidgetManager.getInstance(this).getAppWidgetInfo(widgetId)?.provider?.className
        return when (provider) {
            UpcomingWidget::class.java.name -> "upcoming"
            HabitsWidget::class.java.name -> "habits"
            CountWidget::class.java.name -> "count"
            else -> "today"
        }
    }
}
