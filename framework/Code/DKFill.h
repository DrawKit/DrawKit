///**********************************************************************************************************************************
///  DKFill.h
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 25/11/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKRasterizer.h"


@class DKGradient;


@interface DKFill : DKRasterizer <NSCoding, NSCopying>
{
@private
	NSColor*		m_fillColour;
	NSShadow*		m_shadow;
	DKGradient*		m_gradient;
	BOOL			m_angleTracksObject;	// set if gradient angle remains relative to the object being filled
}

+ (DKFill*)			fillWithColour:(NSColor*) colour;
+ (DKFill*)			fillWithGradient:(DKGradient*) gradient;
+ (DKFill*)			fillWithPatternImage:(NSImage*) image;
+ (DKFill*)			fillWithPatternImageNamed:(NSString*) path;

- (void)			setColour:(NSColor*) colour;
- (NSColor*)		colour;

- (void)			setShadow:(NSShadow*) shadow;
- (NSShadow*)		shadow;

- (void)			setGradient:(DKGradient*) grad;
- (DKGradient*)		gradient;

- (void)			setTracksObjectAngle:(BOOL) toa;
- (BOOL)			tracksObjectAngle;

@end


/*

A renderer that implements a colour fill with optional shadow. Note that the shadow is applied only to the path rendered
by this fill, and has no side effects.

This can also have a gradient property (gradient were formerly renderers, but now they are not, for parity with gradient panel).

A gradient takes precedence over a solid fill; any shadow is based on the solid fill however. If the gradient contains transparent
areas the solid fill will show through.

*/
