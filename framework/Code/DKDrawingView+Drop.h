///**********************************************************************************************************************************
///  DKDrawingView+Drop.h
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by jason on 1/11/2007.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKDrawingView.h"


@interface DKDrawingView (DropHandling)

- (DKLayer*)			activeLayer;

@end



/*

Drag and Drop is extended down to the layer level by this category. When a layer is made active, the drawing view will register its
pasteboard types (because this registration must be performed by an NSView). Subsequently all drag/drop destination messages are
forwarded to the active layer, so the layer merely needs to implement those parts of the NSDraggingDestination protocol that it
is interested in, just as if it were a view. The layer can use [self currentView] if it needs to access the real view object.

Note that if the layer is locked or hidden, drag messages are not forwarded, so the layer does not need to implement this
check itself.

The default responses to the dragging destination calls are NSDragOperationNone, etc. This means that the layer MUST
correctly implement the protocol to its requirements, and not just "hope for the best".


*/
