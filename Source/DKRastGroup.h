/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKRasterizer.h"

@class DKRastGroup;

/** @brief A rendergroup is a single renderer which contains a list of other renderers.

A rendergroup is a single renderer which contains a list of other renderers. Each renderer is applied to the object
in list order.

Because the group is itself a renderer, it can be added to other groups, etc to form complex trees of rendering
behaviour.

A group saves and restores the graphics state around all of its calls, so can also be used to "bracket" sets of
rendering operations together.

The rendering group is the basis for the more application-useful drawing style object.

Because DKRasterizer inherits from GCObservableObject, the group object supports a KVO-based approach for observing its
components. Whenever a component is added or removed from a group, the root object (typically a style) is informed through 
the observableWasAdded: observableWillBeRemoved: methods. If the root object is indeed interested in observing the object,
it should call its setUpKVOForObserver and tearDownKVOForObserver methods. Groups propagate these messages down the tree
as well, so the root object is given the opportunity to observe any component anywhere in the tree. Additionally, groups
themselves are observed for changes to their lists, so the root object is able to track changes to the group structure
as well.
*/
@interface DKRastGroup : DKRasterizer <NSCoding, NSCopying> {
@private
	NSMutableArray* m_renderList;
}

- (void)setRenderList:(NSArray*)list;
- (NSArray*)renderList;

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
- (DKRasterizer*)rendererWithName:(NSString*)name;

- (NSUInteger)countOfRenderList;
- (BOOL)containsRendererOfClass:(Class)cl;
- (NSArray*)renderersOfClass:(Class)cl;

- (BOOL)isValid;

- (void)removeAllRenderers;
- (void)removeRenderersOfClass:(Class)cl inSubgroups:(BOOL)subs;

// KVO compliant variants of the render list management methods, key = "renderList"

- (id)objectInRenderListAtIndex:(NSUInteger)indx;
- (void)insertObject:(id)obj inRenderListAtIndex:(NSUInteger)index;
- (void)removeObjectFromRenderListAtIndex:(NSUInteger)indx;

@end
