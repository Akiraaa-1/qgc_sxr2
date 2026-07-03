import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Column {
    property var channel
    property alias value:             channelSlider.value

    // If the default value is NaN, we add a small range
    // below, which snaps into place
    property var snap:                isNaN(channel.defaultValue)
    property var span:                channel.max - channel.min
    property var snapRange:           span * 0.15
    property var defaultVal:          snap ? channel.min - snapRange : channel.defaultValue
    property var blockUpdates:        true // avoid slider changes on startup

    id:                               root

    Layout.alignment:                 Qt.AlignTop

    readonly property int _sliderHeight: 6
    readonly property bool _popupStyled: popupStyle.inPopupContext(root)

    QGCPalette { id: qgcPal; colorGroupEnabled: true }
    QGCPopupStyle { id: popupStyle }

    function stopTimer() {
        sendTimer.stop();
    }

    function stop() {
        channelSlider.value = defaultVal;
        stopTimer();
    }

    signal actuatorValueChanged(real value, real sliderValue)

    function actuatorDisplayText(text) {
        switch (text) {
        case "All Motors":
            return qsTr("所有电机")
        case "Motor 1":
            return qsTr("电机 1")
        case "Motor 2":
            return qsTr("电机 2")
        case "Motor 3":
            return qsTr("电机 3")
        case "Motor 4":
            return qsTr("电机 4")
        case "Motor 5":
            return qsTr("电机 5")
        case "Motor 6":
            return qsTr("电机 6")
        case "Motor 7":
            return qsTr("电机 7")
        case "Motor 8":
            return qsTr("电机 8")
        case "Servo 1":
            return qsTr("舵机 1")
        case "Servo 2":
            return qsTr("舵机 2")
        case "Servo 3":
            return qsTr("舵机 3")
        case "Servo 4":
            return qsTr("舵机 4")
        default:
            return text
        }
    }

    QGCSlider {
        id:                         channelSlider
        orientation:                Qt.Vertical
        from:               snap ? channel.min - snapRange : channel.min
        to:               channel.max
        stepSize:                   (channel.max-channel.min)/100
        value:                      defaultVal
        live:   true
        anchors.horizontalCenter:   parent.horizontalCenter
        height:                     ScreenTools.defaultFontPixelHeight * _sliderHeight
        trackColor:                 _popupStyled ? popupStyle.inputBackground : qgcPal.button
        trackBorderColor:           _popupStyled ? popupStyle.borderColor : qgcPal.buttonText
        handleColor:                _popupStyled ? popupStyle.panelBackground : qgcPal.button
        handleBorderColor:          _popupStyled ? popupStyle.borderColor : qgcPal.buttonText
        labelColor:                 _popupStyled ? popupStyle.secondaryTextColor : qgcPal.buttonText

        onValueChanged: {
            if (blockUpdates)
                return;
            if (snap) {
                if (value < channel.min) {
                    if (value < channel.min - snapRange/2) {
                        value = channel.min - snapRange;
                    } else {
                        value = channel.min;
                    }
                }
            }
            sendTimer.start()
        }

        Timer {
            id:               sendTimer
            interval:         50
            triggeredOnStart: true
            repeat:           true
            running:          false
            onTriggered:      {
                var sendValue = channelSlider.value;
                if (sendValue < channel.min - snapRange/2) {
                    sendValue = channel.defaultValue;
                }
                root.actuatorValueChanged(sendValue, channelSlider.value)
            }
        }

        Component.onCompleted: {
            blockUpdates = false;
        }
    }

    QGCLabel {
        id: channelLabel
        anchors.horizontalCenter: parent.horizontalCenter
        text:                     root.actuatorDisplayText(channel.label)
        color:                    _popupStyled ? popupStyle.primaryTextColor : qgcPal.text
        width:                    contentHeight
        height:                   contentWidth
        transform: [
            Rotation { origin.x: 0; origin.y: 0; angle: -90 },
            Translate { y: channelLabel.height + 5 }
            ]
    }
} // Column
