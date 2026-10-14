package com.examvault.education

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.android.play.core.appupdate.AppUpdateManager
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateInfo
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.UpdateAvailability
import com.google.android.play.core.install.model.InstallStatus
import android.app.Activity

class MainActivity : FlutterActivity() {
    private val UPDATE_CHANNEL = "com.examvault.education/update"
    private var appUpdateManager: AppUpdateManager? = null
    private val UPDATE_REQUEST_CODE = 2001

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkUpdate" -> {
                        checkForUpdate(result)
                    }
                    "startUpdate" -> {
                        startUpdate()
                        result.success(true)
                    }
                    "openPlayStore" -> {
                        openPlayStore()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun checkForUpdate(result: MethodChannel.Result) {
        try {
            if (appUpdateManager == null) {
                appUpdateManager = AppUpdateManagerFactory.create(this)
            }

            val appUpdateInfoTask = appUpdateManager!!.appUpdateInfo
            appUpdateInfoTask.addOnSuccessListener { appUpdateInfo: AppUpdateInfo ->
                val isUpdateAvailable =
                    appUpdateInfo.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE

                val isFlexibleAllowed =
                    appUpdateInfo.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE)

                val isImmediateAllowed =
                    appUpdateInfo.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE)

                val clientVersionStalenessDays = appUpdateInfo.clientVersionStalenessDays()

                val installStatus = appUpdateInfo.installStatus()

                if (isUpdateAvailable) {
                    result.success(mapOf(
                        "updateAvailable" to true,
                        "versionCode" to appUpdateInfo.availableVersionCode(),
                        "flexibleAllowed" to isFlexibleAllowed,
                        "immediateAllowed" to isImmediateAllowed,
                        "stalenessDays" to (clientVersionStalenessDays ?: -1),
                        "installStatus" to installStatus
                    ))
                } else {
                    result.success(mapOf("updateAvailable" to false))
                }
            }.addOnFailureListener { e ->
                result.success(mapOf("updateAvailable" to false, "error" to e.message))
            }
        } catch (e: Exception) {
            result.success(mapOf("updateAvailable" to false, "error" to e.message))
        }
    }

    private fun startUpdate() {
        try {
            if (appUpdateManager == null) {
                appUpdateManager = AppUpdateManagerFactory.create(this)
            }

            val appUpdateInfoTask = appUpdateManager!!.appUpdateInfo
            appUpdateInfoTask.addOnSuccessListener { appUpdateInfo: AppUpdateInfo ->
                if (appUpdateInfo.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE &&
                    appUpdateInfo.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE)
                ) {
                    appUpdateManager!!.startUpdateFlowForResult(
                        appUpdateInfo,
                        AppUpdateType.FLEXIBLE,
                        this,
                        UPDATE_REQUEST_CODE
                    )
                }
            }
        } catch (e: Exception) {
            // Silent fail
        }
    }

    private fun openPlayStore() {
        try {
            val packageName = packageName
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$packageName"))
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (e: Exception) {
            // Play Store not installed — open web URL
            try {
                val packageName = packageName
                val intent = Intent(
                    Intent.ACTION_VIEW,
                    Uri.parse("https://play.google.com/store/apps/details?id=$packageName")
                )
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
            } catch (e2: Exception) {
                // Silent fail
            }
        }
    }

    override fun onResume() {
        super.onResume()
        // Check if a flexible update was downloaded and prompt to install
        try {
            if (appUpdateManager != null) {
                appUpdateManager!!.appUpdateInfo
                    .addOnSuccessListener { appUpdateInfo: AppUpdateInfo ->
                        if (appUpdateInfo.installStatus() == InstallStatus.DOWNLOADED) {
                            // Force the update to complete
                            appUpdateManager!!.completeUpdate()
                        }
                    }
            }
        } catch (e: Exception) {
            // Silent fail
        }
    }
}
