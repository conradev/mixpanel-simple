//
//  MPTracker.h
//  mixpanel-simple
//
//  Created by Conrad Kramer on 11/16/14.
//  Copyright (c) 2014 DeskConnect. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MPTracker : NSObject {
    @private
    NSString *_token;
    NSString *_distinctId;
    NSDictionary *_defaultProperties;
    NSArray *_eventQueue;
    NSOperationQueue *_eventOperationQueue;
    NSURL *_presentedItemURL;
    NSOperationQueue *_presentedItemOperationQueue;
    NSDate *_lastModificationDate;
    NSNumber *_lastFileSize;
}

@property (nonatomic, readonly, retain) NSString *token;
@property (nonatomic, readonly, retain) NSString *distinctId;
@property (nonatomic, readonly, retain) NSURL *cacheURL;
@property (nonatomic, readonly, retain) NSOperationQueue *operationQueue;
@property (nonatomic, copy) NSDictionary *defaultProperties;

- (instancetype)initWithToken:(NSString *)token cacheURL:(NSURL *)cacheURL NS_DESIGNATED_INITIALIZER;

- (void)track:(NSString *)event;
- (void)track:(NSString *)event properties:(NSDictionary *)properties;

- (void)createAlias:(NSString *)alias forDistinctID:(NSString *)distinctID;
- (void)identify:(NSString *)distinctId;

- (void)startPresenting;
- (void)stopPresenting;

- (void)flush:(void(^)())completion;

@end
