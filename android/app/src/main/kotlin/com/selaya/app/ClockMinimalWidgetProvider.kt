package com.selaya.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

/** Minimal digital-clock widget (#15). The TextClocks tick on their own, so we
 *  only inflate the layout and wire the tap-to-open intent. */
class ClockMinimalWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.clock_minimal).apply {
                launchAppPendingIntent(context)?.let {
                    setOnClickPendingIntent(R.id.widget_root, it)
                }
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
