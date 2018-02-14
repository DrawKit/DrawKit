/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKDrawingTool.h"

/** @brief This tool implements a zoom "magnifier" tool.

 This tool implements a zoom "magnifier" tool. It can zoom in, zoom out or zoom in to a dragged rect. It does not affect
 the data content of the drawing, only the view that is applying it, so does not generate any undo tasks.
*/
@interface DKZoomTool : DKDrawingTool {
@private
	BOOL mMode; //!< \c NO to zoom in, \c YES to zoom out
	NSEventModifierFlags mModeModifierMask; //!< modifier mask used to flip mode in response to modifier
	NSPoint mAnchor; //!< initial click pt
	NSRect mZoomRect; //!< zoom rect when dragged
}

/** @brief \c NO to zoom in, \c YES to zoom out.
 */
@property (nonatomic) BOOL zoomsOut;

/** @brief Modifier mask used to flip mode in response to modifier.
 */
@property NSEventModifierFlags modeModifierMask;

@end
