//
//  Document.m
//  drawkit-document-persistence
//
//  Created by Graham Miln on 08/05/2015.
//  Copyright (c) 2015 Miln. All rights reserved.
//

#import "Document.h"

@interface Document ()

@end

@implementation Document

- (instancetype)init {
    self = [super init];
    if (self) {
		// Add your subclass-specific initialization here.
		
		self.drawing = [DKDrawing defaultDrawingWithSize:[DKDrawing isoA3PaperSize:NO]];
    }
    return self;
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController {
	[super windowControllerDidLoadNib:aController];
	// Add any code here that needs to be executed once the windowController has loaded the document's window.
	
	self.toolController = [[DKToolController alloc] initWithView:self.drawingView];
	[self.drawing addController:self.toolController];
}

+ (BOOL)autosavesInPlace {
	return YES;
}

- (NSString *)windowNibName {
	// Override returning the nib file name of the document
	// If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
	return @"Document";
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
	// Insert code here to write your document to data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning nil.
	// You can also choose to override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
	
	return [self.drawing drawingData];
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
	// Insert code here to read your document from the given data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning NO.
	// You can also choose to override -readFromFileWrapper:ofType:error: or -readFromURL:ofType:error: instead.
	// If you override either of these, you should also override -isEntireFileLoaded to return NO if the contents are lazily loaded.

	if (self.toolController) {
		[self.drawing removeController:self.toolController];
	}

	self.drawing = [DKDrawing drawingWithData:data];

	if (self.toolController) {
		[self.drawing addController:self.toolController];
	}
	
	return YES;
}

@end
