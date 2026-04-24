import QtQuick

import QGroundControl.Controls

QGCComboBox {
    id: control

    AnalyzePalette { id: analyzePalette }

    borderRadius:                 analyzePalette.cornerRadius
    stateAnimationDuration:       analyzePalette.transitionDuration
    showFocusBorder:              true
    backgroundColor:              !enabled
                                    ? analyzePalette.surfacePressed
                                    : (pressed
                                        ? analyzePalette.inputSurfacePressed
                                        : (hovered ? analyzePalette.inputSurfaceHover : analyzePalette.inputSurface))
    borderColor:                  analyzePalette.border
    focusBorderColor:             analyzePalette.accent
    textColor:                    enabled ? analyzePalette.textPrimary : analyzePalette.textDisabled
    popupBackgroundColor:         analyzePalette.popupBackground
    popupBorderColor:             analyzePalette.border
    delegateBackgroundColor:      analyzePalette.popupBackground
    delegateSelectedBackgroundColor: analyzePalette.accent
    delegateTextColor:            analyzePalette.textPrimary
    delegateSelectedTextColor:    analyzePalette.textPrimary
}
