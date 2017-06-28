import Foundation
import SpriteKit

let IncompleteConnectorColor = NSColor.white

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
    init(component c: ComponentView, connectorIndex i: Int, connectorType type: ConnectorType, gameScene: GameScene) {
        component = c
        connectorIndex = i
        connectorType = type
        super.init(texture: nil, color: NSColor.white, size: CGSize(width: 15, height: 15))
        self.zPosition = 1.0
        self.isUserInteractionEnabled = true
        self.name = "connector"
        self.colorBlendFactor = 1.0
        if self.connectorType == ConnectorType.OutputConnector {
            gameScene.model.circuitStateChanged.addHandler(handler: updateColor)
        }
        updateColor()
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

    func updateColor() {
        self.color = self.connectorType == ConnectorType.InputConnector
            ? GenericConnectorColor
            : self.component.component.inputsComplete()
                ? (self.component.component.getOutputValue(outputIndex: self.connectorIndex)
                    ? ConnectionColor
                    : NoConnectionColor)
                : IncompleteConnectorColor
    }
}
