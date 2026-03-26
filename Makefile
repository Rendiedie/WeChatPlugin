ARCHS = arm64
TARGET = iphone:clang:26.0:14.0
INSTALL_TARGET_PROCESSES = WeChat

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = WeChatSimple

WeChatSimple_FILES = Tweak.x
WeChatSimple_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
