/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKRastGroup.h"
#import "DKFill.h"
#import "DKGradient.h"
#import "DKStroke.h"
#import "LogEvent.h"
#import "NSDictionary+DeepCopy.h"

@implementation DKRastGroup
#pragma mark As a DKRenderGroup
dispatch_semaphore_t m_renderListLock;
dispatch_time_t m_renderListLockTimeOutSeconds = 2.0; // infinite is DISPATCH_TIME_FOREVER
/** @brief Set the contained objects to those in array

 This method no longer attempts to try and manage observing of the objects. The observer must
 properly stop observing before this is called, or start observing after it is called when
 initialising from an archive.
 @param list a list of renderer objects
 */
- (void)setRenderList:(NSArray*)list
{
	dispatch_semaphore_wait(m_renderListLock, m_renderListLockTimeOutSeconds);
	
	if (list != m_renderList) {
		NSMutableArray* rl = [list mutableCopy];
		m_renderList = rl;

		// set the container ref for each item in the list - when unarchiving newer files this is already done but
		// for older files may not be. It's a weak ref so doing it anyway here is harmless. The added objects are not
		// yet notified to the root for observation as we don't want them getting observed twice. When the style
		// completes unarchiving it will start observing the whole tree itself. When individual rasterizers are added and
		// removed their observation is managed individually (inclusing the adding/removal of groups, which deals with
		// all the subordinate objects).

		[m_renderList makeObjectsPerformSelector:@selector(setContainer:)
										   withObject:self];
	}
	
	dispatch_semaphore_signal(m_renderListLock);
}

/** @brief Get the list of contained renderers
 @return an array containing the list of renderers
 */
- (NSArray*)renderList
{
	dispatch_semaphore_wait(m_renderListLock, m_renderListLockTimeOutSeconds);
	
	NSArray* ret = [m_renderList copy];
	
	dispatch_semaphore_signal(m_renderListLock);
	
	return ret;
}

#pragma mark -

- (DKRastGroup*)root
{
	return [[self container] root];
}

- (void)observableWasAdded:(GCObservableObject*)observable
{
#pragma unused(observable)

	// placeholder
}

- (void)observableWillBeRemoved:(GCObservableObject*)observable
{
#pragma unused(observable)

	// placeholder
}

#pragma mark -

- (void)addRenderer:(DKRasterizer*)renderer
{
	dispatch_semaphore_wait(m_renderListLock, m_renderListLockTimeOutSeconds);
	
	if (![m_renderList containsObject:renderer]) {
		[renderer setContainer:self];
		[m_renderList insertObject:renderer atIndex:[m_renderList count]];
		// let the root object know so it can start observing the added renderer

		[[self root] observableWasAdded:renderer];
	}
	
	dispatch_semaphore_signal(m_renderListLock);
}

- (void)removeRenderer:(DKRasterizer*)renderer
{
	dispatch_semaphore_wait(m_renderListLock, m_renderListLockTimeOutSeconds);
	
	[self removeRendererUnsafe:renderer];
	
	dispatch_semaphore_signal(m_renderListLock);
}

- (void)removeRendererUnsafe:(DKRasterizer*)renderer
{
	
	if ([m_renderList containsObject:renderer]) {
		// let the root object know so it can stop observing the renderer that is about to vanish

		[[self root] observableWillBeRemoved:renderer];
		[renderer setContainer:nil];
		NSUInteger indexOfRenderer = [m_renderList indexOfObject:renderer];
		[m_renderList removeObjectAtIndex:indexOfRenderer];
	}
	
}

- (void)moveRendererAtIndex:(NSUInteger)src toIndex:(NSUInteger)dest
{
	dispatch_semaphore_wait(m_renderListLock, m_renderListLockTimeOutSeconds);
	
	if (src == dest)
		return;

	if (src >= [m_renderList count])
		src = [m_renderList count] - 1;

	DKRasterizer* moving = [m_renderList objectAtIndex:src];

	[m_renderList removeObjectAtIndex:src];

	if (src < dest)
		--dest;

	[m_renderList insertObject:moving
					   atIndex:dest];
	
	dispatch_semaphore_signal(m_renderListLock);
}

- (void)insertRenderer:(DKRasterizer*)renderer atIndex:(NSUInteger)indx
{
	dispatch_semaphore_wait(m_renderListLock, m_renderListLockTimeOutSeconds);
	
	if (![m_renderList containsObject:renderer]) {
		[renderer setContainer:self];
		[m_renderList insertObject:renderer
						   atIndex:indx];

		// let the root object know so it can start observing

		[[self root] observableWasAdded:renderer];
	}
	dispatch_semaphore_signal(m_renderListLock);
}

- (void)removeRendererAtIndex:(NSUInteger)indx
{
	dispatch_semaphore_wait(m_renderListLock, m_renderListLockTimeOutSeconds);
	
	DKRasterizer* renderer = [m_renderList objectAtIndex:indx];
	
	if ([m_renderList containsObject:renderer]) {
		// let the root object know so it can stop observing:

		[[self root] observableWillBeRemoved:renderer];
		[renderer setContainer:nil];
		[m_renderList removeObjectAtIndex:indx];
	}
	dispatch_semaphore_signal(m_renderListLock);
}

- (NSUInteger)indexOfRenderer:(DKRasterizer*)renderer
{
	dispatch_semaphore_wait(m_renderListLock, m_renderListLockTimeOutSeconds);
	
	NSUInteger ret = [m_renderList indexOfObject:renderer];
	
	dispatch_semaphore_signal(m_renderListLock);
	
	return ret;
}

#pragma mark -

- (DKRasterizer*)rendererAtIndex:(NSUInteger)indx
{
	return (DKRasterizer*)[self objectInRenderListAtIndex:indx];
}

- (DKRasterizer*)rendererWithName:(NSString*)name
{
	dispatch_semaphore_wait(m_renderListLock, m_renderListLockTimeOutSeconds);
	DKRasterizer* ret = nil;
	for (DKRasterizer* rend in m_renderList) {
		if ([[rend name] isEqualToString:name]) {
			ret = rend;
		}
	}
	dispatch_semaphore_signal(m_renderListLock);
	return ret;
}

#pragma mark -

/** @brief Returns the number of directly contained renderers

 Doesn't count renderers owned by nested groups within this one
 @return the count of renderers
 */
- (NSUInteger)countOfRenderList
{
	dispatch_semaphore_wait(m_renderListLock, m_renderListLockTimeOutSeconds);
	
	NSUInteger count = [m_renderList count];
	
	dispatch_semaphore_signal(m_renderListLock);
	
	return count;
}

- (BOOL)containsRendererOfClass:(Class)cl
{
	dispatch_semaphore_wait(m_renderListLock, m_renderListLockTimeOutSeconds);
	
	BOOL ret = [self containsRendererOfClassUnsafe:cl];
	
	dispatch_semaphore_signal(m_renderListLock);

	return ret;
}

- (BOOL)containsRendererOfClassUnsafe:(Class)cl
{
	if ([m_renderList count] > 0) {
		for (id rend in m_renderList) {
			if ([rend isKindOfClass:cl]) // && [rend enabled]  // (should we skip disabled ones? causes some problems with KVO)
				return YES;

			if ([rend isKindOfClass:[DKRastGroup class]]) {
				if ([rend containsRendererOfClassUnsafe:cl])
					return YES;
			}
		}
	}
	
	return NO;
}

- (NSArray*)renderersOfClass:(Class)cl {
	int numberOfSecondsForTimeout = 10;
	dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, numberOfSecondsForTimeout * NSEC_PER_SEC);
	// timeout = m_renderListLockTimeOutSecondsload
	
	dispatch_semaphore_wait(m_renderListLock, timeout);
	
	NSArray* ret = [self renderersOfClassUnsafe:cl];
	
	dispatch_semaphore_signal(m_renderListLock);
	
	return ret;
}

- (NSArray*)renderersOfClassUnsafe:(Class)cl
{
	NSArray* ret = nil;

	if ([self containsRendererOfClassUnsafe:cl]) {

		NSMutableArray* rl = [[NSMutableArray alloc] init];
		
		for (id rend in m_renderList) {
			if ([rend isKindOfClass:cl])
				[rl addObject:rend];

			if ([rend isKindOfClass:[DKRastGroup class]]) {
				NSArray* temp = [rend renderersOfClassUnsafe:cl];
				[rl addObjectsFromArray:temp];
			}
		}
		ret = rl;
	}

	return ret;
}

- (void)removeAllRenderers
{
	dispatch_semaphore_wait(m_renderListLock, m_renderListLockTimeOutSeconds);
	
	for (DKRasterizer* rast in m_renderList) {
		if (![rast isKindOfClass:[DKRastGroup class]]) {
			[self removeRendererUnsafe:rast];
		}
	}
	
	dispatch_semaphore_signal(m_renderListLock);
}

- (void)removeRenderersOfClass:(Class)cl inSubgroups:(BOOL)subs
{
	// removes any renderers of the given *exact* class from the group. If <subs> is YES, recurses down to any subgroups below.

	for (DKRasterizer* rast in [self.renderList copy]) {
		if ([rast isMemberOfClass:cl]) {
			[self removeRenderer:rast];
		} else if (subs && [rast isKindOfClass:[DKRastGroup class]]) {
			[(DKRastGroup*)rast removeRenderersOfClass:cl
										   inSubgroups:subs];
		}
	}
}

#pragma mark -
#pragma mark KVO - compliant accessor methods for "renderList"

- (id)objectInRenderListAtIndex:(NSUInteger)indx
{
	dispatch_semaphore_wait(m_renderListLock, m_renderListLockTimeOutSeconds);
	
	id ret = [m_renderList objectAtIndex:indx];
	
	dispatch_semaphore_signal(m_renderListLock);
	
	return ret;
}

- (void)insertObject:(id)obj inRenderListAtIndex:(NSUInteger)indx
{
	dispatch_semaphore_wait(m_renderListLock, m_renderListLockTimeOutSeconds);
	
	[m_renderList insertObject:obj
					   atIndex:indx];
	
	dispatch_semaphore_signal(m_renderListLock);
}

- (void)removeObjectFromRenderListAtIndex:(NSUInteger)indx
{
	[m_renderList removeObjectAtIndex:indx];
}

#pragma mark -
#pragma mark As a DKRasterizer

/** @brief Determines whther the group will draw anything by finding if any contained renderer will draw anything
 @return YES if at least one contained renderer will draw something
 */
- (BOOL)isValid
{
	// returns YES if the group will result in something being actually drawn, NO if not. A group
	// needs to contain at least one stroke, fill, hatch, gradient, etc that will actually set pixels
	// otherwise it will do nothing. In general invalid renderers should be avoided because they may
	// result in invisible graphic objects that can't be seen or selected.

	if ([self countOfRenderList] < 1)
		return NO;

	for (DKRasterizer* rend in self.renderList) {
		if ([rend enabled] && [rend isValid]) {
			return YES;
		}
	}

	// went through list and nothing was valid, so group isn't valid.

	return NO;
}

/** @brief Returns a style csript representing the group
 @return a string containg a complete script for the group and all contained objects
 */
- (NSString*)styleScript
{
	// returns the spec string of this group. The spec string consists of the concatenation of the spec strings for all renderers, formatted
	// with the correct syntax to indicate the full hierarchy and oredr ofthe renderers. The spec string can be used to construct a
	// render group having the same properties.

	NSMutableString* str = [[NSMutableString alloc] init];

	[str setString:@"{"];

	for (DKRasterizer* rend in self.renderList) {
		[str appendString:[rend styleScript]];
	}

	[str appendString:@"}"];

	return [str copy];
}

#pragma mark -
#pragma mark As a GCObservableObject

/** @brief Returns the keypaths of the properties that can be observed
 @return an array listing the observable key paths
 */
+ (NSArray*)observableKeyPaths
{
	return [[super observableKeyPaths] arrayByAddingObjectsFromArray:@[@"renderList"]];
}

/** @brief Registers the action names for the observable properties published by the object
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

 Propagates the request down to all the components in the group, including other groups so the
 entire tree is traversed
 @param object the observer
 */
- (BOOL)setUpKVOForObserver:(id)object
{
	dispatch_semaphore_wait(m_renderListLock, m_renderListLockTimeOutSeconds);
	
	[m_renderList makeObjectsPerformSelector:@selector(setUpKVOForObserver:)
									   withObject:object];
	
	dispatch_semaphore_signal(m_renderListLock);
	
	return [super setUpKVOForObserver:object];
}

/** @brief Tears down KVO for the given observer object

 Propagates the request down to all the components in the group, including other groups so the
 entire tree is traversed
 @param object the observer
 */
- (BOOL)tearDownKVOForObserver:(id)object
{
	dispatch_semaphore_wait(m_renderListLock, m_renderListLockTimeOutSeconds);
	
	[m_renderList makeObjectsPerformSelector:@selector(tearDownKVOForObserver:)
									   withObject:object];
	
	dispatch_semaphore_signal(m_renderListLock);

	return [super tearDownKVOForObserver:object];
}

#pragma mark -
#pragma mark As an NSObject

- (instancetype)init
{
	self = [super init];
	
	if (self != nil) {
		m_renderList = [[NSMutableArray alloc] init];
		m_renderListLock = dispatch_semaphore_create(1);
		if (m_renderList == nil) {
			return nil;
		}
	}
	return self;
}

#pragma mark -
#pragma mark As part of DKRasterizer Protocol

/** @brief Determines the extra space needed to render by finding the most space needed by any contained renderer
 @return the extra width and height needed over and above the object's (path) bounds
 */
- (NSSize)extraSpaceNeeded
{
	CGSize accSize = NSZeroSize;

	if ([self enabled]) {
		// m_renderList needs to be immutable here, however render() already has a semaphore open on m_renderListLock
		// so run this on a copy
		for (DKRasterizer* rend in [self->m_renderList copy]) {
			NSSize rs = [rend extraSpaceNeeded];

			if (rs.width > accSize.width)
				accSize.width = rs.width;

			if (rs.height > accSize.height)
				accSize.height = rs.height;
		}
	}
	
	return accSize;
}

/** @brief Renders the object by iterating over the contained renderers
 @param object the object to render
 */
- (void)render:(id<DKRenderable>)object
{
	if (![self enabled])
		return;

	if (![object conformsToProtocol:@protocol(DKRenderable)])
		return;

	dispatch_semaphore_wait(m_renderListLock, m_renderListLockTimeOutSeconds);
	
	SAVE_GRAPHICS_CONTEXT //[NSGraphicsContext saveGraphicsState];
		[m_renderList makeObjectsPerformSelector:_cmd
										   withObject:object];

	RESTORE_GRAPHICS_CONTEXT //[NSGraphicsContext restoreGraphicsState];

	dispatch_semaphore_signal(m_renderListLock);
}

/** @brief Renders the object's path by iterating over the contained renderers

 Normally groups and styles should use render: but this provides correct behaviour if a top level
 object elects to use the path (in general, don't do this)
 @param path the path to render
 */
- (void)renderPath:(NSBezierPath*)path
{
	if (![self enabled])
		return;

	dispatch_semaphore_wait(m_renderListLock, m_renderListLockTimeOutSeconds);
	
	SAVE_GRAPHICS_CONTEXT //[NSGraphicsContext saveGraphicsState];
		[m_renderList makeObjectsPerformSelector:_cmd
										   withObject:path];
	RESTORE_GRAPHICS_CONTEXT //[NSGraphicsContext restoreGraphicsState];
	
	dispatch_semaphore_signal(m_renderListLock);
}

/** @brief Queries whther the rasterizer implements a fill or not

 Returns YES if any contained rasterizer returns YES, NO otherwise
 @return YES if the rasterizer is considered a fill type
 */
- (BOOL)isFill
{
	BOOL ret = NO;
	
	dispatch_semaphore_wait(m_renderListLock, m_renderListLockTimeOutSeconds);
	
	for (DKRasterizer* rast in m_renderList) {
		if ([rast isFill]) {
			ret = YES;
			break;
		}
	}

	dispatch_semaphore_signal(m_renderListLock);
	
	return ret;
}

#pragma mark -
#pragma mark As part of GraphicsAttributes Protocol

/** @brief Installs renderers when built from a script
 @param val a renderer object
 @param pnum th eordinal position of the value in the original expression. Not used here.
 */
- (void)setValue:(id)val forNumericParameter:(NSInteger)pnum
{
	LogEvent_(kReactiveEvent, @"anonymous parameter #%ld, value = %@", (long)pnum, val);

	// if <val> conforms to the DKRasterizer protocol, we add it

	if ([val conformsToProtocol:@protocol(DKRasterizer)])
		[self addRenderer:val];
}

#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)encodeWithCoder:(NSCoder*)coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	
	dispatch_semaphore_wait(m_renderListLock, m_renderListLockTimeOutSeconds);

	[super encodeWithCoder:coder];

	[coder encodeConditionalObject:[self container]
							forKey:@"DKRastGroup_container"];
	[coder encodeObject:m_renderList
				 forKey:@"renderlist"];
	
	dispatch_semaphore_signal(m_renderListLock);	
}

- (instancetype)initWithCoder:(NSCoder*)coder
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
	dispatch_semaphore_wait(m_renderListLock, m_renderListLockTimeOutSeconds);
	
	DKRastGroup* copy = [super copyWithZone:zone];

	NSArray* rl = [m_renderList deepCopy];

	[copy setRenderList:rl];

	dispatch_semaphore_signal(m_renderListLock);
	
	return copy;
}

#pragma mark -
#pragma mark As part of NSKeyValueCoding Protocol

/** @brief Returns a renderer class associated with the given key

 This is used to support simple UI's that bind to certain renderers based on generic keypaths
 @param key a key for the renderer class
 @return a renderer class matching the key, if any
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

 This is used to support simple UI's that bind to certain renderers based on generic keypaths. Here,
 the renderer is preferentially referred to by name, but if that fails, falls back on generic
 lookup based on a simplified classname.
 @param key a key for the renderer class
 @return a renderer matching the key, if any
 */
- (id)valueForUndefinedKey:(NSString*)key
{
	Class classForKey = [self renderClassForKey:key];

	for (DKRasterizer* rend in m_renderList) {
		if ([[rend name] isEqualToString:key] || (classForKey && [rend isKindOfClass:classForKey])) {
			return rend;
		}
	}
	return nil;
}

@end
