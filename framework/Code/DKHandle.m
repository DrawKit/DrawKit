//
//  DKHandle.m
//  GCDrawKit
//
//  Created by graham on 4/09/09.
//  Copyright 2009 Apptree.net. All rights reserved.
//

#import "DKHandle.h"
#import "DKBoundingRectHandle.h"
#import "DKPathPointHandle.h"
#import "DKRotationHandle.h"
#import "DKTargetHandle.h"
#import "DKGeometryUtilities.h"
#import "DKQuartzCache.h"
#import "NSColor+DKAdditions.h"

@interface DKHandle (Private)

+ (NSString*)			keyForKnobType:(DKKnobType) type;

@end

#pragma mark -


@implementation DKHandle

static NSMutableDictionary*		s_handleClassTable = nil;
static NSMutableDictionary*		s_handleInstancesTable = nil;


+ (void)				initialize
{
	[self setHandleClass:[DKBoundingRectHandle class]		forType:[[DKBoundingRectHandle class] type]];
	[self setHandleClass:[DKLockedBoundingRectHandle class] forType:[[DKLockedBoundingRectHandle class] type]];
	[self setHandleClass:[DKInactiveBoundingRectHandle class] forType:[[DKInactiveBoundingRectHandle class] type]];
	[self setHandleClass:[DKOnPathPointHandle class]		forType:[[DKOnPathPointHandle class] type]];
	[self setHandleClass:[DKLockedOnPathPointHandle class]	forType:[[DKLockedOnPathPointHandle class] type]];
	[self setHandleClass:[DKInactiveOnPathPointHandle class]forType:[[DKInactiveOnPathPointHandle class] type]];
	[self setHandleClass:[DKOffPathPointHandle class]		forType:[[DKOffPathPointHandle class] type]];
	[self setHandleClass:[DKLockedOffPathPointHandle class] forType:[[DKLockedOffPathPointHandle class] type]];
	[self setHandleClass:[DKInactiveOffPathPointHandle class] forType:[[DKInactiveOffPathPointHandle class] type]];
	[self setHandleClass:[DKRotationHandle class]			forType:[[DKRotationHandle class] type]];
	[self setHandleClass:[DKLockedRotationHandle class]		forType:[[DKLockedRotationHandle class] type]];
	[self setHandleClass:[DKTargetHandle class]				forType:[[DKTargetHandle class] type]];
	[self setHandleClass:[DKLockedTargetHandle class]		forType:[[DKLockedTargetHandle class] type]];
	[self setHandleClass:[DKBoundingRectHandle class]		forType:kDKHotspotKnobType];
	[self setHandleClass:[DKLockedBoundingRectHandle class]	forType:kDKHotspotKnobType | kDKKnobIsDisabledFlag];
	[self setHandleClass:[DKInactiveBoundingRectHandle class]	forType:kDKHotspotKnobType | kDKKnobIsInactiveFlag];
}



+ (DKKnobType)			type
{
	NSLog(@"the +[DKHandle type] method must be overridden");
	
	return kDKInvalidKnobType;
}



+ (DKHandle*)			handleForType:(DKKnobType) type size:(NSSize) size colour:(NSColor*) colour
{
	NSString*	classKey = [self keyForKnobType:type];
	NSString*	key;
	
	if( colour )
		key = [NSString stringWithFormat:@"%@_%@_%dx%d", classKey, [colour hexString], (int)ceil(size.width), (int)ceil(size.height)];
	else
		key = [NSString stringWithFormat:@"%@_%dx%d", classKey, (int)ceil(size.width), (int)ceil(size.height)];

	DKHandle*	inst = nil;
	
	if( s_handleInstancesTable == nil )
		s_handleInstancesTable = [[NSMutableDictionary alloc] init];
	
	inst = [s_handleInstancesTable objectForKey:key];
	
	if( inst == nil )
	{
		Class		hc = [s_handleClassTable objectForKey:classKey];
		
		if( hc != Nil )
			inst = [[hc alloc] initWithSize:size colour:colour];
		
		if( inst != nil )
		{
			[s_handleInstancesTable setObject:inst forKey:key];
			[inst release];
			
			//NSLog(@"added handle instance %@, key = %@, total instances = %d", inst, key, [s_handleInstancesTable count]);
		}
	}
	
	return inst;
}


+ (void)				setHandleClass:(Class) hClass forType:(DKKnobType) type
{
	if([hClass superclass] != [self class])
		return;
	
	if( s_handleClassTable == nil )
		s_handleClassTable = [[NSMutableDictionary alloc] init];
	
	NSString* key = [self keyForKnobType:type];
	[s_handleClassTable setObject:hClass forKey:key];
}




+ (NSColor*)			fillColour
{
	return [NSColor colorWithDeviceRed:0.5 green:0.9 blue:1.0 alpha:1.0];
}



+ (NSColor*)			strokeColour
{
	return [NSColor blackColor];
}



+ (NSBezierPath*)		pathWithSize:(NSSize) size
{
	return [NSBezierPath bezierPathWithRect:NSMakeRect( 0, 0, size.width - [self strokeWidth], size.height - [self strokeWidth])];
}


+ (CGFloat)				strokeWidth
{
	return 0.5;
}


+ (CGFloat)				scaleFactor
{
	return 1.0;
}

#pragma mark -


- (id)					initWithSize:(NSSize) size
{
	return [self initWithSize:size colour:nil];
}


- (id)					initWithSize:(NSSize) size colour:(NSColor*) colour
{
	self = [super init];
	if( self )
	{
		mSize = size;
		mSize.width *= [[self class] scaleFactor];
		mSize.height *= [[self class] scaleFactor];
		
		mSize.width = ceil( mSize.width );
		mSize.height = ceil( mSize.height );
		
		[self setColour:colour];
	}
	
	return self;
}




- (NSSize)				size
{
	return mSize;
}


- (void)				setColour:(NSColor*) colour
{
	[colour retain];
	[mColour release];
	mColour = colour;
}


- (NSColor*)			colour
{
	return mColour;
}


- (void)				drawAtPoint:(NSPoint) point
{
	[self drawAtPoint:point angle:0];
}


- (void)				drawAtPoint:(NSPoint) point angle:(CGFloat) radians
{
	if( mCache == nil )
	{
		mCache = [[DKQuartzCache cacheForCurrentContextWithSize:[self size]] retain];
		
		[mCache lockFocus];
		
		NSBezierPath* path = [[self class] pathWithSize:[self size]];
		NSColor* c = [self colour];
		
		if( c == nil )
			c = [[self class] fillColour];
		
		if( c )
		{
			[c set];
			[path fill];
		}
		
		c = [[self class] strokeColour];
		
		if( c )
		{
			[path setLineWidth:[[self class] strokeWidth]];
			[c set];
			[path stroke];
		}
		[mCache unlockFocus];
	}

	// offset the point to the top, left of the bounds

	SAVE_GRAPHICS_CONTEXT
	
	// because handles are cached at the real screen size, they must be drawn to a scale of 1.0 regardless. Thus the context scale must be
	// forced to 1.0 at this point. This is harder than it looks because the translation must not be affected.
	
	CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
	CGAffineTransform ctm = CGContextGetCTM( context );
	CGAffineTransform newTfm = CGAffineTransformIdentity;
	
	CGFloat compScale = 1.0 / ctm.a;

	newTfm = CGAffineTransformTranslate( newTfm, point.x, point.y);
	
	if( radians != 0 )
		newTfm = CGAffineTransformRotate( newTfm, radians );

	newTfm = CGAffineTransformScale( newTfm, compScale, compScale );
	newTfm = CGAffineTransformTranslate( newTfm, -[self size].width * 0.5, -[self size].height * 0.5);
	CGContextConcatCTM( context, newTfm );
	
	[mCache drawAtPoint:NSZeroPoint];
	
	RESTORE_GRAPHICS_CONTEXT
}



- (BOOL)				hitTestPoint:(NSPoint) point inHandleAtPoint:(NSPoint) hp
{
	NSPoint relPoint;
	
	relPoint.x = point.x - hp.x;
	relPoint.y = point.y - hp.y;
	
	NSBezierPath* path = [[self class] pathWithSize:[self size]];
	return [path containsPoint:relPoint];
}


#pragma mark -

+ (NSString*)			keyForKnobType:(DKKnobType) type
{
	return [NSString stringWithFormat:@"hnd_type_%d", type];
}


#pragma mark -
#pragma mark - as a NSObject
		 
 - (void)	dealloc
 {
	 [mCache release];
	 [mColour release];
	 [super dealloc];
 }

@end
