//
//  DKKeyedUnarchiver.m
//  GCDrawKit
//
//  Created by graham on 27/11/2008.
//  Copyright 2008 Apptree.net. All rights reserved.
//

#import "DKKeyedUnarchiver.h"


@implementation DKKeyedUnarchiver


- (void)					setImageManager:(DKImageDataManager*) imgMgr
{
	// not retained because we know that it's retained by the drawing and the lifetime of the dearchiver is limited.
	
	mImageManagerRef = imgMgr;
}


- (DKImageDataManager*)		imageManager
{
	return mImageManagerRef;
}

@end
