//
//  MixpanelTests.m
//  mixpanel-simple
//
//  Created by Conrad Kramer on 11/20/14.
//  Copyright (c) 2014 DeskConnect. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <objc/runtime.h>

#import "Mixpanel.h"
#import "MPTracker.h"

@interface NSBundle (MixpanelBundleIdentifier)

@end

static char bundleIdentifierKey;

@implementation NSBundle (MixpanelBundleIdentifier)

+ (void)load {
    Method identifierMethod = class_getInstanceMethod(self, @selector(bundleIdentifier));
    Method customIdentifierMethod = class_getInstanceMethod(self, @selector(mp_bundleIdentifier));
    method_exchangeImplementations(identifierMethod, customIdentifierMethod);
}

- (void)mp_setBundleIdentifier:(NSString *)bundleIdentifier {
    objc_setAssociatedObject(self, &bundleIdentifierKey, bundleIdentifier, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *)mp_bundleIdentifier {
    return (objc_getAssociatedObject(self, &bundleIdentifierKey) ?: [self mp_bundleIdentifier]);
}

@end

@interface MixpanelTests : XCTestCase

@end

@implementation MixpanelTests

- (void)testInvalidInitialization {
    XCTAssertNil([[Mixpanel alloc] initWithToken:@"abc123" cacheDirectory:[NSURL fileURLWithPath:@"/mixpanel/somefile"]]);
    XCTAssertThrowsSpecificNamed([[Mixpanel alloc] initWithToken:nil cacheDirectory:[NSURL fileURLWithPath:@"/mixpanel/somefile"]], NSException, NSInternalInconsistencyException);
    XCTAssertThrowsSpecificNamed([[Mixpanel alloc] initWithToken:@"abc123" cacheDirectory:nil], NSException, NSInternalInconsistencyException);
}

- (void)testCacheURLWithNoBundleIdentifier {
    NSURL *cacheDirectory = [NSURL fileURLWithPath:[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject]];
    Mixpanel *mixpanel = [[Mixpanel alloc] initWithToken:@"abc123" cacheDirectory:cacheDirectory];
    XCTAssertTrue([mixpanel.tracker.cacheURL isEqual:[cacheDirectory URLByAppendingPathComponent:@"Mixpanel-abc123.plist"]]);
}

- (void)testCacheURL {
    [[NSBundle mainBundle] mp_setBundleIdentifier:@"com.mixpanel.test"];
    NSURL *cacheDirectory = [NSURL fileURLWithPath:[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject]];
    Mixpanel *mixpanel = [[Mixpanel alloc] initWithToken:@"abc123" cacheDirectory:cacheDirectory];
    XCTAssertTrue([mixpanel.tracker.cacheURL isEqual:[cacheDirectory URLByAppendingPathComponent:@"Mixpanel-abc123-com.mixpanel.test.plist"]]);
    [[NSBundle mainBundle] mp_setBundleIdentifier:nil];
}

@end
