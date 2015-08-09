/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2015
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

/** @brief This subclass of NSLayoutManager captures the laid-out text in a bezier path which it creates.

 This subclass of NSLayoutManager captures the laid-out text in a bezier path which it creates.
 It can be used where a normal NSLayoutManager would be used to return the text as a path.
*/
@interface DKBezierLayoutManager : NSLayoutManager {
	NSBezierPath* mPath;
}

- (NSBezierPath*)textPath;
- (NSArray*)glyphPathsForContainer:(NSTextContainer*)container usedSize:(NSSize*)aSize;

@end
