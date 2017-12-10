/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

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

@interface DKSelectorWrapper : NSObject {
	SEL mSelector;
}

+ (DKSelectorWrapper*)wrapperWithSelector:(nonnull SEL)aSelector;
@property (readonly, nonnull) SEL selector;

@end

#pragma mark Constants(Non - localized)

NSString* kDKDrawingDocumentType = @"Drawing";
NSString* kDKDrawingDocumentUTI = @"net.apptree.drawing";
NSString* kDKDrawingDocumentXMLType = @"xml_drawing";
NSString* kDKDrawingDocumentXMLUTI = @"net.apptree.xmldrawing";

NSString* kDKDocumentLevelsOfUndoDefaultsKey = @"kDKDocumentLevelsOfUndo";

#define qGlobalUndoManager 0

#pragma mark -
@implementation DKDrawingDocument
#pragma mark As a DKDrawDocument

static NSMutableDictionary* sFileImportBindings = nil;
static NSMutableDictionary* sFileExportBindings = nil;

/** @brief Returns an undo manager that can be shared by multiple documents

 Some applications might be set up to use a global undo stack instead of havin gone per document.
 @return the shared instance of the undo manager
 */
+ (NSUndoManager*)sharedDrawkitUndoManager
{
	static DKUndoManager* s_um = nil;

	if (s_um == nil)
		s_um = [[DKUndoManager alloc] init];

	return (NSUndoManager*)s_um;
}

/** @brief Establishes a mapping between a file type and a method that can import that file type

 The selector is used to build an invocation on the DKDrawing class to import the type. The app
 will generally provide the method as part of a category extending DKDrawing, and use this method
 to forge the binding between the two. This class will then invoke the category method as required
 without the need to modify or subclass this class.
 @param fileType a filetype or UTI string for a file type
 @param aSelector a class method of DKDrawing that can import the file type
 */
+ (void)bindFileImportType:(NSString*)fileType toSelector:(SEL)aSelector
{
	NSAssert(fileType != nil, @"cannot bind a nil fileType");

	if (sFileImportBindings == nil)
		sFileImportBindings = [[NSMutableDictionary alloc] init];

	if (aSelector != NULL) {
		DKSelectorWrapper* sw = [DKSelectorWrapper wrapperWithSelector:aSelector];
		[sFileImportBindings setObject:sw
								forKey:fileType];
	} else
		[sFileImportBindings removeObjectForKey:fileType];
}

/** @brief Establishes a mapping between a file type and a method that can export that file type

 The selector is used to build an invocation on the DKDrawing instance to export the type. The app
 will generally provide the method as part of a category extending DKDrawing, and use this method
 to forge the binding between the two. This class will then invoke the category method as required
 without the need to modify or subclass this class.
 @param fileType a filetype or UTI string for a file type
 @param selector a selector for the method that implements the file export
 */
+ (void)bindFileExportType:(NSString*)fileType toSelector:(SEL)aSelector
{
	NSAssert(fileType != nil, @"cannot bind a nil fileType");

	if (sFileExportBindings == nil)
		sFileExportBindings = [[NSMutableDictionary alloc] init];

	if (aSelector != NULL) {
		DKSelectorWrapper* sw = [DKSelectorWrapper wrapperWithSelector:aSelector];
		[sFileExportBindings setObject:sw
								forKey:fileType];
	} else
		[sFileExportBindings removeObjectForKey:fileType];
}

/** @brief Set the default levels of undo assigned to new documents
 @param levels the number of undo levels
 */
+ (void)setDefaultLevelsOfUndo:(NSUInteger)levels
{
	[[NSUserDefaults standardUserDefaults] setInteger:levels
											   forKey:kDKDocumentLevelsOfUndoDefaultsKey];
}

/** @brief Return the default levels of undo assigned to new documents

 If the value wasn't found in the defaults, DEFAULT_LEVELS_OF_UNDO is returned
 @return the number of undo levels
 */
+ (NSUInteger)defaultLevelsOfUndo
{
	NSUInteger levels = [[NSUserDefaults standardUserDefaults] integerForKey:kDKDocumentLevelsOfUndoDefaultsKey];

	if (levels == 0) {
		levels = DEFAULT_LEVELS_OF_UNDO;
		[self setDefaultLevelsOfUndo:levels];
	}

	return levels;
}

/** @brief Set the document's drawing object

 The document owns the drawing
 @param drwg a drawing object
 */
- (void)setDrawing:(DKDrawing*)drwg
{
	// sets the drawing to <drwg>.

	[drwg retain];
	[m_drawing release]; // also removes and releases all existing controllers
	m_drawing = drwg;
	[m_drawing setOwner:self];

	// create a controller for the main view and add it to the drawing - often at this stage mainView is nil, so
	// this step is for when the drawing is recreated sometime after initialisation - e.g. on revert. For the usual
	// case of instantiation from a nib, the -windowControllerDidLoadNib method performs this step.

	if ([self mainView] != nil) {
		DKViewController* mainViewController = [self makeControllerForView:[self mainView]];
		[[self drawing] addController:mainViewController];
	}

#if qGlobalUndoManager
	[self setUndoManager:[[self class] sharedDrawkitUndoManager]];
#endif

	[[self drawing] setUndoManager:[self undoManager]];
	[[self undoManager] setLevelsOfUndo:[[self class] defaultLevelsOfUndo]];

	LogEvent_(kReactiveEvent, @"undo mgr = %@", [self undoManager]);
}

@synthesize drawing=m_drawing;

#pragma mark -

@synthesize mainView=mMainDrawingView;

/** @brief Create a controller object to connect the given view to the document's drawing

 Usually you won't call this yourself but you can override it to supply different types of controllers.
 The default supplies a general purpose drawing tool controller. Note that the relationship
 between the view and the controller is set up by this, but NOT the relationship between the drawing
 and the controller - the controller must be added to the drawing using -addController.
 (Other parts of this class handle that).
 @param aView the view the controller will be used with
 @return a new controller object
 */
- (DKViewController*)makeControllerForView:(NSView*)aView
{
	NSAssert(aView != nil, @"attempt to make controller when view is nil");

	if ([aView respondsToSelector:@selector(makeViewController)])
		return [(id)aView makeViewController];
	else {
		DKViewController* aController = [[DKViewController alloc] initWithView:aView];
		return [aController autorelease];
	}
}

/** @brief Create a drawing object to be used when the document is not opened from a file on disk

 You can override to make a different initial drawing or modify the existing one
 @return a default drawing object
 */
- (DKDrawing*)makeDefaultDrawing
{
	// set up a default drawing - this is A2 in size, landscape orientation, has grid, guids and one drawing layer, which is made active

	DKDrawing* dr = [[DKDrawing alloc] initWithSize:[DKDrawing isoA2PaperSize:NO]];

	// attach a grid layer
	[DKGridLayer setDefaultGridThemeColour:[[NSColor brownColor] colorWithAlphaComponent:0.5]];
	DKGridLayer* grid = [[DKGridLayer alloc] init];
	[dr addLayer:grid];
	[grid tweakDrawingMargins];
	[grid release];

	// attach a drawing layer and make it the active layer

	DKObjectDrawingLayer* layer = [[[self classOfDefaultDrawingLayer] alloc] init];
	[dr addLayer:layer];
	[dr setActiveLayer:layer];
	[layer release];

	// optional info layer

	if ([self wantsInfoLayer]) {
		DKDrawingInfoLayer* infoLayer = [[DKDrawingInfoLayer alloc] init];
		[dr addLayer:infoLayer];
		[infoLayer setVisible:NO];
		[infoLayer release];
	}

	// attach a guide layer

	DKGuideLayer* guides = [[DKGuideLayer alloc] init];
	[dr addLayer:guides];
	[guides release];
	return [dr autorelease];
}

/** @brief Return the class of the layer for New Layer and default drawing construction.

 Subclasses can override this to insert a different layer type without having to override each
 separate command. Note that the returned class is expected to be a subclass of DKObjectDrawingLayer
 by some methods, most notably the -newLayerWithSelection method.
 @return the class of the default drawing layer
 */
- (Class)classOfDefaultDrawingLayer
{
	return [DKObjectDrawingLayer class];
}

/** @brief Return whether an info layer should be added to the default drawing.

 Subclasses can override this to return NO if they don't want the info layer
 @return YES, by default
 */
- (BOOL)wantsInfoLayer
{
	return YES;
}

#pragma mark -
#pragma mark handy user actions

/** @brief High-level method to add a new drawing layer to the document

 The added layer is made the active layer
 @param sender the sender of the message
 */
- (IBAction)newDrawingLayer:(id)sender
{
#pragma unused(sender)

	// high level action to add a new drawing layer to the drawing and make it active

	DKDrawing* dr = [self drawing];
	DKObjectDrawingLayer* layer = [[[self classOfDefaultDrawingLayer] alloc] init];

	[dr addLayer:layer
		andActivateIt:YES];
	[layer release];

	[[self undoManager] setActionName:NSLocalizedString(@"New Layer", @"undo string for new layer")];
}

/** @brief High-level method to add a new drawing layer to the document and move the selected objects to it

 The added layer is made the active layer, the objects are added to the new layer and selected, and
 removed from their current layer.
 @param sender the sender of the message
 */
- (IBAction)newLayerWithSelection:(id)sender
{
#pragma unused(sender)

	// high-level action adds a new drawing layer and moves the currently selected objects to it
	// if the selection is empty or the current active layer is not an object layer, does nothing

	DKObjectDrawingLayer* cLayer = [[self drawing] activeLayerOfClass:[DKObjectDrawingLayer class]];

	if (cLayer != nil) {
		NSArray* selection = [cLayer selectedObjectsPreservingStackingOrder];

		if ([selection count] > 0) {
			// ok, something to do...

			DKDrawing* dr = [self drawing];
			DKObjectDrawingLayer* layer = [[[self classOfDefaultDrawingLayer] alloc] init];

			[dr addLayer:layer
				andActivateIt:YES];

			// move objects to it and select them

			[selection retain];
			[cLayer recordSelectionForUndo];
			[cLayer removeObjectsInArray:selection];
			[cLayer commitSelectionUndoWithActionName:@""];

			[layer recordSelectionForUndo];
			[layer addObjectsFromArray:selection];
			[layer addObjectsToSelectionFromArray:selection];
			[layer commitSelectionUndoWithActionName:@""];

			[selection release];
			[layer release];

			[[self undoManager] setActionName:NSLocalizedString(@"Move To New Layer", @"undo string for move to new layer")];

			return;
		}
	}

	NSBeep();
}

/** @brief High-level method to delete the active layer from the drawing

 After this the active layer will be nil, and should be set to something before further use.
 @param sender the sender of the message
 */
- (IBAction)deleteActiveLayer:(id)sender
{
#pragma unused(sender)

	DKLayer* layer = [[self drawing] activeLayer];

	if ([layer layerMayBeDeleted]) {
		[[self drawing] removeLayer:layer];
		[[self undoManager] setActionName:NSLocalizedString(@"Delete Layer", @"undo string for delete layer")];
	}
}

#pragma mark -
#pragma mark style remerging

/** @brief The first step in reconsolidating a newly opened document's registered styles with the current
 style registry.

 You should override this to handle style remerging in a different way if you need to. The default
 implementation allows the current registry to update the document and also adds the document's
 name as a category to the current registry.
 @param stylesToMerge a set of styles loaded with the document that are flagged as having been registered
 @param url the url from whence the document was loaded (ignored by default)
 */
- (void)remergeStyles:(NSSet*)stylesToMerge readFromURL:(NSURL*)url
{
#pragma unused(url)

	NSAssert(stylesToMerge != nil, @"attempt to remerge a nil set");

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

	NSArray* docNameCat = [NSArray arrayWithObject:[self documentStyleCategoryName]];
	NSSet* changedStyles = [DKStyleRegistry mergeStyles:stylesToMerge
										   inCategories:docNameCat
												options:kDKReturnExistingStyles
										  mergeDelegate:self];

	// the returned set contains the objects from the registry that match those in the document. The document must now adopt these objects in
	// place of the temporary ones that it created on being unarchived. If the set is empty or nil, we're done.

	if (changedStyles != nil && [changedStyles count] > 0)
		[self replaceDocumentStylesWithMatchingStylesFromSet:changedStyles];
}

/** @brief The second step in reconsolidating a newly opened document's registered styles with the current
 style registry.

 This should only be called if the registry actually returned anything from the remerge operation
 @param aSetOfStyles the styles returned from the registry that should replace those in the document
 */
- (void)replaceDocumentStylesWithMatchingStylesFromSet:(NSSet*)aSetOfStyles
{
	// this method is an imperative - when called, styles in the passed set that have a matching key with those in this document MUST
	// replace the doc's styles. This requires iterating over the drawing's entire contents and replacing such styles. This relinks the
	// doc's styles with the registry's styles.

	NSAssert(aSetOfStyles != nil, @"can't replace styles from a nil set");
	LogEvent_(kStateEvent, @"document will replace %d styles", [aSetOfStyles count]);

	[[self drawing] replaceMatchingStylesFromSet:aSetOfStyles];

	// n.b. all undos arising from this operation are discarded - there's no good reason to undo stuff that is really part
	// of the initialisation

	[[self undoManager] removeAllActions];

	/// should the document be dirtied anyway? NO for now.

	//[self updateChangeCount:NSChangeDone];
}

/** @brief Returns a name that can be used for a style registry category for this document
 @return a string - just the document's filename without the extension or other path components
 */
- (NSString*)documentStyleCategoryName
{
	// return the name of the category that this document creates in the style registry - by default it's just the name part of the URL.

	return [[[[self fileURL] path] lastPathComponent] stringByDeletingPathExtension];
}

/** @brief Returns all styles used by the document's drawing
 @return a set of all styles in the drawing
 */
- (NSSet*)allStyles
{
	return [[self drawing] allStyles];
}

/** @brief Returns all registered styles used by the document's drawing

 This method actually returns all styles flagged as formerly registered immediately after the
 document has been opened - all subsequent calls return the actual registered styles. Thus take
 care that this is only called once after loading a document if it's the flagged styles you require.
 @return a set of all registered styles in the drawing
 */
- (NSSet*)allRegisteredStyles
{
	return [[self drawing] allRegisteredStyles];
}

/** @brief Sets the main view's drawing tool to the given tool

 This helps DKDrawingTool's -set method work even when a document window contains several views that
 can be first responder. First the -set method will act directly on first responder, or a responder
 further up the chain. If that fails to find a responder, it then looks for an active document that
 responds to this method.
 @param aTool a drawing tool object
 */
- (void)setDrawingTool:(DKDrawingTool*)aTool
{
	[(id)[self mainView] setDrawingTool:aTool];
}

/** @brief Returns the main view's current drawing tool

 This is a convenience for UI controllers to find the tool from the main view. If there are
 multiple drawing views you'll need another approach
 @return a drawing tool object, if any
 */
- (DKDrawingTool*)drawingTool
{
	return [(id)[self mainView] drawingTool];
}

/** @brief Creates a view used to handle printing.

 This may be overridden to customise the print view. Called by printShowingPrintPanel:
 @return a view suitable for printing the document's drawing
 */
- (DKDrawingView*)makePrintDrawingView
{
	NSRect fr = NSZeroRect;
	fr.size = [[self drawing] drawingSize];

	DKDrawingView* pdv = [[DKDrawingView alloc] initWithFrame:fr];

	return [pdv autorelease];
}

#pragma mark -
#pragma mark As an NSDocument

/** @brief Return the data to save when this document is written to disk.

 This uses the file type bindings established to look up the necessary method to invoke to perform
 the data conversion. If no bindings were registered or the method doesn't exist, will throw an error.
 @param typeName the type of data to write (ignored)
 @param outError an error, if it wasn't successful
 @return the data to be written to disk
 */
- (NSData*)dataOfType:(NSString*)typeName error:(NSError**)outError
{
	NSData* theData = nil;

	[[[self drawing] drawingInfo] setObject:[self displayName]
									 forKey:kDKDrawingInfoTitle];

	// if there is an export binding for the type, use it to create an invocation

	if (sFileExportBindings != nil) {
		DKSelectorWrapper* wrapper = [sFileExportBindings objectForKey:typeName];

		if (wrapper) {
			SEL selector = [wrapper selector];

			if ([[self drawing] respondsToSelector:selector])
				theData = [[self drawing] performSelector:selector];
		}
	}

	// throw an error if the data is nil

	if (theData == nil) {
		if (outError)
			*outError = [NSError errorWithDomain:NSCocoaErrorDomain
											code:NSFileWriteUnsupportedSchemeError
										userInfo:nil];

		return nil;
	}

	return theData;
}

/** @brief Set up the document in its initial state for the "New" command.

 Creates a default drawing object
 @param typeName the type of data that the document is created to handle (ignored)
 @param outError an error, if it wasn't successful
 @return the document object
 */
- (id)initWithType:(NSString*)typeName error:(NSError**)outError
{
	LogEvent_(kLifeEvent, @"initialising default drawing, type = '%@'", typeName);

	[super initWithType:typeName
				  error:outError];

	// create a default drawing. Note that the fileType is ignored. It creates the default drawing regardless of type - if
	// your document needs to be sensitive to the type, override this.

	DKDrawing* dr = [self makeDefaultDrawing];
	[self setDrawing:dr];

	return self;
}

/** @brief Implements the print command.
 @param flag YES to show the print panel
 */
- (void)printShowingPrintPanel:(BOOL)flag
{
	DKDrawingView* pdv = [[self makePrintDrawingView] retain];
	DKViewController* vc = [pdv makeViewController];

	[[self drawing] addController:vc];

	NSPrintInfo* printInfo = [self printInfo];

	[pdv setPrintInfo:printInfo];
	[pdv setPrintCropMarkKind:[[self mainView] printCropMarkKind]];

	NSPrintOperation* printOp = [NSPrintOperation printOperationWithView:pdv
															   printInfo:[self printInfo]];

	[printOp setShowPanels:flag];
	[self runModalPrintOperation:printOp
						delegate:nil
				  didRunSelector:nil
					 contextInfo:nil];

	[pdv release];
}

/** @brief Initialises the document from a file on disk when opened from the "Open" command.

 Instantiates the drawing from the file data at the given URL.
 @param absoluteURL the url being read
 @param typeName the type of data to load
 @param outError the error if not successful
 @return YES if the file was opened, NO otherwise
 */
- (BOOL)readFromData:(NSData*)data ofType:(NSString*)typeName error:(NSError**)outError
{
	DKDrawing* theDrawing = nil;

	if (sFileImportBindings != nil) {
		DKSelectorWrapper* wrapper = [sFileImportBindings objectForKey:typeName];

		if (wrapper) {
			SEL selector = [wrapper selector];

			if ([DKDrawing respondsToSelector:selector])
				theDrawing = [DKDrawing performSelector:selector
											 withObject:data];
		}
	}

	if (theDrawing != nil) {
		[self setDrawing:theDrawing];

		// having loaded the drawing and fully dearchived it, we need to remerge styles in the document with the style registry.
		// what happens here will depend on the application design and possibly the user's personal choice. So this is factored out to
		// allow an easy override. The default method blindly remerges the styles from the document back into the registry.

		NSSet* stylesToMerge = [[self drawing] allRegisteredStyles]; // after a file load, this method returns a special set THIS ONCE ONLY

		if (stylesToMerge != nil && [stylesToMerge count] > 0)
			[self remergeStyles:stylesToMerge
					readFromURL:nil];

		return YES;
	} else {
		if (outError)
			*outError = [NSError errorWithDomain:NSCocoaErrorDomain
											code:NSFileReadUnsupportedSchemeError
										userInfo:nil];
		return NO;
	}
}

/** @brief Sets the printing info

 This forwards the printInfo to the main view so that it can display page breaks
 @param printInfo the printing info
 */
- (void)setPrintInfo:(NSPrintInfo*)printInfo
{
	[super setPrintInfo:printInfo];
	[mMainDrawingView setPrintInfo:printInfo];
}

//#define qTestAutoBackendCreation 1

/** @brief Called when the window controller finished loading the window's nib

 Connects the main view to the drawing using a controller, so everything is ready to use
 @param windowController the window controller
 */
- (void)windowControllerDidLoadNib:(NSWindowController*)windowController
{
#pragma unused(windowController)

	//Note - if you override this, be sure to call super's implementation to ensure the drawing/controller/view system is established

	LogEvent_(kReactiveEvent, @"window controller did load nib; dwg = %@, view = %@", [self drawing], [self mainView]);

// after instantiation from a nib, this hooks up the main view through a controller to the drawing. Note - to test
// automatic back-end creation, this can be temporarily commented out - it leaves the view unconnected so that it will
// create its own back end when it is first asked to draw.

#ifndef qTestAutoBackendCreation

	if (mMainDrawingView != nil && [self drawing] != nil) {
		DKViewController* mainViewController = [self makeControllerForView:[self mainView]];
		[[self drawing] addController:mainViewController];
	}

#endif
}

- (NSString*)windowNibName
{
	return @"DKDrawingDocument";
}

#pragma mark -
#pragma mark As an NSObject

#define USE_DK_UNDO_MANAGER 1

- (id)init
{
	self = [super init];
	if (self != nil) {
#if USE_DK_UNDO_MANAGER
		DKUndoManager* dkum = [[DKUndoManager alloc] init];
		[dkum enableUndoTaskCoalescing:YES];
		[self setUndoManager:(id)dkum];
		[dkum release];
#endif
		// bind the standard drawing types to the usual methods

		[[self class] bindFileExportType:kDKDrawingDocumentType
							  toSelector:@selector(drawingData)];
		[[self class] bindFileExportType:kDKDrawingDocumentUTI
							  toSelector:@selector(drawingData)];
		[[self class] bindFileExportType:kDKDrawingDocumentXMLType
							  toSelector:@selector(drawingAsXMLDataAtRoot)];
		[[self class] bindFileExportType:kDKDrawingDocumentXMLUTI
							  toSelector:@selector(drawingAsXMLDataAtRoot)];

		[[self class] bindFileImportType:kDKDrawingDocumentType
							  toSelector:@selector(drawingWithData:)];
		[[self class] bindFileImportType:kDKDrawingDocumentUTI
							  toSelector:@selector(drawingWithData:)];
	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	// set drawing's undo manager to nil prior to document dealloc so that any other refs to the drawing don't cause
	// a problem with a stale undo mgr ref when the drawing is dealloced

	[[self drawing] setUndoManager:nil];
	[m_drawing setOwner:nil];
	[m_drawing release];
	[super dealloc];
}

- (BOOL)validateMenuItem:(NSMenuItem*)item
{
	SEL action = [item action];

	if (action == @selector(newDrawingLayer:))
		return YES;

	if (action == @selector(newLayerWithSelection:)) {
		DKLayer* active = [[self drawing] activeLayer];
		NSUInteger selCount = 0;

		if ([active respondsToSelector:@selector(countOfSelectedAvailableObjects)])
			selCount = [(DKObjectDrawingLayer*)active countOfSelectedAvailableObjects];

		return selCount > 0;
	}

	if (action == @selector(deleteActiveLayer:))
		return [[[self drawing] activeLayer] layerMayBeDeleted];

	return [super validateMenuItem:item];
}

@end

#pragma mark -
#pragma mark - As a DKSelectorWrapper

@implementation DKSelectorWrapper
@synthesize selector=mSelector;

+ (DKSelectorWrapper*)wrapperWithSelector:(SEL)aSelector
{
	NSAssert(aSelector != NULL, @"can't create selector wrapper for NULL");

	DKSelectorWrapper* wrapper = [[DKSelectorWrapper alloc] init];
	wrapper->mSelector = aSelector;
	return [wrapper autorelease];
}

@end
