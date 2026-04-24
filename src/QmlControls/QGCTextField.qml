import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

TextField {
    id:                 control
    color:              control._popupStyled ? popupStyle.primaryTextColor : control.textColor
    selectionColor:     control._popupStyled ? popupStyle.accentColor : control.textColor
    selectedTextColor:  control._popupStyled ? popupStyle.primaryTextColor : control.backgroundColor
    activeFocusOnPress: true
    antialiasing:       true
    font.pointSize:     ScreenTools.defaultFontPointSize
    font.family:        ScreenTools.normalFontFamily
    inputMethodHints:   numericValuesOnly && !ScreenTools.isiOS ?
                            Qt.ImhFormattedNumbersOnly:  // Forces use of virtual numeric keyboard instead of full keyboard
                            Qt.ImhNone                   // iOS numeric keyboard has no done button, we can't use it.
    leftPadding:        _marginPadding
    rightPadding:       _marginPadding + unitsHelpLayout.width
    topPadding:         _marginPadding
    bottomPadding:      _marginPadding
    EnterKey.type:      Qt.EnterKeyDone

    property bool   showUnits:          false
    property bool   showHelp:           false
    property string unitsLabel:         ""
    property string extraUnitsLabel:    ""
    property bool   numericValuesOnly:  false   // true: Used as hint for mobile devices to show numeric only keyboard
    property color  textColor:          qgcPal.textFieldText
    property color  backgroundColor:    qgcPal.textField
    property color  borderColor:        qgcPal.buttonBorder
    property color  focusBorderColor:   borderColor
    property color  focusGlowColor:     focusBorderColor
    property real   borderRadius:       ScreenTools.defaultBorderRadius
    property real   borderWidth:        qgcPal.globalTheme === QGCPalette.Light ? 1 : 0
    property real   focusBorderWidth:   1
    property bool   showFocusGlow:      false
    property bool   validationError:    false

    property real _helpLayoutWidth: 0
    property real _marginPadding:   ScreenTools.defaultFontPixelHeight / 3
    property int _stateAnimationDuration: 200
    readonly property bool _popupStyled: popupStyle.inPopupContext(control)

    signal helpClicked

    Component.onCompleted: checkActiveFocus()
    onActiveFocusChanged: checkActiveFocus()

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }
    QGCPopupStyle { id: popupStyle }

    onEditingFinished: {
        if (ScreenTools.isMobile) {
            // Toss focus on mobile after Done on virtual keyboard. Prevent strange interactions.
            focus = false
        }
    }

    function checkActiveFocus() {
        if (activeFocus) {
            selectAll()
            if (validationError) {
                validationToolTip.visible = true
            }
        } else {
            validationToolTip.visible = false
        }
    }

    function showValidationError(errorString, originalValidValue = undefined, preventViewSiwtch = true) {
        validationToolTip.text = errorString
        validationToolTip.originalValidValue = originalValidValue
        validationToolTip.visible = true
        if (!validationError) {
            validationError = true
            if (preventViewSiwtch) {
                globals.validationErrorCount++
            }
        }
    }

    function clearValidationError(preventViewSiwtch = true) {
        validationToolTip.visible = false
        validationToolTip.originalValidValue = undefined
        if (validationError) {
            validationError = false
            if (preventViewSiwtch) {
                globals.validationErrorCount--
            }
        }
    }

    background: Rectangle {
        border.width:   control.validationError ? 2 : (control.activeFocus ? control.focusBorderWidth : control.borderWidth)
        border.color:   control.validationError
                            ? qgcPal.colorRed
                            : (control.activeFocus
                                ? (control._popupStyled ? popupStyle.accentColor : control.focusBorderColor)
                                : (control._popupStyled ? popupStyle.borderColor : control.borderColor))
        radius:         control._popupStyled ? popupStyle.cornerRadius : control.borderRadius
        color:          control._popupStyled ? popupStyle.inputBackground : control.backgroundColor
        implicitWidth:  ScreenTools.implicitTextFieldWidth
        implicitHeight: ScreenTools.implicitTextFieldHeight

        Behavior on color { ColorAnimation { duration: control._stateAnimationDuration } }
        Behavior on border.color { ColorAnimation { duration: control._stateAnimationDuration } }

        Rectangle {
            anchors.fill: parent
            visible: control.activeFocus && (control.showFocusGlow || control._popupStyled) && !control.validationError
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: control._popupStyled ? popupStyle.focusGlowColor(0.45) : Qt.rgba(control.focusGlowColor.r, control.focusGlowColor.g, control.focusGlowColor.b, 0.50)
            opacity: 0.65
        }

        RowLayout {
            id:                     unitsHelpLayout
            anchors.top:            parent.top
            anchors.bottom:         parent.bottom
            anchors.right:          parent.right
            anchors.rightMargin:    control.activeFocus ? 2 : control._marginPadding
            spacing:                ScreenTools.defaultFontPixelWidth / 4
            layoutDirection:        Qt.RightToLeft

            Component.onCompleted:  control._helpLayoutWidth = unitsHelpLayout.width
            onWidthChanged:         control._helpLayoutWidth = unitsHelpLayout.width

            // Help button
            Rectangle {
                id:                     helpButton
                Layout.margins:         2
                Layout.leftMargin:      0
                Layout.rightMargin:     1
                Layout.fillHeight:      true
                Layout.preferredWidth:  helpLabel.contentWidth * 3
                Layout.alignment:       Qt.AlignVCenter
                color:                  control.color
                visible:                control.showHelp && control.activeFocus

                QGCLabel {
                    id:                 helpLabel
                    anchors.centerIn:   parent
                    color:              control._popupStyled ? popupStyle.popupBackground : qgcPal.textField
                    text:               qsTr("?")
                }

            }

            // Extra units
            Text {
                Layout.alignment:   Qt.AlignVCenter
                text:               control.extraUnitsLabel
                font.pointSize:     ScreenTools.smallFontPointSize
                font.family:        ScreenTools.normalFontFamily
                antialiasing:       true
                color:              control._popupStyled ? popupStyle.secondaryTextColor : control.color
                visible:            control.showUnits && text !== ""
            }

            // Units
            Text {
                Layout.alignment:   Qt.AlignVCenter
                text:               control.unitsLabel
                font.pointSize:     control.activeFocus ? ScreenTools.smallFontPointSize : ScreenTools.defaultFontPointSize
                font.family:        ScreenTools.normalFontFamily
                antialiasing:       true
                color:              control._popupStyled ? popupStyle.secondaryTextColor : control.color
                visible:            control.showUnits && text !== ""
            }
        }
    }

    ToolTip {
        id: validationToolTip

        property var originalValidValue: undefined

        QGCMouseArea {
            anchors.fill: parent
            onClicked: {
                if (validationToolTip.originalValidValue !== undefined) {
                    control.text = validationToolTip.originalValidValue
                    control.clearValidationError()
                }
            }
        }
    }

    MouseArea {
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        anchors.right:  parent.right
        width:          control._helpLayoutWidth
        enabled:        helpButton.visible
        onClicked:      control.helpClicked()
    }
}
