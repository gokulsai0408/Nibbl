package com.forkcast.forkcast

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Home-screen widget: today's calories and water, with Snap meal / +250 ml buttons. */
class NibblWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        fun text(key: String, fallback: String) = widgetData.getString(key, null) ?: fallback
        fun percent(key: String) = (widgetData.getString(key, null)?.toIntOrNull() ?: 0).coerceIn(0, 100)

        fun open(uri: String) =
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(uri))

        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.nibbl_widget).apply {
                setTextViewText(R.id.headline, text("headline", "Today"))
                setTextViewText(R.id.streak, text("streak", ""))
                setTextViewText(R.id.kcal_value, text("kcal_value", "–"))
                setTextViewText(R.id.kcal_label, text("kcal_label", "kcal left"))
                setProgressBar(R.id.kcal_bar, 100, percent("kcal_pct"), false)
                setTextViewText(R.id.water_text, text("water_text", "0.0 / 2.5 L"))
                setProgressBar(R.id.water_bar, 100, percent("water_pct"), false)
                setTextViewText(R.id.tip, text("tip", "Open Nibbl to start your day"))

                setOnClickPendingIntent(R.id.root, open("nibbl://home"))
                setOnClickPendingIntent(R.id.btn_snap, open("nibbl://log/photo"))
                setOnClickPendingIntent(R.id.btn_water, open("nibbl://water/add?ml=250"))
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
