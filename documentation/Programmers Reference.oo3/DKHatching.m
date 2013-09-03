///**********************************************************************************************************************************
///  DKHatching.m
///  DrawKit
///
///  Created by graham on 06/10/2006.
///  Released under the Creative Commons license 2006 Apptree.net.
///
/// 
///  This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 License.
///  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to
///  Creative Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105, USA.
///
///**********************************************************************************************************************************

#import "DKHatching.h"

#import "DKLineDash.h"
#import "DKScriptingAdditions.h"


@implementation DKHatching
#pragma mark As a DKHatching
+ (DKHatching*)		defaultHatching
{
	// returns a shared instance of the default hatch.
	// Sharing hatches is a good idea to reduce memory and boost performance, as only one cache is needed
	
	static DKHatching* sDefaulthatch = nil;
	
	if ( sDefaulthatch == nil )
		sDefaulthatch = [[DKHatching alloc] init];
	
	return sDefaulthatch;
}


#pragma mark -
- (void)			hatchPath:(NSBezierPath*)	path
{
	[self hatchPath:path objectAngle:0.0];
}


- (void)			hatchPath:(NSBezierPath*) path objectAngle:(float) oa
{
	// if the bounds size of <path> is larger than the cached hatch, then we'll need to enlarge the cache, so invalidate
	// it.
	
	NSRect	cr, br = [path bounds];

	if ( m_cache )
	{
		cr = [m_cache bounds];
		
		if (( br.size.width * 1.5f ) > cr.size.width ||
			 ( br.size.height * 1.5f ) > cr.size.height )
			[self invalidateCache];
	}
	
	if ( m_cache == nil )
		[self calcHatchInRect:br];
		
	cr = [m_cache bounds];
		
	// now we have a hatch cached, set the clip to the path and draw the hatch. The hatch cache always has its
	// path centred at the origin so we also need to transform the cache to the drawn position
	
	[NSGraphicsContext saveGraphicsState];
	[path addClip];
	
	[m_cache setLineWidth:[self width]];

	if ([self dash])
		[[self dash] applyToPath:m_cache];
	else
		[m_cache setLineDash:nil	count:0 phase:0.0f];
		
	[[self colour] setStroke];
	
	NSAffineTransform* xform;
	
	xform = [NSAffineTransform transform];
	[xform translateXBy:NSMidX( br ) yBy:NSMidY( br )];
	[xform concat];
	
	NSBezierPath* hatch;
	
	// compensate for the object's angle by applying that rotation to the hatch path
	
	if ( oa != 0.0 )
	{
		xform = [NSAffineTransform transform];
		[xform rotateByRadians:oa];
		hatch = [xform transformBezierPath:m_cache];
	}
	else
		hatch = m_cache;
		
	[hatch setLineCapStyle:[self lineCapStyle]];
	[hatch setLineJoinStyle:[self lineJoinStyle]];
	[hatch stroke];
	
	[NSGraphicsContext restoreGraphicsState];
}


#pragma mark -
- (void)			setAngle:(float) radians
{
	if ( radians != m_angle )
	{
		// cache doesn't need rebuilding, just rotating to the new angle.
		
		if ( m_cache )
		{
			NSAffineTransform* xform = [NSAffineTransform transform];
			[xform rotateByRadians:radians - m_angle];
			[m_cache transformUsingAffineTransform:xform];
		}
		
		m_angle = radians;
	}
}


- (float)			angle
{
	return m_angle;
}


- (void)			setAngleInDegrees:(float) degs
{
	[self setAngle:(degs * pi)/180.0f];
}


- (float)			angleInDegrees
{
	return fmodf(([self angle] * 180.0f )/ pi, 360.0 );
}


- (void)			setAngleIsRelativeToObject:(BOOL) rel
{
	m_angleRelativeToObject = rel;
}


- (BOOL)			angleIsRelativeToObject
{
	return m_angleRelativeToObject;
}


#pragma mark -
- (void)			setSpacing:(float) spacing
{
	if ( spacing != m_spacing )
	{
		m_spacing = spacing;
		[self invalidateCache];
	}
}


- (float)			spacing
{
	return m_spacing;
}


- (void)			setLeadIn:(float) amount
{
	if ( amount != m_leadIn )
	{
		m_leadIn = amount;
		[self invalidateCache];
	}
}


- (float)			leadIn
{
	return m_leadIn;
}


#pragma mark -
- (void)			setWidth:(float) width
{
	m_lineWidth = width;
}


- (float)			width
{
	return m_lineWidth;
}


- (void)			setLineCapStyle:(NSLineCapStyle) lcs
{
	m_cap = lcs;
}


- (NSLineCapStyle)	lineCapStyle
{
	return m_cap;
}


- (void)			setLineJoinStyle:(NSLineJoinStyle) ljs
{
	m_join = ljs;
}


- (NSLineJoinStyle)	lineJoinStyle
{
	return m_join;
}


#pragma mark -
- (void)			setColour:(NSColor*) colour
{
	[colour retain];
	[m_hatchColour release];
	m_hatchColour = colour;
}


- (NSColor*)		colour
{
	return m_hatchColour;
}


#pragma mark -
- (void)			setDash:(DKLineDash*) dash
{
	[dash retain];
	[m_hatchDash release];
	m_hatchDash = dash;
}


- (DKLineDash*)		dash
{
	return m_hatchDash;
}


- (void)			setAutoDash
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
- (void)			invalidateCache
{
	[m_cache release];
	m_cache = nil;
}


- (void)			calcHatchInRect:(NSRect) rect
{
	// this does the actual work of calculating the hatch. Given the rect, we build a series of lines at the origin in a square
	// based on the largest side of <rect> *~ sqrt(2). Then we transform the cache to the current angle. This is much simpler than
	// calculating where to start and end each line.
	
	if ( m_cache == nil )
	{
		m_cache = [[NSBezierPath bezierPath] retain];
		
		NSRect cr;
		
		cr.size.width = cr.size.height = ( MAX( rect.size.width, rect.size.height ) * 1.5f);
		cr.origin.x = cr.origin.y = ( cr.size.width * -0.5f );
		
		//LogEvent_(kReactiveEvent,  @"hatch origin rect = {%f, %f},{%f, %f}", cr.origin.x, cr.origin.y, cr.size.width, cr.size.height );
		
		int i, m;
		
		m = lroundf( cr.size.width / [self spacing]) + 1;
		NSPoint		a, b;
		
		a.y = NSMinY( cr );
		b.y = NSMaxY( cr );
		
		for( i = 0; i < m; i++ )
		{
			a.x = b.x = cr.origin.x + m_leadIn + ( i * [self spacing]);
			
			[m_cache moveToPoint:a];
			[m_cache lineToPoint:b];
		}
		
		// now rotate the cache to the current angle
		
		NSAffineTransform* rot = [NSAffineTransform transform];
		[rot rotateByRadians:[self angle]];
		[m_cache transformUsingAffineTransform:rot];
	}
}


#pragma mark -
#pragma mark As a DKRasterizer
- (BOOL)			isValid
{
	return YES;
}


- (NSString*)		styleScript
{
	NSMutableString* s = [[NSMutableString alloc] init];
	
	[s setString:[NSString stringWithFormat:@"(hatch spacing:%1.2f lineWidth:%1.2f angle:%1.2f colour:%@)", m_spacing, m_lineWidth, [self angleInDegrees], [[self colour] styleScript]]];
	
	if ([self dash])
	{
		[s appendString:@" dash:"];
		[s appendString:[[self dash] styleScript]];
	}
		
	[s appendString:@")"];
	
	return [s autorelease];
}


#pragma mark -
#pragma mark As a GCObservableObject
+ (NSArray*)		observableKeyPaths
{
	return [[super observableKeyPaths] arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:@"colour", @"angle", @"spacing",
											@"width", @"dash", @"leadIn",
											@"lineCapStyle", @"lineJoinStyle", @"angleIsRelativeToObject", nil]];
}


- (void)		registerActionNames
{
	[super registerActionNames];
	[self setActionName:@"#kind# Hatch Colour" forKeyPath:@"colour"];
	[self setActionName:@"#kind# Hatch Angle" forKeyPath:@"angle"];
	[self setActionName:@"#kind# Hatch Spacing" forKeyPath:@"spacing"];
	[self setActionName:@"#kind# Hatch Line Width" forKeyPath:@"width"];
	[self setActionName:@"#kind# Hatch Dash" forKeyPath:@"dash"];
	[self setActionName:@"#kind# Hatch Lead-in" forKeyPath:@"leadIn"];
	[self setActionName:@"#kind# Hatch Line Cap Style" forKeyPath:@"lineCapStyle"];
	[self setActionName:@"#kind# Hatch Line Join Style" forKeyPath:@"lineJoinStyle"];
	[self setActionName:@"#kind# Hatch Is Relative" forKeyPath:@"angleIsRelativeToObject"];
}


#pragma mark -
#pragma mark As an NSObject
- (void)			dealloc
{
	[m_hatchDash release];
	[m_hatchColour release];
	[self invalidateCache];
	
	[super dealloc];
}


- (id)				init
{
	self = [super init];
	if (self != nil)
	{
		NSAssert(m_cache == nil, @"Expected init to zero");
		[self setColour:[NSColor blackColor]];
		NSAssert(m_hatchDash == nil, @"Expected init to zero");
		
		m_angleRelativeToObject = NO;
		
		[self setLeadIn:0.0];
		[self setSpacing:8.0];
		[self setAngle:pi/4.0]; //45 degrees
		[self setWidth:0.25];
		
		[self setLineCapStyle:NSButtLineCapStyle];
		[self setLineJoinStyle:NSMiterLineJoinStyle];
	}
	return self;
}


#pragma mark -
#pragma mark As part of DKRasterizerProtocol
- (void)		render:(id) obj
{
	NSBezierPath* path = [obj renderingPath];
	
	if ( m_angleRelativeToObject )
		[self hatchPath:path objectAngle:[obj angle]];
	else
		[self hatchPath:path objectAngle:0.0f];
}


#pragma mark -
#pragma mark As part of GraphicAttributtes Protocol
- (void)		setValue:(id) val forNumericParameter:(int) pnum
{
	// 0 -> width, 1 -> spacing, 2 -> angle (degrees), 3 -> colour, 4 -> dash
	
	switch( pnum )
	{
		default:
			break;
			
		case 0:
			[self setWidth:[val floatValue]];
			break;
			
		case 1:
			[self setSpacing:[val floatValue]];
			break;
			
		case 2:
			[self setAngleInDegrees:[val floatValue]];
			break;
	
		case 3:
			[self setColour:val];
			break;
			
		case 4:
			[self setDash:val];
			break;
	}
}


#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)			encodeWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];
	
	[coder encodeObject:[self colour] forKey:@"colour"];
	[coder encodeObject:[self dash] forKey:@"dash"];
	
	[coder encodeFloat:[self leadIn] forKey:@"lead-in"];
	[coder encodeFloat:[self spacing] forKey:@"spacing"];
	[coder encodeFloat:[self angle] forKey:@"angle"];
	[coder encodeFloat:[self width] forKey:@"linewidth"];

	[coder encodeInt:[self lineJoinStyle] forKey:@"DKHatching_lineJoinStyle"];
	[coder encodeInt:[self lineCapStyle] forKey:@"DKHatching_lineCapStyle"];
	[coder encodeBool:m_angleRelativeToObject forKey:@"DKHatching_relAngle"];
}


- (id)				initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super initWithCoder:coder];
	if (self != nil)
	{
		NSAssert(m_cache == nil, @"Expected init to zero");
		[self setColour:[coder decodeObjectForKey:@"colour"]];
		[self setDash:[coder decodeObjectForKey:@"dash"]];
		
		[self setLeadIn:[coder decodeFloatForKey:@"lead-in"]];
		[self setSpacing:[coder decodeFloatForKey:@"spacing"]];
		[self setAngle:[coder decodeFloatForKey:@"angle"]];
		[self setWidth:[coder decodeFloatForKey:@"linewidth"]];
		
		[self setLineCapStyle:[coder decodeIntForKey:@"DKHatching_lineCapStyle"]];
		[self setLineJoinStyle:[coder decodeIntForKey:@"DKHatching_lineJoinStyle"]];
		
		m_angleRelativeToObject = [coder decodeBoolForKey:@"DKHatching_relAngle"];
	}
	return self;
}


#pragma mark -
#pragma mark As part of NSCopying Protocol
- (id)				copyWithZone:(NSZone*) zone
{
	#pragma unused(zone)
	
	DKHatching* copy = [super copyWithZone:zone];
	
	[copy setSpacing:[self spacing]];
	[copy setLeadIn:[self leadIn]];
	[copy setAngle:[self angle]];
	[copy setWidth:[self width]];
	[copy setColour:[self colour]];
	[copy setDash:[self dash]];
	[copy setLineCapStyle:[self lineCapStyle]];
	[copy setLineJoinStyle:[self lineJoinStyle]];
	[copy setAngleIsRelativeToObject:[self angleIsRelativeToObject]];
	
	return copy;
}


@end
