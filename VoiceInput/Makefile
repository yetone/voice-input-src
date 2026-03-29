.PHONY: build run install clean

ARCH = $(shell uname -m)
BUILD_DIR = .build
APP_NAME = VoiceInput
APP_BUNDLE = $(BUILD_DIR)/release/$(APP_NAME).app

build:
swift build -c release --arch $(ARCH)
mkdir -p $(APP_BUNDLE)/Contents/MacOS
mkdir -p $(APP_BUNDLE)/Contents/Resources
cp $(BUILD_DIR)/release/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/
cp Info.plist $(APP_BUNDLE)/Contents/

run: build
open $(APP_BUNDLE)

install: build
cp -r $(APP_BUNDLE) /Applications/

clean:
rm -rf $(BUILD_DIR)
