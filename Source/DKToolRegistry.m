/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

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

NSString* kDKDrawingToolWasRegisteredNotification = @"kDKDrawingToolWasRegisteredNotification";

// standard tool names

NSString* kDKStandardSelectionToolName = @"Select";
NSString* kDKStandardRectangleToolName = @"Rectangle";
NSString* kDKStandardOvalToolName = @"Oval";
NSString* kDKStandardRoundRectangleToolName = @"Round Rectangle";
NSString* kDKStandardRoundEndedRectangleToolName = @"Round End Rectangle";
NSString* kDKStandardBezierPathToolName = @"Path";
NSString* kDKStandardStraightLinePathToolName = @"Line";
NSString* kDKStandardIrregularPolygonPathToolName = @"Polygon";
NSString* kDKStandardRegularPolygonPathToolName = @"Regular Polygon";
NSString* kDKStandardFreehandPathToolName = @"Freehand";
NSString* kDKStandardArcToolName = @"Arc";
NSString* kDKStandardWedgeToolName = @"Wedge";
NSString* kDKStandardRingToolName = @"Ring";
NSString* kDKStandardSpeechBalloonToolName = @"Speech Balloon";
NSString* kDKStandardTextBoxToolName = @"Text";
NSString* kDKStandardTextPathToolName = @"Text Path";
NSString* kDKStandardAddPathPointToolName = @"Insert Path Point";
NSString* kDKStandardDeletePathPointToolName = @"Delete Path Point";
NSString* kDKStandardDeletePathSegmentToolName = @"Delete Path Segment";
NSString* kDKStandardZoomToolName = @"Zoom";

@implementation DKToolRegistry

static DKToolRegistry* s_toolRegistry = nil;

/** @brief Return the shared tool registry

 Creates the registry if needed and installs the standard tools. For other tool collections
 you can instantiate a DKToolRegistry and add tools to it.
 @return a shared DKToolRegistry object
 */
+ (DKToolRegistry*)sharedToolRegistry
{
	if (s_toolRegistry == nil) {
		s_toolRegistry = [[self alloc] init];
		[s_toolRegistry registerStandardTools];
	}

	return s_toolRegistry;
}

/** @brief Return a named tool from the registry
 @param name the name of the tool of interest
 @return the tool if found, or nil if not
 */
- (DKDrawingTool*)drawingToolWithName:(NSString*)name
{
	NSAssert(name != nil, @"cannot find a tool with a nil name");

	return [mToolsReg objectForKey:name];
}

/** @brief Add a tool to the registry
 @param tool the tool to register
 @param name the name of the tool of interest
 */
- (void)registerDrawingTool:(DKDrawingTool*)tool withName:(NSString*)name
{
	NSAssert(tool != nil, @"cannot register a nil tool");
	NSAssert(name != nil, @"cannot register a tool with a nil name");
	NSAssert([name length] > 0, @"cannot register a tool with an empty name");

	[mToolsReg setObject:tool
				  forKey:name];

	// for compatibility, notification object is the tool, not the registry

	[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingToolWasRegisteredNotification
														object:tool];
}

/** @brief Find the tool having a key equivalent matching the key event
 @param keyEvent the key event to match
 @return the tool if found, or nil
 */
- (DKDrawingTool*)drawingToolWithKeyboardEquivalent:(NSEvent*)keyEvent
{
	NSAssert(keyEvent != nil, @"event was nil");

	if ([keyEvent type] == NSKeyDown) {
		NSString* keyEquivalent;
		NSUInteger flags;

		//NSLog(@"looking for tool with keyboard equivalent, string = '%@', modifers = %d", [keyEvent charactersIgnoringModifiers], [keyEvent modifierFlags]);

		for (NSString *name in mToolsReg) {
			DKDrawingTool* tool = [mToolsReg objectForKey:name];

			keyEquivalent = [tool keyboardEquivalent];
			flags = [tool keyboardModifierFlags];

			if ([keyEquivalent isEqualToString:[keyEvent charactersIgnoringModifiers]]) {
				if ((NSDeviceIndependentModifierFlagsMask & [keyEvent modifierFlags]) == flags)
					return tool;
			}
		}
	}
	return nil;
}

- (void)registerStandardTools
{
	// ------ rect ------

	Class trueClass;

	trueClass = [DKDrawableObject classForConversionRequestFor:[DKDrawableShape class]];

	DKDrawableShape* shape = [[trueClass alloc] init];
	[shape setPath:[DKShapeFactory rect]];
	DKDrawingTool* dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:shape];
	[self registerDrawingTool:dt
					 withName:kDKStandardRectangleToolName];
	[dt setKeyboardEquivalent:@"r"
				modifierFlags:0];

	// -------- oval -------

	shape = [[trueClass alloc] init];
	[shape setPath:[DKShapeFactory oval]];
	dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:shape];
	[self registerDrawingTool:dt
					 withName:kDKStandardOvalToolName];
	[dt setKeyboardEquivalent:@"o"
				modifierFlags:0];

	// -------- ring -------

	shape = [[trueClass alloc] init];
	[shape setPath:[DKShapeFactory ring:0.67]];
	dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:shape];
	[self registerDrawingTool:dt
					 withName:kDKStandardRingToolName];

	// ----- roundrect -----

	trueClass = [DKDrawableObject classForConversionRequestFor:[DKReshapableShape class]];

	DKReshapableShape* rss = [[trueClass alloc] init];
	[rss setShapeProvider:[DKShapeFactory sharedShapeFactory]
				 selector:@selector(roundRectInRect:
										   objParam:)];
	[rss setOptionalParameter:@16.0];
	dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:rss];
	[self registerDrawingTool:dt
					 withName:kDKStandardRoundRectangleToolName];

	// ----- roundendrect -----

	rss = [[trueClass alloc] init];
	[rss setShapeProvider:[DKShapeFactory sharedShapeFactory]
				 selector:@selector(roundEndedRect:
										  objParam:)];
	dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:rss];
	[self registerDrawingTool:dt
					 withName:kDKStandardRoundEndedRectangleToolName];

	// ----- speech balloon ----

	rss = [[trueClass alloc] init];
	[rss setShapeProvider:[DKShapeFactory sharedShapeFactory]
				 selector:@selector(speechBalloonInRect:
											   objParam:)];
	dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:rss];
	[self registerDrawingTool:dt
					 withName:kDKStandardSpeechBalloonToolName];

	// ------ text shape ------

	trueClass = [DKDrawableObject classForConversionRequestFor:[DKTextShape class]];

	DKTextShape* tshape = [[trueClass alloc] init];
	dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:tshape];
	[self registerDrawingTool:dt
					 withName:kDKStandardTextBoxToolName];
	[dt setKeyboardEquivalent:@"t"
				modifierFlags:0];

	// ------ text path -----

	trueClass = [DKDrawableObject classForConversionRequestFor:[DKTextPath class]];

	DKTextPath* tPath = [[trueClass alloc] init];
	[tPath setPathCreationMode:kDKPathCreateModeBezierCreate];
	dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:tPath];
	[self registerDrawingTool:dt
					 withName:kDKStandardTextPathToolName];
	[dt setKeyboardEquivalent:@"e"
				modifierFlags:0];

	// -------- bezier path -------

	trueClass = [DKDrawableObject classForConversionRequestFor:[DKDrawablePath class]];

	DKDrawablePath* path = [[trueClass alloc] init];
	[path setPathCreationMode:kDKPathCreateModeBezierCreate];
	dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:path];
	[self registerDrawingTool:dt
					 withName:kDKStandardBezierPathToolName];
	[dt setKeyboardEquivalent:@"b"
				modifierFlags:0];

	//-------- line ---------

	path = [[trueClass alloc] init];
	[path setPathCreationMode:kDKPathCreateModeLineCreate];
	dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:path];
	[self registerDrawingTool:dt
					 withName:kDKStandardStraightLinePathToolName];
	[dt setKeyboardEquivalent:@"l"
				modifierFlags:0];

	//-------- polygon ---------

	path = [[trueClass alloc] init];
	[path setPathCreationMode:kDKPathCreateModePolygonCreate];
	dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:path];
	[self registerDrawingTool:dt
					 withName:kDKStandardIrregularPolygonPathToolName];
	[dt setKeyboardEquivalent:@"p"
				modifierFlags:0];

	//-------- freehand -------

	path = [[trueClass alloc] init];
	[path setPathCreationMode:kDKPathCreateModeFreehandCreate];
	dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:path];
	[self registerDrawingTool:dt
					 withName:kDKStandardFreehandPathToolName];
	[dt setKeyboardEquivalent:@"f"
				modifierFlags:0];

	//-------- regular polygon ---------

	trueClass = [DKDrawableObject classForConversionRequestFor:[DKRegularPolygonPath class]];

	path = [[trueClass alloc] init];
	[path setPathCreationMode:kDKRegularPolyCreationMode];
	[(DKRegularPolygonPath*)path setShowsSpreadControls:YES];
	dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:path];
	[self registerDrawingTool:dt
					 withName:kDKStandardRegularPolygonPathToolName];
	[dt setKeyboardEquivalent:@"g"
				modifierFlags:0];

	//-------- arc ---------

	trueClass = [DKDrawableObject classForConversionRequestFor:[DKArcPath class]];

	DKArcPath* arc = [[trueClass alloc] init];
	[arc setArcType:kDKArcPathOpenArc];
	[arc setStyle:[DKStyle defaultTrackStyle]];
	[arc setPathCreationMode:kDKPathCreateModeArcSegment];
	dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:arc];
	[self registerDrawingTool:dt
					 withName:kDKStandardArcToolName];
	[dt setKeyboardEquivalent:@"a"
				modifierFlags:0];

	//-------- wedge ---------

	arc = [[trueClass alloc] init];
	[arc setArcType:kDKArcPathWedge];
	[arc setPathCreationMode:kDKArcSimpleCreationMode];
	dt = [[DKObjectCreationTool alloc] initWithPrototypeObject:arc];
	[self registerDrawingTool:dt
					 withName:kDKStandardWedgeToolName];
	[dt setKeyboardEquivalent:@"w"
				modifierFlags:0];

	// ----- path add/delete tools ----

	dt = [DKPathInsertDeleteTool pathDeletionTool];
	[self registerDrawingTool:dt
					 withName:kDKStandardDeletePathPointToolName];

	dt = [DKPathInsertDeleteTool pathInsertionTool];
	[self registerDrawingTool:dt
					 withName:kDKStandardAddPathPointToolName];

	dt = [DKPathInsertDeleteTool pathElementDeletionTool];
	[self registerDrawingTool:dt
					 withName:kDKStandardDeletePathSegmentToolName];
	[dt setKeyboardEquivalent:@"x"
				modifierFlags:0];

	// ----- zoom tool -----

	dt = [[DKZoomTool alloc] init];
	[self registerDrawingTool:dt
					 withName:kDKStandardZoomToolName];
	[dt setKeyboardEquivalent:@"z"
				modifierFlags:0];

	// ----- select and edit tool -----

	dt = [[DKSelectAndEditTool alloc] init];
	[self registerDrawingTool:dt
					 withName:kDKStandardSelectionToolName];
	[dt setKeyboardEquivalent:@" "
				modifierFlags:0];
}

- (NSArray*)toolNames
{
	NSMutableArray* tn = [[mToolsReg allKeys] mutableCopy];
	[tn sortUsingSelector:@selector(compare:)];

	return tn;
}

- (NSArray*)allKeysForTool:(DKDrawingTool*)tool
{
	NSAssert(tool != nil, @"cannot find keys for a nil tool");
	return [mToolsReg allKeysForObject:tool];
}

- (NSArray*)tools
{
	return [mToolsReg allValues];
}

#pragma mark -
#pragma mark - as a NSObject

- (instancetype)init
{
	self = [super init];
	if (self) {
		mToolsReg = [[NSMutableDictionary alloc] init];
	}

	return self;
}

@end
