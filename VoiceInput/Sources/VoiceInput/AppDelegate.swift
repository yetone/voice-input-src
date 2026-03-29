import Cocoa
import Speech
import AVFoundation
import CoreGraphics
import Carbon.HIToolbox

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    
    private var isRecording = false
    private var overlayWindow: OverlayWindow?
    private var currentTranscript = ""
    
    private let userDefaults = UserDefaults.standard
    
    static weak var shared: AppDelegate?
    
    var recordingState: Bool {
        return isRecording
    }
    
    override init() {
        super.init()
        AppDelegate.shared = self
        setupUserDefaults()
    }
    
    private func setupUserDefaults() {
        if userDefaults.object(forKey: "selectedLanguage") == nil {
            userDefaults.set("zh-CN", forKey: "selectedLanguage")
        }
        if userDefaults.object(forKey: "llmEnabled") == nil {
            userDefaults.set(true, forKey: "llmEnabled")
        }
        if userDefaults.object(forKey: "apiBaseURL") == nil {
            userDefaults.set("", forKey: "apiBaseURL")
        }
        if userDefaults.object(forKey: "apiKey") == nil {
            userDefaults.set("", forKey: "apiKey")
        }
        if userDefaults.object(forKey: "model") == nil {
            userDefaults.set("gpt-4o-mini", forKey: "model")
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        setupEventTap()
        
        // Request speech recognition authorization
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    print("Speech recognition authorized")
                case .denied, .restricted, .notDetermined:
                    print("Speech recognition not authorized: \(authStatus)")
                @unknown default:
                    break
                }
            }
        }
        
        // Request microphone access (macOS 14+ uses AVAudioSession, fallback for macOS 13)
        if #available(macOS 14.0, *) {
            // AVAudioSession is available on macOS 14+
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if granted {
                        print("Microphone access granted")
                    } else {
                        print("Microphone access denied")
                    }
                }
            }
        } else {
            // For macOS 13, we rely on the system prompt when first accessing the microphone
            print("Microphone access will be requested on first use")
        }
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Voice Input") // SF Symbols available since macOS 11.0
            button.action = #selector(showMenu)
        }
        
        let menu = NSMenu()
        
        let languageItem = NSMenuItem(title: "Language", action: nil, keyEquivalent: "")
        let languageMenu = NSMenu()
        
        let languages = [
            ("zh-CN", "简体中文"),
            ("zh-TW", "繁體中文"),
            ("en-US", "English"),
            ("ja-JP", "日本語"),
            ("ko-KR", "한국어")
        ]
        
        for (code, name) in languages {
            let item = NSMenuItem(title: name, action: #selector(changeLanguage(_:)), keyEquivalent: "")
            item.tag = languages.firstIndex(where: { $0.0 == code }) ?? 0
            item.state = (userDefaults.string(forKey: "selectedLanguage") == code) ? .on : .off
            languageMenu.addItem(item)
        }
        
        languageItem.submenu = languageMenu
        menu.addItem(languageItem)
        
        let llmItem = NSMenuItem(title: "LLM Refinement", action: nil, keyEquivalent: "")
        let llmMenu = NSMenu()
        
        let toggleLLM = NSMenuItem(title: "Enable LLM", action: #selector(toggleLLM(_:)), keyEquivalent: "")
        toggleLLM.state = userDefaults.bool(forKey: "llmEnabled") ? .on : .off
        llmMenu.addItem(toggleLLM)
        
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        llmMenu.addItem(settingsItem)
        
        llmItem.submenu = llmMenu
        menu.addItem(llmItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc private func showMenu() {
        statusItem?.button?.performClick(nil)
    }
    
    @objc private func changeLanguage(_ sender: NSMenuItem) {
        let languages = ["zh-CN", "zh-TW", "en-US", "ja-JP", "ko-KR"]
        if let tag = sender.tag, tag < languages.count {
            userDefaults.set(languages[tag], forKey: "selectedLanguage")
            
            // Update menu states
            if let submenu = statusItem?.menu?.item(withTitle: "Language")?.submenu {
                for item in submenu.items {
                    item.state = .off
                }
                sender.state = .on
            }
        }
    }
    
    @objc private func toggleLLM(_ sender: NSMenuItem) {
        let enabled = !userDefaults.bool(forKey: "llmEnabled")
        userDefaults.set(enabled, forKey: "llmEnabled")
        sender.state = enabled ? .on : .off
    }
    
    @objc private func openSettings() {
        let settingsWindow = SettingsWindow()
        settingsWindow.makeKeyAndOrderFront(nil)
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    private func setupEventTap() {
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                let delegate = Unmanaged<AppDelegate>.fromOpaque(refcon!).takeUnretainedValue()
                return delegate.handleKeyEvent(event: event, type: type)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("Failed to create event tap")
            return
        }
        
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }
    
    private func handleKeyEvent(event: CGEvent, type: CGEventType) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        
        // Fn key keycode is typically 63 on macOS
        if keyCode == 63 {
            if type == .keyDown && !isRecording {
                startRecording()
                return nil // Suppress the Fn key event
            } else if type == .keyUp && isRecording {
                stopRecording()
                return nil // Suppress the Fn key event
            }
        }
        
        return Unmanaged.passRetained(event)
    }
    
    private func startRecording() {
        isRecording = true
        currentTranscript = ""
        
        // Create overlay window
        overlayWindow = OverlayWindow()
        overlayWindow?.show()
        
        startSpeechRecognition()
    }
    
    private func stopRecording() {
        isRecording = false
        
        stopSpeechRecognition()
        
        // Check if LLM refinement is enabled
        let llmEnabled = userDefaults.bool(forKey: "llmEnabled")
        let apiKey = userDefaults.string(forKey: "apiKey") ?? ""
        let apiBaseURL = userDefaults.string(forKey: "apiBaseURL") ?? ""
        
        if llmEnabled && !apiKey.isEmpty {
            overlayWindow?.showRefiningState()
            refineWithLLM(transcript: currentTranscript, baseURL: apiBaseURL, apiKey: apiKey) { [weak self] refinedText in
                DispatchQueue.main.async {
                    self?.injectText(refinedText ?? self?.currentTranscript ?? "")
                    self?.overlayWindow?.hide()
                    self?.overlayWindow = nil
                }
            }
        } else {
            injectText(currentTranscript)
            overlayWindow?.hide()
            overlayWindow = nil
        }
    }
    
    private func startSpeechRecognition() {
        guard let speechRecognizer = speechRecognizer else {
            print("Speech recognizer not available")
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let inputNode = AVAudioEngine().inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine = AVAudioEngine()
        
        do {
            try audioEngine?.start()
        } catch {
            print("Audio engine failed to start: \(error)")
            return
        }
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest!) { result, error in
            if let result = result {
                self.currentTranscript = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.overlayWindow?.updateText(self.currentTranscript)
                }
            }
            
            if error != nil || result?.isFinal == true {
                self.audioEngine?.stop()
                self.audioEngine?.inputNode.removeTap(onBus: 0)
            }
        }
    }
    
    private func stopSpeechRecognition() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
    }
    
    private func refineWithLLM(transcript: String, baseURL: String, apiKey: String, completion: @escaping (String?) -> Void) {
        let systemPrompt = """
        You are a conservative voice transcription corrector. Your task is to fix only obvious speech recognition errors:
        - Chinese homophone errors (e.g., wrong characters that sound similar)
        - English technical terms incorrectly transcribed as Chinese (e.g., "配森" → "Python", "杰森" → "JSON")
        
        Rules:
        - DO NOT rewrite, polish, or delete any content that appears correct
        - If the input looks correct, return it exactly as-is
        - Only fix clear, obvious errors
        - Preserve the original language and style
        - Return ONLY the corrected text, no explanations
        """
        
        let url: URL
        if baseURL.isEmpty {
            url = URL(string: "https://api.openai.com/v1/chat/completions")!
        } else {
            url = URL(string: baseURL.hasSuffix("/chat/completions") ? baseURL : "\(baseURL)/chat/completions")!
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let model = userDefaults.string(forKey: "model") ?? "gpt-4o-mini"
        
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": transcript]
            ],
            "temperature": 0.1,
            "max_tokens": 1000
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("LLM API error: \(error)")
                completion(nil)
                return
            }
            
            guard let data = data else {
                completion(nil)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    completion(content)
                } else {
                    completion(nil)
                }
            } catch {
                print("JSON parsing error: \(error)")
                completion(nil)
            }
        }.resume()
    }
    
    private func injectText(_ text: String) {
        guard !text.isEmpty else { return }
        
        // Save current clipboard content
        let pasteboard = NSPasteboard.general
        let oldContent = pasteboard.string(forType: .string)
        
        // Set new text to clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Check current input source and switch to ASCII if needed
        var switchedSource = false
        if isCJKInputSource() {
            // Switch to US keyboard
            if let usSource = getUSInputSource() {
                TISEnableInputSource(usSource)
                TISSelectInputSource(usSource)
                switchedSource = true
            }
        }
        
        // Small delay to ensure source switch completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            // Simulate Cmd+V
            let source = CGEventSource(stateID: .combinedSessionState)
            let flags = CGEventFlags.maskCommand
            
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
            keyDown?.flags = flags
            keyDown?.post(tap: .cghidEventTap)
            
            usleep(50000) // 50ms
            
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
            keyUp?.flags = flags
            keyUp?.post(tap: .cghidEventTap)
            
            // Restore original clipboard
            if let old = oldContent {
                pasteboard.clearContents()
                pasteboard.setString(old, forType: .string)
            }
            
            // Restore original input source if we switched
            if switchedSource, let origSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() {
                TISSelectInputSource(origSource)
            }
        }
    }
    
    private func isCJKInputSource() -> Bool {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return false
        }
        let categoryPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceCategory)
        guard let category = categoryPtr else { return false }
        let categoryStr = Unmanaged<CFString>.fromOpaque(category).takeUnretainedValue() as String
        
        return categoryStr == kTISCategoryChineseInput || 
               categoryStr == kTISCategoryJapaneseInput || 
               categoryStr == kTISCategoryKoreanInput
    }
    
    private func getUSInputSource() -> TISInputSource? {
        guard let inputSources = TISCopyInputSourceList(kTISPropertyInputSourceType == "Keyboard" as CFString)?.takeRetainedValue() as? [TISInputSource] else {
            return nil
        }
        
        for src in inputSources {
            let langPtr = TISGetInputSourceProperty(src, kTISPropertyInputSourceLanguage)
            if let lang = langPtr {
                let langStr = Unmanaged<CFString>.fromOpaque(lang).takeUnretainedValue() as String
                if langStr == "en" {
                    return src
                }
            }
        }
        return nil
    }
}
