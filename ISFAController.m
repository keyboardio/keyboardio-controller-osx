/*
     File: ISFAController.m 
 Abstract: Implements the main menu's controller.
 Opens a chat room in iChat when users click the "Joins Chat Room" button. 
 Watches for application switch events and updates iChat status using the Scripting Bridge framework. 
  Version: 1.2 
  
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple 
 Inc. ("Apple") in consideration of your agreement to the following 
 terms, and your use, installation, modification or redistribution of 
 this Apple software constitutes acceptance of these terms.  If you do 
 not agree with these terms, please do not use, install, modify or 
 redistribute this Apple software. 
  
 In consideration of your agreement to abide by the following terms, and 
 subject to these terms, Apple grants you a personal, non-exclusive 
 license, under Apple's copyrights in this original Apple software (the 
 "Apple Software"), to use, reproduce, modify and redistribute the Apple 
 Software, with or without modifications, in source and/or binary forms; 
 provided that if you redistribute the Apple Software in its entirety and 
 without modifications, you must retain this notice and the following 
 text and disclaimers in all such redistributions of the Apple Software. 
 Neither the name, trademarks, service marks or logos of Apple Inc. may 
 be used to endorse or promote products derived from the Apple Software 
 without specific prior written permission from Apple.  Except as 
 expressly stated in this notice, no other rights or licenses, express or 
 implied, are granted by Apple herein, including but not limited to any 
 patent rights that may be infringed by your derivative works or by other 
 works in which the Apple Software may be incorporated. 
  
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE 
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION 
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS 
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND 
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS. 
  
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL 
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, 
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED 
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE), 
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE 
 POSSIBILITY OF SUCH DAMAGE. 
  
 Copyright (C) 2011 Apple Inc. All Rights Reserved. 
  
 */


#import "ISFAController.h"

@interface ISFAController (PRIVATE) 
- (void)applicationSwitched;
- (void)applicationLaunched:(NSNotification *)notification;
- (void)applicationTerminated:(NSNotification *)notification;
- (void)registerForAppSwitchNotificationFor:(NSDictionary *)application;
@end

@implementation ISFAController

#pragma mark Watches for Application Switches
/*
	Updates the current status and icon of users in iChat and "iChatStatus" window.
    Sets the user's status and icon to the fronmost application's name and icon.  
*/ 
- (void)applicationSwitched
{
    /* Get information about the current active application */
	NSDictionary *applicationInfo = [[NSWorkspace sharedWorkspace] activeApplication];
	/* Get the application's process id  */
    pid_t switchedPid = (pid_t)[[applicationInfo valueForKey:@"NSApplicationProcessIdentifier"] integerValue];
	
	/* Do not do anything if we do not have new application in the front or if are in the front ourselves */
    if(switchedPid != _currentPid && switchedPid != getpid()) {
	
                /* Grab the icon of the running application as an NSImage */
                NSImage *iconImage = [[NSWorkspace sharedWorkspace] iconForFile:[applicationInfo valueForKey:@"NSApplicationPath"]];
                
                /* Set the application's icon view in the "iChatStatus" window to the icon image */
                [_appIconView setImage:iconImage];
                				
                NSString *statusString = [NSString stringWithFormat:@"%@", [applicationInfo objectForKey:@"NSApplicationName"]];

        NSString *cmd = [NSString stringWithFormat:@"echo '%@' > /dev/cu.usbmodem1421", [applicationInfo objectForKey:@"NSApplicationName"]];

        
        
        
        
        
                popen([cmd UTF8String], "r");
        

				
				/* Set the status message in the "iChatStatus" window */
                [_appLabelField setStringValue:cmd];
    
        /* Store this application's process id so we can compare it with the process id of the next frontmost application */
        _currentPid = switchedPid;
    }
}


/*
	Called when a new application was launched. Registers for its notifications when the 
    application is activated.
*/ 
- (void)applicationLaunched:(NSNotification *)notification
{
	/* A new application has launched. Make sure we get notifications when it activates. */
    [self registerForAppSwitchNotificationFor:[notification userInfo]];
    [self applicationSwitched];
}


/*
	Called when an application was terminated. Stops watching for this application switch events.
*/
- (void)applicationTerminated:(NSNotification *)notification
{
	/* Get the application's process id  */
    NSNumber *pidNumber = [[notification userInfo] valueForKey:@"NSApplicationProcessIdentifier"];
	/* Get the observer associated to this application */
    AXObserverRef observer = (AXObserverRef)[_observers objectForKey:pidNumber];
	/* Check whether this observer is valid. If observer is valid, unregister for accessibility notifications 
	   and display a descriptive message otherwise. */
    if(observer) {
        /* Stop listening to the accessibility notifications for the dead application */
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(),
                              AXObserverGetRunLoopSource(observer),
                              kCFRunLoopDefaultMode);
        [_observers removeObjectForKey:pidNumber];
    } else {
        NSLog(@"Application \"%@\" that we didn't know about quit!", [[notification userInfo] valueForKey:@"NSApplicationName"]);
    }
}


/*
	Calls the applicationSwitched method. 
*/ 
static void applicationSwitched(AXObserverRef observer, AXUIElementRef element, CFStringRef notification, void *self)
{
    [(id)self applicationSwitched];
}


/*
	Creates an accessibility observer to watch an application switch events.
*/ 
- (void)registerForAppSwitchNotificationFor:(NSDictionary *)application
{
    NSNumber *pidNumber = [application valueForKey:@"NSApplicationProcessIdentifier"];
    
    /* Don't sign up for our own switch events (that will fail). */
    if([pidNumber intValue] != getpid()) {
        /* Check whether we are not already watching for this application's switch events */
        if(![_observers objectForKey:pidNumber]) {
            pid_t pid = (pid_t)[pidNumber integerValue];
            /* Create an Accessibility observer for the application */
            AXObserverRef observer;
            if(AXObserverCreate(pid, applicationSwitched, &observer) == kAXErrorSuccess) {
                
                /* Register for the application activated notification */
                CFRunLoopAddSource(CFRunLoopGetCurrent(),
                                   AXObserverGetRunLoopSource(observer), 
                                   kCFRunLoopDefaultMode);
                AXUIElementRef element = AXUIElementCreateApplication(pid);
                if(AXObserverAddNotification(observer, element, kAXApplicationActivatedNotification, self) != kAXErrorSuccess) {
                    NSLog(@"Failed to create observer for application \"%@\".", [application valueForKey:@"NSApplicationName"]);
                } else {
                    /* Remember the observer so that we can unregister later */
                    [_observers setObject:(id)observer forKey:pidNumber];
                }
                /* The observers dictionary wil hold on to the observer for us */
                CFRelease(observer); 
                 /* We do not need the element any more */
                CFRelease(element); 
            } else {
                /* We could not create an observer to watch this application's switch events */
                NSLog(@"Failed to create observer for application \"%@\".", [application valueForKey:@"NSApplicationName"]);
            }  
        } else {
            /* We are already observing this application */
            NSLog(@"Attempted to observe application \"%@\" twice.", [application valueForKey:@"NSApplicationName"]);
        }
    }
}

#pragma mark Initialization
- (void)awakeFromNib
{
    BOOL accessibilityEnabled;
    if (AXIsProcessTrustedWithOptions != NULL) {
        // 10.9 and later
        NSDictionary *options = @{(id)kAXTrustedCheckOptionPrompt: @YES};
         accessibilityEnabled = AXIsProcessTrustedWithOptions((CFDictionaryRef)options);

    } else {
        // 10.8 and older
        accessibilityEnabled =AXAPIEnabled();
    }

    /* Check if 'Enable access for assistive devices' is enabled. */
    if(!accessibilityEnabled) {
        /* 
         'Enable access for assistive devices' is not enabled, so we will alert the user,
         then quit because we can't update the users status on app switch as we are meant to
         (because we can't get notifications of application switches).
         */
        NSRunCriticalAlertPanel(@"'Enable access for assistive devices' is not enabled.", @"iChatStatusFromApplication requires that 'Enable access for assistive devices' in the 'Universal Access' preferences panel be enabled in order to monitor application switching.", @"Quit", nil, nil);
        [NSApp terminate:self];
    }
    
    
    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    _observers = [[NSMutableDictionary alloc] init];
	    
    /* Register for application launch notifications */
    [[workspace notificationCenter] addObserver:self 
                                       selector:@selector(applicationLaunched:) 
                                           name:NSWorkspaceDidLaunchApplicationNotification 
                                         object:workspace];
	/* Register for application termination notifications */
    [[workspace notificationCenter] addObserver:self 
                                       selector:@selector(applicationTerminated:) 
                                           name:NSWorkspaceDidTerminateApplicationNotification 
                                         object:workspace];
    
    /* Register for activation notifications for all currently running applications */
    for(NSDictionary *application in [workspace launchedApplications]) {
        [self registerForAppSwitchNotificationFor:application];
    }
    
    [self applicationSwitched];
}

#pragma mark Deallocate Resources
- (void)dealloc
{
    /* Stop listening to all the notifications */
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
    for(NSNumber *pidNumber in _observers) {
        AXObserverRef observer = (AXObserverRef)[_observers objectForKey:pidNumber];
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer),kCFRunLoopDefaultMode);
    }
    
    /* This will also release the observers in the dictionary */
    [_observers release];
    
    [super dealloc];
}

@end
