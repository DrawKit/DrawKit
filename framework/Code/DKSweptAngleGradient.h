///**********************************************************************************************************************************
///  DKSweptAngleGradient.h
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 13/07/2007.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKGradient.h"


typedef union
{
	unsigned long pixel;
	struct
	{
		unsigned char a;
		unsigned char r;
		unsigned char g;
		unsigned char b;
	}
	c;
}
pix_int;



@interface DKSweptAngleGradient : DKGradient
{
	CGImageRef		m_sa_image;
	CGContextRef	m_sa_bitmap;
	pix_int*		m_sa_colours;
	NSInteger				m_sa_segments;
	NSPoint			m_sa_centre;
	CGFloat			m_sa_startAngle;
	NSInteger				m_sa_img_width;
	BOOL			m_ditherColours;
}

+ (DKGradient*)		sweptAngleGradient;
+ (DKGradient*)		sweptAngleGradientWithStartingColor:(NSColor*) c1 endingColor:(NSColor*) c2;

- (void)			setNumberOfAngularSegments:(NSInteger) ns;
- (NSInteger)				numberOfAngularSegments;

- (void)			preloadColours;
- (void)			createGradientImageWithRect:(NSRect) rect;
- (void)			invalidateCache;

@end
