/**
 * @author Graham Cox, Apptree.net
 * @author Graham Miln, miln.eu
 * @author Contributions from the community
 * @date 2005-2013
 * @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import "DKObjectDrawingLayer.h"

@class DKGridLayer;

enum {
    kDKAlignmentLeftEdge = 0,
    kDKAlignmentTopEdge = 1,
    kDKAlignmentRightEdge = 2,
    kDKAlignmentBottomEdge = 3,
    kDKAlignmentVerticalCentre = 4,
    kDKAlignmentHorizontalCentre = 5,
    kDKAlignmentVerticalDistribution = 6,
    kDKAlignmentHorizontalDistribution = 7,
    kDKAlignmentVSpaceDistribution = 8,
    kDKAlignmentHSpaceDistribution = 9,
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
    kDKAlignmentHorizontalAlignMask = kDKAlignmentAlignLeftEdge | kDKAlignmentAlignRightEdge | kDKAlignmentAlignHorizontalCentre | kDKAlignmentAlignHDistribution | kDKAlignmentAlignHSpaceDistribution,
    kDKAlignmentVerticalAlignMask = kDKAlignmentAlignTopEdge | kDKAlignmentAlignBottomEdge | kDKAlignmentAlignVerticalCentre | kDKAlignmentAlignVDistribution | kDKAlignmentAlignVSpaceDistribution,
    kDKAlignmentDistributionMask = kDKAlignmentAlignVDistribution | kDKAlignmentAlignHDistribution | kDKAlignmentAlignVSpaceDistribution | kDKAlignmentAlignHSpaceDistribution
};

/**
This category implements object alignment features for DKObjectDrawingLayer
*/
@interface DKObjectDrawingLayer (Alignment)

// setting the key object (used by alignment methods)

/** @brief Nominates an object as the master to be used for alignment operations, etc
 * @note
 * The object is not retained as it should already be owned. A nil object can be set to mean that the
 * topmost select object should be considered key.
 * @param keyObject an object that is to be considered key for alignment ops
 * @public
 */
- (void)setKeyObject:(DKDrawableObject*)keyObject;

/** @brief Returns the object as the master to be used for alignment operations, etc
 * @note
 * If no specific object is set (nil), then the first object in the selection is returned. If there's
 * no selection, returns nil. 
 * @return an object that is to be considered key for alignment ops
 * @public
 */
- (DKDrawableObject*)keyObject;

/** @brief Aligns a set of objects
 * @note
 * Objects are aligned with the layer's nominated key object, by default the first object in the supplied list
 * @param objects the objects to align
 * @param align the alignment operation required
 * @public
 */
- (void)alignObjects:(NSArray*)objects withAlignment:(NSInteger)align;

/** @brief Aligns a set ofobjects
 * @param objects the objects to align
 * @param object the "master" object - the one to which the others are aligned
 * @param align the alignment operation required
 * @public
 */
- (void)alignObjects:(NSArray*)objects toMasterObject:(id)object withAlignment:(NSInteger)align;

/** @brief Aligns a set of objects to a given point
 * @param objects the objects to align
 * @param loc the point to which the objects are aligned
 * @param align the alignment operation required
 * @public
 */
- (void)alignObjects:(NSArray*)objects toLocation:(NSPoint)loc withAlignment:(NSInteger)align;

/** @brief Aligns the objects to the grid, resizing and positioning as necessary so that all edges lie on
 * the grid. The logical bounds is used for alignment, consistent with normal snapping behaviour.
 * @note
 * May minimally resize the objects.
 * @param objects the objects to align
 * @param grid the grid to use
 * @public
 */
- (void)alignObjectEdges:(NSArray*)objects toGrid:(DKGridLayer*)grid;

/** @brief Aligns a set of objects so their locations lie on a grid intersection
 * @note
 * Does not resize the objects
 * @param objects the objects to align
 * @param grid the grid to use
 * @public
 */
- (void)alignObjectLocation:(NSArray*)objects toGrid:(DKGridLayer*)grid;

/** @brief Computes the amount of space available for a vertical distribution operation
 * @note
 * The list of objects must be sorted into order of their vertical location.
 * The space is the total distance between the top and bottom objects, minus the sum of the heights
 * of the objects in between
 * @param objects the objects to align
 * @return the total space available for distribution in the vertical direction
 * @private
 */
- (CGFloat)totalVerticalSpace:(NSArray*)objects;

/** @brief Computes the amount of space available for a horizontal distribution operation
 * @note
 * The list of objects must be sorted into order of their horizontal location.
 * The space is the total distance between the leftmost and rightmost objects, minus the sum of the widths
 * of the objects in between
 * @param objects the objects to align
 * @return the total space available for distribution in the horizontal direction
 * @private
 */
- (CGFloat)totalHorizontalSpace:(NSArray*)objects;

/** @brief Sorts a set of objects into order of their vertical location
 * @param objects the objects to sort
 * @return a copy of the array sorted into vertical order
 * @private
 */
- (NSArray*)objectsSortedByVerticalPosition:(NSArray*)objects;

/** @brief Sorts a set of objects into order of their horizontal location
 * @param objects the objects to sort
 * @return a copy of the array sorted into horizontal order
 * @private
 */
- (NSArray*)objectsSortedByHorizontalPosition:(NSArray*)objects;

/** @brief Distributes a set of objects
 * @note
 * Normally this is called by the higher level alignObjects: methods when a distribution alignment is
 * detected
 * @param objects the objects to distribute
 * @param align the distribution required
 * @return YES if the operation could be performed, NO otherwise
 * @public
 */
- (BOOL)distributeObjects:(NSArray*)objects withAlignment:(NSInteger)align;

/** @brief Returns the minimum number of objects needed to enable the user interface item
 * @note
 * Call this from a generic validateMenuItem method for the layer as a whole
 * @param item the user interface item to validate
 * @return number of objects needed for validation. If the item isn't a known alignment command, returns 0
 * @public
 */
- (NSUInteger)alignmentMenuItemRequiredObjects:(id<NSValidatedUserInterfaceItem>)item;

// user actions:

/** @brief Aligns the selected objects on their left edges
 * @param sender the action's sender
 * @public
 */
- (IBAction)alignLeftEdges:(id)sender;

/** @brief Aligns the selected objects on their right edges
 * @param sender the action's sender
 * @public
 */
- (IBAction)alignRightEdges:(id)sender;

/** @brief Aligns the selected objects on their horizontal centres
 * @param sender the action's sender
 * @public
 */
- (IBAction)alignHorizontalCentres:(id)sender;

/** @brief Aligns the selected objects on their top edges
 * @param sender the action's sender
 * @public
 */
- (IBAction)alignTopEdges:(id)sender;

/** @brief Aligns the selected objects on their bottom edges
 * @param sender the action's sender
 * @public
 */
- (IBAction)alignBottomEdges:(id)sender;

/** @brief Aligns the selected objects on their vertical centres
 * @param sender the action's sender
 * @public
 */
- (IBAction)alignVerticalCentres:(id)sender;

/** @brief Distributes the selected objects to equalize the vertical centres
 * @param sender the action's sender
 * @public
 */
- (IBAction)distributeVerticalCentres:(id)sender;

/** @brief Distributes the selected objects to equalize the vertical space
 * @param sender the action's sender
 * @public
 */
- (IBAction)distributeVerticalSpace:(id)sender;

/** @brief Distributes the selected objects to equalize the horizontal centres
 * @param sender the action's sender
 * @public
 */
- (IBAction)distributeHorizontalCentres:(id)sender;

/** @brief Distributes the selected objects to equalize the horizontal space
 * @param sender the action's sender
 * @public
 */
- (IBAction)distributeHorizontalSpace:(id)sender;

- (IBAction)alignEdgesToGrid:(id)sender;
- (IBAction)alignLocationToGrid:(id)sender;

- (IBAction)assignKeyObject:(id)sender;

@end

// alignment helper function:

NSPoint calculateAlignmentOffset(NSRect mr, NSRect sr, NSInteger alignment);
