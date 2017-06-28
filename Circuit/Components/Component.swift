import Foundation

class ComponentFunc {
	typealias FuncType = ([Bool]) -> Bool
	
	var f: FuncType
	
	init() {
		f = { _ in false }
	}
}

class Component: Hashable {
	var numInputs: Int { return 0 }
	var numOutputs: Int { return 0 }
	
	private(set) var inputs = Dictionary<Int, (Component, Int)?>()
	private(set) var outputs = Dictionary<Int, ComponentFunc>()
	
	static var nextId: Int = 0
	internal var hashValue: Int
	
	let inputsWillChange = Event<Int>()
	let inputsChanged = Event<Void>()
	
	init() {
		hashValue = Component.nextId
		Component.nextId += 1
		for i in 0..<numInputs {
			inputs.updateValue(nil, forKey: i)
		}
		for i in 0..<numOutputs {
			outputs.updateValue(ComponentFunc(), forKey: i)
		}
	}
	
	func receiveConnection(comp: (Component, Int), input: Int) {
		inputsWillChange.raise(data: input)
		inputs.updateValue(comp, forKey: input)
		inputsChanged.raise(data: Void())
	}
	func removeConnection(input: Int) {
		inputsWillChange.raise(data: input)
		inputs.updateValue(nil, forKey: input)
		inputsChanged.raise(data: Void())
	}
	
	private func getOutputValue(outputIndex: Int, seenComponents: inout Set<Component>) -> Bool {
		guard outputIndex >= 0 && outputIndex < numOutputs && !seenComponents.contains(self) else {
			return false
		}
		let inputValues = inputs.map { (_: Int, value: (Component, Int)?) -> Bool in
			if let inputComponent = value {
				seenComponents.insert(self)
				return inputComponent.0.getOutputValue(outputIndex: inputComponent.1, seenComponents: &seenComponents)
			}
			return false
		}
		return outputs[outputIndex]!.f(inputValues)
	}
	
	func getOutputValue(outputIndex: Int) -> Bool {
		var seenComponents = Set<Component>()
		return getOutputValue(outputIndex: outputIndex, seenComponents: &seenComponents)
	}
	
	func inputsComplete() -> Bool {
		return inputs.filter{ $1 == nil }.count == 0
			&& inputs.map{ $1!.0.inputsComplete() }.reduce(true, {$0 && $1})
	}
	
	static func == (lhs: Component, rhs: Component) -> Bool {
		return lhs.hashValue == rhs.hashValue
	}
}

class GlobalInput: Component {
	override var numInputs: Int { return 0 }
	override var numOutputs: Int { return 1 }
	
	var state: Bool
	
	override init() {
		state = false
		super.init()
		outputs[0]!.f = { _ in self.state }
	}
}

class Single: Component {
	override var numInputs: Int { return 1 }
	override var numOutputs: Int { return 1 }
	
	override init() {
		super.init()
		outputs[0]!.f = { (bs: [Bool]) -> Bool in bs[0] }
	}
}

class NotGate: Component {
	override var numInputs: Int { return 1 }
	override var numOutputs: Int { return 1 }
	
	override init() {
		super.init()
		outputs[0]!.f = { (bs: [Bool]) -> Bool in !bs[0] }
	}
}

class LogicGate: Component {
	override var numInputs: Int { return 2 }
	override var numOutputs: Int { return 1 }
	
	func logicFunc(_: [Bool]) -> Bool { return false }
	
	override init() {
		super.init()
		outputs[0]!.f = { (bs: [Bool]) -> Bool in self.logicFunc(bs) }
	}
}

class AndGate: LogicGate {
	override func logicFunc(_ bs: [Bool]) -> Bool {
		return bs.reduce(true, { $0 && $1 })
	}
}

class OrGate: LogicGate {
	override func logicFunc(_ bs: [Bool]) -> Bool {
		return bs.reduce(false, { $0 || $1 })
	}
}
