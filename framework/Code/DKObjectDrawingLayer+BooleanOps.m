///**********************************************************************************************************************************
///  DKObjectDrawingLayer+BooleanOps.m
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 03/11/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#ifdef qUseGPC

#import "DKObjectDrawingLayer+BooleanOps.h"
#import "DKGeometryUtilities.h"
#import "DKDrawablePath.h"
#import "DKDrawableShape.h"
#import "NSBezierPath+GPC.h"
#import "NSBezierPath+Combinatorial.h"


@implementation DKObjectDrawingLayer (BooleanOps)
#pragma mark As a DKObjectDrawingLayer
///*********************************************************************************************************************
///
/// method:			unionSelectedObjects:
/// scope:			public action method
///	overrides:
/// description:	forms the union of the selected objects and replaces the selection with the result
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			result adopts the style of the topmost object contributing.
///
///********************************************************************************************************************

- (IBAction)		unionSelectedObjects:(id) sender
{
	#pragma unused(sender)
	
	NSArray*			sel = [self selectedAvailableObjects];
	NSEnumerator*		iter = [sel objectEnumerator];
	DKDrawableShape*	obj, *firstObj;
	DKDrawableShape*	result;
	NSBezierPath*		rp = nil;
	
	// at least 2 objects required:
	
	if([sel count] < 2)
		return;
	
	firstObj = [sel lastObject];
		
	while(( obj = [iter nextObject]))
	{
		// if result path is nil, this is the first object which is the one we'll keep unioning.
	
		if ( rp == nil )
			rp = [obj renderingPath];
		else
			rp = [rp pathFromUnionWithPath:[obj renderingPath]];
	}
	
	// make a new shape from the result path, inheriting style & user data of the topmost object
	
	[self recordSelectionForUndo];

	if([firstObj respondsToSelector:@selector(adoptPath:)])
	{
		[firstObj adoptPath:rp];
		result = firstObj;
		
		NSMutableArray* modSel = [sel mutableCopy];
		[modSel removeObject:result];
		[self removeObjectsInArray:modSel];
		[modSel release];
	}
	else
	{
		result = [[DKDrawableObject classForConversionRequestFor:[DKDrawableShape class]] drawableShapeWithBezierPath:rp withStyle:[firstObj style]];
		[result setUserInfo:[firstObj userInfo]];
		[result willBeAddedAsSubstituteFor:firstObj toLayer:self];
	
		NSInteger xi = [self indexOfObject:firstObj];

		[self addObject:result atIndex:xi];
		[self removeObjectsInArray:sel];
	}
	
	[self replaceSelectionWithObject:result];
	[self commitSelectionUndoWithActionName:NSLocalizedString(@"Union", @"undo string for union op")];
}


///*********************************************************************************************************************
///
/// method:			diffSelectedObjects:
/// scope:			public action method
///	overrides:
/// description:	subtracts the topmost shape from the other.
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			requires exactly two contributing objects. If the shapes don't overlap, this does nothing. The
///					'cutter' object is removed from the layer.
///
///********************************************************************************************************************

- (IBAction)		diffSelectedObjects:(id) sender
{
	#pragma unused(sender)
	
	NSArray*	sel = [self selectedAvailableObjects];
	
	if ([sel count] == 2 )
	{
		DKDrawableShape		*a, *b;
		NSBezierPath*		rp;
		
		// get the objects in shape form
		
		a = [sel objectAtIndex:0];	// lower
		b = [sel objectAtIndex:1];	// upper
		
		// do they intersect at all? If not, nothing to do.
		
		if( ! NSIntersectsRect([a bounds], [b bounds]))
		{
			NSBeep();
			return;
		}
		
		// form the result
	
		rp = [[a renderingPath] pathFromDifferenceWithPath:[b renderingPath]];
		
		// if the result is not empty, turn it into a new shape
		
		if (! [rp isEmpty])
		{
			[self recordSelectionForUndo];
			
			// if the target object can be modified in place, do so. This allows images to be used as well as shapes.

			if([a respondsToSelector:@selector(adoptPath:)])
				[a adoptPath:rp];
			else
			{
				// convert to a shape. This copes with the case where one of the source objects is a path subclass
				// that will not work when simply setting its path (e.g. DKRegularPolygon)
			
				DKDrawableShape* newShape = [[DKDrawableObject classForConversionRequestFor:[DKDrawableShape class]] drawableShapeWithBezierPath:rp withStyle:[a style]];
				[newShape setUserInfo:[a userInfo]];
				[newShape willBeAddedAsSubstituteFor:a toLayer:self];
				
				NSInteger xi = [self indexOfObject:a];
				
				[self removeObject:a];
				[self addObject:newShape atIndex:xi];

				a = newShape;
			}
			
			[self removeObject:b]; // if you wish to leave the "cutter" in the layer, remove this line
			[self replaceSelectionWithObject:a];
			[self commitSelectionUndoWithActionName:NSLocalizedString(@"Difference", @"undo string for diff op")];
		}
	}
}


///*********************************************************************************************************************
///
/// method:			intersectionSelectedObjects:
/// scope:			public action method
///	overrides:
/// description:	replaces a pair of objects by their intersection.
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			requires exactly two contributing objects. If the objects don't intersect, does nothing. The result
///					adopts the style of the lower contributing object
///
///********************************************************************************************************************

- (IBAction)		intersectionSelectedObjects:(id) sender
{
	#pragma unused(sender)
	
	NSArray*	sel = [self selectedAvailableObjects];
	
	if ([sel count] == 2 )
	{
		DKDrawableShape		*a, *b;
		NSBezierPath*		rp;
		
		// get the objects in shape form
		
		a = [sel objectAtIndex:0];	// lower
		b = [sel objectAtIndex:1];	// upper
		
		// are they likely to intersect?
		
		if( ! NSIntersectsRect([a bounds], [b bounds]))
		{
			NSBeep();
			return;
		}
		
		// form the result
		
		NSBezierPath* pa, *pb;
		
		pa = [a renderingPath];
		pb = [b renderingPath];
	
		rp = [pa pathFromIntersectionWithPath:pb];
		
		// if the result is not empty, turn it into a new shape or modify the lower one in place
		
		if (! [rp isEmpty])
		{
			[self recordSelectionForUndo];
			if([a respondsToSelector:@selector(adoptPath:)])
			{
				[a adoptPath:rp];
				[self removeObject:b];
				[self replaceSelectionWithObject:a];
			}
			else
			{
				DKDrawableShape* shape = [[DKDrawableObject classForConversionRequestFor:[DKDrawableShape class]] drawableShapeWithBezierPath:rp withStyle:[a style]];
				
				[shape setUserInfo:[a userInfo]];
				[shape willBeAddedAsSubstituteFor:a toLayer:self];

				NSInteger xi = [self indexOfObject:a];
				
				[self addObject:shape atIndex:xi];
				[self removeObjectsInArray:sel];
				[self replaceSelectionWithObject:shape];
			}
			[self commitSelectionUndoWithActionName:NSLocalizedString(@"Intersection", @"undo string for sect op")];
		}
	}
}


///*********************************************************************************************************************
///
/// method:			xorSelectedObjects:
/// scope:			public action method
///	overrides:
/// description:	replaces a pair of objects by their exclusive-OR.
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			requires exactly two contributing objects. If the objects don't intersect, does nothing. The result
///					adopts the syle of the topmost contributing object
///
///********************************************************************************************************************

- (IBAction)		xorSelectedObjects:(id) sender
{
	[self combineSelectedObjects:sender];
	[[self undoManager] setActionName:NSLocalizedString(@"Exclusive Or", @"undo string for xor op")];
}


///*********************************************************************************************************************
///
/// method:			divideSelectedObjects:
/// scope:			public action method
///	overrides:
/// description:	replaces a pair of objects by their divided replacements.
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			requires exactly two contributing objects. If the objects don't intersect, does nothing. A division
///					splits two overlapping paths at their intersecting points into as many pieces as necessary. The
///					original, objects are replaced by the pieces. Pieces derived from each path retain the styles of
///					the original paths.
///
///********************************************************************************************************************
- (IBAction)		divideSelectedObjects:(id) sender
{
	#pragma unused(sender)
	
	NSArray*	sel = [self selectedAvailableObjects];
	
	if ([sel count] == 2 )
	{
		DKDrawableShape		*a, *b;
		NSBezierPath*		rp;
		
		// get the objects in shape form
		
		a = [sel objectAtIndex:0];	// lower
		b = [sel objectAtIndex:1];	// upper
		
		// are they likely to intersect?
		
		if( ! NSIntersectsRect([a bounds], [b bounds]))
		{
			NSBeep();
			return;
		}
		
		// perform the division
		
		NSArray* parts = [[a renderingPath] dividePathWithPath:[b renderingPath]];
		
		// turn the parts into a set of new objects. Parts consists of two sub-arrays each listing the parts from
		// each source path.
		
		NSUInteger i;
		NSMutableArray*	newShapes = [NSMutableArray array];
		
		for( i = 0; i < [parts count]; ++i )
		{
			NSArray*		pieces = [parts objectAtIndex:i];
			NSEnumerator*	iter = [pieces objectEnumerator];
			
			while(( rp = [iter nextObject]))
			{
				if( ![rp isEmpty])
				{
					DKDrawableShape* shape = [[DKDrawableObject classForConversionRequestFor:[DKDrawableShape class]] drawableShapeWithBezierPath:rp];
					
					if ( shape != nil )
					{
						if( i == 0 )
							[shape setStyle:[a style]];
						else
							[shape setStyle:[b style]];
				
						[newShapes addObject:shape];
					}
				}
			}
		}
		
		// add all the new shapes, replacing the old ones
		
		[self recordSelectionForUndo];
		[self addObjectsFromArray:newShapes];
		[self removeObjectsInArray:sel];
		[self exchangeSelectionWithObjectsFromArray:newShapes];
		[self commitSelectionUndoWithActionName:NSLocalizedString(@"Divide", @"undo string for divide op")];
	}
}


///*********************************************************************************************************************
///
/// method:			combineSelectedObjects:
/// scope:			public action method
///	overrides:
/// description:	replaces a pair of objects by combining their paths.
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			requires two or more contributing objects. The result adopts the syle of the topmost
///					contributing object. The result can act like a union, difference or xor depending on the relative
///					disposition of the contributing paths.
///
///********************************************************************************************************************

- (IBAction)		combineSelectedObjects:(id) sender
{
	#pragma unused(sender)
	
	NSArray*	sel = [self selectedAvailableObjects];
	
	if ([sel count] > 1 )
	{
		DKDrawableObject*	o, *firstObj, *shape;
		NSBezierPath*		rp;
		
		rp = [NSBezierPath bezierPath];
		NSEnumerator*		iter = [sel objectEnumerator];
		
		firstObj = [sel lastObject];
		
		while(( o = [iter nextObject]))
			[rp appendBezierPath:[o renderingPath]];

		// form the result
		
		[rp setWindingRule:NSEvenOddWindingRule];
		
		// if the result is not empty, turn it into a new shape
		
		if (! [rp isEmpty])
		{
			[self recordSelectionForUndo];
			
			if([firstObj respondsToSelector:@selector(adoptPath:)])
			{
				[(DKDrawableShape*)firstObj adoptPath:rp];
				
				NSMutableArray* modSel = [sel mutableCopy];
				[modSel removeObject:firstObj];
				[self removeObjectsInArray:modSel];
				[modSel release];
				
				shape = firstObj;
			}
			else
			{
				shape = [[DKDrawableObject classForConversionRequestFor:[DKDrawableShape class]] drawableShapeWithBezierPath:rp withStyle:[firstObj style]];
				
				[shape setUserInfo:[firstObj userInfo]];
				[shape willBeAddedAsSubstituteFor:firstObj toLayer:self];

				NSInteger xi = [self indexOfObject:firstObj];
				
				[self addObject:shape atIndex:xi];
				[self removeObjectsInArray:sel];
			}
			
			[self replaceSelectionWithObject:shape];
			[self commitSelectionUndoWithActionName:NSLocalizedString(@"Append", @"undo string for combine op")];
		}
	}
}


///*********************************************************************************************************************
///
/// method:			setBooleanOpsFittingPolicy:
/// scope:			public action method
///	overrides:
/// description:	sets the unflattening (smoothing) policy for GPC-based operations.
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			the sender's tag is interpreted as the policy value.
///
///********************************************************************************************************************

- (IBAction)		setBooleanOpsFittingPolicy:(id) sender
{
	[NSBezierPath setPathUnflatteningPolicy:[sender tag]];
}


///*********************************************************************************************************************
///
/// method:			cropToPath:
/// scope:			public action method
///	overrides:
/// description:	crops (intersects) all objects in this layer with the given path.
/// 
/// parameters:		<croppingPath> the path to crop to
/// result:			the array of objects remaining after the operation
///
/// notes:			this can dramatically alter the composition of the layer, but is undoable. Objects outside the
///					path are deleted. Objects fully enclosed are not changed. Objects that intersect the path are
///					modified by intersecting them with the croppingPath. The object's geometry but not their styles
///					are affected.
///
///********************************************************************************************************************

- (NSArray*)			cropToPath:(NSBezierPath*) croppingPath
{
	// first gather the subset of objects that could be affected. Any others are deleted.
	
	NSAssert( croppingPath != nil, @"cannot crop to a nil path");
	NSAssert(![croppingPath isEmpty], @"cannot crop to an empty path");
	NSAssert(!NSIsEmptyRect([croppingPath bounds]), @"cannot crop to an empty path (empty bounds)");
	
	NSArray* cropCandidates = [self objectsInRect:[croppingPath bounds]];
	
	if([cropCandidates count] > 0)
	{
		// remove any selection:
		
		[self deselectAll];
		
		// find the remainder to be deleted
		
		NSMutableSet* remaining = [NSMutableSet setWithArray:[self objects]];
		[remaining minusSet:[NSSet setWithArray:cropCandidates]];
		
		// initially do not unflatten at all - later we can selectively unflatten paths
		// that were actually cropped depending on the original policy.
		
		DKPathUnflatteningPolicy ufp = [NSBezierPath pathUnflatteningPolicy];
		[NSBezierPath setPathUnflatteningPolicy:kDKPathUnflattenNever];
		
		NSEnumerator*		iter = [cropCandidates objectEnumerator];
		DKDrawableObject*	od;
		NSBezierPath*		path;
		NSBezierPath*		cPath;
		
		while((od = [iter nextObject]))
		{
			if ([od isKindOfClass:[DKDrawablePath class]])
				path = [(DKDrawablePath*)od path];
			else
				path = [(DKDrawableShape*)od transformedPath];
		
			cPath = [path pathFromIntersectionWithPath:croppingPath];

			// if cPath is empty, it means that the object is cropped out, so add it to the list of "to be deleted"
			
			if([cPath isEmpty])
				[remaining addObject:od];
			else
			{
				// if the intersected path has the same bounds as the original, it is fully enclosed, so can be ignored.
				
				if( !AreSimilarRects([cPath bounds], [path bounds], 0.001))
				{
					// the object was cropped, so modify its path "in place". At this point, we might unflatten
					// if that was the original policy.
					
					if( ufp != kDKPathUnflattenNever )
						cPath = [cPath bezierPathByUnflatteningPath];
					
					if ([od isKindOfClass:[DKDrawablePath class]])
						[(DKDrawablePath*)od setPath:cPath];
					else
						[(DKDrawableShape*)od adoptPath:cPath];
				}
			}
		}
		
		// restore the original policy:
		
		[NSBezierPath setPathUnflatteningPolicy:ufp];

		// delete the objects excluded:
		
		[self removeObjectsInArray:[remaining allObjects]];
		
		// let undo manager know what we did:
		
		[[self undoManager] setActionName:NSLocalizedString(@"Crop", @"undo string for Crop")];
	}	
	
	return [self objects];
}


///*********************************************************************************************************************
///
/// method:			cropToRect:
/// scope:			public action method
///	overrides:
/// description:	crops (intersects) all objects in the layer with the given rect.
/// 
/// parameters:		<croppingRect> the rect to crop to
/// result:			the array of objects remaining after the operation
///
/// notes:			does nothing and returns nil if the rect is empty.
///
///********************************************************************************************************************

- (NSArray*)			cropToRect:(NSRect) croppingRect
{
	if( !NSIsEmptyRect( croppingRect ))
		return [self cropToPath:[NSBezierPath bezierPathWithRect:croppingRect]];
	else
		return nil;
}


///*********************************************************************************************************************
///
/// method:			intersectingDrawablesinArray:
/// scope:			public action method
///	overrides:
/// description:	tests the bounds of the objects in the array against each other for intersection. Returns NO if
///					there are no intersections, YES if there is at least one.
/// 
/// parameters:		<array> an array of DKDrawableObjects
/// result:			YES if there are any intersections, NO otherwise
///
/// notes:			the worst case is no intersections, in which case this is an O(n^2) operation. However this still
///					may be preferable to performing certain boolean ops on the object's paths.
///
///********************************************************************************************************************

- (BOOL)				intersectingDrawablesinArray:(NSArray*) array
{
	NSAssert( array != nil, @"can't test nil array");
	
	// if list is 0 or 1 items, no intersection because there are not multiple objects
	
	if([array count] < 2 )
		return NO;
		
	NSRect a, b;
		
	// special faster case - if array contains 2 objects, just test them directly without iterating
	
	if([array count] == 2 )
	{
		a = [[array objectAtIndex:0] bounds];
		b = [[array objectAtIndex:1] bounds];
		
		return NSIntersectsRect( a, b );
	}
	else
	{
		NSEnumerator*		outer = [array objectEnumerator];
		DKDrawableObject*	oa;
		DKDrawableObject*	ob;
		
		while(( oa = [outer nextObject]))
		{
			a = [oa bounds];
			NSEnumerator*	inner = [array objectEnumerator];
			
			while(( ob = [inner nextObject]))
			{
				if ( oa != ob )
				{
					b = [ob bounds];
					
					 if( NSIntersectsRect( a, b ))
						return YES;
				}
			}
		}
	}
	
	return NO;
}



@end

#endif /* defined (qUseGPC) */
