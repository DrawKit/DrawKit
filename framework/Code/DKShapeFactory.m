//
//  DKShapeFactory.m
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by graham on 20/08/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//

#import "DKShapeFactory.h"
#import "DKDrawKitMacros.h"
#import "LogEvent.h"


#pragma mark Contants (Non-localized)
NSString*	kDKSpeechBalloonType = @"kDKSpeechBalloonType";
NSString*	kDKSpeechBalloonCornerRadius = @"kDKSpeechBalloonCornerRadius";


#pragma mark -
@implementation DKShapeFactory
#pragma mark As a DKShapeFactory

+ (DKShapeFactory*)	sharedShapeFactory;
{
	static DKShapeFactory* sSharedShapeFactory = nil;
	
	if ( sSharedShapeFactory == nil )
		sSharedShapeFactory = [[DKShapeFactory alloc] init];
		
	return sSharedShapeFactory;
}


#pragma mark -
+ (NSRect)			rectOfUnitSize
{
	return NSMakeRect( -0.5, -0.5, 1.0, 1.0 );
}

#pragma mark -
+ (NSBezierPath*)	rect
{
	return [NSBezierPath bezierPathWithRect:[self rectOfUnitSize]];
}


+ (NSBezierPath*)	oval
{
	return [NSBezierPath bezierPathWithOvalInRect:[self rectOfUnitSize]];
}


+ (NSBezierPath*)	roundRect
{
	// return a roundRect with default corner radius. Note that roundRects do not scale all that well - the corners get distorted
	// if the scale isn't square. In which case you may prefer to recalculate the path given the final size of the shape.
	
	return [self roundRectWithCornerRadius:0.1];
}


+ (NSBezierPath*)	roundRectWithCornerRadius:(CGFloat) radius
{
	return [self roundRectInRect:[self rectOfUnitSize] andCornerRadius:radius];
}


+ (NSBezierPath*)	roundRectInRect:(NSRect) rect andCornerRadius:(CGFloat) radius
{
	// return a roundRect with given corner radius. Note: this code based on Uli Kusterer's NSBezierpathRoundRects class with
	// grateful thanks.
	
	// Make sure radius doesn't exceed a maximum size
	
	if( radius >= (rect.size.height /2))
		radius = rect.size.height * 0.5f;
	
	if( radius >= (rect.size.width /2))
		radius = rect.size.width * 0.5f;
	
	// Make sure silly values simply lead to un-rounded corners:

	if( radius <= 0 || NSIsEmptyRect( rect ))
		return [NSBezierPath bezierPathWithRect: rect];

	// Now draw our rectangle:
	NSRect			innerRect = NSInsetRect( rect, radius, radius );	// Make rect with corners being centers of the corner circles.
	NSBezierPath*	path = [NSBezierPath bezierPath];

	[path moveToPoint: NSMakePoint( rect.origin.x, rect.origin.y + radius)];

	// Bottom left (origin):
	[path appendBezierPathWithArcWithCenter:innerRect.origin radius:radius startAngle:180.0 endAngle:270.0 ];

	// Bottom right:
	[path appendBezierPathWithArcWithCenter:NSMakePoint( NSMaxX(innerRect), NSMinY(innerRect)) radius:radius startAngle:270.0 endAngle:360.0 ];

	// Top right:
	[path appendBezierPathWithArcWithCenter:NSMakePoint( NSMaxX(innerRect), NSMaxY(innerRect)) radius:radius startAngle:0.0  endAngle:90.0 ];

	// Top left:
	[path appendBezierPathWithArcWithCenter:NSMakePoint( NSMinX(innerRect),NSMaxY(innerRect)) radius:radius startAngle:90.0  endAngle:180.0 ];
	[path closePath];   // Implicitly creates left edge.

	return path;
}


#pragma mark -
+ (NSBezierPath*)	regularPolygon:(NSInteger) numberOfSides
{
	CGFloat			angle, radius = 0.5;
	NSInteger				i;
	NSBezierPath*	path = [NSBezierPath bezierPath];
	NSPoint			p;
	
	p.x = 0.5;
	p.y = 0.0;
	
	[path moveToPoint:p];
	
	for( i = 0; i < numberOfSides; i++ )
	{
		angle = (( 2 * pi * i ) / numberOfSides );
		
		p.x = radius * cosf( angle );
		p.y = radius * sinf( angle );
		
		[path lineToPoint:p];
	}
	
	p.x = 0.5;
	p.y = 0.0;
	[path lineToPoint:p];
	[path closePath];
	
	//[path appendBezierPathWithOvalInRect:[DKShapeFactory rectOfUnitSize]];
	
	return path;
}


#pragma mark -
+ (NSBezierPath*)	equilateralTriangle
{
	return [self regularPolygon:3];
}


+ (NSBezierPath*)	rightTriangle
{
	NSBezierPath* rtTrianglePath = [NSBezierPath bezierPath];
	
	NSPoint p;
	
	p.x = 0.5;
	p.y = 0.5;
	[rtTrianglePath moveToPoint:p];
	p.x = -0.5;
	[rtTrianglePath lineToPoint:p];
	p.x = 0.5;
	p.y = -0.5;
	[rtTrianglePath lineToPoint:p];
	p.y = 0.5;
	[rtTrianglePath lineToPoint:p];
	[rtTrianglePath closePath];
		
	return rtTrianglePath;
}


#pragma mark -
+ (NSBezierPath*)	pentagon
{
	return [self regularPolygon:5];
}


+ (NSBezierPath*)	hexagon
{
	return [self regularPolygon:6];
}


+ (NSBezierPath*)	heptagon
{
	return [self regularPolygon:7];
}


+ (NSBezierPath*)	octagon
{
	return [self regularPolygon:8];
}


#pragma mark -
+ (NSBezierPath*)	star:(NSInteger) numberOfPoints innerDiameter:(CGFloat) diam
{
	CGFloat			angle, radius = 0.5;
	NSInteger				i;
	NSBezierPath*	path = [NSBezierPath bezierPath];
	NSPoint			p;
	
	if ( diam > 1.0 )
		diam = 1.0;
	
	p.x = 0.5;
	p.y = 0.0;
	
	[path moveToPoint:p];
	
	for( i = 0; i < ( numberOfPoints * 2 ); i++ )
	{
		angle = (( pi * i ) / numberOfPoints );
		
		if (( i % 2 ) == 0 )
		{
			p.x = radius * cosf( angle );
			p.y = radius * sinf( angle );
		}
		else
		{
			p.x = diam * cosf( angle ) / 2.0;
			p.y = diam * sinf( angle ) / 2.0;
		}
		
		[path lineToPoint:p];
	}
	
	p.x = 0.5;
	p.y = 0.0;
	[path lineToPoint:p];
	[path closePath];
	
	return path;
}


+ (NSBezierPath*)	regularStar:(NSInteger) numberOfPoints
{
	#pragma unused(numberOfPoints)
	
	// a regular star has points evenly distributed but also the inner radius is computed such that a straight line connects alternate
	// points. TO DO
	
	
	return nil;
}


+ (NSBezierPath*)	cross
{
	NSBezierPath* path = [NSBezierPath bezierPath];
	[path moveToPoint:NSMakePoint( 0, -0.5 )];
	[path lineToPoint:NSMakePoint( 0, 0.5 )];
	[path moveToPoint:NSMakePoint( -0.5, 0 )];
	[path lineToPoint:NSMakePoint( 0.5, 0 )];
	return path;
}


+ (NSBezierPath*)	diagonalCross
{
	NSBezierPath* path = [NSBezierPath bezierPath];
	[path moveToPoint:NSMakePoint( -0.5, -0.5 )];
	[path lineToPoint:NSMakePoint( 0.5, 0.5 )];
	[path moveToPoint:NSMakePoint( 0.5, -0.5 )];
	[path lineToPoint:NSMakePoint( -0.5, 0.5 )];
	return path;
}



#pragma mark -
+ (NSBezierPath*)	ring:(CGFloat) innerDiameter
{
	NSBezierPath* path = [NSBezierPath bezierPathWithOvalInRect:[self rectOfUnitSize]];
	
	if ( innerDiameter > 1.0 )
		innerDiameter = 1.0;
	
	CGFloat	rad = innerDiameter * 0.5f;
	NSRect	r = NSMakeRect( -rad, -rad, innerDiameter, innerDiameter );
	
	[path appendBezierPathWithOvalInRect:r];
	[path setWindingRule:NSEvenOddWindingRule];
	
	return path;
}


+ (NSBezierPath*)	roundRectSpeechBalloon:(NSInteger) sbParams cornerRadius:(CGFloat) cr
{
	return [self roundRectSpeechBalloonInRect:[self rectOfUnitSize] params:sbParams cornerRadius:cr];
}


+ (NSBezierPath*)	roundRectSpeechBalloonInRect:(NSRect) rect params:(NSInteger) sbParams cornerRadius:(CGFloat) cr
{
	// speech ballon is a round rect with a straight spur going to one corner. The spur occupies 1/4 of the height or width of the
	// overall bounds rectangle. The params set on which edge and which way the spur points.
	
	NSRect		mainRect = rect;
	
	// calculate the main rect as the main part of the shape excluding the spur.
	
	if (( sbParams & kDKSpeechBalloonEdgeMask ) == kDKSpeechBalloonLeftEdge )
	{
		mainRect.origin.x += rect.size.width / 4.0;
		mainRect.size.width -= rect.size.width / 4.0;
	}
	else if (( sbParams & kDKSpeechBalloonEdgeMask ) == kDKSpeechBalloonRightEdge )
	{
		mainRect.size.width -= rect.size.width / 4.0;
	}
	else if (( sbParams & kDKSpeechBalloonEdgeMask ) == kDKSpeechBalloonTopEdge )
	{
		mainRect.size.height -= rect.size.height / 4.0;
	}
	else if (( sbParams & kDKSpeechBalloonEdgeMask ) == kDKSpeechBalloonBottomEdge )
	{
		mainRect.origin.y += rect.size.height / 4.0;
		mainRect.size.height -= rect.size.height / 4.0;
	}
	
	// Make sure radius doesn't exceed a maximum size
	
	if( cr >= (mainRect.size.height /2) )
		cr = _CGFloatTrunc(mainRect.size.height /2) -1;
	
	if( cr >= (mainRect.size.width /2) )
		cr = _CGFloatTrunc(mainRect.size.width /2) -1;
	
	// Now draw our rectangle:
	NSRect			innerRect = NSInsetRect( mainRect, cr, cr );	// Make rect with corners being centers of the corner circles.
	NSBezierPath*	path = [NSBezierPath bezierPath];

	[path moveToPoint: NSMakePoint( mainRect.origin.x, mainRect.origin.y + cr)];

	// top left (origin):
	[path appendBezierPathWithArcWithCenter:innerRect.origin radius:cr startAngle:180.0 endAngle:270.0 ];
	
	// if the spur is at top left, draw it now
	
	if ( sbParams == ( kDKSpeechBalloonBottomEdge | kDKSpeechBalloonPointsLeft ))
	{
		[path lineToPoint: rect.origin ];	// bottom left corner
		[path lineToPoint: NSMakePoint( rect.origin.x + ( cr * 2.0 ), NSMinY( mainRect ))];
		[path lineToPoint: NSMakePoint( NSMaxX( innerRect ), NSMinY( mainRect ))];
	}
	else if ( sbParams == ( kDKSpeechBalloonBottomEdge | kDKSpeechBalloonPointsRight ))
	{
		[path lineToPoint: NSMakePoint( NSMaxX( innerRect ) - cr, NSMinY( mainRect ))];
		[path lineToPoint: NSMakePoint( NSMaxX( rect ), NSMinY( rect ))];
		[path lineToPoint: NSMakePoint( NSMaxX( innerRect ), NSMinY( mainRect ))];
	}
	else
		[path relativeLineToPoint: NSMakePoint(NSWidth(innerRect), 0.0) ];		// Bottom edge.

	// top right:
	[path appendBezierPathWithArcWithCenter:NSMakePoint( NSMaxX(innerRect), NSMinY(innerRect)) radius:cr startAngle:270.0 endAngle:360.0 ];
	
	// spur on right
	
	if (( sbParams & kDKSpeechBalloonEdgeMask ) == kDKSpeechBalloonRightEdge )
	{
		if ( sbParams & kDKSpeechBalloonPointsUp )
		{
			[path lineToPoint: NSMakePoint( NSMaxX( rect ), NSMinY( rect ))];
			[path lineToPoint: NSMakePoint( NSMaxX( mainRect ), NSMinY ( innerRect ) + cr )];
			[path lineToPoint: NSMakePoint( NSMaxX( mainRect ), NSMaxY( innerRect ))];
		}
		else
		{
			[path lineToPoint: NSMakePoint( NSMaxX( mainRect ), NSMaxY( innerRect ) - cr )];
			[path lineToPoint: NSMakePoint( NSMaxX( rect ), NSMaxY( rect ))];
			[path lineToPoint: NSMakePoint( NSMaxX( mainRect ), NSMaxY( innerRect ))];
		}
	}
	else
		[path relativeLineToPoint: NSMakePoint(0.0, NSHeight(innerRect)) ];		// Right edge.

	// bottom right:
	[path appendBezierPathWithArcWithCenter:NSMakePoint( NSMaxX(innerRect), NSMaxY(innerRect)) radius:cr startAngle:0.0  endAngle:90.0 ];
	
	// spur on bottom:
	if (( sbParams & kDKSpeechBalloonEdgeMask ) == kDKSpeechBalloonTopEdge )
	{
		if ( sbParams & kDKSpeechBalloonPointsRight )
		{
			[path lineToPoint: NSMakePoint( NSMaxX( rect ), NSMaxY( rect ))];
			[path lineToPoint: NSMakePoint( NSMaxX( innerRect) - cr, NSMaxY( mainRect ))];
			[path lineToPoint: NSMakePoint( NSMinX( innerRect ), NSMaxY( mainRect ))];
		}
		else
		{
			[path lineToPoint: NSMakePoint( NSMinX( innerRect ) + cr, NSMaxY( mainRect ))];
			[path lineToPoint: NSMakePoint( NSMinX( rect ), NSMaxY( rect ))];
			[path lineToPoint: NSMakePoint( NSMinX( innerRect), NSMaxY( mainRect ))];
		}
	}
	else
		[path relativeLineToPoint: NSMakePoint( -NSWidth(innerRect), 0.0) ];	// Top edge.

	// bottom left:
	[path appendBezierPathWithArcWithCenter:NSMakePoint( NSMinX(innerRect),NSMaxY(innerRect)) radius:cr startAngle:90.0  endAngle:180.0 ];
	
	// spur on left:
	
	if (( sbParams & kDKSpeechBalloonEdgeMask ) == kDKSpeechBalloonLeftEdge )
	{
		if ( sbParams & kDKSpeechBalloonPointsUp )
		{
			[path lineToPoint: NSMakePoint( NSMinX( mainRect ), NSMinY( innerRect ) + cr )];
			[path lineToPoint: NSMakePoint( NSMinX( rect ), NSMinY( rect ))];
			[path lineToPoint: NSMakePoint( NSMinX( mainRect ), NSMinY( innerRect ))];
		}
		else
		{
			[path lineToPoint: NSMakePoint( NSMinX( rect ), NSMaxY( rect ))];
			[path lineToPoint: NSMakePoint( NSMinX( mainRect ), NSMaxY( innerRect ) - cr )];
			[path lineToPoint: NSMakePoint( NSMinX( mainRect), NSMinY( innerRect ))];
		}
	}
	else
		[path lineToPoint: NSMakePoint( NSMinX( mainRect ), NSMinY( innerRect )) ];	// left edge.

	[path closePath];   // Implicitly creates left edge.

	return path;
}


+ (NSBezierPath*)	ovalSpeechBalloon:(NSInteger) sbParams
{
	#pragma unused(sbParams)
	
	// TO DO
	
	return nil;
}


+ (NSBezierPath*)	arrowhead
{
	NSBezierPath* sArrowhead = nil;
	
	NSRect r = [self rectOfUnitSize];
	sArrowhead = [NSBezierPath bezierPath];

	[sArrowhead moveToPoint:NSMakePoint( NSMinX( r ), NSMidY( r ))];
	[sArrowhead lineToPoint:NSMakePoint( NSMaxX( r ), NSMinY( r ))];
	[sArrowhead lineToPoint:NSMakePoint( NSMaxX( r ), NSMaxY( r ))];
	[sArrowhead closePath];
	
	return sArrowhead;
}


+ (NSBezierPath*)	arrowTailFeather
{
	return [self arrowTailFeatherWithRake:0.5];
}


+ (NSBezierPath*)	arrowTailFeatherWithRake:(CGFloat) rakeFactor
{
	// the rakeFactor is how far back the feather is swept - can be a value from 0..1
	
	rakeFactor = LIMIT( rakeFactor, 0, 1 ) * 0.5f;

	NSBezierPath*	feather = [NSBezierPath bezierPath];
	NSPoint			p = NSMakePoint( -0.5 + rakeFactor, 0 );
	
	[feather moveToPoint:p];
	p.x = -0.5;
	p.y = -0.5;
	[feather lineToPoint:p];
	p.x = 0.5 - rakeFactor;
	[feather lineToPoint:p];
	p.x = 0.5;
	p.y = 0;
	[feather lineToPoint:p];
	p.x = 0.5 - rakeFactor;
	p.y = 0.5;
	[feather lineToPoint:p];
	p.x = -0.5;
	[feather lineToPoint:p];
	[feather closePath];
	
	return feather;
}


+ (NSBezierPath*)	inflectedArrowhead
{
	NSBezierPath*	arrow = [NSBezierPath bezierPath];
	
	[arrow moveToPoint:NSMakePoint( -0.5, 0 )];
	[arrow lineToPoint:NSMakePoint( 0.5, -0.5 )];
	[arrow lineToPoint:NSMakePoint(0.25, 0 )];
	[arrow lineToPoint:NSMakePoint( 0.5, 0.5 )];
	[arrow closePath];
	 
	return arrow;
}


#pragma mark -
+ (NSBezierPath*)	roundEndedRect:(NSRect) rect
{
	// returns a rect with rounded ends (half circles). If <rect> is square this returns a circle. The rounded ends are applied
	// to the shorter sides.
	
	if ( rect.size.width == rect.size.height )
		return [NSBezierPath bezierPathWithOvalInRect:rect];
	else
	{
		NSSize	rs = rect.size;
		BOOL	vertical = ( rs.width < rs.height );
		CGFloat	radius = MIN( rs.width, rs.height );
		
		radius /= 2.0;
		
		NSBezierPath* path = [NSBezierPath bezierPath];
		
		if ( ! vertical )
		{
			[path moveToPoint:NSMakePoint( NSMinX( rect ) + radius, NSMinY( rect ))];
			[path appendBezierPathWithArcWithCenter:NSMakePoint( NSMaxX( rect ) - radius, NSMinY( rect) + radius ) radius:radius startAngle:270.0 endAngle:90.0 ];
			[path appendBezierPathWithArcWithCenter:NSMakePoint( NSMinX( rect ) + radius, NSMinY( rect) + radius ) radius:radius startAngle:90.0 endAngle:270.0 ];
		}
		else
		{
			[path moveToPoint:NSMakePoint( NSMaxX( rect ), NSMinY( rect ) + radius)];
			[path appendBezierPathWithArcWithCenter:NSMakePoint( NSMinX( rect ) + radius, NSMaxY( rect) - radius ) radius:radius startAngle:0.0 endAngle:180.0 ];
			[path appendBezierPathWithArcWithCenter:NSMakePoint( NSMinX( rect ) + radius, NSMinY( rect) + radius ) radius:radius startAngle:180.0 endAngle:0.0 ];
		}
		
		[path closePath];
		
		return path;
	}
}


#pragma mark -
+ (NSBezierPath*)	pathFromGlyph:(NSString*) glyph inFontWithName:(NSString*) fontName
{
	// returns a path at the origin representing the glyph of the letter passed. This may need some adjustment to use in a shape.
	// the character will be drawn "upside down" in a DKDrawingView unless the object that owns this path creates an appropriate transform.
	
	NSFont*			font = [NSFont fontWithName:fontName size:1];
	NSBezierPath*	path = [NSBezierPath bezierPath];
	NSPoint			p = NSMakePoint( -0.5, -0.5 );
	
	[path moveToPoint:p];
	[path appendBezierPathWithGlyph:[font glyphWithName:glyph] inFont:font];

	return path;
}


#pragma mark -
- (NSBezierPath*)	roundRectInRect:(NSRect) bounds objParam:(id) param
{
	return [[self class] roundRectInRect:bounds andCornerRadius:[param doubleValue]];
}


- (NSBezierPath*)	roundEndedRect:(NSRect) rect objParam:(id) param
{
	#pragma unused(param)
	
//	LogEvent_(kInfoEvent, @"rr-rect: {%f,%f},{%f,%f}", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height );
	
	return [[self class] roundEndedRect:rect];
}


- (NSBezierPath*)	speechBalloonInRect:(NSRect) rect objParam:(id) param
{
	// param is a dictionary containing the following parameters:
	// key = kDKSpeechBalloonType, value = type flags (NSNumber as integer)
	// key = kDKSpeechBalloonCornerRadius, value = radius (NSNumber as float)
	NSInteger		sbtype = kDKStandardSpeechBalloon;
	CGFloat	radius = 16.0;
	
	if ([param isKindOfClass:[NSDictionary class]])
	{
		NSDictionary* p = (NSDictionary*) param;
	
		sbtype = [[p objectForKey:kDKSpeechBalloonType] integerValue];
		radius = [[p objectForKey:kDKSpeechBalloonCornerRadius] doubleValue];
	}
	
	return [[self class] roundRectSpeechBalloonInRect:rect params:sbtype cornerRadius:radius];
}


#pragma mark -
#pragma mark - As part of the NSCoding protocol

- (id)			initWithCoder:(NSCoder*) coder
{
	#pragma unused(coder)
	return self;
}

- (void)		encodeWithCoder:(NSCoder*) coder
{
	#pragma unused(coder)

}


@end
