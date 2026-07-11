package com.example.nutrilens_mobile_app.ar

import android.content.Context
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Creates [ArPlatformView] instances for the `nutrilens/ar/preview` view type and
 * hands the live instance back to [ArController] so method/event channels can
 * drive it.
 */
class ArViewFactory(
    private val controller: ArController,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val view = ArPlatformView(
            context,
            onDistance = { distanceCm, stable, depthSource, anchorX, anchorY ->
                controller.emitDistance(distanceCm, stable, depthSource, anchorX, anchorY)
            },
            onSessionError = { message ->
                controller.emitSessionError(message)
            },
        )
        controller.attachView(view)
        return view
    }
}
