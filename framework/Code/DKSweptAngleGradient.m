///**********************************************************************************************************************************
///  DKSweptAngleGradient.m
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 13/07/2007.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKSweptAngleGradient.h"

#import "DKGeometryUtilities.h"
#import "DKRandom.h"
#import "LogEvent.h"


@interface DKGradient (Private)
- (void)			private_colorAtValue:(CGFloat) val components:(CGFloat*) components randomAccess:(BOOL) ra;
@end


#pragma mark -
@implementation DKSweptAngleGradient
#pragma mark As a DKSweptAngleGradient

+ (DKGradient*)		sweptAngleGradient
{
	return [self sweptAngleGradientWithStartingColor:[NSColor whiteColor] endingColor:[NSColor blackColor]];
}


+ (DKGradient*)		sweptAngleGradientWithStartingColor:(NSColor*) c1 endingColor:(NSColor*) c2
{
	DKSweptAngleGradient* sa = [[DKSweptAngleGradient alloc] init];
	
	[sa addColor:c1 at:0];
	[sa addColor:c2 at:1];
	
	return [sa autorelease];
}


#pragma mark -

- (void)			setNumberOfAngularSegments:(NSInteger) ns
{
	m_sa_segments = ns;
}


- (NSInteger)				numberOfAngularSegments
{
	return m_sa_segments;
}



- (void)			preloadColours
{
	// creates a cache of colours representing the complete gradient preformatted in the pixel format of the image. This cache
	// is then used to look up the colour value for a pixel when building the image much faster than computing it directly.
	
	NSInteger i;
	
	if ( m_sa_colours )
		free( m_sa_colours );
		
	m_sa_colours = malloc( sizeof(pix_int) * m_sa_segments );
	
	if ( m_sa_colours )
	{
		CGFloat	components[4];
		CGFloat	v;
		
		for( i = 0; i < m_sa_segments; ++i )
		{
			v = (CGFloat) i / (CGFloat)(m_sa_segments - 1);
			
			[self private_colorAtValue:v components:components randomAccess:NO];
		
			m_sa_colours[i].c.a = components[3] * 255;

			// colours in image are premultiplied by alpha, so do that
			
			m_sa_colours[i].c.r = components[0] * components[3] * 255;
			m_sa_colours[i].c.g = components[1] * components[3] * 255;
			m_sa_colours[i].c.b = components[2] * components[3] * 255;
		}
	}
}


- (void)			createGradientImageWithRect:(NSRect) rect
{
	CGColorSpaceRef		cSpace = CGColorSpaceCreateWithName( kCGColorSpaceGenericRGB );
	NSUInteger			width, height;
	
	// directly create a bitmap context of the desired size then convert it to an image - this is much easier than messing about with data
	// providers, etc
	
	width = MAX( 1, (NSInteger)( rect.size.width * 1.5f));
	height = MAX( 1, (NSInteger)( rect.size.height * 1.5f ));
	
	NSUInteger		bufferSize = 4 * width * ( height + 1 );
	unsigned char*	buffer;
	
	buffer = (unsigned char*) malloc( bufferSize );
	
	if ( buffer )
	{
		m_sa_bitmap = CGBitmapContextCreate( buffer, width, height, 8, 4 * width, cSpace, kCGImageAlphaPremultipliedFirst );
		
		LogEvent_(kInfoEvent, @"bitmap = %@", m_sa_bitmap );
		
		// scan through the buffer and set all the pixels
		
		NSPoint		cp = m_sa_centre;
		
		cp.x -= rect.origin.x;
		cp.y -= rect.origin.y;
		
		pix_int*	colours = m_sa_colours;
		NSUInteger	nColours = m_sa_segments;
		CGFloat		angle, twopi;
		NSUInteger	x,	y, colour;
		
		// offset cp to account for 50% extra size of the image
		
		cp.x *= 1.5;
		cp.y *= 1.5;
		twopi = 2 * pi;
		
		unsigned long* p = (unsigned long*) buffer;
		
		for( y = 0; y < height; ++y )
		{
			for( x = 0; x < width; ++x )
			{
				// need to know angle of x,y relative to centre point which gives us an index into the colour table
				
				angle = atan2f((CGFloat) y - cp.y, (CGFloat) x - cp.x ) + pi;
				colour = (NSUInteger)(( angle * (CGFloat) nColours ) / twopi );
				
				// add a bit of random dither to the colour
				
				if ( m_ditherColours )
					colour = (NSInteger)( colour + [DKRandom randomPositiveOrNegativeNumber] * 2.0 ) % nColours;
					
				// write the colour to the image in one fell swoop
				
				*p++ = colours[colour].pixel;
			}
		}
		
		// convert to an image.
		
		m_sa_image = CGBitmapContextCreateImage( m_sa_bitmap );
	}
	
	CGColorSpaceRelease( cSpace );
}


- (void)			invalidateCache
{
	unsigned char*	buffer;

	if ( m_sa_image )
	{
		CGImageRelease( m_sa_image );
		m_sa_image = NULL;
		buffer = CGBitmapContextGetData( m_sa_bitmap );
		free( buffer );
		CGContextRelease( m_sa_bitmap );
		m_sa_bitmap = NULL;
	}
}


#pragma mark -
#pragma mark As a DKGradient
- (void)			fillPath:(NSBezierPath*) path startingAtPoint:(NSPoint) p startRadius:(CGFloat) sr endingAtPoint:(NSPoint) ep endRadius:(CGFloat) er
{
	#pragma unused(sr)
	#pragma unused(ep)
	#pragma unused(er)
	
	NSInteger		segments = [self numberOfAngularSegments];
	NSRect	rect = [path bounds];
	CGFloat	sa = [self angle];
	BOOL	inval = NO;
	
	if ( segments == 0 )
		segments = 512;
		
	if ( segments != m_sa_segments )
	{
		m_sa_segments = MAX( segments, 2 );
		inval = YES;
	}

	if ( m_sa_image != NULL && (rect.size.width > CGImageGetWidth( m_sa_image ) || rect.size.height > CGImageGetHeight( m_sa_image )))
		inval = YES;
		
	if( m_sa_image == NULL )
		inval = YES;
	
	if ( inval )
	{
		m_sa_centre = p;
		[self invalidateCache];
		[self preloadColours];
		[self createGradientImageWithRect:rect];
	}
	
	// centre the image rect on <rect>, rotated to <sa>
	
	NSPoint rcp = NSMakePoint( NSMidX( rect ), NSMidY( rect ));
	NSRect imgRect = NSMakeRect( 0, 0, CGImageGetWidth( m_sa_image ), CGImageGetHeight( m_sa_image ));
	
	rect.origin.x = -rect.size.width / 2;
	rect.origin.y = -rect.size.height / 2;
	
	NSRect ir = CentreRectInRect( imgRect, rect );
	
	SAVE_GRAPHICS_CONTEXT		//[NSGraphicsContext saveGraphicsState];
	[path addClip];

	CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
	
	CGContextTranslateCTM( context, rcp.x, rcp.y );
	CGContextRotateCTM( context, sa );
	
	CGContextDrawImage( context, *(CGRect*)&ir, m_sa_image );
	RESTORE_GRAPHICS_CONTEXT	//[NSGraphicsContext restoreGraphicsState];
}


#pragma mark -
#pragma mark As an NSObject
- (id)				init
{
	self = [super init];
	if (self != nil)
	{
		NSAssert(m_sa_image == nil, @"Expected init to zero");
		NSAssert(m_sa_bitmap == nil, @"Expected init to zero");
		NSAssert(m_sa_colours == nil, @"Expected init to zero");
		NSAssert(m_sa_segments == 0, @"Expected init to zero");
		NSAssert(NSEqualPoints(m_sa_centre, NSZeroPoint), @"Expected init to zero");
		NSAssert(m_sa_startAngle == 0, @"Expected init to zero");
		NSAssert(m_sa_img_width == 0, @"Expected init to zero");
		NSAssert(!m_ditherColours, @"Expected init to NO");

		[self setGradientType:kDKGradientSweptAngle];
	}
	return self;
}


- (void)			dealloc
{
	[self invalidateCache];
	[super dealloc];
}


@end

