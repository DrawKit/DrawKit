/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2015
 @copyright MPL2; see LICENSE.txt
*/

#import "DKLayer.h"

/** @brief A layer group is a layer which maintains a list of other layers.

A layer group is a layer which maintains a list of other layers. This permits layers to be organised hierarchically if
the application wishes to do so.

DKDrawing is a subclass of this, so it inherits the ability to maintain a list of layers. However it doesn't honour
every possible feature of a layer group, particularly those the group inherits from DKLayer. This is because
DKLayerGroup is actually a refactoring of DKDrawing and backward compatibility with existing files is required. In particular one
should take care not to add a DKDrawing instance to a layer group belonging to another drawing (or create circular references).

The stacking order of layers is arranged so that the top layer always has the index zero, and the bottom is at (count -1).
In general your code should minimise its exposure to the actual layer index, but the reason that layers are stacked this
way is so that a layer UI such as a NSTableView doesn't have to do anything special to view layers in a natural way, with
the top layer at the top of such a table. Prior to beta 3, layers were stacked the other way so such tables appeared to
be upside-down. This class automatically reverses the stacking order in an archive if it detects an older version.
*/
@interface DKLayerGroup : DKLayer <NSCoding> {
@private
	NSMutableArray* m_layers;
}

/** @brief Convenience method for building a new layer group from an existing list of layers

 The group must be added to a drawing to be useful. If the layers are already part of a drawing,
 or other group, they need to be removed first. It is an error to attach a layer in more than one
 group (or drawing, which is a group) at a time.
 Layers should be stacked with the top at index #0, the bottom at #(count -1)
 @param layers a list of existing layers
 @return a new layer group containing the passed layers
 */
+ (DKLayerGroup*)layerGroupWithLayers:(NSArray*)layers;

/** @brief Initialize a layer group

 A layer group must be added to another group or drawing before it can be used
 @param layers a list of existing layers
 @return a new layer group
 */
- (id)initWithLayers:(NSArray*)layers;

// layer list

- (void)setLayers:(NSArray*)layers; // KVC/KVO compliant
- (NSArray*)layers; // KVC/KVO compliant
- (NSUInteger)countOfLayers; // KVC/KVO compliant
- (NSUInteger)indexOfHighestOpaqueLayer;

- (NSArray*)flattenedLayers;
- (NSArray*)flattenedLayersIncludingGroups:(BOOL)includeGroups;
- (NSArray*)flattenedLayersOfClass:(Class)layerClass;
- (NSArray*)flattenedLayersOfClass:(Class)layerClass includeGroups:(BOOL)includeGroups;

/** @brief Returns the hierarchical level of this group, i.e. how deeply nested it is

 The root group returns 0, next level is 1 and so on. 
 @return the group's level
 */
- (NSUInteger)level;

// adding and removing layers

- (DKLayer*)addNewLayerOfClass:(Class)layerClass;
- (void)addLayer:(DKLayer*)aLayer;
- (void)addLayer:(DKLayer*)aLayer aboveLayerIndex:(NSUInteger)layerIndex;
- (void)insertObject:(DKLayer*)aLayer inLayersAtIndex:(NSUInteger)layerIndex; // KVC/KVO compliant
- (void)removeObjectFromLayersAtIndex:(NSUInteger)layerIndex; // KVC/KVO compliant
- (void)removeLayer:(DKLayer*)aLayer;
- (void)removeAllLayers;
- (NSString*)uniqueLayerNameForName:(NSString*)aName;

// getting layers

- (DKLayer*)objectInLayersAtIndex:(NSUInteger)layerIndex; // KVC/KVO compliant
- (DKLayer*)topLayer;
- (DKLayer*)bottomLayer;
- (NSUInteger)indexOfLayer:(DKLayer*)aLayer;
- (DKLayer*)firstLayerOfClass:(Class)cl;
- (DKLayer*)firstLayerOfClass:(Class)cl performDeepSearch:(BOOL)deep;
- (NSArray*)layersOfClass:(Class)cl;
- (NSArray*)layersOfClass:(Class)cl performDeepSearch:(BOOL)deep;
- (NSEnumerator*)layerTopToBottomEnumerator;
- (NSEnumerator*)layerBottomToTopEnumerator;

- (DKLayer*)findLayerForPoint:(NSPoint)aPoint;
- (BOOL)containsLayer:(DKLayer*)aLayer;

/** @brief Returns a layer or layer group having the given unique key

 Unique keys are assigned to layers for the lifetime of the app. They are not persistent and must only
 @param key the layer's key
 @return the layer if found, nil otherwise.
 */
- (DKLayer*)layerWithUniqueKey:(NSString*)key;

// showing and hiding

/** @brief Makes all layers in the group and in any subgroups visible

 Recurses when nested groups are found
 */
- (void)showAll;

/** @brief Makes all layers in the group and in any subgroups hidden except <aLayer>, which is made visible.

 ALayer may be nil in which case this performs a hideAll. Recurses on any subgroups.
 @param aLayer a layer to leave visible
 */
- (void)hideAllExcept:(DKLayer*)aLayer;

/** @brief Returns YES if the  receiver or any of its contained layers is hidden

 Recurses on any subgroups.
 @return YES if there are hidden layers below this, or this is hidden itself
 */
- (BOOL)hasHiddenLayers;

/** @brief Returns YES if the  receiver or any of its contained layers is visible, ignoring the one passed

 Recurses on any subgroups. Typically <aLayer> is the active layer - may be nil.
 @param aLayer a layer to exclude when testing this
 @return YES if there are visible layers below this, or this is visible itself
 */
- (BOOL)hasVisibleLayersOtherThan:(DKLayer*)aLayer;

// layer stacking order

- (void)moveUpLayer:(DKLayer*)aLayer;
- (void)moveDownLayer:(DKLayer*)aLayer;
- (void)moveLayerToTop:(DKLayer*)aLayer;
- (void)moveLayerToBottom:(DKLayer*)aLayer;
- (void)moveLayer:(DKLayer*)aLayer aboveLayer:(DKLayer*)otherLayer;
- (void)moveLayer:(DKLayer*)aLayer belowLayer:(DKLayer*)otherLayer;
- (void)moveLayer:(DKLayer*)aLayer toIndex:(NSUInteger)i;

@end

extern NSString* kDKLayerGroupDidAddLayer;
extern NSString* kDKLayerGroupDidRemoveLayer;
extern NSString* kDKLayerGroupNumberOfLayersDidChange;
extern NSString* kDKLayerGroupWillReorderLayers;
extern NSString* kDKLayerGroupDidReorderLayers;
