import Cocoa

class APHighlightingView: NSView {
    var isHighlighted = false

    // Draw with or without a highlight style
    override func draw(_ dirtyRect: NSRect) {
        if isHighlighted {
            NSColor.alternateSelectedControlColor.set()
            __NSRectFillUsingOperation(dirtyRect, .sourceOver)
        } else {
            NSColor.clear.set()
            __NSRectFillUsingOperation(dirtyRect, .sourceOver)
            
        }
    }
    /* Custom highlighted property setter because when the property changes we need to redraw and update the containing text fields.
     */
    func setHighlighted(_ highlighted: Bool) {
        if self.isHighlighted != highlighted {
            self.isHighlighted = highlighted
            // Inform each contained text field what type of background they will be displayed on. This is how the txt field knows when to draw white text instead of black text.
            for subview in subviews where subview is NSTextField {
                (subview as? NSTextField)?.cell?.backgroundStyle = highlighted ? .dark : .light
            }
            needsDisplay = true
            // make sure we redraw with the correct highlight style.
        }
    }

}
