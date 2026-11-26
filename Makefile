#=============================================================================
#  Strata: builds and packages the installers
#
#      make build          the backend (CMake) and the window (lazbuild)
#      make package_deb    Debian package, on Linux
#      make package_dmg    disk image, on macOS
#      make build_deb      clean, build, package_deb
#      make build_dmg      clean, build, package_dmg
#
#  Windows is packaged with NSIS from windows/Strata.nsi; `make nsis_cmd`
#  prints the command with the right definitions filled in, for the places
#  where make is not what runs it.
#
#  Geant4 is not packaged: the packages need the version in GEANT4_VERSION from
#  https://github.com/ovidiopr/geant4-installers installed.
#=============================================================================

APP            := Strata
VERSION        ?= 1.0.0
PKGROOT        := strata_$(VERSION)

UNAME_S        := $(shell uname -s)
UNAME_M        := $(shell uname -m)

BUILD          := build/release
CMAKE          ?= cmake
CMAKE_ARGS     ?=
LAZBUILD       ?= lazbuild
LAZARUS_DIR    ?=
GEANT4_DIR     ?=
# The Geant4 version Strata is built against
GEANT4_VERSION ?= $(shell cat GEANT4_VERSION)

# Everything that gets packaged is assembled here, in the shape the three
# packagers want, so none of them has to know where a build system put its
# output.  Deliberately not named after the target triple: lazbuild writes
# where StrataGUI.lpi tells it to, and asking fpc for the triple made the
# path depend on fpc being on PATH when make parsed this file.
STAGE          := $(BUILD)/stage
GUI_OUT        := pascal/build

# ----------------------------
# Architecture detection (Linux)
# ----------------------------
ifeq ($(UNAME_M),x86_64)
  DEB_ARCH := amd64
endif
ifeq ($(UNAME_M),i386)
  DEB_ARCH := i386
endif
ifeq ($(UNAME_M),i686)
  DEB_ARCH := i386
endif
ifeq ($(UNAME_M),armv7l)
  DEB_ARCH := armhf
endif
ifeq ($(UNAME_M),aarch64)
  DEB_ARCH := arm64
endif
DEB_ARCH ?= unknown

# ----------------------------
# macOS disk image settings
# ----------------------------
DMG_STAGING    := $(BUILD)/dmg-staging
DMG_VOLNAME    := $(APP) $(VERSION)
APP_BUNDLE_SRC := $(GUI_OUT)/StrataGUI.app
DMG_APP_BUNDLE := $(DMG_STAGING)/StrataGUI.app
DMG_OUT        := strata_$(VERSION)_$(UNAME_M).dmg
ICNS_SRC       := images/strata.icns
PLIST_SRC      := macos/Info.plist

# ----------------------------
# Windows installer settings
# ----------------------------
NSI_ARCH       := win64-x86_64
EXE_SUFFIX     ?=

.PHONY: all clean build build_backend build_gui \
        build_deb build_dmg package_deb package_dmg nsis_cmd print_version

all: build

# For the release workflow, which has to name the packages the same as the tag
print_version:
	@echo $(VERSION)

clean:
	rm -rf $(BUILD) $(PKGROOT) pascal/build *.deb *.dmg

# ----------------------------
# Build
# ----------------------------
build: build_backend build_gui

# The library the window drives, the batch program, and the macros.  Staged
# under $(STAGE) with the same shape the packages want: bin/ and lib/.
build_backend:
	@echo "== backend =="
	$(CMAKE) -S . -B $(BUILD)/cmake -DCMAKE_BUILD_TYPE=Release \
	    $(if $(GEANT4_DIR),-DGeant4_DIR=$(GEANT4_DIR),) $(CMAKE_ARGS)
	$(CMAKE) --build $(BUILD)/cmake --parallel
	$(CMAKE) --install $(BUILD)/cmake --prefix $(STAGE)

build_gui:
	@echo "== window =="
	$(LAZBUILD) $(if $(LAZARUS_DIR),--lazarusdir=$(LAZARUS_DIR),) \
	    --build-mode=Release pascal/gui/StrataGUI.lpi
	mkdir -p $(STAGE)/bin
	cp $(GUI_OUT)/StrataGUI$(EXE_SUFFIX) $(STAGE)/bin/

# ----------------------------
# Debian package
# ----------------------------
build_deb: clean build package_deb

package_deb:
	@echo "Packaging Debian package for $(DEB_ARCH)"
	@test -f "$(STAGE)/bin/Strata" || \
		{ echo "ERROR: $(STAGE)/bin/Strata not found - run 'make build' first"; exit 1; }
	@test -f "$(STAGE)/bin/StrataGUI" || \
		{ echo "ERROR: $(STAGE)/bin/StrataGUI not found - run 'make build' first"; exit 1; }
	rm -rf $(PKGROOT)
	mkdir -p $(PKGROOT)/DEBIAN
	mkdir -p $(PKGROOT)/usr/bin
	mkdir -p $(PKGROOT)/usr/lib/strata
	mkdir -p $(PKGROOT)/usr/share/strata/macros
	mkdir -p $(PKGROOT)/usr/share/strata/configs
	mkdir -p $(PKGROOT)/usr/share/applications
	mkdir -p $(PKGROOT)/usr/share/icons/hicolor/scalable/apps
	mkdir -p $(PKGROOT)/usr/share/doc/strata

	# The window looks for the backend next to its own executable first, so
	# all three live together and /usr/bin gets links to the two programs.
	cp $(STAGE)/bin/StrataGUI     $(PKGROOT)/usr/lib/strata/
	cp $(STAGE)/bin/Strata        $(PKGROOT)/usr/lib/strata/
	cp $(STAGE)/bin/strata_engine $(PKGROOT)/usr/lib/strata/
	cp $(STAGE)/lib/libstrata.so* $(PKGROOT)/usr/lib/strata/
	chmod 755 $(PKGROOT)/usr/lib/strata/StrataGUI $(PKGROOT)/usr/lib/strata/Strata \
		$(PKGROOT)/usr/lib/strata/strata_engine
	ln -sf ../lib/strata/StrataGUI $(PKGROOT)/usr/bin/StrataGUI
	ln -sf ../lib/strata/Strata    $(PKGROOT)/usr/bin/Strata

	cp macros/*.mac $(PKGROOT)/usr/share/strata/macros/
	cp configs/*.scf $(PKGROOT)/usr/share/strata/configs/
	cp README.md LICENSE BUILDING.md $(PKGROOT)/usr/share/doc/strata/
	mkdir -p $(PKGROOT)/usr/share/doc/strata/doc
	cp doc/*.md $(PKGROOT)/usr/share/doc/strata/doc/
	cp images/strata.svg \
		$(PKGROOT)/usr/share/icons/hicolor/scalable/apps/strata.svg
	cp debian/strata.desktop $(PKGROOT)/usr/share/applications/

	sed -e "s/@ARCH@/$(DEB_ARCH)/" -e "s/@VERSION@/$(VERSION)/" \
		-e "s/@GEANT4_VERSION@/$(GEANT4_VERSION)/g" \
		debian/control > $(PKGROOT)/DEBIAN/control
	cp debian/postinst $(PKGROOT)/DEBIAN/
	chmod 755 $(PKGROOT)/DEBIAN/postinst

	fakeroot dpkg-deb --build $(PKGROOT) strata_$(VERSION)_$(DEB_ARCH).deb

# ----------------------------
# macOS disk image
# ----------------------------
build_dmg: clean build package_dmg

package_dmg:
	@echo "Packaging macOS disk image for $(UNAME_M)"
	@test -d "$(APP_BUNDLE_SRC)" || \
		{ echo "ERROR: .app bundle not found at $(APP_BUNDLE_SRC)"; exit 1; }
	@test -f "$(ICNS_SRC)" || \
		{ echo "ERROR: icon not found at $(ICNS_SRC)"; exit 1; }
	@test -f "$(PLIST_SRC)" || \
		{ echo "ERROR: Info.plist not found at $(PLIST_SRC)"; exit 1; }
	@test -f "$(STAGE)/bin/Strata" || \
		{ echo "ERROR: $(STAGE)/bin/Strata not found - run 'make build' first"; exit 1; }
	rm -rf "$(DMG_STAGING)"
	mkdir -p "$(DMG_STAGING)"
	# Copy bundle, resolving all symlinks
	cp -RL "$(APP_BUNDLE_SRC)" "$(DMG_STAGING)/"
	@test -f "$(DMG_APP_BUNDLE)/Contents/MacOS/StrataGUI" || \
		{ echo "ERROR: executable missing after copy"; exit 1; }

	# Info.plist, with the version filled in, over what lazbuild generated
	sed -e "s/@VERSION@/$(VERSION)/g" "$(PLIST_SRC)" \
		> "$(DMG_APP_BUNDLE)/Contents/Info.plist"

	# The icon
	mkdir -p "$(DMG_APP_BUNDLE)/Contents/Resources"
	cp "$(ICNS_SRC)" "$(DMG_APP_BUNDLE)/Contents/Resources/strata.icns"

	# The backend and the batch program go beside the window, which is the
	# first place the window looks for them
	cp "$(STAGE)/bin/Strata" "$(DMG_APP_BUNDLE)/Contents/MacOS/"
	cp "$(STAGE)/bin/strata_engine" "$(DMG_APP_BUNDLE)/Contents/MacOS/"
	cp -P $(STAGE)/lib/libstrata*.dylib "$(DMG_APP_BUNDLE)/Contents/MacOS/"
	# Libraries outside the system are found through the Geant4 folder
	./macos/use-rpath.sh "$(DMG_APP_BUNDLE)/Contents/MacOS/Strata" \
		"$(DMG_APP_BUNDLE)/Contents/MacOS/strata_engine" \
		"$(DMG_APP_BUNDLE)"/Contents/MacOS/libstrata*.dylib

	# The macros, as a reference and as the regression cases
	mkdir -p "$(DMG_APP_BUNDLE)/Contents/Resources/macros"
	cp macros/*.mac "$(DMG_APP_BUNDLE)/Contents/Resources/macros/"
	mkdir -p "$(DMG_APP_BUNDLE)/Contents/Resources/configs"
	cp configs/*.scf "$(DMG_APP_BUNDLE)/Contents/Resources/configs/"

	# Strip any quarantine flag
	xattr -cr "$(DMG_APP_BUNDLE)"

	# Sign the whole bundle as the final step
	codesign --force --deep --sign - "$(DMG_APP_BUNDLE)"
	codesign --verify --deep --strict --verbose=2 "$(DMG_APP_BUNDLE)"

	# Symlink to /Applications for drag-and-drop install
	ln -s /Applications "$(DMG_STAGING)/Applications"
	hdiutil create \
		-volname "$(DMG_VOLNAME)" \
		-srcfolder "$(DMG_STAGING)" \
		-ov \
		-format UDZO \
		"$(DMG_OUT)"
	rm -rf "$(DMG_STAGING)"
	@echo "Done: $(DMG_OUT)"

# ----------------------------
# Windows installer
# ----------------------------
# NSIS runs on the Windows runner, where make is usually not what drives it.
nsis_cmd:
	@echo 'makensis /DPRODUCT_VERSION=$(VERSION) /DG4_VERSION=$(GEANT4_VERSION) /DPRODUCT_ARCH=$(NSI_ARCH) /DBUILD_DIR=..\\build\\release\\stage\\bin windows\\Strata.nsi'
