import QtQuick

import QGroundControl.Controls

QGCCheckBox {
    AnalyzePalette { id: analyzePalette }

    textColor:           enabled ? analyzePalette.textPrimary : analyzePalette.textDisabled
    boxBackgroundColor:  analyzePalette.inputSurface
    boxBorderColor:      analyzePalette.border
    checkColor:          analyzePalette.accent
    hoverColor:          "#FFFFFF"
    stateAnimationDuration: analyzePalette.transitionDuration
}
