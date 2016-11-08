/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKRasterizer.h"

@class DKQuartzCache;

/** @brief This renderer draws the image along the path of another object spaced at <interval> distance.

This renderer draws the image along the path of another object spaced at <interval> distance. Each image is scaled by <scale> and is
rotated to be normal to the path unless _normalToPath is NO.

This prefers PDF image representations where the image contains one, preserving resolution as the drawing is scaled.
*/
@interface DKPathDecorator : DKRasterizer <NSCoding, NSCopying> {
@private
	NSImage* m_image;
	NSPDFImageRep* m_pdf;
	CGFloat m_scale;
	CGFloat m_interval;
	CGFloat m_leader;
	CGFloat m_leadInLength;
	CGFloat m_leadOutLength;
	CGFloat m_liloProportion;
	CGFloat mLateralOffset;
	CGFloat mWobblyness;
	CGFloat mScaleRandomness;
	BOOL mAlternateLateralOffsets;
	BOOL m_normalToPath;
	BOOL m_useChainMethod;
	DKQuartzCache* mDKCache;
	BOOL m_lowQuality;
@protected
	NSUInteger mPlacementCount;
	NSMutableArray* mWobbleCache;
	NSMutableArray* mScaleRandCache;
}

+ (DKPathDecorator*)pathDecoratorWithImage:(NSImage*)image;

- (id)initWithImage:(NSImage*)image;

- (void)setImage:(NSImage*)image;
- (NSImage*)image;
- (void)setUpCache;
- (void)setPDFImageRep:(NSPDFImageRep*)rep;

- (void)setScale:(CGFloat)scale;
- (CGFloat)scale;

- (void)setScaleRandomness:(CGFloat)scRand;
- (CGFloat)scaleRandomness;

- (void)setInterval:(CGFloat)interval;
- (CGFloat)interval;

- (void)setLeaderDistance:(CGFloat)leader;
- (CGFloat)leaderDistance;

- (void)setLateralOffset:(CGFloat)loff;
- (CGFloat)lateralOffset;
- (void)setLateralOffsetAlternates:(BOOL)alts;
- (BOOL)lateralOffsetAlternates;

- (void)setWobblyness:(CGFloat)wobble;
- (CGFloat)wobblyness;

- (void)setNormalToPath:(BOOL)normal;
- (BOOL)normalToPath;

- (void)setLeadInLength:(CGFloat)linLength;
- (void)setLeadOutLength:(CGFloat)loutLength;
- (CGFloat)leadInLength;
- (CGFloat)leadOutLength;

- (void)setLeadInAndOutLengthProportion:(CGFloat)proportion;
- (CGFloat)leadInAndOutLengthProportion;
- (CGFloat)rampFunction:(CGFloat)val;

- (void)setUsesChainMethod:(BOOL)chain;
- (BOOL)usesChainMethod;

@end

// clipping values:

enum {
	kDKPathDecoratorClippingNone = 0,
	kDKPathDecoratorClipOutsidePath = 1,
	kDKPathDecoratorClipInsidePath = 2
};
