package com.example.nutrilens_mobile_app.ar

import android.app.Activity
import android.content.Context
import android.graphics.ImageFormat
import android.graphics.Rect
import android.graphics.YuvImage
import android.opengl.GLES20
import android.opengl.GLSurfaceView
import android.os.Handler
import android.os.Looper
import android.view.View
import com.google.ar.core.Camera
import com.google.ar.core.Config
import com.google.ar.core.Frame
import com.google.ar.core.HitResult
import com.google.ar.core.Plane
import com.google.ar.core.Point
import com.google.ar.core.Session
import com.google.ar.core.TrackingState
import io.flutter.plugin.platform.PlatformView
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.CountDownLatch
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10
import kotlin.math.sqrt

/**
 * A Flutter [PlatformView] hosting a live ARCore session. It renders the camera
 * feed, performs a centre-screen plane raycast every frame to measure the
 * camera-to-food distance, and can capture a still frame with camera intrinsics.
 */
class ArPlatformView(
    private val context: Context,
    private val onDistance: (distanceCm: Double?, stable: Boolean, depthSource: String) -> Unit,
) : PlatformView, GLSurfaceView.Renderer {

    private val glView = GLSurfaceView(context).apply {
        preserveEGLContextOnPause = true
        setEGLContextClientVersion(2)
        setEGLConfigChooser(8, 8, 8, 8, 16, 0)
        setRenderer(this@ArPlatformView)
        renderMode = GLSurfaceView.RENDERMODE_CONTINUOUSLY
    }

    private val background = BackgroundRenderer()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val distanceWindow = ArrayDeque<Double>()

    private var session: Session? = null
    private var viewportWidth = 1
    private var viewportHeight = 1
    private var viewportChanged = false

    // True when the Depth API is active for this session — covers both
    // hardware ToF-fused depth (tier 1) and software depth-from-motion
    // (tier 2) transparently; ARCore picks the best available source.
    private var depthEnabled = false

    // Capture handshake between the platform thread and the GL thread.
    @Volatile private var captureRequested = false
    @Volatile private var captureResult: Map<String, Any>? = null
    private var captureLatch: CountDownLatch? = null

    override fun getView(): View = glView

    override fun dispose() {
        try {
            session?.pause()
            session?.close()
        } catch (_: Exception) {
        }
        session = null
    }

    // --- GLSurfaceView.Renderer ------------------------------------------------

    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        GLES20.glClearColor(0f, 0f, 0f, 1f)
        background.createOnGlThread()
        ensureSession()
    }

    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        viewportWidth = width
        viewportHeight = height
        viewportChanged = true
        GLES20.glViewport(0, 0, width, height)
    }

    override fun onDrawFrame(gl: GL10?) {
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT or GLES20.GL_DEPTH_BUFFER_BIT)
        val session = this.session ?: return
        try {
            session.setCameraTextureName(background.textureId)
            if (viewportChanged) {
                val rotation = displayRotation()
                session.setDisplayGeometry(rotation, viewportWidth, viewportHeight)
                viewportChanged = false
            }
            val frame = session.update()
            background.draw(frame)

            val camera = frame.camera
            if (camera.trackingState == TrackingState.TRACKING) {
                val hit = centerHit(frame, camera)
                if (hit != null) {
                    val distanceCm = hit.distance * 100.0
                    pushDistance(distanceCm)
                } else {
                    pushDistance(null)
                }
            } else {
                pushDistance(null)
            }

            if (captureRequested) {
                captureResult = runCapture(frame, camera)
                captureRequested = false
                captureLatch?.countDown()
            }
        } catch (_: Exception) {
            // Frame can be unavailable transiently; skip this draw.
        }
    }

    // --- Public capture API (called on the platform thread) --------------------

    fun capture(): Map<String, Any>? {
        val latch = CountDownLatch(1)
        captureLatch = latch
        captureResult = null
        captureRequested = true
        // Wait for the GL thread to fulfil the request.
        latch.await()
        return captureResult
    }

    // --- Internals -------------------------------------------------------------

    private fun ensureSession() {
        if (session != null) return
        try {
            val newSession = Session(context)
            val config = Config(newSession).apply {
                planeFindingMode = Config.PlaneFindingMode.HORIZONTAL
                updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
                focusMode = Config.FocusMode.AUTO
            }
            // Depth API works on both ToF-equipped devices (hardware-fused,
            // most accurate) and plain ARCore devices (software
            // depth-from-motion, noisier but still far better than a fixed
            // model assumption) — same call either way, ARCore abstracts it.
            depthEnabled = newSession.isDepthModeSupported(Config.DepthMode.AUTOMATIC)
            if (depthEnabled) {
                config.depthMode = Config.DepthMode.AUTOMATIC
            }
            newSession.configure(config)
            newSession.resume()
            session = newSession
        } catch (e: Exception) {
            mainHandler.post { onDistance(null, false, depthSource()) }
        }
    }

    // "ar_depth" covers both tier-1 ToF-fused and tier-2 depth-from-motion —
    // ARCore doesn't expose which one a given device used, so the badge
    // can't claim "LiDAR" specifically the way iOS's sceneDepth check can.
    private fun depthSource(): String = if (depthEnabled) "ar_depth" else "none"

    private fun centerHit(frame: Frame, camera: Camera): HitResult? {
        val cx = viewportWidth / 2f
        val cy = viewportHeight / 2f
        val hits = frame.hitTest(cx, cy)
        // Prefer a horizontal-plane hit (the table/plate surface).
        for (hit in hits) {
            val trackable = hit.trackable
            if (trackable is Plane && trackable.isPoseInPolygon(hit.hitPose)) {
                return hit
            }
        }
        // Fall back to a feature point if no plane is hit yet.
        for (hit in hits) {
            if (hit.trackable is Point) return hit
        }
        return null
    }

    private fun pushDistance(distanceCm: Double?) {
        if (distanceCm == null) {
            distanceWindow.clear()
            mainHandler.post { onDistance(null, false, depthSource()) }
            return
        }
        distanceWindow.addLast(distanceCm)
        while (distanceWindow.size > STABILITY_WINDOW) distanceWindow.removeFirst()
        val mean = distanceWindow.average()
        val variance = distanceWindow.sumOf { (it - mean) * (it - mean) } / distanceWindow.size
        val stable = distanceWindow.size >= STABILITY_WINDOW && sqrt(variance) < STABILITY_STD_CM
        mainHandler.post { onDistance(mean, stable, depthSource()) }
    }

    private fun runCapture(frame: Frame, camera: Camera): Map<String, Any>? {
        return try {
            val image = frame.acquireCameraImage()
            try {
                val jpegPath = saveYuvAsJpeg(image)
                val intrinsics = camera.imageIntrinsics
                val focal = intrinsics.focalLength       // [fx, fy] in pixels
                val principal = intrinsics.principalPoint // [cx, cy] in pixels
                val dims = intrinsics.imageDimensions     // [width, height]
                val hit = centerHit(frame, camera)
                val distanceCm = hit?.let { it.distance * 100.0 }
                val depthMapPath = if (depthEnabled) acquireDepthNpyPath(frame) else null
                buildMap {
                    put("imagePath", jpegPath)
                    put("width", dims[0])
                    put("height", dims[1])
                    put("fx", focal[0].toDouble())
                    put("fy", focal[1].toDouble())
                    put("cx", principal[0].toDouble())
                    put("cy", principal[1].toDouble())
                    if (distanceCm != null) put("distanceCm", distanceCm)
                    if (depthMapPath != null) {
                        put("depthMapPath", depthMapPath)
                        put("depthUnit", "cm")
                    }
                }
            } finally {
                image.close()
            }
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Reads the ARCore Depth API's per-pixel depth image (ToF-fused on
     * tier-1 devices, depth-from-motion on tier-2) and writes it as a .npy
     * float32 array in centimetres, ready for the AI server's
     * `load_client_depth_map`. Returns null if depth isn't available for
     * this frame yet (e.g. still building the motion-stereo estimate).
     */
    private fun acquireDepthNpyPath(frame: Frame): String? {
        return try {
            val depthImage = frame.acquireDepthImage16Bits()
            try {
                saveDepthAsNpyCm(depthImage)
            } finally {
                depthImage.close()
            }
        } catch (e: Exception) {
            null
        }
    }

    private fun saveDepthAsNpyCm(image: android.media.Image): String {
        val width = image.width
        val height = image.height
        val plane = image.planes[0]
        val buffer = plane.buffer
        val rowStride = plane.rowStride
        val pixelStride = plane.pixelStride
        val values = FloatArray(width * height)
        for (row in 0 until height) {
            for (col in 0 until width) {
                val offset = row * rowStride + col * pixelStride
                val low = buffer.get(offset).toInt() and 0xFF
                val high = buffer.get(offset + 1).toInt() and 0xFF
                // DEPTH16: bits 12-0 are millimetres, bits 15-13 reserved.
                val rangeMm = ((high shl 8) or low) and 0x1FFF
                values[row * width + col] = rangeMm / 10f // mm -> cm; 0 stays 0 (invalid sentinel)
            }
        }
        return writeNpyFloat32(values, height, width)
    }

    /** Minimal NPY v1.0 writer (float32, C-order) — avoids any bit-depth
     * ambiguity a PNG encoder would introduce for single-channel depth. */
    private fun writeNpyFloat32(values: FloatArray, rows: Int, cols: Int): String {
        val headerDict = "{'descr': '<f4', 'fortran_order': False, 'shape': ($rows, $cols), }"
        val preHeaderLen = 6 + 2 + 2
        val totalLen = preHeaderLen + headerDict.length + 1
        val pad = (64 - (totalLen % 64)) % 64
        val header = headerDict + " ".repeat(pad) + "\n"
        val headerBytes = header.toByteArray(Charsets.US_ASCII)

        val buffer = java.nio.ByteBuffer.allocate(preHeaderLen + headerBytes.size + values.size * 4)
        buffer.order(java.nio.ByteOrder.LITTLE_ENDIAN)
        buffer.put(byteArrayOf(0x93.toByte(), 'N'.code.toByte(), 'U'.code.toByte(), 'M'.code.toByte(), 'P'.code.toByte(), 'Y'.code.toByte()))
        buffer.put(1) // major version
        buffer.put(0) // minor version
        buffer.putShort(headerBytes.size.toShort())
        buffer.put(headerBytes)
        for (v in values) buffer.putFloat(v)

        val file = File(context.cacheDir, "ar_depth_${System.currentTimeMillis()}.npy")
        file.writeBytes(buffer.array())
        return file.absolutePath
    }

    private fun saveYuvAsJpeg(image: android.media.Image): String {
        val width = image.width
        val height = image.height
        val yBuffer = image.planes[0].buffer
        val uBuffer = image.planes[1].buffer
        val vBuffer = image.planes[2].buffer
        val ySize = yBuffer.remaining()
        val uSize = uBuffer.remaining()
        val vSize = vBuffer.remaining()
        val nv21 = ByteArray(ySize + uSize + vSize)
        yBuffer.get(nv21, 0, ySize)
        vBuffer.get(nv21, ySize, vSize)
        uBuffer.get(nv21, ySize + vSize, uSize)
        val yuvImage = YuvImage(nv21, ImageFormat.NV21, width, height, null)
        val out = ByteArrayOutputStream()
        yuvImage.compressToJpeg(Rect(0, 0, width, height), 95, out)
        val file = File(context.cacheDir, "ar_capture_${System.currentTimeMillis()}.jpg")
        file.writeBytes(out.toByteArray())
        return file.absolutePath
    }

    private fun displayRotation(): Int {
        val activity = context as? Activity
        @Suppress("DEPRECATION")
        return activity?.windowManager?.defaultDisplay?.rotation ?: 0
    }

    companion object {
        private const val STABILITY_WINDOW = 8
        private const val STABILITY_STD_CM = 1.0
    }
}
