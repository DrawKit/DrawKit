//
//  DKUnarchivingHelper.m
//  GCDrawKit
//
//  Created by graham on 5/05/09.
//  Copyright 2009 Apptree.net. All rights reserved.
//

#import "DKUnarchivingHelper.h"
#import "LogEvent.h"


NSString*	kDKUnarchiverProgressStartedNotification	= @"kDKUnarchiverProgressStartedNotification";
NSString*	kDKUnarchiverProgressContinuedNotification	= @"kDKUnarchiverProgressContinuedNotification";
NSString*	kDKUnarchiverProgressFinishedNotification	= @"kDKUnarchiverProgressFinishedNotification";


@implementation DKUnarchivingHelper

- (void)		reset
{
	mCount = 0;
}

- (NSUInteger)	numberOfObjectsDecoded
{
	return mCount;
}

- (id)			unarchiver:(NSKeyedUnarchiver*) unarchiver didDecodeObject:(id) object
{
#pragma unused(unarchiver)
	
	// this method tracks the number of objects decoded and also sends notifications about the dearchiving progress, allowing a dearchiving
	// to drive a progress bar, etc. The notification is delivered on the main thread in case this is being invoked by a thread.

	NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:mCount], @"count", object, @"decoded_object", nil];
	NSNotification* note;
	
	if( mCount == 0 )
		note = [NSNotification notificationWithName:kDKUnarchiverProgressStartedNotification object:self userInfo:userInfo];
	else
		note = [NSNotification notificationWithName:kDKUnarchiverProgressContinuedNotification object:self userInfo:userInfo];
	
	[[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:note waitUntilDone:[NSThread isMainThread]];

	++mCount;
	
	return object;
}

- (void)		unarchiverDidFinish:(NSKeyedUnarchiver*) unarchiver
{
#pragma unused(unarchiver)

	NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:mCount], @"count", nil];
	NSNotification* note = [NSNotification notificationWithName:kDKUnarchiverProgressFinishedNotification object:self userInfo:userInfo];
	[[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:note waitUntilDone:[NSThread isMainThread]];
}


- (Class)	unarchiver:(NSKeyedUnarchiver*) unarchiver cannotDecodeObjectOfClassName:(NSString*) name originalClasses:(NSArray*) classNames
{
#pragma unused(unarchiver)
#pragma unused(classNames)
	
	// check the first two letters - if it's 'GC' try substituting this with 'DK' and see if that works - many classnames were changed
	// in this way
	
	NSString*	newclass;
	NSString*	ss = [name substringWithRange:NSMakeRange( 0, 2 )];
	
	if ([ss isEqualToString:@"GC"])
		newclass = [NSString stringWithFormat:@"DK%@", [name substringWithRange:NSMakeRange( 2, [name length] - 2)]];
	else
		newclass = name;
	
	// other class name changes - just check and substitute them individually
	
	if ([newclass isEqualToString:@"DKDrawingLayer"])
		newclass = @"DKLayer";
	else if ([newclass isEqualToString:@"DKDrawingStyle"])
		newclass = @"DKStyle";
	else if ([newclass isEqualToString:@"DKGridDrawingLayer"])
		newclass = @"DKGridLayer";
	else if ([newclass isEqualToString:@"DKRenderer"])
		newclass = @"DKRasterizer";
	else if ([newclass isEqualToString:@"DKDrawableShapeWithReshape"])
		newclass = @"DKReshapableShape";
	else if ([newclass isEqualToString:@"DKRendererGroup"])
		newclass = @"DKRastGroup";
	else if ([newclass isEqualToString:@"DKEffectRenderGroup"])
		newclass = @"DKCIFilterRastGroup";
	else if ([newclass isEqualToString:@"DKBlendRenderGroup"])
		newclass = @"DKQuartzBlendRastGroup";
	else if ([newclass isEqualToString:@"DKImageRenderer"])
		newclass = @"DKImageAdornment";
	else if ([newclass isEqualToString:@"DKTextLabelRenderer"])
		newclass = @"DKTextAdornment";
	else if ([newclass isEqualToString:@"DKObjectDrawingToolLayer"])	// obsolete class - just convert to plain drawing layer
		newclass = @"DKObjectDrawingLayer";
	else if ([newclass isEqualToString:@"DKLineDash"])					
		newclass = @"DKStrokeDash";
	
	Class		theClass = NSClassFromString(newclass);
	NSUInteger	indx = 1;
	
	while( theClass == Nil && indx < [classNames count])
	{
		// backtrack up the hierarchy until a known class is encountered. This makes the helper return the closest ancestor that
		// can be supported. It's quite a useful backward/forward compatibility behaviour because it allows new subclasses to gracefully degrade
		// to their ancestor class. However be prepared for objects returned in this manner to throw 'does not respond' errors if the expected
		// class is hardcoded anywhere.
		
		NSString* classname = [classNames objectAtIndex:indx++];
		
		// substitute DKNullObject for NSObject. Because NSOBject does not respond to -initWithCoder:, returning it will throw
		// an exception aborting dearchiving. The DKNullObject does nothing except provide a dummy initWithCoder method.
		
		if([classname isEqualToString:@"NSObject"])
		{
			classname = @"DKNullObject";
			[mLastClassnameSubstituted release];
			mLastClassnameSubstituted = [name retain];
		}
		
		theClass = NSClassFromString(classname);
	}
	
	if( theClass )
		LogEvent_(kInfoEvent, @"substituting class '%@' for '%@'", NSStringFromClass( theClass ), name );
	else
		LogEvent_(kInfoEvent, @"unable to substitute for '%@' - will fail", name );
	
	return theClass;
}


- (NSString*)	lastClassnameSubstituted
{
	return mLastClassnameSubstituted;
}


- (void)		dealloc
{
	[mLastClassnameSubstituted release];
	[super dealloc];
}


@end


#pragma mark -

@implementation DKNullObject

- (void)		setSubstitutionClassname:(NSString*) classname
{
	[classname retain];
	[mSubstitutedForClassname release];
	mSubstitutedForClassname = classname;
}


- (NSString*)	substitutionClassname
{
	return mSubstitutedForClassname;
}


- (id)			initWithCoder:(NSCoder*) coder
{
	// make a note of the class name that this was substituted for. This may aid in debugging.
	
	if([[(NSKeyedUnarchiver*)coder delegate] respondsToSelector:@selector(lastClassnameSubstituted)])
		[self setSubstitutionClassname:[(DKUnarchivingHelper*)[(NSKeyedUnarchiver*)coder delegate] lastClassnameSubstituted]];
	
	LogEvent_( kFileEvent, @"substituted null object for missing class: %@", self );
	
	return self;
}

- (void)		encodeWithCoder:(NSCoder*) coder
{
#pragma unused(coder)
}


- (void)		dealloc
{
	[mSubstitutedForClassname release];
	[super dealloc];
}


- (NSString*)	description
{
	return [NSString stringWithFormat:@"%@ (substituted for missing class %@)", [super description], [self substitutionClassname]];
}


@end
