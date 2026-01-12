package com.example.copypaws

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.app.PendingIntent
import android.widget.RemoteViews
import android.widget.Toast
import android.util.Log

class CopyPawsWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "CopyPawsWidget"
        const val ACTION_COPY = "com.example.copypaws.WIDGET_COPY"
        const val ACTION_PUSH = "com.example.copypaws.WIDGET_PUSH"
        const val ACTION_PULL = "com.example.copypaws.WIDGET_PULL"
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        Log.d(TAG, "onUpdate called with ids: ${appWidgetIds.joinToString()}")
        
        val widgetData = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        
        appWidgetIds.forEach { widgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                    // Get latest clip data
                    val content = widgetData.getString("clip_0_content", "No clips yet") ?: "No clips yet"
                    val source = widgetData.getString("clip_0_source", "") ?: ""
                    val time = widgetData.getString("clip_0_time", "") ?: ""
                    
                    // Build meta text
                    val meta = if (source.isNotEmpty() && time.isNotEmpty()) {
                        "from $source • $time"
                    } else if (source.isNotEmpty()) {
                        "from $source"
                    } else {
                        ""
                    }

                    Log.d(TAG, "Updating widget $widgetId: $content")

                    setTextViewText(R.id.clip_content, content)
                    setTextViewText(R.id.clip_meta, meta)

                    // Setup button click handlers (broadcast to self, not launch activity)
                    setOnClickPendingIntent(R.id.btn_copy, getBroadcastPendingIntent(context, ACTION_COPY, widgetId))
                    setOnClickPendingIntent(R.id.btn_pull, getBroadcastPendingIntent(context, ACTION_PULL, widgetId))
                    setOnClickPendingIntent(R.id.btn_push, getBroadcastPendingIntent(context, ACTION_PUSH, widgetId))
                    
                    // Widget root tap opens app
                    setOnClickPendingIntent(R.id.widget_root, getActivityPendingIntent(context, "open"))
                }
                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (e: Exception) {
                Log.e(TAG, "Error updating widget $widgetId", e)
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "onReceive: ${intent.action}")
        
        when (intent.action) {
            ACTION_COPY -> handleCopyAction(context)
            ACTION_PUSH -> handlePushAction(context)
            ACTION_PULL -> handlePullAction(context)
            else -> super.onReceive(context, intent)
        }
    }

    private fun handleCopyAction(context: Context) {
        Log.d(TAG, "Handling COPY action")
        
        try {
            val widgetData = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val content = widgetData.getString("clip_0_content", null)
            
            if (content.isNullOrEmpty() || content == "No clips yet") {
                Toast.makeText(context, "No clip to copy", Toast.LENGTH_SHORT).show()
                return
            }
            
            val clipboardManager = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            val clip = ClipData.newPlainText("CopyPaws", content)
            clipboardManager.setPrimaryClip(clip)
            
            Toast.makeText(context, "Copied to clipboard!", Toast.LENGTH_SHORT).show()
            Log.d(TAG, "Copied to clipboard: ${content.take(50)}...")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error copying to clipboard", e)
            Toast.makeText(context, "Failed to copy", Toast.LENGTH_SHORT).show()
        }
    }

    private fun handlePushAction(context: Context) {
        Log.d(TAG, "Handling PUSH action - launching app for push")
        
        // For Push, we need network access, so launch app in background mode
        // The app will handle the push and return
        try {
            val intent = Intent(context, MainActivity::class.java).apply {
                data = android.net.Uri.parse("copypaws://push")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("background_action", true)
            }
            context.startActivity(intent)
            Toast.makeText(context, "Pushing clipboard...", Toast.LENGTH_SHORT).show()
        } catch (e: Exception) {
            Log.e(TAG, "Error starting push action", e)
            Toast.makeText(context, "Failed to push", Toast.LENGTH_SHORT).show()
        }
    }

    private fun handlePullAction(context: Context) {
        Log.d(TAG, "Handling PULL action - launching app for pull")
        
        // For Pull, we need network access, so launch app in background mode
        try {
            val intent = Intent(context, MainActivity::class.java).apply {
                data = android.net.Uri.parse("copypaws://pull")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("background_action", true)
            }
            context.startActivity(intent)
            Toast.makeText(context, "Pulling latest clip...", Toast.LENGTH_SHORT).show()
        } catch (e: Exception) {
            Log.e(TAG, "Error starting pull action", e)
            Toast.makeText(context, "Failed to pull", Toast.LENGTH_SHORT).show()
        }
    }

    private fun getBroadcastPendingIntent(context: Context, action: String, widgetId: Int): PendingIntent {
        val intent = Intent(context, CopyPawsWidgetProvider::class.java).apply {
            this.action = action
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
        }
        return PendingIntent.getBroadcast(
            context,
            action.hashCode(),
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
    }

    private fun getActivityPendingIntent(context: Context, action: String): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            data = android.net.Uri.parse("copypaws://$action")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context,
            action.hashCode(),
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
    }
}
