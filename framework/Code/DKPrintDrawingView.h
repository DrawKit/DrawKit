///**********************************************************************************************************************************
///  DKPrintDrawingView.h
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 16/10/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKDrawingView.h"


@interface DKPrintDrawingView : DKDrawingView
{
	NSPrintInfo*	m_printInfo;
}

- (void)			setPrintInfo:(NSPrintInfo*) ip;
- (NSPrintInfo*)	printInfo;

@end
