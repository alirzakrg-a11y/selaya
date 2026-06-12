package com.selaya.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import org.json.JSONArray

/** Home-screen widget: a Name of Allah (Arabic + transliteration + meaning) from
 *  a list Dart pushed as JSON (`esma_list`). Tapping cycles to the next name. */
class EsmaWidgetProvider : AppWidgetProvider() {
    companion object {
        const val ACTION_NEXT = "com.selaya.app.ESMA_NEXT"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        appWidgetIds.forEach { render(context, appWidgetManager, it) }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_NEXT) {
            val prefs = context.getSharedPreferences("selaya_widget", Context.MODE_PRIVATE)
            val arr = parse(prefs.getString("esma_list", "[]"))
            if (arr.length() > 0) {
                val idx = (prefs.getInt("esma_idx", 0) + 1) % arr.length()
                prefs.edit().putInt("esma_idx", idx).apply()
            }
            val manager = AppWidgetManager.getInstance(context)
            manager.getAppWidgetIds(ComponentName(context, EsmaWidgetProvider::class.java))
                .forEach { render(context, manager, it) }
        }
    }

    private fun render(context: Context, manager: AppWidgetManager, id: Int) {
        val prefs = context.getSharedPreferences("selaya_widget", Context.MODE_PRIVATE)
        val arr = parse(prefs.getString("esma_list", "[]"))
        val views = RemoteViews(context.packageName, R.layout.esma_widget)
        if (arr.length() > 0) {
            val idx = prefs.getInt("esma_idx", 0).coerceIn(0, arr.length() - 1)
            arr.optJSONObject(idx)?.let { o ->
                views.setTextViewText(R.id.widget_esma_ar, o.optString("ar"))
                views.setTextViewText(R.id.widget_esma_tr, o.optString("tr"))
                views.setTextViewText(R.id.widget_esma_mn, o.optString("mn"))
            }
        }
        val nextPI = PendingIntent.getBroadcast(
            context,
            0,
            Intent(context, EsmaWidgetProvider::class.java).apply { action = ACTION_NEXT },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        views.setOnClickPendingIntent(R.id.widget_root, nextPI)
        manager.updateAppWidget(id, views)
    }

    private fun parse(s: String?): JSONArray =
        try { JSONArray(s ?: "[]") } catch (e: Exception) { JSONArray() }
}
