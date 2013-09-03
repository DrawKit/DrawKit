//
//  DKToolRegistry.m
//  GCDrawKit
//
//  Created by graham on 15/07/09.
//  Copyright 2009 Apptree.net. All rights reserved.
//

#import "DKToolRegistry.h"
#import "DKObjectCreationTool.h"
#import "DKDrawablePath.h"
#import "DKReshapableShape.h"
#import "DKPathInsertDeleteTool.h"
#import "DKShapeFactory.h"
#import "DKTextShape.h"
#import "DKZoomTool.h"
#import "DKSelectAndEditTool.h"
#import "DKCropTool.h"
#import "DKArcPath.h"
#import "DKStyle.h"
#import "DKRegularPolygonPath.h"
#import "DKTextPath.h"

// notifications

NSString*		kDKDrawingToolWasRegisteredNotification = @"kDKDrawingToolWasRegisteredNotification";

// standard tool names

NSString*		kDKStandardSelectionToolName			= @"Select";
NSString*		kDKStandardRectangleToolName			= @"Rectangle";
NSString*		kDKStandardOvalToolName					= @"Oval";
NSString*		kDKStandardRoundRectangleToolName		= @"Round Rectangle";
NSString*		kDKStandardRoundEndedRectangleToolName	= @"Round End Rectangle";
NSString*		kDKStandardBezierPathToolName			= @"Path";
NSString*		kDKStandardStraightLinePathToolName		= @"Line";
NSString*		kDKStandardIrregularPolygonPathToolName	= @"Polygon";
NSString*		kDKStandardRegularPolygonPathToolName	= @"Regular Polygon";
NSString*		kDKStandardFreehandPathToolName			= @"Freehand";
NSString*		kDKStandardArcToolName					= @"Arc";
NSString*		kDKStandardWedgeToolName				= @"Wedge";
NSString*		kDKStandardRingToolName					= @"Ring";
NSString*		kDKStandardSpeechBalloonToolName		= @"Speech Balloon";
NSString*		kDKStandardTextBoxToolName				= @"Text";
NSString*		kDKStandardTextPathToolName				= @"Text Path";
NSString*		kDKStandardAddPathPointToolName			= @"Insert Path Point";
NSString*		kDKStandardDeletePathPointToolName		= @"Delete Path Point";
NSString*		kDKStandardDeletePathSegmentToolName	= @"Delete Path Segment";
NSString*		kDKStandardZoomToolName					= @"Zoom";



@implementation DKToolRegistry


static DKToolRegistry*	s_toolRegistry = nil;

///*********************************************************************************************************************
///
/// method:			sharedToolRegistry
/// scope:			public class method
///	overrides:		
/// description:	return the shared tool registry
/// 
/// parameters:		none
/// result:			a shared DKToolRegistry object
///
/// notes:			creates the registry if needed and installs the standard tools. For other tool collections
///					you can instantiate a DKToolRegistry and add tools to it.
///
///********************************************************************************************************************

+ (DKToolRegistry*)		sharedToolRegistry
{
	if( s_toolRegistry == nil )
	{
		s_toolRegistry = [[self alloc] init];
		[s_toolRegistry registerStandardTools];
	}
	
	return s_toolRegistry;
}


///*********************************************************************************************************************
///
/// method:			drawingToolWithName:
/// scope:			public instance method
///	overrides:		
/// description:	return a named tool from the registry
/// 
/// parameters:		<name> the name of the tool of interest
/// result:			the tool if found, or nil if not
///
/// notes:			
///
///********************************************************************************************************************

- (DKDrawingTool*)		drawingToolWithName:(NSString*) name
{
	NSAssert( name != nil, @"cannot find a tool with a nil name");
	
	return [mToolsReg objectForKey:name];
}


///*********************************************************************************************************************
///
/// method:			registerDrawingTool:withName:
/// scope:			public instance method
///	overrides:		
/// description:	add a tool to the registry
/// 
/// parameters:		<tool> the tool to register
///					<name> the name of the tool of interest
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				registerDrawingTool:(DKDrawingTool*) tool withName:(NSString*) name
{
	NSAssert( tool != nil, @"cannot register a nil tool");
	NSAssert( name != nil, @"cannot register a tool with a nil name");
	NSAssert([name length] > 0, @"cannot register a tool with an empty name");
	
	[mToolsReg setObject:tool forKey:name];
	
	// for compatibility, notification object is the tool, not the registry
	
	[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingToolWasRegisteredNotification object:tool];
}



///*********************************************************************************************************************
///
/// method:			drawingToolWithKeyboardEquivalent:
/// scope:			public instance method
///	overrides:		
/// description:	find the tool having a key equivalent matching the key event
/// 
/// parameters:		<keyEvent> the key event to match
/// result:			the tool if found, or nil
///
/// notes:			
///
///********************************************************************************************************************

- (DKDrawingTool*)		drawingToolWithKeyboardEquivalent:(NSEvent*) keyEvent
{
	NSAssert( keyEvent != nil, @"event was nil");
	
	if([keyEvent type] == NSKeyDown)
	{
		NSEnumerator*	iter = [[mToolsReg allKeys] objectEnumerator];
		NSString*		name;
		NSString*		keyEquivalent;
		DKDrawingTool*	tool;
		NSUInteger		flags;
		
		//NSLog(@"looking for tool with keyboard equivalent, string = '%@', modifers = %d", [keyEvent charactersIgnoringModifiers], [keyEvent modifierFlags]);
		
		while(( name = [iter nextObject]))
		{
			tool = [mToolsReg objectForKey:name];
			
			keyEquivalent = [tool keyboardEquivalent];
			flags = [tool keyboardModifierFlags];
			
			if([keyEquivalent isEqualToString:[keyEvent charactersIgnoringModifiers]])
			{
				if(( NSDeviceIndependentModifierFlagsMask & [keyEvent modifierFlags]) == flags )
					return tool;
			}
		}
	}
	return nil;
}




- (void)				registerStandardTools
{
	// ------ rect ------
	
	Class trueClass;
	
	trueClass = [DKDrawableObject classForConversionRequestFor:[DKDrawableShape class]];
	
	DKDrawableShape*	shape = [[trueClass alloc] init];
	[shape setPath:[DKShapeFactory rect]];
	DKDrawingTool*		dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:shape];
	[shape release];
	[self registerDrawingTool:dt  withName:kDKStandardRectangleToolName];
	[dt setKeyboardEquivalent:@"r" modifierFlags:0];
	[dt release];
	
	// -------- oval -------
	
	shape = [[trueClass alloc] init];
	[shape setPath:[DKShapeFactory oval]];
	dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:shape];
	[shape release];
	[self registerDrawingTool:dt  withName:kDKStandardOvalToolName];
	[dt setKeyboardEquivalent:@"o" modifierFlags:0];
	[dt release];
	
	// -------- ring -------
	
	shape = [[trueClass alloc] init];
	[shape setPath:[DKShapeFactory ring:0.67]];
	dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:shape];
	[shape release];
	[self registerDrawingTool:dt  withName:kDKStandardRingToolName];
	[dt release];
	
	// ----- roundrect -----
	
	trueClass = [DKDrawableObject classForConversionRequestFor:[DKReshapableShape class]];
	
	DKReshapableShape* rss = [[trueClass alloc] init];
	[rss setShapeProvider:[DKShapeFactory sharedShapeFactory]  selector:@selector( roundRectInRect:objParam: ) ];
	[rss setOptionalParameter:[NSNumber numberWithDouble:16.0]];
	dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:rss];
	[rss release];
	[self registerDrawingTool:dt  withName:kDKStandardRoundRectangleToolName];
	[dt release];
	
	// ----- roundendrect -----
	
	rss = [[trueClass alloc] init];
	[rss setShapeProvider:[DKShapeFactory sharedShapeFactory]  selector:@selector( roundEndedRect:objParam: ) ];
	dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:rss];
	[rss release];
	[self registerDrawingTool:dt  withName:kDKStandardRoundEndedRectangleToolName];
	[dt release];
	
	// ----- speech balloon ----
	
	rss = [[trueClass alloc] init];
	[rss setShapeProvider:[DKShapeFactory sharedShapeFactory]  selector:@selector( speechBalloonInRect:objParam: ) ];
	dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:rss];
	[rss release];
	[self registerDrawingTool:dt  withName:kDKStandardSpeechBalloonToolName];
	[dt release];
	
	// ------ text shape ------
	
	trueClass = [DKDrawableObject classForConversionRequestFor:[DKTextShape class]];
	
	DKTextShape*		tshape = [[trueClass alloc] init];
	dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:tshape];
	[tshape release];
	[self registerDrawingTool:dt  withName:kDKStandardTextBoxToolName];
	[dt setKeyboardEquivalent:@"t" modifierFlags:0];
	[dt release];
	
	// ------ text path -----
	
	trueClass = [DKDrawableObject classForConversionRequestFor:[DKTextPath class]];
	
	DKTextPath* tPath = [[trueClass alloc] init];
	[tPath setPathCreationMode:kDKPathCreateModeBezierCreate];
	dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:tPath];
	[tPath release];
	[self registerDrawingTool:dt  withName:kDKStandardTextPathToolName];
	[dt setKeyboardEquivalent:@"e" modifierFlags:0];
	[dt release];
	
	// -------- bezier path -------
	
	trueClass = [DKDrawableObject classForConversionRequestFor:[DKDrawablePath class]];
	
	DKDrawablePath* path = [[trueClass alloc] init];
	[path setPathCreationMode:kDKPathCreateModeBezierCreate];
	dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:path];
	[path release];
	[self registerDrawingTool:dt  withName:kDKStandardBezierPathToolName];
	[dt setKeyboardEquivalent:@"b" modifierFlags:0];
	[dt release];
	
	//-------- line ---------
	
	path = [[trueClass alloc] init];
	[path setPathCreationMode:kDKPathCreateModeLineCreate];
	dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:path];
	[path release];
	[self registerDrawingTool:dt  withName:kDKStandardStraightLinePathToolName];
	[dt setKeyboardEquivalent:@"l" modifierFlags:0];
	[dt release];
	
	//-------- polygon ---------
	
	path = [[trueClass alloc] init];
	[path setPathCreationMode:kDKPathCreateModePolygonCreate];
	dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:path];
	[path release];
	[self registerDrawingTool:dt  withName:kDKStandardIrregularPolygonPathToolName];
	[dt setKeyboardEquivalent:@"p" modifierFlags:0];
	[dt release];
	
	//-------- freehand -------
	
	path = [[trueClass alloc] init];
	[path setPathCreationMode:kDKPathCreateModeFreehandCreate];
	dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:path];
	[path release];
	[self registerDrawingTool:dt  withName:kDKStandardFreehandPathToolName];
	[dt setKeyboardEquivalent:@"f" modifierFlags:0];
	[dt release];
	
	//-------- regular polygon ---------
	
	trueClass = [DKDrawableObject classForConversionRequestFor:[DKRegularPolygonPath class]];
	
	path = [[trueClass alloc] init];
	[path setPathCreationMode:kDKRegularPolyCreationMode];
	[(DKRegularPolygonPath*)path setShowsSpreadControls:YES];
	dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:path];
	[path release];
	[self registerDrawingTool:dt  withName:kDKStandardRegularPolygonPathToolName];
	[dt setKeyboardEquivalent:@"g" modifierFlags:0];
	[dt release];
	
	//-------- arc ---------
	
	trueClass = [DKDrawableObject classForConversionRequestFor:[DKArcPath class]];
	
	DKArcPath* arc = [[trueClass alloc] init];
	[arc setArcType:kDKArcPathOpenArc];
	[arc setStyle:[DKStyle defaultTrackStyle]];
	[arc setPathCreationMode:kDKPathCreateModeArcSegment];
	dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:arc];
	[arc release];
	[self registerDrawingTool:dt  withName:kDKStandardArcToolName];
	[dt setKeyboardEquivalent:@"a" modifierFlags:0];
	[dt release];
	
	//-------- wedge ---------
	
	arc = [[trueClass alloc] init];
	[arc setArcType:kDKArcPathWedge];
	[arc setPathCreationMode:kDKArcSimpleCreationMode];
	dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:arc];
	[arc release];
	[self registerDrawingTool:dt  withName:kDKStandardWedgeToolName];
	[dt setKeyboardEquivalent:@"w" modifierFlags:0];
	[dt release];
	
	// ----- path add/delete tools ----
	
	dt = [DKPathInsertDeleteTool pathDeletionTool];
	[self registerDrawingTool:dt  withName:kDKStandardDeletePathPointToolName];
	
	dt = [DKPathInsertDeleteTool pathInsertionTool];
	[self registerDrawingTool:dt  withName:kDKStandardAddPathPointToolName];
	
	dt = [DKPathInsertDeleteTool pathElementDeletionTool];
	[self registerDrawingTool:dt  withName:kDKStandardDeletePathSegmentToolName];
	[dt setKeyboardEquivalent:@"x" modifierFlags:0];
	
	// ----- zoom tool -----
	
	dt = [[DKZoomTool alloc] init];
	[self registerDrawingTool:dt withName:kDKStandardZoomToolName];
	[dt setKeyboardEquivalent:@"z" modifierFlags:0];
	[dt release];
	
	// ----- select and edit tool -----
	
	dt = [[DKSelectAndEditTool alloc] init];
	[self registerDrawingTool:dt withName:kDKStandardSelectionToolName];
	[dt setKeyboardEquivalent:@" " modifierFlags:0];
	[dt release];
}



- (NSArray*)			toolNames
{
	NSMutableArray*		tn = [[mToolsReg allKeys] mutableCopy];
	[tn sortUsingSelector:@selector(compare:)];
	
	return [tn autorelease];
}


- (NSArray*)			allKeysForTool:(DKDrawingTool*) tool
{
	NSAssert( tool != nil, @"cannot find keys for a nil tool");	
	return [mToolsReg allKeysForObject:tool];
}


- (NSArray*)			tools
{
	return [mToolsReg allValues];
}




#pragma mark -
#pragma mark - as a NSObject

- (id)					init
{
	self = [super init];
	if( self )
	{
		mToolsReg = [[NSMutableDictionary alloc] init];
	}
	
	return self;
}


- (void)				dealloc
{
	[mToolsReg release];
	[super dealloc];
}


@end
