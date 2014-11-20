//
//  MPFlushOperation.h
//  mixpanel-simple
//
//  Created by Conrad Kramer on 11/19/14.
//  Copyright (c) 2014 DeskConnect. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MPFlushOperation : NSOperation {
    @private
    NSURL *_cacheURL;
    NSFileCoordinator *_coordinator;
}

@property (nonatomic, readonly, retain) NSURL *cacheURL;

- (instancetype)initWithCacheURL:(NSURL *)cacheURL NS_DESIGNATED_INITIALIZER;

@end
