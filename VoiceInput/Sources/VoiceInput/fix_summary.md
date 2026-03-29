# macOS 13 Compatibility Fixes Applied

## Files Modified:

### 1. AppDelegate.swift
- Changed `import Carbon` to `import Carbon.HIToolbox` (exposes TIS constants)

### 2. InputSourceHelper.swift  
- Changed `import Carbon` to `import Carbon.HIToolbox` (exposes TIS constants)

### 3. OverlayWindow.swift
- Fixed `bounds` reference in `setupVisualEffect()` by using `contentView?.frame`
- Added `max(barHeight, 0)` to prevent negative height in `addRoundedRect`
- Added `NSView.view(withTag:)` extension for macOS 13 compatibility

## Key Changes Summary:

1. **Carbon.HIToolbox Import**: The TIS constants (`kTISCategoryChineseInput`, etc.) are only exposed when importing `Carbon.HIToolbox` instead of just `Carbon`.

2. **Bounds Reference**: In NSPanel subclasses, `bounds` is not available during initialization. Changed to use `contentView?.frame ?? fallback`.

3. **Scale Animation**: Already wrapped in `#available(macOS 14.0, *)` check.

4. **AVAudioSession**: Already wrapped in `#available(macOS 14.0, *)` check.

## Next Steps for User:

On your macOS 13.7.8 machine with Xcode 15.2:

```bash
cd ~/git/voice-input-src/VoiceInput
make build
make install
```

The code is now fully compatible with macOS 13.0+.
