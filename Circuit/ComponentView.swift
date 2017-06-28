import Foundation
import SpriteKit

let NoConnectionColor = NSColor.red
let ConnectionColor = NSColor.green
let IncompleteConnectionsColor = NSColor.yellow
let CompleteConnectionsColor = NSColor.white

class ConnectorNode: SKSpriteNode {
	private var connectingLineNodes = Dictionary<ConnectorNode, SKShapeNode>()
	// the currently-being-dragged line we treat as being connected to self
	private var connections = Set<ConnectorNode>()
	private var isTouchDown = false
	private var overrideIsTouchDown = false
	private var previousConnection: ConnectorNode?
	
	enum ConnectorType {
		case InputConnector
		case OutputConnector
	}
	let connectorType: ConnectorType
	let component: ComponentView
	let connectorIndex: Int
	init(component c: ComponentView, connectorIndex i: Int, connectorType type: ConnectorType) {
		component = c
		connectorIndex = i
		connectorType = type
		super.init(texture: nil, color: NSColor.blue, size: CGSize(width: 15, height: 15))
		self.zPosition = 1.0
		self.isUserInteractionEnabled = true
		self.name = "connector"
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	func updateConnectionLine(forConnection connection: ConnectorNode, newPos pos: CGPoint) {
		guard connectorType == ConnectorType.OutputConnector else { return }
		if let oldLineNode = connectingLineNodes[connection] {
			oldLineNode.removeFromParent()
		}
		
		let xDistance = abs(pos.x)
		let curveAmount = xDistance / 2.0
		var points = [
			CGPoint.zero,
			CGPoint(x: curveAmount, y: 0),
			CGPoint(x: pos.x - curveAmount, y: pos.y),
			pos,
			]
		let newNode = SKShapeNode(points: &points, count: points.count)
		newNode.lineWidth = 3
		newNode.strokeColor = NSColor(calibratedWhite: 1.0, alpha: 0.5)
		newNode.name = "connectingLineNode"
		newNode.isUserInteractionEnabled = false
		newNode.zPosition = -5.0
		addChild(newNode)
		connectingLineNodes.updateValue(newNode, forKey: connection)
	}
	
	func updateConnectionLine(forConnection connection: ConnectorNode) {
		let newPos = self.convert(CGPoint.zero, from: connection)
		updateConnectionLine(forConnection: connection, newPos: newPos)
	}
	
	func updateAllConnectionLines() {
		for connection in connectingLineNodes.keys {
			updateConnectionLine(forConnection: connection)
		}
	}
	
	func severConnection(_ connection: ConnectorNode) {
		connectingLineNodes[connection]?.removeFromParent()
		connectingLineNodes.removeValue(forKey: connection)
		if connections.contains(connection) {
			connection.component.removeConnectionLine(connectorIndex: connection.connectorIndex)
		}
		connections.remove(connection)
	}
	
	func touchDown(atPoint pos : CGPoint) {
		if connectorType == ConnectorType.InputConnector {
			if let existingConnection = self.component.getConnectionLine(inputIndex: self.connectorIndex) {
				existingConnection.severConnection(self)
				previousConnection = existingConnection
				existingConnection.overrideIsTouchDown = true
				existingConnection.touchDown(atPoint: convert(pos, to: existingConnection))
				existingConnection.overrideIsTouchDown = false
				isTouchDown = true
			} else {
				isTouchDown = false
			}
		} else {
			if overrideIsTouchDown || self.frame.contains(self.convert(pos, to: self.parent!)) {
				isTouchDown = true
				updateConnectionLine(forConnection: self, newPos: pos)
			} else {
				isTouchDown = false
			}
		}
	}
	
	func touchMoved(toPoint pos : CGPoint) {
		guard isTouchDown else { return }
		guard connectorType == ConnectorType.OutputConnector else {
			if let previousConnection = previousConnection {
				previousConnection.touchMoved(toPoint: convert(pos, to: previousConnection))
			}
			return
		}
		
		updateConnectionLine(forConnection: self, newPos: pos)
	}
	
	func touchUp(atPoint pos : CGPoint) {
		guard isTouchDown else { return }
		guard connectorType == ConnectorType.OutputConnector else {
			if let previousConnection = previousConnection {
				previousConnection.touchUp(atPoint: convert(pos, to: previousConnection))
			}
			return
		}
		severConnection(self)
		var newConnection: ConnectorNode?
		let worldPos = self.convert(pos, to: self.scene!)
		self.scene!.enumerateChildNodes(withName: "//component/connector", using: { (node: SKNode, stop: UnsafeMutablePointer<ObjCBool>) in
			guard node != self else { return }
			let nodePoint = node.parent!.convert(worldPos, from: self.scene!)
			if node.frame.contains(nodePoint) {
				if let connector = node as? ConnectorNode, connector.connectorType == ConnectorType.InputConnector {
					stop.initialize(to: true)
					self.connections.insert(connector)
					connector.component.receiveConnectionLine(node: self, inputIndex: connector.connectorIndex)
					newConnection = connector
				}
			}
		})
		if let newConnection = newConnection {
			updateConnectionLine(forConnection: newConnection)
		}
		isTouchDown = false
	}
	
	override func mouseDown(with event: NSEvent) {
		self.touchDown(atPoint: event.location(in: self))
	}
	
	override func mouseDragged(with event: NSEvent) {
		self.touchMoved(toPoint: event.location(in: self))
	}
	
	override func mouseUp(with event: NSEvent) {
		self.touchUp(atPoint: event.location(in: self))
	}
}

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
	
	func setUpConnectorNodes() {
		let createNode = {(num: Int, total: Int, edge: Int) -> Void in
			let frac = 1.0 / CGFloat(total + 1)
			let node = ConnectorNode(component: self,
			                         connectorIndex: num,
			                         connectorType: edge == 0
										? ConnectorNode.ConnectorType.InputConnector
										: ConnectorNode.ConnectorType.OutputConnector)
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
		setUpConnectorNodes()
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
