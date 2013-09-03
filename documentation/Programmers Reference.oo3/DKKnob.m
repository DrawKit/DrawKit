//
//  DKKnob.m
//  DrawingArchitecture
//
//  Created by graham on 21/08/2006.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "DKKnob.h"
#import "DKGeometryUtilities.h"
#import "NSBezierPath+Geometry.h"


NSString*	kDKKnobPreferredHighlightColour = @"kDKKnobPreferredHighlightColour";


#pragma mark Static Vars
static NSColor*			sKnobColour = nil;
static NSColor*			sRotationColour = nil;
static NSColor*			sPointColour = nil;
static NSColor*			sBarColour = nil;
static float			sBarWidth = 0.0;
static NSSize			sKnobSize = { 6.0, 6.0 };


#pragma mark -
@implementation DKKnob
#pragma mark As a DKKnob
+ (id)				standardKnobs
{
	return [[[DKKnob alloc] init] autorelease];
}


#pragma mark -
+ (void)			setControlKnobColour:(NSColor*) clr
{
	[clr retain];
	[sKnobColour release];
	sKnobColour = clr;
}


+ (NSColor*)		controlKnobColour
{
	if ( sKnobColour == nil )
		[DKKnob setControlKnobColour:[NSColor colorWithDeviceRed:0.5 green:0.9 blue:1.0 alpha:1.0]];
		
	return sKnobColour;
}


#pragma mark -
+ (void)			setRotationKnobColour:(NSColor*) clr
{
	[clr retain];
	[sRotationColour release];
	sRotationColour = clr;
}

+ (NSColor*)		rotationKnobColour
{
	if ( sRotationColour == nil )
		[DKKnob setRotationKnobColour:[NSColor purpleColor]];
		
	return sRotationColour;
}

#pragma mark -
+ (void)			setControlOnPathPointColour:(NSColor*) clr
{
	[clr retain];
	[sPointColour release];
	sPointColour = clr;
}


+ (NSColor*)		controlOnPathPointColour
{
	if ( sPointColour == nil )
		[DKKnob setControlOnPathPointColour:[NSColor orangeColor]];
		
	return sPointColour;
}


#pragma mark -
+ (void)			setControlBarColour:(NSColor*) clr
{
	[clr retain];
	[sBarColour release];
	sBarColour = clr;
}


+ (NSColor*)		controlBarColour
{
	if ( sBarColour == nil )
		[DKKnob setControlBarColour:[NSColor cyanColor]];
		
	return sBarColour;
}


#pragma mark -
+ (void)			setControlKnobSize:(NSSize) size
{
	sKnobSize = size;

}


+ (NSSize)			controlKnobSize
{
	return sKnobSize;
}


#pragma mark -
+ (void)			setControlBarWidth:(float) width
{
	sBarWidth = width;
}


+ (float)			controlBarWidth
{
	return sBarWidth;
}


#pragma mark -
+ (NSRect)			controlKnobRectAtPoint:(NSPoint) kp
{
	NSRect r;
	
	r.size = [[self class] controlKnobSize];
	r.origin.x = kp.x - ( r.size.width * 0.5f );
	r.origin.y = kp.y - ( r.size.height * 0.5f );
	
	return r;
}

#pragma mark -
#pragma mark - main high-level methods will be called by clients
- (void)			setOwner:(id<DKKnobOwner>) owner
{
	if([owner conformsToProtocol:@protocol(DKKnobOwner)])
		m_ownerRef = owner;
	else
	{
		m_ownerRef = nil;
		NSAssert( NO, @"knobs owner must implement the 'DKKnobOwner' protocol - see DKCommonTypes.h");
	}
}


- (id<DKKnobOwner>)	owner
{
	return m_ownerRef;
}


#pragma mark -
- (BOOL)			hitTestPoint:(NSPoint) p inKnobAtPoint:(NSPoint) kp ofType:(DKKnobType) knobType userInfo:(id) userInfo
{
	NSRect br = [self controlKnobRectAtPoint:kp ofType:knobType];
	
	if ( NSPointInRect( p, br ))
	{
		NSBezierPath* path = [self knobPathAtPoint:kp ofType:knobType angle:0.0 userInfo:userInfo];
		return [path containsPoint:p];
	}
	else
		return NO;
}


- (void)			drawKnobAtPoint:(NSPoint) p ofType:(DKKnobType) knobType userInfo:(id) userInfo
{
	[self drawKnobAtPoint:p ofType:knobType angle:0.0 userInfo:userInfo];
}


- (void)			drawKnobAtPoint:(NSPoint) p ofType:(DKKnobType) knobType angle:(float) radians userInfo:(id) userInfo;
{
	NSAssert( knobType != 0, @"knob type can't be zero");
	
	// query the owner to find out whether we're active and what the scale is. If there's no owner set, 
	// skip this fancy stuff
	
	if([self owner] != nil )
	{
		float scale = [[self owner] knobsWantDrawingScale];
		
		if ( scale <= 0.0 )
			scale = 1.0;
			
		[self setControlKnobSizeForViewScale:scale];
		
		BOOL active = [[self owner] knobsWantDrawingActiveState];
		
		if ( !active )
			knobType |= kDKKnobIsInactiveFlag;
	}
	
	NSBezierPath* path = [self knobPathAtPoint:p ofType:knobType angle:radians userInfo:userInfo];
	[self drawKnobPath:path ofType:knobType userInfo:userInfo];
}


#pragma mark -
#pragma mark - low-level methods (mostly internal and overridable)
- (void)			setControlKnobSize:(NSSize) cks
{
	m_knobSize = cks;
}


- (void)			setControlKnobSizeForViewScale:(float) scale
{
	// given a scale of a view where 1.0 = 100%, this calculates the appropriate control knob size to use. Note that control knobs are not
	// set to a fixed size, but do scale a little. This gives a better feel when zooming the view than a straight compensation.
	
	NSAssert( scale > 0.0, @"scale is 0!" );
	
	float   ff = (( scale - 1.0 ) * 0.33 ) + 1.0;
	
	NSSize ns = [[self class] controlKnobSize];
	
	ns.width /= ff;
	ns.height /= ff;
	[self setControlKnobSize:ns];
}


- (NSSize)			controlKnobSize
{
	return m_knobSize;
}


- (NSRect)			controlKnobRectAtPoint:(NSPoint) kp
{
	NSSize hs = [self controlKnobSize];
	NSRect hr = NSMakeRect( kp.x, kp.y, hs.width, hs.height );
	
	hr = NSOffsetRect( hr, -( hs.width * 0.5f ), -( hs.height * 0.5f ));
	
	return hr;
}


- (NSRect)			controlKnobRectAtPoint:(NSPoint) kp ofType:(DKKnobType) knobType
{
	NSRect kr = [self controlKnobRectAtPoint:kp];
	
	switch( knobType & kDKKnobTypeMask )
	{
		case kDKCentreTargetKnobType:
			kr = NSInsetRect( kr, -3, -3 );
			break;
			
		case kDKRotationKnobType:
			kr = NSInsetRect( kr, -0.5, -0.5 );
			break;
		
		case kDKHotspotKnobType:
			kr = NSInsetRect( kr, -1, -1 );
			break;
		
		default:
			break;
	}
	
	return kr;
}


#pragma mark -
- (NSBezierPath*)	knobPathAtPoint:(NSPoint) p ofType:(DKKnobType) knobType angle:(float) radians userInfo:(id) userInfo
{
	#pragma unused(userInfo)
	
	knobType &= kDKKnobTypeMask;	// mask off flags - of no interest here
	
	BOOL			isRect = ( knobType == kDKBoundingRectKnobType ||
								knobType == kDKHotspotKnobType);
	NSBezierPath*	path;
	NSRect			boundsRect = [self controlKnobRectAtPoint:p ofType:knobType];
	
	// inset the bounds to allow for half the stroke width to take up that space
	
	float strokeWidth = [self strokeWidthForKnobType:knobType];
	boundsRect = NSInsetRect( boundsRect, strokeWidth * 0.5f, strokeWidth * 0.5f );
	
	if ( isRect )
	{
		path = [NSBezierPath bezierPathWithRect:boundsRect];
		
		// if angle non-zero, apply rotation to the path about the point p
		
		if ( radians != 0.0 )
			path = [path rotatedPath:radians aboutPoint:p];
	}
	else if ( knobType == kDKCentreTargetKnobType )
	{
		path = [NSBezierPath bezierPath];
		NSSize		half;
	
		half.width = boundsRect.size.width * 0.5f;
		half.height = boundsRect.size.height * 0.5f;
		
		p.y -= half.height;
		[path moveToPoint:p];
		p.y += boundsRect.size.height;
		[path lineToPoint:p];
		p.y -= half.height;
		p.x -= half.width;
		[path moveToPoint:p];
		p.x += boundsRect.size.width;
		[path lineToPoint:p];
	
		NSRect	tr;
	
		tr = NSInsetRect( boundsRect, half.width * 0.5f, half.height * 0.5f );
		[path appendBezierPathWithOvalInRect:tr];
	}
	else
	    path = [NSBezierPath bezierPathWithOvalInRect:boundsRect];
		
	return path;
}


- (void)			drawKnobPath:(NSBezierPath*) path ofType:(DKKnobType) knobType userInfo:(id) userInfo
{
	#pragma unused(userInfo)
	NSAssert( path != nil, @"can't draw knob path - nil");
	
	DKKnobDrawingFlags	flags = [self drawingFlagsForKnobType:knobType];
	NSColor*			colour;
	
	// fill first, stroke on top if requested
	
	if( flags & kDKKnobDrawsFill )
	{
		// if <userInfo> is a dictionary and it contains the kDKKnobPreferredHighlightColour key, use that colour here
		
		colour = [self fillColourForKnobType:knobType];

		if( userInfo != nil && [userInfo isKindOfClass:[NSDictionary class]])
		{
			NSColor* preferred = [(NSDictionary*)userInfo objectForKey:kDKKnobPreferredHighlightColour];
			
			if( preferred != nil )
				colour = preferred;
		}
		
		[colour setFill];
		[path fill];
	}
	
	if( flags & kDKKnobDrawsStroke )
	{
		colour = [self strokeColourForKnobType:knobType];
		[colour setStroke];
		[path setLineWidth:[self strokeWidthForKnobType:knobType]];
		[path stroke];
	}
}


- (DKKnobDrawingFlags) drawingFlagsForKnobType:(DKKnobType) knobType
{
	BOOL locked = ((knobType & kDKKnobIsDisabledFlag) != 0);
	DKKnobDrawingFlags result = kDKKnobDrawsFill;
	
	switch( knobType & kDKKnobTypeMask )
	{
		case kDKControlPointKnobType:
		case kDKOnPathKnobType:
			break;
		
		case kDKHotspotKnobType:	
		case kDKBoundingRectKnobType:
		case kDKRotationKnobType:
		result |= kDKKnobDrawsStroke;
			break;
			
		case kDKCentreTargetKnobType:
			result |= kDKKnobDrawsStroke;
			result &= ~kDKKnobDrawsFill;
			break;
	
		default:
			break;
	}
	
	if( locked )
		result |= kDKKnobDrawsStroke;
	
	return result;
}


#pragma mark -
- (NSColor*)		fillColourForKnobType:(DKKnobType) knobType
{
	BOOL locked = ((knobType & kDKKnobIsDisabledFlag) != 0);
	BOOL inactive = ((knobType & kDKKnobIsInactiveFlag) != 0);
	
	NSColor* result = nil;
	
	if ( inactive )
		result = [NSColor lightGrayColor];
	else
	{
		if ( locked )
			result = [NSColor whiteColor];
		else
		{
			switch( knobType & kDKKnobTypeMask )
			{
				case kDKControlPointKnobType:
				case kDKBoundingRectKnobType:
					result = [[self class] controlKnobColour];
					break;
					
				case kDKOnPathKnobType:
					result = [[self class] controlOnPathPointColour];
					break;
					
				case kDKRotationKnobType:
					result = [[self class] rotationKnobColour];
					break;
					
				case kDKHotspotKnobType:
					result = [NSColor yellowColor];
					break;
					
				case kDKCentreTargetKnobType:
				default:
					break;
			}
		}
	}
	return result;
}


- (NSColor*)		strokeColourForKnobType:(DKKnobType) knobType
{
	BOOL locked = ((knobType & kDKKnobIsDisabledFlag) != 0);
	BOOL inactive = ((knobType & kDKKnobIsInactiveFlag) != 0);

	NSColor* result = nil;
	
	if ( locked || inactive )
		result = [NSColor grayColor];
	else
	{
		switch( knobType & kDKKnobTypeMask )
		{
			case kDKBoundingRectKnobType:
				result = [NSColor darkGrayColor];
				break;
				
			case kDKRotationKnobType:
				result = [NSColor whiteColor];
				break;
				
			case kDKCentreTargetKnobType:
				result = [[self class] controlKnobColour];
				break;
				
			case kDKHotspotKnobType:
				result = [NSColor blackColor];
				break;
				
			case kDKOnPathKnobType:
			default:
				break;
		}
	}
	
	return result;
}


- (float)			strokeWidthForKnobType:(DKKnobType) knobType
{
	NSSize cns = [self controlKnobSize];
	float	strk = 0.0;

	switch( knobType & kDKKnobTypeMask )
	{
		case kDKCentreTargetKnobType:
			strk = cns.width * 4.0f / 24.0f;
			break;
			
		case kDKRotationKnobType:
			strk = cns.width / 6.0;
			break;
			
		default:
			strk = cns.width / 8.0f;
			break;
	}
	
	return strk;
}


#pragma mark -
- (void)			drawControlBarFromPoint:(NSPoint) a toPoint:(NSPoint) b
{
	[[[self class] controlBarColour] set];
	
	// normally knobs would never be drawn to a print of PDF context, but there is a special hidden feature that
	// creates PDFs with the knobs drawn, so make sure that the control bar does come up visible.
	
	if([NSGraphicsContext currentContextDrawingToScreen])
		[NSBezierPath setDefaultLineWidth:[[self class] controlBarWidth]];
	else
		[NSBezierPath setDefaultLineWidth:1.0];
	[NSBezierPath strokeLineFromPoint:a toPoint:b];
}


- (void)			drawControlBarWithKnobsFromPoint:(NSPoint) a toPoint:(NSPoint) b
{
	[self drawControlBarWithKnobsFromPoint:a ofType:kDKControlPointKnobType toPoint:b ofType:kDKControlPointKnobType];
}


- (void)			drawControlBarWithKnobsFromPoint:(NSPoint) a ofType:(DKKnobType) typeA toPoint:(NSPoint) b ofType:(DKKnobType) typeB
{
	float angle = atan2f( b.y - a.y, b.x - a.x );
	
	[self drawControlBarFromPoint:a toPoint:b];
	[self drawKnobAtPoint:a ofType:typeA angle:angle userInfo:nil];
	[self drawKnobAtPoint:b ofType:typeB angle:angle userInfo:nil];
}


#pragma mark -
- (void)			drawRotationBarWithKnobsFromCentre:(NSPoint) centre toPoint:(NSPoint) p
{
	// draws a rotation bar which is a special form of control bar used to signal that a rotation operation is
	// occurring. A target is drawn at <centre> and a rotation knob at <p>
	
	[self drawControlBarWithKnobsFromPoint:centre ofType:kDKCentreTargetKnobType toPoint:p ofType:kDKRotationKnobType];
}


- (void)			drawPartcode:(int) code atPoint:(NSPoint) p fontSize:(float) fontSize
{
	// this is generally only used for debugging. It draws the number <code> inside a box at the location given, using the fontSize.
	
	static NSMutableDictionary*	attrs = nil;
	
	if ( attrs == nil )
		attrs = [[NSMutableDictionary alloc] init];
		
	// calculate the actual drawn font size based on the control size - this avoids huge numbers being drawn when the view
	// is zoomed in
	
	float scale = [[self owner] knobsWantDrawingScale];	
	
	if ( scale == 0.0 )
		scale = 1.0;
		
	fontSize /= scale;
	
	if ( fontSize < 2.0 )
		fontSize = 2.0;
		
	NSFont*		font = [NSFont fontWithName:@"Monaco" size:fontSize];
	[attrs setObject:font forKey:NSFontAttributeName];

	NSString*	s = [NSString stringWithFormat:@"%d", code];
	NSRect box;
	
	box.size = [s sizeWithAttributes:attrs];
	box.origin = p;

	NSRect b = NSInsetRect( box, -1.5, -1 );
	[[NSColor whiteColor] set];
	NSRectFill( b );
	[[NSColor blackColor] set];
	[s drawInRect:box withAttributes:attrs];
	//NSFrameRectWithWidth( b, 0.0 );
	[NSBezierPath setDefaultLineWidth:0.0];
	[NSBezierPath strokeRect:b];
}


#pragma mark -
#pragma mark As an NSObject
- (id)				init
{
	self = [super init];
	if (self != nil)
	{
		NSAssert(m_ownerRef == nil, @"Expected init to zero");
		[self setControlKnobSize:[[self class] controlKnobSize]];
	}
	
	return self;
}


@end
