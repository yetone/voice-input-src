import Cocoa

class SettingsWindow: NSWindow {
    private var apiBaseURLField: NSTextField!
    private var apiKeyField: NSSecureTextField!
    private var modelField: NSTextField!
    
    convenience init() {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let width: CGFloat = 400
        let height: CGFloat = 280
        
        let rect = NSRect(
            x: (screenFrame.width - width) / 2,
            y: (screenFrame.height - height) / 2,
            width: width,
            height: height
        )
        
        self.init(
            contentRect: rect,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        self.title = "LLM Settings"
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces]
        
        setupUI()
    }
    
    private func setupUI() {
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: frame.width, height: frame.height))
        self.contentView = contentView
        
        let userDefaults = UserDefaults.standard
        
        // API Base URL
        let baseURLLabel = NSTextField(labelWithString: "API Base URL:")
        baseURLLabel.frame = NSRect(x: 20, y: 220, width: 120, height: 22)
        contentView.addSubview(baseURLLabel)
        
        apiBaseURLField = NSTextField(frame: NSRect(x: 150, y: 220, width: 230, height: 22))
        apiBaseURLField.stringValue = userDefaults.string(forKey: "apiBaseURL") ?? ""
        apiBaseURLField.placeholderString = "https://api.openai.com/v1"
        contentView.addSubview(apiBaseURLField)
        
        // API Key
        let apiKeyLabel = NSTextField(labelWithString: "API Key:")
        apiKeyLabel.frame = NSRect(x: 20, y: 180, width: 120, height: 22)
        contentView.addSubview(apiKeyLabel)
        
        apiKeyField = NSSecureTextField(frame: NSRect(x: 150, y: 180, width: 230, height: 22))
        apiKeyField.stringValue = userDefaults.string(forKey: "apiKey") ?? ""
        apiKeyField.placeholderString = "sk-..."
        contentView.addSubview(apiKeyField)
        
        // Clear API Key button
        let clearButton = NSButton(frame: NSRect(x: 350, y: 178, width: 30, height: 26))
        clearButton.title = "✕"
        clearButton.bezelStyle = .rounded
        clearButton.target = self
        clearButton.action = #selector(clearAPIKey)
        contentView.addSubview(clearButton)
        
        // Model
        let modelLabel = NSTextField(labelWithString: "Model:")
        modelLabel.frame = NSRect(x: 20, y: 140, width: 120, height: 22)
        contentView.addSubview(modelLabel)
        
        modelField = NSTextField(frame: NSRect(x: 150, y: 140, width: 230, height: 22))
        modelField.stringValue = userDefaults.string(forKey: "model") ?? "gpt-4o-mini"
        modelField.placeholderString = "gpt-4o-mini"
        contentView.addSubview(modelField)
        
        // Test button
        let testButton = NSButton(frame: NSRect(x: 150, y: 80, width: 100, height: 30))
        testButton.title = "Test"
        testButton.bezelStyle = .rounded
        testButton.target = self
        testButton.action = #selector(testConnection)
        contentView.addSubview(testButton)
        
        // Save button
        let saveButton = NSButton(frame: NSRect(x: 280, y: 80, width: 100, height: 30))
        saveButton.title = "Save"
        saveButton.bezelStyle = .rounded
        saveButton.target = self
        saveButton.action = #selector(saveSettings)
        contentView.addSubview(saveButton)
        
        // Status label
        let statusLabel = NSTextField(labelWithString: "")
        statusLabel.tag = 999
        statusLabel.frame = NSRect(x: 20, y: 40, width: 360, height: 22)
        statusLabel.alignment = .center
        statusLabel.textColor = .gray
        contentView.addSubview(statusLabel)
    }
    
    @objc private func clearAPIKey() {
        apiKeyField.stringValue = ""
    }
    
    @objc private func testConnection() {
        let apiKey = apiKeyField.stringValue
        let baseURL = apiBaseURLField.stringValue
        let model = modelField.stringValue
        
        guard !apiKey.isEmpty else {
            updateStatus("Please enter an API key", color: .systemRed)
            return
        }
        
        updateStatus("Testing...", color: .systemBlue)
        
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
        
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": "Hello"]
            ],
            "max_tokens": 10
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.updateStatus("Error: \(error.localizedDescription)", color: .systemRed)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    self?.updateStatus("Connection successful!", color: .systemGreen)
                } else {
                    self?.updateStatus("Connection failed", color: .systemRed)
                }
            }
        }.resume()
    }
    
    @objc private func saveSettings() {
        let userDefaults = UserDefaults.standard
        userDefaults.set(apiBaseURLField.stringValue, forKey: "apiBaseURL")
        userDefaults.set(apiKeyField.stringValue, forKey: "apiKey")
        userDefaults.set(modelField.stringValue, forKey: "model")
        
        updateStatus("Settings saved!", color: .systemGreen)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.close()
        }
    }
    
    private func updateStatus(_ message: String, color: NSColor) {
        guard let contentView = contentView else { return }
        for subview in contentView.subviews {
            if let label = subview as? NSTextField, label.tag == 999 {
                label.stringValue = message
                label.textColor = color
                break
            }
        }
    }
}
