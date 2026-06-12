package com.selaya.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

/** İslami Yeşil digital-clock widget (#15) — same self-ticking clock on a green
 *  glass background with gold time. */
class ClockGreenWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.clock_green).apply {
                launchAppPendingIntent(context)?.let {
                    setOnClickPendingIntent(R.id.widget_root, it)
                }
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
