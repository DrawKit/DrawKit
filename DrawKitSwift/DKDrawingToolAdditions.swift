//
//  DKDrawingToolAdditions.swift
//  DrawKitSwift
//
//  Created by C.W. Betts on 12/12/17.
//  Copyright © 2017 DrawKit. All rights reserved.
//

import DKDrawKit.DKDrawingTool

extension DKDrawingTool {
	public var keyboard: (equivalent: String, modifierFlags: UInt) {
		get {
			return (keyboardEquivalent ?? "", keyboardModifierFlags)
		}
		set {
			setKeyboardEquivalent(newValue.equivalent, modifierFlags: newValue.modifierFlags)
		}
	}
}
