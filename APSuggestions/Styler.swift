//
//  Syler.swift
//  APSuggestions
//
//  Created by Ashok Paudel on 2021-01-04.
//

import Cocoa

public protocol APCellStyleDelegate {
    
    /// The radius for the suggestion cell
    var cornerRadius: CGFloat { get }

    /// The backgroundColor for the suggestion cell
    var backgroundColor: NSColor { get }
    
    var hasLine: Bool { get }
    

    
    /// Title Configuration
    var textColor: NSColor { get }
    var textDirection: textAlignment { get }
    var textSize: CGFloat { get }
    var textFamily: String { get }
    var textStyle: String { get }
}


public enum textAlignment {
    case left
    case right
    case center
    case justify
}

public enum textStyle {
    case bold
    case underline
    case italic
    case bold_underline
    case bold_italic
}
