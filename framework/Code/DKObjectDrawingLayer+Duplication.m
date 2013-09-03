///**********************************************************************************************************************************
///  DKObjectDrawingLayer+Duplication.m
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 22/06/2007.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKObjectDrawingLayer+Duplication.h"

#import "DKDrawableObject.h"
#import "LogEvent.h"


@implementation DKObjectDrawingLayer (Duplication)
#pragma mark As a DKObjectDrawingLayer
///*********************************************************************************************************************
///
/// method:			polarDuplicate:centre:numberOfCopies:incrementAngle:rotateCopies:
/// scope:			public action method
///	overrides:
/// description:	duplicates one or more objects radially around a common centre
/// 
/// parameters:		<objectsToDuplicate> a list of DKDrawableObjects which will be copied
///					<centre> the location of the centre around which the copies are arranged
///					<numberOfCopies> how many copies to make
///					<incrementAngle> the angle in radians between each copy
///					<rotateCopies> YES to rotate the copies so that they lie on the radial, NO to keep them at their original rotation
/// result:			A list of DKDrawableObjects representing the copies. The originals are not copied to this array.
///
/// notes:			objects in the result are obtained by copying the objects in the original list, and so will have the
///					same types, styles, etc.
///
///********************************************************************************************************************

- (NSArray*)	polarDuplicate:(NSArray*) objectsToDuplicate
				centre:(NSPoint) centre
				numberOfCopies:(NSInteger) nCopies
				incrementAngle:(CGFloat) incRadians
				rotateCopies:(BOOL) rotCopies
{
	if (objectsToDuplicate == nil || [objectsToDuplicate count] < 1 || nCopies < 1 )
		return nil;	// nothing to copy
		
	NSMutableArray*	result = [[NSMutableArray alloc] init];
	NSInteger				i;
	
	for( i = 0; i < nCopies; ++i )
	{
		// copy each object
		
		NSEnumerator*		iter = [objectsToDuplicate objectEnumerator];
		DKDrawableObject*	o;
		DKDrawableObject*	copy;
		CGFloat				radius, angle, relAngle;
		NSPoint				location;
		
		while(( o = [iter nextObject]))
		{
			copy = [o copy];
			location = [copy location];
			
			relAngle = incRadians * ( i + 1 );
			radius = hypotf( location.x - centre.x, location.y - centre.y );
			angle = atan2f( location.y - centre.y, location.x - centre.x ) + relAngle;
			
			location.x = centre.x + cosf( angle ) * radius;
			location.y = centre.y + sinf( angle ) * radius;
			
			[copy setLocation:location];
			
			if ( rotCopies )
				[copy setAngle:[o angle] + relAngle];
		
			[result addObject:copy];
			[copy release];
		}
	}

	return [result autorelease];
}

				
///*********************************************************************************************************************
///
/// method:			linearDuplicate:offset:numberOfCopies:
/// scope:			public action method
///	overrides:
/// description:	duplicates one or more objects linearly
/// 
/// parameters:		<objectsToDuplicate> a list of DKDrawableObjects which will be copied
///					<offset> each copy is offset this much from the last
///					<numberOfCopies> how many copies to make
/// result:			A list of DKDrawableObjects representing the copies. The originals are not copied to this array.
///
/// notes:			objects in the result are obtained by copying the objects in the original list, and so will have the
///					same types, styles, etc.
///
///********************************************************************************************************************

- (NSArray*)	linearDuplicate:(NSArray*) objectsToDuplicate
				offset:(NSSize) offset
				numberOfCopies:(NSInteger) nCopies
{
	if (objectsToDuplicate == nil || [objectsToDuplicate count] < 1 || nCopies < 1 )
		return nil;	// nothing to copy
		
	NSMutableArray*	result = [[NSMutableArray alloc] init];
	NSInteger				i;
	
	for( i = 0; i < nCopies; ++i )
	{
		// copy each object
		
		NSEnumerator*		iter = [objectsToDuplicate objectEnumerator];
		DKDrawableObject*	o;
		DKDrawableObject*	copy;
		NSPoint				location;
		
		while(( o = [iter nextObject]))
		{
			copy = [o copy];
			location = [copy location];
			
			location.x += offset.width * ( i + 1 );
			location.y += offset.height * ( i + 1 );
			[copy setLocation:location];
			
			[result addObject:copy];
			[copy release];
		}
	}

	return [result autorelease];
}


///*********************************************************************************************************************
///
/// method:			autoPolarDuplicate:centre:
/// scope:			public action method
///	overrides:
/// description:	automatically polar duplicates object to fit a circle exactly
/// 
/// parameters:		<object> a single opject to be copied
///					<centre> the centre around which the object is located
/// result:			A list of DKDrawableObjects representing the copies. The originals are not copied to this array.
///
/// notes:			This computes the increment angle and number of copies needed to fit the object exactly into
///					a circle. The angle is that subtended by the object's logical bounds at the centre. The radius
///					will be adjusted outwards as necessary so that an integral number of copies fit a complete circle.
///
///********************************************************************************************************************

- (NSArray*)	autoPolarDuplicate:(DKDrawableObject*) object
				centre:(NSPoint) centre
{
	NSRect	lb = [object logicalBounds];
	NSPoint	ocp = [object location];//NSMakePoint( NSMidX( lb ), NSMidY( lb ));
	CGFloat	objAngle = atan2f( [object location].y - centre.y, [object location].x - centre.x );
	CGFloat	r, radius, incAngle;
	
	// r is radius of a circle that encloses the object
		
	r = hypotf( lb.size.width, lb.size.height )  / 2.0;
	
	radius = hypotf( ocp.x - centre.x, ocp.y - centre.y );
	incAngle = atanf( r / radius ) * 2.0;
	
	// how many fit in a circle?
	
	NSInteger number = (NSInteger)((2 * pi) / incAngle) + 1;
	
	// to fit this many exactly will require a small increase in radius
	
	incAngle = ( 2 * pi ) / (CGFloat)number;
	radius = r / tanf( incAngle * 0.5f );
	
	// set the duplication master at this radius from centre
	
	ocp.x = centre.x + radius * cosf( objAngle );
	ocp.y = centre.y + radius * sinf( objAngle );
	
	[object setLocation:ocp];
	
	LogEvent_(kReactiveEvent, @"auto polar, copies = %d, inc = %f", number, incAngle );
	
	return [self polarDuplicate:[NSArray arrayWithObject:object] centre:centre numberOfCopies:number - 1 incrementAngle:incAngle rotateCopies:YES];
}



///*********************************************************************************************************************
///
/// method:			concentricDuplicate:centre:numberOfCopies:scaleXBy:scaleYBy:
/// scope:			public action method
///	overrides:
/// description:	duplicates one or more objects concentrically around a common centre
/// 
/// parameters:		<objectsToDuplicate> a list of DKDrawableObjects which will be copied
///					<centre> the location of the centre around which the copies are arranged
///					<numberOfCopies> how many copies to make
///					<insetBy> the amount each copy is inset or outset (-ve) by 
/// result:			A list of DKDrawableObjects representing the copies. The originals are not copied to this array.
///
/// notes:			objects in the result are obtained by copying the objects in the original list, and so will have the
///					same types, styles, etc. While this works with paths, it works best with shapes or groups, because
///					paths don't implement setSize: and their location is at their top, left.
///
///********************************************************************************************************************

- (NSArray*)	concentricDuplicate:(NSArray*) objectsToDuplicate
				centre:(NSPoint) centre
				numberOfCopies:(NSInteger) nCopies
				insetBy:(CGFloat) inset
{
	if (objectsToDuplicate == nil || [objectsToDuplicate count] < 1 || nCopies < 1 )
		return nil;	// nothing to copy

	NSMutableArray* result = [NSMutableArray array];
	NSInteger				i;
	
	for( i = 0; i < nCopies; ++i )
	{
		NSEnumerator*		iter = [objectsToDuplicate objectEnumerator];
		DKDrawableObject*	o;
		DKDrawableObject*	copy;
		CGFloat				radius, angle, di, scale;
		NSPoint				location;
		NSSize				size;
		
		di = -inset * (i + 1) * 2.0;
		
		while(( o = [iter nextObject]))
		{
			copy = [o copy];
			location = [copy location];
			size = [copy size];
			
			radius = hypotf( location.x - centre.x, location.y - centre.y );
			angle = atan2f( location.y - centre.y, location.x - centre.x );
			size.width += di;
			size.height += di;
			
			scale = ( size.width / [copy size].width );
			
			location.x = centre.x + cosf( angle ) * radius * scale;
			location.y = centre.y + sinf( angle ) * radius * scale;
			
			[copy setSize:size];
			[copy setLocation:location];
			
			[result addObject:copy];
			[copy release];
		}
	}

	return result;
}


@end
