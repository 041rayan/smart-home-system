package com.example.smart_home_app

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import io.flutter.plugin.common.MethodChannel
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.Signature
import java.security.spec.ECGenParameterSpec

class BiometricCryptoManager(private val activity: FragmentActivity) {

    companion object {
        const val KEY_ALIAS = "smart_home_biometric_door_key"
        const val ANDROID_KEYSTORE = "AndroidKeyStore"
        const val SIGNATURE_ALGORITHM = "SHA256withECDSA"
    }

    private val biometricManager = BiometricManager.from(activity)

    /**
     * Checks availability of BIOMETRIC_STRONG hardware and enrollment.
     */
    fun checkBiometricAvailability(): Map<String, Any> {
        val authResult = biometricManager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG)
        val statusString = when (authResult) {
            BiometricManager.BIOMETRIC_SUCCESS -> "SUCCESS"
            BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE -> "NO_HARDWARE"
            BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE -> "HW_UNAVAILABLE"
            BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> "NONE_ENROLLED"
            BiometricManager.BIOMETRIC_ERROR_SECURITY_UPDATE_REQUIRED -> "SECURITY_UPDATE_REQUIRED"
            else -> "UNKNOWN"
        }

        return mapOf(
            "canAuthenticate" to (authResult == BiometricManager.BIOMETRIC_SUCCESS),
            "status" to statusString,
            "isStrong" to true,
            "keyExists" to isKeyCreated(),
            "deviceModel" to (Build.MODEL ?: "Android")
        )
    }

    /**
     * Generates a new EC (secp256r1) keypair in AndroidKeyStore requiring BIOMETRIC_STRONG authentication.
     */
    fun generateOrRotateKey(): Map<String, Any> {
        return try {
            val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
            if (keyStore.containsAlias(KEY_ALIAS)) {
                keyStore.deleteEntry(KEY_ALIAS)
            }

            val kpg = KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, ANDROID_KEYSTORE)
            val builder = KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_SIGN
            ).apply {
                setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
                setDigests(KeyProperties.DIGEST_SHA256)
                setUserAuthenticationRequired(true)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG)
                }
                setInvalidatedByBiometricEnrollment(true)
            }

            val keyPair = kpg.run {
                initialize(builder.build())
                generateKeyPair()
            }

            val publicKeyBase64 = Base64.encodeToString(keyPair.public.encoded, Base64.NO_WRAP)
            mapOf(
                "success" to true,
                "publicKeyBase64" to publicKeyBase64,
                "algorithm" to SIGNATURE_ALGORITHM
            )
        } catch (e: Exception) {
            mapOf(
                "success" to false,
                "error" to (e.message ?: "Key generation failed")
            )
        }
    }

    /**
     * Retrieves the Base64-encoded X.509 public key if available.
     */
    fun getPublicKeyBase64(): String? {
        return try {
            val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
            val cert = keyStore.getCertificate(KEY_ALIAS) ?: return null
            Base64.encodeToString(cert.publicKey.encoded, Base64.NO_WRAP)
        } catch (e: Exception) {
            null
        }
    }

    fun isKeyCreated(): Boolean {
        return try {
            val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
            keyStore.containsAlias(KEY_ALIAS)
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Prompts the user with AndroidX BiometricPrompt (BIOMETRIC_STRONG only),
     * unlocking the hardware private key via CryptoObject, and signing the payload.
     */
    fun authenticateAndSign(
        payload: String,
        title: String,
        subtitle: String,
        description: String,
        resultCallback: MethodChannel.Result
    ) {
        // 1. Verify Biometric Strong availability
        val authCheck = biometricManager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG)
        if (authCheck != BiometricManager.BIOMETRIC_SUCCESS) {
            resultCallback.success(
                mapOf(
                    "success" to false,
                    "errorCode" to "BIOMETRIC_UNAVAILABLE",
                    "errorMessage" to "BIOMETRIC_STRONG is not available or not enrolled ($authCheck)"
                )
            )
            return
        }

        // 2. Ensure Keystore key exists
        if (!isKeyCreated()) {
            val genResult = generateOrRotateKey()
            if (genResult["success"] != true) {
                resultCallback.success(
                    mapOf(
                        "success" to false,
                        "errorCode" to "KEY_GENERATION_FAILED",
                        "errorMessage" to (genResult["error"] ?: "Failed to generate key")
                    )
                )
                return
            }
        }

        // 3. Initialize Signature with Keystore PrivateKey
        val cryptoObject: BiometricPrompt.CryptoObject
        try {
            val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
            val privateKey = keyStore.getKey(KEY_ALIAS, null) as? PrivateKey
                ?: throw IllegalStateException("Private key not found in AndroidKeyStore")

            val signature = Signature.getInstance(SIGNATURE_ALGORITHM)
            signature.initSign(privateKey)
            cryptoObject = BiometricPrompt.CryptoObject(signature)
        } catch (e: KeyPermanentlyInvalidatedException) {
            // Biometric enrollment changed
            generateOrRotateKey()
            resultCallback.success(
                mapOf(
                    "success" to false,
                    "errorCode" to "KEY_PERMANENTLY_INVALIDATED",
                    "errorMessage" to "Biometric enrollment changed. Key was rotated. Please authenticate again."
                )
            )
            return
        } catch (e: Exception) {
            resultCallback.success(
                mapOf(
                    "success" to false,
                    "errorCode" to "CRYPTO_INIT_FAILED",
                    "errorMessage" to (e.message ?: "Failed to initialize signature")
                )
            )
            return
        }

        // 4. Configure BiometricPrompt.PromptInfo (Strict BIOMETRIC_STRONG, NO PIN FALLBACK)
        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle(title)
            .setSubtitle(subtitle)
            .setDescription(description)
            .setNegativeButtonText("Cancel")
            .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
            .build()

        val executor = ContextCompat.getMainExecutor(activity)
        val biometricPrompt = BiometricPrompt(
            activity,
            executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    super.onAuthenticationSucceeded(result)
                    try {
                        val authSignature = result.cryptoObject?.signature
                            ?: throw IllegalStateException("CryptoObject signature is null after authentication")

                        val payloadBytes = payload.toByteArray(Charsets.UTF_8)
                        authSignature.update(payloadBytes)
                        val signatureBytes = authSignature.sign()
                        val signatureBase64 = Base64.encodeToString(signatureBytes, Base64.NO_WRAP)
                        val pubKey = getPublicKeyBase64() ?: ""

                        resultCallback.success(
                            mapOf(
                                "success" to true,
                                "payload" to payload,
                                "signatureBase64" to signatureBase64,
                                "publicKeyBase64" to pubKey,
                                "algorithm" to SIGNATURE_ALGORITHM
                            )
                        )
                    } catch (e: Exception) {
                        resultCallback.success(
                            mapOf(
                                "success" to false,
                                "errorCode" to "SIGNING_FAILED",
                                "errorMessage" to (e.message ?: "Cryptographic signing failed")
                            )
                        )
                    }
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    super.onAuthenticationError(errorCode, errString)
                    val codeStr = when (errorCode) {
                        BiometricPrompt.ERROR_LOCKOUT -> "ERROR_LOCKOUT"
                        BiometricPrompt.ERROR_LOCKOUT_PERMANENT -> "ERROR_LOCKOUT_PERMANENT"
                        BiometricPrompt.ERROR_USER_CANCELED,
                        BiometricPrompt.ERROR_NEGATIVE_BUTTON -> "ERROR_CANCELED"
                        BiometricPrompt.ERROR_NO_BIOMETRICS -> "ERROR_NO_BIOMETRICS"
                        BiometricPrompt.ERROR_HW_UNAVAILABLE -> "ERROR_HW_UNAVAILABLE"
                        BiometricPrompt.ERROR_TIMEOUT -> "ERROR_TIMEOUT"
                        else -> "ERROR_CODE_$errorCode"
                    }

                    resultCallback.success(
                        mapOf(
                            "success" to false,
                            "errorCode" to codeStr,
                            "errorMessage" to errString.toString()
                        )
                    )
                }

                override fun onAuthenticationFailed() {
                    super.onAuthenticationFailed()
                    // Biometric rejected (unrecognized finger/face) - Android automatically prompts retry
                }
            }
        )

        biometricPrompt.authenticate(promptInfo, cryptoObject)
    }
}
