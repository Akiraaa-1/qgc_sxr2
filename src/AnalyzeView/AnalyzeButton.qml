import QtQuick

import QGroundControl.Controls

QGCButton {
    id: control

    AnalyzePalette { id: analyzePalette }

    backRadius:              analyzePalette.cornerRadius
    showBorder:              true
    stateAnimationDuration:  analyzePalette.transitionDuration
    hoverOverlayOpacity:     0
    pressedOverlayOpacity:   0
    overlayColor:            "transparent"
    textColor:               enabled ? analyzePalette.textPrimary : analyzePalette.textDisabled
    borderColor:             primary ? analyzePalette.primaryButton : analyzePalette.border
    backgroundColor:         !enabled
                                ? analyzePalette.surfacePressed
                                : (pressed
                                ? (primary ? analyzePalette.primaryButtonPressed : analyzePalette.secondaryButtonPressed)
                                : (hovered ? (primary ? analyzePalette.primaryButtonHover : analyzePalette.secondaryButtonHover)
                                           : (primary ? analyzePalette.primaryButton : analyzePalette.secondaryButton)))
}
