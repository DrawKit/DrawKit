/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

/** @brief This category provides some basic methods for supporting interactive editing of a NSBezierPath object.

This category provides some basic methods for supporting interactive editing of a NSBezierPath object. This can be more tricky
than it looks because control points are often not edited in isolation - they often crosslink to other control points (such as
when two curveto segments are joined and a colinear handle is needed).

These methods allow you to refer to any individual control point in the object using a unique partcode. These methods will
hit detect all control points, giving the partcode, and then get and set that point.

The moveControlPointPartcode:toPoint:colinear: is a high-level call that will handle most editing tasks in a simple to use way. It
optionally maintains colinearity across curve joins, and knows how to maintain closed loops properly.
*/
@interface NSBezierPath (DKEditing)

@property (class) CGFloat constraintAngle;
+ (NSPoint)colinearPointForPoint:(NSPoint)p centrePoint:(NSPoint)q;
+ (NSPoint)colinearPointForPoint:(NSPoint)p centrePoint:(NSPoint)q radius:(CGFloat)r;
+ (NSInteger)point:(NSPoint)p inNSPointArray:(NSPoint*)array count:(NSInteger)count tolerance:(CGFloat)t;
/** test the point \c p against a list of points <code>array</code>,<code>count</code> using the tolerance <code>t</code>>. Returns the index of
 the point in the array "hit" by <code>p</code>, or \c NSNotFound if not hit.
 */
+ (NSInteger)point:(NSPoint)p inNSPointArray:(NSPoint*)array count:(NSInteger)count tolerance:(CGFloat)t reverse:(BOOL)reverse;
+ (void)colineariseVertex:(const NSPoint[_Nonnull 3])inPoints cpA:(nullable NSPoint*)outCPA cpB:(nullable NSPoint*)outCPB;

- (NSBezierPath*)bezierPathByRemovingTrailingElements:(NSInteger)numToRemove;
- (NSBezierPath*)bezierPathByStrippingRedundantElements;
- (NSBezierPath*)bezierPathByRemovingElementAtIndex:(NSInteger)indx;

/** @brief Counts the number of elements of each type in the path

 Pass \c NULL for any values you are not interested in
 @param mtc Pointer to integer that receive the move to count.
 @param ltc Pointer to integer that receive the line count.
 @param ctc Pointer to integer that receive the curve to count.
 @param cpc Pointer to integer that receive the close path count.*/
- (void)getPathMoveToCount:(nullable NSInteger*)mtc lineToCount:(nullable NSInteger*)ltc curveToCount:(nullable NSInteger*)ctc closePathCount:(nullable NSInteger*)cpc;

@property (readonly, getter=isPathClosed) BOOL pathClosed;
@property (readonly) NSUInteger checksum;

- (BOOL)subpathContainingElementIsClosed:(NSInteger)element;
- (NSInteger)subpathStartingElementForElement:(NSInteger)element;
- (NSInteger)subpathEndingElementForElement:(NSInteger)element;

- (NSBezierPathElement)elementTypeForPartcode:(NSInteger)pc;
- (BOOL)isOnPathPartcode:(NSInteger)pc NS_SWIFT_NAME(isOnPathPartcode(_:));

- (void)setControlPoint:(NSPoint)p forPartcode:(NSInteger)pc;
- (NSPoint)controlPointForPartcode:(NSInteger)pc;

- (NSInteger)partcodeHitByPoint:(NSPoint)p tolerance:(CGFloat)t;
- (NSInteger)partcodeHitByPoint:(NSPoint)p tolerance:(CGFloat)t prioritiseOnPathPoints:(BOOL)onpPriority;
- (NSInteger)partcodeHitByPoint:(NSPoint)p tolerance:(CGFloat)t startingFromElement:(NSInteger)startElement;
- (NSInteger)partcodeHitByPoint:(NSPoint)p tolerance:(CGFloat)t startingFromElement:(NSInteger)startElement prioritiseOnPathPoints:(BOOL)onpPriority;
- (NSInteger)partcodeForLastPoint;
- (NSPoint)referencePointForConstrainedPartcode:(NSInteger)pc;

- (void)moveControlPointPartcode:(NSInteger)pc toPoint:(NSPoint)p colinear:(BOOL)colin coradial:(BOOL)corad constrainAngle:(BOOL)acon;

// adding and deleting points from a path:
// note that all of these methods return a new path since NSBezierPath doesn't support deletion/insertion except by reconstructing a path.

- (NSBezierPath*)deleteControlPointForPartcode:(NSInteger)pc;
- (nullable NSBezierPath*)insertControlPointAtPoint:(NSPoint)p tolerance:(CGFloat)tol type:(NSInteger)controlPointType;

- (NSPoint)nearestPointToPoint:(NSPoint)p tolerance:(CGFloat)tol;

// geometry utilities:

- (CGFloat)tangentAtStartOfSubpath:(NSInteger)elementIndex;
- (CGFloat)tangentAtEndOfSubpath:(NSInteger)elementIndex;

- (NSInteger)elementHitByPoint:(NSPoint)p tolerance:(CGFloat)tol tValue:(nullable CGFloat*)t;
- (NSInteger)elementHitByPoint:(NSPoint)p tolerance:(CGFloat)tol tValue:(nullable CGFloat*)t nearestPoint:(nullable NSPoint*)npp;
- (NSInteger)elementBoundsContainsPoint:(NSPoint)p tolerance:(CGFloat)tol;

// element bounding boxes - can reduce need to draw entire path when only a part is edited

- (NSRect)boundingBoxForElement:(NSInteger)elementIndex;
- (void)drawElementsBoundingBoxes;
- (NSSet<NSValue*>*)boundingBoxesForPartcode:(NSInteger)pc NS_REFINED_FOR_SWIFT;
- (NSSet<NSValue*>*)allBoundingBoxes NS_REFINED_FOR_SWIFT;

@end

NSInteger partcodeForElement(const NSInteger element);
NSInteger partcodeForElementControlPoint(const NSInteger element, const NSInteger controlPointIndex);

NS_ASSUME_NONNULL_END
