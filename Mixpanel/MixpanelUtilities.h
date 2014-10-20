//
//  MixpanelFunctions.h
//
//  Created by Conrad Kramer on 10/2/14.
//  Copyright (c) 2014 DeskConnect. All rights reserved.
//

#import <Foundation/Foundation.h>

extern id MPJSONSerializableObject(id object);

extern NSDictionary *MPDeviceProperties();

extern NSURLRequest *MPURLRequestForEvents(NSArray *events);

@interface MPUnsafeObject : NSObject {
    id _object;
}

+ (instancetype)unsafeObjectWithObject:(id)object;

- (instancetype)initWithObject:(id)object;

@end