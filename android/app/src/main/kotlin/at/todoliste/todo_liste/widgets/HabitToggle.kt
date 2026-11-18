package at.todoliste.todo_liste.widgets

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import at.todoliste.todo_liste.MainActivity
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject
import java.util.Calendar

/**
 * Tipp auf eine Gewohnheit im Widget: für heute abhaken (oder wieder öffnen), ohne die App zu öffnen.
 *
 * Das Widget kann die Datenbank der App nicht ändern. Darum passiert zweierlei:
 * 1. Die Zusammenfassung, aus der die Widgets zeichnen, wird sofort angepasst – der Haken ist gleich da.
 * 2. Der Wunsch kommt auf einen Merkzettel. Die App übernimmt ihn in ihre Daten (und den Abgleich
 *    mit anderen Geräten), sobald sie läuft – sofort, wenn sie im Hintergrund noch offen ist.
 */
class HabitToggleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val habitId = intent.getStringExtra(Widgets.EXTRA_HABIT) ?: return
        val app = context.applicationContext
        if (!HabitToggles.toggleToday(app, habitId)) return
        Widgets.updateAll(app)
        MainActivity.habitsChanged()
    }
}

object HabitToggles {
    private const val PREFS = "widget_actions"
    private const val KEY = "habit_toggles"

    /** Dreht „heute erledigt“ für die Gewohnheit um. false, wenn es sie nicht (mehr) gibt. */
    fun toggleToday(context: Context, habitId: String): Boolean {
        val today = todayIso()
        val done = try {
            val snap = JSONObject(WidgetData.raw(context) ?: return false)
            val habits = snap.optJSONArray("habits") ?: return false
            var result: Boolean? = null
            for (i in 0 until habits.length()) {
                val h = habits.getJSONObject(i)
                if (h.optString("id") != habitId) continue
                val old = h.optJSONArray("days") ?: JSONArray()
                val days = JSONArray()
                var was = false
                for (j in 0 until old.length()) {
                    if (old.optString(j) == today) was = true else days.put(old.optString(j))
                }
                if (!was) days.put(today)
                h.put("days", days)
                result = !was
            }
            if (result == null) return false
            WidgetData.save(context, snap.toString())
            result
        } catch (e: JSONException) {
            return false
        }
        // Merkzettel: je Gewohnheit und Tag der zuletzt gewünschte Zustand.
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val queue = try {
            JSONObject(prefs.getString(KEY, null) ?: "{}")
        } catch (e: JSONException) {
            JSONObject()
        }
        queue.put("$habitId|$today", done)
        prefs.edit().putString(KEY, queue.toString()).commit()
        return true
    }

    /** Gibt den Merkzettel an die App und leert ihn. */
    fun take(context: Context): String? {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val raw = prefs.getString(KEY, null) ?: return null
        prefs.edit().remove(KEY).commit()
        return raw
    }

    private fun todayIso(): String {
        val c = Calendar.getInstance()
        return "%04d-%02d-%02d".format(c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH))
    }
}
