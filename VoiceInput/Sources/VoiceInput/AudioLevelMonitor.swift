import AVFoundation
import CoreAudio

class AudioLevelMonitor {
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioNode?
    private var isMonitoring = false
    
    var currentLevel: Float = 0.0
    var levelUpdateHandler: ((Float) -> Void)?
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode
        
        let recordingFormat = inputNode?.outputFormat(forBus: 0)
        
        inputNode?.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, time in
            self?.analyzeBuffer(buffer)
        }
        
        do {
            try audioEngine?.start()
            isMonitoring = true
        } catch {
            print("Failed to start audio engine for monitoring: \(error)")
        }
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        isMonitoring = false
        currentLevel = 0.0
    }
    
    private func analyzeBuffer(_ buffer: AVAudioPCMBuffer) {
        let channelData = buffer.floatChannelData?[0]
        let frameLength = Int(buffer.frameLength)
        
        guard let data = channelData else { return }
        
        var sum: Float = 0.0
        for i in 0..<frameLength {
            let sample = data[i]
            sum += sample * sample
        }
        
        let rms = sqrt(sum / Float(frameLength))
        currentLevel = min(1.0, rms * 3.0) // Scale up for better visualization
        
        DispatchQueue.main.async { [weak self] in
            self?.levelUpdateHandler?(self?.currentLevel ?? 0.0)
        }
    }
}
