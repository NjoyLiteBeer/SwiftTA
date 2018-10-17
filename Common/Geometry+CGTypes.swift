//
//  Geometry+CGTypes.swift
//  SwiftTA macOS
//
//  Created by Logan Jones on 10/11/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Foundation

// On iOS, the CoreGraphics types are not defined in Foundation.
#if canImport(CoreGraphics)
import CoreGraphics
#endif


// MARK:- CGType to Geometry Initializers

extension Point2 where Element: BinaryInteger {
    init(_ point: CGPoint) {
        self.init(Element(point.x), Element(point.y))
    }
}
extension Point2 where Element: BinaryFloatingPoint {
    init(_ point: CGPoint) {
        self.init(Element(point.x), Element(point.y))
    }
}

extension Size2 where Element: BinaryInteger {
    init(_ size: CGSize) {
        self.init(Element(size.width), Element(size.height))
    }
}
extension Size2 where Element: BinaryFloatingPoint {
    init(_ size: CGSize) {
        self.init(Element(size.width), Element(size.height))
    }
}

extension Rect4 where Element: BinaryInteger {
    init(_ rect: CGRect) {
        self.init(Element(rect.origin.x), Element(rect.origin.y), Element(rect.size.width), Element(rect.size.height))
    }
}
extension Rect4 where Element: BinaryFloatingPoint {
    init(_ rect: CGRect) {
        self.init(Element(rect.origin.x), Element(rect.origin.y), Element(rect.size.width), Element(rect.size.height))
    }
}


// MARK:- Geometry to CGPoint Initializers

extension CGPoint {
    
    init<Element: BinaryInteger>(_ point: Point2<Element>) {
        self.init(x: CGFloat(point.x), y: CGFloat(point.y))
    }
    init<Element: BinaryFloatingPoint>(_ point: Point2<Element>) {
        self.init(x: CGFloat(point.x), y: CGFloat(point.y))
    }
    
}

extension CGSize {
    
    init<Element: BinaryInteger>(_ size: Size2<Element>) {
        self.init(width: CGFloat(size.width), height: CGFloat(size.height))
    }
    init<Element: BinaryFloatingPoint>(_ size: Size2<Element>) {
        self.init(width: CGFloat(size.width), height: CGFloat(size.height))
    }
    
}

extension CGRect {
    
    init(size: CGSize) {
        self.init(x: 0, y: 0, width: size.width, height: size.height)
    }
    
    init<Element: BinaryInteger>(origin: Point2<Element>, size: Size2<Element>) {
        self.init(x: CGFloat(origin.x), y: CGFloat(origin.y), width: CGFloat(size.width), height: CGFloat(size.height))
    }
    init<Element: BinaryFloatingPoint>(origin: Point2<Element>, size: Size2<Element>) {
        self.init(x: CGFloat(origin.x), y: CGFloat(origin.y), width: CGFloat(size.width), height: CGFloat(size.height))
    }
    
    init<Element: BinaryInteger>(size: Size2<Element>) {
        self.init(x: 0, y: 0, width: CGFloat(size.width), height: CGFloat(size.height))
    }
    init<Element: BinaryFloatingPoint>(size: Size2<Element>) {
        self.init(x: 0, y: 0, width: CGFloat(size.width), height: CGFloat(size.height))
    }
    
    init<Element: BinaryInteger>(_ rect: Rect4<Element>) {
        self.init(x: CGFloat(rect.origin.x), y: CGFloat(rect.origin.y), width: CGFloat(rect.size.width), height: CGFloat(rect.size.height))
    }
    init<Element: BinaryFloatingPoint>(_ rect: Rect4<Element>) {
        self.init(x: CGFloat(rect.origin.x), y: CGFloat(rect.origin.y), width: CGFloat(rect.size.width), height: CGFloat(rect.size.height))
    }
    
}


// MARK:- Operator Extensions

extension CGPoint {
    
    static func * (point: CGPoint, mult: Int) -> CGPoint {
        let df = CGFloat(mult)
        return CGPoint(x: point.x * df, y: point.y * df)
    }
    static func * (point: CGPoint, mult: CGFloat) -> CGPoint {
        let df = mult
        return CGPoint(x: point.x * df, y: point.y * df)
    }
    
    static func / (point: CGPoint, divisor: Int) -> CGPoint {
        let df = CGFloat(divisor)
        return CGPoint(x: point.x / df, y: point.y / df)
    }
    static func /= (point: inout CGPoint, divisor: Int) {
        let df = CGFloat(divisor)
        point.x /= df
        point.y /= df
    }
    
    static func / (point: CGPoint, divisor: CGFloat) -> CGPoint {
        return CGPoint(x: point.x / divisor, y: point.y / divisor)
    }
    static func /= (point: inout CGPoint, divisor: CGFloat) {
        point.x /= divisor
        point.y /= divisor
    }
    
}
extension CGSize {
    
    static func * (size: CGSize, mult: Int) -> CGSize {
        let df = CGFloat(mult)
        return CGSize(width: size.width * df, height: size.height * df)
    }
    static func * (size: CGSize, mult: CGFloat) -> CGSize {
        let df = mult
        return CGSize(width: size.width * df, height: size.height * df)
    }
    
    static func / (size: CGSize, divisor: Int) -> CGSize {
        let df = CGFloat(divisor)
        return CGSize(width: size.width / df, height: size.height / df)
    }
    static func /= (size: inout CGSize, divisor: Int) {
        let df = CGFloat(divisor)
        size.width /= df
        size.height /= df
    }
    
    static func / (size: CGSize, divisor: CGFloat) -> CGSize {
        return CGSize(width: size.width / divisor, height: size.height / divisor)
    }
    static func /= (size: inout CGSize, divisor: CGFloat) {
        size.width /= divisor
        size.height /= divisor
    }
    
}
