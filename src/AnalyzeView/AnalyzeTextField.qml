import QtQuick

import QGroundControl.Controls

QGCTextField {
    AnalyzePalette { id: analyzePalette }

    borderRadius:        analyzePalette.cornerRadius
    borderWidth:         analyzePalette.borderWidth
    focusBorderWidth:    analyzePalette.borderWidth
    showFocusGlow:       true
    backgroundColor:     !enabled
                            ? analyzePalette.surfacePressed
                            : (activeFocus
                            ? analyzePalette.inputSurfaceHover
                            : analyzePalette.inputSurface)
    borderColor:         analyzePalette.border
    focusBorderColor:    analyzePalette.accent
    focusGlowColor:      analyzePalette.accent
    textColor:           enabled ? analyzePalette.textPrimary : analyzePalette.textDisabled
    placeholderTextColor: analyzePalette.textSecondary
}
