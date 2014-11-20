//
//  Mixpanel.h
//  mixpanel-simple
//
//  Created by Conrad Kramer on 10/2/14.
//  Copyright (c) 2014 DeskConnect. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MPTracker, MPFlusher;

@interface Mixpanel : NSObject {
    @private
    MPTracker *_tracker;
    MPFlusher *_flusher;
}

@property (nonatomic, readonly, retain) MPTracker *tracker;
@property (nonatomic, readonly, retain) MPFlusher *flusher;

- (instancetype)initWithToken:(NSString *)token cacheDirectory:(NSURL *)cacheDirectory NS_DESIGNATED_INITIALIZER;

@end
