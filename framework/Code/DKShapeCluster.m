/**
 * @author Graham Cox, Apptree.net
 * @author Graham Miln, miln.eu
 * @author Contributions from the community
 * @date 2005-2013
 * @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import "DKShapeCluster.h"

@implementation DKShapeCluster
#pragma mark As a DKShapeCluster

/** @brief Creates a new cluster from a set of objects
 * @note
 * The master object must be also one of the objects in the list of objects, and must be a shape.
 * @param objects the list of objects to be added to the cluster
 * @param master the master object
 * @return a new autoreleased cluster object, which should be added to a suitable drawing layer before use
 * @public
 */
+ (DKShapeCluster*)		clusterWithObjects:(NSArray*) objects masterObject:(DKDrawableShape*) master;
{
	DKShapeCluster* cluster = [[DKShapeCluster alloc] initWithObjectsInArray:objects];

	[cluster setMasterObject:master];
	
	return [cluster autorelease];
}

#pragma mark -

/** @brief Sets the master object for the cluster
 * @note
 * The master object must already be one of the objects in the group, and it must be a shape
 * @param master the master object
 * @public
 */
- (void)				setMasterObject:(DKDrawableShape*) master
{
	if ([[self groupObjects] containsObject:master])
	{
		m_masterObjRef = master;	// not retained
		
		// sets the cluster's rotation centre to the master object's location
		
		NSPoint cp = [self convertPointToContainer:[master location]];
		[super moveKnob:kDKDrawableShapeOriginTarget toPoint:cp allowRotate:NO constrain:NO];
	}
}

/** @brief What is the cluster's master object?
 * @return the master object for this cluster
 * @public
 */
- (DKDrawableShape*)	masterObject
{
	return m_masterObjRef;
}

#pragma mark -
#pragma mark As a DKDrawableShape

/** @param knobPartCode the knob partcode being moved
 * @param p the point to locate it at
 * @param rotate YES to allow rotation by any knob, NO otherwise
 * @param constrain YES to constrain aspect ratio
 * @private
 */
- (void)				moveKnob:(NSInteger) knobPartCode toPoint:(NSPoint) p allowRotate:(BOOL) rotate constrain:(BOOL) constrain
{
	// the cluster as a whole must be resized/rotated but the mouse point is operating on the master object. Thus the point must
	// be mapped to the equivalent partcode on the cluster itself.
	
	NSPoint np = p;
	
	if ( knobPartCode != kDKDrawableShapeOriginTarget )
	{
		NSPoint	mk = [[self masterObject] pointForPartcode:knobPartCode];
		
		CGFloat dx, dy;
		
		dx = p.x - mk.x;
		dy = p.y - mk.y;
		
		np = [self pointForPartcode:knobPartCode];
		
		np.x += dx;
		np.y += dy;
	}
	[super moveKnob:knobPartCode toPoint:np allowRotate:rotate constrain:constrain];
}

/** @brief Sets the shape's offset to the location of the given knob partcode, after saving the current offset
 * @note
 * Part of the process of setting up the interactive dragging of a sizing knob
 * @param part a knob partcode
 * @private
 */
- (void)				setDragAnchorToPart:(NSInteger) part
{
	[super setDragAnchorToPart:part];
	
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

/** @brief Draw the cluster in its selected state
 */
- (void)				drawSelectedState
{
	/*
	NSBezierPath* pp = [NSBezierPath bezierPathWithRect:[self canonicalPathBounds]];

	[pp transformUsingAffineTransform:[self transformIncludingParent]];
	[[[NSColor lightGrayColor] colorWithAlphaComponent:0.1] set];
	[pp fill];
	*/
	
	[[self masterObject] drawSelectedState];
	[self drawKnob:kDKDrawableShapeOriginTarget];
	
	if ( m_inRotateOp )
		[super drawSelectedState];
}

/** @brief Detects which part of the cluster was hit
 * @note
 * Master object supplies the partcode
 * @param mp the mouse point
 * @param snap YES if detecting a snap to object, NO otherwise
 * @return a number which is the partcode hit
 */
- (NSInteger)					hitSelectedPart:(NSPoint) mp forSnapDetection:(BOOL) snap
{
	return [[self masterObject] hitSelectedPart:mp forSnapDetection:snap];
}

/** @brief Gets the location of the rotation knob
 * @note
 * Factored separately to allow override for special uses
 * @return a point, the position of the rotation knob
 * @private
 */
- (NSPoint)				rotationKnobPoint
{
	return [[self masterObject] rotationKnobPoint];
}

/** @brief When the cluster's style is set, the master object gets it
 * @param aStyle a style object
 * @public
 */
- (void)				setStyle:(DKStyle*) aStyle
{
	[[self masterObject] setStyle:aStyle];
}

/** @brief Returns the master object's style
 * @return the current style
 * @public
 */
- (DKStyle*)		style
{
	return [[self masterObject] style];
}

@end

