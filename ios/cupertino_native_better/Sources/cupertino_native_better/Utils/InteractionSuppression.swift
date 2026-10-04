import ObjectiveC
import UIKit

private var cnSuppressedViewsKey: UInt8 = 0

extension UIView {
  /// Turns touch handling off across this view's subtree while a Flutter
  /// modal covers it (`setInteractive`), and back on afterwards.
  ///
  /// Re-enabling **restores** only the views this call disabled, rather than
  /// forcing `isUserInteractionEnabled = true` on every descendant. Forcing
  /// it was a bug: UIKit ships many internal subviews with interaction off
  /// — `UIButton`'s image view, title label and glass background among them
  /// — precisely so hit-testing passes through them to the control. Turned
  /// on, the deepest of them wins `hitTest`, the touch is delivered to it
  /// instead of the `UIControl`, and `.touchUpInside` never fires: the
  /// button looks fine but is dead from the first modal close onwards.
  ///
  /// The record lives on the root it was called on, so separate platform
  /// views never restore each other. Calling it twice with `false` is safe —
  /// the second walk finds everything already off and records nothing.
  func cnSetInteractive(_ interactive: Bool) {
    let existing = objc_getAssociatedObject(self, &cnSuppressedViewsKey) as? NSHashTable<UIView>
    if interactive {
      existing?.allObjects.forEach { $0.isUserInteractionEnabled = true }
      objc_setAssociatedObject(self, &cnSuppressedViewsKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    } else {
      let table = existing ?? NSHashTable<UIView>.weakObjects()
      cnSuppressInteraction(recordingIn: table)
      objc_setAssociatedObject(self, &cnSuppressedViewsKey, table, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
  }

  private func cnSuppressInteraction(recordingIn table: NSHashTable<UIView>) {
    if isUserInteractionEnabled {
      isUserInteractionEnabled = false
      table.add(self)
    }
    for sub in subviews { sub.cnSuppressInteraction(recordingIn: table) }
  }
}
