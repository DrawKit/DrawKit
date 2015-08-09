/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2015
 @copyright MPL2; see LICENSE.txt
*/

#import "DKDrawableShape.h"
#import "DKDrawableContainerProtocol.h"

@class DKObjectDrawingLayer;

// caching options

typedef enum {
	kDKGroupCacheNone = 0,
	kDKGroupCacheUsingPDF = (1 << 0),
	kDKGroupCacheUsingCGLayer = (1 << 1)
} DKGroupCacheOption;

/** @brief This is a group objects that can group any number of shapes or paths.

This is a group objects that can group any number of shapes or paths.

It inherits from DKDrawableShape so that it gets the usual sizing and rotation behaviours.

This operates by establishing its own coordinate system in which the objects are embedded. An informal protocol is used that allows a shape or
path to obtain the transform of its "parent". When that parent is a group, the transform is manipulated such that the path is modified just
prior to rendering to allow for the group's size, rotation, etc.

Be aware of one "gotcha" with this class - a bit of a chicken-and-egg situation. When objects are grouped, they are offset to be local to the group's
overall location. For grouping to be undoable, the objects being grouped need to have a valid container at the time this location offset is done,
so that there is an undo manager available to record that change. If not they might end up in the wrong place when undoing the "group" command.

For the normal case of grouping existing objects within a layer, this is not an issue, but can be if you are programmatically creating groups.
*/
@interface DKShapeGroup : DKDrawableShape <NSCoding, NSCopying, DKDrawableContainer> {
@private
	NSArray* m_objects; // objects in the group
	NSRect mBounds; // overall bounding rect of the group
	BOOL m_transformVisually; // if YES, group transform is visual only (like SVG) otherwise it's genuine
	CGLayerRef mContentCache; // used to cache content
	NSPDFImageRep* mPDFContentCache; // used to cache content at higher quality
	DKGroupCacheOption mCacheOption; // caching options
	BOOL mIsWritingToCache; // YES when building cache - modifies transforms
	BOOL mClipContentToPath; // YES to clip group content to the group's path
}

// creating new groups:

/** @brief Creates a group of shapes or paths from a list of bezier paths

 This constructs a group from a list of bezier paths by wrapping a drawable around each path then
 grouping the result. While general purpose in nature, this is primarily to support the construction
 of a group containing text glyphs from a text shape object. The group's location is set to the
 centre of the union of the bounds of all created objects, which in turn depends on the paths' positions.
 caller may wish to move the group before adding it to a layer.
 @param paths a list of NSBezierPath objects
 @param type a value indicating what type of objects the group should consist of. Can be 0 = shapes or
 @param style a style object to apply to each new shape or path as it is created; pass nil to create
 @return a new group object consisting of a set of other objects built from the supplied paths
 */
+ (DKShapeGroup*)groupWithBezierPaths:(NSArray*)paths objectType:(NSInteger)type style:(DKStyle*)style;

/** @brief Creates a group from a list of existing objects

 Initial location is at the centre of the rectangle that bounds all of the contributing objects.
 the objects can be newly created or already existing as part of a drawing. Grouping the objects
 will change the parent of the object but not the owner until the group is placed. The group should
 be added to a drawing layer after creation. The higher level "group" command in the drawing layer
 class will set up a group from the selection.
 @param objects a list of drawable objects
 @return a new group object consisting of the objects supplied
 */
+ (DKShapeGroup*)groupWithObjects:(NSArray*)objects;

/** @brief Filters array to remove objects whose class returns NO to isGroupable.
 @param array a list of drawable objects
 @return an array of the same objects less those that can't be grouped
 */
+ (NSArray*)objectsAvailableForGroupingFromArray:(NSArray*)array;

// setting up the group:

/** @brief Initialises a group from a list of existing objects

 Designated initialiser. initial location is at the centre of the rectangle that bounds all of
 the contributing objects.
 the objects can be newly created or already existing as part of a drawing. Grouping the objects
 will change the parent of the object but not the owner until the group is placed. The group should
 be added to a drawing layer after creation. The higher level "group" command in the drawing layer
 class will set up a group from the selection.
 @param objects a list of drawable objects
 @return the group object
 */
- (id)initWithObjectsInArray:(NSArray*)objects;

/** @brief Sets up the group state from the original set of objects

 This sets the initial size and location of the group, and adjusts the position of each object so
 it is relative to the group, not the original drawing. It also sets the parent member of each object
 to the group so that the group's transform is applied when the objects are drawn.
 @param objects the set of objects to be grouped
 */
- (void)setGroupObjects:(NSArray*)objects;

/** @brief Gets the list of objects contained by the group
 @return the list of contained objects
 */
- (NSArray*)groupObjects;

/** @brief Computes the initial overall bounding rect of the constituent objects

 This sets the _bounds member to the union of the apparent bounds of the constituent objects. This
 rect represents the original size and position of the group, and does not change even if the group
 is moved or resized - transforms are calculated by comparing the original bounds to the instantaneous
 size and position.
 @param objects the objects to be grouped */
- (void)calcBoundingRectOfObjects:(NSArray*)objects;

/** @brief Computes the extra space needed for the objects
 @param objects the objects to be grouped
 @return a size, the maximum width and height needed to be added to the logical bounds to accomodate the
 objects visually. */

/** @brief Returns the extra space needed to display the object graphically. This will usually be the difference
 between the logical and reported bounds.

 The result is the max of all the contained objects
 @return the extra space required
 */
- (NSSize)extraSpaceNeededByObjects:(NSArray*)objects;

/** @brief Returns the original untransformed bounds of the grouped objects
 @return the original group bounds
 */
- (NSRect)groupBoundingRect;

/** @brief Returns the scale ratios that the group is currently applying to its contents.

 The scale ratio is the ratio between the group's original bounds and its current size.
 @return the scale ratios
 */
- (NSSize)groupScaleRatios;

/** @brief Sets the current list of objects to the given objects

 This is a low level method called by setGroupObjects: it implements the undoable part of building
 a group. It should not be directly called.
 @param objects the objects to be grouped */
- (void)setObjects:(NSArray*)objects;

// drawing the group:

/** @brief Returns a transform used to map the contained objects to the group's size, position and angle.

 This transform is used when drawing the group's contents
 @return a transform object */
- (NSAffineTransform*)contentTransform;

/** @brief Returns a transform which is the accumulation of all the parent objects above this one.

 Drawables will request and apply this transform when rendering. Either the identity matrix is
 returned if the group is visually transforming the result, or a combination of the parents above
 and the content transform. Either way contained objects are oblivious and do the right thing.
 @return a transform object */
- (NSAffineTransform*)renderingTransform;

/** @brief Maps a point from the original container's coordinates to the equivalent group point

 The container will be usually a layer or another group.
 @param p a point
 @return a new point */
- (NSPoint)convertPointFromContainer:(NSPoint)p;

/** @brief Maps a point from the group's coordinates to the equivalent original container point

 The container will be usually a layer or another group.
 @param p a point
 @return a new point */
- (NSPoint)convertPointToContainer:(NSPoint)p;
- (void)drawGroupContent;

- (void)setClipContentToPath:(BOOL)clip;
- (BOOL)clipContentToPath;

- (void)setTransformsVisually:(BOOL)tv;
- (BOOL)transformsVisually;

// caching:

- (void)setCacheOptions:(DKGroupCacheOption)cacheOption;
- (DKGroupCacheOption)cacheOptions;

// ungrouping:

/** @brief Unpacks the group back into the nominated layer 

 Usually it's better to call the higher level ungroupObjects: action method which calls this. This
 method strives to preserve as much information about the objects as possible - e.g. their rotation
 angle and size. Nested groups can cause distortions which are visually preserved though the bounds
 muct necessarily be altered. Objects are inserted into the layer at the same Z-index position as
 the group currently occupies.
 @param layer the layer into which the objects are unpacked */
- (void)ungroupToLayer:(DKObjectDrawingLayer*)layer;

/** @brief High-level call to ungroup the group.

 Undoably ungroups this and replaces itself in its layer by its contents
 @param sender the sender of the action
 */
- (IBAction)ungroupObjects:(id)sender;

/** @brief High-level call to toggle path clipping.
 @param sender the sender of the action
 */
- (IBAction)toggleClipToPath:(id)sender;

@end

// constant that can be passed as <objectType> to groupWithBezierPaths:objectType:style:

enum {
	kDKCreateGroupWithShapes = 0,
	kDKCreateGroupWithPaths = 1
};
