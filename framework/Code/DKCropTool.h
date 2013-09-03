//
//  DKCropTool.h
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by graham on 24/06/2008.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//

#import "DKDrawingTool.h"

@interface DKCropTool : DKDrawingTool
{
	NSPoint	mAnchor;		// initial click pt
	NSRect	mZoomRect;		// zoom rect when dragged
}

@end


/*

Implements a very simple type of crop tool. You drag out a rect, and on mouse up the objects are cropped to that rect. A more sophisticated
tool might be preferred - this is to test the crop function.

*/


