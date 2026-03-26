#include <substrate.h>
#include <UIKit/UIKit.h>
#include <Foundation/Foundation.h>

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
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [[WXConfig alloc] init];
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

@interface WXMenu : UIView
@end

@implementation WXMenu
- (instancetype)init {
    self = [super initWithFrame:CGRectMake(50, 100, 260, 440)];
    if (self) {
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.9];
        self.layer.cornerRadius = 12;
        self.clipsToBounds = YES;
    }
    return self;
}
@end

static void showMenu() {
    WXConfig *cfg = [WXConfig shared];
    if (!cfg.doubleFingerMenu) return;
    static WXMenu *menu;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        menu = [[WXMenu alloc] init];
    });
    [[UIApplication sharedApplication].keyWindow addSubview:menu];
}

__attribute__((constructor))
static void initPlugin() {
    WXConfig *cfg = [WXConfig shared];
    NSLog(@"WeChat Plugin Loaded");

    Class cls = objc_getClass("MMEnvironment");
    if (cls) {
        MSHookMessageEx(cls, @selector(isAppDuplicated), imp_getBypass(), NULL);
        MSHookMessageEx(cls, @selector(isJailbroken), imp_getBypass(), NULL);
    }

    Class winCls = objc_getClass("WCFullScreenWindow");
    if (winCls) {
        static void (*orig)(id, SEL, NSSet*, UIEvent*);
        void hook(id self, SEL sel, NSSet *touches, UIEvent *e) {
            orig(self, sel, touches, e);
            if (touches.count == 2) showMenu();
        }
        MSHookMessageEx(winCls, @selector(touchesBegan:withEvent:), (IMP)hook, (IMP)&orig);
    }
}

static BOOL imp_getBypass() { return NO; }
