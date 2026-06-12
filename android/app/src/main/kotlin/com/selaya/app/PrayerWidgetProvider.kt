package com.selaya.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import org.json.JSONArray

/** Home-screen widget: city + next prayer + a 2x3 grid of the day's six times
 *  (the next one highlighted gold). Data comes from the shared "selaya_widget"
 *  store written by Dart. Tapping opens the app. */
class PrayerWidgetProvider : AppWidgetProvider() {
    private val nameIds = intArrayOf(
        R.id.widget_pw_1n, R.id.widget_pw_2n, R.id.widget_pw_3n,
        R.id.widget_pw_4n, R.id.widget_pw_5n, R.id.widget_pw_6n
    )
    private val timeIds = intArrayOf(
        R.id.widget_pw_1t, R.id.widget_pw_2t, R.id.widget_pw_3t,
        R.id.widget_pw_4t, R.id.widget_pw_5t, R.id.widget_pw_6t
    )

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences("selaya_widget", Context.MODE_PRIVATE)
        val city = prefs.getString("prayer_city", "") ?: ""
        val next = prefs.getString("prayer_next", "") ?: ""
        val nextName = prefs.getString("prayer_next_name", "") ?: ""
        val times = try {
            JSONArray(prefs.getString("prayer_times", "[]"))
        } catch (e: Exception) {
            JSONArray()
        }

        val gold = 0xFFE0B250.toInt()
        val white = 0xFFF4F6FB.toInt()
        val dim = 0xFF9AA3B8.toInt()

        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.prayer_widget).apply {
                setTextViewText(R.id.widget_pw_city, city)
                setTextViewText(R.id.widget_pw_next, next)
                for (i in 0 until 6) {
                    val o = times.optJSONObject(i)
                    val n = o?.optString("n") ?: ""
                    val t = o?.optString("t") ?: ""
                    setTextViewText(nameIds[i], n)
                    setTextViewText(timeIds[i], t)
                    val isNext = n.isNotEmpty() && n == nextName
                    setTextColor(timeIds[i], if (isNext) gold else white)
                    setTextColor(nameIds[i], if (isNext) gold else dim)
                }
                launchAppPendingIntent(context)?.let {
                    setOnClickPendingIntent(R.id.widget_root, it)
                }
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
