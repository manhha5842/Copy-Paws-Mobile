package com.example.copypaws

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.app.PendingIntent
import android.net.Uri
import android.widget.RemoteViews
import android.util.Log

class CopyPawsWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        Log.d("CopyPawsWidget", "onUpdate called with ids: ${appWidgetIds.joinToString()}")
        
        val widgetData = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        
        appWidgetIds.forEach { widgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                    val c0 = widgetData.getString("clip_0_content", "No clips yet")
                    val c1 = widgetData.getString("clip_1_content", "")
                    val c2 = widgetData.getString("clip_2_content", "")

                    Log.d("CopyPawsWidget", "Updating widget $widgetId: $c0")

                    setTextViewText(R.id.clip_0_content, c0)
                    setTextViewText(R.id.clip_1_content, c1)
                    setTextViewText(R.id.clip_2_content, c2)

                    // Helper for PendingIntents
                    fun getPendingIntent(action: String): PendingIntent {
                         val intent = Intent(context, MainActivity::class.java).apply {
                            data = Uri.parse("copypaws://$action")
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        }
                        return PendingIntent.getActivity(
                            context, 
                            action.hashCode(), 
                            intent, 
                            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                        )
                    }

                    setOnClickPendingIntent(R.id.btn_push, getPendingIntent("push"))
                    setOnClickPendingIntent(R.id.btn_pull, getPendingIntent("pull"))
                    setOnClickPendingIntent(R.id.widget_root, getPendingIntent("open"))
                }
                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (e: Exception) {
                Log.e("CopyPawsWidget", "Error updating widget $widgetId", e)
            }
        }
    }
}
