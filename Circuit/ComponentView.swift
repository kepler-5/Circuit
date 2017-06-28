import Foundation
import SpriteKit

let NoConnectionColor = NSColor.red
let ConnectionColor = NSColor.green
let IncompleteConnectionsColor = NSColor.yellow
let CompleteConnectionsColor = NSColor.white
let GenericConnectorColor = NSColor.blue

class ComponentView: SKSpriteNode {
	let component: Component
	
	private var connectors = [ConnectorNode]()
	private var startingTouchPos: CGPoint?

	private var receivingConnectionLines = Dictionary<Int, ConnectorNode>()

    override var zPosition: CGFloat {
        didSet {
            for connector in connectors {
                connector.zPosition = self.zPosition + 1.0
            }
        }
    }

    private var gameScene: GameScene? {
        return self.scene as? GameScene
    }
	
	func receiveConnectionLine(node: ConnectorNode, inputIndex: Int) {
		if let oldConnectionLine = self.receivingConnectionLines[inputIndex] {
			oldConnectionLine.severConnection(connectors[inputIndex])
		}
		self.receivingConnectionLines.updateValue(node, forKey: inputIndex)
		self.component.receiveConnection(comp: (node.component.component, node.connectorIndex), input: inputIndex)
	}
	func removeConnectionLine(connectorIndex: Int) {
		self.receivingConnectionLines.removeValue(forKey: connectorIndex)
		self.component.removeConnection(input: connectorIndex)
	}
	func getConnectionLine(inputIndex: Int) -> ConnectorNode? {
		return receivingConnectionLines[inputIndex]
	}
	
	func updateOutputConnectionLines() {
		for c in connectors.filter({ $0.connectorType == ConnectorNode.ConnectorType.OutputConnector }) {
			c.updateAllConnectionLines()
		}
	}
	
	func updateInputConnectionLines() {
		for componentView in receivingConnectionLines.map({ (_: Int, value: ConnectorNode) in value.component }) {
			componentView.updateOutputConnectionLines()
		}
	}
	
	static func getTexture(comp: Component) -> SKTexture {
		if let _ = comp as? AndGate {
			return SKTexture(imageNamed: "andGate")
		}
		if let _ = comp as? OrGate {
			return SKTexture(imageNamed: "orGate")
		}
		if let _ = comp as? NotGate {
			return SKTexture(imageNamed: "notGate")
		}
		if let _ = comp as? Single {
			return SKTexture(imageNamed: "singleComponent")
		}
		if let _ = comp as? GlobalInput {
			return SKTexture(imageNamed: "globalInput")
		}
		fatalError("unsupported component")
	}
	
    func setUpConnectorNodes(gameScene: GameScene) {
		let createNode = {(num: Int, total: Int, edge: Int) -> Void in
			let frac = 1.0 / CGFloat(total + 1)
			let node = ConnectorNode(component: self,
			                         connectorIndex: num,
			                         connectorType: edge == 0
										? ConnectorNode.ConnectorType.InputConnector
										: ConnectorNode.ConnectorType.OutputConnector,
			                         gameScene: gameScene)
			node.position = CGPoint(x: CGFloat(edge) * self.size.width, y: frac * CGFloat(num+1) * self.size.height)
			self.addChild(node)
			self.connectors.append(node)
		}
		for i in 0..<component.numInputs {
			createNode(i, component.numInputs, 0)
		}
		for i in 0..<component.numOutputs {
			createNode(i, component.numOutputs, 1)
		}
	}
	
	init(component comp: Component, gameScene: GameScene) {
		component = comp
		super.init(texture: ComponentView.getTexture(comp: component), color: NSColor.white, size: CGSize(width: 100, height: 100))
		
		self.isUserInteractionEnabled = true
		self.anchorPoint = CGPoint(x: 0.0, y: 0.0)
		self.name = "component"
        setUpConnectorNodes(gameScene: gameScene)
		self.colorBlendFactor = 1.0
		
		gameScene.model.circuitStateChanged.addHandler(handler: updateColor)
		updateColor()
        gameScene.viewState.select(self)
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	func touchDown(atPoint pos : CGPoint) {
        gameScene?.viewState.select(self)
		startingTouchPos = pos
	}
	
	func touchMoved(toPoint pos : CGPoint) {
		var pos = pos
		if let prev = startingTouchPos {
			pos = CGPoint(x: pos.x - prev.x, y: pos.y - prev.y)
		}
		self.position = self.convert(pos, to: self.parent!)
		
		updateOutputConnectionLines()
		updateInputConnectionLines()
	}
	
	func touchUp(atPoint pos : CGPoint) {}
	
	override func mouseDown(with event: NSEvent) {
		self.touchDown(atPoint: event.location(in: self))
	}
	
	override func mouseDragged(with event: NSEvent) {
		self.touchMoved(toPoint: event.location(in: self))
	}
	
	override func mouseUp(with event: NSEvent) {
		self.touchUp(atPoint: event.location(in: self))
	}
	
	func updateColor() {
		self.color = component.inputsComplete()
			? CompleteConnectionsColor
			: IncompleteConnectionsColor
	}
}

class SingleComponentView: ComponentView {
	override init(component comp: Component, gameScene: GameScene) {
		super.init(component: comp, gameScene: gameScene)

		assert((component as? Single) != nil)
		updateColor()
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func updateColor() {
		self.color = component.inputsComplete()
			? (self.component.getOutputValue(outputIndex: 0)
				? ConnectionColor
				: NoConnectionColor)
			: IncompleteConnectionsColor
	}
}

class GlobalInputComponentView: ComponentView {
	override init(component comp: Component, gameScene: GameScene) {
		super.init(component: comp, gameScene: gameScene)
		updateColor()
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func touchDown(atPoint pos : CGPoint) {
		let g = self.component as! GlobalInput
		g.state = !g.state
		super.touchDown(atPoint: pos)
		component.inputsChanged.raise(data: ())
		
		updateColor()
	}
	
	override func updateColor() {
		self.color = component.getOutputValue(outputIndex: 0)
			? ConnectionColor
			: NoConnectionColor
	}
}

func createComponentView(c: Component, g: GameScene) -> ComponentView {
	if let _ = c as? Single {
		return SingleComponentView(component: c, gameScene: g)
	}
	if let _ = c as? GlobalInput {
		return GlobalInputComponentView(component: c, gameScene: g)
	}
	return ComponentView(component: c, gameScene: g)
}
