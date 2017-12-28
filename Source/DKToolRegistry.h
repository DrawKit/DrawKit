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

/** @brief \c DKToolRegistry takes over the tool collection functionality formerly part of DKDrawingTool itself.

 DKToolRegistry takes over the tool collection functionality formerly part of \c DKDrawingTool itself. The old methods in \c DKDrawingTool now map to this class for backward
 compatibility but are deprecated.
*/
@interface DKToolRegistry : NSObject {
	NSMutableDictionary<DKToolName,__kindof DKDrawingTool*>* mToolsReg;
}

/** @brief Return the shared tool registry

 Creates the registry if needed and installs the standard tools. For other tool collections
 you can instantiate a \c DKToolRegistry and add tools to it.
 */
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

/** @brief Set a "standard" set of tools in the registry
 
 "Standard" tools are creation tools for various basic shapes, the selection tool, zoom tool and
 launch time, may be safely called more than once - subsequent calls are no-ops.
 If the conversion table has been set up prior to this, the tools will automatically pick up
 the class from the table, so that apps don't need to swap out all the tools for subclasses, but
 can simply set up the table.
 */
- (void)registerStandardTools;

/** @brief Return a list of registered tools' names, sorted alphabetically
 
 May be useful for supporting a UI
 @return an array, a list of NSStrings
 */
@property (readonly, copy) NSArray<DKToolName> *toolNames;
- (NSArray<DKToolName>*)allKeysForTool:(DKDrawingTool*)tool;
/** @brief Return a list of registered tools.
 */
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
