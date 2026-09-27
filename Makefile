APP_NAME := RioVideoWallpaper
SCHEME := $(APP_NAME)
PROJECT := $(APP_NAME).xcodeproj
CONFIGURATION := Release
DERIVED_DATA := build/DerivedData

.PHONY: build test release

build:
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-derivedDataPath $(DERIVED_DATA) \
		CODE_SIGNING_ALLOWED=NO \
		CODE_SIGNING_REQUIRED=NO \
		build

test:
	TEST_RUNNER_VIDEO_WALLPAPER_UI_TESTING=1 xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination 'platform=macOS' \
		-derivedDataPath $(DERIVED_DATA) \
		CODE_SIGNING_ALLOWED=YES \
		CODE_SIGNING_REQUIRED=YES \
		CODE_SIGN_STYLE=Manual \
		CODE_SIGN_IDENTITY=- \
		DEVELOPMENT_TEAM= \
		test

release:
	./scripts/release.sh
	@echo "Tip: TAG=v0.1.0 make release"
	@echo "Tip: SIGN_IDENTITY=... NOTARY_PROFILE=... make release"
	@echo "Tip: NOTARIZE=0 make release"
	@echo "Tip: PUBLISH=0 make release"
