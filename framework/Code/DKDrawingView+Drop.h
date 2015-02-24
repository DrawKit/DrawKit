/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2015
 @copyright GNU GPL3; see LICENSE
*/

#import "DKDrawingView.h"

/** @brief Drag and Drop is extended down to the layer level by this category.

Drag and Drop is extended down to the layer level by this category. When a layer is made active, the drawing view will register its
pasteboard types (because this registration must be performed by an NSView). Subsequently all drag/drop destination messages are
forwarded to the active layer, so the layer merely needs to implement those parts of the NSDraggingDestination protocol that it
is interested in, just as if it were a view. The layer can use [self currentView] if it needs to access the real view object.

Note that if the layer is locked or hidden, drag messages are not forwarded, so the layer does not need to implement this
check itself.

The default responses to the dragging destination calls are NSDragOperationNone, etc. This means that the layer MUST
correctly implement the protocol to its requirements, and not just "hope for the best".
*/
@interface DKDrawingView (DropHandling)

/** @brief Returns the current active layer, by asking the controller for it

 DKDrawing maintains the active layer - look there for a method to set it
 @return a layer, the one that is currently active
 */
- (DKLayer*)activeLayer;

@end
