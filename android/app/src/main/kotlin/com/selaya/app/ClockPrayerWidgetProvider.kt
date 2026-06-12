package com.selaya.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.os.SystemClock
import android.widget.RemoteViews

/** Prayer-focused clock widget (#15): a self-ticking time, the next prayer, and
 *  a LIVE count-down. The Chronometer counts down (API 24+) to the next prayer;
 *  its base is the wall-clock target translated into elapsedRealtime. The next
 *  prayer + epoch + localized labels come from the shared "selaya_widget" store. */
class ClockPrayerWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences("selaya_widget", Context.MODE_PRIVATE)
        val nextLabel = prefs.getString("prayer_next_label", "") ?: ""
        val remainingLabel = prefs.getString("prayer_remaining_label", "") ?: ""
        val epoch = prefs.getString("prayer_next_epoch", "0")?.toLongOrNull() ?: 0L
        val base = SystemClock.elapsedRealtime() + (epoch - System.currentTimeMillis())

        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.clock_prayer).apply {
                if (nextLabel.isNotEmpty()) setTextViewText(R.id.widget_cp_next, nextLabel)
                if (remainingLabel.isNotEmpty()) {
                    setTextViewText(R.id.widget_cp_label, remainingLabel)
                }
                setChronometerCountDown(R.id.widget_cp_count, true)
                setChronometer(R.id.widget_cp_count, base, "%s", epoch > 0L)
                launchAppPendingIntent(context)?.let {
                    setOnClickPendingIntent(R.id.widget_root, it)
                }
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
