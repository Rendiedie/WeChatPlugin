#include <substrate.h>
#include <UIKit/UIKit.h>
#include <Foundation/Foundation.h>

#pragma mark - 全局开关
@interface WXConfig : NSObject
@property (nonatomic, assign) BOOL autoRedPacket;
@property (nonatomic, assign) BOOL autoReceiveMoney;
@property (nonatomic, assign) BOOL jokerMessage;
@property (nonatomic, assign) BOOL voiceForward;
@property (nonatomic, assign) BOOL antiRecall;
@property (nonatomic, assign) BOOL messageTime;
@property (nonatomic, assign) BOOL timelineAdBlock;
@property (nonatomic, assign) BOOL miniAppAdBlock;
@property (nonatomic, assign) BOOL fakeQRCode;
@property (nonatomic, assign) BOOL fakeDevice;
@property (nonatomic, assign) BOOL doubleFingerMenu;
@end

@implementation WXConfig
+ (instancetype)shared {
    static WXConfig *inst;
    static dispatch_once_t t;
    dispatch_once(&t, ^{
        inst = [WXConfig new];
        inst.autoRedPacket = YES;
        inst.autoReceiveMoney = YES;
        inst.jokerMessage = YES;
        inst.voiceForward = YES;
        inst.antiRecall = YES;
        inst.messageTime = YES;
        inst.timelineAdBlock = YES;
        inst.miniAppAdBlock = YES;
        inst.fakeQRCode = YES;
        inst.fakeDevice = YES;
        inst.doubleFingerMenu = YES;
    });
    return inst;
}
@end

#pragma mark - 悬浮菜单
@interface WXMenu : UIView
@end

@implementation WXMenu
- (instancetype)init {
    self = [super initWithFrame:CGRectMake(60, 120, 260, 450)];
    if (self) {
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.9];
        self.layer.cornerRadius = 14;
        self.clipsToBounds = YES;
        
        NSArray *names = @[
            @"自动抢红包", @"自动收款", @"小丑消息", @"语音转发", @"防撤回",
            @"消息显示秒数", @"朋友圈去广告", @"小程序去广告",
            @"二维码伪装相机", @"自定义设备信息", @"双指打开菜单"
        ];
        
        WXConfig *cfg = WXConfig.shared;
        NSArray *values = @[
            @(cfg.autoRedPacket), @(cfg.autoReceiveMoney), @(cfg.jokerMessage),
            @(cfg.voiceForward), @(cfg.antiRecall), @(cfg.messageTime),
            @(cfg.timelineAdBlock), @(cfg.miniAppAdBlock), @(cfg.fakeQRCode),
            @(cfg.fakeDevice), @(cfg.doubleFingerMenu)
        ];
        
        for (int i=0; i<names.count; i++) {
            UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20, 30+i*38, 180, 30)];
            label.text = names[i];
            label.textColor = UIColor.whiteColor;
            label.font = [UIFont systemFontOfSize:15];
            [self addSubview:label];
            
            UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(200, 30+i*38, 0, 0)];
            sw.on = [values[i] boolValue];
            sw.tag = 1000+i;
            [self addSubview:sw];
        }
        
        UIButton *btn = [UIButton buttonWithType:0];
        btn.frame = CGRectMake(0, 410, 260, 40);
        [btn setTitle:@"关闭菜单" forState:0];
        [btn setTitleColor:UIColor.whiteColor forState:0];
        [btn addTarget:self action:@selector(removeFromSuperview) forControlEvents:1<<6];
        [self addSubview:btn];
    }
    return self;
}
@end

#pragma mark - 功能实现
__attribute__((constructor))
static void main() {
    WXConfig *cfg = WXConfig.shared;
    NSLog(@"✅ 微信插件加载成功");

    // 11 屏蔽多开/越狱/人脸检测（默认强制开启）
    Class env = objc_getClass("MMEnvironment");
    if (env) {
        MSHookMessageEx(env, @selector(isAppDuplicated), (IMP)BOOL{return NO;}, NULL);
        MSHookMessageEx(env, @selector(isJailbroken), (IMP)BOOL{return NO;}, NULL);
        MSHookMessageEx(env, @selector(checkSafeEnvironment), (IMP)id{return @YES;}, NULL);
    }

    // 双指打开菜单
    Class win = objc_getClass("WCFullScreenWindow");
    if (win) {
        static void (*o)(id,SEL,NSSet*,UIEvent*);
        void h(id self, SEL _s, NSSet *t, UIEvent *e) {
            o(self,_s,t,e);
            if (cfg.doubleFingerMenu && t.count == 2) {
                static WXMenu *m;
                static dispatch_once_t tt;
                dispatch_once(&tt, ^{ m = [WXMenu new]; });
                [[UIApplication sharedApplication].keyWindow addSubview:m];
            }
        }
        MSHookMessageEx(win, @selector(touchesBegan:withEvent:), (IMP)h, (IMP)&o);
    }

    // 1 自动抢红包
    Class red = objc_getClass("WCRedEnvelopesReceiveControlLogic");
    if (red) {
        static void (*o)(id,SEL,id);
        void h(id self, SEL _s, id msg) {
            o(self,_s,msg);
            if (cfg.autoRedPacket) {
                [self performSelector:@selector(onOpenRedEnvelopes:) withObject:msg afterDelay:0.1];
            }
        }
        MSHookMessageEx(red, @selector(onReceiveRedEnvelopesMsg:), (IMP)h, (IMP)&o);
    }

    // 2 自动收款+自动回复
    Class tran = objc_getClass("WCPayTransferControlLogic");
    if (tran) {
        static void (*o)(id,SEL,id);
        void h(id self, SEL _s, id msg) {
            o(self,_s,msg);
            if (cfg.autoReceiveMoney) {
                [self performSelector:@selector(onAcceptTransfer:) withObject:msg afterDelay:0.1];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    id mgr = objc_getClass("MessageSendMgr");
                    [mgr sendMessageToUser:msg.fromUser text:@"自动收款谢谢"];
                });
            }
        }
        MSHookMessageEx(tran, @selector(onReceiveTransferMsg:), (IMP)h, (IMP)&o);
    }

    // 3 小丑消息
    Class msgCell = objc_getClass("MessageCellView");
    if (msgCell) {
        static void (*o)(id,SEL,id);
        void h(id self, SEL _s, id msg) {
            o(self,_s,msg);
            if (cfg.jokerMessage && !msg.isSenderMe) {
                UILabel *lab = [self valueForKey:@"_textLabel"];
                if (lab) lab.text = @"🧟‍♂️ 本条消息已被小丑修改";
            }
        }
        MSHookMessageEx(msgCell, @selector(setMessageContent:), (IMP)h, (IMP)&o);
    }

    // 4 语音转发
    Class voice = objc_getClass("WCVoiceMessageCellView");
    if (voice) {
        static BOOL (*o)(id,SEL);
        BOOL h(id self, SEL _s) {
            return cfg.voiceForward ? YES : o(self,_s);
        }
        MSHookMessageEx(voice, @selector(canForward), (IMP)h, (IMP)&o);
    }

    // 5 防撤回
    Class recall = objc_getClass("CMessageMgr");
    if (recall) {
        static void (*o)(id,SEL,id);
        void h(id self, SEL _s, id msg) {
            if (!cfg.antiRecall) o(self,_s,msg);
            else NSLog(@"🚫 拦截撤回");
        }
        MSHookMessageEx(recall, @selector(revokeMsg:), (IMP)h, (IMP)&o);
    }

    // 6 消息时间精确到秒
    Class time = objc_getClass("MessageHeaderView");
    if (time) {
        static void (*o)(id,SEL,NSString*);
        void h(id self, SEL _s, NSString *t) {
            if (cfg.messageTime) {
                NSDateFormatter *f = [NSDateFormatter new];
                f.dateFormat = @"HH:mm:ss";
                o(self,_s,[f stringFromDate:[NSDate date]]);
            } else {
                o(self,_s,t);
            }
        }
        MSHookMessageEx(time, @selector(setTimeLabelText:), (IMP)h, (IMP)&o);
    }

    // 7 朋友圈去广告
    Class feedAd = objc_getClass("FeedsAdTableViewCell");
    if (feedAd) {
        static id (*o)(id,SEL);
        id h(id self, SEL _s) {
            return cfg.timelineAdBlock ? nil : o(self,_s);
        }
        MSHookMessageEx(feedAd, @selector(getAdInfo), (IMP)h, (IMP)&o);
    }

    // 8 小程序去广告
    Class webAd = objc_getClass("WebViewAdLogic");
    if (webAd) {
        static void (*o)(id,SEL);
        void h(id self, SEL _s) {
            if (!cfg.miniAppAdBlock) o(self,_s);
        }
        MSHookMessageEx(webAd, @selector(loadAd), (IMP)h, (IMP)&o);
    }

    // 9 二维码伪装相机
    Class qr = objc_getClass("WCScanQRCodeLogic");
    if (qr) {
        static BOOL (*o)(id,SEL);
        BOOL h(id self, SEL _s) {
            return cfg.fakeQRCode ? YES : o(self,_s);
        }
        MSHookMessageEx(qr, @selector(isFromCamera), (IMP)h, (IMP)&o);
    }

    // 10 自定义设备型号
    Class device = objc_getClass("DeviceUtil");
    if (device) {
        static NSString* (*o1)(id,SEL);
        NSString* h1(id self, SEL _s) {
            return cfg.fakeDevice ? @"iPhone 16 Pro" : o1(self,_s);
        }
        static NSString* (*o2)(id,SEL);
        NSString* h2(id self, SEL _s) {
            return cfg.fakeDevice ? @"iOS 18.2" : o2(self,_s);
        }
        MSHookMessageEx(device, @selector(getDeviceName), (IMP)h1, (IMP)&o1);
        MSHookMessageEx(device, @selector(getSystemVersion), (IMP)h2, (IMP)&o2);
    }
}
