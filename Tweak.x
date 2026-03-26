#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "WeChatPlugin.h"

#pragma mark - 功能开关

static BOOL g_enableRedEnvelope = YES;
static BOOL g_enableAutoReceive = YES;
static BOOL g_enableAntiRecall = YES;
static BOOL g_enableAdBlock = YES;

#pragma mark - 消息处理

%group MessageGroup

%hook CMessageWrap

- (void)setM_uiMessageType:(unsigned int)type {
    %orig;
    WXPluginLog(@"收到消息类型: %u, 内容: %@", type, self.m_nsContent);
}

%end

%hook CMessageMgr

- (BOOL)SendMessage:(id)message toUserName:(id)userName {
    WXPluginLog(@"发送消息给: %@, 内容: %@", userName, message);
    return %orig;
}

%end

%end

#pragma mark - 红包相关

%group RedEnvelopeGroup

%hook NSObject

%new
- (void)handleRedEnvelope {
    if (!g_enableRedEnvelope) return;
    WXPluginLog(@"检测到红包，准备自动领取");
}

%end

%end

#pragma mark - 防撤回

%group AntiRecallGroup

%hook NSObject

%new
- (void)preventRecall {
    if (!g_enableAntiRecall) return;
    WXPluginLog(@"防撤回功能已触发");
}

%end

%end

#pragma mark - 初始化

%ctor {
    WXPluginLog(@"功能模块初始化");
    
    %init(MessageGroup);
    
    if (g_enableRedEnvelope) {
        %init(RedEnvelopeGroup);
    }
    
    if (g_enableAntiRecall) {
        %init(AntiRecallGroup);
    }
}
