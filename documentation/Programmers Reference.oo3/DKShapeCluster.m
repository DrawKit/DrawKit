///**********************************************************************************************************************************
///  DKShapeCluster.m
///  DrawKit
///
///  Created by graham on 10/08/2007.
///  Released under the Creative Commons license 2007 Apptree.net.
///
/// 
///  This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 License.
///  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to
///  Creative Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105, USA.
///
///**********************************************************************************************************************************

#import "DKShapeCluster.h"


@implementation DKShapeCluster
#pragma mark As a DKShapeCluster
///*********************************************************************************************************************
///
/// method:			clusterWithObjects:masterObject:
/// scope:			public class method
/// overrides:		
/// description:	creates a new cluster from a set of objects
/// 
/// parameters:		<objects> the list of objects to be added to the cluster
///					<master> the master object
/// result:			a new autoreleased cluster object, which should be added to a suitable drawing layer before use
///
/// notes:			the master object must be also one of the objects in the list of objects, and must be a shape.
///
///********************************************************************************************************************

+ (DKShapeCluster*)		clusterWithObjects:(NSArray*) objects masterObject:(DKDrawableShape*) master;
{
	DKShapeCluster* cluster = [[DKShapeCluster alloc] initWithObjectsInArray:objects];

	[cluster setMasterObject:master];
	
	return [cluster autorelease];
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			setMasterObject
/// scope:			public instance method
/// overrides:		
/// description:	sets the master object for the cluster
/// 
/// parameters:		<master> the master object
/// result:			none
///
/// notes:			the master object must already be one of the objects in the group, and it must be a shape
///
///********************************************************************************************************************

- (void)				setMasterObject:(DKDrawableShape*) master
{
	if ([[self groupObjects] containsObject:master])
	{
		m_masterObjRef = master;	// not retained
		
		// sets the cluster's rotation centre to the master object's location
		
		NSPoint cp = [self convertPointToContainer:[master location]];
		[super moveKnob:kGCDrawableShapeOriginTarget toPoint:cp allowRotate:NO constrain:NO];
	}
}


///*********************************************************************************************************************
///
/// method:			masterObject
/// scope:			public instance method
/// overrides:		
/// description:	what is the cluster's master object?
/// 
/// parameters:		none
/// result:			the master object for this cluster
///
/// notes:			
///
///********************************************************************************************************************

- (DKDrawableShape*)	masterObject
{
	return m_masterObjRef;
}


#pragma mark -
#pragma mark As a DKDrawableShape
///*********************************************************************************************************************
///
/// method:			moveKnob:toPoint:allowRotate:constrain:
/// scope:			private instance method
/// overrides:		DKDrawableShape
/// description:	moves a knob to the given point, optionally rotating and/or constraining
/// 
/// parameters:		<knobPartCode> the knob partcode being moved
///					<p> the point to locate it at
///					<rotate> YES to allow rotation by any knob, NO otherwise
///					<constrain> YES to constrain aspect ratio
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				moveKnob:(int) knobPartCode toPoint:(NSPoint) p allowRotate:(BOOL) rotate constrain:(BOOL) constrain
{
	// the cluster as a whole must be resized/rotated but the mouse point is operating on the master object. Thus the point must
	// be mapped to the equivalent partcode on the cluster itself.
	
	NSPoint np = p;
	
	if ( knobPartCode != kGCDrawableShapeOriginTarget )
	{
		NSPoint	mk = [[self masterObject] pointForPartcode:knobPartCode];
		
		float dx, dy;
		
		dx = p.x - mk.x;
		dy = p.y - mk.y;
		
		np = [self pointForPartcode:knobPartCode];
		
		np.x += dx;
		np.y += dy;
	}
	[super moveKnob:knobPartCode toPoint:np allowRotate:rotate constrain:constrain];
}


///*********************************************************************************************************************
///
/// method:			setDragAnchorToPart:
/// scope:			private instance method
/// overrides:		DKDrawableShape
/// description:	sets the shape's offset to the location of the given knob partcode, after saving the current offset
/// 
/// parameters:		<part> a knob partcode
/// result:			none
///
/// notes:			part of the process of setting up the interactive dragging of a sizing knob
///
///********************************************************************************************************************

- (void)				setDragAnchorToPart:(int) part
{
	m_savedOffset = m_offset;
	
	NSPoint p = [[self masterObject] knobPoint:part];
	NSAffineTransform* ti = [self transformIncludingParent];
	[ti invert];
	
	p = [ti transformPoint:p];
	
	NSSize	offs;
	
	offs.width = p.x;
	offs.height = p.y;
	
	[self setOffset:offs];
}


#pragma mark -
#pragma mark As a DKDrawableObject
///*********************************************************************************************************************
///
/// method:			drawSelectedState
/// scope:			protected instance method
/// overrides:		DKDrawableShape
/// description:	draw the cluster in its selected state
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				drawSelectedState
{
	/*
	NSBezierPath* pp = [NSBezierPath bezierPathWithRect:[self canonicalPathBounds]];

	[pp transformUsingAffineTransform:[self transformIncludingParent]];
	[[[NSColor lightGrayColor] colorWithAlphaComponent:0.1] set];
	[pp fill];
	*/
	
	[[self masterObject] drawSelectedState];
	[self drawKnob:kGCDrawableShapeOriginTarget];
	
	if ( m_inRotateOp )
		[super drawSelectedState];
}


///*********************************************************************************************************************
///
/// method:			hitSelectedPart:forSnapDetection:
/// scope:			protected instance method
/// overrides:		DKDrawableShape
/// description:	detects which part of the cluster was hit
/// 
/// parameters:		<mp> the mouse point
///					<snap> YES if detecting a snap to object, NO otherwise
/// result:			a number which is the partcode hit
///
/// notes:			master object supplies the partcode
///
///********************************************************************************************************************

- (int)					hitSelectedPart:(NSPoint) mp forSnapDetection:(BOOL) snap
{
	return [[self masterObject] hitSelectedPart:mp forSnapDetection:snap];
}


///*********************************************************************************************************************
///
/// method:			rotationKnobPoint
/// scope:			private instance method
/// overrides:		DKDrawableShape
/// description:	gets the location of the rotation knob
/// 
/// parameters:		none
/// result:			a point, the position of the rotation knob
///
/// notes:			factored separately to allow override for special uses
///
///********************************************************************************************************************

- (NSPoint)				rotationKnobPoint
{
	return [[self masterObject] rotationKnobPoint];
}


///*********************************************************************************************************************
///
/// method:			setStyle:
/// scope:			public instance method
/// overrides:		DKShapeGroup
/// description:	when the cluster's style is set, the master object gets it
/// 
/// parameters:		<aStyle> a style object
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				setStyle:(DKStyle*) aStyle
{
	[[self masterObject] setStyle:aStyle];
}


///*********************************************************************************************************************
///
/// method:			style
/// scope:			public instance method
/// overrides:		DKShapeGroup
/// description:	returns the master object's style
/// 
/// parameters:		none
/// result:			the current style
///
/// notes:			
///
///********************************************************************************************************************

- (DKStyle*)		style
{
	return [[self masterObject] style];
}


@end
