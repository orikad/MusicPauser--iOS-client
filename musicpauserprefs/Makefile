include theos/makefiles/common.mk

BUNDLE_NAME = MusicPauser
MusicPauser_FILES = MusicPauser.mm
MusicPauser_INSTALL_PATH = /Library/PreferenceBundles
MusicPauser_FRAMEWORKS = UIKit CoreGraphics
MusicPauser_PRIVATE_FRAMEWORKS = Preferences

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/MusicPauser.plist$(ECHO_END)
