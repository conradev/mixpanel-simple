//
//  Mixpanel.m
//  mixpanel-simple
//
//  Created by Conrad Kramer on 10/2/14.
//  Copyright (c) 2014 DeskConnect. All rights reserved.
//

#import "Mixpanel.h"
#import "MPTracker.h"
#import "MPFlusher.h"

@implementation Mixpanel

@synthesize tracker=_tracker;
@synthesize flusher=_flusher;

- (instancetype)init {
    return [self initWithToken:nil cacheDirectory:nil];
}

- (instancetype)initWithToken:(NSString *)token cacheDirectory:(NSURL *)cacheDirectory {
    self = [super init];
    if (self) {
        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        NSURL *cacheURL = [cacheDirectory URLByAppendingPathComponent:[NSString stringWithFormat:@"Mixpanel-%@%@.plist", token, (bundleIdentifier ? [NSString stringWithFormat:@"-%@", bundleIdentifier] : @"")]];
        _tracker = [[MPTracker alloc] initWithToken:token cacheURL:cacheURL];
        _flusher = [[MPFlusher alloc] initWithCacheDirectory:cacheDirectory];

        if (!_tracker && !_flusher) {
            [self release];
            return nil;
        }
    }
    return self;
}

- (void)dealloc {
    [_tracker release];
    [_flusher release];
    [super dealloc];
}

@end
