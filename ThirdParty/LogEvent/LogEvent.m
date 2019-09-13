// =======================================================================================
// File:       LogEvent.m
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

#ifdef qUseLogEvent

#if __has_feature(objc_arc)
#error This file CAN NOT be built using ARC: the usage of singletons prevent this.
#endif

#import "LogEvent.h"
#import <Foundation/NSDebug.h>
#import <AppKit/AppKit.h>

#pragma mark Constants (Not Localized)
NSString* const kWheneverEvent = @"LogWhenever";

NSString* const kUserEvent = @"LogUserEvents";
NSString* const kScriptEvent = @"LogScriptingEvents";
NSString* const kReactiveEvent = @"LogReactiveEvents";
NSString* const kUIEvent = @"LogInterfaceEvents";
NSString* const kFileEvent = @"LogFileInteractionEvents";
NSString* const kLifeEvent = @"LogObjectLifetimeEvents";
NSString* const kStateEvent = @"LogObjectChangeEvents";
NSString* const kInfoEvent = @"LogInfoEvents";
NSString* const kKVOEvent = @"LogInfoKVOEvents";
NSString* const kUndoEvent = @"LogInfoUndoEvents";

static const NSUInteger kNumStandardEventTypes = 10;
// When adding new event types, don't forget to modify or override the -newEventTypes method.

#pragma mark Static Variables
static LoggingController* sSharedLoggingController = nil;

static BOOL sHaveLoggingEventPrefsBeenInitialized = NO;

#pragma mark Private Function Declarations
void InitializePrefsForEventTypeNames(void);
BOOL IsValidEventType(NSString* eventType);

#pragma mark -
#pragma mark Functions
void InitializePrefsForEventTypeNames(void)
{
	// macOS 10.14+ will crash if you try to initiate a Window controller on a background thread
	if ([NSThread isMainThread] && !sHaveLoggingEventPrefsBeenInitialized) {
		// Register default preferences with the standard NSUserDefaults.
		LoggingController* sharedLoggingController = [LoggingController sharedLoggingController];

		assert(sharedLoggingController != nil);
		NSArray* eventTypeNames = [sharedLoggingController eventTypeNames];

		assert(eventTypeNames != nil);
		NSUInteger count = [eventTypeNames count];
		NSMutableDictionary* defaultPrefs = [NSMutableDictionary dictionaryWithCapacity:count];
		NSNumber* defaultLoggingState = @NO;
		for (NSString* typeName in eventTypeNames) {
			assert(defaultPrefs != nil);
			assert(defaultLoggingState != nil);
			assert(typeName != nil);
			[defaultPrefs setObject:defaultLoggingState forKey:typeName];
		}

		NSUserDefaults* userPrefs = [NSUserDefaults standardUserDefaults];

		assert(userPrefs != nil);
		assert(defaultPrefs != nil);
		[userPrefs registerDefaults:defaultPrefs];
		sHaveLoggingEventPrefsBeenInitialized = YES;

		LogLoggingState(eventTypeNames);
	}
}

#ifdef NDEBUG
BOOL IsValidEventType(NSString* eventType)
{
	BOOL isValidType = NO;

	if ([eventType isEqualToString:kWheneverEvent]) {
		isValidType = YES;
	} else if( [NSThread isMainThread] ) {
		LoggingController* sharedLoggingController = [LoggingController sharedLoggingController];

		assert(sharedLoggingController != nil);
		NSArray* eventTypeNames = [sharedLoggingController eventTypeNames];

		assert(eventTypeNames != nil);

		for (NSString* typeName in eventTypeNames) {
			assert(eventType != nil);
			assert(typeName != nil);
			if ([eventType isEqualToString:typeName]) {
				isValidType = YES;
				break;
			}
		}
	}

	return isValidType;
}
#endif

#pragma mark -
BOOL LogEvent(NSString* eventType, NSString* format, ...)
{
	assert(eventType != nil);
	assert(format != nil);

	BOOL didLog = NO;

	NSUserDefaults* userPrefs = [NSUserDefaults standardUserDefaults];

	assert(userPrefs != nil);
	if ([NSThread isMainThread] && IsValidEventType(eventType) && [userPrefs boolForKey:eventType] || ([eventType isEqualToString:kWheneverEvent] && IsAnyEventTypeBeingLogged())) {
		// If no message has been logged yet...
		if (!sHaveLoggingEventPrefsBeenInitialized) {
			// Forces prefs initialization, which forces logging the log state.
			LoggingController* sharedLoggingController = [LoggingController sharedLoggingController];

			assert(sharedLoggingController != nil);
			[sharedLoggingController eventTypeNames]; // We can safely ignore the returned value.
		}

		va_list argsP;
		va_start(argsP, format);

		NSLogv(format, argsP);
		didLog = YES;

		va_end(argsP);
	}
	return didLog;
}

#pragma mark -
BOOL IsAnyEventTypeBeingLogged(void)
{
	BOOL isTypeBeingLogged = NO;

	// macOS 10.14+ will crash if you try to initiate a Window controller on a background thread
	if ([NSThread isMainThread]) {
		LoggingController* sharedLoggingController = [LoggingController sharedLoggingController];

		assert(sharedLoggingController != nil);
		NSArray* eventTypeNames = [sharedLoggingController eventTypeNames];

		assert(eventTypeNames != nil);
		NSUserDefaults* userPrefs = [NSUserDefaults standardUserDefaults];

		for (NSString* typeName in eventTypeNames) {
			assert(userPrefs != nil);
			assert(typeName != nil);
			if ([userPrefs boolForKey:typeName]) {
				isTypeBeingLogged = YES;
				break;
			}
		}
	}
	return isTypeBeingLogged;
}

void LogAppNameAndVersion(void)
{
	NSBundle* mainBundle = [NSBundle mainBundle];

	assert(mainBundle != nil);
	NSDictionary* localInfoDict = [mainBundle localizedInfoDictionary];
	NSDictionary* infoDictionary = [mainBundle infoDictionary];

	NSString* appName = [localInfoDict objectForKey:@"CFBundleName"];
	if (appName == nil) {
		appName = [localInfoDict objectForKey:@"CFBundleExecutable"];
		if (appName == nil) {
			assert(infoDictionary != nil);
			appName = [infoDictionary objectForKey:@"CFBundleName"];
			if (appName == nil) {
				appName = [infoDictionary objectForKey:@"CFBundleExecutable"];
				if (appName == nil) {
					appName = @"<Unknown>";
				}
			}
		}
	}
	assert(appName != nil);

	NSString* versionString = [localInfoDict objectForKey:@"CFBundleVersion"];
	if (versionString == nil) {
		assert(infoDictionary != nil);
		versionString = [infoDictionary objectForKey:@"CFBundleVersion"];
		if (versionString == nil) {
			versionString = @"<unknown>";
		}
	}
	assert(versionString != nil);

	LogEvent(kWheneverEvent, @"Logging state for %@ application, version %@, is:", appName, versionString);
}

void LogLoggingState(NSArray* eventTypeNames)
{
	// First, log the app name and version
	LogAppNameAndVersion();

	// Second, log the current state of logging.
	NSUserDefaults* userPrefs = [NSUserDefaults standardUserDefaults];

	assert(eventTypeNames != nil);
	for (NSString* typeName in eventTypeNames) {
		assert(typeName != nil);
		assert(userPrefs != nil);
		LogEvent(kWheneverEvent, @"%@ is turned %@.", typeName, ([userPrefs boolForKey:typeName]) ? @"on" : @"off");
	}
}

#pragma mark -
@implementation LoggingController {
	NSArray* nibs;
}
#pragma mark As a LoggingController
@synthesize userActions = mUserActions;
@synthesize scriptingActions = mScriptingActions;
@synthesize reactiveEvents = mReactiveEvents;
@synthesize interfaceEvents = mInterfaceEvents;
@synthesize fileInteraction = mFileInteraction;
@synthesize objectLifetime = mObjectLifetime;
@synthesize objectChanges = mObjectChanges;
@synthesize miscInfo = mMiscInfo;
@synthesize KVOInfo = mKVOInfo;
@synthesize undoInfo = mUndoInfo;
@synthesize zombiesCheckbox = mZombiesCheckbox;

- (void)loadNib
{
	// If the nib hasn't been loaded yet...
	if (!mIsNibLoaded) {
		NSString* nibName = [self windowNibName];
		NSArray* tmpArr = nil;

		NSAssert(nibName != nil, @"Expected valid nibName");
		if (![[NSBundle bundleForClass:[self class]] loadNibNamed:nibName owner:self topLevelObjects:&tmpArr]) {
			NSLog(@"***Failed to load %@.nib", nibName);
			NSBeep();
		} else {
			nibs = [tmpArr retain];
			// Setup the window
			NSWindow* window = [self window];

			NSAssert(window != nil, @"Expected valid window");
			[window setExcludedFromWindowsMenu:YES];
			[window setMenu:nil];
			[window center];
			mIsNibLoaded = YES;
		}
	}
}

#pragma mark -
- (void)setEventTypes:(NSDictionary*)eventTypes
{
	if (eventTypes != mEventTypes) {
		[mEventTypes release];
		mEventTypes = [eventTypes copy];
	}
	InitializePrefsForEventTypeNames();
}

- (NSDictionary*)eventTypes
{
	if (mEventTypes == nil) {
		[self loadNib];

		NSDictionary* eventTypes = [self newEventTypes];

		NSAssert(eventTypes != nil, @"Expected valid eventTypes");
		[self setEventTypes:eventTypes];
	}
	NSAssert(mEventTypes != nil, @"Expected valid mEventTypes");

	return [[mEventTypes retain] autorelease];
}

#pragma mark -
+ (LoggingController*)sharedLoggingController
{
	@synchronized(self)
	{
		if (sSharedLoggingController == nil) {
			sSharedLoggingController = [[self alloc] init]; // Assignment done in allocWithZone:
		}
	}
	NSAssert(sSharedLoggingController != nil, @"Expected valid sSharedLoggingController");

	return sSharedLoggingController;
}

#pragma mark -
- (void)showLoggingWindow
{
	[self loadNib];

	NSWindow* window = [self window];

	NSAssert(window != nil, @"Expected valid window");
	if (![window isVisible]) {
		NSUserDefaults* userPrefs = [NSUserDefaults standardUserDefaults];
		NSDictionary* eventTypes = [self eventTypes];

		NSAssert(eventTypes != nil, @"Expected valid eventTypes");
		for (NSString* eventKey in eventTypes) {
			NSAssert(eventKey != nil, @"Expected valid eventKey");
			NSButton* eventButton = [eventTypes objectForKey:eventKey];

			NSAssert(userPrefs != nil, @"Expected valid userPrefs");
			BOOL prefState = [userPrefs boolForKey:eventKey];

			NSAssert(eventButton != nil, @"Expected valid eventButton");
			[eventButton setState:(prefState) ? NSOnState : NSOffState];
		}
	}

	// Show the window
	[window makeKeyAndOrderFront:nil];
}

#pragma mark -
- (NSDictionary*)newEventTypes
{
	NSMutableDictionary* eventTypes = [[NSMutableDictionary alloc] initWithCapacity:kNumStandardEventTypes];

	NSAssert(eventTypes != nil, @"Expected valid eventTypes");
	for (NSUInteger i = 0; i < kNumStandardEventTypes; ++i) {
		NSString* eventKey = nil;
		NSButton* eventButton = nil;
		switch (i) {
		case 0:
			eventKey = kUserEvent;
			eventButton = mUserActions;
			NSAssert(eventKey != nil, @"Expected valid eventKey");
			NSAssert(eventButton != nil, @"Expected valid eventButton");
			NSAssert([eventButton action] == @selector(logStateChanged:), @"Expected every logging IBOutlet to have logStateChanged: as its action");
			break;
		case 1:
			eventKey = kScriptEvent;
			eventButton = mScriptingActions;
			NSAssert(eventKey != nil, @"Expected valid eventKey");
			NSAssert(eventButton != nil, @"Expected valid eventButton");
			NSAssert([eventButton action] == @selector(logStateChanged:), @"Expected every logging IBOutlet to have logStateChanged: as its action");
			break;
		case 2:
			eventKey = kReactiveEvent;
			eventButton = mReactiveEvents;
			NSAssert(eventKey != nil, @"Expected valid eventKey");
			NSAssert(eventButton != nil, @"Expected valid eventButton");
			NSAssert([eventButton action] == @selector(logStateChanged:), @"Expected every logging IBOutlet to have logStateChanged: as its action");
			break;
		case 3:
			eventKey = kUIEvent;
			eventButton = mInterfaceEvents;
			NSAssert(eventKey != nil, @"Expected valid eventKey");
			NSAssert(eventButton != nil, @"Expected valid eventButton");
			NSAssert([eventButton action] == @selector(logStateChanged:), @"Expected every logging IBOutlet to have logStateChanged: as its action");
			break;
		case 4:
			eventKey = kFileEvent;
			eventButton = mFileInteraction;
			NSAssert(eventKey != nil, @"Expected valid eventKey");
			NSAssert(eventButton != nil, @"Expected valid eventButton");
			NSAssert([eventButton action] == @selector(logStateChanged:), @"Expected every logging IBOutlet to have logStateChanged: as its action");
			break;
		case 5:
			eventKey = kLifeEvent;
			eventButton = mObjectLifetime;
			NSAssert(eventKey != nil, @"Expected valid eventKey");
			NSAssert(eventButton != nil, @"Expected valid eventButton");
			NSAssert([eventButton action] == @selector(logStateChanged:), @"Expected every logging IBOutlet to have logStateChanged: as its action");
			break;
		case 6:
			eventKey = kStateEvent;
			eventButton = mObjectChanges;
			NSAssert(eventKey != nil, @"Expected valid eventKey");
			NSAssert(eventButton != nil, @"Expected valid eventButton");
			NSAssert([eventButton action] == @selector(logStateChanged:), @"Expected every logging IBOutlet to have logStateChanged: as its action");
			break;
		case 7:
			eventKey = kInfoEvent;
			eventButton = mMiscInfo;
			NSAssert(eventKey != nil, @"Expected valid eventKey");
			NSAssert(eventButton != nil, @"Expected valid eventButton");
			NSAssert([eventButton action] == @selector(logStateChanged:), @"Expected every logging IBOutlet to have logStateChanged: as its action");
			break;
		case 8:
			eventKey = kKVOEvent;
			eventButton = mKVOInfo;
			NSAssert(eventKey != nil, @"Expected valid eventKey");
			NSAssert(eventButton != nil, @"Expected valid eventButton");
			NSAssert([eventButton action] == @selector(logStateChanged:), @"Expected every logging IBOutlet to have logStateChanged: as its action");
			break;
		case 9:
			eventKey = kUndoEvent;
			eventButton = mUndoInfo;
			NSAssert(eventKey != nil, @"Expected valid eventKey");
			NSAssert(eventButton != nil, @"Expected valid eventButton");
			NSAssert([eventButton action] == @selector(logStateChanged:), @"Expected every logging IBOutlet to have logStateChanged: as its action");
			break;
		default:
			NSAssert(NO, @"Encountered invalid switch case (%lu)", (unsigned long)i);
			break;
		}
		NSAssert(eventKey != nil, @"Expected valid eventKey");
		NSAssert(eventButton != nil, @"Expected valid eventButton");

		[eventTypes setObject:eventButton forKey:eventKey];
	}

	return [NSDictionary dictionaryWithDictionary:[eventTypes autorelease]];
}

- (NSArray*)eventTypeNames
{
	NSDictionary* eventTypes = [self eventTypes];

	NSAssert(eventTypes != nil, @"Expected valid eventTypes");
	NSArray* typeNames = [eventTypes allKeys];

	NSAssert(typeNames != nil, @"Expected valid typeNames");
	return [typeNames sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}

#pragma mark -
- (IBAction)logStateChanged:(id)sender
{
#pragma unused(sender)
	NSUserDefaults* userPrefs = [NSUserDefaults standardUserDefaults];
	NSAssert(userPrefs != nil, @"Expected valid userPrefs");

	NSDictionary* eventTypes = [self eventTypes];

	NSAssert(eventTypes != nil, @"Expected valid eventTypes");
	for (NSString* eventKey in eventTypes) {
		NSAssert(eventKey != nil, @"Expected valid eventKey");
		NSButton* eventButton = [eventTypes objectForKey:eventKey];

		NSAssert(eventButton != nil, @"Expected valid eventButton");
		NSControlStateValue buttonState = [eventButton state];

		if (buttonState == NSOnState) {
			[userPrefs setBool:YES forKey:eventKey];
			LogEvent(eventKey, @"%@ has been turned on", eventKey);
		} else {
			LogEvent(eventKey, @"%@ has been turned off", eventKey);
			[userPrefs setBool:NO forKey:eventKey];
			[userPrefs removeObjectForKey:eventKey];
		}
	}
	// Because logging is typically turned on while debugging a problem, we make an immediate note of the changes to the prefs under the assum ption the app can crash at any time.
	[userPrefs synchronize];
}

- (IBAction)setZombiesAction:(id)sender
{
#pragma unused(sender)

	NSAlert* relaunchAlert = [[NSAlert alloc] init];
	relaunchAlert.messageText = @"Relaunch Ortelius?";
	relaunchAlert.informativeText = @"Click to relaunch Ortelius with Zombies ON. Launching again from the Finder will disable zombies.";
	[relaunchAlert addButtonWithTitle:@"Launch With Zombies"];
	[relaunchAlert addButtonWithTitle:@"Cancel"];

	NSInteger result = [relaunchAlert runModal];

	if (result == NSAlertFirstButtonReturn) {
		NSDictionary* environment = @{ @"NSZombieEnabled" : @"YES" };

		[[NSWorkspace sharedWorkspace] launchApplicationAtURL:[[NSBundle mainBundle] bundleURL] options:(NSWorkspaceLaunchDefault | NSWorkspaceLaunchNewInstance) configuration:@{ NSWorkspaceLaunchConfigurationArguments : environment } error:NULL];

		// Don't worry about releasing relaunchAlert: the kernel will clean up when we exit.
		[NSApp terminate:nil];
	}
	[relaunchAlert release];
}

#pragma mark -
#pragma mark As an NSWindowController
- (NSString*)windowNibName
{
	return @"Logging";
}

#pragma mark -
#pragma mark As an NSObject
+ (id)allocWithZone:(NSZone*)zone
{
	@synchronized(self)
	{
		if (sSharedLoggingController == nil) {
			// Assignment & return on first allocation.
			sSharedLoggingController = [super allocWithZone:zone];
			return sSharedLoggingController;
		}
	}
	return nil; // On subsequent allocation attempts, a singleton returns nil.
}

- (id)autorelease
{
	return self; // Singleton's cannot be autoreleased.
}

- (id)copyWithZone:(NSZone*)zone
{
#pragma unused(zone)
	return self; // Singleton's do not actually copy.
}

- (void)dealloc
{
	[mEventTypes release];
	[nibs release];

	[super dealloc];
	sSharedLoggingController = nil;
}

- (id)retain
{
	return self; // Singleton's do not modify their retain count.
}

- (NSUInteger)retainCount
{
	return NSUIntegerMax; // Denotes an object, such as a singleton, that cannot be released.
}

- (oneway void)release
{
	// Singleton's do nothing.
}

@end
#endif /* defined(qUseLogEvent) */

/* $HeadURL: http://graham@jasonjobe.com/drawkit/DrawKit/Trunk/Source/ThirdParty/LogEvent/LogEvent.m $
** $LastChangedRevision: 1039 $
** $LastChangedDate: 2008-04-22 10:28:13 +1000 (Tue, 22 Apr 2008) $
** $LastChangedBy: graham $
*/
