///**********************************************************************************************************************************
///  DKDrawDocument.m
///  DrawKit
///
///  Created by graham on 15/10/2006.
///  Released under the Creative Commons license 2006 Apptree.net.
///
/// 
///  This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 License.
///  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to
///  Creative Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105, USA.
///
///**********************************************************************************************************************************

#import "DKDrawingDocument.h"
#import "DKUndoManager.h"
#import "DKDrawing.h"
#import "DKDrawing+Paper.h"
#import "DKViewController.h"
#import "DKGridLayer.h"
#import "DKGuideLayer.h"
#import "DKObjectDrawingLayer.h"
#import "DKPrintDrawingView.h"
#import "DKStyleRegistry.h"
#import "DKDrawingInfoLayer.h"
#import "LogEvent.h"

#pragma mark Contants (Non-localized)

NSString*		kGCDrawingDocumentType = @"Drawing";
NSString*		kDKDrawingDocumentUTI = @"net.apptree.drawing";


#define	qGlobalUndoManager		0

#pragma mark -
@implementation DKDrawingDocument
#pragma mark As a DKDrawDocument


///*********************************************************************************************************************
///
/// method:			sharedDrawkitUndoManager
/// scope:			public class method
/// overrides:		
/// description:	returns an undo manager that can be shared by multiple documents
/// 
/// parameters:		none
/// result:			the shared instance of the undo manager
///
/// notes:			some applications might be set up to use a global undo stack instead of havin gone per document.
///
///********************************************************************************************************************

+ (NSUndoManager*)		sharedDrawkitUndoManager
{
	static DKUndoManager* s_um = nil;
	
	if ( s_um == nil )
		s_um = [[DKUndoManager alloc] init];
		
	return s_um;
}



///*********************************************************************************************************************
///
/// method:			setDrawing:
/// scope:			public instance method
/// overrides:		
/// description:	set the document's drawing object
/// 
/// parameters:		<drwg> a drawing object
/// result:			none
///
/// notes:			the document owns the drawing
///
///********************************************************************************************************************

- (void)				setDrawing:(DKDrawing*) drwg
{
	// sets the drawing to <drwg>.
	
	[drwg retain];
	[m_drawing release];	// also removes and releases all existing controllers
	m_drawing = drwg;
	
	// create a controller for the main view and add it to the drawing - often at this stage mainView is nil, so
	// this step is for when the drawing is recreated sometime after initialisation - e.g. on revert. For the usual
	// case of instantiation from a nib, the -windowControllerDidLoadNib method performs this step.
	
	if ( m_mainView != nil )
	{
		DKViewController*  mainViewController = [self makeControllerForView:[self mainView]];
		[m_drawing addController:mainViewController];
	}

#if qGlobalUndoManager	
	[self setUndoManager:[[self class] sharedDrawkitUndoManager]];
#endif
	
	[m_drawing setUndoManager:[self undoManager]];
	[[self undoManager] setLevelsOfUndo:24];
	
	LogEvent_(kReactiveEvent, @"undo mgr = %@", [self undoManager]);
}


///*********************************************************************************************************************
///
/// method:			drawing
/// scope:			public instance method
/// overrides:		
/// description:	return the document's drawing object
/// 
/// parameters:		none
/// result:			the document's drawing object
///
/// notes:			the document owns the drawing
///
///********************************************************************************************************************

- (DKDrawing*)			drawing
{
	return m_drawing;
}


#pragma mark -

///*********************************************************************************************************************
///
/// method:			mainView
/// scope:			public instance method
/// overrides:		
/// description:	return the document's main view
/// 
/// parameters:		none
/// result:			the document's main view
///
/// notes:			if the document has a main view, this returns it. Normally this is set up in the nib. A document
///					isn't required to have an outlet to the main view but it makes setting everything up easier.
///
///********************************************************************************************************************

- (DKDrawingView*)		mainView
{
	return m_mainView;
}


///*********************************************************************************************************************
///
/// method:			makeControllerForView:
/// scope:			public instance method
/// overrides:		
/// description:	create a controller object to connect the given view to the document's drawing
/// 
/// parameters:		<aView> the view the controller will be used with
/// result:			a new controller object
///
/// notes:			usually you won't call this yourself but you can override it to supply different types of controllers.
//					The default supplies a general purpose drawing tool controller. Note that the relationship
///					between the view and the controller is set up by this, but NOT the relationship between the drawing
///					and the controller - the controller must be added to the drawing using -addController.
///					(Other parts of this class handle that).
///
///********************************************************************************************************************

- (DKViewController*)	makeControllerForView:(NSView*) aView
{
	if ([aView isKindOfClass:[DKDrawingView class]])
		return [(DKDrawingView*)aView makeViewController];
	else
	{
		DKViewController* aController = [[DKViewController alloc] initWithView:aView];
		return [aController autorelease];
	}
}


#define ADD_INFO_LAYER 1


///*********************************************************************************************************************
///
/// method:			makeDefaultDrawing
/// scope:			public instance method
/// overrides:		
/// description:	create a drawing object to be used when the document is not opened from a file on disk
/// 
/// parameters:		none
/// result:			a default drawing object
///
/// notes:			you can override to make a different initial drawing or modify the existing one
///
///********************************************************************************************************************

- (DKDrawing*)			makeDefaultDrawing
{
	// set up a default drawing - this is A2 in size, landscape orientation, has grid, guids and one drawing layer, which is made active
		
	DKDrawing* dr = [[DKDrawing alloc] initWithSize:[DKDrawing isoA2PaperSize:NO]];
	
	// attach a grid layer
	[DKGridLayer setGridThemeColour:[[NSColor brownColor] colorWithAlphaComponent:0.5]];
	DKGridLayer* grid = [[DKGridLayer alloc] init];
	[dr addLayer:grid];
	[grid tweakDrawingMargins];
	[grid release];
	
	// attach a drawing layer and make it the active layer

	DKObjectDrawingLayer*	layer = [[DKObjectDrawingLayer alloc] init];
	[dr addLayer:layer];
	[dr setActiveLayer:layer];
	[layer release];
	
	// info layer
#ifdef ADD_INFO_LAYER
	DKDrawingInfoLayer*	infoLayer = [[DKDrawingInfoLayer alloc] init];
	[dr addLayer:infoLayer];
	[infoLayer setVisible:NO];
	[infoLayer release];
#endif
	// attach a guide layer

	DKGuideLayer*	guides = [[DKGuideLayer alloc] init];
	[dr addLayer:guides];
	[guides release];

	return [dr autorelease];
}


#pragma mark -
#pragma mark handy user actions
///*********************************************************************************************************************
///
/// method:			newDrawingLayer:
/// scope:			public action method
/// overrides:		
/// description:	high-level method to add a new drawing layer to the document
/// 
/// parameters:		<sender> the sender of the message
/// result:			none
///
/// notes:			the added layer is made the active layer
///
///********************************************************************************************************************

- (IBAction)			newDrawingLayer:(id) sender
{
	#pragma unused (sender)

	// high level action to add a new drawing layer to the drawing and make it active
	
	DKDrawing* dr = [self drawing];
	DKObjectDrawingLayer*	layer = [[DKObjectDrawingLayer alloc] init];
	
	[dr addLayer:layer andActivateIt:YES];
	[layer release];
	
	[[self undoManager] setActionName:NSLocalizedString(@"New Layer", @"undo string for new layer")];
}


///*********************************************************************************************************************
///
/// method:			newLayerWithSelection:
/// scope:			public action method
/// overrides:		
/// description:	high-level method to add a new drawing layer to the document and move the selected objects to it
/// 
/// parameters:		<sender> the sender of the message
/// result:			none
///
/// notes:			the added layer is made the active layer, the objects are added to the new layer and selected, and
///					removed from their current layer.
///
///********************************************************************************************************************

- (IBAction)			newLayerWithSelection:(id) sender
{
	#pragma unused (sender)
	
	// high-level action adds a new drawing layer and moves the currently selected objects to it
	// if the selection is empty or the current active layer is not an object layer, does nothing
	
	DKObjectDrawingLayer* cLayer = [[self drawing] activeLayerOfClass:[DKObjectDrawingLayer class]];
	
	if ( cLayer != nil )
	{
		NSArray* selection = [cLayer selectedObjectsPreservingStackingOrder];
		
		if ([selection count] > 0 )
		{
			// ok, something to do...
			
			DKDrawing* dr = [self drawing];
			DKObjectDrawingLayer*	layer = [[DKObjectDrawingLayer alloc] init];
	
			[dr addLayer:layer andActivateIt:YES];
			[layer release];
			
			// move objects to it and select them
			
			[layer addObjects:selection];
			[layer addObjectsToSelectionFromArray:selection];
			[cLayer removeObjects:selection];
			[cLayer deselectAll];
		
			[[self undoManager] setActionName:NSLocalizedString(@"New Layer With Selection", @"undo string for new layer")];
			
			return;
		}
	}
	
	NSBeep();
}


///*********************************************************************************************************************
///
/// method:			deleteActiveLayer:
/// scope:			public action method
/// overrides:		
/// description:	high-level method to delete the active layer from the drawing
/// 
/// parameters:		<sender> the sender of the message
/// result:			none
///
/// notes:			After this the active layer will be nil, and should be set to something before further use.
///
///********************************************************************************************************************

- (IBAction)			deleteActiveLayer:(id) sender
{
	#pragma unused (sender)

	[[self drawing] removeLayer:[[self drawing] activeLayer]];
	[[self undoManager] setActionName:NSLocalizedString(@"Delete Layer", @"undo string for delete layer")];
}


#pragma mark -
#pragma mark style remerging

///*********************************************************************************************************************
///
/// method:			remergeStyles:readFromURL:
/// scope:			public instance method
/// overrides:		
/// description:	the first step in reconsolidating a newly opened document's registered styles with the current
///					style registry.
/// 
/// parameters:		<stylesToMerge> a set of styles loaded with the document that are flagged as having been registered
///					at the time the document was saved. Note that this method isn't called if there are no such styles.
///					<url> the url from whence the document was loaded (ignored by default)
/// result:			none
///
/// notes:			You should override this to handle style remerging in a different way if you need to. The default
///					implementation allows the current registry to update the document and also adds the document's
///					name as a category to the current registry.
///
///********************************************************************************************************************

- (void)				remergeStyles:(NSSet*) stylesToMerge readFromURL:(NSURL*) url
{
	#pragma unused(url)
	
	NSAssert( stylesToMerge != nil, @"attempt to remerge a nil set");
	
	LogEvent_(kInfoEvent, @"remerge of %d styles after loading...", [stylesToMerge count]);
	
	// the styles in the given set are those that were originally registered when this document was last saved. At this point in time
	// the styles exist as new copies of the registered styles, so they need to be reconciled with the current state of the registry, which
	// may have changed dramatically since the file was saved. Several possibilities exist at this point for styles that exist both here and
	// in the current registry:
	
	// 1. these styles might replace those in the registry - this is safest for THIS document, but might adversely affect others open right now.
	// 2. the registry styles might replace these styles. This could change the appearance of objects in this document but they will be up
	// to date to the latest registry styles, and no other open documents will be affected.
	// 3. these styles can be copied and stored as additional copies of the style in the registry, possibly given new names to disambiguate them.
	// This is safest for all from the point of view of changing appearance, but can cause the registry to grow very large with many duplicate
	// styles.
	
	// note that if any previously registered doc style is not currently registered, it is registered "as is" regardless of the settings you pass.
	
	// applications will want to override this and do what they think is the right thing, including possibly asking the user.
	
	// this default method takes option 2 as it's the simplest. It also creates a category using the document's name which will list
	// all of these styles.
	
	// perform a preflight at this point if you wish - info returned can be used to help th euser make an informed choice, etc.
	// By default this info isn't used, just logged
	
	NSDictionary* preflightInfo = [DKStyleRegistry compareStylesInSet:stylesToMerge];
	
	LogEvent_(kInfoEvent, @"preflight info = %@", preflightInfo);
	
	NSArray*	docNameCat = [NSArray arrayWithObject:[self documentStyleCategoryName]];
	NSSet*		changedStyles = [DKStyleRegistry mergeStyles:stylesToMerge inCategories:docNameCat options:kDKReturnExistingStyles mergeDelegate:self];
	
	// the returned set contains the objects from the registry that match those in the document. The document must now adopt these objects in
	// place of the temporary ones that it created on being unarchived. If the set is empty or nil, we're done.
	
	if ( changedStyles != nil && [changedStyles count] > 0 )
		[self replaceDocumentStylesWithMatchingStylesFromSet:changedStyles];
}


///*********************************************************************************************************************
///
/// method:			replaceDocumentStylesWithMatchingStylesFromSet:
/// scope:			public instance method
/// overrides:		
/// description:	the second step in reconsolidating a newly opened document's registered styles with the current
///					style registry.
/// 
/// parameters:		<aSetOfStyles> the styles returned from the registry that should replace those in the document
/// result:			none
///
/// notes:			This should only be called if the registry actually returned anything from the remerge operation
///
///********************************************************************************************************************

- (void)				replaceDocumentStylesWithMatchingStylesFromSet:(NSSet*) aSetOfStyles
{
	// this method is an imperative - when called, styles in the passed set that have a matching key with those in this document MUST
	// replace the doc's styles. This requires iterating over the drawing's entire contents and replacing such styles. This relinks the
	// doc's styles with the registry's styles.
	
	NSAssert( aSetOfStyles != nil, @"can't replace styles from a nil set");
	LogEvent_(kStateEvent, @"document will replace %d styles", [aSetOfStyles count] );
	
	[[self drawing] replaceMatchingStylesFromSet:aSetOfStyles];
	
	// n.b. all undos arising from this operation are discarded - there's no good reason to undo stuff that is really part
	// of the initialisation

	[[self undoManager] removeAllActions];
	
	/// should the document be dirtied anyway? NO for now.
	
	//[self updateChangeCount:NSChangeDone];
}


///*********************************************************************************************************************
///
/// method:			documentStyleCategoryName
/// scope:			public instance method
/// overrides:		
/// description:	returns a name that can be used for a style registry category for this document
/// 
/// parameters:		none
/// result:			a string - just the document's filename without the extension or other path components
///
/// notes:			
///
///********************************************************************************************************************

- (NSString*)			documentStyleCategoryName
{
	// return the name of the category that this document creates in the style registry - by default it's just the name part of the URL.
	
	return [[[[self fileURL] path] lastPathComponent] stringByDeletingPathExtension];
}


///*********************************************************************************************************************
///
/// method:			allStyles
/// scope:			public instance method
/// overrides:		
/// description:	returns all styles used by the document's drawing
/// 
/// parameters:		none
/// result:			a set of all styles in the drawing
///
/// notes:			
///
///********************************************************************************************************************

- (NSSet*)				allStyles
{
	return [[self drawing] allStyles];
}


///*********************************************************************************************************************
///
/// method:			allRegisteredStyles
/// scope:			public instance method
/// overrides:		
/// description:	returns all registered styles used by the document's drawing
/// 
/// parameters:		none
/// result:			a set of all registered styles in the drawing
///
/// notes:			this method actually returns all styles flagged as formerly registered immediately after the
///					document has been opened - all subsequent calls return the actual registered styles. Thus take
///					care that this is only called once after loading a document if it's the flagged styles you require.
///
///********************************************************************************************************************

- (NSSet*)				allRegisteredStyles
{
	return [[self drawing] allRegisteredStyles];
}



#pragma mark -
#pragma mark As an NSDocument

///*********************************************************************************************************************
///
/// method:			dataOfType:error:
/// scope:			public instance method
/// overrides:		NSDocument
/// description:	return the data to save when this document is written to disk.
/// 
/// parameters:		<typename> the type of data to write (ignored)
///					<outError> an error, if it wasn't successful
/// result:			the data to be written to disk
///
/// notes:			
///
///********************************************************************************************************************

- (NSData *)			dataOfType:(NSString*) typeName error:(NSError**) outError
{
	#pragma unused (typeName)
	#pragma unused (outError)

	 return [[self drawing] drawingData];
}


///*********************************************************************************************************************
///
/// method:			initWithType:error:
/// scope:			public instance method
/// overrides:		NSDocument
/// description:	set up the document in its initial state for the "New" command.
/// 
/// parameters:		<typename> the type of data that the document is created to handle
///					<outError> an error, if it wasn't successful
/// result:			the document object
///
/// notes:			creates a default drawing object
///
///********************************************************************************************************************

- (id)					initWithType:(NSString*) typeName error:(NSError**) outError
{
	LogEvent_(kLifeEvent, @"initialising default drawing, type = '%@'", typeName );

	[super initWithType:typeName error:outError];
	
	// note - <typeName> will be different when linking against the 10.5 SDK. On 10.4, this is "Drawing", on 10.5 this is the UTI,
	// "net.apptree.drawing". For now, we just accept either type here.

	if([typeName isEqualToString:kGCDrawingDocumentType] || [typeName isEqualToString:kDKDrawingDocumentUTI])
	{
		DKDrawing* dr = [self makeDefaultDrawing];
		[self setDrawing:dr];
	}
	return self;
}


///*********************************************************************************************************************
///
/// method:			printShowingPrintPanel:
/// scope:			public instance method
/// overrides:		NSDocument
/// description:	implements the print command.
/// 
/// parameters:		<flag> YES to show the print panel
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				printShowingPrintPanel:(BOOL) flag
{
	NSRect					fr = NSZeroRect;
	fr.size = [[self drawing] drawingSize];
	
	DKPrintDrawingView*		pdv = [[DKPrintDrawingView alloc] initWithFrame:fr];
	DKViewController*		vc = [pdv makeViewController];
	
	[[self drawing] addController:vc];
	[pdv setPrintInfo:[self printInfo]];
	
	NSPrintOperation* printOp = [NSPrintOperation printOperationWithView:pdv printInfo:[self printInfo]];
	
	[printOp setShowPanels:flag];
	[self runModalPrintOperation:printOp delegate:nil didRunSelector:nil contextInfo:nil];
}


///*********************************************************************************************************************
///
/// method:			readFromURL:ofType:error:
/// scope:			public instance method
/// overrides:		NSDocument
/// description:	initialises the document from a file on disk when opened from the "Open" command.
/// 
/// parameters:		<absoluteURL> the url being read
///					<typename> the type of data to load
///					<error> the error if not successful
/// result:			YES if the file was opened, NO otherwise
///
/// notes:			instantiates the drawing from the file data at the given URL.
///
///********************************************************************************************************************

//- (BOOL)				readFromURL:(NSURL*) absoluteURL ofType:(NSString*) typeName error:(NSError**) outError

- (BOOL)				readFromData:(NSData*) data ofType:(NSString*) typeName error:(NSError **)outError
{
	#pragma unused (outError)
	
	if([typeName isEqualToString:kGCDrawingDocumentType] || [typeName isEqualToString:kDKDrawingDocumentUTI])
	{
		//LogEvent_(kFileEvent, @"loading drawing from URL: %@", absoluteURL );
		
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		//NSData* data = [NSData dataWithContentsOfURL: absoluteURL];
		
		DKDrawing* dwg = [DKDrawing drawingWithData:data]; //[DKDrawing drawingWithData:data fromFileAtPath:[absoluteURL path]];
		[self setDrawing:dwg];
		
		NSAssert([self drawing] != nil, @"drawing was nil after trying to initialise it from file data");
		
		// having loaded the drawing and fully dearchived it, we need to remerge styles in the document with the style registry.
		// what happens here will depend on the application design and possibly the user's personal choice. So this is factored out to
		// allow an easy override. The default method blindly remerges the styles from the document back into the registry.
		
		NSSet* stylesToMerge = [[self drawing] allRegisteredStyles];	// after a file load, this method returns a special set THIS ONCE ONLY
		
		if ( stylesToMerge != nil && [stylesToMerge count] > 0 )
			[self remergeStyles:stylesToMerge readFromURL:nil];
		
		[pool release];

		return YES;
	}
	else
		return NO;
}


///*********************************************************************************************************************
///
/// method:			setPrintInfo:
/// scope:			public instance method
/// overrides:		NSDocument
/// description:	sets the printing info
/// 
/// parameters:		<printInfo> the printing info
/// result:			none
///
/// notes:			this forwards the printInfo to the main view so that it can display page breaks
///
///********************************************************************************************************************

- (void)				setPrintInfo:(NSPrintInfo*) printInfo
{
	[super setPrintInfo:printInfo];
	
	if([m_mainView pageBreaksVisible])
		[m_mainView setPageBreakInfo:printInfo];
}


//#define qTestAutoBackendCreation 1

///*********************************************************************************************************************
///
/// method:			windowControllerDidLoadNib:
/// scope:			public instance method
/// overrides:		NSDocument
/// description:	called when the window controller finished loading the window's nib
/// 
/// parameters:		<windowController> the window controller
/// result:			none
///
/// notes:			connects the main view to the drawing using a controller, so everything is ready to use
///
///********************************************************************************************************************

- (void)				windowControllerDidLoadNib:(NSWindowController*) windowController
{
	#pragma unused (windowController)
	
	//Note - if you override this, be sure to call super's implementation to ensure the drawing/controller/view system is established
	
	LogEvent_(kReactiveEvent, @"window controller did load nib; dwg = %@, view = %@", [self drawing], m_mainView );
	
	// after instantiation from a nib, this hooks up the main view through a controller to the drawing. Note - to test
	// automatic back-end creation, this can be temporarily commented out - it leaves the view unconnected so that it will
	// create its own back end when it is first asked to draw.

#ifndef qTestAutoBackendCreation
	
	if ( m_mainView != nil && [self drawing] != nil )
	{
		DKViewController*  mainViewController = [self makeControllerForView:[self mainView]];
		[[self drawing] addController:mainViewController];
	}

#endif
}


- (NSString*)			windowNibName
{
	return @"DKDrawingDocument";
}


#pragma mark -
#pragma mark As an NSObject

- (id)			init
{
    self = [super init];
 	if (self != nil)
	{
		[self setUndoManager:[[DKUndoManager alloc] init]];
	}
    return self;
}


- (void)				dealloc
{	
 	[[self undoManager] removeAllActions];
	[[self drawing] release];
	[super dealloc];
}


@end
