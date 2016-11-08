/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKDrawingView.h"

@interface DKPrintDrawingView : DKDrawingView {
	NSPrintInfo* m_printInfo;
}

- (void)setPrintInfo:(NSPrintInfo*)ip;
- (NSPrintInfo*)printInfo;

@end
