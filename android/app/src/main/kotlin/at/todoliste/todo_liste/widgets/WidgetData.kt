package at.todoliste.todo_liste.widgets

import android.content.Context
import android.graphics.Color
import org.json.JSONObject
import java.util.Calendar

/**
 * Eine offene Aufgabe, wie die App sie ins Widget schreibt.
 * [day] ist der Tag, ab dem sie in der Liste steht (Abgabe minus Vorlauf der Kategorie),
 * [due] der Abgabetag.
 */
data class WTask(
    val title: String,
    val day: Int,
    val due: Int,
    val minutes: Int?,
    val color: Int,
    val cat: String,
)

/** Eine Kategorie (für die Auswahl „nur diese Kategorien“ je Widget). */
data class WCat(val id: String, val name: String)

/** Eine Gewohnheit mit den erledigten Tagen der letzten zwei Wochen. */
data class WHabit(val id: String, val name: String, val color: Int, val days: Set<Int>)

/**
 * Zusammenfassung der App-Daten für die Widgets.
 *
 * Die Flutter-App legt sie als JSON in ihren Einstellungen ab (lib/services/home_widgets.dart).
 * „Heute“ steht absichtlich nicht drin: Das Widget rechnet selbst, damit es auch nach
 * Mitternacht stimmt, wenn die App nicht läuft.
 */
class WidgetData private constructor(
    private val allTasks: List<WTask>,
    private val categories: List<WCat>,
    val habits: List<WHabit>,
    private val labels: Map<String, String>,
    private val weekdays: List<String>,
    private val english: Boolean,
    private val accentLight: Int?,
    private val accentDark: Int?,
) {
    val today: Int = todayIndex()

    fun label(key: String, fallback: String): String = labels[key] ?: fallback

    /** Die gewählten Kategorien, die es noch gibt (gelöschte zählen nicht mehr). */
    private fun chosen(cats: Set<String>): List<WCat> = categories.filter { it.id in cats }

    /** Offene Aufgaben dieses Widgets: alle oder nur die gewählten Kategorien. */
    fun tasks(cats: Set<String>): List<WTask> {
        val ids = chosen(cats).map { it.id }.toSet()
        return if (ids.isEmpty()) allTasks else allTasks.filter { it.cat in ids }
    }

    /** Was heute in der Liste der App steht: Überfälliges und alles, was heute dran ist. */
    fun dueToday(cats: Set<String>): List<WTask> = tasks(cats).filter { it.day <= today }

    /** Überfällig wie in der App: erst wenn die Abgabe vorbei ist (ohne Uhrzeit gilt der ganze Tag). */
    fun isLate(t: WTask): Boolean {
        if (t.due < today) return true
        val m = t.minutes ?: return false
        val c = Calendar.getInstance()
        return t.due == today && m < c.get(Calendar.HOUR_OF_DAY) * 60 + c.get(Calendar.MINUTE)
    }

    /** Titel mit den gewählten Kategorien dahinter, z. B. „Heute · Test, Termin“. */
    fun title(base: String, cats: Set<String>): String {
        val names = chosen(cats).map { it.name }
        return if (names.isEmpty()) base else base + " · " + names.joinToString(", ")
    }

    /** Akzentfarbe des App-Themes für hell bzw. dunkel (null: noch keine Daten von der App). */
    fun accent(dark: Boolean): Int? = if (dark) accentDark else accentLight

    /** „Heute“, „Morgen“, „Gestern“, sonst „Mo 24.11.“ bzw. „Mo 11/24“. */
    fun dayLabel(day: Int): String = when (day - today) {
        0 -> label("today", "Heute")
        1 -> label("tomorrow", "Morgen")
        -1 -> label("yesterday", "Gestern")
        else -> {
            val (_, m, d) = civilFromDays(day)
            val wd = weekdays.getOrNull(Math.floorMod(day + 3, 7)) ?: ""
            if (english) "$wd $m/$d" else "$wd $d.$m."
        }
    }

    fun timeLabel(minutes: Int): String = "%02d:%02d".format(minutes / 60, minutes % 60)

    /**
     * Zweite Zeile einer Aufgabe: Abgabetag und, falls gesetzt, Uhrzeit. Ohne [withDay]
     * (Widget „Heute“) steht der Tag nur da, wenn die Abgabe nicht heute ist.
     */
    fun subLabel(t: WTask, withDay: Boolean): String {
        val parts = ArrayList<String>()
        if (isLate(t)) parts += label("overdue", "Überfällig")
        val day = if (withDay || t.due != today) dayLabel(t.due) else null
        val time = t.minutes?.let(::timeLabel)
        listOfNotNull(day, time).joinToString(", ").takeIf { it.isNotEmpty() }?.let { parts += it }
        return parts.joinToString(" · ")
    }

    companion object {
        /** Datei und Schlüssel, unter denen das Flutter-Paket shared_preferences speichert. */
        private const val PREFS = "FlutterSharedPreferences"
        private const val KEY = "flutter.widget.v1"

        /** Die Zusammenfassung als JSON-Text, wie die App sie zuletzt geschrieben hat. */
        fun raw(context: Context): String? =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null)

        /** Nur für „Gewohnheit im Widget abhaken“: Haken sofort zeigen, bis die App nachzieht. */
        fun save(context: Context, json: String) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, json).commit()
        }

        fun load(context: Context): WidgetData {
            val raw = raw(context)
            return try {
                parse(JSONObject(raw ?: "{}"))
            } catch (e: Exception) {
                // Kaputte oder alte Daten: leeres Widget statt Absturz.
                parse(JSONObject())
            }
        }

        private fun parse(o: JSONObject): WidgetData {
            val tasks = ArrayList<WTask>()
            o.optJSONArray("tasks")?.let { a ->
                for (i in 0 until a.length()) {
                    val t = a.getJSONObject(i)
                    val due = parseDay(t.optString("d")) ?: continue
                    tasks += WTask(
                        title = t.optString("t"),
                        day = parseDay(t.optString("s")) ?: due,
                        due = due,
                        minutes = if (t.isNull("m")) null else t.optInt("m"),
                        color = parseColor(t.optString("c")) ?: Color.GRAY,
                        cat = t.optString("k"),
                    )
                }
            }
            val cats = ArrayList<WCat>()
            o.optJSONArray("cats")?.let { a ->
                for (i in 0 until a.length()) {
                    val c = a.getJSONObject(i)
                    cats += WCat(c.optString("id"), c.optString("n"))
                }
            }
            val habits = ArrayList<WHabit>()
            o.optJSONArray("habits")?.let { a ->
                for (i in 0 until a.length()) {
                    val h = a.getJSONObject(i)
                    val days = HashSet<Int>()
                    h.optJSONArray("days")?.let { d ->
                        for (j in 0 until d.length()) parseDay(d.optString(j))?.let(days::add)
                    }
                    habits += WHabit(h.optString("id"), h.optString("n"), parseColor(h.optString("c")) ?: Color.GRAY, days)
                }
            }
            val labels = HashMap<String, String>()
            o.optJSONObject("labels")?.let { l -> l.keys().forEach { k -> labels[k] = l.optString(k) } }
            val wd = ArrayList<String>()
            o.optJSONArray("wd")?.let { a -> for (i in 0 until a.length()) wd += a.optString(i) }
            return WidgetData(
                allTasks = tasks,
                categories = cats,
                habits = habits,
                labels = labels,
                weekdays = wd,
                english = o.optBoolean("en", false),
                accentLight = parseColor(o.optString("accent")),
                accentDark = parseColor(o.optString("accentDark")),
            )
        }

        private fun parseColor(hex: String): Int? = try {
            if (hex.isEmpty()) null else Color.parseColor(hex)
        } catch (e: IllegalArgumentException) {
            null
        }

        /** „2026-11-18“ → fortlaufende Tagesnummer (Tage seit 1.1.1970). */
        private fun parseDay(iso: String): Int? {
            val p = iso.split("-")
            if (p.size != 3) return null
            val y = p[0].toIntOrNull() ?: return null
            val m = p[1].toIntOrNull() ?: return null
            val d = p[2].toIntOrNull() ?: return null
            return daysFromCivil(y, m, d)
        }

        private fun todayIndex(): Int {
            val c = Calendar.getInstance()
            return daysFromCivil(c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH))
        }

        // Kalenderrechnung ohne Zeitzonen (Algorithmus von Howard Hinnant).
        private fun daysFromCivil(year: Int, m: Int, d: Int): Int {
            val y = if (m <= 2) year - 1 else year
            val era = Math.floorDiv(y, 400)
            val yoe = y - era * 400
            val doy = (153 * (m + (if (m > 2) -3 else 9)) + 2) / 5 + d - 1
            val doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
            return era * 146097 + doe - 719468
        }

        private fun civilFromDays(days: Int): Triple<Int, Int, Int> {
            val z = days + 719468
            val era = Math.floorDiv(z, 146097)
            val doe = z - era * 146097
            val yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
            val doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
            val mp = (5 * doy + 2) / 153
            val d = doy - (153 * mp + 2) / 5 + 1
            val m = if (mp < 10) mp + 3 else mp - 9
            val y = yoe + era * 400 + (if (m <= 2) 1 else 0)
            return Triple(y, m, d)
        }
    }
}
