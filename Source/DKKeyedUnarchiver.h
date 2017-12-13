/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

@class DKImageDataManager;

/** @brief This class works identically to NSKeyedUnarchiver in every way, except that it can store a reference to the drawing's DKImageDataManager instance.

This class works identically to NSKeyedUnarchiver in every way, except that it can store a reference to the drawing's DKImageDataManager instance. This allows
 objects to dearchive images that are cached by the manager without requiring a valid back pointer to the drawing, which is often the case at -initWithCoder: time.
 
 Note that the image manager is archived and dearchived normally, but DKDrawing sets the coder's reference having dearchived it, so subsequent unarchiving can
 find it.
*/
@interface DKKeyedUnarchiver : NSKeyedUnarchiver {
@private
	DKImageDataManager* __unsafe_unretained mImageManagerRef;
}

// not retained because we know that it's retained by the drawing and the lifetime of the dearchiver is limited.
@property (unsafe_unretained) DKImageDataManager *imageManager;

@end
