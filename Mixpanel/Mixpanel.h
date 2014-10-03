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
    NSURL *_baseURL;
    NSMutableArray *_eventQueue;
    NSArray *_batch;
    NSURLConnection *_connection;
    NSHTTPURLResponse *_response;
    NSError *_error;
    NSData *_data;
    NSTimer *_timer;
}

@property (nonatomic, readonly, copy) NSString *token;
@property (nonatomic, readonly, copy) NSString *distinctId;
@property (nonatomic, copy) NSDictionary *defaultProperties;

+ (instancetype)sharedInstanceWithToken:(NSString *)token cacheDirectory:(NSURL *)cacheDirectory;
+ (instancetype)sharedInstance;

- (instancetype)initWithToken:(NSString *)token cacheDirectory:(NSURL *)cacheDirectory;

- (void)identify:(NSString *)distinctId;

- (void)track:(NSString *)event;
- (void)track:(NSString *)event properties:(NSDictionary *)properties;

- (void)flush;

@end
