/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKStroke.h"

/** @brief DKRoughStroke is a stroke rasterizer that randomly varies the stroke width about its nominal set width by some factor.

DKRoughStroke is a stroke rasterizer that randomly varies the stroke width about its nominal set width by some factor. The result is a rough stroke
that looks much more naturalistic than a standard one, which is very useful for illustration work.

The nominal width, colour, etc are all inherited from DKStroke. <roughness> is the amount of randomness and is a fraction of the stroke width.

Because a roughened path is both fairly complicated to compute and has a lot of randomness that is different every time, this object caches the roughened
paths it generates and re-uses them as much as it can. A path is cached based on its bounds, width and length, giving a key that is likely to be unique in practice.
Paths are cached up to the maximum number set by the constant, after which least used cached paths are discarded.
*/
@interface DKRoughStroke : DKStroke <NSCoding, NSCopying> {
@private
	CGFloat mRoughness;
	NSMutableDictionary* mPathCache;
	NSMutableArray* mCacheList;
}

/**  */
- (void)setRoughness:(CGFloat)roughness;
- (CGFloat)roughness;

@property CGFloat roughness;

- (NSString*)pathKeyForPath:(NSBezierPath*)path;
- (void)invalidateCache;
- (NSBezierPath*)roughPathFromPath:(NSBezierPath*)path;

@end

#define kDKRoughPathCacheMaximumCapacity 99
