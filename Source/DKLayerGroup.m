/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKLayerGroup.h"
#import "DKDrawing.h"
#import "DKDrawKitMacros.h"
#import "LogEvent.h"

#pragma mark Constants(Non - localized)
NSString* kDKLayerGroupDidAddLayer = @"kDKLayerGroupDidAddLayer";
NSString* kDKLayerGroupDidRemoveLayer = @"kDKLayerGroupDidRemoveLayer";
NSString* kDKLayerGroupNumberOfLayersDidChange = @"kDKLayerGroupNumberOfLayersDidChange";
NSString* kDKLayerGroupWillReorderLayers = @"kDKLayerGroupWillReorderLayers";
NSString* kDKLayerGroupDidReorderLayers = @"kDKLayerGroupDidReorderLayers";

#pragma mark -
@implementation DKLayerGroup
#pragma mark As a DKLayerGroup

/** @brief Convenience method for building a new layer group from an existing list of layers

 The group must be added to a drawing to be useful. If the layers are already part of a drawing,
 or other group, they need to be removed first. It is an error to attach a layer in more than one
 group (or drawing, which is a group) at a time.
 Layers should be stacked with the top at index #0, the bottom at #(count -1)
 @param layers a list of existing layers
 @return a new layer group containing the passed layers
 */
+ (DKLayerGroup*)layerGroupWithLayers:(NSArray*)layers
{
	DKLayerGroup* lg = [[self alloc] initWithLayers:layers];

	return lg;
}

#pragma mark -

/** @brief Initialize a layer group

 A layer group must be added to another group or drawing before it can be used
 @param layers a list of existing layers
 @return a new layer group
 */
- (instancetype)initWithLayers:(NSArray*)layers
{
	self = [super init];
	if (self != nil) {
		m_layers = [NSMutableArray arrayWithCapacity:4];

		if (m_layers == nil) {
			return nil;
		}

		if (layers != nil) {
			[self setLayers:layers];
		}
		[self setSelectionColour:nil];
	}
	return self;
}

#pragma mark -
#pragma mark - layer list

/** @brief Sets the drawing's layers to those in the array

 Layers are usually added one at a time through some user interface, but this allows them to
 be set all at once, as when unarchiving. Not recorded for undo.
 @param layers an array, consisting of any number of DKLayer objects or subclasses
 */
- (void)setLayers:(NSArray*)layers
{
	NSAssert(layers != nil, @"attempt to set layer groups layers to nil");

	if (layers != [self layers]) {
		LogEvent_(kReactiveEvent, @"setting layer group %@, layers = %@", self, layers);

		[m_layers makeObjectsPerformSelector:@selector(setLayerGroup:)
								  withObject:nil];
		m_layers = [layers mutableCopy];

		// this is to ensure the group member is inited - older files didn't save the group ref so it will be nil
		// newer files do, but doing this anyway has no harmful effect

		[m_layers makeObjectsPerformSelector:@selector(setLayerGroup:)
								  withObject:self];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerGroupNumberOfLayersDidChange
															object:self];
	}
}

/** @brief Returns the current layers

 A drawing can have an unlimited number of layers
 @return an array, a list of any number of DKLayer objects or subclasses
 */
- (NSArray*)layers
{
	return m_layers;
}

/** @brief Returns the number of layers
 @return the number of layers
 */
- (NSUInteger)countOfLayers
{
	return [m_layers count];
}

/** @brief Returns the layer index number of the highest layer that is fully opaque.

 Used for optimising drawing - layers below the highest opaque layer are not drawn (because they can't
 be seen "through" the opaque layer). A layer decides itself if it's opaque by returning YES or NO for
 isOpaque. If no layers are opaque, returns the index of the bottom layer.
 @return an integer, the index number of the highest opaque layer
 */
- (NSUInteger)indexOfHighestOpaqueLayer
{
	// returns the index of the topmost layer that returns YES for isOpaque.

	NSUInteger i = 0;

	do {
		if ([[self objectInLayersAtIndex:i] isOpaque])
			return i;
	} while (++i < [self countOfLayers]);

	return [self countOfLayers] - 1; // the bottom layer is the last
}

/** @brief Returns all of the layers in this group and all groups below it

 The returned list does not contain any layer groups
 @return a list of layers
 */
- (NSArray*)flattenedLayers
{
	return [self flattenedLayersIncludingGroups:NO];
}

/** @brief Returns all of the layers in this group and all groups below it
 @param includeGroups if YES, list includes the groups, NO only returns actual layers
 @return a list of layers
 */
- (NSArray*)flattenedLayersIncludingGroups:(BOOL)includeGroups
{
	NSMutableArray* fLayers = [NSMutableArray array];

	if (includeGroups)
		[fLayers addObject:self];

	for (DKLayer* layer in [self layers]) {
		if ([layer respondsToSelector:_cmd])
			[fLayers addObjectsFromArray:[(DKLayerGroup*)layer flattenedLayersIncludingGroups:includeGroups]];
		else
			[fLayers addObject:layer];
	}

	return fLayers;
}

/** @brief Returns all of the layers in this group and all groups below it having the given class

 Does not include groups unless the class is DKLayerGroup
 @param layerClass a Class indicating the kind of layer of interest
 @return a list of matching layers
 */
- (NSArray*)flattenedLayersOfClass:(Class)layerClass
{
	return [self flattenedLayersOfClass:layerClass
						  includeGroups:NO];
}

/** @brief Returns all of the layers in this group and all groups below it having the given class
 @param layerClass a Class indicating the kind of layer of interest
 @param includeGroups if YES, includes groups as well as the requested class
 @return a list of matching layers
 */
- (NSArray*)flattenedLayersOfClass:(Class)layerClass includeGroups:(BOOL)includeGroups
{
	NSMutableArray* fLayers = [NSMutableArray array];

	if (includeGroups || [self isKindOfClass:layerClass])
		[fLayers addObject:self];

	for (DKLayer* layer in [self layers]) {
		if ([layer respondsToSelector:_cmd])
			[fLayers addObjectsFromArray:[(DKLayerGroup*)layer flattenedLayersOfClass:layerClass
																		includeGroups:includeGroups]];
		else if ([layer isKindOfClass:layerClass])
			[fLayers addObject:layer];
	}

	return fLayers;
}

#pragma mark -
#pragma mark - adding and removing layers

/** @brief Creates and adds a layer to the drawing

 LayerClass must be a valid subclass of DKLayer, otherwise does nothing and nil is returned
 @param layerClass the class of some kind of layer
 @return the layer created
 */
- (DKLayer*)addNewLayerOfClass:(Class)layerClass
{
	if ([layerClass isSubclassOfClass:[DKLayer class]]) {
		DKLayer* layer = [[layerClass alloc] init];

		[self addLayer:layer];
		 // retained by self

		return layer;
	} else
		return nil;
}

/** @brief Adds a layer to the group

 The added layer is placed above all other layers.
 @param aLayer a DKLayer object, or subclass thereof
 */
- (void)addLayer:(DKLayer*)aLayer
{
	NSAssert(aLayer != nil, @"can't add a nil layer");

	[self insertObject:aLayer
		inLayersAtIndex:0];
}

/** @brief Adds a layer above a specific index position in the stack

 Layer indexes run from 0 being the top layer to (count -1), being the bottom layer
 @param aLayer a DKLayer object, or subclass thereof
 @param layerIndex the index number of the layer the new layer should be placed in front of.
 */
- (void)addLayer:(DKLayer*)aLayer aboveLayerIndex:(NSUInteger)layerIndex
{
	NSAssert(aLayer != nil, @"cannot add a nil layer");

	// adds a layer above the given index - if index is 0 or 1 puts the layer on top

	if (layerIndex <= 1)
		[self insertObject:aLayer
			inLayersAtIndex:0];
	else
		[self insertObject:aLayer
			inLayersAtIndex:layerIndex];
}

/** @brief Adds a layer at a specific index position in the stack

 All other addLayer methods call this, which permits the operation to be undone including restoring
 layer indexes run from 0 being the top layer to (count -1), being the bottom layer
 @param aLayer a DKLayer object, or subclass thereof
 @param layerIndex the index number of the layer inserted
 */
- (void)insertObject:(DKLayer*)aLayer inLayersAtIndex:(NSUInteger)layerIndex
{
	NSAssert(aLayer != nil, @"cannot insert a nil layer");

	// check that the layer being added isn't a DKDrawing instance - that is a bad thing to attempt.

	if ([aLayer isKindOfClass:[DKDrawing class]])
		[NSException raise:NSInternalInconsistencyException
					format:@"Error - attempt to add a DKDrawing instance to a layer group"];

	if (![self locked] && ![m_layers containsObject:aLayer]) {
		[[[self undoManager] prepareWithInvocationTarget:self] removeObjectFromLayersAtIndex:layerIndex];

		[m_layers insertObject:aLayer
					   atIndex:layerIndex];
		[aLayer setLayerGroup:self];
		[aLayer drawingDidChangeToSize:[NSValue valueWithSize:[[self drawing] drawingSize]]];
		[self setNeedsDisplay:YES];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerGroupDidAddLayer
															object:self];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerGroupNumberOfLayersDidChange
															object:self];
	}
}

/** @brief Removes the layer from the drawing

 Disposes of the layer if there are no other references to it.
 @param aLayer a DKLayer object, or subclass thereof, that already exists in the group
 */
- (void)removeLayer:(DKLayer*)aLayer
{
	NSAssert(aLayer != nil, @"cannot remove a nil layer");

	[self removeObjectFromLayersAtIndex:[self indexOfLayer:aLayer]];
}

/** @brief Remove the layer with a particular index number from the layer

 All other removeLayer methods call this, which permits the operation to be undone including restoring
 layer indexes run from 0 being the top layer to (count -1), being the bottom layer
 @param layerIndex the index number of the layer to remove
 */
- (void)removeObjectFromLayersAtIndex:(NSUInteger)layerIndex
{
	NSAssert(layerIndex < [self countOfLayers], @"layer index out of range in removeLayerFromLayersAtIndex:");

	if (![self locked]) {
		DKLayer* aLayer = [self objectInLayersAtIndex:layerIndex];

		if (aLayer) {
			[[[self undoManager] prepareWithInvocationTarget:self] insertObject:aLayer
																inLayersAtIndex:layerIndex];
			[aLayer setLayerGroup:nil];
			[m_layers removeObjectAtIndex:layerIndex];
			[self setNeedsDisplay:YES];
			[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerGroupDidRemoveLayer
																object:self];
			[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerGroupNumberOfLayersDidChange
																object:self];
		}
	}
}

/** @brief Removes all of the group's layers

 This method is not undoable. To undoably remove a layer, remove them one at a time. KVO observers
 will not be notified by this method.
 */
- (void)removeAllLayers
{
	if (![self locked]) {
		[[self undoManager] removeAllActionsWithTarget:self];

		[m_layers makeObjectsPerformSelector:@selector(setLayerGroup:)
								  withObject:nil];
		[m_layers removeAllObjects];
		[self setNeedsDisplay:YES];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerGroupDidRemoveLayer
															object:self];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerGroupNumberOfLayersDidChange
															object:self];
	}
}

/** @brief Disambiguates a layer's name by appending digits until there is no conflict

 It is not important that layer's have unique names, but a UI will usually want to do this, thus
 when using the addLayer:andActivateIt: method, the name of the added layer is disambiguated.
 @param aName a string containing the proposed name
 @return a string, either the original string or a modified version of it
 */
- (NSString*)uniqueLayerNameForName:(NSString*)aName
{
	NSInteger numeral = 0;
	BOOL found = YES;
	NSString* temp = aName;
	NSArray* keys = [[self layers] valueForKey:@"layerName"];

	while (found) {
		NSInteger k = [keys indexOfObject:temp];

		if (k == NSNotFound)
			found = NO;
		else
			temp = [NSString stringWithFormat:@"%@ %ld", aName, (long)++numeral];
	}

	return temp;
}

#pragma mark -
#pragma mark - getting layers

/** @brief Returns the layer object at the given index
 @param layerIndex the index number of the layer of interest
 @return a DKLayer object or subclass
 */
- (DKLayer*)objectInLayersAtIndex:(NSUInteger)layerIndex
{
	NSAssert1(layerIndex < [self countOfLayers], @"bad layer index %ld (overrange)", (long)layerIndex);

	return [[self layers] objectAtIndex:layerIndex];
}

/** @brief Returns the topmost layer
 @return the topmost DKLayer object or subclass
 */
- (DKLayer*)topLayer
{
	if ([self countOfLayers] > 0)
		return [self objectInLayersAtIndex:0];
	else
		return nil;
}

/** @brief Returns the bottom layer

 Ignores opacity of layers in the stack - this is the one on the bottom, regardless
 @return the bottom DKLayer object or subclass, or nil, if there are no layers
 */
- (DKLayer*)bottomLayer
{
	return [[self layers] lastObject];
}

/** @brief Returns the stack position of a given layer

 Layer indexes run from 0 being the top layer to (count -1), being the bottom layer. If the group does
 not contain the layer, returns NSNotFound. See also -containsLayer:
 @param aLayer a DKLayer object, or subclass thereof, that already exists in the drawing
 @return the stack index position of the layer
 */
- (NSUInteger)indexOfLayer:(DKLayer*)aLayer
{
	return [[self layers] indexOfObjectIdenticalTo:aLayer];
}

/** @brief Returns the uppermost layer matching class, if any

 Does not perform a deep search
 @param cl the class of layer to seek
 @return the uppermost layer of the given class, or nil
 */
- (DKLayer*)firstLayerOfClass:(Class)cl
{
	return [self firstLayerOfClass:cl
				 performDeepSearch:NO];
}

/** @brief Returns the uppermost layer matching class, if any
 @param cl the class of layer to seek
 @param deep if YES, searches all subgroups below this one
 @return the uppermost layer of the given class, or nil
 */
- (DKLayer*)firstLayerOfClass:(Class)cl performDeepSearch:(BOOL)deep
{
	NSArray* layers = [self layersOfClass:cl
						performDeepSearch:deep];

	if (layers && [layers count] > 0)
		return [layers objectAtIndex:0];
	else
		return nil;
}

/** @brief Returns a list of layers of the given class

 Does not perform a deep search
 @param cl the class of layer to seek
 @return a list of layers. May be empty.
 */
- (NSArray*)layersOfClass:(Class)cl
{
	return [self layersOfClass:cl
			 performDeepSearch:NO];
}

/** @brief Returns a list of layers of the given class
 @param cl the class of layer to seek
 @param deep if YES, will search all subgroups below this one. If NO, only this level is searched
 @return a list of layers. May be empty.
 */
- (NSArray*)layersOfClass:(Class)cl performDeepSearch:(BOOL)deep

{
	NSEnumerator* iter = [self layerTopToBottomEnumerator];
	NSMutableArray* layers = [NSMutableArray array];

	for (DKLayer* lyr in iter) {
		if ([lyr isKindOfClass:cl])
			[layers addObject:lyr];

		if (deep && [lyr respondsToSelector:_cmd])
			[layers addObjectsFromArray:[(DKLayerGroup*)lyr layersOfClass:cl
														performDeepSearch:YES]];
	}

	return layers;
}

/** @brief Returns an enumerator that can be used to iterate over the layers in top to bottom order

 This is provided as a convenience so you don't have to worry about the implementation detail of
 which way round layers are ordered to give the top to bottom visual stacking.
 @return an NSEnumerator object
 */
- (NSEnumerator*)layerTopToBottomEnumerator
{
	return [[self layers] objectEnumerator];
}

/** @brief Returns an enumerator that can be used to iterate over the layers in bottom to top order

 This is provided as a convenience so you don't have to worry about the implementation detail of
 which way round layers are ordered to give the top to bottom visual stacking.
 @return an NSEnumerator object
 */
- (NSEnumerator*)layerBottomToTopEnumerator
{
	return [[self layers] reverseObjectEnumerator];
}

/** @brief Find the topmost layer in this group that is 'hit' by the given point

 A layer must implement hitLayer: sensibly for this to operate. This recurses down through any groups
 contained within. See also -hitLayer:
 @param p a point in drawing coordinates
 @return a layer, or nil
 */
- (DKLayer*)findLayerForPoint:(NSPoint)p
{
	if ([self visible]) {
		NSEnumerator* iter = [self layerTopToBottomEnumerator];

		for (__strong DKLayer* layer in iter) {
			if ([layer isKindOfClass:[DKLayerGroup class]]) {
				layer = [(DKLayerGroup*)layer findLayerForPoint:p];

				if (layer)
					return layer;
			} else if ([layer visible] && [layer hitLayer:p])
				return layer;
		}
	}
	return nil;
}

/** @brief Returns whether this group, or any subgroup within, contains the layer

 Unlike -indexOfLayer:, considers nested subgroups.  If the layer is the group, returns \c NO
 (doesn't contain itself).
 @param aLayer a layer of interest
 @return YES if the group contains the layer.
 */
- (BOOL)containsLayer:(DKLayer*)aLayer
{
	if (aLayer == self)
		return NO;
	else {
		NSEnumerator* iter = [self layerTopToBottomEnumerator];

		for (DKLayer* layer in iter) {
			if (aLayer == layer)
				return YES;

			if ([layer isKindOfClass:[DKLayerGroup class]]) {
				if ([(DKLayerGroup*)layer containsLayer:aLayer])
					return YES;
			}
		}

		return NO;
	}
}

/** @brief Returns a layer or layer group having the given unique key

 Unique keys are assigned to layers for the lifetime of the app. They are not persistent and must only
 @param key the layer's key
 @return the layer if found, nil otherwise.
 */
- (DKLayer*)layerWithUniqueKey:(NSString*)key
{
	for (__strong DKLayer* layer in [self layers]) {
		if ([[layer uniqueKey] isEqualToString:key])
			return layer;
		else if ([layer isKindOfClass:[self class]]) {
			layer = [(DKLayerGroup*)layer layerWithUniqueKey:key];
			if (layer)
				return layer;
		}
	}

	return nil;
}

#pragma mark -

/** @brief Makes all layers in the group and in any subgroups visible

 Recurses when nested groups are found
 */
- (void)showAll
{
	NSEnumerator* iter = [self layerTopToBottomEnumerator];

	for (DKLayer* aLayer in iter) {
		[aLayer setVisible:YES];

		if ([aLayer isKindOfClass:[DKLayerGroup class]])
			[(DKLayerGroup*)aLayer showAll];
	}
}

/** @brief Makes all layers in the group and in any subgroups hidden except <aLayer>, which is made visible.

 ALayer may be nil in which case this performs a hideAll. Recurses on any subgroups.
 @param aLayer a layer to leave visible
 */
- (void)hideAllExcept:(DKLayer*)aLayer
{
	NSEnumerator* iter = [self layerTopToBottomEnumerator];

	for (DKLayer* layer in iter) {
		if ([layer isKindOfClass:[DKLayerGroup class]]) {
			[(DKLayerGroup*)layer hideAllExcept:aLayer];

			// this logic keeps groups that contain the excepted layer visible if necessary

			if (layer == aLayer || [(DKLayerGroup*)layer containsLayer:aLayer])
				[layer setVisible:YES];
			else
				[layer setVisible:NO];
		} else
			[layer setVisible:layer == aLayer];
	}
}

/** @brief Returns YES if the  receiver or any of its contained layers is hidden

 Recurses on any subgroups.
 @return YES if there are hidden layers below this, or this is hidden itself
 */
- (BOOL)hasHiddenLayers
{
	if (![self visible])
		return YES;
	else {
		NSEnumerator* iter = [self layerTopToBottomEnumerator];

		for (DKLayer* layer in iter) {
			if (![layer visible])
				return YES;

			if ([layer isKindOfClass:[DKLayerGroup class]]) {
				if ([(DKLayerGroup*)layer hasHiddenLayers])
					return YES;
			}
		}

		return NO;
	}
}

/** @brief Returns YES if the  receiver or any of its contained layers is visible, ignoring the one passed

 Recurses on any subgroups. Typically <aLayer> is the active layer - may be nil.
 @param aLayer a layer to exclude when testing this
 @return YES if there are visible layers below this, or this is visible itself
 */
- (BOOL)hasVisibleLayersOtherThan:(DKLayer*)aLayer
{
	if (![self visible] && self != aLayer)
		return NO;

	NSEnumerator* iter = [self layerTopToBottomEnumerator];

	for (DKLayer* layer in iter) {
		if (layer != aLayer) {
			if ([layer visible])
				return YES;

			if ([layer isKindOfClass:[DKLayerGroup class]]) {
				if ([(DKLayerGroup*)layer hasVisibleLayersOtherThan:aLayer])
					return YES;
			}
		}
	}

	return NO;
}

#pragma mark -
#pragma mark - layer stacking order

/** @brief Moves the layer one place towards the top of the stack

 If already on top, does nothing
 @param aLayer the layer to move up
 */
- (void)moveUpLayer:(DKLayer*)aLayer
{
	NSAssert(aLayer != nil, @"cannot move a nil layer");

	[self moveLayer:aLayer
			toIndex:[self indexOfLayer:aLayer] - 1];
}

/** @brief Moves the layer one place towards the bottom of the stack

 If already at the bottom, does nothing
 @param aLayer the layer to move down
 */
- (void)moveDownLayer:(DKLayer*)aLayer
{
	NSAssert(aLayer != nil, @"cannot move a nil layer");

	[self moveLayer:aLayer
			toIndex:[self indexOfLayer:aLayer] + 1];
}

/** @brief Moves the layer to the top of the stack

 If already on top, does nothing
 @param aLayer the layer to move up
 */
- (void)moveLayerToTop:(DKLayer*)aLayer
{
	NSAssert(aLayer != nil, @"cannot move a nil layer");

	[self moveLayer:aLayer
			toIndex:0];
}

/** @brief Moves the layer to the bottom of the stack

 If already at the bottom, does nothing
 @param aLayer the layer to move down
 */
- (void)moveLayerToBottom:(DKLayer*)aLayer
{
	NSAssert(aLayer != nil, @"cannot move a nil layer");

	[self moveLayer:aLayer
			toIndex:[self countOfLayers] - 1];
}

/** @brief Changes a layer's z-stacking order so it comes before (above) <otherLayer>
 @param aLayer the layer to move - may not be nil
 @param otherLayer move above this layer. May be nil, which moves the layer to the bottom
 */
- (void)moveLayer:(DKLayer*)aLayer aboveLayer:(DKLayer*)otherLayer
{
	NSAssert(aLayer != nil, @"cannot move a nil layer");

	if (otherLayer == nil)
		[self moveLayerToBottom:aLayer];
	else
		[self moveLayer:aLayer
				toIndex:[self indexOfLayer:otherLayer]];
}

/** @brief Changes a layer's z-stacking order so it comes after (below) <otherLayer>
 @param aLayer the layer to move - may not be nil
 @param otherLayer move below this layer. May be nil, which moves the layer to the top
 */
- (void)moveLayer:(DKLayer*)aLayer belowLayer:(DKLayer*)otherLayer
{
	NSAssert(aLayer != nil, @"cannot move a nil layer");

	if (otherLayer == nil)
		[self moveLayerToTop:aLayer];
	else
		[self moveLayer:aLayer
				toIndex:[self indexOfLayer:otherLayer] + 1];
}

/** @brief Moves a layer to the index position given. This is called by all if the other moveLayer... methods

 If the layer can't be moved, does nothing. The action is recorded for undo if there is an undoManager
 attached.
 @param aLayer the layer to move
 @param i the index position to move it to.
 */
- (void)moveLayer:(DKLayer*)aLayer toIndex:(NSUInteger)i
{
	// all other layer stacking methods call this one, which implements undo and notification

	NSAssert(aLayer != nil, @"trying to move nil layer");
	NSAssert(![aLayer locked], @"trying to move a locked layer");

	if (![self locked]) {
		NSUInteger k = [self indexOfLayer:aLayer];

		if (k == NSNotFound)
			return;

		i = MIN(i, [self countOfLayers] - 1);

		if (k != i) {
			[[[self undoManager] prepareWithInvocationTarget:self] moveLayer:aLayer
																	 toIndex:k];
			[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerGroupWillReorderLayers
																object:self];

			[m_layers removeObject:aLayer];
			[m_layers insertObject:aLayer
						   atIndex:i];

			[self setNeedsDisplay:YES];
			[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerGroupDidReorderLayers
																object:self];
		}
	}
}

#pragma mark -
#pragma mark As a DKLayer

/** @brief Propagates the undo manager to all contained layers
 @param um the drawing's undo manager
 */
- (void)drawingHasNewUndoManager:(NSUndoManager*)um
{
	[[self layers] makeObjectsPerformSelector:@selector(drawingHasNewUndoManager:)
								   withObject:um];
}

/** @brief Draws the layers it contains

 Layers are not drawn if they lie below the highest opaque layer, or if we are printing and the layer
 isn't printable. Otherwise they are drawn from bottom upwards.
 @param rect the update area passed from the original view
 */
- (void)drawRect:(NSRect)rect inView:(DKDrawingView*)aView
{
	if ([self countOfLayers] > 0) {
		// if clipping to the interior, set up that clip now

		SAVE_GRAPHICS_CONTEXT //[NSGraphicsContext saveGraphicsState];
			if ([self clipsDrawingToInterior])
					[NSBezierPath clipRect : [[self drawing] interior]];

		NSUInteger bottom;
		NSInteger n;
		BOOL printing = ![NSGraphicsContext currentContextDrawingToScreen];
		DKLayer* layer;

		bottom = [self indexOfHighestOpaqueLayer];

		for (n = bottom; n >= 0; --n) {
			layer = [self objectInLayersAtIndex:n];

			if ([layer visible] && !(printing && ![layer shouldDrawToPrinter])) {
				@try
				{
					[NSGraphicsContext saveGraphicsState];

					if ([layer clipsDrawingToInterior])
						[NSBezierPath clipRect:[[self drawing] interior]];

					[layer beginDrawing];
					[layer drawRect:rect
							 inView:aView];
					[layer endDrawing];
				}
				@catch (id exc)
				{
					NSLog(@"exception while drawing layer %@ [%ld of %ld in group %@](%@ - ignored)", layer, (long)n, (long)[self countOfLayers], self, exc);
				}
				@finally
				{
					[NSGraphicsContext restoreGraphicsState];
				}
			}
		}
		RESTORE_GRAPHICS_CONTEXT //[NSGraphicsContext restoreGraphicsState];
	}
}

/** @brief Returns whether the layer can become the active layer

 The default for groups is NO. Discrete layers should be activated, not groups.
 @return YES if the layer can become active, NO to not become active
 */
- (BOOL)layerMayBecomeActive
{
	return NO;
}

/** @brief Propagate the message to all contained layers
 @param sizeVal the new size
 */
- (void)drawingDidChangeToSize:(NSValue*)sizeVal
{
	[[self layers] makeObjectsPerformSelector:@selector(drawingDidChangeToSize:)
								   withObject:sizeVal];
}

/** @brief Propagate the message to all contained layers
 @param oldInterior the old interior rect of the drawing
 */
- (void)drawingDidChangeMargins:(NSValue*)oldInterior
{
	[[self layers] makeObjectsPerformSelector:@selector(drawingDidChangeMargins:)
								   withObject:oldInterior];
}

/** @brief See if any enclosed layer is hit by the point
 @param p the point to test
 @return YES if any layer within this group was hit, otherwise NO
 */
- (BOOL)hitLayer:(NSPoint)p
{
	NSEnumerator* iter = [self layerTopToBottomEnumerator];

	for (DKLayer* layer in iter) {
		if ([layer hitLayer:p])
			return YES;
	}
	return NO;
}

/** @brief Notifies the layer that it or a group containing it was added to a drawing.

 Propagates the message to all contained layers
 @param aDrawing the drawing that added the layer
 */
- (void)wasAddedToDrawing:(DKDrawing*)aDrawing
{
	[[self layers] makeObjectsPerformSelector:_cmd
								   withObject:aDrawing];
}

/** @brief Returns the hierarchical level of this group, i.e. how deeply nested it is

 The root group returns 0, next level is 1 and so on. 
 @return the group's level
 */
- (NSUInteger)level
{
	if ([self layerGroup] == nil)
		return 0;
	else
		return [[self layerGroup] level] + 1;
}

#pragma mark -
#pragma mark - style utilities

/** @brief Return all of styles used by layers in this group
 @return a set containing the union of sets returned by all similar methods of individual layers
 */
- (NSSet*)allStyles
{
	// returns the union of all sublayers that return something for this method

	NSEnumerator* iter = [self layerTopToBottomEnumerator];
	NSMutableSet* unionOfAllStyles = nil;

	for (DKLayer* layer in iter) {
		NSSet *styles = [layer allStyles];

		if (styles != nil) {
			// we got one - make a set to union them with if necessary

			if (unionOfAllStyles == nil)
				unionOfAllStyles = [styles mutableCopy];
			else
				[unionOfAllStyles unionSet:styles];
		}
	}

	return unionOfAllStyles;
}

/** @brief Return all of registered styles used by the layers in this group
 @return a set containing the union of sets returned by all similar methods of individual layers
 */
- (NSSet*)allRegisteredStyles
{
	// returns the union of all sublayers that return something for this method

	NSEnumerator* iter = [self layerTopToBottomEnumerator];
	NSMutableSet* unionOfAllStyles = nil;

	for (DKLayer* layer in iter) {
		NSSet *styles = [layer allRegisteredStyles];

		if (styles != nil) {
			// we got one - make a set to union them with if necessary

			if (unionOfAllStyles == nil)
				unionOfAllStyles = [styles mutableCopy];
			else
				[unionOfAllStyles unionSet:styles];
		}
	}

	return unionOfAllStyles;
}

/** @brief Substitute styles with those in the given set

 This is an important step in reconciling the styles loaded from a file with the existing
 registry. Implemented by DKObjectOwnerLayer, etc. Groups propagate the change to all sublayers.
 @param aSet a set of style objects
 */
- (void)replaceMatchingStylesFromSet:(NSSet*)aSet
{
	[[self layers] makeObjectsPerformSelector:@selector(replaceMatchingStylesFromSet:)
								   withObject:aSet];
}

#pragma mark -
#pragma mark As an NSObject
- (void)dealloc
{
	// set group ref to nil in case someone else is retaining any layer

	[m_layers makeObjectsPerformSelector:@selector(setLayerGroup:)
							  withObject:nil];
}

- (instancetype)init
{
	return [self initWithLayers:nil];
}

#pragma mark -
#pragma mark As part NSCoding Protocol
- (void)encodeWithCoder:(NSCoder*)coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];

	// store a flag to say that we now store layers the other way up - this triggers older files that lack this
	// to have their layer order reversed when loaded

	[coder encodeBool:YES
			   forKey:@"DKLayerGroup_invertedStack"];
	[coder encodeObject:[self layers]
				 forKey:@"DKLayerGroup_layers"];
}

- (instancetype)initWithCoder:(NSCoder*)coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	LogEvent_(kFileEvent, @"decoding layer group %@", self);

	self = [super initWithCoder:coder];
	if (self != nil) {
		// prior to beta 3, layers were stored in the inverse order, so those files need to have their layers stacked
		//  the other way up so they come up true in the current model.

		BOOL hasInvertedLayerStack = [coder decodeBoolForKey:@"DKLayerGroup_invertedStack"];

		if (!hasInvertedLayerStack) {
			NSArray* layerStack = [coder decodeObjectForKey:@"layers"];

			if ([layerStack count] > 1) {
				NSMutableArray* temp = [NSMutableArray array];

				for (DKLayer* layer in layerStack)
					[temp insertObject:layer
							   atIndex:0];

				[self setLayers:temp];
			} else
				[self setLayers:layerStack];
		} else {
			NSArray* layers = [coder decodeObjectForKey:@"DKLayerGroup_layers"];

			if (layers == nil)
				layers = [coder decodeObjectForKey:@"layers"];

			LogEvent_(kFileEvent, @"decoding layers in group: %@", layers);
			[self setLayers:layers];
		}

		if (m_layers == nil) {
			return nil;
		}
	}
	return self;
}

@end
