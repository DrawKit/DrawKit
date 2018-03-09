/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

/** @brief Forms a rectangle from any two corner points.
 
 The rect is normalised, in that the relative positions of \c a and \c b do not affect the result - the
 rect always extends in the positive x and y directions.
 @param a A rect.
 @paran b A rect.
 @return The rectangle formed by \c a and \c b at the opposite corners. */
NSRect NSRectFromTwoPoints(const NSPoint a, const NSPoint b);

/** @brief Forms a rectangle of the given size centred on <code>p</code>.
 @param p A point.
 @param size The rect size.
 @return The rectangle. */
NSRect NSRectCentredOnPoint(const NSPoint p, const NSSize size);

/** @brief Returns the smallest rect that encloses both a and b

 Unlike <code>NSUnionRect</code>, this is practical when either or both of the input rects have a zero
 width or height. For convenience, if either \c a or \c b is \b exactly <code>NSZeroRect</code>, the other rect is
 returned, but in all other cases it correctly forms the union. While \c NSUnionRect might be
 considered mathematically correct, since a rect of zero width or height cannot "contain" anything
 in the set sense, what's more practically required for real geometry is to allow infinitely thin
 lines and points to push out the "envelope" of the rectangular space they define. That's what this does.
 @param a the first rect
 @param b the second rect
 @return the rectangle that encloses \c a and \c b */
NSRect UnionOfTwoRects(const NSRect a, const NSRect b);

/** @brief Returns the smallest rect that encloses all rects in the set.
 @param aSet A set of <code>NSValue</code>s containing rect values.
 @return The rectangle that encloses all rects. */
NSRect UnionOfRectsInSet(const NSSet<NSValue*>* aSet) NS_REFINED_FOR_SWIFT;

/** @brief Returns the area that is different between two input rects, as a list of rects
 
 This can be used to optimize upates. If a and b are "before and after" rects of a visual change,
 the resulting list is the area to update assuming that nothing changed in the common area,
 which is frequently so. If a and b are equal, the result is empty. If a and b do not intersect,
 the result contains \c a and <code>b</code>.
 @param a The first rect.
 @param b The second rect.
 @return A set of rect NSValues. */
NSSet<NSValue*>* DifferenceOfTwoRects(const NSRect a, const NSRect b) NS_REFINED_FOR_SWIFT;

/** @brief Subtracts \c b from <code>a</code>, returning the pieces left over.
 
 Subtracts \c b from <code>a</code>, returning the pieces left over. If \c a and \c b don't intersect the result is correct
 but unnecessary, so the caller should test for intersection first.
 */
NSSet<NSValue*>* SubtractTwoRects(const NSRect a, const NSRect b) NS_REFINED_FOR_SWIFT;

/** @brief Returns \c YES if the rects \c a and \c b are within \c epsilon of each other.
 */
BOOL AreSimilarRects(const NSRect a, const NSRect b, const CGFloat epsilon);

CGFloat PointFromLine(const NSPoint inPoint, const NSPoint a, const NSPoint b);
NSPoint NearestPointOnLine(const NSPoint inPoint, const NSPoint a, const NSPoint b);
CGFloat RelPoint(const NSPoint inPoint, const NSPoint a, const NSPoint b);

/** @brief returns the point in the line segment.
 
 Returns \c 0 if \c inPoint falls within the region defined by the line segment <code>a-b</code>, \c -1 if it's beyond the point <code>a</code>, \c 1 if beyond <code>b</code>. The "region" is an
 infinite plane defined by all possible lines parallel to <code>a-b</code>.
 */
NSInteger PointInLineSegment(const NSPoint inPoint, const NSPoint a, const NSPoint b);

NSPoint BisectLine(const NSPoint a, const NSPoint b);
NSPoint Interpolate(const NSPoint a, const NSPoint b, const CGFloat proportion);
CGFloat LineLength(const NSPoint a, const NSPoint b);

CGFloat SquaredLength(const NSPoint p);

/** @brief Returns the difference of two points.
 */
NSPoint DiffPoint(const NSPoint a, const NSPoint b);

/** @brief Returns the square of the distance between two points.
 */
CGFloat DiffPointSquaredLength(const NSPoint a, const NSPoint b);

/** @brief Returns the sum of two points.
 */
NSPoint SumPoint(const NSPoint a, const NSPoint b);

/** @brief Returns the end point of a line given its <code>origin</code>, <code>length</code>, and \c angle relative to x axis.
 */
NSPoint EndPoint(NSPoint origin, CGFloat angle, CGFloat length);

/** @brief Returns the slope of a line given its end points, in radians.
 */
CGFloat Slope(const NSPoint a, const NSPoint b);

/** @brief Returns the angle formed between three points \c abc where \c b is the vertex.
 */
CGFloat AngleBetween(const NSPoint a, const NSPoint b, const NSPoint c);

CGFloat DotProduct(const NSPoint a, const NSPoint b);

/** @brief Returns the intersecting point of two lines \c a and <code>b</code>, whose end points are passed in. If the lines are parallel,
 the result is undefined (NaN).
 */
NSPoint Intersection(const NSPoint aa, const NSPoint ab, const NSPoint ba, const NSPoint bb);

/** @brief Return the intersecting point of two lines SEGMENTS \c p1-p2 and <code>p3-p4</code>, whose end points are passed in.
 
 Return the intersecting point of two lines SEGMENTS \c p1-p2 and <code>p3-p4</code>, whose end points are passed in. If the lines are parallel,
 the result is <code>NSNotFoundPoint</code>. Uses an alternative algorithm from \c Intersection() - this is faster and more usable. This only returns a
 point if the two segments actually intersect - it doesn't project the lines.
 */
NSPoint Intersection2(const NSPoint p1, const NSPoint p2, const NSPoint p3, const NSPoint p4);

/** @brief Relocates the rect so its centre is at <code>p</code>. Does not change the rect's size
 */
NSRect CentreRectOnPoint(const NSRect inRect, const NSPoint p);

/** @brief Given a point \c p within \c rect this returns it mapped to a 0..1 interval
 */
NSPoint MapPointFromRect(const NSPoint p, const NSRect rect);

/** @brief Given a point \c p in 0..1 space, maps it to <code>rect</code>.
 */
NSPoint MapPointToRect(const NSPoint p, const NSRect rect);

/** @brief Maps a point \c p in \c srcRect to the same relative location within <code>destRect</code>.
 */
NSPoint MapPointFromRectToRect(const NSPoint p, const NSRect srcRect, const NSRect destRect);

/** @brief Maps a rect from \c srcRect to the same relative position within <code>destRect</code>.
 */
NSRect MapRectFromRectToRect(const NSRect inRect, const NSRect srcRect, const NSRect destRect);

/** @brief Multiplies the width and height of \c inrect by \c scale and offsets the origin by half the difference.
 
 Multiplies the width and height of \c inrect by \c scale and offsets the origin by half the difference, which
 keeps the original centre of the rect at the same point. Values <code>> 1</code> expand the rect, <code>< 1</code> shrink it.
 */
NSRect ScaleRect(const NSRect inRect, const CGFloat scale);

/** Returns a rect having the same aspect ratio as <code>inSize</code>>, scaled to fit within <code>fitRect</code>. The shorter side is centred
 within \c fitRect as appropriate
 */
NSRect ScaledRectForSize(const NSSize inSize, NSRect const fitRect);

/** @brief Centres \c r over <code>cr</code>, returning a rect the same size as <code>r</code>.
 */
NSRect CentreRectInRect(const NSRect r, const NSRect cr);
/** @brief Turns the rect into a path, rotated about its centre by <code>radians</code>.
 */
NSBezierPath* RotatedRect(const NSRect r, const CGFloat radians);

/** @brief returns the same rect as the input, but adjusts any negative width or height to be positive and
 compensates the origin.
 */
NSRect NormalizedRect(const NSRect r);

/** @brief Returns a transform that will cause a rotation about the point given at the angle given.
 */
NSAffineTransform* RotationTransform(const CGFloat radians, const NSPoint aboutPoint);

//NSPoint			PerspectiveMap( NSPoint inPoint, NSSize sourceSize, NSPoint quad[4]);

/** @brief Compute the parameter value of the point on a Bezier
 curve segment closest to some arbtitrary, user-input point.
 Return the point on the curve at that parameter value.
 */
NSPoint NearestPointOnCurve(const NSPoint inp, const NSPoint bez[_Nonnull 4], double* __nullable tValue);
/** @brief Evaluate a Bezier curve at a particular parameter value
 
 Fill in control points for resulting sub-curves if \c Left and
 \c Right are non-null.
 */
NSPoint Bezier(const NSPoint* v, const NSInteger degree, const double t, NSPoint* __nullable Left, NSPoint* __nullable Right);

/** @brief Returns the slope of the curve defined by the bezier control points \c bez at the \c t value given.
 
 Returns the slope of the curve defined by the bezier control points \c bez at the \c t value given. This slope can be used to determine
 the angle of something placed at that point tangent to the curve, such as a text character, etc. Add 90 degrees to get the normal to any
 point. For text on a path, you also need to calculate \c t based on a linear length along the path.
 */
CGFloat BezierSlope(const NSPoint bez[_Nonnull 4], const CGFloat t);

/** @brief This point constant is arbitrary but it is intended to be very unlikely to arise by chance. It can be used to signal "not found" when
 returning a point value from a function.
 */
extern const NSPoint NSNotFoundPoint;

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
