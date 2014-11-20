//
//  MPFlushOperationTests.m
//  mixpanel-simple
//
//  Created by Conrad Kramer on 11/19/14.
//  Copyright (c) 2014 DeskConnect. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "MPFlushOperation.h"

@interface MPFlushOperationTests : XCTestCase

@end

@implementation MPFlushOperationTests

- (void)testInvalidInitialization {
    XCTAssertNil([[MPFlushOperation alloc] initWithCacheURL:[NSURL fileURLWithPath:@"/mixpanel/somefile"]]);
    XCTAssertThrowsSpecificNamed([[MPFlushOperation alloc] initWithCacheURL:nil], NSException, NSInternalInconsistencyException);
    XCTAssertThrowsSpecificNamed([[MPFlushOperation alloc] init], NSException, NSInternalInconsistencyException);
}

@end
