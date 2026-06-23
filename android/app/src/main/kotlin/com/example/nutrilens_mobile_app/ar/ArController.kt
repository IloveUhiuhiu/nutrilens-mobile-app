package com.example.nutrilens_mobile_app.ar

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import com.google.ar.core.ArCoreApk
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Bridges the Flutter `nutrilens/ar` MethodChannel + `nutrilens/ar/distance`
 * EventChannel to the live [ArPlatformView]. Handles capability probing,
 * realtime distance streaming and still-frame capture.
 */
class ArController(
    private val context: Context,
    messenger: BinaryMessenger,
) {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private var view: ArPlatformView? = null

    init {
        MethodChannel(messenger, "nutrilens/ar").setMethodCallHandler { call, result ->
            onMethodCall(call, result)
        }
        EventChannel(messenger, "nutrilens/ar/distance").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            },
        )
    }

    fun attachView(view: ArPlatformView) {
        this.view = view
    }

    /** No-ops if no AR view is currently active — safe to call unconditionally
     *  from Activity.onPause/onResume regardless of which screen is showing. */
    fun pauseActiveSession() {
        view?.pauseSession()
    }

    fun resumeActiveSession() {
        view?.resumeSession()
    }

    fun emitDistance(distanceCm: Double?, stable: Boolean, depthSource: String) {
        val sink = eventSink ?: return
        mainHandler.post {
            sink.success(
                buildMap<String, Any> {
                    if (distanceCm != null) put("distance", distanceCm)
                    put("stable", stable)
                    put("depthSource", depthSource)
                },
            )
        }
    }

    /**
     * Reports that the ARCore session itself failed to start (e.g. camera
     * permission denied at the OS level despite the Dart-side pre-check, or
     * the camera being held by another app). Without this, [ensureSession]
     * failures previously degraded silently into "distance stays null
     * forever", indistinguishable on screen from "still searching for a
     * surface".
     */
    fun emitSessionError(message: String) {
        val sink = eventSink ?: return
        mainHandler.post {
            sink.success(
                buildMap<String, Any> {
                    put("stable", false)
                    put("depthSource", "none")
                    put("error", message)
                },
            )
        }
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkCapability" -> result.success(checkCapability())
            "requestInstall" -> {
                requestInstall()
                result.success(null)
            }
            "captureFrame" -> captureFrame(result)
            "dispose" -> {
                view = null
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Launches the "Google Play Services for AR" install/update flow for a
     * [ArCapability.needsInstall] device. Per ARCore's own contract this must
     * only be called in direct response to an explicit user action (the
     * Dart-side "Cài đặt" button tap satisfies that). The result isn't
     * synchronous — the host Activity pauses while the user is in the Play
     * Store, and the Dart side re-probes `checkCapability` once the app
     * resumes, so there's nothing useful to return here beyond "we tried".
     */
    private fun requestInstall() {
        val activity = context as? Activity ?: return
        try {
            ArCoreApk.getInstance().requestInstall(activity, true)
        } catch (e: Exception) {
            // UnavailableDeviceNotCompatibleException / UnavailableUserDeclinedInstallationException:
            // nothing actionable here — the resume-triggered re-check on the
            // Dart side falls back to the plain camera regardless.
        }
    }

    private fun checkCapability(): String {
        return try {
            when (ArCoreApk.getInstance().checkAvailability(context)) {
                ArCoreApk.Availability.SUPPORTED_INSTALLED -> "supported"
                ArCoreApk.Availability.SUPPORTED_APK_TOO_OLD,
                ArCoreApk.Availability.SUPPORTED_NOT_INSTALLED -> "needsInstall"
                ArCoreApk.Availability.UNKNOWN_CHECKING -> "needsInstall"
                else -> "unsupported"
            }
        } catch (e: Exception) {
            "unsupported"
        }
    }

    private fun captureFrame(result: MethodChannel.Result) {
        val target = view
        if (target == null) {
            result.error("no_view", "AR view is not active.", null)
            return
        }
        // capture() blocks awaiting the GL thread, so run it off the main thread.
        Thread {
            val captured = target.capture()
            mainHandler.post {
                if (captured == null) {
                    result.error("capture_failed", "Could not capture AR frame.", null)
                } else {
                    result.success(captured)
                }
            }
        }.start()
    }
}
