///**********************************************************************************************************************************
///  DKLayerGroup.m
///  DrawKit
///
///  Created by graham on 23/08/2007.
///  Released under the Creative Commons license 2007 Apptree.net.
///
/// 
///  This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 License.
///  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to
///  Creative Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105, USA.
///
///**********************************************************************************************************************************

#import "DKLayerGroup.h"

#import "DKDrawKitMacros.h"
#import "LogEvent.h"


#pragma mark Constants (Non-localized)
NSString*		kDKLayerGroupDidAddLayer			= @"kDKLayerGroupDidAddLayer";
NSString*		kDKLayerGroupDidRemoveLayer			= @"kDKLayerGroupDidRemoveLayer";
NSString*		kDKLayerGroupWillReorderLayers		= @"kDKLayerGroupWillReorderLayers";
NSString*		kDKLayerGroupDidReorderLayers		= @"kDKLayerGroupDidReorderLayers";


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
		m_layers = [[NSMutableArray alloc] init];
		
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
///					be set all at once, as when unarchiving.
///
///********************************************************************************************************************

- (void)				setLayers:(NSArray*) layers
{
	NSAssert( layers != nil, @"attempt to set layer groups layers to nil");
	
	if( layers != [self layers])
	{
		[m_layers release];
		m_layers = [layers mutableCopy];
		
		// this is to ensure the group member is inited - older files didn't save the group ref so it will be nil
		// newer files do, but doing this anyway has no harmful effect
		
		[m_layers makeObjectsPerformSelector:@selector(setLayerGroup:) withObject:self];
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

- (unsigned)			countOfLayers
{
	return[[self layers] count];
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

- (unsigned)			indexOfHighestOpaqueLayer
{
	// returns the index of the topmost layer that returns YES for isOpaque.

	unsigned i = 0;
	
	do
	{
		if ([[self layerAtIndex:i] isOpaque])
			return i;
	}
	while( ++i < [self countOfLayers]);
	
	return [self countOfLayers] - 1;	// the bottom layer is the last
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
	[self insertLayer:aLayer atIndex:0];
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

- (void)				addLayer:(DKLayer*) aLayer aboveLayerIndex:(unsigned) layerIndex
{
	NSAssert( aLayer != nil, @"cannot add a nil layer");

	// adds a layer above the given index - if index is 0 or 1 puts the layer on top
	
	if ( layerIndex <= 1 )
		[self insertLayer:aLayer atIndex:0];
	else
		[self insertLayer:aLayer atIndex:layerIndex - 1];
}


///*********************************************************************************************************************
///
/// method:			insertLayer:atIndex:
/// scope:			public method
/// overrides:
/// description:	adds a layer at a specific index position in the stack
/// 
/// parameters:		<aLayer> a DKLayer object, or subclass thereof
///					<layerIndex> the index number of the layer inserted
/// result:			none
///
/// notes:			all other addLayer methods call this, which permits the operation to be undone including restoring
///					the layer's index.
///					layer indexes run from 0 being the top layer to (count -1), being the bottom layer
///
///********************************************************************************************************************

- (void)				insertLayer:(DKLayer*) aLayer atIndex:(unsigned) layerIndex
{
	NSAssert( aLayer != nil, @"cannot insert a nil layer");
	
	if( ![self locked] && ![m_layers containsObject:aLayer])
	{
		[[[self undoManager] prepareWithInvocationTarget:self] removeLayerAtIndex:layerIndex];

		[m_layers insertObject:aLayer atIndex:layerIndex];
		[aLayer setLayerGroup:self];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerGroupDidAddLayer object:self];
		[self setNeedsDisplay:YES];
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
	
	[self removeLayerAtIndex:[self indexOfLayer:aLayer]];
}


///*********************************************************************************************************************
///
/// method:			removeLayerAtIndex:
/// scope:			public method
/// overrides:
/// description:	remove the layer with a particular index number from the layer
/// 
/// parameters:		<layerIndex> the index number of the layer to remove
/// result:			none
///
/// notes:			all other removeLayer methods call this, which permits the operation to be undone including restoring
///					the layer's index.
///					layer indexes run from 0 being the top layer to (count -1), being the bottom layer
///
///********************************************************************************************************************

- (void)				removeLayerAtIndex:(unsigned) layerIndex
{
	NSAssert( layerIndex < [self countOfLayers], @"layer index out of range in removeLayerAtIndex:");

	if (![self locked])
	{
		DKLayer* aLayer = [self layerAtIndex:layerIndex];
		
		[[[self undoManager] prepareWithInvocationTarget:self] insertLayer:aLayer atIndex:layerIndex];
		[aLayer setLayerGroup:nil];
		[m_layers removeObjectAtIndex:layerIndex];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerGroupDidRemoveLayer object:self];
		[self setNeedsDisplay:YES];
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
/// notes:			this method is not undoable. To undoably remove a layer, remove them one at a time.
///
///********************************************************************************************************************

- (void)				removeAllLayers
{
	if( ![self locked])
	{
		[[self undoManager] removeAllActionsWithTarget:self];
		[m_layers removeAllObjects];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerGroupDidRemoveLayer object:self];
		[self setNeedsDisplay:YES];
	}
}


#pragma mark -
#pragma mark - getting layers
///*********************************************************************************************************************
///
/// method:			layerAtIndex:
/// scope:			public method
/// overrides:
/// description:	returns the layer object at the given index
/// 
/// parameters:		<layerIndex> the index number of the layer of interest
/// result:			a DKLayer object or subclass
///
/// notes:			layer indexes run from 0 being the top layer to (count -1), being the bottom layer
///
///********************************************************************************************************************

- (DKLayer*)		layerAtIndex:(unsigned) layerIndex
{
	NSAssert1( layerIndex < [self countOfLayers], @"bad layer index %d (overrange)", layerIndex);
	
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
		return [self layerAtIndex:0];
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
/// notes:			layer indexes run from 0 being the top layer to (count -1), being the bottom layer
///
///********************************************************************************************************************

- (unsigned)		indexOfLayer:(DKLayer*) aLayer
{
	return [[self layers] indexOfObject:aLayer];
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
/// notes:			
///
///********************************************************************************************************************

- (DKLayer*)		firstLayerOfClass:(Class) cl
{
	NSEnumerator*	iter = [self layerTopToBottomEnumerator];
	DKLayer*		lyr;
	
	while(( lyr = [iter nextObject]))
	{
		if ([lyr isKindOfClass:cl])
			return lyr;
	}
	
	return nil;
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
/// description:	moves a layer to the index position given. This is caled by all if the other moveLayer... methods
/// 
/// parameters:		<aLayer> the layer to move
///					<i> the index position to move it to.
/// result:			none
///
/// notes:			if the layer can't be moved, does nothing. The action is recorded for undo if there is an undoManager
///					attached.
///
///********************************************************************************************************************

- (void)				moveLayer:(DKLayer*) aLayer toIndex:(unsigned) i
{
	// all other layer stacking methods call this one, which implements undo and notification
	
	NSAssert( aLayer != nil, @"trying to move nil layer");
	NSAssert( ![aLayer locked], @"trying to move a locked layer");
	
	if( ![self locked])
	{
		unsigned k = [self indexOfLayer:aLayer];
		
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
		unsigned	bottom;
		int			n;
		BOOL		printing = ![NSGraphicsContext currentContextDrawingToScreen];
		DKLayer*	layer;
		
		bottom = [self indexOfHighestOpaqueLayer];
		
		for( n = bottom; n >= 0; --n )
		{
			layer = [self layerAtIndex:n];
			
			if ([layer visible] && !( printing && ![layer shouldDrawToPrinter]))
				[layer drawRect:rect inView:aView];
		}
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
	[coder encodeObject:[self layers] forKey:@"layers"];
}


- (id)						initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
//	LogEvent_(kFileEvent, @"decoding layer group %@", self);
	
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
			[self setLayers:[coder decodeObjectForKey:@"layers"]];
		
		if (m_layers == nil)
		{
			[self autorelease];
			self = nil;
		}
	}
	return self;
}


@end
