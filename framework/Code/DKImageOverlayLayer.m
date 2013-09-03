//
//  DKImageOverlayLayer.m
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by graham on 28/08/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//

#import "DKImageOverlayLayer.h"

#import "DKDrawing.h"



@implementation DKImageOverlayLayer
#pragma mark As a DKImageOverlayLayer
- (id)			initWithImage:(NSImage*) image
{
	self = [self init];
	if (self != nil)
	{
		[self setImage:image];
		[self setOpacity:1.0];
		[self setCoverageMethod:kDKDrawingImageCoverageNormal];
		
		if (m_image == nil)
		{
			[self autorelease];
			self = nil;
		}
	}
	
	return self;
}


- (id)			initWithContentsOfFile:(NSString*) imagefile
{
	NSImage* img = [[[NSImage alloc] initWithContentsOfFile:imagefile] autorelease];
	return [self initWithImage:img];
}


#pragma mark -
- (void)		setImage:(NSImage*) image
{
	[image retain];
	[m_image release];
	m_image = image;
	[m_image setFlipped:YES];
}


- (NSImage*)	image
{
	return m_image;
}


#pragma mark -
- (void)		setOpacity:(CGFloat) op
{
	if ( op != m_opacity )
	{
		m_opacity = op;
		[self setNeedsDisplay:YES];
	}
}


- (CGFloat)		opacity
{
	return m_opacity;
}


#pragma mark -
- (void)		setCoverageMethod:(DKImageCoverageFlags) cm
{
	if ( cm != m_coverageMethod )
	{
		m_coverageMethod = cm;
		[self setNeedsDisplay:YES];
	}
}


- (DKImageCoverageFlags) coverageMethod
{
	return m_coverageMethod;
}


#pragma mark -
- (NSRect)		imageDestinationRect
{
	// return the image destination rect according to the coverage method. Note that if we are tiling, the drawing
	// size in that dimension is returned - thus you need to check further which coverage method is in use - the
	// rect alone doesn't tell you.
	
	NSSize	ds = [[self drawing] drawingSize];
	NSSize	is = [[self image] size];
	NSRect	r = NSZeroRect;
	
	r.size = is;
	NSInteger cm = [self coverageMethod];
	
	if ( cm & kDKDrawingImageCoverageHorizontallyCentred )
		r.origin.x = ( ds.width / 2.0 ) - ( is.width / 2.0 );
	else if ( cm & ( kDKDrawingImageCoverageHorizontallyStretched | kDKDrawingImageCoverageHorizontallyTiled))
		r.size.width = ds.width;
		
	if ( cm & kDKDrawingImageCoverageVerticallyCentred )
		r.origin.y = ( ds.height / 2.0 ) - ( is.height / 2.0 );
	else if ( cm & ( kDKDrawingImageCoverageVerticallyStretched | kDKDrawingImageCoverageVerticallyTiled ))
		r.size.height = ds.height;
		
	return r;
}


#pragma mark -
#pragma mark As a DKLayer
- (void)		drawRect:(NSRect) rect inView:(DKDrawingView*) aView
{
	#pragma unused(aView)
	
	NSRect dr = [self imageDestinationRect];
	
	if ( NSIntersectsRect( rect, dr ))
	{
		DKImageCoverageFlags cm = [self coverageMethod];
		
		if ( cm & ( kDKDrawingImageCoverageVerticallyTiled | kDKDrawingImageCoverageHorizontallyTiled))
		{
			// some tiling to do here
			
			NSRect	ri = dr;
			NSSize ds = [[self drawing] drawingSize];
			
			if ( cm & kDKDrawingImageCoverageVerticallyStretched )
				ri.size.height = ds.height;
			else
				ri.size.height = [[self image] size].height;
				
			if ( cm & kDKDrawingImageCoverageHorizontallyStretched )
				ri.size.width = ds.width;
			else
				ri.size.width = [[self image] size].width;
			
			NSInteger h, v, x, y;
			
			if ( cm & kDKDrawingImageCoverageHorizontallyTiled )
				h = 1 + _CGFloatTrunc(ds.width / ri.size.width);
			else
				h = 1;
			
			if ( cm & kDKDrawingImageCoverageVerticallyTiled )
				v = 1 + _CGFloatTrunc(ds.height / ri.size.height);
			else
				v = 1;
			
			for( y = 0; y < v; ++y )
			{
				for( x = 0; x < h; ++x )
				{
					[[self image] drawInRect:ri fromRect:NSZeroRect operation:NSCompositeSourceAtop fraction:[self opacity]];
					ri.origin.x += ri.size.width;
				}
				ri.origin.x = dr.origin.x;
				ri.origin.y += ri.size.height;
			}
		}
		else
		{
			// straightforward composition of the image
			
			[[self image] drawInRect:dr fromRect:NSZeroRect operation:NSCompositeSourceAtop fraction:[self opacity]];
		}
	}
}


#pragma mark -
#pragma mark As an NSObject
- (void)		dealloc
{
	[m_image release];
	
	[super dealloc];
}


#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)		encodeWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];
	
	[coder encodeObject:[self image] forKey:@"image"];
	[coder encodeDouble:[self opacity] forKey:@"opacity"];
	[coder encodeInteger:[self coverageMethod] forKey:@"coveragemethod"];
}


- (id)			initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super initWithCoder:coder];
	if (self != nil)
	{
		[self setImage:[coder decodeObjectForKey:@"image"]];
		[self setOpacity:[coder decodeDoubleForKey:@"opacity"]];
		[self setCoverageMethod:[coder decodeIntegerForKey:@"coveragemethod"]];
		
		if (m_image == nil)
		{
			[self autorelease];
			self = nil;
		}
	}
	return self;
}


@end
