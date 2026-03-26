#include <substrate.h>
#include <Foundation/Foundation.h>

__attribute__((constructor))
static void myinit() {
    NSLog(@"✅ 插件编译成功！");
}
