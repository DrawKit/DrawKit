//
//  DKDrawingAdditions.swift
//  DrawKitSwift
//
//  Created by C.W. Betts on 12/10/17.
//  Copyright © 2017 DrawKit. All rights reserved.
//

import DKDrawKit.DKDrawing

extension DKDrawing {
	//- (__kindof DKLayer*)activeLayerOfClass:(Class)aClass
	public func activeLayer<A: DKLayer>(of class: A.Type) -> A? {
		return __activeLayer(of: `class`) as? A
	}
}
