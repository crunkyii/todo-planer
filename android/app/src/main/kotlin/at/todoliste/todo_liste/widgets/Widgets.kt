package at.todoliste.todo_liste.widgets

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Typeface
import android.net.Uri
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.RelativeSizeSpan
import android.text.style.StyleSpan
import android.view.View
import android.widget.RemoteViews
import at.todoliste.todo_liste.MainActivity
import at.todoliste.todo_liste.R
import org.json.JSONException
import org.json.JSONObject

/** Welche Liste ein Listen-Widget zeigt. */
enum class ListMode { TODAY, UPCOMING, HABITS }

/** Zeichnet alle Widgets neu – nach jeder Änderung in der App und wenn Android es verlangt. */
object Widgets {
    const val EXTRA_ACTION = "widget_action"
    const val ACTION_NEW_TASK = "new_task"
    const val EXTRA_MODE = "mode"
    const val EXTRA_ID = "widget_id"
    const val EXTRA_HABIT = "habit_id"
    const val EXTRA_COUNT = "count_only"

    private val listWidgets = mapOf(
        TodayWidget::class.java to ListMode.TODAY,
        UpcomingWidget::class.java to ListMode.UPCOMING,
        HabitsWidget::class.java to ListMode.HABITS,
    )

    /** Die Daten, mit denen die Widgets zuletzt gezeichnet wurden (einheitlich geschrieben). */
    private var drawn: String? = null

    /** Gleicher Inhalt = gleicher Text, egal ob die App oder das Widget das JSON geschrieben hat. */
    private fun normalized(raw: String?): String? = try {
        raw?.let { JSONObject(it).toString() }
    } catch (e: JSONException) {
        raw
    }

    /**
     * Zeichnet alle Widgets neu. Der Startbildschirm baut ein Widget dabei komplett neu auf
     * (bei Samsung flackert die Liste kurz) – darum mit [onlyIfChanged] nichts tun, wenn die
     * Daten schon so angezeigt werden (z. B. nachdem im Widget selbst abgehakt wurde).
     */
    fun updateAll(context: Context, onlyIfChanged: Boolean = false) {
        val now = normalized(WidgetData.raw(context))
        if (onlyIfChanged && now != null && now == drawn) return
        drawn = now
        val mgr = AppWidgetManager.getInstance(context)
        val data = WidgetData.load(context)
        for ((cls, mode) in listWidgets) {
            for (id in mgr.getAppWidgetIds(ComponentName(context, cls))) updateList(context, mgr, id, mode, data)
        }
        val counts = mgr.getAppWidgetIds(ComponentName(context, CountWidget::class.java))
        for (id in counts) updateCount(context, mgr, id, data)
        val any = counts.isNotEmpty() || listWidgets.keys.any { mgr.getAppWidgetIds(ComponentName(context, it)).isNotEmpty() }
        scheduleRefresh(context, if (any) data.nextChangeMillis() else null)
    }

    /**
     * Die Widgets zeichnen sonst nur neu, wenn die App Daten schreibt (oder alle 30 Minuten).
     * Damit eine Aufgabe pünktlich auf „überfällig“ springt und um Mitternacht der neue Tag
     * stimmt, weckt Android die Widgets zu diesem Zeitpunkt ([at] = null: keine Widgets mehr).
     * Ungenauer Wecker: braucht keine Berechtigung und weckt das Telefon nicht extra auf.
     * Android erlaubt dafür höchstens „innerhalb von 10 Minuten“ – so spät kann es also werden.
     */
    private fun scheduleRefresh(context: Context, at: Long?) {
        val alarm = context.getSystemService(AlarmManager::class.java) ?: return
        val refresh = PendingIntent.getBroadcast(
            context,
            4,
            Intent(context, WidgetRefreshReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        if (at == null) alarm.cancel(refresh) else alarm.setWindow(AlarmManager.RTC, at, 10 * 60_000L, refresh)
    }

    /**
     * Im Widget wurde eine Gewohnheit abgehakt: nur die Zeilen und den Zähler der
     * Gewohnheiten-Widgets neu füllen. Das Widget selbst bleibt stehen, nichts flackert, und
     * die Tipp-Animation (Kreis wächst, Splash) läuft ungestört zu Ende.
     *
     * Der Zähler „1/2“ ist dafür eine eigene Liste mit einer Zeile: Jede andere Änderung an der
     * Kopfzeile (auch updateAppWidget nur für den Text) lässt den Samsung-Startbildschirm das
     * ganze Widget neu aufbauen – dann ist die Liste kurz leer.
     */
    fun habitToggled(context: Context) {
        val mgr = AppWidgetManager.getInstance(context)
        // Jedes Listen-Widget kann auf „Gewohnheiten“ gestellt sein, nicht nur das Gewohnheiten-Widget.
        val ids = listWidgets.flatMap { (cls, kind) ->
            mgr.getAppWidgetIds(ComponentName(context, cls)).filter {
                (WidgetConfig.load(context, it).content ?: kind) == ListMode.HABITS
            }
        }.toIntArray()
        @Suppress("DEPRECATION")
        mgr.notifyAppWidgetViewDataChanged(ids, R.id.list)
        @Suppress("DEPRECATION")
        mgr.notifyAppWidgetViewDataChanged(ids, R.id.count_list)
        drawn = normalized(WidgetData.raw(context))
    }

    fun habitCount(data: WidgetData): String =
        "${data.habits.count { data.today in it.days }}/${data.habits.size}"

    /** Zeichnet ein Listen-Widget; [kind] ist seine Art, gezeigt wird, was die Einstellungen sagen. */
    fun updateList(context: Context, mgr: AppWidgetManager, id: Int, kind: ListMode, data: WidgetData) {
        val v = RemoteViews(context.packageName, R.layout.widget_list)
        val cfg = WidgetConfig.load(context, id)
        val mode = cfg.content ?: kind
        val look = WidgetLook(context, cfg, data)
        val (title, count, empty) = when (mode) {
            ListMode.TODAY -> Triple(
                data.label("today", "Heute"),
                data.dueToday(cfg.cats).size.toString(),
                data.label("nothingDue", "Nichts fällig."),
            )
            ListMode.UPCOMING -> Triple(
                data.label("upcoming", "Demnächst"),
                data.tasks(cfg.cats).size.toString(),
                data.label("nothingDue", "Nichts fällig."),
            )
            ListMode.HABITS -> Triple(
                data.label("habits", "Gewohnheiten"),
                habitCount(data),
                data.label("noHabits", "Noch keine Gewohnheiten."),
            )
        }
        look.background(v)
        // Titel fett; im Widget „Heute“ daneben kleiner das Datum, dahinter die gewählten Kategorien.
        val heading = SpannableStringBuilder(title)
        if (mode == ListMode.TODAY) {
            heading.append(' ')
            val from = heading.length
            heading.append(data.dateLabel())
            heading.setSpan(RelativeSizeSpan(0.8f), from, heading.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        heading.setSpan(StyleSpan(Typeface.BOLD), 0, title.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        if (mode != ListMode.HABITS) {
            val from = heading.length
            heading.append(data.titleSuffix(cfg.cats))
            heading.setSpan(StyleSpan(Typeface.BOLD), from, heading.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        v.setTextViewText(R.id.title, heading)
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

        // Gewohnheiten: Zähler als eigene kleine Liste (siehe habitToggled).
        val habits = mode == ListMode.HABITS
        v.setViewVisibility(R.id.count, if (habits) View.GONE else View.VISIBLE)
        v.setViewVisibility(R.id.count_list, if (habits) View.VISIBLE else View.GONE)
        if (habits) {
            val counter = Intent(context, WidgetListService::class.java)
                .putExtra(EXTRA_MODE, mode.name)
                .putExtra(EXTRA_ID, id)
                .putExtra(EXTRA_COUNT, true)
                .setData(Uri.parse("todoliste://widget/${mode.name}/$id/count"))
            @Suppress("DEPRECATION")
            v.setRemoteAdapter(R.id.count_list, counter)
            v.setPendingIntentTemplate(R.id.count_list, openApp(context, null, mutable = true))
        }

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
        @Suppress("DEPRECATION")
        if (habits) mgr.notifyAppWidgetViewDataChanged(id, R.id.count_list)
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

/** Der Wecker aus [Widgets.updateAll]: alle Widgets neu zeichnen. */
class WidgetRefreshReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) = Widgets.updateAll(context.applicationContext)
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
