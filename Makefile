APP_NAME = Pomodorni
BUNDLE_ID = com.ornitech.pomodorni
SIGNING_IDENTITY ?= -

BUILD_DIR = .build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
APP_CONTENTS = $(APP_BUNDLE)/Contents
DMG_NAME = $(APP_NAME).dmg

ICON_SOURCE = Pomodorni/Assets/AppIcon.png
ICONSET_DIR = $(BUILD_DIR)/AppIcon.iconset
ICNS_FILE = $(BUILD_DIR)/AppIcon.icns

# Extract version from most recent git tag, default to 1.0.0
VERSION ?= $(shell git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "1.0.0")

.PHONY: build app dmg run iconset clean

build:
	swift build -c release

app: build
	@echo "Assembling $(APP_NAME).app..."
	mkdir -p "$(APP_CONTENTS)/MacOS"
	mkdir -p "$(APP_CONTENTS)/Resources"
	mkdir -p "$(APP_CONTENTS)/Frameworks"
	cp "$(BUILD_DIR)/release/$(APP_NAME)" "$(APP_CONTENTS)/MacOS/$(APP_NAME)"
	cp Pomodorni/Info.plist "$(APP_CONTENTS)/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" "$(APP_CONTENTS)/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(VERSION)" "$(APP_CONTENTS)/Info.plist"
	@if [ -f "$(ICNS_FILE)" ]; then \
		cp "$(ICNS_FILE)" "$(APP_CONTENTS)/Resources/AppIcon.icns"; \
	elif [ -f "$(ICON_SOURCE)" ]; then \
		$(MAKE) iconset; \
		cp "$(ICNS_FILE)" "$(APP_CONTENTS)/Resources/AppIcon.icns"; \
	fi
	codesign --force --sign "$(SIGNING_IDENTITY)" "$(APP_BUNDLE)"
	@echo "$(APP_NAME).app assembled at $(APP_BUNDLE)"

dmg: app
	@echo "Creating DMG..."
	mkdir -p "$(BUILD_DIR)/dmg-staging"
	cp -R "$(APP_BUNDLE)" "$(BUILD_DIR)/dmg-staging/"
	ln -sf /Applications "$(BUILD_DIR)/dmg-staging/Applications"
	hdiutil create -volname "$(APP_NAME)" \
		-srcfolder "$(BUILD_DIR)/dmg-staging" \
		-ov -format UDZO \
		"$(BUILD_DIR)/$(DMG_NAME)"
	rm -rf "$(BUILD_DIR)/dmg-staging"
	@echo "DMG created at $(BUILD_DIR)/$(DMG_NAME)"

run:
	swift build
	mkdir -p "$(APP_CONTENTS)/MacOS"
	cp "$(BUILD_DIR)/debug/$(APP_NAME)" "$(APP_CONTENTS)/MacOS/$(APP_NAME)"
	cp Pomodorni/Info.plist "$(APP_CONTENTS)/Info.plist"
	@if [ -f "$(ICNS_FILE)" ]; then \
		mkdir -p "$(APP_CONTENTS)/Resources"; \
		cp "$(ICNS_FILE)" "$(APP_CONTENTS)/Resources/AppIcon.icns"; \
	fi
	codesign --force --sign - "$(APP_BUNDLE)"
	open "$(APP_BUNDLE)"

iconset:
	@if [ ! -f "$(ICON_SOURCE)" ]; then \
		echo "Error: $(ICON_SOURCE) not found. Please provide a 1024x1024 PNG."; \
		exit 1; \
	fi
	@echo "Generating .icns from $(ICON_SOURCE)..."
	mkdir -p "$(ICONSET_DIR)"
	sips -z 16 16     "$(ICON_SOURCE)" --out "$(ICONSET_DIR)/icon_16x16.png"      > /dev/null
	sips -z 32 32     "$(ICON_SOURCE)" --out "$(ICONSET_DIR)/icon_16x16@2x.png"   > /dev/null
	sips -z 32 32     "$(ICON_SOURCE)" --out "$(ICONSET_DIR)/icon_32x32.png"      > /dev/null
	sips -z 64 64     "$(ICON_SOURCE)" --out "$(ICONSET_DIR)/icon_32x32@2x.png"   > /dev/null
	sips -z 128 128   "$(ICON_SOURCE)" --out "$(ICONSET_DIR)/icon_128x128.png"    > /dev/null
	sips -z 256 256   "$(ICON_SOURCE)" --out "$(ICONSET_DIR)/icon_128x128@2x.png" > /dev/null
	sips -z 256 256   "$(ICON_SOURCE)" --out "$(ICONSET_DIR)/icon_256x256.png"    > /dev/null
	sips -z 512 512   "$(ICON_SOURCE)" --out "$(ICONSET_DIR)/icon_256x256@2x.png" > /dev/null
	sips -z 512 512   "$(ICON_SOURCE)" --out "$(ICONSET_DIR)/icon_512x512.png"    > /dev/null
	sips -z 1024 1024 "$(ICON_SOURCE)" --out "$(ICONSET_DIR)/icon_512x512@2x.png" > /dev/null
	iconutil -c icns "$(ICONSET_DIR)" -o "$(ICNS_FILE)"
	rm -rf "$(ICONSET_DIR)"
	@echo "Icon generated at $(ICNS_FILE)"

clean:
	rm -rf "$(BUILD_DIR)"
	@echo "Cleaned build artifacts"
