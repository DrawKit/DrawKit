/**
 * @author Graham Cox, Apptree.net
 * @author Graham Miln, miln.eu
 * @author Contributions from the community
 * @date 2005-2013
 * @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import "DKRastGroup.h"
#import "NSDictionary+DeepCopy.h"
#import "DKFill.h"
#import "DKStroke.h"
#import "DKGradient.h"
#import "LogEvent.h"

@implementation DKRastGroup
#pragma mark As a DKRenderGroup

/** @brief Set the contained objects to those in array
 * @note
 * This method no longer attempts to try and manage observing of the objects. The observer must
 * properly stop observing before this is called, or start observing after it is called when
 * initialising from an archive. 
 * @param list a list of renderer objects
 * @public
 */
- (void)setRenderList:(NSArray*)list
{
    if (list != [self renderList]) {
        NSMutableArray* rl = [list mutableCopy];
        [m_renderList release];
        m_renderList = rl;

        // set the container ref for each item in the list - when unarchiving newer files this is already done but
        // for older files may not be. It's a weak ref so doing it anyway here is harmless. The added objects are not
        // yet notified to the root for observation as we don't want them getting observed twice. When the style
        // completes unarchiving it will start observing the whole tree itself. When individual rasterizers are added and
        // removed their observation is managed individually (inclusing the adding/removal of groups, which deals with
        // all the subordinate objects).

        [[self renderList] makeObjectsPerformSelector:@selector(setContainer:)
                                           withObject:self];
    }
}

/** @brief Get the list of contained renderers
 * @return an array containing the list of renderers
 * @public
 */
- (NSArray*)renderList
{
    return m_renderList; //[[m_renderList copy] autorelease];
}

#pragma mark -

/** @brief Returns the top-level group in any hierarchy, which in DrawKit is a style object
 * @note
 * Will return nil if the group isn't part of a complete tree
 * @return the top level group
 * @public
 */
- (DKRastGroup*)root
{
    return [[self container] root];
}

/** @brief Notifies that an observable object was added to the group
 * @note
 * Overridden by the root object (style)
 * @param observable the object to start observing
 * @public
 */
- (void)observableWasAdded:(GCObservableObject*)observable
{
#pragma unused(observable)

    // placeholder
}

/** @brief Notifies that an observable object is about to be removed from the group
 * @note
 * Overridden by the root object (style)
 * @param observable the object to stop observing
 * @public
 */
- (void)observableWillBeRemoved:(GCObservableObject*)observable
{
#pragma unused(observable)

    // placeholder
}

#pragma mark -

/** @brief Adds a renderer to the group
 * @param renderer a renderer object
 * @public
 */
- (void)addRenderer:(DKRasterizer*)renderer
{
    if (![m_renderList containsObject:renderer]) {
        [renderer setContainer:self];
        [self insertObject:renderer
            inRenderListAtIndex:[self countOfRenderList]];

        // let the root object know so it can start observing the added renderer

        [[self root] observableWasAdded:renderer];
    }
}

/** @brief Removes a renderer from the group
 * @param renderer the renderer object to remove
 * @public
 */
- (void)removeRenderer:(DKRasterizer*)renderer
{
    if ([m_renderList containsObject:renderer]) {
        // let the root object know so it can stop observing the renderer that is about to vanish

        [[self root] observableWillBeRemoved:renderer];
        [renderer setContainer:nil];
        [self removeObjectFromRenderListAtIndex:[self indexOfRenderer:renderer]];
    }
}

/** @brief Relocates a renderer within the group (which affects drawing order)
 * @param src the index position of the renderer to move
 * @param dest the index where to move it
 * @public
 */
- (void)moveRendererAtIndex:(NSUInteger)src toIndex:(NSUInteger)dest
{
    if (src == dest)
        return;

    if (src >= [m_renderList count])
        src = [m_renderList count] - 1;

    DKRasterizer* moving = [[m_renderList objectAtIndex:src] retain];

    [self removeObjectFromRenderListAtIndex:src];

    if (src < dest)
        --dest;

    [self insertObject:moving
        inRenderListAtIndex:dest];
    [moving release];
}

/** @brief Inserts a renderer into the group at the given index
 * @param renderer the renderer to insert
 * @param index the index where to insert it
 * @public
 */
- (void)insertRenderer:(DKRasterizer*)renderer atIndex:(NSUInteger)indx
{
    if (![m_renderList containsObject:renderer]) {
        [renderer setContainer:self];
        [self insertObject:renderer
            inRenderListAtIndex:indx];

        // let the root object know so it can start observing

        [[self root] observableWasAdded:renderer];
    }
}

/** @brief Removes the renderer at the given index
 * @param index the index to remove
 * @public
 */
- (void)removeRendererAtIndex:(NSUInteger)indx
{
    DKRasterizer* renderer = [self rendererAtIndex:indx];

    if ([m_renderList containsObject:renderer]) {
        // let the root object know so it can stop observing:

        [[self root] observableWillBeRemoved:renderer];
        [renderer setContainer:nil];
        [self removeObjectFromRenderListAtIndex:indx];
    }
}

/** @brief Returns the index of the given renderer
 * @param renderer the renderer in question
 * @return the index position of the renderer, or NSNotFound
 * @public
 */
- (NSUInteger)indexOfRenderer:(DKRasterizer*)renderer
{
    return [[self renderList] indexOfObject:renderer];
}

#pragma mark -

/** @brief Returns the rendere at the given index position
 * @param index the index position of the renderer
 * @return the renderer at that position
 * @public
 */
- (DKRasterizer*)rendererAtIndex:(NSUInteger)indx
{
    return (DKRasterizer*)[self objectInRenderListAtIndex:indx]; //[[self renderList] objectAtIndex:indx];
}

/** @brief Returns the renderer matching the given name
 * @param name the name of the renderer
 * @return the renderer with that name, if any
 * @public
 */
- (DKRasterizer*)rendererWithName:(NSString*)name
{
    NSEnumerator* iter = [[self renderList] objectEnumerator];
    DKRasterizer* rend;

    while ((rend = [iter nextObject])) {
        if ([[rend name] isEqualToString:name])
            return rend;
    }

    return nil;
}

#pragma mark -

/** @brief Returns the number of directly contained renderers
 * @note
 * Doesn't count renderers owned by nested groups within this one
 * @return the count of renderers
 * @public
 */
- (NSUInteger)countOfRenderList
{
    return [[self renderList] count];
}

/** @brief Queries whether a renderer of a given class exists somewhere in the render tree
 * @note
 * Usually called from the top level to get a broad idea of what the group will draw. A style
 * has some higher level methods that call this.
 * @param cl the class to look for
 * @return YES if there is at least one [enabled] renderer with the given class, NO otherwise
 * @public
 */
- (BOOL)containsRendererOfClass:(Class)cl
{
    if ([self countOfRenderList] > 0) {
        NSEnumerator* iter = [[self renderList] objectEnumerator];
        id rend;

        while ((rend = [iter nextObject])) {
            if ([rend isKindOfClass:cl]) // && [rend enabled]  // (should we skip disabled ones? causes some problems with KVO)
                return YES;

            if ([rend isKindOfClass:[DKRastGroup class]]) {
                if ([rend containsRendererOfClass:cl])
                    return YES;
            }
        }
    }

    return NO;
}

/** @brief Returns a flattened list of renderers of a given class
 * @param cl the class to look for
 * @return an array containing the renderers matching <cl>, or nil.
 * @public
 */
- (NSArray*)renderersOfClass:(Class)cl
{
    if ([self containsRendererOfClass:cl]) {
        NSMutableArray* rl = [[NSMutableArray alloc] init];
        NSEnumerator* iter = [[self renderList] objectEnumerator];
        id rend;

        while ((rend = [iter nextObject])) {
            if ([rend isKindOfClass:cl])
                [rl addObject:rend];

            if ([rend isKindOfClass:[self class]]) {
                NSArray* temp = [rend renderersOfClass:cl];
                [rl addObjectsFromArray:temp];
            }
        }

        return [rl autorelease];
    }

    return nil;
}

/** @brief Removes all renderers from this group except other groups
 * @note
 * Specialist use - not generally for application use
 * @public
 */
- (void)removeAllRenderers
{
    NSEnumerator* iter = [[self renderList] reverseObjectEnumerator];
    DKRasterizer* rast;

    while ((rast = [iter nextObject])) {
        if (![rast isKindOfClass:[self class]])
            [self removeRenderer:rast];
    }
}

/** @brief Removes all renderers of the given class, optionally traversing levels below this
 * @note
 * Renderers must be an exact match for <class> - subclasses are not considered a match. This is
 * intended for specialist use and should not generally be used by application code
 * @param cl the renderer class to remove
 * @return <subs> if YES, traverses into subgroups and repeats the exercise there. NO to only examine this level.
 * @public
 */
- (void)removeRenderersOfClass:(Class)cl inSubgroups:(BOOL)subs
{
    // removes any renderers of the given *exact* class from the group. If <subs> is YES, recurses down to any subgroups below.

    NSEnumerator* iter = [[self renderList] reverseObjectEnumerator];
    DKRasterizer* rast;

    while ((rast = [iter nextObject])) {
        if ([rast isMemberOfClass:cl])
            [self removeRenderer:rast];
        else if (subs && [rast isKindOfClass:[self class]])
            [(DKRastGroup*)rast removeRenderersOfClass:cl
                                           inSubgroups:subs];
    }
}

#pragma mark -
#pragma mark KVO-compliant accessor methods for "renderList"

- (id)objectInRenderListAtIndex:(NSUInteger)indx
{
    return [[self renderList] objectAtIndex:indx];
}

- (void)insertObject:(id)obj inRenderListAtIndex:(NSUInteger)indx
{
    [m_renderList insertObject:obj
                       atIndex:indx];
}

- (void)removeObjectFromRenderListAtIndex:(NSUInteger)indx
{
    [m_renderList removeObjectAtIndex:indx];
}

#pragma mark -
#pragma mark As a DKRasterizer

/** @brief Determines whther the group will draw anything by finding if any contained renderer will draw anything
 * @return YES if at least one contained renderer will draw something
 * @public
 */
- (BOOL)isValid
{
    // returns YES if the group will result in something being actually drawn, NO if not. A group
    // needs to contain at least one stroke, fill, hatch, gradient, etc that will actually set pixels
    // otherwise it will do nothing. In general invalid renderers should be avoided because they may
    // result in invisible graphic objects that can't be seen or selected.

    if ([self countOfRenderList] < 1)
        return NO;

    NSEnumerator* iter = [[self renderList] objectEnumerator];
    DKRasterizer* rend;

    while ((rend = [iter nextObject])) {
        if ([rend enabled] && [rend isValid])
            return YES;
    }

    // went through list and nothing was valid, so group isn't valid.

    return NO;
}

/** @brief Returns a style csript representing the group
 * @return a string containg a complete script for the group and all contained objects
 * @public
 */
- (NSString*)styleScript
{
    // returns the spec string of this group. The spec string consists of the concatenation of the spec strings for all renderers, formatted
    // with the correct syntax to indicate the full hierarchy and oredr ofthe renderers. The spec string can be used to construct a
    // render group having the same properties.

    NSEnumerator* iter = [[self renderList] objectEnumerator];
    DKRasterizer* rend;
    NSMutableString* str;

    str = [[NSMutableString alloc] init];

    [str setString:@"{"];

    while ((rend = [iter nextObject]))
        [str appendString:[rend styleScript]];

    [str appendString:@"}"];

    return [str autorelease];
}

#pragma mark -
#pragma mark As a GCObservableObject

/** @brief Returns the keypaths of the properties that can be observed
 * @return an array listing the observable key paths
 * @public
 */
+ (NSArray*)observableKeyPaths
{
    return [[super observableKeyPaths] arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:@"renderList", nil]];
}

/** @brief Registers the action names for the observable properties published by the object
 * @public
 */
- (void)registerActionNames
{
    [super registerActionNames];

    // note that all operations on the group's contents invoke the same keypath via KVO, so the action name is
    // not very fine-grained. TO DO - find a better way. (n.b. for DKStyle, undo is handled differently
    // and overrides the KVO mechanism, avoiding this issue - only sub-groups are affected)

    [self setActionName:@"#kind# Component Group"
             forKeyPath:@"renderList"];
}

/** @brief Sets up KVO for the given observer object
 * @note
 * Propagates the request down to all the components in the group, including other groups so the
 * entire tree is traversed
 * @param object the observer
 * @public
 */
- (BOOL)setUpKVOForObserver:(id)object
{
    [[self renderList] makeObjectsPerformSelector:@selector(setUpKVOForObserver:)
                                       withObject:object];
    return [super setUpKVOForObserver:object];
}

/** @brief Tears down KVO for the given observer object
 * @note
 * Propagates the request down to all the components in the group, including other groups so the
 * entire tree is traversed
 * @param object the observer
 * @public
 */
- (BOOL)tearDownKVOForObserver:(id)object
{
    [[self renderList] makeObjectsPerformSelector:@selector(tearDownKVOForObserver:)
                                       withObject:object];
    return [super tearDownKVOForObserver:object];
}

#pragma mark -
#pragma mark As an NSObject

- (void)dealloc
{
    [m_renderList release];
    [super dealloc];
}

- (id)init
{
    self = [super init];
    if (self != nil) {
        m_renderList = [[NSMutableArray alloc] init];

        if (m_renderList == nil) {
            [self autorelease];
            self = nil;
        }
    }

    return self;
}

#pragma mark -
#pragma mark As part of DKRasterizer Protocol

/** @brief Determines the extra space needed to render by finding the most space needed by any contained renderer
 * @return the extra width and height needed over and above the object's (path) bounds
 * @public
 */
- (NSSize)extraSpaceNeeded
{
    NSSize rs, accSize = NSZeroSize;

    if ([self enabled]) {
        NSEnumerator* iter = [[self renderList] objectEnumerator];
        DKRasterizer* rend;

        while ((rend = [iter nextObject])) {
            rs = [rend extraSpaceNeeded];

            if (rs.width > accSize.width)
                accSize.width = rs.width;

            if (rs.height > accSize.height)
                accSize.height = rs.height;
        }
    }

    return accSize;
}

/** @brief Renders the object by iterating over the contained renderers
 * @param object the object to render
 * @public
 */
- (void)render:(id<DKRenderable>)object
{
    if (![self enabled])
        return;

    if (![object conformsToProtocol:@protocol(DKRenderable)])
        return;

    SAVE_GRAPHICS_CONTEXT //[NSGraphicsContext saveGraphicsState];
        [[self renderList] makeObjectsPerformSelector : _cmd withObject : object];

    RESTORE_GRAPHICS_CONTEXT //[NSGraphicsContext restoreGraphicsState];
}

/** @brief Renders the object's path by iterating over the contained renderers
 * @note
 * Normally groups and styles should use render: but this provides correct behaviour if a top level
 * object elects to use the path (in general, don't do this)
 * @param path the path to render
 * @public
 */
- (void)renderPath:(NSBezierPath*)path
{
    if (![self enabled])
        return;

    SAVE_GRAPHICS_CONTEXT //[NSGraphicsContext saveGraphicsState];
        [[self renderList] makeObjectsPerformSelector : _cmd withObject : path];
    RESTORE_GRAPHICS_CONTEXT //[NSGraphicsContext restoreGraphicsState];
}

/** @brief Queries whther the rasterizer implements a fill or not
 * @note
 * Returns YES if any contained rasterizer returns YES, NO otherwise
 * @return YES if the rasterizer is considered a fill type
 * @public
 */
- (BOOL)isFill
{
    NSEnumerator* iter = [[self renderList] objectEnumerator];
    DKRasterizer* rast;

    while ((rast = [iter nextObject])) {
        if ([rast isFill])
            return YES;
    }

    return NO;
}

#pragma mark -
#pragma mark As part of GraphicsAttributes Protocol

/** @brief Installs renderers when built from a script
 * @param val a renderer object
 * @param pnum th eordinal position of the value in the original expression. Not used here.
 * @public
 */
- (void)setValue:(id)val forNumericParameter:(NSInteger)pnum
{
    LogEvent_(kReactiveEvent, @"anonymous parameter #%d, value = %@", pnum, val);

    // if <val> conforms to the DKRasterizer protocol, we add it

    if ([val conformsToProtocol:@protocol(DKRasterizer)])
        [self addRenderer:val];
}

#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)encodeWithCoder:(NSCoder*)coder
{
    NSAssert(coder != nil, @"Expected valid coder");
    [super encodeWithCoder:coder];

    [coder encodeConditionalObject:[self container]
                            forKey:@"DKRastGroup_container"];
    [coder encodeObject:[self renderList]
                 forKey:@"renderlist"];
}

- (id)initWithCoder:(NSCoder*)coder
{
    NSAssert(coder != nil, @"Expected valid coder");
    self = [super initWithCoder:coder];
    if (self != nil) {
        [self setContainer:[coder decodeObjectForKey:@"DKRastGroup_container"]];
        [self setRenderList:[coder decodeObjectForKey:@"renderlist"]];
    }
    return self;
}

#pragma mark -
#pragma mark As part of NSCopying Protocol
- (id)copyWithZone:(NSZone*)zone
{
    DKRastGroup* copy = [super copyWithZone:zone];

    NSArray* rl = [[self renderList] deepCopy];
    [copy setRenderList:rl];
    [rl release];

    return copy;
}

#pragma mark -
#pragma mark As part of NSKeyValueCoding Protocol

/** @brief Returns a renderer class associated with the given key
 * @note
 * This is used to support simple UI's that bind to certain renderers based on generic keypaths
 * @param key a key for the renderer class
 * @return a renderer class matching the key, if any
 * @public
 */
- (Class)renderClassForKey:(NSString*)key
{
    // TO DO: make this a much smarter and more general lookup

    if ([@"fill" isEqualToString:key])
        return [DKFill class];

    else if ([@"stroke" isEqualToString:key])
        return [DKStroke class];

    else if ([@"gradient" isEqualToString:key])
        return [DKGradient class];
    else
        return Nil;
}

#pragma mark -

/** @brief Returns a renderer class associated with the given key
 * @note
 * This is used to support simple UI's that bind to certain renderers based on generic keypaths. Here,
 * the renderer is preferentially referred to by name, but if that fails, falls back on generic
 * lookup based on a simplified classname.
 * @param key a key for the renderer class
 * @return a renderer matching the key, if any
 * @public
 */
- (id)valueForUndefinedKey:(NSString*)key
{
    NSEnumerator* iter = [[self renderList] objectEnumerator];
    DKRasterizer* rend;
    Class classForKey = [self renderClassForKey:key];

    while ((rend = [iter nextObject])) {
        if ([[rend name] isEqualToString:key] || (classForKey && [rend isKindOfClass:classForKey]))
            return rend;
    }
    return nil;
}

@end
