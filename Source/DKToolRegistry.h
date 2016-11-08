/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

@class DKDrawingTool;

/** @brief DKToolRegistry takes over the tool collection functionality formerly part of DKDrawingTool itself.

DKToolRegistry takes over the tool collection functionality formerly part of DKDrawingTool itself. The old methods in DKDrawingTool now map to this class for backward
 compatibility but are deprecated.
*/
@interface DKToolRegistry : NSObject {
	NSMutableDictionary* mToolsReg;
}

/** @brief Return the shared tool registry

 Creates the registry if needed and installs the standard tools. For other tool collections
 you can instantiate a DKToolRegistry and add tools to it.
 @return a shared DKToolRegistry object
 */
+ (DKToolRegistry*)sharedToolRegistry;

/** @brief Return a named tool from the registry
 @param name the name of the tool of interest
 @return the tool if found, or nil if not
 */
- (DKDrawingTool*)drawingToolWithName:(NSString*)name;

/** @brief Add a tool to the registry
 @param tool the tool to register
 @param name the name of the tool of interest
 */
- (void)registerDrawingTool:(DKDrawingTool*)tool withName:(NSString*)name;

/** @brief Find the tool having a key equivalent matching the key event
 @param keyEvent the key event to match
 @return the tool if found, or nil
 */
- (DKDrawingTool*)drawingToolWithKeyboardEquivalent:(NSEvent*)keyEvent;

- (void)registerStandardTools;
- (NSArray*)toolNames;
- (NSArray*)allKeysForTool:(DKDrawingTool*)tool;
- (NSArray*)tools;

@end

// notifications

extern NSString* kDKDrawingToolWasRegisteredNotification;

// standard tool name constants

extern NSString* kDKStandardSelectionToolName;
extern NSString* kDKStandardRectangleToolName;
extern NSString* kDKStandardOvalToolName;
extern NSString* kDKStandardRoundRectangleToolName;
extern NSString* kDKStandardRoundEndedRectangleToolName;
extern NSString* kDKStandardBezierPathToolName;
extern NSString* kDKStandardStraightLinePathToolName;
extern NSString* kDKStandardIrregularPolygonPathToolName;
extern NSString* kDKStandardRegularPolygonPathToolName;
extern NSString* kDKStandardFreehandPathToolName;
extern NSString* kDKStandardArcToolName;
extern NSString* kDKStandardWedgeToolName;
extern NSString* kDKStandardRingToolName;
extern NSString* kDKStandardSpeechBalloonToolName;
extern NSString* kDKStandardTextBoxToolName;
extern NSString* kDKStandardTextPathToolName;
extern NSString* kDKStandardAddPathPointToolName;
extern NSString* kDKStandardDeletePathPointToolName;
extern NSString* kDKStandardDeletePathSegmentToolName;
extern NSString* kDKStandardZoomToolName;
