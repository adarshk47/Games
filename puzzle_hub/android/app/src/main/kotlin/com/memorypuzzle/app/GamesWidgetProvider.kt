package com.memorypuzzle.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widget: one row of 3 games. Tapping a game opens it directly
 * (masterg://game/<id>). The app writes the 3 games via home_widget
 * (keys g0_id, g0_emoji, g0_title ... g2_*).
 */
class GamesWidgetProvider : HomeWidgetProvider() {

    private val defaults = listOf(
        Triple("block_puzzle", "🧱", "Block Puzzle"),
        Triple("game_2048", "🔶", "2048"),
        Triple("sudoku", "🔢", "Sudoku"),
    )

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val slots = listOf(
            Triple(R.id.slot0, R.id.emoji0, R.id.title0),
            Triple(R.id.slot1, R.id.emoji1, R.id.title1),
            Triple(R.id.slot2, R.id.emoji2, R.id.title2),
        )
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.games_widget)
            slots.forEachIndexed { i, (slot, emoji, title) ->
                val id = widgetData.getString("g${i}_id", null) ?: defaults[i].first
                views.setTextViewText(emoji, widgetData.getString("g${i}_emoji", null) ?: defaults[i].second)
                views.setTextViewText(title, widgetData.getString("g${i}_title", null) ?: defaults[i].third)
                val open = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("masterg://game/$id"),
                )
                views.setOnClickPendingIntent(slot, open)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
