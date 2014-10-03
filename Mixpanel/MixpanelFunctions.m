//
//  MixpanelFunctions.m
//
//  Created by Conrad Kramer on 10/2/14.
//  Copyright (c) 2014 DeskConnect. All rights reserved.
//

#import <Foundation/Foundation.h>

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
#import <UIKit/UIKit.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#elif defined(__MAC_OS_X_VERSION_MIN_REQUIRED)
#import <AppKit/AppKit.h>
#endif

#include <sys/sysctl.h>

id MPJSONSerializableObject(id object) {
    static NSDateFormatter *dateFormatter = nil;
    if (!dateFormatter) {
        dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
        [dateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
        [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
    }

    NSArray *types = [NSArray arrayWithObjects:[NSString class], [NSNumber class], [NSNull class], nil];
    for (Class typeClass in types)
        if ([object isKindOfClass:typeClass])
            return object;

    if ([object isKindOfClass:[NSArray class]] || [object isKindOfClass:[NSSet class]]) {
        NSMutableArray *array = [NSMutableArray array];
        for (id member in object)
            [array addObject:MPJSONSerializableObject(member)];
        return [NSArray arrayWithArray:array];
    }

    if ([object isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
        for (id key in object) {
            key = ([key isKindOfClass:[NSString class]] ? key : [key description]);
            id value = MPJSONSerializableObject([object valueForKey:key]);
            [dictionary setObject:value forKey:key];
        }
        return [NSDictionary dictionaryWithDictionary:dictionary];
    }

    if ([object isKindOfClass:[NSDate class]]) {
        return [dateFormatter stringFromDate:object];
    } else if ([object isKindOfClass:[NSURL class]]) {
        return [object absoluteString];
    }

    return [object description];
}

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)

NSDictionary *MPDeviceProperties() {
    static NSDictionary *deviceProperties = nil;
    
    if (!deviceProperties) {
        size_t length;
        sysctlbyname("hw.machine", NULL, &length, NULL, 0);
        char *buffer = malloc(length);
        sysctlbyname("hw.machine", buffer, &length, NULL, 0);
        NSString *model = [[[NSString alloc] initWithBytesNoCopy:buffer length:(length - 1) encoding:NSUTF8StringEncoding freeWhenDone:YES] autorelease];

        UIDevice *device = [UIDevice currentDevice];

        CTTelephonyNetworkInfo *networkInfo = [[CTTelephonyNetworkInfo alloc] init];
        NSString *carrier = [[networkInfo subscriberCellularProvider] carrierName];
        [networkInfo release];

        CGSize size = [[UIScreen mainScreen] bounds].size;
        NSNumber *width = [NSNumber numberWithInteger:(NSInteger)MIN(size.width, size.height)];
        NSNumber *height = [NSNumber numberWithInteger:(NSInteger)MAX(size.width, size.height)];

        NSMutableDictionary *properties = [NSMutableDictionary dictionary];
        [properties setValue:@"Apple" forKey:@"$manufacturer"];
        [properties setValue:carrier forKey:@"$carrier"];
        [properties setValue:model forKey:@"$model"];
        [properties setValue:[device systemName] forKey:@"$os"];
        [properties setValue:[device systemVersion] forKey:@"$os_version"];
        [properties setValue:width forKey:@"$screen_width"];
        [properties setValue:height forKey:@"$screen_height"];

        deviceProperties = [properties copy];
    }
    
    return deviceProperties;
}

#elif defined(__MAC_OS_X_VERSION_MIN_REQUIRED)

NSDictionary *MPDeviceProperties() {
    static NSDictionary *deviceProperties = nil;

    if (!deviceProperties) {
        size_t length;
        sysctlbyname("hw.model", NULL, &length, NULL, 0);
        char *buffer = malloc(length);
        sysctlbyname("hw.model", buffer, &length, NULL, 0);
        NSString *model = [[[NSString alloc] initWithBytesNoCopy:buffer length:(length - 1) encoding:NSUTF8StringEncoding freeWhenDone:YES] autorelease];

        SInt32 major, minor, bugfix;
        Gestalt(gestaltSystemVersionMajor, &major);
        Gestalt(gestaltSystemVersionMinor, &minor);
        Gestalt(gestaltSystemVersionBugFix, &bugfix);
        NSString *version = [NSString stringWithFormat:@"%d.%d", (int)major, (int)minor];
        if (bugfix)
            version = [version stringByAppendingString:[NSString stringWithFormat:@".%d", (int)bugfix]];

        NSSize size = [[NSScreen mainScreen] frame].size;
        NSNumber *width = [NSNumber numberWithInteger:(NSInteger)size.width];
        NSNumber *height = [NSNumber numberWithInteger:(NSInteger)size.height];

        NSMutableDictionary *properties = [NSMutableDictionary dictionary];
        [properties setValue:@"Apple" forKey:@"$manufacturer"];
        [properties setValue:model forKey:@"$model"];
        [properties setValue:@"Mac OS" forKey:@"$os"];
        [properties setValue:version forKey:@"$os_version"];
        [properties setValue:width forKey:@"$screen_width"];
        [properties setValue:height forKey:@"$screen_height"];

        deviceProperties = [properties copy];
    }
    
    return deviceProperties;
}

#else

NSDictionary *MPDeviceProperties() {
    return nil;
}

#endif
