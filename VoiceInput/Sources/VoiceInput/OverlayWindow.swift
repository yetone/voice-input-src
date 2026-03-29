import Cocoa
import CoreAudio

class OverlayWindow: NSPanel {
    private var visualEffectView: NSVisualEffectView!
    private var waveformContainer: NSView!
    private var waveformBars: [WaveformBar] = []
    private var textLabel: NSTextField!
    private var currentText = ""
    
    private let weights: [CGFloat] = [0.5, 0.8, 1.0, 0.75, 0.55]
    private let attackTime: CGFloat = 0.4
    private let releaseTime: CGFloat = 0.15
    
    private var audioLevelMonitor: AudioLevelMonitor?
    private var audioLevel: Float = 0.0
    private var smoothedLevels: [CGFloat] = [0, 0, 0, 0, 0]
    
    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
    }
    
    convenience init() {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let initialWidth: CGFloat = 280
        let height: CGFloat = 56
        
        let rect = NSRect(
            x: (screenFrame.width - initialWidth) / 2,
            y: screenFrame.minY + 100,
            width: initialWidth,
            height: height
        )
        
        self.init(
            contentRect: rect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = false
        self.hasShadow = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.backgroundColor = .clear
        
        setupVisualEffect()
        setupWaveform()
        setupTextLabel()
    }
    
    private func setupVisualEffect() {
        visualEffectView = NSVisualEffectView(frame: bounds)
        // Use .contentBackground for macOS 13 compatibility (hudWindow requires macOS 14+)
        if #available(macOS 14.0, *) {
            visualEffectView.material = .hudWindow
        } else {
            visualEffectView.material = .contentBackground
        }
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 28
        visualEffectView.layer?.masksToBounds = true

        contentView = visualEffectView
    }
    
    private func setupWaveform() {
        waveformContainer = NSView(frame: NSRect(x: 16, y: 12, width: 44, height: 32))
        visualEffectView.addSubview(waveformContainer)
        
        let barWidth: CGFloat = 6
        let spacing: CGFloat = 2
        let totalWidth = CGFloat(weights.count) * barWidth + CGFloat(weights.count - 1) * spacing
        let startX = (waveformContainer.frame.width - totalWidth) / 2
        
        for i in 0..<weights.count {
            let bar = WaveformBar(
                frame: NSRect(
                    x: startX + CGFloat(i) * (barWidth + spacing),
                    y: 0,
                    width: barWidth,
                    height: 32
                ),
                weight: weights[i]
            )
            waveformContainer.addSubview(bar)
            waveformBars.append(bar)
        }
        
        startAudioMonitoring()
    }
    
    private func startAudioMonitoring() {
        audioLevelMonitor = AudioLevelMonitor()
        audioLevelMonitor?.levelUpdateHandler = { [weak self] level in
            self?.updateWaveformLevels(with: level)
        }
        audioLevelMonitor?.startMonitoring()
    }
    
    private func stopAudioMonitoring() {
        audioLevelMonitor?.stopMonitoring()
    }
    
    private func setupTextLabel() {
        textLabel = NSTextField(labelWithString: "")
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.font = NSFont.systemFont(ofSize: 15, weight: .regular)
        textLabel.textColor = .white
        textLabel.alignment = .left
        textLabel.lineBreakMode = .byTruncatingTail
        textLabel.maximumNumberOfLines = 1
        
        visualEffectView.addSubview(textLabel)
        
        NSLayoutConstraint.activate([
            textLabel.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 76),
            textLabel.trailingAnchor.constraint(lessThanOrEqualTo: visualEffectView.trailingAnchor, constant: -16),
            textLabel.centerYAnchor.constraint(equalTo: visualEffectView.centerYAnchor),
            textLabel.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    func show() {
        makeKeyAndOrderFront(nil)
        
        // Entry animation with spring
        animator().alphaValue = 0
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.68, -0.55, 0.265, 1.55)
            self.animator().alphaValue = 1
        }, completionHandler: nil)
        
        audioLevelMonitor?.startMonitoring()
    }
    
    func hide() {
        audioLevelMonitor?.stopMonitoring()
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0
            // Skip scale animation for macOS 13 compatibility
            if #available(macOS 14.0, *) {
                self.animator().scale(by: 0.8)
            }
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
        })
    }
    
    func updateText(_ text: String) {
        guard text != currentText else { return }
        currentText = text
        
        // Animate text width transition
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            textLabel.stringValue = text
            
            // Update window size based on text length
            let textSize = text.boundingRect(with: CGSize(width: 400, height: 24), options: .usesLineFragmentOrigin)
            let newWidth = min(max(160 + textSize.width, 280), 560)
            
            if let screen = screen {
                let screenFrame = screen.visibleFrame
                let newY = screenFrame.minY + 100
                let newX = (screenFrame.width - newWidth) / 2
                
                setFrame(NSRect(x: newX, y: newY, width: newWidth, height: 56), display: true)
            }
        }, completionHandler: nil)
    }
    
    func showRefiningState() {
        textLabel.stringValue = "Refining..."
    }
    
    private func updateWaveformLevels(with level: Float) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            var audioLevel = level
            
            // Smooth the level with attack/release envelope
            if level > self.audioLevel {
                audioLevel = self.audioLevel + (level - self.audioLevel) * Float(self.attackTime)
            } else {
                audioLevel = self.audioLevel - (self.audioLevel - level) * Float(self.releaseTime)
            }
            self.audioLevel = audioLevel
            
            for i in 0..<self.weights.count {
                let baseLevel = audioLevel * Float(self.weights[i])
                // Add ±4% random jitter for organic feel
                let jitter = Float.random(in: -0.04...0.04)
                let targetHeight = max(0.05, min(1.0, CGFloat(baseLevel + jitter)))
                
                // Smooth transition
                self.smoothedLevels[i] += (targetHeight - self.smoothedLevels[i]) * 0.3
                
                if i < self.waveformBars.count {
                    self.waveformBars[i].setLevel(self.smoothedLevels[i])
                }
            }
        }
    }
}

class WaveformBar: NSView {
    private var level: CGFloat = 0.0
    private let weight: CGFloat
    private let shapeLayer: CAShapeLayer = CAShapeLayer()
    
    init(frame: NSRect, weight: CGFloat) {
        self.weight = weight
        super.init(frame: frame)
        wantsLayer = true
        setupLayer()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupLayer() {
        layer?.addSublayer(shapeLayer)
        shapeLayer.fillColor = NSColor.white.cgColor
        shapeLayer.cornerRadius = 3
    }
    
    func setLevel(_ level: CGFloat) {
        self.level = level
        updateShape()
    }
    
    private func updateShape() {
        let maxHeight = bounds.height
        let barHeight = maxHeight * level
        
        let path = CGMutablePath()
        let y = (bounds.height - barHeight) / 2
        // Use cornerWidth and cornerHeight parameters for macOS 13 compatibility
        path.addRoundedRect(in: CGRect(x: 0, y: y, width: bounds.width, height: barHeight), cornerWidth: 3, cornerHeight: 3)
        
        shapeLayer.path = path
    }
}

// Extension to track recording state
extension OverlayWindow {
    var isRecording: Bool {
        // Access via AppDelegate.shared singleton
        return AppDelegate.shared?.recordingState ?? false
    }
}
