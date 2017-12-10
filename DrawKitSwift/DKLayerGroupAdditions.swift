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
	/// - parameter layerClass: a Class indicating the kind of layer of interest
	/// - parameter includeGroups: if `true`, includes groups as well as the requested class.<br>
	/// Default is `false`.
	/// - returns: a list of matching layers.
	public func flattenedLayers<A: DKLayer>(of layerClass: A.Type, includeGroups: Bool = false) -> [A] {
		return __flattenedLayers(of: layerClass, includeGroups: includeGroups) as! [A]
	}
	
	public func firstLayer<A: DKLayer>(of cl: A.Type, performDeepSearch: Bool) -> A? {
		return __firstLayer(of: cl, performDeepSearch: performDeepSearch) as? A
	}
	
	public func layers<A: DKLayer>(of cl: A.Type, performDeepSearch: Bool) -> [A]? {
		return __layers(of: cl, performDeepSearch: performDeepSearch) as? [A]
	}	
}
