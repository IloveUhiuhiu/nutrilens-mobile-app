package com.example.nutrilens_mobile_app

import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Build
import com.example.nutrilens_mobile_app.ar.ArController
import com.example.nutrilens_mobile_app.ar.ArViewFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var arController: ArController? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "nutrilens/camera_intrinsics"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getBackCameraIntrinsics" -> getBackCameraIntrinsics(result)
                else -> result.notImplemented()
            }
        }

        // AR (ARCore): capability + realtime distance + frame capture, and the
        // native camera preview platform view.
        val controller = ArController(this, flutterEngine.dartExecutor.binaryMessenger)
        arController = controller
        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory("nutrilens/ar/preview", ArViewFactory(controller))
    }

    // No-ops when no AR view is active (most of the app's lifetime), so it's
    // safe to forward every Activity pause/resume here unconditionally.
    // Without this, the ARCore session and its GLSurfaceView kept rendering
    // and holding the camera even after the app was backgrounded mid-scan.
    override fun onPause() {
        super.onPause()
        arController?.pauseActiveSession()
    }

    override fun onResume() {
        super.onResume()
        arController?.resumeActiveSession()
    }

    private fun getBackCameraIntrinsics(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            result.error("unavailable", "Camera2 is not available on this Android version.", null)
            return
        }

        val cameraManager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val cameraId = cameraManager.cameraIdList.firstOrNull { id ->
            val characteristics = cameraManager.getCameraCharacteristics(id)
            characteristics.get(CameraCharacteristics.LENS_FACING) ==
                CameraCharacteristics.LENS_FACING_BACK
        }

        if (cameraId == null) {
            result.error("unavailable", "Back camera is not available.", null)
            return
        }

        val characteristics = cameraManager.getCameraCharacteristics(cameraId)
        val calibration = characteristics.get(
            CameraCharacteristics.LENS_INTRINSIC_CALIBRATION
        )
        val activeArray = characteristics.get(
            CameraCharacteristics.SENSOR_INFO_ACTIVE_ARRAY_SIZE
        )

        if (calibration == null || calibration.size < 4 || activeArray == null) {
            result.error("unavailable", "Camera intrinsic calibration is not available.", null)
            return
        }

        result.success(
            mapOf(
                "fx" to calibration[0].toDouble(),
                "fy" to calibration[1].toDouble(),
                "cx" to calibration[2].toDouble(),
                "cy" to calibration[3].toDouble(),
                "sensorWidth" to activeArray.width(),
                "sensorHeight" to activeArray.height(),
                "source" to "android_camera2_lens_intrinsic_calibration"
            )
        )
    }
}
