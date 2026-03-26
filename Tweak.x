#include <substrate.h>
#include <UIKit/UIKit.h>
#include <Foundation/Foundation.h>

__attribute__((constructor))
static void init(void) {
    NSLog(@"✅ 微信插件加载成功");
}
