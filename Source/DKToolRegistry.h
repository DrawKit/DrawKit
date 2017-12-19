/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import <Cocoa/Cocoa.h>
#import "DKCommonTypes.h"

NS_ASSUME_NONNULL_BEGIN

@class DKDrawingTool;

/** @brief DKToolRegistry takes over the tool collection functionality formerly part of DKDrawingTool itself.

DKToolRegistry takes over the tool collection functionality formerly part of DKDrawingTool itself. The old methods in DKDrawingTool now map to this class for backward
 compatibility but are deprecated.
*/
@interface DKToolRegistry : NSObject {
	NSMutableDictionary<DKToolName,__kindof DKDrawingTool*>* mToolsReg;
}

/** @brief Return the shared tool registry

 Creates the registry if needed and installs the standard tools. For other tool collections
 you can instantiate a DKToolRegistry and add tools to it.
 @return a shared DKToolRegistry object
 */
+ (DKToolRegistry*)sharedToolRegistry;
@property (class, readonly, retain) DKToolRegistry *sharedToolRegistry;

/** @brief Return a named tool from the registry
 @param name the name of the tool of interest
 @return the tool if found, or nil if not
 */
- (nullable __kindof DKDrawingTool*)drawingToolWithName:(DKToolName)name;

/** @brief Add a tool to the registry
 @param tool the tool to register
 @param name the name of the tool of interest
 */
- (void)registerDrawingTool:(DKDrawingTool*)tool withName:(DKToolName)name;

/** @brief Find the tool having a key equivalent matching the key event
 @param keyEvent the key event to match
 @return the tool if found, or nil
 */
- (nullable __kindof DKDrawingTool*)drawingToolWithKeyboardEquivalent:(NSEvent*)keyEvent;

- (void)registerStandardTools;
- (NSArray<DKToolName>*)toolNames;
- (NSArray<DKToolName>*)allKeysForTool:(DKDrawingTool*)tool;
- (NSArray<DKDrawingTool*>*)tools;

@property (readonly, copy) NSArray<DKToolName> *toolNames;
@property (readonly, copy) NSArray<DKDrawingTool*> *tools;

@end

// notifications

extern NSString* kDKDrawingToolWasRegisteredNotification;

// standard tool name constants

extern DKToolName kDKStandardSelectionToolName;
extern DKToolName kDKStandardRectangleToolName;
extern DKToolName kDKStandardOvalToolName;
extern DKToolName kDKStandardRoundRectangleToolName;
extern DKToolName kDKStandardRoundEndedRectangleToolName;
extern DKToolName kDKStandardBezierPathToolName;
extern DKToolName kDKStandardStraightLinePathToolName;
extern DKToolName kDKStandardIrregularPolygonPathToolName;
extern DKToolName kDKStandardRegularPolygonPathToolName;
extern DKToolName kDKStandardFreehandPathToolName;
extern DKToolName kDKStandardArcToolName;
extern DKToolName kDKStandardWedgeToolName;
extern DKToolName kDKStandardRingToolName;
extern DKToolName kDKStandardSpeechBalloonToolName;
extern DKToolName kDKStandardTextBoxToolName;
extern DKToolName kDKStandardTextPathToolName;
extern DKToolName kDKStandardAddPathPointToolName;
extern DKToolName kDKStandardDeletePathPointToolName;
extern DKToolName kDKStandardDeletePathSegmentToolName;
extern DKToolName kDKStandardZoomToolName;

NS_ASSUME_NONNULL_END
