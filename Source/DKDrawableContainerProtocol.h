/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class DKDrawing, DKLayer, DKImageDataManager, DKDrawableObject, DKMetadataItem;

/**
 
 Objects that claim ownership of a \c DKDrawableObject must formally implement this protocol.
 
 This includes DKObjectOwnerLayer, DKShapeGroup
 */
@protocol DKDrawableContainer <NSObject>

- (DKDrawing*)drawing;
- (DKLayer*)layer;
@property (readonly, copy) NSAffineTransform* renderingTransform;
- (DKImageDataManager*)imageManager;
- (NSUInteger)indexOfObject:(DKDrawableObject*)obj;

@optional
- (DKMetadataItem*)metadataItemForKey:(NSString*)key;
- (id)metadataObjectForKey:(NSString*)key;

@end

NS_ASSUME_NONNULL_END
