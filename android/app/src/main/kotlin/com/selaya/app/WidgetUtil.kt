package com.selaya.app

import android.app.PendingIntent
import android.content.Context

/** PendingIntent that opens the NIDA app — shared by the home-screen widgets. */
fun launchAppPendingIntent(context: Context): PendingIntent? {
    val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        ?: return null
    return PendingIntent.getActivity(
        context,
        0,
        launch,
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
    )
}
