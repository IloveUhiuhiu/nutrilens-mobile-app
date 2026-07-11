/// Master switch for the AR capture path.
///
/// While `false`, [CaptureGate] always resolves to the plain camera path even
/// on AR-capable devices, so the app behaves exactly as before. Flip to `true`
/// once the native ARCore/ARKit session and the `/scan/ar` PlatformView are
/// wired in (see the AR module design, sections 4 & 6 of the architecture doc).
const bool kArCaptureEnabled = true;
