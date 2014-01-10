/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import <Cocoa/Cocoa.h>

#ifdef __cplusplus
extern "C" {
#endif

NSRect NSRectFromTwoPoints(const NSPoint a, const NSPoint b);

/** @brief Forms a rectangle of the given size centred on p
 @param p a point
 @param size the rect size
 @return the rectangle */
NSRect NSRectCentredOnPoint(const NSPoint p, const NSSize size);

/** @brief Returns the smallest rect that encloses both a and b

 Unlike NSUnionRect, this is practical when either or both of the input rects have a zero
 width or height. For convenience, if either a or b is EXACTLY NSZeroRect, the other rect is
 returned, but in all other cases it correctly forms the union. While NSUnionRect might be
 considered mathematically correct, since a rect of zero width or height cannot "contain" anything
 in the set sense, what's more practically required for real geometry is to allow infinitely thin
 lines and points to push out the "envelope" of the rectangular space they define. That's what this does.
 @param a, b a pair of rects
 @return the rectangle that encloses a and b */
NSRect UnionOfTwoRects(const NSRect a, const NSRect b);

/** @brief Returns the smallest rect that encloses all rects in the set
 @param aSet a set of NSValues containing rect values
 @return the rectangle that encloses all rects */
NSRect UnionOfRectsInSet(const NSSet* aSet);
NSSet* DifferenceOfTwoRects(const NSRect a, const NSRect b);
NSSet* SubtractTwoRects(const NSRect a, const NSRect b);

BOOL AreSimilarRects(const NSRect a, const NSRect b, const CGFloat epsilon);

CGFloat PointFromLine(const NSPoint inPoint, const NSPoint a, const NSPoint b);
NSPoint NearestPointOnLine(const NSPoint inPoint, const NSPoint a, const NSPoint b);
CGFloat RelPoint(const NSPoint inPoint, const NSPoint a, const NSPoint b);
NSInteger PointInLineSegment(const NSPoint inPoint, const NSPoint a, const NSPoint b);

NSPoint BisectLine(const NSPoint a, const NSPoint b);
NSPoint Interpolate(const NSPoint a, const NSPoint b, const CGFloat proportion);
CGFloat LineLength(const NSPoint a, const NSPoint b);

CGFloat SquaredLength(const NSPoint p);
NSPoint DiffPoint(const NSPoint a, const NSPoint b);
CGFloat DiffPointSquaredLength(const NSPoint a, const NSPoint b);
NSPoint SumPoint(const NSPoint a, const NSPoint b);

NSPoint EndPoint(NSPoint origin, CGFloat angle, CGFloat length);
CGFloat Slope(const NSPoint a, const NSPoint b);
CGFloat AngleBetween(const NSPoint a, const NSPoint b, const NSPoint c);
CGFloat DotProduct(const NSPoint a, const NSPoint b);
NSPoint Intersection(const NSPoint aa, const NSPoint ab, const NSPoint ba, const NSPoint bb);
NSPoint Intersection2(const NSPoint p1, const NSPoint p2, const NSPoint p3, const NSPoint p4);

NSRect CentreRectOnPoint(const NSRect inRect, const NSPoint p);
NSPoint MapPointFromRect(const NSPoint p, const NSRect rect);
NSPoint MapPointToRect(const NSPoint p, const NSRect rect);
NSPoint MapPointFromRectToRect(const NSPoint p, const NSRect srcRect, const NSRect destRect);
NSRect MapRectFromRectToRect(const NSRect inRect, const NSRect srcRect, const NSRect destRect);

NSRect ScaleRect(const NSRect inRect, const CGFloat scale);
NSRect ScaledRectForSize(const NSSize inSize, NSRect const fitRect);
NSRect CentreRectInRect(const NSRect r, const NSRect cr);
NSBezierPath* RotatedRect(const NSRect r, const CGFloat radians);

NSRect NormalizedRect(const NSRect r);
NSAffineTransform* RotationTransform(const CGFloat radians, const NSPoint aboutPoint);

//NSPoint			PerspectiveMap( NSPoint inPoint, NSSize sourceSize, NSPoint quad[4]);

NSPoint NearestPointOnCurve(const NSPoint inp, const NSPoint bez[4], double* tValue);
NSPoint Bezier(const NSPoint* v, const NSInteger degree, const double t, NSPoint* Left, NSPoint* Right);

CGFloat BezierSlope(const NSPoint bez[4], const CGFloat t);

extern const NSPoint NSNotFoundPoint;

#ifdef __cplusplus
}
#endif
