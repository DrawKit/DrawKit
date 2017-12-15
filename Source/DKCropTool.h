/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKDrawingTool.h"

/** @brief Implements a very simple type of crop tool.

Implements a very simple type of crop tool. You drag out a rect, and on mouse up the objects are cropped to that rect. A more sophisticated
tool might be preferred - this is to test the crop function.
*/
@interface DKCropTool : DKDrawingTool {
	NSPoint mAnchor; // initial click pt
	NSRect mZoomRect; // zoom rect when dragged
}

@end
