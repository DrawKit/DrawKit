/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKRasterizer.h"

@class DKStrokeDash;

/** @brief represents the stroke of a path, and can be added as an attribute of a DKStyle.

represents the stroke of a path, and can be added as an attribute of a DKStyle. Note that because a stroke
is an object, it's easy to stroke a path multiple times for special effects. A DKStyle will apply all
the strokes it is aware of in order when it is asked to stroke a path.

DKStyle can contains a list of strokes without limit.
*/
@interface DKStroke : DKRasterizer <NSCoding, NSCopying> {
@private
	NSColor* m_colour;
	DKStrokeDash* m_dash;
	NSShadow* m_shadow;
	NSLineCapStyle m_cap;
	NSLineJoinStyle m_join;
	CGFloat m_mitreLimit;
	CGFloat m_trimLength;
	CGFloat mLateralOffset;
@protected
	CGFloat m_width;
}

+ (instancetype)defaultStroke NS_SWIFT_UNAVAILABLE("use DKStroke.init() instead.");
+ (instancetype)strokeWithWidth:(CGFloat)width colour:(NSColor*)colour;

- (instancetype)init;
- (instancetype)initWithWidth:(CGFloat)width colour:(NSColor*)colour NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_DESIGNATED_INITIALIZER;

@property (strong) NSColor *colour;

@property CGFloat width;
- (void)scaleWidthBy:(CGFloat)scale;
@property (readonly) CGFloat allowance;

@property (strong) DKStrokeDash *dash;
- (void)setAutoDash;

@property CGFloat lateralOffset;

@property (strong) NSShadow *shadow;

- (void)strokeRect:(NSRect)rect;
- (void)applyAttributesToPath:(NSBezierPath*)path;

@property NSLineCapStyle lineCapStyle;

@property NSLineJoinStyle lineJoinStyle;

@property CGFloat miterLimit;

@property (nonatomic) CGFloat trimLength;

@property (readonly) NSSize extraSpaceNeededIgnoringMitreLimit;

@end
