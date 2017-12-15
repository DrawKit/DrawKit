/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKRasterizer.h"
#import "NSBezierPath+Text.h"

@class DKQuartzCache;

/** @brief This renderer draws the image along the path of another object spaced at <interval> distance.

This renderer draws the image along the path of another object spaced at \c interval distance. Each image is scaled by \c scale and is
rotated to be normal to the path unless _normalToPath is NO.

This prefers PDF image representations where the image contains one, preserving resolution as the drawing is scaled.
*/
@interface DKPathDecorator : DKRasterizer <NSCoding, NSCopying, DKBezierPlacement> {
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

- (instancetype)initWithCoder:(NSCoder*)coder NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithImage:(NSImage*)image NS_DESIGNATED_INITIALIZER;

@property (nonatomic, strong) NSImage *image;
- (void)setUpCache;
- (void)setPDFImageRep:(NSPDFImageRep*)rep;

@property (nonatomic) CGFloat scale;

@property (nonatomic) CGFloat scaleRandomness;

@property CGFloat interval;

@property CGFloat leaderDistance;

@property CGFloat lateralOffset;
@property BOOL lateralOffsetAlternates;

@property (nonatomic) CGFloat wobblyness;

@property BOOL normalToPath;

@property CGFloat leadInLength;
@property CGFloat leadOutLength;

@property (nonatomic) CGFloat leadInAndOutLengthProportion;
- (CGFloat)rampFunction:(CGFloat)val;

/**
 experimental: allows use of "chain" callback which emulates links more accurately than image drawing - but really this ought to be
 pushed out into another more specialised class.
*/
@property BOOL usesChainMethod;

@end

// clipping values:

enum {
	kDKPathDecoratorClippingNone = 0,
	kDKPathDecoratorClipOutsidePath = 1,
	kDKPathDecoratorClipInsidePath = 2
};
