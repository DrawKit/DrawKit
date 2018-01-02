#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#include "main.h"
#import <Cocoa/Cocoa.h>
#import <DKDrawKit/DKDrawKit.h>

/* -----------------------------------------------------------------------------
   Generate a preview for file

   This function's job is to create preview for designated file
   ----------------------------------------------------------------------------- */

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options)
{
	@autoreleasepool {
		NSURL *nsURL = (__bridge NSURL *)url;
		NSString *nsUTI = (__bridge NSString*)contentTypeUTI;
		//NSDictionary *nsOptions = (__bridge NSDictionary*)options;
		
		DKDrawing *drawDat;
		if ([nsUTI isEqualToString:kDKDrawingDocumentUTI]) {
			NSData *dat = [[NSData alloc] initWithContentsOfURL:nsURL];
			if (dat == nil || QLPreviewRequestIsCancelled(preview)) {
				return noErr;
			}
			drawDat = [DKDrawing drawingWithData:dat];
		}
		if (drawDat == nil || QLPreviewRequestIsCancelled(preview)) {
			return noErr;
		}
		
		// Should not be needed: we didn't edit anything.
		//[drawDat finalizePriorToSaving];

		CGContextRef ctx = QLPreviewRequestCreateContext(preview, drawDat.drawing.drawingSize, false, NULL);
		{
			NSGraphicsContext *gc;
			if (@available(macOS 10.10, *)) {
				gc = [NSGraphicsContext graphicsContextWithCGContext:ctx flipped:YES];
			} else {
				gc = [NSGraphicsContext graphicsContextWithGraphicsPort:ctx flipped:YES];
			}
			[NSGraphicsContext saveGraphicsState];
			NSAffineTransform *flipTrans = [[NSAffineTransform alloc] init];
			[flipTrans scaleXBy:1 yBy:-1];
			[flipTrans translateXBy:0 yBy:-drawDat.drawing.drawingSize.height];
			NSGraphicsContext.currentContext = gc;
			[flipTrans concat];
			NSRect frame = NSZeroRect;
			frame.size = drawDat.drawing.drawingSize;
			drawDat.drawing.gridLayer.shouldDrawToPrinter = YES;
			
			DKLayerPDFView* pdfView = [[DKLayerPDFView alloc] initWithFrame:frame
																  withLayer:drawDat];
			DKViewController* vc = [pdfView makeViewController];
			
			[drawDat.drawing addController:vc];
			
			[pdfView drawRect:frame];
			pdfView = nil; // removes the controller
			[NSGraphicsContext restoreGraphicsState];
		}
		QLPreviewRequestFlushContext(preview, ctx);
		CGContextRelease(ctx);
	}

	return noErr;
}

void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview)
{
    // Implement only if supported
}
