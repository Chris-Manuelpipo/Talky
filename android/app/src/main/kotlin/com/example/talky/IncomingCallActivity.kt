package com.example.talky

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class IncomingCallActivity : FlutterActivity() {
    private val CHANNEL = "com.example.talky/incoming_call"
    
    override fun onCreate(savedInstanceState: Bundle?) {
        // Afficher l'activité même si l'écran est verrouillé
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
        
        super.onCreate(savedInstanceState)
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCallData" -> {
                    val callData = mapOf(
                        "callerId" to intent.getStringExtra("callerId"),
                        "callerName" to intent.getStringExtra("callerName"),
                        "isVideo" to intent.getBooleanExtra("isVideo", false),
                        "isGroup" to intent.getBooleanExtra("isGroup", false),
                        "roomId" to intent.getStringExtra("roomId"),
                        "offer" to intent.getStringExtra("offer")
                    )
                    result.success(callData)
                }
                "finish" -> {
                    finish()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
    
    companion object {
        fun createIntent(context: Context, data: Map<String, Any?>): Intent {
            return Intent(context, IncomingCallActivity::class.java).apply {
                putExtra("callerId", data["callerId"] as? String)
                putExtra("callerName", data["callerName"] as? String)
                putExtra("isVideo", data["isVideo"] as? Boolean ?: false)
                putExtra("isGroup", data["isGroup"] as? Boolean ?: false)
                putExtra("roomId", data["roomId"] as? String)
                putExtra("offer", data["offer"] as? String)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        }
    }
}
