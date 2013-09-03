///**********************************************************************************************************************************
///  DKDrawableContainerProtocol.h
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 01/03/2009
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************


#import <Cocoa/Cocoa.h>

@class DKDrawing, DKLayer, DKImageDataManager, DKDrawableObject, DKMetadataItem;


@protocol DKDrawableContainer <NSObject>

- (DKDrawing*)				drawing;
- (DKLayer*)				layer;
- (NSAffineTransform*)		renderingTransform;
- (DKImageDataManager*)		imageManager;
- (NSUInteger)				indexOfObject:(DKDrawableObject*) obj;

@optional
- (DKMetadataItem*)			metadataItemForKey:(NSString*) key;
- (id)						metadataObjectForKey:(NSString*) key;

@end





/*

Objects that claim ownership of a DKDrawableObject must formally implement this protocol.
 
This includes DKObjectOwnerLayer, DKShapeGroup


*/


