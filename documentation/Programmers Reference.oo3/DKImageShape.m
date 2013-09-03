///**********************************************************************************************************************************
///  DKImageShape.m
///  DrawKit
///
///  Created by graham on 23/08/2006.
///  Released under the Creative Commons license 2006 Apptree.net.
///
/// 
///  This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 License.
///  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to
///  Creative Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105, USA.
///
///**********************************************************************************************************************************


#import "DKImageShape.h"
#import "DKObjectOwnerLayer.h"
#import "DKDrawableObject+Metadata.h"
#import "DKStyle.h"
#import "DKDrawableShape+Hotspots.h"
#import "DKDrawKitMacros.h"
#import "LogEvent.h"

#pragma mark Constants

NSString*	kDKOriginalFileMetadataKey				= @"dk_original_file";
NSString*	kDKOriginalImageDimensionsMetadataKey	= @"dk_image_original_dims";
NSString*	kDKOriginalNameMetadataKey				= @"dk_original_name";


@implementation DKImageShape
#pragma mark As a DKImageShape

///*********************************************************************************************************************
///
/// method:			initWithPasteboard
/// scope:			public instance method
/// overrides:		
/// description:	initializes the image shape from the pasteboard
/// 
/// parameters:		<pboard> a pasteboard
/// result:			the objet if it was successfully initialized, or nil
///
/// notes:			
///
///********************************************************************************************************************

- (id)						initWithPasteboard:(NSPasteboard*) pboard;
{
	NSImage*		image = nil;
	if ([NSImage canInitWithPasteboard:pboard])
	{
		image = [[[NSImage alloc] initWithPasteboard:pboard] autorelease];
	}
	if (image == nil)
	{
		[self autorelease];
		self = nil;
	}else
	{
		self = [self initWithImage:image];
		
		if ( self != nil )
		{
			NSString* urlType = [pboard availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]];
			
			if ( urlType != nil )
			{
				NSArray* files = (NSArray*)[pboard propertyListForType:NSFilenamesPboardType];
				
			//	LogEvent_(kReactiveEvent, @"dropped files = %@", files);
				
				NSString* path = [files objectAtIndex:0];
				
				// add this info to the metadata for the object
				
				[self setString:path forKey:kDKOriginalFileMetadataKey];
				[self setString:[[path lastPathComponent] stringByDeletingPathExtension] forKey:kDKOriginalNameMetadataKey];
			}
		}
	}
	return self;
}

#pragma mark -

///*********************************************************************************************************************
///
/// method:			initWithImage
/// scope:			public instance method, designated initializer
/// overrides:		
/// description:	initializes the image shape from an image
/// 
/// parameters:		<anImage> a valid image object
/// result:			the object if it was successfully initialized, or nil
///
/// notes:			the object's metdata also record's the image's original size
///
///********************************************************************************************************************

- (id)						initWithImage:(NSImage*) anImage
{
	NSAssert( anImage != nil, @"cannot init with a nil image");
	
	NSRect r = NSZeroRect;
	r.size = [anImage size];
	
	self = [super initWithRect:r];
	if (self != nil)
	{
		[self setImage:anImage];
		[self setImageOpacity:1.0];
		m_imageScale = 1.0;
		NSAssert(NSEqualPoints(m_imageOffset, NSZeroPoint), @"Expected init to zero");
		[self setImageDrawsOnTop:NO];
		[self setCompositingOperation:NSCompositeSourceAtop];
		[self setImageCroppingOptions:kDKImageScaleToPath];
		
		if (m_image == nil)
		{
			[self autorelease];
			self = nil;
		}
	}
	if (self != nil)
	{
		// initially images have a style with a clear fill. This suppresses the grey border that
		// is drawn when there is no style at all. Note that if this style is removed altogether, the object 
		// won't be "hittable", because the hit bitmap will be empty - the image is not currently drawn
		// into the hit bitmap.
		
		[self setStyle:[DKStyle styleWithFillColour:[NSColor clearColor] strokeColour:nil]];
		
		// set up a hotspot to handle the image offset dragging
		
		DKHotspot* hs = [[DKHotspot alloc] initHotspotWithOwner:self partcode:0 delegate:self];
		mImageOffsetPartcode = [self addHotspot:hs];
		[hs setRelativeLocation:NSZeroPoint];
		[hs release];
	}
	return self;
}


///*********************************************************************************************************************
///
/// method:			initWithImageNamed
/// scope:			public instance method
/// overrides:		
/// description:	initializes the image shape from an image
/// 
/// parameters:		<imageName> the name of an image
/// result:			the object if it was successfully initialized, or nil
///
/// notes:			the original name of the image is recorded in the object's metadata
///
///********************************************************************************************************************

- (id)						initWithImageNamed:(NSString*) imageName
{
	[self initWithImage:[NSImage imageNamed:imageName]];
	[self setString:imageName forKey:kDKOriginalNameMetadataKey];
	
	return self;
}


///*********************************************************************************************************************
///
/// method:			initWithContentsOfFile
/// scope:			public instance method
/// overrides:		
/// description:	initializes the image shape from an image file given by the path
/// 
/// parameters:		<filepath> the path to an image file on disk
/// result:			the object if it was successfully initialized, or nil
///
/// notes:			the original name and path of the image is recorded in the object's metadata
///
///********************************************************************************************************************

- (id)						initWithContentsOfFile:(NSString*) filepath
{
	NSImage* img = [[[NSImage alloc] initWithContentsOfFile:filepath] autorelease];
	
	[self initWithImage:img];
	
	[self setString:filepath forKey:kDKOriginalFileMetadataKey];
	[self setString:[[filepath lastPathComponent] stringByDeletingPathExtension] forKey:kDKOriginalNameMetadataKey];
	
	return self;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			setImage:
/// scope:			public instance method
/// overrides:		
/// description:	sets the object's image
/// 
/// parameters:		<anImage> an image to display in this shape.
/// result:			none
///
/// notes:			the shape's path, size, angle, etc. are not changed by this method
///
///********************************************************************************************************************

- (void)					setImage:(NSImage*) anImage
{
	NSAssert( anImage != nil, @"can't set a nil image");
	
	if ( anImage != [self image])
	{
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setImage:) object:[self image]];

		[anImage retain];
		[m_image release];
		m_image = anImage;
		[m_image setFlipped:YES];
		[self notifyVisualChange];
		
		// record image size in metadata
		
		[self setSize:[anImage size] forKey:kDKOriginalImageDimensionsMetadataKey];
	}
}


///*********************************************************************************************************************
///
/// method:			image
/// scope:			public instance method
/// overrides:		
/// description:	get the object's image
/// 
/// parameters:		none
/// result:			the image
///
/// notes:			
///
///********************************************************************************************************************

- (NSImage*)				image
{
	return m_image;
}


///*********************************************************************************************************************
///
/// method:			setImageWithPasteboard
/// scope:			public instance method
/// overrides:		
/// description:	set the object's image from image data on the pasteboard
/// 
/// parameters:		<pb> the pasteboard
/// result:			YES if the operation succeeded, NO otherwise
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)					setImageWithPasteboard:(NSPasteboard*) pb
{
	NSAssert( pb != nil, @"pasteboard is nil");
	
	if([NSImage canInitWithPasteboard:pb])
	{
		NSImage* image = [[NSImage alloc] initWithPasteboard:pb];
		
		if( image != nil )
		{
			[self setImage:image];
			[image release];
			
			return YES;
		}
	}
	
	return NO;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			setImageOpacity:
/// scope:			public instance method
/// overrides:		
/// description:	set the image's opacity
/// 
/// parameters:		<opacity> an opacity value from 0.0 (fully transparent) to 1.0 (fully opaque)
/// result:			none
///
/// notes:			the default is 1.0
///
///********************************************************************************************************************

- (void)					setImageOpacity:(float) opacity
{
	if ( opacity != m_opacity )
	{
		[[[self undoManager] prepareWithInvocationTarget:self] setImageOpacity:[self imageOpacity]];
		m_opacity = opacity;
		[self notifyVisualChange];
	}
}


///*********************************************************************************************************************
///
/// method:			imageOpacity
/// scope:			public instance method
/// overrides:		
/// description:	get the image's opacity
/// 
/// parameters:		none
/// result:			<opacity> an opacity value from 0.0 (fully transparent) to 1.0 (fully opaque)
///
/// notes:			default is 1.0
///
///********************************************************************************************************************

- (float)					imageOpacity
{
	return m_opacity;
}


///*********************************************************************************************************************
///
/// method:			setImageDrawsOnTop:
/// scope:			public instance method
/// overrides:		
/// description:	set whether the image draws above or below the rendering done by the style
/// 
/// parameters:		<onTop> YES to draw on top (after) the style, NO to draw below (before)
/// result:			none
///
/// notes:			default is NO
///
///********************************************************************************************************************

- (void)					setImageDrawsOnTop:(BOOL) onTop
{
	if ( onTop != [self imageDrawsOnTop])
	{
		[[[self undoManager] prepareWithInvocationTarget:self] setImageDrawsOnTop:[self imageDrawsOnTop]];
		m_drawnOnTop = onTop;
		[self notifyVisualChange];
	}
}


///*********************************************************************************************************************
///
/// method:			imageDrawsOnTop
/// scope:			public instance method
/// overrides:		
/// description:	whether the image draws above or below the rendering done by the style
/// 
/// parameters:		none
/// result:			YES to draw on top (after) the style, NO to draw below (before)
///
/// notes:			default is NO
///
///********************************************************************************************************************

- (BOOL)					imageDrawsOnTop
{
	return m_drawnOnTop;
}

///*********************************************************************************************************************
///
/// method:			setCompositingOperation:
/// scope:			public instance method
/// overrides:		
/// description:	set the Quartz composition mode to use when compositing the image
/// 
/// parameters:		<op> an NSCompositingOperation constant
/// result:			none
///
/// notes:			default is NSCompositeSourceAtop
///
///********************************************************************************************************************

- (void)					setCompositingOperation:(NSCompositingOperation) op
{
	if ( op != m_op )
	{
		[[[self undoManager] prepareWithInvocationTarget:self] setCompositingOperation:[self compositingOperation]];
		m_op = op;
		[self notifyVisualChange];
	}
}


///*********************************************************************************************************************
///
/// method:			compositingOperation
/// scope:			public instance method
/// overrides:		
/// description:	get the Quartz composition mode to use when compositing the image
/// 
/// parameters:		none 
/// result:			an NSCompositingOperation constant
///
/// notes:			default is NSCompositeSourceAtop
///
///********************************************************************************************************************

- (NSCompositingOperation)	compositingOperation
{
	return m_op;
}


///*********************************************************************************************************************
///
/// method:			setImageScale:
/// scope:			public instance method
/// overrides:		
/// description:	set the scale factor for the image
/// 
/// parameters:		<scale> a scaling value, 1.0 = 100% 
/// result:			none
///
/// notes:			this is not currently implemented - images scale to fit the bounds when in scale mode, and are
///					drawn at their native size in crop mode.
///
///********************************************************************************************************************

- (void)					setImageScale:(float) scale
{
	if ( scale != m_imageScale )
	{
		[[[self undoManager] prepareWithInvocationTarget:self] setImageScale:[self imageScale]];
		[self notifyVisualChange];
		m_imageScale = scale;
		[self notifyVisualChange];
	}
}


///*********************************************************************************************************************
///
/// method:			imageScale
/// scope:			public instance method
/// overrides:		
/// description:	get the scale factor for the image
/// 
/// parameters:		none 
/// result:			the scale
///
/// notes:			this is not currently implemented - images scale to fit the bounds when in scale mode, and are
///					drawn at their native size in crop mode.
///
///********************************************************************************************************************

- (float)					imageScale
{
	return m_imageScale;
}


///*********************************************************************************************************************
///
/// method:			setImageOffset:
/// scope:			public instance method
/// overrides:		
/// description:	set the offset position for the image
/// 
/// parameters:		<imgoff> the offset position 
/// result:			none
///
/// notes:			the default is 0,0. The value is the distance in points from the top, left corner of the shape's
///					bounds to the top, left corner of the image
///
///********************************************************************************************************************

- (void)					setImageOffset:(NSPoint) imgoff
{
	if ( ! NSEqualPoints( imgoff, m_imageOffset ))
	{
		[[[self undoManager] prepareWithInvocationTarget:self] setImageOffset:[self imageOffset]];
		[self notifyVisualChange];
		m_imageOffset = imgoff;
		[self notifyVisualChange];
	}
}


///*********************************************************************************************************************
///
/// method:			imageOffset
/// scope:			public instance method
/// overrides:		
/// description:	get the offset position for the image
/// 
/// parameters:		none
/// result:			the image offset
///
/// notes:			the default is 0,0. The value is the distance in points from the top, left corner of the shape's
///					bounds to the top, left corner of the image
///
///********************************************************************************************************************

- (NSPoint)					imageOffset
{
	return m_imageOffset;
}


///*********************************************************************************************************************
///
/// method:			setImageCroppingOptions:
/// scope:			public instance method
/// overrides:		
/// description:	set the display mode for the object - crop image or scale it
/// 
/// parameters:		<crop> a mode value
/// result:			none
///
/// notes:			the default is scale. 
///
///********************************************************************************************************************

- (void)					setImageCroppingOptions:(DKImageCroppingOptions) crop
{
	if ( crop != mImageCropping )
	{
		[[[self undoManager] prepareWithInvocationTarget:self] setImageCroppingOptions:[self imageCroppingOptions]];
		[self notifyVisualChange];
		mImageCropping = crop;
		[self notifyVisualChange];
	}	
}


///*********************************************************************************************************************
///
/// method:			imageCroppingOptions
/// scope:			public instance method
/// overrides:		
/// description:	get the display mode for the object - crop image or scale it
/// 
/// parameters:		none
/// result:			a mode value
///
/// notes:			the default is scale. 
///
///********************************************************************************************************************

- (DKImageCroppingOptions)	imageCroppingOptions
{
	return mImageCropping;
}



#pragma mark -
///*********************************************************************************************************************
///
/// method:			drawImage
/// scope:			private instance method
/// overrides:		
/// description:	draw the image applying all of the shape's settings
/// 
/// parameters:		none
/// result:			none
///
/// notes:			 
///
///********************************************************************************************************************

- (void)					drawImage
{
	// the image must be transformed to the object's scale, rotation and position. This is achieved by concatenating the transform
	// to the current graphics context.
	
	[NSGraphicsContext saveGraphicsState];
	
	NSAffineTransform*	xt = [self containerTransform];
	
	[[self transformedPath] addClip];
	
	NSAffineTransform*  tx = [self imageTransform];
	[tx appendTransform:xt];
	[tx concat];
	
	NSRect ir;
	
	ir.size = [[self image] size];
	
	if([self imageCroppingOptions] == kDKImageScaleToPath)
	{
		ir.origin.x = m_imageOffset.x - ( ir.size.width / 2.0 );
		ir.origin.y = m_imageOffset.y - ( ir.size.height / 2.0 );
	}
	else
	{
		ir.origin.x = m_imageOffset.x;
		ir.origin.y = m_imageOffset.y;
	}
	
	[[self image]	drawInRect:ir
					fromRect:NSZeroRect
					operation:[self compositingOperation]
					fraction:[self imageOpacity]];
	
	[NSGraphicsContext restoreGraphicsState];
}


///*********************************************************************************************************************
///
/// method:			imageTransform
/// scope:			private instance method
/// overrides:		
/// description:	return a transform that can be used to position, size and rotate the image to the shape
/// 
/// parameters:		none
/// result:			a transform
///
/// notes:			a separate transform is necessary because trying to use the normal shape transform and rendering the
///					image into a unit square results in some very visible rounding errors. Instead the image is
///					transformed independently from its orginal size directly to the final size, so the errors are
///					eliminated.
///
///********************************************************************************************************************

- (NSAffineTransform*)		imageTransform
{
	NSSize	si = [[self image] size];
	NSSize	sc = [self size];
	float	sx, sy;
	NSPoint loc;

	NSAffineTransform* xform = [NSAffineTransform transform];
	
	if([self imageCroppingOptions] == kDKImageScaleToPath)
	{
		si.width /= [self imageScale];
		si.height /= [self imageScale];
		sx = sc.width / si.width;
		sy = sc.height / si.height;
		loc = [self location];
		[xform translateXBy:loc.x yBy:loc.y];
		[xform rotateByRadians:[self angle]];
		
		if( sx != 0.0 && sy != 0.0 )
			[xform scaleXBy:sx yBy:sy];
		
		[xform translateXBy:-[self offset].width * si.width yBy:-[self offset].height * si.height];
	}
	else
	{
		// cropping is based on the top, left point not the centre
		// TO DO - doesn't take into account flipped shape correctly
		
		loc = [self locationIgnoringOffset];
		
		[xform translateXBy:loc.x yBy:loc.y];
		[xform rotateByRadians:[self angle]];
		[xform translateXBy:(-0.5 * sc.width) yBy:(-0.5 * sc.height)];
	}
		
		
	return xform;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			selectCropOrScaleAction:
/// scope:			public action method
/// overrides:		
/// description:	select whether the object displays using crop or scale modes
/// 
/// parameters:		<sender> the message sender
/// result:			none
///
/// notes:			this action method uses the sender's tag value as the cropping mode to set. It can be connected
///					directly to a menu item with a suitable tag set for example.
///
///********************************************************************************************************************

- (IBAction)				selectCropOrScaleAction:(id) sender
{
	DKImageCroppingOptions opt = (DKImageCroppingOptions)[sender tag];
	
	if ( opt != [self imageCroppingOptions])
	{
		[self setImageCroppingOptions:opt];
	
		if ( opt == kDKImageScaleToPath )
			[[self undoManager] setActionName:NSLocalizedString(@"Scale Image To Path", @"undo string for scale image to path")];
		else
			[[self undoManager] setActionName:NSLocalizedString(@"Crop Image To Path", @"undo string for crop image to path")];
	}
}


///*********************************************************************************************************************
///
/// method:			toggleImageAboveAction:
/// scope:			public action method
/// overrides:		
/// description:	toggle between image drawn on top and image drawn below the rest of the style
/// 
/// parameters:		<sender> the message sender
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (IBAction)				toggleImageAboveAction:(id) sender
{
	// user action permits the image on top setting to be flipped
	
	#pragma unused(sender)
	
	[self setImageDrawsOnTop:![self imageDrawsOnTop]];
	[[self undoManager] setActionName:NSLocalizedString(@"Image On Top", @"undo string for image on top")];
}


///*********************************************************************************************************************
///
/// method:			pasteImage:
/// scope:			public action method
/// overrides:		
/// description:	replace the shape's image with one from the pasteboard if possible.
/// 
/// parameters:		<sender> the message sender
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (IBAction)				pasteImage:(id) sender
{
	#pragma unused(sender)
	
	NSPasteboard* pb = [NSPasteboard generalPasteboard];
	if([self setImageWithPasteboard:pb])
	{
		[[self undoManager] setActionName:NSLocalizedString(@"Paste Image Into Shape", @"undo string for paste image into shape")];
	}
}


///*********************************************************************************************************************
///
/// method:			fitToImage:
/// scope:			public action method
/// overrides:		
/// description:	resizes the shape to exactly fit the image at its original size.
/// 
/// parameters:		<sender> the message sender
/// result:			none
///
/// notes:			cropped images remain in the same visual location that they are currently at, with the shape's
///					frame moved to fit around it exactly. Scaled images are resized to the original size and the object's
///					location remains the same. A side effect is to reset any offset, image offset, but not the angle.
///
///********************************************************************************************************************

- (IBAction)				fitToImage:(id) sender
{
	#pragma unused(sender)
	
	if([self imageCroppingOptions] == kDKImageScaleToPath)
	{
		[self setImageOffset:NSZeroPoint];
		[self setSize:[[self image] size]];
	}
	else
	{
		// where is the top, left corner of the image?
		
		NSAffineTransform* tfm = [self imageTransform];
		NSPoint p = [self imageOffset];
		
		p = [tfm transformPoint:p];
		
		// this is where the new top, left corner of the bounds needs to be
		// reset any offset to the centre
		
		[self setOffset:NSZeroSize];
		[self setSize:[[self image] size]];
		[self setImageOffset:NSZeroPoint];
		
		// the rotation isn't reset - take it into account
		
		tfm = [self transform];
		NSPoint topLeft = [tfm transformPoint:NSMakePoint( -0.5, -0.5 )];
		
		[self moveByX:p.x - topLeft.x byY:p.y - topLeft.y];
	}
	[[self hotspotForPartCode:mImageOffsetPartcode] setRelativeLocation:NSZeroPoint];
	[[self undoManager] setActionName:NSLocalizedString(@"Fit To Image", @"undo string for fit to image")];
}




#pragma mark -
#pragma mark As a DKDrawableObject
///*********************************************************************************************************************
///
/// method:			drawContent
/// scope:			public action method
/// overrides:		DKDrawableObject
/// description:	draws the object
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				drawContent
{
	if ( ![self imageDrawsOnTop])
		[self drawImage];
		
	[super drawContent];
	
	if ([self imageDrawsOnTop])
		[self drawImage];
}


///*********************************************************************************************************************
///
/// method:			populateContextualMenu
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	add contextual menu items pertaining to the current object's context
/// 
/// parameters:		<themenu> a menu object to add items to
/// result:			YES
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)					populateContextualMenu:(NSMenu*) theMenu
{
	[super populateContextualMenu:theMenu];
	
	[theMenu addItem:[NSMenuItem separatorItem]];
	
	[[theMenu addItemWithTitle:NSLocalizedString(@"Fit To Image", @"menu item for fit to image") action:@selector(fitToImage:) keyEquivalent:@""] setTarget:self];
	
	if([NSImage canInitWithPasteboard:[NSPasteboard generalPasteboard]])
		[[theMenu addItemWithTitle:NSLocalizedString(@"Paste Image", @"menu item for Paste Image") action:@selector(pasteImage:) keyEquivalent:@""] setTarget:self];
		
	return YES;
}


- (NSString*)			undoActionNameForPartCode:(int) pc
{
	if( pc == mImageOffsetPartcode )
		return NSLocalizedString( @"Move Image Origin", @"undo string for move image origin" );
	else
		return [super undoActionNameForPartCode:pc];
}


#pragma mark -
#pragma mark As an NSObject
///*********************************************************************************************************************
///
/// method:			dealloc
/// scope:			public action method
/// overrides:		NSObject
/// description:	deallocates the object
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				dealloc
{
	[m_image release];
	[super dealloc];
}


#pragma mark -
#pragma mark As part of the DKHotspotDelegate protocol


///*********************************************************************************************************************
///
/// method:			hotspot:willBeginTrackingWithEvent:inView:
/// scope:			hotspot delegate callback method
/// overrides:		
/// description:	saves the current cursor and sets the hand cursor
/// 
/// parameters:		<hs> the hotspot hit
///					<event> the mouse down event
///					<view> the currentview
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				hotspot:(DKHotspot*) hs willBeginTrackingWithEvent:(NSEvent*) event inView:(NSView*) view
{
	#pragma unused(hs)
	#pragma unused(event)
	#pragma unused(view)

	[[NSCursor currentCursor] push];
	
	int pc = [hs partcode];
	
	if ( pc == mImageOffsetPartcode )
	{
		[[NSCursor openHandCursor] set];
	}
}


///*********************************************************************************************************************
///
/// method:			hotspot:isTrackingWithEvent:inView:
/// scope:			hotspot delegate callback method
/// overrides:		
/// description:	moves the hotspot to a new place dragging the image offset with it
/// 
/// parameters:		<hs> the hotspot hit
///					<event> the mouse down event
///					<view> the currentview
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				hotspot:(DKHotspot*) hs isTrackingWithEvent:(NSEvent*) event inView:(NSView*) view
{
	int pc = [hs partcode];
	
	if ( pc == mImageOffsetPartcode )
	{
		[[NSCursor closedHandCursor] set];
		
		NSPoint p = [view convertPoint:[event locationInWindow] fromView:nil];
		
		NSPoint offset;
		
		p = [[self inverseTransform] transformPoint:p];
		
		p.x = LIMIT( p.x, -0.5, 0.5 );
		p.y = LIMIT( p.y, -0.5, 0.5 );
		[hs setRelativeLocation:p];
		[self notifyVisualChange];

		offset.x = p.x * [[self image] size].width;
		offset.y = p.y * [[self image] size].height;
		[self setImageOffset:offset];
	}
}


///*********************************************************************************************************************
///
/// method:			hotspot:didEndTrackingWithEvent:inView:
/// scope:			hotspot delegate callback method
/// overrides:		
/// description:	restores hte cursor
/// 
/// parameters:		<hs> the hotspot hit
///					<event> the mouse down event
///					<view> the currentview
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				hotspot:(DKHotspot*) hs didEndTrackingWithEvent:(NSEvent*) event inView:(NSView*) view
{
	#pragma unused(hs)
	#pragma unused(event)
	#pragma unused(view)
	
	[NSCursor pop];
}


#pragma mark -
#pragma mark As part of NSDraggingDestination protocol

///*********************************************************************************************************************
///
/// method:			performDragOperation:
/// scope:			NSDraggingDestination method
/// overrides:		
/// description:	receive a drag onto this object
/// 
/// parameters:		<sender> the drag sender
/// result:			YES if the operation could be carried out, NO otherwise
///
/// notes:			DK allows images to be simply dragged right into an existing image shape, replacing the current image
///
///********************************************************************************************************************

- (BOOL)				performDragOperation:(id <NSDraggingInfo>) sender
{
	NSPasteboard* pb = [sender draggingPasteboard];
	
	if([self setImageWithPasteboard:pb])
		return YES;
	else
		return [super performDragOperation:sender];
}


#pragma mark -
#pragma mark As part of NSCoding Protocol

///*********************************************************************************************************************
///
/// method:			encodeWithCoder:
/// scope:			NSCoding method
/// overrides:		
/// description:	archive the object
/// 
/// parameters:		<coder> a coder
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)		encodeWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];
	
	[coder encodeObject:[self image] forKey:@"image"];
	[coder encodeFloat:[self imageOpacity] forKey:@"imageOpacity"];
	[coder encodeFloat:[self imageScale] forKey:@"imageScale"];
	[coder encodePoint:[self imageOffset] forKey:@"imageOffset"];
	[coder encodeBool:[self imageDrawsOnTop] forKey:@"imageOnTop"];
	[coder encodeInt:[self compositingOperation] forKey:@"imageComp"];
	[coder encodeInt:[self imageCroppingOptions] forKey:@"DKImageShape_croppingOptions"];
}


///*********************************************************************************************************************
///
/// method:			initWithCoder:
/// scope:			NSCoding method
/// overrides:		
/// description:	dearchive the object
/// 
/// parameters:		<coder> a coder
/// result:			the object
///
/// notes:			
///
///********************************************************************************************************************

- (id)			initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super initWithCoder:coder];
	if (self != nil)
	{
		[self setImage:[coder decodeObjectForKey:@"image"]];
		[self setImageOpacity:[coder decodeFloatForKey:@"imageOpacity"]];
		[self setImageScale:[coder decodeFloatForKey:@"imageScale"]];
		[self setImageOffset:[coder decodePointForKey:@"imageOffset"]];
		[self setImageDrawsOnTop:[coder decodeBoolForKey:@"imageOnTop"]];
		[self setCompositingOperation:[coder decodeIntForKey:@"imageComp"]];
		[self setImageCroppingOptions:[coder decodeIntForKey:@"DKImageShape_croppingOptions"]];
		
		mImageOffsetPartcode = [[[self hotspots] lastObject] partcode];
		
		if (m_image == nil)
		{
			[self autorelease];
			self = nil;
		}
	}
	return self;
}


#pragma mark -
#pragma mark As part of NSCopying Protocol
///*********************************************************************************************************************
///
/// method:			copyWithZone:
/// scope:			NSCopying method
/// overrides:		
/// description:	copy the object
/// 
/// parameters:		<zone> a zone
/// result:			a copy of the object
///
/// notes:			
///
///********************************************************************************************************************

- (id)			copyWithZone:(NSZone*) zone
{
	DKImageShape* copy = [super copyWithZone:zone];

	[copy setImage:[self image]];
	[copy setImageOpacity:[self imageOpacity]];
	[copy setImageScale:[self imageScale]];
	[copy setImageOffset:[self imageOffset]];
	[copy setImageDrawsOnTop:[self imageDrawsOnTop]];
	[copy setCompositingOperation:[self compositingOperation]];
	[copy setImageCroppingOptions:[self imageCroppingOptions]];
	
	copy->mImageOffsetPartcode = mImageOffsetPartcode;
	[[copy hotspotForPartCode:mImageOffsetPartcode] setDelegate:copy];
	
	return copy;
}

#pragma mark -
#pragma mark As part of NSMenuValidation Protocol

///*********************************************************************************************************************
///
/// method:			validateMenuItem:
/// scope:			NSMenuValidation method
/// overrides:		
/// description:	enable menu items this object can respond to
/// 
/// parameters:		<item> the menu item
/// result:			YES if the item is enabled, NO otherwise
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)			validateMenuItem:(NSMenuItem*) item
{
	BOOL	enable = NO;
	
	if ([item action] == @selector(vectorize:) ||
		[item action] == @selector(fitToImage:))
		enable = ![self locked];
	else if([item action] == @selector(selectCropOrScaleAction:))
	{
		enable = ![self locked];
		[item setState:([item tag] == (int)[self imageCroppingOptions])? NSOnState : NSOffState];
	}
	else if ([item action] == @selector(toggleImageAboveAction:))
	{
		enable = ![self locked];
		[item setState:[self imageDrawsOnTop]? NSOnState : NSOffState];
	}
	else if([item action] == @selector(pasteImage:))
	{
		enable = [NSImage canInitWithPasteboard:[NSPasteboard generalPasteboard]] && ![self locked];
	}

	enable |= [super validateMenuItem:item];
	
	return enable;
}

@end
