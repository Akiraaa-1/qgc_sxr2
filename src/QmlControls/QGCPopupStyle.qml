import QtQuick

QtObject {
    readonly property color overlayColor: "#B31A1A1A"
    readonly property color popupBackground: "#1E1E1E"
    readonly property color panelBackground: "#2D2D2D"
    readonly property color inputBackground: "#252525"
    readonly property color borderColor: "#333333"
    readonly property color accentColor: "#2563EB"
    readonly property color primaryButtonColor: "#2563EB"
    readonly property color secondaryButtonColor: "#333333"
    readonly property color primaryTextColor: "#FFFFFF"
    readonly property color secondaryTextColor: "#B0B0B0"
    readonly property color disabledTextColor: "#666666"
    readonly property real cornerRadius: 8
    readonly property int stateAnimationDuration: 200

    function _blend(baseColor, topColor, factor) {
        return Qt.rgba(
            (baseColor.r * (1.0 - factor)) + (topColor.r * factor),
            (baseColor.g * (1.0 - factor)) + (topColor.g * factor),
            (baseColor.b * (1.0 - factor)) + (topColor.b * factor),
            (baseColor.a * (1.0 - factor)) + (topColor.a * factor)
        )
    }

    function hoverColor(baseColor) {
        return _blend(baseColor, "#FFFFFF", 0.06)
    }

    function pressedColor(baseColor) {
        return _blend(baseColor, "#000000", 0.10)
    }

    function focusGlowColor(opacity = 0.35) {
        return Qt.rgba(accentColor.r, accentColor.g, accentColor.b, opacity)
    }

    function primaryButtonHoverColor() {
        return pressedColor(primaryButtonColor)
    }

    function primaryButtonPressedColor() {
        return _blend(primaryButtonColor, "#000000", 0.20)
    }

    function secondaryButtonHoverColor() {
        return hoverColor(secondaryButtonColor)
    }

    function secondaryButtonPressedColor() {
        return pressedColor(secondaryButtonColor)
    }

    function hasPopupChrome(item) {
        return !!item && (item._qgcPopupChrome === true)
    }

    function popupChromeFor(item) {
        let current = item
        while (current) {
            if (hasPopupChrome(current)) {
                return current
            }
            current = current.parent
        }
        return null
    }

    function inPopupContext(item) {
        return popupChromeFor(item) !== null
    }
}
