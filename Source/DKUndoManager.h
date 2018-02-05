/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Foundation/Foundation.h>
#import "GCUndoManager.h"

#define USE_GC_UNDO_MANAGER 0

#if USE_GC_UNDO_MANAGER

/**
 This subclass of \c NSUndoManager can coalesce consecutive tasks that it receives so that only one task is recorded to undo a series of
 otherwise identical ones. This is very useful when interactively editing objects where a large stream of identical tasks can be
 received. It is largely safe to use with coalescing enabled even for normal undo situations, so coalescing is enabled by default.

 It also records a change count which is an easy way to check if the state of the undo stack has changed from some earlier time -
 just compare the change count with one you recorded earlier.

************* NOTE - THIS DOES NOT WORK - DO NOT ENABLE GROUP DEFERRAL!! ***************

 Group deferral is another useful thing that works around an \c NSUndoManager bug. When \c -beginUndoGrouping is called, the group is not
 actually opened at that point - instead it is flagged as deferred. If an actual task is received, the group is opened if the
 defer flag is set. This ensures that a group is only created when there is something to put in it - \c NSUndoManager creates a
 bogus Undo item on the stack for empty groups. This allows client code to simply open a group on mouse down, do stuff in dragged,
 and close the group at mouse up without creating bogus stack states.
*/
@interface DKUndoManager : GCUndoManager

- (BOOL)enableUndoTaskCoalescing:(BOOL)enable;

@end

#else

@interface DKUndoManager : NSUndoManager {
@private
	BOOL mCoalescingEnabled;
	BOOL mEmulate105Behaviour;
	id mSkipTargetRef;
	id mLastTargetRef;
	NSUInteger mChangeCount;
	NSUInteger mChangePerGroupCount;
	BOOL mInPrivateMethod;
	BOOL mSkipTask;
	SEL mLastSelector;
	id mTarget;
}

- (BOOL)enableUndoTaskCoalescing:(BOOL)enable;
@property (readonly, getter=isUndoTaskCoalescingEnabled) BOOL undoTaskCoalescingEnabled;

@property (readonly) NSUInteger changeCount;
- (void)resetChangeCount;

@property (readonly) NSUInteger numberOfTasksInLastGroup;

- (void)enableSnowLeopardBackwardCompatibility:(BOOL)slpEnable;
- (void)invokeEmbeddedInvocation:(NSInvocation*)invocation;

- (BOOL)hasStupidIncompatibleSnowLeopardChange;

- (void)reset;

@end

#endif
