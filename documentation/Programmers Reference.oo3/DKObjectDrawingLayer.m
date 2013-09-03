///**********************************************************************************************************************************
///  DKObjectDrawingLayer.m
///  DrawKit
///
///  Created by graham on 11/08/2006.
///  Released under the Creative Commons license 2006 Apptree.net.
///
/// 
///  This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 License.
///  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to
///  Creative Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105, USA.
///
///**********************************************************************************************************************************

#import "DKObjectDrawingLayer.h"
#import "DKDrawablePath.h"
#import "DKDrawing.h"
#import "DKUndoManager.h"
#import "DKObjectDrawingLayer+Alignment.h"
#import "DKSelectionPDFView.h"
#import "DKShapeCluster.h"
#import "NSBezierPath+GPC.h"
#import "DKRuntimeHelper.h"
#import "NSMutableArray+DKAdditions.h"
#import "DKImageShape.h"
#import "DKTextShape.h"
#import "DKGeometryUtilities.h"
#import "LogEvent.h"

#pragma mark Contants (Non-localized)
NSString*		kGCLayerDidReorderObjects = @"kGCLayerDidReorderObjects";
NSString*		kGCDrawableObjectPasteboardType = @"net.apptree.drawkit.drawable";
NSString*		kGCLayerSelectionDidChange = @"kGCLayerSelectionDidChange";


#pragma mark Static Vars
static BOOL		sSelVisWhenInactive = NO;

#pragma mark -
@implementation DKObjectDrawingLayer
#pragma mark As a DKObjectDrawingLayer

+ (void)				setSelectionIsShownWhenInactive:(BOOL) visInactive
{
	sSelVisWhenInactive = visInactive;
}


+ (BOOL)				selectionIsShownWhenInactive
{
	return sSelVisWhenInactive;
}


+ (void)				setDefaultSelectionChangesAreUndoable:(BOOL) undoSel
{
	[[NSUserDefaults standardUserDefaults] setBool:undoSel forKey:@"DKDrawingLayer_undoableSelectionDefault"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}


+ (BOOL)				defaultSelectionChangesAreUndoable
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:@"DKDrawingLayer_undoableSelectionDefault"];
}



#pragma mark -
#pragma mark - useful lists of objects
///*********************************************************************************************************************
///
/// method:			selectedAvailableObjects
/// scope:			public instance method
///	overrides:
/// description:	returns the objects that are not locked, visible and selected
/// 
/// parameters:		none
/// result:			an array, objects that can be acted upon by a command as a set
///
/// notes:			this also preserves the stacking order of the objects (unlike -selection), so is the most useful
///					means of obtaining the set of objects that can be acted upon by a command or user interface control.
///					Note that if the layer is locked as a whole, this always returns an empty list
///
///********************************************************************************************************************

- (NSArray*)			selectedAvailableObjects
{
	NSMutableArray*		ao = [[NSMutableArray alloc] init];
	
	if ( ![self lockedOrHidden])
	{
		NSEnumerator*		iter = [self objectBottomToTopEnumerator];
		DKDrawableObject*	od;
		
		while(( od = [iter nextObject]))
		{
			if ([od visible] && ![od locked] && [self isSelectedObject:od])
				[ao addObject:od];
		}
	}
	return [ao autorelease];
}


///*********************************************************************************************************************
///
/// method:			selectedAvailableObjectsOfClass:
/// scope:			public instance method
///	overrides:
/// description:	returns the objects that are not locked, visible and selected and which have the given class
/// 
/// parameters:		none
/// result:			an array, objects of the given class that can be acted upon by a command as a set
///
/// notes:			see comments for selectedAvailableObjects
///
///********************************************************************************************************************

- (NSArray*)			selectedAvailableObjectsOfClass:(Class) aClass
{
	NSMutableArray*		ao = [[NSMutableArray alloc] init];
	
	if ( ![self lockedOrHidden])
	{
		NSEnumerator*		iter = [self objectBottomToTopEnumerator];
		DKDrawableObject*	od;
		
		while(( od = [iter nextObject]))
		{
			if ([od visible] && ![od locked] && [self isSelectedObject:od] && [od isKindOfClass:aClass])
				[ao addObject:od];
		}
	}
	return [ao autorelease];
}


///*********************************************************************************************************************
///
/// method:			selectedVisibleObjects
/// scope:			public instance method
///	overrides:
/// description:	returns the objects that are visible and selected
/// 
/// parameters:		none
/// result:			an array
///
/// notes:			see comments for selectedAvailableObjects
///
///********************************************************************************************************************

- (NSArray*)			selectedVisibleObjects
{
	NSMutableArray*		ao = [[NSMutableArray alloc] init];
	
	if ( ![self visible])
	{
		NSEnumerator*		iter = [self objectBottomToTopEnumerator];
		DKDrawableObject*	od;
		
		while(( od = [iter nextObject]))
		{
			if ([od visible] && [self isSelectedObject:od])
				[ao addObject:od];
		}
	}
	return [ao autorelease];
}


///*********************************************************************************************************************
///
/// method:			selectedObjectsReturning:toSelector:
/// scope:			public instance method
///	overrides:
/// description:	returns objects that respond to the selector with the value <answer>
/// 
/// parameters:		<answer> a value that should match the response ofthe selector
///					<selector> a selector taking no parameters
/// result:			an array, objects in the selection that match the value of <answer>
///
/// notes:			this is a very simple type of predicate test. Note - the method <selector> must not return
///					anything larger than an int or it will be ignored and the result may be wrong.
///
///********************************************************************************************************************

- (NSSet*)			selectedObjectsReturning:(int) answer toSelector:(SEL) selector
{
	NSEnumerator*	iter = [[self selection] objectEnumerator];
	NSMutableSet*	result = [NSMutableSet set];
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
	
	LogEvent_( kInfoEvent, @"%d objects (of %d) returned '%d' to selector '%@'", [result count], [[self selection] count], answer, NSStringFromSelector( selector ));
	
	return result;
}


///*********************************************************************************************************************
///
/// method:			duplicatedSelection
/// scope:			public instance method
///	overrides:
/// description:	returns an array consisting of a copy of the selected objects
/// 
/// parameters:		none
/// result:			an array of objects. 
///
/// notes:			the result maintains the stacking order of the original objects, but the objects do not belong to
///					this or any other layer. Usually this will be called as part of a duplicate or copy/cut command
///					where objects are ultimately going to be pasted back in to this or another layer.
///
///********************************************************************************************************************

- (NSArray*)			duplicatedSelection
{
	NSMutableArray*		arr;
	NSEnumerator*		iter = [[self selectedObjectsPreservingStackingOrder] objectEnumerator];
	DKDrawableObject*	od;
	DKDrawableObject*	odc;
	
	arr = [[NSMutableArray alloc] init];
	
	while(( od = [iter nextObject]))
	{
		odc = [od copy];
		[arr addObject:odc];
		[odc release];
	}
	
	return [arr autorelease];
}


///*********************************************************************************************************************
///
/// method:			selectedObjectsPreservingStackingOrder
/// scope:			public instance method
///	overrides:
/// description:	returns the selected objects in their original stacking order.
/// 
/// parameters:		none
/// result:			an array, the selected objects in their original order
///
/// notes:			slower than -selection, as it needs to iterate over the objects. This ignores visible and locked
///					states of the objects. See also -selectedAvailableObjects. If the layer itself is locked, returns
///					an empty array.
///
///********************************************************************************************************************

- (NSArray*)			selectedObjectsPreservingStackingOrder
{
	NSEnumerator*		iter = [self objectBottomToTopEnumerator];
	DKDrawableObject*	obj;
	NSMutableArray*		arr;
	
	arr = [[NSMutableArray alloc] init];
	
	if (![self lockedOrHidden])
	{
		while(( obj = [iter nextObject]))
		{
			if ([self isSelectedObject:obj])
				[arr addObject:obj];
		}
	}
	return [arr autorelease];
}


///*********************************************************************************************************************
///
/// method:			countSelectedAvailableObjects
/// scope:			public instance method
///	overrides:
/// description:	returns the number of objects that are visible and not locked
/// 
/// parameters:		none
/// result:			the count
///
/// notes:			if the layer itself is locked, returns 0
///
///********************************************************************************************************************

- (int)					countOfSelectedAvailableObjects
{
	// returns the number of selected objects that are also unlocked and visible.
	
	int cc = 0;
	
	if ( ![self lockedOrHidden])
	{
		NSEnumerator* iter = [[self selection] objectEnumerator];
		DKDrawableObject* od;
		
		while(( od = [iter nextObject]))
		{
			if ([od visible] && ![od locked])
				++cc;
		}
	}
	return cc;
}


#pragma mark -
#pragma mark - doing stuff to each item in the selection
///*********************************************************************************************************************
///
/// method:			makeSelectedAvailableObjectsPerform:
/// scope:			public instance method
///	overrides:
/// description:	makes the selected available object perform a given selector.
/// 
/// parameters:		<selector> the selector the objects should perform
/// result:			none
///
/// notes:			an easy way to apply a command to the set of selected available objects, provided that the
///					selector requires no parameters
///
///********************************************************************************************************************

- (void)				makeSelectedAvailableObjectsPerform:(SEL) selector
{
	[[self selectedAvailableObjects] makeObjectsPerformSelector:selector];
}


///*********************************************************************************************************************
///
/// method:			makeSelectedAvailableObjectsPerform:withObject:
/// scope:			public instance method
///	overrides:
/// description:	makes the selected available object perform a given selector with a single object parameter
/// 
/// parameters:		<selector> the selector the objects should perform
///					<anObject> the object parameter to pass to each method
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				makeSelectedAvailableObjectsPerform:(SEL) selector withObject:(id) anObject
{
	[[self selectedAvailableObjects] makeObjectsPerformSelector:selector withObject:anObject];
}


///*********************************************************************************************************************
///
/// method:			setSelectedObjectsLocked:
/// scope:			public instance method
///	overrides:
/// description:	locks or unlocks all the selected objects
/// 
/// parameters:		<lock> YES to lock the objects, NO to unlock them
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				setSelectedObjectsLocked:(BOOL) lock
{
	NSEnumerator*		iter = [[self selection] objectEnumerator];
	DKDrawableObject*	od;
	
	while(( od = [iter nextObject]))
		[od setLocked:lock];
}


///*********************************************************************************************************************
///
/// method:			setSelectedObjectsVisible:
/// scope:			public instance method
///	overrides:
/// description:	hides or shows all of the objects in the selection
/// 
/// parameters:		<visible> YES to show the objects, NO to hide them
/// result:			none
///
/// notes:			since hidden selected objects are not drawn, use with care, since usability may be severely
///					compromised (for example, how are you going to be able to select hidden objects in order to show them?)
///
///********************************************************************************************************************

- (void)				setSelectedObjectsVisible:(BOOL) visible
{
	// sets the visible state of all objects in the selection to <visible>
	
	NSEnumerator*		iter = [[self selection] objectEnumerator];
	DKDrawableObject*	od;
	
	while(( od = [iter nextObject]))
		[od setVisible:visible];
}


///*********************************************************************************************************************
///
/// method:			setHiddenObjectsVisible:
/// scope:			public instance method
///	overrides:
/// description:	reveals any hidden objects, setting the selection to those revealed
/// 
/// parameters:		none
/// result:			YES if at least one object was shown, NO otherwise
///
///
///********************************************************************************************************************

- (BOOL)				setHiddenObjectsVisible
{
	NSEnumerator*		iter = [self objectBottomToTopEnumerator];
	DKDrawableObject*	od;
	NSMutableSet*		hidden = [NSMutableSet set];
	
	while(( od = [iter nextObject]))
	{
		if (![od visible])
		{
			[od setVisible:YES];
			[hidden addObject:od];
		}
	}
	
	if ([hidden count] > 0 )
	{
		[self setSelection:hidden];
		return YES;
	}
	else
		return NO;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			refreshSelectedObjects
/// scope:			public class method
///	overrides:
/// description:	causes all selected objects to redraw themselves
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				refreshSelectedObjects
{
	[[self selection] makeObjectsPerformSelector:@selector(notifyVisualChange)];
}


///*********************************************************************************************************************
///
/// method:			moveSelectedObjectsByX:byY:
/// scope:			public instance method
///	overrides:
/// description:	changes the location of all objects in the selection by dx and dy
/// 
/// parameters:		<dx> add this much to each object's x coordinate
///					<dy> add this much to each object's y coordinate
/// result:			YES if there were selected objects, NO if there weren't, and so nothing happened
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				moveSelectedObjectsByX:(float) dx byY:(float) dy
{
	NSArray*			arr = [self selectedAvailableObjects];
	
	if (([arr count] > 0 ) && (( dx != 0.0 ) || ( dy != 0.0 )))
	{
		NSEnumerator*		iter = [arr objectEnumerator];
		DKDrawableObject*	od;
		
		while(( od = [iter nextObject]))
			[od moveByX:dx byY:dy];

		return YES;
	}
	else
		return NO;
}


#pragma mark -
#pragma mark - the selection
///*********************************************************************************************************************
///
/// method:			setSelection:
/// scope:			public instance method
///	overrides:
/// description:	sets the selection to a given set of objects
/// 
/// parameters:		<sel> a set of objects to select
/// result:			none
///
/// notes:			for interactive selections, exchangeSelection: is usually a better bet.
///
///********************************************************************************************************************

- (void)				setSelection:(NSSet*) sel
{
	if ( ![self lockedOrHidden])
	{
		if ([sel isEqualToSet:[self selection]])
			return;
		
		// if this change is coming from the undo manager, ignore the undoable flag
		
		if ([self selectionChangesAreUndoable] || [[self undoManager] isUndoing] || [[self undoManager] isRedoing])
			[[self undoManager] registerUndoWithTarget:self selector:@selector(setSelection:) object:[self selection]];
		
		[self refreshSelectedObjects];
		[m_selection makeObjectsPerformSelector:@selector(objectIsNoLongerSelected)];
		
		NSMutableSet*	temp = [sel mutableCopy];
		[m_selection release];
		m_selection = temp;
		
		[m_selection makeObjectsPerformSelector:@selector(objectDidBecomeSelected)];
		[self refreshSelectedObjects];
		[[NSNotificationCenter defaultCenter] postNotificationName:kGCLayerSelectionDidChange object:self];
	}
}


///*********************************************************************************************************************
///
/// method:			selection
/// scope:			public instance method
///	overrides:
/// description:	returns the list of objects that are selected
/// 
/// parameters:		none
/// result:			all selected objects
///
/// notes:			If stacking order of the items in the selection is important,
///					a method such as selectedAvailableObjects or selectedObjectsPreservingStackingOrder should be used.
///					if the layer itself is locked or hidden, always returns nil.
///
///********************************************************************************************************************

- (NSSet*)			selection
{
	return [self lockedOrHidden]? nil : [[m_selection copy] autorelease];
}


///*********************************************************************************************************************
///
/// method:			singleSelection
/// scope:			public instance method
///	overrides:
/// description:	if the selection consists of a single available object, return it. Otherwise nil.
/// 
/// parameters:		none
/// result:			the selected object if it's the only one and it's available
///
/// notes:			this is useful for easily handling the case where an operation can only operate on one object to be
///					meaningful. It is also used by the automatic invocation forwarding mechanism.
///
///********************************************************************************************************************

- (DKDrawableObject*)	singleSelection
{
	// if the selection consists of a single object, return it. nil otherwise.
	
	if ([self isSingleObjectSelected])
		return [m_selection anyObject];
	else
		return nil;
}


#pragma mark -
#pragma mark - selection operations
///*********************************************************************************************************************
///
/// method:			deselectAll
/// scope:			public instance method
///	overrides:
/// description:	deselect any selected objects
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				deselectAll
{
	if ([self isSelectionNotEmpty])
	{
		[self refreshSelectedObjects];
		[m_selection makeObjectsPerformSelector:@selector(objectIsNoLongerSelected)];
		[m_selection removeAllObjects];
		[[self drawing] hideRulerMarkers];
		[[NSNotificationCenter defaultCenter] postNotificationName:kGCLayerSelectionDidChange object:self];
	}
}


///*********************************************************************************************************************
///
/// method:			selectAll
/// scope:			public instance method
///	overrides:
/// description:	select all available objects
/// 
/// parameters:		none
/// result:			none
///
/// notes:			this also adds hidden objects to the selection, even though they are not visible
///
///********************************************************************************************************************

- (void)				selectAll
{
	[self exchangeSelectionWithObjectsInArray:[self objects]];
}


///*********************************************************************************************************************
///
/// method:			addObjectToSelection:
/// scope:			public instance method
///	overrides:
/// description:	add a single object to the selection
/// 
/// parameters:		<obj> an object to select
/// result:			none
///
/// notes:			any existing objects in the selection remain selected
///
///********************************************************************************************************************

- (void)				addObjectToSelection:(DKDrawableObject*) obj
{
	if (![m_selection containsObject:obj] && ![self lockedOrHidden])
	{
		[m_selection addObject:obj];
		[obj objectDidBecomeSelected];
		[obj notifyVisualChange];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:kGCLayerSelectionDidChange object:self];
	}
}


///*********************************************************************************************************************
///
/// method:			addObjectsToSelection
/// scope:			public instance method
///	overrides:
/// description:	add a set of objects to the selection
/// 
/// parameters:		<objs> an array of objects to select
/// result:			none
///
/// notes:			existing objects in the selection remain selected
///
///********************************************************************************************************************

- (void)				addObjectsToSelectionFromArray:(NSArray*) objs;
{
	if([objs count] > 0 )
	{
		NSEnumerator*	iter = [objs objectEnumerator];
		DKDrawableObject* o;
		
		while(( o = [iter nextObject]))
			[self addObjectToSelection:o];
	}
}


///*********************************************************************************************************************
///
/// method:			replaceSelection:
/// scope:			public instance method
///	overrides:
/// description:	select the given object, deselecting all previously selected objects
/// 
/// parameters:		<obj> the object to select
/// result:			YES if the selection changed, NO if it did not (i.e. if <obj> was already the only selected object)
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				replaceSelectionWithObject:(DKDrawableObject*) obj
{
	NSAssert( obj != nil, @"attempt to replace selection with nil");
	
	return [self exchangeSelectionWithObjectsInArray:[NSArray arrayWithObject:obj]];
}


///*********************************************************************************************************************
///
/// method:			removeObjectFromSelection:
/// scope:			public instance method
///	overrides:
/// description:	remove a single object from the selection
/// 
/// parameters:		<obj> the object to deselect
/// result:			none
///
/// notes:			other objects in the selection are unaffected
///
///********************************************************************************************************************

- (void)				removeObjectFromSelection:(DKDrawableObject*) obj
{
	if ([m_selection containsObject:obj] && ![self lockedOrHidden])
	{
		[obj notifyVisualChange];
		[obj objectIsNoLongerSelected];
		[m_selection removeObject:obj];

		if(![self isSelectionNotEmpty])
			[[self drawing] hideRulerMarkers];

		[[NSNotificationCenter defaultCenter] postNotificationName:kGCLayerSelectionDidChange object:self];
	}
}


///*********************************************************************************************************************
///
/// method:			exchangeSelectionWithObjectsInArray:
/// scope:			public instance method
///	overrides:
/// description:	sets the selection to a given set of objects
/// 
/// parameters:		<sel> the set of objects to select
/// result:			YES if the selection changed, NO if it did not
///
/// notes:			this is intended as a more efficient version of setSelection:, since it only changes the state of
///					objects that differ between the current selection and the list passed. It is intended to be called
///					when interactively making a selection such as during a marquee drag, when it's likely that the same
///					set of objects is repeatedly offered for selection. Also, since it accepts an array parameter, it may
///					be used directly with sets of objects without first making into a set.
///
///********************************************************************************************************************

- (BOOL)				exchangeSelectionWithObjectsInArray:(NSArray*) sel
{
	BOOL didChange = NO;
	
	if(![self lockedOrHidden])
	{
		NSMutableSet* newSel = [NSMutableSet setWithArray:sel];
		
		if ( ![m_selection isEqualToSet:newSel])
		{
			NSMutableSet* oldSel = [m_selection mutableCopy];
			
			[oldSel minusSet:newSel];	// these are not present in the new selection, so will be deselected
			[newSel minusSet:[self selection]];	// these are not present in the old selection, so will be selected
			
			[oldSel makeObjectsPerformSelector:@selector(objectIsNoLongerSelected)];
			[oldSel makeObjectsPerformSelector:@selector(notifyVisualChange)];
			[m_selection setSet:[NSSet setWithArray:sel]];
			[newSel makeObjectsPerformSelector:@selector(objectDidBecomeSelected)];
			[newSel makeObjectsPerformSelector:@selector(notifyVisualChange)];
			
			[oldSel release];
			
			if(![self isSelectionNotEmpty])
				[[self drawing] hideRulerMarkers];

			[[NSNotificationCenter defaultCenter] postNotificationName:kGCLayerSelectionDidChange object:self];
			didChange = YES;
		}
	}
	return didChange;
}


///*********************************************************************************************************************
///
/// method:			scrollToSelection
/// scope:			public instance method
///	overrides:
/// description:	scrolls one or all views attached to the drawing so that the selection within this layer is visible
/// 
/// parameters:		<aView> if not nil, the view to scroll. If nil, scrolls all views
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				scrollToSelectionInView:(NSView*) aView
{
	if ([self isSelectionNotEmpty])
	{
		NSRect sb = [self selectionBounds];
		
		if( aView == nil )
			[[self drawing] scrollToRect:sb];
		else
			[aView scrollRectToVisible:sb];
	}
}


#pragma mark -
#pragma mark - style operations on multiple items
///*********************************************************************************************************************
///
/// method:			selectObjectsWithStyle:
/// scope:			public instance method
///	overrides:
/// description:	sets the selection to the set of objects that havethe given style
/// 
/// parameters:		<style> the style to match
/// result:			YES if the selection changed, NO if it did not
///
/// notes:			the style is compared by key, so clones of the style are not considered a match
///
///********************************************************************************************************************

- (BOOL)				selectObjectsWithStyle:(DKStyle*) style
{
	return [self exchangeSelectionWithObjectsInArray:[self objectsWithStyle:style]];
}


///*********************************************************************************************************************
///
/// method:			replaceStyle:withStyle:selectingObjects:
/// scope:			public instance method
///	overrides:
/// description:	replaces the style of all objects that have a reference to <style> with <newStyle>, optionally selecting them
/// 
/// parameters:		<style> the style to match
///					<newStyle> the style to replace it with
///					<select> if YES, also replace the selection with the affected objects
/// result:			YES if the selection changed, NO if it did not
///
/// notes:			the style is compared by key, so clones of the style are not considered a match
///
///********************************************************************************************************************

- (BOOL)				replaceStyle:(DKStyle*) style withStyle:(DKStyle*) newStyle selectingObjects:(BOOL) selectObjects
{
	NSArray*			matches = [self objectsWithStyle:style];
	NSEnumerator*		iter = [matches objectEnumerator];
	DKDrawableObject*	o;
	
	while(( o = [iter nextObject]))
		[o setStyle:newStyle];
	
	if ( selectObjects )
		return [self exchangeSelectionWithObjectsInArray:matches];
	else
		return NO;
}


#pragma mark -
#pragma mark - useful selection tests
///*********************************************************************************************************************
///
/// method:			isSelected:
/// scope:			public instance method
///	overrides:
/// description:	query whether a given object is selected or not
/// 
/// parameters:		<obj> the object to test
/// result:			YES if it is selected, NO if not
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				isSelectedObject:(DKDrawableObject*) obj
{
	return [m_selection containsObject:obj];
}


///*********************************************************************************************************************
///
/// method:			selectionNotEmpty
/// scope:			public instance method
///	overrides:
/// description:	query whether any objects are selected
/// 
/// parameters:		none
/// result:			YES if there is at least one object selected, NO if none are
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				isSelectionNotEmpty
{
	return [[self selection] count] > 0;
}


///*********************************************************************************************************************
///
/// method:			singleObjectSelected
/// scope:			public instance method
///	overrides:
/// description:	query whether there is exactly one object selected
/// 
/// parameters:		none
/// result:			YES if one object selected, NO if none or more than one are
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				isSingleObjectSelected
{
	return [[self selection] count] == 1;
}


///*********************************************************************************************************************
///
/// method:			selectionContainsObjectOfClass:
/// scope:			public instance method
///	overrides:
/// description:	query whether the selection contains any objects matching the given class
/// 
/// parameters:		<c> the class of object sought
/// result:			YES if there is at least one object of type <c>, NO otherwise
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				selectionContainsObjectOfClass:(Class) c
{
	NSEnumerator*	iter = [[self selection] objectEnumerator];
	id				o;
	
	while(( o = [iter nextObject]))
	{
		if( [o isKindOfClass:c] )
			return YES;
	}
	
	return NO;
}


///*********************************************************************************************************************
///
/// method:			selectionBounds
/// scope:			public instance method
///	overrides:
/// description:	return the overall area bounded by the objects in the selection
/// 
/// parameters:		none
/// result:			the union of the bounds of all selected objects
///
/// notes:			
///
///********************************************************************************************************************

- (NSRect)				selectionBounds
{
	NSRect				r = NSZeroRect;
	
	if ([self isSelectionNotEmpty])
	{
		DKDrawableObject*	od;
		NSEnumerator*		iter = [[self selection] objectEnumerator];
		
		while(( od = [iter nextObject]))
			r = UnionOfTwoRects( r, [od bounds]);
	}
	return r;
}


#pragma mark -
#pragma mark - selection undo stuff
///*********************************************************************************************************************
///
/// method:			setSelectionChangesAreUndoable:
/// scope:			public instance method
///	overrides:
/// description:	set whether selection changes should be recorded for undo.
/// 
/// parameters:		<undoable> YES to record selection changes, NO to not bother.
/// result:			none
///
/// notes:			different apps may want to treat selection changes as undoable state changes or not.
///
///********************************************************************************************************************

- (void)				setSelectionChangesAreUndoable:(BOOL) undoable
{
	m_selectionIsUndoable = undoable;
}


///*********************************************************************************************************************
///
/// method:			selectionChangesAreUndoable
/// scope:			public instance method
///	overrides:
/// description:	are selection changes undoable?
/// 
/// parameters:		none
/// result:			YES if they are undoable, NO if not
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				selectionChangesAreUndoable
{
	return m_selectionIsUndoable;
}


///*********************************************************************************************************************
///
/// method:			recordSelectionForUndo
/// scope:			private instance method
///	overrides:
/// description:	make a copy of the selection for a possible undo recording
/// 
/// parameters:		none
/// result:			none
///
/// notes:			the selection is copied and stored in the ivar <_selectionUndo>. Usually called at the start of
///					an operation that can potentially change the selection state, such as a mouse down.
///
///********************************************************************************************************************

- (void)				recordSelectionForUndo
{
	if ( m_selectionUndo )
	{
		[m_selectionUndo release];
		m_selectionUndo = nil;
	}
	
	// keep a note of the undo count at this point - if it hasn't changed when the
	// selection is committed, then don't record the selection change unless the flag forces it.
	
	mUndoCount = [(DKUndoManager*)[self undoManager] changeCount];
	m_selectionUndo = [[self selection] retain];
	
	LogEvent_( kReactiveEvent, @"recorded selection for possible undo, count = %d", mUndoCount );
}


///*********************************************************************************************************************
///
/// method:			commitSelectionUndoWithActionName:
/// scope:			private instance method
///	overrides:
/// description:	sends the recorded selection state to the undo manager and tags it with the given action name
/// 
/// parameters:		<actionName> undo menu string, or nil to use a preset name
/// result:			none
///
/// notes:			usually called at the end of any operation than might have changed the selection. This also sets
///					the action name even if the selection is unaffected, so callers can just call this with the
///					desired action name and get the correct outcome, whether or not selection is undoable or changed.
///					This will help keep code tidy.
///
///********************************************************************************************************************

- (void)				commitSelectionUndoWithActionName:(NSString*) actionName
{
	// sends the recorded selection to the undo manager. If sel changes are not undoable on their own, the sel change is only
	// added to the undo stack if some other operation has also occurred, and then only if the selection actually
	// changed. If the flag is to record all changes, unaccompanied sel changes are recorded regardless.
	
	unsigned cc = [(DKUndoManager*)[self undoManager] changeCount];
	
	if (([self selectionChangesAreUndoable] || cc > mUndoCount) && m_selectionUndo != nil )
	{
		// if selection hasn't changed, do nothing
		
		if([self selectionHasChangedFromRecorded])
		{
			LogEvent_( kStateEvent, @"selection changed - recording for undo");
			
			[[self undoManager] registerUndoWithTarget:self selector:@selector(setSelection:) object:m_selectionUndo];
			
			// use the passed action name if there is one, otherwise any stored action name
			
			if ( actionName != nil )
				[[self undoManager] setActionName:actionName];
		}
	}
	else
	{
		// here, the selection is the only change, and it's not meant to be undone, so
		// do not set the action name
		
		actionName = nil;
	}
	
	if ( actionName != nil )
		[[self undoManager] setActionName:actionName];
	
	// done with the recorded selection, so get rid of it
	
	[m_selectionUndo release];
	m_selectionUndo = nil;
}


///*********************************************************************************************************************
///
/// method:			selectionHasChangedFromRecorded
/// scope:			public instance method
///	overrides:
/// description:	test whether the selection is now different from the recorded selection
/// 
/// parameters:		none
/// result:			YES if the selection differs, NO if they are the same
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				selectionHasChangedFromRecorded
{
	// returns whether the recorded selection differs from the current selection
	
	return ![[self selection] isEqualToSet:m_selectionUndo];
}


#pragma mark -
#pragma mark - making images of the selected objects
///*********************************************************************************************************************
///
/// method:			drawSelectedObjects
/// scope:			public instance method
///	overrides:
/// description:	draws only the selected objects, but with the selection highlight itself not shown. This is used when
///					imaging the selection to a PDF or other context.
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				drawSelectedObjects
{
	[self drawSelectedObjectsWithSelectionState:NO];
}

///*********************************************************************************************************************
///
/// method:			drawSelectedObjectsWithSelectionState:
/// scope:			public instance method
///	overrides:
/// description:	draws only the selected objects, with the selection highlight given. This is used when
///					imaging the selection to a PDF or other context.
/// 
/// parameters:		<selected> YES to show the selection, NO to not show it
/// result:			none
///
/// notes:			usually there is no good reason to copy objects with the selection state set to YES, but this is
///					provided for special needs when you do want that.
///
///********************************************************************************************************************

- (void)				drawSelectedObjectsWithSelectionState:(BOOL) selected
{
	NSArray*			sel = [self selectedObjectsPreservingStackingOrder];
	NSEnumerator*		iter = [sel objectEnumerator];
	DKDrawableObject*	od;
	
	while (( od = [iter nextObject]))
		[od drawContentWithSelectedState:selected];
}


///*********************************************************************************************************************
///
/// method:			selectedObjectsImage
/// scope:			public instance method
///	overrides:
/// description:	creates an image of the selected objects
/// 
/// parameters:		none
/// result:			an image
///
/// notes:			used to create an image representation of the selection when performing a cut or copy operation, to
///					allow the selection to be exported to graphical apps that don't understand our internal object format.
///
///********************************************************************************************************************

- (NSImage*)			imageOfSelectedObjects
{
	// returns an image of the objects in the selection. This images just the selected objects and leaves out any others,
	// even if they overlap or interleave with the selected objects. If the selection is empty, returns nil. The image
	// omits the selection highlight itself.
	
	NSImage*			img;
	NSRect				sb;
	
	sb = [self selectionBounds];
	
	img = [[NSImage alloc] initWithSize:sb.size];
	[img setFlipped:YES];
	
	NSAffineTransform* tfm = [NSAffineTransform transform];
	[tfm translateXBy:-sb.origin.x yBy:-sb.origin.y];
	
	[img lockFocus];
	
	[[NSColor clearColor] set];
	NSRectFill( NSMakeRect( 0, 0, sb.size.width, sb.size.height ));
	
	[tfm concat];
	[self drawSelectedObjects];
	[img unlockFocus];
	
	return [img autorelease];
}


///*********************************************************************************************************************
///
/// method:			pdfDataOfSelectedObjects
/// scope:			public instance method
///	overrides:
/// description:	creates a PDF representation of the selected objects
/// 
/// parameters:		none
/// result:			PDF data of the selected objects only
///
/// notes:			used to create a PDF representation of the selection when performing a cut or copy operation, to
///					allow the selection to be exported to PDF apps that don't understand our internal object format.
///					This requires the use of a temporary special view for recording the output as PDF.
///
///********************************************************************************************************************

- (NSData*)				pdfDataOfSelectedObjects
{
	// returns pdf data of the objects in the selection. This images just the selected objects and leaves out any others,
	// even if they overlap or interleave with the selected objects. If the selection is empty, returns nil.
	
	NSRect					fr = NSZeroRect;
	
	fr.size = [[self drawing] drawingSize];
	DKSelectionPDFView*		pdfView = [[DKSelectionPDFView alloc] initWithFrame:fr];
	DKViewController*		vc = [pdfView makeViewController];
	
	[[self drawing] addController:vc];
	
	NSRect sr = [self selectionBounds];
	NSData* pdfData = [pdfView dataWithPDFInsideRect:sr];
	[pdfView release];
	
	return pdfData;
}


#pragma mark -
#pragma mark - clipboard ops
///*********************************************************************************************************************
///
/// method:			copySelectionToPasteboard:
/// scope:			public instance method
///	overrides:
/// description:	copies the selection to the given pasteboard in a variety of formats
/// 
/// parameters:		<pb> the pasteboard to copy to
/// result:			none
///
/// notes:			data is recorded as native data, PDF and TIFF. Note that locked objects can't be copied as
///					native types, but images are still copied.
///
///********************************************************************************************************************

- (void)				copySelectionToPasteboard:(NSPasteboard*) pb
{
	NSMutableArray* dataTypes = [[self pasteboardTypesForOperation:kDKAllWritableTypes] mutableCopy];
	NSArray*		sel = [self selectedAvailableObjects];
	
	// if the selection is empty, remove the native type from the list
	
	if([sel count] == 0 )
		[dataTypes removeObject:kGCDrawableObjectPasteboardType];
	
	[pb declareTypes:dataTypes owner:self];
	
	if([sel count] > 0 )
	{
		// convert selection to data by archiving it
	
		NSData* pbdata = [NSKeyedArchiver archivedDataWithRootObject:sel];
		[pb setData:pbdata forType:kGCDrawableObjectPasteboardType];	
	}
			
	// add image of selection in PDF format:
	NSData* pdf = [self pdfDataOfSelectedObjects];
	[pb setData:pdf forType:NSPDFPboardType];
	
	// and TIFF format:

	NSImage* si = [self imageOfSelectedObjects];
	[pb setData:[si TIFFRepresentation] forType:NSTIFFPboardType];
	
	[dataTypes release];
}


#pragma mark -
#pragma mark - options
///*********************************************************************************************************************
///
/// method:			setDrawsSelectionHighlightsOnTop:
/// scope:			public instance method
///	overrides:
/// description:	sets whether selection highlights should be drawn on top of all other objects, or if they should be
///					drawn with the object at its current stacking position.
/// 
/// parameters:		<onTop> YES to draw on top, NO to draw in situ
/// result:			none
///
/// notes:			default is YES
///
///********************************************************************************************************************

- (void)				setDrawsSelectionHighlightsOnTop:(BOOL) onTop
{
	m_drawSelectionOnTop = onTop;
}


///*********************************************************************************************************************
///
/// method:			drawsSelectionHighlightsOnTop
/// scope:			public instance method
///	overrides:
/// description:	draw selection highlights on top or in situ?
/// 
/// parameters:		none
/// result:			YES if drawn on top, NO in situ.
///
/// notes:			default is YES
///
///********************************************************************************************************************

- (BOOL)				drawsSelectionHighlightsOnTop
{
	return m_drawSelectionOnTop;
}


///*********************************************************************************************************************
///
/// method:			setAllowsObjectsToBeTargetedByDrags:
/// scope:			public instance method
///	overrides:
/// description:	sets whether a drag into this layer will target individual objects or not.
/// 
/// parameters:		<allow> allow individual objects to receive drags
/// result:			none
///
/// notes:			if YES, the object under the mouse will highlight as a drag into the layer proceeds, and upon drop,
///					the object itself will be passed the drop information. Default is YES.
///
///********************************************************************************************************************

- (void)				setAllowsObjectsToBeTargetedByDrags:(BOOL) allow
{
	m_allowDragTargeting = allow;
}


///*********************************************************************************************************************
///
/// method:			allowsObjectsToBeTargetedByDrags
/// scope:			public instance method
///	overrides:
/// description:	returns whether a drag into this layer will target individual objects or not.
/// 
/// parameters:		none
/// result:			YES if objects can be targeted by drags
///
/// notes:			if YES, the object under the mouse will highlight as a drag into the layer proceeds, and upon drop,
///					the object itself will be passed the drop information. Default is YES.
///
///********************************************************************************************************************

- (BOOL)				allowsObjectsToBeTargetedByDrags
{
	return m_allowDragTargeting;
}


///*********************************************************************************************************************
///
/// method:			setSelectionVisible:
/// scope:			public instance method
///	overrides:
/// description:	sets whether the selection is actually shown or not.
/// 
/// parameters:		<vis> YES to show the selection, NO to hide it
/// result:			none
///
/// notes:			normally the selection should be visible, but some tools might want to hide it temporarily
///					at certain well-defined times, such as when dragging objects.
///
///********************************************************************************************************************

- (void)				setSelectionVisible:(BOOL) vis
{
	if( vis != m_selectionVisible )
	{
		m_selectionVisible = vis;
		[self refreshSelectedObjects];
	}
}


///*********************************************************************************************************************
///
/// method:			selectionVisible
/// scope:			public instance method
///	overrides:
/// description:	whether the selection is actually shown or not.
/// 
/// parameters:		none
/// result:			YES if the selection is visible, NO if hidden
///
/// notes:			normally the selection should be visible, but some tools might want to hide it temporarily
///					at certain well-defined times, such as when dragging objects.
///
///********************************************************************************************************************

- (BOOL)				selectionVisible
{
	return m_selectionVisible;
}




#pragma mark -
#pragma mark - drag + drop
///*********************************************************************************************************************
///
/// method:			setDragExclusionRect:
/// scope:			public instance method
///	overrides:
/// description:	sets the rect outside of which a mouse drag will drag the selection with the drag manager.
/// 
/// parameters:		<aRect> a rectangle - drags inside this rect do not cause a DM operation. Can be empty to
///					cause all drags to immediately be treated as DM drags.
/// result:			none
///
/// notes:			by default the drag exclusion rect is set to the interior of the drawing. Dragging objects to the
///					margins thus drags them "off" the drawing.
///
///********************************************************************************************************************

- (void)				setDragExclusionRect:(NSRect) aRect
{
	m_dragExcludeRect = aRect;
}


///*********************************************************************************************************************
///
/// method:			dragExclusionRect
/// scope:			public instance method
///	overrides:
/// description:	gets the rect outside of which a mouse drag will drag the selection with the drag manager.
/// 
/// parameters:		none
/// result:			a rect defining the area within which drags do not traigger DM operations
///
/// notes:			
///
///********************************************************************************************************************

- (NSRect)				dragExclusionRect
{
	return m_dragExcludeRect;
}


///*********************************************************************************************************************
///
/// method:			beginDragOfSelectedObjectsWithEvent:inView:
/// scope:			public instance method
///	overrides:
/// description:	initiates a drag of the selection to another document or app, or back to self.
/// 
/// parameters:		<event> the event that triggered the action - must be a mouseDown or mouseDragged
///					<view> the view in which the user dragging operation is taking place
/// result:			none
///
/// notes:			Keeps control until the drag completes. Swallows the mouseUp event. called from the mouseDragged
///					method when the mouse leaves the drag exclusion rect.
///
///********************************************************************************************************************

- (void)				beginDragOfSelectedObjectsWithEvent:(NSEvent*) event inView:(NSView*) view
{
	// starts a "real" drag of the selection. Usually called from mouseDragged when the mouse leaves the drag exclusion rect.
	
	NSImage*		image = [self imageOfSelectedObjects];
	NSPasteboard*	pb = [NSPasteboard pasteboardWithName:NSDragPboard];
	NSPoint			dragLoc;
	
	dragLoc.x = NSMinX([self selectionBounds]);
	dragLoc.y = NSMaxY([self selectionBounds]);
	
	// set the image the other way up and make it a bit transparent
	
	[image setFlipped:NO];
	[image lockFocus];
	[image drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositeCopy fraction:0.5];
	[image unlockFocus];
	
	// put the selection on the pasteboard
	
	[self copySelectionToPasteboard:pb]; 
	[self hideInfoWindow];

	// save a temporary list of the objects being dragged so that if they are dragged back into the same layer,
	// the originals can be removed.
	
	m_objectsPendingDrag = [[self selectedObjectsPreservingStackingOrder] retain];
	[self setSelectedObjectsVisible:NO]; 
	
	[view dragImage:image at:dragLoc offset:NSZeroSize event:event pasteboard:pb source:self slideBack:YES];
}


- (void)				drawingSizeChanged:(NSNotification*) note
{
	#pragma unused(note)
	
	[self setDragExclusionRect:[[self drawing] interior]];
}


#pragma mark -
#pragma mark - user actions
///*********************************************************************************************************************
///
/// method:			cut:
/// scope:			public action method
///	overrides:		NSResponder
/// description:	perform a cut
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			cuts the selection
///
///********************************************************************************************************************

- (IBAction)			cut:(id) sender
{
	[self copy:sender];
	[self delete:sender];
	[[self undoManager] setActionName:NSLocalizedString(@"Cut", @"undo string for cut object from layer")];
}


///*********************************************************************************************************************
///
/// method:			copy:
/// scope:			public action method
///	overrides:		NSResponder
/// description:	perform a copy
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			copies the selection to the general pasteboard
///
///********************************************************************************************************************

- (IBAction)			copy:(id) sender
{
	#pragma unused(sender)
	
	if([self isSelectionNotEmpty])
		[self copySelectionToPasteboard:[NSPasteboard generalPasteboard]];
}


///*********************************************************************************************************************
///
/// method:			paste:
/// scope:			public action method
///	overrides:		NSResponder
/// description:	perform a paste
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			pastes from the general pasteboard
///
///********************************************************************************************************************

- (IBAction)			paste:(id) sender
{
	#pragma unused(sender)
	
	if([self lockedOrHidden])
		return;
	
	[self recordSelectionForUndo];
	
	NSPasteboard*	pb = [NSPasteboard generalPasteboard];
	NSArray*		objects = [self nativeObjectsFromPasteboard:pb];
	BOOL			isContextMenu = ([sender tag] == kDKPasteCommandContextualMenuTag);
	NSView*			view = (NSView*)[[NSApp keyWindow] firstResponder];
	NSPoint			cp;
	
	// if the command came from the context menu, use the mouse location to position the item
	
	if ( isContextMenu )
	{
		cp = [[NSApp currentEvent] locationInWindow];
		cp = [view convertPoint:cp fromView:nil];
	}
	else
		cp = [(GCZoomView*)view centredPointInDocView];

	if( objects != nil && [objects count] > 0 )
	{
		if ( isContextMenu )
		{
			// figure out the bottom left corner of the pasted objects
			
			NSRect ur = [DKDrawableObject unionOfBoundsOfDrawablesInArray:objects];
			cp.x -= ur.size.width * 0.5f;
			cp.y += ur.size.height * 0.5f;
			
			[self addObjects:objects fromPasteboard:pb atDropLocation:cp];
		}
		else
		{
			m_recordPasteOffset = YES;
			[self addObjects:objects offsetByX:m_pasteOffset.width byY:m_pasteOffset.height];
			[self exchangeSelectionWithObjectsInArray:objects];
		}
		
		// select the objects that were pasted
		[self scrollToSelectionInView:view];
		[self commitSelectionUndoWithActionName:NSLocalizedString(@"Paste Object", @"undo string for paste object")];
	}
	else if ([pb availableTypeFromArray:[NSArray arrayWithObject:NSStringPboardType]] != nil )
	{
		// pasting a string - add a text object
		
		NSString* theString = [pb stringForType:NSStringPboardType];
		
		if( theString != nil )
		{
			DKTextShape* tShape = [DKTextShape textShapeWithString:theString inRect:NSMakeRect( 0, 0, 200, 100 )];
			[tShape fitToText:self];
			
			cp.x -= [tShape size].width * 0.5f;
			cp.y += [tShape size].height * 0.5f;
			
			objects = [NSArray arrayWithObject:tShape];
			[self addObjects:objects fromPasteboard:pb atDropLocation:cp];
			[self scrollToSelectionInView:view];
			[self commitSelectionUndoWithActionName:NSLocalizedString(@"Paste Text", @"undo string for paste text")];
		}
	}
	else if ([NSImage canInitWithPasteboard:pb])
	{
		// convert to an image shape and add it. Since this doesn't have a position, paste it in the centre of
		// the view.
		
		NSImage*		image = [[NSImage alloc] initWithPasteboard:pb];
		DKImageShape*	imshape = [[DKImageShape alloc] initWithImage:image];
		
		[image release];
		
		objects = [NSArray arrayWithObject:imshape];
		[imshape release];
		
		cp.x -= [imshape size].width * 0.5f;
		cp.y += [imshape size].height * 0.5f;

		[self addObjects:objects fromPasteboard:pb atDropLocation:cp];
		[self scrollToSelectionInView:view];
		[self commitSelectionUndoWithActionName:NSLocalizedString(@"Paste Image", @"undo string for paste image")];
	}
}


///*********************************************************************************************************************
///
/// method:			delete:
/// scope:			public action method
///	overrides:		NSResponder
/// description:	performs a delete operation
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (IBAction)			delete:(id) sender
{
	#pragma unused(sender)
	
	if ([[self selectedAvailableObjects] count] > 0 && ![self lockedOrHidden])
	{
		[self recordSelectionForUndo];
		[self removeObjects:[self selectedAvailableObjects]];
		[self deselectAll];
		[self commitSelectionUndoWithActionName:NSLocalizedString(@"Delete", @"undo string for Delete")];
	}
}


///*********************************************************************************************************************
///
/// method:			deleteBackward:
/// scope:			public class method
///	overrides:		NSResponder
/// description:	
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			calls delete: when backspace key is typed
///
///********************************************************************************************************************

- (IBAction)			deleteBackward:(id) sender
{
	[self delete:sender];
}


///*********************************************************************************************************************
///
/// method:			duplicate:
/// scope:			public action method
///	overrides:		
/// description:	Duplicates the selection
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (IBAction)			duplicate:(id) sender
{
	#pragma unused(sender)
	
	if ( ![self lockedOrHidden])
	{
		NSArray* s = [self duplicatedSelection];
		
		if ([s count] > 0 )
		{
			m_recordPasteOffset = YES;
			[self recordSelectionForUndo];
			[self addObjects:s offsetByX:m_pasteOffset.width byY:m_pasteOffset.height];
			[self exchangeSelectionWithObjectsInArray:s];
			[self scrollToSelectionInView:nil];
			[self commitSelectionUndoWithActionName:NSLocalizedString(@"Duplicate", @"undo string for Duplicate")];
		}
	}
}


///*********************************************************************************************************************
///
/// method:			selectAll:
/// scope:			public action method
///	overrides:		NSResponder
/// description:	selects all objects
/// 
/// parameters:		<sender> the action's sender (in fact the view)
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (IBAction)			selectAll:(id) sender
{
	#pragma unused(sender)
	
	if ( ![self lockedOrHidden])
	{
		[self recordSelectionForUndo];
		[self selectAll];
		[self scrollToSelectionInView:nil];
		[self commitSelectionUndoWithActionName:NSLocalizedString(@"Select All", @"undo string for select all")];
	}
}


///*********************************************************************************************************************
///
/// method:			selectNone:
/// scope:			public action method
///	overrides:		
/// description:	deselects all objects in the selection
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (IBAction)			selectNone:(id) sender
{
	#pragma unused(sender)
	
	if ( ![self lockedOrHidden])
	{
		[self recordSelectionForUndo];
		[self deselectAll];
		[self commitSelectionUndoWithActionName:NSLocalizedString(@"Deselect All", @"undo string for deselect all")];
	}
}


///*********************************************************************************************************************
///
/// method:			objectBringForward:
/// scope:			public action method
///	overrides:
/// description:	brings the selected object forward
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (IBAction)			objectBringForward:(id) sender
{
	#pragma unused(sender)
	
	if (![self lockedOrHidden] && [self isSingleObjectSelected])
	{
		[self moveUpObject:[self singleSelection]];
		[[self undoManager] setActionName:NSLocalizedString( @"Bring Forwards", @"undo name for bring object forward")];
	}
}


///*********************************************************************************************************************
///
/// method:			objectSendBackward:
/// scope:			public action method
///	overrides:
/// description:	sends the selected object backward
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (IBAction)			objectSendBackward:(id) sender
{
	#pragma unused(sender)
	
	if (![self lockedOrHidden] && [self isSingleObjectSelected])
	{
		[self moveDownObject:[self singleSelection]];
		[[self undoManager] setActionName:NSLocalizedString( @"Send Backwards", @"undo name for send object backward")];
	}
}


///*********************************************************************************************************************
///
/// method:			objectBringToFront:
/// scope:			public action method
///	overrides:
/// description:	brings the selected object to the front
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (IBAction)			objectBringToFront:(id) sender
{
	#pragma unused(sender)
	
	if (![self lockedOrHidden] && [self isSingleObjectSelected])
	{
		[self moveObjectToTop:[self singleSelection]];
		[[self undoManager] setActionName:NSLocalizedString( @"Bring To Front", @"undo name for bring object to front")];
	}
}


///*********************************************************************************************************************
///
/// method:			objectSendToBack:
/// scope:			public action method
///	overrides:
/// description:	sends the selected object to the back
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (IBAction)			objectSendToBack:(id) sender
{
	#pragma unused(sender)
	
	if (![self lockedOrHidden] && [self isSingleObjectSelected])
	{
		[self moveObjectToBottom:[self singleSelection]];
		[[self undoManager] setActionName:NSLocalizedString( @"Send To Back", @"undo name for send object to back")];
	}
}


///*********************************************************************************************************************
///
/// method:			lockObject:
/// scope:			public action method
///	overrides:
/// description:	locks all selected objects
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (IBAction)			lockObject:(id) sender
{
	#pragma unused(sender)
	
	if ( ![self lockedOrHidden])
	{
		// lock the selected objects (not the layer)
		
		[self setSelectedObjectsLocked:YES];
		[[self undoManager] setActionName:NSLocalizedString( @"Lock", @"undo name for lock object")];
	}
}


///*********************************************************************************************************************
///
/// method:			
/// method:			unlockObject:
/// scope:			public action method
///	overrides:
/// description:	unlocks all selected objects
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (IBAction)			unlockObject:(id) sender
{
	#pragma unused(sender)
	
	if ( ![self lockedOrHidden])
	{
		// unlock the selected objects (not the layer)
		[self setSelectedObjectsLocked:NO];
		[[self undoManager] setActionName:NSLocalizedString( @"Unlock", @"undo name for lock object")];
	}
}


///*********************************************************************************************************************
///
/// method:			showObject:
/// scope:			public action method
///	overrides:
/// description:	shows all selected objects
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (IBAction)			showObject:(id) sender
{
	#pragma unused(sender)
	
	if ( ![self lockedOrHidden])
	{
		[self setSelectedObjectsVisible:YES];
		[self scrollToSelectionInView:nil];
		[[self undoManager] setActionName:NSLocalizedString( @"Show Objects", @"undo name for show object")];
	}
}


///*********************************************************************************************************************
///
/// method:			hideObject:
/// scope:			public action method
///	overrides:
/// description:	hides all selected objects, then deselects all
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			caution: hiding the selection has usability implications!!
///
///********************************************************************************************************************

- (IBAction)			hideObject:(id) sender
{
	#pragma unused(sender)
	
	if ( ![self lockedOrHidden])
	{
		[self recordSelectionForUndo];
		[self setSelectedObjectsVisible:NO];
		[self deselectAll];
		[self commitSelectionUndoWithActionName:NSLocalizedString(@"Hide Objects", @"undo string for hide objects")];
	}
}


///*********************************************************************************************************************
///
/// method:			revealHiddenObjects:
/// scope:			public action method
///	overrides:
/// description:	reveals any hidden objects, setting the selection to them
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			beeps if no objects were hidden
///
///********************************************************************************************************************

- (IBAction)			revealHiddenObjects:(id) sender
{
	#pragma unused(sender)
	
	if ( ![self lockedOrHidden])
	{
		[self recordSelectionForUndo];
		if( [self setHiddenObjectsVisible])
		{
			[self scrollToSelectionInView:nil];
			[self commitSelectionUndoWithActionName:NSLocalizedString(@"Reveal Hidden Objects", @"undo string for reveal hidden objects")];
		}
		else
			NSBeep();
	}
}


///*********************************************************************************************************************
///
/// method:			groupObjects:
/// scope:			public action method
///	overrides:
/// description:	turns the selected objects into a group.
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			the new group is placed on top of all objects even if the objects grouped were not on top. The group
///					as a whole can be moved to any index - ungrouping replaces objects at that index.
///
///********************************************************************************************************************

- (IBAction)			groupObjects:(id) sender
{
	#pragma unused(sender)
	
	// turn the selected objects into a group object
	
	if (![self lockedOrHidden] && [self isSelectionNotEmpty] && ![self isSingleObjectSelected])
	{
		[self recordSelectionForUndo];
		
		NSArray*		objects = [self selectedAvailableObjects];
		DKShapeGroup*	group = [[DKShapeGroup alloc] init];
		
		// because the objects need a valid container in order for their location change to be recorded for undo,
		// the group must be added to the layer before objects are added to the group. hence we do not use the
		// convenience method +groupWithObjects: here, as it does not allow this order of the transfer of objects.
		
		[self addObject:group];
		[group setGroupObjects:objects];
		[group release];
		
		[self removeObjects:objects];

		[self replaceSelectionWithObject:group];
		[self commitSelectionUndoWithActionName:NSLocalizedString(@"Group", @"undo string for grouping")];
	}
}


- (IBAction)			clusterObjects:(id) sender
{
	#pragma unused(sender)
	
	if (![self lockedOrHidden] && [self isSelectionNotEmpty] && ![self isSingleObjectSelected])
	{
		[self recordSelectionForUndo];
		
		NSArray*		objects = [self selectedAvailableObjects];
		DKShapeCluster*	group = [DKShapeCluster clusterWithObjects:objects masterObject:[objects lastObject]];
		
		[self removeObjects:objects];
		[self addObject:group];
		[self replaceSelectionWithObject:group];
		[self commitSelectionUndoWithActionName:NSLocalizedString(@"Cluster", @"undo string for clustering")];
	}
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			moveLeft:
/// scope:			public action method
///	overrides:		NSResponder
/// description:	nudges the selected objects left by one unit
/// 
/// parameters:		<sender> the action's sender (in fact the view)
/// result:			none
///
/// notes:			the nudge amount is determined by the drawing's grid settings
///
///********************************************************************************************************************

- (IBAction)			moveLeft:(id) sender
{
	if ( ![self lockedOrHidden])
	{
		NSPoint		nd = [[self drawing] nudgeOffset];
		if([self moveSelectedObjectsByX:-nd.x byY:0])
		{
			[self scrollToSelectionInView:sender];
			[[self undoManager] setActionName:NSLocalizedString( @"Nudge Left", @"undo string for nudge left")];
		}
	}
}


///*********************************************************************************************************************
///
/// method:			moveRight:
/// scope:			public action method
///	overrides:		NSResponder
/// description:	nudges the selected objects right by one unit
/// 
/// parameters:		<sender> the action's sender (in fact the view)
/// result:			none
///
/// notes:			the nudge amount is determined by the drawing's grid settings
///
///********************************************************************************************************************

- (IBAction)			moveRight:(id) sender
{
	if ( ![self lockedOrHidden])
	{
		NSPoint		nd = [[self drawing] nudgeOffset];
		
		if([self moveSelectedObjectsByX:nd.x byY:0])
		{
			[self scrollToSelectionInView:sender];
			[[self undoManager] setActionName:NSLocalizedString( @"Nudge Right", @"undo string for nudge left")];
		}
	}
}


///*********************************************************************************************************************
///
/// method:			moveUp:
/// scope:			public action method
///	overrides:		NSResponder
/// description:	nudges the selected objects up by one unit
/// 
/// parameters:		<sender> the action's sender (in fact the view)
/// result:			none
///
/// notes:			the nudge amount is determined by the drawing's grid settings
///
///********************************************************************************************************************

- (IBAction)			moveUp:(id) sender
{
	if ( ![self lockedOrHidden])
	{
		NSPoint		nd = [[self drawing] nudgeOffset];
		if([self moveSelectedObjectsByX:0 byY:-nd.y])
		{
			[self scrollToSelectionInView:sender];
			[[self undoManager] setActionName:NSLocalizedString( @"Nudge Up", @"undo string for nudge left")];
		}
	}
}


///*********************************************************************************************************************
///
/// method:			moveDown:
/// scope:			public action method
///	overrides:		NSResponder
/// description:	nudges the selected objects down by one unit
/// 
/// parameters:		<sender> the action's sender (in fact the view)
/// result:			none
///
/// notes:			the nudge amount is determined by the drawing's grid settings
///
///********************************************************************************************************************

- (IBAction)			moveDown:(id) sender
{
	if ( ![self lockedOrHidden])
	{
		NSPoint		nd = [[self drawing] nudgeOffset];
		if([self moveSelectedObjectsByX:0 byY:nd.y])
		{
			[self scrollToSelectionInView:sender];
			[[self undoManager] setActionName:NSLocalizedString( @"Nudge Down", @"undo string for nudge left")];
		}
	}
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			selectMatchingStyle:
/// scope:			public action method
///	overrides:		-
/// description:	selects all objects having the same style as the single selected object
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (IBAction)			selectMatchingStyle:(id) sender
{
	#pragma unused(sender)
	
	if(![self lockedOrHidden])
	{
		DKStyle* style = [[self singleSelection] style];
		
		if ( style )
		{
			[self recordSelectionForUndo];
			[self selectObjectsWithStyle:style];
			[self scrollToSelectionInView:nil];
			[self commitSelectionUndoWithActionName:NSLocalizedString(@"Select Matching Styles", @"undo string for select matching styles")];
		}
	}
}


///*********************************************************************************************************************
///
/// method:			joinPaths:
/// scope:			public action method
///	overrides:
/// description:	connects any paths sharing an end point into a single path
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (IBAction)			joinPaths:(id) sender
{
	if(![self lockedOrHidden])
	{
		NSArray*		sp = [self selectedAvailableObjectsOfClass:[DKDrawablePath class]];
		NSEnumerator*	iter = [sp objectEnumerator];
		DKDrawablePath*	path;
		DKDrawablePath* a = nil;
		int				joinsMade = 0;
		
		if ([sp count] < 2 )
			return;
			
		BOOL colin = ([sender tag] == kGCMakeColinearJoinTag );
			
		// use a tolerance value equal to a grid square, or 2, whichever is greater:
		
		float tolerance = [[self drawing] nudgeOffset].x;
		
		if ( tolerance < 2 )
			tolerance = 2;
			
		[self recordSelectionForUndo];
		
		while(( path = [iter nextObject]))
		{
			// first path is "master" and dictates style etc of result
			
			if ( a == nil )
				a = path;
			else
			{
				if ([a join:path tolerance:tolerance makeColinear:colin])
				{
					[self removeObject:path];
					++joinsMade;
				}
			}
		}
		
		if( joinsMade > 0 )
			[self commitSelectionUndoWithActionName:NSLocalizedString(@"Join Paths", @"undo string for join paths")];
		else
			NSBeep();
	}
}


#pragma mark -
#pragma mark As a DKObjectOwnerLayer
///*********************************************************************************************************************
///
/// method:			hitTest:partCode:
/// scope:			public instance method
///	overrides:
/// description:	performs a hit test but also returns the hit part code
/// 
/// parameters:		<point> the point to test
///					<part> pointer to int, receives the partcode hit as a result of the test
/// result:			the object hit, or nil if none
///
/// notes:			see notes for hitTest:
///
///********************************************************************************************************************

- (DKDrawableObject*)	hitTest:(NSPoint) point partCode:(int*) part
{
	// test for hits in the layer's objects. When selections are drawn on top, this first does a top-down search of the selected
	// objects so that the user is better able to manipulate a control knob that lies on top of another object.
	
	NSEnumerator*		iter;
	DKDrawableObject*	o;
	int					pc;
	
	if ( [self drawsSelectionHighlightsOnTop])
	{
		iter = [[self selectedObjectsPreservingStackingOrder] reverseObjectEnumerator];
		
		while(( o = [iter nextObject]))
		{
			pc = [o hitPart:point];
		
			if ( pc != kGCDrawingEntireObjectPart && pc != kGCDrawingNoPart )
				return o;
		}
	}
	
	iter = [self objectTopToBottomEnumerator];
	
	while(( o = [iter nextObject]))
	{
		pc = [o hitPart:point];
	
		if ( pc != kGCDrawingNoPart )
			return o;
	}
	
	pc = kGCDrawingNoPart;
	
	if( part != NULL )
		*part = pc;
		
	return nil;
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
/// notes:			also deselects all objects
///
///********************************************************************************************************************

- (void)				removeAllObjects
{
	[self deselectAll];
	[super removeAllObjects];
}


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
/// notes:			also removes the object from the selection if it is selected
///
///********************************************************************************************************************

- (void)				removeObject:(DKDrawableObject*) obj
{
	if ([[self objects] containsObject:obj])
	{
		[super removeObject:obj];
		[self removeObjectFromSelection:obj];
	}
}


///*********************************************************************************************************************
///
/// method:			addObjects:fromPasteboard:atDropLocation:
/// scope:			public instance method
///	overrides:		DKObjectOwnerLayer
/// description:	add objects to the layer from the pasteboard
/// 
/// parameters:		<objects> a list of objects already dearchived from the pasteboard
///					<pb> the pasteboard (for information only)
///					<p> the drop location of the objects
/// result:			none
///
/// notes:			overrides the superclass so that the added objects are initially selected
///
///********************************************************************************************************************

- (void)				addObjects:(NSArray*) objects fromPasteboard:(NSPasteboard*) pb atDropLocation:(NSPoint) p
{
	[self recordSelectionForUndo];
	[super addObjects:objects fromPasteboard:pb atDropLocation:p];
	[self exchangeSelectionWithObjectsInArray:objects];
	
	// need to commit the selection change here but caller may want to set a more specific action name
	
	[self commitSelectionUndoWithActionName:NSLocalizedString(@"Drop", @"undo string for generic drop")];
}


#pragma mark -
#pragma mark As a DKLayer
///*********************************************************************************************************************
///
/// method:			drawRect:inView:
/// scope:			private instance method
///	overrides:		DKObjectOwnerLayer
/// description:	draws the layer and its contents on demand
/// 
/// parameters:		<rect> the area being updated
/// result:			none
///
/// notes:			called by the drawing when necessary to update the views. 
///
///********************************************************************************************************************

- (void)				drawRect:(NSRect) rect inView:(DKDrawingView*) aView
{
	if([[self drawing] activeLayer] == self )
	{
		NSEnumerator*		iter = [self objectBottomToTopEnumerator];
		DKDrawableObject*	obj;
		BOOL				screen = [NSGraphicsContext currentContextDrawingToScreen];
		BOOL				drawSelected = [self selectionVisible] && screen && ([self isActive] || [[self class] selectionIsShownWhenInactive]) && ![self locked];
		
		// draw the objects
		
		while(( obj = [iter nextObject]))
		{
			if ( [obj visible] && ( aView == nil || [aView needsToDrawRect:[obj bounds]]))
				[obj drawContentWithSelectedState:[self isSelectedObject:obj] && drawSelected && ![self drawsSelectionHighlightsOnTop]];
		}
		
		// draw the selection on top if set to do so
		
		if ([self drawsSelectionHighlightsOnTop] && drawSelected )
		{
			iter = [self objectBottomToTopEnumerator];
			
			while(( obj = [iter nextObject]))
			{
				if ([obj visible] && [self isSelectedObject:obj] && [aView needsToDrawRect:[obj bounds]])
					[obj drawSelectedState];
			}
		}
		
		// draw any pending object
		
		[self drawPendingObjectInView:aView];

		if ( m_inDragOp )
		{
			// draw a highlight around the edge of the layer
			
			NSRect ir = [[self drawing] interior];
			
			[[self selectionColour] set];
			NSFrameRectWithWidth( NSInsetRect( ir, -3, -3), 3.0 );
		}
	}
	else
		[super drawRect:rect inView:aView];
}


///*********************************************************************************************************************
///
/// method:			layerDidBecomeActiveLayer
/// scope:			public instance method
///	overrides:		DKLayer
/// description:	
/// 
/// parameters:		none
/// result:			none
///
/// notes:			refreshes the selection when the layer becomes active
///
///********************************************************************************************************************

- (void)				layerDidBecomeActiveLayer
{
	[super layerDidBecomeActiveLayer];
	[self refreshSelectedObjects];
}


///*********************************************************************************************************************
///
/// method:			layerDidResignActiveLayer
/// scope:			public instance method
///	overrides:		DKLayer
/// description:	
/// 
/// parameters:		none
/// result:			none
///
/// notes:			refreshes the selection when the layer resigns active state
///
///********************************************************************************************************************

- (void)				layerDidResignActiveLayer
{
	[super layerDidResignActiveLayer];
	[self refreshSelectedObjects];
}


///*********************************************************************************************************************
///
/// method:			menuForEvent:inView:
/// scope:			public instance method
///	overrides:		DKLayer
/// description:	builds a contextual menu for the layer
/// 
/// parameters:		<theEvent> the event thattriggered this call (right mouse click)
///					<view> the view that received it
/// result:			a menu
///
/// notes:			this first gives any hit object a chance to populate the menu, then adds the layer level commands
///
///********************************************************************************************************************

- (NSMenu *)			menuForEvent:(NSEvent*) theEvent inView:(NSView*) view
{
	NSMenu*		contextmenu = [[NSMenu alloc] initWithTitle:@"DL_ContextM"];	// title is never displayed
	NSMenuItem*	item;
	
	// if the mouse hit an object, give the object a chance to populate the menu.
	
	NSPoint mp = [view convertPoint:[theEvent locationInWindow] fromView:nil];
	DKDrawableObject* od = [self hitTest:mp];
	
	if ( od )
	{
		//[self replaceSelection:od];
		
		if ( [od populateContextualMenu:contextmenu])
			[contextmenu addItem:[NSMenuItem separatorItem]];
	
		// add the layer level commands
		// if >1 object selected, add group command

		if ([self countOfSelectedAvailableObjects] > 1 )
		{
			[[contextmenu addItemWithTitle:NSLocalizedString(@"Group", @"menu item for group") action:@selector( groupObjects: ) keyEquivalent:@"g"] setTarget:self];
		}

		[[contextmenu addItemWithTitle:NSLocalizedString(@"Copy", @"menu item for Copy") action:@selector( copy: ) keyEquivalent:@"c"] setTarget:self];
		[[contextmenu addItemWithTitle:NSLocalizedString(@"Duplicate", @"menu item for Duplicate") action:@selector( duplicate: ) keyEquivalent:@"d"] setTarget:self];
		[[contextmenu addItemWithTitle:NSLocalizedString(@"Delete", @"menu item for Delete") action:@selector( delete: ) keyEquivalent:@""] setTarget:self];
		
		if ([self countOfSelectedAvailableObjects] == 1 )
		{
			item = [contextmenu addItemWithTitle:NSLocalizedString(@"Arrange", @"menu item for Arrange") action:nil keyEquivalent:@""];

			NSMenu* am = [[NSMenu alloc] initWithTitle:@""];
			[[am addItemWithTitle:NSLocalizedString(@"Bring To Front", @"menu item for bring to front") action:@selector( objectBringToFront: ) keyEquivalent:@""] setTarget:self];
			[[am addItemWithTitle:NSLocalizedString(@"Bring Forwards", @"menu item for bring forwards") action:@selector( objectBringForward: ) keyEquivalent:@""] setTarget:self];
			[[am addItemWithTitle:NSLocalizedString(@"Send Backwards", @"menu item for send backwards") action:@selector( objectSendBackward: ) keyEquivalent:@""] setTarget:self];
			[[am addItemWithTitle:NSLocalizedString(@"Send To Back", @"menu item for send to back") action:@selector( objectSendToBack: ) keyEquivalent:@""] setTarget:self];
			
			[item setSubmenu:am];
			[am release];
		}
	}
	else
	{
		item = [contextmenu addItemWithTitle:NSLocalizedString(@"Paste", @"menu item for Paste") action:@selector( paste: ) keyEquivalent:@"v"];
		[item setTarget:self];
		[item setTag:kDKPasteCommandContextualMenuTag];
	}
	
	return [contextmenu autorelease];
}


- (void)				setLayerGroup:(DKLayerGroup*) aGroup
{
	[super setLayerGroup:aGroup];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(drawingSizeChanged:) name:kDKDrawingDidChangeSize object:[self drawing]];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(drawingSizeChanged:) name:kDKDrawingDidChangeMargins object:[self drawing]];
	[self setDragExclusionRect:[[self drawing] interior]];
}


///*********************************************************************************************************************
///
/// method:			setLocked:
/// scope:			public instance method
///	overrides:		DKLayer
/// description:	locks or unlocks the layer
/// 
/// parameters:		<locked> YES to lock, NO to unlock
/// result:			none
///
/// notes:			redraws the objects when the layer's lock state changes (selections are not shown for locked layers)
///
///********************************************************************************************************************

- (void)				setLocked:(BOOL) locked
{
	if ( locked != [self locked])
	{
		[super setLocked:locked];
		[self refreshSelectedObjects];
		[[NSNotificationCenter defaultCenter] postNotificationName:kGCLayerSelectionDidChange object:self];
	}
}


- (NSArray*)			pasteboardTypesForOperation:(DKPasteboardOperationType) op
{
	// if drag-targeting of objects is allowed, this adds the types declared by the objects to the types declared by the
	// layer itself. Currently only drag receives are allowed.
	
	NSMutableArray* types = [[super pasteboardTypesForOperation:op] mutableCopy];
	
	if([self allowsObjectsToBeTargetedByDrags] && ((op & kDKReadableTypesForDrag) != 0))
	{
		// append all the types from the object classes we can accept:
		
		NSArray*		eligibleClasses = [DKRuntimeHelper allClassesOfKind:[DKDrawableObject class]];
		NSEnumerator*	iter = [eligibleClasses objectEnumerator];
		Class			class;
		NSArray*		dragTypes;
		
		while(( class = [iter nextObject]))
		{
			if([class respondsToSelector:@selector(pasteboardTypesForOperation:)])
				dragTypes = [class pasteboardTypesForOperation:op];
			else
				dragTypes = nil;
				
			if ( dragTypes != nil )
				[types addUniqueObjectsFromArray:dragTypes];
		}
	}
	
	return [types autorelease];
}


#pragma mark -
#pragma mark As part of the NSDraggingDestination protocol

- (NSDragOperation)		draggingUpdated:(id <NSDraggingInfo>) sender
{
	NSDragOperation result = NSDragOperationCopy;
	
	if([self allowsObjectsToBeTargetedByDrags] && [sender draggingSource] != self )
	{
		// one problem here is that if the drag originated in another document, our native objects are also written as images.
		// It isn't sensible to add such images to an existing object, so we just need to do an additional check here to
		// see if what's being dragged is our native type - if so, don't try and target an individual object.
		
		NSPasteboard* pb = [sender draggingPasteboard];
		NSString*	availableType = [pb availableTypeFromArray:[NSArray arrayWithObject:kGCDrawableObjectPasteboardType]];
		
		if ( availableType != nil )
		{
			[self deselectAll];
			return NSDragOperationCopy;
		}
		NSPoint cp = [sender draggingLocation];
		cp = [[self currentView] convertPoint:cp fromView:nil];
		
	//	LogEvent_(kUserEvent, @"drag pt = %@", NSStringFromPoint( cp ));
		
		DKDrawableObject* target = [self hitTest:cp];
		
		if ( target != nil && ![target locked] && [target visible])
		{
			// there is an object under the mouse. If it is able to respond to the drag, select it:
			
			NSArray* types = [[target class] pasteboardTypesForOperation:kDKReadableTypesForDrag];
			availableType = [pb availableTypeFromArray:types];
			
			if( availableType != nil )
			{
				// yes, the object is able to respond to this drag, so select it:
				
				[self replaceSelectionWithObject:target];
			}
			else
			{
				[self deselectAll];
				result = NSDragOperationNone;
			}
		}
		else
			[self deselectAll];
	}

	return result;
}


- (BOOL)				performDragOperation:(id <NSDraggingInfo>) sender
{
	DKDrawableObject*	target = [self singleSelection];
	BOOL				wasHandled = NO;
	
	if( target != nil && [self allowsObjectsToBeTargetedByDrags] && [target respondsToSelector:@selector(performDragOperation:)] &&
		![target locked] && [target visible])
	{
		// can the target handle the drag?
		
		NSArray* types = [[target class] pasteboardTypesForOperation:kDKReadableTypesForDrag];
		NSPasteboard* pb = [sender draggingPasteboard];
		NSString*	availableType = [pb availableTypeFromArray:types];
		
		if( availableType != nil )
		{
			// yes, so pass the drag info to the target and let it get on with it
		//	LogEvent_(kReactiveEvent, @"passing drop to target = %@, availableType = %@", target, availableType );
		
			wasHandled = [target performDragOperation:sender];
		}
	}
	
	if( !wasHandled)
	{
		BOOL result = [super performDragOperation:sender];
		
		if ( result )
		{
			if([sender draggingSource] == self)
			{
				// delete the objects held in the temporary drag list, as we have dragged them to self
				
				[self removeObjects:m_objectsPendingDrag];
				[m_objectsPendingDrag release];
				m_objectsPendingDrag = nil;
			}
		}
		
		return result;
	}
	else
	{
		// remove the layer highlight
		
		m_inDragOp = NO;
		[self setNeedsDisplay:YES];
		return YES;
	}
}


	
#pragma mark -
#pragma mark As part of the NSDraggingSource protocol

- (void)	draggedImage:(NSImage*) anImage endedAt:(NSPoint) aPoint operation:(NSDragOperation) operation
{
	#pragma unused(anImage)
	#pragma unused( aPoint)
	#pragma unused(operation)
	
//	LogEvent_(kReactiveEvent, @"drag ended - cleaning up pending list");
	
	// if the pending drag list still exists, re-show all the objects in it
	
	if ( m_objectsPendingDrag != nil )
	{
		NSEnumerator* iter = [m_objectsPendingDrag objectEnumerator];
		DKDrawableObject* dko;
		
		while(( dko = [iter nextObject]))
			[dko setVisible:YES];
		
		[m_objectsPendingDrag release];
		m_objectsPendingDrag = nil;
	}
}


#pragma mark -
#pragma mark As an NSObject
- (void)				dealloc
{
//	LogEvent_(kReactiveEvent, @"dealloc - DKObjectDrawingLayer");
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[m_selectionUndo release];
	[m_selection release];
	
	[super dealloc];
}


///*********************************************************************************************************************
///
/// method:			forwardInvocation:
/// scope:			private instance method
///	overrides:		NSObject
/// description:	allows actions to be retargeted on single selected objects directly
/// 
/// parameters:		<invocation> the invocation
/// result:			none
///
/// notes:			commands can be implemented by a single selected object that wants to make use of them - this makes
///					it happen by forwarding unrecognised method calls to that object if possible. Note that for commands
///					that apply to all objects in a selection when there is more than one, you need to implement that here,
///					in the layer, not in the object. This is a convenience intended to streamline the design of
///					user commands that apply a unique instance only. Locked/Hidden objects won't receive the invocation.
///
///********************************************************************************************************************

- (void)				forwardInvocation:(NSInvocation*) invocation
{
	SEL aSelector = [invocation selector];
	
	DKDrawableObject* od = [self singleSelection];
 
    if ([od visible] && [od respondsToSelector:aSelector])
        [invocation invokeWithTarget:od];
    else
        [self doesNotRecognizeSelector:aSelector];
}


- (id)				init
{
	self = [super init];
	if (self != nil)
	{
		m_selection = [[NSMutableSet alloc] init];
		NSAssert(m_selectionUndo == nil, @"Expected init to zero");
		NSAssert(NSEqualRects(m_dragExcludeRect, NSZeroRect), @"Expected init to zero");
		
		m_selectionIsUndoable = [[self class] defaultSelectionChangesAreUndoable];
		m_drawSelectionOnTop = YES;
		m_selectionVisible = YES;
		m_allowDragTargeting = YES;
		
		if (m_selection == nil)
		{
			[self autorelease];
			self = nil;
		}
	}
	return self;
}


///*********************************************************************************************************************
///
/// method:			methodSignatureForSelector:
/// scope:			private instance method
///	overrides:		NSObject
/// description:	
/// 
/// parameters:		<aSelector>
/// result:			the method signature
///
/// notes:			
///
///********************************************************************************************************************

- (NSMethodSignature *)	methodSignatureForSelector:(SEL) aSelector
{
	NSMethodSignature* sig;
	
	sig = [super methodSignatureForSelector:aSelector];
	
	if ( sig == nil )
		sig = [[self singleSelection] methodSignatureForSelector:aSelector];
		
	return sig;
}


///*********************************************************************************************************************
///
/// method:			respondsToSelector:
/// scope:			private instance method
///	overrides:		NSObject
/// description:	
/// 
/// parameters:		<aSElector>
/// result:			YES if the selector is recognised, NO if not
///
/// notes:			locked objects are not rejected at this stage because you would not be able to pass the "unlock"
///					message, so the lock state is handled by the object itself.
///
///********************************************************************************************************************

- (BOOL)				respondsToSelector:(SEL) aSelector
{
	DKDrawableObject* od = [self singleSelection];

	return (([od visible] && [od respondsToSelector:aSelector]) || [super respondsToSelector:aSelector]);
}


#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)				encodeWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];
	
	[coder encodeBool:m_selectionIsUndoable forKey:@"selundo"];
	[coder encodeBool:m_drawSelectionOnTop forKey:@"selOnTop"];
	[coder encodeBool:[self allowsObjectsToBeTargetedByDrags] forKey:@"DKObjectDrawingLayer_allowDragTargets"];
}


- (id)					initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
//	LogEvent_(kFileEvent, @"decoding object drawing layer %@", self);

	self = [super initWithCoder:coder];
	if (self != nil)
	{
		m_selection = [[NSMutableSet alloc] init];
		NSAssert(m_selectionUndo == nil, @"Expected init to zero");
		[self setDragExclusionRect:[[self drawing] interior]];
		
		m_selectionIsUndoable = [[self class] defaultSelectionChangesAreUndoable];

		m_drawSelectionOnTop = [coder decodeBoolForKey:@"selOnTop"];
		m_selectionVisible = YES;
		
		if ([coder containsValueForKey:@"DKObjectDrawingLayer_allowDragTargets"])
			[self setAllowsObjectsToBeTargetedByDrags:[coder decodeBoolForKey:@"DKObjectDrawingLayer_allowDragTargets"]];
		else
			[self setAllowsObjectsToBeTargetedByDrags:YES];
		
		if (m_selection == nil)
		{
			[self autorelease];
			self = nil;
		}
	}

	return self;
}


#pragma mark -
#pragma mark As part of NSMenuValidation Protocol
///*********************************************************************************************************************
///
/// method:			validateMenuItem:
/// scope:			public instance method
///	overrides:		NSObject
/// description:	validates the menu items pertaining to actions that this layer can handle
/// 
/// parameters:		<item> the menu item to validate
/// result:			YES if it's enabled, NO if not
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				validateMenuItem:(NSMenuItem*) item
{
	SEL					action = [item action];
	BOOL				enable = NO;
	DKDrawableObject*	od = [self singleSelection];
	
	int alignCrit = [self alignmentMenuItemRequiredObjects:item];
	
	if ( alignCrit != 0 )
		return ([self countOfSelectedAvailableObjects] >= alignCrit );
	
	if ( action == @selector( cut: ) ||
		 action == @selector( delete: ) ||
		 action == @selector( lockObject: ) ||
		 action == @selector( hideObject:))
	{
		enable = ([self countOfSelectedAvailableObjects] > 0);
	}
	else if ( action == @selector( selectAll: ))
	{
		enable = ![self lockedOrHidden];
	}
	else if ( action == @selector( copy: ) ||
			  action == @selector( duplicate: ) ||
			  action == @selector( selectNone: ) ||
			  action == @selector( selectMatchingStyle: ))
	{
		enable = [self isSelectionNotEmpty];
	}
	else if ( action == @selector( unlockObject: ))
	{
		int locks = [[self selectedObjectsReturning:YES toSelector:@selector( locked )] count];
		enable = locks > 0;
	}
	else if ( action == @selector( revealHiddenObjects: ))
	{
		int hidden = [[self objectsReturning:NO toSelector:@selector( visible )] count];
		enable = hidden > 0;
	}
	else if ( action == @selector( paste: ))
	{
		enable = ([[NSPasteboard generalPasteboard] availableTypeFromArray:[self pasteboardTypesForOperation:kDKReadableTypesForPaste]] != nil);
	}
	else if ( action == @selector( groupObjects: ) ||
			  action == @selector( unionSelectedObjects: ) ||
			  action == @selector( clusterObjects: ) ||
			  action == @selector( combineSelectedObjects: ))
	{
		enable = ([self countOfSelectedAvailableObjects] > 1 );
	}
	else if ( action == @selector(setBooleanOpsFittingPolicy:))
	{
		enable = [self respondsToSelector:action];
		
		if ( enable )
			[item setState:((unsigned)[item tag] == [NSBezierPath pathUnflatteningPolicy])? NSOnState : NSOffState];
		else
			[item setState:NSOffState];
	}
	else if ( action == @selector( objectBringForward: ) ||
			  action == @selector( objectBringToFront: ))
	{
		enable = ( od != nil ) && ![od locked] && [od visible] && (od != [self topObject]);
	}
	else if ( action == @selector( objectSendBackward: ) ||
			  action == @selector( objectSendToBack: ))
	{
		enable = ( od != nil ) && ![od locked] && [od visible] && (od != [self bottomObject]);
	}
	else if ( action == @selector( diffSelectedObjects: ) ||
				action == @selector( intersectionSelectedObjects: ) ||
				action == @selector( xorSelectedObjects: ))
	{
		enable = ([self countOfSelectedAvailableObjects] == 2 );
	
	}
	else if (action == @selector(joinPaths:))
	{
		enable = ([[self selectedAvailableObjectsOfClass:[DKDrawablePath class]] count] > 1 );
	}
	else if ([self isSingleObjectSelected])
		enable = [[self singleSelection] validateMenuItem:item];

	enable |= [super validateMenuItem:item];
	
	return enable;
}


@end
