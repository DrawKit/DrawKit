/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKLayer.h"

NS_ASSUME_NONNULL_BEGIN

/** @brief A layer group is a layer which maintains a list of other layers.

 A layer group is a layer which maintains a list of other layers. This permits layers to be organised hierarchically if
 the application wishes to do so.

 \c DKDrawing is a subclass of this, so it inherits the ability to maintain a list of layers. However it doesn't honour
 every possible feature of a layer group, particularly those the group inherits from DKLayer. This is because
 \c DKLayerGroup is actually a refactoring of \c DKDrawing and backward compatibility with existing files is required. In particular one
 should take care not to add a \c DKDrawing instance to a layer group belonging to another drawing (or create circular references).

 The stacking order of layers is arranged so that the top layer always has the index zero, and the bottom is at (count -1).
 In general your code should minimise its exposure to the actual layer index, but the reason that layers are stacked this
 way is so that a layer UI such as a NSTableView doesn't have to do anything special to view layers in a natural way, with
 the top layer at the top of such a table. Prior to beta 3, layers were stacked the other way so such tables appeared to
 be upside-down. This class automatically reverses the stacking order in an archive if it detects an older version.
*/
@interface DKLayerGroup : DKLayer <NSCoding> {
@private
	NSMutableArray<DKLayer*>* m_layers;
}

/** @brief Convenience method for building a new layer group from an existing list of layers

 The group must be added to a drawing to be useful. If the layers are already part of a drawing,
 or other group, they need to be removed first. It is an error to attach a layer in more than one
 group (or drawing, which is a group) at a time.
 Layers should be stacked with the top at index #0, the bottom at #(count -1)
 @param layers a list of existing layers
 @return a new layer group containing the passed layers
 */
+ (nullable instancetype)layerGroupWithLayers:(nullable NSArray<DKLayer*>*)layers;

/** @brief Initialize a layer group

 A layer group must be added to another group or drawing before it can be used
 @param layers a list of existing layers
 @return a new layer group
 */
- (nullable instancetype)initWithLayers:(nullable NSArray<DKLayer*>*)layers NS_DESIGNATED_INITIALIZER;

- (nullable instancetype)initWithCoder:(NSCoder*)coder NS_DESIGNATED_INITIALIZER;

- (instancetype)init;

// layer list

/** @brief The drawing's layers.
 @discussion Layers are usually added one at a time through some user interface, but this setter allows them to
 be set all at once, as when unarchiving. Not recorded for undo.
*/
@property (nonatomic, copy) NSArray<DKLayer*>* layers; // KVC/KVO compliant
//! The number of layers.
@property (readonly) NSUInteger countOfLayers; // KVC/KVO compliant

/** @brief returns the index of the topmost layer that returns \c YES for <code>isOpaque</code>.
 
 @discussion Used for optimising drawing - layers below the highest opaque layer are not drawn (because they can't
 be seen "through" the opaque layer). A layer decides itself if it's opaque by returning \c YES or \c NO for
 <code>isOpaque</code>. If no layers are opaque, returns the index of the bottom layer.
 */
@property (readonly) NSUInteger indexOfHighestOpaqueLayer;

/** @brief returns all of the layers in this group and all groups below it
 
 @discussion The returned list does not contain any layer groups.
 @return a list of layers
 */
- (NSArray<__kindof DKLayer*>*)flattenedLayers;

/** @brief Returns all of the layers in this group and all groups below it.

 @param includeGroups If <code>YES</code>, list includes the groups, \c NO only returns actual layers.
 @return A list of layers.
 */
- (NSArray<__kindof DKLayer*>*)flattenedLayersIncludingGroups:(BOOL)includeGroups;

/** @brief Returns all of the layers in this group and all groups below it having the given class.
 
 @discussion Does not include groups unless the class is <code>DKLayerGroup</code>.

 @param layerClass A \c Class indicating the kind of layer of interest.
 @return A list of matching layers.
 */
- (NSArray<__kindof DKLayer*>*)flattenedLayersOfClass:(Class)layerClass NS_REFINED_FOR_SWIFT;

/** @brief Returns all of the layers in this group and all groups below it having the given class.

 @param layerClass A \c Class indicating the kind of layer of interest
 @param includeGroups If YES, includes groups as well as the requested class
 @return A list of matching layers.
 */
- (NSArray<__kindof DKLayer*>*)flattenedLayersOfClass:(Class)layerClass includeGroups:(BOOL)includeGroups;

/** @brief Returns the hierarchical level of this group, i.e. how deeply nested it is.

 @discussion The root group returns 0, next level is 1 and so on.
 */
@property (readonly) NSUInteger level;

// adding and removing layers

/** @brief Creates and adds a layer to the drawing.
 
 @discussion \c layerClass must be a valid subclass of <code>DKLayer</code>, otherwise does nothing and \c nil is returned.

 @param layerClass The class of some kind of layer.
 @return The layer created.
 */
- (nullable __kindof DKLayer*)addNewLayerOfClass:(Class)layerClass NS_REFINED_FOR_SWIFT;

/** @brief Adds a layer to the group.
 
 @discussion The added layer is placed above all other layers.
 @param aLayer A \c DKLayer object, or subclass thereof.
 */
- (void)addLayer:(DKLayer*)aLayer;

/** @brief adds a layer above a specific index position in the stack
 
 @discussion Layer indexes run from 0 being the top layer to (count - 1), being the bottom layer.
 @param aLayer A \c DKLayer object, or subclass thereof.
 @param layerIndex the index number of the layer the new layer should be placed in front of.
 */
- (void)addLayer:(DKLayer*)aLayer aboveLayerIndex:(NSUInteger)layerIndex;

/** @brief Adds a layer at a specific index position in the stack.
 
 @discussion All other addLayer methods call this, which permits the operation to be undone including restoring
 the layer's index. KVC/KVO compliant.<br>
 Layer indexes run from 0 being the top layer to (count - 1), being the bottom layer.
 @param aLayer A \c DKLayer object, or subclass thereof.
 @param layerIndex the index number of the layer inserted.
 */
- (void)insertObject:(DKLayer*)aLayer inLayersAtIndex:(NSUInteger)layerIndex; // KVC/KVO compliant

/** @brief Remove the layer with a particular index number from the layer.
 
 @discussion All other removeLayer methods call this, which permits the operation to be undone including restoring
 the layer's index. KVC/KVO compliant.<br>
 Layer indexes run from 0 being the top layer to (count -1), being the bottom layer.
 @param layerIndex The index number of the layer to remove.
 */
- (void)removeObjectFromLayersAtIndex:(NSUInteger)layerIndex; // KVC/KVO compliant

/** @brief Removes the layer from the drawing.
 
 @discussion Disposes of the layer if there are no other references to it.
 @param aLayer A \c DKLayer object, or subclass thereof, that already exists in the group.
 */
- (void)removeLayer:(DKLayer*)aLayer;

/** @brief removes all of the group's layers

 @discussion This method is not undoable. To undoably remove a layer, remove them one at a time. KVO observers
 will not be notified by this method.
 */
- (void)removeAllLayers;

/** @brief Disambiguates a layer's name by appending digits until there is no conflict.
 
 @discussion It is not important that layer's have unique names, but a UI will usually want to do this, thus
 when using the \c addLayer:andActivateIt: method, the name of the added layer is disambiguated.
 @param aName A string containing the proposed name.
 @return A string, either the original string or a modified version of it.
 */
- (NSString*)uniqueLayerNameForName:(NSString*)aName;

// getting layers

/** @brief Returns the layer object at the given index.
 
 @discussion Layer indexes run from 0 being the top layer to (count - 1), being the bottom layer. KVC/KVO compliant.
 @param layerIndex The index number of the layer of interest.
 @return A \c DKLayer object or subclass.
 */
- (__kindof DKLayer*)objectInLayersAtIndex:(NSUInteger)layerIndex; // KVC/KVO compliant

/** @brief returns the topmost layer

 @discussion the topmost \c DKLayer object or subclass, or \c nil if there are no layers.

 Ignores opacity of layers in the stack - this is the one on the top, regardless.
 */
@property (readonly, strong, nullable) __kindof DKLayer* topLayer;

/** @brief The bottom layer.

 @discussion the bottom \c DKLayer object or subclass, or \c nil if there are no layers.

 Ignores opacity of layers in the stack - this is the one on the bottom, regardless.
 */
@property (readonly, strong, nullable) __kindof DKLayer* bottomLayer;

/** @brief Returns the stack position of a given layer.
 
 @discussion layer indexes run from 0 being the top layer to (count - 1), being the bottom layer. If the group does
 not contain the layer, returns <code>NSNotFound</code>. See also <code>-containsLayer:</code>.

 @param aLayer A \c DKLayer object, or subclass thereof, that already exists in the drawing.
 @return The stack index position of the layer.
 */
- (NSUInteger)indexOfLayer:(DKLayer*)aLayer;

/** @brief returns the uppermost layer matching class, if any

 @discussion does not perform a deep search
 @param cl The class of layer to seek.
 @return The uppermost layer of the given class, or <code>nil</code>.
 */
- (nullable __kindof DKLayer*)firstLayerOfClass:(Class)cl NS_REFINED_FOR_SWIFT;

/** @brief returns the uppermost layer matching class, if any

 @param cl The class of layer to seek.
 @param deep If <code>YES</code>, will search all subgroups below this one. If <code>NO</code>, only this level is searched.
 @return The uppermost layer of the given class, or <code>nil</code>.
 */
- (nullable __kindof DKLayer*)firstLayerOfClass:(Class)cl performDeepSearch:(BOOL)deep NS_REFINED_FOR_SWIFT;

/** @brief returns a list of layers of the given class

 @discussion does not perform a deep search
 @param cl The class of layer to seek.
 @return A list of layers. May be empty.
 */
- (NSArray<__kindof DKLayer*>*)layersOfClass:(Class)cl NS_REFINED_FOR_SWIFT;

/** @brief returns a list of layers of the given class

 @param cl The class of layer to seek.
 @param deep If <code>YES</code>, will search all subgroups below this one. If <code>NO</code>, only this level is searched.
 @return A list of layers. May be empty.
 */
- (NSArray<__kindof DKLayer*>*)layersOfClass:(Class)cl performDeepSearch:(BOOL)deep NS_REFINED_FOR_SWIFT;

/** @brief returns an enumerator that can be used to iterate over the layers in top to bottom order

 @discussion this is provided as a convenience so you don't have to worry about the implementation detail of
 which way round layers are ordered to give the top to bottom visual stacking.
 @return An \c NSEnumerator object.
 */
- (NSEnumerator<DKLayer*>*)layerTopToBottomEnumerator;

/** @brief Returns an enumerator that can be used to iterate over the layers in bottom to top order.

 @discussion This is provided as a convenience so you don't have to worry about the implementation detail of
 which way round layers are ordered to give the top to bottom visual stacking.
 @return An \c NSEnumerator object.
 */
- (NSEnumerator<DKLayer*>*)layerBottomToTopEnumerator;

/** @brief find the topmost layer in this group that is 'hit' by the given point
 
 @discussion A layer must implement \c hitLayer: sensibly for this to operate. This recurses down
 through any groups contained within. See also <code>-hitLayer:</code>.

 @param aPoint A point in drawing coordinates.
 @return A layer, or <code>nil</code>.
 */
- (nullable __kindof DKLayer*)findLayerForPoint:(NSPoint)aPoint;

/** @brief returns whether this group, or any subgroup within, contains the layer
 
 @discussion Unlike <code>-indexOfLayer:</code>, considers nested subgroups.  If the layer is the group, returns \c NO
 (doesn't contain itself).
 @param  aLayer A layer of interest.
 @return \c YES if the group contains the layer.
 */
- (BOOL)containsLayer:(DKLayer*)aLayer;

/** @brief Returns a layer or layer group having the given unique key

 Unique keys are assigned to layers for the lifetime of the app. They are not persistent and must only
 be used to find layers in the case where a layer pointer/address would be unreliable.
 @param key The layer's key.
 @return the layer if found, nil otherwise.
 */
- (nullable __kindof DKLayer*)layerWithUniqueKey:(NSString*)key;

// showing and hiding

/** @brief Makes all layers in the group and in any subgroups visible

 Recurses when nested groups are found
 */
- (void)showAll;

/** @brief Makes all layers in the group and in any subgroups hidden except <code>aLayer</code>, which is made visible.

 \c aLayer may be \c nil in which case this performs a <code>hideAll</code>. Recurses on any subgroups.
 @param aLayer a layer to leave visible
 */
- (void)hideAllExcept:(nullable DKLayer*)aLayer;

/** @brief Is \c YES if there are hidden layers below this, or this is hidden itself.
 @discussion Recurses on any subgroups.
 */
@property (readonly) BOOL hasHiddenLayers;

/** @brief Returns YES if the  receiver or any of its contained layers is visible, ignoring the one passed

 Recurses on any subgroups. Typically \c aLayer is the active layer - may be <code>nil</code>.
 @param aLayer a layer to exclude when testing this
 @return YES if there are visible layers below this, or this is visible itself
 */
- (BOOL)hasVisibleLayersOtherThan:(nullable DKLayer*)aLayer;

// layer stacking order

/** @brief Moves the layer one place towards the top of the stack.

 @discussion If already on top, does nothing.
 @param aLayer the layer to move up.
 */
- (void)moveUpLayer:(DKLayer*)aLayer;

/** @brief Moves the layer one place towards the bottom of the stack.
 
 @discussion If already at the bottom, does nothing.
 @param aLayer The layer to move down.
 */
- (void)moveDownLayer:(DKLayer*)aLayer;

/** @brief Moves the layer to the top of the stack.
 
 @discussion If already on top, does nothing.
 @param aLayer The layer to move up.
 */
- (void)moveLayerToTop:(DKLayer*)aLayer;

/// @brief Moves the layer to the bottom of the stack.
///
/// @param aLayer The layer to move down.
///
/// @discussion If already at the bottom, does nothing.
- (void)moveLayerToBottom:(DKLayer*)aLayer;

/** @brief Changes a layer's z-stacking order so it comes before (above) <code>otherLayer</code>.

 @param aLayer The layer to move - may not be <code>nil</code>.
 @param otherLayer Move above this layer. May be <code>nil</code>, which moves the layer to the bottom.
 */
- (void)moveLayer:(DKLayer*)aLayer aboveLayer:(nullable DKLayer*)otherLayer;

/** @brief Changes a layer's z-stacking order so it comes after (below) <otherLayer>

 @param aLayer The layer to move - may not be <code>nil</code>.
 @param otherLayer Move below this layer. May be <code>nil</code>, which moves the layer to the top.
 */
- (void)moveLayer:(DKLayer*)aLayer belowLayer:(nullable DKLayer*)otherLayer;

/** @brief Moves a layer to the index position given. This is called by all if the other \c moveLayer... methods.
 
 @discussion If the layer can't be moved, does nothing. The action is recorded for undo if there is an undoManager attached.
 @param aLayer The layer to move.
 @param i The index position to move it to.
 */
- (void)moveLayer:(DKLayer*)aLayer toIndex:(NSUInteger)i;

@end

extern NSNotificationName const kDKLayerGroupDidAddLayer;
extern NSNotificationName const kDKLayerGroupDidRemoveLayer;
extern NSNotificationName const kDKLayerGroupNumberOfLayersDidChange;
extern NSNotificationName const kDKLayerGroupWillReorderLayers;
extern NSNotificationName const kDKLayerGroupDidReorderLayers;

NS_ASSUME_NONNULL_END
