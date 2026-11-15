//
//  bridge.h
//  Camlo · 开幕
//

#ifndef bridge_h
#define bridge_h

#import "Bridge/bad_query.h"
#import "Bridge/worse_query.h"
#import "Bridge/pathleak.h"
#import "Bridge/CSStoreResolver.h"
#import "Bridge/CAPackageHost.h"
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

typedef struct CF_BRIDGED_TYPE(id) __SecTask *SecTaskRef;

SecTaskRef _Nullable SecTaskCreateFromSelf(CFAllocatorRef _Nullable allocator) CF_RETURNS_RETAINED;

CFTypeRef _Nullable SecTaskCopyValueForEntitlement(SecTaskRef _Nonnull task, CFStringRef _Nonnull entitlement, CFErrorRef _Nullable * _Nullable error) CF_RETURNS_RETAINED;

#endif /* bridge_h */
