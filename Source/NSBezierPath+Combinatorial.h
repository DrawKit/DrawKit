/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

typedef NS_ENUM(NSInteger, DKBooleanOperation) {
	kDKBooleanOpUnion = 0,
	kDKBooleanOpIntersection = 1,
	kDKBooleanOpDifference = 2,
	kDKBooleanOpExclusiveOR = 3
};

/**
######## NOTE ######## NOT YET IMPLEMENTED - DO NOT USE - THESE FILES ARE A PLACEHOLDER ONLY

implements union, intersection, diff and xor between pairs of paths.

this maintains paths in their original form as much as possible.

restrictions: both operand paths must be closed.

how it works:

first, the points where the paths intersect are found by searching for intersections between flattened versions of the paths. This is the slowest part of the
operation because every path segments needs to be tested against every path segment of the second path (after weeding out obvious non-intersecting points).

then, the paths are split up into new path fragments at the intersecting points. Depending on which operation is being performed, some of these paths will be
thrown away, and the rest joined up into the new path.
*/
@interface NSBezierPath (Combinatorial)

- (void)showIntersectionsWithPath:(NSBezierPath*)path;
- (NSBezierPath*)renormalizePath;
- (NSArray*)dividePathWithPath:(NSBezierPath*)path;

- (NSBezierPath*)performBooleanOp:(DKBooleanOperation)op withPath:(NSBezierPath*)path;

@end
