import Foundation
import SpriteKit

let NoConnectionColor = NSColor.red
let ConnectionColor = NSColor.green

class ConnectorNode: SKSpriteNode {
	private var connectingLineNode: SKShapeNode?
	private var connection: ConnectorNode?
	private var touchDown = false
	
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
	
	func updateConnectionLine(newPos pos: CGPoint) {
		guard connectorType == ConnectorType.OutputConnector else { return }
		if let oldLineNode = connectingLineNode {
			oldLineNode.removeFromParent()
		}
		var points = [
			CGPoint.zero,
			pos,
			]
		connectingLineNode = SKShapeNode(points: &points, count: points.count)
		connectingLineNode?.isUserInteractionEnabled = false
		connectingLineNode?.zPosition = -5.0
		addChild(connectingLineNode!)
	}
	
	func updateConnectionLine() {
		guard let connection = self.connection else { return }
		let newPos = self.convert(CGPoint.zero, from: connection)
		updateConnectionLine(newPos: newPos)
	}
	
	func severConnection() {
		connectingLineNode?.removeFromParent()
		if let c = connection {
			c.component.removeConnectionLine(connectorIndex: c.connectorIndex)
		}
		connection = nil
	}
	
	func touchDown(atPoint pos : CGPoint) {
		if self.frame.contains(self.convert(pos, to: self.parent!)) {
			touchDown = true
			severConnection()
			updateConnectionLine(newPos: pos)
		} else {
			touchDown = false
		}
	}
	
	func touchMoved(toPoint pos : CGPoint) {
		guard touchDown else { return }
		updateConnectionLine(newPos: pos)
	}
	
	func touchUp(atPoint pos : CGPoint) {
		guard touchDown else { return }
		var boundToTarget = false
		guard connectorType == ConnectorType.OutputConnector else { return }
		let worldPos = self.convert(pos, to: self.scene!)
		self.scene!.enumerateChildNodes(withName: "//component/connector", using: { (node: SKNode, stop: UnsafeMutablePointer<ObjCBool>) in
			guard node != self else { return }
			let nodePoint = node.parent!.convert(worldPos, from: self.scene!)
			if node.frame.contains(nodePoint) {
				if let connector = node as? ConnectorNode, connector.connectorType == ConnectorType.InputConnector {
					self.severConnection()
					stop.initialize(to: true)
					self.connection = connector
					connector.component.receiveConnectionLine(node: self, inputIndex: connector.connectorIndex)
					boundToTarget = true
				}
			}
		})
		if !boundToTarget {
			connectingLineNode?.removeFromParent()
			connectingLineNode = nil
		} else {
			updateConnectionLine()
		}
		touchDown = false
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
	
	func receiveConnectionLine(node: ConnectorNode, inputIndex: Int) {
		if let oldConnectionLine = self.receivingConnectionLines[inputIndex] {
			oldConnectionLine.severConnection()
		}
		self.receivingConnectionLines.updateValue(node, forKey: inputIndex)
		self.component.receiveConnection(comp: (node.component.component, node.connectorIndex), input: inputIndex)
	}
	func removeConnectionLine(connectorIndex: Int) {
		self.receivingConnectionLines.removeValue(forKey: connectorIndex)
		self.component.removeConnection(input: connectorIndex)
	}
	
	func updateOutputConnectionLines() {
		for c in connectors.filter({ $0.connectorType == ConnectorNode.ConnectorType.OutputConnector }) {
			c.updateConnectionLine()
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
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	func touchDown(atPoint pos : CGPoint) {
		self.zPosition = 1.0
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
	
	func touchUp(atPoint pos : CGPoint) {
		self.zPosition = 0.0
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

class SingleComponentView: ComponentView {
	override init(component comp: Component, gameScene: GameScene) {
		super.init(component: comp, gameScene: gameScene)

		assert((component as? Single) != nil)
		updateColor()
		gameScene.model.circuitStateChanged.addHandler(handler: updateColor)
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	func updateColor() {
		self.color = self.component.getOutputValue(outputIndex: 0)
			? ConnectionColor
			: NoConnectionColor
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
	
	func updateColor() {
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
