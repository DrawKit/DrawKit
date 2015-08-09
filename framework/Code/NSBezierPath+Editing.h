/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2015
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

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

+ (void)setConstraintAngle:(CGFloat)radians;
+ (NSPoint)colinearPointForPoint:(NSPoint)p centrePoint:(NSPoint)q;
+ (NSPoint)colinearPointForPoint:(NSPoint)p centrePoint:(NSPoint)q radius:(CGFloat)r;
+ (NSInteger)point:(NSPoint)p inNSPointArray:(NSPoint*)array count:(NSInteger)count tolerance:(CGFloat)t;
+ (NSInteger)point:(NSPoint)p inNSPointArray:(NSPoint*)array count:(NSInteger)count tolerance:(CGFloat)t reverse:(BOOL)reverse;
+ (void)colineariseVertex:(NSPoint[3])inPoints cpA:(NSPoint*)outCPA cpB:(NSPoint*)outCPB;

- (NSBezierPath*)bezierPathByRemovingTrailingElements:(NSInteger)numToRemove;
- (NSBezierPath*)bezierPathByStrippingRedundantElements;
- (NSBezierPath*)bezierPathByRemovingElementAtIndex:(NSInteger)indx;

/** @brief Counts the number of elements of each type in the path

 Pass NULL for any values you are not interested in
 @param mtc, ltc, ctc, cpc pointers to integers that receive the counts for each element type */
- (void)getPathMoveToCount:(NSInteger*)mtc lineToCount:(NSInteger*)ltc curveToCount:(NSInteger*)ctc closePathCount:(NSInteger*)cpc;

- (BOOL)isPathClosed;
- (NSUInteger)checksum;

- (BOOL)subpathContainingElementIsClosed:(NSInteger)element;
- (NSInteger)subpathStartingElementForElement:(NSInteger)element;
- (NSInteger)subpathEndingElementForElement:(NSInteger)element;

- (NSBezierPathElement)elementTypeForPartcode:(NSInteger)pc;
- (BOOL)isOnPathPartcode:(NSInteger)pc;

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
- (NSBezierPath*)insertControlPointAtPoint:(NSPoint)p tolerance:(CGFloat)tol type:(NSInteger)controlPointType;

- (NSPoint)nearestPointToPoint:(NSPoint)p tolerance:(CGFloat)tol;

// geometry utilities:

- (CGFloat)tangentAtStartOfSubpath:(NSInteger)elementIndex;
- (CGFloat)tangentAtEndOfSubpath:(NSInteger)elementIndex;

- (NSInteger)elementHitByPoint:(NSPoint)p tolerance:(CGFloat)tol tValue:(CGFloat*)t;
- (NSInteger)elementHitByPoint:(NSPoint)p tolerance:(CGFloat)tol tValue:(CGFloat*)t nearestPoint:(NSPoint*)npp;
- (NSInteger)elementBoundsContainsPoint:(NSPoint)p tolerance:(CGFloat)tol;

// element bounding boxes - can reduce need to draw entire path when only a part is edited

- (NSRect)boundingBoxForElement:(NSInteger)elementIndex;
- (void)drawElementsBoundingBoxes;
- (NSSet*)boundingBoxesForPartcode:(NSInteger)pc;
- (NSSet*)allBoundingBoxes;

@end

NSInteger partcodeForElement(const NSInteger element);
NSInteger partcodeForElementControlPoint(const NSInteger element, const NSInteger controlPointIndex);
