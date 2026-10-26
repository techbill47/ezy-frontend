package com.tekcon.ezy

import android.bluetooth.BluetoothAdapter
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ezy/ble_test")
            .setMethodCallHandler { call, result ->
                val adapter = BluetoothAdapter.getDefaultAdapter()
                when (call.method) {
                    "sdkInt" -> result.success(Build.VERSION.SDK_INT)
                    "getBluetoothName" -> result.success(adapter?.name)
                    "setBluetoothName" -> {
                        val name = call.argument<String>("name")
                        result.success(name != null && adapter?.setName(name) == true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
