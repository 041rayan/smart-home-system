package com.example.smart_home_app

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.example.smart_home/biometric_crypto"
    private lateinit var cryptoManager: BiometricCryptoManager

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        cryptoManager = BiometricCryptoManager(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkBiometricAvailability" -> {
                    result.success(cryptoManager.checkBiometricAvailability())
                }
                "generateOrRotateKey" -> {
                    result.success(cryptoManager.generateOrRotateKey())
                }
                "getPublicKey" -> {
                    val pubKey = cryptoManager.getPublicKeyBase64()
                    result.success(mapOf("publicKey" to pubKey))
                }
                "isKeyCreated" -> {
                    result.success(cryptoManager.isKeyCreated())
                }
                "authenticateAndSign" -> {
                    val payload = call.argument<String>("payload") ?: ""
                    val title = call.argument<String>("title") ?: "Authorize Door Unlock"
                    val subtitle = call.argument<String>("subtitle") ?: "Biometric authentication required"
                    val description = call.argument<String>("description") ?: "Confirm your identity to unlock"
                    cryptoManager.authenticateAndSign(payload, title, subtitle, description, result)
                }
                else -> result.notImplemented()
            }
        }
    }
}
