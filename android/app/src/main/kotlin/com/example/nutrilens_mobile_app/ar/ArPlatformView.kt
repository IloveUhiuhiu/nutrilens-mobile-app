package com.example.nutrilens_mobile_app.ar

import android.app.Activity
import android.content.Context
import android.graphics.ImageFormat
import android.graphics.PointF
import android.graphics.Rect
import android.graphics.YuvImage
import android.opengl.GLES20
import android.opengl.GLSurfaceView
import android.os.Handler
import android.os.Looper
import android.view.View
import com.google.ar.core.Camera
import com.google.ar.core.Config
import com.google.ar.core.Coordinates2d
import com.google.ar.core.Frame
import com.google.ar.core.HitResult
import com.google.ar.core.Plane
import com.google.ar.core.Session
import com.google.ar.core.TrackingState
import io.flutter.plugin.platform.PlatformView
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.CountDownLatch
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * A Flutter [PlatformView] hosting a live ARCore session. It renders the camera
 * feed, performs a centre-screen plane raycast every frame to measure the
 * camera-to-food distance, and can capture a still frame with camera intrinsics.
 */
class ArPlatformView(
    private val context: Context,
    private val onDistance: (
        distanceCm: Double?,
        stable: Boolean,
        depthSource: String,
        anchorX: Double?,
        anchorY: Double?,
    ) -> Unit,
    private val onSessionError: (message: String) -> Unit,
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

    // "Sticky" anchor point (view pixel coordinates) — re-tested every frame
    // before falling back to a fresh search, so the on-screen dot doesn't
    // jitter between candidates while the same spot is still a valid plane hit.
    private var lastAnchorPoint: PointF? = null

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

    /**
     * Called when the host Activity is paused (e.g. app backgrounded mid-scan).
     * Order matters — GLSurfaceView is paused first so it doesn't query the
     * session after it's gone; pausing the session first risks the GL thread
     * hitting a SessionPausedException on its next frame. Mirrors ARCore's
     * own HelloAR sample.
     */
    fun pauseSession() {
        glView.onPause()
        try {
            session?.pause()
        } catch (_: Exception) {
        }
    }

    /** Called when the host Activity resumes. Mirror of [pauseSession]'s ordering. */
    fun resumeSession() {
        try {
            session?.resume()
        } catch (_: Exception) {
        }
        glView.onResume()
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
                val anchor = findAnchorHit(frame)
                if (anchor != null) {
                    val (point, hit) = anchor
                    val distanceCm = hit.distance * 100.0
                    val anchorX = if (viewportWidth > 0) point.x / viewportWidth else null
                    val anchorY = if (viewportHeight > 0) point.y / viewportHeight else null
                    pushDistance(distanceCm, anchorX, anchorY)
                } else {
                    pushDistance(null, null, null)
                }
            } else {
                pushDistance(null, null, null)
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
            val message = e.message ?: "Không thể khởi tạo phiên AR."
            mainHandler.post { onSessionError(message) }
        }
    }

    // "ar_depth" covers both tier-1 ToF-fused and tier-2 depth-from-motion —
    // ARCore doesn't expose which one a given device used, so the badge
    // can't claim "LiDAR" specifically the way iOS's sceneDepth check can.
    private fun depthSource(): String = if (depthEnabled) "ar_depth" else "none"

    /** Hit-tests a single view-pixel point, accepting only a horizontal-plane
     * hit within its observed polygon (the table/plate surface) — no fallback
     * to a feature [com.google.ar.core.Point], since that could land on the
     * food itself. */
    private fun planeHit(frame: Frame, point: PointF): HitResult? {
        val hits = frame.hitTest(point.x, point.y)
        for (hit in hits) {
            val trackable = hit.trackable
            if (trackable is Plane && trackable.isPoseInPolygon(hit.hitPose)) {
                return hit
            }
        }
        return null
    }

    /** Candidate points for the anchor search: viewport centre first, then
     * rings expanding outward (up to 90% of the half-extent, leaving a ~10%
     * margin near the edges where lens distortion is worst). */
    private fun candidateAnchorPoints(): List<PointF> {
        val cx = viewportWidth / 2f
        val cy = viewportHeight / 2f
        val halfW = viewportWidth / 2f
        val halfH = viewportHeight / 2f
        val points = mutableListOf(PointF(cx, cy))
        for (radiusFraction in ANCHOR_RING_RADIUS_FRACTIONS) {
            for (i in 0 until ANCHOR_RING_ANGLE_COUNT) {
                val angle = (i.toFloat() / ANCHOR_RING_ANGLE_COUNT) * 2f * Math.PI.toFloat()
                val dx = cos(angle) * radiusFraction * halfW
                val dy = sin(angle) * radiusFraction * halfH
                points.add(PointF(cx + dx, cy + dy))
            }
        }
        return points
    }

    /**
     * Finds a point that currently lands on the detected horizontal plane —
     * preferring the previous frame's point ([lastAnchorPoint]) to keep the
     * on-screen dot stable, only searching a fresh ring of candidates when
     * that point stops being valid (e.g. the user moved the phone). Unlike a
     * fixed centre point, this naturally avoids food (never tracked as part
     * of a plane) and glossy/textureless plate surfaces (rarely tracked
     * either), since both are excluded from the plane's observed geometry
     * rather than guessed around.
     */
    private fun findAnchorHit(frame: Frame): Pair<PointF, HitResult>? {
        lastAnchorPoint?.let { sticky ->
            planeHit(frame, sticky)?.let { return sticky to it }
        }
        for (candidate in candidateAnchorPoints()) {
            planeHit(frame, candidate)?.let {
                lastAnchorPoint = candidate
                return candidate to it
            }
        }
        lastAnchorPoint = null
        return null
    }

    /** Maps a view-pixel point to the matching pixel in the captured camera
     * image — the space the depth map and camera intrinsics operate in.
     * Needed because the anchor point is no longer always the image centre,
     * so the backend can no longer assume anchor pixel == (cx, cy).
     * [Frame.transformCoordinates2d] is ARCore's own API for this mapping. */
    private fun imagePixel(frame: Frame, viewPoint: PointF): FloatArray? {
        if (viewportWidth <= 0 || viewportHeight <= 0) return null
        val viewNormalized = floatArrayOf(viewPoint.x / viewportWidth, viewPoint.y / viewportHeight)
        val imageNormalized = FloatArray(2)
        frame.transformCoordinates2d(
            Coordinates2d.VIEW_NORMALIZED,
            viewNormalized,
            Coordinates2d.IMAGE_NORMALIZED,
            imageNormalized,
        )
        val dims = frame.camera.imageIntrinsics.imageDimensions
        return floatArrayOf(imageNormalized[0] * dims[0], imageNormalized[1] * dims[1])
    }

    private fun pushDistance(distanceCm: Double?, anchorX: Float?, anchorY: Float?) {
        if (distanceCm == null) {
            distanceWindow.clear()
            mainHandler.post { onDistance(null, false, depthSource(), null, null) }
            return
        }
        distanceWindow.addLast(distanceCm)
        while (distanceWindow.size > STABILITY_WINDOW) distanceWindow.removeFirst()
        val mean = distanceWindow.average()
        val variance = distanceWindow.sumOf { (it - mean) * (it - mean) } / distanceWindow.size
        val stable = distanceWindow.size >= STABILITY_WINDOW && sqrt(variance) < STABILITY_STD_CM
        mainHandler.post {
            onDistance(mean, stable, depthSource(), anchorX?.toDouble(), anchorY?.toDouble())
        }
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
                val anchor = findAnchorHit(frame)
                val distanceCm = anchor?.second?.let { it.distance * 100.0 }
                val anchorPixel = anchor?.let { imagePixel(frame, it.first) }
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
                    if (anchorPixel != null) {
                        put("anchorPixelX", anchorPixel[0].toDouble())
                        put("anchorPixelY", anchorPixel[1].toDouble())
                    }
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
        private val ANCHOR_RING_RADIUS_FRACTIONS = floatArrayOf(0.15f, 0.30f, 0.45f)
        private const val ANCHOR_RING_ANGLE_COUNT = 8
    }
}
