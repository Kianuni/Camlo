//
//  CAPackageHost.m
//  Camlo · 开幕
//

#import "CAPackageHost.h"

extern NSString * const kCAPackageTypeCAMLBundle;
extern NSString * const kCAPackageTypeCAMLFile;

@interface CAState : NSObject
@property (nonatomic, copy) NSString *name;
@end

@interface CAPackage : NSObject
+ (nullable instancetype)packageWithContentsOfURL:(NSURL *)url
                                             type:(NSString *)type
                                          options:(nullable NSDictionary *)options
                                            error:(NSError **)error;
@property (nullable, readonly) CALayer *rootLayer;
@property (readonly, getter=isGeometryFlipped) BOOL geometryFlipped;
@end

@interface CALayer (CamloCAStateLookup)
- (nullable CAState *)stateWithName:(NSString *)name;
@end

@interface CAStateController : NSObject
- (instancetype)initWithLayer:(CALayer *)layer;
- (void)setInitialStatesOfLayer:(CALayer *)layer;
- (void)setState:(nullable CAState *)state ofLayer:(CALayer *)layer transitionSpeed:(float)speed;
- (void)cancelTimers;
@end

static NSError *CamloCAHostError(NSInteger code, NSString *description) {
    return [NSError errorWithDomain:@"com.kianuni.camlo.ca"
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: description ?: @"CAPackage error"}];
}

static CGSize CamloReadDocumentSize(NSURL *url, CALayer *rootLayer) {
    CGSize boundsSize = rootLayer.bounds.size;
    if (boundsSize.width > 1.0 && boundsSize.height > 1.0) {
        return boundsSize;
    }

    BOOL isDirectory = NO;
    [[NSFileManager defaultManager] fileExistsAtPath:url.path isDirectory:&isDirectory];
    if (isDirectory) {
        NSURL *indexURL = [url URLByAppendingPathComponent:@"index.xml"];
        NSDictionary *indexPlist = [NSDictionary dictionaryWithContentsOfURL:indexURL];
        if ([indexPlist isKindOfClass:[NSDictionary class]]) {
            double docW = [indexPlist[@"documentWidth"] doubleValue];
            double docH = [indexPlist[@"documentHeight"] doubleValue];
            if (docW > 1.0 && docH > 1.0) {
                return CGSizeMake((CGFloat)docW, (CGFloat)docH);
            }
        }
    }

    return CGSizeMake(390.0, 844.0);
}

@interface CamloCAStageController ()
@property (nonatomic, strong) CAPackage *package;
@property (nonatomic, strong, readwrite) CALayer *rootLayer;
@property (nonatomic, assign, readwrite) CGSize documentSize;
@property (nonatomic, assign, readwrite) BOOL isGeometryFlipped;
@property (nonatomic, strong, nullable) CAStateController *primaryController;
@property (nonatomic, strong) NSMapTable<CALayer *, CAStateController *> *sublayerControllers;
@end

@implementation CamloCAStageController

- (nullable instancetype)initWithPackageURL:(NSURL *)url
                                      error:(NSError * _Nullable * _Nullable)outError {
    self = [super init];
    if (!self) {
        return nil;
    }

    _sublayerControllers = [NSMapTable weakToStrongObjectsMapTable];

    if (!url || !url.isFileURL) {
        if (outError) {
            *outError = CamloCAHostError(1001, @"Invalid Core Animation package URL.");
        }
        return nil;
    }

    BOOL isDirectory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:url.path isDirectory:&isDirectory]) {
        if (outError) {
            *outError = CamloCAHostError(1002, @"Core Animation package path does not exist.");
        }
        return nil;
    }

    NSString *packageType = isDirectory ? kCAPackageTypeCAMLBundle : kCAPackageTypeCAMLFile;

    @try {
        NSError *loadError = nil;
        CAPackage *pkg = [CAPackage packageWithContentsOfURL:url
                                                        type:packageType
                                                     options:nil
                                                       error:&loadError];
        if (!pkg || !pkg.rootLayer) {
            if (outError) {
                *outError = loadError ?: CamloCAHostError(1003, @"CAPackage returned a nil rootLayer.");
            }
            return nil;
        }

        CALayer *root = pkg.rootLayer;
        CAStateController *controller = [[CAStateController alloc] initWithLayer:root];
        [controller setInitialStatesOfLayer:root];

        _package = pkg;
        _rootLayer = root;
        _isGeometryFlipped = pkg.isGeometryFlipped;
        _documentSize = CamloReadDocumentSize(url, root);
        _primaryController = controller;
        return self;
    } @catch (NSException *exception) {
        if (outError) {
            NSString *reason = exception.reason ?: exception.name ?: @"Unknown NSException loading CAML package.";
            *outError = CamloCAHostError(1004, reason);
        }
        return nil;
    }
}

- (nullable CAStateController *)controllerForTargetLayer:(CALayer *)targetLayer {
    if (!targetLayer) {
        return nil;
    }
    if (targetLayer == self.rootLayer) {
        return self.primaryController;
    }
    CAStateController *existing = [self.sublayerControllers objectForKey:targetLayer];
    if (existing) {
        return existing;
    }
    @try {
        CAStateController *created = [[CAStateController alloc] initWithLayer:targetLayer];
        [created setInitialStatesOfLayer:targetLayer];
        [self.sublayerControllers setObject:created forKey:targetLayer];
        return created;
    } @catch (NSException *exception) {
        return nil;
    }
}

- (nullable CALayer *)resolveLayerWithStateNamed:(NSString *)stateName
                                        outState:(CAState * _Nullable * _Nullable)outState {
    if (!stateName.length || !self.rootLayer) {
        return nil;
    }

    @try {
        if ([self.rootLayer respondsToSelector:@selector(stateWithName:)]) {
            CAState *rootState = [self.rootLayer stateWithName:stateName];
            if (rootState) {
                if (outState) {
                    *outState = rootState;
                }
                return self.rootLayer;
            }

            for (CALayer *sublayer in self.rootLayer.sublayers) {
                if ([sublayer respondsToSelector:@selector(stateWithName:)]) {
                    CAState *subState = [sublayer stateWithName:stateName];
                    if (subState) {
                        if (outState) {
                            *outState = subState;
                        }
                        return sublayer;
                    }
                }
            }
        }
    } @catch (NSException *exception) {
        return nil;
    }

    return nil;
}

- (BOOL)hasStateNamed:(NSString *)stateName {
    return [self resolveLayerWithStateNamed:stateName outState:NULL] != nil;
}

- (void)applyInitialStates {
    @try {
        if (self.primaryController && self.rootLayer) {
            [self.primaryController setInitialStatesOfLayer:self.rootLayer];
        }
        for (CALayer *layer in self.sublayerControllers) {
            CAStateController *controller = [self.sublayerControllers objectForKey:layer];
            [controller setInitialStatesOfLayer:layer];
        }
    } @catch (NSException *exception) {
    }
}

- (BOOL)transitionToStateNamed:(NSString *)stateName speed:(float)speed {
    CAState *state = nil;
    CALayer *targetLayer = [self resolveLayerWithStateNamed:stateName outState:&state];
    if (!targetLayer || !state) {
        return NO;
    }

    CAStateController *controller = [self controllerForTargetLayer:targetLayer];
    if (!controller) {
        return NO;
    }

    @try {
        [controller setState:state ofLayer:targetLayer transitionSpeed:speed];
        return YES;
    } @catch (NSException *exception) {
        return NO;
    }
}

- (void)teardown {
    @try {
        [self.primaryController cancelTimers];
        self.primaryController = nil;
        for (CALayer *layer in self.sublayerControllers) {
            CAStateController *controller = [self.sublayerControllers objectForKey:layer];
            [controller cancelTimers];
        }
        [self.sublayerControllers removeAllObjects];
    } @catch (NSException *exception) {
    }
}

- (void)dealloc {
    [self teardown];
}

@end
