//
//  Mixpanel.h
//
//  Created by Conrad Kramer on 10/2/14.
//  Copyright (c) 2014 DeskConnect. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Mixpanel : NSObject {
    @private
    NSString *_token;
    NSString *_distinctId;
    NSDictionary *_defaultProperties;
    NSURL *_cacheURL;
    NSMutableArray *_eventQueue;
    NSMutableArray *_eventBuffer;
    NSArray *_batch;
    NSURLConnection *_connection;
    NSHTTPURLResponse *_response;
    NSError *_error;
    NSData *_data;
    NSTimer *_timer;
    BOOL _reading;
    BOOL _writing;
    BOOL _presenting;
#ifdef NS_BLOCKS_AVAILABLE
    void (^_completionHandler)();
#endif
#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000) || (defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1070)
    NSOperationQueue *_presentedItemOperationQueue;
    NSMutableSet *_blockedURLs;
    void (^_reader)(void (^reacquirer)(void));
    void (^_writer)(void (^reacquirer)(void));
#endif
}

@property (nonatomic, readonly, copy) NSString *token;
@property (nonatomic, readonly, copy) NSString *distinctId;
@property (nonatomic, copy) NSDictionary *defaultProperties;
@property (nonatomic, readonly, getter = isPresenting) BOOL presenting;

#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000) || (defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1070)
+ (dispatch_queue_t)coordinationQueue;
#endif

+ (instancetype)sharedInstanceWithToken:(NSString *)token cacheDirectory:(NSURL *)cacheDirectory;
+ (instancetype)sharedInstance;

- (instancetype)initWithToken:(NSString *)token cacheDirectory:(NSURL *)cacheDirectory;

- (void)identify:(NSString *)distinctId;

- (void)track:(NSString *)event;
- (void)track:(NSString *)event properties:(NSDictionary *)properties;
- (void)createAlias:(NSString *)alias forDistinctID:(NSString *)distinctID;

- (void)flush;
#ifdef NS_BLOCKS_AVAILABLE
- (void)flush:(void(^)())completionHandler;
#endif

- (void)startPresenting;
- (void)stopPresenting;

@end
