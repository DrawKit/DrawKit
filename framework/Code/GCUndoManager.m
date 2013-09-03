//
//  GCUndoManager.m
//  GCDrawKit
//
//  Created by graham on 4/12/09.
//  Copyright 2009 Apptree.net. All rights reserved.
//

#import "GCUndoManager.h"

// this proxy object is returned by -prepareWithInvocationTarget: if GCUM_USE_PROXY is 1. This provides a similar behaviour to NSUndoManager
// on 10.6 so that a wider range of methods can be submitted as undo tasks. Unlike 10.6 however, it does not bypass um's -forwardInvocation:
// method, so subclasses still work when -forwardInvocaton: is overridden.


@interface GCUndoManagerProxy : NSProxy
{
@private
	GCUndoManager*		mUndoManager;
	id					mNextTarget;
}

- (id)					initWithUndoManager:(GCUndoManager*) um;
- (void)				forwardInvocation:(NSInvocation*) inv;
- (NSMethodSignature*)	methodSignatureForSelector:(SEL) selector;
- (BOOL)				respondsToSelector:(SEL) selector;
- (void)				_gcum_setTarget:(id) target;

@end

// if this is set to 0 no proxy is used and -prepareWithInvocationTarget: returns the undo manager itself.
// In general using the proxy is recommended. NSUndoManager uses a proxy on 10.6 and later, but does not on 10.5 and earlier.

#define GCUM_USE_PROXY	1

// the grouping level is maintained as groups are opened and closed. The GNUStep implementation works it out by traversing
// the tree of open groups. They should both give the same answer - you can do it using traversal by setting this to 1 if you want.

#define CALCULATE_GROUPING_LEVEL	0


#pragma mark -


@implementation GCUndoManager

- (void)				beginUndoGrouping
{
	// starts a new group. If there's an existing one open, this is nested inside it. A group must be opened before any undo tasks can be
	// accumulated. If groupsByEvent is YES, a group will be automatically opened and closed around the main event loop when the first
	// valid task is submitted. Unlike NSUndoManger it is safe to merely open and then close a group with no tasks submitted
	// - the empty group is (optionally) removed automatically. (see -endUndoGrouping)
	
	GCUndoGroup* newGroup = [[GCUndoGroup alloc] init];
	
	THROW_IF_FALSE( newGroup != nil, @"unable to create new group");
	
	if( mGroupLevel == 0 )
	{
		if([self isUndoing])
			[self pushGroupOntoRedoStack:newGroup];
		else
			[self pushGroupOntoUndoStack:newGroup];
	}
	else
	{
		THROW_IF_FALSE( mOpenGroupRef != nil, @"internal inconsistency - group level was > 0 but no open group was found");
		
		[[self currentGroup] addTask:newGroup];
	}
	
	mOpenGroupRef = newGroup;
	[newGroup release];
	
	if(![self isUndoing] && mGroupLevel > 0 )
		[self checkpoint];
	
	++mGroupLevel;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:NSUndoManagerDidOpenUndoGroupNotification object:self];
}



- (void)				endUndoGrouping
{
	// close the current group. If the group level is 1, this completes the top-level group. Otherwise restore the group that
	// was operating when this group was opened (its parent group). If no top level group is open, does nothing.
	
	if( mGroupLevel > 0 )
	{
		[self checkpoint];
		
		--mGroupLevel;
		
		THROW_IF_FALSE( mOpenGroupRef != nil, @"bad group state - attempt to close a nested group with no group open");
		
		if( mGroupLevel == 0 )
		{
			// closing outer group. If it's empty, remove it. This is what NSUndoManager should do, but doesn't. That means that this
			// um is easier to use in some situations such as grouping across a series of events that may or may not submit undo tasks.
			// If no tasks were submitted, no bogus empty undo task remains on the stack. In addition no closure notification is sent
			// so as far as the client is concerned, it just never happened.
			
			@try
			{
				if([self automaticallyDiscardsEmptyGroups] && [[self currentGroup] isEmpty])
				{
					if([self isUndoing])
						[self popRedo];
					else
						[self popUndo];
				}
				else if([self undoManagerState] == kGCUndoCollectingTasks)
				{
					// this notification is not exactly in line with documentation, but it correctly ensures that NSDocument's change count
					// management is correct. I suspect that the documentation is in error.
					
					[[NSNotificationCenter defaultCenter] postNotificationName:NSUndoManagerWillCloseUndoGroupNotification object:self];
				}
			}
			@catch( NSException* excp )
			{
				NSLog(@"an exception occurred while closing an undo group - ignored: %@", excp );
			}
			@finally
			{
				//NSLog(@"top level group closed: %@", mOpenGroupRef);
				
				mOpenGroupRef = nil;
				
				// keep the number of undo tasks at the top level limited to the undoLevels
				// by discarding the oldest tasks
				
				if([self levelsOfUndo] > 0 && !mIsRemovingTargets)
				{
					mIsRemovingTargets = YES;
					
					while([self numberOfUndoActions] > [self levelsOfUndo])
						[mUndoStack removeObjectAtIndex:0];
					
					mIsRemovingTargets = NO;
				}
			}
		}
		else
		{
			// closing an inner nested group, so restore its containing group as the open one.
			
			mOpenGroupRef = [[self currentGroup] parentGroup];
			
			THROW_IF_FALSE( mOpenGroupRef != nil, @"nested group could not be restored - bad parent group ref");
		}
	}
}



- (BOOL)				canUndo
{
	return [self numberOfUndoActions] > 0 && [self undoManagerState] == kGCUndoCollectingTasks;
}



- (BOOL)				canRedo
{
	[self checkpoint];	// why here? Just conforming to documentation
	return [self numberOfRedoActions] > 0 && [self undoManagerState] == kGCUndoCollectingTasks;
}



- (void)				undo
{
	THROW_IF_FALSE([self groupingLevel] < 2, @"can't undo with a nested group open");
	
	[self endUndoGrouping];
	[self undoNestedGroup];
}



- (void)				redo
{
	THROW_IF_FALSE([self undoManagerState] == kGCUndoCollectingTasks, @"can't redo - already undoing or redoing");
	THROW_IF_FALSE([self groupingLevel] == 0, @"can't redo - a group is still open");
	
	[self checkpoint];
	[self popRedoAndPerformTasks];
}



- (BOOL)				isUndoing
{
	return [self undoManagerState] == kGCUndoIsUndoing;
}



- (BOOL)				isRedoing
{
	return [self undoManagerState] == kGCUndoIsRedoing;
}



- (void)				undoNestedGroup
{
	// warning: this is not the same as NSUndoManager, but does the same as -undo except the top-level group must be closed to invoke this.
	// At present the ability to undo an inner nested group while the top group is still open is not implemented.
	
	THROW_IF_FALSE([self undoManagerState] == kGCUndoCollectingTasks, @"can't undo - already undoing or redoing");
	THROW_IF_FALSE([self groupingLevel] == 0, @"can't undo - a group is still open");
	
	[self checkpoint];
	[self popUndoAndPerformTasks];
}



- (void)				enableUndoRegistration
{
	THROW_IF_FALSE( mEnableLevel < 0, @"inconsistent state - undo enabled when not previously disabled");
	
	++mEnableLevel;
}



- (void)				disableUndoRegistration
{
	--mEnableLevel;
}



- (BOOL)				isUndoRegistrationEnabled
{
	return mEnableLevel >= 0;
}



- (NSUInteger)			groupingLevel
{
#if CALCULATE_GROUPING_LEVEL
	NSUInteger		level = 0;
	GCUndoGroup*	group = [self currentGroup];
	
	while( group )
	{
		++level;
		group = [group parentGroup];
	}
	
	THROW_IF_FALSE( level == mGroupLevel, @"calculated group level does not match recorded level - internal inconsistency");
	
	return level;
#else
	return mGroupLevel;
#endif
}



- (BOOL)				groupsByEvent
{
	return mGroupsByEvent;
}



- (void)				setGroupsByEvent:(BOOL) groupByEvent
{
	mGroupsByEvent = groupByEvent;
}



- (NSUInteger)			levelsOfUndo
{
	return mLevelsOfUndo;
}



- (void)				setLevelsOfUndo:(NSUInteger) levels
{
	mLevelsOfUndo = levels;
	
	// if the new levels are exceeded, trim the stacks accordingly
	
	if( levels > 0 && !mIsRemovingTargets )
	{
		mIsRemovingTargets = YES;
		
		while([self numberOfUndoActions] > levels)
			[mUndoStack removeObjectAtIndex:0];

		while([self numberOfRedoActions] > levels)
			[mRedoStack removeObjectAtIndex:0];
		
		mIsRemovingTargets = NO;
	}
}



- (NSArray*)			runLoopModes
{
	return mRunLoopModes;
}



- (void)				setRunLoopModes:(NSArray*) modes
{
	[modes retain];
	[mRunLoopModes release];
	mRunLoopModes = modes;
	
	// n.b. if this is changed while a callback is pending, the new modes won't take effect until
	// the next event cycle.
}



- (void)				setActionName:(NSString*) actionName
{
	// for compatibility with NSUndoManager, conditionally open a group - this allows an action name to be set
	// before any task is submitted. I think it's incorrect that tasks are nameable before being created and should be
	// named at the end - but if someone's code does that, this allows it to work.
	
	//[self conditionallyBeginUndoGrouping];
	
	if([self isUndoing])
		[[self peekRedo] setActionName:actionName];
	else
		[[self peekUndo] setActionName:actionName];
}



- (NSString*)			undoActionName
{
	return [[self peekUndo] actionName];
}



- (NSString*)			redoActionName
{
	return [[self peekRedo] actionName];
}



- (NSString*)			undoMenuItemTitle
{
	return [self undoMenuTitleForUndoActionName:[self undoActionName]];
}



- (NSString*)			redoMenuItemTitle
{
	return [self redoMenuTitleForUndoActionName:[self redoActionName]];
}



- (NSString*)			undoMenuTitleForUndoActionName:(NSString*) actionName
{
	if([self canUndo])
	{
		if( actionName )
			return [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"Undo", nil), actionName];
		else
			return NSLocalizedString(@"Undo", nil);
	}
	else
		return NSLocalizedString(@"Nothing To Undo", nil);
}



- (NSString*)			redoMenuTitleForUndoActionName:(NSString*) actionName
{
	if([self canRedo])
	{
		if( actionName )
			return [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"Redo", nil), actionName];
		else
			return NSLocalizedString(@"Redo", nil);
	}
	else
		return NSLocalizedString(@"Nothing To Redo", nil);
}



- (id)					prepareWithInvocationTarget:(id) target
{
	// Records the target and returns either the proxy or self. The proxy allows methods also implemented by this class
	// to be recorded as forward invocations, and is generally a good idea (Snow Leopard does the same, but not in
	// a way that is backward compatible with overrides of -forwardInvocation: This implementation does not have that bug.
	
	if( mProxy )
	{
		[mProxy _gcum_setTarget:target];
		return mProxy;
	}
	else
	{
		mNextTarget = target;
		return self;
	}
}



- (void)				forwardInvocation:(NSInvocation*) invocation
{
	// registers a new undo task using a forwarded invocation, called after -prepareWithInvocationTarget: If registration
	// disabled, does nothing, If coalescing enabled and the previous target and selector was the same, also does nothing.
	// Will open a top-level group automtically if necessary and -groupsByEvent is YES.
	
	if([self isUndoRegistrationEnabled])
	{
		THROW_IF_FALSE( invocation != nil, @"-forwardInvocation: was passed an invalid nil invocation" );
		
		GCConcreteUndoTask* task = [[[GCConcreteUndoTask alloc] initWithInvocation:invocation] autorelease];
		[task setTarget:mNextTarget retained:[self retainsTargets]];
		[self submitUndoTask:task];
	}
	mNextTarget = nil;
}



- (void)				registerUndoWithTarget:(id) target selector:(SEL) selector object:(id) anObject
{
	// registers a new undo task using the supplied target, selector and optional object parameter. If registration
	// disabled, does nothing, If coalescing enabled and the previous target and selector was the same, also does nothing.
	// Will open a top-level group automatically if necessary and -groupsByEvent is YES.

	if([self isUndoRegistrationEnabled])
	{
		THROW_IF_FALSE( selector != NULL, @"invalid (NULL) selector passed to registerUndoWithTarget:selector:object:" );
		
		GCConcreteUndoTask* task = [[[GCConcreteUndoTask alloc] initWithTarget:target selector:selector object:anObject] autorelease];
		[task setTarget:target retained:[self retainsTargets]];
		[self submitUndoTask:task];
	}
	mNextTarget = nil;
}


- (void)				removeAllActions
{
	// removes all tasks from the undo/redo stacks and puts the undo manager back into its default state, clearing any open groups
	// or temporary references.
	
	if( !mIsRemovingTargets )
	{
		// prevent re-entrancy, in case targets are retained and releasing them calls -removeAllActionsWithTarget:
		
		mIsRemovingTargets = YES;
		[mUndoStack removeAllObjects];
		[mRedoStack removeAllObjects];
		mIsRemovingTargets = NO;
		[self reset];
	}
}



- (void)				removeAllActionsWithTarget:(id) target
{
	// removes all tasks having the given target. Groups that become empty as a result are also removed.
	
	if( !mIsRemovingTargets )
	{
		// prevent re-entrancy, in case targets are retained and releasing them would call this again

		mIsRemovingTargets = YES;
		
		NSArray*		temp = [[self undoStack] copy];
		NSEnumerator*	iter = [temp objectEnumerator];
		GCUndoGroup*	task;
		
		while(( task = [iter nextObject]))
		{
			[task removeTasksWithTarget:target undoManager:self];
			
			// delete groups that become empty unless it's the current group
			
			if([task isEmpty] && task != [self currentGroup])
			{
				[mUndoStack removeObject:task];
			}
		}
		
		[temp release];
		
		temp = [[self redoStack] copy];
		iter = [temp objectEnumerator];
		
		while(( task = [iter nextObject]))
		{
			[task removeTasksWithTarget:target undoManager:self];
			
			// delete groups that become empty unless it's the current group
			
			if([task isEmpty] && task != [self currentGroup])
			{
				[mRedoStack removeObject:task];
			}
		}
		
		[temp release];
		
		mIsRemovingTargets = NO;
	}
	mNextTarget = nil;
}


#pragma mark -
#pragma mark - private NSUndoManager API

- (void)				_processEndOfEventNotification:(NSNotification*) note
{
#pragma unused(note)
	
	// private API invoked by NSDocument before a document is saved. Does nothing, but required for NSDocument compatibility.
	//NSLog(@"_processEndOfEventNotification: %@", note );
}



#pragma mark -
#pragma mark - additional API

- (void)				setAutomaticallyDiscardsEmptyGroups:(BOOL) autoDiscard
{
	// set whether empty groups are automatically discarded when the top level group is closed. Default is YES. Set to
	// NO for NSUndoManager behaviour - could conceivably be used to trigger undo managed outside of the undo manager.
	// However this behaviour is buggy for normal usage of the undo manager. Setting this from NO to YES does not
	// remove existing empty groups. Used in -endUndoGrouping.
	
	mAutoDeleteEmptyGroups = autoDiscard;
}


- (BOOL)				automaticallyDiscardsEmptyGroups
{
	return mAutoDeleteEmptyGroups;
}



- (void)				enableUndoTaskCoalescing
{
	mCoalescing = YES;
}



- (void)				disableUndoTaskCoalescing
{
	mCoalescing = NO;
}



- (BOOL)				isUndoTaskCoalescingEnabled
{
	return mCoalescing;
}


- (void)				setCoalescingKind:(GCUndoTaskCoalescingKind) kind
{
	// sets the behaviour for coalescing. kGCCoalesceLastTask (default) checks just the most recent task submitted, whereas
	// kGCCoalesceAllMatchingTasks checks all in the current group. Last task is appropriate for property changes such as
	// ABBBBBBA > ABA, where the last A needs to be included but the intermediate B's do not. The other kind is better for changes
	// such as ABABABAB > AB where a repeated sequence is coalesced into a single example of the sequence. 
	
	mCoalKind = kind;
}


- (GCUndoTaskCoalescingKind) coalescingKind;
{
	return mCoalKind;
}


- (void)				setRetainsTargets:(BOOL) retainsTargets
{
	// NSUndoManager does not retain its targets. In general, that is the right thing to do, but simpler memory management can
	// be obtained when targets are retained. The default is NO, and should only be set to YES if you are certain of the consequences.
	// Note that existing invocations are unaffected by this being changed, only subsequent ones are.
	
	mRetainsTargets = retainsTargets;
}


- (BOOL)				retainsTargets
{	
	return mRetainsTargets;
}


- (void)				setNextTarget:(id) target
{
	// for use by the proxy only - sets the target assigned to the next created task
	
	mNextTarget = target;
}


- (NSUInteger)			changeCount
{
	// return the change count, which is roughly the number of individual tasks accepted. However, do not rely on the exact value,
	// instead you can compare it before and after, and if it has changed, then something was added. This could be used to e.g.
	// provide some additional auxiliary undoable state, such as selection changes, which are not normally considered undoable
	// in their own right.
	
	return mChangeCount;
}


- (void)				resetChangeCount
{
	mChangeCount = 0;
}


- (void)				conditionallyBeginUndoGrouping
{
	// if set to groupByEvent and no top-level group is open, this opens the group and schedules its automatic closure. Otherwise
	// does nothing.
	
	if([self groupsByEvent] && [self groupingLevel] == 0 )
	{
		[self beginUndoGrouping];
		
		THROW_IF_FALSE([self groupingLevel] == 1, @"internal inconsistency - group level should be 1 here");
		
		// schedule an automatic close of the group at the end of the event
		
		[[NSRunLoop mainRunLoop] performSelector:@selector(endUndoGrouping) target:self argument:nil order:NSUndoCloseGroupingRunLoopOrdering modes:[self runLoopModes]];
	}
}


- (GCUndoGroup*)		peekUndo
{
	// return the current top undo task without popping it off the stack.
	// If the stack is empty, returns nil.
	
	return [[self undoStack] lastObject];
}



- (GCUndoGroup*)		peekRedo
{
	// return the current top redo task without popping it off the stack
	// If the stack is empty, returns nil.
	
	return [[self redoStack] lastObject];
}



- (NSUInteger)			numberOfUndoActions
{
	return [[self undoStack] count];
}



- (NSUInteger)			numberOfRedoActions
{
	return [[self redoStack] count];
}


- (GCUndoGroup*)		currentGroup
{
	// return the currently open group, or nil if no group is open
	
	return mOpenGroupRef;
}



- (NSArray*)			undoStack
{
	return mUndoStack;
}



- (NSArray*)			redoStack
{
	return mRedoStack;
}



- (void)				pushGroupOntoUndoStack:(GCUndoGroup*) aGroup
{
	THROW_IF_FALSE( aGroup != nil, @"invalid attempt to push a nil group onto undo stack");
	
	[mUndoStack addObject:aGroup];
}



- (void)				pushGroupOntoRedoStack:(GCUndoGroup*) aGroup
{
	THROW_IF_FALSE( aGroup != nil, @"invalid attempt to push a nil group onto redo stack");

	[mRedoStack addObject:aGroup];
}


- (BOOL)				submitUndoTask:(GCConcreteUndoTask*) aTask
{
	// during task collection, this is called to coalesce and add the task to the current group if needed. A group is opened
	// if necessary and groups by Event is YES. This is invoked by -forwardInvocation: and -registerUndoWithTarget:selector:object:
	// returns YES if the task was added, NO if it was not (coalesced away).
	
	THROW_IF_FALSE( aTask != nil, @"invalid task was nil in -submitUndoTask:"); 
	
	// if coalescing, reject invocation that matches an already registered target and selector within the current group.
	// Coalescing is never done while redoing or undoing. Because this matches any already-registered action, not just the
	// last action registered, it will also coalesce actions made up of multiple property changes. The match only checks the
	// current open group, not any subgroups, so opening & closing groups automatically isolates coalescing to the current
	// group scope as it should.
	
	if([self isUndoTaskCoalescingEnabled] && ([self undoManagerState] == kGCUndoCollectingTasks) && ([self currentGroup] != nil ))
	{
		if([self coalescingKind] == kGCCoalesceLastTask)
		{
			GCConcreteUndoTask* lastTask = [[self currentGroup] lastTaskIfConcrete];
			
			if([lastTask target] == [aTask target] && [lastTask selector] == [aTask selector])
				return NO;
		}
		else
		{
			NSArray* matchingTasks = [[self currentGroup] tasksWithTarget:[aTask target] selector:[aTask selector]];
			
			if([matchingTasks count] > 0 )
				return NO;
		}
	}
	
	// for just-in-time grouping, open a group now if not open already and groupsByEvent is YES
	
	[self conditionallyBeginUndoGrouping];
	
	THROW_IF_FALSE( mOpenGroupRef != nil, @"invalid attempt to add undo task with no open group");
	
	// change count is bumped for all registered tasks. Clients can check this to see whether anything was actually
	// submitted for undo, which can be useful when supplying auxiliary undoable state such as selection changes.
	
	++mChangeCount;
	
	[[self currentGroup] addTask:aTask];
	
	//NSLog(@"new task submitted %@: %@", [self isUndoing]? @"to r-stack" : @"to u-stack", aTask );
	
	// if not undoing or redoing, clear the redo stack (a new mainstream task)
	
	if([self undoManagerState] == kGCUndoCollectingTasks )
		[self clearRedoStack];
	
	return YES;
}



- (void)				popUndoAndPerformTasks
{
	// pops the top undo group and invokes all of its tasks
	
	if([self numberOfUndoActions] > 0 && ![[self peekUndo] isEmpty])
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:	NSUndoManagerWillUndoChangeNotification object:self];
		
		[self setUndoManagerState:kGCUndoIsUndoing];
		[self beginUndoGrouping];
		
		// the group is autoreleased so its targets will remain retained at least until the end of the event cycle.
		
		GCUndoGroup* group = [self popUndo];
		
		//NSLog(@"------ undoing ------");
		
		@try
		{
			[group perform];
		}
		@catch( NSException* excp )
		{
			NSLog(@"an exception occurred while performing Undo - undo manager will be cleaned up: %@", excp );
			
			@throw;
		}
		@finally
		{
			// by default copy the action name to the top of the redo stack - client code might
			// change it but if not at least it's set to the same name initially. Safe because this
			// was called between begin/end group, and that method has added an empty group to the
			// relevant stack. If no tasks were actually submitted, the group will be discarded
			
			[[self peekRedo] setActionName:[group actionName]];
			
			[self endUndoGrouping];
			[self setUndoManagerState:kGCUndoCollectingTasks];
			
			[[NSNotificationCenter defaultCenter] postNotificationName:NSUndoManagerDidUndoChangeNotification object:self];
		}
	}
}



- (void)				popRedoAndPerformTasks
{
	// pops the top redo group and invokes all of its tasks
	
	if([self numberOfRedoActions] > 0 && ![[self peekUndo] isEmpty])
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:	NSUndoManagerWillRedoChangeNotification object:self];
		
		[self setUndoManagerState:kGCUndoIsRedoing];
		[self beginUndoGrouping];
		
		GCUndoGroup* group = [self popRedo];
		
		//NSLog(@"------ redoing ------");
		
		@try
		{
			[group perform];
		}
		@catch( NSException* excp )
		{
			NSLog(@"an exception occurred while performing Redo - undo manager will be cleaned up: %@", excp );
			
			@throw;
		}
		@finally
		{
			// by default copy the action name to the top of the undo stack - client code might
			// change it but if not at least it's set to the same name initially
			
			[[self peekUndo] setActionName:[group actionName]];

			[self endUndoGrouping];
			[self setUndoManagerState:kGCUndoCollectingTasks];

			[[NSNotificationCenter defaultCenter] postNotificationName:NSUndoManagerDidRedoChangeNotification object:self];
		}
	}
}


- (GCUndoGroup*)		popUndo
{
	// pops the top undo task and returns it, or nil if the stack is empty.
	
	if([mUndoStack count] > 0 )
	{
		GCUndoGroup* group = [[[self peekUndo] retain] autorelease];
		[mUndoStack removeLastObject];
				
		return group;
	}
	else
		return nil;
}


- (GCUndoGroup*)		popRedo
{
	// pops the top redo task and returns it, or nil if the stack is empty.

	if([mRedoStack count] > 0 )
	{
		GCUndoGroup* group = [[[self peekRedo] retain] autorelease];
		[mRedoStack removeLastObject];
		
		return group;
	}
	else
		return nil;
}


- (void)				clearRedoStack
{
	// removes all objects from the redo stack
	
	if( !mIsRemovingTargets )
	{
		mIsRemovingTargets = YES;
		[mRedoStack removeAllObjects];
		mIsRemovingTargets = NO;
	}
}


- (void)				checkpoint
{
	// sends the checkpoint notification. Frankly, this seems very vague and called at all sorts of random points, so it's unclear
	// exactly what the notification is meant to do. The GNUStep implementation also sends it more than the current documentation
	// for NSUndoManager indicates. This implementation follows the current documentation.
	
	[[NSNotificationCenter defaultCenter] postNotificationName:NSUndoManagerCheckpointNotification object:self];
}


- (GCUndoManagerState)	undoManagerState
{
	return mState;
}


- (void)				setUndoManagerState:(GCUndoManagerState) aState
{
	// sets the current state of the undo manager - called internally, not for client use
	
	mState = aState;
}


- (void)				reset
{
	// puts the undo manager back to its default state. It does not remove anything from the stacks, but will close all groups and re-enable
	// the UM.
	
	[[NSRunLoop mainRunLoop] cancelPerformSelectorsWithTarget:self];
	
	mNextTarget = nil;
	mOpenGroupRef = nil;
	mGroupLevel = 0;
	mCoalKind = kGCCoalesceLastTask;
	mGroupsByEvent = YES;
	mEnableLevel = 0;
	[self setUndoManagerState:kGCUndoCollectingTasks];
}


- (void)				explodeTopUndoAction
{
	// this method takes the top undo group and breaks out the individual tasks in it into a series of single-action groups. It allows
	// you single-step through a series of undo tasks. It is intended primarily to assist with debugging undo/redo of apps where
	// the effect of each individual change can be otherwise hard to isolate. Each new task has the same action name as the original but
	// with an appended step number and the selector string.
	
	if([self canUndo])
	{
		GCUndoGroup*	topGroup = [self popUndo];
		NSEnumerator*	iter = [[topGroup tasks] objectEnumerator];
		NSUInteger		suffix = 0;
		GCUndoTask*		task;
		GCUndoGroup*	newTaskGroup;
		NSString*		selString;
		
		while(( task = [iter nextObject]))
		{
			newTaskGroup = [[GCUndoGroup alloc] init];
			[newTaskGroup addTask:task];
			
			if([task respondsToSelector:@selector(selector)])
				selString = NSStringFromSelector([(GCConcreteUndoTask*)task selector]);
			else
				selString = @"<subgroup>";
			
			[newTaskGroup setActionName:[NSString stringWithFormat:@"%@ (%d: %@)", [topGroup actionName], ++suffix, selString ]];
			[self pushGroupOntoUndoStack:newTaskGroup];
			[newTaskGroup release];
		}
	}
}

#pragma mark -
#pragma mark - as a NSObject

- (id)					init
{
	self = [super init];
	if( self )
	{
		mUndoStack = [[NSMutableArray alloc] init];
		mRedoStack = [[NSMutableArray alloc] init];
		
		mGroupsByEvent = YES;
		mRunLoopModes = [[NSArray arrayWithObject:NSDefaultRunLoopMode] retain];
		mAutoDeleteEmptyGroups = YES;
		mCoalKind = kGCCoalesceLastTask;
		
#if GCUM_USE_PROXY
		mProxy = [[GCUndoManagerProxy alloc] initWithUndoManager:self];
#endif
	}
	
	return self;
}



- (void)				dealloc
{
	[[NSRunLoop mainRunLoop] cancelPerformSelectorsWithTarget:self];
	
	[mUndoStack release];
	[mRedoStack release];
	[mRunLoopModes release];
	[mProxy release];
	[super dealloc];
}


- (NSMethodSignature*)	methodSignatureForSelector:(SEL) aSelector
{
#if !GCUM_USE_PROXY
	if( mNextTarget )
		return [mNextTarget methodSignatureForSelector:aSelector];
	else
#endif
		return [super methodSignatureForSelector:aSelector];
}


- (BOOL)				respondsToSelector:(SEL) aSelector
{
#if !GCUM_USE_PROXY
	if( mNextTarget )
		return [mNextTarget respondsToSelector:aSelector];
	else
#endif
		return [super respondsToSelector:aSelector];
}


- (NSString*)			description
{
	return [NSString stringWithFormat:@"%@ g-level = %d, u-stack: %@, r-stack: %@", [super description], [self groupingLevel], [self undoStack], [self redoStack]];
}


@end

#pragma mark -

@implementation GCUndoTask

- (GCUndoGroup*)		parentGroup
{
	return mGroupRef;
}


- (void)				setParentGroup:(GCUndoGroup*) parent
{
	mGroupRef = parent;
}



- (void)				perform
{
	// abstract class - override to implement
	
	NSAssert( NO, @"-perform must be overridden");
}

@end


#pragma mark -

@implementation GCUndoGroup

- (void)				addTask:(GCUndoTask*) aTask
{
	THROW_IF_FALSE1( aTask != nil, @"invalid attempt to add a nil task to group %@", self );
	
	[mTasks addObject:aTask];
	[aTask setParentGroup:self];
}


- (GCUndoTask*)			taskAtIndex:(NSUInteger) indx
{
	THROW_IF_FALSE2( indx < [[self tasks] count], @"invalid task index (%d) in group %@", indx, self );
	
	return [[self tasks] objectAtIndex:indx];
}


- (GCConcreteUndoTask*)	lastTaskIfConcrete
{
	GCUndoTask* task = [[self tasks] lastObject];
	
	if([task isKindOfClass:[GCConcreteUndoTask class]])
		return (GCConcreteUndoTask*)task;
	else
		return nil;
}


- (NSArray*)			tasks
{
	return mTasks;
}


- (NSArray*)			tasksWithTarget:(id) target selector:(SEL) selector
{
	// searches this group (but not any subgroups) for tasks matching the target & selector. Pass nil if you don't care about
	// a match (so nil, nil returns all tasks). No matches returns the empty array. This is typically used as part of the coalescing
	// done by the um, where the current open group is checked for a match in order to drop identical tasks.
	
	if( target == nil && selector == NULL )
		return [self tasks];

	NSEnumerator*	iter = [[self tasks] objectEnumerator];
	GCUndoTask*		task;
	NSMutableArray*	tasks = [NSMutableArray array];
	
	while(( task = [iter nextObject]))
	{
		if([task isKindOfClass:[GCConcreteUndoTask class]])
		{
			id targ = [(GCConcreteUndoTask*)task target];
			SEL sel = [(GCConcreteUndoTask*)task selector];
			
			if(( target == nil || target == targ ) && ( selector == NULL || selector == sel ))
				[tasks addObject:task];
		}
	}
	
	return tasks;
}


- (BOOL)				isEmpty
{
	// return whether the group contains any actual tasks. If it only contains other empty groups, returns YES.
	
	if([[self tasks] count] == 0 )
		return YES;
	else
	{
		NSEnumerator*	iter = [[self tasks] objectEnumerator];
		GCUndoTask*		task;
		
		while(( task = [iter nextObject]))
		{
			if([task isKindOfClass:[self class]])
			{
				// is a group - is that one empty?
				
				if( ![(GCUndoGroup*)task isEmpty])
					return NO;
			}
			else
				return NO;
		}
	}
	
	return YES;
}


- (void)				removeTasksWithTarget:(id) aTarget undoManager:(GCUndoManager*) um
{
	// Removes all tasks in this group and any subgroups having the given target.
	// It also removes any subgroups that become empty as a result.
	
	NSArray*		temp = [[self tasks] copy];
	NSEnumerator*	iter = [temp objectEnumerator];
	GCUndoTask*		task;
	
	while(( task = [iter nextObject]))
	{
		if([task respondsToSelector:_cmd])
		{
			[(GCUndoGroup*)task removeTasksWithTarget:aTarget undoManager:um];
			
			if([(GCUndoGroup*)task isEmpty] && [um currentGroup] != task)
				[mTasks removeObject:task];
		}
		else if([task respondsToSelector:@selector(target)])
		{
			if( aTarget == [(GCConcreteUndoTask*)task target])
				[mTasks removeObject:task];
		}
	}
	
	[temp release];
}



- (void)				setActionName:(NSString*) name
{
	// sets the group's action name. In general this is automatically handled by the owning undo manager
	
	[name retain];
	[mActionName release];
	mActionName = name;
}



- (NSString*)			actionName
{
	return mActionName;
}



#pragma mark -
#pragma mark - as a GCUndoTask

- (void)				perform
{
	// cause the tasks in the group to be executed IN REVERSE ORDER. Subgroups are recursively executed.
	
	NSInteger i = [[self tasks] count];
	
	while( i-- > 0 )
		[[self taskAtIndex:i] perform];
}



#pragma mark -
#pragma mark - as a NSObject

- (id)					init
{
	self = [super init];
	if( self )
	{
		mTasks = [[NSMutableArray alloc] init];
	}
	
	return self;
}



- (void)				dealloc
{
	//NSLog(@"deallocating undo group %@", self );
	
	[mTasks release];
	[mActionName release];
	[super dealloc];
}


- (NSString*)			description
{
	return [NSString stringWithFormat:@"%@ '%@' %d tasks: %@", [super description], [self actionName], [mTasks count], mTasks];
}

@end


#pragma mark -

@implementation GCConcreteUndoTask

- (id)					initWithInvocation:(NSInvocation*) inv
{
	// designated initializer.
	// If <inv> is nil the task is released and nil is returned.
	
	self = [super init];
	if( self )
	{
		if( inv )
		{
			// the invocation retains its arguments and target if the target is set at this point. Therefore the target
			// is set as nil and is managed independently. mTarget is set to the invocation's original target if set.
			
			mTarget = [inv target];
			[inv setTarget:nil];
			[inv retainArguments];
			mInvocation = [inv retain];
		}
		else
		{
			[self autorelease];
			self = nil;
		}
	}
	
	return self;
}



- (id)					initWithTarget:(id) target selector:(SEL) selector object:(id) object
{
	// alternative initialiser for direct target/selector/object initialisation. Creates an invocation internally. If the UM is set not to retain
	// its target, the target will be nil and subsequently set using -setTarget:
	
	NSMethodSignature* sig = [target methodSignatureForSelector:selector];
	NSInvocation* inv = [NSInvocation invocationWithMethodSignature:sig];
	
	[inv setSelector:selector];
	
	// don't set the argument if the selector doesn't take one
	
	if([sig numberOfArguments] >= 3 )
		[inv setArgument:&object atIndex:2];
	
	self = [self initWithInvocation:inv];
	
	// keep track of the target separately from the invocation, so it can be memory managed independently.
	// The invocation's internal target is nil. The target is not retained unless -setTarget:retained: is called with YES for <retained>.
	
	if( self )
		mTarget = target;
	
	return self;
}


- (void)				setTarget:(id) target retained:(BOOL) retainIt
{
	// sets the invocation's target, optionally retaining it.
	
	if( retainIt )
		[target retain];
	
	if( mTargetRetained )
		[mTarget release];
	
	mTarget = target;
	mTargetRetained = retainIt;
}


- (id)					target
{
	return mTarget;
}


- (SEL)					selector
{
	return [mInvocation selector];
}


#pragma mark -
#pragma mark - as a GCUndoTask

- (void)				perform
{
	// if target has never been set, does nothing
	
	//NSLog(@"about to invoke task %@", self );
	
	if( mTarget )
		[mInvocation invokeWithTarget:mTarget];
}



#pragma mark -
#pragma mark - as a NSObject

- (id)					init
{
	[self autorelease];
	return nil;
}



- (void)				dealloc
{
	[mInvocation release];
	
	if( mTargetRetained )
		[mTarget release];
	
	[super dealloc];
}


- (NSString*)			description
{
	return [NSString stringWithFormat:@"%@ target = <%@ 0x%x>, selector: %@", [super description], NSStringFromClass([[self target] class]), [self target], NSStringFromSelector([mInvocation selector])];
}

@end


#pragma mark -

@implementation		GCUndoManagerProxy

- (id)					initWithUndoManager:(GCUndoManager*) um
{
	// n.b. does not inherit from NSObject so no [super init] here
	
	mUndoManager = um;
	return self;
}


- (void)				forwardInvocation:(NSInvocation*) inv
{
	THROW_IF_FALSE( mNextTarget != nil, @"invalid forwardInvocation (proxy) without preparing");
	
	[mUndoManager setNextTarget:mNextTarget];
	[mUndoManager forwardInvocation:inv];
	mNextTarget = nil;
}


- (NSMethodSignature*)	methodSignatureForSelector:(SEL) selector
{
	return [mNextTarget methodSignatureForSelector:selector];
}


- (BOOL)				respondsToSelector:(SEL) selector
{
	return [mNextTarget respondsToSelector:selector];
}


- (void)				_gcum_setTarget:(id) target
{
	THROW_IF_FALSE( target != self, @"bizarre internal inconsistency - attempt to set proxy as its own target");
	
	mNextTarget = target;
}

@end;

