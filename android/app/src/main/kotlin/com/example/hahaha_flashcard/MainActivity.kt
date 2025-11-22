package com.example.hahaha_flashcard

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.hahaha_flashcard/text"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            // Flutter에서 호출할 메서드가 필요하면 여기에 추가
            result.notImplemented()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        
        val action = intent.action
        val type = intent.type

        // PROCESS_TEXT intent 처리
        if (Intent.ACTION_PROCESS_TEXT == action && type != null) {
            if ("text/plain" == type) {
                val text = intent.getStringExtra(Intent.EXTRA_PROCESS_TEXT)
                if (text != null && text.isNotBlank()) {
                    // Flutter로 텍스트 전달
                    methodChannel?.invokeMethod("processText", text)
                }
            }
        }
    }
}
