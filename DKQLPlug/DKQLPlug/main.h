//
//  main.h
//  DKQLPlug
//
//  Created by C.W. Betts on 1/1/18.
//  Copyright © 2018 C.W. Betts. All rights reserved.
//

#ifndef main_h
#define main_h

#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>

#ifndef __private_extern
#define __private_extern __attribute((visibility("hidden")))
#endif

// The thumbnail generation function to be implemented in GenerateThumbnailForURL.c
__private_extern extern OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize);
__private_extern extern void CancelThumbnailGeneration(void* thisInterface, QLThumbnailRequestRef thumbnail);

// The preview generation function to be implemented in GeneratePreviewForURL.c
__private_extern extern OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options);
__private_extern extern void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview);

#endif /* main_h */
