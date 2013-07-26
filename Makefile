TARGET = iphone:clang:latest:6.0
ARCHS = armv7 armv7s
include theos/makefiles/common.mk


TWEAK_NAME = MusicPauser
MusicPauser_FILES = Tweak.xm
THEOS_BUILD_DIR = build

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += musicpauserprefs
include $(THEOS_MAKE_PATH)/aggregate.mk
