#include <substrate.h>
#include <UIKit/UIKit.h>
#include <Foundation/Foundation.h>

#pragma mark - 全局开关配置
@interface WXPluginConfig : NSObject
@property (nonatomic, assign) BOOL enableAutoRedPacket;
@property (nonatomic, assign) BOOL enableAutoReceiveMoney;
@property (nonatomic, assign) BOOL enableJokerMessage;
@property (nonatomic, assign) BOOL enableVoiceForward;
@property (nonatomic, assign) BOOL enableAntiRecall;
@property (nonatomic, assign) BOOL enableMessageTime;
@property (nonatomic, assign) BOOL enableTimelineAdBlock;
@property (nonatomic, assign) BOOL enableMiniAppAdBlock;
@property (nonatomic, assign) BOOL enableFakeQRCode;
@property (nonatomic, assign) BOOL enableFakeDevice;
@property (nonatomic, assign) BOOL enableDoubleFingerMenu;
@end

@implementation WXPluginConfig
+ (instancetype)shared {
    static WXPluginConfig *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[WXPluginConfig alloc] init];
        instance.enableAutoRedPacket = YES;
        instance.enableAutoReceiveMoney = YES;
        instance.enableJokerMessage = YES;
        instance.enableVoiceForward = YES;
        instance.enableAntiRecall = YES;
        instance.enableMessageTime = YES;
        instance.enableTimelineAdBlock = YES;
        instance.enableMiniAppAdBlock = YES;
        instance.enableFakeQRCode = YES;
        instance.enableFakeDevice = YES;
        instance.enableDoubleFingerMenu = YES;
    });
    return instance;
}
@end

#pragma mark - 悬浮菜单
@interface WXPluginMenu : UIView
@end

@implementation WXPluginMenu
- (instancetype)init {
    self = [super initWithFrame:CGRectMake(50, 100, 260, 440)];
    if (self) {
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.9];
        self.layer.cornerRadius = 12;
        self.clipsToBounds = YES;

        NSArray *titles = @[
            @"自动抢红包", @"自动收款", @"小丑消息", @"语音转发", @"防撤回",
            @"消息时间(秒)", @"朋友圈去广告", @"小程序去广告",
            @"二维码伪装相机", @"自定义设备信息", @"双指打开菜单"
        ];

        WXPluginConfig *cfg = [WXPluginConfig shared];
        NSArray *keys = @[
            @"enableAutoRedPacket", @"enableAutoReceiveMoney", @"enableJokerMessage",
            @"enableVoiceForward", @"enableAntiRecall", @"enableMessageTime",
            @"enableTimelineAdBlock", @"enableMiniAppAdBlock", @"enableFakeQRCode",
            @"enableFakeDevice", @"enableDoubleFingerMenu"
        ];

        for (int i=0; i<titles.count; i++) {
            UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20, 25 + i*36, 170, 30)];
            label.text = titles[i];
            label.textColor = [UIColor whiteColor];
            label.font = [UIFont systemFontOfSize:14];
            [self addSubview:label];

            UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(200, 25 + i*36, 0, 0)];
            BOOL on = [[cfg valueForKey:keys[i]] boolValue];
            sw.on = on;
            [self addSubview:sw];
        }

        UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        closeBtn.frame = CGRectMake(0, 400, 260, 40);
        [closeBtn setTitle:@"关闭菜单" forState:UIControlStateNormal];
        [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [closeBtn addTarget:self action:@selector(removeFromSuperview) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:closeBtn];
    }
    return self;
}
@end

#pragma mark - 功能实现
__attribute__((constructor))
static void pluginEntry() {
    WXPluginConfig *cfg = [WXPluginConfig shared];
    NSLog(@"✅ 微信插件加载成功");

    Class envClass = objc_getClass("MMEnvironment");
    if (envClass) {
        static BOOL (*origIsDuplicated)(id, SEL);
        BOOL hackIsDuplicated(id self, SEL _cmd) { return NO; }
        MSHookMessageEx(envClass, @selector(isAppDuplicated), (IMP)hackIsDuplicated, (IMP *)&origIsDuplicated);

        static BOOL (*origIsJailbroken)(id, SEL);
        BOOL hackIsJailbroken(id self, SEL _cmd) { return NO; }
        MSHookMessageEx(envClass, @selector(isJailbroken), (IMP)hackIsJailbroken, (IMP *)&origIsJailbroken);
    }

    Class windowClass = objc_getClass("WCFullScreenWindow");
    if (windowClass) {
        static void (*origTouchesBegan)(id, SEL, NSSet*, UIEvent*);
        void hackTouchesBegan(id self, SEL _cmd, NSSet *touches, UIEvent *event) {
            origTouchesBegan(self, _cmd, touches, event);
            if (cfg.enableDoubleFingerMenu && touches.count == 2) {
                static WXPluginMenu *menu;
                static dispatch_once_t once;
                dispatch_once(&once, ^{ menu = [[WXPluginMenu alloc] init]; });
                [[UIApplication sharedApplication].keyWindow addSubview:menu];
            }
        }
        MSHookMessageEx(windowClass, @selector(touchesBegan:withEvent:), (IMP)hackTouchesBegan, (IMP *)&origTouchesBegan);
    }

    Class redClass = objc_getClass("WCRedEnvelopesReceiveControlLogic");
    if (redClass) {
        static void (*origOnReceiveRed)(id, SEL, id);
        void hackOnReceiveRed(id self, SEL _cmd, id msg) {
            origOnReceiveRed(self, _cmd, msg);
            if (cfg.enableAutoRedPacket) {
                [self performSelector:@selector(onOpenRedEnvelopes:) withObject:msg afterDelay:0.1];
            }
        }
        MSHookMessageEx(redClass, @selector(onReceiveRedEnvelopesMsg:), (IMP)hackOnReceiveRed, (IMP *)&origOnReceiveRed);
    }

    Class transferClass = objc_getClass("WCPayTransferControlLogic");
    if (transferClass) {
        static void (*origOnReceiveTransfer)(id, SEL, id);
        void hackOnReceiveTransfer(id self, SEL _cmd, id msg) {
            origOnReceiveTransfer(self, _cmd, msg);
            if (cfg.enableAutoReceiveMoney) {
                [self performSelector:@selector(onAcceptTransfer:) withObject:msg afterDelay:0.1];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    id sendMgr = objc_getClass("MessageSendMgr");
                    if (sendMgr) {
                        [sendMgr performSelector:@selector(sendMessageToUser:text:) withObject:msg withObject:@"自动收款谢谢"];
                    }
                });
            }
        }
        MSHookMessageEx(transferClass, @selector(onReceiveTransferMsg:), (IMP)hackOnReceiveTransfer, (IMP *)&origOnReceiveTransfer);
    }

    Class msgCellClass = objc_getClass("MessageCellView");
    if (msgCellClass) {
        static void (*origSetContent)(id, SEL, id);
        void hackSetContent(id self, SEL _cmd, id msg) {
            origSetContent(self, _cmd, msg);
            if (cfg.enableJokerMessage && ![(id)msg performSelector:@selector(isSenderMe)]) {
                UILabel *textLabel = [self valueForKey:@"_textLabel"];
                if (textLabel) textLabel.text = @"🧟‍♂️ 本条消息已被小丑修改";
            }
        }
        MSHookMessageEx(msgCellClass, @selector(setMessageContent:), (IMP)hackSetContent, (IMP *)&origSetContent);
    }

    Class voiceClass = objc_getClass("WCVoiceMessageCellView");
    if (voiceClass) {
        static BOOL (*origCanForward)(id, SEL);
        BOOL hackCanForward(id self, SEL _cmd) {
            return cfg.enableVoiceForward ? YES : origCanForward(self, _cmd);
        }
        MSHookMessageEx(voiceClass, @selector(canForward), (IMP)hackCanForward, (IMP *)&origCanForward);
    }

    Class recallClass = objc_getClass("CMessageMgr");
    if (recallClass) {
        static void (*origRevokeMsg)(id, SEL, id);
        void hackRevokeMsg(id self, SEL _cmd, id msg) {
            if (!cfg.enableAntiRecall) origRevokeMsg(self, _cmd, msg);
        }
        MSHookMessageEx(recallClass, @selector(revokeMsg:), (IMP)hackRevokeMsg, (IMP *)&origRevokeMsg);
    }

    Class timeClass = objc_getClass("MessageHeaderView");
    if (timeClass) {
        static void (*origSetTimeText)(id, SEL, NSString*);
        void hackSetTimeText(id self, SEL _cmd, NSString *text) {
            if (cfg.enableMessageTime) {
                NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
                fmt.dateFormat = @"HH:mm:ss";
                NSString *time = [fmt stringFromDate:[NSDate date]];
                origSetTimeText(self, _cmd, time);
            } else {
                origSetTimeText(self, _cmd, text);
            }
        }
        MSHookMessageEx(timeClass, @selector(setTimeLabelText:), (IMP)hackSetTimeText, (IMP *)&origSetTimeText);
    }

    Class feedAdClass = objc_getClass("FeedsAdTableViewCell");
    if (feedAdClass) {
        static id (*origGetAdInfo)(id, SEL);
        id hackGetAdInfo(id self, SEL _cmd) {
            return cfg.enableTimelineAdBlock ? nil : origGetAdInfo(self, _cmd);
        }
        MSHookMessageEx(feedAdClass, @selector(getAdInfo), (IMP)hackGetAdInfo, (IMP *)&origGetAdInfo);
    }

    Class miniAdClass = objc_getClass("WebViewAdLogic");
    if (miniAdClass) {
        static void (*origLoadAd)(id, SEL);
        void hackLoadAd(id self, SEL _cmd) {
            if (!cfg.enableMiniAppAdBlock) origLoadAd(self, _cmd);
        }
        MSHookMessageEx(miniAdClass, @selector(loadAd), (IMP)hackLoadAd, (IMP *)&origLoadAd);
    }

    Class qrClass = objc_getClass("WCScanQRCodeLogic");
    if (qrClass) {
        static BOOL (*origIsFromCamera)(id, SEL);
        BOOL hackIsFromCamera(id self, SEL _cmd) {
            return cfg.enableFakeQRCode ? YES : origIsFromCamera(self, _cmd);
        }
        MSHookMessageEx(qrClass, @selector(isFromCamera), (IMP)hackIsFromCamera, (IMP *)&origIsFromCamera);
    }

    Class deviceClass = objc_getClass("DeviceUtil");
    if (deviceClass) {
        static NSString *(*origDeviceName)(id, SEL);
        NSString *hackDeviceName(id self, SEL _cmd) {
            return cfg.enableFakeDevice ? @"iPhone 16 Pro" : origDeviceName(self, _cmd);
        }
        static NSString *(*origSystemVersion)(id, SEL);
        NSString *hackSystemVersion(id self, SEL _cmd) {
            return cfg.enableFakeDevice ? @"iOS 18.2" : origSystemVersion(self, _cmd);
        }
        MSHookMessageEx(deviceClass, @selector(getDeviceName), (IMP)hackDeviceName, (IMP *)&origDeviceName);
        MSHookMessageEx(deviceClass, @selector(getSystemVersion), (IMP)hackSystemVersion, (IMP *)&origSystemVersion);
    }
}
