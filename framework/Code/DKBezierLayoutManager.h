/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
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
