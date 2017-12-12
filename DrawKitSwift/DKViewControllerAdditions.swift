//
//  DKViewControllerAdditions.swift
//  DrawKitSwift
//
//  Created by C.W. Betts on 12/11/17.
//  Copyright © 2017 DrawKit. All rights reserved.
//

import DKDrawKit.DKViewController

extension DKViewController {
	///Return the drawing's current active layer if it matches the given class, else nil
	/// - parameter aClass: A layer class.
	/// - returns: The active layer if it matches the class, otherwise `nil`.
	public func activeLayer<A: DKLayer>(of aClass: A.Type) -> A? {
		return __activeLayer(of: aClass) as? A
	}

}
