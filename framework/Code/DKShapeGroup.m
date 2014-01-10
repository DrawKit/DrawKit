/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import "DKShapeGroup.h"
#import "DKGeometryUtilities.h"
#import "DKDrawablePath.h"
#import "DKDrawing.h"
#import "DKStyle.h"
#import "DKObjectDrawingLayer.h"
#import "NSBezierPath+Geometry.h"
#import "DKSelectionPDFView.h"
#import "LogEvent.h"
#import "DKDrawableObject+Metadata.h"

@interface DKShapeGroup (Private)
- (void)invalidateCache;
- (void)updateCache;
- (void)drawUntransformedContent;

@end

@implementation DKShapeGroup
#pragma mark As a DKShapeGroup

/** @brief Creates a group of shapes or paths from a list of bezier paths

 This constructs a group from a list of bezier paths by wrapping a drawable around each path then
 grouping the result. While general purpose in nature, this is primarily to support the construction
 of a group containing text glyphs from a text shape object. The group's location is set to the
 centre of the union of the bounds of all created objects, which in turn depends on the paths' positions.
 caller may wish to move the group before adding it to a layer.
 @param paths a list of NSBezierPath objects
 @param type a value indicating what type of objects the group should consist of. Can be 0 = shapes or
 @param style a style object to apply to each new shape or path as it is created; pass nil to create
 @return a new group object consisting of a set of other objects built from the supplied paths
 */
+ (DKShapeGroup*)groupWithBezierPaths:(NSArray*)paths objectType:(NSInteger)type style:(DKStyle*)style
{
    NSMutableArray* objects = [NSMutableArray array];
    NSEnumerator* iter = [paths objectEnumerator];
    NSBezierPath* path;
    DKDrawableObject* od;

    while ((path = [iter nextObject])) {
        if (![path isEmpty] && !NSEqualSizes([path bounds].size, NSZeroSize)) {
            if (type == kDKCreateGroupWithShapes)
                od = [DKDrawableShape drawableShapeWithBezierPath:path];
            else if (type == kDKCreateGroupWithPaths)
                od = [DKDrawablePath drawablePathWithBezierPath:path];
            else
                return nil; // illegal

            if (style)
                [od setStyle:style];

            [objects addObject:od];
        }
    }

    return [self groupWithObjects:objects];
}

/** @brief Creates a group from a list of existing objects

 Initial location is at the centre of the rectangle that bounds all of the contributing objects.
 the objects can be newly created or already existing as part of a drawing. Grouping the objects
 will change the parent of the object but not the owner until the group is placed. The group should
 be added to a drawing layer after creation. The higher level "group" command in the drawing layer
 class will set up a group from the selection.
 @param objects a list of drawable objects
 @return a new group object consisting of the objects supplied
 */
+ (DKShapeGroup*)groupWithObjects:(NSArray*)objects
{
    DKShapeGroup* group = [[DKShapeGroup alloc] initWithObjectsInArray:objects];

    return [group autorelease];
}

/** @brief Filters array to remove objects whose class returns NO to isGroupable.
 @param array a list of drawable objects
 @return an array of the same objects less those that can't be grouped
 */
+ (NSArray*)objectsAvailableForGroupingFromArray:(NSArray*)array
{
    NSMutableArray* groupables = [NSMutableArray array];
    NSEnumerator* iter = [array objectEnumerator];
    DKDrawableObject* od;

    while ((od = [iter nextObject])) {
        if ([[od class] isGroupable])
            [groupables addObject:od];
    }

    return groupables;
}

#pragma mark -

/** @brief Initialises a group from a list of existing objects

 Designated initialiser. initial location is at the centre of the rectangle that bounds all of
 the contributing objects.
 the objects can be newly created or already existing as part of a drawing. Grouping the objects
 will change the parent of the object but not the owner until the group is placed. The group should
 be added to a drawing layer after creation. The higher level "group" command in the drawing layer
 class will set up a group from the selection.
 @param objects a list of drawable objects
 @return the group object
 */
- (id)initWithObjectsInArray:(NSArray*)objects
{
    self = [super init];
    if (self != nil) {
        [self setGroupObjects:objects];

        if (m_objects == nil) {
            [self autorelease];
            self = nil;
        }
    }
    if (self != nil) {
        NSBezierPath* path = [NSBezierPath bezierPathWithRect:[[self class] unitRectAtOrigin]];
        [self setPath:path];

        //[self setCacheOptions:kDKGroupCacheUsingCGLayer];
    }
    return self;
}

#pragma mark -
#pragma mark - setting up the group

/** @brief Sets up the group state from the original set of objects

 This sets the initial size and location of the group, and adjusts the position of each object so
 it is relative to the group, not the original drawing. It also sets the parent member of each object
 to the group so that the group's transform is applied when the objects are drawn.
 @param objects the set of objects to be grouped
 */
- (void)setGroupObjects:(NSArray*)objects
{
    NSArray* groupObjects = [[self class] objectsAvailableForGroupingFromArray:objects];

    if ([groupObjects count] < 2)
        return;

    // set the group's geometry:

    [self calcBoundingRectOfObjects:groupObjects];
    [self setSize:mBounds.size];
    [self setLocation:NSMakePoint(NSMidX(mBounds), NSMidY(mBounds))];

    // become the owner of these objects - sets object's container to self (undoably):

    [self setObjects:groupObjects];

    // set the initial coordinates for the objects so they are relative to the group location

    NSPoint loc;

    NSEnumerator* iter = [m_objects objectEnumerator];
    DKDrawableObject* obj;

    while ((obj = [iter nextObject])) {
        loc = [self convertPointFromContainer:[obj location]];
        [obj setLocation:loc];
    }
}

/** @brief Gets the list of objects contained by the group
 @return the list of contained objects
 */
- (NSArray*)groupObjects
{
    return m_objects;
}

/** @brief Sets the current list of objects to the given objects

 This is a low level method called by setGroupObjects: it implements the undoable part of building
 a group. It should not be directly called.
 @param objects the objects to be grouped */
- (void)setObjects:(NSArray*)objects
{
    if (objects != [self groupObjects]) {
        [[self undoManager] registerUndoWithTarget:self
                                          selector:@selector(setObjects:)
                                            object:m_objects];

        [objects retain];
        [m_objects release];
        m_objects = objects;

        [m_objects makeObjectsPerformSelector:@selector(groupWillAddObject:)
                                   withObject:self];
        [m_objects makeObjectsPerformSelector:@selector(setContainer:)
                                   withObject:self];
    }
}

/** @brief Computes the initial overall bounding rect of the constituent objects

 This sets the _bounds member to the union of the apparent bounds of the constituent objects. This
 rect represents the original size and position of the group, and does not change even if the group
 is moved or resized - transforms are calculated by comparing the original bounds to the instantaneous
 size and position.
 @param objects the objects to be grouped */
- (void)calcBoundingRectOfObjects:(NSArray*)objects
{
    NSRect bounds = NSZeroRect;
    NSEnumerator* iter = [objects objectEnumerator];
    DKDrawableObject* obj;

    // WARNING!! Do NOT use NSUnionRect here - it doesn't work when bounds height or width is 0 as is the case with
    // paths consisting of straight lines at orthogonal angles

    while ((obj = [iter nextObject]))
        bounds = UnionOfTwoRects(bounds, NormalizedRect([obj logicalBounds]));

    mBounds = bounds;
}

/** @brief Computes the extra space needed for the objects
 @param objects the objects to be grouped
 @return a size, the maximum width and height needed to be added to the logical bounds to accomodate the
 objects visually. */

/** @brief Returns the extra space needed to display the object graphically. This will usually be the difference
 between the logical and reported bounds.

 The result is the max of all the contained objects
 @return the extra space required
 */
- (NSSize)extraSpaceNeededByObjects:(NSArray*)objects
{
    NSEnumerator* iter = [objects objectEnumerator];
    DKDrawableObject* obj;
    NSSize extra, ms = NSMakeSize(0, 0);

    while ((obj = [iter nextObject])) {
        extra = [obj extraSpaceNeeded];

        if (extra.width > ms.width)
            ms.width = extra.width;

        if (extra.height > ms.height)
            ms.height = extra.height;
    }

    return ms;
}

/** @brief Returns the original untransformed bounds of the grouped objects
 @return the original group bounds
 */
- (NSRect)groupBoundingRect
{
    return mBounds;
}

/** @brief Returns the scale ratios that the group is currently applying to its contents.

 The scale ratio is the ratio between the group's original bounds and its current size.
 @return the scale ratios
 */
- (NSSize)groupScaleRatios
{
    NSSize sr;

    sr.width = [self size].width / mBounds.size.width;
    sr.height = [self size].height / mBounds.size.height;

    return sr;
}

#pragma mark -
#pragma mark - transforms

/** @brief Returns a transform used to map the contained objects to the group's size, position and angle.

 This transform is used when drawing the group's contents
 @return a transform object */
- (NSAffineTransform*)contentTransform
{
    CGFloat sx, sy;

    sx = [self size].width / mBounds.size.width;
    sy = [self size].height / mBounds.size.height;

    NSPoint p = NSZeroPoint;
    p = [[self transform] transformPoint:p];

    NSAffineTransform* xform = [NSAffineTransform transform];
    [xform translateXBy:p.x
                    yBy:p.y];
    [xform rotateByRadians:[self angle]];

    if (sx != 0.0 && sy != 0.0)
        [xform scaleXBy:sx
                    yBy:sy];

    return xform;
}

/** @brief Maps a point from the original container's coordinates to the equivalent group point

 The container will be usually a layer or another group.
 @param p a point
 @return a new point */
- (NSPoint)convertPointFromContainer:(NSPoint)p
{
    // given a point <p> in the container's coordinates, returns the same point relative to this group

    NSAffineTransform* ct = [self contentTransform];
    [ct invert];
    return [ct transformPoint:p];
}

/** @brief Maps a point from the group's coordinates to the equivalent original container point

 The container will be usually a layer or another group.
 @param p a point
 @return a new point */
- (NSPoint)convertPointToContainer:(NSPoint)p
{
    return [[self contentTransform] transformPoint:p];
}

- (void)drawGroupContent
{
    NSEnumerator* iter = [[self groupObjects] objectEnumerator];
    DKDrawableShape* od;

    if (m_transformVisually) {
        [NSGraphicsContext saveGraphicsState];
        NSAffineTransform* tfm = [self contentTransform];
        [tfm concat];
    }

    while ((od = [iter nextObject])) {
        if ([od visible]) {
            [od setBeingHitTested:[self isBeingHitTested]];
            [od drawContentWithSelectedState:NO];
            [od setBeingHitTested:NO];
        }
    }

    if (m_transformVisually)
        [NSGraphicsContext restoreGraphicsState];
}

/*
- (NSData*)				pdfDataOfObjects
{
	NSData* pdfData = nil;
	
	if([[self groupObjects] count] > 0 )
	{
		NSRect	fr = NSZeroRect;
		
		fr.size = [[self drawing] drawingSize];
		
		DKGroupPDFView*		pdfView = [[DKGroupPDFView alloc] initWithFrame:fr withGroup:self];
		DKViewController*	vc = [pdfView makeViewController];
		
		[[self drawing] addController:vc];
		
		NSRect sr = mBounds;
		pdfData = [pdfView dataWithPDFInsideRect:sr];
		[pdfView release];
	}
	return pdfData;
}
*/

- (void)setClipContentToPath:(BOOL)clip
{
    if (clip != mClipContentToPath) {
        [[[self undoManager] prepareWithInvocationTarget:self] setClipContentToPath:mClipContentToPath];
        mClipContentToPath = clip;
        [self notifyVisualChange];
    }
}

- (BOOL)clipContentToPath
{
    return mClipContentToPath;
}

- (void)setTransformsVisually:(BOOL)tv
{
    if (tv != m_transformVisually) {
        m_transformVisually = tv;
        [self notifyVisualChange];
    }
}

- (BOOL)transformsVisually
{
    return m_transformVisually;
}

#pragma mark -
#pragma mark - content caching

- (void)setCacheOptions:(DKGroupCacheOption)cacheOption
{
    if (cacheOption != mCacheOption) {
        mCacheOption = cacheOption;
        [self invalidateCache];
    }
}

- (DKGroupCacheOption)cacheOptions
{
    return mCacheOption;
}

- (void)updateCache
{
    // currently no-op
}

- (void)invalidateCache
{
    // currently no-op
}

- (void)drawUntransformedContent
{
    // draws the group content without applying any transforms - this is used to capture the original state of the
    // contents into a cached context.

    mIsWritingToCache = YES;
    [self drawGroupContent];
    mIsWritingToCache = NO;
}

#pragma mark -
#pragma mark - ungrouping

/** @brief Unpacks the group back into the nominated layer 

 Usually it's better to call the higher level ungroupObjects: action method which calls this. This
 method strives to preserve as much information about the objects as possible - e.g. their rotation
 angle and size. Nested groups can cause distortions which are visually preserved though the bounds
 muct necessarily be altered. Objects are inserted into the layer at the same Z-index position as
 the group currently occupies.
 @param layer the layer into which the objects are unpacked */
- (void)ungroupToLayer:(DKObjectDrawingLayer*)layer
{
    [[self undoManager] registerUndoWithTarget:self
                                      selector:@selector(setObjects:)
                                        object:m_objects];

    // discover our own Z-position - ungrouped objects will be inserted at this position

    NSInteger groupIndex = [layer indexOfObject:self];

    LogEvent_(kReactiveEvent, @"will ungroup %d objects, inserting at %d", [m_objects count], groupIndex);

    NSEnumerator* iter = [m_objects objectEnumerator];
    DKDrawableObject* obj;
    NSAffineTransform* tfm;
    NSInteger insertIndex = groupIndex;

    if (m_transformVisually)
        tfm = [self contentTransform];
    else
        tfm = [self renderingTransform];

    while ((obj = [iter nextObject])) {
        // set the object's container to the layer it will become part of, so its transform is not influenced
        // by the group for the next step.

        [obj setContainer:layer];

        // groups, paths and shapes all have slightly different needs here. Thus each kind needs to implement
        // group:willUngroupObjectWithTransform: in order to do the right thing to ungroup itself correctly.

        [obj group:self
            willUngroupObjectWithTransform:tfm];

        // if resulting object is still valid, use it, otherwise it is skipped and will be discarded

        if ([obj objectIsValid]) {
            [layer insertObject:obj
                inObjectsAtIndex:insertIndex++];
        }
    }

    [layer exchangeSelectionWithObjectsFromArray:m_objects];

    [m_objects makeObjectsPerformSelector:@selector(objectWasUngrouped)];

    [layer didUngroupObjects:m_objects];

    [m_objects release];
    m_objects = nil;
}

/** @brief High-level call to ungroup the group.

 Undoably ungroups this and replaces itself in its layer by its contents
 @param sender the sender of the action
 */
- (IBAction)ungroupObjects:(id)sender
{
#pragma unused(sender)

    // note to self - consider what to do if ungrouping could place objects offscreen

    DKObjectDrawingLayer* odl = (DKObjectDrawingLayer*)[self layer];

    if ([odl shouldUngroup:self]) {
        [odl recordSelectionForUndo];
        [self ungroupToLayer:odl];
        [odl removeObject:self];
        [odl commitSelectionUndoWithActionName:NSLocalizedString(@"Ungroup", @"undo string for ungroup")];
    }
}

/** @brief High-level call to toggle path clipping.
 @param sender the sender of the action
 */
- (IBAction)toggleClipToPath:(id)sender
{
#pragma unused(sender)

    [self setClipContentToPath:![self clipContentToPath]];
    [[self undoManager] setActionName:NSLocalizedString(@"Toggle Clipping", @"undo action for toggle clipping (group)")];
}

#pragma mark -
#pragma mark As a DKDrawableShape

/** @brief Overrides this method to ensure it has no effect */
- (void)resetBoundingBox
{
}

/** @brief Overrides this method to ensure it has no effect */
- (void)resetBoundingBoxAndRotation
{
}

/** @brief Overrides this method to ensure it has no effect

 Distortion operations cannot be applied to a group
 @param mode ignored */
- (void)setOperationMode:(NSInteger)mode
{
#pragma unused(mode)
}

#pragma mark -
#pragma mark As a DKDrawableObject

- (NSRect)bounds
{
    mBoundsCache = NSZeroRect;
    return [super bounds];
}

- (NSSet*)allStyles
{
    // return the union of all the contained objects' styles

    NSEnumerator* iter = [[self groupObjects] objectEnumerator];
    NSSet* styles;
    NSMutableSet* unionOfAllStyles = nil;
    DKDrawableObject* dko;

    while ((dko = [iter nextObject])) {
        styles = [dko allStyles];

        if (styles != nil) {
            // we got one - make a set to union them with if necessary

            if (unionOfAllStyles == nil)
                unionOfAllStyles = [styles mutableCopy];
            else
                [unionOfAllStyles unionSet:styles];
        }
    }

    return [unionOfAllStyles autorelease];
}

- (NSSet*)allRegisteredStyles
{
    // return the union of all the contained objects' registered styles

    NSEnumerator* iter = [[self groupObjects] objectEnumerator];
    NSSet* styles;
    NSMutableSet* unionOfAllStyles = nil;
    DKDrawableObject* dko;

    while ((dko = [iter nextObject])) {
        styles = [dko allRegisteredStyles];

        if (styles != nil) {
            // we got one - make a set to union them with if necessary

            if (unionOfAllStyles == nil)
                unionOfAllStyles = [styles mutableCopy];
            else
                [unionOfAllStyles unionSet:styles];
        }
    }

    return [unionOfAllStyles autorelease];
}

- (void)replaceMatchingStylesFromSet:(NSSet*)aSet
{
    // propagate this to all objects in the group:

    [[self groupObjects] makeObjectsPerformSelector:@selector(replaceMatchingStylesFromSet:)
                                         withObject:aSet];
}

/** @brief Draws the objects within the group.

 Depending on how the group's transforms are set to work, this either sets up the graphics context
 and renders the objects directly, or else it relies on the objects calling back to get the
 parent transform and applying it correctly. */
- (void)drawContent
{
    SAVE_GRAPHICS_CONTEXT

    // apply any path as a clipping path

    if ([self clipContentToPath])
        [[self renderingPath] addClip];

    [self drawGroupContent];

    RESTORE_GRAPHICS_CONTEXT
}

/** @brief Draws the objects within the group but using the given style.

 Depending on how the group's transforms are set to work, this either sets up the graphics context
 and renders the objects directly, or else it relies on the objects calling back to get the
 parent transform and applying it correctly.
 @param aStyle some style object */
- (void)drawContentWithStyle:(DKStyle*)aStyle
{
    if (m_transformVisually) {
        [NSGraphicsContext saveGraphicsState];
        NSAffineTransform* tfm = [self contentTransform];
        [tfm concat];
    }

    [[self groupObjects] makeObjectsPerformSelector:@selector(drawContentWithStyle:)
                                         withObject:aStyle];

    if (m_transformVisually)
        [NSGraphicsContext restoreGraphicsState];
}

/** @brief Draws the group's selection highlight.

 If set to clip the contents, the clipping path is also highlighted */
- (void)drawSelectedState
{
    if ([self clipContentToPath])
        [self drawSelectionPath:[self renderingPath]];

    [super drawSelectedState];
}

- (NSSize)extraSpaceNeeded
{
    return [self extraSpaceNeededByObjects:[self groupObjects]];
}

/** @brief Adds group commands to the contextual menu
 @param theMenu a menu to populate
 @return YES */
- (BOOL)populateContextualMenu:(NSMenu*)theMenu
{
    [[theMenu addItemWithTitle:NSLocalizedString(@"Ungroup", @"menu item for ungroup")
                        action:@selector(ungroupObjects:)
                 keyEquivalent:@""] setTarget:self];
    [[theMenu addItemWithTitle:NSLocalizedString(@"Paste Style", @"menu item for paste style")
                        action:@selector(pasteDrawingStyle:)
                 keyEquivalent:@""] setTarget:self];
    [[theMenu addItemWithTitle:NSLocalizedString(@"Clip Contents", @"menu item for toggle clipping")
                        action:@selector(toggleClipToPath:)
                 keyEquivalent:@""] setTarget:self];
    return YES;
}

/** @brief Propagates a style change to all objects in the group

 This is a convenience method - often groups will contain objects with different styles. If you do
 want to apply a style to a number of different objects you can group them and call this.
 @param style the style to apply
 */
- (void)setStyle:(DKStyle*)style
{
    // copies the style to all objects in the group, as a convenient way to set styles for several objects at once

    [[self groupObjects] makeObjectsPerformSelector:@selector(setStyle:)
                                         withObject:style];
    [self notifyVisualChange];
}

/** @brief Returns a style from the group

 In general, it makes little sense to ask a group for its style, since there are multiple
 objects contained which could have many styles. Instead, the -allStyles method will return a complete
 set of all styles referenced by the group. To emphasise this point, asking a group for its style
 always returns nil
 @return nil
 */
- (DKStyle*)style
{
    return nil;
}

/** @brief This object is being ungrouped from a group

 When ungrouping, an object must help the group to the right thing by resizing, rotating and repositioning
 itself appropriately. At the time this is called, the object has already has its container set to
 the layer it will be added to but has not actually been added.
 @param aGroup the group containing the object
 @param aTransform the transform that the group is applying to the object to scale rotate and translate it.
 */
- (void)group:(DKShapeGroup*)aGroup willUngroupObjectWithTransform:(NSAffineTransform*)aTransform
{
    // groups within groups can be tricky, as multiple transforms apply and they are hard.
    // currently, this implementation is unable to preserve combined rotated and scaled groups exactly because
    // the resulting paths should be skewed but after ungrouping they will not be.

    NSPoint p = [self location];
    NSSize gs = [self size];

    CGFloat sx, sy;

    sx = [aGroup size].width / [aGroup groupBoundingRect].size.width;
    sy = [aGroup size].height / [aGroup groupBoundingRect].size.height;

    gs.width *= sx;
    gs.height *= sy;

    if (gs.width != 0.0 && gs.height != 0.0) {
        [self rotateByAngle:[aGroup angle]]; // preserve rotated bounds
        [self setSize:gs];
        [self setLocation:[aTransform transformPoint:p]];
    } else
        [self setSize:NSZeroSize]; // force object to become invalid
}

/** @brief If the object's style is currently sharable, copy it and make it non-sharable.

 If the style is already non-sharable, this does nothing. The purpose of this is to detach this
 from it style such that it has its own private copy. It does not change appearance.
 */
- (void)detachStyle
{
    // detaches the styles of all of its contained objects

    [[self groupObjects] makeObjectsPerformSelector:_cmd];
}

- (void)setGhosted:(BOOL)ghosted
{
    NSEnumerator* iter = [[self groupObjects] objectEnumerator];
    DKDrawableObject* obj;

    while ((obj = [iter nextObject]))
        [obj setGhosted:ghosted];

    [self notifyVisualChange];
}

- (BOOL)isGhosted
{
    NSEnumerator* iter = [[self groupObjects] objectEnumerator];
    DKDrawableObject* obj;

    while ((obj = [iter nextObject])) {
        if ([obj isGhosted])
            return YES;
    }

    return NO;
}

/** @brief The object was added to a layer

 Propagates this to the contained objects
 @param aLayer the layer this was added to
 */
- (void)objectWasAddedToLayer:(DKObjectOwnerLayer*)aLayer
{
    [super objectWasAddedToLayer:aLayer];
    [[self groupObjects] makeObjectsPerformSelector:_cmd
                                         withObject:aLayer];
}

/** @brief The object was removed from the layer

 Propagates this to the contained objects
 @param aLayer the layer this was removed from
 */
- (void)objectWasRemovedFromLayer:(DKObjectOwnerLayer*)aLayer
{
    [super objectWasRemovedFromLayer:aLayer];
    [[self groupObjects] makeObjectsPerformSelector:_cmd
                                         withObject:aLayer];
}

/** @brief The object's container changed

 Propagates this to the contained objects. This does not actually change their container (which is
 self) but if they are relying on other changes such as the parent layer to trigger other effects,
 this ensures that happens correctly when the groups container changes (such as on delete).
 @param aContainer the object's container
 */
- (void)setContainer:(id<DKDrawableContainer>)aContainer
{
    [super setContainer:aContainer];
    [[self groupObjects] makeObjectsPerformSelector:_cmd
                                         withObject:self];
}

#pragma mark -
#pragma mark As an NSObject

- (id)init
{
    self = [super init];
    if (self != nil) {
        NSBezierPath* path = [NSBezierPath bezierPathWithRect:[[self class] unitRectAtOrigin]];
        [self setPath:path];
        //[self setCacheOptions:kDKGroupCacheUsingCGLayer];
    }
    return self;
}

- (void)dealloc
{
    [self invalidateCache];
    [m_objects makeObjectsPerformSelector:@selector(setContainer:)
                               withObject:nil];
    [m_objects release];
    [super dealloc];
}

#pragma mark -
#pragma mark As part of DKDrawableContainer Protocol

/** @brief Returns a transform which is the accumulation of all the parent objects above this one.

 Drawables will request and apply this transform when rendering. Either the identity matrix is
 returned if the group is visually transforming the result, or a combination of the parents above
 and the content transform. Either way contained objects are oblivious and do the right thing.
 @return a transform object */
- (NSAffineTransform*)renderingTransform
{
    // returns the concatenation of all groups and layers transforms containing this one

    if (mIsWritingToCache) {
        NSAffineTransform* stf = [NSAffineTransform transform];
        //[stf translateXBy:m_bounds.origin.x yBy:m_bounds.origin.y];
        return stf;
    } else {
        NSAffineTransform* tfm = [self containerTransform];

        if (m_transformVisually)
            return tfm;
        else {
            NSAffineTransform* ct = [self contentTransform];

            if (tfm) {
                [tfm prependTransform:ct];
                return tfm;
            } else
                return ct;
        }
    }
}

- (NSUInteger)indexOfObject:(DKDrawableObject*)obj
{
    return [[self groupObjects] indexOfObject:obj];
}

- (DKImageDataManager*)imageManager
{
    return [[self drawing] imageManager];
}

- (id)metadataObjectForKey:(NSString*)key
{
    return [super metadataObjectForKey:key];
}

#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)encodeWithCoder:(NSCoder*)coder
{
    NSAssert(coder != nil, @"Expected valid coder");
    [super encodeWithCoder:coder];

    [coder encodeRect:mBounds
               forKey:@"group_bounds"];
    [coder encodeObject:[self groupObjects]
                 forKey:@"groupedobjects"];
    [coder encodeBool:[self clipContentToPath]
               forKey:@"DKShapeGroup_clipContent"];
}

- (id)initWithCoder:(NSCoder*)coder
{
    NSAssert(coder != nil, @"Expected valid coder");
    self = [super initWithCoder:coder];
    if (self != nil) {
        [self setObjects:[coder decodeObjectForKey:@"groupedobjects"]];

        if (m_objects == nil) {
            [self autorelease];
            self = nil;
        }
    }
    if (self != nil) {
        [[self path] appendBezierPathWithRect:[[self class] unitRectAtOrigin]];
        mBounds = [coder decodeRectForKey:@"group_bounds"];

        mClipContentToPath = [coder decodeBoolForKey:@"DKShapeGroup_clipContent"];
    }

    return self;
}

#pragma mark -
#pragma mark As part of NSCopying Protocol
- (id)copyWithZone:(NSZone*)zone
{
    DKShapeGroup* copy = [super copyWithZone:zone];

    NSMutableArray* objectsCopy = [[NSMutableArray alloc] init];
    NSEnumerator* iter = [[self groupObjects] objectEnumerator];
    DKDrawableShape* obj;
    DKDrawableShape* copyOfObj;

    // make a deep copy of the group's objects

    while ((obj = [iter nextObject])) {
        copyOfObj = [obj copyWithZone:zone];

        [objectsCopy addObject:copyOfObj];
        [copyOfObj setContainer:copy];
        [copyOfObj release];
    }

    copy->m_objects = objectsCopy;
    copy->mBounds = mBounds;
    copy->mClipContentToPath = mClipContentToPath;

    [copy setCacheOptions:[self cacheOptions]];
    [copy updateCache];

    return copy;
}

#pragma mark -
#pragma mark As part of NSMenuValidation Protocol
- (BOOL)validateMenuItem:(NSMenuItem*)item
{
    SEL action = [item action];

    if (action == @selector(setDistortMode:) || action == @selector(resetBoundingBox:) || action == @selector(convertToPath:))
        return NO;

    if (action == @selector(toggleClipToPath:)) {
        [item setState:[self clipContentToPath] ? NSOnState : NSOffState];
        return YES;
    }

    if (action == @selector(ungroupObjects:))
        return ![self locked];

    return [super validateMenuItem:item];
}

@end
