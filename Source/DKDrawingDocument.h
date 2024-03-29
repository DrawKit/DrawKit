/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKStyleRegistry.h"

NS_ASSUME_NONNULL_BEGIN

@class DKDrawing, DKDrawingView, DKViewController, DKDrawingTool, DKPrintDrawingView;
@class DKStyle;

/** @brief This class is a simple document type that owns a drawing instance.

 This class is a simple document type that owns a drawing instance. It can be used as the basis for any drawing-based
 document, where there is a 1:1 relationship between the documnent, the drawing and the main drawing view.

 You can subclass to add functionality without having to rewrite the drawing ownership stuff.

 This also handles standard printing of the drawing

 Note that this is expected to be set up via the associated nib file. The outlet \c m_mainView should be set to the \c DKDrawingView in the window. Inherited
 outlets such as window should be set as normal (File's Owner is of course, this object). If you forget to set the m_mainView outlet things won't work
 properly because the document won't know which view to link to the drawing it creates. What will happen is that the unconnected view will work, and the first
 time it goes to draw it will detect it has no back-end, and create one automatically. This is a feature, but in this case can be misleading, in that the drawing
 you \a see is \b not the drawing that the document owns. The \c m_mainView outlet is the only way the document has to know about the view it's supposed to connect to
 its drawing.

 If you subclass this to have more views, etc, bear this in mind - you have to consider how the document's drawing gets hooked up to the views you want. Outlets
 like this are one easy way to do it, but not the only way.
*/
@interface DKDrawingDocument : NSDocument <DKStyleRegistryDelegate> {
@private
	IBOutlet DKDrawingView* __weak mMainDrawingView;
	DKDrawing* m_drawing;
}

/** @brief Returns an undo manager that can be shared by multiple documents.

 Some applications might be set up to use a global undo stack instead of having gone per-document.
 @return The shared instance of the undo manager.
 */
@property (class, readonly, retain) NSUndoManager* sharedDrawkitUndoManager;

/** @brief Establishes a mapping between a file type and a method that can import that file type.

 The selector is used to build an invocation on the \c DKDrawing class to import the type. The app
 will generally provide the method as part of a category extending DKDrawing, and use this method
 to forge the binding between the two. This class will then invoke the category method as required
 without the need to modify or subclass this class.
 @param fileType A filetype or UTI string for a file type.
 @param aSelector A class method of \c DKDrawing that can import the file type.
 */
+ (void)bindFileImportType:(NSString*)fileType toSelector:(SEL)aSelector;

/** @brief Establishes a mapping between a file type and a method that can export that file type.

 The selector is used to build an invocation on the \c DKDrawing instance to export the type. The app
 will generally provide the method as part of a category extending DKDrawing, and use this method
 to forge the binding between the two. This class will then invoke the category method as required
 without the need to modify or subclass this class.
 @param fileType A filetype or UTI string for a file type.
 @param aSelector A selector for the method that implements the file export.
 */
+ (void)bindFileExportType:(NSString*)fileType toSelector:(SEL)aSelector;

/** @brief The default levels of undo assigned to new documents.

 If the value wasn't found in the defaults, \c DEFAULT_LEVELS_OF_UNDO is returned.
 @return The number of undo levels.
 */
@property (class) NSUInteger defaultLevelsOfUndo;

/** @brief The document's drawing object.

 The document owns the drawing.
 */
@property (atomic, strong) DKDrawing* drawing;

/** @brief Return the document's main view.

 If the document has a main view, this returns it. Normally this is set up in the nib. A document
 isn't required to have an outlet to the main view but it makes setting everything up easier.
 @return The document's main view.
 */
@property (readonly, weak) DKDrawingView* mainView;

/** @brief Create a controller object to connect the given view to the document's drawing.

 Usually you won't call this yourself but you can override it to supply different types of controllers.
 The default supplies a general purpose drawing tool controller. Note that the relationship
 between the view and the controller is set up by this, but NOT the relationship between the drawing
 and the controller - the controller must be added to the drawing using -addController.
 (Other parts of this class handle that).
 @param aView The view the controller will be used with.
 @return A new controller object.
 */
- (DKViewController*)makeControllerForView:(NSView*)aView;

/** @brief Create a drawing object to be used when the document is not opened from a file on disk.

 You can override to make a different initial drawing or modify the existing one.
 @return A default drawing object.
 */
- (DKDrawing*)makeDefaultDrawing;

/** @brief Return the class of the layer for New Layer and default drawing construction.

 Subclasses can override this to insert a different layer type without having to override each
 separate command. Note that the returned class is expected to be a subclass of \c DKObjectDrawingLayer
 by some methods, most notably the \c -newLayerWithSelection method.
 @return The class of the default drawing layer.
 */
@property (unsafe_unretained, readonly) Class classOfDefaultDrawingLayer;

/** @brief Return whether an info layer should be added to the default drawing.

 Subclasses can override this to return NO if they don't want the info layer.
 @return YES, by default.
 */
@property (readonly) BOOL wantsInfoLayer;

/** @brief Returns all styles used by the document's drawing.
 @return A set of all styles in the drawing.
 */
@property (readonly, copy) NSSet<DKStyle*>* allStyles;

/** @brief Returns all registered styles used by the document's drawing.

 This method actually returns all styles flagged as formerly registered immediately after the
 document has been opened - all subsequent calls return the actual registered styles. Thus take
 care that this is only called once after loading a document if it's the flagged styles you require.
 @return A set of all registered styles in the drawing.
 */
@property (readonly, copy) NSSet<DKStyle*>* allRegisteredStyles;

/** @brief The first step in reconsolidating a newly opened document's registered styles with the current
 style registry.

 You should override this to handle style remerging in a different way if you need to. The default
 implementation allows the current registry to update the document and also adds the document's
 name as a category to the current registry.
 @param stylesToMerge A set of styles loaded with the document that are flagged as having been registered.
 @param url The url from whence the document was loaded (ignored by default).
 */
- (void)remergeStyles:(NSSet<DKStyle*>*)stylesToMerge readFromURL:(nullable NSURL*)url;

/** @brief The second step in reconsolidating a newly opened document's registered styles with the current
 style registry.

 This should only be called if the registry actually returned anything from the remerge operation.
 @param aSetOfStyles The styles returned from the registry that should replace those in the document.
 */
- (void)replaceDocumentStylesWithMatchingStylesFromSet:(NSSet<DKStyle*>*)aSetOfStyles;

/** @brief Returns a name that can be used for a style registry category for this document.
 @return A string - just the document's filename without the extension or other path components.
 */
@property (readonly, copy) NSString* documentStyleCategoryName;

/** @brief Sets the main view's drawing tool to the given tool.

 This is a convenience for UI controllers to find the tool from the main view. If there are
 multiple drawing views you'll need another approach.
 This helps <code>DKDrawingTool</code>'s \c -set method work even when a document window contains several views that
 can be first responder. First the \c -set method will act directly on first responder, or a responder
 further up the chain. If that fails to find a responder, it then looks for an active document that
 responds to this method.
 */
@property (strong) DKDrawingTool* drawingTool;

/** @brief High-level method to add a new drawing layer to the document.

 The added layer is made the active layer.
 @param sender The sender of the message.
 */
- (IBAction)newDrawingLayer:(nullable id)sender;

/** @brief High-level method to add a new drawing layer to the document and move the selected objects to it.

 The added layer is made the active layer, the objects are added to the new layer and selected, and
 removed from their current layer.
 @param sender The sender of the message.
 */
- (IBAction)newLayerWithSelection:(nullable id)sender;

/** @brief High-level method to delete the active layer from the drawing.

 After this, the active layer will be <code>nil</code>, and should be set to something before further use.
 @param sender The sender of the message.
 */
- (IBAction)deleteActiveLayer:(nullable id)sender;

/** @brief Creates a view used to handle printing.

 This may be overridden to customise the print view. Called by \c printShowingPrintPanel:
 @return A view suitable for printing the document's drawing.
 */
- (DKDrawingView*)makePrintDrawingView;

@end

extern NSString* const kDKDrawingDocumentType;
extern NSString* const kDKDrawingDocumentUTI;
extern NSString* const kDKDrawingDocumentXMLType;
extern NSString* const kDKDrawingDocumentXMLUTI;

extern NSString* const kDKDocumentLevelsOfUndoDefaultsKey;

#define DEFAULT_LEVELS_OF_UNDO 24lu

NS_ASSUME_NONNULL_END
