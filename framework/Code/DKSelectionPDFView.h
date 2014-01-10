/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import "DKDrawingView.h"

@class DKDrawableObject, DKObjectOwnerLayer, DKShapeGroup;

/** @brief these objects are never used to make a visible view.

these objects are never used to make a visible view. Their only function is to allow parts of a drawing to be
 selectively written to a PDF. This is made by DKObjectDrawingLayer internally and is private to the DrawKit.
*/
@interface DKSelectionPDFView : DKDrawingView
@end

@class DKObjectOwnerLayer, DKShapeGroup;

@interface DKLayerPDFView : DKDrawingView {
    DKLayer* mLayerRef;
}

- (id)initWithFrame:(NSRect)frame withLayer:(DKLayer*)aLayer;

@end

@interface DKDrawablePDFView : NSView {
    DKDrawableObject* mObjectRef;
}

- (id)initWithFrame:(NSRect)frame object:(DKDrawableObject*)obj;

@end
