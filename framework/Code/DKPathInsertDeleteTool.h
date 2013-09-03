///**********************************************************************************************************************************
///  DKPathInsertDeleteTool.h
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 09/06/2007.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKDrawingTool.h"


@class DKDrawablePath;

// modes of operation for this tool:

typedef enum
{
	kDKPathDeletePointMode		= 0,
	kDKPathInsertPointMode		= 1,
	kDKPathDeleteElementMode	= 2
}
DKPathToolMode;




@interface DKPathInsertDeleteTool : DKDrawingTool
{
@private
	DKPathToolMode		m_mode;
	BOOL				m_performedAction;
	DKDrawablePath*		mTargetRef;
}

+ (DKDrawingTool*)		pathDeletionTool;
+ (DKDrawingTool*)		pathInsertionTool;
+ (DKDrawingTool*)		pathElementDeletionTool;

- (void)				setMode:(DKPathToolMode) m;
- (DKPathToolMode)		mode;

@end

extern NSString*	kDKInsertPathPointCursorImageName;
extern NSString*	kDKDeletePathPointCursorImageName;
extern NSString*	kDKDeletePathElementCursorImageName;


/*

This tool is able to insert or delete on-path points from a path. If applied to other object type it does nothing.

*/

