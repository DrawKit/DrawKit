///**********************************************************************************************************************************
///  DKLayerGroup.m
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 23/08/2007.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKLayerGroup.h"
#import "DKDrawing.h"
#import "DKDrawKitMacros.h"
#import "LogEvent.h"


#pragma mark Constants (Non-localized)
NSString*		kDKLayerGroupDidAddLayer				= @"kDKLayerGroupDidAddLayer";
NSString*		kDKLayerGroupDidRemoveLayer				= @"kDKLayerGroupDidRemoveLayer";
NSString*		kDKLayerGroupNumberOfLayersDidChange	= @"kDKLayerGroupNumberOfLayersDidChange";
NSString*		kDKLayerGroupWillReorderLayers			= @"kDKLayerGroupWillReorderLayers";
NSString*		kDKLayerGroupDidReorderLayers			= @"kDKLayerGroupDidReorderLayers";


#pragma mark -
@implementation DKLayerGroup
#pragma mark As a DKLayerGroup
///*********************************************************************************************************************
///
/// method:			layerGroupWithLayers:
/// scope:			public class method
/// overrides:
/// description:	convenience method for building a new layer group from an existing list of layers
/// 
/// parameters:		<layers> a list of existing layers
/// result:			a new layer group containing the passed layers
///
/// notes:			the group must be added to a drawing to be useful. If the layers are already part of a drawing,
///					or other group, they need to be removed first. It is an error to attach a layer in more than one
///					group (or drawing, which is a group) at a time.
///					Layers should be stacked with the top at index #0, the bottom at #(count -1)
///
///********************************************************************************************************************

+ (DKLayerGroup*)			layerGroupWithLayers:(NSArray*) layers
{
	DKLayerGroup* lg = [[self alloc] initWithLayers:layers];
	
	return [lg autorelease];
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			initWithLayers:
/// scope:			public method, designated initializer
/// overrides:
/// description:	initialize a layer group
/// 
/// parameters:		<layers> a list of existing layers
/// result:			a new layer group
///
/// notes:			a layer group must be added to another group or drawing before it can be used
///
///********************************************************************************************************************

- (id)						initWithLayers:(NSArray*) layers
{
	self = [super init];
	if (self != nil)
	{
		m_layers = [[NSMutableArray arrayWithCapacity:4] retain];
		
		if (m_layers == nil)
		{
			[self autorelease];
			self = nil;
		}
	}
	if (self != nil)
	{
		if (layers != nil)
		{
			[self setLayers:layers];
		}
		[self setSelectionColour:nil];
	}
	return self;
}


#pragma mark -
#pragma mark - layer list
///*********************************************************************************************************************
///
/// method:			setLayers:
/// scope:			public method
/// overrides:
/// description:	sets the drawing's layers to those in the array
/// 
/// parameters:		<layers> an array, consisting of any number of DKLayer objects or subclasses
/// result:			none
///
/// notes:			layers are usually added one at a time through some user interface, but this allows them to
///					be set all at once, as when unarchiving. Not recorded for undo.
///
///********************************************************************************************************************

- (void)				setLayers:(NSArray*) layers
{
	NSAssert( layers != nil, @"attempt to set layer groups layers to nil");
	
	if( layers != [self layers])
	{
		LogEvent_(kReactiveEvent, @"setting layer group %@, layers = %@", self, layers);

		[m_layers makeObjectsPerformSelector:@selector(setLayerGroup:) withObject:nil];
		[m_layers release];
		m_layers = [layers mutableCopy];
		
		// this is to ensure the group member is inited - older files didn't save the group ref so it will be nil
		// newer files do, but doing this anyway has no harmful effect
		
		[m_layers makeObjectsPerformSelector:@selector(setLayerGroup:) withObject:self];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerGroupNumberOfLayersDidChange object:self];
	}
}


///*********************************************************************************************************************
///
/// method:			layers
/// scope:			public method
/// overrides:
/// description:	returns the current layers
/// 
/// parameters:		none
/// result:			an array, a list of any number of DKLayer objects or subclasses
///
/// notes:			a drawing can have an unlimited number of layers
///
///********************************************************************************************************************

- (NSArray*)			layers
{
	return m_layers;
}


///*********************************************************************************************************************
///
/// method:			countOfLayers
/// scope:			public method
/// overrides:
/// description:	returns the number of layers
/// 
/// parameters:		none
/// result:			the number of layers
///
/// notes:			
///
///********************************************************************************************************************

- (NSUInteger)			countOfLayers
{
	return[m_layers count];
}


///*********************************************************************************************************************
///
/// method:			indexOfHighestOpaqueLayer
/// scope:			public method
/// overrides:
/// description:	returns the layer index number of the highest layer that is fully opaque.
/// 
/// parameters:		none
/// result:			an integer, the index number of the highest opaque layer
///
/// notes:			used for optimising drawing - layers below the highest opaque layer are not drawn (because they can't
///					be seen "through" the opaque layer). A layer decides itself if it's opaque by returning YES or NO for
///					isOpaque. If no layers are opaque, returns the index of the bottom layer.
///
///********************************************************************************************************************

- (NSUInteger)			indexOfHighestOpaqueLayer
{
	// returns the index of the topmost layer that returns YES for isOpaque.

	NSUInteger i = 0;
	
	do
	{
		if ([[self objectInLayersAtIndex:i] isOpaque])
			return i;
	}
	while( ++i < [self countOfLayers]);
	
	return [self countOfLayers] - 1;	// the bottom layer is the last
}


///*********************************************************************************************************************
///
/// method:			flattenedLayers
/// scope:			public method
/// overrides:
/// description:	returns all of the layers in this group and all groups below it
/// 
/// parameters:		none
/// result:			a list of layers
///
/// notes:			the returned list does not contain any layer groups
///
///********************************************************************************************************************

- (NSArray*)			flattenedLayers
{
	return [self flattenedLayersIncludingGroups:NO];
}


///*********************************************************************************************************************
///
/// method:			flattenedLayersIncludingGroups:
/// scope:			public method
/// overrides:
/// description:	returns all of the layers in this group and all groups below it
/// 
/// parameters:		<includeGroups> if YES, list includes the groups, NO only returns actual layers
/// result:			a list of layers
///
/// notes:			
///
///********************************************************************************************************************

- (NSArray*)			flattenedLayersIncludingGroups:(BOOL) includeGroups
{
	NSEnumerator*	iter = [[self layers] objectEnumerator];
	DKLayer*		layer;
	NSMutableArray*	fLayers = [NSMutableArray array];
	
	if( includeGroups )
		[fLayers addObject:self];
	
	while(( layer = [iter nextObject]))
	{
		if([layer respondsToSelector:_cmd])
			[fLayers addObjectsFromArray:[(DKLayerGroup*)layer flattenedLayersIncludingGroups:includeGroups]];
		else
			[fLayers addObject:layer];
	}
	
	return fLayers;
}


///*********************************************************************************************************************
///
/// method:			flattenedLayersOfClass:
/// scope:			public method
/// overrides:
/// description:	returns all of the layers in this group and all groups below it having the given class
/// 
/// parameters:		<layerClass> a Class indicating the kind of layer of interest
/// result:			a list of matching layers
///
/// notes:			does not include groups unless the class is DKLayerGroup
///
///********************************************************************************************************************

- (NSArray*)			flattenedLayersOfClass:(Class) layerClass
{
	return [self flattenedLayersOfClass:layerClass includeGroups:NO];
}


///*********************************************************************************************************************
///
/// method:			flattenedLayersOfClass:includeGroups:
/// scope:			public method
/// overrides:
/// description:	returns all of the layers in this group and all groups below it having the given class
/// 
/// parameters:		<layerClass> a Class indicating the kind of layer of interest
///					<includeGroups> if YES, includes groups as well as the requested class
/// result:			a list of matching layers
///
/// notes:			
///
///********************************************************************************************************************

- (NSArray*)			flattenedLayersOfClass:(Class) layerClass includeGroups:(BOOL) includeGroups
{
	NSEnumerator*	iter = [[self layers] objectEnumerator];
	DKLayer*		layer;
	NSMutableArray*	fLayers = [NSMutableArray array];
	
	if( includeGroups || [self isKindOfClass:layerClass])
		[fLayers addObject:self];
	
	while(( layer = [iter nextObject]))
	{
		if([layer respondsToSelector:_cmd])
			[fLayers addObjectsFromArray:[(DKLayerGroup*)layer flattenedLayersOfClass:layerClass includeGroups:includeGroups]];
		else if([layer isKindOfClass:layerClass])
			[fLayers addObject:layer];
	}
	
	return fLayers;
}


#pragma mark -
#pragma mark - adding and removing layers
///*********************************************************************************************************************
///
/// method:			addNewLayerOfClass:
/// scope:			public method
/// overrides:
/// description:	creates and adds a layer to the drawing
/// 
/// parameters:		<layerClass> the class of some kind of layer
/// result:			the layer created
///
/// notes:			layerClass must be a valid subclass of DKLayer, otherwise does nothing and nil is returned
///
///********************************************************************************************************************

- (DKLayer*)		addNewLayerOfClass:(Class) layerClass
{
	if ([layerClass isSubclassOfClass:[DKLayer class]])
	{
		DKLayer* layer = [[layerClass alloc] init];
	
		[self addLayer:layer];
		[layer release]; // retained by self
	
		return layer;
	}
	else
		return nil;
}


///*********************************************************************************************************************
///
/// method:			addLayer:
/// scope:			public method
/// overrides:
/// description:	adds a layer to the group
/// 
/// parameters:		<aLayer> a DKLayer object, or subclass thereof
/// result:			none
///
/// notes:			the added layer is placed above all other layers.
///
///********************************************************************************************************************

- (void)				addLayer:(DKLayer*) aLayer
{
	NSAssert( aLayer != nil, @"can't add a nil layer");
	
	[self insertObject:aLayer inLayersAtIndex:0];
}


///*********************************************************************************************************************
///
/// method:			addLayer:aboveLayerIndex:
/// scope:			public method
/// overrides:
/// description:	adds a layer above a specific index position in the stack
/// 
/// parameters:		<aLayer> a DKLayer object, or subclass thereof
///					<layerIndex> the index number of the layer the new layer should be placed in front of.
/// result:			none
///
/// notes:			layer indexes run from 0 being the top layer to (count -1), being the bottom layer
///
///********************************************************************************************************************

- (void)				addLayer:(DKLayer*) aLayer aboveLayerIndex:(NSUInteger) layerIndex
{
	NSAssert( aLayer != nil, @"cannot add a nil layer");

	// adds a layer above the given index - if index is 0 or 1 puts the layer on top
	
	if ( layerIndex <= 1 )
		[self insertObject:aLayer inLayersAtIndex:0];
	else
		[self insertObject:aLayer inLayersAtIndex:layerIndex];
}


///*********************************************************************************************************************
///
/// method:			insertLayer:inLayersAtIndex:
/// scope:			public method
/// overrides:
/// description:	adds a layer at a specific index position in the stack
/// 
/// parameters:		<aLayer> a DKLayer object, or subclass thereof
///					<layerIndex> the index number of the layer inserted
/// result:			none
///
/// notes:			all other addLayer methods call this, which permits the operation to be undone including restoring
///					the layer's index. KVC/KVO compliant.
///					layer indexes run from 0 being the top layer to (count -1), being the bottom layer
///
///********************************************************************************************************************

- (void)				insertObject:(DKLayer*) aLayer inLayersAtIndex:(NSUInteger) layerIndex
{
	NSAssert( aLayer != nil, @"cannot insert a nil layer");
	
	// check that the layer being added isn't a DKDrawing instance - that is a bad thing to attempt.
	
	if([aLayer isKindOfClass:[DKDrawing class]])
		[NSException raise:NSInternalInconsistencyException format:@"Error - attempt to add a DKDrawing instance to a layer group"];

	if( ![self locked] && ![m_layers containsObject:aLayer])
	{
		[[[self undoManager] prepareWithInvocationTarget:self] removeObjectFromLayersAtIndex:layerIndex];
		
		[m_layers insertObject:aLayer atIndex:layerIndex];
		[aLayer setLayerGroup:self];
		[aLayer drawingDidChangeToSize:[NSValue valueWithSize:[[self drawing] drawingSize]]];
		[self setNeedsDisplay:YES];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerGroupDidAddLayer object:self];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerGroupNumberOfLayersDidChange object:self];
	}
}


///*********************************************************************************************************************
///
/// method:			removeLayer:
/// scope:			public method
/// overrides:
/// description:	removes the layer from the drawing
/// 
/// parameters:		<aLayer> a DKLayer object, or subclass thereof, that already exists in the group
/// result:			none
///
/// notes:			disposes of the layer if there are no other references to it.
///
///********************************************************************************************************************

- (void)				removeLayer:(DKLayer*) aLayer
{
	NSAssert( aLayer != nil, @"cannot remove a nil layer");
	
	[self removeObjectFromLayersAtIndex:[self indexOfLayer:aLayer]];
}


///*********************************************************************************************************************
///
/// method:			removeLayerFromLayersAtIndex:
/// scope:			public method
/// overrides:
/// description:	remove the layer with a particular index number from the layer
/// 
/// parameters:		<layerIndex> the index number of the layer to remove
/// result:			none
///
/// notes:			all other removeLayer methods call this, which permits the operation to be undone including restoring
///					the layer's index. KVC/KVO compliant.
///					layer indexes run from 0 being the top layer to (count -1), being the bottom layer
///
///********************************************************************************************************************

- (void)				removeObjectFromLayersAtIndex:(NSUInteger) layerIndex
{
	NSAssert( layerIndex < [self countOfLayers], @"layer index out of range in removeLayerFromLayersAtIndex:");

	if (![self locked])
	{
		DKLayer* aLayer = [self objectInLayersAtIndex:layerIndex];
		
		if( aLayer )
		{
			[[[self undoManager] prepareWithInvocationTarget:self] insertObject:aLayer inLayersAtIndex:layerIndex];
			[aLayer setLayerGroup:nil];
			[m_layers removeObjectAtIndex:layerIndex];
			[self setNeedsDisplay:YES];
			[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerGroupDidRemoveLayer object:self];
			[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerGroupNumberOfLayersDidChange object:self];
		}
	}
}


///*********************************************************************************************************************
///
/// method:			removeAllLayers
/// scope:			public method
/// overrides:
/// description:	removes all of the group's layers
/// 
/// parameters:		none
/// result:			none
///
/// notes:			this method is not undoable. To undoably remove a layer, remove them one at a time. KVO observers
///					will not be notified by this method.
///
///********************************************************************************************************************

- (void)				removeAllLayers
{
	if( ![self locked])
	{
		[[self undoManager] removeAllActionsWithTarget:self];
		
		[m_layers makeObjectsPerformSelector:@selector(setLayerGroup:) withObject:nil];
		[m_layers removeAllObjects];
		[self setNeedsDisplay:YES];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerGroupDidRemoveLayer object:self];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerGroupNumberOfLayersDidChange object:self];
	}
}


///*********************************************************************************************************************
///
/// method:			uniqueLayerNameForName:
/// scope:			public method
/// overrides:
/// description:	disambiguates a layer's name by appending digits until there is no conflict
/// 
/// parameters:		<aName> a string containing the proposed name
/// result:			a string, either the original string or a modified version of it
///
/// notes:			it is not important that layer's have unique names, but a UI will usually want to do this, thus
///					when using the addLayer:andActivateIt: method, the name of the added layer is disambiguated.
///
///********************************************************************************************************************

- (NSString*)			uniqueLayerNameForName:(NSString*) aName
{
	NSInteger	numeral = 0;
	BOOL		found = YES;
	NSString*	temp = aName;
	NSArray*	keys = [[self layers] valueForKey:@"layerName"];
	
	while( found )
	{
		NSInteger	k = [keys indexOfObject:temp];
		
		if ( k == NSNotFound )
			found = NO;
		else
			temp = [NSString stringWithFormat:@"%@ %ld", aName, (long)++numeral];
	}
	
	return temp;
}


#pragma mark -
#pragma mark - getting layers
///*********************************************************************************************************************
///
/// method:			layerInLayersAtIndex:
/// scope:			public method
/// overrides:
/// description:	returns the layer object at the given index
/// 
/// parameters:		<layerIndex> the index number of the layer of interest
/// result:			a DKLayer object or subclass
///
/// notes:			layer indexes run from 0 being the top layer to (count -1), being the bottom layer. KVC/KVO compliant.
///
///********************************************************************************************************************

- (DKLayer*)		objectInLayersAtIndex:(NSUInteger) layerIndex
{
	NSAssert1( layerIndex < [self countOfLayers], @"bad layer index %ld (overrange)", (long)layerIndex);
	
	return [[self layers] objectAtIndex:layerIndex];
}


///*********************************************************************************************************************
///
/// method:			topLayer
/// scope:			public method
/// overrides:
/// description:	returns the topmost layer
/// 
/// parameters:		none
/// result:			the topmost DKLayer object or subclass
///
/// notes:			
///
///********************************************************************************************************************

- (DKLayer*)		topLayer
{
	if([self countOfLayers] > 0)
		return [self objectInLayersAtIndex:0];
	else
		return nil;
}


///*********************************************************************************************************************
///
/// method:			bottomLayer
/// scope:			public method
/// overrides:
/// description:	returns the bottom layer
/// 
/// parameters:		none
/// result:			the bottom DKLayer object or subclass, or nil, if there are no layers
///
/// notes:			ignores opacity of layers in the stack - this is the one on the bottom, regardless
///
///********************************************************************************************************************

- (DKLayer*)		bottomLayer
{
	return [[self layers] lastObject];
}


///*********************************************************************************************************************
///
/// method:			indexOfLayer:
/// scope:			public method
/// overrides:
/// description:	returns the stack position of a given layer
/// 
/// parameters:		<aLayer> a DKLayer object, or subclass thereof, that already exists in the drawing
/// result:			the stack index position of the layer
///
/// notes:			layer indexes run from 0 being the top layer to (count -1), being the bottom layer. If the group does
///					not contain the layer, returns NSNotFound. See also -containsLayer:
///
///********************************************************************************************************************

- (NSUInteger)		indexOfLayer:(DKLayer*) aLayer
{
	return [[self layers] indexOfObjectIdenticalTo:aLayer];
}


///*********************************************************************************************************************
///
/// method:			firstLayerOfClass:
/// scope:			public method
/// overrides:
/// description:	returns the uppermost layer matching class, if any
/// 
/// parameters:		<cl> the class of layer to seek
/// result:			the uppermost layer of the given class, or nil
///
/// notes:			does not perform a deep search
///
///********************************************************************************************************************

- (DKLayer*)		firstLayerOfClass:(Class) cl
{
	return [self firstLayerOfClass:cl performDeepSearch:NO];
}


///*********************************************************************************************************************
///
/// method:			firstLayerOfClass:performDeepSearch:
/// scope:			public method
/// overrides:
/// description:	returns the uppermost layer matching class, if any
/// 
/// parameters:		<cl> the class of layer to seek
///					<deep> if YES, searches all subgroups below this one
/// result:			the uppermost layer of the given class, or nil
///
/// notes:			
///
///********************************************************************************************************************

- (DKLayer*)		firstLayerOfClass:(Class) cl performDeepSearch:(BOOL) deep
{
	NSArray* layers = [self layersOfClass:cl performDeepSearch:deep];
	
	if( layers && [layers count] > 0)
		return [layers objectAtIndex:0];
	else
		return nil;
}


///*********************************************************************************************************************
///
/// method:			layersOfClass:
/// scope:			public method
/// overrides:
/// description:	returns a list of layers of the given class
/// 
/// parameters:		<cl> the class of layer to seek
/// result:			a list of layers. May be empty.
///
/// notes:			does not perform a deep search
///
///********************************************************************************************************************


- (NSArray*)		layersOfClass:(Class) cl
{
	return [self layersOfClass:cl performDeepSearch:NO];
}


///*********************************************************************************************************************
///
/// method:			layersOfClass:performDeepSearch:
/// scope:			public method
/// overrides:
/// description:	returns a list of layers of the given class
/// 
/// parameters:		<cl> the class of layer to seek
///					<deep> if YES, will search all subgroups below this one. If NO, only this level is searched
/// result:			a list of layers. May be empty.
///
/// notes:			
///
///********************************************************************************************************************

- (NSArray*)		layersOfClass:(Class) cl performDeepSearch:(BOOL) deep

{
	NSEnumerator*	iter = [self layerTopToBottomEnumerator];
	DKLayer*		lyr;
	NSMutableArray*	layers = [NSMutableArray array];
	
	while(( lyr = [iter nextObject]))
	{
		if ([lyr isKindOfClass:cl])
			[layers addObject:lyr];
		
		if( deep && [lyr respondsToSelector:_cmd])
			[layers addObjectsFromArray:[(DKLayerGroup*)lyr layersOfClass:cl performDeepSearch:YES]];
	}
	
	return layers;
}


///*********************************************************************************************************************
///
/// method:			layerTopToBottomEnumerator
/// scope:			public method
/// overrides:
/// description:	returns an enumerator that can be used to iterate over the layers in top to bottom order
/// 
/// parameters:		none
/// result:			an NSEnumerator object
///
/// notes:			this is provided as a convenience so you don't have to worry about the implementation detail of
///					which way round layers are ordered to give the top to bottom visual stacking.
///
///********************************************************************************************************************

- (NSEnumerator*)		layerTopToBottomEnumerator
{
	return [[self layers] objectEnumerator];
}


///*********************************************************************************************************************
///
/// method:			layerBottomToTopEnumerator
/// scope:			public method
/// overrides:
/// description:	returns an enumerator that can be used to iterate over the layers in bottom to top order
/// 
/// parameters:		none
/// result:			an NSEnumerator object
///
/// notes:			this is provided as a convenience so you don't have to worry about the implementation detail of
///					which way round layers are ordered to give the top to bottom visual stacking.
///
///********************************************************************************************************************

- (NSEnumerator*)		layerBottomToTopEnumerator
{
	return [[self layers] reverseObjectEnumerator];
}



///*********************************************************************************************************************
///
/// method:			findLayerForPoint:
/// scope:			public method
/// overrides:
/// description:	find the topmost layer in this group that is 'hit' by the given point
/// 
/// parameters:		<p> a point in drawing coordinates
/// result:			a layer, or nil
///
/// notes:			A layer must implement hitLayer: sensibly for this to operate. This recurses down through any groups
///					contained within. See also -hitLayer:
///
///********************************************************************************************************************

- (DKLayer*)			findLayerForPoint:(NSPoint) p
{
	if([self visible])
	{
		NSEnumerator*	iter = [self layerTopToBottomEnumerator];
		DKLayer*		layer;
		
		while(( layer = [iter nextObject]))
		{
			if([layer isKindOfClass:[DKLayerGroup class]])
			{
				layer = [(DKLayerGroup*)layer findLayerForPoint:p];
				
				if( layer )
					return layer;
			}
			else if ([layer visible] && [layer hitLayer:p])
				return layer;
		}
	}
	return nil;
}


///*********************************************************************************************************************
///
/// method:			containsLayer:
/// scope:			public method
/// overrides:
/// description:	returns whether this group, or any subgroup within, contains the layer
/// 
/// parameters:		<alayer> a layer of interest
/// result:			YES if the group contains the layer.
///
/// notes:			Unlike -indexOfLayer:, considers nested subgroups.  If the layer is the group, returns NO
///					(doesn't contain itself).
///
///********************************************************************************************************************

- (BOOL)				containsLayer:(DKLayer*) aLayer
{
	if( aLayer == self )
		return NO;
	else
	{
		NSEnumerator*	iter = [self layerTopToBottomEnumerator];
		DKLayer*		layer;
		
		while(( layer = [iter nextObject]))
		{
			if( aLayer == layer )
				return YES;
			
			if([layer isKindOfClass:[DKLayerGroup class]])
			{
				if([(DKLayerGroup*)layer containsLayer:aLayer])
					return YES;
			}
		}
		
		return NO;
	}
}



///*********************************************************************************************************************
///
/// method:			layerWithUniqueKey:
/// scope:			public method
/// overrides:
/// description:	returns a layer or layer group having the given unique key
/// 
/// parameters:		<key> the layer's key
/// result:			the layer if found, nil otherwise.
///
/// notes:			unique keys are assigned to layers for the lifetime of the app. They are not persistent and must only
///					be used to find layers in the case where a layer pointer/address would be unreliable.
///
///********************************************************************************************************************

- (DKLayer*)				layerWithUniqueKey:(NSString*) key
{
	NSEnumerator*	iter = [[self layers] objectEnumerator];
	DKLayer*		layer;
	
	while(( layer = [iter nextObject]))
	{
		if([[layer uniqueKey] isEqualToString:key])
			return layer;
		else if([layer isKindOfClass:[self class]])
		{
			layer = [(DKLayerGroup*)layer layerWithUniqueKey:key];
			if( layer )
				return layer;
		}
	}
	
	return nil;
}


#pragma mark -

///*********************************************************************************************************************
///
/// method:			showAll:
/// scope:			public method
/// overrides:
/// description:	makes all layers in the group and in any subgroups visible
/// 
/// parameters:		none
/// result:			none
///
/// notes:			recurses when nested groups are found
///
///********************************************************************************************************************

- (void)					showAll
{
	NSEnumerator*	iter = [self layerTopToBottomEnumerator];
	DKLayer*		aLayer;
	
	while(( aLayer = [iter nextObject]))
	{
		[aLayer setVisible:YES];

		if([aLayer isKindOfClass:[DKLayerGroup class]])
			[(DKLayerGroup*)aLayer showAll];
	}
}


///*********************************************************************************************************************
///
/// method:			hideAllExcept:
/// scope:			public method
/// overrides:
/// description:	makes all layers in the group and in any subgroups hidden except <aLayer>, which is made visible.
/// 
/// parameters:		<aLayer> a layer to leave visible
/// result:			none
///
/// notes:			aLayer may be nil in which case this performs a hideAll. Recurses on any subgroups.
///
///********************************************************************************************************************

- (void)					hideAllExcept:(DKLayer*) aLayer
{
	NSEnumerator*	iter = [self layerTopToBottomEnumerator];
	DKLayer*		layer;
	
	while(( layer = [iter nextObject]))
	{
		if([layer isKindOfClass:[DKLayerGroup class]])
		{
			[(DKLayerGroup*)layer hideAllExcept:aLayer];
			
			// this logic keeps groups that contain the excepted layer visible if necessary
			
			if( layer == aLayer || [(DKLayerGroup*)layer containsLayer:aLayer])
				[layer setVisible:YES];
			else
				[layer setVisible:NO];
		}
		else
			[layer setVisible:layer == aLayer];
	}
}


///*********************************************************************************************************************
///
/// method:			hasHiddenLayers
/// scope:			public method
/// overrides:
/// description:	returns YES if the  receiver or any of its contained layers is hidden
/// 
/// parameters:		none
/// result:			YES if there are hidden layers below this, or this is hidden itself
///
/// notes:			Recurses on any subgroups.
///
///********************************************************************************************************************

- (BOOL)					hasHiddenLayers
{
	if( ![self visible])
		return YES;
	else
	{
		NSEnumerator*	iter = [self layerTopToBottomEnumerator];
		DKLayer*		layer;
		
		while(( layer = [iter nextObject]))
		{
			if( ![layer visible])
				return YES;

			if([layer isKindOfClass:[DKLayerGroup class]])
			{
				if([(DKLayerGroup*)layer hasHiddenLayers])
					return YES;
			}
		}
		
		return NO;
	}
}


///*********************************************************************************************************************
///
/// method:			hasVisibleLayersOtherThan:
/// scope:			public method
/// overrides:
/// description:	returns YES if the  receiver or any of its contained layers is visible, ignoring the one passed
/// 
/// parameters:		<aLayer> a layer to exclude when testing this
/// result:			YES if there are visible layers below this, or this is visible itself
///
/// notes:			Recurses on any subgroups. Typically <aLayer> is the active layer - may be nil.
///
///********************************************************************************************************************

- (BOOL)					hasVisibleLayersOtherThan:(DKLayer*) aLayer
{
	if(![self visible] && self != aLayer )
		return NO;
	
	NSEnumerator*	iter = [self layerTopToBottomEnumerator];
	DKLayer*		layer;
	
	while(( layer = [iter nextObject]))
	{
		if( layer != aLayer )
		{
			if([layer visible])
				return YES;
	
			if([layer isKindOfClass:[DKLayerGroup class]])
			{
				if([(DKLayerGroup*)layer hasVisibleLayersOtherThan:aLayer])
					return YES;
			}
		}
	}
	
	return NO;
}



#pragma mark -
#pragma mark - layer stacking order
///*********************************************************************************************************************
///
/// method:			moveUpLayer:
/// scope:			public method
/// overrides:
/// description:	moves the layer one place towards the top of the stack
/// 
/// parameters:		<aLayer> the layer to move up
/// result:			none
///
/// notes:			if already on top, does nothing
///
///********************************************************************************************************************

- (void)				moveUpLayer:(DKLayer*) aLayer
{
	NSAssert( aLayer != nil, @"cannot move a nil layer");
	
	[self moveLayer:aLayer toIndex:[self indexOfLayer:aLayer] - 1];
}


///*********************************************************************************************************************
///
/// method:			moveDownLayer:
/// scope:			public method
/// overrides:
/// description:	moves the layer one place towards the bottom of the stack
/// 
/// parameters:		<aLayer> the layer to move down
/// result:			none
///
/// notes:			if already at the bottom, does nothing
///
///********************************************************************************************************************

- (void)				moveDownLayer:(DKLayer*) aLayer
{
	NSAssert( aLayer != nil, @"cannot move a nil layer");

	[self moveLayer:aLayer toIndex:[self indexOfLayer:aLayer] + 1];
}


///*********************************************************************************************************************
///
/// method:			moveLayerToTop:
/// scope:			public method
/// overrides:
/// description:	moves the layer to the top of the stack
/// 
/// parameters:		<aLayer> the layer to move up
/// result:			none
///
/// notes:			if already on top, does nothing
///
///********************************************************************************************************************

- (void)				moveLayerToTop:(DKLayer*) aLayer
{
	NSAssert( aLayer != nil, @"cannot move a nil layer");

	[self moveLayer:aLayer toIndex:0];
}


///*********************************************************************************************************************
///
/// method:			moveLayerToBottom:
/// scope:			public method
/// overrides:
/// description:	moves the layer to the bottom of the stack
/// 
/// parameters:		<aLayer> the layer to move down
/// result:			none
///
/// notes:			if already at the bottom, does nothing
///
///********************************************************************************************************************

- (void)				moveLayerToBottom:(DKLayer*) aLayer
{
	NSAssert( aLayer != nil, @"cannot move a nil layer");

	[self moveLayer:aLayer toIndex:[self countOfLayers] - 1];
}


///*********************************************************************************************************************
///
/// method:			moveLayer:aboveLayer:
/// scope:			public method
/// overrides:
/// description:	changes a layer's z-stacking order so it comes before (above) <otherLayer>
/// 
/// parameters:		<aLayer> the layer to move - may not be nil
///					<otherLayer> move above this layer. May be nil, which moves the layer to the bottom
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				moveLayer:(DKLayer*) aLayer aboveLayer:(DKLayer*) otherLayer
{
	NSAssert( aLayer != nil, @"cannot move a nil layer");

	if ( otherLayer == nil )
		[self moveLayerToBottom:aLayer];
	else
		[self moveLayer:aLayer toIndex:[self indexOfLayer:otherLayer]];
}


///*********************************************************************************************************************
///
/// method:			moveLayer:belowLayer:
/// scope:			public class method
/// overrides:
/// description:	changes a layer's z-stacking order so it comes after (below) <otherLayer>
/// 
/// parameters:		<aLayer> the layer to move - may not be nil
///					<otherLayer> move below this layer. May be nil, which moves the layer to the top
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				moveLayer:(DKLayer*) aLayer belowLayer:(DKLayer*) otherLayer
{
	NSAssert( aLayer != nil, @"cannot move a nil layer");

	if ( otherLayer == nil )
		[self moveLayerToTop:aLayer];
	else
		[self moveLayer:aLayer toIndex:[self indexOfLayer:otherLayer] + 1];
}


///*********************************************************************************************************************
///
/// method:			moveLayer:toIndex:
/// scope:			public method
/// overrides:
/// description:	moves a layer to the index position given. This is called by all if the other moveLayer... methods
/// 
/// parameters:		<aLayer> the layer to move
///					<i> the index position to move it to.
/// result:			none
///
/// notes:			if the layer can't be moved, does nothing. The action is recorded for undo if there is an undoManager
///					attached.
///
///********************************************************************************************************************

- (void)				moveLayer:(DKLayer*) aLayer toIndex:(NSUInteger) i
{
	// all other layer stacking methods call this one, which implements undo and notification
	
	NSAssert( aLayer != nil, @"trying to move nil layer");
	NSAssert( ![aLayer locked], @"trying to move a locked layer");
	
	if( ![self locked])
	{
		NSUInteger k = [self indexOfLayer:aLayer];
		
		if( k == NSNotFound )
			return;
		
		i = MIN( i, [self countOfLayers] - 1 );
		
		if ( k != i )
		{
			[[[self undoManager] prepareWithInvocationTarget:self] moveLayer:aLayer toIndex:k];
			[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerGroupWillReorderLayers object:self];
			
			[aLayer retain];
			[m_layers removeObject:aLayer];
			[m_layers insertObject:aLayer atIndex:i];
			[aLayer release];

			[self setNeedsDisplay:YES];
			[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerGroupDidReorderLayers object:self];
		}
	}
}


#pragma mark -
#pragma mark As a DKLayer
///*********************************************************************************************************************
///
/// method:			drawingHasNewUndoManager:
/// scope:			public method
/// overrides:		DKLayer
/// description:	propagates the undo manager to all contained layers
/// 
/// parameters:		<um> the drawing's undo manager
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)					drawingHasNewUndoManager:(NSUndoManager*) um
{
	[[self layers] makeObjectsPerformSelector:@selector(drawingHasNewUndoManager:) withObject:um];
}


///*********************************************************************************************************************
///
/// method:			drawRect:inView:
/// scope:			public method
/// overrides:		DKLayer
/// description:	draws the layers it contains
/// 
/// parameters:		<rect> the update area passed from the original view
/// result:			none
///
/// notes:			layers are not drawn if they lie below the highest opaque layer, or if we are printing and the layer
///					isn't printable. Otherwise they are drawn from bottom upwards.
///
///********************************************************************************************************************

- (void)				drawRect:(NSRect) rect inView:(DKDrawingView*) aView
{
	if ([self countOfLayers] > 0 )
	{
		// if clipping to the interior, set up that clip now
		
		SAVE_GRAPHICS_CONTEXT			//[NSGraphicsContext saveGraphicsState];

		if ([self clipsDrawingToInterior])
			[NSBezierPath clipRect:[[self drawing] interior]];

		NSUInteger	bottom;
		NSInteger			n;
		BOOL		printing = ![NSGraphicsContext currentContextDrawingToScreen];
		DKLayer*	layer;
		
		bottom = [self indexOfHighestOpaqueLayer];
		
		for( n = bottom; n >= 0; --n )
		{
			layer = [self objectInLayersAtIndex:n];
			
			if ([layer visible] && !( printing && ![layer shouldDrawToPrinter]))
			{
				@try
				{
					[NSGraphicsContext saveGraphicsState];
				
					if ([layer clipsDrawingToInterior])
						[NSBezierPath clipRect:[[self drawing] interior]];
					
					[layer beginDrawing];
					[layer drawRect:rect inView:aView];
					[layer endDrawing];
				}
				@catch( id exc )
				{
					NSLog(@"exception while drawing layer %@ [%ld of %ld in group %@](%@ - ignored)", layer, (long)n, (long)[self countOfLayers], self, exc );
				}
				@finally
				{
					[NSGraphicsContext restoreGraphicsState];
				}
			}
		}
		RESTORE_GRAPHICS_CONTEXT	//[NSGraphicsContext restoreGraphicsState];
	}
}


///*********************************************************************************************************************
///
/// method:			layerMayBecomeActive
/// scope:			public class method
/// description:	returns whether the layer can become the active layer
/// 
/// parameters:		none
/// result:			YES if the layer can become active, NO to not become active
///
/// notes:			The default for groups is NO. Discrete layers should be activated, not groups.
///
///********************************************************************************************************************

- (BOOL)			layerMayBecomeActive
{
	return NO;
}


///*********************************************************************************************************************
///
/// method:			drawingDidChangeToSize:
/// scope:			public class method
/// description:	propagate the message to all contained layers
/// 
/// parameters:		<sizeVal> the new size
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)			drawingDidChangeToSize:(NSValue*) sizeVal
{
	[[self layers] makeObjectsPerformSelector:@selector(drawingDidChangeToSize:) withObject:sizeVal];
}

///*********************************************************************************************************************
///
/// method:			drawingDidChangeMargins:
/// scope:			public instance method
/// description:	propagate the message to all contained layers
/// 
/// parameters:		<oldInterior> the old interior rect of the drawing
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)			drawingDidChangeMargins:(NSValue*) oldInterior
{
	[[self layers] makeObjectsPerformSelector:@selector(drawingDidChangeMargins:) withObject:oldInterior];
}


///*********************************************************************************************************************
///
/// method:			hitLayer:
/// scope:			public instance method
/// description:	see if any enclosed layer is hit by the point
/// 
/// parameters:		<p> the point to test
/// result:			YES if any layer within this group was hit, otherwise NO
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)			hitLayer:(NSPoint) p
{
	NSEnumerator*	iter = [self layerTopToBottomEnumerator];
	DKLayer*		layer;
	
	while(( layer = [iter nextObject]))
	{
		if([layer hitLayer:p])
			return YES;
	}
	return NO;
}


///*********************************************************************************************************************
///
/// method:			wasAddedToDrawing:
/// scope:			public instance method
/// description:	notifies the layer that it or a group containing it was added to a drawing.
/// 
/// parameters:		<aDrawing> the drawing that added the layer
/// result:			none
///
/// notes:			propagates the message to all contained layers
///
///********************************************************************************************************************

- (void)			wasAddedToDrawing:(DKDrawing*) aDrawing
{
	[[self layers] makeObjectsPerformSelector:_cmd withObject:aDrawing];
}


///*********************************************************************************************************************
///
/// method:			level
/// scope:			public method
/// overrides:
/// description:	returns the hierarchical level of this group, i.e. how deeply nested it is
/// 
/// parameters:		none
/// result:			the group's level
///
/// notes:			the root group returns 0, next level is 1 and so on. 
///
///********************************************************************************************************************

- (NSUInteger)				level
{
	if([self layerGroup] == nil )
		return 0;
	else
		return [[self layerGroup] level] + 1;
}


#pragma mark -
#pragma mark - style utilities

///*********************************************************************************************************************
///
/// method:			allStyles
/// scope:			public method
/// overrides:
/// description:	return all of styles used by layers in this group
/// 
/// parameters:		none
/// result:			a set containing the union of sets returned by all similar methods of individual layers
///
/// notes:			
///
///********************************************************************************************************************

- (NSSet*)			allStyles
{
	// returns the union of all sublayers that return something for this method
	
	NSEnumerator*	iter = [self layerTopToBottomEnumerator];
	DKLayer*		layer;
	NSSet*			styles;
	NSMutableSet*	unionOfAllStyles = nil;
	
	while(( layer = [iter nextObject]))
	{
		styles = [layer allStyles];
		
		if ( styles != nil )
		{
			// we got one - make a set to union them with if necessary
			
			if ( unionOfAllStyles == nil )
				unionOfAllStyles = [styles mutableCopy];
			else
				[unionOfAllStyles unionSet:styles];
		}
	}
	
	return [unionOfAllStyles autorelease];
}


///*********************************************************************************************************************
///
/// method:			allRegisteredStyles
/// scope:			public method
/// overrides:
/// description:	return all of registered styles used by the layers in this group
/// 
/// parameters:		none
/// result:			a set containing the union of sets returned by all similar methods of individual layers
///
/// notes:			
///
///********************************************************************************************************************

- (NSSet*)			allRegisteredStyles
{
	// returns the union of all sublayers that return something for this method
	
	NSEnumerator*	iter = [self layerTopToBottomEnumerator];
	DKLayer*		layer;
	NSSet*			styles;
	NSMutableSet*	unionOfAllStyles = nil;
	
	while(( layer = [iter nextObject]))
	{
		styles = [layer allRegisteredStyles];
		
		if ( styles != nil )
		{
			// we got one - make a set to union them with if necessary
			
			if ( unionOfAllStyles == nil )
				unionOfAllStyles = [styles mutableCopy];
			else
				[unionOfAllStyles unionSet:styles];
		}
	}
	
	return [unionOfAllStyles autorelease];
}


///*********************************************************************************************************************
///
/// method:			replaceMatchingStylesFromSet:
/// scope:			public method
/// overrides:
/// description:	substitute styles with those in the given set
/// 
/// parameters:		<aSet> a set of style objects
/// result:			none
///
/// notes:			This is an important step in reconciling the styles loaded from a file with the existing
///					registry. Implemented by DKObjectOwnerLayer, etc. Groups propagate the change to all sublayers.
///
///********************************************************************************************************************

- (void)			replaceMatchingStylesFromSet:(NSSet*) aSet
{
	[[self layers] makeObjectsPerformSelector:@selector(replaceMatchingStylesFromSet:) withObject:aSet];
}



#pragma mark -
#pragma mark As an NSObject
- (void)					dealloc
{
	// set group ref to nil in case someone else is retaining any layer
	
	[m_layers makeObjectsPerformSelector:@selector(setLayerGroup:) withObject:nil];
	[m_layers release];
	[super dealloc];
}


- (id)						init
{
	return [self initWithLayers:nil];
}


#pragma mark -
#pragma mark As part NSCoding Protocol
- (void)					encodeWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];
	
	// store a flag to say that we now store layers the other way up - this triggers older files that lack this
	// to have their layer order reversed when loaded
	
	[coder encodeBool:YES forKey:@"DKLayerGroup_invertedStack"];
	[coder encodeObject:[self layers] forKey:@"DKLayerGroup_layers"];
}


- (id)						initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	LogEvent_(kFileEvent, @"decoding layer group %@", self);
	
	self = [super initWithCoder:coder];
	if (self != nil)
	{
		// prior to beta 3, layers were stored in the inverse order, so those files need to have their layers stacked
		//  the other way up so they come up true in the current model.
		
		BOOL hasInvertedLayerStack = [coder decodeBoolForKey:@"DKLayerGroup_invertedStack"];
		
		if( !hasInvertedLayerStack )
		{
			NSArray*		layerStack = [coder decodeObjectForKey:@"layers"];
			
			if([layerStack count] > 1)
			{
				NSMutableArray* temp = [NSMutableArray array];
				NSEnumerator*	iter = [layerStack objectEnumerator];
				DKLayer*		layer;
				
				while(( layer = [iter nextObject]))
					[temp insertObject:layer atIndex:0];
					
				[self setLayers:temp];
			}
			else
				[self setLayers:layerStack];
		}
		else
		{
			NSArray*	layers = [coder decodeObjectForKey:@"DKLayerGroup_layers"];
			
			if( layers == nil )
				layers = [coder decodeObjectForKey:@"layers"];
			
			LogEvent_(kFileEvent, @"decoding layers in group: %@", layers);
			[self setLayers:layers];
		}
		
		
		if (m_layers == nil)
		{
			[self autorelease];
			self = nil;
		}
	}
	return self;
}


@end
