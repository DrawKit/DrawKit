/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
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

- (instancetype)initWithFrame:(NSRect)frame withLayer:(DKLayer*)aLayer NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithCoder:(NSCoder *)decoder NS_DESIGNATED_INITIALIZER;

@end

@interface DKDrawablePDFView : NSView {
	DKDrawableObject* mObjectRef;
}

- (instancetype)initWithFrame:(NSRect)frame object:(DKDrawableObject*)obj NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithCoder:(NSCoder *)decoder NS_DESIGNATED_INITIALIZER;

@end
