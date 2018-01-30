/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKRasterizer.h"

NS_ASSUME_NONNULL_BEGIN

@class DKRastGroup;

/** @brief A rendergroup is a single renderer which contains a list of other renderers.

 A rendergroup is a single renderer which contains a list of other renderers. Each renderer is applied to the object
 in list order.

 Because the group is itself a renderer, it can be added to other groups, etc to form complex trees of rendering
 behaviour.

 A group saves and restores the graphics state around all of its calls, so can also be used to "bracket" sets of
 rendering operations together.

 The rendering group is the basis for the more application-useful drawing style object.
 
 Because \c DKRasterizer inherits from GCObservableObject, the group object supports a KVO-based approach for observing its
 components. Whenever a component is added or removed from a group, the root object (typically a style) is informed through
 the observableWasAdded: observableWillBeRemoved: methods. If the root object is indeed interested in observing the object,
 it should call its \c setUpKVOForObserver and \c tearDownKVOForObserver methods. Groups propagate these messages down the tree
 as well, so the root object is given the opportunity to observe any component anywhere in the tree. Additionally, groups
 themselves are observed for changes to their lists, so the root object is able to track changes to the group structure
as well.
*/
@interface DKRastGroup : DKRasterizer <NSCoding, NSCopying> {
@private
	NSMutableArray<DKRasterizer*>* m_renderList;
}

/** @brief The list of contained renderers.

 The setter no longer attempts to try and manage observing of the objects. The observer must
 properly stop observing before this is called, or start observing after it is called when
 initialising from an archive.
*/
@property (nonatomic, copy, nullable) NSArray<DKRasterizer*>* renderList;

- (DKRastGroup*)root;

- (void)observableWasAdded:(GCObservableObject*)observable;
- (void)observableWillBeRemoved:(GCObservableObject*)observable;

- (void)addRenderer:(DKRasterizer*)renderer;
- (void)removeRenderer:(DKRasterizer*)renderer;
- (void)moveRendererAtIndex:(NSUInteger)src toIndex:(NSUInteger)dest;
- (void)insertRenderer:(DKRasterizer*)renderer atIndex:(NSUInteger)index;
- (void)removeRendererAtIndex:(NSUInteger)index;
- (NSUInteger)indexOfRenderer:(DKRasterizer*)renderer;

- (DKRasterizer*)rendererAtIndex:(NSUInteger)index;
- (nullable DKRasterizer*)rendererWithName:(NSString*)name;

/** @brief Returns the number of directly contained renderers
 
 Doesn't count renderers owned by nested groups within this one
 */
@property (readonly) NSUInteger countOfRenderList;
- (BOOL)containsRendererOfClass:(Class)cl;
- (nullable NSArray<DKRasterizer*>*)renderersOfClass:(Class)cl NS_REFINED_FOR_SWIFT;

/** @brief Determines whther the group will draw anything by finding if any contained renderer will draw anything.
 Is \c YES if at least one contained renderer will draw something.
 */
@property (readonly, getter=isValid) BOOL valid;

/** @brief Removes all renderers from this group except other groups
 
 Specialist use - not generally for application use
 */
- (void)removeAllRenderers;

/** @brief Removes all renderers of the given class, optionally traversing levels below this
 
 Renderers must be an exact match for \c cl - subclasses are not considered a match. This is
 intended for specialist use and should not generally be used by application code
 @param cl The renderer class to remove.
 @param subs If <code>YES</code>, traverses into subgroups and repeats the exercise there. \c NO to only examine this level.
 */
- (void)removeRenderersOfClass:(Class)cl inSubgroups:(BOOL)subs;

// KVO compliant variants of the render list management methods, key = "renderList"

- (id)objectInRenderListAtIndex:(NSUInteger)indx;
- (void)insertObject:(DKRasterizer*)obj inRenderListAtIndex:(NSUInteger)index;
- (void)removeObjectFromRenderListAtIndex:(NSUInteger)indx;

@end

NS_ASSUME_NONNULL_END
