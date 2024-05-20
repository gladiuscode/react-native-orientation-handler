#import <React/RCTEventEmitter.h>

#ifdef RCT_NEW_ARCH_ENABLED
#import "RNOrientationHandlerSpec.h"

@interface OrientationHandler : RCTEventEmitter <NativeOrientationHandlerSpec>
#else
#import <React/RCTBridgeModule.h>

@interface OrientationHandler : RCTEventEmitter <RCTBridgeModule>
#endif

@property (nonatomic, assign) BOOL isJsListening;

+(UIInterfaceOrientationMask)getSupportedInterfaceOrientationsForWindow;

@end
