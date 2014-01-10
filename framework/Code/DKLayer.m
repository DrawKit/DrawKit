/**
 * @author Graham Cox, Apptree.net
 * @author Graham Miln, miln.eu
 * @author Contributions from the community
 * @date 2005-2013
 * @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import "DKLayer.h"
#import "DKKnob.h"
#import "DKDrawing.h"
#import "DKDrawingView.h"
#import "DKSelectionPDFView.h"
#import "DKGeometryUtilities.h"
#import "GCInfoFloater.h"
#import "LogEvent.h"
#import "DKLayer+Metadata.h"
#import "DKUniqueID.h"
#import "NSDictionary+DeepCopy.h"

#pragma mark Constants (Non-localized)

NSString* kDKLayerLockStateDidChange = @"kDKLayerLockStateDidChange";
NSString* kDKLayerVisibleStateDidChange = @"kDKLayerVisibleStateDidChange";
NSString* kDKLayerNameDidChange = @"kDKLayerNameDidChange";
NSString* kDKLayerSelectionHighlightColourDidChange = @"kDKLayerSelectionHighlightColourDidChange";

#pragma mark Static Vars
static NSInteger sLayerIndexSeed = 4;

#pragma mark -
@implementation DKLayer
#pragma mark As a DKLayer

static NSArray* s_selectionColours = nil;

/** @brief Allows a list of colours to be set for supplying the selection colours
 * @note
 * The list is used to supply colours in rotation when new layers are instantiated
 * @param listOfColours an array containing NSColor objects
 * @public
 */
+ (void)setSelectionColours:(NSArray*)listOfColours
{
    [listOfColours retain];
    [s_selectionColours release];
    s_selectionColours = listOfColours;
}

/** @brief Returns the list of colours used for supplying the selection colours
 * @note
 * If never specifically set, this returns a very simple list of basic colours which is what DK has
 * traditionally used.
 * @return an array containing NSColor objects
 * @public
 */
+ (NSArray*)selectionColours
{
    if (s_selectionColours == nil) {
        NSMutableArray* list = [NSMutableArray array];

        static CGFloat colours[][3] = { { 0.5, 0.9, 1 }, // light blue
                                        { 1, 0, 0 }, // red
                                        { 0, 1, 0 }, // green
                                        { 0, 0.7, 0.7 }, // cyanish
                                        { 1, 0, 1 }, // magenta
                                        { 1, 0.5, 0 } }; // orange

        NSInteger i;

        for (i = 0; i < 6; i++) {
            NSColor* colour = [NSColor colorWithDeviceRed:colours[i][0]
                                                    green:colours[i][1]
                                                     blue:colours[i][2]
                                                    alpha:1.0];
            [list addObject:colour];
        }

        [self setSelectionColours:list];
    }

    return s_selectionColours;
}

/** @brief Returns a colour that can be used as the selection colour for a layer
 * @note
 * This simply returns a colour looked up in a table. It provides a default
 * selection colour for new layers - you can change the layer's selection colour to whatever you like - 
 * this just provides a default
 * @param index a positive number
 * @return a colour
 * @public
 */
+ (NSColor*)selectionColourForIndex:(NSUInteger)indx
{
    NSArray* selColours = [self selectionColours];

    if (selColours && [selColours count] > 0) {
        indx = indx % [selColours count];
        return [selColours objectAtIndex:indx];
    } else
        return nil;
}

#pragma mark -
#pragma mark - owning drawing

/** @brief Returns the drawing that the layer belongs to
 * @note
 * The drawing is the root object in a layer hierarchy, it overrides -drawing to return self, which is
 * how this works
 * @return the layer's owner drawing
 * @public
 */
- (DKDrawing*)drawing
{
    return [[self layerGroup] drawing];
}

/** @brief Called when the drawing's undo manager is changed - this gives objects that cache the UM a chance
 * to update their references
 * @note
 * The default implementation does nothing - override to make something of it
 * @param um the new undo manager
 * @public
 */
- (void)drawingHasNewUndoManager:(NSUndoManager*)um
{
#pragma unused(um)
}

/** @brief Called when the drawing's size is changed - this gives layers that need to know about this a
 * direct notification
 * @note
 * If you need to know before and after sizes, you'll need to subscribe to the relevant notifications.
 * @param sizeVal the new size of the drawing - extract -sizeValue.
 * @public
 */
- (void)drawingDidChangeToSize:(NSValue*)sizeVal
{
#pragma unused(sizeVal)
}

/** @brief Called when the drawing's margins changed - this gives layers that need to know about this a
 * direct notification
 * @note
 * The old interior is passed - you can get the new one directly from the drawing
 * @param oldInterior the old interior rect of the drawing - extract -rectValue.
 * @public
 */
- (void)drawingDidChangeMargins:(NSValue*)oldInterior
{
#pragma unused(oldInterior)
}

/** @brief Obtains the undo manager that is handling undo for the drawing and hence, this layer
 * @return the undo manager in use
 * @public
 */
- (NSUndoManager*)undoManager
{
    // return the nominated undo manager

    return [[self drawing] undoManager];
}

/** @brief Notifies the layer that it or a group containing it was added to a drawing.
 * @note
 * This can be used to perform additional setup that requires knowledge of the drawing such as its
 * size. The default method does nothing - override to use.
 * @param aDrawing the drawing that added the layer
 * @public
 */
- (void)wasAddedToDrawing:(DKDrawing*)aDrawing
{
#pragma unused(aDrawing)
}

#pragma mark -
#pragma mark - layer group hierarchy

/** @brief Sets the group that the layer is contained in - called automatically when the layer is added to a group
 * @note
 * The group retains this, so the group isn't retained here
 * @param group the group we belong to
 */
- (void)setLayerGroup:(DKLayerGroup*)group
{
    m_groupRef = group;
}

/** @brief Gets the group that the layer is contained in
 * @note
 * The layer's group might be the drawing itself, which is a group
 * @return the layer's group
 */
- (DKLayerGroup*)layerGroup
{
    return m_groupRef;
}

/** @brief Gets the layer's index within the group that the layer is contained in
 * @note
 * If the layer isn't in a group yet, result is 0. This is intended for debugging mostly.
 * @return an integer, the layer's index
 * @public
 */
- (NSUInteger)indexInGroup
{
    return [[self layerGroup] indexOfLayer:self];
}

/** @brief Determine whether a given group is the parent of this layer, or anywhere above it in the hierarchy
 * @note
 * Intended to check for absurd operations, such as moving a parent group into one of its own children.
 * @param aGroup a layer group
 * @return YES if the group sits above this in the hierarchy, NO otherwise
 * @public
 */
- (BOOL)isChildOfGroup:(DKLayerGroup*)aGroup
{
    if ([self layerGroup] == aGroup)
        return YES;
    else if ([self layerGroup] == nil)
        return NO;
    else
        return [[self layerGroup] isChildOfGroup:aGroup];
}

/** @brief Returns the hierarchical level of this layer, i.e. how deeply nested it is
 * @note
 * Layers in the root group return 1. A layer's level is its group's level + 1 
 * @return the layer's level
 * @public
 */
- (NSUInteger)level
{
    return [[self layerGroup] level] + 1;
}

#pragma mark -
#pragma mark - drawing

/** @brief Main entry point for drawing the layer and its contents to the drawing's views.
 * @note
 * Can be treated as the similar NSView call - to optimise drawing you can query the view that's doing
 * the drawing and use calls such as needsToDrawRect: etc. Will not be called in
 * cases where the layer is not visible, so you don't need to test for that. Must be overridden.
 * @param rect the overall area being updated
 * @param aView the view doing the rendering
 * @public
 */
- (void)drawRect:(NSRect)rect inView:(DKDrawingView*)aView
{
#pragma unused(rect)
#pragma unused(aView)

    NSLog(@"you should override [DKLayer drawRect:inView];");
}

/** @brief Is the layer opaque or transparent?
 * @note
 * Can be overridden to optimise drawing in some cases. Layers below an opaque layer are skipped
 * when drawing, so if you know your layer is opaque, return YES to implement the optimisation.
 * The default is NO, layers are considered to be transparent.
 * @return whether to treat the layer as opaque or not
 * @public
 */
- (BOOL)isOpaque
{
    return NO;
}

/** @brief Flags the whole layer as needing redrawing
 * @note
 * Always use this method instead of trying to access the view directly. This ensures that all attached
 * views get refreshed correctly.
 * @param update flag whether to update or not
 * @public
 */
- (void)setNeedsDisplay:(BOOL)update
{
    [[self drawing] setNeedsDisplay:update];
}

/** @brief Flags part of a layer as needing redrawing
 * @note
 * Always use this method instead of trying to access the view directly. This ensures that all attached
 * views get refreshed correctly.
 * @param rect the area that needs to be redrawn
 * @public
 */
- (void)setNeedsDisplayInRect:(NSRect)rect
{
    [[self drawing] setNeedsDisplayInRect:rect];
}

/** @brief Marks several areas for update at once
 * @note
 * Several update optimising methods return sets of rect values, this allows them to be processed
 * directly.
 * @param setOfRects a set containing NSValues with rect values
 * @public
 */
- (void)setNeedsDisplayInRects:(NSSet*)setOfRects
{
    [[self drawing] setNeedsDisplayInRects:setOfRects];
}

/** @brief Marks several areas for update at once
 * @note
 * Several update optimising methods return sets of rect values, this allows them to be processed
 * directly.
 * @param setOfRects a set containing NSValues with rect values
 * @param padding the width and height will be added to EACH rect before invalidating
 * @public
 */
- (void)setNeedsDisplayInRects:(NSSet*)setOfRects withExtraPadding:(NSSize)padding
{
    [[self drawing] setNeedsDisplayInRects:setOfRects
                          withExtraPadding:padding];
}

/** @brief Called before the layer starts drawing its content
 * @note
 * Can be used to hook into the start of drawing - by default does nothing
 * @public
 */
- (void)beginDrawing
{
    // override to make something useful of this
}

/** @brief Called after the layer has finished drawing its content
 * @note
 * Can be used to hook into the end of drawing - by default does nothing
 * @public
 */
- (void)endDrawing
{
    // override to make something useful of this
}

#pragma mark -

/** @brief Sets the colour preference to use for selected objects within this layer
 * @note
 * Different layers may wish to have a different colour for selections to help the user tell which
 * layer they are working in. The layer doesn't enforce this - it's up to objects to make use of
 * this provided colour where necessary.
 * @param colour the selection colour preference
 * @public
 */
- (void)setSelectionColour:(NSColor*)colour
{
    if (![self locked] && ![colour isEqual:[self selectionColour]]) {
        LogEvent_(kReactiveEvent, @"<%@ 0x%x> setting selection colour: %@", NSStringFromClass([self class]), self, colour);

        [[[self undoManager] prepareWithInvocationTarget:self] setSelectionColour:[self selectionColour]];

        [colour retain];
        [m_selectionColour release];
        m_selectionColour = colour;
        [self setNeedsDisplay:YES];

        // also set the info window's background to the same colour if it exists

        if (m_infoWindow != nil)
            [m_infoWindow setBackgroundColor:colour];

        // tell anyone who's interested:

        [[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerSelectionHighlightColourDidChange
                                                            object:self];
        [[self undoManager] setActionName:NSLocalizedString(@"Selection Colour", nil)];
    }
}

/** @brief Returns the currently preferred selection colour for this layer
 * @return the colour
 * @public
 */
- (NSColor*)selectionColour
{
    return m_selectionColour;
}

#pragma mark -

/** @brief Returns an image of the layer a the given size
 * @note
 * While the image has the size passed, the rendered content will have the same aspect ratio as the
 * drawing, scaled to fit. Areas left outside of the drawn portion are transparent.
 * @return an image of this layer only
 * @public
 */

/** @brief Returns an image of the layer at the default size
 * @return an image of this layer only
 * @public
 */
- (NSImage*)thumbnailImageWithSize:(NSSize)size
{
    NSSize drsize = [[self drawing] drawingSize];

    if (NSEqualSizes(size, NSZeroSize)) {
        size.width = drsize.width / 8.0;
        size.height = drsize.height / 8.0;
    }

    //LogEvent_(kReactiveEvent,  @"creating layer thumbnail size: {%f, %f}", size.width, size.height );

    NSImage* thumb = [[NSImage alloc] initWithSize:size];
    NSRect tr, dr, dest;

    [thumb setFlipped:[[self drawing] isFlipped]];

    tr = NSMakeRect(0, 0, size.width, size.height);
    dr = NSMakeRect(0, 0, drsize.width, drsize.height);

    dest = ScaledRectForSize(drsize, tr);

    // build a transform to scale the drawing to the destination rect size

    CGFloat scale = dest.size.width / drsize.width;
    NSAffineTransform* tfm = [NSAffineTransform transform];
    [tfm scaleBy:scale];

    [thumb lockFocus];
    [[NSColor clearColor] set];
    NSRectFill(tr);
    [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];

    [tfm concat];
    [self drawRect:dr
            inView:nil];

    [[NSColor blackColor] set];
    NSFrameRectWithWidth(dr, 2.0);

    [thumb unlockFocus];

    return [thumb autorelease];
}

- (NSImage*)thumbnail
{
    return [self thumbnailImageWithSize:NSZeroSize];
}

/** @brief Returns the content of the layer as a pdf
 * @note
 * By default the pdf contains the entire layer's visible content exactly as drawn to a printer.
 * @return NSData containing the pdf representation of the layer and its contents
 * @public
 */
- (NSData*)pdf
{
    NSRect frame = NSZeroRect;
    frame.size = [[self drawing] drawingSize];

    DKLayerPDFView* pdfView = [[DKLayerPDFView alloc] initWithFrame:frame
                                                          withLayer:self];
    DKViewController* vc = [pdfView makeViewController];

    [[self drawing] addController:vc];

    NSData* pdfData = [pdfView dataWithPDFInsideRect:frame];
    [pdfView release]; // removes the controller

    return pdfData;
}

/** @brief Writes the content of the layer as a pdf to a nominated pasteboard
 * @note
 * Becomes the new pasteboard owner and removes any existing declared types
 * @param pb the pasteboard
 * @return YES if written OK, NO otherwise
 * @public
 */
- (BOOL)writePDFDataToPasteboard:(NSPasteboard*)pb
{
    NSAssert(pb != nil, @"Cannot write to a nil pasteboard");

    [pb declareTypes:[NSArray arrayWithObject:NSPDFPboardType]
               owner:self];
    return [pb setData:[self pdf]
               forType:NSPDFPboardType];
}

/** @brief Returns the layer's content as a transparent bitmap having the given DPI.
 * @note
 * A dpi of 0 uses the default, which is 72 dpi. The image pixel size is calculated from the drawing
 * size and the dpi. The layer is imaged onto a transparent background with alpha.
 * @param dpi image resolution in dots per inch
 * @return the bitmap
 * @public
 */
- (NSBitmapImageRep*)bitmapRepresentationWithDPI:(NSUInteger)dpi
{
    if (dpi == 0)
        dpi = 72;

    NSSize imageSize = [[self drawing] drawingSize];
    NSUInteger pixelsAcross, pixelsDown;

    pixelsAcross = ceil(imageSize.width * dpi / 72.0);
    pixelsDown = ceil(imageSize.height * dpi / 72.0);

    NSBitmapImageRep* rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                    pixelsWide:pixelsAcross
                                                                    pixelsHigh:pixelsDown
                                                                 bitsPerSample:8
                                                               samplesPerPixel:4
                                                                      hasAlpha:YES
                                                                      isPlanar:NO
                                                                colorSpaceName:NSCalibratedRGBColorSpace
                                                                   bytesPerRow:0
                                                                  bitsPerPixel:0];

    NSAssert(rep != nil, @"bitmap rep could not be created");

    NSData* pdf = [self pdf];

    NSAssert(pdf != nil, @"unable to get pdf data");

    // create a second rep from the pdf data

    NSPDFImageRep* pdfRep = [NSPDFImageRep imageRepWithData:pdf];

    NSAssert(pdfRep != nil, @"unable to create pdf representation");

    // set up a graphics context

    NSGraphicsContext* context = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
    [context setImageInterpolation:NSImageInterpolationHigh];
    [context setShouldAntialias:YES];

    SAVE_GRAPHICS_CONTEXT

    [NSGraphicsContext setCurrentContext:context];

    // focus on the image and draw the content

    NSRect layerRect = NSMakeRect(0, 0, pixelsAcross, pixelsDown);

    [pdfRep drawInRect:layerRect];

    RESTORE_GRAPHICS_CONTEXT

    return [rep autorelease];
}

/** @brief Sets whether drawing is limited to the interior area or not
 * @note
 * Default is NO, so drawings show in the margins.
 * @param clip YES to limit drawing to the interior, NO to allow drawing to be visible in the margins.
 * @public
 */
- (void)setClipsDrawingToInterior:(BOOL)clip
{
    if (clip != [self clipsDrawingToInterior]) {
        [[[self undoManager] prepareWithInvocationTarget:self] setClipsDrawingToInterior:m_clipToInterior];
        m_clipToInterior = clip;
        [self setNeedsDisplay:YES];
        [[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerLockStateDidChange
                                                            object:self];

        if (!([[self undoManager] isUndoing] || [[self undoManager] isRedoing]))
            [[self undoManager] setActionName:NSLocalizedString(@"Clip To Margin", @"undo for layer clipping")];
    }
}

/** @brief Whether the drawing will be clipped to the interior or not
 * @note
 * Default is NO.
 * @return YES if clipping, NO if not.
 * @public
 */
- (BOOL)clipsDrawingToInterior
{
    return m_clipToInterior;
}

/** @brief Sets the alpha level for the layer
 * @note
 * Default is 1.0 (fully opaque objects). Note that alpha must be implemented by a layer's
 * -drawRect:inView: method to have an actual effect, and unless compositing to a CGLayer or other
 * graphics surface, may not have the expected effect (just setting the context's alpha before
 * drawing renders each individual object with the given alpha, for example).
 * @param alpha the alpha level, 0..1
 * @public
 */
- (void)setAlpha:(CGFloat)alpha
{
    if (![self locked] && alpha != mAlpha) {
        [(DKLayer*)[[self undoManager] prepareWithInvocationTarget:self] setAlpha:mAlpha];

        mAlpha = LIMIT(alpha, 0.0, 1.0);
        [self setNeedsDisplay:YES];
    }
}

/** @brief Returns the alpha level for the layer as a whole
 * @note
 * Default is 1.0 (fully opaque objects)
 * @return the current alpha level
 * @public
 */
- (CGFloat)alpha
{
    return mAlpha;
}

- (void)updateRulerMarkersForRect:(NSRect)rect
{
    if ([self rulerMarkerUpdatesEnabled])
        [[self layerGroup] updateRulerMarkersForRect:rect];
}

- (void)hideRulerMarkers
{
    if ([self rulerMarkerUpdatesEnabled])
        [[self layerGroup] hideRulerMarkers];
}

- (void)setRulerMarkerUpdatesEnabled:(BOOL)enable
{
    mRulerMarkersEnabled = enable;
}

- (BOOL)rulerMarkerUpdatesEnabled
{
    return mRulerMarkersEnabled;
}

#pragma mark -
#pragma mark - states

/** @brief Sets whether the layer is locked or not
 * @note
 * A locked layer will be drawn but cannot be edited. In case the layer's appearance changes
 * according to this state change, a refresh is performed.
 * @param locked YES to lock, NO to unlock
 * @public
 */
- (void)setLocked:(BOOL)locked
{
    if (locked != m_locked) {
        [[[self undoManager] prepareWithInvocationTarget:self] setLocked:m_locked];
        m_locked = locked;
        [self setNeedsDisplay:YES];
        [[self drawing] invalidateCursors];
        [[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerLockStateDidChange
                                                            object:self];

        if (!([[self undoManager] isUndoing] || [[self undoManager] isRedoing]))
            [[self undoManager] setActionName:locked ? NSLocalizedString(@"Lock Layer", @"undo for lock layer") : NSLocalizedString(@"Unlock Layer", @"undo for Unlock Layer")];
    }
}

/** @brief Returns whether the layer is locked or not
 * @note
 * Locked layers cannot be edited. Also returns YES if the layer belongs to a locked group
 * @return YES if locked, NO if unlocked
 * @public
 */
- (BOOL)locked
{
    return m_locked || [[self layerGroup] locked];
}

/** @brief Sets whether the layer is visible or not
 * @note
 * Invisible layers are neither drawn nor can be edited.
 * @param visible YES to show the layer, NO to hide it
 * @public
 */
- (void)setVisible:(BOOL)visible
{
    if (visible != m_visible) {
        [[[self undoManager] prepareWithInvocationTarget:self] setVisible:[self visible]];
        m_visible = visible;
        [self setNeedsDisplay:YES];
        [[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerVisibleStateDidChange
                                                            object:self];

        if (!([[self undoManager] isUndoing] || [[self undoManager] isRedoing]))
            [[self undoManager] setActionName:visible ? NSLocalizedString(@"Show Layer", @"undo for show layer") : NSLocalizedString(@"Hide Layer", @"undo for hide Layer")];
    }
}

/** @brief Is the layer visible?
 * @note
 * Also returns NO if the layer's group is not visible
 * @return YES if visible, NO if not
 * @public
 */
- (BOOL)visible
{
    return m_visible && ([self layerGroup] == nil || [[self layerGroup] visible]);
}

/** @brief Is the layer the active layer?
 * @return YES if the active layer, NO otherwise
 * @public
 */
- (BOOL)isActive
{
    return ([[self drawing] activeLayer] == self);
}

/** @brief Returns whether the layer is locked or hidden
 * @note
 * Locked or hidden layers cannot usually be edited.
 * @return YES if locked or hidden, NO if unlocked and visible
 * @public
 */
- (BOOL)lockedOrHidden
{
    return [self locked] || ![self visible];
}

/** @brief Returns the layer's unique key
 * @return the unique key
 * @public
 */
- (NSString*)uniqueKey
{
    return mLayerUniqueKey;
}

#pragma mark -

/** @brief Sets the user-readable name of the layer
 * @note
 * Layer names are a convenience for the user, and can be displayed by a user interface. The name is
 * not significant internally. This copies the name passed for safety.
 * @param name the layer's name
 * @public
 */
- (void)setLayerName:(NSString*)name
{
    if (![name isEqualToString:[self layerName]]) {
        [[[self undoManager] prepareWithInvocationTarget:self] setLayerName:[self layerName]];

        NSString* nameCopy = [name copy];

        [m_name release];
        m_name = nameCopy;

        LogEvent_(kStateEvent, @"layer's name was set to '%@'", m_name);

        [[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerNameDidChange
                                                            object:self];

        if (!([[self undoManager] isUndoing] || [[self undoManager] isRedoing]))
            [[self undoManager] setActionName:NSLocalizedString(@"Change Layer Name", @"undo action for change layer name")];
    }
}

/** @brief Returns the layer's name
 * @return the name
 * @public
 */
- (NSString*)layerName
{
    return m_name;
}

#pragma mark -
#pragma mark - user info

/** @brief Attach a dictionary of user data to the object
 * @note
 * The dictionary replaces the current user info. To merge with any existing user info, use addUserInfo:
 * For the more specific metadata attachemnts, refer to DKLayer+Metadata. Metadata is stored within the
 * user info dictionary as a subdictionary.
 * @param info a dictionary containing anything you wish
 * @public
 */
- (void)setUserInfo:(NSMutableDictionary*)info
{
    [info retain];
    [mUserInfo release];
    mUserInfo = info;
}

/** @brief Add a dictionary of metadata to the object
 * @note
 * <info> is merged with the existin gcontent of the user info
 * @param info a dictionary containing anything you wish
 * @public
 */
- (void)addUserInfo:(NSDictionary*)info
{
    if (mUserInfo == nil)
        mUserInfo = [[NSMutableDictionary alloc] init];

    NSDictionary* deepCopy = [info deepCopy];

    [mUserInfo addEntriesFromDictionary:deepCopy];
    [deepCopy release];
}

/** @brief Return the attached user info
 * @note
 * The user info is returned as a mutable dictionary (which it is), and can thus have its contents
 * mutated directly for certain uses. Doing this cannot cause any notification of the status of
 * the object however.
 * @return the user info
 * @public
 */
- (NSMutableDictionary*)userInfo
{
    return mUserInfo;
}

/** @brief Return an item of user info
 * @param key the key to use to refer to the item
 * @return the user info item
 * @public
 */
- (id)userInfoObjectForKey:(NSString*)key
{
    return [[self userInfo] objectForKey:key];
}

/** @brief Set an item of user info
 * @param obj the object to store
 * @param key the key to use to refer to the item
 * @public
 */
- (void)setUserInfoObject:(id)obj forKey:(NSString*)key
{
    NSAssert(obj != nil, @"cannot add nil to the user info");
    NSAssert(key != nil, @"user info key can't be nil");

    if (mUserInfo == nil)
        mUserInfo = [[NSMutableDictionary alloc] init];

    [[self userInfo] setObject:obj
                        forKey:key];
}

#pragma mark -
#pragma mark - print this layer?

/** @brief Set whether this layer should be included in printed output
 * @note
 * Default is YES
 * @param printIt YES to includethe layer, NO to skip it
 * @public
 */
- (void)setShouldDrawToPrinter:(BOOL)printIt
{
    m_printed = printIt;
}

/** @brief Return whether the layer should be part of the printed output or not
 * @note
 * Some layers won't want to be printed - guides for example. Override this to return NO if you
 * don't want the layer to be printed. By default layers are printed.
 * @return YES to draw to printer, NO to suppress drawing on the printer
 * @public
 */
- (BOOL)shouldDrawToPrinter
{
    return m_printed;
}

#pragma mark -
#pragma mark - becoming/resigning active

/** @brief Returns whether the layer can become the active layer
 * @note
 * The default is YES. Layers may override this and return NO if they do not want to ever become active
 * @return YES if the layer can become active, NO to not become active
 * @public
 */
- (BOOL)layerMayBecomeActive
{
    return YES;
}

/** @brief The layer was made the active layer by the owning drawing
 * @note
 * Layers may want to know when their active state changes. Override to make use of this.
 * @public
 */
- (void)layerDidBecomeActiveLayer
{
    // override to make use of this message

    LogEvent_(kReactiveEvent, @"layer %@ became active", self);
}

/** @brief The layer is no longer the active layer
 * @note
 * Layers may want to know when their active state changes. Override to make use of this.
 * @public
 */
- (void)layerDidResignActiveLayer
{
    // override to make use of this message

    LogEvent_(kReactiveEvent, @"layer %@ resigned active", self);
}

/** @brief Return whether the layer can be deleted
 * @note
 * This setting is intended to be checked by UI-level code to prevent deletion of layers within the UI.
 * It does not prevent code from directly removing the layer.
 * @return YES if layer can be deleted, override to return NO to prevent this
 * @public
 */
- (BOOL)layerMayBeDeleted
{
    return ![self locked];
}

#pragma mark -
#pragma mark - mouse event handling

/** @brief Should the layer automatically activate on a click if the view has this behaviour set?
 * @note
 * Override to return NO if your layer type should not auto activate. Note that auto-activation also
 * needs to be set for the view. The event is passed so that a sensible decision can be reached.
 * @param event the event (usually a mouse down) of the view that is asking
 * @return YES if the layer is unlocked, NO otherwise
 * @public
 */
- (BOOL)shouldAutoActivateWithEvent:(NSEvent*)event
{
#pragma unused(event)

    return ![self locked];
}

/** @brief Detect whether the layer was "hit" by a point.
 * @note
 * This is used to implement automatic layer activation when the user clicks in a view. This isn't
 * always the most useful behaviour, so by default this returns NO. Subclasses can override to refine
 * the hit test appropriately.
 * @param p the point to test
 * @return YES if the layer was hit, NO otherwise
 * @public
 */
- (BOOL)hitLayer:(NSPoint)p
{
#pragma unused(p)

    return NO;
}

/** @brief Detect what object was hit by a point.
 * @note
 * Layers that support objects implement this meaningfully. A non-object layer returns nil which
 * simplifies the design of certain tools that look for targets to operate on, without the need
 * to ascertain the layer class first.
 * @param p the point to test
 * @return the object hit, or nil
 * @public
 */
- (DKDrawableObject*)hitTest:(NSPoint)p
{
#pragma unused(p)

    return nil;
}

#pragma mark -

/** @brief The mouse went down in this layer
 * @note
 * Override to respond to the event. Note that where tool controllers and tools are used, these
 * methods may never be called, as the tool will operate on target objects within the layer directly.
 * @param event the original mouseDown event
 * @param view the view which responded to the event and passed it on to us
 * @public
 */
- (void)mouseDown:(NSEvent*)event inView:(NSView*)view
{
#pragma unused(event)
#pragma unused(view)
}

/** @note
 * Subclasses must override to be notified of mouse dragged events
 * @param event the original mouseDragged event
 * @param view the view which responded to the event and passed it on to us
 * @public
 */
- (void)mouseDragged:(NSEvent*)event inView:(NSView*)view;
{
#pragma unused(event)
#pragma unused(view)
}

/** @note
 * Override to respond to the event
 * @param event the original mouseUpevent
 * @param view the view which responded to the event and passed it on to us
 * @public
 */
- (void)mouseUp:(NSEvent*)event inView:(NSView*)view;
{
#pragma unused(event)
#pragma unused(view)
}

/** @brief Respond to a change in the modifier key state
 * @note
 * Is passed from the key view to the active layer
 * @param event the event
 * @public
 */
- (void)flagsChanged:(NSEvent*)event
{
#pragma unused(event)

    // override to do something useful
}

#pragma mark -

/** @brief Returns the view which is either currently drawing the layer, or the one that mouse events are
 * coming from
 * @note
 * This generally does the expected thing. If you're drawing, it returns the view that's doing the drawing
 * original event in question. At any other time it will return nil. Wherever possible you should
 * use the view parameter that is passed to you rather than use this.
 * @return the currently "important" view
 * @public
 */
- (NSView*)currentView
{
    return [DKDrawingView currentlyDrawingView];
}

/** @brief Returns the cursor to display while the mouse is over this layer while it's active
 * @note
 * Subclasses will usually want to override this and provide a cursor appropriate to the layer or where
 * the mouse is within it, or which tool has been attached.
 * @return the desired cursor
 * @public
 */
- (NSCursor*)cursor
{
    return [NSCursor arrowCursor];
}

/** @brief Return a rect where the layer's cursor is shown when the mouse is within it
 * @note
 * By default the cursor rect is the entire interior area.
 * @return the cursor rect
 * @public
 */
- (NSRect)activeCursorRect
{
    return [[self drawing] interior];
}

#pragma mark -

/** @brief Allows a contextual menu to be built for the layer or its contents
 * @note
 * By default this returns nil, resulting in nothing being displayed. Subclasses can override to build
 * a suitable menu for the point where the layer was clicked.
 * @param theEvent the original event (a right-click mouse event)
 * @param view the view that received the original event
 * @return a menu that will be displayed as a contextual menu
 * @public
 */
- (NSMenu*)menuForEvent:(NSEvent*)theEvent inView:(NSView*)view
{
#pragma unused(theEvent)
#pragma unused(view)

    return nil;
}

#pragma mark -
#pragma mark supporting per-layer knob handling

/** @brief Sets the selection knob helper object used for this drawing and any objects within it
 * @note
 * Selection appearance can be customised for this drawing by setting up the knobs object or subclassing
 * it. This object is propagated down to all objects below this in the system to draw their selection.
 * See also: -setSelectionColour, -selectionColour.
 * @param knobs the knobs objects
 * @public
 */
- (void)setKnobs:(DKKnob*)knobs
{
    [knobs retain];
    [m_knobs release];
    m_knobs = knobs;

    [m_knobs setOwner:self];
}

/** @brief Returns the attached selection knobs helper object
 * @note
 * If custom knobs have been set for the layer, they are returned. Otherwise, the knobs for the group
 * or ultimately the drawing will be returned.
 * @return the attached knobs object
 * @public
 */
- (DKKnob*)knobs
{
    if (m_knobs != nil)
        return m_knobs;
    else
        return [[self layerGroup] knobs];
}

/** @brief Sets whether selection knobs should scale to compensate for the view scale. default is YES.
 * @note
 * In general it's best to scale the knobs otherwise they tend to overlap and become large at high
 * zoom factors, and vice versa. The knobs objects itself decides exactly how to perform the scaling.
 * @param ka YES to set knobs to scale, NO to fix their size.
 * @public
 */
- (void)setKnobsShouldAdustToViewScale:(BOOL)ka
{
    m_knobsAdjustToScale = ka;
}

/** @brief Return whether the drawing will scale its selection knobs to the view or not
 * @note
 * The default setting is YES, knobs should adjust to scale.
 * @return YES if knobs ar scaled, NO if not
 * @public
 */
- (BOOL)knobsShouldAdjustToViewScale
{
    if (m_knobs != nil)
        return m_knobsAdjustToScale;
    else
        return NO;
}

#pragma mark -
#pragma mark - pasteboard/drag and drop support

/** @brief Return the pasteboard types this layer is able to receive in a given operation (drop or paste)
 * @param op the kind of operation we need pasteboard types for
 * @return an array of pasteboard types
 * they can handle and also implement the necessary parts of the NSDraggingDestination protocol
 * just as if they were a view.
 * @public
 */
- (NSArray*)pasteboardTypesForOperation:(DKPasteboardOperationType)op
{
#pragma unused(op)

    return nil;
}

/** @brief Tests whether the pasteboard has any of the types the layer is interested in receiving for the given
 * operation
 * @param pb the pasteboard
 * @param op the kind of operation we need pasteboard types for
 * @return YES if the pasteboard has any of the types of interest, otherwise NO
 * @public
 */
- (BOOL)pasteboard:(NSPasteboard*)pb hasAvailableTypeForOperation:(DKPasteboardOperationType)op
{
    // return whether the given pasteboard has an available data type for the given operation on this object

    NSAssert(pb != nil, @"pasteboard is nil");

    NSArray* types = [self pasteboardTypesForOperation:op];

    if (types != nil) {
        NSString* type = [pb availableTypeFromArray:types];
        return (type != nil);
    } else
        return NO;
}

#pragma mark -
#pragma mark - style utilities

/** @brief Return all of styles used by the layer
 * @note
 * Override if your layer uses styles
 * @return nil
 * @public
 */
- (NSSet*)allStyles
{
    return nil; // generic layers have no styles
}

/** @brief Return all of registered styles used by the layer
 * @note
 * Override if your layer uses styles
 * @return nil
 * @public
 */
- (NSSet*)allRegisteredStyles
{
    return nil; // generic layers have no registered styles
}

/** @brief Substitute styles with those in the given set
 * @note
 * Subclasses may implement this to replace styles they use with styles from the set that have matching
 * keys. This is an important step in reconciling the styles loaded from a file with the existing
 * registry. Implemented by DKObjectOwnerLayer, etc. Layer groups also implement this to propagate
 * the change to all sublayers.
 * @param aSet a set of style objects
 * @public
 */
- (void)replaceMatchingStylesFromSet:(NSSet*)aSet
{
#pragma unused(aSet)
}

#pragma mark -

/** @brief Displays a small floating info window near the point p containg the string.
 * @note
 * The window is shown near the point rather than at it. Generally the info window should be used
 * for small, dynamically changing and temporary information, like a coordinate value. The background
 * colour is initially set to the layer's selection colour
 * @param str a pre-formatted string containg some information to display
 * @param p a point in local drawing coordinates
 * @public
 */
- (void)showInfoWindowWithString:(NSString*)str atPoint:(NSPoint)p
{
    if (m_infoWindow == nil) {
        m_infoWindow = [[GCInfoFloater infoFloater] retain];
        [m_infoWindow setFormat:nil];
        [m_infoWindow setBackgroundColor:[self selectionColour]];
        [m_infoWindow setWindowOffset:NSMakeSize(6, 10)];
    }

    [m_infoWindow setStringValue:str];
    [m_infoWindow positionNearPoint:p
                             inView:[self currentView]];
    [m_infoWindow show];
}

/** @brief Sets the background colour of the small floating info window
 * @param colour a colour for the window
 * @public
 */
- (void)setInfoWindowBackgroundColour:(NSColor*)colour
{
    if (m_infoWindow == nil) {
        m_infoWindow = [[GCInfoFloater infoFloater] retain];
        [m_infoWindow setFormat:nil];
        [m_infoWindow setBackgroundColor:[self selectionColour]];
        [m_infoWindow setWindowOffset:NSMakeSize(6, 10)];
    }

    if (colour != nil)
        [m_infoWindow setBackgroundColor:colour];
}

/** @brief Hides the info window if it's visible
 * @public
 */
- (void)hideInfoWindow
{
    [m_infoWindow hide];
}

#pragma mark -
#pragma mark - user actions

/** @note
 * User interface level method can be linked to a menu or other appropriate UI widget
 * @param sender the sender of the action
 * @public
 */
- (IBAction)lockLayer:(id)sender
{
#pragma unused(sender)

    [self setLocked:YES];
    [[self undoManager] setActionName:NSLocalizedString(@"Lock Layer", @"undo string for lock layer")];
}

/** @note
 * User interface level method can be linked to a menu or other appropriate UI widget
 * @param sender the sender of the action
 * @public
 */
- (IBAction)unlockLayer:(id)sender
{
#pragma unused(sender)

    [self setLocked:NO];
    [[self undoManager] setActionName:NSLocalizedString(@"Unlock Layer", @"undo string for unlock layer")];
}

/** @note
 * User interface level method can be linked to a menu or other appropriate UI widget
 * @param sender the sender of the action
 * @public
 */
- (IBAction)toggleLayerLock:(id)sender
{
    if ([self locked])
        [self unlockLayer:sender];
    else
        [self lockLayer:sender];
}

#pragma mark -

/** @note
 * User interface level method can be linked to a menu or other appropriate UI widget
 * @param sender the sender of the action
 * @public
 */
- (IBAction)showLayer:(id)sender
{
#pragma unused(sender)

    [self setVisible:YES];
    [[self undoManager] setActionName:NSLocalizedString(@"Show Layer", @"undo string for show layer")];
}

/** @note
 * User interface level method can be linked to a menu or other appropriate UI widget
 * @param sender the sender of the action
 * @public
 */
- (IBAction)hideLayer:(id)sender
{
#pragma unused(sender)

    [self setVisible:NO];
    [[self undoManager] setActionName:NSLocalizedString(@"Hide Layer", @"undo string for hide layer")];
}

/** @note
 * User interface level method can be linked to a menu or other appropriate UI widget
 * @param sender the sender of the action
 * @public
 */
- (IBAction)toggleLayerVisible:(id)sender
{
    if ([self visible])
        [self hideLayer:sender];
    else
        [self showLayer:sender];
}

/** @note
 * Debugging method
 * @param sender the sender of the action
 * @public
 */
- (IBAction)logDescription:(id)sender
{
#pragma unused(sender)
    NSLog(@"%@", self);
}

/** @brief Places the layer on the clipboard as a PDF
 * @param sender the sender of the action
 * @public
 */
- (IBAction)copy:(id)sender
{
#pragma unused(sender)

    // export the layer's content as a PDF

    [self writePDFDataToPasteboard:[NSPasteboard generalPasteboard]];
}

#pragma mark -
#pragma mark As an NSObject
- (void)dealloc
{
    LogEvent_(kLifeEvent, @"deallocating DKLayer %p", self);

    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[self undoManager] removeAllActionsWithTarget:self];

    [m_infoWindow release];
    [m_knobs release];
    [m_selectionColour release];
    [m_name release];
    [mUserInfo release];
    [mLayerUniqueKey release];
    [super dealloc];
}

/** @brief Designated initializer for base class of all layers
 * @note
 * A layer must be added to a group (and ultimately a drawing, which is a group) before it can be used
 */
- (id)init
{
    self = [super init];
    if (self != nil) {
        [self setVisible:YES];
        [self setLocked:NO];
        [self setKnobsShouldAdustToViewScale:YES];
        [self setShouldDrawToPrinter:YES];
        [self setSelectionColour:[[self class] selectionColourForIndex:sLayerIndexSeed++]];
        mLayerUniqueKey = [[DKUniqueID uniqueKey] retain];
        mRulerMarkersEnabled = YES;
        mAlpha = 1.0;
    }
    return self;
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"%@; name = '%@',\nuser info = %@,\ngroup = %@", [super description], [self layerName], [self userInfo], [self layerGroup]];
}

#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)encodeWithCoder:(NSCoder*)coder
{
    NSAssert(coder != nil, @"Expected valid coder");
    [coder encodeConditionalObject:[self layerGroup]
                            forKey:@"group"];
    [coder encodeObject:[self layerName]
                 forKey:@"name"];
    [coder encodeObject:[self selectionColour]
                 forKey:@"selcolour"];
    [coder encodeObject:[self knobs]
                 forKey:@"DKLayer_knobs"];

    [coder encodeBool:[self visible]
               forKey:@"visible"];
    [coder encodeBool:[self locked]
               forKey:@"locked"];
    [coder encodeBool:YES
               forKey:@"hasPrintFlag"];
    [coder encodeBool:m_printed
               forKey:@"printed"];
    [coder encodeBool:m_clipToInterior
               forKey:@"DKLayer_clipToInterior"];
    [coder encodeObject:[self userInfo]
                 forKey:@"DKLayer_userInfo"];
    [coder encodeDouble:[self alpha]
                 forKey:@"DKLayer_alpha"];

    [coder encodeBool:![self rulerMarkerUpdatesEnabled]
               forKey:@"DKLayer_disableRulerMarkerUpdates"];
}

- (id)initWithCoder:(NSCoder*)coder
{
    NSAssert(coder != nil, @"Expected valid coder");
    LogEvent_(kFileEvent, @"decoding layer %@", self);

    self = [self init];
    if (self) {
        [self setLayerGroup:[coder decodeObjectForKey:@"group"]];
        [self setLayerName:[coder decodeObjectForKey:@"name"]];

        NSColor* selColour = [coder decodeObjectForKey:@"selcolour"];

        if (selColour)
            [self setSelectionColour:selColour];

        [self setKnobs:[coder decodeObjectForKey:@"DKLayer_knobs"]];
        [self setKnobsShouldAdustToViewScale:YES];

        [self setVisible:[coder decodeBoolForKey:@"visible"]];
        // Check older files for presence of flag - if not there, assume YES
        BOOL hasPrintFlag = [coder decodeBoolForKey:@"hasPrintFlag"];
        if (hasPrintFlag)
            [self setShouldDrawToPrinter:[coder decodeBoolForKey:@"printed"]];
        else
            [self setShouldDrawToPrinter:YES];

        [self setClipsDrawingToInterior:[coder decodeBoolForKey:@"DKLayer_clipToInterior"]];
        [self setUserInfo:[coder decodeObjectForKey:@"DKLayer_userInfo"]];

        mLayerUniqueKey = [[DKUniqueID uniqueKey] retain];

        // alpha was added in 1.0.7 - if not present, default to 1.0

        if ([coder containsValueForKey:@"DKLayer_alpha"])
            mAlpha = [coder decodeDoubleForKey:@"DKLayer_alpha"];
        else
            mAlpha = 1.0;

        [self setRulerMarkerUpdatesEnabled:![coder decodeBoolForKey:@"DKLayer_disableRulerMarkerUpdates"]];
    }
    return self;
}

- (id)awakeAfterUsingCoder:(NSCoder*)coder
{
    [self setLocked:[coder decodeBoolForKey:@"locked"]];
    [self updateMetadataKeys];
    return self;
}

#pragma mark -
#pragma mark As part of NSMenuValidation Protocol

/** @note
 * Overrides NSObject
 * @param item the menu item to validate
 * @return YES to enable the item, NO to disable it
 * @public
 */
- (BOOL)validateMenuItem:(NSMenuItem*)item
{
    SEL action = [item action];

    if (action == @selector(lockLayer:))
        return ![self locked];

    if (action == @selector(unlockLayer:))
        return [self locked];

    if (action == @selector(showLayer:))
        return ![self visible];

    if (action == @selector(hideLayer:))
        return [self visible];

    if (action == @selector(toggleLayerLock:) || action == @selector(toggleLayerVisible:))
        return YES;

    if (action == @selector(logDescription:))
        return YES;

    return NO;
}

- (BOOL)validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)anItem
{
    if ([(id)anItem isKindOfClass:[NSMenuItem class]])
        return [self validateMenuItem:(NSMenuItem*)anItem];

    // Temporary hack: find out what the old menu validation would return for the same action and
    // use that result.

    NSMenuItem* temp = [[NSMenuItem alloc] initWithTitle:@"NEVER_SEEN"
                                                  action:[anItem action]
                                           keyEquivalent:@""];
    BOOL oldResult = [self validateMenuItem:temp];
    [temp release];

    return oldResult;
}

#pragma mark -
#pragma mark As part of the DKKnobOwner protocol

- (CGFloat)knobsWantDrawingScale
{
    // query the currently rendering view's scale and pass it back to the knobs

    if ([self knobsShouldAdjustToViewScale])
        return [(DKDrawingView*)[[self drawing] currentView] scale];
    else
        return 1.0;
}

- (BOOL)knobsWantDrawingActiveState
{
    // query the currently rendering view's active state and pass it back to the knobs

    NSWindow* window = [[[self drawing] currentView] window];

    // if there is no window (e.g. for a print or PDF view) assume active

    return (window == nil) || [window isMainWindow];
}

@end
