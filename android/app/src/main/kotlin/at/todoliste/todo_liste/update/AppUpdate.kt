package at.todoliste.todo_liste.update

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

/** Gibt nur den Ordner mit der geladenen APK an den Installer weiter (res/xml/update_paths.xml). */
class UpdateFileProvider : FileProvider()

/**
 * Android-Teil des Auto-Updates (lib/services/update_platform.dart). Die App lädt die APK und prüft
 * ihre Signatur selbst; hier wird nur noch die Erlaubnis geholt und der Installer des Systems geöffnet.
 */
class AppUpdate(private val activity: Activity) : MethodChannel.MethodCallHandler {
    /** Wartet auf die Rückkehr aus den Einstellungen bzw. aus dem Installer. */
    private var pending: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            // Welche App ist das? Nur die veröffentlichte aktualisiert sich selbst.
            "info" -> result.success(mapOf("package" to activity.packageName, "cert" to certSha256()))
            "dir" -> result.success(dir().path)
            "canInstall" -> result.success(canInstall())
            "requestPermission" -> requestPermission(result)
            "install" -> install(call.arguments as? String, result)
            else -> result.notImplemented()
        }
    }

    /** Von der Activity weitergereicht; `true`, wenn die Antwort zu einem Update-Schritt gehörte. */
    fun onActivityResult(requestCode: Int): Boolean {
        val answer: Boolean = when (requestCode) {
            REQUEST_PERMISSION -> canInstall()
            // Wer hier noch läuft, wurde nicht ersetzt: Der Nutzer hat abgebrochen.
            REQUEST_INSTALL -> false
            else -> return false
        }
        pending?.success(answer)
        pending = null
        return true
    }

    private fun dir() = File(activity.cacheDir, DIR)

    private fun canInstall() =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O || activity.packageManager.canRequestPackageInstalls()

    /** Öffnet „Unbekannte Apps installieren“ für diese App; die Antwort kommt bei der Rückkehr. */
    private fun requestPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return result.success(true)
        val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${activity.packageName}"))
        open(intent, REQUEST_PERMISSION, result)
    }

    private fun install(path: String?, result: MethodChannel.Result) {
        // Nur eine Datei direkt im Update-Ordner – nichts anderes aus dem Speicher der App.
        val file = path?.let { File(it).canonicalFile }
        if (file == null || file.parentFile != dir().canonicalFile || !file.isFile) {
            return result.error("file", "Keine Update-Datei", null)
        }
        val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.update", file)
        val intent = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, "application/vnd.android.package-archive")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        open(intent, REQUEST_INSTALL, result)
    }

    private fun open(intent: Intent, requestCode: Int, result: MethodChannel.Result) {
        if (pending != null) return result.error("busy", "Es läuft schon ein Update", null)
        try {
            activity.startActivityForResult(intent, requestCode)
            pending = result
        } catch (e: ActivityNotFoundException) {
            result.error("unavailable", "Auf diesem Gerät nicht möglich", null)
        }
    }

    /** SHA-256 des Zertifikats, mit dem diese App signiert ist (klein geschrieben, ohne Trennzeichen). */
    private fun certSha256(): String? {
        val pm = activity.packageManager
        val name = activity.packageName
        val signers = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            pm.getPackageInfo(name, PackageManager.GET_SIGNING_CERTIFICATES).signingInfo?.apkContentsSigners
        } else {
            @Suppress("DEPRECATION")
            pm.getPackageInfo(name, PackageManager.GET_SIGNATURES).signatures
        }
        val cert = signers?.singleOrNull() ?: return null
        return MessageDigest.getInstance("SHA-256").digest(cert.toByteArray()).joinToString("") { "%02x".format(it) }
    }

    companion object {
        const val CHANNEL = "todo_liste/update"
        private const val DIR = "updates"
        private const val REQUEST_PERMISSION = 4701
        private const val REQUEST_INSTALL = 4702
    }
}
