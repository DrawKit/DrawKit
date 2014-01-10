/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import <Cocoa/Cocoa.h>

@class DKDrawing, DKLayer, DKImageDataManager, DKDrawableObject, DKMetadataItem;

@protocol DKDrawableContainer <NSObject>

- (DKDrawing*)drawing;
- (DKLayer*)layer;
- (NSAffineTransform*)renderingTransform;
- (DKImageDataManager*)imageManager;
- (NSUInteger)indexOfObject:(DKDrawableObject*)obj;

@optional
- (DKMetadataItem*)metadataItemForKey:(NSString*)key;
- (id)metadataObjectForKey:(NSString*)key;

@end

/*

Objects that claim ownership of a DKDrawableObject must formally implement this protocol.
 
This includes DKObjectOwnerLayer, DKShapeGroup


*/
