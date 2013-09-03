///**********************************************************************************************************************************
///  DKQuartzBlendRastGroup.h
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 30/06/2007.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKRastGroup.h"


@interface DKQuartzBlendRastGroup : DKRastGroup <NSCoding, NSCopying>
{
	CGBlendMode				m_blendMode;
	CGFloat					m_alpha;
	NSImage*				m_maskImage;
}

- (void)					setBlendMode:(CGBlendMode) mode;
- (CGBlendMode)				blendMode;

- (void)					setAlpha:(CGFloat) alpha;
- (CGFloat)					alpha;

- (void)					setMaskImage:(NSImage*) image;
- (NSImage*)				maskImage;

@end



/*

Simple render group subclass that applies the set blend mode to the context for all of the renderers it contains,
yielding a wide range of available effects.


*/
