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
@property (class, readonly, strong) DKToolRegistry *sharedToolRegistry;

/** @brief Return a named tool from the registry
 @param name the name of the tool of interest
 @return The tool if found, or \c nil if not.
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

extern DKToolName const kDKStandardSelectionToolName NS_SWIFT_NAME(DKToolName.standardSelection);
extern DKToolName const kDKStandardRectangleToolName NS_SWIFT_NAME(DKToolName.standardRectangle);
extern DKToolName const kDKStandardOvalToolName NS_SWIFT_NAME(DKToolName.standardOval);
extern DKToolName const kDKStandardRoundRectangleToolName NS_SWIFT_NAME(DKToolName.standardRoundRectangle);
extern DKToolName const kDKStandardRoundEndedRectangleToolName NS_SWIFT_NAME(DKToolName.standardRoundEndedRectangle);
extern DKToolName const kDKStandardBezierPathToolName NS_SWIFT_NAME(DKToolName.standardBezierPath);
extern DKToolName const kDKStandardStraightLinePathToolName NS_SWIFT_NAME(DKToolName.standardStraightLinePath);
extern DKToolName const kDKStandardIrregularPolygonPathToolName NS_SWIFT_NAME(DKToolName.standardIrregularPolygonPath);
extern DKToolName const kDKStandardRegularPolygonPathToolName NS_SWIFT_NAME(DKToolName.standardRegularPolygonPath);
extern DKToolName const kDKStandardFreehandPathToolName NS_SWIFT_NAME(DKToolName.standardFreehandPath);
extern DKToolName const kDKStandardArcToolName NS_SWIFT_NAME(DKToolName.standardArc);
extern DKToolName const kDKStandardWedgeToolName NS_SWIFT_NAME(DKToolName.standardWedge);
extern DKToolName const kDKStandardRingToolName NS_SWIFT_NAME(DKToolName.standardRing);
extern DKToolName const kDKStandardSpeechBalloonToolName NS_SWIFT_NAME(DKToolName.standardSpeechBalloon);
extern DKToolName const kDKStandardTextBoxToolName NS_SWIFT_NAME(DKToolName.standardTextBox);
extern DKToolName const kDKStandardTextPathToolName NS_SWIFT_NAME(DKToolName.standardTextPath);
extern DKToolName const kDKStandardAddPathPointToolName NS_SWIFT_NAME(DKToolName.standardAddPathPoint);
extern DKToolName const kDKStandardDeletePathPointToolName NS_SWIFT_NAME(DKToolName.standardDeletePathPoint);
extern DKToolName const kDKStandardDeletePathSegmentToolName NS_SWIFT_NAME(DKToolName.standardDeletePathSegment);
extern DKToolName const kDKStandardZoomToolName NS_SWIFT_NAME(DKToolName.standardZoom);

NS_ASSUME_NONNULL_END
