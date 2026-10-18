// Godot 4.6 uses a SwiftUI hosting controller above the engine controller.
// Apply orientation policy to that root and explicitly request iOS scene geometry.
#import <UIKit/UIKit.h>
#import <CoreMotion/CoreMotion.h>
#import <objc/runtime.h>

static UIInterfaceOrientationMask SichuanLandscapeMask(id self, SEL command) {
    return UIInterfaceOrientationMaskLandscape;
}
static BOOL SichuanAutorotate(id self, SEL command) { return YES; }

@interface SichuanLandscapeRotation : NSObject
@property(nonatomic, strong) CMMotionManager *motion;
@property(nonatomic) UIInterfaceOrientationMask candidate;
@property(nonatomic) CFTimeInterval candidateSince;
@property(nonatomic) BOOL requestInFlight;
@property(nonatomic) CFTimeInterval lastRequest;
+ (instancetype)shared;
- (void)start;
- (void)sampleX:(double)x y:(double)y;
@end

@implementation SichuanLandscapeRotation
+ (instancetype)shared {
    static SichuanLandscapeRotation *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ instance = [self new]; });
    return instance;
}
- (void)installPolicy:(UIViewController *)root {
    // Override the concrete hosting class, never UIViewController globally.
    Class host = object_getClass(root);
    if (!strstr(class_getName(host), "HostingController")) return;
    class_replaceMethod(host, @selector(supportedInterfaceOrientations), (IMP)SichuanLandscapeMask, "Q@:");
    class_replaceMethod(host, @selector(shouldAutorotate), (IMP)SichuanAutorotate, "B@:");
}
- (void)start {
    if (!self.motion) {
        self.motion = [CMMotionManager new];
        self.motion.accelerometerUpdateInterval = 0.15;
    }
    if (!self.motion.accelerometerAvailable || self.motion.accelerometerActive) return;
    __weak SichuanLandscapeRotation *weakSelf = self;
    [self.motion startAccelerometerUpdatesToQueue:NSOperationQueue.mainQueue
        withHandler:^(CMAccelerometerData *data, NSError *error) {
            if (data && !error) [weakSelf sampleX:data.acceleration.x y:data.acceleration.y];
        }];
}
- (void)sampleX:(double)x y:(double)y {
    if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;
    // In portrait/flat poses keep the last landscape side; reject motion noise.
    if (fabs(x) < 0.65 || fabs(x) < fabs(y) + 0.15) {
        self.candidate = 0;
        return;
    }
    UIInterfaceOrientationMask target = x > 0 ? UIInterfaceOrientationMaskLandscapeLeft : UIInterfaceOrientationMaskLandscapeRight;
    CFTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    if (target != self.candidate) {
        self.candidate = target;
        self.candidateSince = now;
        return;
    }
    if (now - self.candidateSince < 0.35 || self.requestInFlight || now - self.lastRequest < 1.0) return;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class] || scene.activationState != UISceneActivationStateForegroundActive) continue;
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        UIWindow *window = nil;
        for (UIWindow *candidate in windowScene.windows) if (candidate.isKeyWindow) { window = candidate; break; }
        UIViewController *root = window.rootViewController;
        if (!root) continue;
        [self installPolicy:root];
        UIInterfaceOrientation current = windowScene.interfaceOrientation;
        if ((target == UIInterfaceOrientationMaskLandscapeLeft && current == UIInterfaceOrientationLandscapeLeft) ||
            (target == UIInterfaceOrientationMaskLandscapeRight && current == UIInterfaceOrientationLandscapeRight)) continue;
        if (@available(iOS 16.0, *)) {
            self.lastRequest = now;
            self.requestInFlight = YES;
            [root setNeedsUpdateOfSupportedInterfaceOrientations];
            UIWindowSceneGeometryPreferencesIOS *preferences = [[UIWindowSceneGeometryPreferencesIOS alloc] initWithInterfaceOrientations:target];
            [windowScene requestGeometryUpdateWithPreferences:preferences errorHandler:^(NSError *error) {
                NSLog(@"Sichuan landscape request failed: %@", error.localizedDescription);
            }];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                self.requestInFlight = NO;
                NSLog(@"Sichuan landscape sensor: target=%lu actual=%ld", (unsigned long)target, (long)windowScene.interfaceOrientation);
            });
        } else {
            // On pre-iOS16 UIKit handles sensor rotation with the root mask.
            [UIViewController attemptRotationToDeviceOrientation];
        }
    }
}
@end

// Plugin initialization runs after UIApplication exists and before gameplay.
void sichuan_landscape_rotation_initialize(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        SichuanLandscapeRotation *rotation = [SichuanLandscapeRotation shared];
        [NSNotificationCenter.defaultCenter addObserver:rotation selector:@selector(start) name:UIApplicationDidBecomeActiveNotification object:nil];
        [rotation start];
    });
}
