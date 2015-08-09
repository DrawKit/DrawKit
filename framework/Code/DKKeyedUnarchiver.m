/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2015
 @copyright MPL2; see LICENSE.txt
*/

#import "DKKeyedUnarchiver.h"

@implementation DKKeyedUnarchiver

- (void)setImageManager:(DKImageDataManager*)imgMgr
{
	// not retained because we know that it's retained by the drawing and the lifetime of the dearchiver is limited.

	mImageManagerRef = imgMgr;
}

- (DKImageDataManager*)imageManager
{
	return mImageManagerRef;
}

@end
