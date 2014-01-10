/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import "DKDrawingTool.h"

@class DKDrawablePath;

// modes of operation for this tool:

typedef enum {
    kDKPathDeletePointMode = 0,
    kDKPathInsertPointMode = 1,
    kDKPathDeleteElementMode = 2
} DKPathToolMode;

/** @brief This tool is able to insert or delete on-path points from a path.

This tool is able to insert or delete on-path points from a path. If applied to other object type it does nothing.
*/
@interface DKPathInsertDeleteTool : DKDrawingTool {
@private
    DKPathToolMode m_mode;
    BOOL m_performedAction;
    DKDrawablePath* mTargetRef;
}

+ (DKDrawingTool*)pathDeletionTool;
+ (DKDrawingTool*)pathInsertionTool;
+ (DKDrawingTool*)pathElementDeletionTool;

- (void)setMode:(DKPathToolMode)m;
- (DKPathToolMode)mode;

@end

extern NSString* kDKInsertPathPointCursorImageName;
extern NSString* kDKDeletePathPointCursorImageName;
extern NSString* kDKDeletePathElementCursorImageName;
