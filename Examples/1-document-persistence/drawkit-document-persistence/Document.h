//
//  Document.h
//  drawkit-document-persistence
//
//  Created by Graham Miln on 08/05/2015.
//  Copyright (c) 2015 Miln. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <DKDrawKit/DKDrawKit.h>

@interface Document : NSDocument
@property(strong) DKDrawing* drawing;
@property(strong) DKToolController* toolController;
@property(weak) IBOutlet DKDrawingView* drawingView;

@end

