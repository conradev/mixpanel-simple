//
//  MPFlushOperation.m
//  mixpanel-simple
//
//  Created by Conrad Kramer on 11/19/14.
//  Copyright (c) 2014 DeskConnect. All rights reserved.
//

#import "MPFlushOperation.h"
#import "MPTracker.h"
#import "MPUtilities.h"

extern NSString * const MPEventQueueKey;

@implementation MPFlushOperation

@synthesize cacheURL=_cacheURL;

- (instancetype)init {
    return [self initWithCacheURL:nil];
}

- (instancetype)initWithCacheURL:(NSURL *)cacheURL {
    NSParameterAssert(cacheURL);
    self = [super init];
    if (self) {
        if (![[NSFileManager defaultManager] fileExistsAtPath:cacheURL.path]) {
            NSLog(@"%@: Invalid cache file", self);
            [self release];
            return nil;
        }

        _cacheURL = [cacheURL copy];
    }
    return self;
}

- (void)dealloc {
    [_cacheURL release];
    [_coordinator cancel];
    [_coordinator release];
    [super dealloc];
}

- (void)main {
    _coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
    [_coordinator coordinateWritingItemAtURL:_cacheURL options:NSFileCoordinatorWritingForMerging error:nil byAccessor:^(NSURL *newURL) {
        NSMutableDictionary *state = [NSMutableDictionary dictionaryWithContentsOfURL:newURL];
        if (!state)
            return;

        NSMutableArray *eventQueue = [NSMutableArray arrayWithArray:[state objectForKey:MPEventQueueKey]];
        NSUInteger length = MIN(eventQueue.count, 50);
        if (!length)
            return;

        NSRange batchRange = NSMakeRange(0, length);
        NSArray *batch = [eventQueue subarrayWithRange:batchRange];
        NSURLRequest *request = MPURLRequestForEvents(batch);
        if (!request)
            return;

        NSError *error = nil;
        NSHTTPURLResponse *response = nil;
        NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];

        NSIndexSet *acceptableCodes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 100)];
        if (!error && [acceptableCodes containsIndex:response.statusCode]) {
            if ([[[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease] integerValue] != 1) {
                NSLog(@"%@: Not all events accepted by server", self);
            }
            [eventQueue removeObjectsInRange:batchRange];
        } else {
            NSLog(@"%@: Error uploading events", self);
        }

        [state setObject:eventQueue forKey:MPEventQueueKey];
        [state writeToURL:newURL atomically:YES];
    }];
    [_coordinator release];
    _coordinator = nil;
}

- (void)cancel {
    [_coordinator cancel];
    [super cancel];
}

@end
