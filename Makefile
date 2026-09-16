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
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination 'platform=macOS' \
		-derivedDataPath $(DERIVED_DATA) \
		-parallel-testing-enabled NO \
		'PRODUCT_BUNDLE_IDENTIFIER=st.rio.$$(PRODUCT_NAME).Tests' \
		CODE_SIGNING_ALLOWED=YES \
		CODE_SIGN_IDENTITY=- \
		CODE_SIGN_STYLE=Manual \
		test

release:
	./scripts/release.sh
	@echo "Tip: TAG=v0.1.0 make release"
	@echo "Tip: SIGN_IDENTITY=... NOTARY_PROFILE=... make release"
	@echo "Tip: NOTARIZE=0 make release"
	@echo "Tip: PUBLISH=0 make release"
