package com.memorypuzzle.app

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Android 15+: draw behind the status / navigation bars with the
        // non-deprecated API (the Flutter UI keeps its SafeArea padding).
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }
}
