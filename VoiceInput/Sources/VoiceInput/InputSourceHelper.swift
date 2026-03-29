import Cocoa
import Carbon

struct InputSourceHelper {
    static func getCurrentInputSource() -> TISInputSource? {
        return TISCopyCurrentKeyboardInputSource()?.takeRetainedValue()
    }
    
    static func isCJKInput(source: TISInputSource?) -> Bool {
        guard let source = source else { return false }
        
        if let category = TISGetInputSourceProperty(source, kTISPropertyInputSourceCategory) as? String {
            return category == kTISCategoryChineseInput ||
                   category == kTISCategoryJapaneseInput ||
                   category == kTISCategoryKoreanInput
        }
        
        return false
    }
    
    static func switchToASCIIInput() -> Bool {
        guard let inputSources = TISCopyInputSourceList(kCFBooleanTrue, kTISPropertyInputSourceType == "Keyboard")?.takeRetainedValue() as? [TISInputSource] else {
            return false
        }
        
        for source in inputSources {
            if let lang = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguage) as? String,
               lang == "en" {
                TISEnableInputSource(source)
                TISSelectInputSource(source)
                return true
            }
        }
        
        return false
    }
    
    static func restoreInputSource(_ source: TISInputSource?) {
        guard let source = source else { return }
        TISSelectInputSource(source)
    }
}
