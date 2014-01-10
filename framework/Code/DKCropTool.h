/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

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
