// =======================================================================================
// File:       LogEvent.h
// Created:    2007/Sep/25
// Modified:   See SVN LastChangedDate information at the bottom of the file.
//
// Copyright:  (c)2007-2008 Intriguing Development, Inc. <http://www.idevelop.net>
//             All rights reserved.
//
//             Redistribution and use in source and binary forms, with or without
//             modification, are permitted provided that the following conditions are met:
//               * Redistributions of source code must retain the above copyright notice,
//                 this list of conditions and the following disclaimer.
//               * Redistributions in binary form must reproduce the above copyright
//                 notice, this list of conditions and the following disclaimer in the
//                 documentation and/or other materials provided with the distribution.
//               * Neither the name of Intriguing Development, Inc. nor the names of its
//                 contributors may be used to endorse or promote products derived from
//                 this software without specific prior written permission.
//
//             THIS SOFTWARE IS PROVIDED BY Intriguing Development, Inc. "AS IS" AND ANY
//             EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
//             WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//             DISCLAIMED. IN NO EVENT SHALL Intriguing Development, Inc. BE LIABLE FOR
//             ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//             DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
//             SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
//             CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
//             LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY 
//             OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
//             SUCH DAMAGE.
// =======================================================================================
//
//    The LogEvent files contain functions (most notably LogEvent()) useful for
// *conditionally* logging various types of events or steps with in a process. The intent
// is for an application to allow an end user to enable (or "turn on") various types of
// logging (or permanent debugging). The logging of messages for any given type is
// prevented unless its type has been turned on (i.e., a user pref has been set).
//    For you to use the LogEvent functionality, qUseLogEvent must be defined (typically
// in a precompiled header). If you want event logging to drop out of one of your
// configurations (or you do not agree to the licensing terms), don't define qUseLogEvent.
// (For more about dropping event logging out of one of your configurations, see the
// Macros section below.)
// 
//    The LoggingController class encapsulates an NSWindowController for modifying the
// user selectable logging options. It follows the singleton design pattern and therefore
// follows Apple's guidelines for a singleton (cf. "Creating a Singleton Instance" chapter
// in the Cocoa Fundamentals Guide).
// 
//    Although frameworks may use LogEvent() and the various event types defined below,
// they generally do not actually make use of the LoggingController class (and its nib
// file). The LoggingController class is a UI level object that simplifies turning logging
// on or off. Adding it to your application is easy.
//    In our projects, we typically have access to the Logging dialog "hidden" in the
// -showAboutBox: IBAction. In other words, to enable or disable logging, a user simply
// holds down a modifier key while choosing About Application. It looks something like
// this:

/*- (IBAction)showAboutBox:(id)sender
{
	BOOL isOptionKeyDown = (([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) != 0);
	if (isOptionKeyDown)
	{
		[[LoggingController sharedLoggingController] showLoggingWindow];
	}else
	{
		[[AboutBox sharedAboutBox] showAboutBox:sender];
	}
}*/


#pragma mark Macro (when qUseLogEvent undefined)
#ifndef qUseLogEvent

	#define LogEvent_(...)

#else /* defined(qUseLogEvent) */


#import <AppKit/AppKit.h>


#pragma mark -
#pragma mark Constants (Not Localized)
	// Standard event types for conditional logging
extern NSString*const kWheneverEvent; // I.e., Whenever we are logging anything
	// Useful for logging an event that is always of interest when debugging, but not of interest when not debugging. For example, a caught exception or other failure of some kind.
	// You will still use NSLog() to *always* log an event, regardless of whether you are debugging or not.

extern NSString*const kUserEvent;     // E.g., IBActions and other user input
extern NSString*const kScriptEvent;   // E.g., Any reaction to an AppleScript event
extern NSString*const kReactiveEvent; // E.g., Significant reactions, such as a critical method call
extern NSString*const kUIEvent;       // E.g., Displaying a dialog or changing a tab of a NSTabView
extern NSString*const kFileEvent;     // E.g., Any intermediate steps taken during file saving or reading.
extern NSString*const kLifeEvent;     // I.e., Object lifetime (allocation, initialization or deallocation)
extern NSString*const kStateEvent;    // E.g., Significant changes to object state
extern NSString*const kInfoEvent;     // E.g., Informational logging such as an object's current state. Use sparingly.

// new event types added by Graham Cox 

extern NSString* const kKVOEvent;		// pertains to KVO adding or removing observers, which events lead to a very verbose log if enabled, therefore separate.
extern NSString* const kUndoEvent;		// pertains to undo operations

//    Remember, you are not required to use all of the event types. They are intended
// solely to make it easier to reduce the noise level in any given set of logged output.


#pragma mark Macros (when qUseLogEvent defined)
//    When qUseLogEvent is defined, you can use all of the LogEvent features. However,
// when it is not defined, only the LogEvent_ macro remains available, but it is defined
// to do nothing. This macro makes it easy to drop event logging out of one of your
// configurations. It simply converts to a LogEvent() call when qUseLogEvent is defined,
// or does nothing when it is not.

#define LogEvent_ LogEvent


#pragma mark -
#pragma mark Free Functions
#ifdef __cplusplus
extern "C" {
#endif

	BOOL LogEvent(NSString* eventType, NSString* format, ...);
	// Returns YES when the message was actually logged out; NO otherwise. Useful for attempting to log for more than one type, but not kWheneverEvent.

	BOOL IsAnyEventTypeBeingLogged(void);
	void LogAppNameAndVersion(void);
	void LogLoggingState(NSArray* eventTypeNames); // Which also logs app name & version

#ifdef __cplusplus
}
#endif


#pragma mark -
@interface LoggingController : NSWindowController
{
@private
	NSDictionary*		mEventTypes;
	BOOL				mIsNibLoaded;
	
	IBOutlet NSButton*	mUserActions;
	IBOutlet NSButton*	mScriptingActions;
	IBOutlet NSButton*	mReactiveEvents;
	IBOutlet NSButton*	mInterfaceEvents;
	IBOutlet NSButton*	mFileInteraction;
	IBOutlet NSButton*	mObjectLifetime;
	IBOutlet NSButton*	mObjectChanges;
	IBOutlet NSButton*	mMiscInfo;
	IBOutlet NSButton*	mKVOInfo;
	IBOutlet NSButton*	mUndoInfo;
	
	IBOutlet NSButton*	mZombiesCheckbox;
}

+ (LoggingController*)sharedLoggingController;

- (void)showLoggingWindow;

- (NSDictionary*)newEventTypes; // Override if you wish to add more eventTypes; but message super.
- (NSArray*)eventTypeNames; // An array of the event type names (NSStrings).

- (IBAction)logStateChanged:(id)sender;
	// All logging IBOutlets (NSButtons) have this as their action.

- (NSString*)windowNibName; // Override to use a nib name other than "Logging".

- (IBAction)	setZombiesAction:(id) sender;

@end

#endif /* defined(qUseLogEvent) */


/* $HeadURL: http://graham@jasonjobe.com/drawkit/DrawKit/Trunk/Source/ThirdParty/LogEvent/LogEvent.h $
** $LastChangedRevision: 1039 $
** $LastChangedDate: 2008-04-22 10:28:13 +1000 (Tue, 22 Apr 2008) $
** $LastChangedBy: graham $
*/
