PROJECT = ScoreStage.xcodeproj
IOS_SCHEME = ScoreStage-iOS
MAC_SCHEME = ScoreStage-macOS
TEST_SCHEME = ScoreStageTests

IPHONE_SIM = iPhone 17 Pro
IPAD_SIM = iPad Pro 13-inch (M5)

DERIVED_DATA = $(HOME)/Library/Developer/Xcode/DerivedData

.PHONY: app mac ipad iphone test generate clean

# Build both platforms
app: mac iphone

# Build and launch macOS app
mac:
	xcodebuild build -project $(PROJECT) -scheme $(MAC_SCHEME) \
		-destination 'generic/platform=macOS' -quiet
	@echo "Launching ScoreStage on macOS..."
	@open "$$(find $(DERIVED_DATA) -path '*/Build/Products/Debug/ScoreStage.app' -maxdepth 5 | head -1)"

# Build and launch on iPad simulator
ipad:
	xcrun simctl boot "$(IPAD_SIM)" 2>/dev/null || true
	xcodebuild build -project $(PROJECT) -scheme $(IOS_SCHEME) \
		-destination 'platform=iOS Simulator,name=$(IPAD_SIM)' -quiet
	@echo "Installing and launching on $(IPAD_SIM)..."
	@xcrun simctl install "$(IPAD_SIM)" \
		"$$(find $(DERIVED_DATA) -path '*/Build/Products/Debug-iphonesimulator/ScoreStage.app' -maxdepth 5 | head -1)"
	@xcrun simctl launch "$(IPAD_SIM)" com.scorestage.app
	@open -a Simulator

# Build and launch on iPhone simulator
iphone:
	xcrun simctl boot "$(IPHONE_SIM)" 2>/dev/null || true
	xcodebuild build -project $(PROJECT) -scheme $(IOS_SCHEME) \
		-destination 'platform=iOS Simulator,name=$(IPHONE_SIM)' -quiet
	@echo "Installing and launching on $(IPHONE_SIM)..."
	@xcrun simctl install "$(IPHONE_SIM)" \
		"$$(find $(DERIVED_DATA) -path '*/Build/Products/Debug-iphonesimulator/ScoreStage.app' -maxdepth 5 | head -1)"
	@xcrun simctl launch "$(IPHONE_SIM)" com.scorestage.app
	@open -a Simulator

# Run unit tests
test:
	xcodebuild test -project $(PROJECT) -scheme $(TEST_SCHEME) \
		-destination 'platform=iOS Simulator,name=$(IPHONE_SIM)' -quiet

# Regenerate Xcode project from project.yml
generate:
	xcodegen generate

# Clean build artifacts
clean:
	xcodebuild clean -project $(PROJECT) -scheme $(IOS_SCHEME) -quiet
	xcodebuild clean -project $(PROJECT) -scheme $(MAC_SCHEME) -quiet
