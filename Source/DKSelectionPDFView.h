/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKDrawingView.h"

NS_ASSUME_NONNULL_BEGIN

@class DKDrawableObject, DKObjectOwnerLayer, DKShapeGroup;

/** @brief These objects are never used to make a visible view.

 These objects are never used to make a visible view. Their only function is to allow parts of a drawing to be
 selectively written to a PDF. This is made by \c DKObjectDrawingLayer internally and is private to the DrawKit.
*/
@interface DKSelectionPDFView : DKDrawingView
@end

@class DKObjectOwnerLayer, DKShapeGroup;

@interface DKLayerPDFView : DKDrawingView {
	__weak DKLayer* mLayerRef;
}

- (instancetype)initWithFrame:(NSRect)frame withLayer:(nullable DKLayer*)aLayer NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)decoder NS_DESIGNATED_INITIALIZER;

@end

@interface DKDrawablePDFView : NSView {
	__weak DKDrawableObject* mObjectRef;
}

- (instancetype)initWithFrame:(NSRect)frame object:(nullable DKDrawableObject*)obj NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)decoder NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
