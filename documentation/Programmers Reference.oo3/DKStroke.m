///**********************************************************************************************************************************
///  DKStroke.m
///  DrawKit
///
///  Created by graham on 09/11/2006.
///  Released under the Creative Commons license 2006 Apptree.net.
///
/// 
///  This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 License.
///  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to
///  Creative Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105, USA.
///
///**********************************************************************************************************************************

#import "DKStroke.h"

#import "DKLineDash.h"
#import "DKScriptingAdditions.h"
#import "NSBezierPath+Geometry.h"
#import "NSShadow+Scaling.h"
#import "DKDrawableObject.h"
#import "DKDrawing.h"


@implementation DKStroke
#pragma mark As a DKStroke
+ (DKStroke*)	defaultStroke;
{
	return [[[DKStroke alloc] init] autorelease];
}


+ (DKStroke*)	strokeWithWidth:(float) width colour:(NSColor*) colour
{
	DKStroke*	stroke = [[DKStroke alloc] init];
	
	[stroke setWidth:width];
	[stroke setColour:colour];
	
	return [stroke autorelease];
}


#pragma mark -
- (id)			initWithWidth:(float) width colour:(NSColor*) colour
{
	self = [super init];
	if (self != nil)
	{
		[self setColour:colour];
		NSAssert(m_dash == nil, @"Expected init to zero");
		NSAssert(m_shadow == nil, @"Expected init to zero");
		[self setLineCapStyle:NSButtLineCapStyle];
		[self setLineJoinStyle:NSMiterLineJoinStyle];
		
		[self setWidth:width];
		m_pathScale = 1.0;
		m_trimLength = 0.0;
		m_strokePosition = kGCStrokePathCentreLine;
		
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
- (void)		setWidth:(float) width
{
	//LogEvent_(kReactiveEvent, @"stroke setting width: %f", width);
	
	if( width != m_width )
	{
		m_width = width;
	}
}


- (float)		width
{
	return m_width;
}


- (void)		scaleWidthBy:(float) scale
{
	// n.b. important that this doesn't call setWidth: which triggers KVO messages - this must do its thing stealthily.
	
	m_width = [self width] * scale;
}


- (float)		allowance
{
	float allow = [self width] * 0.5f;
	
	// factor in shadow, if any
	
	if([self shadow])
		allow += [[self shadow] extraSpace];

	return allow;
}


#pragma mark -
- (void)		setDash:(DKLineDash*) dash
{
	[dash retain];
	[m_dash release];
	m_dash = dash;
}


- (DKLineDash*)	dash
{
	return m_dash;
}


- (void)		setAutoDash
{
	// sets a simple on/off dash in proportion to the current width
	
	DKLineDash* dash = [[DKLineDash alloc] init];
	float		dp[2];
	
	dp[0] = dp[1] = [self width] * 3.0;
	[dash setDashPattern:dp count:2];
	
	[self setDash:dash];
	[dash release];
}


#pragma mark -
- (void)		setStrokePosition:(int) sp
{
	m_strokePosition = sp;
}


- (int)			strokePosition
{
	return m_strokePosition;
}


- (void)		setPathScaleFactor:(float) psf
{
	if ( psf == 0.0 )
		psf = 1.0;
	
	m_pathScale = psf;
}


- (float)		pathScaleFactor
{
	return m_pathScale;
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


#pragma mark -
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


#pragma mark -
- (void)				setTrimLength:(float) tl
{
	// trim length is an amount to remove from both ends of the stroked path before stroking it (useful mainly for open paths)
	// note that the value cannot be negative.
	
	NSAssert( tl >= 0.0, @"trim length must be zero or positive" );
	m_trimLength = tl;
}


- (float)				trimLength
{
	return m_trimLength;
}


#pragma mark -
#pragma mark As a DKRasterizer
- (BOOL)		isValid
{
	return ([self colour] != nil);
}


- (NSString*)	styleScript
{
	NSMutableString* s = [[NSMutableString alloc] init];
	
	[s setString:[NSString stringWithFormat:@"(stroke width:%1.2f colour:%@", [self width], [[self colour] styleScript]]];
	
	if ([self dash])
	{
		[s appendString:@" dash:"];
		[s appendString:[[self dash] styleScript]];
	}
	
	if([self shadow])
	{
		[s appendString:@" shadow:"];
		[s appendString:[[self shadow] styleScript]];
	}
		
	[s appendString:@")"];
	
	return [s autorelease];
}


#pragma mark -
#pragma mark As a GCObservableObject
+ (NSArray*)		observableKeyPaths
{
	return [[super observableKeyPaths] arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:@"colour", @"width", @"dash",
																					@"shadow", @"lineCapStyle", @"lineJoinStyle",
																					@"pathScaleFactor", @"trimLength", nil]];
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
	[self setActionName:@"#kind# Path Scale" forKeyPath:@"pathScaleFactor"];
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


- (void)		render:(id) obj
{
	BOOL lowQuality = [obj useLowQualityDrawing];
		
	[[NSGraphicsContext currentContext] saveGraphicsState];
	
	if([self shadow] != nil )
	{
		if ( !lowQuality)
			[[self shadow] setAbsolute];
		else
			[[self shadow] drawApproximateShadowWithPath:[obj renderingPath] operation:kDKShadowDrawStroke strokeWidth:[self width]];
	}
		
	[super render:obj];
	[[NSGraphicsContext currentContext] restoreGraphicsState];
}


- (void)		renderPath:(NSBezierPath*) path
{
	// copy path as we are about to change many of its properties
	
	NSBezierPath* pc;
	
	if ([self trimLength] > 0.0 )
		pc = [path bezierPathByTrimmingFromBothEnds:[self trimLength]];
	else
		pc = [[path copy] autorelease];
		
	[[self colour] setStroke];
	[self applyAttributesToPath:pc];
	
	// path manipulations needed to implement stroke inside/outside. Note
	// that for open paths and complex shapes, this will not work well. May
	// need custom stroking code to properly implement this.
	
	if ([self strokePosition] != kGCStrokePathCentreLine )
	{
		float inset = [self width] * 0.5;
		
		if ([self strokePosition] == kGCStrokePathOutside )
			inset = -inset;
			
		pc = [pc insetPathBy:inset];
	}
	else if ([self pathScaleFactor] != 1.0 )
		pc = [pc scaledPath:[self pathScaleFactor]];
		
	[pc stroke];
}


#pragma mark -
#pragma mark As part of GraphicAttributtes Protocol
- (void)		setValue:(id) val forNumericParameter:(int) pnum
{
	// 0 -> width, 1 -> colour, 2 -> dash, 3 -> shadow
	
	switch( pnum )
	{
		case 0:
			[self setWidth:[val floatValue]];
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
	[coder encodeInt:[self lineCapStyle] forKey:@"cap_style"];
	[coder encodeInt:[self lineJoinStyle] forKey:@"join_style"];
	
	[coder encodeFloat:[self width] forKey:@"width"];
	[coder encodeFloat:[self pathScaleFactor] forKey:@"path_scale"];
	[coder encodeFloat:[self trimLength] forKey:@"trim_length"];
	[coder encodeInt:[self strokePosition] forKey:@"position"];
}


- (id)			initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super initWithCoder:coder];
	if (self != nil)
	{
		[self setColour:[coder decodeObjectForKey:@"colour"]];
		[self setDash:[coder decodeObjectForKey:@"dash"]];
		[self setShadow:[coder decodeObjectForKey:@"stroke_shadow"]];
		[self setLineCapStyle:[coder decodeIntForKey:@"cap_style"]];
		[self setLineJoinStyle:[coder decodeIntForKey:@"join_style"]];
		
		[self setWidth:[coder decodeFloatForKey:@"width"]];
		[self setPathScaleFactor:[coder decodeFloatForKey:@"path_scale"]];
		[self setTrimLength:[coder decodeFloatForKey:@"trim_length"]];
		[self setStrokePosition:[coder decodeIntForKey:@"position"]];
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
	[cp setDash:[self dash]];
	[cp setStrokePosition:[self strokePosition]];
	
	NSShadow* shcopy = [[self shadow] copyWithZone:zone];
	[cp setShadow:shcopy];
	[shcopy release];
	
	[cp setLineCapStyle:[self lineCapStyle]];
	[cp setLineJoinStyle:[self lineJoinStyle]];
	[cp setPathScaleFactor:[self pathScaleFactor]];
	[cp setTrimLength:[self trimLength]];
	
	return cp;
}


@end
