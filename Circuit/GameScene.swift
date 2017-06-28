import SpriteKit
import GameplayKit

class AddButton: SKSpriteNode {
	override init(texture: SKTexture?, color: NSColor, size: CGSize) {
		super.init(texture: texture, color: color, size: size)
		self.isUserInteractionEnabled = true
	}
	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		self.isUserInteractionEnabled = true
	}
	
	func touchDown(atPoint pos : CGPoint) {
		if let scene = self.scene as? GameScene {
			if let type = (self.userData?["type"] as? String) {
				switch type {
				case "and":
					scene.createComponentViewWithComponent(comp: AndGate())
				case "or":
					scene.createComponentViewWithComponent(comp: OrGate())
				case "not":
					scene.createComponentViewWithComponent(comp: NotGate())
				case "single":
					scene.createComponentViewWithComponent(comp: Single())
				case "globalInput":
					scene.createComponentViewWithComponent(comp: GlobalInput())
				default:
					fatalError("bad userdata in add button")
				}
			}
		}
	}
	override func mouseDown(with event: NSEvent) {
		self.touchDown(atPoint: event.location(in: self))
	}
}

class GameScene: SKScene {
	
    private var label : SKLabelNode?
    private var spinnyNode : SKShapeNode?
	
	let model = Model()
    let viewState = CircuitViewState()
	
	func doSanityTests() {
		let g1 = GlobalInput()
		let g2 = GlobalInput()
		let and = AndGate()
		and.receiveConnection(comp: (g1, 0), input: 0)
		and.receiveConnection(comp: (g2, 0), input: 1)
		assert(!and.getOutputValue(outputIndex: 0))
		g1.state = true
		assert(!and.getOutputValue(outputIndex: 0))
		g2.state = true
		assert(and.getOutputValue(outputIndex: 0))
		g1.state = false
		assert(!and.getOutputValue(outputIndex: 0))
		
		let g3 = GlobalInput()
		let s1 = Single()
		let or = OrGate()
		or.receiveConnection(comp: (and, 0), input: 0)
		or.receiveConnection(comp: (g3, 0), input: 1)
		assert(!or.getOutputValue(outputIndex: 0))
		g1.state = true
		assert(or.getOutputValue(outputIndex: 0))
		g1.state = false
		g3.state = true
		assert(or.getOutputValue(outputIndex: 0))
		
		s1.receiveConnection(comp: (g3, 0), input: 0)
		or.receiveConnection(comp: (s1, 0), input: 1)
		assert(or.getOutputValue(outputIndex: 0))
	}
    
    override func didMove(to view: SKView) {
		doSanityTests()
    }
	
	func createComponentViewWithComponent(comp: Component) {
		model.addComponent(comp)
		let componentView = createComponentView(c: comp, g: self)
		componentView.position = CGPoint(x: self.size.width/2.0, y: self.size.height/2.0)
		addChild(componentView)
	}
}
