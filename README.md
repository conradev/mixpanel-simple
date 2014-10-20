# Mixpanel (Simplified)

This is a version of Mixpanel's [iOS SDK](https://github.com/mixpanel/mixpanel-iphone.git) that:

- Supports both 32 and 64 bit OS X
- Allows configuration of the cache directory
- Allows clients using the same cache directory to upload events on behalf of the others (using file coordination)
- Is persistent by default (you don't lose events if the app terminates unexpectedly)
- Only tracks events
- Does not use `UIApplication`
- Does not require blocks
- Does not use ARC

## File Coordination

Each client uses a cache file unique to its main bundle identifier and Mixpanel token. Upon initialization a client is added as a file presenter.

In order for clients in other processes to access and modify the cache file, you need to call `-[Mixpanel stopPresenting]` before the current process is backgrounded (and before the runloop is suspended). When the process returns to the foreground, it should start presenting with `-[Mixpanel startPresenting]`. Here are some common scenarios:

| Context | Suspension |
|---------|------------|
| `UIApplication` | Stop presenting on `UIApplicationWillResignActiveNotification` and start presenting upon receiving `UIApplicationDidBecomeActiveNotification`. |
| `NSExtensionContext` | Each instance of your principal class should have its own client. That way, when the extension request is finished, the client will be deallocated. <br/><br/> **Note**: If the extension request is active and the host app enters the background, the cache file will be locked until the request is completed, the host app returns to the foreground, or the host app is killed. |

