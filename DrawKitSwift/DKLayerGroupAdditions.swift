//
//  DKLayerGroupAdditions.swift
//  DrawKitSwift
//
//  Created by C.W. Betts on 12/10/17.
//  Copyright © 2017 DrawKit. All rights reserved.
//

import DKDrawKit.DKLayerGroup

extension DKLayerGroup {
	/// Returns all of the layers in this group and all groups below it having the given class
	/// - parameter layerClass: A class indicating the kind of layer of interest.
	/// - returns: A list of matching layers.
	public func flattenedLayers<A: DKLayer>(of layerClass: A.Type) -> [A] {
		return __flattenedLayers(of: layerClass) as! [A]
	}
	
	/// Returns the uppermost layer matching `class`, if any.
	///
	/// - parameter cl: The class of layer to seek.
	/// - parameter deep: If `true`, will search all subgroups below this one. If `false`, only this level is searched.<br>
	/// Default is `false`.
	/// - returns: The uppermost layer of the given class, or `nil`.
	public func firstLayer<A: DKLayer>(of cl: A.Type, performDeepSearch deep: Bool = false) -> A? {
		return __firstLayer(of: cl, performDeepSearch: deep) as? A
	}
	
	/// Returns a list of layers of the given class.
	///
	/// - parameter cl: The class of layer to seek.
	/// - parameter deep: If `true`, will search all subgroups below this one. If `false`, only this level is searched.<br>
	/// Default is `false`.
	/// - returns: A list of layers. May be empty.
	public func layers<A: DKLayer>(of cl: A.Type, performDeepSearch deep: Bool = false) -> [A] {
		return __layers(of: cl, performDeepSearch: deep) as! [A]
	}
	
	/// Creates and adds a layer to the drawing.
	///
	/// `layerClass` must be a valid subclass of `DKLayer`, otherwise does nothing and `nil` is returned.
	///
	/// - parameter layerClass: The class of some kind of layer.
	/// - returns: The layer created.
	public func addNewLayer<A: DKLayer>(of layerClass: A.Type) -> A? {
		return __addNewLayer(of: layerClass) as? A
	}
}
