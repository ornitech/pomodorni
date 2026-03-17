# Pomodorni Distribution Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the app to Pomodorni and set up distribution via GitHub Releases (DMG), Sparkle auto-updates, Homebrew tap, and GitHub Actions CI/CD.

**Architecture:** The existing SwiftPM-based menu bar app gets renamed, a Makefile replaces `run.sh` for building/packaging, Sparkle is integrated for auto-updates, and GitHub Actions handles CI and automated releases with auto-tagging on merge to main.

**Tech Stack:** Swift/SwiftUI, SwiftPM, Sparkle 2 (SPM package dependency), GitHub Actions, Homebrew Cask, `hdiutil` for DMG creation, `iconutil` for icon conversion, `PlistBuddy` for version injection.

**Spec:** `docs/superpowers/specs/2026-03-17-pomodorni-distribution-design.md`

---

## Chunk 1: Rename, Conventions & Build System

### Task 1: Rename Project to Pomodorni

Rename all directories, update Package.swift, Info.plist, user-visible strings, and all test imports. The app must build and all 56 tests must pass after this task.

**Files:**
- Rename directory: `Pomodoro/` → `Pomodorni/`
- Rename directory: `PomodoroTests/` → `PomodorniTests/`
- Rename directory: `PomodoroSnapshotTests/` → `PomodorniSnapshotTests/`
- Rename file: `Pomodorni/PomodoroApp.swift` → `Pomodorni/PomodorniApp.swift`
- Modify: `Package.swift`
- Modify: `Pomodorni/Info.plist`
- Modify: `Pomodorni/PomodorniApp.swift`
- Modify: All test files (update `@testable import`)

- [ ] **Step 1: Rename source directories**

```bash
cd /Users/victorgustafsson/Projects/pomodoro
mv Pomodoro Pomodorni
mv PomodoroTests PomodorniTests
mv PomodoroSnapshotTests PomodorniSnapshotTests
mv Pomodorni/PomodoroApp.swift Pomodorni/PomodorniApp.swift
```

- [ ] **Step 2: Update Package.swift**

Replace the entire file with:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Pomodorni",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Pomodorni", targets: ["Pomodorni"])
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.15.0")
    ],
    targets: [
        .executableTarget(
            name: "Pomodorni",
            path: "Pomodorni",
            exclude: ["Info.plist", "Assets"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "PomodorniTests",
            dependencies: ["Pomodorni"],
            path: "PomodorniTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "PomodorniSnapshotTests",
            dependencies: [
                "Pomodorni",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            path: "PomodorniSnapshotTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
```

Note: `"Assets"` is added to `exclude` so SwiftPM doesn't try to process PNG files in that directory.

- [ ] **Step 3: Update Info.plist**

Replace `Pomodorni/Info.plist` entirely:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.ornitech.pomodorni</string>
    <key>CFBundleExecutable</key>
    <string>Pomodorni</string>
    <key>CFBundleName</key>
    <string>Pomodorni</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright 2026 Ornitech</string>
</dict>
</plist>
```

- [ ] **Step 4: Update user-visible strings in PomodorniApp.swift**

In `Pomodorni/PomodorniApp.swift`, update these strings:
- Line 58: `accessibilityDescription: "Pomodoro"` → `accessibilityDescription: "Pomodorni"`
- Line 193 (context menu): `"Quit Pomodoro"` → `"Quit Pomodorni"`

- [ ] **Step 5: Update `@testable import` in all test and mock files**

In every test/mock file, replace `@testable import Pomodoro` with `@testable import Pomodorni`. Files to update:

- `PomodorniTests/Core/SessionTypeTests.swift`
- `PomodorniTests/Core/TimerStateTests.swift`
- `PomodorniTests/Core/TimerEngineTests.swift`
- `PomodorniTests/Core/SettingsTests.swift`
- `PomodorniTests/Core/NotificationServiceTests.swift`
- `PomodorniTests/Core/SoundServiceTests.swift`
- `PomodorniTests/Integration/PomodoroFlowTests.swift`
- `PomodorniTests/Mocks/MockTimeProvider.swift`
- `PomodorniTests/Mocks/MockNotificationProvider.swift`
- `PomodorniTests/Mocks/MockSoundProvider.swift`
- `PomodorniSnapshotTests/SnapshotTestsPlaceholder.swift`

Use find-and-replace across all files:

```bash
find PomodorniTests PomodorniSnapshotTests -name "*.swift" -exec sed -i '' 's/@testable import Pomodoro$/@testable import Pomodorni/' {} +
```

Also check for any `import Pomodoro` (without `@testable`) and update those too:

```bash
find PomodorniTests PomodorniSnapshotTests -name "*.swift" -exec sed -i '' 's/^import Pomodoro$/import Pomodorni/' {} +
```

- [ ] **Step 6: Verify build and tests pass**

```bash
swift build
swift test
```

Expected: Build succeeds, all 56 tests pass.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "refactor: rename project from Pomodoro to Pomodorni"
```

---

### Task 2: Update Repo Conventions

Add conventional commit rules and update .gitignore for distribution artifacts.

**Files:**
- Modify: `.gitignore`
- Create: `CLAUDE.md`

- [ ] **Step 1: Update .gitignore**

Append these lines to the existing `.gitignore`:

```
# Distribution artifacts
*.dmg
*.icns
*.app/
```

- [ ] **Step 2: Create CLAUDE.md**

Create `CLAUDE.md` at the project root:

```markdown
# Pomodorni

macOS menu bar pomodoro timer by Ornitech.

## Conventions

### Commits
Always use conventional commit format:
- `feat:` — new feature
- `fix:` — bug fix
- `refactor:` — code restructuring without behavior change
- `chore:` — build, CI, dependency changes
- `docs:` — documentation only
- `test:` — adding or updating tests

### Pull Requests
- Use descriptive titles
- Add `[minor]` to PR title for feature releases (minor version bump)
- Add `[major]` to PR title for breaking changes (major version bump)
- Default (no tag) = patch version bump

### Build
- `make run` — build debug and launch the app
- `make build` — release build
- `make app` — assemble .app bundle
- `make dmg` — create distributable DMG
- `swift test` — run all tests

### Architecture
- Three-layer: Core (pure Swift) → Themes → Views
- Protocol-based DI for testability (TimeProvider, NotificationProvider, SoundProvider)
- @Observable with private backing fields for Int properties (didSet + @Observable + value clamping causes SIGBUS — use `_backingField` pattern). Simple Bool didSet properties are fine.
- NSPanel for popover (not NSPopover — positioning control)
```

- [ ] **Step 3: Commit**

```bash
git add .gitignore CLAUDE.md
git commit -m "chore: add repo conventions and update gitignore for distribution"
```

---

### Task 3: Makefile

Replace `run.sh` with a Makefile that handles build, app bundle assembly, DMG creation, icon conversion, and cleanup. Uses `PlistBuddy` for robust version injection instead of fragile sed-based markers.

**Files:**
- Create: `Makefile`
- Delete: `run.sh`
- Create: `Pomodorni/Assets/.gitkeep`

- [ ] **Step 1: Create Makefile**

```makefile
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
	# Inject version into Info.plist
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" "$(APP_CONTENTS)/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(VERSION)" "$(APP_CONTENTS)/Info.plist"
	# Copy icon if it exists
	@if [ -f "$(ICNS_FILE)" ]; then \
		cp "$(ICNS_FILE)" "$(APP_CONTENTS)/Resources/AppIcon.icns"; \
	elif [ -f "$(ICON_SOURCE)" ]; then \
		$(MAKE) iconset; \
		cp "$(ICNS_FILE)" "$(APP_CONTENTS)/Resources/AppIcon.icns"; \
	fi
	# Sign the bundle
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
	@# Assemble a debug .app bundle
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
```

- [ ] **Step 2: Delete run.sh**

```bash
rm run.sh
```

- [ ] **Step 3: Create the Assets directory**

```bash
mkdir -p Pomodorni/Assets
touch Pomodorni/Assets/.gitkeep
```

- [ ] **Step 4: Verify the build system works**

```bash
make run
```

Expected: The app builds, launches, and works as before.

- [ ] **Step 5: Commit**

```bash
git add Makefile Pomodorni/Assets/.gitkeep
git rm run.sh
git commit -m "chore: replace run.sh with Makefile build system"
```

---

### Task 4: Sparkle Integration

Add Sparkle for auto-updates. This involves adding the dependency, initializing the updater in AppDelegate, wiring the settings toggle to Sparkle's updater, adding a "Check for Updates" menu item, and updating Info.plist.

**Files:**
- Modify: `Package.swift`
- Modify: `Pomodorni/PomodorniApp.swift`
- Modify: `Pomodorni/Views/SettingsView.swift`
- Modify: `Pomodorni/Core/Settings.swift`
- Modify: `Pomodorni/Info.plist`
- Modify: `Makefile`
- Test: `PomodorniTests/Core/SettingsTests.swift`

- [ ] **Step 1: Add Sparkle dependency to Package.swift**

In `Package.swift`, add to the top-level `dependencies` array:

```swift
.package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0")
```

Add to the executable target's `dependencies`:

```swift
.product(name: "Sparkle", package: "Sparkle")
```

The full executable target becomes:

```swift
.executableTarget(
    name: "Pomodorni",
    dependencies: [
        .product(name: "Sparkle", package: "Sparkle")
    ],
    path: "Pomodorni",
    exclude: ["Info.plist", "Assets"],
    swiftSettings: [.swiftLanguageMode(.v5)]
),
```

- [ ] **Step 2: Verify Sparkle resolves and builds**

```bash
swift package resolve
swift build
```

Expected: Sparkle package downloads and the project builds successfully.

- [ ] **Step 3: Write test for Settings.checkForUpdatesAutomatically**

Add to `PomodorniTests/Core/SettingsTests.swift`:

```swift
@Test func checkForUpdatesAutomaticallyDefaultsToTrue() {
    let defaults = UserDefaults(suiteName: "test-updates-\(UUID().uuidString)")!
    let settings = Settings(defaults: defaults)
    #expect(settings.checkForUpdatesAutomatically == true)
}

@Test func checkForUpdatesAutomaticallyPersists() {
    let suite = "test-updates-persist-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    let settings = Settings(defaults: defaults)
    settings.checkForUpdatesAutomatically = false
    let settings2 = Settings(defaults: defaults)
    #expect(settings2.checkForUpdatesAutomatically == false)
}
```

- [ ] **Step 4: Run tests to verify they fail**

```bash
swift test --filter SettingsTests
```

Expected: FAIL — `checkForUpdatesAutomatically` property doesn't exist yet.

- [ ] **Step 5: Add checkForUpdatesAutomatically to Settings**

In `Pomodorni/Core/Settings.swift`, add the property after `selectedTheme`. This uses `didSet` directly (safe for simple Bool properties — only Int properties with clamping need the backing field pattern):

```swift
var checkForUpdatesAutomatically: Bool {
    didSet { defaults.set(checkForUpdatesAutomatically, forKey: "checkForUpdatesAutomatically") }
}
```

In `init(defaults:)`, add after the `selectedTheme` initialization:

```swift
self.checkForUpdatesAutomatically = defaults.object(forKey: "checkForUpdatesAutomatically") as? Bool ?? true
```

- [ ] **Step 6: Run tests to verify they pass**

```bash
swift test --filter SettingsTests
```

Expected: All tests pass including the two new ones.

- [ ] **Step 7: Update AppDelegate with Sparkle updater**

In `Pomodorni/PomodorniApp.swift`:

Add import at the top:

```swift
import Sparkle
```

Add properties to `AppDelegate` class (after `eventMonitor`):

```swift
private var updaterController: SPUStandardUpdaterController!
```

In `applicationDidFinishLaunching`, after the status item setup and before the panel setup, add:

```swift
updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
updaterController.updater.automaticallyChecksForUpdates = settings.checkForUpdatesAutomatically
```

At the end of `applicationDidFinishLaunching` (after the timer display update Timer), add observation of the settings toggle to sync with Sparkle:

```swift
// Sync Sparkle auto-update setting when user changes it
Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
    guard let self else { return }
    self.updaterController.updater.automaticallyChecksForUpdates = self.settings.checkForUpdatesAutomatically
}
```

- [ ] **Step 8: Add "Check for Updates" to context menu**

In `Pomodorni/PomodorniApp.swift`, replace the existing `showContextMenu()` method:

```swift
private func showContextMenu() {
    let menu = NSMenu()
    let checkForUpdatesItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: "")
    checkForUpdatesItem.target = self
    menu.addItem(checkForUpdatesItem)
    menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
    menu.addItem(.separator())
    menu.addItem(NSMenuItem(title: "Quit Pomodorni", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

    statusItem.menu = menu
    statusItem.button?.performClick(nil)
    statusItem.menu = nil
}
```

Add the action method after `openSettings()`:

```swift
@objc private func checkForUpdates() {
    updaterController.checkForUpdates(nil)
}
```

- [ ] **Step 9: Add auto-update toggle to SettingsView**

In `Pomodorni/Views/SettingsView.swift`, add a toggle in the `behaviorSection` after the "Show time in menu bar" toggle:

```swift
Toggle("Check for updates automatically", isOn: $settings.checkForUpdatesAutomatically)
    .font(.callout)
```

- [ ] **Step 10: Update Info.plist with Sparkle keys**

Add Sparkle keys to `Pomodorni/Info.plist` (inside the `<dict>` block, before `</dict>`):

```xml
<key>SUFeedURL</key>
<string>https://ornitech.github.io/pomodorni/appcast.xml</string>
<key>SUPublicEDKey</key>
<string>PLACEHOLDER_PUBLIC_KEY</string>
```

Note: `SUPublicEDKey` is a placeholder. It gets replaced with the real key after the user generates the Sparkle EdDSA keypair (see TODO.md).

- [ ] **Step 11: Update Makefile app target for Sparkle framework embedding**

In the `app` target of `Makefile`, add after the icon copy block and before the codesign step:

```makefile
	# Copy Sparkle framework if available
	@SPARKLE_PATH=$$(find $(BUILD_DIR) -name "Sparkle.framework" -type d 2>/dev/null | head -1); \
	if [ -n "$$SPARKLE_PATH" ]; then \
		cp -R "$$SPARKLE_PATH" "$(APP_CONTENTS)/Frameworks/"; \
		echo "Sparkle.framework embedded"; \
	fi
```

- [ ] **Step 12: Verify everything builds and tests pass**

```bash
swift build
swift test
```

Expected: Build succeeds with Sparkle linked, all tests pass (including 2 new Settings tests = 58 total).

- [ ] **Step 13: Commit**

```bash
git add Package.swift Package.resolved Pomodorni/PomodorniApp.swift \
    Pomodorni/Core/Settings.swift Pomodorni/Views/SettingsView.swift \
    Pomodorni/Info.plist Makefile PomodorniTests/Core/SettingsTests.swift
git commit -m "feat: integrate Sparkle for auto-updates"
```

---

## Chunk 2: CI/CD & Homebrew

### Task 5: GitHub Actions CI Workflow

Set up continuous integration that builds and tests on every push and PR.

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: Create CI workflow**

```bash
mkdir -p .github/workflows
```

Create `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build-and-test:
    runs-on: macos-14
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v4

      - name: Build
        run: swift build

      - name: Test
        run: swift test
```

Note: No explicit Xcode selection — the `macos-14` runner ships with a default Xcode that supports Swift 6.0 / macOS 14 targets.

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "chore: add GitHub Actions CI workflow"
```

---

### Task 6: GitHub Actions Release Workflow

Automate releases: auto-tag on merge to main, build DMG, sign with Sparkle, generate appcast, create GitHub Release, and notify Homebrew tap. Every push to main triggers a release (this is intentional — main should always be releasable).

**Files:**
- Create: `.github/workflows/release.yml`

- [ ] **Step 1: Create release workflow**

Create `.github/workflows/release.yml`:

```yaml
name: Release

on:
  push:
    branches: [main]

permissions:
  contents: write

jobs:
  release:
    runs-on: macos-14
    timeout-minutes: 20
    # Skip commits that are just appcast/CI updates
    if: "!contains(github.event.head_commit.message, '[skip-release]')"
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Full history for tags

      - name: Determine version bump
        id: version
        run: |
          # Get the latest tag, or empty if none exist
          LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
          echo "Latest tag: ${LATEST_TAG:-none}"

          if [ -z "$LATEST_TAG" ]; then
            # First release ever
            NEW_VERSION="1.0.0"
          else
            # Parse version components
            VERSION="${LATEST_TAG#v}"
            MAJOR=$(echo "$VERSION" | cut -d. -f1)
            MINOR=$(echo "$VERSION" | cut -d. -f2)
            PATCH=$(echo "$VERSION" | cut -d. -f3)

            # Get the commit message (contains PR title on merge)
            COMMIT_MSG=$(git log -1 --pretty=%s)
            echo "Commit message: $COMMIT_MSG"

            # Determine bump level
            if echo "$COMMIT_MSG" | grep -qi '\[major\]'; then
              MAJOR=$((MAJOR + 1))
              MINOR=0
              PATCH=0
            elif echo "$COMMIT_MSG" | grep -qi '\[minor\]'; then
              MINOR=$((MINOR + 1))
              PATCH=0
            else
              PATCH=$((PATCH + 1))
            fi

            NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
          fi

          NEW_TAG="v${NEW_VERSION}"
          echo "New version: $NEW_VERSION (tag: $NEW_TAG)"

          echo "version=$NEW_VERSION" >> "$GITHUB_OUTPUT"
          echo "tag=$NEW_TAG" >> "$GITHUB_OUTPUT"

      - name: Create and push tag
        run: |
          git tag "${{ steps.version.outputs.tag }}"
          git push origin "${{ steps.version.outputs.tag }}"

      - name: Build and create DMG
        run: make dmg VERSION=${{ steps.version.outputs.version }}

      - name: Download Sparkle tools
        id: sparkle-tools
        run: |
          # Get Sparkle version from Package.resolved
          SPARKLE_VERSION=$(python3 -c "
          import json
          with open('Package.resolved') as f:
              data = json.load(f)
          for pin in data.get('pins', []):
              if 'sparkle' in pin.get('identity', '').lower():
                  state = pin.get('state', {})
                  print(state.get('version', '2.6.4'))
                  break
          else:
              print('2.6.4')
          ")
          echo "Sparkle version: $SPARKLE_VERSION"

          curl -sL "https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz" -o /tmp/sparkle.tar.xz
          mkdir -p /tmp/sparkle && tar xf /tmp/sparkle.tar.xz -C /tmp/sparkle
          chmod +x /tmp/sparkle/bin/sign_update
          echo "tool_path=/tmp/sparkle/bin/sign_update" >> "$GITHUB_OUTPUT"

      - name: Sign DMG with Sparkle
        if: ${{ secrets.SPARKLE_PRIVATE_KEY != '' }}
        env:
          SPARKLE_PRIVATE_KEY: ${{ secrets.SPARKLE_PRIVATE_KEY }}
        id: sign
        run: |
          # sign_update outputs: sparkle:edSignature="..." length="..."
          RAW_OUTPUT=$("${{ steps.sparkle-tools.outputs.tool_path }}" ".build/Pomodorni.dmg" -f <(echo "$SPARKLE_PRIVATE_KEY"))

          # Extract just the edSignature value
          ED_SIGNATURE=$(echo "$RAW_OUTPUT" | grep -o 'sparkle:edSignature="[^"]*"' | sed 's/sparkle:edSignature="//;s/"//')
          echo "signature=$ED_SIGNATURE" >> "$GITHUB_OUTPUT"
          echo "DMG signed successfully"

      - name: Update appcast on gh-pages
        if: steps.sign.outputs.signature != ''
        run: |
          DMG_SIZE=$(stat -f%z .build/Pomodorni.dmg)
          VERSION="${{ steps.version.outputs.version }}"
          TAG="${{ steps.version.outputs.tag }}"
          SIGNATURE="${{ steps.sign.outputs.signature }}"
          DATE=$(date -u +"%a, %d %b %Y %H:%M:%S %z")
          DOWNLOAD_URL="https://github.com/${{ github.repository }}/releases/download/${TAG}/Pomodorni.dmg"

          # Clean up any leftover worktree from previous failed runs
          git worktree remove /tmp/gh-pages 2>/dev/null || true
          rm -rf /tmp/gh-pages

          # Check out gh-pages or create it
          git fetch origin gh-pages 2>/dev/null || true
          if git rev-parse --verify origin/gh-pages >/dev/null 2>&1; then
            git worktree add /tmp/gh-pages origin/gh-pages
          else
            git worktree add --detach /tmp/gh-pages
            cd /tmp/gh-pages
            git checkout --orphan gh-pages
            git rm -rf . 2>/dev/null || true
            cd -
          fi

          # Export env vars for the Python script
          export VERSION="${VERSION}"
          export DATE="${DATE}"
          export DOWNLOAD_URL="${DOWNLOAD_URL}"
          export SIGNATURE="${SIGNATURE}"
          export DMG_SIZE="${DMG_SIZE}"

          # Generate appcast.xml using Python for reliable XML handling
          python3 << 'PYEOF'
          import xml.etree.ElementTree as ET
          import os

          appcast_path = "/tmp/gh-pages/appcast.xml"
          ns = "http://www.andymatuschak.org/xml-namespaces/sparkle"
          ET.register_namespace("sparkle", ns)

          version = os.environ["VERSION"]
          date = os.environ["DATE"]
          url = os.environ["DOWNLOAD_URL"]
          sig = os.environ["SIGNATURE"]
          size = os.environ["DMG_SIZE"]

          if os.path.exists(appcast_path):
              tree = ET.parse(appcast_path)
              root = tree.getroot()
              channel = root.find("channel")
          else:
              root = ET.fromstring(
                  f'<rss version="2.0" xmlns:sparkle="{ns}">'
                  f'<channel><title>Pomodorni Updates</title></channel>'
                  f'</rss>'
              )
              tree = ET.ElementTree(root)
              channel = root.find("channel")

          item = ET.SubElement(channel, "item")
          ET.SubElement(item, "title").text = f"Version {version}"
          ET.SubElement(item, "pubDate").text = date
          ET.SubElement(item, "sparkle:version").text = version
          enclosure = ET.SubElement(item, "enclosure")
          enclosure.set("url", url)
          enclosure.set("sparkle:edSignature", sig)
          enclosure.set("length", size)
          enclosure.set("type", "application/octet-stream")

          tree.write(appcast_path, xml_declaration=True, encoding="utf-8")
          PYEOF

          # Commit and push appcast
          cd /tmp/gh-pages
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add appcast.xml
          git commit -m "chore: update appcast for ${TAG} [skip-release]"
          git push origin gh-pages
          cd -
          git worktree remove /tmp/gh-pages

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          tag_name: ${{ steps.version.outputs.tag }}
          name: Pomodorni ${{ steps.version.outputs.version }}
          files: .build/Pomodorni.dmg
          generate_release_notes: true

      - name: Notify Homebrew tap
        if: ${{ secrets.HOMEBREW_TAP_TOKEN != '' }}
        env:
          HOMEBREW_TAP_TOKEN: ${{ secrets.HOMEBREW_TAP_TOKEN }}
        run: |
          DMG_SHA256=$(shasum -a 256 .build/Pomodorni.dmg | awk '{print $1}')
          curl -X POST \
            -H "Accept: application/vnd.github+json" \
            -H "Authorization: token $HOMEBREW_TAP_TOKEN" \
            "https://api.github.com/repos/ornitech/homebrew-tap/dispatches" \
            -d "{
              \"event_type\": \"update-cask\",
              \"client_payload\": {
                \"version\": \"${{ steps.version.outputs.version }}\",
                \"tag\": \"${{ steps.version.outputs.tag }}\",
                \"sha256\": \"$DMG_SHA256\",
                \"url\": \"https://github.com/${{ github.repository }}/releases/download/${{ steps.version.outputs.tag }}/Pomodorni.dmg\"
              }
            }"
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "chore: add GitHub Actions release workflow with auto-tagging"
```

---

### Task 7: Homebrew Tap

Create the cask formula and auto-update workflow for the `ornitech/homebrew-tap` repo. These files are templates — the user will push them to the tap repo after creating it.

**Files:**
- Create: `homebrew-tap/Casks/pomodorni.rb`
- Create: `homebrew-tap/.github/workflows/update-cask.yml`
- Create: `homebrew-tap/README.md`

- [ ] **Step 1: Create Homebrew tap directory structure**

```bash
mkdir -p homebrew-tap/Casks
mkdir -p homebrew-tap/.github/workflows
```

- [ ] **Step 2: Create cask formula**

Create `homebrew-tap/Casks/pomodorni.rb`:

```ruby
cask "pomodorni" do
  version "1.0.0"
  sha256 "PLACEHOLDER"

  url "https://github.com/ornitech/pomodorni/releases/download/v#{version}/Pomodorni.dmg"
  name "Pomodorni"
  desc "Menu bar pomodoro timer"
  homepage "https://github.com/ornitech/pomodorni"

  app "Pomodorni.app"

  zap trash: [
    "~/Library/Preferences/com.ornitech.pomodorni.plist",
  ]
end
```

- [ ] **Step 3: Create auto-update workflow**

Create `homebrew-tap/.github/workflows/update-cask.yml`:

```yaml
name: Update Cask

on:
  repository_dispatch:
    types: [update-cask]

permissions:
  contents: write

jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Update cask formula
        run: |
          VERSION="${{ github.event.client_payload.version }}"
          SHA256="${{ github.event.client_payload.sha256 }}"

          sed -i "s/version \".*\"/version \"${VERSION}\"/" Casks/pomodorni.rb
          sed -i "s/sha256 \".*\"/sha256 \"${SHA256}\"/" Casks/pomodorni.rb

          echo "Updated cask to version ${VERSION}"

      - name: Commit and push
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add Casks/pomodorni.rb
          git commit -m "chore: update pomodorni to v${{ github.event.client_payload.version }}"
          git push
```

- [ ] **Step 4: Create tap README**

Create `homebrew-tap/README.md`:

```markdown
# Ornitech Homebrew Tap

Homebrew formulae for Ornitech apps.

## Install

```bash
brew tap ornitech/tap
brew install --cask pomodorni
```
```

- [ ] **Step 5: Commit**

```bash
git add homebrew-tap/
git commit -m "chore: add Homebrew tap template files"
```

---

### Task 8: Final Verification & Cleanup

Verify everything works end-to-end locally.

**Files:**
- Modify: `TODO.md`

- [ ] **Step 1: Run full test suite**

```bash
swift test
```

Expected: All tests pass (56 original + 2 new Settings tests = 58 total).

- [ ] **Step 2: Build and launch the app**

```bash
make run
```

Expected: App launches with the name "Pomodorni", right-click menu shows "Check for Updates...", "Settings...", and "Quit Pomodorni".

- [ ] **Step 3: Build a release DMG**

```bash
make dmg
```

Expected: `.build/Pomodorni.dmg` is created. Double-clicking it shows the Pomodorni app and an Applications shortcut.

- [ ] **Step 4: Update TODO.md with Sparkle key generation instructions**

Update `TODO.md` — replace the Sparkle keypair item with specific instructions:

```markdown
- [ ] **Generate Sparkle EdDSA keypair** — download the Sparkle release matching the version in `Package.resolved`, then run:
  ```bash
  # Download Sparkle and run generate_keys
  SPARKLE_VERSION=2.6.4  # check Package.resolved for exact version
  curl -sL "https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz" -o /tmp/sparkle.tar.xz
  mkdir -p /tmp/sparkle && tar xf /tmp/sparkle.tar.xz -C /tmp/sparkle
  /tmp/sparkle/bin/generate_keys
  ```
  This prints a public key and saves the private key to your keychain. Copy the public key into `Pomodorni/Info.plist` (replace `PLACEHOLDER_PUBLIC_KEY` in `SUPublicEDKey`). Export the private key and save it as the `SPARKLE_PRIVATE_KEY` GitHub Actions secret.
```

- [ ] **Step 5: Commit**

```bash
git add TODO.md
git commit -m "docs: update TODO with Sparkle key generation instructions"
```

- [ ] **Step 6: Final verification**

```bash
swift build -c release
swift test
```

Expected: Release build succeeds, all 58 tests pass. The project is ready for the user to:
1. Create the `ornitech` GitHub org and repos (`pomodorni`, `homebrew-tap`)
2. Push the code to `ornitech/pomodorni`
3. Push `homebrew-tap/` contents to `ornitech/homebrew-tap`
4. Generate Sparkle keys and add secrets
5. Enable GitHub Pages on `ornitech/pomodorni` (deploy from `gh-pages` branch)
6. Provide a 1024x1024 app icon PNG at `Pomodorni/Assets/AppIcon.png`
