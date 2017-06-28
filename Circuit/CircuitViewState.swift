import Foundation

class CircuitViewState {

    // can't implement `deinit` unless this is a class, not a struct
    // so this simple tool to make code easier to write now involves a heap allocation
    // I miss C++
    class Selection {
        static let selectedZ: CGFloat = 1.0
        static let deselectedZ: CGFloat = 0.0
        let component: ComponentView

        init(withComponent c: ComponentView) {
            component = c
            component.zPosition = Selection.selectedZ
        }
        deinit {
            component.zPosition = Selection.deselectedZ
        }
    }
    private var selection: Selection?

    func select(_ component: ComponentView) -> Void {
        if component != selection?.component {
            selection = Selection(withComponent: component)
        }
    }
}
