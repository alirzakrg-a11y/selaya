package com.selaya.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.view.View
import android.widget.RemoteViews

/** Home-screen widget: today's Hijri date + Gregorian + an optional upcoming
 *  religious-day note. Tapping opens the app. */
class HijriWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences("selaya_widget", Context.MODE_PRIVATE)
        val date = prefs.getString("hijri_date", "—") ?: "—"
        val greg = prefs.getString("hijri_greg", "") ?: ""
        val event = prefs.getString("hijri_event", "") ?: ""

        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.hijri_widget).apply {
                setTextViewText(R.id.widget_hijri_date, date)
                setTextViewText(R.id.widget_hijri_greg, greg)
                setTextViewText(R.id.widget_hijri_event, event)
                setViewVisibility(
                    R.id.widget_hijri_event,
                    if (event.isBlank()) View.GONE else View.VISIBLE
                )
                launchAppPendingIntent(context)?.let {
                    setOnClickPendingIntent(R.id.widget_root, it)
                }
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
