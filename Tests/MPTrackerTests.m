//
//  MPTrackerTests.m
//  mixpanel-simple
//
//  Created by Conrad Kramer on 11/19/14.
//  Copyright (c) 2014 DeskConnect. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "MPTracker.h"

@interface MPTrackerTests : XCTestCase

@end

@implementation MPTrackerTests {
    MPTracker *_tracker;
}

- (void)setUp {
    [super setUp];
    NSURL *cacheURL = [[NSURL fileURLWithPath:[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject]] URLByAppendingPathComponent:@"Mixpanel.plist"];
    _tracker = [[MPTracker alloc] initWithToken:@"abc123" cacheURL:cacheURL];
}

- (void)tearDown {
    _tracker = nil;
    [super tearDown];
}

- (void)testInvalidInitialization {
    XCTAssertNil([[MPTracker alloc] initWithToken:@"abc123" cacheURL:[NSURL fileURLWithPath:@"/mixpanel/somefile"]]);
    XCTAssertThrowsSpecificNamed([[MPTracker alloc] initWithToken:nil cacheURL:[NSURL fileURLWithPath:@"/mixpanel/somefile"]], NSException, NSInternalInconsistencyException);
    XCTAssertThrowsSpecificNamed([[MPTracker alloc] initWithToken:@"abc123" cacheURL:nil], NSException, NSInternalInconsistencyException);
    XCTAssertThrowsSpecificNamed([[MPTracker alloc] init], NSException, NSInternalInconsistencyException);
}

@end
