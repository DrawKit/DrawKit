///**********************************************************************************************************************************
///  DKImageShape.m
///  DrawKit ¬©2005-2008 Apptree.net
///
///  Created by graham on 23/08/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************


#import "DKImageShape.h"
#import "DKImageShape+Vectorization.h"
#import "DKObjectOwnerLayer.h"
#import "DKDrawableObject+Metadata.h"
#import "DKStyle.h"
#import "DKDrawableShape+Hotspots.h"
#import "DKDrawKitMacros.h"
#import "LogEvent.h"
#import "DKDrawing.h"
#import "DKImageDataManager.h"
#import "DKKeyedUnarchiver.h"

#pragma mark Constants

NSString*	kDKOriginalFileMetadataKey				= @"dk_original_file";
NSString*	kDKOriginalImageDimensionsMetadataKey	= @"dk_image_original_dims";
NSString*	kDKOriginalNameMetadataKey				= @"dk_original_name";

@interface DKImageShape (Private)

- (NSAffineTransform*)		imageTransformWithoutLocation;
- (NSAffineTransform*)		imageTransform;
- (void)					drawImage;


@end


@implementation DKImageShape
#pragma mark As a DKImageShape

+ (DKStyle*)				imageShapeDefaultStyle
{
	return [DKStyle styleWithFillColour:[NSColor clearColor] strokeColour:nil];
}

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
	
	self = [super initWithRect:r style:[[self class] imageShapeDefaultStyle]];
	if (self != nil)
	{
		[self setImage:anImage];
		[self setImageOpacity:1.0];
		m_imageScale = 1.0;

		[self setImageDrawsOnTop:NO];
		[self setCompositingOperation:NSCompositeSourceOver];
		[self setImageCroppingOptions:kDKImageScaleToPath];
		
		DKHotspot* hs = [[DKHotspot alloc] initHotspotWithOwner:self partcode:0 delegate:self];
		mImageOffsetPartcode = [self addHotspot:hs];
		[hs setRelativeLocation:NSZeroPoint];
		[hs release];

		if (m_image == nil)
		{
			[self autorelease];
			self = nil;
		}
	}

	return self;
}


///*********************************************************************************************************************
///
/// method:			initWithImageData:
/// scope:			public instance method
/// overrides:		
/// description:	initializes the image shape from image data
/// 
/// parameters:		<imageData> image data of some kind
/// result:			the object if it was successfully initialized, or nil
///
/// notes:			this method is preferred where data is available as it allows the original data to be cached
///					very efficiently by the document's image data manager. This maintains quality and keeps file
///					sizes to a minimum.
///
///********************************************************************************************************************

- (id)						initWithImageData:(NSData*) imageData
{
	NSAssert( imageData != nil, @"cannot initialise with nil data");
	
	NSImage* image = [[NSImage alloc] initWithData:imageData];
	
	if( image )
	{
		self = [self initWithImage:image];
		[image release];
		
		if( self )
			[self setImageData:imageData];
	}
	else
	{
		[self autorelease];
		self = nil;
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
/// notes:			the original name and path of the image is recorded in the object's metadata. This extracts the
///					original data which allows the image to be efficiently stored.
///
///********************************************************************************************************************

- (id)						initWithContentsOfFile:(NSString*) filepath
{
	NSAssert( filepath != nil, @"path was nil");
	
	NSData* data = [NSData dataWithContentsOfFile:filepath];
	
	if( data )
	{
		self = [self initWithImageData:data];
		
		if( self )
		{
			[self setString:filepath forKey:kDKOriginalFileMetadataKey];
			[self setString:[[filepath lastPathComponent] stringByDeletingPathExtension] forKey:kDKOriginalNameMetadataKey];
		}
	}
	else
	{
		[self autorelease];
		self = nil;
	}
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
		
		[m_image setCacheMode:NSImageCacheNever];
		[m_image recache];
		[m_image setScalesWhenResized:YES];
		[self notifyVisualChange];
		
		// setting the image nils the key. Callers that know there is a key should use setImageWithKey:coder: instead.
		
		[mImageKey release];
		mImageKey = nil;

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
/// method:			imageAtRenderedSize
/// scope:			public instance method
/// overrides:		
/// description:	get a copy of the object's image scaled to the same size, angle and aspect ratio as the image drawn
/// 
/// parameters:		none
/// result:			the image
///
/// notes:			this also applies the path clipping, if any
///
///********************************************************************************************************************

- (NSImage*)				imageAtRenderedSize
{
	NSCompositingOperation savedOp = [self compositingOperation];
	NSSize	 niSize = [self logicalBounds].size;
	NSImage* newImage = [[NSImage alloc] initWithSize:niSize];
	
	if( newImage != nil )
	{
		[self setCompositingOperation:NSCompositeCopy];
		[newImage lockFocus];
		
		CGFloat dx, dy;
		
		dx = niSize.width * 0.5f;
		dy = niSize.height * 0.5f;
		
		NSAffineTransform* tfm = [NSAffineTransform transform];
		[tfm translateXBy:-([self location].x - dx) yBy:-([self location].y - dy)];
		[tfm concat];
		
		[self drawImage];
		[newImage unlockFocus];
	}
	
	[self setCompositingOperation:savedOp];
	return [newImage autorelease];

}




///*********************************************************************************************************************
///
/// method:			setImageWithKey:
/// scope:			public instance method
/// overrides:		
/// description:	set the object's image from image data in the drawing's image data manager
/// 
/// parameters:		<key> the image's key
///					<coder> the dearchiver in use, if any.
/// result:			none
///
/// notes:			The object must usually have been added to a drawing before this is called, so that it can locate the
///					image data manager to use. However, during dearchiving this isn't the case so the coder itself can
///					return a reference to the image manager.
///
///********************************************************************************************************************

- (void)					setImageWithKey:(NSString*) key coder:(NSCoder*) coder
{
	if(![key isEqualToString:[self imageKey]])
	{
		DKImageDataManager* dm;
		
		if( coder && [coder respondsToSelector:@selector(imageManager)])
			dm = [(DKKeyedUnarchiver*)coder imageManager];
		else
			dm = [[self container] imageManager];
		
		if( dm )
		{
			NSLog(@"image shape %@ loading image from image manager, key = %@", self, key );
			
			NSImage* image = [dm makeImageForKey:key];
			
			if( image )
			{
				[key retain];
				[self setImage:image];	// releases key and sets it to nil
				mImageKey = key;
			}
		}
	}
}


///*********************************************************************************************************************
///
/// method:			setImageKey:
/// scope:			public instance method
/// overrides:		
/// description:	set the object's image key
/// 
/// parameters:		<key> the image's key
/// result:			none
///
/// notes:			This is called by other methods as necessary. It currently simply retains the key.
///
///********************************************************************************************************************

- (void)					setImageKey:(NSString*) key
{
	[key retain];
	[mImageKey release];
	mImageKey = key;
}


///*********************************************************************************************************************
///
/// method:			imageKey
/// scope:			public instance method
/// overrides:		
/// description:	return the object's image key
/// 
/// parameters:		none 
/// result:			the image's key
///
/// notes:			
///
///********************************************************************************************************************

- (NSString*)				imageKey
{
	return mImageKey;
}


///*********************************************************************************************************************
///
/// method:			transferImageKeyToNewContainer:
/// scope:			public instance method
/// overrides:		
/// description:	transfer the image key when the object is added to a new container
/// 
/// parameters:		<container> the new container 
/// result:			none
///
/// notes:			called as necessary by other methods
///
///********************************************************************************************************************

- (void)					transferImageKeyToNewContainer:(id<DKDrawableContainer>) container
{
	// when an image shape has a new container, image data may need to be transferred to it. This is called
	// by setContainer: and usually is not needed by apps.
	
	if( container )
	{
		NSAssert2([container conformsToProtocol:@protocol(DKDrawableContainer)], @"container (%@) passed to %@ does not conform to the DKDrawableContainer protocol", container, self );
		
		DKImageDataManager* newIM = [container imageManager];
		NSData* imageData = [self imageData];
		
		if( newIM && imageData )
		{
			//NSLog(@"transferring image data (%d bytes) to new IM: %@", [imageData length], newIM );
			
			// does new IM know about this data? If so, simply keep a note of the key and use its copy of the data.
			// If not, add our copy of the data to it and get a new key if we need one. There is only ever one copy of the
			// image data no matter how many image shapes use it across any number of documents, etc.
			
			NSString* key = [newIM keyForImageData:imageData];
			
			if( key )
			{
				imageData = [[newIM imageDataForKey:key] retain];
				[mOriginalImageData release];
				mOriginalImageData = imageData;
				[self setImageKey:key];
				
				//NSLog(@"image data was found in new IM, updated key: %@", key );
			}
			else
			{
				key = [self imageKey];
				
				if( key == nil )
					key = [newIM generateKey];
				
				[newIM setImageData:imageData forKey:key];
				[self setImageKey:key];
				
				//NSLog(@"image data was added to new IM, key: %@", key );
			}
		}
	}
}



///*********************************************************************************************************************
///
/// method:			setImageData:
/// scope:			public instance method
/// overrides:		
/// description:	sets the image from data
/// 
/// parameters:		<data> data containing image data 
/// result:			none
///
/// notes:			This method liases with the image manager so that the image key is correctly recorded or assigned
///					as needed.
///
///********************************************************************************************************************

- (void)					setImageData:(NSData*) data
{
	[data retain];
	[mOriginalImageData release];
	mOriginalImageData = data;
	
	// link up with the image manager - if it already knows the data it will return a key for it, otherwise a new key
	// if there is no image manager, create an image anyway, retain the data but don't create a key.
	
	DKImageDataManager* imgMgr = [[self container] imageManager];
	NSImage* image;
	
	if( imgMgr )
	{
		NSString* key;
		image = [imgMgr makeImageWithData:data key:&key];
		
		[self setImage:image];
		[self setImageKey:key];
	}
	else
	{
		image = [[NSImage alloc] initWithData:data];
		[self setImage:image];
		[image release];
	}
}


///*********************************************************************************************************************
///
/// method:			imageData
/// scope:			public instance method
/// overrides:		
/// description:	returns the image original data
/// 
/// parameters:		
/// result:			data containing image data
///
/// notes:			This returns either the locally retained original data, or the data held by the image manager. In
///					either case the data returned is the original data from which the image was created. If the image
///					was set directly and not from data, and the key is unknown to the image manager, returns nil.
///
///********************************************************************************************************************

- (NSData*)					imageData
{
	if( mOriginalImageData == nil )
		mOriginalImageData = [[[[self container] imageManager] imageDataForKey:[self imageKey]] retain];

	return mOriginalImageData;
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
/// notes:			this first tries to use the image data manager to handle the pasteboard, so that the image is
///					efficiently cached. If that doesn't work, falls back to the original direct approach.
///
///********************************************************************************************************************

- (BOOL)					setImageWithPasteboard:(NSPasteboard*) pb
{
	NSAssert( pb != nil, @"pasteboard is nil");
	
	DKImageDataManager* dm = [[self container] imageManager];
	
	if( dm )
	{
		NSString* newKey = nil;
		NSImage* image = [dm makeImageWithPasteboard:pb key:&newKey];
		
		if( image )
		{
			[image setScalesWhenResized:YES];
			[image setCacheMode:NSImageCacheNever];
			
			// keep a local reference to the data if possible
			
			NSData* imgData = [dm imageDataForKey:newKey];
			[imgData retain];
			[mOriginalImageData release];
			mOriginalImageData = imgData;
			
			[self setImage:image];
			[self setImageKey:newKey];
			
			return YES;
		}
	}
	
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



///*********************************************************************************************************************
///
/// method:			writeImageToPasteboard:
/// scope:			public instance method
/// overrides:		
/// description:	place the object's image data on the pasteboard
/// 
/// parameters:		<pb> the pasteboard
/// result:			YES if the operation succeeded, NO otherwise
///
/// notes:			adds the image data in a variety of forms to the pasteboard - raw data (as file content type)
///					TIFF and PDF formats.
///
///********************************************************************************************************************

- (BOOL)					writeImageToPasteboard:(NSPasteboard*) pb
{
	NSAssert( pb != nil, @"cannot write to nil pasteboard");
	
	BOOL result = NO;
	
	[pb declareTypes:[NSArray arrayWithObjects:NSFileContentsPboardType, NSTIFFPboardType, NSPDFPboardType, nil] owner:self];
	
	NSData* imgData = [self imageData];
	if( imgData )
		result = [pb setData:imgData forType:NSFileContentsPboardType];
	
	NSImage* image = [self image];
	if( image )
	{
		imgData = [image TIFFRepresentation];
		result |= [pb setData:imgData forType:NSTIFFPboardType];
		
		// look for PDF data
		
		NSEnumerator* iter = [[image representations] objectEnumerator];
		NSImageRep*		rep;
		
		while(( rep = [iter nextObject]))
		{
			if([rep respondsToSelector:@selector(PDFRepresentation)])
			{
				imgData = [(NSPDFImageRep*)rep PDFRepresentation];
				result |= [pb setData:imgData forType:NSPDFPboardType];
				break;
			}
		}
	}
	
	return result;
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

- (void)					setImageOpacity:(CGFloat) opacity
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

- (CGFloat)					imageOpacity
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

- (void)					setImageScale:(CGFloat) scale
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

- (CGFloat)					imageScale
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
	
	SAVE_GRAPHICS_CONTEXT		//[NSGraphicsContext saveGraphicsState];
	
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
	
	// render at high quality
	
	[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
	[[self image] setFlipped:[[NSGraphicsContext currentContext] isFlipped]];
	
	[[self image]	drawInRect:ir
					fromRect:NSZeroRect
					operation:[self compositingOperation]
					fraction:[self imageOpacity]];
	
	RESTORE_GRAPHICS_CONTEXT	//[NSGraphicsContext restoreGraphicsState];
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
	NSAffineTransform*	tfm = [NSAffineTransform transform];
	NSAffineTransform*	twl = [self imageTransformWithoutLocation];
	NSPoint				loc;
	
	if([self imageCroppingOptions] == kDKImageScaleToPath)
		loc = [self location];
	else
		loc = [self locationIgnoringOffset];
	
	[tfm translateXBy:loc.x yBy:loc.y];
	[twl appendTransform:tfm];
	return twl;
}


- (NSAffineTransform*)		imageTransformWithoutLocation
{
	NSSize	si = [[self image] size];
	NSSize	sc = [self size];
	CGFloat	sx, sy;

	NSAffineTransform* xform = [NSAffineTransform transform];
	
	if([self imageCroppingOptions] == kDKImageScaleToPath)
	{
		si.width /= [self imageScale];
		si.height /= [self imageScale];
		sx = sc.width / si.width;
		sy = sc.height / si.height;
		
		[xform rotateByRadians:[self angle]];
		
		if( sx != 0.0 && sy != 0.0 )
			[xform scaleXBy:sx yBy:sy];
		
		[xform translateXBy:-[self offset].width * si.width yBy:-[self offset].height * si.height];
	}
	else
	{
		// cropping is based on the top, left point not the centre
		// TO DO - doesn't take into account flipped shape correctly
		
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
/// method:			copyImage:
/// scope:			public action method
/// overrides:		
/// description:	copy the image directly to the pasteboard.
/// 
/// parameters:		<sender> the message sender
/// result:			none
///
/// notes:			A normal "Copy" does place an image of the object on the pb, but that is the whole object with
///					all style elements based on the bounds. For some work, such as uing images for pattern fills,
///					that's not appropriate, so this action allows you to extract the internal image.
///
///********************************************************************************************************************

- (IBAction)				copyImage:(id) sender
{
#pragma unused(sender)
	
	[self writeImageToPasteboard:[NSPasteboard generalPasteboard]];
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
		
		NSSize is = [[self image] size];
		
		is.width *= [self imageScale];
		is.height *= [self imageScale];
		[self setImageScale:1.0];
		[self setSize:is];
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
		
		[self offsetLocationByX:p.x - topLeft.x byY:p.y - topLeft.y];
	}
	[[self hotspotForPartCode:mImageOffsetPartcode] setRelativeLocation:NSZeroPoint];
	[[self undoManager] setActionName:NSLocalizedString(@"Fit To Image", @"undo string for fit to image")];
}




#pragma mark -
#pragma mark As a DKDrawableObject
///*********************************************************************************************************************
///
/// method:			drawContentWithStyle:
/// scope:			public instance method
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
	if([self isBeingHitTested])
	{
		[[NSColor grayColor] set];
		[[self renderingPath] fill];
	}
	else
	{
		if ( ![self imageDrawsOnTop])
			[self drawImage];
			
		[super drawContent];
		
		if ([self imageDrawsOnTop])
			[self drawImage];
	}
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
	[[theMenu addItemWithTitle:NSLocalizedString(@"Copy Image", @"menu item for copy image") action:@selector(copyImage:) keyEquivalent:@""] setTarget:self];
	
	if([NSImage canInitWithPasteboard:[NSPasteboard generalPasteboard]])
		[[theMenu addItemWithTitle:NSLocalizedString(@"Paste Image", @"menu item for Paste Image") action:@selector(pasteImage:) keyEquivalent:@""] setTarget:self];
		
	return YES;
}


- (NSString*)			undoActionNameForPartCode:(NSInteger) pc
{
	if( pc == mImageOffsetPartcode )
		return NSLocalizedString( @"Move Image Origin", @"undo string for move image origin" );
	else
		return [super undoActionNameForPartCode:pc];
}



- (void)			setContainer:(id<DKDrawableContainer>) container
{
	// when an image shape is transferred to a new container, and it is using an image key, the data must be copied from the old image manager
	// to the image manager of the new container, to maintain data integrity when the object is subsequently archived. Otherwise the image
	// may get "lost" and the shape will be unable to be dearchived.
	
	[self transferImageKeyToNewContainer:container];
	[super setContainer:container];
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
	[mImageKey release];
	[mOriginalImageData release];
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
	
	NSInteger pc = [hs partcode];
	
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
	NSInteger pc = [hs partcode];
	
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
	
	// if there's an image key, just archive that and the data instead of the expanded image itself. The image can then be efficiently
	// recovered from the image data cache using the key. The data itself is also archived, though only one copy is actually saved.
	// This allows us to recover the image under all circumstances
	
	if( mImageKey )
	{
		[coder encodeObject:[self imageKey] forKey:@"DKImageShape_imageKey"];
		[coder encodeObject:[self imageData] forKey:@"DKImageShape_imageData"];
	}
	else
		[coder encodeObject:[self image] forKey:@"image"];
	
	[coder encodeDouble:[self imageOpacity] forKey:@"imageOpacity"];
	[coder encodeDouble:[self imageScale] forKey:@"imageScale"];
	[coder encodePoint:[self imageOffset] forKey:@"imageOffset"];
	[coder encodeBool:[self imageDrawsOnTop] forKey:@"imageOnTop"];
	[coder encodeInteger:[self compositingOperation] forKey:@"imageComp"];
	[coder encodeInteger:[self imageCroppingOptions] forKey:@"DKImageShape_croppingOptions"];
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
		// first see if an image key was archived. If so, we can recover our image from the image archive. If not,
		// load the original archived image.
		
		NSString* imKey = [coder decodeObjectForKey:@"DKImageShape_imageKey"];
		
		if( imKey )
		{
			// if we have a ref to the image data itself, initialise using that - it's much more straightforward
			// than trying to determine which image manager to use in every case. Older files don't have this (b6 onwards).
			// This recovers the image even if we have no container, etc. If a container is later set, the image data is
			// consolidated with whatever image manager is in use for the container.
			
			NSData* imgData = [coder decodeObjectForKey:@"DKImageShape_imageData"];
			
			if( imgData )
				[self setImageData:imgData];
			else
			{
				// older method: create image from original data in the master cache & store the key
			
				[self setImageWithKey:imKey coder:coder];
			}
		}
		else
			[self setImage:[coder decodeObjectForKey:@"image"]];
		
		[self setImageOpacity:[coder decodeDoubleForKey:@"imageOpacity"]];
		[self setImageScale:[coder decodeDoubleForKey:@"imageScale"]];
		[self setImageOffset:[coder decodePointForKey:@"imageOffset"]];
		[self setImageDrawsOnTop:[coder decodeBoolForKey:@"imageOnTop"]];
		[self setCompositingOperation:[coder decodeIntegerForKey:@"imageComp"]];
		[self setImageCroppingOptions:[coder decodeIntegerForKey:@"DKImageShape_croppingOptions"]];
		
		mImageOffsetPartcode = [[[self hotspots] lastObject] partcode];
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
	
	if([self imageData])
		[copy setImageData:[self imageData]];
	else
	{
		[copy setImage:[self image]];
		[copy setImageKey:[self imageKey]];
	}
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
	if ([item action] == @selector(vectorize:) ||
		[item action] == @selector(fitToImage:))
		return ![self locked];
	
	if([item action] == @selector(selectCropOrScaleAction:))
	{
		[item setState:([item tag] == (NSInteger)[self imageCroppingOptions])? NSOnState : NSOffState];
		return ![self locked];
	}
	
	if ([item action] == @selector(toggleImageAboveAction:))
	{
		[item setState:[self imageDrawsOnTop]? NSOnState : NSOffState];
		return ![self locked];
	}
	
	if([item action] == @selector(copyImage:))
		return YES;
	
	if([item action] == @selector(pasteImage:))
	{
		return [NSImage canInitWithPasteboard:[NSPasteboard generalPasteboard]] && ![self locked];
	}

	return [super validateMenuItem:item];
}

@end
