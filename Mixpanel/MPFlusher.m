//
//  MPFlusher.m
//  mixpanel-simple
//
//  Created by Conrad Kramer on 11/19/14.
//  Copyright (c) 2014 DeskConnect. All rights reserved.
//

#import "MPFlusher.h"
#import "MPFlushOperation.h"

@implementation MPFlusher

@synthesize cacheDirectory=_cacheDirectory;

- (instancetype)init {
    return [self initWithCacheDirectory:nil];
}

- (instancetype)initWithCacheDirectory:(NSURL *)cacheDirectory {
    NSParameterAssert(cacheDirectory);
    self = [super init];
    if (self) {
        BOOL directory = NO;
        if (![[NSFileManager defaultManager] fileExistsAtPath:cacheDirectory.path isDirectory:&directory] || !directory) {
            NSLog(@"%@: Invalid cache directory provided", self);
            [self release];
            return nil;
        }

        _cacheDirectory = [cacheDirectory copy];
        _flushOperationQueue = [NSOperationQueue new];
        [self setFlushInterval:15.0f];
    }
    return self;
}

- (void)dealloc {
    [_cacheDirectory release];
    [_flushOperationQueue release];
    [_flushTimer invalidate];
    [_flushTimer release];
    [super dealloc];
}

- (NSTimeInterval)flushInterval {
    return _flushTimer.timeInterval;
}

- (void)setFlushInterval:(NSTimeInterval)flushInterval {
    [_flushTimer invalidate];
    [_flushTimer release];
    NSTimer *flushTimer = [NSTimer timerWithTimeInterval:flushInterval target:self selector:@selector(flush) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:flushTimer forMode:NSRunLoopCommonModes];
    _flushTimer = [flushTimer retain];
    [_flushTimer fire];
}

- (void)flush {
    NSSet *queuedURLs = [NSSet setWithArray:[_flushOperationQueue.operations valueForKey:NSStringFromSelector(@selector(cacheURL))]];
    NSDirectoryEnumerator *cacheEnumerator = [[NSFileManager defaultManager] enumeratorAtURL:_cacheDirectory includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:^BOOL(NSURL *url, NSError *error) {
        return YES;
    }];
    for (NSURL *cacheURL in cacheEnumerator) {
        cacheURL = [cacheURL URLByResolvingSymlinksInPath];
        if (![queuedURLs containsObject:cacheURL]) {
            MPFlushOperation *operation = [[MPFlushOperation alloc] initWithCacheURL:cacheURL];
            [_flushOperationQueue addOperation:operation];
            [operation release];
        }
    }
}

@end
