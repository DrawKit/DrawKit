///**********************************************************************************************************************************
///  DKObjectOwnerLayer.m
///  DrawKit
///
///  Created by graham on 21/11/2006.
///  Released under the Creative Commons license 2006 Apptree.net.
///
/// 
///  This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 License.
///  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to
///  Creative Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105, USA.
///
///**********************************************************************************************************************************

#import "DKObjectOwnerLayer.h"
#import "DKDrawing.h"
#import "DKStyle.h"
#import "DKDrawingView.h"
#import "DKDrawKitMacros.h"
#import "DKGeometryUtilities.h"
#import "DKGridLayer.h"
#import "DKImageShape.h"
#import "DKTextShape.h"
#import "DKSelectionPDFView.h"
#import "LogEvent.h"



@interface DKObjectOwnerLayer (Private)
- (void)	updateCache;
- (void)	invalidateCache;
@end

@implementation DKObjectOwnerLayer
#pragma mark As a DKObjectOwnerLayer

///*********************************************************************************************************************
///
/// method:			layer
/// scope:			public instance method
///	overrides:
/// description:	returns the layer of a drawable's container - since this is that layer, returns self
/// 
/// parameters:		none
/// result:			self
///
/// notes:			see DKDrawableObject which also implements this protocol
///
///********************************************************************************************************************

- (DKObjectOwnerLayer*)	layer
{
	return self;
}


#pragma mark - the list of objects

///*********************************************************************************************************************
///
/// method:			setObjects:
/// scope:			public instance method
///	overrides:
/// description:	sets the objects that this layer owns
/// 
/// parameters:		<objs> an array of DKDrawableObjects, or subclasses thereof
/// result:			none
///
/// notes:			used by undo and dearchivers
///
///********************************************************************************************************************

- (void)				setObjects:(NSArray*) objs
{
	NSAssert( objs != nil, @"array of objects cannot be nil");
	
	if ( objs != [self objects])
	{
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setObjects:) object:m_objects];
		[self refreshAllObjects];
		
		NSMutableArray*		temp = [objs mutableCopy];
		[m_objects release];
		m_objects = temp;
		
		[[self objects] makeObjectsPerformSelector:@selector(setContainer:) withObject:self];
		[self refreshAllObjects];
	}
}


///*********************************************************************************************************************
///
/// method:			objects
/// scope:			public instance method
///	overrides:
/// description:	returns all owned objects
/// 
/// parameters:		none
/// result:			an array of the objects
///
/// notes:			all objects are returned whether or not visible, locked or selected
///
///********************************************************************************************************************

- (NSArray*)			objects
{
	return m_objects;
}


///*********************************************************************************************************************
///
/// method:			availableObjects
/// scope:			public instance method
///	overrides:
/// description:	returns objects that are available to the user, that is, not locked or invisible
/// 
/// parameters:		none
/// result:			an array of available objects
///
/// notes:			If the layer itself is locked, returns the empty list
///
///********************************************************************************************************************

- (NSArray*)			availableObjects
{
	// an available object is one that is both visible and not locked. Stacking order is maintained.
	
	NSMutableArray*		ao = [[NSMutableArray alloc] init];
	
	if( ![self lockedOrHidden])
	{
		NSEnumerator*		iter = [self objectBottomToTopEnumerator];
		DKDrawableObject*	od;
		
		while(( od = [iter nextObject]))
		{
			if ([od visible] && ![od locked])
				[ao addObject:od];
		}
	}
	return [ao autorelease];
}


///*********************************************************************************************************************
///
/// method:			visibleObjects
/// scope:			public instance method
///	overrides:
/// description:	returns objects that are visible to the user, but may be locked
/// 
/// parameters:		none
/// result:			an array of visible objects
///
/// notes:			If the layer itself is not visible, returns nil
///
///********************************************************************************************************************

- (NSArray*)			visibleObjects
{
	NSMutableArray* vo = nil;
	
	if([self visible])
	{
		vo = [[NSMutableArray alloc] init];
	
		NSEnumerator*		iter = [self objectBottomToTopEnumerator];
		DKDrawableObject*	od;
		
		while(( od = [iter nextObject]))
		{
			if ([od visible])
				[vo addObject:od];
		}
	}
	
	return [vo autorelease];
}


///*********************************************************************************************************************
///
/// method:			objectsWithStyle:
/// scope:			public instance method
///	overrides:
/// description:	returns objects that share the given style
/// 
/// parameters:		<style> the style to compare
/// result:			an array of those objects that have the style
///
/// notes:			the style is compared by unique key, so style clones are not considered a match. Unavailable objects are
///					also included.
///
///********************************************************************************************************************

- (NSArray*)			objectsWithStyle:(DKStyle*) style
{
	NSMutableArray*		ao = [[NSMutableArray alloc] init];
	NSEnumerator*		iter = [self objectBottomToTopEnumerator];
	DKDrawableObject*	od;
	NSString*			key = [style uniqueKey];
	
	while(( od = [iter nextObject]))
	{
		if ([[[od style] uniqueKey] isEqualToString:key])
			[ao addObject:od];
	}
	
	return [ao autorelease];
}


///*********************************************************************************************************************
///
/// method:			objectsReturning:toSelector:
/// scope:			public instance method
///	overrides:
/// description:	returns objects that respond to the selector with the value <answer>
/// 
/// parameters:		<answer> a value that should match the response of the selector (can also be YES/NO)
///					<selector> a selector taking no parameters
/// result:			an array, objects that match the value of <answer>
///
/// notes:			this is a very simple type of predicate test. Note - the method <selector> must not return
///					anything larger than an int or it will be ignored and the result may be wrong.
///
///********************************************************************************************************************

- (NSArray*)			objectsReturning:(int) answer toSelector:(SEL) selector
{
	NSEnumerator*	iter = [[self objects] objectEnumerator];
	NSMutableArray*	result = [NSMutableArray array];
	id				o;
	int				rval;
	
	while(( o = [iter nextObject]))
	{
		if ([o respondsToSelector:selector])
		{
			rval = 0;
			
			NSInvocation* inv = [NSInvocation invocationWithMethodSignature:[o methodSignatureForSelector:selector]];
			
			[inv setSelector:selector];
			[inv invokeWithTarget:o];
		
			if([[inv methodSignature] methodReturnLength] <= sizeof( int ))
				[inv getReturnValue:&rval];

			if ( rval == answer )
				[result addObject:o];
		}
	}
	
	return result;
}




#pragma mark -
#pragma mark - getting objects
///*********************************************************************************************************************
///
/// method:			countObjects
/// scope:			public instance method
///	overrides:
/// description:	returns the number of objects in the layer
/// 
/// parameters:		none
/// result:			the count of all objects
///
/// notes:			
///
///********************************************************************************************************************

- (int)					countOfObjects
{
	return [[self objects] count];
}


///*********************************************************************************************************************
///
/// method:			objectAtIndex:
/// scope:			public instance method
///	overrides:
/// description:	returns the object at a given stacking position index
/// 
/// parameters:		<index> the stacking position
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (DKDrawableObject*)	objectAtIndex:(int) indx
{
	return [[self objects] objectAtIndex:indx];
}


///*********************************************************************************************************************
///
/// method:			topObject
/// scope:			public class method
///	overrides:
/// description:	returns the topmost object
/// 
/// parameters:		none
/// result:			the topmost object
///
/// notes:			
///
///********************************************************************************************************************

- (DKDrawableObject*)	topObject
{
	return [[self objects] lastObject];
}


///*********************************************************************************************************************
///
/// method:			bottomObject
/// scope:			public instance method
///	overrides:
/// description:	returns the bottom object
/// 
/// parameters:		none
/// result:			the bottom object
///
/// notes:			
///
///********************************************************************************************************************

- (DKDrawableObject*)	bottomObject
{
	return [[self objects] objectAtIndex:0];
}


///*********************************************************************************************************************
///
/// method:			indexOfObject:
/// scope:			public instance method
///	overrides:
/// description:	returns the stacking position of the given object
/// 
/// parameters:		<obj> the object
/// result:			the object's stacking order index
///
/// notes:			
///
///********************************************************************************************************************

- (int)					indexOfObject:(DKDrawableObject*) obj
{
	return [[self objects] indexOfObject:obj];
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			objectsAtIndexesInSet:
/// scope:			public instance method
///	overrides:
/// description:	returns a list of objects given by the index set
/// 
/// parameters:		<set> an index set
/// result:			a list of objects
///
/// notes:			
///
///********************************************************************************************************************

- (NSArray*)			objectsAtIndexesInSet:(NSIndexSet*) set
{
	NSMutableArray*		oa = [[NSMutableArray alloc] init];
	DKDrawableObject*	o;
	unsigned			indx = [set firstIndex];
	
	while( indx != NSNotFound )
	{
		o = [m_objects objectAtIndex:indx];
		[oa addObject:o];
		
		indx = [set indexGreaterThanIndex:indx];
	}
	
	return [oa autorelease];
}


///*********************************************************************************************************************
///
/// method:			indexSetForObjectsInArray:
/// scope:			public instance method
///	overrides:
/// description:	given a list of objects that are part of this layer, return an index set for them
/// 
/// parameters:		<objs> a list of objects
/// result:			an index set listing the array index positions for the objects passed
///
/// notes:			
///
///********************************************************************************************************************

- (NSIndexSet*)			indexSetForObjectsInArray:(NSArray*) objs;
{
	NSMutableIndexSet*	mset = [[NSMutableIndexSet alloc] init];
	DKDrawableObject*	o;
	NSEnumerator*		iter = [objs objectEnumerator];
	unsigned			indx;
	
	while(( o = [iter nextObject]))
	{
		indx = [m_objects indexOfObject:o];
		
		if ( indx != NSNotFound )
			[mset addIndex:indx];
	}
	
	return [mset autorelease];
}


#pragma mark -
#pragma mark - adding and removing objects
///*********************************************************************************************************************
///
/// method:			addObject:
/// scope:			public instance method
///	overrides:
/// description:	adds an object to the layer
/// 
/// parameters:		<obj> the object to add
/// result:			none
///
/// notes:			if layer locked, does nothing
///
///********************************************************************************************************************

- (void)				addObject:(DKDrawableObject*) obj
{
	NSAssert( obj != nil, @"attempt to add a nil object to the layer" );
	
	if(![m_objects containsObject:obj] && ![self lockedOrHidden])
	{
		[[self undoManager] registerUndoWithTarget:self selector:@selector(removeObject:) object:obj];
		[m_objects addObject:obj];
		[obj setContainer:self];
		[obj notifyVisualChange];
	}
}


///*********************************************************************************************************************
///
/// method:			addObject:atIndex:
/// scope:			public instance method
///	overrides:
/// description:	adds an object to the layer at a specific stacking index position
/// 
/// parameters:		<obj> the object to add
///					<index> the stacking order position index (0 = bottom, grows upwards)
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				addObject:(DKDrawableObject*) obj atIndex:(int) indx
{
	NSAssert( obj != nil, @"attempt to add a nil object to the layer" );

	if ( indx >= ( [self countOfObjects] - 1 ))
		[self addObject:obj];
	else if (![m_objects containsObject:obj] && ![self lockedOrHidden])
	{
		[[self undoManager] registerUndoWithTarget:self selector:@selector(removeObject:) object:obj];
		[m_objects insertObject:obj atIndex:indx];
		[obj setContainer:self];
		[obj notifyVisualChange];
	}
}


///*********************************************************************************************************************
///
/// method:			addObjects:
/// scope:			public instance method
///	overrides:
/// description:	adds a set of objects to the layer
/// 
/// parameters:		<objs> an array of DKDrawableObjects, or subclasses.
/// result:			none
///
/// notes:			take care that no objects are already owned by the layer - this doesn't check.
///
///********************************************************************************************************************

- (void)				addObjects:(NSArray*) objs
{
	NSAssert( objs != nil, @"attempt to add a nil array of objects to the layer" );

	if (![self lockedOrHidden])
	{
		[[self undoManager] registerUndoWithTarget:self selector:@selector(removeObjects:) object:objs];
		[m_objects addObjectsFromArray:objs];

		NSEnumerator* iter = [objs objectEnumerator];
		DKDrawableObject* o;
		
		while(( o = [iter nextObject]))
		{
			[o setContainer:self];
			[o notifyVisualChange];
		}
	}
}


///*********************************************************************************************************************
///
/// method:			addObjects:offsetByX:byY:
/// scope:			public instance method
///	overrides:
/// description:	adds a set of objects to the layer offsetting their location by the given delta values.
/// 
/// parameters:		<objs> a list of DKDrawableObjects to add
///					<dx> add this much to the x coordinate of each object
///					<dy> add this much to the y coordinate of each object
/// result:			none
///
/// notes:			used for paste and other similar ops. This attempts to keep the objects within the interior bounds
///					of the drawing, so the position may vary from location + delta.
///
///********************************************************************************************************************

- (void)				addObjects:(NSArray*) objs offsetByX:(float) dx byY:(float) dy
{
	if (![self lockedOrHidden])
	{
		NSEnumerator*		iter = [objs objectEnumerator];
		DKDrawableObject*	o;
		NSPoint				proposedLocation;
		NSRect				di = [[self drawing] interior];
		float				j = -1.0;
		int					attempts = 0;
		BOOL				hadFirst = NO;
		
		while(( o = [iter nextObject]))
		{
			// check whether the proposed offset would place the object ouside the drawing - if so
			// take steps to keep it within bounds.
			
			do 
			{
				proposedLocation = [o location];
				
				if ( m_recordPasteOffset && !hadFirst )
					m_pasteAnchor = proposedLocation;
				
				proposedLocation.x += dx;
				proposedLocation.y += dy;
				
				if (  ! NSPointInRect( proposedLocation, di ))
				{
					// proposed location falls outside the drawing interior, so modify the offset
					// until it fits OK. Each try reverses the direction of the errant offset and doubles its distance.
					
					if ( proposedLocation.x > NSMaxX( di ) || proposedLocation.x < NSMinX( di ))
						dx = j * dx;
					
					if ( proposedLocation.y > NSMaxY( di ) || proposedLocation.y < NSMinY( di ))
						dy = j * dy;
						
					[self setPasteOffsetX:dx y:dy];
					
					j -= 1.0;
					++attempts;
				}
				else
					break;
			}
			while( attempts < 4 );
			
			[o moveByX:dx byY:dy];
			[self addObject:o];
		}
	}
}


///*********************************************************************************************************************
///
/// method:			addObjects:atIndexesInSet:
/// scope:			public instance method
///	overrides:
/// description:	inserts a set of objects at the indexes given. The array and set order should match, and
///					have equal counts.
/// 
/// parameters:		<objs> the objects to insert
///					<set> the indexes where they should be inserted
/// result:			none
///
/// notes:			this undoably adds objects at particular positions
///
///********************************************************************************************************************

- (void)				addObjects:(NSArray*) objs atIndexesInSet:(NSIndexSet*) set
{
	if ( ![self lockedOrHidden])
	{
		if ([objs count] == [set count])
		{
			[[[self undoManager] prepareWithInvocationTarget:self] removeObjectsAtIndexesInSet:set];
			
			DKDrawableObject*	o;
			unsigned			indx = [set firstIndex];
			int					n = 0;
			
			while( indx != NSNotFound )
			{
				o = [objs objectAtIndex:n++];
				
				if (indx >= [m_objects count])
					[m_objects addObject:o];
				else
					[m_objects insertObject:o atIndex:indx];
				
				[o setContainer:self];
				[o notifyVisualChange];
				
				indx = [set indexGreaterThanIndex:indx];
			}
		}
	}
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			removeObject:
/// scope:			public instance method
///	overrides:
/// description:	removes the object from the layer
/// 
/// parameters:		<obj> the object to remove
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				removeObject:(DKDrawableObject*) obj
{
	if ([m_objects containsObject:obj] && ![self lockedOrHidden])
		[self removeObjectsAtIndexesInSet:[NSIndexSet indexSetWithIndex:[m_objects indexOfObject:obj]]];
}


///*********************************************************************************************************************
///
/// method:			removeObjectAtIndex:
/// scope:			public instance method
///	overrides:
/// description:	removes the object at the given stacking position index
/// 
/// parameters:		<index> the stacking index value
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				removeObjectAtIndex:(int) indx
{
	[self removeObjectsAtIndexesInSet:[NSIndexSet indexSetWithIndex:indx]];
}


///*********************************************************************************************************************
///
/// method:			removeObjects:
/// scope:			public instance method
///	overrides:
/// description:	removes a set of objects from the layer
/// 
/// parameters:		<objs>
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				removeObjects:(NSArray*) objs
{
	[self removeObjectsAtIndexesInSet:[self indexSetForObjectsInArray:objs]];
}


///*********************************************************************************************************************
///
/// method:			removeObjectsAtIndexesInSet:
/// scope:			public instance method
///	overrides:
/// description:	removes objects from the indexes listed by the set
/// 
/// parameters:		<set> an index set
/// result:			none
///
/// notes:			this allows objects to be removed undoably from distinct positions in the list
///
///********************************************************************************************************************

- (void)				removeObjectsAtIndexesInSet:(NSIndexSet*) set
{
	if ( ![self lockedOrHidden])
	{
		// sanity check that the count of indexes is less than the list length
		
		if ([set count] <= [m_objects count])
		{
			NSArray* rmObs = [self objectsAtIndexesInSet:set];
			
			[[[self undoManager] prepareWithInvocationTarget:self] addObjects:rmObs atIndexesInSet:set];
			
			[rmObs makeObjectsPerformSelector:@selector(notifyVisualChange)];
			[m_objects removeObjectsInArray:rmObs];
		}
	}
}


///*********************************************************************************************************************
///
/// method:			removeAllObjects
/// scope:			public instance method
///	overrides:
/// description:	removes all objects from the layer
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				removeAllObjects
{
	if ( ![self lockedOrHidden])
	{
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setObjects:) object:m_objects];
		[self refreshAllObjects];
		[m_objects removeAllObjects];
	}
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			objectTopToBottomEnumerator
/// scope:			public instance method
///	overrides:
/// description:	return an iterator that will enumerate the object in top to bottom order
/// 
/// parameters:		none
/// result:			an iterator
///
/// notes:			the idea is to insulate you from the implementation detail of how stacking order relates to the
///					list order of objects internally.
///
///********************************************************************************************************************

- (NSEnumerator*)		objectTopToBottomEnumerator
{
	return [[self objects] reverseObjectEnumerator];
}


///*********************************************************************************************************************
///
/// method:			objectBottomToTopEnumerator
/// scope:			public instance method
///	overrides:
/// description:	return an iterator that will enumerate the object in bottom to top order
/// 
/// parameters:		none
/// result:			an iterator
///
/// notes:			the idea is to insulate you from the implementation detail of how stacking order relates to the
///					list order of objects internally.
///
///********************************************************************************************************************

- (NSEnumerator*)		objectBottomToTopEnumerator
{
	return [[self objects] objectEnumerator];
}


#pragma mark -
#pragma mark - updating and drawing
///*********************************************************************************************************************
///
/// method:			drawable:needsDisplayInRect:
/// scope:			public instance method
/// description:	flags part of a layer as needing redrawing
/// 
/// parameters:		<obj> the drawable object requesting the update
///					<rect> the area that needs to be redrawn
/// result:			none
///
/// notes:			allows the object requesting the update to be identified - by default this just invalidates <rect>
///
///********************************************************************************************************************

- (void)			drawable:(DKDrawableObject*) obj needsDisplayInRect:(NSRect) rect
{
	#pragma unused(obj)
	
	[self setNeedsDisplayInRect:rect];
}



///*********************************************************************************************************************
///
/// method:			drawVisibleObjects:
/// scope:			public instance method
/// description:	draws all of the visible objects
/// 
/// parameters:		none
/// result:			none
///
/// notes:			this is used when drawing the layer into special contexts, not for view rendering
///
///********************************************************************************************************************

- (void)			drawVisibleObjects
{
	NSEnumerator*		iter = [[self visibleObjects] objectEnumerator];
	DKDrawableObject*	od;
	
	while(( od = [iter nextObject]))
		[od drawContentWithSelectedState:NO];
}



///*********************************************************************************************************************
///
/// method:			imageOfObjects:
/// scope:			public instance method
/// description:	get an image of the current objects in the layer
/// 
/// parameters:		none
/// result:			an NSImage
///
/// notes:			if there are no visible objects, returns nil.
///
///********************************************************************************************************************

- (NSImage*)		imageOfObjects
{
	NSImage*			img = nil;
	NSRect				sb;
	
	if([[self visibleObjects] count] > 0 )
	{
		sb = [self unionOfAllObjectBounds];
		
		img = [[NSImage alloc] initWithSize:sb.size];
		
		NSAffineTransform* tfm = [NSAffineTransform transform];
		[tfm translateXBy:-sb.origin.x yBy:-sb.origin.y];
		
		[img lockFocus];
		
		[[NSColor clearColor] set];
		NSRectFill( NSMakeRect( 0, 0, sb.size.width, sb.size.height ));
		
		[tfm concat];
		[self drawVisibleObjects];
		[img unlockFocus];
	}
	return [img autorelease];
}


///*********************************************************************************************************************
///
/// method:			pdfDataOfObjects
/// scope:			public instance method
/// description:	get a PDF of the current visible objects in the layer
/// 
/// parameters:		none
/// result:			PDF data in an NSData object
///
/// notes:			if there are no visible objects, returns nil.
///
///********************************************************************************************************************

- (NSData*)			pdfDataOfObjects
{
	NSData* pdfData = nil;
	
	if([[self visibleObjects] count] > 0 )
	{
		NSRect	fr = NSZeroRect;
		
		fr.size = [[self drawing] drawingSize];
		
		DKObjectLayerPDFView*	pdfView = [[DKObjectLayerPDFView alloc] initWithFrame:fr withLayer:self];
		DKViewController*		vc = [pdfView makeViewController];
		
		[[self drawing] addController:vc];
		
		NSRect sr = [self unionOfAllObjectBounds];
		pdfData = [pdfView dataWithPDFInsideRect:sr];
		[pdfView release];
	}
	return pdfData;
}


#pragma mark -
#pragma mark - handling a pending object

///*********************************************************************************************************************
///
/// method:			addPendingObject
/// scope:			public instance method
///	overrides:
/// description:	adds a new object to the layer pending successful interactive creation
/// 
/// parameters:		<pend> a new potential object to be added to the layer
/// result:			none
///
/// notes:			when interactively creating objects, it is preferable to create the object successfully before
///					committing it to the layer - this gives the caller a chance to abort the creation without needing
///					to be concerned about any undos, etc. The pending object is drawn on top of all others as normal
///					but until it is committed, it creates no undo task for the layer.
///
///********************************************************************************************************************

- (void)				addObjectPendingCreation:(DKDrawableObject*) pend
{
	NSAssert( pend != nil, @"pending object cannot be nil");

	[self removePendingObject];
	mNewObjectPending = [pend retain];
	
	// set the container first so that the undo task it generates is swallowed	
	[mNewObjectPending setContainer:self];
}


///*********************************************************************************************************************
///
/// method:			removePendingObject
/// scope:			public instance method
///	overrides:
/// description:	removes a pending object in the situation that the creation was unsuccessful
/// 
/// parameters:		none
/// result:			none
///
/// notes:			when interactively creating objects, if for any reason the creation failed, this should be called
///					to remove the object from the layer without triggering any undo tasks, and to remove any the object
///					itself made
///
///********************************************************************************************************************

- (void)				removePendingObject
{
	if ( mNewObjectPending != nil )
	{
		[mNewObjectPending notifyVisualChange];
		[mNewObjectPending release];
		mNewObjectPending = nil;
	}
}


///*********************************************************************************************************************
///
/// method:			commitPendingObjectWithUndoActionName:
/// scope:			public instance method
///	overrides:
/// description:	commits the pending object to the layer and sets up the undo task action name
/// 
/// parameters:		<actionName> the action name to give the undo manager after committing the object
/// result:			none
///
/// notes:			when interactively creating objects, if the creation succeeded, the pending object should be
///					committed to the layer permanently. This does that by adding it using addObject. The undo task
///					thus created is given the action name (note that other operations can also change this later).
///
///********************************************************************************************************************

- (void)				commitPendingObjectWithUndoActionName:(NSString*) actionName
{
	NSAssert( mNewObjectPending != nil, @"can't commit pending object because it is nil");
	
	[self addObject:mNewObjectPending];
	[self removePendingObject];
	[[self undoManager] setActionName:actionName];
}


///*********************************************************************************************************************
///
/// method:			drawPendingObjectInView:
/// scope:			public instance method
///	overrides:
/// description:	draws the pending object, if any, in the layer - called by drawRect:inView:
/// 
/// parameters:		<aView> the view being drawn into
/// result:			none
///
/// notes:			pending objects are drawn normally is if part of the current list, and on top of all others. Subclasses
///					may need to override this if the selected state needs passing differently. Typically pending objects
///					will be drawn selected, so the default is YES.
///
///********************************************************************************************************************

- (void)				drawPendingObjectInView:(NSView*) aView
{
	if ( mNewObjectPending != nil )
	{
		if([aView needsToDrawRect:[mNewObjectPending bounds]])
			[mNewObjectPending drawContentWithSelectedState:YES];
	}
}



#pragma mark -
#pragma mark - geometry
///*********************************************************************************************************************
///
/// method:			unionOfAllObjectBounds
/// scope:			public instance method
///	overrides:
/// description:	return the union of all the visible objects in the layer. If there are no visible objects, returns
///					NSZeroRect.
/// 
/// parameters:		none
/// result:			a rect, the union of all visible object's bounds in the layer
///
/// notes:			avoid using for refreshing objects. It is more efficient to use refreshAllObjects
///
///********************************************************************************************************************

- (NSRect)				unionOfAllObjectBounds
{
	NSEnumerator*		iter = [[self visibleObjects] objectEnumerator];
	DKDrawableObject*	obj;
	NSRect				u = NSZeroRect;
	
	while(( obj = [iter nextObject]))
		u = UnionOfTwoRects( u, [obj bounds]);
		
	return u;
}


///*********************************************************************************************************************
///
/// method:			refreshAllObjects
/// scope:			public instance method
///	overrides:
/// description:	causes all visible objects to redraw themselves
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				refreshAllObjects
{
	[[self visibleObjects] makeObjectsPerformSelector:@selector(notifyVisualChange)];
}


///*********************************************************************************************************************
///
/// method:			renderingTransform
/// scope:			public instance method
///	overrides:
/// description:	returns the layer's transform used when rendering objects within - it nearly always should be the
///					identity matrix.
/// 
/// parameters:		none
/// result:			a transform
///
/// notes:			part of an informal protocol mainly for the benefit of groups. Layers just return the identity matrix.
///
///********************************************************************************************************************

- (NSAffineTransform*)	renderingTransform
{
	return [NSAffineTransform transform];
}


#pragma mark -
#pragma mark - stacking order
///*********************************************************************************************************************
///
/// method:			moveUpObject:
/// scope:			public instance method
///	overrides:
/// description:	moves the object up in the stacking order
/// 
/// parameters:		<obj> object to move
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				moveUpObject:(DKDrawableObject*) obj
{
	int new = [self indexOfObject:obj] + 1;
	[self moveObject:obj toIndex:new];
}


///*********************************************************************************************************************
///
/// method:			moveDownObject:
/// scope:			public instance method
///	overrides:
/// description:	moves the object down in the stacking order
/// 
/// parameters:		<obj> the object to move
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				moveDownObject:(DKDrawableObject*) obj
{
	int new = [self indexOfObject:obj] - 1;
	[self moveObject:obj toIndex:new];
}


///*********************************************************************************************************************
///
/// method:			moveObjectToTop:
/// scope:			public instance method
///	overrides:
/// description:	moves the object to the top of the stacking order
/// 
/// parameters:		<obj> the object to move
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				moveObjectToTop:(DKDrawableObject*) obj
{
	int top = [m_objects count] - 1;
	[self moveObject:obj toIndex:top];
}


///*********************************************************************************************************************
///
/// method:			moveObjectToBottom:
/// scope:			public instance method
///	overrides:
/// description:	moves the object to the bottom of the stacking order
/// 
/// parameters:		<obj> object to move
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				moveObjectToBottom:(DKDrawableObject*) obj
{
	[self moveObject:obj toIndex:0];
}


///*********************************************************************************************************************
///
/// method:			moveObject:toIndex:
/// scope:			public instance method
///	overrides:
/// description:	movesthe object to the given stacking position index
/// 
/// parameters:		<obj> the object to move
///					<i> the index it should be moved to
/// result:			none
///
/// notes:			used to implement all the other moveTo.. ops
///
///********************************************************************************************************************

- (void)				moveObject:(DKDrawableObject*) obj toIndex:(int) i
{
	if ( ![self lockedOrHidden])
	{
		i = LIMIT(i, 0, [self countOfObjects] - 1);
		
		int old = [self indexOfObject:obj];
		
		if ( old != i )
		{
			[[[self undoManager] prepareWithInvocationTarget:self] moveObject:obj toIndex:old];
			
			[obj retain];
			[m_objects removeObject:obj];
			[m_objects insertObject:obj atIndex:i];
			[obj release];
			[obj notifyVisualChange];
		
			[[NSNotificationCenter defaultCenter] postNotificationName:kGCLayerDidReorderObjects object:self];
		}
	}
}


#pragma mark -
#pragma mark - clipboard ops


///*********************************************************************************************************************
///
/// method:			objectsFromPasteboard:
/// scope:			public instance method
///	overrides:
/// description:	unarchive a list of objects from the pasteboard, if possible
/// 
/// parameters:		<pb> the pasteboard to take objects from
/// result:			a list of objects
///
/// notes:			this factors the dearchiving of objects from the pasteboard. If the pasteboard does not contain
///					any valid types, nil is returned
///
///********************************************************************************************************************

- (NSArray*)			nativeObjectsFromPasteboard:(NSPasteboard*) pb
{
	NSData*				pbdata = [pb dataForType:kGCDrawableObjectPasteboardType];
	NSArray*			objects = nil;
	
	if ( pbdata != nil )
		objects = [NSKeyedUnarchiver unarchiveObjectWithData:pbdata];

	return objects;
}


///*********************************************************************************************************************
///
/// method:			addObjects:fromPasteboard:atDropLocation:
/// scope:			public instance method
///	overrides:
/// description:	add objects to the layer from the pasteboard
/// 
/// parameters:		<objects> a list of objects already dearchived from the pasteboard
///					<pb> the pasteboard (for information only)
///					<p> the drop location of the objects, defined as the lower left corner of the drag image - thus
///					this corresponds to the bottom left corner of the rect that bounds the entire list of objects. This
///					method computes the location of the first dropped object from this so that the objects are dropped
///					in a position corresponding to the drag image (plus any minor adjustment for the grid)
/// result:			none
///
/// notes:			this is used to implement a drag/drop operation of native objects. Currently, the first object in
///					a multiple selection is positioned at the point p, with others maintaining their positions
///					relative to this object as in the original set. 
///
///					This is the preferred method to use when pasting or dropping anything, because the subclass that
///					implements selection overrides this to handle the selection also. Thus when pasting non-native
///					objects, convert them to native objects and pass to this method in an array.
///
///********************************************************************************************************************

- (void)				addObjects:(NSArray*) objects fromPasteboard:(NSPasteboard*) pb atDropLocation:(NSPoint) p
{
	#pragma unused(pb)
	
	if ([self lockedOrHidden])
		return;
		
	NSAssert( objects != nil, @"cannot drop - array of objects is nil");
	
	NSEnumerator*		iter = [objects objectEnumerator];
	DKDrawableObject*	o;
	float				dx, dy;
	BOOL				hadFirst = NO;
	NSPoint				q = NSZeroPoint;
	NSRect				dropBounds;
	
	dropBounds = [DKDrawableObject unionOfBoundsOfDrawablesInArray:objects];
	o = [objects objectAtIndex:0];	// drop location is relative to the location of the first object
	
	dx = [o location].x - NSMinX( dropBounds );
	dy = [o location].y - NSMaxY( dropBounds );
	
	p.x += dx;
	p.y += dy;
	
	p = [[self drawing] snapToGrid:p withControlFlag:NO];
	
	while(( o = [iter nextObject]))
	{
		if(![o isKindOfClass:[DKDrawableObject class]])
			[NSException raise:NSInternalInconsistencyException format:@"error - trying to drop non-drawable objects"];
		
		if ( ! hadFirst )
		{
			q = [o location];
			[o moveToPoint:p];
			hadFirst = YES;
		}
		else
		{
			dx = [o location].x - q.x;
			dy = [o location].y - q.y;
			
			[o moveToPoint:NSMakePoint( p.x + dx, p.y + dy )];
		}
		[self addObject:o];
	}
}


///*********************************************************************************************************************
///
/// method:			setPasteOffsetX:y:
/// scope:			public instance method
///	overrides:
/// description:	establish the paste offset - a value used to position items when pasting and duplicating
/// 
/// parameters:		<x>, <y> the x and y values of the offset
/// result:			none
///
/// notes:			the values passed will be adjusted to the nearest grid interval if snap to grid is on.
///
///********************************************************************************************************************

- (void)				setPasteOffsetX:(float) x y:(float) y
{
	// sets the paste/duplicate offset to x, y - if there is a grid and snap to grid is on, the offset is made a grid
	// integral size.
	
	m_pasteOffset = NSMakeSize( x, y );
	
	if ([[self drawing] snapsToGrid])
	{
		DKGridLayer* grid = [[self drawing] gridLayer];
	
		m_pasteOffset = [grid nearestGridIntegralToSize:m_pasteOffset];
	}
	
//	LogEvent_(kReactiveEvent, @"set paste offset: {%f, %f}", _pasteOffset.width, _pasteOffset.height );
}


#pragma mark -
#pragma mark - hit testing
///*********************************************************************************************************************
///
/// method:			hitTest:
/// scope:			public instance method
///	overrides:
/// description:	find which object was hit by the given point, if any
/// 
/// parameters:		<point> a point to test against
/// result:			the object hit, or nil if none
///
/// notes:			
///
///********************************************************************************************************************

- (DKDrawableObject*)	hitTest:(NSPoint) point
{
	return [self hitTest:point partCode:NULL];
}


///*********************************************************************************************************************
///
/// method:			hitTest:partCode:
/// scope:			public instance method
///	overrides:
/// description:	performs a hit test but also returns the hit part code
/// 
/// parameters:		<point> the point to test
///					<part> pointer to int, receives the partcode hit as a result of the test. Can be NULL to ignore
///					this value.
/// result:			the object hit, or nil if none
///
/// notes:			
///
///********************************************************************************************************************

- (DKDrawableObject*)	hitTest:(NSPoint) point partCode:(int*) part
{
	NSEnumerator*		iter;
	DKDrawableObject*	o;
	int					partcode;
	
	iter = [self objectTopToBottomEnumerator];
	
	while(( o = [iter nextObject]))
	{
		partcode = [o hitPart:point];
	
		if ( partcode != kGCDrawingNoPart )
		{
			if ( part )
				*part = partcode;

			return o;
		}
	}
	
	if ( part )
		*part = kGCDrawingNoPart;
	return nil;
}


///*********************************************************************************************************************
///
/// method:			objectsInRect:
/// scope:			public instance method
///	overrides:
/// description:	finds all objects touched by the given rect
/// 
/// parameters:		<rect> a rectangle
/// result:			a list of objects touched by the rect
///
/// notes:			test for inclusion by calling the object's intersectsRect method. Can be used to select objects in
///					a given rect or for any other purpose. For selections, the results can be passed directly to
///					exchangeSelection:
///
///********************************************************************************************************************

- (NSArray*)			objectsInRect:(NSRect) rect
{
	NSEnumerator*		iter = [self objectBottomToTopEnumerator];
	DKDrawableObject*	o;
	NSMutableArray*		hits;
	
	hits = [[NSMutableArray alloc] init];
	
	while(( o = [iter nextObject]))
	{
		if([o visible] && [o intersectsRect:rect])
			[hits addObject:o];
	}

	return [hits autorelease];
}


#pragma mark -
#pragma mark - snapping
///*********************************************************************************************************************
///
/// method:			snapPoint:toAnyObjectExcept:snapTolerance:
/// scope:			public instance method
///	overrides:		
/// description:	snap a point to any existing object control point within tolerance
/// 
/// parameters:		<p> a point
///					<except> don't snap to this object (intended to be the one being snapped)
///					<tol> has to be within this distance to snap
/// result:			the modified point, or the original point
///
/// notes:			if snap to object is not set for this layer, this simply returns the original point unmodified.
///					currently uses hitPart to test for a hit, so tolerance is ignored and objects apply their internal
///					hit testing tolerance.
///
///********************************************************************************************************************

- (NSPoint)				snapPoint:(NSPoint) p toAnyObjectExcept:(DKDrawableObject*) except snapTolerance:(float) tol
{
	#pragma unused(tol)
	
	if ([self allowsSnapToObjects])
	{
		int					pc;
		DKDrawableObject*	ho;
		NSEnumerator*		iter;
		
		iter = [self objectTopToBottomEnumerator];
		
		while(( ho = [iter nextObject]))
		{
			if ( ho != except )
			{
				pc = [ho hitSelectedPart:p forSnapDetection:YES];
		
				if ( pc != kGCDrawingNoPart && pc != kGCDrawingEntireObjectPart )
				{
					p = [ho pointForPartcode:pc];
				//	LogEvent_(kInfoEvent, @"detectedsnap on %@, pc = %d", ho, pc );
					break;
				}
			}
		}
	}

	return p;
}


///*********************************************************************************************************************
///
/// method:			snappedMousePoint:forObject:
/// scope:			public instance method
///	overrides:		
/// description:	snap a (mouse) point to grid, guide or other object according to settings
/// 
/// parameters:		<p> a point
/// result:			the modified point, or the original point
///
/// notes:			usually called from snappedMousePoint: method in DKDrawableObject
///
///********************************************************************************************************************

- (NSPoint)				snappedMousePoint:(NSPoint) mp forObject:(DKDrawableObject*) obj withControlFlag:(BOOL) snapControl
{
	NSPoint omp = mp;
	NSPoint	gp;
	
	// snap to other objects unless the snapControl is pressed - object snapping has priority
	// over grid and guide snapping, but also has the least "pull" on the point
	
	if ( !snapControl && [self allowsSnapToObjects])
		mp = [self snapPoint:mp toAnyObjectExcept:obj snapTolerance:2.0];
		
	// if point remains unmodified, check for grid and guides
	
	if ( NSEqualPoints( mp, omp ))
	{
		mp = [[self drawing] snapToGuides:mp];
		gp = [[self drawing] snapToGrid:omp withControlFlag:snapControl];
		
		// use whichever is closest to the original point but which is not the original point
		
		if ( NSEqualPoints( mp, omp ))
			return gp;
		else if ( NSEqualPoints( gp, omp ))
			return mp;
		else
		{
			// in this case both a guide and a grid line have an influence on the point - use the
			// one that moves it the least
			
			float d1, d2;
			
			d1 = DiffPointSquaredLength( mp, omp );
			d2 = DiffPointSquaredLength( gp, omp );
			
			if ( d1 > d2 )
				return gp;
			else
				return mp;
		}
	}

	return mp;
}


#pragma mark -
#pragma mark - options
///*********************************************************************************************************************
///
/// method:			setAllowsEditing:
/// scope:			public instance method
///	overrides:
/// description:	sets whether the layer permits editing of its objects
/// 
/// parameters:		<editable> YES to enable editing, NO to prevent it
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				setAllowsEditing:(BOOL) editable
{
	m_allowEditing = editable;
}


///*********************************************************************************************************************
///
/// method:			allowsEditing
/// scope:			public instance method
///	overrides:
/// description:	does the layer permit editing of its objects?
/// 
/// parameters:		none
/// result:			YES if editing will take place, NO if it is prevented
///
/// notes:			locking and hiding the layer also disables editing
///
///********************************************************************************************************************

- (BOOL)				allowsEditing
{
	return m_allowEditing && ![self lockedOrHidden];
}


///*********************************************************************************************************************
///
/// method:			setAllowsSnapToObjects:
/// scope:			public instance method
///	overrides:
/// description:	sets whether the layer permits snapping to its objects
/// 
/// parameters:		<snap> YES to allow snapping
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				setAllowsSnapToObjects:(BOOL) snap
{
	m_allowSnapToObjects = snap;
}


///*********************************************************************************************************************
///
/// method:			allowsSnapToObjects
/// scope:			public instance method
///	overrides:
/// description:	does the layer permit snapping to its objects?
/// 
/// parameters:		none
/// result:			YES if snapping allowed
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				allowsSnapToObjects
{
	return m_allowSnapToObjects;
}


///*********************************************************************************************************************
///
/// method:			setLayerCacheOption:
/// scope:			public instance method
///	overrides:
/// description:	set whether the layer caches its content in an offscreen layer when not active, and how
/// 
/// parameters:		<option> the desired cache option
/// result:			none
///
/// notes:			layers can cache their entire contents offscreen when they are inactive. This can boost
///					drawing performance when there are many layers, or the layers have complex contents. When the
///					layer is deactivated the cache is updated, on activation the "real" content is drawn.
///
///********************************************************************************************************************

- (void)				setLayerCacheOption:(DKLayerCacheOption) option
{
	mLayerCachingOption = option;
}

///*********************************************************************************************************************
///
/// method:			layerCacheOption
/// scope:			public instance method
///	overrides:
/// description:	query whether the layer caches its content in an offscreen layer when not active
/// 
/// parameters:		none
/// result:			the current cache option
///
/// notes:			layers can cache their entire contents offscreen when they are inactive. This can boost
///					drawing performance when there are many layers, or the layers have complex contents. When the
///					layer is deactivated the cache is updated, on activation the "real" content is drawn.
///
///********************************************************************************************************************

- (DKLayerCacheOption)	layerCacheOption
{
	return mLayerCachingOption;
}



#pragma mark -
#pragma mark - user actions
///*********************************************************************************************************************
///
/// method:			toggleSnapToObjects:
/// scope:			public action method
///	overrides:		
/// description:	sets the snapping state for the layer
/// 
/// parameters:		<sender>
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (IBAction)			toggleSnapToObjects:(id) sender
{
	#pragma unused(sender)
	
	[self setAllowsSnapToObjects:![self allowsSnapToObjects]];
}


#pragma mark -
#pragma mark - private

///*********************************************************************************************************************
///
/// method:			updateCache
/// scope:			private method
///	overrides:		
/// description:	builds the offscreen cache(s) for drawing the layer more quickly when it's inactive
/// 
/// parameters:		none
/// result:			none
///
/// notes:			application code shouldn't call this directly
///
///********************************************************************************************************************

- (void)				updateCache
{
	if( mPDFCache == nil && mLayerContentCache == nil )
	{
		mCacheBounds = [self unionOfAllObjectBounds];
		
		if( mCacheBounds.size.width > 0.0 && mCacheBounds.size.height > 0.0 )
		{
			// create a PDF of the entire layer content. Note - this may not actually boost
			// performance over drawing objects on their own. Do experiment!
			
			if([self layerCacheOption] & kDKLayerCacheUsingPDF )
			{
				NSData* pdf = [self pdfDataOfObjects];
				
				NSAssert( pdf != nil, @"couldn't get pdf data for the layer");
				
				NSPDFImageRep* rep = [NSPDFImageRep imageRepWithData:pdf];
			
				NSAssert( rep != nil, @"can't create PDF image rep");
				mPDFCache = [rep retain];
			}
			
			// also create a CGLayer version of the same image, for use when drawing is using low quality mode or
			// when this is the only cache option set
			
			if([self layerCacheOption] & kDKLayerCacheUsingCGLayer)
			{
				CGContextRef	context = [[NSGraphicsContext currentContext] graphicsPort];
				
				NSAssert( context != nil, @"no context for caching the layer");
				
				CGLayerRef		layer = CGLayerCreateWithContext( context, *(CGSize*)&mCacheBounds.size, NULL );
				
				NSAssert( layer != nil, @"couldn't create caching layer");
				
				context = CGLayerGetContext( layer );
				NSGraphicsContext* nsContext = [NSGraphicsContext graphicsContextWithGraphicsPort:context flipped:YES];
				
				[NSGraphicsContext saveGraphicsState];
				[NSGraphicsContext setCurrentContext:nsContext];
				
				// draw the contents into the layer, offsetting to the area's origin

				NSAffineTransform* transform = [NSAffineTransform transform];
				[transform translateXBy:-mCacheBounds.origin.x yBy:-mCacheBounds.origin.y];
				[transform concat];
				[self drawVisibleObjects];
				[NSGraphicsContext restoreGraphicsState];
				
				LogEvent_( kReactiveEvent, @"built offscreen cache = %@; size = %@", layer, NSStringFromSize( mCacheBounds.size ));
			
				// assign the new layer cache to the ivar:
				
				mLayerContentCache = layer;
			}
		}
	}
}


///*********************************************************************************************************************
///
/// method:			invalidateCache
/// scope:			private method
///	overrides:		
/// description:	discard the offscreen cache(s) used for drawing the layer more quickly when it's inactive
/// 
/// parameters:		none
/// result:			none
///
/// notes:			application code shouldn't call this directly
///
///********************************************************************************************************************

- (void)			invalidateCache
{
	LogEvent_( kReactiveEvent, @"invalidating layer cache");
	
	if ( mLayerContentCache != nil )
	{
		CGLayerRelease( mLayerContentCache );
		mLayerContentCache = nil;
	}
	
	if( mPDFCache != nil )
	{
		[mPDFCache release];
		mPDFCache = nil;
	}
}


#pragma mark -
#pragma mark As a DKLayer


///*********************************************************************************************************************
///
/// method:			drawingHasNewUndoManager:
/// scope:			public instance method
/// description:	called when the drawing's undo manager is changed - this gives objects that cache the UM a chance
///					to update their references
/// 
/// parameters:		<um> the new undo manager
/// result:			none
///
/// notes:			pushes out the new um to all object's styles (which cache the um)
///
///********************************************************************************************************************

- (void)			drawingHasNewUndoManager:(NSUndoManager*) um
{
//	LogEvent_(kReactiveEvent, @"layer %@ updating undo manager: %@", self, um );

	[[self allStyles] makeObjectsPerformSelector:@selector(setUndoManager:) withObject:um];
}


///*********************************************************************************************************************
///
/// method:			drawRect:inView:
/// scope:			private instance method
///	overrides:		DKLayer
/// description:	draws the layer and its contents on demand
/// 
/// parameters:		<rect> the area being updated
/// result:			none
///
/// notes:			called by the drawing when necessary to update the views. This will draw from the cache if set
///					to do so and the layer isn't active
///
///********************************************************************************************************************

- (void)				drawRect:(NSRect) rect inView:(DKDrawingView*) aView
{
	#pragma unused(rect)
	
	if([[self objects] count] > 0)
	{
		mCacheBounds = [self unionOfAllObjectBounds];
		
		// if the layer has a valid offscreen cache, use it to draw the layer's contents to the screen
		
		BOOL drawingToScreen = [NSGraphicsContext currentContextDrawingToScreen];
		BOOL usingCache = [self layerCacheOption] != kDKLayerCacheNone;
		
		if( drawingToScreen && usingCache && ![self isActive])
		{
			// if not cached, build the cache
			
			if( mPDFCache == nil )
				[self updateCache];
			
			// if we need to draw anything, do so from the cache
				
			if([aView needsToDrawRect:mCacheBounds])
			{
				BOOL hasPDF = ([self layerCacheOption] & kDKLayerCacheUsingPDF) && ( mPDFCache != nil );
				BOOL hasCG = ([self layerCacheOption] & kDKLayerCacheUsingCGLayer) && ( mLayerContentCache != nil );
				
				// draw using layer if it's the only thing available OR the drawing is in LQ mode
				
				if(( hasCG && !hasPDF) || (hasCG && [[self drawing] lowRenderingQuality]))
				{
					CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
					CGContextDrawLayerAtPoint( context, *(CGPoint*)&mCacheBounds.origin, mLayerContentCache );
				}
				else if( hasPDF )
				{
					// pdf cache is flipped, so need a transform here to unflip it
					
					NSAffineTransform* unflipper = [NSAffineTransform transform];
					[unflipper translateXBy:mCacheBounds.origin.x yBy:mCacheBounds.origin.y + mCacheBounds.size.height];
					[unflipper scaleXBy:1.0 yBy:-1.0];
					[unflipper concat];
					
					[mPDFCache draw];
				}
			}
		}
		else
		{
			// if the active layer, or printing, or not using the cache, just draw the objects directly
			
			NSEnumerator*		iter = [self objectBottomToTopEnumerator];
			DKDrawableObject*	obj;
			
			// draw the objects
			
			while(( obj = [iter nextObject]))
			{
				if ( [obj visible] && ( aView == nil || [aView needsToDrawRect:[obj bounds]]))
					[obj drawContentWithSelectedState:NO];
			}
		}
	}
	
	// draw any pending object on top of the others
	
	[self drawPendingObjectInView:aView];
	
	if ( m_inDragOp )
	{
		// draw a highlight around the edge of the layer
		
		NSRect ir = [[self drawing] interior];
		
		[[self selectionColour] set];
		NSFrameRectWithWidth( NSInsetRect( ir, -3, -3), 3.0 );
	}
}


///*********************************************************************************************************************
///
/// method:			hitLayer:
/// scope:			public instance method
///	overrides:		DKLayer
/// description:	does the point hit anything in the layer?
/// 
/// parameters:		<p> the point to test
/// result:			YES if any object is hit, NO otherwise
///
/// notes:			 
///
///********************************************************************************************************************

- (BOOL)				hitLayer:(NSPoint) p
{
	return ([self hitTest:p] != nil );
}


///*********************************************************************************************************************
///
/// method:			allStyles
/// scope:			public instance method
///	overrides:		DKLayer
/// description:	returns a list of styles used by the current set of objects
/// 
/// parameters:		none
/// result:			the set of unique style objects
///
/// notes:			being a set, the result is unordered
///
///********************************************************************************************************************

- (NSSet*)				allStyles
{
	NSEnumerator*		iter = [self objectTopToBottomEnumerator];
	DKDrawableObject*	dko;
	NSSet*				styles;
	NSMutableSet*		unionOfAllStyles = nil;
	
	while(( dko = [iter nextObject]))
	{
		styles = [dko allStyles];
		
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
/// scope:			public instance method
///	overrides:		DKLayer
/// description:	returns a list of styles used by the current set of objects that are also registered
/// 
/// parameters:		none
/// result:			the set of unique registered style objects used by objects in this layer
///
/// notes:			being a set, the result is unordered
///
///********************************************************************************************************************

- (NSSet*)				allRegisteredStyles
{
	NSEnumerator*		iter = [self objectTopToBottomEnumerator];
	DKDrawableObject*	dko;
	NSSet*				styles;
	NSMutableSet*		unionOfAllStyles = nil;
	
	while(( dko = [iter nextObject]))
	{
		styles = [dko allRegisteredStyles];
		
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
/// scope:			public instance method
///	overrides:		DKLayer
/// description:	given a set of styles, replace those that have a matching key with the objects in the set
/// 
/// parameters:		<aSet> a set of style objects
/// result:			none
///
/// notes:			used when consolidating a document's saved styles with the application registry after a load
///
///********************************************************************************************************************

- (void)				replaceMatchingStylesFromSet:(NSSet*) aSet
{
	// propagate this to all drawables in the layer
	
	[[self objects] makeObjectsPerformSelector:@selector(replaceMatchingStylesFromSet:) withObject:aSet];
}


///*********************************************************************************************************************
///
/// method:			pasteboardTypesForOperation:
/// scope:			public instance method
///	overrides:		DKLayer
/// description:	get a list of the data types that the layer is able to deal with in a paste or drop operation
/// 
/// parameters:		<op> a set of flags indicating what operation the types should be relevant to. This is arranged
///					as a bitfield to allow combinations.
/// result:			an array of acceptable pasteboard data types for the given operation in preferred order
///
/// notes:			
///
///********************************************************************************************************************

- (NSArray*)			pasteboardTypesForOperation:(DKPasteboardOperationType) op
{
	// we can always cut/paste and drag/drop our native type:
	
	NSMutableArray* types = [NSMutableArray arrayWithObject:kGCDrawableObjectPasteboardType];
	
	// we can read any image format or a file containing one, or a string
	
	if (( op & kDKAllReadableTypes ) != 0 )
	{
		[types addObjectsFromArray:[NSImage imagePasteboardTypes]];
		[types addObject:NSFilenamesPboardType];
		[types addObject:NSStringPboardType];
	}
	
	// we can write PDF and TIFF image formats:
	
	if ((op & kDKAllWritableTypes ) != 0 )
	{
		[types addObjectsFromArray:[NSArray arrayWithObjects:NSPDFPboardType, NSTIFFPboardType, nil]];
	}
	
	return types;
}


- (void)				layerDidBecomeActiveLayer
{
	[self invalidateCache];
}



#pragma mark -
#pragma mark As an NSObject
- (void)				dealloc
{
	[self invalidateCache];
	
	// though we are about to release all the objects, set their container to nil - this ensures that
	// if anything else is retaining them, when they are later released they won't have stale refs to the drawing, owner, et. al.
	
	[m_objects makeObjectsPerformSelector:@selector(setContainer:) withObject:nil];
	
	[m_objects release];
	[super dealloc];
}


- (id)				init
{
	self = [super init];
	if (self != nil)
	{
		m_objects = [[NSMutableArray alloc] init];
		[self setPasteOffsetX:20 y:20];
		[self setAllowsSnapToObjects:YES];
		[self setAllowsEditing:YES];
		[self setLayerCacheOption:kDKLayerCacheNone];
		[self setName:NSLocalizedString(@"Drawing Layer", @"default name for new drawing layers")];
		
		if (m_objects == nil)
		{
			[self autorelease];
			self = nil;
		}
	}
	return self;
}


#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)				encodeWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];
	
	[coder encodeObject:[self objects] forKey:@"objects"];
	[coder encodeBool:[self allowsEditing] forKey:@"editable"];
	[coder encodeBool:[self allowsSnapToObjects] forKey:@"snappable"];
	[coder encodeInt:[self layerCacheOption] forKey:@"DKObjectOwnerLayer_cacheOption"];
}


- (id)					initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
//	LogEvent_(kFileEvent, @"decoding object owner layer %@", self);

	self = [super initWithCoder:coder];
	if (self != nil)
	{
		[self setObjects:[coder decodeObjectForKey:@"objects"]];
		
		[self setPasteOffsetX:20 y:20];
		NSAssert(NSEqualPoints(m_pasteAnchor, NSZeroPoint), @"Expected init to zero");
		NSAssert(!m_recordPasteOffset, @"Expected init to NO");
		
		[self setAllowsEditing:[coder decodeBoolForKey:@"editable"]];
		[self setAllowsSnapToObjects:[coder decodeBoolForKey:@"snappable"]];
		
		if([coder containsValueForKey:@"DKObjectOwnerLayer_cacheOption"])
			[self setLayerCacheOption:[coder decodeIntForKey:@"DKObjectOwnerLayer_cacheOption"]];
		else
			[self setLayerCacheOption:kDKLayerCacheNone];
				
		if (m_objects == nil)
		{
			[self autorelease];
			self = nil;
		}
	}
	return self;
}


#pragma mark -
#pragma mark As part of the NSDraggingDestination protocol

- (BOOL)			performDragOperation:(id <NSDraggingInfo>) sender
{
	BOOL			result = NO;
	NSView*			view = [self currentView];
	NSPasteboard*	pb = [sender draggingPasteboard];
	NSPoint			cp, ip = [sender draggedImageLocation];
	NSArray*		dropObjects = nil;


	cp = [view convertPoint:ip fromView:nil];
	
	NSString*	dt = [pb availableTypeFromArray:[self pasteboardTypesForOperation:kDKReadableTypesForDrag]];
	
	if ([dt isEqualToString:kGCDrawableObjectPasteboardType])
	{
		// drag contains native objects, which we can use directly.
		// if dragging source is this layer, remove existing
		
		dropObjects = [self nativeObjectsFromPasteboard:pb];
		[self addObjects:dropObjects fromPasteboard:pb atDropLocation:cp];
		[[self undoManager] setActionName:NSLocalizedString(@"Drag and Drop Objects", @"undo string for drag/drop objects")];
		
		result = YES;
	}
	else if ([dt isEqualToString:NSStringPboardType])
	{
		// create a text object to contain the dropped string
		
		NSString* theString = [pb stringForType:NSStringPboardType];
		
		if( theString != nil )
		{
			DKTextShape* tShape = [DKTextShape textShapeWithString:theString inRect:NSMakeRect( 0, 0, 200, 100 )];
			[tShape fitToText:self];
			
			cp = [view convertPoint:[sender draggingLocation] fromView:nil];
			cp.x -= [tShape size].width * 0.5f;
			cp.y += [tShape size].height * 0.5f;
			
			dropObjects = [NSArray arrayWithObject:tShape];
			[self addObjects:dropObjects fromPasteboard:pb atDropLocation:cp];
			[[self undoManager] setActionName:NSLocalizedString(@"Drag and Drop Text", @"undo string for drag/drop text")];
			
			result = YES;
		}
	}
	else if ([NSImage canInitWithPasteboard:pb])
	{
		DKImageShape*	imshape = [[DKImageShape alloc] initWithPasteboard:pb];
		
		if ( imshape )
		{
			// centre the image on the drop location as the drag image is from Finder and is of little use to us here
			
			cp = [view convertPoint:[sender draggingLocation] fromView:nil];
			
			cp.x -= [imshape size].width * 0.5f;
			cp.y += [imshape size].height * 0.5f;
			
			dropObjects = [NSArray arrayWithObject:imshape];
			[imshape release];
			[self addObjects:dropObjects fromPasteboard:pb atDropLocation:cp];
			[[self undoManager] setActionName:NSLocalizedString(@"Drag and Drop Image", @"undo string for drag/drop image")];
			
			result = YES;
		}
	}
	
	m_inDragOp = NO;
	[self setNeedsDisplay:YES];
	
	return result;
}


- (NSDragOperation)		draggingEntered:(id <NSDraggingInfo>) sender
{
	#pragma unused(sender)
	
	m_inDragOp = YES;
	[self setNeedsDisplay:YES];
	
	return NSDragOperationCopy;
}


- (void)				draggingExited:(id <NSDraggingInfo>) sender
{
	#pragma unused(sender)

	m_inDragOp = NO;
	[self setNeedsDisplay:YES];
}


- (NSDragOperation)		draggingUpdated:(id <NSDraggingInfo>) sender
{
	#pragma unused(sender)

	return NSDragOperationCopy;
}


- (BOOL)				prepareForDragOperation:(id <NSDraggingInfo>) sender
{
	#pragma unused(sender)

	return YES;
}


#pragma mark -
#pragma mark As part of NSMenuValidation Protocol

- (BOOL)				validateMenuItem:(NSMenuItem*) item
{
	SEL action = [item action];
	
	if ( action == @selector(toggleSnapToObjects:))
	{
		[item setState:[self allowsSnapToObjects]? NSOnState : NSOffState ];
		return YES;
	}
	else
		return [super validateMenuItem:item];
}


@end
