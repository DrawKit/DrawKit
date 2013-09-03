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


#import "LogEvent.h"
#import <Foundation/NSDebug.h>

#pragma mark Constants (Not Localized)
       NSString*const kWheneverEvent		= @"LogWhenever";

       NSString*const kUserEvent			= @"LogUserEvents";
       NSString*const kScriptEvent			= @"LogScriptingEvents";
       NSString*const kReactiveEvent		= @"LogReactiveEvents";
       NSString*const kUIEvent				= @"LogInterfaceEvents";
       NSString*const kFileEvent			= @"LogFileInteractionEvents";
       NSString*const kLifeEvent			= @"LogObjectLifetimeEvents";
       NSString*const kStateEvent			= @"LogObjectChangeEvents";
       NSString*const kInfoEvent			= @"LogInfoEvents";
	   NSString* const kKVOEvent			= @"LogInfoKVOEvents";
		NSString* const kUndoEvent			= @"LogInfoUndoEvents";

static const unsigned kNumStandardEventTypes = 10;
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
	if (!sHaveLoggingEventPrefsBeenInitialized)
	{
		// Register default preferences with the standard NSUserDefaults.
		LoggingController* sharedLoggingController = [LoggingController sharedLoggingController];
		
		assert(sharedLoggingController != nil);
		NSArray* eventTypeNames = [sharedLoggingController eventTypeNames];
		
		assert(eventTypeNames != nil);
		unsigned count = [eventTypeNames count];
		NSMutableDictionary* defaultPrefs = [NSMutableDictionary dictionaryWithCapacity:count];
		NSNumber* defaultLoggingState = [NSNumber numberWithBool:NO];
		
		NSEnumerator* typeNameEnumerator = [eventTypeNames objectEnumerator];
		assert(typeNameEnumerator != nil);
		NSString* typeName;
		while ((typeName = [typeNameEnumerator nextObject]) != nil)
		{
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

#ifndef NDEBUG
BOOL IsValidEventType(NSString* eventType)
{
	BOOL isValidType = NO;
	
	if ([eventType isEqualToString:kWheneverEvent])
	{
		isValidType = YES;
	}else
	{
		LoggingController* sharedLoggingController = [LoggingController sharedLoggingController];
		
		assert(sharedLoggingController != nil);
		NSArray* eventTypeNames = [sharedLoggingController eventTypeNames];
		
		assert(eventTypeNames != nil);
		NSEnumerator* typeNameEnumerator = [eventTypeNames objectEnumerator];
		
		assert(typeNameEnumerator != nil);
		NSString* typeName;
		while ((typeName = [typeNameEnumerator nextObject]) != nil)
		{
			assert(eventType != nil);
			assert(typeName != nil);
			if ([eventType isEqualToString:typeName])
			{
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
	assert(IsValidEventType(eventType));
	assert(format != nil);
	
	BOOL didLog = NO;
	
	NSUserDefaults* userPrefs = [NSUserDefaults standardUserDefaults];
	
	assert(userPrefs != nil);
	if ( [userPrefs boolForKey:eventType] || ([eventType isEqualToString:kWheneverEvent] && IsAnyEventTypeBeingLogged()) )
	{
		// If no message has been logged yet...
		if (!sHaveLoggingEventPrefsBeenInitialized)
		{
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
	
	LoggingController* sharedLoggingController = [LoggingController sharedLoggingController];
	
	assert(sharedLoggingController != nil);
	NSArray* eventTypeNames = [sharedLoggingController eventTypeNames];
	
	assert(eventTypeNames != nil);
	NSEnumerator* typeNameEnumerator = [eventTypeNames objectEnumerator];
	NSUserDefaults* userPrefs = [NSUserDefaults standardUserDefaults];
	
	assert(typeNameEnumerator != nil);
	NSString* typeName;
	while ((typeName = [typeNameEnumerator nextObject]) != nil)
	{
		assert(userPrefs != nil);
		assert(typeName != nil);
		if ([userPrefs boolForKey:typeName])
		{
			isTypeBeingLogged = YES;
			break;
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
	
	assert(localInfoDict != nil);
	NSString* appName = [localInfoDict objectForKey:@"CFBundleName"];
	if (appName == nil)
	{
		appName = [localInfoDict objectForKey:@"CFBundleExecutable"];
		if (appName == nil)
		{
			assert(infoDictionary != nil);
			appName = [infoDictionary objectForKey:@"CFBundleName"];
			if (appName == nil)
			{
				appName = [infoDictionary objectForKey:@"CFBundleExecutable"];
				if (appName == nil)
				{
					appName = @"<Unknown>";
				}
			}
		}
	}
	assert(appName != nil);
	
	NSString* versionString = [localInfoDict objectForKey:@"CFBundleVersion"];
	if (versionString == nil)
	{
		assert(infoDictionary != nil);
		versionString = [infoDictionary objectForKey:@"CFBundleVersion"];
		if (versionString == nil)
		{
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
	NSEnumerator* typeNameEnumerator = [eventTypeNames objectEnumerator];
	
	assert(typeNameEnumerator != nil);
	NSString* typeName;
	while ((typeName = [typeNameEnumerator nextObject]) != nil)
	{
		assert(typeName != nil);
		assert(userPrefs != nil);
		LogEvent(kWheneverEvent, @"%@ is turned %@.", typeName, ([userPrefs boolForKey:typeName]) ? @"on" : @"off");
	}
}


#pragma mark -
@implementation LoggingController
#pragma mark As a LoggingController
- (void)loadNib
{
	// If the nib hasn't been loaded yet...
	if (!mIsNibLoaded)
	{
		NSString* nibName = [self windowNibName];
		
		NSAssert(nibName != nil, @"Expected valid nibName");
		if (![NSBundle loadNibNamed:nibName owner:self])
		{
			NSLog(@"***Failed to load %@.nib", nibName);
			NSBeep();
		}else
		{
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
	if (eventTypes != mEventTypes)
	{
		[mEventTypes release];
		mEventTypes = [eventTypes retain];
	}
	InitializePrefsForEventTypeNames();
}

- (NSDictionary*)eventTypes
{
	if (mEventTypes == nil)
	{
		[self loadNib];
		
		NSDictionary* eventTypes = [[self newEventTypes] autorelease];
		
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
		if (sSharedLoggingController == nil)
		{
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
	if (![window isVisible])
	{
		NSUserDefaults* userPrefs = [NSUserDefaults standardUserDefaults];
		NSDictionary* eventTypes = [self eventTypes];
		
		NSAssert(eventTypes != nil, @"Expected valid eventTypes");
		NSEnumerator* keyEnumerator = [eventTypes keyEnumerator];
		
		NSAssert(keyEnumerator != nil, @"Expected valid keyEnumerator");
		NSString* eventKey;
		while ((eventKey = [keyEnumerator nextObject]) != nil)
		{
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
	NSMutableDictionary* eventTypes = [[[NSMutableDictionary alloc] initWithCapacity:kNumStandardEventTypes] autorelease];
	
	NSAssert(eventTypes != nil, @"Expected valid eventTypes");
	unsigned i = 0;
	for ( ; i < kNumStandardEventTypes; ++i)
	{
		NSString* eventKey = nil;
		NSButton* eventButton = nil;
		switch (i)
		{
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
				NSAssert1(NO, @"Encountered invalid switch case (%u)", i);
			break;
		}
		NSAssert(eventKey != nil, @"Expected valid eventKey");
		NSAssert(eventButton != nil, @"Expected valid eventButton");
		
		[eventTypes setObject:eventButton forKey:eventKey];
	}
	// Method name begins with "new"; clients are responsible for releasing.
	return [[NSDictionary alloc] initWithDictionary:eventTypes];
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
#pragma unused (sender)
	NSUserDefaults* userPrefs = [NSUserDefaults standardUserDefaults];
	NSAssert(userPrefs != nil, @"Expected valid userPrefs");
	
	NSDictionary* eventTypes = [self eventTypes];
	
	NSAssert(eventTypes != nil, @"Expected valid eventTypes");
	NSEnumerator* keyEnumerator = [eventTypes keyEnumerator];
	
	NSAssert(keyEnumerator != nil, @"Expected valid keyEnumerator");
	NSString* eventKey;
	while ((eventKey = [keyEnumerator nextObject]) != nil)
	{
		NSAssert(eventKey != nil, @"Expected valid eventKey");
		NSButton* eventButton = [eventTypes objectForKey:eventKey];
		
		NSAssert(eventButton != nil, @"Expected valid eventButton");
		int buttonState = [eventButton state];
		
		if (buttonState == NSOnState)
		{
			[userPrefs setBool:YES forKey:eventKey];
			LogEvent(eventKey, @"%@ has been turned on", eventKey);
		}else
		{
			LogEvent(eventKey, @"%@ has been turned off", eventKey);
			[userPrefs setBool:NO forKey:eventKey];
			[userPrefs removeObjectForKey:eventKey];
		}
	}
	// Because logging is typically turned on while debugging a problem, we make an immediate note of the changes to the prefs under the assum ption the app can crash at any time.
	[userPrefs synchronize];
}


- (IBAction)	setZombiesAction:(id) sender
{
#pragma unused(sender)
	
	NSAlert* relaunchAlert = [NSAlert alertWithMessageText:@"Relaunch Ortelius?"
											 defaultButton:@"Launch With Zombies"
										   alternateButton:@"Cancel"
											   otherButton:nil
								 informativeTextWithFormat:@"Click to relaunch Ortelius with Zombies ON. Launching again from the Finder will disable zombies."];
	
	NSInteger result = [relaunchAlert runModal];
	
	if( result == NSAlertDefaultReturn )
	{
		FSRef fileRef;
		NSDictionary *environment = [NSDictionary dictionaryWithObject: @"YES" forKey: @"NSZombieEnabled"];
		NSString* execPath = [[NSBundle mainBundle] executablePath];
		
		const char* executablePath = [execPath UTF8String];
		
		FSPathMakeRef((UInt8*) executablePath, &fileRef, nil);
		LSApplicationParameters appParameters = {0, kLSLaunchDefaults | kLSLaunchNewInstance, &fileRef, nil, (CFDictionaryRef)environment, nil, nil};
		
		LSOpenApplication(&appParameters, nil);
		
		[NSApp terminate: nil];
	}
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
		if (sSharedLoggingController == nil)
		{
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
#pragma unused (zone)
	return self; // Singleton's do not actually copy.
}

- (void)dealloc
{
	[mEventTypes release];
	
	[super dealloc];
	sSharedLoggingController = nil;
}

- (id)retain
{
	return self; // Singleton's do not modify their retain count.
}

- (unsigned)retainCount
{
	return UINT_MAX; // Denotes an object, such as a singleton, that cannot be released.
}

- (void)release
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
