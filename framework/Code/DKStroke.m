///**********************************************************************************************************************************
///  DKStroke.m
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 09/11/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKStroke.h"
#import "DKStyle.h"
#import "DKStrokeDash.h"
#import "NSBezierPath+Geometry.h"
#import "NSShadow+Scaling.h"
#import "DKDrawableObject.h"
#import "DKDrawing.h"


@implementation DKStroke
#pragma mark As a DKStroke
+ (DKStroke*)	defaultStroke;
{
	return [[[self alloc] init] autorelease];
}


+ (DKStroke*)	strokeWithWidth:(CGFloat) width colour:(NSColor*) colour
{
	DKStroke*	stroke = [[self alloc] init];
	
	[stroke setWidth:width];
	[stroke setColour:colour];
	
	return [stroke autorelease];
}


#pragma mark -
- (id)			initWithWidth:(CGFloat) width colour:(NSColor*) colour
{
	self = [super init];
	if (self != nil)
	{
		[self setColour:colour];
		[self setLineCapStyle:NSButtLineCapStyle];
		[self setLineJoinStyle:NSRoundLineJoinStyle];
		[self setWidth:width];
		[self setMiterLimit:10.0];

		m_trimLength = 0.0;
		
		if (m_colour == nil)
		{
			[self autorelease];
			self = nil;
		}
	}
	return self;
}


#pragma mark -
- (void)		setColour:(NSColor*) colour
{
	//LogEvent_(kReactiveEvent, @"stroke setting colour: %@", colour);
	
	[colour retain];
	[m_colour release];
	m_colour = colour;
}


- (NSColor*)	colour
{
	return m_colour;
}


#pragma mark -
- (void)		setWidth:(CGFloat) width
{
	//LogEvent_(kReactiveEvent, @"stroke setting width: %f", width);
	
	if( width != m_width )
	{
		m_width = width;
	}
}


- (CGFloat)		width
{
	return m_width;
}


- (void)		scaleWidthBy:(CGFloat) scale
{
	// n.b. important that this doesn't call setWidth: which triggers KVO messages - this must do its thing stealthily.
	
	m_width = [self width] * scale;
}


- (CGFloat)		allowance
{
	CGFloat allow = ([self width] * 0.5f) + fabs([self lateralOffset]);
	
	// factor in miter limit if that's the join style. Note that miter limits can be extremely generous, and cause the bounds
	// to blow out quite substantially.
	
	if([self lineJoinStyle] == NSMiterLineJoinStyle)
	{
		CGFloat m = ([self miterLimit] * [self width] * 0.5f );
		CGFloat om = ([self miterLimit] * fabs([self lateralOffset]));
		
		if ( m > allow )
			allow = m;
		
		if( om > allow )
			allow = om;
	}
	
	// factor in shadow, if any
	
	if([self shadow])
	{
		CGFloat es = [[self shadow] extraSpace];
		
		if ( es > allow )
			allow = es;
	}
	
	return allow;
}


#pragma mark -
- (void)		setDash:(DKStrokeDash*) dash
{
	[dash retain];
	[m_dash release];
	m_dash = dash;
}


- (DKStrokeDash*)	dash
{
	return m_dash;
}


- (void)		setAutoDash
{
	// sets a simple on/off dash in proportion to the current width
	
	DKStrokeDash* dash = [[DKStrokeDash alloc] init];
	CGFloat		dp[2];
	
	dp[0] = dp[1] = [self width] * 3.0;
	[dash setDashPattern:dp count:2];
	
	[self setDash:dash];
	[dash release];
}


#pragma mark -
- (void)		setLateralOffset:(CGFloat) offset
{
	mLateralOffset = offset;
}


- (CGFloat)		lateralOffset
{
	return mLateralOffset;
}



#pragma mark -
- (void)		setShadow:(NSShadow*) shadw
{
	[shadw retain];
	[m_shadow release];
	m_shadow = shadw;
}


- (NSShadow*)	shadow
{
	return m_shadow;
}


#pragma mark -
- (void)		strokeRect:(NSRect) rect
{
	[self renderPath:[NSBezierPath bezierPathWithRect:rect]];
}


- (void)				applyAttributesToPath:(NSBezierPath*) path
{
	// applies the stroke's width, cap, join, mitre limit and dash to the path
	
	[path setLineWidth:[self width]];
	[path setLineCapStyle:[self lineCapStyle]];
	[path setLineJoinStyle:[self lineJoinStyle]];
	[path setMiterLimit:[self miterLimit]];
	
	if ([self dash])
		[[self dash] applyToPath:path]; 
	else
		[path setLineDash:NULL count:0 phase:0.0];
}


#pragma mark -
- (void)				setLineCapStyle:(NSLineCapStyle) lcs
{
	if ( lcs != m_cap )
	{
		m_cap = lcs;
	}
}


- (NSLineCapStyle)		lineCapStyle
{
	return m_cap;
}


- (void)				setLineJoinStyle:(NSLineJoinStyle) ljs
{
	if ( ljs != m_join )
	{
		m_join = ljs;
	}
}


- (NSLineJoinStyle)		lineJoinStyle
{
	return m_join;
}


- (void)				setMiterLimit:(CGFloat) limit
{
	m_mitreLimit = limit;
}



- (CGFloat)				miterLimit
{
	return m_mitreLimit;
}



#pragma mark -
- (void)				setTrimLength:(CGFloat) tl
{
	// trim length is an amount to remove from both ends of the stroked path before stroking it (useful mainly for open paths)
	// note that the value cannot be negative.
	
	NSAssert( tl >= 0.0, @"trim length must be zero or positive" );
	m_trimLength = tl;
}


- (CGFloat)				trimLength
{
	return m_trimLength;
}


- (NSSize)				extraSpaceNeededIgnoringMitreLimit
{
	NSLineJoinStyle savedJS = m_join;
	m_join = NSRoundLineJoinStyle;
	
	NSSize es = [self extraSpaceNeeded];
	m_join = savedJS;
	
	return es;
}



#pragma mark -
#pragma mark As a DKRasterizer
- (BOOL)		isValid
{
	return ([self colour] != nil);
}




#pragma mark -
#pragma mark As a GCObservableObject
+ (NSArray*)		observableKeyPaths
{
	return [[super observableKeyPaths] arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:@"colour", @"width", @"dash",
																					@"shadow", @"lineCapStyle", @"lineJoinStyle",
																					@"lateralOffset", @"trimLength", nil]];
}


- (void)	registerActionNames
{
	[super registerActionNames];
	[self setActionName:@"#kind# Stroke Colour" forKeyPath:@"colour"];
	[self setActionName:@"#kind# Stroke Width" forKeyPath:@"width"];
	[self setActionName:@"#kind# Stroke Dash" forKeyPath:@"dash"];
	[self setActionName:@"#kind# Stroke Shadow" forKeyPath:@"shadow"];
	[self setActionName:@"#kind# Line Cap Style" forKeyPath:@"lineCapStyle"];
	[self setActionName:@"#kind# Line Join Style" forKeyPath:@"lineJoinStyle"];
	[self setActionName:@"#kind# Stroke Offset" forKeyPath:@"lateralOffset"];
	[self setActionName:@"#kind# Trim Length" forKeyPath:@"trimLength"];
}


#pragma mark -
#pragma mark As an NSObject
- (void)		dealloc
{
	[m_shadow release];
	[m_dash release];
	[m_colour release];
	
	[super dealloc];
}


- (id)			init
{
	return [self initWithWidth:1.0 colour:[NSColor blackColor]];
}


#pragma mark -
#pragma mark As part of DKRasterizerProtocol
- (NSSize)		extraSpaceNeeded
{
	return NSMakeSize([self allowance], [self allowance]);
}


- (void)		render:(id<DKRenderable>) obj
{
	if( ![obj conformsToProtocol:@protocol(DKRenderable)] || ![self enabled])
		return;

	BOOL lowQuality = [obj useLowQualityDrawing];
		
	SAVE_GRAPHICS_CONTEXT		//[NSGraphicsContext saveGraphicsState];
		
	if([self shadow] != nil && [DKStyle willDrawShadows])
	{
		if ( !lowQuality)
			[[self shadow] setAbsolute];
		else
			[[self shadow] drawApproximateShadowWithPath:[obj renderingPath] operation:kDKShadowDrawStroke strokeWidth:[self width]];
	}
	
		
	[super render:obj];
	RESTORE_GRAPHICS_CONTEXT	//[NSGraphicsContext restoreGraphicsState];
}


- (void)		renderPath:(NSBezierPath*) path
{
	// copy path as we are about to change many of its properties
	
	NSBezierPath* pc;
	
	if ([self trimLength] > 0.0 )
		pc = [path bezierPathByTrimmingFromBothEnds:[self trimLength]];
	else
		pc = [[path copy] autorelease];
	
	if( mLateralOffset != 0.0 )
	{
		// make a parallel copy of the path
		CGFloat savedFlatness = [NSBezierPath defaultFlatness];
		[NSBezierPath setDefaultFlatness:0.05];
		[pc setLineJoinStyle:[self lineJoinStyle]];
		pc = [pc paralleloidPathWithOffset22:[self lateralOffset]];
		[NSBezierPath setDefaultFlatness:savedFlatness];
	}
		
	[[self colour] setStroke];
	[self applyAttributesToPath:pc];
	
	[pc stroke];
}


#pragma mark -
#pragma mark As part of GraphicAttributtes Protocol
- (void)		setValue:(id) val forNumericParameter:(NSInteger) pnum
{
	// 0 -> width, 1 -> colour, 2 -> dash, 3 -> shadow
	
	switch( pnum )
	{
		case 0:
			[self setWidth:[val doubleValue]];
			break;
			
		case 1:
			[self setColour:val];
			break;
			
		case 2:
			[self setDash:val];
			break;
			
		case 3:
			[self setShadow:val];
			break;
			
		default:
			break;
	}
}


#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)		encodeWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];
	
	[coder encodeObject:[self colour] forKey:@"colour"];
	[coder encodeObject:[self dash] forKey:@"dash"];
	[coder encodeObject:[self shadow] forKey:@"stroke_shadow"];
	[coder encodeInteger:[self lineCapStyle] forKey:@"cap_style"];
	[coder encodeInteger:[self lineJoinStyle] forKey:@"join_style"];
	[coder encodeDouble:[self miterLimit] forKey:@"DKStroke_miterLimit"];
	
	[coder encodeDouble:[self width] forKey:@"width"];
	[coder encodeDouble:[self lateralOffset] forKey:@"DKStroke_lateralOffset"];
	[coder encodeDouble:[self trimLength] forKey:@"trim_length"];
}


- (id)			initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super initWithCoder:coder];
	if (self != nil)
	{
		[self setColour:[coder decodeObjectForKey:@"colour"]];
		
		// copy the dash to clear a possible bug with multiple strokes incorrectly having the same dash object
		
		DKStrokeDash* dash = [[coder decodeObjectForKey:@"dash"] copy];
		[self setDash:dash];
		[dash release];
		
		[self setShadow:[coder decodeObjectForKey:@"stroke_shadow"]];
		[self setLineCapStyle:[coder decodeIntegerForKey:@"cap_style"]];
		[self setLineJoinStyle:[coder decodeIntegerForKey:@"join_style"]];
		
		[self setWidth:[coder decodeDoubleForKey:@"width"]];
		[self setLateralOffset:[coder decodeDoubleForKey:@"DKStroke_lateralOffset"]];
		[self setTrimLength:[coder decodeDoubleForKey:@"trim_length"]];
		
		CGFloat ml = [coder decodeDoubleForKey:@"DKStroke_miterLimit"];
		
		if ( ml == 0.0 )
			ml = 10.0;
			
		[self setMiterLimit:ml];
	}
	return self;
}


#pragma mark -
#pragma mark As part of NSCopying Protocol
- (id)			copyWithZone:(NSZone*) zone
{
	DKStroke* cp = [super copyWithZone:zone];
	
	[cp setColour:[self colour]];
	[cp setWidth:[self width]];
	
	DKStrokeDash* dashCopy = [[self dash] copyWithZone:zone];
	[cp setDash:dashCopy];
	[dashCopy release];
	
	NSShadow* shcopy = [[self shadow] copyWithZone:zone];
	[cp setShadow:shcopy];
	[shcopy release];
	
	[cp setLineCapStyle:[self lineCapStyle]];
	[cp setLineJoinStyle:[self lineJoinStyle]];
	[cp setLateralOffset:[self lateralOffset]];
	[cp setTrimLength:[self trimLength]];
	[cp setMiterLimit:[self miterLimit]];
	
	return cp;
}


@end
