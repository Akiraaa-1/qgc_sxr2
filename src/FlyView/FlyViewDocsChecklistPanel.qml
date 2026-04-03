import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Item {
    id: root

    property var vehicle
    property color panelColor: "#2F2F2F"
    property color rowColor: "#3A3D41"
    property color rowLeftColor: "#34373B"
    property color rowBorderColor: "#4A4E53"
    property color titleColor: "#FFFFFF"
    property color detailColor: "#CFD3D8"
    property color passColor: "#00C2A0"
    property color failColor: "#D88E8E"
    property int minimumBatteryPercent: 40
    property int minimumSatellites: 10

    property bool _hardwareChecked: false
    property bool _batteryConnectorChecked: false
    property bool _radioChecked: false

    readonly property var _rowModel: [
        {
            "key": "hardware",
            "details": [qsTr("Props mounted?"), qsTr("Wings secured?"), qsTr("Tail secured?")]
        },
        {
            "key": "battery",
            "details": [qsTr("Connector firmly plugged?")]
        },
        {
            "key": "sensors",
            "details": []
        },
        {
            "key": "gps",
            "details": []
        },
        {
            "key": "radio",
            "details": [qsTr("Receiving signal"), qsTr("Perform range test")]
        }
    ]

    readonly property var _battery: vehicle && vehicle.batteries && vehicle.batteries.count > 0 ? vehicle.batteries.get(0) : null
    readonly property real _batteryPercent: _battery && _battery.percentRemaining && !isNaN(Number(_battery.percentRemaining.rawValue)) ? Number(_battery.percentRemaining.rawValue) : NaN
    readonly property bool _batteryTelemetryPassed: !isNaN(_batteryPercent) && _batteryPercent >= minimumBatteryPercent
    readonly property bool _batteryPassed: _batteryConnectorChecked && _batteryTelemetryPassed

    readonly property int _unhealthySensors: vehicle ? Number(vehicle.sensorsUnhealthyBits) : -1
    readonly property int _requiredSensors: Vehicle.SysStatusSensor3dMag |
                                            Vehicle.SysStatusSensor3dAccel |
                                            Vehicle.SysStatusSensor3dGyro |
                                            Vehicle.SysStatusSensorAbsolutePressure |
                                            Vehicle.SysStatusSensorDifferentialPressure |
                                            Vehicle.SysStatusSensorGPS |
                                            Vehicle.SysStatusSensorAHRS
    readonly property bool _sensorsPassed: vehicle ? ((_unhealthySensors & _requiredSensors) === 0) : false

    readonly property int _gpsLock: vehicle && vehicle.gps && vehicle.gps.lock && !isNaN(Number(vehicle.gps.lock.rawValue)) ? Number(vehicle.gps.lock.rawValue) : 0
    readonly property int _gpsSatellites: vehicle && vehicle.gps && vehicle.gps.count && !isNaN(Number(vehicle.gps.count.rawValue)) ? Number(vehicle.gps.count.rawValue) : 0
    readonly property bool _gpsPassed: vehicle ? (_gpsLock >= 3 && _gpsSatellites >= minimumSatellites) : false
    readonly property bool _allChecksPassed: _hardwareChecked && _batteryPassed && _sensorsPassed && _gpsPassed && _radioChecked
    readonly property int _completedChecks: (_hardwareChecked ? 1 : 0) +
                                            (_batteryPassed ? 1 : 0) +
                                            (_sensorsPassed ? 1 : 0) +
                                            (_gpsPassed ? 1 : 0) +
                                            (_radioChecked ? 1 : 0)

    onVehicleChanged: _resetManualChecks()

    function _resetManualChecks() {
        _hardwareChecked = false
        _batteryConnectorChecked = false
        _radioChecked = false
    }

    function _isManualRow(key) {
        return key === "hardware" || key === "battery" || key === "radio"
    }

    function _toggleRow(key) {
        if (key === "hardware") {
            _hardwareChecked = !_hardwareChecked
        } else if (key === "battery") {
            _batteryConnectorChecked = !_batteryConnectorChecked
        } else if (key === "radio") {
            _radioChecked = !_radioChecked
        }
    }

    function _isRowChecked(key) {
        if (key === "hardware") {
            return _hardwareChecked
        } else if (key === "battery") {
            return _batteryPassed
        } else if (key === "sensors") {
            return _sensorsPassed
        } else if (key === "gps") {
            return _gpsPassed
        } else if (key === "radio") {
            return _radioChecked
        }
        return false
    }

    function _rowTitleText(key) {
        if (key === "hardware") {
            return qsTr("Hardware:")
        } else if (key === "battery") {
            return qsTr("Battery")
        } else if (key === "sensors") {
            return _sensorsPassed ? qsTr("Sensors: Passed") : qsTr("Sensors: Check vehicle sensors")
        } else if (key === "gps") {
            return _gpsPassed ? qsTr("GPS: Passed") : qsTr("GPS: Waiting for lock")
        } else if (key === "radio") {
            return qsTr("Radio Control:")
        }
        return ""
    }

    function _sensorFailureText() {
        if (!vehicle) {
            return qsTr("Connect a vehicle to evaluate sensor health.")
        }
        if ((_unhealthySensors & _requiredSensors) === 0) {
            return ""
        }
        if (_unhealthySensors & Vehicle.SysStatusSensor3dMag) {
            return qsTr("Magnetometer issue detected.")
        } else if (_unhealthySensors & Vehicle.SysStatusSensor3dAccel) {
            return qsTr("Accelerometer issue detected.")
        } else if (_unhealthySensors & Vehicle.SysStatusSensor3dGyro) {
            return qsTr("Gyroscope issue detected.")
        } else if (_unhealthySensors & Vehicle.SysStatusSensorAbsolutePressure) {
            return qsTr("Barometer issue detected.")
        } else if (_unhealthySensors & Vehicle.SysStatusSensorDifferentialPressure) {
            return qsTr("Airspeed sensor issue detected.")
        } else if (_unhealthySensors & Vehicle.SysStatusSensorAHRS) {
            return qsTr("AHRS issue detected.")
        } else if (_unhealthySensors & Vehicle.SysStatusSensorGPS) {
            return qsTr("GPS sensor issue detected.")
        }
        return qsTr("Sensor health issue detected.")
    }

    function _batteryHintText() {
        if (!vehicle) {
            return qsTr("Connect a vehicle to evaluate battery health.")
        }
        if (isNaN(_batteryPercent)) {
            return qsTr("Battery level unavailable.")
        }
        if (_batteryTelemetryPassed) {
            return ""
        }
        return qsTr("Battery %1% is below minimum %2%.").arg(Math.round(_batteryPercent)).arg(minimumBatteryPercent)
    }

    function _gpsHintText() {
        if (_gpsPassed) {
            return ""
        }
        if (!vehicle) {
            return qsTr("Connect a vehicle to evaluate GPS health.")
        }
        if (_gpsLock < 3) {
            return qsTr("Waiting for 3D lock.")
        }
        if (_gpsSatellites < minimumSatellites) {
            return qsTr("Satellites %1/%2.").arg(_gpsSatellites).arg(minimumSatellites)
        }
        return qsTr("GPS telemetry unavailable.")
    }

    function _rowHintText(key) {
        if (key === "battery") {
            return _batteryHintText()
        } else if (key === "sensors") {
            return _sensorsPassed ? "" : _sensorFailureText()
        } else if (key === "gps") {
            return _gpsHintText()
        }
        return ""
    }

    function _rowHintColor(key) {
        if ((key === "battery" && !_batteryTelemetryPassed) || (key === "sensors" && !_sensorsPassed) || (key === "gps" && !_gpsPassed)) {
            return failColor
        }
        return detailColor
    }

    Rectangle {
        anchors.fill: parent
        color: panelColor

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: ScreenTools.defaultFontPixelHeight * 0.32
            spacing: ScreenTools.defaultFontPixelHeight * 0.18

            QGCLabel {
                Layout.fillWidth: true
                color: titleColor
                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.64
                font.weight: Font.DemiBold
                text: qsTr("CHECKLIST")
            }

            Flickable {
                id: checklistFlickable

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: checklistColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                }
                ScrollBar.horizontal: ScrollBar {
                    policy: ScrollBar.AlwaysOff
                }

                ColumnLayout {
                    id: checklistColumn

                    width: checklistFlickable.width
                    spacing: ScreenTools.defaultFontPixelHeight * 0.1

                    Repeater {
                        model: root._rowModel

                        delegate: Rectangle {
                            required property var modelData

                            readonly property bool _checked: root._isRowChecked(modelData.key)
                            readonly property bool _isManual: root._isManualRow(modelData.key)
                            readonly property string _titleText: root._rowTitleText(modelData.key)
                            readonly property string _hintText: root._rowHintText(modelData.key)

                            Layout.fillWidth: true
                            color: root.rowColor
                            border.color: root.rowBorderColor
                            border.width: 1
                            radius: ScreenTools.defaultFontPixelHeight * 0.08
                            implicitHeight: rowLayout.implicitHeight + (ScreenTools.defaultFontPixelHeight * 0.16)

                            RowLayout {
                                id: rowLayout

                                anchors.fill: parent
                                spacing: 0

                                Rectangle {
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 1.7
                                    color: root.rowLeftColor
                                    border.color: root.rowBorderColor
                                    border.width: 1

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: ScreenTools.defaultFontPixelHeight * 0.64
                                        height: width
                                        radius: ScreenTools.defaultFontPixelHeight * 0.07
                                        color: _checked ? root.passColor : "transparent"
                                        border.color: _checked ? root.passColor : "#A8ADB5"
                                        border.width: 1

                                        QGCColoredImage {
                                            anchors.centerIn: parent
                                            width: parent.width * 0.7
                                            height: width
                                            visible: _checked
                                            color: "#0F231C"
                                            fillMode: Image.PreserveAspectFit
                                            source: "/InstrumentValueIcons/checkmark.svg"
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.leftMargin: ScreenTools.defaultFontPixelWidth * 0.42
                                    Layout.rightMargin: ScreenTools.defaultFontPixelWidth * 0.42
                                    Layout.topMargin: ScreenTools.defaultFontPixelHeight * 0.16
                                    Layout.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.16
                                    spacing: ScreenTools.defaultFontPixelHeight * 0.06

                                    QGCLabel {
                                        Layout.fillWidth: true
                                        color: _checked ? root.detailColor : root.titleColor
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.72
                                        font.weight: Font.DemiBold
                                        text: _titleText
                                        wrapMode: Text.WordWrap
                                    }

                                    Repeater {
                                        model: modelData.details

                                        delegate: QGCLabel {
                                            required property var modelData

                                            Layout.fillWidth: true
                                            color: root.detailColor
                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.66
                                            text: "\u2022 " + modelData
                                            wrapMode: Text.WordWrap
                                        }
                                    }

                                    QGCLabel {
                                        Layout.fillWidth: true
                                        visible: _hintText.length > 0
                                        color: root._rowHintColor(modelData.key)
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.58
                                        text: _hintText
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }

                            QGCMouseArea {
                                anchors.fill: parent
                                enabled: _isManual
                                onClicked: root._toggleRow(modelData.key)
                            }
                        }
                    }
                }
            }
        }
    }
}
