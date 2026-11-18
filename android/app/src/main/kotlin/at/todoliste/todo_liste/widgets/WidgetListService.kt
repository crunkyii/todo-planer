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
        return Factory(applicationContext, mode, id)
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
            tasks = if (mode == ListMode.TODAY) data.dueToday(cfg.cats) else data.tasks(cfg.cats)
        }

        override fun onDestroy() {}

        override fun getCount(): Int = if (mode == ListMode.HABITS) data.habits.size else tasks.size

        override fun getViewAt(position: Int): RemoteViews {
            val v = RemoteViews(context.packageName, R.layout.widget_row)
            look.text(v, R.id.text) { it.text }
            if (mode == ListMode.HABITS) {
                val h = data.habits.getOrNull(position) ?: return v
                val done = data.today in h.days
                v.setTextViewText(R.id.text, h.name)
                v.setInt(R.id.bar, "setColorFilter", h.color)
                v.setViewVisibility(R.id.sub, View.GONE)
                v.setViewVisibility(R.id.mark, View.VISIBLE)
                v.setImageViewResource(R.id.mark, if (done) R.drawable.widget_check else R.drawable.widget_circle)
                look.tint(v, R.id.mark) { if (done) h.color else it.sub }
            } else {
                val t = tasks.getOrNull(position) ?: return v
                val sub = data.subLabel(t, withDay = mode == ListMode.UPCOMING)
                v.setTextViewText(R.id.text, t.title)
                v.setInt(R.id.bar, "setColorFilter", t.color)
                v.setTextViewText(R.id.sub, sub)
                v.setViewVisibility(R.id.sub, if (sub.isEmpty()) View.GONE else View.VISIBLE)
                look.text(v, R.id.sub) { if (t.day < data.today) it.overdue else it.sub }
                v.setViewVisibility(R.id.mark, View.GONE)
            }
            // Tippen auf die Zeile öffnet die App (füllt die Vorlage des Widgets aus).
            v.setOnClickFillInIntent(R.id.row, Intent())
            return v
        }

        override fun getLoadingView(): RemoteViews? = null
        override fun getViewTypeCount(): Int = 1
        override fun getItemId(position: Int): Long = position.toLong()
        override fun hasStableIds(): Boolean = false
    }
}
