/**
 * @author Graham Cox, Apptree.net
 * @author Graham Miln, miln.eu
 * @author Contributions from the community
 * @date 2005-2013
 * @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import <Cocoa/Cocoa.h>

/** @brief This class is used by DKTextAdornment to lay out text flowed into an arbitrary shape.

This class is used by DKTextAdornment to lay out text flowed into an arbitrary shape. Given the bezier path representing
the text container, this caches the text layout rects and uses that info to return rects on demand to the layout manager.
*/
@interface DKBezierTextContainer : NSTextContainer
{
	NSBezierPath*	mPath;
}

/** 
 */
- (void)			setBezierPath:(NSBezierPath*) aPath;

@end

