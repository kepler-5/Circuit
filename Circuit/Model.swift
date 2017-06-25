import Foundation

class Model {
	private(set) var activeComponents: Set<Component>
	
	let circuitStateChanged = Event<Void>()
	
	init() {
		activeComponents = Set<Component>()
	}
	
	func addComponent(_ c : Component) {
		activeComponents.update(with: c)
		c.inputsChanged.addHandler(handler: { (Void) -> () in
			self.circuitStateChanged.raise(data: ())
		})
	}
}
