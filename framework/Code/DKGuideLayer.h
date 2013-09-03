///**********************************************************************************************************************************
///  DKGuideLayer.h
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 28/08/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************


#import "DKLayer.h"


@class DKGuide;


@interface DKGuideLayer : DKLayer <NSCoding>
{
@private
	NSMutableArray*		m_hGuides;					// the list of horizontal guides
	NSMutableArray*		m_vGuides;					// the list of vertical guides
	BOOL				m_snapToGrid;				// YES if snap to grid is enabled
	BOOL				m_showDragInfo;				// YES if dragging a guide displays the floating info window
	DKGuide*			m_dragGuideRef;				// the current guide being dragged
	CGFloat				m_snapTolerance;			// the current snap tolerance value
	NSRect				mGuideDeletionZone;			// guides dragged outside this rect are deleted
	BOOL				mDrawGuidesInClipView;		// if YES, guides are extended to be drawn in the clip view of an enclosing scroller
}


// default snapping tolerance:

+ (void)				setDefaultSnapTolerance:(CGFloat) tol;
+ (CGFloat)				defaultSnapTolerance;

// adding and removing guides:

- (void)				addGuide:(DKGuide*) guide;
- (void)				removeGuide:(DKGuide*) guide;
- (void)				removeAllGuides;
- (DKGuide*)			createVerticalGuideAndBeginDraggingFromPoint:(NSPoint) p;
- (DKGuide*)			createHorizontalGuideAndBeginDraggingFromPoint:(NSPoint) p;

- (NSArray*)			guides;
- (void)				setGuides:(NSArray*) guides;

// finding guides close to a given position

- (DKGuide*)			nearestVerticalGuideToPosition:(CGFloat) pos;
- (DKGuide*)			nearestHorizontalGuideToPosition:(CGFloat) pos;
- (NSArray*)			verticalGuides;
- (NSArray*)			horizontalGuides;

// setting a common colour for the guides:

- (void)				setGuideColour:(NSColor*) colour;
- (NSColor*)			guideColour;

// set whether guides snap to grid or not

- (void)				setGuidesSnapToGrid:(BOOL) gridsnap;
- (BOOL)				guidesSnapToGrid;

// set the snapping tolerance for this layer

- (void)				setSnapTolerance:(CGFloat) tol;
- (CGFloat)				snapTolerance;

// set whether the info window is displayed or not

- (void)				setShowsDragInfoWindow:(BOOL) showsIt;
- (BOOL)				showsDragInfoWindow;

- (void)				setGuideDeletionRect:(NSRect) rect;
- (NSRect)				guideDeletionRect;

- (void)				setGuidesDrawnInEnclosingScrollview:(BOOL) drawOutside;
- (BOOL)				guidesDrawnInEnclosingScrollview;

// snapping points and rects to the guides:

- (NSPoint)				snapPointToGuide:(NSPoint) p;
- (NSRect)				snapRectToGuide:(NSRect) r;
- (NSRect)				snapRectToGuide:(NSRect) r includingCentres:(BOOL) centre;
- (NSSize)				snapPointsToGuide:(NSArray*) arrayOfPoints;
- (NSSize)				snapPointsToGuide:(NSArray*) arrayOfPoints verticalGuide:(DKGuide**) gv horizontalGuide:(DKGuide**) gh;

// redrawing the guides

- (void)				refreshGuide:(DKGuide*) guide;
- (NSRect)				guideRect:(DKGuide*) guide;

// user actions:

- (IBAction)			clearGuides:(id) sender;

@end

// each guide is implemented by an instance of DKGuide:


@interface DKGuide : NSObject <NSCoding>
{
@private
	CGFloat				m_position;
	BOOL				m_isVertical;
	NSColor*			m_colour;
}

- (void)				setGuidePosition:(CGFloat) pos;
- (CGFloat)				guidePosition;

- (void)				setIsVerticalGuide:(BOOL) vert;
- (BOOL)				isVerticalGuide;

- (void)				setGuideColour:(NSColor*) colour;
- (NSColor*)			guideColour;

- (void)				drawInRect:(NSRect) rect lineWidth:(CGFloat) lw;

@end


/*

A guide layer implements any number of horizontal and vertical guidelines and provides methods for snapping points and rectangles
to them.

A drawing typically has one guide layer, though you are not limited to just one - however since DKDrawing will generally provide
snapping to both guides and grid as a high-level method, having more than one guide layer can create ambiguities for the user
unless your client code takes account of the possibility of multiple guide layers.

The default snap tolerance for guides is 6 points.

By default guides don't snap to the grid. You can force a guide to snap to the grid even if this setting is off by dragging with
the shift key down.

*/

