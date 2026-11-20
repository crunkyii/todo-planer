package at.todoliste.todo_liste.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import at.todoliste.todo_liste.R

/** Liefert die Zeilen der Listen-Widgets (Android holt sie über diesen Dienst). */
class WidgetListService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        val mode = try {
            ListMode.valueOf(intent.getStringExtra(Widgets.EXTRA_MODE) ?: "")
        } catch (e: IllegalArgumentException) {
            ListMode.TODAY
        }
        val id = intent.getIntExtra(Widgets.EXTRA_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        if (intent.getBooleanExtra(Widgets.EXTRA_COUNT, false)) return CountFactory(applicationContext, id)
        return Factory(applicationContext, mode, id)
    }

    /** Der Zähler „1/2“ im Kopf des Gewohnheiten-Widgets: eine Liste mit genau einer Zeile. */
    private class CountFactory(private val context: Context, private val widgetId: Int) : RemoteViewsFactory {
        private lateinit var data: WidgetData
        private lateinit var look: WidgetLook

        override fun onCreate() = onDataSetChanged()

        override fun onDataSetChanged() {
            data = WidgetData.load(context)
            look = WidgetLook(context, WidgetConfig.load(context, widgetId), data)
        }

        override fun onDestroy() {}
        override fun getCount(): Int = 1

        override fun getViewAt(position: Int): RemoteViews =
            RemoteViews(context.packageName, R.layout.widget_count_item).also {
                it.setTextViewText(R.id.count_text, Widgets.habitCount(data))
                look.text(it, R.id.count_text) { p -> p.accent }
                it.setOnClickFillInIntent(R.id.count_text, Intent())
            }

        override fun getLoadingView(): RemoteViews = RemoteViews(context.packageName, R.layout.widget_count_item)
        override fun getViewTypeCount(): Int = 1
        override fun getItemId(position: Int): Long = 0
        override fun hasStableIds(): Boolean = true
    }

    private class Factory(
        private val context: Context,
        private val mode: ListMode,
        private val widgetId: Int,
    ) : RemoteViewsFactory {
        private lateinit var data: WidgetData
        private lateinit var look: WidgetLook
        private var tasks: List<WTask> = emptyList()

        override fun onCreate() = onDataSetChanged()

        override fun onDataSetChanged() {
            val cfg = WidgetConfig.load(context, widgetId)
            data = WidgetData.load(context)
            look = WidgetLook(context, cfg, data)
            tasks = if (mode == ListMode.TODAY) data.dueToday(cfg.cats) else data.upcoming(cfg.cats, cfg.range)
        }

        override fun onDestroy() {}

        override fun getCount(): Int = if (mode == ListMode.HABITS) data.habits.size else tasks.size

        override fun getViewAt(position: Int): RemoteViews {
            val v = RemoteViews(context.packageName, R.layout.widget_row)
            look.text(v, R.id.text) { it.text }
            // Android füllt dieselbe Zeile wieder, die vorher „lädt“ gezeigt hat: Streifen wieder zeigen.
            v.setViewVisibility(R.id.bar, View.VISIBLE)
            if (mode == ListMode.HABITS) {
                val h = data.habits.getOrNull(position) ?: return v
                val done = data.today in h.days
                v.setTextViewText(R.id.text, h.name)
                v.setInt(R.id.bar, "setColorFilter", h.color)
                v.setViewVisibility(R.id.sub, View.GONE)
                v.setViewVisibility(R.id.mark, View.VISIBLE)
                v.setInt(R.id.row, "setBackgroundResource", 0)
                v.setImageViewResource(R.id.mark, if (done) R.drawable.widget_check else R.drawable.widget_circle)
                look.tint(v, R.id.mark) { if (done) h.color else it.sub }
            } else {
                val t = tasks.getOrNull(position) ?: return v
                val sub = data.subLabel(t, withDay = mode == ListMode.UPCOMING)
                v.setTextViewText(R.id.text, t.title)
                v.setInt(R.id.bar, "setColorFilter", t.color)
                v.setTextViewText(R.id.sub, sub)
                v.setViewVisibility(R.id.sub, if (sub.isEmpty()) View.GONE else View.VISIBLE)
                val late = data.isLate(t)
                look.text(v, R.id.sub) { if (late) it.overdue else it.sub }
                v.setViewVisibility(R.id.mark, View.GONE)
                // Aufgaben öffnen die App: Splash über die ganze Zeile.
                v.setInt(R.id.row, "setBackgroundResource", R.drawable.widget_row_ripple)
            }
            // Tippen auf die Zeile füllt die Vorlage des Widgets aus: Aufgaben öffnen die App,
            // Gewohnheiten werden abgehakt (dafür steht hier, welche gemeint ist).
            val fill = Intent()
            if (mode == ListMode.HABITS) data.habits.getOrNull(position)?.let { fill.putExtra(Widgets.EXTRA_HABIT, it.id) }
            v.setOnClickFillInIntent(R.id.row, fill)
            return v
        }

        // Solange Android die Zeilen holt, leere Zeilen zeigen statt „Wird geladen…“.
        override fun getLoadingView(): RemoteViews = RemoteViews(context.packageName, R.layout.widget_row).also {
            it.setViewVisibility(R.id.bar, View.INVISIBLE)
            it.setViewVisibility(R.id.sub, View.GONE)
        }
        override fun getViewTypeCount(): Int = 1
        override fun getItemId(position: Int): Long = position.toLong()
        override fun hasStableIds(): Boolean = false
    }
}
