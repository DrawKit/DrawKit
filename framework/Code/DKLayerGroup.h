///**********************************************************************************************************************************
///  DKLayerGroup.h
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 23/08/2007.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKLayer.h"


@interface DKLayerGroup : DKLayer <NSCoding>
{
@private
	NSMutableArray*			m_layers;
}

+ (DKLayerGroup*)			layerGroupWithLayers:(NSArray*) layers;

- (id)						initWithLayers:(NSArray*) layers;

// layer list

- (void)					setLayers:(NSArray*) layers;											// KVC/KVO compliant
- (NSArray*)				layers;																	// KVC/KVO compliant
- (NSUInteger)				countOfLayers;															// KVC/KVO compliant
- (NSUInteger)				indexOfHighestOpaqueLayer;

- (NSArray*)				flattenedLayers;
- (NSArray*)				flattenedLayersIncludingGroups:(BOOL) includeGroups;
- (NSArray*)				flattenedLayersOfClass:(Class) layerClass;
- (NSArray*)				flattenedLayersOfClass:(Class) layerClass includeGroups:(BOOL) includeGroups;

- (NSUInteger)				level;

// adding and removing layers

- (DKLayer*)				addNewLayerOfClass:(Class) layerClass;
- (void)					addLayer:(DKLayer*) aLayer;
- (void)					addLayer:(DKLayer*) aLayer aboveLayerIndex:(NSUInteger) layerIndex;
- (void)					insertObject:(DKLayer*) aLayer inLayersAtIndex:(NSUInteger) layerIndex;	// KVC/KVO compliant
- (void)					removeObjectFromLayersAtIndex:(NSUInteger) layerIndex;					// KVC/KVO compliant
- (void)					removeLayer:(DKLayer*) aLayer;
- (void)					removeAllLayers;
- (NSString*)				uniqueLayerNameForName:(NSString*) aName;

// getting layers

- (DKLayer*)				objectInLayersAtIndex:(NSUInteger) layerIndex;							// KVC/KVO compliant
- (DKLayer*)				topLayer;
- (DKLayer*)				bottomLayer;
- (NSUInteger)				indexOfLayer:(DKLayer*) aLayer;
- (DKLayer*)				firstLayerOfClass:(Class) cl;
- (DKLayer*)				firstLayerOfClass:(Class) cl performDeepSearch:(BOOL) deep;
- (NSArray*)				layersOfClass:(Class) cl;
- (NSArray*)				layersOfClass:(Class) cl performDeepSearch:(BOOL) deep;
- (NSEnumerator*)			layerTopToBottomEnumerator;
- (NSEnumerator*)			layerBottomToTopEnumerator;

- (DKLayer*)				findLayerForPoint:(NSPoint) aPoint;
- (BOOL)					containsLayer:(DKLayer*) aLayer;

- (DKLayer*)				layerWithUniqueKey:(NSString*) key;

// showing and hiding

- (void)					showAll;
- (void)					hideAllExcept:(DKLayer*) aLayer;
- (BOOL)					hasHiddenLayers;
- (BOOL)					hasVisibleLayersOtherThan:(DKLayer*) aLayer;

// layer stacking order

- (void)					moveUpLayer:(DKLayer*) aLayer;
- (void)					moveDownLayer:(DKLayer*) aLayer;
- (void)					moveLayerToTop:(DKLayer*) aLayer;
- (void)					moveLayerToBottom:(DKLayer*) aLayer;
- (void)					moveLayer:(DKLayer*) aLayer aboveLayer:(DKLayer*) otherLayer;
- (void)					moveLayer:(DKLayer*) aLayer belowLayer:(DKLayer*) otherLayer;
- (void)					moveLayer:(DKLayer*) aLayer toIndex:(NSUInteger) i;


@end


extern NSString*		kDKLayerGroupDidAddLayer;
extern NSString*		kDKLayerGroupDidRemoveLayer;
extern NSString*		kDKLayerGroupNumberOfLayersDidChange;
extern NSString*		kDKLayerGroupWillReorderLayers;
extern NSString*		kDKLayerGroupDidReorderLayers;


/*

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

