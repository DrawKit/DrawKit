///**********************************************************************************************************************************
///  GCObservableObject.m
///  DrawKit
///
///  Created by graham on 27/05/2007.
///  Released under the Creative Commons license 2007 Apptree.net.
///
/// 
///  This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 License.
///  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to
///  Creative Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105, USA.
///
///**********************************************************************************************************************************

#import "GCObservableObject.h"
#import "LogEvent.h"


#pragma mark Contants (Non-localized)
NSString*		kGCObserverRelayDidReceiveChange = @"kGCObserverRelayDidReceiveChange";
NSString*		kGCObservableKeyPath = @"kGCObservableKeyPath";


#pragma mark Static Vars
static NSMutableDictionary*		sActionNameRegistry = nil;


#pragma mark -
@implementation GCObservableObject
#pragma mark As a GCObservableObject
+ (void)			registerActionName:(NSString*) na forKeyPath:(NSString*) kp objClass:(Class) cl
{
	if ( sActionNameRegistry == nil )
		sActionNameRegistry = [[NSMutableDictionary alloc] init];
		
	NSMutableDictionary* sd = [sActionNameRegistry objectForKey:cl];
	
	if ( sd == nil )
	{
		sd = [[NSMutableDictionary alloc] init];
		[sActionNameRegistry setObject:sd forKey:cl];
		[sd release];
	}
		
	[sd setObject:na forKey:kp];
}


+ (NSString*)		actionNameForKeyPath:(NSString*) kp objClass:(Class) cl
{
	NSDictionary*	sd = [sActionNameRegistry objectForKey:cl];
	NSString*		an = [sd objectForKey:kp];
	
	if ( an )
		return NSLocalizedString( an, @"");
	else
		return nil;
}


+ (NSArray*)		observableKeyPaths
{
	// subclasses can override to provide a list of observable properties for this class, which can be
	// automatically registered with any nominated observer. This returns an empty array by default, allowing
	// subclasses to simply append their own keypaths without caring if there are already any paths defined
	// by its superclass.
	
	return [NSArray array];
}


#pragma mark -
- (BOOL)			setUpKVOForObserver:(id) object
{
	LogEvent_( kKVOEvent, @"setting up KVO for observer %@", [object description]);

	if ( object == nil )
		return NO;
	
	// attempt to auto-register any keypaths returned by the "observables" list
	
	NSArray* observables = [[self class] observableKeyPaths];
	
	if ( observables && [observables count] > 0 )
		[self setUpObservables:observables forObserver:object];
	
	return YES;
}


- (BOOL)			tearDownKVOForObserver:(id) object
{
	LogEvent_( kKVOEvent, @"tearing down KVO for observer %@", [object description]);
	
	if ( object == nil )
		return NO;

	// attempt to auto-unregister any keypaths returned by the "observables" list
	
	NSArray* observables = [[self class] observableKeyPaths];
	
	if (( observables != nil)  && [observables count] > 0 )
		[self tearDownObservables:observables forObserver:object];

	return YES;
}


#pragma mark -
- (void)			setUpObservables:(NSArray*) keypaths forObserver:(id) object
{
	// given a list of keypaths, this sets up the given observer for those paths. The observer should already have been
	// recorded by setUpKVO..., this is called by that method for the class's list of keypaths if that list isn't empty.
	
	NSAssert( keypaths != nil, @"array of observable keypaths was nil");
	
	LogEvent_( kKVOEvent, @"%@ is adding the observer %@ for keypaths %@", [self description], [object description], keypaths);

	NSEnumerator* iter = [keypaths objectEnumerator];
	NSString*		kp;
	
	while(( kp = [iter nextObject]))
		[self addObserver:object forKeyPath:kp options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew context:NULL];
}


- (void)			tearDownObservables:(NSArray*) keypaths forObserver:(id) object
{
	NSAssert( keypaths != nil, @"array of observable keypaths was nil");
	
	LogEvent_( kKVOEvent, @"%@ is removing the observer %@ for keypaths %@", [self description], [object description], keypaths);
	
	NSEnumerator* iter = [keypaths objectEnumerator];
	NSString*		kp;
	
	while(( kp = [iter nextObject]))
		[self removeObserver:object forKeyPath:kp];
}


#pragma mark -
- (void)			registerActionNames
{
	// subclasses can override to register the action names they need to - called from init.
}


- (NSString*)		actionNameForKeyPath:(NSString*) keypath
{
	return [self actionNameForKeyPath:keypath changeKind:NSKeyValueChangeSetting];
}


- (NSString*)		actionNameForKeyPath:(NSString*) keypath changeKind:(NSKeyValueChange) kind
{
	NSString* an = [GCObservableObject actionNameForKeyPath:keypath objClass:[self class]];
	
	if ( an == nil )
	{
		// not known, so supply a generic string based on the keypath
		
		LogEvent_(kWheneverEvent, @"[<%@> %@] has no registered action name - you should probably add one", NSStringFromClass([self class]), keypath);

		an = [NSString stringWithFormat:@"#kind# %@", [keypath capitalizedString]];
	}
	
	NSRange range = [an rangeOfString:@"#kind#" options:NSCaseInsensitiveSearch];

	if ( range.location != NSNotFound )
	{
		// substitute '#kind#' with the type of change indicated by the change kind
	
		NSString* chStr;
		
		switch( kind )
		{
			default:
			case NSKeyValueChangeSetting:
			case NSKeyValueChangeReplacement:
				chStr = @"Change";
				break;
				
			case NSKeyValueChangeInsertion:
				chStr = @"Add";
				break;
				
			case NSKeyValueChangeRemoval:
				chStr = @"Delete";
				break;
		}
		
		// replace tag with the proper verb
		
		NSMutableString* s = [an mutableCopy];
		[s replaceCharactersInRange:range withString:NSLocalizedString(chStr, @"")];
	
		return [s autorelease];
	}
	else
		return an;
}


#pragma mark -
- (void)			setActionName:(NSString*) name forKeyPath:(NSString*) keypath
{
	[GCObservableObject registerActionName:name forKeyPath:keypath objClass:[self class]];
}


- (NSArray*)		oldArrayValueForKeyPath:(NSString*) keypath
{
	return [m_oldArrayValues objectForKey:keypath];
}


#pragma mark -
#pragma mark As an NSObject
- (void)			dealloc
{
	[m_oldArrayValues release];
	[super dealloc];
}


- (id)				init
{
	self = [super init];
	if (self != nil )
	{
		NSAssert(m_oldArrayValues == nil, @"Expected init to zero");	// created when needed
		[self registerActionNames];
	}
	if (self != nil )
	{
		[self registerActionNames];
	}
	return self;
}


#pragma mark -
#pragma mark As part of NSKeyValueObserving Protocol
- (void)			willChange:(NSKeyValueChange) change valuesAtIndexes:(NSIndexSet*) indexes forKey:(NSString*) key
{
	// due to an oversight in the KVO implementation, when changing an array the value of the old array isn't recorded and
	// passed along in the change dictionary. To get around this we record this information locally so that the observer
	// may query us to get this information. Otherwise straightforward Undo on array inserts/deletes is very tricky.
	
	if ( change == NSKeyValueChangeInsertion ||
		 change == NSKeyValueChangeRemoval ||
		 change == NSKeyValueChangeReplacement )
	{
		NSArray* old = [[self valueForKey:key] copy];
		
		if ( old != nil )
		{
			if ( m_oldArrayValues == nil )
				m_oldArrayValues = [[NSMutableDictionary alloc] init];
				
			[m_oldArrayValues setObject:old forKey:key];
			[old release];
		}
	}
	
	[super willChange:change valuesAtIndexes:indexes forKey:key];
}


@end


#pragma mark -
@implementation GCObserverUndoRelay
#pragma mark As a GCObserverUndoRelay
- (void)				setUndoManager:(NSUndoManager*) um
{
	m_um = um;
}


- (NSUndoManager*)		undoManager
{
	return m_um;
}


///*********************************************************************************************************************
///
/// method:			changeKeyPath:ofObject:toValue:
/// scope:			private method
/// overrides:		
/// description:	vectors undo invocations back to the object from whence they came
/// 
/// parameters:		<keypath> the keypath of the action, relative to the object
///					<object> the real target of the invocation
///					<value> the value being restored by the undo/redo task
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				changeKeyPath:(NSString*) keypath ofObject:(id) object toValue:(id) value
{
	if([value isEqual:[NSNull null]])
		value = nil;
	
	[object setValue:value forKeyPath:keypath];
}


#pragma mark -
#pragma mark As part of NSKeyValueObserving Protocol
- (void)				observeValueForKeyPath:(NSString*) keyPath ofObject:(id) object change:(NSDictionary*) change context:(void*) context
{
	#pragma unused(context)
	
//	LogEvent_(kReactiveEvent, @"observer relay observed change at '%@' for object %@, change = %@", keyPath, object, change);
	
	NSKeyValueChange ch = [[change objectForKey:NSKeyValueChangeKindKey] intValue];
	BOOL	wasChanged = NO;
	
	if ( ch == NSKeyValueChangeSetting )
	{
		if(![[change objectForKey:NSKeyValueChangeOldKey] isEqual:[change objectForKey:NSKeyValueChangeNewKey]])
		{
			[[[self undoManager] prepareWithInvocationTarget:self]	changeKeyPath:keyPath
																	ofObject:object
																	toValue:[change objectForKey:NSKeyValueChangeOldKey]];
			wasChanged = YES;
		}
	}
	else if ( ch == NSKeyValueChangeInsertion || ch == NSKeyValueChangeRemoval )
	{
		// Cocoa has a bug where array insertion/deletion changes don't properly record the old array.
		// GCObserveableObject gives us a workaround
				
		NSArray* old = [object oldArrayValueForKeyPath:keyPath];
		[[[self undoManager] prepareWithInvocationTarget:self]	changeKeyPath:keyPath
																ofObject:object
																toValue:old];	
																
		wasChanged = YES;
	}
	
	if ( wasChanged && ![[self undoManager] isUndoing])
	{
		if([object respondsToSelector:@selector(actionNameForKeyPath:)])
			[[self undoManager] setActionName:[object actionNameForKeyPath:keyPath changeKind:ch]];
		else
			[[self undoManager] setActionName:[GCObservableObject actionNameForKeyPath:keyPath objClass:[object class]]];
	}
	
	// also broadcast a general notification that one of our observees changed

	NSMutableDictionary*	changeDict = [change mutableCopy];
	[changeDict setObject:keyPath forKey:kGCObservableKeyPath];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:kGCObserverRelayDidReceiveChange object:object userInfo:changeDict];
	[changeDict release];
}


@end;


