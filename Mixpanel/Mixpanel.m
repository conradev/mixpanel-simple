//
//  Mixpanel.m
//
//  Created by Conrad Kramer on 10/2/14.
//  Copyright (c) 2014 DeskConnect. All rights reserved.
//

#import <SystemConfiguration/SystemConfiguration.h>
#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
#import <UIKit/UIKit.h>
#endif

#import "Mixpanel.h"
#import "MixpanelUtilities.h"

static NSString * const MPDistinctIdKey = @"MPDistinctId";
static NSString * const MPEventQueueKey = @"MPEventQueue";

static Mixpanel *sharedInstance = nil;

#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000) || (defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1070)
@interface Mixpanel () <NSFilePresenter>
@end
#endif

@implementation Mixpanel

@synthesize token = _token;
@synthesize distinctId = _distinctId;
@synthesize defaultProperties = _defaultProperties;
@synthesize presenting = _presenting;

#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000) || (defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1070)
@synthesize presentedItemOperationQueue = _presentedItemOperationQueue;
@synthesize presentedItemURL = _cacheURL;
#endif

+ (NSDictionary *)automaticProperties {
    static NSDictionary *automaticProperties = nil;
    if (!automaticProperties) {
        NSBundle *bundle = [NSBundle mainBundle];

        NSMutableDictionary *properties = [NSMutableDictionary dictionaryWithDictionary:MPDeviceProperties()];
        [properties setValue:[bundle.infoDictionary objectForKey:(id)kCFBundleVersionKey] forKey:@"$app_version"];
        [properties setValue:[bundle.infoDictionary objectForKey:@"CFBundleShortVersionString"] forKey:@"$app_release"];
        [properties setValue:@"iphone" forKey:@"mp_lib"];
        [properties setValue:@"1.0" forKey:@"$lib_version"];

        automaticProperties = [properties copy];
    }

    return automaticProperties;
}

+ (instancetype)sharedInstanceWithToken:(NSString *)token cacheDirectory:(NSURL *)cacheDirectory {
    if (!sharedInstance)
        sharedInstance = [[self alloc] initWithToken:token cacheDirectory:cacheDirectory];
    return sharedInstance;
}

+ (instancetype)sharedInstance {
    if (!sharedInstance)
        NSLog(@"%@: You must call +[Mixpanel sharedInstanceWithToken:cacheDirectory:] before calling +[Mixpanel sharedInstance]", self);
    return sharedInstance;
}

- (instancetype)init {
    self = [self initWithToken:nil cacheDirectory:nil];
    return self;
}

- (instancetype)initWithToken:(NSString *)token cacheDirectory:(NSURL *)cacheDirectory {
    NSParameterAssert(token);
    NSParameterAssert(cacheDirectory);
    self = [super init];
    if (self) {
        BOOL directory = NO;
        if (![[NSFileManager defaultManager] fileExistsAtPath:cacheDirectory.path isDirectory:&directory] || !directory) {
            NSLog(@"%@: You did not provide a valid cache directory", self);
            [self release];
            return nil;
        }

        NSString *bundleIdentifer = [[NSBundle mainBundle] bundleIdentifier];

        _token = [token copy];
        _cacheURL = [[[cacheDirectory URLByAppendingPathComponent:[NSString stringWithFormat:@"Mixpanel-%@-%@", bundleIdentifer, token]] URLByAppendingPathExtension:@"plist"] retain];

#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000) || (defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1070)
        _presentedItemOperationQueue = [[NSOperationQueue alloc] init];
#endif

        [self startPresenting];

        MPUnsafeObject *unsafeSelf = [MPUnsafeObject unsafeObjectWithObject:self];
        _timer = [[NSTimer scheduledTimerWithTimeInterval:15.0f target:unsafeSelf selector:@selector(flush) userInfo:nil repeats:YES] retain];
        [self flush];
    }
    return self;
}

- (void)dealloc {
    [self stopPresenting];
#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000) || (defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1070)
    [_presentedItemOperationQueue release];
#endif
    [_token release];
    [_distinctId release];
    [_defaultProperties release];
    [_timer invalidate];
    [_timer release];
    [_cacheURL release];
    [_eventQueue release];
    [super dealloc];
}

- (BOOL)isPresenting {
#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000) || (defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1070)
    return ([NSFileCoordinator class] ? [[NSFileCoordinator filePresenters] containsObject:self] : _presenting);
#else
    return _presenting;
#endif
}

- (void)startPresenting {
    if (_reading || _writing)
        return;

#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000) || (defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1070)
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __block NSDictionary *state = nil;
        if ([NSFileCoordinator class]) {
            NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:self];
            [coordinator coordinateReadingItemAtURL:_cacheURL options:0 error:nil byAccessor:^(NSURL *newURL) {
                state = [NSDictionary dictionaryWithContentsOfURL:newURL];
                [NSFileCoordinator addFilePresenter:self];
            }];
            [coordinator release];
        } else {
            state = [NSDictionary dictionaryWithContentsOfURL:_cacheURL];
        }
#else
        NSDictionary *state = [NSDictionary dictionaryWithContentsOfURL:_cacheURL];
#endif

        _presenting = YES;

        [_distinctId release];
        [_eventQueue release];

        _distinctId = [[state objectForKey:MPDistinctIdKey] copy];
        _eventQueue = ([[state objectForKey:MPEventQueueKey] mutableCopy] ?: [NSMutableArray new]);
        [_eventQueue addObjectsFromArray:_eventBuffer];

        [self save];

        [_eventBuffer release];
        _eventBuffer = nil;

#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000) || (defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1070)
    });
#endif
}

- (void)stopPresenting {
#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000) || (defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1070)
    [NSFileCoordinator removeFilePresenter:self];
#endif
    _presenting = NO;
}

- (NSString *)distinctId {
    if (!_distinctId) {
#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
        UIDevice *device = [UIDevice currentDevice];
        _distinctId = ([device respondsToSelector:@selector(identifierForVendor)] ? [[device.identifierForVendor UUIDString] copy] : [[device performSelector:@selector(uniqueIdentifier)] copy]);
#pragma clang diagnostic pop
#elif defined(__MAC_OS_X_VERSION_MIN_REQUIRED)
        io_registry_entry_t ioRegistryRoot = IORegistryEntryFromPath(kIOMasterPortDefault, "IOService:/");
        _distinctId = (NSString *)IORegistryEntryCreateCFProperty(ioRegistryRoot, CFSTR(kIOPlatformUUIDKey), kCFAllocatorDefault, 0);
        IOObjectRelease(ioRegistryRoot);
#endif
    }
    return _distinctId;
}

- (void)identify:(NSString *)distinctId {
    [_distinctId release];
    _distinctId = [distinctId copy];
    [self save];
}

#pragma mark - Queuing

- (void)track:(NSString *)event {
    [self track:event properties:nil];
}

- (void)track:(NSString *)event properties:(NSDictionary *)properties {
    NSParameterAssert(event);

    NSNumber *timestamp = [NSNumber numberWithInteger:(NSInteger)round([[NSDate date] timeIntervalSince1970])];

    NSMutableDictionary *mergedProperties = [NSMutableDictionary dictionaryWithDictionary:[[self class] automaticProperties]];
    [mergedProperties addEntriesFromDictionary:self.defaultProperties];
    [mergedProperties addEntriesFromDictionary:properties];
    [mergedProperties setValue:timestamp forKey:@"time"];
    [mergedProperties setValue:self.token forKey:@"token"];
    [mergedProperties setValue:self.distinctId forKey:@"distinct_id"];

    NSDictionary *eventDictionary = MPJSONSerializableObject([NSDictionary dictionaryWithObjectsAndKeys:event, @"event", mergedProperties, @"properties", nil]);

    if (_reading || _writing || !self.presenting) {
        if (!_eventBuffer)
            _eventBuffer = [NSMutableArray new];
        [_eventBuffer addObject:eventDictionary];
    } else {
        [_eventQueue addObject:eventDictionary];
        [self save];
    }
}

#pragma mark - Persistence

- (void)save {
#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000) || (defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1070)
    if ([NSFileCoordinator class]) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:self];
            [coordinator coordinateWritingItemAtURL:_cacheURL options:0 error:nil byAccessor:^(NSURL *newURL) {
                NSDictionary *state = [NSDictionary dictionaryWithObjectsAndKeys:_distinctId, MPDistinctIdKey, _eventQueue, MPEventQueueKey, nil];
                [state writeToURL:newURL atomically:YES];
            }];
            [coordinator release];
        });
    } else {
        NSDictionary *state = [NSDictionary dictionaryWithObjectsAndKeys:_distinctId, MPDistinctIdKey, _eventQueue, MPEventQueueKey, nil];
        [state writeToURL:_cacheURL atomically:YES];
    }
#else
    NSDictionary *state = [NSDictionary dictionaryWithObjectsAndKeys:_distinctId, MPDistinctIdKey, _eventQueue, MPEventQueueKey, nil];
    [state writeToURL:_cacheURL atomically:YES];
#endif
}

#pragma mark - Flushing

#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000) || (defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1070)

- (void)flushOtherClients {
    if (![NSFileCoordinator class])
        return;

    NSURL *cacheDirectory = [_cacheURL URLByDeletingLastPathComponent];
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:cacheDirectory includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:^BOOL(NSURL *url, NSError *error) {
        return YES;
    }];

    if (!_blockedURLs)
        _blockedURLs = [NSMutableSet new];

    for (NSURL *cacheURL in enumerator) {
        if ([cacheURL isEqual:_cacheURL])
            continue;
        if (![cacheURL.lastPathComponent hasPrefix:@"Mixpanel"])
            continue;
        if (![[cacheURL.lastPathComponent stringByDeletingPathExtension] hasSuffix:_token])
            continue;

        if (![_blockedURLs containsObject:cacheURL]) {
            [_blockedURLs addObject:cacheURL];
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] init];
                [_blockedURLs addObject:cacheURL];
                [coordinator coordinateReadingItemAtURL:cacheURL options:0 writingItemAtURL:cacheURL options:0 error:nil byAccessor:^(NSURL *newReadingURL, NSURL *newWritingURL) {
                    NSMutableDictionary *state = [NSMutableDictionary dictionaryWithContentsOfURL:newReadingURL];
                    if (!state)
                        return;

                    NSMutableArray *events = ([NSMutableArray arrayWithArray:[state objectForKey:MPEventQueueKey]] ?: [NSMutableArray array]);
                    NSUInteger length = MIN(events.count, 100);
                    if (!length)
                        return;

                    NSArray *batch = [events subarrayWithRange:NSMakeRange(0, length)];
                    NSURLRequest *request = MPURLRequestForEvents(events);
                    if (!request)
                        return;

                    NSError *error = nil;
                    NSHTTPURLResponse *response = nil;
                    [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];

                    NSIndexSet *acceptableCodes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 100)];
                    if (!error && [acceptableCodes containsIndex:response.statusCode])
                        [events removeObjectsInArray:batch];
                    else
                        return;

                    [state setObject:events forKey:MPEventQueueKey];
                    [state writeToURL:newWritingURL atomically:YES];
                }];
                [coordinator release];
                dispatch_sync(dispatch_get_main_queue(), ^{
                    [_blockedURLs removeObject:cacheURL];
                });
            });
        }
    }
}

#endif

- (void)flush {
#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000) || (defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1070)
    [self flushOtherClients];
#endif

    if (_connection || _reading || _writing || !self.presenting)
        return;

    NSUInteger length = MIN(_eventQueue.count, 50);
    if (!length)
        return;

    _batch = [[_eventQueue subarrayWithRange:NSMakeRange(0, length)] copy];
    NSURLRequest *request = MPURLRequestForEvents(_batch);
    if (!request) {
        [_batch release];
        _batch = nil;
        return;
    }

    _connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    [_connection start];

    [self retain];
}

- (void)finishFlush {
    BOOL success;
    NSIndexSet *acceptableCodes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 100)];
    if (_error || ![acceptableCodes containsIndex:_response.statusCode]) {
        NSLog(@"%@: Network failure %@", self, _error);
        success = NO;
    } else {
        NSInteger result = [[[[NSString alloc] initWithData:_data encoding:NSUTF8StringEncoding] autorelease] integerValue];
        if (!result)
            NSLog(@"%@: API rejected some items", self);
        [_eventQueue removeObjectsInArray:_batch];
        [self save];
        success = YES;
    }

    [_error release];
    [_data release];
    [_response release];
    [_connection release];
    [_batch release];
    _error = nil;
    _data = nil;
    _response = nil;
    _connection = nil;
    _batch = nil;

#ifdef NS_BLOCKS_AVAILABLE
    if (_completionHandler) {
        _completionHandler();
        Block_release(_completionHandler);
        _completionHandler = nil;
    }
#endif

#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000) || (defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1070)
    if (_reader) {
        _reading = YES;
        _reader(^{
            _reading = NO;
            [self startPresenting];
        });
        Block_release(_reader);
        _reader = nil;
    }

    if (_writer) {
        _writing = YES;
        _writer(^{
            _writing = NO;
            [self startPresenting];
        });
        Block_release(_writer);
        _writer = nil;
    }
#endif

    [self autorelease];

    if (_eventQueue.count > 0 && success)
        [self flush];
}

#ifdef NS_BLOCKS_AVAILABLE

- (void)flush:(void(^)())completionHandler {
    [self flush];

    if (completionHandler) {
        if (_connection) {
            _completionHandler = Block_copy(completionHandler);
        } else {
            completionHandler();
        }
    }
}

#endif

#pragma mark - NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [_error release];
    _error = [error retain];
    [self finishFlush];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSHTTPURLResponse *)response {
    [_response release];
    _response = [response retain];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    // This code is only okay because valid Mixpanel responses are one byte long
    [_data release];
    _data = [data retain];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [self finishFlush];
}

#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000) || (defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1070)

#pragma mark - NSFilePresenter

- (void)relinquishPresentedItemToReader:(void (^)(void (^reacquirer)(void)))reader {
    if (_connection) {
        _reader = Block_copy(reader);
    } else {
        _reading = YES;
        reader(^{
            _reading = NO;
            [self startPresenting];
        });
    }
}

- (void)relinquishPresentedItemToWriter:(void (^)(void (^)(void)))writer {
    if (_connection) {
        _writer = Block_copy(writer);
    } else {
        _writing = YES;
        writer(^{
            _writing = NO;
            [self startPresenting];
        });
    }
}

- (void)savePresentedItemChangesWithCompletionHandler:(void (^)(NSError *errorOrNil))completionHandler {
    [self save];
    completionHandler(nil);
}

#endif

@end
