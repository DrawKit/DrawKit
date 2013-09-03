///**********************************************************************************************************************************
///  DKDrawableObject.m
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

#import "DKDrawableObject.h"

#import "DKDrawing.h"
#import "DKStyle.h"
#import "DKKnob.h"
#import "DKObjectDrawingLayer.h"
#import "NSDictionary+DeepCopy.h"
#import "DKGeometryUtilities.h"
#import "LogEvent.h"


#pragma mark Contants (Non-localized)
NSString*		kGCDrawableDidChangeNotification			= @"kGCDrawableDidChangeNotification";
NSString*		kDKDrawableStyleWillBeDetachedNotification	= @"kDKDrawableStyleWillBeDetachedNotification";
NSString*		kDKDrawableStyleWasAttachedNotification		= @"kDKDrawableStyleWasAttachedNotification";

NSString*		kDKDrawableOldStyleKey = @"old_style";
NSString*		kDKDrawableNewStyleKey = @"new_style";

#pragma mark Static vars
static BOOL		sDisplaysSizeInfo = YES;


#pragma mark -
@implementation DKDrawableObject
#pragma mark As a DKDrawableObject

+ (BOOL)				displaysSizeInfoWhenDragging
{
	return sDisplaysSizeInfo;
}



///*********************************************************************************************************************
///
/// method:			setDisplaysSizeInfoWhenDragging:
/// scope:			class method
/// overrides:		
/// description:	set whether an info floater is displayed when resizing an object
/// 
/// parameters:		<doesDisplay> YES to show the info, NO to not show it
/// result:			none
///
/// notes:			size info is width and height
///
///********************************************************************************************************************

+ (void)				setDisplaysSizeInfoWhenDragging:(BOOL) doesDisplay
{
	sDisplaysSizeInfo = doesDisplay;
}


///*********************************************************************************************************************
///
/// method:			unionOfBoundsOfDrawablesInArray:
/// scope:			class method
/// overrides:		
/// description:	returns the union of the bounds of the objects in the array
/// 
/// parameters:		<array> a list of DKDrawable objects
/// result:			a rect, the union of the bounds of all objects
///
/// notes:			utility method as this is a very common task - throws exception if any object in the list is
///					not a DKDrawableObject or subclass thereof
///
///********************************************************************************************************************

+ (NSRect)				unionOfBoundsOfDrawablesInArray:(NSArray*) array
{
	NSAssert( array != nil, @"array cannot be nil");
	
	NSRect			u = NSZeroRect;
	NSEnumerator*	iter = [array objectEnumerator];
	id				dko;
	
	while(( dko = [iter nextObject]))
	{
		if (![dko isKindOfClass:[DKDrawableObject class]])
			[NSException raise:NSInternalInconsistencyException format:@"objects must all derive from DKDrawableObject"];
			
		u = UnionOfTwoRects( u, [dko bounds]);
	}
	
	return u;
}


///*********************************************************************************************************************
///
/// method:			pasteboardTypesForOperation:
/// scope:			public class method
/// overrides:
/// description:	return pasteboard types that this object class can receive
/// 
/// parameters:		<op> set of flags indicating what this operation the types relate to. Currently objects can only
///					receive drags so this is the only flag that should be passed
/// result:			an array of pasteboard types
///
/// notes:			default method does nothing - subclasses will override if they can receive a drag
///
///********************************************************************************************************************

+ (NSArray*)		pasteboardTypesForOperation:(DKPasteboardOperationType) op
{
	#pragma unused(op)
	return nil;
}


///*********************************************************************************************************************
///
/// method:			initialPartcodeForObjectCreation
/// scope:			public class method
/// overrides:
/// description:	return the partcode that should be used by tools when initially creating a new object
/// 
/// parameters:		none
/// result:			a partcode value
///
/// notes:			default method does nothing - subclasses must override this and supply the right partcode value
///					appropriate to the class. The client of this method is DKObjectCreationTool.
///
///********************************************************************************************************************

+ (int)				initialPartcodeForObjectCreation
{
	return kGCDrawingNoPart;
}




#pragma mark -
#pragma mark - relationships

///*********************************************************************************************************************
///
/// method:			layer
/// scope:			public instance method
/// overrides:
/// description:	returns the layer that this object ultimately belongs to
/// 
/// parameters:		none
/// result:			the containing layer
///
/// notes:			this returns the layer even if container isn't the layer, by recursing up the tree as needed
///
///********************************************************************************************************************

- (DKObjectOwnerLayer*)	layer
{
	return (DKObjectOwnerLayer*)[[self container] layer];
}


///*********************************************************************************************************************
///
/// method:			drawing
/// scope:			public instance method
/// overrides:
/// description:	returns the drawing that owns this object's layer
/// 
/// parameters:		none
/// result:			the drawing
///
/// notes:			
///
///********************************************************************************************************************

- (DKDrawing*)		drawing
{
	return [[self container] drawing];
}


///*********************************************************************************************************************
///
/// method:			undoManager
/// scope:			public instance method
/// overrides:
/// description:	returns the undo manager used to handle undoable actions for this object
/// 
/// parameters:		none
/// result:			the undo manager in use
///
/// notes:			
///
///********************************************************************************************************************

- (NSUndoManager*)	undoManager
{
	return [[self drawing] undoManager];
}


///*********************************************************************************************************************
///
/// method:			parent
/// scope:			public instance method
/// overrides:
/// description:	returns the immediate parent of this object
/// 
/// parameters:		none
/// result:			the object's parent
///
/// notes:			a parent is usually a layer, same as owner - but can be a group if the object is grouped
///
///********************************************************************************************************************

- (id)				container
{
	return mContainerRef;
}


///*********************************************************************************************************************
///
/// method:			setParent:
/// scope:			private instance method
/// overrides:
/// description:	sets the immediate parent of this object (a DKObjectOwnerLayer layer, typically)
/// 
/// parameters:		<aContainer> the immediate container of this object
/// result:			none
///
/// notes:			the container itself is responsible for setting this - applications should not use this method. An
///					object's container is usually the layer, but can be a group. <aContainer> is not retained. Note that
///					a valid container is required for the object to locate an undo manager, so nothing is undoable
///					until this is set to a valid object that can supply one.
///
///********************************************************************************************************************

- (void)			setContainer:(id) aContainer
{
	if ( aContainer != mContainerRef )
	{
		mContainerRef = aContainer;
		
		// make sure any attached style is aware of the undo manager used by the drawing/layers
		
		[[self style] setUndoManager:[self undoManager]];
	}
}


#pragma mark -
#pragma mark - state
///*********************************************************************************************************************
///
/// method:			setVisible:
/// scope:			public instance method
/// overrides:
/// description:	sets whether the object is drawn (visible) or not
/// 
/// parameters:		<vis> YES to show the object, NO to hide it
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)			setVisible:(BOOL) vis
{
	if ( m_visible != vis )
	{
		[[[self undoManager] prepareWithInvocationTarget:self] setVisible:m_visible];
		m_visible = vis;
		[self notifyVisualChange];
		[self notifyStatusChange];
	}
}


///*********************************************************************************************************************
///
/// method:			visible
/// scope:			public instance method
/// overrides:
/// description:	is the object visible?
/// 
/// parameters:		none
/// result:			YES if visible, NO if not
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)			visible
{
	return m_visible;
}


///*********************************************************************************************************************
///
/// method:			setLocked:
/// scope:			public instance method
/// overrides:
/// description:	sets whether the object is locked or not
/// 
/// parameters:		<locked> YES to lock, NO to unlock
/// result:			none
///
/// notes:			locked objects are visible but can't be edited
///
///********************************************************************************************************************

- (void)			setLocked:(BOOL) locked
{
	if ( m_locked != locked )
	{
		[[[self undoManager] prepareWithInvocationTarget:self] setLocked:m_locked];
		m_locked = locked;
		[self notifyVisualChange];		// on the assumption that the locked state is shown differently
		[self notifyStatusChange];
	}
}


///*********************************************************************************************************************
///
/// method:			locked
/// scope:			public instance method
/// overrides:
/// description:	is the object locked?
/// 
/// parameters:		none
/// result:			YES if locked, NO if not
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)			locked
{
	return m_locked;
}


///*********************************************************************************************************************
///
/// method:			setMouseSnappingEnabled:
/// scope:			public instance method
/// overrides:
/// description:	enable mouse snapping
/// 
/// parameters:		<ems> YES to enable snapping (default), NO to disable it
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)			setMouseSnappingEnabled:(BOOL) ems
{
	m_snapEnable = ems;
}


///*********************************************************************************************************************
///
/// method:			mouseSnappingEnabled
/// scope:			public instance method
/// overrides:
/// description:	is mouse snapping enabled?
/// 
/// parameters:		none
/// result:			YES if will snap on mouse actions, NO if not
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)			mouseSnappingEnabled
{
	return m_snapEnable;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			isSelected
/// scope:			public instance method
/// overrides:
/// description:	returns whether the object is selected 
/// 
/// parameters:		none
/// result:			YES if selected, NO otherwise
///
/// notes:			assumes that the owning layer is an object drawing layer (which is a reasonable assumption!)
///
///********************************************************************************************************************

- (BOOL)			isSelected
{
	return [(DKObjectDrawingLayer*)[self layer] isSelectedObject:self];
}


///*********************************************************************************************************************
///
/// method:			objectDidBecomeSelected
/// scope:			public instance method
/// overrides:
/// description:	get notified when the object is selected
/// 
/// parameters:		none
/// result:			none
///
/// notes:			subclasses can override to take action when they become selected (drawing the selection isn't
///					part of this - the layer will do that)
///
///********************************************************************************************************************

- (void)			objectDidBecomeSelected
{
	[self notifyStatusChange];
	
	// override to make use of this notification
}


///*********************************************************************************************************************
///
/// method:			objectIsNoLongerSelected
/// scope:			public instance method
/// overrides:
/// description:	get notified when an object is deselected
/// 
/// parameters:		none
/// result:			none
///
/// notes:			subclasses can override to take action when they are deselected
///
///********************************************************************************************************************

- (void)			objectIsNoLongerSelected
{
	[self notifyStatusChange];

	// override to make use of this notification
}


#pragma mark -
#pragma mark - drawing
///*********************************************************************************************************************
///
/// method:			drawContentWithSelectedState:
/// scope:			public instance method
/// overrides:
/// description:	draw the object and its selection on demand
/// 
/// parameters:		<selected> YES if the object is to draw itself in the selected state, NO otherwise
/// result:			none
///
/// notes:			the caller will have determined that the object needs drawing, so this will only be called when
///					necessary. The default method does nothing - subclasses must override this.
///
///********************************************************************************************************************

- (void)			drawContentWithSelectedState:(BOOL) selected
{
#ifdef qIncludeGraphicDebugging
	[NSGraphicsContext saveGraphicsState];
	
	if ( m_clipToBBox)
	{
		NSBezierPath* clipPath = [NSBezierPath bezierPathWithRect:[self bounds]];
		[clipPath addClip];
	}
#endif
	[self drawContent];
	
	if ( selected )
		[self drawSelectedState];

#ifdef qIncludeGraphicDebugging

	[NSGraphicsContext restoreGraphicsState];

	if ( m_showBBox )
	{
		[[NSColor redColor] set];
		
		NSRect bb = NSInsetRect([self bounds], 0.5, 0.5);
		NSBezierPath* bbox = [NSBezierPath bezierPathWithRect:bb];
		
		[bbox moveToPoint:bb.origin];
		[bbox lineToPoint:NSMakePoint( NSMaxX( bb ), NSMaxY( bb ))];
		[bbox moveToPoint:NSMakePoint( NSMaxX( bb ), NSMinY( bb ))];
		[bbox lineToPoint:NSMakePoint( NSMinX( bb ), NSMaxY( bb ))];
		
		[bbox setLineWidth:0.0];
		[bbox stroke];
	}
#endif
}


///*********************************************************************************************************************
///
/// method:			drawContent
/// scope:			public instance method
/// overrides:
/// description:	draw the content of the object
/// 
/// parameters:		none
/// result:			none
///
/// notes:			this just hands off to the style rendering by default, but subclasses may override it to do more.
///
///********************************************************************************************************************

- (void)			drawContent
{
	if([self style] && [[self style] countOfRenderList] > 0 )
		[[self style] render:self];
	else
	{
		// if there's no style, the shape will be invisible. This makes it hard to select for deletion, etc. Thus if
		// drawing to the screen, a visible outline is drawn so that it can be seen and selected. This is not drawn
		// to the printer so the drawing remains correct for printed output.
		
		if([NSGraphicsContext currentContextDrawingToScreen])
		{
			[[NSColor lightGrayColor] set];
			
			NSBezierPath* rpc = [[self renderingPath] copy];
			[rpc setLineWidth:1.0];
			[rpc stroke];
			[rpc release];
		}
	}
}


///*********************************************************************************************************************
///
/// method:			drawContentWithStyle:
/// scope:			public instance method
/// overrides:
/// description:	draw the content of the object but using a specific style, which might not be the one attached
/// 
/// parameters:		<aStyle> a valid style object
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)			drawContentWithStyle:(DKStyle*) aStyle
{
	NSAssert( aStyle != nil, @"expected style to be not nil");
	
	[aStyle render:self];
}


///*********************************************************************************************************************
///
/// method:			drawContentForHitBitmap
/// scope:			private instance method
/// overrides:
/// description:	draw the content of the object but using a hit testing style derived from the current one
/// 
/// parameters:		none
/// result:			none
///
/// notes:			this is called by the -pathBitmap method, and is not generally useful to client code. DKShapeGroup
///					overrides this to build a hit bitmap from all of its sub-objects
///
///********************************************************************************************************************

- (void)			drawContentForHitBitmap
{
	DKStyle* hitStyle;
	
	if([self style] != nil )
		hitStyle = [[self style] hitTestingStyle];
	else
		hitStyle = [[DKStyle defaultStyle] hitTestingStyle];
		
	[self drawContentWithStyle:hitStyle];
}

///*********************************************************************************************************************
///
/// method:			drawSelectedState
/// scope:			public instance method
/// overrides:
/// description:	draw the selection highlight for the object
/// 
/// parameters:		none
/// result:			none
///
/// notes:			the owning layer may call this independently of drawContent~ in some circumstances, so 
///					subclasses need to be ready to factor this code as required.
///
///********************************************************************************************************************

- (void)			drawSelectedState
{
	// placeholder - override to implement this
}


///*********************************************************************************************************************
///
/// method:			drawSelectionPath
/// scope:			public instance method
/// overrides:
/// description:	stroke the given path using the selection highlight colour for the owning layer
/// 
/// parameters:		<path> the selection highlight path
/// result:			none
///
/// notes:			this is a convenient utility method your subclasses can use as needed to make selections consistent
///					among different objects and layers. A side effect is that the line width of the path may be changed.
///
///********************************************************************************************************************

- (void)			drawSelectionPath:(NSBezierPath*) path
{
	if ([self locked])
		[[NSColor lightGrayColor] set];
	else
		[[[self layer] selectionColour] set];

	[path setLineWidth:0.0];
	[path stroke];
}


///*********************************************************************************************************************
///
/// method:			notifyVisualChange
/// scope:			public instance method
/// overrides:
/// description:	request a redraw of this object
/// 
/// parameters:		none
/// result:			none
///
/// notes:			marks the object's bounds as needing updating. Most operations on an object that affect its
///					appearance to the user should call this before and after the operation is performed.
///
///********************************************************************************************************************

- (void)			notifyVisualChange
{
	if ([self layer] != nil )
	{
		[[self layer] drawable:self needsDisplayInRect:[self bounds]];
		[[self drawing] updateRulerMarkersForRect:[self logicalBounds]];
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:kGCDrawableDidChangeNotification object:self];
}


///*********************************************************************************************************************
///
/// method:			notifyStatusChange
/// scope:			public instance method
/// overrides:
/// description:	notify the drawing and its controllers that a non-visual status change occurred
/// 
/// parameters:		none
/// result:			none
///
/// notes:			the drawing passes this back to any controllers it has
///
///********************************************************************************************************************

- (void)			notifyStatusChange
{
	[[self drawing] objectDidNotifyStatusChange:self];
	[[NSNotificationCenter defaultCenter] postNotificationName:kGCDrawableDidChangeNotification object:self];
}


///*********************************************************************************************************************
///
/// method:			setNeedsDisplayInRect
/// scope:			public instance method
/// overrides:
/// description:	mark some part of the drawing as needing update
/// 
/// parameters:		<rect> this area requires an update
/// result:			none
///
/// notes:			usually an object should mark only areas within its bounds using this, to be polite.
///
///********************************************************************************************************************

- (void)			setNeedsDisplayInRect:(NSRect) rect
{
	[[self layer] setNeedsDisplayInRect:rect];
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			renderingPath
/// scope:			public instance method
/// overrides:
/// description:	return the path that represents the final user-visible path of the drawn object
/// 
/// parameters:		none
/// result:			the object's path
///
/// notes:			the default method does nothing. Subclasses should override this and supply the appropriate path,
///					which is the one requested by a renderer when the object is actually drawn. See also the
///					DKRasterizerProtocol, which makes use of this.
///
///********************************************************************************************************************

- (NSBezierPath*)	renderingPath
{
	return nil;
}


///*********************************************************************************************************************
///
/// method:			useLowQualityDrawing
/// scope:			public instance method
/// overrides:
/// description:	return hint to rasterizers that low quality drawing should be used
/// 
/// parameters:		none
/// result:			YES to use low quality drawing, no otherwise
///
/// notes:			part of the informal rendering protocol used by rasterizers
///
///********************************************************************************************************************

- (BOOL)			useLowQualityDrawing
{
	return [[self drawing] lowRenderingQuality];
}

#pragma mark -
#pragma mark - style
///*********************************************************************************************************************
///
/// method:			setStyle:
/// scope:			public instance method
/// overrides:
/// description:	attaches a style to the object
/// 
/// parameters:		<aStyle> the style to attach. The object will be drawn using this style from now on
/// result:			none
///
/// notes:			it's important to call the inherited method if you override this, as objects generally need to
///					subscribe to a style's notifications, and a style needs to know when it is attached to objects.
///
///					IMPORTANT: because styles may be set to be shared or not, the rule is that styles MUST be copied
///					before attaching. Shared styles don't really make a copy, so the sharing of such styles occurs
///					automatically without the client object needing to know about it.
///
///********************************************************************************************************************

- (void)			setStyle:(DKStyle*) aStyle
{
	// important rule: always make a 'copy' of the style to honour its sharable flag:
	
	DKStyle* newStyle = [aStyle copy];
	
	if ( newStyle != [self style])
	{
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setStyle:) object:[self style]];	
		[self notifyVisualChange];
		
		// subscribe to change notifications from the style so we can refresh and undo changes
		
		if ( m_style )
			[[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:[self style]];
		
		if ( newStyle )
		{
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( styleWillChange:) name:kDKStyleWillChangeNotification object:newStyle];
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( styleDidChange:) name:kDKStyleDidChangeNotification object:newStyle];
		}
		
		// set up the user info. If newStyle is nil, this will terminate the list after the old style
		
		NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[self style], kDKDrawableOldStyleKey, newStyle, kDKDrawableNewStyleKey, nil];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawableStyleWillBeDetachedNotification object:self userInfo:userInfo];
		
		[m_style styleWillBeRemoved:self];
		[m_style release];
		m_style = newStyle;
		
		// set the style's undo manager to ours if it's actually set
		
		if([self undoManager] != nil )
			[m_style setUndoManager:[self undoManager]];
		
		[m_style styleWasAttached:self];
		[self notifyStatusChange];
		[self notifyVisualChange];

		[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawableStyleWasAttachedNotification object:self userInfo:userInfo];
	}
}


///*********************************************************************************************************************
///
/// method:			style
/// scope:			public instance method
/// overrides:
/// description:	return the attached style
/// 
/// parameters:		none
/// result:			the current style
///
/// notes:			
///
///********************************************************************************************************************

- (DKStyle*)	style
{
	return m_style;
}

///*********************************************************************************************************************
///
/// method:			styleWillChange:
/// scope:			private notification method
/// overrides:
/// description:	called when the attached style is about to change
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)			styleWillChange:(NSNotification*) note
{
	#pragma unused(note)
	
	[self notifyVisualChange];
}


///*********************************************************************************************************************
///
/// method:			styleDidChange
/// scope:			private notification method
/// overrides:
/// description:	called just after the attached style has changed
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)			styleDidChange:(NSNotification*) note
{
	#pragma unused(note)
	
	[self notifyVisualChange];
}



///*********************************************************************************************************************
///
/// method:			allStyles
/// scope:			public instance method
/// overrides:
/// description:	return all styles used by this object
/// 
/// parameters:		none
/// result:			a set, containing the object's style
///
/// notes:			this is part of an informal protocol used, among other possible uses, for remerging styles after
///					a document load. Objects higher up the chain form the union of all such sets, which is why this
///					is returned as a set, even though it contains just one style. Subclasses might also use more than
///					one style.
///
///********************************************************************************************************************

- (NSSet*)			allStyles
{
	if ([self style] != nil )
		return [NSSet setWithObject:[self style]];
	else
		return nil;
}


///*********************************************************************************************************************
///
/// method:			allRegisteredStyles
/// scope:			public instance method
/// overrides:
/// description:	return all registered styles used by this object
/// 
/// parameters:		none
/// result:			a set, containing the object's style if it is registerd or flagged for remerge
///
/// notes:			this is part of an informal protocol used for remerging styles after
///					a document load. Objects higher up the chain form the union of all such sets, which is why this
///					is returned as a set, even though it contains just one style. Subclasses might also use more than
///					one style. After a fresh load from an archive, this returns the style if the remerge flag is set,
///					but at all other times it returns the style if registered. The remerge flag is cleared by this
///					method, thus you need to make sure to call it just once after a reload if it's the remerge flagged
///					styles you want (in general this usage is automatic and is handled at a much higher level - see
///					DKDrawingDocument).
///
///********************************************************************************************************************

- (NSSet*)			allRegisteredStyles
{
	if ([self style] != nil)
	{
		if([[self style] requiresRemerge] || [[self style] isStyleRegistered])
		{
			[[self style] clearRemergeFlag];
			return [NSSet setWithObject:[self style]];
		}
	}

	return nil;
}


///*********************************************************************************************************************
///
/// method:			replaceMatchingStylesFromSet
/// scope:			public instance method
/// overrides:
/// description:	replace the object's style from any in th egiven set that have the same ID.
/// 
/// parameters:		<aSet> a set of style objects
/// result:			none
///
/// notes:			this is part of an informal protocol used for remerging registered styles after
///					a document load. If <aSet> contains a style having the same ID as this object's current style,
///					the style is updated with the one from the set.
///
///********************************************************************************************************************

- (void)			replaceMatchingStylesFromSet:(NSSet*) aSet
{
	NSAssert( aSet != nil, @"style set was nil");

	if ([self style] != nil )
	{
		NSEnumerator*	iter = [aSet objectEnumerator];
		DKStyle*	st;
		
		while((st = [iter nextObject]))
		{
			if([[st uniqueKey] isEqualToString:[[self style] uniqueKey]])
			{
				LogEvent_(kStateEvent, @"replacing style with %@ '%@'", st, [st name]);
				
				[self setStyle:st];
				break;
			}
		}
	}
}


#pragma mark -
#pragma mark - geometry
///*********************************************************************************************************************
///
/// method:			setSize:
/// scope:			public instance method
/// overrides:
/// description:	sets the object's size to the width and height passed
/// 
/// parameters:		<size> the new size
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)			setSize:(NSSize) size
{
	[self notifyVisualChange];
	m_bounds.size = size;
	[self notifyVisualChange];
}


///*********************************************************************************************************************
///
/// method:			size
/// scope:			public instance method
/// overrides:
/// description:	returns the size of the object regardless of angle, etc.
/// 
/// parameters:		none
/// result:			the object's size
///
/// notes:			
///
///********************************************************************************************************************

- (NSSize)			size
{
	return [self logicalBounds].size;
}


///*********************************************************************************************************************
///
/// method:			bounds
/// scope:			public instance method
/// overrides:
/// description:	return the full extent of the object within the drawing, including any decoration, etc.
/// 
/// parameters:		none
/// result:			the full bounds of the object
///
/// notes:			the object must draw only within its declared bounds. If it draws outside of this, it will leave
///					trails and debris when moved, rotated or scaled. All style-based decoration must be contained within
///					bounds. The style has the method -extraSpaceNeeded to help you determine the correct bounds.
///
///********************************************************************************************************************

- (NSRect)			bounds
{
	return m_bounds;
}


///*********************************************************************************************************************
///
/// method:			apparentBounds
/// scope:			public instance method
/// overrides:
/// description:	returns the visually apparent bounds
/// 
/// parameters:		none
/// result:			the apparent bounds rect
///
/// notes:			this bounds is intended for use when aligning objects to each other or to guides, etc. By default
///					it is the same as the bounds, but subclasses may redefine it to be something else.
///
///********************************************************************************************************************

- (NSRect)			apparentBounds
{
	return [self bounds];
}


///*********************************************************************************************************************
///
/// method:			logicalBounds
/// scope:			public instance method
/// overrides:
/// description:	returns the logical bounds
/// 
/// parameters:		none
/// result:			the logical bounds
///
/// notes:			the logical bounds is the object's bounds ignoring any stylistic effects. Unlike the other bounds,
///					it remains constant for a given paht even if styles change. By default it is the same as the bounds,
///					but subclasses will probably wish to redefine it.
///
///********************************************************************************************************************

- (NSRect)			logicalBounds
{
	return [self bounds];
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
/// notes:			
///********************************************************************************************************************

- (NSSize)			extraSpaceNeeded
{
	if ([self style])
		return [[self style] extraSpaceNeeded];
	else
		return NSMakeSize( 0, 0 );
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			intersectsRect:
/// scope:			public instance method
/// overrides:
/// description:	test whether the object intersects a given rectangle
/// 
/// parameters:		<rect> the rect to test against
/// result:			YES if the object intersects the rect, NO otherwise
///
/// notes:			used for selecting using a margquee, and other things. By default this merely tests for an
///					intersection with the bounds, but in most cases subclasses will want to refine this appropriately
///
///********************************************************************************************************************

- (BOOL)			intersectsRect:(NSRect) rect
{
	if ([self visible] && NSIntersectsRect([self bounds], rect ))
		return [self rectHitsPath:rect];
	else
		return NO;	// invisible objects don't intersect anything
}


///*********************************************************************************************************************
///
/// method:			moveToPoint:
/// scope:			public instance method
/// overrides:
/// description:	set the location of the object to the given point
/// 
/// parameters:		<p> the point to locate the object at
/// result:			none
///
/// notes:			the object can decide how it aligns itself about its own location in any way that is self-consistent.
///					the default is to align the origin of the bounds at the point, but most subclasses do something
///					more sophisticated
///
///********************************************************************************************************************

- (void)			moveToPoint:(NSPoint) p
{
	if ( ! NSEqualPoints( p, [self location]))
	{
		[[[self undoManager] prepareWithInvocationTarget:self] moveToPoint:[self location]];
		[self notifyVisualChange];
		m_bounds.origin = p;
		[self notifyVisualChange];
	}
}


///*********************************************************************************************************************
///
/// method:			moveByX:byY:
/// scope:			public instance method
/// overrides:
/// description:	offsets the object's position by the values passed
/// 
/// parameters:		<dx> add this much to the x coordinate
///					<dy> add this much to the y coordinate
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)			moveByX:(float) dx byY:(float) dy
{
	if ( dx != 0 && dy != 0 )
	{
		[[[self undoManager] prepareWithInvocationTarget:self] moveToPoint:[self location]];
		[self notifyVisualChange];
		NSOffsetRect( m_bounds, dx, dy );
		[self notifyVisualChange];
	}
}


///*********************************************************************************************************************
///
/// method:			location
/// scope:			public instance method
/// overrides:
/// description:	return the object's current location
/// 
/// parameters:		none
/// result:			the object's location
///
/// notes:			
///
///********************************************************************************************************************

- (NSPoint)			location
{
	return [self logicalBounds].origin;
}


///*********************************************************************************************************************
///
/// method:			angle
/// scope:			public instance method
/// overrides:
/// description:	return the object's current angle
/// 
/// parameters:		none
/// result:			the object's angle
///
/// notes:			override if your subclass implements variable angles
///
///********************************************************************************************************************

- (float)			angle
{
	return 0.0f;
}


- (void)				rotateToAngle:(float) angle
{
	#pragma unused(angle)
	
	// placeholder
}


///*********************************************************************************************************************
///
/// method:			angleInDegrees
/// scope:			public instance method
/// overrides:		
/// description:	return the shape's current rotation angle
/// 
/// parameters:		none
/// result:			the shape's angle in degrees
///
/// notes:			
///
///********************************************************************************************************************

- (float)				angleInDegrees
{
	return fmodf(([self angle] * 180.0f )/ pi, 360.0 );
}


#pragma mark -
- (void)			setOffset:(NSSize) offs
{
	#pragma unused(offs)
	
	// placeholder
}


- (NSSize)			offset
{
	return NSZeroSize;
}


- (void)			resetOffset
{

}


///*********************************************************************************************************************
///
/// method:			transform
/// scope:			protected instance method
/// overrides:
/// description:	return a transform that maps the object's stored path to its true location in the drawing
/// 
/// parameters:		none
/// result:			a transform
///
/// notes:			override for real transforms - the default merely returns the identity matrix
///
///********************************************************************************************************************

- (NSAffineTransform*)	transform
{
	return [NSAffineTransform transform];
}


///*********************************************************************************************************************
///
/// method:			containerTransform
/// scope:			protected instance method
/// overrides:
/// description:	return the container's transform
/// 
/// parameters:		none
/// result:			a transform
///
/// notes:			the container transform must be taken into account for rendering this object, as it accounts for
///					groups and other possible containers.
///
///********************************************************************************************************************

- (NSAffineTransform*)	containerTransform
{
	return [[self container] renderingTransform];
}


#pragma mark -
#pragma mark - drawing tool information

- (void)			creationTool:(DKDrawingTool*) tool willBeginCreationAtPoint:(NSPoint) p
{
	#pragma unused(tool)
	#pragma unused(p)
	
	// override to make use of this event
}


- (void)			creationTool:(DKDrawingTool*) tool willEndCreationAtPoint:(NSPoint) p
{
	#pragma unused(tool)
	#pragma unused(p)
	
	// override to make use of this event
}



///*********************************************************************************************************************
///
/// method:			objectIsValid
/// scope:			public instance method
/// overrides:
/// description:	return whether the object is valid in terms of having a visible, usable state
/// 
/// parameters:		none
/// result:			YES if valid, NO otherwise
///
/// notes:			subclasses must override and implement this appropriately. It is called by the object creation tool
///					at the end of a creation operation to determine if what was created is in any way useful. Objects that
///					cannot be used will not be added to the drawing. The object type needs to decide what constitutes
///					validity - for example shapes with zero size or paths with zero length are likely not valid.
///
///********************************************************************************************************************

- (BOOL)			objectIsValid
{
	return NO;
}




#pragma mark -
#pragma mark - snapping to guides, grid and other objects (utility methods)
///*********************************************************************************************************************
///
/// method:			snappedMousePoint
/// scope:			protected instance method
/// overrides:
/// description:	offset the point to cause snap to grid + guides accoding to the drawing's settings
/// 
/// parameters:		<mp> a point which is the proposed location of the shape
///					<snapControl> a control flag used to temporarily enable/disable snapping
/// result:			a new point which may be offset from the input enough to snap it to the guides and grid
///
/// notes:			DKObjectOwnerLayer + DKDrawing implements the details of this method. The snapControl flag is
///					intended to come from a modifier flag - usually <ctrl>.
///
///********************************************************************************************************************

- (NSPoint)				snappedMousePoint:(NSPoint) mp withControlFlag:(BOOL) snapControl
{
	if ([self mouseSnappingEnabled] && [self layer])
		mp = [(DKObjectOwnerLayer*)[self layer] snappedMousePoint:mp forObject:self withControlFlag:snapControl];

	return mp;
}


///*********************************************************************************************************************
///
/// method:			snappedMousePoint:forSnappingPointsWithControlFlag:
/// scope:			public instance method
/// overrides:
/// description:	offset the point to cause snap to grid + guides according to the drawing's settings
/// 
/// parameters:		<mp> a point which is the proposed location of the shape
///					<snapControl> a flag which enables/disables snapping temporarily
/// result:			a new point which may be offset from the input enough to snap it to the guides and grid
///
/// notes:			given a proposed location, this modifies it by checking if any of the points returned by the
///					object's snappingPoints method will snap. The result can be passed to moveToPoint:
///
///********************************************************************************************************************

- (NSPoint)			snappedMousePoint:(NSPoint) mp forSnappingPointsWithControlFlag:(BOOL) snapControl
{
	if ([self mouseSnappingEnabled] && [self drawing])
	{
		// factor in snap to grid + guides
		
		mp = [[self drawing] snapToGrid:mp withControlFlag:snapControl];
		
		NSSize	offs;
		
		offs.width = mp.x - [self location].x;
		offs.height = mp.y - [self location].y;

		NSSize snapOff = [[self drawing] snapPointsToGuide:[self snappingPointsWithOffset:offs]];
		
		mp.x += snapOff.width;
		mp.y += snapOff.height;
	}

	return mp;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			snappingPoints
/// scope:			public instance method
/// overrides:
/// description:	return an array of NSpoint values representing points that can be snapped to guides
/// 
/// parameters:		none
/// result:			a list of points (NSValues)
///
/// notes:			
///
///********************************************************************************************************************

- (NSArray*)		snappingPoints
{
	return [self snappingPointsWithOffset:NSZeroSize];
}


///*********************************************************************************************************************
///
/// method:			snappingPointsWithOffset:
/// scope:			public instance method
/// overrides:
/// description:	return an array of NSpoint values representing points that can be snapped to guides
/// 
/// parameters:		<offset> an offset value that is added to each point
/// result:			a list of points (NSValues)
///
/// notes:			snapping points are locations within an object that will snap to a guide. List can be empty.
///
///********************************************************************************************************************

- (NSArray*)		snappingPointsWithOffset:(NSSize) offset
{
	NSPoint p = [self location];
	
	p.x += offset.width;
	p.y += offset.height;
	
	return [NSArray arrayWithObject:[NSValue valueWithPoint:p]];
}


///*********************************************************************************************************************
///
/// method:			mouseOffset
/// scope:			public instance method
/// overrides:
/// description:	returns the offset between the mouse point and the shape's location during a drag
/// 
/// parameters:		none
/// result:			mouse offset during a drag
///
/// notes:			result is undefined except during a dragging operation
///
///********************************************************************************************************************

- (NSSize)			mouseOffset
{
	return m_mouseOffset;
}


#pragma mark -
#pragma mark - getting dimensions in drawing coordinates
///*********************************************************************************************************************
///
/// method:			convertLength:
/// scope:			public instance method
/// overrides:
/// description:	convert a distance in quartz coordinates to the units established by the drawing grid
/// 
/// parameters:		<len> a distance in pixels
/// result:			the distance in drawing units
///
/// notes:			this is a conveniece API to query the drawing's grid layer
///
///********************************************************************************************************************

- (float)			convertLength:(float) len
{
	return [[self drawing] convertLength:len];
}


///*********************************************************************************************************************
///
/// method:			convertPointToDrawing:
/// scope:			public instance method
/// overrides:
/// description:	convert a point in quartz coordinates to the units established by the drawing grid
/// 
/// parameters:		<pt> a point value
/// result:			the equivalent point in drawing units
///
/// notes:			this is a conveniece API to query the drawing's grid layer
///
///********************************************************************************************************************

- (NSPoint)			convertPointToDrawing:(NSPoint) pt
{
	return [[self drawing] convertPoint:pt];

}


#pragma mark -
#pragma mark - hit testing
///*********************************************************************************************************************
///
/// method:			hitPart:
/// scope:			public instance method
/// overrides:
/// description:	hit test the object
/// 
/// parameters:		<pt> the mouse location
/// result:			a part code representing which part of the object got hit, if any
///
/// notes:			part codes are private to the object class, except for 0 = nothing hit and -1 = entire object hit.
///					for other parts, the object is free to return any code it likes and attach any meaning it wishes.
///					the part code is passed back by the mouse event methods but apart from 0 and -1 is never interpreted
///					by any other object
///
///********************************************************************************************************************

- (int)				hitPart:(NSPoint) pt
{
	if ([self visible])
	{
		int pc = ( NSMouseInRect( pt, [self bounds], YES )? kGCDrawingEntireObjectPart : kGCDrawingNoPart );
	
		if (( pc == kGCDrawingEntireObjectPart ) && [self isSelected] && ![self locked])
			pc = [self hitSelectedPart:pt forSnapDetection:NO];
			
		return pc;
	}
	else
		return kGCDrawingNoPart;	// can never hit invisible objects
}


///*********************************************************************************************************************
///
/// method:			hitSelectedPart:
/// scope:			protected instance method
/// overrides:
/// description:	hit test the object in the selected state
/// 
/// parameters:		<pt> the mouse location
///					<snap> is YES if called to detect snap, NO otherwise
/// result:			a part code representing which part of the selected object got hit, if any
///
/// notes:			this is a factoring of the general hitPart: method to allow parts that only come into play when
///					selected to be hit tested. It is also used when snapping to objects. Subclasses should override
///					for the partcodes they define such as control knobs that operate when selected.
///
///********************************************************************************************************************

- (int)				hitSelectedPart:(NSPoint) pt forSnapDetection:(BOOL) snap
{
	#pragma unused(pt)
	#pragma unused(snap)
	
	return kGCDrawingEntireObjectPart;
}


///*********************************************************************************************************************
///
/// method:			pointForPartcode:
/// scope:			public instance method
/// overrides:
/// description:	return the point associated with the part code
/// 
/// parameters:		<pc> a valid partcode for this object
/// result:			the current point associated with the partcode
///
/// notes:			if partcode is no object, returns {-1,-1}, if entire object, return location. Object classes
///					should override this to correctly implement it for partcodes they define
///
///********************************************************************************************************************

- (NSPoint)			pointForPartcode:(int) pc
{
	if ( pc == kGCDrawingEntireObjectPart )
		return [self location];
	else
		return NSMakePoint( -1, -1 );
}


///*********************************************************************************************************************
///
/// method:			knobTypeForPartCode:
/// scope:			public instance method
/// overrides:
/// description:	provide a mapping between the object's partcode and a knob type draw for that part
/// 
/// parameters:		<pc> a valid partcode for this object
/// result:			a valid knob type
///
/// notes:			knob types are defined by DKKnob, they describe the functional type of the knob, plus the locked
///					state. Concrete subclasses should override this unless the default suffices.
///
///********************************************************************************************************************

- (DKKnobType)		knobTypeForPartCode:(int) pc
{
	#pragma unused(pc)
	
	DKKnobType result = kDKControlPointKnobType;
	
	if ([self locked])
		result |= kDKKnobIsDisabledFlag;
		
	return result;
}


///*********************************************************************************************************************
///
/// method:			pathBitmapInRect:
/// scope:			private instance method
/// overrides:		
/// description:	given a rect in drawing coordinates, create a bitmap of the same size and draw the object into
///					it. The rect can be zero-sized, in which case a 1x1 bitmap is returned.
/// 
/// parameters:		<aRect> a rect in drawing coordinates
/// result:			an 8-bit bitmap having the same size as the rect containing the object's image
///
/// notes:			this is used for hit testing - the rect passed can represent the selection rect or the hit point.
///					Called by rectHitsPath: and pointHitsPath: which do additional checks. The bitmap is returned
///					retained - if you call this you must release the result.
///
///********************************************************************************************************************

- (NSBitmapImageRep*)	pathBitmapInRect:(NSRect) aRect
{
	//NSLog(@"building bitmap for rect: %@", NSStringFromRect( aRect ));
	
	NSBitmapImageRep* tempBits = nil;
	
	if( aRect.size.width < 1 )
		aRect.size.width = 1;
		
	if( aRect.size.height < 1 )
		aRect.size.height = 1;
	
	tempBits = [[NSBitmapImageRep alloc]	initWithBitmapDataPlanes:NULL
											pixelsWide:aRect.size.width
											pixelsHigh:aRect.size.height
											bitsPerSample:8
											samplesPerPixel:1
											hasAlpha:NO
											isPlanar:NO
											colorSpaceName:NSDeviceWhiteColorSpace
											bitmapFormat:0
											bytesPerRow:0
											bitsPerPixel:0 ];
											
	if( tempBits == nil )
		[NSException raise:NSInternalInconsistencyException format:@"hit bitmap couldn't be created - bailing"];
															
	// lock focus onto the image and draw the shape into it
															
	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:tempBits]];
	[[NSGraphicsContext currentContext] setShouldAntialias:NO];
	
	NSRect hr = NSMakeRect( 0, 0, aRect.size.width, aRect.size.height );
	[[NSColor whiteColor] set];
	NSRectFill( hr );
	
	// need to transform the origin of the image to the right place so that
	// when we draw, the correct pixels are plonked into the bitmap. 
	
	NSAffineTransform* ot = [NSAffineTransform transform];
	[ot translateXBy:-aRect.origin.x yBy:-aRect.origin.y];
	[ot concat];
	
	// draw self using hit style
	
	[self drawContentForHitBitmap];
	[NSGraphicsContext restoreGraphicsState];
	
	// note that the bitmap is returned retained, not autoreleased. This is done because it's private to the class
	// and the callers will release it - it avoids bitmaps piling up in the autorelease pool during a drag.
	
	return tempBits;
}


///*********************************************************************************************************************
///
/// method:			rectHitsPath:
/// scope:			private instance method
/// overrides:		
/// description:	test if a rect encloses any of the shape's actual pixels
/// 
/// parameters:		<r> the rect to test
/// result:			YES if at least one pixel enclosed by the rect, NO otherwise
///
/// notes:			note this can be an expensive way to test this - eliminate all obvious trivial cases first.
///
///********************************************************************************************************************

- (BOOL)				rectHitsPath:(NSRect) r
{
	NSRect	ir = NSIntersectionRect( r, [self bounds]);
	BOOL	hit = NO;
	
	if ( ir.size.width > 0.0 && ir.size.height > 0.0 )
	{
		// if ir is equal to our bounds, we know that <r> fully encloses this, so there's no need
		// to perform the expensive bitmap test - just return YES. This assumes that the shape draws *something*
		// somewhere within its bounds, which is not unreasonable.
		
		if( NSEqualRects( ir, [self bounds]))
			return YES;
		else
		{
			NSBitmapImageRep* bits = [self pathBitmapInRect:ir];
			
			// if any pixels in this bitmap are set, we have a hit.
			
			int				x, y;
			unsigned int	pixel;
			
			for( y = 0; y < ir.size.height; ++y )
			{
				for( x = 0; x < ir.size.width; ++x )
				{
					[bits getPixel:&pixel atX:x y:y];
					
					if ( pixel < 255 )
					{
						hit = YES;
						goto endOfLoop;
					}
				}
			}
		
		endOfLoop:
			// bits need to be released
			
			[bits release];
		}
	}
	
	return hit;
}


///*********************************************************************************************************************
///
/// method:			pointHitsPath:
/// scope:			private instance method
/// overrides:		
/// description:	test a point against the offscreen bitmap representation of the shape
/// 
/// parameters:		<p> the point to test
/// result:			YES if the point hit the shape's pixels, NO otherwise
///
/// notes:			white pixels are considered part of the background
///
///********************************************************************************************************************

- (BOOL)				pointHitsPath:(NSPoint) p
{
	if( NSPointInRect( p, [self bounds]))
	{
		NSRect				pr = NSMakeRect( p.x, p.y, 1, 1 );
		NSBitmapImageRep*	bm = [self pathBitmapInRect:pr];
		unsigned int		pixel;
		
		[bm getPixel:&pixel atX:0 y:0];
		[bm release];
		
		return ( pixel < 255 );
	}
	
	return NO;
}


#pragma mark -
#pragma mark - basic event handling

///*********************************************************************************************************************
///
/// method:			mouseDownAtPoint:inPart:event:
/// scope:			public instance method
/// overrides:
/// description:	the mouse went down in this object
/// 
/// parameters:		<mp> the mouse point (already converted to the relevant view - gives drawing relative coordinates)
///					<partcode> the partcode that was returned by hitPart if non-zero.
///					<evt> the original event
/// result:			none
///
/// notes:			default method records the mouse offset, but otherwise you will override to make use of this
///
///********************************************************************************************************************

- (void)			mouseDownAtPoint:(NSPoint) mp inPart:(int) partcode event:(NSEvent*) evt
{
	m_mouseOffset.width = mp.x - [self location].x;
	m_mouseOffset.height = mp.y - [self location].y;
	m_mouseEverMoved = NO;
	m_inMouseOp = YES;
	
	if([evt clickCount] > 1)
		[self mouseDoubleClickedAtPoint:mp inPart:partcode event:evt];
}


///*********************************************************************************************************************
///
/// method:			mouseDraggedAtPoint:inPart:event:
/// scope:			public instance method
/// overrides:
/// description:	the mouse is dragging within this object
/// 
/// parameters:		<mp> the mouse point (already converted to the relevant view - gives drawing relative coordinates)
///					<partcode> the partcode that was returned by hitPart if non-zero.
///					<evt> the original event
/// result:			none
///
/// notes:			default method moves the entire object, and snaps to grid and guides if enabled. Control key disables
///					snapping temporarily.
///
///********************************************************************************************************************

- (void)			mouseDraggedAtPoint:(NSPoint) mp inPart:(int) partcode event:(NSEvent*) evt
{
	#pragma unused(partcode)
	
	mp.x -= m_mouseOffset.width;
	mp.y -= m_mouseOffset.height;
	
	BOOL controlKey = (([evt modifierFlags] & NSControlKeyMask) != 0 );
	mp = [self snappedMousePoint:mp forSnappingPointsWithControlFlag:controlKey];
	
	[self moveToPoint:mp];
	m_mouseEverMoved = YES;
}


///*********************************************************************************************************************
///
/// method:			mouseUpAtPoint:inPart:event:
/// scope:			public instance method
/// overrides:
/// description:	the mouse went up in this object
/// 
/// parameters:		<mp> the mouse point (already converted to the relevant view - gives drawing relative coordinates)
///					<partcode> the partcode that was returned by hitPart if non-zero.
///					<evt> the original event
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)			mouseUpAtPoint:(NSPoint) mp inPart:(int) partcode event:(NSEvent*) evt
{
	#pragma unused(mp)
	#pragma unused(partcode)
	#pragma unused(evt)
	
	if ( m_mouseEverMoved )
	{
		[[self undoManager] setActionName:NSLocalizedString( @"Move", @"undo string for move object")];
		m_mouseEverMoved = NO;
	}
	
	m_inMouseOp = NO;
}


///*********************************************************************************************************************
///
/// method:			currentView
/// scope:			public instance method
/// overrides:
/// description:	get the view currently drawing or passing events to this
/// 
/// parameters:		none
/// result:			the view that is either drawing or handling the mouse/responder events
///
/// notes:			the view is only meaningful when called from within a drawing or event handling method.
///
///********************************************************************************************************************

- (NSView*)			currentView
{
	return [[self layer] currentView];
}


///*********************************************************************************************************************
///
/// method:			mouseDoubleClickedAtPoint:inPart:event:
/// scope:			public instance method
/// overrides:
/// description:	the mouse was double-clicked in this object
/// 
/// parameters:		<mp> the mouse point (already converted to the relevant view - gives drawing relative coordinates)
///					<partcode> the partcode that was returned by hitPart if non-zero.
///					<evt> the original event
/// result:			none
///
/// notes:			default method does nothing. Called from default mouseDown: method - if you are overriding that
///					and not calling super, this won't be automatically called.
///
///********************************************************************************************************************

- (void)			mouseDoubleClickedAtPoint:(NSPoint) mp inPart:(int) partcode event:(NSEvent*) evt
{
	#pragma unused(mp)
	#pragma unused(partcode)
	#pragma unused(evt)
}


///*********************************************************************************************************************
///
/// method:			cursorForPartcode:
/// scope:			public instance method
/// overrides:
/// description:	return the cursor displayed when a given partcode is hit or entered
/// 
/// parameters:		<partcode> the partcode
///					<button> YES if the mouse left button is pressed, NO otherwise
/// result:			a cursor object
///
/// notes:			the cursor may be displayed when the mouse hovers over or is clicked in the area indicated by the
///					partcode. The default is simply to return the standard arrow - override for others.
///
///********************************************************************************************************************

- (NSCursor*)		cursorForPartcode:(int) partcode mouseButtonDown:(BOOL) button
{
	#pragma unused(partcode)
	#pragma unused(button)
	
	return [NSCursor arrowCursor];
}


#pragma mark -
#pragma mark - contextual menu
///*********************************************************************************************************************
///
/// method:			populateContextualMenu:
/// scope:			public instance method
/// overrides:
/// description:	allows the object to populate the menu with commands that are relevant to its current state and type
/// 
/// parameters:		<theMenu> a menu - add items and commands to it as required
/// result:			YES if any items were added, NO otherwise.
///
/// notes:			the defualt method adds commands to copy and paste the style
///
///********************************************************************************************************************

- (BOOL)			populateContextualMenu:(NSMenu*) theMenu
{
	// if the object supports any contextual menu commands, it should add them to the menu and return YES. If subclassing,
	// you should call the inherited method first so that the menu is the union of all the ancestor's added methods.
	
	[[theMenu addItemWithTitle:NSLocalizedString(@"Copy Drawing Style", @"menu item for copy style") action:@selector( copyDrawingStyle: ) keyEquivalent:@""] setTarget:self];
	[[theMenu addItemWithTitle:NSLocalizedString(@"Paste Drawing Style", @"menu item for paste style") action:@selector( pasteDrawingStyle: ) keyEquivalent:@""] setTarget:self];
	
	return YES;
}


#pragma mark -
#pragma mark - swatch
///*********************************************************************************************************************
///
/// method:			swatchImageWithSize:
/// scope:			public instance method
/// overrides:
/// description:	returns an image of this object rendered using its current style and path
/// 
/// parameters:		<size> desired size of the image - shape is scaled to fit in this size
/// result:			the image
///
/// notes:			
///
///********************************************************************************************************************

- (NSImage*)		swatchImageWithSize:(NSSize) size
{
	NSImage* image = [[NSImage alloc] initWithSize:size];
	[image setFlipped:YES];
	
	DKDrawableObject*	cc = [self copy];
	NSRect				br = [cc bounds];
	float				sx, sy;
	
	sx = br.size.width / size.width;
	sy = br.size.height / size.height;
	
	NSAffineTransform* ot = [NSAffineTransform transform];
	[ot translateXBy:-br.origin.x yBy:-br.origin.y];
	[ot scaleXBy:sx yBy:sy];

	[image lockFocus];
	[[NSColor clearColor] set];
	NSRectFill( NSMakeRect( 0, 0, size.width, size.height ));
	
	[ot concat];
	
	[cc drawContentWithSelectedState:NO];
	[image unlockFocus];
	
	[cc release];
	
	return [image autorelease];
}


#pragma mark -
#pragma mark - user info
///*********************************************************************************************************************
///
/// method:			setUserInfo:
/// scope:			public instance method
/// overrides:
/// description:	attach a dictionary of metadata to the object
/// 
/// parameters:		<info> a dictionary containing anything you wish
/// result:			none
///
/// notes:			the drawkit does not interpret this data at all, but will archive and copy it as necessary. To
///					make this more intelligent when used with dictionaries, if there is already user info and it's
///					a mutable dictionary and the info passed is a dictionary, the dictionaries are merged to avoid
///					any potential data loss. This flags a status change but not a visual one.
///
///********************************************************************************************************************

- (void)			setUserInfo:(id) info
{
	// check if we should merge
	
	if([info isKindOfClass:[NSDictionary class]] && [m_userInfo isKindOfClass:[NSMutableDictionary class]])
	{
		[(NSMutableDictionary*)m_userInfo addEntriesFromDictionary:info];
	}
	else
	{
		id mc = [info mutableCopy];
		[m_userInfo release];
		m_userInfo = mc;
	}
	[self notifyStatusChange];
}


///*********************************************************************************************************************
///
/// method:			userInfo
/// scope:			public instance method
/// overrides:
/// description:	get the attached user info
/// 
/// parameters:		none
/// result:			the user info
///
/// notes:			
///
///********************************************************************************************************************

- (id)				userInfo
{
	return m_userInfo;
}


#pragma mark -
#pragma mark - user level commands that can be responded to by this object (and its subclasses)
///*********************************************************************************************************************
///
/// method:			copyDrawingStyle:
/// scope:			public action method
/// overrides:
/// description:	copies the object's style to the general pasteboard
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (IBAction)		copyDrawingStyle:(id) sender
{
	#pragma unused(sender)
	
	// allows the attached style to be copied to the clipboard.
	
	if ([self style] != nil )
		[[self style] copyToPasteboard:[NSPasteboard generalPasteboard]];
}


///*********************************************************************************************************************
///
/// method:			pasteDrawingStyle:
/// scope:			public action method
/// overrides:
/// description:	pastes a style from the general pasteboard onto the object
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			attempts to maintain shared styles by using the style's name initially.
///
///********************************************************************************************************************

- (IBAction)		pasteDrawingStyle:(id) sender
{
	#pragma unused(sender)
	
	if ( ![self locked])
	{
		DKStyle* style = [DKStyle styleFromPasteboard:[NSPasteboard generalPasteboard]];
		
		if ( style != nil )
		{
			[self setStyle:style];
			[[self undoManager] setActionName:NSLocalizedString(@"Paste Style", "undo string for object paste style")];
		}
	}
}




#ifdef qIncludeGraphicDebugging
#pragma mark -
#pragma mark - debugging

- (IBAction)		toggleShowBBox:(id) sender
{
	#pragma unused(sender)
	
	m_showBBox = !m_showBBox;
	[self notifyVisualChange];
}


- (IBAction)		toggleClipToBBox:(id) sender
{
	#pragma unused(sender)
	
	m_clipToBBox = !m_clipToBBox;
	[self notifyVisualChange];
}


- (IBAction)		toggleShowPartcodes:(id) sender
{
	#pragma unused(sender)
	
	m_showPartcodes = !m_showPartcodes;
	[self notifyVisualChange];
}


- (IBAction)		toggleShowTargets:(id) sender
{
	#pragma unused(sender)
	
	m_showTargets = !m_showTargets;
	[self notifyVisualChange];
}

#endif


#pragma mark -
#pragma mark As an NSObject
- (void)			dealloc
{
	if ( m_style != nil )
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:m_style];
		[m_style styleWillBeRemoved:self];
		[m_style release];
	}
	[m_userInfo release];
	[super dealloc];
}


- (id)				init
{
	self = [super init];
	if (self != nil )
	{
		NSAssert(mContainerRef == nil, @"Expected init to zero");
		[self setStyle:[DKStyle defaultStyle]];
		NSAssert(NSEqualSizes(m_mouseOffset, NSZeroSize), @"Expected init to zero");
		NSAssert(m_userInfo == nil, @"Expected init to zero");
		
		NSAssert(!m_mouseEverMoved, @"Expected init to NO");
		m_visible = YES;
		NSAssert(!m_locked, @"Expected init to NO");
		m_snapEnable = YES;
		NSAssert(NSEqualRects(m_bounds, NSZeroRect), @"Expected init to zero");
#ifdef qDebug
		NSAssert(!m_showBBox, @"Expected init to NO");
		NSAssert(!m_clipToBBox, @"Expected init to NO");
		NSAssert(!m_showPartcodes, @"Expected init to NO");
		NSAssert(!m_showTargets, @"Expected init to NO");
#endif
		// n.b. drawables without a style object are legitimate
	}
	return self;
}


#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)			encodeWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[coder encodeConditionalObject:[self container] forKey:@"container"];
	[coder encodeObject:[self style] forKey:@"style"];
	[coder encodeObject:[self userInfo] forKey:@"userinfo"];
	
	[coder encodeBool:[self visible] forKey:@"visible"];
	[coder encodeBool:[self locked] forKey:@"locked"];
}


- (id)				initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
//	LogEvent_(kFileEvent, @"decoding drawable object %@", self);

	self = [super init];
	if (self != nil )
	{
		[self setContainer:[coder decodeObjectForKey:@"container"]];
		
		// if container is nil, as it could be for very old test files, set it to the same value as the owner.
		// for groups this is incorrect and the file won't open correctly.
		
		if ([self container] == nil )
		{
			// more recent older files wrote this key as "parent" - try that 
			
			[self setContainer:[coder decodeObjectForKey:@"parent"]];
		}
		[self setStyle:[coder decodeObjectForKey:@"style"]];
		NSAssert(NSEqualSizes(m_mouseOffset, NSZeroSize), @"Expected init to zero");
		[self setUserInfo:[coder decodeObjectForKey:@"userinfo"]];
		
		NSAssert(!m_mouseEverMoved, @"Expected init to NO");
		[self setVisible:[coder decodeBoolForKey:@"visible"]];
		[self setLocked:[coder decodeBoolForKey:@"locked"]];
		m_snapEnable = YES;
		NSAssert(NSEqualRects(m_bounds, NSZeroRect), @"Expected init to zero");
#ifdef qDebug
		NSAssert(!m_showBBox, @"Expected init to NO");
		NSAssert(!m_clipToBBox, @"Expected init to NO");
		NSAssert(!m_showPartcodes, @"Expected init to NO");
		NSAssert(!m_showTargets, @"Expected init to NO");
#endif
	}
	return self;
}


#pragma mark -
#pragma mark As part of NSCopying Protocol
- (id)				copyWithZone:(NSZone*) zone
{
	DKDrawableObject* copy = [[[self class] allocWithZone:zone] init];
	
	[copy setContainer:nil];				// we don't know who will own the copy
	
	DKStyle* styleCopy = [[self style] copy];
	[copy setStyle:styleCopy];			// style will be shared if set to be shared, otherwise copied
	[styleCopy release];
										// gets a deep copy of the user info
	
	if([self userInfo] != nil )
	{									
		NSDictionary*	ucopy = [[self userInfo] deepCopy];
		[copy setUserInfo:ucopy];
		[ucopy release];
	}
	return copy;
}


#pragma mark -
#pragma mark As part of NSMenuValidation Protocol
- (BOOL)			validateMenuItem:(NSMenuItem*) item
{
	BOOL enable = NO;
	SEL	action = [item action];
	
	if (![self locked])
	{
		if ( action == @selector(pasteDrawingStyle:))
			enable = ([[NSPasteboard generalPasteboard] availableTypeFromArray:[NSArray arrayWithObject:kDKStylePasteboardType]] != nil );
	}
		
	// even locked objects can have their style copied
	
	if ( action == @selector(copyDrawingStyle:))
		enable = ([self style] != nil );
	
#ifdef qIncludeGraphicDebugging
	if ( action == @selector( toggleShowBBox:) ||
		 action == @selector( toggleClipToBBox:) ||
		 action == @selector( toggleShowTargets:) ||
		 action == @selector( toggleShowPartcodes:))
	{
		enable = YES;
		
		// set a checkmark next to those that are turned on
		
		if( action == @selector(toggleShowBBox:))
			[item setState:m_showBBox? NSOnState : NSOffState];
		else if ( action == @selector(toggleClipToBBox:))
			[item setState:m_clipToBBox? NSOnState : NSOffState];
		else if ( action == @selector(toggleShowTargets:))
			[item setState:m_showTargets? NSOnState : NSOffState];
		else if ( action == @selector(toggleShowPartcodes:))
			[item setState:m_showPartcodes? NSOnState : NSOffState];
	}
#endif

	return enable;
}


@end
