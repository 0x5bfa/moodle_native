package dev.example.moodlenative.storage

import android.content.Context
import android.content.SharedPreferences
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.security.KeyStore
import java.util.Base64
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class AndroidEncryptedAppSessionStore(
    context: Context,
    private val keyAlias: String = DEFAULT_KEY_ALIAS,
) : AppSessionStore {
    private val preferences: SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)

    override fun readSnapshot(): AppSessionSnapshot {
        val encryptedSnapshot = preferences.getString(KEY_SNAPSHOT, null) ?: return AppSessionSnapshot()

        return try {
            AppSessionSnapshotCodec.decode(decrypt(encryptedSnapshot))
        } catch (_: AppSessionStoreError) {
            clear()
            AppSessionSnapshot()
        } catch (_: RuntimeException) {
            clear()
            AppSessionSnapshot()
        }
    }

    override fun writeSnapshot(snapshot: AppSessionSnapshot) {
        val encodedSnapshot = AppSessionSnapshotCodec.encode(snapshot)
        preferences.edit()
            .putString(KEY_SNAPSHOT, encrypt(encodedSnapshot))
            .apply()
    }

    override fun clear() {
        preferences.edit()
            .remove(KEY_SNAPSHOT)
            .apply()
    }

    private fun encrypt(value: String): String =
        try {
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.ENCRYPT_MODE, secretKey())
            cipher.updateAAD(AAD)
            val cipherText = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
            val iv = cipher.iv
            val payload = byteArrayOf(iv.size.toByte()) + iv + cipherText
            Base64.getEncoder().encodeToString(payload)
        } catch (error: Exception) {
            throw AppSessionStoreError.CryptoFailure(error)
        }

    private fun decrypt(value: String): String =
        try {
            val payload = Base64.getDecoder().decode(value)
            require(payload.isNotEmpty())
            val ivSize = payload[0].toInt() and 0xFF
            require(ivSize > 0 && payload.size > 1 + ivSize)

            val iv = payload.copyOfRange(1, 1 + ivSize)
            val cipherText = payload.copyOfRange(1 + ivSize, payload.size)
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.DECRYPT_MODE, secretKey(), GCMParameterSpec(GCM_TAG_BITS, iv))
            cipher.updateAAD(AAD)
            cipher.doFinal(cipherText).toString(Charsets.UTF_8)
        } catch (error: Exception) {
            throw AppSessionStoreError.CryptoFailure(error)
        }

    private fun secretKey(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        (keyStore.getKey(keyAlias, null) as? SecretKey)?.let { return it }

        val keyGenerator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        val parameterSpec = KeyGenParameterSpec.Builder(
            keyAlias,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .build()

        keyGenerator.init(parameterSpec)
        return keyGenerator.generateKey()
    }

    private companion object {
        const val PREFERENCES_NAME = "moodle_native_app_session"
        const val KEY_SNAPSHOT = "encrypted_snapshot"
        const val DEFAULT_KEY_ALIAS = "dev.example.moodlenative.app_session"
        const val ANDROID_KEYSTORE = "AndroidKeyStore"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
        const val GCM_TAG_BITS = 128
        val AAD: ByteArray = "moodle-native-app-session-v1".toByteArray(Charsets.UTF_8)
    }
}
