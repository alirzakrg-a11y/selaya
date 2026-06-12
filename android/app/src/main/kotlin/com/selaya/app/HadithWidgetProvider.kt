package com.selaya.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

/**
 * Home-screen widget showing the daily hadith. Reads data written from Dart by
 * the `home_widget` package into its "HomeWidgetPreferences" store — so this
 * provider has no compile dependency on the plugin's Kotlin classes.
 */
class HadithWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences("selaya_widget", Context.MODE_PRIVATE)
        val text = prefs.getString("text", "Ameller ancak niyetlere göredir.")
        val ref = prefs.getString("ref", "Buhârî & Müslim")
        val label = prefs.getString("label", "Günün Hadisi")

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.hadith_widget).apply {
                setTextViewText(R.id.widget_label, label)
                setTextViewText(R.id.widget_text, text)
                setTextViewText(R.id.widget_ref, ref)

                val launchIntent =
                    context.packageManager.getLaunchIntentForPackage(context.packageName)
                if (launchIntent != null) {
                    val pendingIntent = PendingIntent.getActivity(
                        context,
                        0,
                        launchIntent,
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                    )
                    setOnClickPendingIntent(R.id.widget_root, pendingIntent)
                }
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
