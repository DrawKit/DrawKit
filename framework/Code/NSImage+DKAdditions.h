/**
 * @author Graham Cox, Apptree.net
 * @author Graham Miln, miln.eu
 * @author Contributions from the community
 * @date 2005-2013
 * @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */
//
//  NSImage+DKAdditions.h
//  GCDrawKit
//
//  Created by Graham Cox on 9/04/10.
//  Copyright 2010 Apptree.net. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSImage (DKAdditions)

+ (NSImage*)	imageFromImage:(NSImage*) srcImage withSize:(NSSize) size;
+ (NSImage*)	imageFromImage:(NSImage*) srcImage withSize:(NSSize) size fraction:(CGFloat) opacity allowScaleUp:(BOOL) scaleUp;

@end
