/**
 * @author Graham Cox, Apptree.net
 * @author Graham Miln, miln.eu
 * @author Contributions from the community
 * @date 2005-2013
 * @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

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

