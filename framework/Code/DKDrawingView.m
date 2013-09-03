///**********************************************************************************************************************************
///  DKDrawingView.m
///  DrawKit ¬¨¬®¬¨¬©2005-2008 Apptree.net
///
///  Created by graham on 11/08/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************


#import "DKDrawingView.h"
#import "DKToolController.h"
#import "DKDrawing.h"
#import "DKGridLayer.h"
#import "GCThreadQueue.h"
#import "LogEvent.h"
#import "NSBezierPath+Shapes.h"
#import "NSColor+DKAdditions.h"

#pragma mark Constants (Non-localized)

NSString* kDKDrawingViewDidBeginTextEditing				= @"kDKDrawingViewDidBeginTextEditing";
NSString* kDKDrawingViewTextEditingContentsDidChange	= @"kDKDrawingViewTextEditingContentsDidChange";
NSString* kDKDrawingViewDidEndTextEditing				= @"kDKDrawingViewDidEndTextEditing";
NSString* kDKDrawingViewWillCreateAutoDrawing			= @"kDKDrawingViewWillCreateAutoDrawing";
NSString* kDKDrawingViewDidCreateAutoDrawing			= @"kDKDrawingViewDidCreateAutoDrawing";
NSString* kDKDrawingMouseDownLocation					= @"kDKDrawingMouseDownLocation";
NSString* kDKDrawingMouseDraggedLocation				= @"kDKDrawingMouseDraggedLocation";
NSString* kDKDrawingMouseUpLocation						= @"kDKDrawingMouseUpLocation";
NSString* kDKDrawingMouseMovedLocation					= @"kDKDrawingMouseMovedLocation";
NSString* kDKDrawingMouseLocationInView					= @"kDKDrawingMouseLocationInView";
NSString* kDKDrawingMouseLocationInDrawingUnits			= @"kDKDrawingMouseLocationInDrawingUnits";
NSString* kDKDrawingRulersVisibleDefaultPrefsKey		= @"kDKDrawingRulersVisibleDefault";
NSString* kDKTextEditorSmartQuotesPrefsKey				= @"kDKTextEditorSmartQuotes";
NSString* kDKDrawingViewRulersChanged					= @"kDKDrawingViewRulersChanged";


// constant strings for ruler marker names

NSString*		kDKDrawingViewHorizontalLeftMarkerName		= @"marker_h_left";
NSString*		kDKDrawingViewHorizontalCentreMarkerName	= @"marker_h_centre";
NSString*		kDKDrawingViewHorizontalRightMarkerName		= @"marker_h_right";
NSString*		kDKDrawingViewVerticalTopMarkerName			= @"marker_v_top";
NSString*		kDKDrawingViewVerticalCentreMarkerName		= @"marker_v_centre";
NSString*		kDKDrawingViewVerticalBottomMarkerName		= @"marker_v_bottom";

#pragma mark Static Vars

static NSMutableArray*	sDrawingViewStack = nil;	// stack of view refs
static NSColor*			sPageBreakColour = nil;
static NSPoint			sLastContextMenuClick = {0,0};

NSString* kDKTextEditorUndoesTypingPrefsKey					= @"kDKTextEditorUndoesTyping";


@interface DKDrawingView (Private)

+ (void)				secondaryThreadEntryPoint:(id) obj;
+ (BOOL)				secondaryThreadShouldRun;
+ (void)				signalSecondaryThreadShouldDrawInRect:(NSRect) rect withView:(DKDrawingView*) aView;
- (void)				postMouseLocationInfo:(NSString*) operation event:(NSEvent*) event;
+ (void)				pushCurrentViewAndSet:(DKDrawingView*) aView;
- (void)				setRulerMarkerInfo:(NSDictionary*) dict;
- (NSDictionary*)		rulerMarkerInfo;

@end


#pragma mark -
@implementation DKDrawingView
#pragma mark As a DKDrawingView


///*********************************************************************************************************************
///
/// method:			currentlyDrawingView
/// scope:			public class method
/// overrides:
/// description:	return the view currently drawing
/// 
/// parameters:		none
/// result:			the current view that is drawing
///
/// notes:			this is only valid during a drawRect: call - some internal parts of DK use this to obtain the
///					view doing the drawing when they do not have a direct parameter to it.
///
///********************************************************************************************************************

+ (DKDrawingView*)		currentlyDrawingView
{
	return [sDrawingViewStack lastObject];
}


+ (void)				pushCurrentViewAndSet:(DKDrawingView*) aView
{
	if( sDrawingViewStack == nil )
		sDrawingViewStack = [[NSMutableArray alloc] init];
		
	//NSLog(@"pushing %@; setting %@", [self currentlyDrawingView], aView);
		
	[sDrawingViewStack addObject:aView];
}


+ (void)				pop
{
	NSUInteger stackSize = [sDrawingViewStack count];
	
	if( stackSize > 0 )
		[sDrawingViewStack removeObjectAtIndex:stackSize - 1];

	//NSLog(@"popping %@", [self currentlyDrawingView]);
}


///*********************************************************************************************************************
///
/// method:			setPageBreakColour:
/// scope:			public class method
/// overrides:
/// description:	set the colour used to draw the page breaks
/// 
/// parameters:		<colour> the colour to draw page breaks with
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

+ (void)				setPageBreakColour:(NSColor*) colour
{
	[colour retain];
	[sPageBreakColour release];
	sPageBreakColour = colour;
}


///*********************************************************************************************************************
///
/// method:			pageBreakColour
/// scope:			public class method
/// overrides:
/// description:	get the colour used to draw the page breaks
/// 
/// parameters:		none
/// result:			a colour
///
/// notes:			
///
///********************************************************************************************************************

+ (NSColor*)			pageBreakColour
{
	if ( sPageBreakColour == nil )
	{
		sPageBreakColour = [[[NSColor cyanColor] colorWithAlphaComponent:0.75] retain];
	}
	
	return sPageBreakColour;
}


///*********************************************************************************************************************
///
/// method:			backgroundColour
/// scope:			public class method
/// overrides:
/// description:	return the colour used to draw the background area of the scrollview outside the drawing area
/// 
/// parameters:		none
/// result:			a colour
///
/// notes:			
///
///********************************************************************************************************************

+ (NSColor*)			backgroundColour
{
	return [NSColor colorWithCalibratedRed:0.75 green:0.75 blue:0.8 alpha:1.0];
}


///*********************************************************************************************************************
///
/// method:			pointForLastContextualMenuEvent
/// scope:			public class method
/// overrides:
/// description:	get the point for the initial mouse down that last opened a contextual menu
/// 
/// parameters:		none
/// result:			a point in the drawing's coordinates
///
/// notes:			
///
///********************************************************************************************************************

+ (NSPoint)				pointForLastContextualMenuEvent
{
	return sLastContextMenuClick;
}


///*********************************************************************************************************************
///
/// method:			imageResourceNamed:
/// scope:			public class method
/// overrides:
/// description:	return an image resource from the framework bundle
/// 
/// parameters:		<name> the image name
/// result:			the image, if available
///
/// notes:			
///
///********************************************************************************************************************

+ (NSImage*)			imageResourceNamed:(NSString*) name
{
	NSString *path = [[NSBundle bundleForClass:self] pathForImageResource:name];
	NSImage *image = [[NSImage alloc] initByReferencingFile:path];
	return [image autorelease];
}


#pragma mark -
#pragma mark - setting the class for the temporary text editor

static Class	s_textEditorClass = Nil;

+ (Class)				classForTextEditor
{
	if( s_textEditorClass == nil )
		s_textEditorClass = [NSTextView class];
	
	return s_textEditorClass;
}


+ (void)				setClassForTextEditor:(Class) aClass
{
	if([aClass isSubclassOfClass:[NSTextView class]])
		s_textEditorClass = aClass;
}


+ (void)				setTextEditorAllowsTypingUndo:(BOOL) allowUndo
{
	[[NSUserDefaults standardUserDefaults] setBool:allowUndo forKey:kDKTextEditorUndoesTypingPrefsKey];
}


+ (BOOL)				textEditorAllowsTypingUndo
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:kDKTextEditorUndoesTypingPrefsKey];
}


#pragma mark -
#pragma mark - the view's controller

///*********************************************************************************************************************
///
/// method:			setController:
/// scope:			public instance method
/// overrides:
/// description:	set the view's controller
/// 
/// parameters:		<aController> the controller for this view
/// result:			none
///
/// notes:			do not call this directly - the controller will call it to set up the relationship at the right
///					time.
///
///********************************************************************************************************************

- (void)				setController:(DKViewController*) aController
{
	mControllerRef = aController;
}


///*********************************************************************************************************************
///
/// method:			controller
/// scope:			public instance method
/// overrides:
/// description:	return the view's controller
/// 
/// parameters:		none
/// result:			the controller
///
/// notes:			
///
///********************************************************************************************************************

- (DKViewController*)	controller
{
	return mControllerRef;
}


///*********************************************************************************************************************
///
/// method:			replaceControllerWithController:
/// scope:			public instance method
/// overrides:
/// description:	sea new controller for this view
/// 
/// parameters:		<newController> the new controller
/// result:			none
///
/// notes:			this is a convenience that allows a controller to be simply instantiated and passed in, replacing
///					the existing controller. Note that -setController: does NOT achieve that. The drawing must
///					already exist for this to work.
///
///********************************************************************************************************************

- (void)				replaceControllerWithController:(DKViewController*) newController
{
	NSAssert([self drawing] != nil, @"cannot replace the controller as there is no drawing yet");
	NSAssert( newController != nil, @"cannot replace the controller with nil");
	NSAssert([newController isKindOfClass:[DKViewController class]], @"new controller must be a DKViewController or subclass");
	
	if( newController != [self controller])
	{
		DKDrawing* dwg = [self drawing];
		
		[dwg removeController:[self controller]];
		[newController setView:self];
		[dwg addController:newController];
	}
}



#pragma mark -
#pragma mark - drawing info

///*********************************************************************************************************************
///
/// method:			drawing
/// scope:			public instance method
/// overrides:
/// description:	return the drawing that the view will draw
/// 
/// parameters:		none
/// result:			a drawing object
///
/// notes:			the drawing is obtained via the controller, and may be nil if the controller hasn't been added
///					to a drawing yet. Even when the view owns the drawing (for auto back-end) you should use this
///					method to get a view's drawing.
///
///********************************************************************************************************************

- (DKDrawing*)			drawing
{
	return [[self controller] drawing];
}


///*********************************************************************************************************************
///
/// method:			createAutomaticDrawing
/// scope:			private instance method
/// overrides:
/// description:	create an entire "back end" for the view 
/// 
/// parameters:		none
/// result:			none
///
/// notes:			Normally you create a drawing, and add layers to it. However, you can also let the view create the
///					drawing back-end for you. This will occur when the view is asked to draw and there is no back end. This method
///					does the building. This feature means you can simply drop a drawingView into a NIB and get a
///					functional drawing program. For more sophisticated needs however, you really need to build it yourself.
///
///********************************************************************************************************************

- (void)				createAutomaticDrawing
{
	NSSize viewSize = [self bounds].size;
	
	LogEvent_( kReactiveEvent, @"View automatically instantiating a drawing (size = %@)", NSStringFromSize( viewSize ));
	
	[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingViewWillCreateAutoDrawing object:self];
	
	[DKDrawing loadDefaults];
	mAutoDrawing = [[DKDrawing defaultDrawingWithSize:viewSize] retain];
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
	
	NSUndoManager*	um = [self undoManager];
	
	[mAutoDrawing setUndoManager:um];
	[um setLevelsOfUndo:24];

	[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingViewDidCreateAutoDrawing object:self];

	NSAssert([mAutoDrawing undoManager] != nil, @"note - automatic drawing was created before an undo manager was available. Check your code!");
}


///*********************************************************************************************************************
///
/// method:			makeViewController
/// scope:			public instance method
/// overrides:
/// description:	creates a controller for this view that can be added to a drawing
/// 
/// parameters:		none
/// result:			a controller, an instance of DKViewController or one of its subclasses
///
/// notes:			Normally you wouldn't call this yourself unless you are building the entire DK system by hand rather
///					than using DKDrawDocument or automatic drawing creation. You can override it to create different
///					kinds of controller however. Th edefault controller is DKToolController so that DK provides you
///					with a set of working drawing tools by default.
///
///********************************************************************************************************************

- (DKViewController*)	makeViewController
{
	DKToolController* aController = [[DKToolController alloc] initWithView:self];
	return [aController autorelease];
}


#pragma mark -
#pragma mark - drawing page breaks and crop marks


///*********************************************************************************************************************
///
/// method:			pageBreakPathWithExtension:options:
/// scope:			protected method
/// overrides:
/// description:	returns a path which represents all of the printed page rectangles
/// 
/// parameters:		<amount> the extension amount by which each line is extended beyond the end of the corner. May be 0.
///					<options> crop marks kind
/// result:			a bezier path, may be stroked in various ways to show page breaks, crop marks, etc.
///
/// notes:			Any extension may not end up visible when printed depending on the printer's margin settings, etc.
///					The only supported option currently is kDKCornerOnly, which generates corner crop marks rather
///					than the full rectangles.
///
///********************************************************************************************************************

- (NSBezierPath*)		pageBreakPathWithExtension:(CGFloat) amount options:(DKCropMarkKind) options
{
	NSRect		pr, dr;
	NSInteger	pagesAcross, pagesDown;
	NSSize		ds = [[self drawing] drawingSize];
	NSSize		ps = [[self printInfo] paperSize];
	
	dr.origin = NSZeroPoint;
	dr.size = ds;
	
	if([[self printInfo] horizontalPagination] != NSAutoPagination)
	{
		pagesAcross = 1;
		
		if([[self printInfo] horizontalPagination] == NSFitPagination)
			ps.width = ds.width;
	}
	else
	{
		ps.width -= ([[self printInfo] leftMargin] + [[self printInfo] rightMargin]);
		pagesAcross = MAX( 1, _CGFloatFloor(ds.width / ps.width));
		if ( fmodf( ds.width, ps.width ) > 2.0 )
			++pagesAcross;
	}
	
	if([[self printInfo] verticalPagination] != NSAutoPagination)
	{
		pagesDown = 1;
		
		if([[self printInfo] verticalPagination] == NSFitPagination)
			ps.height = ds.height;
	}
	else
	{
		ps.height -= ([[self printInfo] topMargin] + [[self printInfo] bottomMargin]);
		pagesDown = MAX( 1, _CGFloatFloor(ds.height / ps.height));
		if ( fmodf( ds.height, ps.height ) > 2.0 )
			++pagesDown;
	}
	
	pr.size = ps;
	
	NSInteger		page;
	
	NSBezierPath* pbPath = [NSBezierPath bezierPath];
	
	for( page = 0; page < (pagesAcross * pagesDown); ++page )
	{
		pr.origin.y = ( page / pagesAcross ) * ps.height;
		pr.origin.x = ( page % pagesAcross ) * ps.width;
		
		NSRect ar = (options & DKCropMarksEdges)? NSIntersectionRect( pr, dr ) : pr;
		
		if( amount <= 0.0 && (( options & DKCropMarksCorners ) == 0 ))
			[pbPath appendBezierPathWithRect:ar];
		else
		{
			// extending or doing corners only. This is somewhat more involved.
			
			if( options & DKCropMarksCorners )
				[pbPath appendBezierPath:[NSBezierPath bezierPathWithCropMarksForRect:ar length:30 extension:amount]];
			else
				[pbPath appendBezierPath:[NSBezierPath bezierPathWithCropMarksForRect:ar extension:amount]];
		}
	}
	
	return pbPath;
}

///*********************************************************************************************************************
///
/// method:			drawPageBreaks
/// scope:			protected method
/// overrides:
/// description:	draw page breaks based on the page break print info
/// 
/// parameters:		none
/// result:			none
///
/// notes:			called from drawRect if a p/b print info is set
///
///********************************************************************************************************************

- (void)				drawPageBreaks
{
	NSBezierPath* pbPath = [self pageBreakPathWithExtension:0 options:DKCropMarksNone];
	
	//float pbDashPattern[] = { 8.0, 8.0 };
	
	[pbPath setLineWidth:1];
	//[pbPath setLineDash:pbDashPattern count:2 phase:0.0];
	//[pbPath setLineCapStyle:NSButtLineCapStyle];
	[[[self class] pageBreakColour] setStroke];
	[pbPath stroke];
}


///*********************************************************************************************************************
///
/// method:			setPrintInfo:
/// scope:			public method
/// overrides:
/// description:	sets the print info to use for drawing the page breaks, paginating and general printing operations
/// 
/// parameters:		<pbpi> the print info
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				setPrintInfo:(NSPrintInfo*) pbpi
{
	[pbpi retain];
	[mPrintInfo release];
	mPrintInfo = pbpi;
	
	[self setNeedsDisplay:YES];
}


///*********************************************************************************************************************
///
/// method:			printInfo
/// scope:			public method
/// overrides:
/// description:	return the print info to use for drawing the page breaks, paginating and general printing operations
/// 
/// parameters:		none
/// result:			a NSPrintInfo object
///
/// notes:			
///
///********************************************************************************************************************

- (NSPrintInfo*)		printInfo
{
	return mPrintInfo;
}



///*********************************************************************************************************************
///
/// method:			setPageBreaksVisible:
/// scope:			public method
/// overrides:
/// description:	sets whether the page breaks are shown or not
/// 
/// parameters:		<pbVisible> YES to show the page breaks, NO otherwise
/// result:			none
///
/// notes:			page breaks also need a valid printInfo object set
///
///********************************************************************************************************************

- (void)				setPageBreaksVisible:(BOOL) pbVisible
{
	if( pbVisible != [self pageBreaksVisible])
	{
		mPageBreaksVisible = pbVisible;
		[self setNeedsDisplay:YES];
	}
}


///*********************************************************************************************************************
///
/// method:			pageBreaksVisible
/// scope:			public instance method
/// overrides:		
/// description:	are page breaks vissble?
/// 
/// parameters:		none
/// result:			YES if page breaks are visible
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				pageBreaksVisible
{
	return mPageBreaksVisible;
}



///*********************************************************************************************************************
///
/// method:			toggleShowPageBreaks:
/// scope:			public action method
/// overrides:		
/// description:	show or hide the page breaks
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (IBAction)				toggleShowPageBreaks:(id) sender
{
	#pragma unused(sender)
	[self setPageBreaksVisible:![self pageBreaksVisible]];
}


///*********************************************************************************************************************
///
/// method:			setPrintCropMarkKind:
/// scope:			public instance method
/// overrides:		
/// description:	set what kind of crop marks printed output includes
/// 
/// parameters:		<kind> the kind of crop mark (including none)
/// result:			none
///
/// notes:			default is no crop marks
///
///********************************************************************************************************************

- (void)				setPrintCropMarkKind:(DKCropMarkKind) kind
{
	if( kind != mCropMarkKind )
	{
		mCropMarkKind = kind;
		[self setNeedsDisplay:YES];
	}
}


///*********************************************************************************************************************
///
/// method:			printCropMarkKind
/// scope:			public instance method
/// overrides:		
/// description:	what sort of crop mark sare applied to printed output
/// 
/// parameters:		none
/// result:			the crop mark kind
///
/// notes:			default is no crop marks
///
///********************************************************************************************************************

- (DKCropMarkKind)		printCropMarkKind
{
	return mCropMarkKind;
}

///*********************************************************************************************************************
///
/// method:			drawCropMarks
/// scope:			protected instance method
/// overrides:		
/// description:	draws the crop marks if set to do so and the view is being printed
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				drawCropMarks
{
	//NSLog(@"drawing crop marks");
	
	NSBezierPath* pbPath = [self pageBreakPathWithExtension:10 options:[self printCropMarkKind]];
	
	[pbPath setLineWidth:0.1];
	[pbPath setLineCapStyle:NSButtLineCapStyle];
	[pbPath setLineJoinStyle:NSMiterLineJoinStyle];
	[[NSColor blackColor] setStroke];
	[pbPath stroke];
}



#pragma mark -
#pragma mark - editing text directly in the drawing

///*********************************************************************************************************************
///
/// method:			editText:inRect:delegate:
/// scope:			public instance method
/// overrides:		
/// description:	start editing text in a box within the view
/// 
/// parameters:		<text> the text to edit
///					<rect> the position and size of the text box to edit within
///					<del> a delegate object
/// result:			the temporary text view created to handle the job
///
/// notes:			When an object in the drawing wishes to allow the user to edit some text, it can use this utility
///					to set up the editor. This creates a subview for text editing with the nominated text and the
///					bounds rect given within the drawing. The text is installed, selected and activated. User actions
///					then edit that text. When done, call endTextEditing. To get the text edited, call editedText
///					before ending the mode. You can only set one item at a time to be editable.
///
///********************************************************************************************************************

- (NSTextView*)			editText:(NSAttributedString*) text inRect:(NSRect) rect delegate:(id) del
{
	return [self editText:text inRect:rect delegate:del drawsBackground:NO];
}


///*********************************************************************************************************************
///
/// method:			editText:inRect:delegate:drawsBackground:
/// scope:			public instance method
/// overrides:		
/// description:	start editing text in a box within the view
/// 
/// parameters:		<text> the text to edit
///					<rect> the position and size of the text box to edit within
///					<del> a delegate object
///					<drawBkGnd> YES to draw a background, NO to have transparent text
/// result:			the temporary text view created to handle the job
///
/// notes:			When an object in the drawing wishes to allow the user to edit some text, it can use this utility
///					to set up the editor. This creates a subview for text editing with the nominated text and the
///					bounds rect given within the drawing. The text is installed, selected and activated. User actions
///					then edit that text. When done, call endTextEditing. To get the text edited, call editedText
///					before ending the mode. You can only set one item at a time to be editable.
///
///********************************************************************************************************************

#define USE_STORAGE_REPLACEMENT		1



- (NSTextView*)			editText:(NSAttributedString*) text inRect:(NSRect) rect delegate:(id) del drawsBackground:(BOOL) drawBkGnd
{
	NSAssert( text != nil, @"text was nil when trying to start a text editing operation");
	NSAssert( rect.size.width > 0, @"editing rect has 0 or -ve width");
	NSAssert( rect.size.height > 0, @"editing rect has 0 or -ve height");

	if ([self isTextBeingEdited])
		[self endTextEditing];
	
	// editor's frame is expanded by five points to ensure all characters are visible when not using screen fonts
	// container text inset is set to compensate for this.

	NSRect editorFrame = NSInsetRect( rect, -5, -5 );
	
	if( m_textEditViewRef == nil )
		m_textEditViewRef = [[[[self class] classForTextEditor] alloc] initWithFrame:editorFrame];
	else
	{
		[m_textEditViewRef setDelegate:nil];
		[m_textEditViewRef setFrame:editorFrame];
		[m_textEditViewRef setSelectedRange:NSMakeRange(0,0)];
	}
	
    [m_textEditViewRef setAllowsUndo:NO];
	
	NSLayoutManager*	lm = [m_textEditViewRef layoutManager];
	
#if USE_STORAGE_REPLACEMENT
	NSTextStorage* textStorage = [[NSTextStorage alloc] initWithAttributedString:text];
	[lm replaceTextStorage:textStorage];
	[textStorage release];
#else
	NSRange textRange = NSMakeRange( 0, [[m_textEditViewRef textStorage] length]);
	
	if([m_textEditViewRef shouldChangeTextInRange:textRange replacementString:[text string]])
	{
		[[m_textEditViewRef textStorage] beginEditing];
		[[m_textEditViewRef textStorage] replaceCharactersInRange:textRange withAttributedString:text];
		[[m_textEditViewRef textStorage] endEditing];
		[m_textEditViewRef didChangeText];
	}
	else
		return nil;
#endif	
	// not using screen fonts ensures precise WYSIWYG at small point sizes
	
	[lm setUsesScreenFonts:NO];
	
	[m_textEditViewRef setDrawsBackground:drawBkGnd];
	[m_textEditViewRef setFieldEditor:YES];
	[m_textEditViewRef setSelectedRange:NSMakeRange( 0, [text length])];
	[m_textEditViewRef setDelegate:del];
	[m_textEditViewRef setNextResponder:self];
	[m_textEditViewRef setTextContainerInset:NSMakeSize( 5, 5 )];
	
	// if smart quotes is supported, set the editor to use the current preference. This feature requires 10.5 or later
	
	if([m_textEditViewRef respondsToSelector:@selector(setAutomaticQuoteSubstitutionEnabled:)])
	{
		BOOL smartQuotes = [[NSUserDefaults standardUserDefaults] boolForKey:kDKTextEditorSmartQuotesPrefsKey];
		[m_textEditViewRef setAutomaticQuoteSubstitutionEnabled:smartQuotes];
	}
	
	// register self as an observer of frame change notification, so that as the view expands and shrinks, it gets refreshed and doesn't leave bits of
	// itself visible
	
	[m_textEditViewRef setPostsFrameChangedNotifications:YES];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(editorFrameChangedNotification:) name:NSViewFrameDidChangeNotification object:m_textEditViewRef];
	mEditorFrame = [m_textEditViewRef frame];
	
	// add the subview and make it first responder
	
	[self addSubview:m_textEditViewRef];
	[[self window] makeFirstResponder:m_textEditViewRef];

	[m_textEditViewRef setNeedsDisplay:YES];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingViewDidBeginTextEditing object:self];
	
	LogEvent_( kReactiveEvent, @"View began text editing, text editor = %@", m_textEditViewRef );
	
	mTextEditViewInUse = YES;
	
	// undo is enabled by the class setting but clients are free to override this
	
    [m_textEditViewRef setAllowsUndo:[[self class]textEditorAllowsTypingUndo]];
	
	return m_textEditViewRef;
}


///*********************************************************************************************************************
///
/// method:			endTextEditing
/// scope:			public instance method
/// overrides:		
/// description:	stop the temporary text editing and get rid of the editing view
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				endTextEditing
{
	if ([self isTextBeingEdited])
	{
		// track smart quotes setting in prefs. Smart Quotes requires 10.5 or later
		
		if([m_textEditViewRef respondsToSelector:@selector(isAutomaticQuoteSubstitutionEnabled)])
			[[NSUserDefaults standardUserDefaults] setBool:[m_textEditViewRef isAutomaticQuoteSubstitutionEnabled] forKey:kDKTextEditorSmartQuotesPrefsKey];
		
		[[NSNotificationCenter defaultCenter] removeObserver:self name:NSViewFrameDidChangeNotification object:m_textEditViewRef];
		
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
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingViewDidEndTextEditing object:self];
		[[self window] makeFirstResponder:self];
	}
}


///*********************************************************************************************************************
///
/// method:			editedText
/// scope:			public instance method
/// overrides:		
/// description:	return the text from the temporary editing view
/// 
/// parameters:		none
/// result:			the text
///
/// notes:			this must be called prior to calling -endTextEditing, because the storage is made empty at that time
///
///********************************************************************************************************************

- (NSTextStorage*)		editedText
{
	return [[m_textEditViewRef layoutManager] textStorage];
}


///*********************************************************************************************************************
///
/// method:			textEditingView
/// scope:			public instance method
/// overrides:		
/// description:	return the current temporary text editing view
/// 
/// parameters:		none
/// result:			the text editing view, or nil
///
/// notes:			
///
///********************************************************************************************************************

- (NSTextView*)			textEditingView
{
	return m_textEditViewRef;
}


///*********************************************************************************************************************
///
/// method:			editorFrameChangedNotification
/// scope:			private instance method
/// overrides:		
/// description:	respond to frame size changes in the text editor view
/// 
/// parameters:		<note> the notification
/// result:			none
///
/// notes:			This tidies up the display when the editor frame changes size. The frame can change
///					during editing depending on how the client has configured it, but to prevent bits from being
///					left behind when the frame is made smaller, this simply invalidates the previous frame rect.
///
///********************************************************************************************************************

- (void)				editorFrameChangedNotification:(NSNotification*) note
{
	[self setNeedsDisplayInRect:mEditorFrame];
	mEditorFrame = [[note object] frame];
}


///*********************************************************************************************************************
///
/// method:			isTextBeingEdited
/// scope:			public instance method
/// overrides:		
/// description:	is the text editor visible and active?
/// 
/// parameters:		none
/// result:			YES if text editing is in progress, NO otherwise
///
/// notes:			clients should not generally start a text editing operation if there is already one in progress,
///					though if they do the old one is immediately ended anyway.
///
///********************************************************************************************************************

- (BOOL)				isTextBeingEdited
{
	return mTextEditViewInUse;
}


#pragma mark -
#pragma mark - ruler stuff

///*********************************************************************************************************************
///
/// method:			updateRulerMouseTracking:
/// scope:			protected instance method
/// overrides:		
/// description:	set the ruler lines to the current mouse point
/// 
/// parameters:		<mouse> the current mouse poin tin local coordinates
/// result:			none
///
/// notes:			n.b. on 10.4 and earlier, there is a bug in NSRulerView that prevents both h and v ruler lines
///					showing up correctly at the same time. No workaround is known. Fixed in 10.5+
///
///********************************************************************************************************************

- (void)				updateRulerMouseTracking:(NSPoint) mouse
{
	// updates the mouse tracking marks on the rulers, if they are visible. Note that the point parameter is the location in the view's window
	// as obtained from an event - not the location in the drawing or view.
	
	static CGFloat ox = -1.0;
	static CGFloat oy = -1.0;
	
	NSScrollView* sv = [self enclosingScrollView];
	
	if( sv != nil )
	{
		NSRulerView*	rh;
		NSRulerView*	rv;
		NSPoint			rp;
			
		if ([sv rulersVisible])
		{
			rv = [sv verticalRulerView];
			rp = [rv convertPoint:mouse fromView:nil];
			
			[rv moveRulerlineFromLocation:oy toLocation:rp.y];
			oy = rp.y;

			rh = [sv horizontalRulerView];
			rp = [rh convertPoint:mouse fromView:nil];
			
			[rh moveRulerlineFromLocation:ox toLocation:rp.x];
			ox = rp.x;
		}
	}
}


///*********************************************************************************************************************
///
/// method:			moveRulerMarkerNamed:toLocation:
/// scope:			public instance method
/// overrides:		
/// description:	set a ruler marker to a given position
/// 
/// parameters:		<markerName> the name of the marker to move
///					<loc> a position value to move the ruler marker to
/// result:			none
///
/// notes:			generally called from the view's controller
///
///********************************************************************************************************************

- (void)				moveRulerMarkerNamed:(NSString*) markerName toLocation:(CGFloat) loc
{
	NSScrollView* sv = [self enclosingScrollView];
	
	if(sv && [sv rulersVisible])
	{
		NSRulerMarker* marker = [[self rulerMarkerInfo] objectForKey:markerName];
		if( loc != [marker markerLocation])
		{
			NSRulerView* rv = [marker ruler];
			[rv setNeedsDisplayInRect:[marker imageRectInRuler]];
			[marker setMarkerLocation:loc];
			[rv setNeedsDisplayInRect:[marker imageRectInRuler]];
		}
	}
}


///*********************************************************************************************************************
///
/// method:			createRulerMarkers
/// scope:			public instance method
/// overrides:		
/// description:	set up the markers for the rulers.
/// 
/// parameters:		none
/// result:			none
///
/// notes:			done as part of the view's initialization - markers are initially created offscreen.
///
///********************************************************************************************************************

- (void)				createRulerMarkers
{
	NSScrollView*	sv = [self enclosingScrollView];
	
	if ( sv != nil )
	{
		[self removeRulerMarkers];
		
		NSRulerView*			rv;
		NSRulerMarker*			rm;
		NSImage*				markerImg;
		NSMutableDictionary*	markerInfo = [NSMutableDictionary dictionary];
		
		rv = [sv horizontalRulerView];

		markerImg = [[self class] imageResourceNamed:kDKDrawingViewHorizontalLeftMarkerName];
		if( markerImg )
		{
			rm = [[NSRulerMarker alloc] initWithRulerView:rv markerLocation:-10000.0 image:markerImg imageOrigin:NSMakePoint(4.0, 0.0)];
			[rv addMarker:rm];
			[markerInfo setObject:rm forKey:kDKDrawingViewHorizontalLeftMarkerName];
			[rm release];
		}
		
		markerImg = [[self class] imageResourceNamed:kDKDrawingViewHorizontalCentreMarkerName];
		if( markerImg )
		{
			rm = [[NSRulerMarker alloc] initWithRulerView:rv markerLocation:-10000.0 image:markerImg imageOrigin:NSMakePoint(4.0, 0.0)];
			[rv addMarker:rm];
			[markerInfo setObject:rm forKey:kDKDrawingViewHorizontalCentreMarkerName];
			[rm release];
		}
		
		markerImg = [[self class] imageResourceNamed:kDKDrawingViewHorizontalRightMarkerName];
		if( markerImg )
		{
			rm = [[NSRulerMarker alloc] initWithRulerView:rv markerLocation:-10000.0 image:markerImg imageOrigin:NSMakePoint(0.0, 0.0)];
			[rv addMarker:rm];
			[markerInfo setObject:rm forKey:kDKDrawingViewHorizontalRightMarkerName];
			[rm release];
		}
		
		rv = [sv verticalRulerView];
		
		markerImg = [[self class] imageResourceNamed:kDKDrawingViewVerticalTopMarkerName];
		if( markerImg )
		{
			rm = [[NSRulerMarker alloc] initWithRulerView:rv markerLocation:-10000.0 image:markerImg imageOrigin:NSMakePoint(8.0, 1.0)];
			[rv addMarker:rm];
			[markerInfo setObject:rm forKey:kDKDrawingViewVerticalTopMarkerName];
			[rm release];
		}
		
		markerImg = [[self class] imageResourceNamed:kDKDrawingViewVerticalCentreMarkerName];
		if( markerImg )
		{
			rm = [[NSRulerMarker alloc] initWithRulerView:rv markerLocation:-10000.0 image:markerImg imageOrigin:NSMakePoint(5.0, 5.0)];
			[rv addMarker:rm];
			[markerInfo setObject:rm forKey:kDKDrawingViewVerticalCentreMarkerName];
			[rm release];
		}
		
		markerImg = [[self class] imageResourceNamed:kDKDrawingViewVerticalBottomMarkerName];
		if( markerImg )
		{
			rm = [[NSRulerMarker alloc] initWithRulerView:rv markerLocation:-10000.0 image:markerImg imageOrigin:NSMakePoint(8.0, 8.0)];
			[rv addMarker:rm];
			[markerInfo setObject:rm forKey:kDKDrawingViewVerticalBottomMarkerName];
			[rm release];
		}
		
		[self setRulerMarkerInfo:markerInfo];
	}
}


///*********************************************************************************************************************
///
/// method:			removeRulerMarkers
/// scope:			public instance method
/// overrides:		
/// description:	remove the markers from the rulers.
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				removeRulerMarkers
{
	NSRulerView*	rv = [[self enclosingScrollView] horizontalRulerView];
	[rv setMarkers:nil];
	
	rv = [[self enclosingScrollView] verticalRulerView];
	[rv setMarkers:nil];
	
	[self setRulerMarkerInfo:nil];
}


///*********************************************************************************************************************
///
/// method:			resetRulerClientView
/// scope:			public instance method
/// overrides:		
/// description:	set up the client view for the rulers.
/// 
/// parameters:		none
/// result:			none
///
/// notes:			done as part of the view's initialization
///
///********************************************************************************************************************

- (void)				resetRulerClientView
{
	NSRulerView* ruler;
	
	ruler = [[self enclosingScrollView] horizontalRulerView];
	
	if( ruler != nil )
	{
		[ruler setClientView:self];
		[ruler setAccessoryView:nil];
	}
	
	ruler = [[self enclosingScrollView] verticalRulerView];
	
	if( ruler != nil )
	{
		[ruler setClientView:self];
	}
	[self createRulerMarkers];
}


///*********************************************************************************************************************
///
/// method:			toggleRuler:
/// scope:			public action method
/// overrides:		
/// description:	show or hide the ruler.
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (IBAction)			toggleRuler:(id) sender
{
	#pragma unused(sender)
	
	BOOL rvis = [[self enclosingScrollView] rulersVisible];
	[[self enclosingScrollView] setRulersVisible:!rvis];
	
	[[NSUserDefaults standardUserDefaults] setBool:!rvis forKey:kDKDrawingRulersVisibleDefaultPrefsKey];
	[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingViewRulersChanged object:self];
}


///*********************************************************************************************************************
///
/// method:			setRulerMarkerInfo:
/// scope:			private instance method
/// overrides:		
/// description:	store the local rule marker info.
/// 
/// parameters:		<dict> a dictionary
/// result:			none
///
/// notes:			private - an internal detail of how markers are handled
///
///********************************************************************************************************************

- (void)				setRulerMarkerInfo:(NSDictionary*) dict
{
	[dict retain];
	[mRulerMarkersDict release];
	mRulerMarkersDict = dict;
}


///*********************************************************************************************************************
///
/// method:			rulerMarkerInfo:
/// scope:			private instance method
/// overrides:		
/// description:	store the local rule marker info.
/// 
/// parameters:		none
/// result:			a dictionary
///
/// notes:			private - an internal detail of how markers are handled
///
///********************************************************************************************************************

- (NSDictionary*)		rulerMarkerInfo
{
	return mRulerMarkersDict;
}



#pragma mark -
#pragma mark - monitoring the mouse location

///*********************************************************************************************************************
///
/// method:			postMouseLocationInfo:event:
/// scope:			private instance method
/// overrides:		
/// description:	broadcast the current mouse position in both native and drawing coordinates.
/// 
/// parameters:		<operation> the name of the notification
///					<event> the event associated with this
/// result:			none
///
/// notes:			A UI that displays the current mouse position could use this notification to keep itself updated.
///
///********************************************************************************************************************

- (void)				postMouseLocationInfo:(NSString*) operation event:(NSEvent*) event
{
	NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity:2];
	NSPoint	p = [self convertPoint:[event locationInWindow] fromView:nil];
	NSPoint cp = [[self drawing] convertPoint:p];
	
	[dict setObject:[NSValue valueWithPoint:p] forKey:kDKDrawingMouseLocationInView];
	[dict setObject:[NSValue valueWithPoint:cp] forKey:kDKDrawingMouseLocationInDrawingUnits];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:operation object:self userInfo:dict];
}


#pragma mark -
#pragma mark window activations

///*********************************************************************************************************************
///
/// method:			windowActiveStateChanged
/// scope:			private notificaiton callback
/// overrides:		
/// description:	invalidate the view when window active state changes.
/// 
/// parameters:		<note> the notification
/// result:			none
///
/// notes:			drawings can change appearance when the active state changes, for example selections are drawn
///					in inactive colour, etc. This makes sure that the drawing is refreshed when the state does change.
///
///********************************************************************************************************************

- (void)				windowActiveStateChanged:(NSNotification*) note
{
	#pragma unused(note)
	
	if([[self window] isMainWindow])
		[[self enclosingScrollView] setBackgroundColor:[[self class] backgroundColour]];
	else
		[[self enclosingScrollView] setBackgroundColor:[NSColor veryLightGrey]];
	
	[self setNeedsDisplay:YES];
}


#pragma mark -

- (void)				set
{
	// sets this view as the currently drawing view, pushing the current one onto the stack. A +pop will put the original one back. This allows nested drawRect: calls to work
	// across several views, which may occur in unusual circumstances, such as caching PDF data using a PDF view.
	
	[[self class] pushCurrentViewAndSet:self];
}


#pragma mark -
#pragma mark As an NSView

///*********************************************************************************************************************
///
/// method:			drawRect:
/// scope:			public instance method
/// overrides:		NSView
/// description:	draw the content of the drawing.
/// 
/// parameters:		<rect> the rect to update
/// result:			none
///
/// notes:			draws the entire drawing content, then any controller-based content, then finally the pagebreaks.
///					If at this point there is no drawing, one is automatically created so that you can get a working
///					DK system simply by dropping a DKDrawingView into a window in a nib, and away you go.
///
///********************************************************************************************************************

- (void)				drawRect:(NSRect) rect
{
	// draw the entire content of the drawing:
	
	[self set];
	[[self drawing] drawRect:rect inView:self];
	
	// if our controller implements a drawRect: method, call it - the default controller doesn't but subclasses can.
	// any drawing done by a controller will be "on top" of any drawing content. Typically this is used by tools
	// that draw something, such as a selection rect, etc.
	
	if([[self controller] respondsToSelector:@selector(drawRect:)])
		[(id)[self controller] drawRect:rect];
	
	// draw page breaks on top of everything else if enabled
	
	BOOL printing = ![NSGraphicsContext currentContextDrawingToScreen];
	
	if( !printing && [self pageBreaksVisible] && [self printInfo])
		[self drawPageBreaks];
	
	if( printing && [self printCropMarkKind] != DKCropMarksNone )
		[self drawCropMarks];
	
	[[self class] pop];
}


///*********************************************************************************************************************
///
/// method:			isFlipped
/// scope:			public instance method
/// overrides:		NSView
/// description:	is the view flipped.
/// 
/// parameters:		none
/// result:			returns the flipped state of the drawing itself (which actually only affects the views, but
///					the drawing holds this state because all views should be consistent)
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				isFlipped
{
	if([self drawing] != nil )
		return [[self drawing] isFlipped];
	else
		return YES;
}


///*********************************************************************************************************************
///
/// method:			isOpaque
/// scope:			public instance method
/// overrides:		NSView
/// description:	is the view opaque, yes.
/// 
/// parameters:		none
/// result:			always YES
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				isOpaque
{
	return YES;
}


///*********************************************************************************************************************
///
/// method:			resetCursorRects
/// scope:			public instance method
/// overrides:		NSView
/// description:	invalidate the cursor rects and set up new ones
/// 
/// parameters:		none
/// result:			none
///
/// notes:			the controller will supply a cursor and an active rect to apply it in
///
///********************************************************************************************************************

- (void)				resetCursorRects
{
	NSCursor*	curs = [[self controller] cursor];
	NSRect		cr = [[self controller] activeCursorRect];
	
	cr = NSIntersectionRect( cr, [self visibleRect]);
	
	[self addCursorRect:cr cursor:curs];
	[curs setOnMouseEntered:YES];
}



///*********************************************************************************************************************
///
/// method:			menuForEvent:
/// scope:			public instance method
/// overrides:		
/// description:	create a menu that is used for a right-click in the view
/// 
/// parameters:		<event> the event
/// result:			a menu, or nil
///
/// notes:			initially defers to the controller, then to super
///
///********************************************************************************************************************

- (NSMenu *)			menuForEvent:(NSEvent*) event
{
	[self set];
	NSMenu* menu = [[self controller] menuForEvent:event];
	[[self class] pop];
	
	if ( menu == nil )
		menu = [super menuForEvent:event];
	
	// if the menu was created, record the local mouse down point so that client code can get this point
	// if needed when responding to a menu command in the menu.
	
	if( menu != nil )
		sLastContextMenuClick = [self convertPoint:[event locationInWindow] fromView:nil];
		
	return menu;
}


///*********************************************************************************************************************
///
/// method:			acceptsFirstMouse:
/// scope:			public instance method
/// overrides:		NSView
/// description:	accept whether the activating click is also handled as a mouse down
/// 
/// parameters:		<event> the event
/// result:			YES
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				acceptsFirstMouse:(NSEvent*) event
{
#pragma unused(event)
	
	return YES;
}


///*********************************************************************************************************************
///
/// method:			preservesContentDuringLiveResize
/// scope:			public instance method
/// overrides:		NSView
/// description:	tell drawing system that we preserve the content for live resize
/// 
/// parameters:		none
/// result:			YES
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				preservesContentDuringLiveResize
{
	return YES;
}


///*********************************************************************************************************************
///
/// method:			setFrameSize:
/// scope:			public instance method
/// overrides:		NSView
/// description:	invalidate areas not preserved during live resize
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				setFrameSize:(NSSize) newSize
{
	[super setFrameSize:newSize];
	
	if([self inLiveResize])
	{
		NSRect	rects[4];
        int		count;
		
        [self getRectsExposedDuringLiveResize:rects count:&count];
        
		while (count-- > 0)
			[self setNeedsDisplayInRect:rects[count]];
	}
	else
		[self setNeedsDisplay:YES];
}


- (BOOL)				lockFocusIfCanDraw
{
	// if at the point where the view is asked to draw something, there is no "back end", it creates one
	// automatically on the basis of its current bounds. In this case, the view owns the drawing. This is done here rather than in -drawRect:
	// though ideally it would go in -viewWillDraw, however that is >= 10.5 only.
	
	if ([self drawing] == nil )
		[self createAutomaticDrawing];
	
	return [super lockFocusIfCanDraw];
}


#pragma mark -
#pragma mark As an NSResponder

///*********************************************************************************************************************
///
/// method:			acceptsFirstResponder
/// scope:			public instance method
/// overrides:		
/// description:	can the view be 1st R?
/// 
/// parameters:		none
/// result:			always YES
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				acceptsFirstResponder
{
	return YES;
}


///*********************************************************************************************************************
///
/// method:			keyDown:
/// scope:			public instance method
/// overrides:		
/// description:	handle the key down event
/// 
/// parameters:		<event> the event
/// result:			none
///
/// notes:			key down events are preprocessed in the usual way and end up getting forwarded down through
///					the controller and active layer because of invocation forwarding. Thus you can respond to
///					normal NSResponder methods at any level that makes sense within DK. The controller is however
///					given first shot at the raw event, in case it does something special (like DKToolController does
///					for selecting a tool using a keyboard shortcut).
///
///********************************************************************************************************************

- (void)				keyDown:(NSEvent*) event
{
	if([[self controller] respondsToSelector:@selector(keyDown:)])
		[(NSResponder*)[self controller] keyDown:event];
	else
		[self interpretKeyEvents:[NSArray arrayWithObject:event]];
}


///*********************************************************************************************************************
///
/// method:			mouseDown:
/// scope:			public instance method
/// overrides:		
/// description:	handle the mouse down event
/// 
/// parameters:		<event> the event
/// result:			none
///
/// notes:			the view defers to its controller after broadcasting the mouse position info
///
///********************************************************************************************************************

- (void)				mouseDown:(NSEvent*) event
{
	[self postMouseLocationInfo:kDKDrawingMouseDownLocation event:event];
	[self set];
	[[self controller] mouseDown:event];
}


///*********************************************************************************************************************
///
/// method:			mouseDragged:
/// scope:			public instance method
/// overrides:		
/// description:	handle the mouse dragged event
/// 
/// parameters:		<event> the event
/// result:			none
///
/// notes:			the view defers to its controller after broadcasting the mouse position info
///
///********************************************************************************************************************

- (void)				mouseDragged:(NSEvent*) event
{
	// do not process drags at more than 40 fps...
	
	NSTimeInterval t = [event timestamp];
	
	if( t > mLastMouseDragTime + 0.025 )
	{
		mLastMouseDragTime = t;
	
		[self updateRulerMouseTracking:[event locationInWindow]];
		[self postMouseLocationInfo:kDKDrawingMouseDraggedLocation event:event];
		[[self controller] mouseDragged:event];
	}
}


///*********************************************************************************************************************
///
/// method:			mouseMoved:
/// scope:			public instance method
/// overrides:		
/// description:	handle the mouse moved event
/// 
/// parameters:		<event> the event
/// result:			none
///
/// notes:			the view defers to its controller after updating the ruler lines and broadcasting the mouse position info
///
///********************************************************************************************************************

- (void)				mouseMoved:(NSEvent*) event
{
	// update the ruler mouse tracking lines if the rulers are visible.

	[self updateRulerMouseTracking:[event locationInWindow]];
	[self postMouseLocationInfo:kDKDrawingMouseMovedLocation event:event];
	[[self controller] mouseMoved:event];
}


///*********************************************************************************************************************
///
/// method:			mouseUp:
/// scope:			public instance method
/// overrides:		
/// description:	handle the mouse up event
/// 
/// parameters:		<event> the event
/// result:			none
///
/// notes:			the view defers to its controller after broadcasting the mouse position info
///
///********************************************************************************************************************

- (void)				mouseUp:(NSEvent*) event
{
	[self postMouseLocationInfo:kDKDrawingMouseUpLocation event:event];
	[[self controller] mouseUp:event];
	[[self class] pop];
}


///*********************************************************************************************************************
///
/// method:			flagsChanged:
/// scope:			public instance method
/// overrides:		NSResponder
/// description:	handle the flags changed event
/// 
/// parameters:		<event> the event
/// result:			none
///
/// notes:			the view simply defers to its controller
///
///********************************************************************************************************************

- (void)				flagsChanged:(NSEvent*) event
{
	[[self controller] flagsChanged:event];
}


///*********************************************************************************************************************
///
/// method:			doCommandBySelector:
/// scope:			public instance method
/// overrides:		NSResponder
/// description:	do the command requested
/// 
/// parameters:		<aSelector> the selector for a command
/// result:			none
///
/// notes:			this overrides the default implementation to send itself as the <sender> parameter. Because in
///					fact the selector is actually forwarded down to some other objects deep inside DK, this is a very
///					easy way for them to get passed the view from whence the event came. NSResponder methods such
///					as moveLeft: are called by this.
///
///********************************************************************************************************************

- (void)				doCommandBySelector:(SEL) aSelector
{
	if([self respondsToSelector:aSelector])
		[self tryToPerform:aSelector with:self];
	else
		[super doCommandBySelector:aSelector];
}


///*********************************************************************************************************************
///
/// method:			insertText:
/// scope:			public instance method
/// overrides:		NSResponder
/// description:	insert text
/// 
/// parameters:		<aString> the text to insert
/// result:			none
///
/// notes:			this overrides the default implementation to forward insertText: to the active layer and beyond.
///
///********************************************************************************************************************

- (void)				insertText:(id) aString
{
	if([[self controller] respondsToSelector:_cmd])
		[(id)[self controller] insertText:aString];
}


#pragma mark -

- (void)				changeAttributes:(id) sender
{
	// workaround 10.5 and earlier bug where target isn't applied to -changeAttributes: and ends up in the responder chain
	// instead. This catches it and sends it to the true target before our forwarding mechanism gets to work on it.
	
	if( sender == [NSFontManager sharedFontManager])
	{
		id target = [sender target];
		
		if( target && [target respondsToSelector:_cmd])
		{
			//NSLog(@"redirecting -changeAttributes: to %@", target );
			
			[target changeAttributes:sender];
			return;
		}
	}
	
	[(id)super changeAttributes:sender];
}



#pragma mark -
#pragma mark As an NSObject

///*********************************************************************************************************************
///
/// method:			dealloc
/// scope:			public instance method
/// overrides:		NSObject
/// description:	deallocate the view
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				dealloc
{
	// going away - make sure our controller is removed from the drawing
	
	if([self controller] != nil)
	{
		[[self controller] setView:nil];
		[[self drawing] removeController:[self controller]];
		[self setController:nil];
	}
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[mPrintInfo release];
	[mRulerMarkersDict release];
	[m_textEditViewRef release];
	
	// if the view automatically created its own "back-end", release all of that now - the drawing owns the controllers so
	// they are also disposed of.

	if ( m_didCreateDrawing && mAutoDrawing != nil )
		[mAutoDrawing release];

	[super dealloc];
}


///*********************************************************************************************************************
///
/// method:			forwardInvocation
/// scope:			public instance method
/// overrides:		NSObject
/// description:	forward an invocation to the active layer if it implements it
/// 
/// parameters:		<invocation> the invocation to forward
/// result:			none
///
/// notes:			DK makes a lot of use of invocation forwarding - views forward to their controllers, which forward
///					to the active layer, which may forward to selected objects within the layer. This allows objects
///					to respond to action methods and so forth at their own level.
///
///********************************************************************************************************************

- (void)				forwardInvocation:(NSInvocation*) invocation
{
    // commands can be implemented by the layer that wants to make use of them - this makes it happen by forwarding unrecognised
	// method calls to the active layer if possible.
	
	SEL aSelector = [invocation selector];

    if ([[self controller] respondsToSelector:aSelector])
	{
        [invocation invokeWithTarget:[self controller]];
	}
    else
        [self doesNotRecognizeSelector:aSelector];
}


///*********************************************************************************************************************
///
/// method:			methodSignatureForSelector:
/// scope:			public instance method
/// overrides:		NSObject
/// description:	return a method's signature
/// 
/// parameters:		<aSelector> the selector
/// result:			the signature for the method
///
/// notes:			DK makes a lot of use of invocaiton forwarding - views forward to their controllers, which forward
///					to the active layer, which may forward to selected objects within the layer. This allows objects
///					to respond to action methods and so forth at their own level.
///
///********************************************************************************************************************

- (NSMethodSignature *)	methodSignatureForSelector:(SEL) aSelector
{
	NSMethodSignature* sig;
	
	sig = [super methodSignatureForSelector:aSelector];
	
	if ( sig == nil )
		sig = [[self controller] methodSignatureForSelector:aSelector];

	return sig;
}


///*********************************************************************************************************************
///
/// method:			respondsToSelector:
/// scope:			public instance method
/// overrides:		NSObject
/// description:	return whether the selector can be responded to
/// 
/// parameters:		<aSelector> the selector
/// result:			YES or NO
///
/// notes:			DK makes a lot of use of invocaiton forwarding - views forward to their controllers, which forward
///					to the active layer, which may forward to selected objects within the layer. This allows objects
///					to respond to action methods and so forth at their own level.
///
///********************************************************************************************************************

- (BOOL)				respondsToSelector:(SEL) aSelector
{
	BOOL responds = [super respondsToSelector:aSelector];
	
	if( !responds )
		responds = [[self controller] respondsToSelector:aSelector];
		
	return responds;
}


#pragma mark -
#pragma mark As part of NSMenuValidation Protocol

///*********************************************************************************************************************
///
/// method:			validateMenuItem:
/// scope:			public instance method
/// overrides:		NSObject
/// description:	enable and set menu item state for actions implemented by the controller
/// 
/// parameters:		<item> the menu item to validate
/// result:			YES or NO
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)					validateMenuItem:(NSMenuItem*) item
{
	SEL		action = [item action];
	
	if ( action == @selector(toggleRuler:))
	{
		BOOL rvis = [[self enclosingScrollView] rulersVisible];
		[item setTitle:NSLocalizedString( rvis? @"Hide Rulers" : @"Show Rulers", @"" )];
		return YES;
	}
	
	if ( action == @selector(toggleShowPageBreaks:))
	{
		[item setTitle:NSLocalizedString([self pageBreaksVisible]? @"Hide Page Breaks" : @"Show Page Breaks", @"page break menu items")];
		return YES;
	}
	
	BOOL e1 = [super validateMenuItem:item];
	BOOL e2 = [[self controller] validateMenuItem:item];
	
	return e1 || e2;
}


#pragma mark -
#pragma mark As part of NSNibAwaking Protocol

///*********************************************************************************************************************
///
/// method:			awakeFromNib
/// scope:			public instance method
/// overrides:		NSNibAwaking
/// description:	set up the rulers and other defaults when the view is first created
/// 
/// parameters:		none
/// result:			none
///
/// notes:			Typically you should create your views from a NIB, it's just much easier that way. If you decide to
///					do it the hard way you'll have to do this set up yourself.
///
///********************************************************************************************************************

- (void)				awakeFromNib
{
	NSScrollView*		sv = [self enclosingScrollView];
	
	if ( sv )
	{
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
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowActiveStateChanged:) name:NSWindowDidResignMainNotification object:[self window]];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowActiveStateChanged:) name:NSWindowDidBecomeMainNotification object:[self window]];

}


@end
