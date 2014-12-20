//
//  MPTracker.m
//  mixpanel-simple
//
//  Created by Conrad Kramer on 11/16/14.
//  Copyright (c) 2014 DeskConnect. All rights reserved.
//

#import <Foundation/Foundation.h>
#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
#import <UIKit/UIKit.h>
#endif
#import "MPTracker.h"
#import "MPUtilities.h"
#import "MPFlushOperation.h"

NSString * const MPDistinctIdKey = @"MPDistinctId";
NSString * const MPEventQueueKey = @"MPEventQueue";

@interface MPTracker () <NSFilePresenter>

@end

@implementation MPTracker

@synthesize token=_token;
@synthesize distinctId=_distinctId;
@synthesize defaultProperties=_defaultProperties;
@synthesize operationQueue=_eventOperationQueue;
@synthesize presentedItemURL=_presentedItemURL;
@synthesize presentedItemOperationQueue=_presentedItemOperationQueue;

- (instancetype)init {
    return [self initWithToken:nil cacheURL:nil];
}

- (instancetype)initWithToken:(NSString *)token cacheURL:(NSURL *)cacheURL {
    NSParameterAssert(token);
    NSParameterAssert(cacheURL);
    self = [super init];
    if (self) {
        BOOL directory = NO;
        NSURL *cacheDirectory = [cacheURL URLByDeletingLastPathComponent];
        if (![[NSFileManager defaultManager] fileExistsAtPath:cacheDirectory.path isDirectory:&directory] || !directory) {
            NSLog(@"%@: Invalid cache path provided", self);
            [self release];
            return nil;
        }

        _token = [token copy];
        _eventQueue = [NSArray new];
        _eventOperationQueue = [NSOperationQueue new];
        _eventOperationQueue.maxConcurrentOperationCount = 1;
        _eventOperationQueue.suspended = YES;
        _flushOperationQueue = [NSOperationQueue new];
        _presentedItemURL = [cacheURL copy];
        _presentedItemOperationQueue = [NSOperationQueue new];
        _presentedItemOperationQueue.maxConcurrentOperationCount = 1;

        [self startPresenting];
    }
    return self;
}

- (void)dealloc {
    [NSFileCoordinator removeFilePresenter:self];
    [_token release];
    [_distinctId release];
    [_defaultProperties release];
    [_eventQueue release];
    [_eventOperationQueue release];
    [_flushOperationQueue release];
    [_presentedItemURL release];
    [_presentedItemOperationQueue release];
    [_lastModificationDate release];
    [_lastFileSize release];
    [super dealloc];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p, token: %@>", NSStringFromClass([self class]), self, _token];
}

- (NSURL *)cacheURL {
    return _presentedItemURL;
}

- (NSString *)distinctId {
    if (!_distinctId) {
#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
        UIDevice *device = [UIDevice currentDevice];
        _distinctId = ([device respondsToSelector:@selector(identifierForVendor)] ? [[device.identifierForVendor UUIDString] copy] : nil);
#pragma clang diagnostic pop
#elif defined(__MAC_OS_X_VERSION_MIN_REQUIRED)
        io_registry_entry_t ioRegistryRoot = IORegistryEntryFromPath(kIOMasterPortDefault, "IOService:/");
        _distinctId = (NSString *)IORegistryEntryCreateCFProperty(ioRegistryRoot, CFSTR(kIOPlatformUUIDKey), kCFAllocatorDefault, 0);
        IOObjectRelease(ioRegistryRoot);
#endif
    }
    return _distinctId;
}

- (void)track:(NSString *)event {
    [self track:event properties:nil];
}

- (void)track:(NSString *)event properties:(NSDictionary *)properties {
    NSParameterAssert(event);

    NSNumber *timestamp = [NSNumber numberWithInteger:(NSInteger)round([[NSDate date] timeIntervalSince1970])];

    NSMutableDictionary *mergedProperties = [NSMutableDictionary dictionaryWithDictionary:MPAutomaticProperties()];
    [mergedProperties addEntriesFromDictionary:properties];
    [mergedProperties setValue:timestamp forKey:@"time"];

    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:@selector(enqueueEvent:withProperties:)]];
    [invocation setTarget:self];
    [invocation setSelector:@selector(enqueueEvent:withProperties:)];
    [invocation setArgument:&event atIndex:2];
    [invocation setArgument:&mergedProperties atIndex:3];
    [invocation retainArguments];

    NSInvocationOperation *saveOperation = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(save:) object:invocation];
    [_eventOperationQueue addOperation:saveOperation];
    [saveOperation release];
}

- (void)createAlias:(NSString *)alias forDistinctID:(NSString *)distinctID {
    if (!alias.length)
        NSLog(@"%@: Create alias called with invalid alias", self);
    if (!distinctID.length)
        NSLog(@"%@: Create alias called with invalid distinct ID", self);
    if (!alias.length || !distinctID.length)
        return;
    [self track:@"$create_alias" properties:@{@"distinct_id": distinctID, @"alias": alias}];
}

- (void)identify:(NSString *)distinctId {
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:@selector(changeDistinctId:)]];
    [invocation setTarget:self];
    [invocation setSelector:@selector(changeDistinctId:)];
    [invocation setArgument:&distinctId atIndex:2];
    [invocation retainArguments];

    NSInvocationOperation *saveOperation = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(save:) object:invocation];
    [_eventOperationQueue addOperation:saveOperation];
    [saveOperation release];
}

#pragma mark - Presenting;

- (void)startPresenting {
    NSInvocationOperation *addPresenterOperation = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(addAsPresenter) object:nil];
    [_presentedItemOperationQueue addOperation:addPresenterOperation];
    [addPresenterOperation release];
}

- (void)addAsPresenter {
    if ([[NSFileCoordinator filePresenters] containsObject:self])
        return;

    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[NSFileCoordinator methodSignatureForSelector:@selector(addFilePresenter:)]];
    [invocation setTarget:[NSFileCoordinator class]];
    [invocation setSelector:@selector(addFilePresenter:)];
    [invocation setArgument:&self atIndex:2];
    [invocation retainArguments];

    [self load:invocation];
    _eventOperationQueue.suspended = NO;
}

- (void)stopPresenting {
    NSInvocationOperation *removePresenterOperation = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(removeAsPresenter) object:nil];
    [_eventOperationQueue addOperation:removePresenterOperation];
    [removePresenterOperation release];
}

- (void)removeAsPresenter {
    _eventOperationQueue.suspended = YES;
    [NSFileCoordinator removeFilePresenter:self];
}

#pragma mark - Flushing

- (void)flush:(void(^)())completion {
    MPFlushOperation *flushOperation = [[MPFlushOperation alloc] initWithCacheURL:_presentedItemURL];
    flushOperation.completionBlock = completion;
    [_flushOperationQueue addOperation:flushOperation];
    [flushOperation release];
}

#pragma mark - NSFilePresenter

- (void)relinquishPresentedItemToReader:(void (^)(void (^reacquirer)(void)))reader {
    [_eventOperationQueue addOperationWithBlock:^{
        _eventOperationQueue.suspended = YES;
        reader(^{
            _eventOperationQueue.suspended = NO;
        });
    }];
}

- (void)relinquishPresentedItemToWriter:(void (^)(void (^reacquirer)(void)))writer {
    [_eventOperationQueue addOperationWithBlock:^{
        _eventOperationQueue.suspended = YES;
        writer(^{
            _eventOperationQueue.suspended = NO;
        });
    }];
}

- (void)savePresentedItemChangesWithCompletionHandler:(void (^)(NSError *errorOrNil))completionHandler {
    [self save:nil];
    completionHandler(nil);
}

- (void)presentedItemDidMoveToURL:(NSURL *)newURL {
    [_presentedItemURL release];
    _presentedItemURL = [newURL copy];
}

- (void)presentedItemDidChange {
    [self load:nil];
}

#pragma mark - Modification

- (void)changeDistinctId:(NSString *)distinctId {
    [_distinctId release];
    _distinctId = [distinctId copy];
}

- (void)enqueueEvent:(NSString *)event withProperties:(NSDictionary *)properties {
    NSMutableDictionary *mergedProperties = [NSMutableDictionary dictionaryWithDictionary:properties];
    [mergedProperties addEntriesFromDictionary:_defaultProperties];
    [mergedProperties setValue:_token forKey:@"token"];
    [mergedProperties setValue:self.distinctId forKey:@"distinct_id"];

    NSDictionary *eventDictionary = MPJSONSerializableObject([NSDictionary dictionaryWithObjectsAndKeys:event, @"event", mergedProperties, @"properties", nil]);
    NSArray *eventQueue = [_eventQueue arrayByAddingObject:eventDictionary];
    [_eventQueue release];
    _eventQueue = [eventQueue retain];
}

#pragma mark - Persistence

- (void)load:(NSInvocation *)invocation {
    NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:self];
    [coordinator coordinateReadingItemAtURL:_presentedItemURL options:NSFileCoordinatorReadingWithoutChanges error:nil byAccessor:^(NSURL *newURL) {
        [self loadStateFromURL:newURL];
        [invocation invoke];
    }];
    [coordinator release];
}

- (void)save:(NSInvocation *)invocation {
    NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:self];
    [coordinator coordinateWritingItemAtURL:_presentedItemURL options:0 error:nil byAccessor:^(NSURL *newURL) {
        [self loadStateFromURL:newURL];
        [invocation invoke];
        [self writeStateToURL:newURL];
    }];
    [coordinator release];
}

- (void)loadStateFromURL:(NSURL *)url {
    if ([self modificationDateHasChangedFromURL:url]) {
        NSDictionary *state = [NSDictionary dictionaryWithContentsOfURL:url];
        [_distinctId release];
        [_eventQueue release];
        _distinctId = [[state objectForKey:MPDistinctIdKey] copy];
        _eventQueue = ([[state objectForKey:MPEventQueueKey] copy] ?: [NSArray new]);
    }
    [self updateModificationDateFromURL:url];
}

- (void)writeStateToURL:(NSURL *)url {
    NSDictionary *state = [NSDictionary dictionaryWithObjectsAndKeys:_eventQueue, MPEventQueueKey, self.distinctId, MPDistinctIdKey, nil];
    [state writeToURL:url atomically:YES];
    [self updateModificationDateFromURL:url];
}

- (BOOL)modificationDateHasChangedFromURL:(NSURL *)url {
    [url removeCachedResourceValueForKey:NSURLContentModificationDateKey];
    NSDate *lastModificationDate = nil;
    BOOL dateChanged = (![url getResourceValue:&lastModificationDate forKey:NSURLContentModificationDateKey error:nil] || ![_lastModificationDate isEqual:lastModificationDate]);

    [url removeCachedResourceValueForKey:NSURLFileSizeKey];
    NSNumber *lastFileSize = nil;
    BOOL sizeChanged = (![url getResourceValue:&lastFileSize forKey:NSURLFileSizeKey error:nil] || ![_lastFileSize isEqual:lastFileSize]);

    return (dateChanged || sizeChanged);
}

- (void)updateModificationDateFromURL:(NSURL *)url {
    NSDate *lastModificationDate = nil;
    [url removeCachedResourceValueForKey:NSURLContentModificationDateKey];
    [_lastModificationDate release];
    _lastModificationDate = ([url getResourceValue:&lastModificationDate forKey:NSURLContentModificationDateKey error:nil] ? [lastModificationDate copy] : nil);

    NSDate *lastFileSize = nil;
    [url removeCachedResourceValueForKey:NSURLFileSizeKey];
    [_lastFileSize release];
    _lastFileSize = ([url getResourceValue:&lastFileSize forKey:NSURLFileSizeKey error:nil] ? [lastFileSize copy] : nil);
}

@end
