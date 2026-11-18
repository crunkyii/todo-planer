package at.todoliste.todo_liste.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import at.todoliste.todo_liste.MainActivity
import at.todoliste.todo_liste.R

/** Welche Liste ein Listen-Widget zeigt. */
enum class ListMode { TODAY, UPCOMING, HABITS }

/** Zeichnet alle Widgets neu – nach jeder Änderung in der App und wenn Android es verlangt. */
object Widgets {
    const val EXTRA_ACTION = "widget_action"
    const val ACTION_NEW_TASK = "new_task"
    const val EXTRA_MODE = "mode"
    const val EXTRA_ID = "widget_id"
    const val EXTRA_HABIT = "habit_id"

    private val listWidgets = mapOf(
        TodayWidget::class.java to ListMode.TODAY,
        UpcomingWidget::class.java to ListMode.UPCOMING,
        HabitsWidget::class.java to ListMode.HABITS,
    )

    fun updateAll(context: Context) {
        val mgr = AppWidgetManager.getInstance(context)
        val data = WidgetData.load(context)
        for ((cls, mode) in listWidgets) {
            for (id in mgr.getAppWidgetIds(ComponentName(context, cls))) updateList(context, mgr, id, mode, data)
        }
        for (id in mgr.getAppWidgetIds(ComponentName(context, CountWidget::class.java))) {
            updateCount(context, mgr, id, data)
        }
    }

    fun updateList(context: Context, mgr: AppWidgetManager, id: Int, mode: ListMode, data: WidgetData) {
        val v = RemoteViews(context.packageName, R.layout.widget_list)
        val cfg = WidgetConfig.load(context, id)
        val look = WidgetLook(context, cfg, data)
        val (title, count, empty) = when (mode) {
            ListMode.TODAY -> Triple(
                data.title(data.label("today", "Heute"), cfg.cats),
                data.dueToday(cfg.cats).size.toString(),
                data.label("nothingDue", "Nichts fällig."),
            )
            ListMode.UPCOMING -> Triple(
                data.title(data.label("upcoming", "Demnächst"), cfg.cats),
                data.tasks(cfg.cats).size.toString(),
                data.label("nothingDue", "Nichts fällig."),
            )
            ListMode.HABITS -> Triple(
                data.label("habits", "Gewohnheiten"),
                "${data.habits.count { data.today in it.days }}/${data.habits.size}",
                data.label("noHabits", "Noch keine Gewohnheiten."),
            )
        }
        look.background(v)
        v.setTextViewText(R.id.title, title)
        look.text(v, R.id.title) { it.text }
        v.setTextViewText(R.id.count, count)
        look.text(v, R.id.count) { it.accent }
        v.setTextViewText(R.id.empty, empty)
        look.text(v, R.id.empty) { it.sub }
        look.tint(v, R.id.plus) { it.accent }
        v.setContentDescription(R.id.plus, data.label("newTask", "Neue Aufgabe"))
        v.setViewVisibility(R.id.plus, if (mode == ListMode.HABITS) View.GONE else View.VISIBLE)

        // Jede Liste braucht eine eigene Adresse, sonst teilt Android sie zwischen den Widgets.
        val service = Intent(context, WidgetListService::class.java)
            .putExtra(EXTRA_MODE, mode.name)
            .putExtra(EXTRA_ID, id)
            .setData(Uri.parse("todoliste://widget/${mode.name}/$id"))
        @Suppress("DEPRECATION")
        v.setRemoteAdapter(R.id.list, service)
        v.setEmptyView(R.id.list, R.id.empty)

        v.setOnClickPendingIntent(R.id.header, openApp(context, null))
        v.setOnClickPendingIntent(R.id.empty, openApp(context, null))
        v.setOnClickPendingIntent(R.id.plus, openApp(context, ACTION_NEW_TASK))
        // Zeile antippen: Aufgaben öffnen die App, Gewohnheiten werden gleich im Widget abgehakt.
        v.setPendingIntentTemplate(
            R.id.list,
            if (mode == ListMode.HABITS) toggleHabit(context) else openApp(context, null, mutable = true),
        )

        mgr.updateAppWidget(id, v)
        @Suppress("DEPRECATION")
        mgr.notifyAppWidgetViewDataChanged(id, R.id.list)
    }

    fun updateCount(context: Context, mgr: AppWidgetManager, id: Int, data: WidgetData) {
        val v = RemoteViews(context.packageName, R.layout.widget_count)
        val cfg = WidgetConfig.load(context, id)
        val look = WidgetLook(context, cfg, data)
        val due = data.dueToday(cfg.cats)
        val overdue = due.count(data::isLate)
        look.background(v)
        v.setTextViewText(R.id.number, due.size.toString())
        look.text(v, R.id.number) { it.accent }
        v.setTextViewText(R.id.label, data.label("today", "Heute"))
        look.text(v, R.id.label) { it.text }
        look.text(v, R.id.extra) { it.overdue }
        v.setViewVisibility(R.id.extra, if (overdue > 0) View.VISIBLE else View.GONE)
        v.setTextViewText(R.id.extra, "${data.label("overdue", "Überfällig")}: $overdue")
        v.setOnClickPendingIntent(R.id.root, openApp(context, null))
        mgr.updateAppWidget(id, v)
    }

    /** Vorlage für die Zeilen des Gewohnheiten-Widgets; welche Gewohnheit, trägt die Zeile ein. */
    private fun toggleHabit(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context,
        3,
        Intent(context, HabitToggleReceiver::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
    )

    /** Öffnet die App; mit [action] „new_task“ gleich mit dem Sheet für eine neue Aufgabe. */
    private fun openApp(context: Context, action: String?, mutable: Boolean = false): PendingIntent {
        val intent = Intent(context, MainActivity::class.java)
            .setAction("at.todoliste.todo_liste.WIDGET_${action ?: "open"}")
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        if (action != null) intent.putExtra(EXTRA_ACTION, action)
        // Die Vorlage für Listenzeilen muss veränderbar sein, weil Android die Zeile einträgt.
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            (if (mutable) PendingIntent.FLAG_MUTABLE else PendingIntent.FLAG_IMMUTABLE)
        return PendingIntent.getActivity(context, if (mutable) 2 else if (action == null) 0 else 1, intent, flags)
    }
}

abstract class BaseWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, mgr: AppWidgetManager, ids: IntArray) = Widgets.updateAll(context)

    /** Widget vom Startbildschirm entfernt: seine Einstellungen löschen. */
    override fun onDeleted(context: Context, ids: IntArray) = WidgetConfig.delete(context, ids)
}

/** Überfällige und heute fällige Aufgaben. */
class TodayWidget : BaseWidget()

/** Alle offenen Aufgaben nach Fälligkeit. */
class UpcomingWidget : BaseWidget()

/** Gewohnheiten mit Haken für heute. */
class HabitsWidget : BaseWidget()

/** Zahl der heute offenen Aufgaben. */
class CountWidget : BaseWidget()
