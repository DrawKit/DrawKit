/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#ifdef qUseGPC

#import <Cocoa/Cocoa.h>
#import "gpc.h"

// path simplifying constants - auto will not simplify when both source paths consist only of line segments

typedef enum {
    kDKPathUnflattenNever = 0,
    kDKPathUnflattenAlways = 1,
    kDKPathUnflattenAuto = 2
} DKPathUnflatteningPolicy;

@interface NSBezierPath (GPC)

/** @brief Converts a vector polygon in gpc format to an NSBezierPath
 @param poly a gpc polygon structure
 @return the same polygon as an NSBezierPath */
+ (NSBezierPath*)bezierPathWithGPCPolygon:(gpc_polygon*)poly;

/** @brief Sets the unflattening (curve fitting) policy for curve fitting flattened paths after a boolean op
 @param sp policy constant */
+ (void)setPathUnflatteningPolicy:(DKPathUnflatteningPolicy)sp;
+ (DKPathUnflatteningPolicy)pathUnflatteningPolicy;

/** @brief Converts a bezier path to a gpc polygon format structure

 The caller is responsible for freeing the returned object (in contrast to usual cocoa rules)
 @return a newly allocated gpc polygon structure */
- (gpc_polygon*)gpcPolygon;

/** @brief Converts a bezier path to a gpc polygon format structure

 The caller is responsible for freeing the returned object (in contrast to usual cocoa rules)
 @param flatness the flatness value for converting curves to vector form
 @return a newly allocated gpc polygon structure */
- (gpc_polygon*)gpcPolygonWithFlatness:(CGFloat)flatness;

- (NSInteger)subPathCountStartingAtElement:(NSInteger)se;

/** @brief Tests whether this path intersects another

 This works by computing the intersection of the two paths and checking if it's empty. Because it
 does a full-blown intersection, it is not necessarily a trivial operation. It is accurate for
 curves, etc however. It is worth trying to eliminate all obvious non-intersecting cases prior to
 calling this where performance is critical - this does however return quickly if the bounds do not
 intersect.
 @param path another path to test against
 @return YES if the paths intersect, NO otherwise */
- (BOOL)intersectsPath:(NSBezierPath*)path;

/** @brief Creates a new path from a boolean operation between this path and another path

 This applies the current flattening policy set for the class. If the policy is auto, this looks
 at the makeup of the contributing paths to determine whether to unflatten or not. If both source
 paths consist solely of line elements (no bezier curves), then no unflattening is performed.
 @param otherPath another path which is combined with this one's path
 @param op the operation to perform - constants defined in gpc.h
 @return a new path (may be empty in certain cases) */
- (NSBezierPath*)pathFromPath:(NSBezierPath*)otherPath usingBooleanOperation:(gpc_op)op;

/** @brief Creates a new path from a boolean operation between this path and another path

 The unflattening flag is passed directly - the curve fitting policy of the class is ignored
 @param otherPath another path which is combined with this one's path
 @param op the operation to perform - constants defined in gpc.h
 @param unflattenResult YES to attempt curve fitting on the result, NO to leave it in vector form
 @return a new path (may be empty in certain cases)
 */
- (NSBezierPath*)pathFromPath:(NSBezierPath*)otherPath usingBooleanOperation:(gpc_op)op unflattenResult:(BOOL)uf;

// boolean ops on bezier paths yay!

/** @brief Creates a new path which is the union of this path and another path

 Curve fitting policy for the class is applied to this method
 @param otherPath another path which is unioned with this one's path
 @return a new path */
- (NSBezierPath*)pathFromUnionWithPath:(NSBezierPath*)otherPath;

/** @brief Creates a new path which is the intersection of this path and another path

 Curve fitting policy for the class is applied to this method. If the paths bounds do not intersect,
 returns nil
 @param otherPath another path which is intersected with this one's path
 @return a new path (possibly empty) */
- (NSBezierPath*)pathFromIntersectionWithPath:(NSBezierPath*)otherPath;

/** @brief Creates a new path which is the difference of this path and another path

 Curve fitting policy for the class is applied to this method. If the paths bounds do not
 intersect, returns self, on the basis that subtracting the other path doesn't change this one.
 @param otherPath another path which is subtracted from this one's path
 @return a new path (possibly empty) */
- (NSBezierPath*)pathFromDifferenceWithPath:(NSBezierPath*)otherPath;

/** @brief Creates a new path which is the xor of this path and another path

 Curve fitting policy for the class is applied to this method
 @param otherPath another path which is xored with this one's path
 @return a new path (possibly empty) */
- (NSBezierPath*)pathFromExclusiveOrWithPath:(NSBezierPath*)otherPath;

// unflatten a poly-based path using curve fitting

/** @brief Creates a new path which is the unflattened version of this
 @return the unflattened path (curve fitted) */
- (NSBezierPath*)bezierPathByUnflatteningPath;

@end

NSUInteger checksumPoly(gpc_polygon* poly);
NSRect boundsOfPoly(gpc_polygon* poly);
BOOL equalPolys(gpc_polygon* polyA, gpc_polygon* polyB);
BOOL intersectingPolys(gpc_polygon* polyA, gpc_polygon* polyB);

#define kDKCurveFittingErrorValue 1E-4

extern NSString* kDKCurveFittingPolicyDefaultsKey;

/*

This category on NSBezierPath converts to and from the gpc_polygon data structure used by
the wonderful gpc (general polygon clipping) lib. This lib is used to perform boolean ops on paths.

Note that at present paths are flattened into polygons and so curve control points, etc are not preserved.

The curve-fitting is accomplished using 3rd party code from Lib2Geom, which is in turn a C++ implementation
of the classic Graphics Gems code. Curve-fitting is controlled by the "simplifying policy" that you set. By
default it's set to 'auto', meaning that if either of the original paths contains curves, curve fitting will
be done on the result, but if both source paths only have line segments, it won't be. This preserves sharp-cornered
shapes such as rects, etc.

For simplifying a path at any other time, you must pass a flattened path. Simplifying really means "unflattening".

*/

#endif /* defined (qUseGPC) */
