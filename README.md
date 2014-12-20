# Mixpanel (Simplified) ![](https://circleci.com/gh/conradev/mixpanel-simple.svg?style=shield&circle-token=812e14aed49b65e299f6f7a318ed4873b289019d)

This is a version of Mixpanel's [iOS SDK](https://github.com/mixpanel/mixpanel-iphone.git) that:

- Supports both 32 and 64 bit OS X
- Only works on iOS 5 and OS X 10.7 and above
- Depends on and integrates with file coordination
- Is persistent by default
- Only tracks events
- Does not use `UIApplication`
- Does not use blocks when can be avoided
- Does not use ARC

## File Coordination

Each client uses a cache file unique to its main bundle identifier and Mixpanel token by default. Upon initialization the tracker is added as a file presenter.

In order for clients in other processes to access and modify the cache file, you need to call `-[MPTracker stopPresenting]` before the current process is backgrounded (and before the runloop is suspended). When the process returns to the foreground, it should start presenting with `-[MPTracker startPresenting]`. Here are some common scenarios:

| Context | Suspension |
|---------|------------|
| `UIApplication` | Stop presenting on `UIApplicationWillResignActiveNotification` and start presenting upon receiving `UIApplicationDidBecomeActiveNotification`. |
| `NSExtensionContext` | Each instance of your principal class should have its own client. That way, when the extension request is finished, the client will be deallocated. <br/><br/> **Note**: If the extension request is active and the host app enters the background, the cache file will be locked until the request is completed, the host app returns to the foreground, or the host app is killed. The client graciously handles locked cache files by separating them based on bundle identifier. |
