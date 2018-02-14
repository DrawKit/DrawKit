/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

/** @brief This class is used by DKTextAdornment to lay out text flowed into an arbitrary shape.

 This class is used by DKTextAdornment to lay out text flowed into an arbitrary shape. Given the bezier path representing
 the text container, this caches the text layout rects and uses that info to return rects on demand to the layout manager.
*/
@interface DKBezierTextContainer : NSTextContainer {
	NSBezierPath* mPath;
}

@property (nonatomic, copy, nullable) NSBezierPath* bezierPath;

@end
