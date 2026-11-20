package at.todoliste.todo_liste.widgets

import android.content.Context
import android.content.res.Configuration
import android.graphics.Color
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import at.todoliste.todo_liste.R
import org.json.JSONException
import org.json.JSONObject

/** Form des Hintergrunds. */
enum class WidgetShape(val drawable: Int) {
    ROUND(R.drawable.widget_bg),
    SOFT(R.drawable.widget_bg_soft),
    SQUARE(R.drawable.widget_bg_square),
}

enum class WidgetMode { SYSTEM, LIGHT, DARK }

/**
 * Einstellungen eines einzelnen Widgets (welche Kategorien, Hintergrund, Form, hell/dunkel,
 * Durchsichtigkeit, Farbe). Geschrieben vom Einstellungsfenster der App
 * (lib/services/widget_config.dart), hier nur gelesen.
 */
class WidgetConfig private constructor(
    /** Nur diese Kategorien zeigen; leer = alle. */
    val cats: Set<String>,
    val background: Boolean,
    val shape: WidgetShape,
    val mode: WidgetMode,
    /** Durchsichtigkeit des Hintergrunds in Prozent. */
    val transparency: Int,
    /** Was ein Listen-Widget zeigt; null = wie beim Hinzufügen gewählt. */
    val content: ListMode?,
    private val bgLight: Int?,
    private val bgDark: Int?,
    private val accentLight: Int?,
    private val accentDark: Int?,
) {
    fun bg(dark: Boolean): Int? = if (dark) bgDark else bgLight
    fun accent(dark: Boolean): Int? = if (dark) accentDark else accentLight

    companion object {
        private const val PREFS = "widget_config"

        private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        /** Gespeichertes JSON dieses Widgets oder null, wenn es noch nie eingestellt wurde. */
        fun raw(context: Context, id: Int): String? = prefs(context).getString(id.toString(), null)

        fun load(context: Context, id: Int): WidgetConfig = try {
            parse(JSONObject(raw(context, id) ?: "{}"))
        } catch (e: JSONException) {
            parse(JSONObject())
        }

        /** Speichert nur gültiges JSON; alles andere wird abgelehnt. */
        fun save(context: Context, id: Int, json: String): Boolean = try {
            JSONObject(json)
            prefs(context).edit().putString(id.toString(), json).commit()
        } catch (e: JSONException) {
            false
        }

        /** Entfernte Widgets: Einstellungen wegräumen. */
        fun delete(context: Context, ids: IntArray) {
            val edit = prefs(context).edit()
            for (id in ids) edit.remove(id.toString())
            edit.apply()
        }

        private fun parse(o: JSONObject): WidgetConfig {
            val cats = HashSet<String>()
            o.optJSONArray("cats")?.let { a -> for (i in 0 until a.length()) cats += a.optString(i) }
            return WidgetConfig(
                cats = cats,
                background = o.optBoolean("bg", true),
                shape = enumOr(o.optString("shape"), WidgetShape.ROUND),
                mode = enumOr(o.optString("mode"), WidgetMode.SYSTEM),
                transparency = o.optInt("alpha", 0).coerceIn(0, 100),
                content = enumValues<ListMode>().firstOrNull { it.name.equals(o.optString("content"), ignoreCase = true) },
                bgLight = color(o, "bgLight"),
                bgDark = color(o, "bgDark"),
                accentLight = color(o, "accentLight"),
                accentDark = color(o, "accentDark"),
            )
        }

        private inline fun <reified T : Enum<T>> enumOr(name: String, fallback: T): T =
            enumValues<T>().firstOrNull { it.name.equals(name, ignoreCase = true) } ?: fallback

        private fun color(o: JSONObject, key: String): Int? = try {
            o.optString(key).takeIf { it.isNotEmpty() }?.let(Color::parseColor)
        } catch (e: IllegalArgumentException) {
            null
        }
    }
}

/** Farben eines Widgets in einem Modus (hell oder dunkel). */
class WidgetPalette(val bg: Int, val text: Int, val sub: Int, val accent: Int, val overdue: Int)

/**
 * Aussehen eines Widgets: Farben für hell und dunkel, Form und Durchsichtigkeit.
 *
 * Steht das Widget auf „System“, bekommt Android (ab 12) beide Farben mit – dann wechselt
 * es mit dem Dunkelmodus des Telefons mit, ohne dass die App neu zeichnen muss.
 */
class WidgetLook(context: Context, private val cfg: WidgetConfig, data: WidgetData) {
    private val light = palette(context, data, dark = false)
    private val dark = palette(context, data, dark = true)
    private val systemDark =
        (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES

    private val current: WidgetPalette
        get() = when (cfg.mode) {
            WidgetMode.LIGHT -> light
            WidgetMode.DARK -> dark
            WidgetMode.SYSTEM -> if (systemDark) dark else light
        }

    private fun palette(context: Context, data: WidgetData, dark: Boolean): WidgetPalette {
        // Die Grundfarben stehen in res/values(-night)/widget_colors.xml – hier für den gewünschten Modus geholt.
        val conf = Configuration(context.resources.configuration)
        conf.uiMode = (conf.uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or
            (if (dark) Configuration.UI_MODE_NIGHT_YES else Configuration.UI_MODE_NIGHT_NO)
        val c = context.createConfigurationContext(conf)
        return WidgetPalette(
            bg = cfg.bg(dark) ?: c.getColor(R.color.widget_bg),
            text = c.getColor(R.color.widget_text),
            sub = c.getColor(R.color.widget_sub),
            accent = cfg.accent(dark) ?: data.accent(dark) ?: c.getColor(R.color.widget_accent),
            overdue = c.getColor(R.color.widget_overdue),
        )
    }

    /** Ruft [method] (nimmt eine Farbe) an der View auf – passend zu hell/dunkel. */
    fun color(v: RemoteViews, viewId: Int, method: String, pick: (WidgetPalette) -> Int) {
        if (cfg.mode == WidgetMode.SYSTEM && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            v.setColorInt(viewId, method, pick(light), pick(dark))
        } else {
            v.setInt(viewId, method, pick(current))
        }
    }

    fun text(v: RemoteViews, viewId: Int, pick: (WidgetPalette) -> Int) = color(v, viewId, "setTextColor", pick)
    fun tint(v: RemoteViews, viewId: Int, pick: (WidgetPalette) -> Int) = color(v, viewId, "setColorFilter", pick)

    /**
     * Der Startbildschirm schneidet jedes Widget an den Ecken rund ab (bei Samsung immer).
     * Damit „weich“ und „eckig“ trotzdem zu sehen sind, rückt der Hintergrund so weit nach
     * innen, dass seine Ecken innerhalb dieser Rundung liegen.
     */
    private val inset: Int = run {
        val res = context.resources
        val outer = res.getDimension(R.dimen.widget_radius)
        val own = when (cfg.shape) {
            WidgetShape.ROUND -> outer
            WidgetShape.SOFT -> res.getDimension(R.dimen.widget_radius_soft)
            WidgetShape.SQUARE -> 0f
        }
        // Abstand der Ecke eines Quadrats zum Kreisbogen: r · (1 − 1/√2) ≈ 0,3 · r
        if (!cfg.background || own >= outer) 0 else Math.ceil((outer - own) * 0.3 + res.displayMetrics.density).toInt()
    }

    /** Hintergrund: Form, Farbe, Durchsichtigkeit – oder ganz weg. */
    fun background(v: RemoteViews) {
        v.setViewPadding(R.id.root, inset, inset, inset, inset)
        v.setViewVisibility(android.R.id.background, if (cfg.background) View.VISIBLE else View.GONE)
        if (!cfg.background) return
        v.setImageViewResource(android.R.id.background, cfg.shape.drawable)
        tint(v, android.R.id.background) { it.bg or 0xFF000000.toInt() }
        v.setInt(android.R.id.background, "setImageAlpha", 255 * (100 - cfg.transparency) / 100)
    }
}
