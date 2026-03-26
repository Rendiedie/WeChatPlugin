RCHS = arm64 arm64e
TARGET = iphone:clang:14.5:12.0

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = WeChatPlugin

WeChatPlugin_FILES = Tweak.xm $(wildcard Classes/*.m) $(wildcard Classes/**/*.m)
WeChatPlugin_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
WeChatPlugin_FRAMEWORKS = UIKit Foundation QuartzCore CoreGraphics
WeChatPlugin_PRIVATE_FRAMEWORKS = Preferences

include $(THEOS_MAKE_PATH)/tweak.mk
