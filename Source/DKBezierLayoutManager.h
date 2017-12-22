/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

/** @brief This subclass of \c NSLayoutManager captures the laid-out text in a bezier path which it creates.

 This subclass of \c NSLayoutManager captures the laid-out text in a bezier path which it creates.
 It can be used where a normal \c NSLayoutManager would be used to return the text as a path.
*/
@interface DKBezierLayoutManager : NSLayoutManager {
	NSBezierPath* mPath;
}

@property (readonly, strong) NSBezierPath *textPath;
- (NSArray*)glyphPathsForContainer:(NSTextContainer*)container usedSize:(NSSize*)aSize;

@end
