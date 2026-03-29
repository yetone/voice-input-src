import Cocoa
import Carbon

struct InputSourceHelper {
    static func getCurrentInputSource() -> TISInputSource? {
        return TISCopyCurrentKeyboardInputSource()?.takeRetainedValue()
    }
    
    static func isCJKInput(source: TISInputSource?) -> Bool {
        guard let source = source else { return false }
        
        let categoryPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceCategory)
        guard let categoryPtr = categoryPtr else { return false }
        let category = Unmanaged<CFString>.fromOpaque(categoryPtr).takeUnretainedValue() as String
        
        return category == kTISCategoryChineseInput ||
               category == kTISCategoryJapaneseInput ||
               category == kTISCategoryKoreanInput
    }
    
    static func switchToASCIIInput() -> Bool {
        guard let inputSources = TISCopyInputSourceList(kTISPropertyInputSourceType == "Keyboard" as CFString)?.takeRetainedValue() as? [TISInputSource] else {
            return false
        }
        
        for source in inputSources {
            let langPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguage)
            if let langPtr = langPtr {
                let lang = Unmanaged<CFString>.fromOpaque(langPtr).takeUnretainedValue() as String
                if lang == "en" {
                    TISEnableInputSource(source)
                    TISSelectInputSource(source)
                    return true
                }
            }
        }
        
        return false
    }
    
    static func restoreInputSource(_ source: TISInputSource?) {
        guard let source = source else { return }
        TISSelectInputSource(source)
    }
}
