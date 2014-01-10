/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import "DKRasterizer.h"

@class DKStrokeDash;

/** @brief This class provides a simple hatching fill for a path.

This class provides a simple hatching fill for a path. It draws equally-spaced solid lines of a given thickness at a
particular angle. Subclass for more sophisticated hatches.

Can be set as a fill style in a DKStyle object.

The hatch is cached in an NSBezierPath object based on the bounds of the path. If another path is hatched that is smaller
than the cached size, it is not rebuilt. It is rebuilt if the angle or spacing changes or a bigger path is hatched. Linewidth also
doesn't change the cache.
*/
@interface DKHatching : DKRasterizer <NSCoding, NSCopying> {
@private
    NSBezierPath* m_cache;
    NSBezierPath* mRoughenedCache;
    NSColor* m_hatchColour;
    DKStrokeDash* m_hatchDash;
    NSLineCapStyle m_cap;
    NSLineJoinStyle m_join;
    CGFloat m_leadIn;
    CGFloat m_spacing;
    CGFloat m_angle;
    CGFloat m_lineWidth;
    BOOL m_angleRelativeToObject;
    BOOL mRoughenStrokes;
    CGFloat mRoughness;
    CGFloat mWobblyness;
}

/** @brief Return the default hatching

 Be sure to copy the object if you intend to change its parameters.
 @return the default hatching object (shared instance). The default is black 45 degree lines spaced 8 points
 apart with a width of 0.25 points.
 */
+ (DKHatching*)defaultHatching;

/** @brief Return a hatching with e basic parameters given

 The colour is set to black
 @param w the line width of the lines
 @param spacing the line spacing
 @param angle the overall angle in radians
 @return a hatching instance
 */
+ (DKHatching*)hatchingWithLineWidth:(CGFloat)w spacing:(CGFloat)spacing angle:(CGFloat)angle;

/** @brief Return a hatching which implements a dot pattern

 The colour is set to black. The dot pattern is created using a dashed line at 45 degrees where
 the line and dash spacing is set to the dot pitch. The line width is the dot diameter and the
 rounded cap style is used. This is an efficient way to implement a dot pattern of a given density.
 @param pitch the spacing between the dots
 @param diameter the dot diameter
 @return a hatching instance having the given dot pattern
 */
+ (DKHatching*)hatchingWithDotPitch:(CGFloat)pitch diameter:(CGFloat)diameter;

/** @brief Return a hatching which implements a dot pattern of given density

 Dots have a diameter of 2.0 points, and are spaced according to density. If density = 1, dots
 touch (spacing = 2.0), 0.5 = dots have a spacing of 4.0, etc. A density of 0 is not allowed.
 @param density a density figure from 0 to 1
 @return a hatching instance having a dot pattern of the given density
 */
+ (DKHatching*)hatchingWithDotDensity:(CGFloat)density;

- (void)hatchPath:(NSBezierPath*)path;

/** @brief Apply the hatching to the path with a given object angle
 @param path the path to fill
 @param oa the additional angle to apply, in radians
 */
- (void)hatchPath:(NSBezierPath*)path objectAngle:(CGFloat)oa;

/** @brief Set the angle of the hatching
 @param radians the angle in radians
 */
- (void)setAngle:(CGFloat)radians;

/** @brief The angle of the hatching
 @return the angle in radians
 */
- (CGFloat)angle;

/** @brief Set the angle of the hatching in degrees
 @param degs the angle in degrees 
 */
- (void)setAngleInDegrees:(CGFloat)degs;

/** @brief The angle of the hatching in degrees
 @return the angle in degrees
 */
- (CGFloat)angleInDegrees;
- (void)setAngleIsRelativeToObject:(BOOL)rel;
- (BOOL)angleIsRelativeToObject;

- (void)setSpacing:(CGFloat)spacing;
- (CGFloat)spacing;
- (void)setLeadIn:(CGFloat)amount;
- (CGFloat)leadIn;

- (void)setWidth:(CGFloat)width;
- (CGFloat)width;
- (void)setLineCapStyle:(NSLineCapStyle)lcs;
- (NSLineCapStyle)lineCapStyle;
- (void)setLineJoinStyle:(NSLineJoinStyle)ljs;
- (NSLineJoinStyle)lineJoinStyle;

- (void)setColour:(NSColor*)colour;
- (NSColor*)colour;

- (void)setDash:(DKStrokeDash*)dash;
- (DKStrokeDash*)dash;
- (void)setAutoDash;

- (void)setRoughness:(CGFloat)amount;
- (CGFloat)roughness;
- (void)setWobblyness:(CGFloat)wobble;
- (CGFloat)wobblyness;

- (void)invalidateCache;
- (void)calcHatchInRect:(NSRect)rect;

@end
