/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

//#ifdef qUseGPC

#import "DKObjectDrawingLayer.h"

/** @brief This category provides high-level Boolean Operation commands for a drawing layer.

This category provides high-level Boolean Operation commands for a drawing layer. It requires the
NSBezierPath+GPC category to function.

The operations here are user-level ops, and can be simply hooked to menu commands. The operations proceed as follows:

Union:

Two or more objects in the selection are replaced by a single shape object whose path is the union of all the selected object's paths.
Path objects are converted to shape objects prior to forming the union. The result object does not preserve the rotation angle
of the original objects. The result inherits the style of the topmost object. The result is always a shape even if some or all
of the contributing objects are paths.

Difference:

Exactly two objects must be in the selection. The shape or path that is topmost is unchanged, but acts as a "cookie cutter"
for the other object, which is replaced by the result. The result inherits the style and type of the object it replaces.
Rotation angle is preserved for shapes.

Intersection:

Exactly two objects must be in the selection. Path objects are converted to shape objects before computing the intersection.
The original objects are replaced by the intersection unless the intersection is empty, in which case this is a no-op. The
result inherits the style of the topmost original object. Rotation angle is not preserved; the result is always a shape even if
one or both of the operands is a path object.

Xor:

As for intersection.

Combine:

Two or more objects must be in the selection. Appends each path to the lowest one using appendBezierPath. The result is like an Xor
or a union, depending on the disposition of the paths. The advantage of this is that no path flattening is required.

Note that the design choices here about what type the result is, how stacking order affects the result, and so forth are intended
to provide the most natural and obvious outcomes for a typical drawing type program. That's why these operations must be considered
high level. If you want to implement some other behaviour built from boolean operations on paths, you have every freedom to do so,
since the code this calls operates purely at the abstract NSBezierPath level.
*/
@interface DKObjectDrawingLayer (BooleanOps)

/** @brief Forms the union of the selected objects and replaces the selection with the result

 Result adopts the style of the topmost object contributing.
 @param sender the action's sender
 */
- (IBAction)unionSelectedObjects:(id)sender;

/** @brief Subtracts the topmost shape from the other.

 Requires exactly two contributing objects. If the shapes don't overlap, this does nothing. The
 'cutter' object is removed from the layer.
 @param sender the action's sender
 */
- (IBAction)diffSelectedObjects:(id)sender;

/** @brief Replaces a pair of objects by their intersection.

 Requires exactly two contributing objects. If the objects don't intersect, does nothing. The result
 adopts the style of the lower contributing object
 @param sender the action's sender
 */
- (IBAction)intersectionSelectedObjects:(id)sender;

/** @brief Replaces a pair of objects by their exclusive-OR.

 Requires exactly two contributing objects. If the objects don't intersect, does nothing. The result
 adopts the syle of the topmost contributing object
 @param sender the action's sender
 */
- (IBAction)xorSelectedObjects:(id)sender;

/** @brief Replaces a pair of objects by their divided replacements.

 Requires exactly two contributing objects. If the objects don't intersect, does nothing. A division
 splits two overlapping paths at their intersecting points into as many pieces as necessary. The
 original, objects are replaced by the pieces. Pieces derived from each path retain the styles of
 the original paths.
 @param sender the action's sender
 */
- (IBAction)divideSelectedObjects:(id)sender;

/** @brief Replaces a pair of objects by combining their paths.

 Requires two or more contributing objects. The result adopts the syle of the topmost
 contributing object. The result can act like a union, difference or xor depending on the relative
 disposition of the contributing paths.
 @param sender the action's sender
 */
- (IBAction)combineSelectedObjects:(id)sender;

/** @brief Sets the unflattening (smoothing) policy for GPC-based operations.

 The sender's tag is interpreted as the policy value.
 @param sender the action's sender
 */
- (IBAction)setBooleanOpsFittingPolicy:(id)sender;

- (NSArray*)cropToPath:(NSBezierPath*)croppingPath;
- (NSArray*)cropToRect:(NSRect)croppingRect;

- (BOOL)intersectingDrawablesinArray:(NSArray*)array;

@end

//#endif /* defined (qUseGPC) */
