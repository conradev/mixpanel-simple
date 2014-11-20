//
//  MPUtilitiesTest.m
//  mixpanel-simple
//
//  Created by Conrad Kramer on 11/20/14.
//  Copyright (c) 2014 DeskConnect. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "MPUtilities.h"

@interface MPUtilitiesTest : XCTestCase

@end

@implementation MPUtilitiesTest

- (void)testArbitraryObjectSerialization {
    id object = MPJSONSerializableObject(@{@"stream": [NSStream new]});
    XCTAssertTrue([NSJSONSerialization isValidJSONObject:object]);
    XCTAssertTrue([[object objectForKey:@"stream"] isKindOfClass:[NSString class]]);
}

- (void)testSetSerialization {
    id object = MPJSONSerializableObject(@{@"set": [NSSet setWithObject:@""]});
    XCTAssertTrue([NSJSONSerialization isValidJSONObject:object]);
    XCTAssertTrue([[object objectForKey:@"set"] isKindOfClass:[NSArray class]]);
}

@end
