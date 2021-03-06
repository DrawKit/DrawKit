/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKObjectDrawingLayer.h"

NS_ASSUME_NONNULL_BEGIN

@class DKGridLayer;

typedef NS_ENUM(NSInteger, DKAlignment) {
	kDKAlignmentLeftEdge = 0,
	kDKAlignmentTopEdge = 1,
	kDKAlignmentRightEdge = 2,
	kDKAlignmentBottomEdge = 3,
	kDKAlignmentVerticalCentre = 4,
	kDKAlignmentHorizontalCentre = 5,
	kDKAlignmentVerticalDistribution = 6,
	kDKAlignmentHorizontalDistribution = 7,
	kDKAlignmentVSpaceDistribution = 8,
	kDKAlignmentHSpaceDistribution = 9
};

typedef NS_OPTIONS(NSUInteger, DKAlignmentAlign) {
	kDKAlignmentAlignLeftEdge = (1 << kDKAlignmentLeftEdge),
	kDKAlignmentAlignTopEdge = (1 << kDKAlignmentTopEdge),
	kDKAlignmentAlignRightEdge = (1 << kDKAlignmentRightEdge),
	kDKAlignmentAlignBottomEdge = (1 << kDKAlignmentBottomEdge),
	kDKAlignmentAlignVerticalCentre = (1 << kDKAlignmentVerticalCentre),
	kDKAlignmentAlignHorizontalCentre = (1 << kDKAlignmentHorizontalCentre),
	kDKAlignmentAlignVDistribution = (1 << kDKAlignmentVerticalDistribution),
	kDKAlignmentAlignHDistribution = (1 << kDKAlignmentHorizontalDistribution),
	kDKAlignmentAlignVSpaceDistribution = (1 << kDKAlignmentVSpaceDistribution),
	kDKAlignmentAlignHSpaceDistribution = (1 << kDKAlignmentHSpaceDistribution),
	kDKAlignmentAlignNone = 0,
	kDKAlignmentAlignColocate = kDKAlignmentAlignVerticalCentre | kDKAlignmentAlignHorizontalCentre,
	kDKAlignmentAlignHorizontalMask = kDKAlignmentAlignLeftEdge | kDKAlignmentAlignRightEdge | kDKAlignmentAlignHorizontalCentre | kDKAlignmentAlignHDistribution | kDKAlignmentAlignHSpaceDistribution,
	kDKAlignmentAlignVerticalMask = kDKAlignmentAlignTopEdge | kDKAlignmentAlignBottomEdge | kDKAlignmentAlignVerticalCentre | kDKAlignmentAlignVDistribution | kDKAlignmentAlignVSpaceDistribution,
	kDKAlignmentAlignDistributionMask = kDKAlignmentAlignVDistribution | kDKAlignmentAlignHDistribution | kDKAlignmentAlignVSpaceDistribution | kDKAlignmentAlignHSpaceDistribution
};

/** @brief This category implements object alignment features for \c DKObjectDrawingLayer
*/
@interface DKObjectDrawingLayer (Alignment)

// setting the key object (used by alignment methods)

/** @brief Nominates an object as the master to be used for alignment operations, etc.

 The object is not retained as it should already be owned. A \c nil object can be set to mean that the
 topmost select object should be considered key.
 If no specific object is set (<code>nil</code>), then the first object in the selection is returned. If there's
 no selection, returns <code>nil</code>.
 */
@property (unsafe_unretained, nullable) DKDrawableObject* keyObject;

/** @brief Aligns a set of objects.

 Objects are aligned with the layer's nominated key object, by default the first object in the supplied list.
 @param objects The objects to align.
 @param align The alignment operation required.
 */
- (void)alignObjects:(NSArray<DKDrawableObject*>*)objects withAlignment:(DKAlignmentAlign)align;

/** @brief Aligns a set of objects.
 @param objects The objects to align.
 @param object The "master" object - the one to which the others are aligned.
 @param align The alignment operation required.
 */
- (void)alignObjects:(NSArray<DKDrawableObject*>*)objects toMasterObject:(id)object withAlignment:(DKAlignmentAlign)align;

/** @brief Aligns a set of objects to a given point.
 @param objects The objects to align.
 @param loc The point to which the objects are aligned.
 @param align The alignment operation required.
 */
- (void)alignObjects:(NSArray<DKDrawableObject*>*)objects toLocation:(NSPoint)loc withAlignment:(DKAlignmentAlign)align;

/** @brief Aligns the objects to the grid, resizing and positioning as necessary so that all edges lie on
 the grid. The logical bounds is used for alignment, consistent with normal snapping behaviour.

 May minimally resize the objects.
 @param objects The objects to align.
 @param grid The grid to use.
 */
- (void)alignObjectEdges:(NSArray<DKDrawableObject*>*)objects toGrid:(DKGridLayer*)grid;

/** @brief Aligns a set of objects so their locations lie on a grid intersection.

 Does not resize the objects.
 @param objects The objects to align.
 @param grid The grid to use.
 */
- (void)alignObjectLocation:(NSArray<DKDrawableObject*>*)objects toGrid:(DKGridLayer*)grid;

/** @brief Computes the amount of space available for a vertical distribution operation.

 The list of objects must be sorted into order of their vertical location.
 The space is the total distance between the top and bottom objects, minus the sum of the heights
 of the objects in between.
 @param objects The objects to align.
 @return The total space available for distribution in the vertical direction.
 */
- (CGFloat)totalVerticalSpace:(NSArray<DKDrawableObject*>*)objects;

/** @brief Computes the amount of space available for a horizontal distribution operation.

 The list of objects must be sorted into order of their horizontal location.
 The space is the total distance between the leftmost and rightmost objects, minus the sum of the widths
 of the objects in between.
 @param objects The objects to align
 @return The total space available for distribution in the horizontal direction
 */
- (CGFloat)totalHorizontalSpace:(NSArray<DKDrawableObject*>*)objects;

/** @brief Sorts a set of objects into order of their vertical location.
 @param objects The objects to sort.
 @return A copy of the array sorted into vertical order.
 */
- (NSArray<DKDrawableObject*>*)objectsSortedByVerticalPosition:(NSArray<DKDrawableObject*>*)objects;

/** @brief Sorts a set of objects into order of their horizontal location.
 @param objects The objects to sort.
 @return A copy of the array sorted into horizontal order.
 */
- (NSArray<DKDrawableObject*>*)objectsSortedByHorizontalPosition:(NSArray<DKDrawableObject*>*)objects;

/** @brief Distributes a set of objects.

 Normally this is called by the higher level alignObjects: methods when a distribution alignment is
 detected.
 @param objects The objects to distribute.
 @param align The distribution required.
 @return \c YES if the operation could be performed, \c NO otherwise.
 */
- (BOOL)distributeObjects:(NSArray<DKDrawableObject*>*)objects withAlignment:(DKAlignmentAlign)align;

/** @brief Returns the minimum number of objects needed to enable the user interface item.

 Call this from a generic validateMenuItem method for the layer as a whole.
 @param item The user interface item to validate.
 @return Number of objects needed for validation. If the item isn't a known alignment command, returns <code>0</code>.
 */
- (NSUInteger)alignmentMenuItemRequiredObjects:(id<NSValidatedUserInterfaceItem>)item;

// user actions:

/** @brief Aligns the selected objects on their left edges
 @param sender the action's sender
 */
- (IBAction)alignLeftEdges:(nullable id)sender;

/** @brief Aligns the selected objects on their right edges
 @param sender the action's sender
 */
- (IBAction)alignRightEdges:(nullable id)sender;

/** @brief Aligns the selected objects on their horizontal centres
 @param sender the action's sender
 */
- (IBAction)alignHorizontalCentres:(nullable id)sender;

/** @brief Aligns the selected objects on their top edges
 @param sender the action's sender
 */
- (IBAction)alignTopEdges:(nullable id)sender;

/** @brief Aligns the selected objects on their bottom edges
 @param sender the action's sender
 */
- (IBAction)alignBottomEdges:(nullable id)sender;

/** @brief Aligns the selected objects on their vertical centres
 @param sender the action's sender
 */
- (IBAction)alignVerticalCentres:(nullable id)sender;

/** @brief Distributes the selected objects to equalize the vertical centres
 @param sender the action's sender
 */
- (IBAction)distributeVerticalCentres:(nullable id)sender;

/** @brief Distributes the selected objects to equalize the vertical space
 @param sender the action's sender
 */
- (IBAction)distributeVerticalSpace:(nullable id)sender;

/** @brief Distributes the selected objects to equalize the horizontal centres
 @param sender the action's sender
 */
- (IBAction)distributeHorizontalCentres:(nullable id)sender;

/** @brief Distributes the selected objects to equalize the horizontal space.
 @param sender The action's sender.
 */
- (IBAction)distributeHorizontalSpace:(nullable id)sender;

- (IBAction)alignEdgesToGrid:(nullable id)sender;
- (IBAction)alignLocationToGrid:(nullable id)sender;

- (IBAction)assignKeyObject:(nullable id)sender;

@end

static const DKAlignmentAlign kDKAlignmentDistributionMask API_DEPRECATED_WITH_REPLACEMENT("kDKAlignmentAlignDistributionMask", macosx(10.0, 10.7)) = kDKAlignmentAlignDistributionMask;
static const DKAlignmentAlign kDKAlignmentHorizontalAlignMask API_DEPRECATED_WITH_REPLACEMENT("kDKAlignmentAlignHorizontalMask", macosx(10.0, 10.7)) = kDKAlignmentAlignHorizontalMask;
static const DKAlignmentAlign kDKAlignmentVerticalAlignMask API_DEPRECATED_WITH_REPLACEMENT("kDKAlignmentAlignVerticalMask", macosx(10.0, 10.7)) = kDKAlignmentAlignVerticalMask;

// alignment helper function:

/** @brief Returns an offset indicating the distance \c sr needs to be moved to give the chosen alignment with \c mr
 @param mr The first bounding rectangle.
 @param sr The second bounding rectangle.
 @param alignment The type of alignment being applied.
 @return An x and y offset. */
NSPoint DKCalculateAlignmentOffset(NSRect mr, NSRect sr, DKAlignmentAlign alignment);

NS_ASSUME_NONNULL_END
