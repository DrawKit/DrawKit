/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKDrawingView.h"
#import "DKDrawing.h"
#import "DKGridLayer.h"
#import "DKToolController.h"
#import "GCThreadQueue.h"
#import "LogEvent.h"
#import "NSBezierPath+Shapes.h"
#import "NSColor+DKAdditions.h"
#include <tgmath.h>

#pragma mark Constants(Non - localized)

NSString* const kDKDrawingViewDidBeginTextEditing = @"kDKDrawingViewDidBeginTextEditing";
NSString* const kDKDrawingViewTextEditingContentsDidChange = @"kDKDrawingViewTextEditingContentsDidChange";
NSString* const kDKDrawingViewDidEndTextEditing = @"kDKDrawingViewDidEndTextEditing";
NSString* const kDKDrawingViewWillCreateAutoDrawing = @"kDKDrawingViewWillCreateAutoDrawing";
NSString* const kDKDrawingViewDidCreateAutoDrawing = @"kDKDrawingViewDidCreateAutoDrawing";
NSString* const kDKDrawingMouseDownLocation = @"kDKDrawingMouseDownLocation";
NSString* const kDKDrawingMouseDraggedLocation = @"kDKDrawingMouseDraggedLocation";
NSString* const kDKDrawingMouseUpLocation = @"kDKDrawingMouseUpLocation";
NSString* const kDKDrawingMouseMovedLocation = @"kDKDrawingMouseMovedLocation";
NSString* const kDKDrawingMouseLocationInView = @"kDKDrawingMouseLocationInView";
NSString* const kDKDrawingMouseLocationInDrawingUnits = @"kDKDrawingMouseLocationInDrawingUnits";
NSString* const kDKDrawingRulersVisibleDefaultPrefsKey = @"kDKDrawingRulersVisibleDefault";
NSString* const kDKTextEditorSmartQuotesPrefsKey = @"kDKTextEditorSmartQuotes";
NSString* const kDKDrawingViewRulersChanged = @"kDKDrawingViewRulersChanged";

// constant strings for ruler marker names

NSString* const kDKDrawingViewHorizontalLeftMarkerName = @"marker_h_left";
NSString* const kDKDrawingViewHorizontalCentreMarkerName = @"marker_h_centre";
NSString* const kDKDrawingViewHorizontalRightMarkerName = @"marker_h_right";
NSString* const kDKDrawingViewVerticalTopMarkerName = @"marker_v_top";
NSString* const kDKDrawingViewVerticalCentreMarkerName = @"marker_v_centre";
NSString* const kDKDrawingViewVerticalBottomMarkerName = @"marker_v_bottom";

#pragma mark Static Vars

static NSMutableArray* sDrawingViewStack = nil; // stack of view refs
static NSColor* sPageBreakColour = nil;
static NSPoint sLastContextMenuClick = { 0, 0 };

NSString* const kDKTextEditorUndoesTypingPrefsKey = @"kDKTextEditorUndoesTyping";

@interface DKDrawingView ()

#if 0
+ (void)secondaryThreadEntryPoint:(id)obj;
+ (BOOL)secondaryThreadShouldRun;
+ (void)signalSecondaryThreadShouldDrawInRect:(NSRect)rect withView:(DKDrawingView*)aView;
#endif

/** @brief Broadcast the current mouse position in both native and drawing coordinates.

 A UI that displays the current mouse position could use this notification to keep itself updated.
 @param operation the name of the notification
 @param event the event associated with this
 */
- (void)postMouseLocationInfo:(NSString*)operation event:(NSEvent*)event;
+ (void)pushCurrentViewAndSet:(DKDrawingView*)aView;

/** @brief Store the local rule marker info.

 Private - an internal detail of how markers are handled
 @param dict a dictionary
 */
- (void)setRulerMarkerInfo:(NSDictionary*)dict;

/** @brief Store the local rule marker info.

 Private - an internal detail of how markers are handled
 @return a dictionary
 */
- (NSDictionary*)rulerMarkerInfo;

@property (copy) NSDictionary* rulerMarkerInfo;
@end

#pragma mark -
@implementation DKDrawingView
#pragma mark As a DKDrawingView

/** @brief Return the view currently drawing

 This is only valid during a drawRect: call - some internal parts of DK use this to obtain the
 view doing the drawing when they do not have a direct parameter to it.
 @return the current view that is drawing
 */
+ (DKDrawingView*)currentlyDrawingView
{
	return [sDrawingViewStack lastObject];
}

+ (void)pushCurrentViewAndSet:(DKDrawingView*)aView
{
	if (sDrawingViewStack == nil)
		sDrawingViewStack = [[NSMutableArray alloc] init];

	//NSLog(@"pushing %@; setting %@", [self currentlyDrawingView], aView);

	[sDrawingViewStack addObject:aView];
}

+ (void)pop
{
	NSUInteger stackSize = [sDrawingViewStack count];

	if (stackSize > 0)
		[sDrawingViewStack removeObjectAtIndex:stackSize - 1];

	//NSLog(@"popping %@", [self currentlyDrawingView]);
}

/** @brief Set the colour used to draw the page breaks
 @param colour the colour to draw page breaks with
 */
+ (void)setPageBreakColour:(NSColor*)colour
{
	sPageBreakColour = colour;
}

/** @brief Get the colour used to draw the page breaks
 @return a colour
 */
+ (NSColor*)pageBreakColour
{
	if (sPageBreakColour == nil) {
		sPageBreakColour = [[NSColor cyanColor] colorWithAlphaComponent:0.75];
	}

	return sPageBreakColour;
}

/** @brief Return the colour used to draw the background area of the scrollview outside the drawing area
 @return a colour
 */
+ (NSColor*)backgroundColour
{
	return [NSColor colorWithCalibratedRed:0.75
									 green:0.75
									  blue:0.8
									 alpha:1.0];
}

/** @brief Get the point for the initial mouse down that last opened a contextual menu
 @return a point in the drawing's coordinates
 */
+ (NSPoint)pointForLastContextualMenuEvent
{
	return sLastContextMenuClick;
}

/** @brief Return an image resource from the framework bundle
 @param name the image name
 @return the image, if available
 */
+ (NSImage*)imageResourceNamed:(NSString*)name
{
	NSImage* image = [[NSBundle bundleForClass:self] imageForResource:name];
	return image;
}

#pragma mark -
#pragma mark - setting the class for the temporary text editor

static Class s_textEditorClass = Nil;

+ (Class)classForTextEditor
{
	if (s_textEditorClass == nil)
		s_textEditorClass = [NSTextView class];

	return s_textEditorClass;
}

+ (void)setClassForTextEditor:(Class)aClass
{
	if ([aClass isSubclassOfClass:[NSTextView class]])
		s_textEditorClass = aClass;
}

+ (void)setTextEditorAllowsTypingUndo:(BOOL)allowUndo
{
	[[NSUserDefaults standardUserDefaults] setBool:allowUndo
											forKey:kDKTextEditorUndoesTypingPrefsKey];
}

+ (BOOL)textEditorAllowsTypingUndo
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:kDKTextEditorUndoesTypingPrefsKey];
}

#pragma mark -
#pragma mark - the view's controller

@synthesize controller = mControllerRef;

- (void)replaceControllerWithController:(DKViewController*)newController
{
	NSAssert([self drawing] != nil, @"cannot replace the controller as there is no drawing yet");
	NSAssert(newController != nil, @"cannot replace the controller with nil");
	NSAssert([newController isKindOfClass:[DKViewController class]], @"new controller must be a DKViewController or subclass");

	if (newController != [self controller]) {
		DKDrawing* dwg = [self drawing];

		[dwg removeController:[self controller]];
		[newController setView:self];
		[dwg addController:newController];
	}
}

#pragma mark -
#pragma mark - drawing info

/** @brief Return the drawing that the view will draw

 The drawing is obtained via the controller, and may be nil if the controller hasn't been added
 to a drawing yet. Even when the view owns the drawing (for auto back-end) you should use this
 method to get a view's drawing.
 @return a drawing object
 */
- (DKDrawing*)drawing
{
	return [[self controller] drawing];
}

/** @brief Create an entire "back end" for the view 

 Normally you create a drawing, and add layers to it. However, you can also let the view create the
 drawing back-end for you. This will occur when the view is asked to draw and there is no back end. This method
 does the building. This feature means you can simply drop a drawingView into a NIB and get a
 functional drawing program. For more sophisticated needs however, you really need to build it yourself.
 */
- (void)createAutomaticDrawing
{
	NSSize viewSize = [self bounds].size;

	LogEvent_(kReactiveEvent, @"View automatically instantiating a drawing (size = %@)", NSStringFromSize(viewSize));

	[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingViewWillCreateAutoDrawing
														object:self];

	mAutoDrawing = [DKDrawing defaultDrawingWithSize:viewSize];
	m_didCreateDrawing = YES;
	[mAutoDrawing setOwner:self];

	// create a suitable controller and add it to the drawing. Note that because the controller holds weak refs to both the view
	// and the drawing (the drawing owns its controllers), there is no retain cycle here even though for auto drawings, the view
	// owns the drawing.

	DKViewController* vc = [self makeViewController];
	[mAutoDrawing addController:vc];

	// set the undo manager for the drawing to be the view's undo manager. This is the right thing for drawings created by the view, but
	// for hand-built drawings, the owning document's undo manager is more appropriate. This also sets the undo limit to 24 - which helps
	// to prevent excessive memory use when editing a drawing, but you can adjust it to something else if you want; 0 = unlimited.

	NSUndoManager* um = [self undoManager];

	[mAutoDrawing setUndoManager:um];
	[um setLevelsOfUndo:24];

	[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingViewDidCreateAutoDrawing
														object:self];

	NSAssert([mAutoDrawing undoManager] != nil, @"note - automatic drawing was created before an undo manager was available. Check your code!");
}

- (DKViewController*)makeViewController
{
	DKToolController* aController = [[DKToolController alloc] initWithView:self];
	return aController;
}

#pragma mark -
#pragma mark - drawing page breaks and crop marks

/** @brief Returns a path which represents all of the printed page rectangles

 Any extension may not end up visible when printed depending on the printer's margin settings, etc.
 The only supported option currently is kDKCornerOnly, which generates corner crop marks rather
 than the full rectangles.
 @param amount the extension amount by which each line is extended beyond the end of the corner. May be 0.
 @param options crop marks kind
 @return a bezier path, may be stroked in various ways to show page breaks, crop marks, etc. */
- (NSBezierPath*)pageBreakPathWithExtension:(CGFloat)amount options:(DKCropMarkKind)options
{
	NSRect pr, dr;
	NSInteger pagesAcross, pagesDown;
	NSSize ds = [[self drawing] drawingSize];
	NSSize ps = [[self printInfo] paperSize];

	dr.origin = NSZeroPoint;
	dr.size = ds;

	if ([[self printInfo] horizontalPagination] != NSAutoPagination) {
		pagesAcross = 1;

		if ([[self printInfo] horizontalPagination] == NSFitPagination)
			ps.width = ds.width;
	} else {
		ps.width -= ([[self printInfo] leftMargin] + [[self printInfo] rightMargin]);
		pagesAcross = MAX(1, floor(ds.width / ps.width));
		if (fmod(ds.width, ps.width) > 2.0)
			++pagesAcross;
	}

	if ([[self printInfo] verticalPagination] != NSAutoPagination) {
		pagesDown = 1;

		if ([[self printInfo] verticalPagination] == NSFitPagination)
			ps.height = ds.height;
	} else {
		ps.height -= ([[self printInfo] topMargin] + [[self printInfo] bottomMargin]);
		pagesDown = MAX(1, floor(ds.height / ps.height));
		if (fmod(ds.height, ps.height) > 2.0)
			++pagesDown;
	}

	pr.size = ps;

	NSInteger page;

	NSBezierPath* pbPath = [NSBezierPath bezierPath];

	for (page = 0; page < (pagesAcross * pagesDown); ++page) {
		pr.origin.y = (page / pagesAcross) * ps.height;
		pr.origin.x = (page % pagesAcross) * ps.width;

		NSRect ar = (options & DKCropMarksEdges) ? NSIntersectionRect(pr, dr) : pr;

		if (amount <= 0.0 && ((options & DKCropMarksCorners) == 0))
			[pbPath appendBezierPathWithRect:ar];
		else {
			// extending or doing corners only. This is somewhat more involved.

			if (options & DKCropMarksCorners)
				[pbPath appendBezierPath:[NSBezierPath bezierPathWithCropMarksForRect:ar
																			   length:30
																			extension:amount]];
			else
				[pbPath appendBezierPath:[NSBezierPath bezierPathWithCropMarksForRect:ar
																			extension:amount]];
		}
	}

	return pbPath;
}

/** @brief Draw page breaks based on the page break print info */
- (void)drawPageBreaks
{
	NSBezierPath* pbPath = [self pageBreakPathWithExtension:0
													options:DKCropMarksNone];

	//float pbDashPattern[] = { 8.0, 8.0 };

	[pbPath setLineWidth:1];
	//[pbPath setLineDash:pbDashPattern count:2 phase:0.0];
	//[pbPath setLineCapStyle:NSButtLineCapStyle];
	[[[self class] pageBreakColour] setStroke];
	[pbPath stroke];
}

/** @brief Sets the print info to use for drawing the page breaks, paginating and general printing operations
 @param pbpi the print info
 */
- (void)setPrintInfo:(NSPrintInfo*)pbpi
{
	mPrintInfo = pbpi;

	[self setNeedsDisplay:YES];
}

@synthesize printInfo = mPrintInfo;

/** @brief Sets whether the page breaks are shown or not

 Page breaks also need a valid printInfo object set
 @param pbVisible YES to show the page breaks, NO otherwise
 */
- (void)setPageBreaksVisible:(BOOL)pbVisible
{
	if (pbVisible != [self pageBreaksVisible]) {
		mPageBreaksVisible = pbVisible;
		[self setNeedsDisplay:YES];
	}
}

@synthesize pageBreaksVisible = mPageBreaksVisible;

- (IBAction)toggleShowPageBreaks:(id)sender
{
#pragma unused(sender)
	[self setPageBreaksVisible:![self pageBreaksVisible]];
}

/** @brief Set what kind of crop marks printed output includes

 Default is no crop marks
 @param kind the kind of crop mark (including none)
 */
- (void)setPrintCropMarkKind:(DKCropMarkKind)kind
{
	if (kind != mCropMarkKind) {
		mCropMarkKind = kind;
		[self setNeedsDisplay:YES];
	}
}

@synthesize printCropMarkKind = mCropMarkKind;

/** @brief Draws the crop marks if set to do so and the view is being printed */
- (void)drawCropMarks
{
	//NSLog(@"drawing crop marks");

	NSBezierPath* pbPath = [self pageBreakPathWithExtension:10
													options:[self printCropMarkKind]];

	[pbPath setLineWidth:0.1];
	[pbPath setLineCapStyle:NSButtLineCapStyle];
	[pbPath setLineJoinStyle:NSMiterLineJoinStyle];
	[[NSColor blackColor] setStroke];
	[pbPath stroke];
}

#pragma mark -
#pragma mark - editing text directly in the drawing

/** @brief Start editing text in a box within the view

 When an object in the drawing wishes to allow the user to edit some text, it can use this utility
 to set up the editor. This creates a subview for text editing with the nominated text and the
 bounds rect given within the drawing. The text is installed, selected and activated. User actions
 then edit that text. When done, call endTextEditing. To get the text edited, call editedText
 before ending the mode. You can only set one item at a time to be editable.
 @param text the text to edit
 @param rect the position and size of the text box to edit within
 @param del a delegate object
 @return the temporary text view created to handle the job
 */
- (NSTextView*)editText:(NSAttributedString*)text inRect:(NSRect)rect delegate:(id)del
{
	return [self editText:text
				   inRect:rect
				 delegate:del
		  drawsBackground:NO];
}

#define USE_STORAGE_REPLACEMENT 1

/** @brief Start editing text in a box within the view

 When an object in the drawing wishes to allow the user to edit some text, it can use this utility
 to set up the editor. This creates a subview for text editing with the nominated text and the
 bounds rect given within the drawing. The text is installed, selected and activated. User actions
 then edit that text. When done, call endTextEditing. To get the text edited, call editedText
 before ending the mode. You can only set one item at a time to be editable.
 @param text the text to edit
 @param rect the position and size of the text box to edit within
 @param del a delegate object
 @param drawBkGnd YES to draw a background, NO to have transparent text
 @return the temporary text view created to handle the job
 */
- (NSTextView*)editText:(NSAttributedString*)text inRect:(NSRect)rect delegate:(id)del drawsBackground:(BOOL)drawBkGnd
{
	NSAssert(text != nil, @"text was nil when trying to start a text editing operation");
	NSAssert(rect.size.width > 0, @"editing rect has 0 or -ve width");
	NSAssert(rect.size.height > 0, @"editing rect has 0 or -ve height");

	if ([self isTextBeingEdited])
		[self endTextEditing];

	// editor's frame is expanded by five points to ensure all characters are visible when not using screen fonts
	// container text inset is set to compensate for this.

	NSRect editorFrame = NSInsetRect(rect, -5, -5);

	if (m_textEditViewRef == nil)
		m_textEditViewRef = [[[[self class] classForTextEditor] alloc] initWithFrame:editorFrame];
	else {
		[m_textEditViewRef setDelegate:nil];
		[m_textEditViewRef setFrame:editorFrame];
		[m_textEditViewRef setSelectedRange:NSMakeRange(0, 0)];
	}

	[m_textEditViewRef setAllowsUndo:NO];

	NSLayoutManager* lm = [m_textEditViewRef layoutManager];

#if USE_STORAGE_REPLACEMENT
	NSTextStorage* textStorage = [[NSTextStorage alloc] initWithAttributedString:text];
	[lm replaceTextStorage:textStorage];
#else
	NSRange textRange = NSMakeRange(0, [[m_textEditViewRef textStorage] length]);

	if ([m_textEditViewRef shouldChangeTextInRange:textRange
								 replacementString:[text string]]) {
		[[m_textEditViewRef textStorage] beginEditing];
		[[m_textEditViewRef textStorage] replaceCharactersInRange:textRange
											 withAttributedString:text];
		[[m_textEditViewRef textStorage] endEditing];
		[m_textEditViewRef didChangeText];
	} else
		return nil;
#endif
	// not using screen fonts ensures precise WYSIWYG at small point sizes

	[lm setUsesScreenFonts:NO];

	[m_textEditViewRef setDrawsBackground:drawBkGnd];
	[m_textEditViewRef setFieldEditor:YES];
	[m_textEditViewRef setSelectedRange:NSMakeRange(0, [text length])];
	[m_textEditViewRef setDelegate:del];
	[m_textEditViewRef setNextResponder:self];
	[m_textEditViewRef setTextContainerInset:NSMakeSize(5, 5)];

	// if smart quotes is supported, set the editor to use the current preference. This feature requires 10.5 or later

	if ([m_textEditViewRef respondsToSelector:@selector(setAutomaticQuoteSubstitutionEnabled:)]) {
		BOOL smartQuotes = [[NSUserDefaults standardUserDefaults] boolForKey:kDKTextEditorSmartQuotesPrefsKey];
		[m_textEditViewRef setAutomaticQuoteSubstitutionEnabled:smartQuotes];
	}

	// register self as an observer of frame change notification, so that as the view expands and shrinks, it gets refreshed and doesn't leave bits of
	// itself visible

	[m_textEditViewRef setPostsFrameChangedNotifications:YES];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(editorFrameChangedNotification:)
												 name:NSViewFrameDidChangeNotification
											   object:m_textEditViewRef];
	mEditorFrame = [m_textEditViewRef frame];

	// add the subview and make it first responder

	[self addSubview:m_textEditViewRef];
	[[self window] makeFirstResponder:m_textEditViewRef];

	[m_textEditViewRef setNeedsDisplay:YES];

	[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingViewDidBeginTextEditing
														object:self];

	LogEvent_(kReactiveEvent, @"View began text editing, text editor = %@", m_textEditViewRef);

	mTextEditViewInUse = YES;

	// undo is enabled by the class setting but clients are free to override this

	[m_textEditViewRef setAllowsUndo:[[self class] textEditorAllowsTypingUndo]];

	return m_textEditViewRef;
}

/** @brief Stop the temporary text editing and get rid of the editing view
 */
- (void)endTextEditing
{
	if ([self isTextBeingEdited]) {
		// track smart quotes setting in prefs. Smart Quotes requires 10.5 or later

		if ([m_textEditViewRef respondsToSelector:@selector(isAutomaticQuoteSubstitutionEnabled)])
			[[NSUserDefaults standardUserDefaults] setBool:[m_textEditViewRef isAutomaticQuoteSubstitutionEnabled]
													forKey:kDKTextEditorSmartQuotesPrefsKey];

		[[NSNotificationCenter defaultCenter] removeObserver:self
														name:NSViewFrameDidChangeNotification
													  object:m_textEditViewRef];

		// once the edit session ends, undo tasks that applied to it would ideally be removed - the whole edit operation is still normally
		// undoable as a single undo command. However, there's a bug in NSUndoManager that causes a EXC_BAD_ACCESS when you do this.
		// So for now we leavethe annying "Undo Typing" tasks there. They will do nothong visible or useful. The aleternative is to
		// disable undo for the editor but it means undoing *while* typing won't work.

		[m_textEditViewRef setAllowsUndo:NO];
		[m_textEditViewRef setNeedsDisplay:YES];
		[m_textEditViewRef removeFromSuperview];
		[m_textEditViewRef setDelegate:nil];

		mTextEditViewInUse = NO;

		mEditorFrame = NSZeroRect;
		[self resetRulerClientView];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingViewDidEndTextEditing
															object:self];
		[[self window] makeFirstResponder:self];
	}
}

/** @brief Return the text from the temporary editing view

 This must be called prior to calling -endTextEditing, because the storage is made empty at that time
 @return the text
 */
- (NSTextStorage*)editedText
{
	return [[m_textEditViewRef layoutManager] textStorage];
}

@synthesize textEditingView = m_textEditViewRef;

/** @brief Respond to frame size changes in the text editor view

 This tidies up the display when the editor frame changes size. The frame can change
 during editing depending on how the client has configured it, but to prevent bits from being
 left behind when the frame is made smaller, this simply invalidates the previous frame rect.
 @param note the notification
 */
- (void)editorFrameChangedNotification:(NSNotification*)note
{
	[self setNeedsDisplayInRect:mEditorFrame];
	mEditorFrame = [[note object] frame];
}

@synthesize textBeingEdited = mTextEditViewInUse;

#pragma mark -
#pragma mark - ruler stuff

/** @brief Set the ruler lines to the current mouse point

 N.b. on 10.4 and earlier, there is a bug in NSRulerView that prevents both h and v ruler lines
 showing up correctly at the same time. No workaround is known. Fixed in 10.5+
 @param mouse the current mouse poin tin local coordinates */
- (void)updateRulerMouseTracking:(NSPoint)mouse
{
	// updates the mouse tracking marks on the rulers, if they are visible. Note that the point parameter is the location in the view's window
	// as obtained from an event - not the location in the drawing or view.

	static CGFloat ox = -1.0;
	static CGFloat oy = -1.0;

	NSScrollView* sv = [self enclosingScrollView];

	if (sv != nil) {
		NSRulerView* rh;
		NSRulerView* rv;
		NSPoint rp;

		if ([sv rulersVisible]) {
			rv = [sv verticalRulerView];
			rp = [rv convertPoint:mouse
						 fromView:nil];

			[rv moveRulerlineFromLocation:oy
							   toLocation:rp.y];
			oy = rp.y;

			rh = [sv horizontalRulerView];
			rp = [rh convertPoint:mouse
						 fromView:nil];

			[rh moveRulerlineFromLocation:ox
							   toLocation:rp.x];
			ox = rp.x;
		}
	}
}

/** @brief Set a ruler marker to a given position

 Generally called from the view's controller
 @param markerName the name of the marker to move
 @param loc a position value to move the ruler marker to
 */
- (void)moveRulerMarkerNamed:(NSString*)markerName toLocation:(CGFloat)loc
{
	NSScrollView* sv = [self enclosingScrollView];

	if (sv && [sv rulersVisible]) {
		NSRulerMarker* marker = [[self rulerMarkerInfo] objectForKey:markerName];
		if (loc != [marker markerLocation]) {
			NSRulerView* rv = [marker ruler];
			[rv setNeedsDisplayInRect:[marker imageRectInRuler]];
			[marker setMarkerLocation:loc];
			[rv setNeedsDisplayInRect:[marker imageRectInRuler]];
		}
	}
}

/** @brief Set up the markers for the rulers.

 Done as part of the view's initialization - markers are initially created offscreen.
 */
- (void)createRulerMarkers
{
	NSScrollView* sv = [self enclosingScrollView];

	if (sv != nil) {
		[self removeRulerMarkers];

		NSRulerView* rv;
		NSRulerMarker* rm;
		NSImage* markerImg;
		NSMutableDictionary* markerInfo = [NSMutableDictionary dictionary];

		rv = [sv horizontalRulerView];

		markerImg = [[self class] imageResourceNamed:kDKDrawingViewHorizontalLeftMarkerName];
		if (markerImg) {
			rm = [[NSRulerMarker alloc] initWithRulerView:rv
										   markerLocation:-10000.0
													image:markerImg
											  imageOrigin:NSMakePoint(4.0, 0.0)];
			[rv addMarker:rm];
			[markerInfo setObject:rm
						   forKey:kDKDrawingViewHorizontalLeftMarkerName];
		}

		markerImg = [[self class] imageResourceNamed:kDKDrawingViewHorizontalCentreMarkerName];
		if (markerImg) {
			rm = [[NSRulerMarker alloc] initWithRulerView:rv
										   markerLocation:-10000.0
													image:markerImg
											  imageOrigin:NSMakePoint(4.0, 0.0)];
			[rv addMarker:rm];
			[markerInfo setObject:rm
						   forKey:kDKDrawingViewHorizontalCentreMarkerName];
		}

		markerImg = [[self class] imageResourceNamed:kDKDrawingViewHorizontalRightMarkerName];
		if (markerImg) {
			rm = [[NSRulerMarker alloc] initWithRulerView:rv
										   markerLocation:-10000.0
													image:markerImg
											  imageOrigin:NSMakePoint(0.0, 0.0)];
			[rv addMarker:rm];
			[markerInfo setObject:rm
						   forKey:kDKDrawingViewHorizontalRightMarkerName];
		}

		rv = [sv verticalRulerView];

		markerImg = [[self class] imageResourceNamed:kDKDrawingViewVerticalTopMarkerName];
		if (markerImg) {
			rm = [[NSRulerMarker alloc] initWithRulerView:rv
										   markerLocation:-10000.0
													image:markerImg
											  imageOrigin:NSMakePoint(8.0, 1.0)];
			[rv addMarker:rm];
			[markerInfo setObject:rm
						   forKey:kDKDrawingViewVerticalTopMarkerName];
		}

		markerImg = [[self class] imageResourceNamed:kDKDrawingViewVerticalCentreMarkerName];
		if (markerImg) {
			rm = [[NSRulerMarker alloc] initWithRulerView:rv
										   markerLocation:-10000.0
													image:markerImg
											  imageOrigin:NSMakePoint(5.0, 5.0)];
			[rv addMarker:rm];
			[markerInfo setObject:rm
						   forKey:kDKDrawingViewVerticalCentreMarkerName];
		}

		markerImg = [[self class] imageResourceNamed:kDKDrawingViewVerticalBottomMarkerName];
		if (markerImg) {
			rm = [[NSRulerMarker alloc] initWithRulerView:rv
										   markerLocation:-10000.0
													image:markerImg
											  imageOrigin:NSMakePoint(8.0, 8.0)];
			[rv addMarker:rm];
			[markerInfo setObject:rm
						   forKey:kDKDrawingViewVerticalBottomMarkerName];
		}

		[self setRulerMarkerInfo:markerInfo];
	}
}

/** @brief Remove the markers from the rulers.
 */
- (void)removeRulerMarkers
{
	NSRulerView* rv = [[self enclosingScrollView] horizontalRulerView];
	[rv setMarkers:nil];

	rv = [[self enclosingScrollView] verticalRulerView];
	[rv setMarkers:nil];

	[self setRulerMarkerInfo:nil];
}

/** @brief Set up the client view for the rulers.

 Done as part of the view's initialization
 */
- (void)resetRulerClientView
{
	NSRulerView* ruler;

	ruler = [[self enclosingScrollView] horizontalRulerView];

	if (ruler != nil) {
		[ruler setClientView:self];
		[ruler setAccessoryView:nil];
	}

	ruler = [[self enclosingScrollView] verticalRulerView];

	if (ruler != nil) {
		[ruler setClientView:self];
	}
	[self createRulerMarkers];
}

/** @brief Show or hide the ruler.
 @param sender the action's sender
 */
- (IBAction)toggleRuler:(id)sender
{
#pragma unused(sender)

	BOOL rvis = [[self enclosingScrollView] rulersVisible];
	[[self enclosingScrollView] setRulersVisible:!rvis];

	[[NSUserDefaults standardUserDefaults] setBool:!rvis
											forKey:kDKDrawingRulersVisibleDefaultPrefsKey];
	[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingViewRulersChanged
														object:self];
}

@synthesize rulerMarkerInfo = mRulerMarkersDict;

#pragma mark -
#pragma mark - monitoring the mouse location

- (void)postMouseLocationInfo:(NSString*)operation event:(NSEvent*)event
{
	NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity:2];
	NSPoint p = [self convertPoint:[event locationInWindow]
						  fromView:nil];
	NSPoint cp = [[self drawing] convertPoint:p];

	[dict setObject:[NSValue valueWithPoint:p]
			 forKey:kDKDrawingMouseLocationInView];
	[dict setObject:[NSValue valueWithPoint:cp]
			 forKey:kDKDrawingMouseLocationInDrawingUnits];

	[[NSNotificationCenter defaultCenter] postNotificationName:operation
														object:self
													  userInfo:dict];
}

#pragma mark -
#pragma mark window activations

/** @brief Invalidate the view when window active state changes.

 Drawings can change appearance when the active state changes, for example selections are drawn
 in inactive colour, etc. This makes sure that the drawing is refreshed when the state does change.
 @param note the notification
 */
- (void)windowActiveStateChanged:(NSNotification*)note
{
#pragma unused(note)

	if ([[self window] isMainWindow])
		[[self enclosingScrollView] setBackgroundColor:[[self class] backgroundColour]];
	else
		[[self enclosingScrollView] setBackgroundColor:[NSColor veryLightGrey]];

	[self setNeedsDisplay:YES];
}

#pragma mark -

- (void)set
{
	// sets this view as the currently drawing view, pushing the current one onto the stack. A +pop will put the original one back. This allows nested drawRect: calls to work
	// across several views, which may occur in unusual circumstances, such as caching PDF data using a PDF view.

	[[self class] pushCurrentViewAndSet:self];
}

#pragma mark -
#pragma mark As an NSView

/** @brief Draw the content of the drawing.

 Draws the entire drawing content, then any controller-based content, then finally the pagebreaks.
 If at this point there is no drawing, one is automatically created so that you can get a working
 DK system simply by dropping a DKDrawingView into a window in a nib, and away you go.
 @param rect the rect to update
 */
- (void)drawRect:(NSRect)rect
{
	// draw the entire content of the drawing:

	[self set];
	[[self drawing] drawRect:rect
					  inView:self];

	// if our controller implements a drawRect: method, call it - the default controller doesn't but subclasses can.
	// any drawing done by a controller will be "on top" of any drawing content. Typically this is used by tools
	// that draw something, such as a selection rect, etc.

	if ([[self controller] respondsToSelector:@selector(drawRect:)])
		[(id)[self controller] drawRect:rect];

	// draw page breaks on top of everything else if enabled

	BOOL printing = ![NSGraphicsContext currentContextDrawingToScreen];

	if (!printing && [self pageBreaksVisible] && [self printInfo])
		[self drawPageBreaks];

	if (printing && [self printCropMarkKind] != DKCropMarksNone)
		[self drawCropMarks];

	[[self class] pop];
}

/** @brief Is the view flipped.
 @return returns the flipped state of the drawing itself (which actually only affects the views, but
 the drawing holds this state because all views should be consistent)
 */
- (BOOL)isFlipped
{
	if ([self drawing] != nil)
		return [[self drawing] isFlipped];
	else
		return YES;
}

/** @brief Is the view opaque, yes.
 @return always YES
 */
- (BOOL)isOpaque
{
	return YES;
}

/** @brief Invalidate the cursor rects and set up new ones

 The controller will supply a cursor and an active rect to apply it in
 */
- (void)resetCursorRects
{
	NSCursor* curs = [[self controller] cursor];
	NSRect cr = [[self controller] activeCursorRect];

	cr = NSIntersectionRect(cr, [self visibleRect]);

	[self addCursorRect:cr
				 cursor:curs];
	[curs setOnMouseEntered:YES];
}

/** @brief Create a menu that is used for a right-click in the view

 Initially defers to the controller, then to super
 @param event the event
 @return a menu, or nil
 */
- (NSMenu*)menuForEvent:(NSEvent*)event
{
	[self set];
	NSMenu* menu = [[self controller] menuForEvent:event];
	[[self class] pop];

	if (menu == nil)
		menu = [super menuForEvent:event];

	// if the menu was created, record the local mouse down point so that client code can get this point
	// if needed when responding to a menu command in the menu.

	if (menu != nil)
		sLastContextMenuClick = [self convertPoint:[event locationInWindow]
										  fromView:nil];

	return menu;
}

/** @brief Accept whether the activating click is also handled as a mouse down
 @param event the event
 @return YES
 */
- (BOOL)acceptsFirstMouse:(NSEvent*)event
{
#pragma unused(event)

	return YES;
}

/** @brief Tell drawing system that we preserve the content for live resize
 @return YES
 */
- (BOOL)preservesContentDuringLiveResize
{
	return YES;
}

/** @brief Invalidate areas not preserved during live resize
 */
- (void)setFrameSize:(NSSize)newSize
{
	[super setFrameSize:newSize];

	if ([self inLiveResize]) {
		NSRect rects[4];
		NSInteger count;

		[self getRectsExposedDuringLiveResize:rects
										count:&count];

		while (count-- > 0)
			[self setNeedsDisplayInRect:rects[count]];
	} else
		[self setNeedsDisplay:YES];
}

- (BOOL)lockFocusIfCanDraw
{
	// if at the point where the view is asked to draw something, there is no "back end", it creates one
	// automatically on the basis of its current bounds. In this case, the view owns the drawing. This is done here rather than in -drawRect:
	// though ideally it would go in -viewWillDraw, however that is >= 10.5 only.

	if ([self drawing] == nil)
		[self createAutomaticDrawing];

	return [super lockFocusIfCanDraw];
}

- (void)viewWillDraw
{
	// if at the point where the view is asked to draw something, if there is no "back end", it creates one
	// automatically on the basis of its current bounds. In this case, the view owns the drawing. This is done here rather than in -drawRect:
	if ([self drawing] == nil)
		[self createAutomaticDrawing];
	
	[super viewWillDraw];
}

#pragma mark -
#pragma mark As an NSResponder

/** @brief Can the view be 1st R?
 @return always YES
 */
- (BOOL)acceptsFirstResponder
{
	return YES;
}

/** @brief Handle the key down event

 Key down events are preprocessed in the usual way and end up getting forwarded down through
 the controller and active layer because of invocation forwarding. Thus you can respond to
 normal NSResponder methods at any level that makes sense within DK. The controller is however
 given first shot at the raw event, in case it does something special (like DKToolController does
 for selecting a tool using a keyboard shortcut).
 @param event the event
 */
- (void)keyDown:(NSEvent*)event
{
	if ([[self controller] respondsToSelector:@selector(keyDown:)])
		[(NSResponder*)[self controller] keyDown:event];
	else
		[self interpretKeyEvents:@[event]];
}

/** @brief Handle the mouse down event

 The view defers to its controller after broadcasting the mouse position info
 @param event the event
 */
- (void)mouseDown:(NSEvent*)event
{
	[self postMouseLocationInfo:kDKDrawingMouseDownLocation
						  event:event];
	[self set];
	[[self controller] mouseDown:event];
}

/** @brief Handle the mouse dragged event

 The view defers to its controller after broadcasting the mouse position info
 @param event the event
 */
- (void)mouseDragged:(NSEvent*)event
{
	// do not process drags at more than 40 fps...

	NSTimeInterval t = [event timestamp];

	if (t > mLastMouseDragTime + 0.025) {
		mLastMouseDragTime = t;

		[self updateRulerMouseTracking:[event locationInWindow]];
		[self postMouseLocationInfo:kDKDrawingMouseDraggedLocation
							  event:event];
		[[self controller] mouseDragged:event];
	}
}

/** @brief Handle the mouse moved event

 The view defers to its controller after updating the ruler lines and broadcasting the mouse position info
 @param event the event
 */
- (void)mouseMoved:(NSEvent*)event
{
	// update the ruler mouse tracking lines if the rulers are visible.

	[self updateRulerMouseTracking:[event locationInWindow]];
	[self postMouseLocationInfo:kDKDrawingMouseMovedLocation
						  event:event];
	[[self controller] mouseMoved:event];
}

/** @brief Handle the mouse up event

 The view defers to its controller after broadcasting the mouse position info
 @param event the event
 */
- (void)mouseUp:(NSEvent*)event
{
	[self postMouseLocationInfo:kDKDrawingMouseUpLocation
						  event:event];
	[[self controller] mouseUp:event];
	[[self class] pop];
}

/** @brief Handle the flags changed event

 The view simply defers to its controller
 @param event the event
 */
- (void)flagsChanged:(NSEvent*)event
{
	[[self controller] flagsChanged:event];
}

/** @brief Do the command requested

 This overrides the default implementation to send itself as the <sender> parameter. Because in
 fact the selector is actually forwarded down to some other objects deep inside DK, this is a very
 easy way for them to get passed the view from whence the event came. NSResponder methods such
 as moveLeft: are called by this.
 @param aSelector the selector for a command
 */
- (void)doCommandBySelector:(SEL)aSelector
{
	if ([self respondsToSelector:aSelector])
		[self tryToPerform:aSelector
					  with:self];
	else
		[super doCommandBySelector:aSelector];
}

/** @brief Insert text

 This overrides the default implementation to forward insertText: to the active layer and beyond.
 @param aString the text to insert
 */
- (void)insertText:(id)aString
{
	if ([[self controller] respondsToSelector:_cmd])
		[(id)[self controller] insertText:aString];
}

#pragma mark -

- (void)changeAttributes:(id)sender
{
	// TODO: ensure this method is no longer called, and remove

	// workaround 10.5 and earlier bug where target isn't applied to -changeAttributes: and ends up in the responder chain
	// instead. This catches it and sends it to the true target before our forwarding mechanism gets to work on it.

	if (sender == [NSFontManager sharedFontManager]) {
		id target = [sender target];

		if (target && [target respondsToSelector:_cmd]) {
			//NSLog(@"redirecting -changeAttributes: to %@", target );

			[target changeAttributes:sender];
			return;
		}
	}
}

#pragma mark -
#pragma mark As an NSObject

/** @brief Deallocate the view
 */
- (void)dealloc
{
	// going away - make sure our controller is removed from the drawing

	if ([self controller] != nil) {
		[[self controller] setView:nil];
		[[self drawing] removeController:[self controller]];
		[self setController:nil];
	}

	[[NSNotificationCenter defaultCenter] removeObserver:self];

	// if the view automatically created its own "back-end", release all of that now - the drawing owns the controllers so
	// they are also disposed of.
}

/** @brief Forward an invocation to the active layer if it implements it

 DK makes a lot of use of invocation forwarding - views forward to their controllers, which forward
 to the active layer, which may forward to selected objects within the layer. This allows objects
 to respond to action methods and so forth at their own level.
 @param invocation the invocation to forward
 */
- (void)forwardInvocation:(NSInvocation*)invocation
{
	// commands can be implemented by the layer that wants to make use of them - this makes it happen by forwarding unrecognised
	// method calls to the active layer if possible.

	SEL aSelector = [invocation selector];

	if ([[self controller] respondsToSelector:aSelector]) {
		[invocation invokeWithTarget:[self controller]];
	} else
		[self doesNotRecognizeSelector:aSelector];
}

/** @brief Return a method's signature

 DK makes a lot of use of invocaiton forwarding - views forward to their controllers, which forward
 to the active layer, which may forward to selected objects within the layer. This allows objects
 to respond to action methods and so forth at their own level.
 @param aSelector the selector
 @return the signature for the method
 */
- (NSMethodSignature*)methodSignatureForSelector:(SEL)aSelector
{
	NSMethodSignature* sig;

	sig = [super methodSignatureForSelector:aSelector];

	if (sig == nil)
		sig = [[self controller] methodSignatureForSelector:aSelector];

	return sig;
}

/** @brief Return whether the selector can be responded to

 DK makes a lot of use of invocaiton forwarding - views forward to their controllers, which forward
 to the active layer, which may forward to selected objects within the layer. This allows objects
 to respond to action methods and so forth at their own level.
 @param aSelector the selector
 @return YES or NO
 */
- (BOOL)respondsToSelector:(SEL)aSelector
{
	BOOL responds = [super respondsToSelector:aSelector];

	if (!responds)
		responds = [[self controller] respondsToSelector:aSelector];

	return responds;
}

#pragma mark -
#pragma mark As part of NSMenuValidation Protocol

/** @brief Enable and set menu item state for actions implemented by the controller
 @param item the menu item to validate
 @return YES or NO
 */
- (BOOL)validateMenuItem:(NSMenuItem*)item
{
	SEL action = [item action];

	if (action == @selector(toggleRuler:)) {
		BOOL rvis = [[self enclosingScrollView] rulersVisible];
		[item setTitle:NSLocalizedString(rvis ? @"Hide Rulers" : @"Show Rulers", @"")];
		return YES;
	}

	if (action == @selector(toggleShowPageBreaks:)) {
		[item setTitle:NSLocalizedString([self pageBreaksVisible] ? @"Hide Page Breaks" : @"Show Page Breaks", @"page break menu items")];
		return YES;
	}

	BOOL e1 = [super validateMenuItem:item];
	BOOL e2 = [[self controller] validateMenuItem:item];

	return e1 || e2;
}

#pragma mark -
#pragma mark As part of NSNibAwaking Protocol

/** @brief Set up the rulers and other defaults when the view is first created

 Typically you should create your views from a NIB, it's just much easier that way. If you decide to
 do it the hard way you'll have to do this set up yourself.
 */
- (void)awakeFromNib
{
	NSScrollView* sv = [self enclosingScrollView];

	if (sv) {
		[sv setHasHorizontalRuler:YES];
		[sv setHasVerticalRuler:YES];

		BOOL rvis = [[NSUserDefaults standardUserDefaults] boolForKey:kDKDrawingRulersVisibleDefaultPrefsKey];
		[sv setRulersVisible:rvis];

		[sv setDrawsBackground:YES];
		[sv setBackgroundColor:[[self class] backgroundColour]];

		[[sv horizontalRulerView] setClientView:self];
		[[sv horizontalRulerView] setReservedThicknessForMarkers:6.0];

		[[sv verticalRulerView] setClientView:self];
		[[sv verticalRulerView] setReservedThicknessForMarkers:6.0];

		[self resetRulerClientView];
	}
	[[self window] setAcceptsMouseMovedEvents:YES];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(windowActiveStateChanged:)
												 name:NSWindowDidResignMainNotification
											   object:[self window]];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(windowActiveStateChanged:)
												 name:NSWindowDidBecomeMainNotification
											   object:[self window]];
}

@end
