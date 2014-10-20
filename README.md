# Mixpanel (Simplified)

This is a version of Mixpanel's [iOS SDK](https://github.com/mixpanel/mixpanel-iphone.git) that:

- Supports both 32 and 64 bit OS X
- Allows you to configure where to cache events
- Allows any client using the same cache directory to upload events for the others (using file coordination)
- Is persistent by default (you don't lose events if the app terminates unexpectedly)
- Only tracks events
- Does not use `UIApplication`
- Does not require blocks
- Does not use ARC
