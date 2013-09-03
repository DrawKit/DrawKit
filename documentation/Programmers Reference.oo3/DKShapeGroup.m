///**********************************************************************************************************************************
///  DKShapeGroup.m
///  DrawKit
///
///  Created by graham on 28/10/2006.
///  Released under the Creative Commons license 2006 Apptree.net.
///
/// 
///  This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 License.
///  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to
///  Creative Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105, USA.
///
///**********************************************************************************************************************************

#import "DKShapeGroup.h"
#import "DKGeometryUtilities.h"
#import "DKDrawablePath.h"
#import "DKDrawing.h"
#import "DKStyle.h"
#import "DKObjectDrawingLayer.h"
#import "NSBezierPath+Geometry.h"
#import "DKSelectionPDFView.h"
#import "LogEvent.h"


@interface DKShapeGroup (Private)
- (void)	invalidateCache;
- (void)	updateCache;
- (void)	drawUntransformedContent;

@end

@implementation DKShapeGroup
#pragma mark As a DKShapeGroup
///*********************************************************************************************************************
///
/// method:			groupWithBezierPaths:objectType:style:
/// scope:			public class method
/// overrides:		
/// description:	creates a group of shapes or paths from a list of bezier paths
/// 
/// parameters:		<paths> a list of NSBezierPath objects
///					<type> a value indicating what type of objects the group should consist of. Can be 0 = shapes or
///					1 = paths. All other values are reserved.
///					<style> a style object to apply to each new shape or path as it is created; pass nil to create
///					the objects with the default style initially.
/// result:			a new group object consisting of a set of other objects built from the supplied paths
///
/// notes:			this constructs a group from a list of bezier paths by wrapping a drawable around each path then
///					grouping the result. While general purpose in nature, this is primarily to support the construction
///					of a group containing text glyphs from a text shape object. The group's location is set to the
///					centre of the union of the bounds of all created objects, which in turn depends on the paths' positions.
///					caller may wish to move the group before adding it to a layer.
///
///********************************************************************************************************************

+ (DKShapeGroup*)		groupWithBezierPaths:(NSArray*) paths objectType:(int) type style:(DKStyle*) style
{
	NSMutableArray*		objects = [NSMutableArray array];
	NSEnumerator*		iter = [paths objectEnumerator];
	NSBezierPath*		path;
	DKDrawableObject*	od;
	
	while(( path = [iter nextObject]))
	{
		if ( ![path isEmpty] && !NSEqualSizes([path bounds].size, NSZeroSize))
		{
			if ( type == kGCCreateGroupWithShapes )
				od = [DKDrawableShape drawableShapeWithPath:path];
			else if ( type == kGCCreateGroupWithPaths )
				od = [DKDrawablePath drawablePathWithPath:path];
			else
				return nil;	// illegal
			
			if ( style )	
				[od setStyle:style];
				
			[objects addObject:od];
		}
	}
	
	return [self groupWithObjects:objects];
}


///*********************************************************************************************************************
///
/// method:			groupWithObjects:
/// scope:			public class method
/// overrides:		
/// description:	creates a group from a list of existing objects
/// 
/// parameters:		<objects> a list of drawable objects
/// result:			a new group object consisting of the objects supplied
///
/// notes:			initial location is at the centre of the rectangle that bounds all of the contributing objects.
///					the objects can be newly created or already existing as part of a drawing. Grouping the objects
///					will change the parent of the object but not the owner until the group is placed. The group should
///					be added to a drawing layer after creation. The higher level "group" command in the drawing layer
///					class will set up a group from the selection.
///
///********************************************************************************************************************

+ (DKShapeGroup*)		groupWithObjects:(NSArray*) objects
{
	DKShapeGroup* group = [[DKShapeGroup alloc] initWithObjectsInArray:objects];
	
	return [group autorelease];
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			initWithObjectsInArray:
/// scope:			public instance method
/// overrides:		
/// description:	initialises a group from a list of existing objects
/// 
/// parameters:		<objects> a list of drawable objects
/// result:			the group object
///
/// notes:			designated initialiser. initial location is at the centre of the rectangle that bounds all of
///					the contributing objects.
///					the objects can be newly created or already existing as part of a drawing. Grouping the objects
///					will change the parent of the object but not the owner until the group is placed. The group should
///					be added to a drawing layer after creation. The higher level "group" command in the drawing layer
///					class will set up a group from the selection.
///
///********************************************************************************************************************

- (id)					initWithObjectsInArray:(NSArray*) objects
{
	self = [super init];
	if (self != nil)
	{
		[self setGroupObjects:objects];
		NSAssert(!m_transformVisually, @"Expected init to NO");
				
		if (m_objects == nil)
		{
			[self autorelease];
			self = nil;
		}
	}
	if (self != nil)
	{
		NSBezierPath* path = [NSBezierPath bezierPathWithRect:[[self class] unitRectAtOrigin]];
		[self setPath:path];
		
		//[self setCacheOptions:kDKGroupCacheUsingCGLayer];
	}
	return self;
}


#pragma mark -
#pragma mark - setting up the group
///*********************************************************************************************************************
///
/// method:			setGroupObjects:
/// scope:			private instance method
/// overrides:		
/// description:	sets up the group state from the original set of objects
/// 
/// parameters:		<objects> the set of objects to be grouped
/// result:			none
///
/// notes:			this sets the initial size and location of the group, and adjusts the position of each object so
///					it is relative to the group, not the original drawing. It also sets the parent member of each object
///					to the group so that the group's transform is applied when the objects are drawn.
///
///********************************************************************************************************************

- (void)				setGroupObjects:(NSArray*) objects
{
	// set the group's geometry:
	
	[self calcBoundingRectOfObjects:objects];
	[self setSize:m_bounds.size];
	[self moveToPoint:NSMakePoint( NSMidX( m_bounds ), NSMidY( m_bounds ))];
	
	// become the owner of these objects - sets object's container to self (undoably):
	
	[self setObjects:objects];
	
	// set the initial coordinates for the objects so they are relative to the group location

	NSPoint	loc;
	
	NSEnumerator*		iter = [m_objects objectEnumerator];
	DKDrawableObject*	obj;

	while(( obj = [iter nextObject]))
	{
		loc = [self convertPointFromContainer:[obj location]];
		[obj moveToPoint:loc];
	}
}


///*********************************************************************************************************************
///
/// method:			groupObjects
/// scope:			public instance method
/// overrides:		
/// description:	gets the list of objects contained by the group
/// 
/// parameters:		none
/// result:			the list of contained objects
///
/// notes:			
///
///********************************************************************************************************************

- (NSArray*)			groupObjects
{
	return m_objects;
}


///*********************************************************************************************************************
///
/// method:			setObjects:
/// scope:			protected instance method
/// overrides:		
/// description:	sets the current list of objects to the given objects
/// 
/// parameters:		<objects> the objects to be grouped
/// result:			none
///
/// notes:			this is a low level method called by setGroupObjects: it implements the undoable part of building
///					a group. It should not be directly called.
///
///********************************************************************************************************************

- (void)				setObjects:(NSArray*) objects
{
	if ( objects != [self groupObjects])
	{
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setObjects:) object:[self groupObjects]];
		
		[objects retain];
		[m_objects release];
		m_objects = objects;
		
		[m_objects makeObjectsPerformSelector:@selector(setContainer:) withObject:self];
	}
}


///*********************************************************************************************************************
///
/// method:			calcBoundingRectOfObjects:
/// scope:			protected instance method
/// overrides:		
/// description:	computes the initial overall bounding rect of the constituent objects
/// 
/// parameters:		<objects> the objects to be grouped
/// result:			none
///
/// notes:			this sets the _bounds member to the union of the apparent bounds of the constituent objects. This
///					rect represents the original size and position of the group, and does not change even if the group
///					is moved or resized - transforms are calculated by comparing the original bounds to the instantaneous
///					size and position.
///
///********************************************************************************************************************

- (void)				calcBoundingRectOfObjects:(NSArray*) objects
{
	NSRect				bounds = NSZeroRect;
	NSEnumerator*		iter = [objects objectEnumerator];
	DKDrawableObject*	obj;
	
	// WARNING!! Do NOT use NSUnionRect here - it doesn't work when bounds height or width is 0 as is the case with
	// paths consisting of straight lines at orthogonal angles
	
	while(( obj = [iter nextObject]))
		bounds = UnionOfTwoRects( bounds, [obj logicalBounds]);
		
	m_bounds = bounds;
}


///*********************************************************************************************************************
///
/// method:			extraSpaceNeededByObjects:
/// scope:			protected instance method
/// overrides:		
/// description:	computes the extra space needed for the objects
/// 
/// parameters:		<objects> the objects to be grouped
/// result:			a size, the maximum width and height needed to be added to the logical bounds to accomodate the
///					objects visually.
///
/// notes:			
///
///********************************************************************************************************************

- (NSSize)				extraSpaceNeededByObjects:(NSArray*) objects
{
	NSEnumerator*		iter = [objects objectEnumerator];
	DKDrawableObject*	obj;
	NSSize				extra, ms = NSMakeSize( 0, 0 );
	
	while(( obj = [iter nextObject]))
	{
		extra = [obj extraSpaceNeeded];
		
		if ( extra.width > ms.width )
			ms.width = extra.width;
			
		if ( extra.height > ms.height )
			ms.height = extra.height;
	}
	
	return ms;
}


#pragma mark -
#pragma mark - transforms
///*********************************************************************************************************************
///
/// method:			contentTransform
/// scope:			protected instance method
/// overrides:		
/// description:	returns a transform used to map the contained objects to the group's size, position and angle.
/// 
/// parameters:		none
/// result:			a transform object
///
/// notes:			this transform is used when drawing the group's contents
///
///********************************************************************************************************************

- (NSAffineTransform*)	contentTransform
{
	float sx, sy;
	
	sx = [self size].width / m_bounds.size.width;
	sy = [self size].height / m_bounds.size.height;
	
	NSPoint p = NSZeroPoint;
	p = [[self transform] transformPoint:p];

	NSAffineTransform* xform = [NSAffineTransform transform];
	[xform translateXBy:p.x yBy:p.y];
	[xform rotateByRadians:[self angle]];
	
	if( sx != 0.0 && sy != 0.0 )
		[xform scaleXBy:sx yBy:sy];
	
	return xform;
}


///*********************************************************************************************************************
///
/// method:			renderingTransform
/// scope:			protected instance method
/// overrides:		DKDrawableObject
/// description:	returns a transform which is the accumulation of all the parent objects above this one.
/// 
/// parameters:		none
/// result:			a transform object
///
/// notes:			drawables will request and apply this transform when rendering. Either the identity matrix is
//					returned if the group is visually transforming the result, or a combination of the parents above
///					and the content transform. Either way contained objects are oblivious and do the right thing.
///
///********************************************************************************************************************

- (NSAffineTransform*)	renderingTransform
{
	// returns the concatenation of all groups and layers transforms containing this one
	
	if ( mIsWritingToCache )
	{
		NSAffineTransform* stf = [NSAffineTransform transform];
		//[stf translateXBy:m_bounds.origin.x yBy:m_bounds.origin.y];
		return stf;
	}
	else
	{
		NSAffineTransform*	tfm = [[self container] renderingTransform];
		
		if ( m_transformVisually )
			return tfm;
		else
		{
			NSAffineTransform*	ct = [self contentTransform];
			
			if ( tfm )
			{
				[tfm prependTransform:ct];
				return tfm;
			}
			else
				return ct;
		}
	}
}


///*********************************************************************************************************************
///
/// method:			convertPointFromContainer:
/// scope:			protected instance method
/// overrides:		
/// description:	maps a point from the original container's coordinates to the equivalent group point
/// 
/// parameters:		<p> a point
/// result:			a new point
///
/// notes:			the container will be usually a layer or another group.
///
///********************************************************************************************************************

- (NSPoint)				convertPointFromContainer:(NSPoint) p
{
	// given a point <p> in the container's coordinates, returns the same point relative to this group
	
	NSAffineTransform* ct = [self contentTransform];
	[ct invert];
	return [ct transformPoint:p];
}


///*********************************************************************************************************************
///
/// method:			convertPointToContainer:
/// scope:			protected instance method
/// overrides:		
/// description:	maps a point from the group's coordinates to the equivalent original container point
/// 
/// parameters:		<p> a point
/// result:			a new point
///
/// notes:			the container will be usually a layer or another group.
///
///********************************************************************************************************************

- (NSPoint)				convertPointToContainer:(NSPoint) p
{
	return [[self contentTransform] transformPoint:p];
} 


- (void)				drawGroupContent
{
	NSEnumerator*		iter = [[self groupObjects] objectEnumerator];
	DKDrawableShape*	od;
	
	if ( m_transformVisually )
	{
		[NSGraphicsContext saveGraphicsState];
		NSAffineTransform* tfm = [self contentTransform];
		[tfm concat];
	}
	
	while(( od = [iter nextObject]))
	{
		if([od visible])
			[od drawContentWithSelectedState:NO];
	}
	
	if ( m_transformVisually )
		[NSGraphicsContext restoreGraphicsState];
}



- (NSData*)				pdfDataOfObjects
{
	NSData* pdfData = nil;
	
	if([[self groupObjects] count] > 0 )
	{
		NSRect	fr = NSZeroRect;
		
		fr.size = [[self drawing] drawingSize];
		
		DKGroupPDFView*		pdfView = [[DKGroupPDFView alloc] initWithFrame:fr withGroup:self];
		DKViewController*	vc = [pdfView makeViewController];
		
		[[self drawing] addController:vc];
		
		NSRect sr = m_bounds;
		pdfData = [pdfView dataWithPDFInsideRect:sr];
		[pdfView release];
	}
	return pdfData;
}


#pragma mark -
#pragma mark - content caching

- (void)				setCacheOptions:(DKGroupCacheOption) cacheOption
{
	if( cacheOption != mCacheOption )
	{
		mCacheOption = cacheOption;
		[self invalidateCache];
	}
}


- (DKGroupCacheOption)	cacheOptions
{
	return mCacheOption;
}


- (void)				updateCache
{
	if( mPDFContentCache == nil && mContentCache == nil )
	{
		NSRect cacheBounds = m_bounds;
		
		if( cacheBounds.size.width > 0.0 && cacheBounds.size.height > 0.0 )
		{
			// create a PDF of the entire group content
			
			if([self cacheOptions] & kDKGroupCacheUsingPDF )
			{
				NSData* pdf = [self pdfDataOfObjects];
				
				NSAssert( pdf != nil, @"couldn't get pdf data for the layer");
				
				NSPDFImageRep* rep = [NSPDFImageRep imageRepWithData:pdf];
			
				NSAssert( rep != nil, @"can't create PDF image rep");
				mPDFContentCache = [rep retain];
				
				LogEvent_( kReactiveEvent, @"built PDF cache = %@; size = %@", rep, NSStringFromSize( m_bounds.size ));
			}
			
			// also create a CGLayer version of the same image, for use when drawing is using low quality mode or
			// when this is the only cache option set
			
			if([self cacheOptions] & kDKGroupCacheUsingCGLayer)
			{
				CGContextRef	context = [[NSGraphicsContext currentContext] graphicsPort];
				
				NSAssert( context != nil, @"no context for caching the layer");
				
				CGLayerRef		layer = CGLayerCreateWithContext( context, *(CGSize*)&cacheBounds.size, NULL );
				
				NSAssert( layer != nil, @"couldn't create caching layer");
				
				context = CGLayerGetContext( layer );
				NSGraphicsContext* nsContext = [NSGraphicsContext graphicsContextWithGraphicsPort:context flipped:YES];
				
				[NSGraphicsContext saveGraphicsState];
				[NSGraphicsContext setCurrentContext:nsContext];
				
				// draw the contents into the layer, offsetting to the area's origin

				NSAffineTransform* transform = [NSAffineTransform transform];
				[transform translateXBy:-cacheBounds.origin.x yBy:-cacheBounds.origin.y];
				[transform concat];
				[self drawUntransformedContent];
				[NSGraphicsContext restoreGraphicsState];
				
				LogEvent_( kReactiveEvent, @"built offscreen cache = %@; size = %@", layer, NSStringFromSize( m_bounds.size ));
			
				// assign the new layer cache to the ivar:
				
				mContentCache = layer;
			}
		}
	}
}


- (void)				invalidateCache
{
	LogEvent_( kReactiveEvent, @"invalidating group cache");
	
	if ( mContentCache != nil )
	{
		CGLayerRelease( mContentCache );
		mContentCache = nil;
	}
	
	if( mPDFContentCache != nil )
	{
		[mPDFContentCache release];
		mPDFContentCache = nil;
	}
}


- (void)				drawUntransformedContent
{
	// draws the group content without applying any transforms - this is used to capture the original state of the
	// contents into a cached context.
	
	mIsWritingToCache = YES;
	[self drawGroupContent];
	mIsWritingToCache = NO;
}


#pragma mark -
#pragma mark - ungrouping
///*********************************************************************************************************************
///
/// method:			ungroupToLayer:
/// scope:			protected instance method
/// overrides:		
/// description:	unpacks the group back into the nominated layer 
/// 
/// parameters:		<layer> the layer into which the objects are unpacked
/// result:			none
///
/// notes:			usually it's better to call the higher level ungroupObjects: action method which calls this. This
///					method strives to preserve as much information about the objects as possible - e.g. their rotation
///					angle and size. Nested groups can cause distortions which are visually preserved though the bounds
///					muct necessarily be altered. Objects are inserted into the layer at the same Z-index position as
///					the group currently occupies.
///
///********************************************************************************************************************

- (void)				ungroupToLayer:(DKObjectDrawingLayer*) layer
{
	[[self undoManager] registerUndoWithTarget:self selector:@selector(setObjects:) object:m_objects];
	
	// discover our own Z-position - ungrouped objects will be inserted at this position
	
	int groupIndex = [layer indexOfObject:self];

	// first set object parent to the layer so that the transform is no longer affected by the group
	
	[m_objects makeObjectsPerformSelector:@selector(setContainer:) withObject:layer];

	NSEnumerator*		iter = [m_objects objectEnumerator];
	DKDrawableObject*	obj;
	NSBezierPath*		path;
	NSAffineTransform*	tfm;
	int					insertIndex = groupIndex;
	
	if ( m_transformVisually )
		tfm = [self contentTransform];
	else
		tfm = [self renderingTransform];

	while(( obj = [iter nextObject]))
	{
		// unfortunately groups, paths and shapes all have slightly different needs here
		
		if([obj isKindOfClass:[DKShapeGroup class]])
		{
			// groups within groups can be tricky, as multiple transforms apply and they are hard.
			// currently, this implementation is unable to preserve combined rotated and scaled groups exactly because
			// the resulting paths should be skewed but after ungrouping they will not be. TO DO: fix this - there has to be a way!!
			
			NSPoint p = [(DKShapeGroup*)obj location];
			NSSize	gs = [(DKShapeGroup*)obj size];

			float sx, sy;
			
			sx = [self size].width / m_bounds.size.width;
			sy = [self size].height / m_bounds.size.height;
			
			gs.width *= sx;
			gs.height *= sy;
			
			[(DKShapeGroup*)obj rotateByAngle:[self angle]];	// preserve rotated bounds
			[(DKShapeGroup*)obj setSize:gs];
			[(DKShapeGroup*)obj moveToPoint:[tfm transformPoint:p]];
		}
		else if([obj isKindOfClass:[DKDrawableShape class]])
		{
			NSPoint loc = [obj location];
			path = [[(DKDrawableShape*)obj transformedPath] copy];
			
			[path transformUsingAffineTransform:tfm];
			loc = [tfm transformPoint:loc];
			
			[(DKDrawableShape*)obj moveToPoint:loc];
			[(DKDrawableShape*)obj rotateByAngle:[self angle]];	// preserves rotated bounds
			[(DKDrawableShape*)obj adoptPath:path];
			[path release];
		}
		else if ([obj isKindOfClass:[DKDrawablePath class]])
		{
			path = [[(DKDrawablePath*)obj path] copy];
			[path transformUsingAffineTransform:tfm];
			[(DKDrawableShape*)obj setPath:path];
			[path release];
		}
	
		[layer addObject:obj atIndex:insertIndex++];
	}

	[layer exchangeSelectionWithObjectsInArray:m_objects];
	[m_objects release];
	m_objects = nil;
}


///*********************************************************************************************************************
///
/// method:			ungroupObjects:
/// scope:			public action method
/// overrides:		
/// description:	high-level call to ungroup the group.
/// 
/// parameters:		<sender> the sender of the action
/// result:			none
///
/// notes:			undoably ungroups this and replaces itself in its layer by its contents
///
///********************************************************************************************************************

- (IBAction)			ungroupObjects:(id) sender
{
	#pragma unused(sender)
	
	// note to self - consider what to do if ungrouping could place objects offscreen
	
	DKObjectDrawingLayer* odl = (DKObjectDrawingLayer*)[self layer];
	
	[odl recordSelectionForUndo];
	[self ungroupToLayer:odl];
	[odl removeObject:self];
	[odl commitSelectionUndoWithActionName:NSLocalizedString(@"Ungroup", @"undo string for ungroup")];
}


#pragma mark -
#pragma mark As a DKDrawableShape
///*********************************************************************************************************************
///
/// method:			resetBoundingBox
/// scope:			protected instance method
/// overrides:		DKDrawableShape
/// description:	overrides this method to ensure it has no effect
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				resetBoundingBox
{
}


///*********************************************************************************************************************
///
/// method:			resetBoundingBoxAndRotation
/// scope:			protected instance method
/// overrides:		DKDrawableShape
/// description:	overrides this method to ensure it has no effect
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				resetBoundingBoxAndRotation
{
}


///*********************************************************************************************************************
///
/// method:			setOperationMode:
/// scope:			protected instance method
/// overrides:		DKDrawableShape
/// description:	overrides this method to ensure it has no effect
/// 
/// parameters:		<mode> ignored
/// result:			none
///
/// notes:			distortion operations cannot be applied to a group
///
///********************************************************************************************************************

- (void)				setOperationMode:(int) mode
{
	#pragma unused(mode)
	
}


#pragma mark -
#pragma mark As a DKDrawableObject


- (NSSet*)				allStyles
{
	// return the union of all the contained objects' styles
	
	NSEnumerator*		iter = [[self groupObjects] objectEnumerator];
	NSSet*				styles;
	NSMutableSet*		unionOfAllStyles = nil;
	DKDrawableObject*	dko;
	
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


- (NSSet*)				allRegisteredStyles
{
	// return the union of all the contained objects' registered styles
	
	NSEnumerator*		iter = [[self groupObjects] objectEnumerator];
	NSSet*				styles;
	NSMutableSet*		unionOfAllStyles = nil;
	DKDrawableObject*	dko;
	
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


- (void)				replaceMatchingStylesFromSet:(NSSet*) aSet
{
	// propagate this to all objects in the group:
	
	[[self groupObjects] makeObjectsPerformSelector:@selector(replaceMatchingStylesFromSet:) withObject:aSet];
}



///*********************************************************************************************************************
///
/// method:			drawContent
/// scope:			protected instance method
/// overrides:		DKDrawableShape
/// description:	draws the objects within the group.
/// 
/// parameters:		none
/// result:			none
///
/// notes:			depending on how the group's transforms are set to work, this either sets up the graphics context
///					and renders the objects directly, or else it relies on the objects calling back to get the
///					parent transform and applying it correctly.
///
///********************************************************************************************************************

- (void)				drawContent
{
	// see if we should be building/using the cache
	
	BOOL drawingToScreen = [NSGraphicsContext currentContextDrawingToScreen];
	BOOL usingCache = [self cacheOptions] != kDKGroupCacheNone;
	
	if( drawingToScreen && usingCache )
	{
		if ( mPDFContentCache == nil )
			[self updateCache];
		
		// set up the transform
		
		NSPoint topLeft = NSMakePoint( -0.5, -0.5 );
		topLeft = [[self transform] transformPoint:topLeft];
		topLeft = [self convertPointFromContainer:topLeft];
		
		[NSGraphicsContext saveGraphicsState];
		
		BOOL hasPDF = ([self cacheOptions] & kDKGroupCacheUsingPDF) && ( mPDFContentCache != nil );
		BOOL hasCG = ([self cacheOptions] & kDKGroupCacheUsingCGLayer) && ( mContentCache != nil );
		
		// draw using layer if it's the only thing available OR the drawing is in LQ mode
		
		if(( hasCG && !hasPDF) || (hasCG && [[self drawing] lowRenderingQuality]))
		{
			[[self contentTransform] concat];
			
			CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
			CGContextDrawLayerAtPoint( context, *(CGPoint*)&NSZeroPoint, mContentCache );
		}
		else if( hasPDF )
		{
			[[self contentTransform] concat];

			// pdf cache is flipped, so need a transform here to unflip it
			
			NSAffineTransform* unflipper = [NSAffineTransform transform];
			//[unflipper translateXBy:0 yBy:m_bounds.size.height];
			[unflipper scaleXBy:1.0 yBy:-1.0];
			[unflipper concat];
			
			[mPDFContentCache drawAtPoint:topLeft];
		}
		
		[NSGraphicsContext restoreGraphicsState];
	}
	else
		[self drawGroupContent];
}


///*********************************************************************************************************************
///
/// method:			drawContentWithStyle
/// scope:			protected instance method
/// overrides:		DKDrawableObject
/// description:	draws the objects within the group but using the given style.
/// 
/// parameters:		<aStyle> some style object
/// result:			none
///
/// notes:			depending on how the group's transforms are set to work, this either sets up the graphics context
///					and renders the objects directly, or else it relies on the objects calling back to get the
///					parent transform and applying it correctly.
///
///********************************************************************************************************************

- (void)			drawContentWithStyle:(DKStyle*) aStyle
{
	if ( m_transformVisually )
	{
		[NSGraphicsContext saveGraphicsState];
		NSAffineTransform* tfm = [self contentTransform];
		[tfm concat];
	}

	[[self groupObjects] makeObjectsPerformSelector:@selector(drawContentWithStyle:) withObject:aStyle];

	if ( m_transformVisually )
		[NSGraphicsContext restoreGraphicsState];
}

///*********************************************************************************************************************
///
/// method:			drawContentForHitBitmap
/// scope:			protected instance method
/// overrides:		DKDrawableObject
/// description:	draws the content using the hit testing style
/// 
/// parameters:		none
/// result:			none
///
/// notes:			ensures all objects contribute to the group's hit testing as a whole
///
///********************************************************************************************************************

- (void)				drawContentForHitBitmap
{
	NSEnumerator*		iter = [[self groupObjects] objectEnumerator];
	DKDrawableShape*	od;
	
	if ( m_transformVisually )
	{
		[NSGraphicsContext saveGraphicsState];
		NSAffineTransform* tfm = [self contentTransform];
		[tfm concat];
	}
	
	while(( od = [iter nextObject]))
		[od drawContentForHitBitmap];

	if ( m_transformVisually )
		[NSGraphicsContext restoreGraphicsState];
}



///*********************************************************************************************************************
///
/// method:			extraSpaceNeeded
/// scope:			public instance method
/// overrides:
/// description:	returns the extra space needed to display the object graphically. This will usually be the difference
///					between the logical and reported bounds.
/// 
/// parameters:		none
/// result:			the extra space required
///
/// notes:			the result is the max of all the contained objects
///********************************************************************************************************************

- (NSSize)				extraSpaceNeeded
{
	return [self extraSpaceNeededByObjects:[self groupObjects]];
}


///*********************************************************************************************************************
///
/// method:			populateContextualMenu:
/// scope:			protected instance method
/// overrides:		DKDrawableShape
/// description:	adds group commands to the contextual menu
/// 
/// parameters:		<theMenu> a menu to populate
/// result:			YES
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				populateContextualMenu:(NSMenu*) theMenu
{
	[[theMenu addItemWithTitle:NSLocalizedString(@"Ungroup", @"menu item for ungroup") action:@selector( ungroupObjects: ) keyEquivalent:@""] setTarget:self];
	[[theMenu addItemWithTitle:NSLocalizedString(@"Paste Drawing Style", @"menu item for paste style") action:@selector( pasteDrawingStyle: ) keyEquivalent:@""] setTarget:self];
	return YES;
}


///*********************************************************************************************************************
///
/// method:			setStyle:
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	propagates a style change to all objects in the group
/// 
/// parameters:		<style> the style to apply
/// result:			none
///
/// notes:			this is a convenience method - often groups will contain objects with different styles. If you do
///					want to apply a style to a number of different objects you can group them and call this.
///
///********************************************************************************************************************

- (void)				setStyle:(DKStyle*) style
{
	// copies the style to all objects in the group, as a convenient way to set styles for several objects at once
	
	[[self groupObjects] makeObjectsPerformSelector:@selector(setStyle:) withObject:style];
	[self notifyVisualChange];
}







#pragma mark -
#pragma mark As an NSObject


- (id)					init
{
	self = [super init];
	if (self != nil)
	{
		NSBezierPath* path = [NSBezierPath bezierPathWithRect:[[self class] unitRectAtOrigin]];
		[self setPath:path];
		//[self setCacheOptions:kDKGroupCacheUsingCGLayer];
	}
	return self;
}


- (void)				dealloc
{
	[self invalidateCache];
	[m_objects release];
	[super dealloc];
}


#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)				encodeWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];
	
	[coder encodeRect:m_bounds forKey:@"group_bounds"];
	[coder encodeObject:[self groupObjects] forKey:@"groupedobjects"];
}


- (id)					initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super initWithCoder:coder];
	if (self != nil)
	{
		[self setObjects:[coder decodeObjectForKey:@"groupedobjects"]];
		NSAssert(!m_transformVisually, @"Expected init to NO");
		
		if (m_objects == nil)
		{
			[self autorelease];
			self = nil;
		}
	}
	if (self != nil)
	{
		[[self path] appendBezierPathWithRect:[[self class] unitRectAtOrigin]];
		m_bounds = [coder decodeRectForKey:@"group_bounds"];
	}
	
	return self;
}


#pragma mark -
#pragma mark As part of NSCopying Protocol
- (id)					copyWithZone:(NSZone*) zone
{
	DKShapeGroup*		copy = [super copyWithZone:zone];

	NSMutableArray*		objectsCopy = [[NSMutableArray alloc] init];
	NSEnumerator*		iter = [[self groupObjects] objectEnumerator];
	DKDrawableShape*	obj;
	DKDrawableShape*	copyOfObj;
	
	// make a deep copy of the group's objects
	
	while(( obj = [iter nextObject]))
	{
		copyOfObj = [obj copyWithZone:zone];
		
		[objectsCopy addObject:copyOfObj];
		[copyOfObj setContainer:copy];
		[copyOfObj release];
	}
	
	copy->m_objects = objectsCopy;
	copy->m_bounds = m_bounds;
	
	[copy setCacheOptions:[self cacheOptions]];
	[copy updateCache];
	
	return copy;
}


#pragma mark -
#pragma mark As part of NSMenuValidation Protocol
- (BOOL)				validateMenuItem:(NSMenuItem*) item
{
	BOOL	enable = NO;
	SEL		action = [item action];
	
	if ( action == @selector(setDistortMode:) ||
		 action == @selector(resetBoundingBox:) ||
		 action == @selector(convertToPath:))
		return NO;
		
	if ( action == @selector(ungroupObjects:))
		enable = ![self locked];
		
	return enable | [super validateMenuItem:item];
}


@end
