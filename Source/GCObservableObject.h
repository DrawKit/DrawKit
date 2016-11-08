/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

/** @brief This is used to permit setting up KVO in a simpler manner than comes as standard.

This is used to permit setting up KVO in a simpler manner than comes as standard.

The idea is that each class simply publishes a list of the observable properties that an observer can observe. When the observer wants to
start observing all of these published properties, it calls setUpKVOForObserver: conversely, tearDownKVOForObserver: will stop the
observer watching all the published properties.

Subclasses can also override these methods to be more selective about which properties are observed, or to propagate the message to
additional observable objects they own.

This class also works around a bug or oversight in the KVO implementation (in 10.4 at least). When an array is changed, the old
value isn't sent to the observer. To allow this, we record the old value locally. An observer can then call us back to get this
old array if it needs to (for example, when building an Undo invocation).

The undo relay class provides a standard implementation for using KVO to implement Undo when using GCObservables. The relay needs
to be added as an observer to any observable and given an undo manager. Then it will relay undoable actions from the observed
objects to the undo manager and vice versa, implementing undo for all keypaths declared by the observee.
*/
@interface GCObservableObject : NSObject {
@private
	NSMutableDictionary* m_oldArrayValues;
}

+ (void)registerActionName:(NSString*)na forKeyPath:(NSString*)kp objClass:(Class)cl;
+ (NSString*)actionNameForKeyPath:(NSString*)kp objClass:(Class)cl;

+ (NSArray*)observableKeyPaths;

- (BOOL)setUpKVOForObserver:(id)object;
- (BOOL)tearDownKVOForObserver:(id)object;

- (void)setUpObservables:(NSArray*)keypaths forObserver:(id)object;
- (void)tearDownObservables:(NSArray*)keypaths forObserver:(id)object;

- (void)registerActionNames;
- (NSString*)actionNameForKeyPath:(NSString*)keypath;
- (NSString*)actionNameForKeyPath:(NSString*)keypath changeKind:(NSKeyValueChange)kind;

- (void)setActionName:(NSString*)name forKeyPath:(NSString*)keypath;
- (NSArray*)oldArrayValueForKeyPath:(NSString*)keypath;

- (void)sendInitialValuesForAllPropertiesToObserver:(id)object context:(void*)context;

@end

#define kDKChangeKindStringMarkerTag #kind #

// the observer relay is a simple object that can liaise between any undo manager instance and any class
// set up as an observer. It also implements the above protocol so that observees are easily able to hook up to it.

@interface GCObserverUndoRelay : NSObject {
	NSUndoManager* m_um;
}

- (void)setUndoManager:(NSUndoManager*)um;
- (NSUndoManager*)undoManager;

/** @brief Vectors undo invocations back to the object from whence they came
 @param keypath the keypath of the action, relative to the object
 @param object the real target of the invocation
 */
- (void)changeKeyPath:(NSString*)keypath ofObject:(id)object toValue:(id)value;

@end

extern NSString* kDKObserverRelayDidReceiveChange;
extern NSString* kDKObservableKeyPath;
