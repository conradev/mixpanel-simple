//
//  MPFlusherTests.m
//  mixpanel-simple
//
//  Created by Conrad Kramer on 11/19/14.
//  Copyright (c) 2014 DeskConnect. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "MPFlusher.h"

@interface MPFlusherTests : XCTestCase

@end

@implementation MPFlusherTests

- (void)testInvalidInitialization {
    XCTAssertNil([[MPFlusher alloc] initWithCacheDirectory:[NSURL fileURLWithPath:@"/mixpanel/somefile"]]);
    XCTAssertThrowsSpecificNamed([[MPFlusher alloc] initWithCacheDirectory:nil], NSException, NSInternalInconsistencyException);
}

@end
