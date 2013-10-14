/**
 * @author Graham Cox, Apptree.net
 * @author Graham Miln, miln.eu
 * @author Contributions from the community
 * @date 2005-2013
 * @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import "DKDrawingView.h"

@interface DKPrintDrawingView : DKDrawingView
{
	NSPrintInfo*	m_printInfo;
}

- (void)			setPrintInfo:(NSPrintInfo*) ip;
- (NSPrintInfo*)	printInfo;

@end
