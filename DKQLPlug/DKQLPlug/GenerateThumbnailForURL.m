#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#include "main.h"
#import <Foundation/Foundation.h>
#import <DKDrawKit/DKDrawKit.h>

static NSSize sizeConstrainedToSize(NSSize mainSize, NSSize constrainedSize)
{
	CGFloat mainRat = mainSize.width / mainSize.height;
	CGFloat constrRat = constrainedSize.width / constrainedSize.height;
	
	if (mainSize.width < constrainedSize.width && mainSize.height < constrainedSize.height) {
		return mainSize;
	}

	if (NSEqualSizes(mainSize, constrainedSize)) {
		return constrainedSize;
	}

	if (mainRat == constrRat) {
		return constrainedSize;
	}
	
	CGFloat bigConstrSize;
	if (constrRat < 1) {
		bigConstrSize = constrainedSize.width / mainSize.width;
	} else {
		bigConstrSize = constrainedSize.height / mainSize.height;
	}
	
	
	return NSMakeSize(bigConstrSize * mainSize.width, bigConstrSize * mainSize.height);
}

/* -----------------------------------------------------------------------------
    Generate a thumbnail for file

   This function's job is to create thumbnail for designated file as fast as possible
   ----------------------------------------------------------------------------- */

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize)
{
	@autoreleasepool {
		NSURL *nsURL = (__bridge NSURL *)url;
		NSString *nsUTI = (__bridge NSString*)contentTypeUTI;
		//NSDictionary *nsOptions = (__bridge NSDictionary*)options;
		
		DKDrawing *drawDat;
		if ([nsUTI isEqualToString:kDKDrawingDocumentUTI]) {
			NSData *dat = [[NSData alloc] initWithContentsOfURL:nsURL];
			if (dat == nil || QLThumbnailRequestIsCancelled(thumbnail)) {
				return noErr;
			}
			drawDat = [DKDrawing drawingWithData:dat];
		}
		if (drawDat == nil || QLThumbnailRequestIsCancelled(thumbnail)) {
			return noErr;
		}
		
		CGSize aSize = QLThumbnailRequestGetMaximumSize(thumbnail);
		aSize = sizeConstrainedToSize(drawDat.drawing.drawingSize, aSize);
		
		drawDat.drawing.drawingSize = aSize;
		[drawDat finalizePriorToSaving];
		if (QLThumbnailRequestIsCancelled(thumbnail)) {
			return noErr;
		}

		NSData *pdfDat = [drawDat pdf];
		if (QLThumbnailRequestIsCancelled(thumbnail)) {
			return noErr;
		}

		QLThumbnailRequestSetImageWithData(thumbnail, (__bridge CFDataRef)(pdfDat), (__bridge CFDictionaryRef)@{(NSString*)kCGImageSourceTypeIdentifierHint: (NSString*)kUTTypePDF});
	}

	return noErr;
}

void CancelThumbnailGeneration(void *thisInterface, QLThumbnailRequestRef thumbnail)
{
    // Implement only if supported
}
