#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#include "main.h"
#import <Foundation/Foundation.h>
#import <DKDrawKit/DKDrawKit.h>

#if 0
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
	if (constrRat < mainRat) {
		bigConstrSize = constrainedSize.width / mainSize.width;
	} else {
		bigConstrSize = constrainedSize.height / mainSize.height;
	}
	
	
	return NSMakeSize(bigConstrSize * mainSize.width, bigConstrSize * mainSize.height);
}
#endif

static CGFloat scaleConstrainedFromSize(NSSize mainSize, NSSize constrainedSize)
{
	CGFloat mainRat = mainSize.width / mainSize.height;
	CGFloat constrRat = constrainedSize.width / constrainedSize.height;
	
	if (mainSize.width < constrainedSize.width && mainSize.height < constrainedSize.height) {
		return 1.0;
	}
	
	if (NSEqualSizes(mainSize, constrainedSize)) {
		return 1.0;
	}
	
	if (mainRat == constrRat) {
		return constrainedSize.width / mainSize.width;
	}
	
	CGFloat bigConstrSize;
	if (constrRat < mainRat) {
		bigConstrSize = constrainedSize.width / mainSize.width;
	} else {
		bigConstrSize = constrainedSize.height / mainSize.height;
	}
	
	return bigConstrSize;
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
		
		// Should not be needed: we didn't edit anything.
		//[drawDat finalizePriorToSaving];
		
		NSSize imgSize = drawDat.drawing.drawingSize;

		CGImageRef anImage = [drawDat CGImageWithResolution:72 hasAlpha:YES relativeScale:scaleConstrainedFromSize(imgSize, maxSize)];
		if (anImage == NULL || QLThumbnailRequestIsCancelled(thumbnail)) {
			return noErr;
		}

		QLThumbnailRequestSetImage(thumbnail, anImage, NULL);
	}

	return noErr;
}

void CancelThumbnailGeneration(void *thisInterface, QLThumbnailRequestRef thumbnail)
{
    // Implement only if supported
}
