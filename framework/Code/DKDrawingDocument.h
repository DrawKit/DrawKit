/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2015
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

@class DKDrawing, DKDrawingView, DKViewController, DKDrawingTool, DKPrintDrawingView;

/** @brief This class is a simple document type that owns a drawing instance.

This class is a simple document type that owns a drawing instance. It can be used as the basis for any drawing-based
document, where there is a 1:1 relationship between the documnent, the drawing and the main drawing view.

You can subclass to add functionality without having to rewrite the drawing ownership stuff.

This also handles standard printing of the drawing

Note that this is expected to be set up via the associated nib file. The outlet m_mainView should be set to the DKDrawingView in the window. Inherited
outlets such as window should be set as normal (File's Owner is of course, this object). If you forget to set the m_mainView outlet things won't work
properly because the document won't know which view to link to the drawing it creates. What will happen is that the unconnected view will work, and the first
time it goes to draw it will detect it has no back-end, and create one automatically. This is a feature, but in this case can be misleading, in that the drawing
you *see* is NOT the drawing that the document owns. The m_mainView outlet is the only way the document has to know about the view it's supposed to connect to
its drawing.

If you subclass this to have more views, etc, bear this in mind - you have to consider how the document's drawing gets hooked up to the views you want. Outlets
like this are one easy way to do it, but not the only way.
*/
@interface DKDrawingDocument : NSDocument {
@private
	IBOutlet DKDrawingView* mMainDrawingView;
	DKDrawing* m_drawing;
}

/** @brief Returns an undo manager that can be shared by multiple documents

 Some applications might be set up to use a global undo stack instead of havin gone per document.
 @return the shared instance of the undo manager
 */
+ (NSUndoManager*)sharedDrawkitUndoManager;

/** @brief Establishes a mapping between a file type and a method that can import that file type

 The selector is used to build an invocation on the DKDrawing class to import the type. The app
 will generally provide the method as part of a category extending DKDrawing, and use this method
 to forge the binding between the two. This class will then invoke the category method as required
 without the need to modify or subclass this class.
 @param fileType a filetype or UTI string for a file type
 @param aSelector a class method of DKDrawing that can import the file type
 */
+ (void)bindFileImportType:(NSString*)fileType toSelector:(SEL)aSelector;

/** @brief Establishes a mapping between a file type and a method that can export that file type

 The selector is used to build an invocation on the DKDrawing instance to export the type. The app
 will generally provide the method as part of a category extending DKDrawing, and use this method
 to forge the binding between the two. This class will then invoke the category method as required
 without the need to modify or subclass this class.
 @param fileType a filetype or UTI string for a file type
 @param selector a selector for the method that implements the file export
 */
+ (void)bindFileExportType:(NSString*)fileType toSelector:(SEL)aSelector;

/** @brief Set the default levels of undo assigned to new documents
 @param levels the number of undo levels
 */
+ (void)setDefaultLevelsOfUndo:(NSUInteger)levels;

/** @brief Return the default levels of undo assigned to new documents

 If the value wasn't found in the defaults, DEFAULT_LEVELS_OF_UNDO is returned
 @return the number of undo levels
 */
+ (NSUInteger)defaultLevelsOfUndo;

/** @brief Set the document's drawing object

 The document owns the drawing
 @param drwg a drawing object
 */
- (void)setDrawing:(DKDrawing*)drwg;

/** @brief Return the document's drawing object

 The document owns the drawing
 @return the document's drawing object
 */
- (DKDrawing*)drawing;

/** @brief Return the document's main view

 If the document has a main view, this returns it. Normally this is set up in the nib. A document
 isn't required to have an outlet to the main view but it makes setting everything up easier.
 @return the document's main view
 */
- (DKDrawingView*)mainView;

/** @brief Create a controller object to connect the given view to the document's drawing

 Usually you won't call this yourself but you can override it to supply different types of controllers.
 The default supplies a general purpose drawing tool controller. Note that the relationship
 between the view and the controller is set up by this, but NOT the relationship between the drawing
 and the controller - the controller must be added to the drawing using -addController.
 (Other parts of this class handle that).
 @param aView the view the controller will be used with
 @return a new controller object
 */
- (DKViewController*)makeControllerForView:(NSView*)aView;

/** @brief Create a drawing object to be used when the document is not opened from a file on disk

 You can override to make a different initial drawing or modify the existing one
 @return a default drawing object
 */
- (DKDrawing*)makeDefaultDrawing;

/** @brief Return the class of the layer for New Layer and default drawing construction.

 Subclasses can override this to insert a different layer type without having to override each
 separate command. Note that the returned class is expected to be a subclass of DKObjectDrawingLayer
 by some methods, most notably the -newLayerWithSelection method.
 @return the class of the default drawing layer
 */
- (Class)classOfDefaultDrawingLayer;

/** @brief Return whether an info layer should be added to the default drawing.

 Subclasses can override this to return NO if they don't want the info layer
 @return YES, by default
 */
- (BOOL)wantsInfoLayer;

/** @brief Returns all styles used by the document's drawing
 @return a set of all styles in the drawing
 */
- (NSSet*)allStyles;

/** @brief Returns all registered styles used by the document's drawing

 This method actually returns all styles flagged as formerly registered immediately after the
 document has been opened - all subsequent calls return the actual registered styles. Thus take
 care that this is only called once after loading a document if it's the flagged styles you require.
 @return a set of all registered styles in the drawing
 */
- (NSSet*)allRegisteredStyles;

/** @brief The first step in reconsolidating a newly opened document's registered styles with the current
 style registry.

 You should override this to handle style remerging in a different way if you need to. The default
 implementation allows the current registry to update the document and also adds the document's
 name as a category to the current registry.
 @param stylesToMerge a set of styles loaded with the document that are flagged as having been registered
 @param url the url from whence the document was loaded (ignored by default)
 */
- (void)remergeStyles:(NSSet*)stylesToMerge readFromURL:(NSURL*)url;

/** @brief The second step in reconsolidating a newly opened document's registered styles with the current
 style registry.

 This should only be called if the registry actually returned anything from the remerge operation
 @param aSetOfStyles the styles returned from the registry that should replace those in the document
 */
- (void)replaceDocumentStylesWithMatchingStylesFromSet:(NSSet*)aSetOfStyles;

/** @brief Returns a name that can be used for a style registry category for this document
 @return a string - just the document's filename without the extension or other path components
 */
- (NSString*)documentStyleCategoryName;

/** @brief Sets the main view's drawing tool to the given tool

 This helps DKDrawingTool's -set method work even when a document window contains several views that
 can be first responder. First the -set method will act directly on first responder, or a responder
 further up the chain. If that fails to find a responder, it then looks for an active document that
 responds to this method.
 @param aTool a drawing tool object
 */
- (void)setDrawingTool:(DKDrawingTool*)aTool;

/** @brief Returns the main view's current drawing tool

 This is a convenience for UI controllers to find the tool from the main view. If there are
 multiple drawing views you'll need another approach
 @return a drawing tool object, if any
 */
- (DKDrawingTool*)drawingTool;

/** @brief High-level method to add a new drawing layer to the document

 The added layer is made the active layer
 @param sender the sender of the message
 */
- (IBAction)newDrawingLayer:(id)sender;

/** @brief High-level method to add a new drawing layer to the document and move the selected objects to it

 The added layer is made the active layer, the objects are added to the new layer and selected, and
 removed from their current layer.
 @param sender the sender of the message
 */
- (IBAction)newLayerWithSelection:(id)sender;

/** @brief High-level method to delete the active layer from the drawing

 After this the active layer will be nil, and should be set to something before further use.
 @param sender the sender of the message
 */
- (IBAction)deleteActiveLayer:(id)sender;

/** @brief Creates a view used to handle printing.

 This may be overridden to customise the print view. Called by printShowingPrintPanel:
 @return a view suitable for printing the document's drawing
 */
- (DKDrawingView*)makePrintDrawingView;

@end

extern NSString* kDKDrawingDocumentType;
extern NSString* kDKDrawingDocumentUTI;
extern NSString* kDKDrawingDocumentXMLType;
extern NSString* kDKDrawingDocumentXMLUTI;

extern NSString* kDKDocumentLevelsOfUndoDefaultsKey;

#define DEFAULT_LEVELS_OF_UNDO 24
