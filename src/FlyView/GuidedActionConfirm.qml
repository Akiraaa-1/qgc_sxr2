import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Item {
    id:         control
    implicitHeight: confirmPanel.implicitHeight
    width:      confirmPanel.width
    visible:    false

    property var    guidedController
    property var    guidedValueSlider
    property var    messageDisplay
    property string title
    property string message
    property int    action
    property var    actionData
    property bool   hideTrigger:        false
    property var    mapIndicator
    property bool   registerWithController: true
    property alias  optionText:         optionCheckBox.text
    property alias  optionChecked:      optionCheckBox.checked

    property real _margins:         Math.round(ScreenTools.defaultFontPixelHeight * 0.28)
    property bool _emergencyAction: guidedController && action === guidedController.actionEmergencyStop
    property bool _landAction:      guidedController && action === guidedController.actionLand
    property color _actionColor:    _emergencyAction ? qgcPal.colorRed : qgcPal.buttonHighlight
    property color _panelColor:     qgcPal.windowShadeDark
    property string _compactMessage: _landAction ? qsTr("将持续下降至落地，请确认下方安全") : ""
    property real _panelWidth:      Math.min(ScreenTools.defaultFontPixelWidth * 22,
                                             Math.max(ScreenTools.defaultFontPixelWidth * 14,
                                                      parent ? parent.width - (ScreenTools.defaultFontPixelWidth * 4) : ScreenTools.defaultFontPixelWidth * 32))

    Component.onCompleted: _registerWithController()
    onGuidedControllerChanged: _registerWithController()
    onRegisterWithControllerChanged: _registerWithController()
    Component.onDestruction: {
        if (guidedController && guidedController.confirmDialog === control) {
            guidedController.confirmDialog = null
        }
    }

    function _registerWithController() {
        if (registerWithController && guidedController) {
            guidedController.confirmDialog = control
        }
    }

    onHideTriggerChanged: {
        if (hideTrigger) {
            confirmCancelled()
        }
    }

    function show(immediate) {
        if (immediate) {
            _reallyShow()
        } else {
            // We delay showing the confirmation for a small amount in order for any other state
            // changes to propogate through the system. This way only the final state shows up.
            visibleTimer.restart()
        }
    }

    function confirmCancelled() {
        guidedValueSlider.visible = false
        visible = false
        hideTrigger = false
        visibleTimer.stop()
        if (messageDisplay) {
            messageDisplay.opacity = 1.0
        }
        messageFadeTimer.stop()
        messageOpacityAnimation.stop()
        if (mapIndicator) {
            mapIndicator.actionCancelled()
            mapIndicator = undefined
        }
    }

    function _reallyShow() {
        visible = true
        if (messageDisplay) {
            messageDisplay.opacity = 1.0
        }
        messageOpacityAnimation.stop()
        messageFadeTimer.start()
    }

    Timer {
        id:             visibleTimer
        interval:       1000
        repeat:         false
        onTriggered:    _reallyShow()
    }

    QGCPalette { id: qgcPal }

    PropertyAnimation {
        id:         messageOpacityAnimation
        target:     messageDisplay
        property:   "opacity"
        from:       1
        to:         0
        duration:   500
    }

    Timer {
        id:             messageFadeTimer
        interval:       4000
        onTriggered:    if (messageDisplay) { messageOpacityAnimation.start() }
    }

    Rectangle {
        id: confirmPanel

        border.color: qgcPal.windowShade
        border.width: 1
        color: control._panelColor
        implicitHeight: mainLayout.implicitHeight + (control._margins * 2)
        radius: ScreenTools.defaultFontPixelHeight * 0.28
        width: control._panelWidth

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.top: parent.top
            color: control._actionColor
            radius: parent.radius
            width: ScreenTools.defaultFontPixelWidth * 0.5

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.top: parent.top
                color: parent.color
                width: parent.radius
            }
        }

        ColumnLayout {
            id: mainLayout

            anchors.fill: parent
            anchors.margins: control._margins
            anchors.leftMargin: control._margins + (ScreenTools.defaultFontPixelWidth * 0.6)
            spacing: ScreenTools.defaultFontPixelHeight * 0.16

            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth * 0.5

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    QGCPixelLabel {
                        Layout.fillWidth: true
                        color: qgcPal.text
                        elide: Text.ElideRight
                        font.bold: true
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.64
                        text: control.title
                    }

                    QGCPixelLabel {
                        Layout.fillWidth: true
                        color: qgcPal.text
                        elide: Text.ElideRight
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.46
                        opacity: 0.72
                        text: control._compactMessage
                        visible: text !== ""
                    }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredHeight: Layout.preferredWidth
                    Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.92
                    color: closeMouseArea.pressed ? qgcPal.windowShade : qgcPal.windowShadeDark
                    radius: width / 2

                    QGCColoredImage {
                        anchors.centerIn: parent
                        color: qgcPal.text
                        fillMode: Image.PreserveAspectFit
                        height: width
                        source: "/res/XDelete.svg"
                        width: parent.width * 0.38
                    }

                    QGCMouseArea {
                        id: closeMouseArea

                        anchors.fill: parent
                        onClicked: confirmCancelled()
                    }
                }
            }

            QGCCheckBox {
                id: optionCheckBox

                Layout.fillWidth: true
                visible: text !== ""
            }

            QGCDelayButton {
                Layout.fillWidth: true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.38
                backRadius: ScreenTools.defaultFontPixelHeight * 0.18
                backgroundColor: control._actionColor
                fontWeight: Font.DemiBold
                heightFactor: 0.34
                pointSize: ScreenTools.defaultFontPointSize
                showBorder: false
                text: qsTr("长按确认")
                textColor: qgcPal.buttonHighlightText
                wrapMode: Text.NoWrap

                onActivated: {
                    control.visible = false
                    var sliderOutputValue = 0
                    if (guidedValueSlider.visible) {
                        sliderOutputValue = guidedValueSlider.getOutputValue()
                        guidedValueSlider.visible = false
                    }
                    hideTrigger = false
                    let success = guidedController.executeAction(control.action, control.actionData, sliderOutputValue, control.optionChecked)
                    if (mapIndicator) {
                        if (success) {
                            mapIndicator.actionConfirmed()
                        } else {
                            mapIndicator.actionCancelled()
                        }
                        mapIndicator = undefined
                    }
                }
            }

        }
    }
}
