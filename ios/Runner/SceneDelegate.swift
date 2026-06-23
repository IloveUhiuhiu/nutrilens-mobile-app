import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  // FlutterSceneDelegate's own implementation forwards these to registered
  // plugins via `sceneLifeCycleDelegate` — must call super to preserve that.
  override func sceneWillResignActive(_ scene: UIScene) {
    super.sceneWillResignActive(scene)
    (UIApplication.shared.delegate as? AppDelegate)?.arController?.pauseActiveSession()
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    (UIApplication.shared.delegate as? AppDelegate)?.arController?.resumeActiveSession()
  }
}
