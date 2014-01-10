/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

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

+ (DKStroke*)defaultStroke;
+ (DKStroke*)strokeWithWidth:(CGFloat)width colour:(NSColor*)colour;

- (id)initWithWidth:(CGFloat)width colour:(NSColor*)colour;

- (void)setColour:(NSColor*)colour;
- (NSColor*)colour;

- (void)setWidth:(CGFloat)width;
- (CGFloat)width;
- (void)scaleWidthBy:(CGFloat)scale;
- (CGFloat)allowance;

- (void)setDash:(DKStrokeDash*)dash;
- (DKStrokeDash*)dash;
- (void)setAutoDash;

- (void)setLateralOffset:(CGFloat)offset;
- (CGFloat)lateralOffset;

- (void)setShadow:(NSShadow*)shadow;
- (NSShadow*)shadow;

- (void)strokeRect:(NSRect)rect;
- (void)applyAttributesToPath:(NSBezierPath*)path;

- (void)setLineCapStyle:(NSLineCapStyle)lcs;
- (NSLineCapStyle)lineCapStyle;

- (void)setLineJoinStyle:(NSLineJoinStyle)ljs;
- (NSLineJoinStyle)lineJoinStyle;

- (void)setMiterLimit:(CGFloat)limit;
- (CGFloat)miterLimit;

- (void)setTrimLength:(CGFloat)tl;
- (CGFloat)trimLength;

- (NSSize)extraSpaceNeededIgnoringMitreLimit;

@end
