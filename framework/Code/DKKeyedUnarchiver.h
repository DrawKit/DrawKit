//
//  DKKeyedUnarchiver.h
//  GCDrawKit
//
//  Created by graham on 27/11/2008.
//  Copyright 2008 Apptree.net. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class DKImageDataManager;



@interface DKKeyedUnarchiver : NSKeyedUnarchiver
{
@private
	DKImageDataManager*		mImageManagerRef;
}

- (void)					setImageManager:(DKImageDataManager*) imgMgr;
- (DKImageDataManager*)		imageManager;

@end



/*

This class works identically to NSKeyedUnarchiver in every way, except that it can store a reference to the drawing's DKImageDataManager instance. This allows
 objects to dearchive images that are cached by the manager without requiring a valid back pointer to the drawing, which is often the case at -initWithCoder: time.
 
 Note that the image manager is archived and dearchived normally, but DKDrawing sets the coder's reference having dearchived it, so subsequent unarchiving can
 find it.


*/


