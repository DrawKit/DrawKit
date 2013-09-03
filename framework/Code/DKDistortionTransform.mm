///**********************************************************************************************************************************
///  DKDistortionTransform.m
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 27/10/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKDistortionTransform.h"

extern "C" {
#import "DKGeometryUtilities.h"
}


#define qUseAgg		0


#if qUseAgg
#import "agg_trans_perspective.h"
#endif

#pragma mark Static Functions
static inline float	MMul( float a, float b, float c, float d )
{
	return a*d-b*c;
}

static inline void	VP(float *px, float *py, float x1, float y1, float x2, float y2, float x3, float y3, float x4, float y4)
{
  float d = MMul(x1-x2,y1-y2,x3-x4,y3-y4);
  
  if (d==0.0f)
    d = 1.0f;
  
  *px = MMul(MMul(x1,y1,x2,y2),x1-x2,MMul(x3,y3,x4,y4),x3-x4)/d;
  *py = MMul(MMul(x1,y1,x2,y2),y1-y2,MMul(x3,y3,x4,y4),y3-y4)/d;
}


static NSPoint	Map( NSPoint inPoint, NSSize sourceSize, NSPoint quad[4])
{
	// maps a point <inPoint> within a rect from 0,0 to <sourceSize> to a point within the quadrilateral defined by the four points in <quad>.
	
	NSPoint		p;
	
  VP( &p.x, &p.y,
    ((sourceSize.height-inPoint.y)*quad[0].x + (inPoint.y)*quad[3].x)/sourceSize.height, ((sourceSize.height-inPoint.y)*quad[0].y + inPoint.y*quad[3].y)/sourceSize.height,
    ((sourceSize.height-inPoint.y)*quad[1].x + (inPoint.y)*quad[2].x)/sourceSize.height, ((sourceSize.height-inPoint.y)*quad[1].y + inPoint.y*quad[2].y)/sourceSize.height,
    ((sourceSize.width-inPoint.x)*quad[0].x + (inPoint.x)*quad[1].x)/sourceSize.width, ((sourceSize.width-inPoint.x)*quad[0].y + inPoint.x*quad[1].y)/sourceSize.width,
    ((sourceSize.width-inPoint.x)*quad[3].x + (inPoint.x)*quad[2].x)/sourceSize.width, ((sourceSize.width-inPoint.x)*quad[3].y + inPoint.x*quad[2].y)/sourceSize.width);
	
	return p;
}


#pragma mark -
@implementation DKDistortionTransform
#pragma mark As a DKDistortionTransform

+ (DKDistortionTransform*)	transformWithInitialRect:(NSRect) rect
{
	DKDistortionTransform* dt = [[DKDistortionTransform alloc] initWithRect:rect];
	
	return [dt autorelease];
}


#pragma mark -
- (id)				initWithRect:(NSRect) rect
{
	self = [super init];
	if (self != nil)
	{
		NSPoint rp[4];
		
		rp[0] = NSMakePoint( NSMinX( rect ), NSMinY( rect ));
		rp[1] = NSMakePoint( NSMaxX( rect ), NSMinY( rect ));
		rp[2] = NSMakePoint( NSMaxX( rect ), NSMaxY( rect ));
		rp[3] = NSMakePoint( NSMinX( rect ), NSMaxY( rect ));

		[self setEnvelopePoints:rp];
		NSAssert(!m_inverted, @"Expected init to NO");
	}
	
	return self;
}


- (id)				initWithEnvelope:(NSPoint*) points
{
	self = [super init];
	if (self != nil)
	{
		[self setEnvelopePoints:points];
		NSAssert(!m_inverted, @"Expected init to NO");
	}
	
	return self;
}


#pragma mark -
- (void)			setEnvelopePoints:(NSPoint*) points
{
	m_q[0] = points[0];
	m_q[1] = points[1];
	m_q[2] = points[2];
	m_q[3] = points[3];
}


- (void)			getEnvelopePoints:(NSPoint*) points
{
	points[0] = m_q[0];
	points[1] = m_q[1];
	points[2] = m_q[2];
	points[3] = m_q[3];
}


- (NSRect)			bounds
{
	// returns a rect bounding the envelope points
	
	NSRect	r = NSZeroRect;
	int		i;
	
	for( i = 0; i < 4; ++i )
		r = NSUnionRect( r, NSInsetRect( NSRectFromTwoPoints( m_q[i], m_q[i] ), -1.0, -1.0 ));

	return r;
}


#pragma mark -
- (void)			offsetByX:(float) dx byY:(float) dy
{
	m_q[0].x += dx;
	m_q[1].x += dx;
	m_q[2].x += dx;
	m_q[3].x += dx;
	m_q[0].y += dy;
	m_q[1].y += dy;
	m_q[2].y += dy;
	m_q[3].y += dy;
}


- (void)			shearHorizontallyBy:(float) dx
{
	m_q[0].x += dx;
	m_q[1].x += dx;
	m_q[2].x -= dx;
	m_q[3].x -= dx;
}


- (void)			shearVerticallyBy:(float) dy
{
	m_q[0].y -= dy;
	m_q[3].y -= dy;
	m_q[1].y += dy;
	m_q[2].y += dy;
}


- (void)			differentialPerspectiveBy:(float) delta
{
	m_q[0].y += delta;
	m_q[1].y -= delta;
	m_q[2].y += delta;
	m_q[3].y -= delta;
}


#pragma mark -
- (void)			invert
{
	m_inverted = !m_inverted;
}


#pragma mark -
- (NSPoint)			transformPoint:(NSPoint) p fromRect:(NSRect) rect
{
#if qUseAgg
	
	double x1, y1, x2, y2;
	double quad[8];
	
	x1 = NSMinX( rect );
	y1 = NSMinY( rect );
	x2 = NSMaxX( rect );
	y2 = NSMaxY( rect );
	
	//x1,y1, x2,y2, x3,y3, x4,y4
	
	quad[0] = m_q[0].x;
	quad[1] = m_q[0].y;
	quad[2] = m_q[1].x;
	quad[3] = m_q[1].y;
	quad[4] = m_q[2].x;
	quad[5] = m_q[2].y;
	quad[6] = m_q[3].x;
	quad[7] = m_q[3].y;
	
	agg::trans_perspective	tfm(  x1, y1, x2, y2, quad );
	
	if ( m_inverted )
	{
		tfm.invert();
	}
	
	//if (tfm.is_valid())
	{
		double x, y;
	
		x = p.x;
		y = p.y;
		
		tfm.transform( &x, &y );
		
		p.x = x;
		p.y = y;
	}
	return p;

#else	
	NSPoint np = p;
	
	np.x -= rect.origin.x;
	np.y -= rect.origin.y;
	
	return Map( np, rect.size, m_q );
#endif
}


- (NSBezierPath*)	transformBezierPath:(NSBezierPath*) path
{
	// transforms every point in the path, making a new path
	
	NSBezierPath*		newPath = [path copy];
	NSPoint				ap[3];
	NSBezierPathElement	elem;
	int					i, ec;
	NSRect				bounds = [path controlPointBounds];
	
	[newPath removeAllPoints];
	ec = [path elementCount];
	
	for( i = 0; i < ec; ++i )
	{
		elem = [path elementAtIndex:i associatedPoints:ap];
		
		if ( elem == NSCurveToBezierPathElement )
		{
			ap[0] = [self transformPoint:ap[0] fromRect:bounds];
			ap[1] = [self transformPoint:ap[1] fromRect:bounds];
			ap[2] = [self transformPoint:ap[2] fromRect:bounds];
			
			[newPath curveToPoint:ap[2] controlPoint1:ap[0] controlPoint2:ap[1]];
		}
		else
		{
			ap[0] = [self transformPoint:ap[0] fromRect:bounds];
		
			switch( elem )
			{
				case NSMoveToBezierPathElement:
					[newPath moveToPoint:ap[0]];
					break;
					
				case NSLineToBezierPathElement:
					[newPath lineToPoint:ap[0]];
					break;
					
				case NSClosePathBezierPathElement:
					[newPath closePath];
					break;
					
				default:
					break;
			}
		}
	}
	
	return [newPath autorelease];
}


#pragma mark -
#pragma mark As part of NSCoding Protocol
- (id)				initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super init];
	if (self != nil)
	{
		m_q[0] = [coder decodePointForKey:@"q0"];
		m_q[1] = [coder decodePointForKey:@"q1"];
		m_q[2] = [coder decodePointForKey:@"q2"];
		m_q[3] = [coder decodePointForKey:@"q3"];
		m_inverted = [coder decodeBoolForKey:@"inverted"];
	}
	return self;
}


- (void)			encodeWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[coder encodePoint:m_q[0] forKey:@"q0"];
	[coder encodePoint:m_q[1] forKey:@"q1"];
	[coder encodePoint:m_q[2] forKey:@"q2"];
	[coder encodePoint:m_q[3] forKey:@"q3"];
	[coder encodeBool:m_inverted forKey:@"inverted"];
}


#pragma mark -
#pragma mark As part of NSCopying Protocol
- (id)				copyWithZone:(NSZone*) zone
{
	return [[[self class] allocWithZone:zone] initWithEnvelope:m_q];
}


@end
