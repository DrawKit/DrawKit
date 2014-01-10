/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import "DKRastGroup.h"

/**
Simple render group subclass that applies the set blend mode to the context for all of the renderers it contains,
yielding a wide range of available effects.
*/
@interface DKQuartzBlendRastGroup : DKRastGroup <NSCoding, NSCopying> {
    CGBlendMode m_blendMode;
    CGFloat m_alpha;
    NSImage* m_maskImage;
}

- (void)setBlendMode:(CGBlendMode)mode;
- (CGBlendMode)blendMode;

- (void)setAlpha:(CGFloat)alpha;
- (CGFloat)alpha;

- (void)setMaskImage:(NSImage*)image;
- (NSImage*)maskImage;

@end
