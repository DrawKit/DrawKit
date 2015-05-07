/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2015
 @copyright GNU LGPL3; see LICENSE
*/

#import "DKDrawingView.h"

@interface DKPrintDrawingView : DKDrawingView {
	NSPrintInfo* m_printInfo;
}

- (void)setPrintInfo:(NSPrintInfo*)ip;
- (NSPrintInfo*)printInfo;

@end
