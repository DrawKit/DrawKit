/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
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
    DKImageDataManager* mImageManagerRef;
}

- (void)setImageManager:(DKImageDataManager*)imgMgr;
- (DKImageDataManager*)imageManager;

@end
