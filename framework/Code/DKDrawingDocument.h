///**********************************************************************************************************************************
///  DKDrawDocument.h
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 15/10/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import <Cocoa/Cocoa.h>


@class DKDrawing, DKDrawingView, DKViewController, DKDrawingTool, DKPrintDrawingView;


@interface DKDrawingDocument : NSDocument
{
@private
	IBOutlet DKDrawingView*	mMainDrawingView;
	DKDrawing*				m_drawing;
}

+ (NSUndoManager*)		sharedDrawkitUndoManager;

+ (void)				bindFileImportType:(NSString*) fileType toSelector:(SEL) aSelector;
+ (void)				bindFileExportType:(NSString*) fileType toSelector:(SEL) aSelector;

+ (void)				setDefaultLevelsOfUndo:(NSUInteger) levels;
+ (NSUInteger)			defaultLevelsOfUndo;

- (void)				setDrawing:(DKDrawing*) drwg;
- (DKDrawing*)			drawing;
- (DKDrawingView*)		mainView;
- (DKViewController*)	makeControllerForView:(NSView*) aView;
- (DKDrawing*)			makeDefaultDrawing;
- (Class)				classOfDefaultDrawingLayer;
- (BOOL)				wantsInfoLayer;

- (NSSet*)				allStyles;
- (NSSet*)				allRegisteredStyles;

- (void)				remergeStyles:(NSSet*) stylesToMerge readFromURL:(NSURL*) url;
- (void)				replaceDocumentStylesWithMatchingStylesFromSet:(NSSet*) aSetOfStyles;
- (NSString*)			documentStyleCategoryName;

- (void)				setDrawingTool:(DKDrawingTool*) aTool;
- (DKDrawingTool*)		drawingTool;

- (IBAction)			newDrawingLayer:(id) sender;
- (IBAction)			newLayerWithSelection:(id) sender;
- (IBAction)			deleteActiveLayer:(id) sender;

- (DKDrawingView*)		makePrintDrawingView;

@end

extern NSString*		kDKDrawingDocumentType;
extern NSString*		kDKDrawingDocumentUTI;
extern NSString*		kDKDrawingDocumentXMLType;
extern NSString*		kDKDrawingDocumentXMLUTI;

extern NSString*		kDKDocumentLevelsOfUndoDefaultsKey;


#define DEFAULT_LEVELS_OF_UNDO		24



/*

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
