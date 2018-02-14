/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@protocol DKBezierElementIterationDelegate;

@interface NSBezierPath (Geometry)

// simple transformations

/** @brief Returns a copy of the receiver scaled by <code>scale</code>, with the path's origin assumed to be at the centre of its bounds rect.
 */
- (NSBezierPath*)scaledPath:(CGFloat)scale;
/** @brief Returns a copy of the receiver scaled by <code>scale</code>, with the path's origin at <code>cp</code>
 
 This is like an inset or an outset operation. If scale is 1.0, self is returned.
 */
- (NSBezierPath*)scaledPath:(CGFloat)scale aboutPoint:(NSPoint)cp;
/** Return a rotated copy of the receiver. The origin is taken as the centre of the path bounds.
 \c angle is a value in radians.
 @param angle The angle, in radians.
 */
- (NSBezierPath*)rotatedPath:(CGFloat)angle;
/** return a rotated copy of the receiver. The origin is taken as point \c cp relative to the original path.
 \c angle is a value in radians
 */
- (NSBezierPath*)rotatedPath:(CGFloat)angle aboutPoint:(NSPoint)cp;
/** @Brief Returns a scaled copy of the receiver, calculating the scale by adding \c amount to all edges of the bounds.
 
 @discussion Since this can scale differently in \a x and \a y directions, this doesn't call the scale function but works
 very similarly.

 Note that due to the mathematics of bezier curves, this may not produce exactly perfect results for some
 curves.

 Positive values of \c amount inset (shrink) the path, negative values outset (grow) the shape.
 */
- (NSBezierPath*)insetPathBy:(CGFloat)amount;
- (NSBezierPath*)horizontallyFlippedPathAboutPoint:(NSPoint)cp;
- (NSBezierPath*)verticallyFlippedPathAboutPoint:(NSPoint)cp;
@property (readonly, copy) NSBezierPath *horizontallyFlippedPath;
@property (readonly, copy) NSBezierPath *verticallyFlippedPath;

@property (readonly) NSPoint centreOfBounds;
/** @brief returns the smallest angle subtended by any segment join in the path.
 
 @discussion The largest value this can be is \a pi (180 degrees), the smallest is 0. The
 result is in radians. Can be used to determine the necessary bounding rect of the path for a given stroke width and miter limit. For curve
 elements, the curvature is ignored and the element treated as a line segment.
 */
@property (readonly) CGFloat minimumCornerAngle;

// iterating over a path using a iteration delegate:

/** @brief Allows a delegate to use the info to build a new path element by element.
 
 @discussion This method allows a delegate to use the info from the receiver to build a new path element by element. This is a generic method that is intended to
 avoid the need to write these loops over and over. The delegate is passed the points of each element in an order that is easier to work with than
 the native list and also always includes the last point in a subpath.
 */
- (nullable NSBezierPath*)bezierPathByIteratingWithDelegate:(id<DKBezierElementIterationDelegate>)delegate contextInfo:(nullable void*)contextInfo;

/** @brief returns a copy of the receiver modified by offsetting all of its control points by \c delta in the direction of the
 normal of the path at the location of the on-path control point.
 
 Returns a copy of the receiver modified by offsetting all of its control points by \c delta in the direction of the
 normal of the path at the location of the on-path control point. This will create a parallel-ish offset path that works
 for most non-pathological paths. Given that there is no known mathematically correct way to do this (for bezier curves), this works well enough in
 many practical situations. Positive delta moves the path below or to the right, negative is up and left.
 */
- (NSBezierPath*)paralleloidPathWithOffset:(CGFloat)delta;
- (NSBezierPath*)paralleloidPathWithOffset2:(CGFloat)delta;
- (NSBezierPath*)paralleloidPathWithOffset22:(CGFloat)delta;
- (NSBezierPath*)offsetPathWithStartingOffset:(CGFloat)delta1 endingOffset:(CGFloat)delta2;
- (NSBezierPath*)offsetPathWithStartingOffset2:(CGFloat)delta1 endingOffset:(CGFloat)delta2;

// interpolating flattened paths:

- (NSBezierPath*)bezierPathByInterpolatingPath:(CGFloat)amount;

// calculating a fillet

- (NSBezierPath*)filletPathForVertex:(NSPoint[_Nonnull 3])vp filletSize:(CGFloat)fs;

// roughening and randomising paths

- (NSBezierPath*)bezierPathByRandomisingPoints:(CGFloat)maxAmount;
- (nullable NSBezierPath*)bezierPathWithRoughenedStrokeOutline:(CGFloat)amount;
- (NSBezierPath*)bezierPathWithFragmentedLineSegments:(CGFloat)flatness;

// zig-zags and waves

- (NSBezierPath*)bezierPathWithZig:(CGFloat)zig zag:(CGFloat)zag;
- (NSBezierPath*)bezierPathWithWavelength:(CGFloat)lambda amplitude:(CGFloat)amp spread:(CGFloat)spread;

// getting the outline of a stroked path:

@property (readonly, copy) NSBezierPath *strokedPath;
- (NSBezierPath*)strokedPathWithStrokeWidth:(CGFloat)width;

// breaking a path apart:

@property (readonly, copy) NSArray<NSBezierPath*> *subPaths;
@property (readonly) NSInteger countSubPaths;

// converting to and from Core Graphics paths

- (nullable CGPathRef)newQuartzPath CF_RETURNS_RETAINED;
- (nullable CGMutablePathRef)newMutableQuartzPath CF_RETURNS_RETAINED;
- (CGContextRef)setQuartzPath CF_RETURNS_NOT_RETAINED;
- (void)setQuartzPathInContext:(CGContextRef)context isNewPath:(BOOL)np;

+ (NSBezierPath*)bezierPathWithCGPath:(CGPathRef)path;
+ (NSBezierPath*)bezierPathWithPathFromContext:(CGContextRef)context;

// finding path lengths for points and points for lengths

- (NSPoint)pointOnPathAtLength:(CGFloat)length slope:(nullable CGFloat*)slope;
@property (readonly) CGFloat slopeStartingPath;
- (CGFloat)distanceFromStartOfPathAtPoint:(NSPoint)p tolerance:(CGFloat)tol;

- (NSInteger)pointWithinPathRegion:(NSPoint)p;

// clipping utilities:

- (void)addInverseClip;

// path trimming

@property (readonly) CGFloat length;
/** @brief Estimate the total length of a bezier path
 */
- (CGFloat)lengthWithMaximumError:(CGFloat)maxError;
- (CGFloat)lengthOfElement:(NSInteger)i;
- (CGFloat)lengthOfPathFromElement:(NSInteger)startElement toElement:(NSInteger)endElement;

@property (readonly) NSPoint firstPoint;
@property (readonly) NSPoint lastPoint;

// trimming utilities - modified source originally from A J Houghton, see copyright notice below

/** @brief Return an \c NSBezierPath corresponding to the first \c trimLength units
 of this NSBezierPath. */
- (NSBezierPath*)bezierPathByTrimmingToLength:(CGFloat)trimLength;
/** @brief Return an \c NSBezierPath corresponding to the first \c trimLength units
 of this NSBezierPath. */
- (NSBezierPath*)bezierPathByTrimmingToLength:(CGFloat)trimLength withMaximumError:(CGFloat)maxError;

/* @brief Return an \c NSBezierPath corresponding to the part \b after the first
 \c trimLength units of this NSBezierPath. */
- (NSBezierPath*)bezierPathByTrimmingFromLength:(CGFloat)trimLength;
/* @brief Return an \c NSBezierPath corresponding to the part \b after the first
 \c trimLength units of this NSBezierPath. */
- (NSBezierPath*)bezierPathByTrimmingFromLength:(CGFloat)trimLength withMaximumError:(CGFloat)maxError;

/** @brief Trims \c trimLength from both ends of the path, returning the shortened centre section.
 */
- (NSBezierPath*)bezierPathByTrimmingFromBothEnds:(CGFloat)trimLength;
/** @brief Trims \c trimLength from both ends of the path, returning the shortened centre section.
 */
- (NSBezierPath*)bezierPathByTrimmingFromBothEnds:(CGFloat)trimLength withMaximumError:(CGFloat)maxError;

/** @brief Removes a section \c trimLength long from the centre of the path. The returned path thus consists of two
 subpaths with a gap between them.
 */
- (NSBezierPath*)bezierPathByTrimmingFromCentre:(CGFloat)trimLength;
/** @brief Removes a section \c trimLength long from the centre of the path. The returned path thus consists of two
 subpaths with a gap between them.
 */
- (NSBezierPath*)bezierPathByTrimmingFromCentre:(CGFloat)trimLength withMaximumError:(CGFloat)maxError;

/** @brief Returns a new path which is \c newLength long, starting at \c startLength on the receiver's path. If \c newLength exceeds the available length, the
 remainder of the path is returned. If \c startLength exceeds the length, returns <code>nil</code>.
 */
- (nullable NSBezierPath*)bezierPathByTrimmingFromLength:(CGFloat)startLength toLength:(CGFloat)newLength;
/** @brief Returns a new path which is \c newLength long, starting at \c startLength on the receiver's path. If \c newLength exceeds the available length, the
 remainder of the path is returned. If \c startLength exceeds the length, returns <code>nil</code>.
 */
- (nullable NSBezierPath*)bezierPathByTrimmingFromLength:(CGFloat)startLength toLength:(CGFloat)newLength withMaximumError:(CGFloat)maxError;

/** @brief Create an \c NSBezierPath containing an arrowhead for the start of this path
 */
- (NSBezierPath*)bezierPathWithArrowHeadForStartOfLength:(CGFloat)length angle:(CGFloat)angle closingPath:(BOOL)closeit;
/** @brief  Convenience method for obtaining arrow for the other end.
 */
- (NSBezierPath*)bezierPathWithArrowHeadForEndOfLength:(CGFloat)length angle:(CGFloat)angle closingPath:(BOOL)closeit;

/** @brief Append a Bezier path, but if it starts with a <code>-moveToPoint</code>, then remove
 it.
 
 @discussion This is useful when manipulating trimmed path segments. */
- (void)appendBezierPathRemovingInitialMoveToPoint:(NSBezierPath*)path;

@end

/** @brief Protocol for iterating over the elements in a bezier path using \c bezierPathByIteratingWithDelegate:contextInfo:
 */
@protocol DKBezierElementIterationDelegate <NSObject>

/**
 @param path the new path that the delegate can build or modify from the information given
 @param element the element index
 @param type the element type
 @param p list of associated points 0 = next point, 1 = cp1, 2 = cp2 (for curves), 3 = last point on subpath
 @param spi which subpath this is
 @param spClosed is the subpath closed?
 @param contextInfo the context info
 */
- (void)path:(NSBezierPath*)path // the new path that the delegate can build or modify from the information given
	 elementIndex:(NSInteger)element // the element index
			 type:(NSBezierPathElement)type // the element type
	  points:(NSPoint[_Nonnull 4])p // list of associated points 0 = next point, 1 = cp1, 2 = cp2 (for curves), 3 = last point on subpath
	 subPathIndex:(NSInteger)spi // which subpath this is
	subPathClosed:(BOOL)spClosed // is the subpath closed?
 contextInfo:(nullable void*)contextInfo; // the context info

@end

/*
 Bezier path utility category (trimming)
 *
 (c) 2004 Alastair J. Houghton
 All Rights Reserved.
 *
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 *
   1. Redistributions of source code must retain the above copyright
	  notice, this list of conditions and the following disclaimer.
 *
   2. Redistributions in binary form must reproduce the above copyright
	  notice, this list of conditions and the following disclaimer in the
	  documentation and/or other materials provided with the distribution.
 *
   3. The name of the author of this software may not be used to endorse
	  or promote products derived from the software without specific prior
	  written permission.
 *
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER "AS IS" AND ANY EXPRESS
 OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 IN NO EVENT SHALL THE COPYRIGHT OWNER BE LIABLE FOR ANY DIRECT, INDIRECT,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO
 PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA OR PROFITS;
 OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * */

void subdivideBezierAtT(const NSPoint bez[_Nonnull 4], NSPoint bez1[_Nonnull 4], NSPoint bez2[_Nonnull 4], CGFloat t);

NS_ASSUME_NONNULL_END
