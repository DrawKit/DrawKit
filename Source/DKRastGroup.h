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
	dispatch_semaphore_t m_renderListLock;
	dispatch_time_t m_renderListLockTimeOutSeconds;
}

/** @brief The list of contained renderers.

 The setter no longer attempts to try and manage observing of the objects. The observer must
 properly stop observing before this is called, or start observing after it is called when
 initialising from an archive.
*/
@property (nonatomic, copy, nullable) NSArray<DKRasterizer*>* renderList;

/** @brief Returns the top-level group in any hierarchy, which in DrawKit is a style object.
 
 Will return \c nil if the group isn't part of a complete tree.
 @return the top level group.
 */
- (nullable DKRastGroup*)root;

/** @brief Notifies that an observable object was added to the group.
 
 Overridden by the root object (style).
 @param observable The object to start observing.
 */
- (void)observableWasAdded:(GCObservableObject*)observable;

/** @brief Notifies that an observable object is about to be removed from the group.
 
 Overridden by the root object (style).
 @param observable The object to stop observing.
 */
- (void)observableWillBeRemoved:(GCObservableObject*)observable;

/** @brief Adds a renderer to the group.
 @param renderer A renderer object.
 */
- (void)addRenderer:(DKRasterizer*)renderer;

/** @brief Removes a renderer from the group.
 @param renderer The renderer object to remove.
 */
- (void)removeRenderer:(DKRasterizer*)renderer;

/** @brief Relocates a renderer within the group (which affects drawing order).
 @param src The index position of the renderer to move.
 @param dest The index where to move it.
 */
- (void)moveRendererAtIndex:(NSUInteger)src toIndex:(NSUInteger)dest;

/** @brief Inserts a renderer into the group at the given index.
 @param renderer The renderer to insert.
 @param index The index where to insert it.
 */
- (void)insertRenderer:(DKRasterizer*)renderer atIndex:(NSUInteger)index;

/** @brief Removes the renderer at the given index.
 @param index The index to remove.
 */
- (void)removeRendererAtIndex:(NSUInteger)index;

/** @brief Returns the index of the given renderer.
 @param renderer The renderer in question.
 @return The index position of the renderer, or <code>NSNotFound</code>
 */
- (NSUInteger)indexOfRenderer:(DKRasterizer*)renderer;

/** @brief Returns the rendere at the given index position.
 @param index The index position of the renderer.
 @return The renderer at that position.
 */
- (DKRasterizer*)rendererAtIndex:(NSUInteger)index;

/** @brief Returns the renderer matching the given name.
 @param name The name of the renderer.
 @return The renderer with that name, if any.
 */
- (nullable DKRasterizer*)rendererWithName:(NSString*)name;

/** @brief Returns the number of directly contained renderers.
 
 Doesn't count renderers owned by nested groups within this one.
 */
@property (readonly) NSUInteger countOfRenderList;

/** @brief Queries whether a renderer of a given class exists somewhere in the render tree.
 
 Usually called from the top level to get a broad idea of what the group will draw. A style
 has some higher level methods that call this.
 @param cl The class to look for.
 @return \c YES if there is at least one \c [enabled] renderer with the given class, \c NO otherwise.
 */
- (BOOL)containsRendererOfClass:(Class)cl;

/** @brief Returns a flattened list of renderers of a given class
 @param cl the class to look for
 @return an array containing the renderers matching <code>cl</code>, or <code>nil</code>.
 */
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

- (__kindof DKRasterizer*)objectInRenderListAtIndex:(NSUInteger)indx;
- (void)insertObject:(DKRasterizer*)obj inRenderListAtIndex:(NSUInteger)index;
- (void)removeObjectFromRenderListAtIndex:(NSUInteger)indx;

@end

NS_ASSUME_NONNULL_END
