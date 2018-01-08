/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <AppKit/NSImage.h>
#import "DKDrawingTool.h"

@class DKDrawablePath;

//! modes of operation for this tool:
typedef NS_ENUM(NSInteger, DKPathToolMode) {
	kDKPathDeletePointMode = 0,
	kDKPathInsertPointMode = 1,
	kDKPathDeleteElementMode = 2
};

/** @brief This tool is able to insert or delete on-path points from a path.

This tool is able to insert or delete on-path points from a path. If applied to other object type it does nothing.
*/
@interface DKPathInsertDeleteTool : DKDrawingTool {
@private
	DKPathToolMode m_mode;
	BOOL m_performedAction;
	__weak DKDrawablePath* mTargetRef;
}

+ (DKDrawingTool*)pathDeletionTool;
+ (DKDrawingTool*)pathInsertionTool;
+ (DKDrawingTool*)pathElementDeletionTool;

@property DKPathToolMode mode;

@end

extern NSImageName const kDKInsertPathPointCursorImageName;
extern NSImageName const kDKDeletePathPointCursorImageName;
extern NSImageName const kDKDeletePathElementCursorImageName;
