/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
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

@property CGBlendMode blendMode;
@property CGFloat alpha;
@property (strong) NSImage *maskImage;

@end
