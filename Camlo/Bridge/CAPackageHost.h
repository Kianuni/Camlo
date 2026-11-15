//
//  CAPackageHost.h
//  Camlo · 开幕
//
//  Exception-safe Objective-C host bridging QuartzCore CAPackage and
//  CAStateController for 120Hz hardware-accelerated CAML live preview.
//

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

NS_ASSUME_NONNULL_BEGIN

@interface CamloCAStageController : NSObject

@property (nonatomic, strong, readonly) CALayer *rootLayer;
@property (nonatomic, assign, readonly) CGSize documentSize;
@property (nonatomic, assign, readonly) BOOL isGeometryFlipped;

- (nullable instancetype)initWithPackageURL:(NSURL *)url
                                      error:(NSError * _Nullable * _Nullable)outError;

- (BOOL)hasStateNamed:(NSString *)stateName;
- (void)applyInitialStates;
- (BOOL)transitionToStateNamed:(NSString *)stateName speed:(float)speed;
- (void)teardown;

@end

NS_ASSUME_NONNULL_END
