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

#include <resolv.h>

#import "Mixpanel.h"
#import "MixpanelFunctions.h"
#import "PJSONKit.h"

static NSString * const MPBaseURLString = @"https://api.mixpanel.com";

static NSString * const MPDistinctIdKey = @"MPDistinctId";
static NSString * const MPEventQueueKey = @"MPEventQueue";

static Mixpanel *sharedInstance = nil;

@implementation Mixpanel

@synthesize token = _token;
@synthesize distinctId = _distinctId;
@synthesize defaultProperties = _defaultProperties;

+ (NSDictionary *)automaticProperties {
    static NSDictionary *automaticProperties = nil;
    if (!automaticProperties) {
        NSBundle *bundle = [NSBundle bundleForClass:self];
        
        NSMutableDictionary *properties = [NSMutableDictionary dictionaryWithDictionary:MPDeviceProperties()];
        [properties setValue:[bundle.infoDictionary objectForKey:(id)kCFBundleVersionKey] forKey:@"$app_version"];
        [properties setValue:[bundle.infoDictionary objectForKey:@"CFBundleShortVersionString"] forKey:@"$app_release"];
        [properties setValue:@"iphone" forKey:@"mp_lib"];
        [properties setValue:@"VERSION!" forKey:@"$lib_version"];
        
        automaticProperties = [properties copy];
    }
    
    // TODO: WiFi
    
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

        _token = [token copy];
        _cacheURL = [[[cacheDirectory URLByAppendingPathComponent:[NSString stringWithFormat:@"Mixpanel-%@", token]] URLByAppendingPathExtension:@"plist"] retain];
        _baseURL = [[NSURL URLWithString:MPBaseURLString] retain];

        NSDictionary *state = [NSDictionary dictionaryWithContentsOfURL:_cacheURL];
        _distinctId = [state objectForKey:MPDistinctIdKey];
        _eventQueue = ([[state objectForKey:MPEventQueueKey] mutableCopy] ?: [NSMutableArray new]);

        _timer = [[NSTimer scheduledTimerWithTimeInterval:15.0f target:self selector:@selector(flush) userInfo:nil repeats:YES] retain];
    }
    return self;
}

- (void)dealloc {
    [_token release];
    [_distinctId release];
    [_defaultProperties release];
    [_cacheURL release];
    [_baseURL release];
    [_eventQueue release];
    [_timer invalidate];
    [_timer release];
    [super dealloc];
}

- (NSString *)distinctId {
    if (!_distinctId) {
#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
        UIDevice *device = [UIDevice currentDevice];
        _distinctId = ([device respondsToSelector:@selector(identifierForVendor)] ? [device.identifierForVendor UUIDString] : [[device performSelector:@selector(uniqueIdentifier)] copy]);
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
    [_eventQueue addObject:eventDictionary];
    [self save];
}

#pragma mark - Persistence

- (void)save {
    NSDictionary *state = [NSDictionary dictionaryWithObjectsAndKeys:_distinctId, MPDistinctIdKey, _eventQueue, MPEventQueueKey, nil];
    [state writeToURL:_cacheURL atomically:YES];
}

#pragma mark - Flushing

- (void)flush {
    if (_connection)
        return;

    NSUInteger length = MIN(_eventQueue.count, 50);
    if (!length)
        return;

    NSError *error = nil;
    _batch = [[_eventQueue subarrayWithRange:NSMakeRange(0, length)] copy];
    NSData *data = [_batch MPJSONDataWithOptions:0 error:&error];
    if (!data) {
        [_batch release];
        _batch = nil;
        return;
    }


    NSUInteger encodedLength = ((data.length + 2) / 3) * 4 + 1;
    char *buffer = malloc(encodedLength);
    int actual = b64_ntop(data.bytes, data.length, buffer, encodedLength);
    if (!actual) {
        free(buffer);
        return;
    }

    NSString *encodedData = [[[NSString alloc] initWithBytesNoCopy:buffer length:(actual + 1) encoding:NSUTF8StringEncoding freeWhenDone:YES] autorelease];
    NSString *escapedData = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)encodedData, NULL, CFSTR("!*'();:@&=+$,/?%#[]"), kCFStringEncodingUTF8));
    NSData *body = [[NSString stringWithFormat:@"ip=1&data=%@", escapedData] dataUsingEncoding:NSUTF8StringEncoding];

    NSURL *url = [NSURL URLWithString:@"track/" relativeToURL:_baseURL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:body];

    _connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    [_connection start];
    [self retain];
}

- (void)finishFlush {
    NSIndexSet *acceptableCodes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 100)];
    if (_error || ![acceptableCodes containsIndex:_response.statusCode]) {
        NSLog(@"%@: Network failure %@", self, _error);
    } else {
        NSInteger result = [[[[NSString alloc] initWithData:_data encoding:NSUTF8StringEncoding] autorelease] integerValue];
        if (!result)
            NSLog(@"%@: API rejected some items", self);
        [_eventQueue removeObjectsInArray:_batch];
        [self save];
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

    [self release];

    if (_eventQueue.count > 0)
        [self flush];
}

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

@end
