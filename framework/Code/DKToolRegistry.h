//
//  DKToolRegistry.h
//  GCDrawKit
//
//  Created by graham on 15/07/09.
//  Copyright 2009 Apptree.net. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class DKDrawingTool;



@interface DKToolRegistry : NSObject
{
	NSMutableDictionary*	mToolsReg;
}


+ (DKToolRegistry*)		sharedToolRegistry;

- (DKDrawingTool*)		drawingToolWithName:(NSString*) name;
- (void)				registerDrawingTool:(DKDrawingTool*) tool withName:(NSString*) name;
- (DKDrawingTool*)		drawingToolWithKeyboardEquivalent:(NSEvent*) keyEvent;

- (void)				registerStandardTools;
- (NSArray*)			toolNames;
- (NSArray*)			allKeysForTool:(DKDrawingTool*) tool;
- (NSArray*)			tools;

@end


// notifications

extern NSString*		kDKDrawingToolWasRegisteredNotification;


// standard tool name constants


extern NSString*		kDKStandardSelectionToolName;
extern NSString*		kDKStandardRectangleToolName;
extern NSString*		kDKStandardOvalToolName;
extern NSString*		kDKStandardRoundRectangleToolName;
extern NSString*		kDKStandardRoundEndedRectangleToolName;
extern NSString*		kDKStandardBezierPathToolName;
extern NSString*		kDKStandardStraightLinePathToolName;
extern NSString*		kDKStandardIrregularPolygonPathToolName;
extern NSString*		kDKStandardRegularPolygonPathToolName;
extern NSString*		kDKStandardFreehandPathToolName;
extern NSString*		kDKStandardArcToolName;
extern NSString*		kDKStandardWedgeToolName;
extern NSString*		kDKStandardRingToolName;
extern NSString*		kDKStandardSpeechBalloonToolName;
extern NSString*		kDKStandardTextBoxToolName;
extern NSString*		kDKStandardTextPathToolName;
extern NSString*		kDKStandardAddPathPointToolName;
extern NSString*		kDKStandardDeletePathPointToolName;
extern NSString*		kDKStandardDeletePathSegmentToolName;
extern NSString*		kDKStandardZoomToolName;


/*

 DKToolRegistry takes over the tool collection functionality formerly part of DKDrawingTool itself. The old methods in DKDrawingTool now map to this class for backward
 compatibility but are deprecated.

*/

