//
//  DKSelectionPDFView.h
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by graham on 30/09/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//

#import "DKDrawingView.h"


@class DKDrawableObject, DKObjectOwnerLayer, DKShapeGroup;


@interface DKSelectionPDFView : DKDrawingView
@end



@class DKObjectOwnerLayer, DKShapeGroup;


@interface DKLayerPDFView : DKDrawingView
{
	DKLayer* mLayerRef;
}

- (id)		initWithFrame:(NSRect) frame withLayer:(DKLayer*) aLayer;

@end


@interface DKDrawablePDFView : NSView
{
	DKDrawableObject*	mObjectRef;
}

- (id)		initWithFrame:(NSRect) frame object:(DKDrawableObject*) obj;


@end

/* these objects are never used to make a visible view. Their only function is to allow parts of a drawing to be
 selectively written to a PDF. This is made by DKObjectDrawingLayer internally and is private to the DrawKit.
 
 */
