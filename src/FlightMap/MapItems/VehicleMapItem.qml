import QtQuick
import QtQuick.Effects
import QtLocation
import QtPositioning

import QGroundControl
import QGroundControl.Controls

/// Marker for displaying a vehicle location on the map
MapQuickItem {
    id: _root

    property var    sourceCoordinate:     QtPositioning.coordinate()
    property var    vehicle                                                         /// Vehicle object, undefined for ADSB vehicle
    property var    map
    property double altitude:       Number.NaN                                      ///< NAN to not show
    property string callsign:       ""                                              ///< Vehicle callsign
    property double heading:        vehicle ? vehicle.heading.value : Number.NaN    ///< Vehicle heading, NAN for none
    property real   size:           ScreenTools.defaultFontPixelHeight * 3          /// Default size for icon, most usage overrides this
    property bool   alert:          false                                           /// Collision alert
    property bool   showStatusCard: false

    anchorPoint.x:  vehicleItem.width  / 2
    anchorPoint.y:  vehicleItem.height / 2
    coordinate:     QGroundControl.mapDisplayCoordinate(sourceCoordinate)
    visible:        coordinate.isValid

    property var    _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property bool   _adsbVehicle:   vehicle ? false : true
    property var    _map:           map
    property bool   _multiVehicle:  QGroundControl.multiVehicleManager.vehicles.count > 1
    property bool   _showStatusCard: !!vehicle && showStatusCard && _multiVehicle

    function _hasFactValue(fact) {
        return fact && fact.rawValue !== undefined && !isNaN(Number(fact.rawValue))
    }

    function _factText(fact, fallback) {
        const safeFallback = fallback === undefined ? "--" : fallback
        if (!_hasFactValue(fact)) {
            return safeFallback
        }

        const units = fact.units !== "" ? (" " + fact.units) : ""
        return fact.valueString + units
    }

    function _vehicleTitle() {
        if (!vehicle) {
            return qsTr("Vehicle")
        }

        const names = [vehicle.vehicleName, vehicle.name, vehicle.callsign, vehicle.displayName, vehicle.objectName]
        for (let i = 0; i < names.length; i++) {
            const name = names[i] === undefined || names[i] === null ? "" : ("" + names[i]).trim()
            if (name !== "") {
                return name
            }
        }

        return qsTr("Vehicle %1").arg(vehicle.id)
    }

    sourceItem: Item {
        id:         vehicleItem
        width:      vehicleIcon.width
        height:     vehicleIcon.height
        opacity:    _adsbVehicle ? 1.0 : (vehicle === _activeVehicle ? 1.0 : (_showStatusCard ? 0.86 : 0.5))

        MultiEffect {
            source: vehicleIcon
            shadowEnabled: vehicleIcon.visible && _adsbVehicle
            shadowColor: Qt.rgba(0.94,0.91,0,1.0)
            shadowVerticalOffset: 4
            shadowHorizontalOffset: 4
            shadowBlur: 1.0
            shadowOpacity: 0.5
            shadowScale: 1.3
            blurMax: 32
            blurMultiplier: .1
        }

        Repeater {
            model: vehicle ? vehicle.gimbalController.gimbals : []

            Item {
                id:                           canvasItem
                anchors.centerIn:             vehicleItem
                width:                        vehicleItem.width * 2
                height:                       vehicleItem.height * 2
                property var gimbalYaw:       object.absoluteYaw.rawValue
                rotation:                     gimbalYaw + 180
                onGimbalYawChanged:           canvas.requestPaint()
                visible:                      vehicle && !isNaN(gimbalYaw) && QGroundControl.settingsManager.gimbalControllerSettings.showAzimuthIndicatorOnMap.rawValue
                opacity:                      object === vehicle.gimbalController.activeGimbal ? 1.0 : 0.4

                Canvas {
                    id:                           canvas
                    anchors.centerIn:             canvasItem
                    anchors.verticalCenterOffset: vehicleItem.width
                    width:                        vehicleItem.width
                    height:                       vehicleItem.height

                    onPaint:                      paintHeading()

                    function paintHeading() {
                        var context = getContext("2d")
                        // console.log("painting heading " + object.param1Raw + " " + opacity + " " + visible + " " + _index)
                        context.clearRect(0, 0, vehicleIcon.width, vehicleIcon.height);

                        var centerX = canvas.width / 2;
                        var centerY = canvas.height / 2;
                        var length = canvas.height * 1.3
                        var width = canvas.width * 0.6

                        var point1 = [centerX - width , centerY + canvas.height * 0.6]
                        var point2 = [centerX, centerY - canvas.height * 0.5]
                        var point3 = [centerX + width , centerY + canvas.height * 0.6]
                        var point4 = [centerX, centerY + canvas.height * 0.2]

                        // Draw the arrow
                        context.save();
                        context.globalAlpha = 0.9;
                        context.beginPath();
                        context.moveTo(centerX, centerY + canvas.height * 0.2);
                        context.lineTo(point1[0], point1[1]);
                        context.lineTo(point2[0], point2[1]);
                        context.lineTo(point3[0], point3[1]);
                        context.lineTo(point4[0], point4[1]);
                        context.closePath();

                        const gradient = context.createLinearGradient(canvas.width / 2, canvas.height , canvas.width / 2, 0);
                        gradient.addColorStop(0.3, Qt.rgba(255,255,255,0));
                        gradient.addColorStop(0.5, Qt.rgba(255,255,255,0.5));
                        gradient.addColorStop(1, qgcPal.mapIndicator);

                        context.fillStyle = gradient;
                        context.fill();
                        context.restore();
                    }
                }
            }
        }

        Image {
            id:                 vehicleIcon
            source:             _adsbVehicle ? (alert ? "/qmlimages/AlertAircraft.svg" : "/qmlimages/AwarenessAircraft.svg") : vehicle.vehicleImageOpaque
            mipmap:             true
            width:              _root.size
            sourceSize.width:   _root.size
            fillMode:           Image.PreserveAspectFit
            transform: Rotation {
                id:             vehicleIconRotation
                origin.x:       vehicleIcon.width  / 2
                origin.y:       vehicleIcon.height / 2
                angle:          isNaN(heading) ? 0 : heading

                Behavior on angle {
                    RotationAnimation {
                        duration: 120
                        direction: RotationAnimation.Shortest
                        easing.type: Easing.Linear
                    }
                }
            }
        }

        Rectangle {
            id: vehicleStatusCard
            visible: _showStatusCard
            x: ScreenTools.defaultFontPixelWidth * 0.35
            y: -height - (ScreenTools.defaultFontPixelHeight * 0.32)
            width: Math.max(titleLabel.implicitWidth, metricsColumn.implicitWidth) + (ScreenTools.defaultFontPixelWidth * 4.1)
            height: metricsColumn.y + metricsColumn.implicitHeight + (ScreenTools.defaultFontPixelHeight * 0.52)
            radius: ScreenTools.defaultFontPixelHeight * 0.18
            color: vehicle === _activeVehicle ? Qt.rgba(0.08, 0.09, 0.10, 0.96) : Qt.rgba(0.08, 0.09, 0.10, 0.88)
            border.width: 1
            border.color: vehicle === _activeVehicle ? Qt.rgba(0.56, 0.79, 1, 0.42) : Qt.rgba(1, 1, 1, 0.10)

            QGCLabel {
                id: titleLabel
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.72
                anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.38
                anchors.right: parent.right
                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 1.9
                color: "#F0F3F6"
                elide: Text.ElideRight
                font.weight: Font.DemiBold
                font.pixelSize: ScreenTools.smallFontPixelHeight * 1.02
                text: _root._vehicleTitle()
            }

            Column {
                id: metricsColumn
                x: ScreenTools.defaultFontPixelWidth * 0.72
                y: titleLabel.y + titleLabel.implicitHeight + (ScreenTools.defaultFontPixelHeight * 0.18)
                spacing: ScreenTools.defaultFontPixelHeight * 0.12

                Row {
                    spacing: ScreenTools.defaultFontPixelWidth * 0.16

                    QGCColoredImage {
                        width: ScreenTools.defaultFontPixelHeight * 0.56
                        height: width
                        color: "#D6DBE2"
                        fillMode: Image.PreserveAspectFit
                        source: "/InstrumentValueIcons/arrow-thin-up.svg"
                    }

                    QGCLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#D9DDE2"
                        font.pixelSize: ScreenTools.smallFontPixelHeight * 0.95
                        text: _root._factText(vehicle ? vehicle.altitudeRelative : null, "--")
                    }
                }

                Row {
                    spacing: ScreenTools.defaultFontPixelWidth * 0.16

                    QGCColoredImage {
                        width: ScreenTools.defaultFontPixelHeight * 0.56
                        height: width
                        color: "#D6DBE2"
                        fillMode: Image.PreserveAspectFit
                        source: "/InstrumentValueIcons/dashboard.svg"
                    }

                    QGCLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#D9DDE2"
                        font.pixelSize: ScreenTools.smallFontPixelHeight * 0.95
                        text: _root._factText(vehicle ? vehicle.groundSpeed : null, "--")
                    }
                }
            }
        }

        Rectangle {
            visible: vehicleStatusCard.visible
            width: ScreenTools.defaultFontPixelHeight * 1.12
            height: width
            radius: width / 2
            x: vehicleStatusCard.x + vehicleStatusCard.width - (width * 0.28)
            y: vehicleStatusCard.y + ScreenTools.defaultFontPixelHeight * 0.42
            color: Qt.rgba(0.12, 0.13, 0.15, 1.0)
            border.width: 1.4
            border.color: vehicle === _activeVehicle ? Qt.rgba(0.93, 0.96, 1, 0.86) : Qt.rgba(1, 1, 1, 0.46)

            QGCColoredImage {
                anchors.centerIn: parent
                width: parent.width * 0.5
                height: width
                color: vehicle === _activeVehicle ? "#8FD1FF" : "#F0F3F6"
                fillMode: Image.PreserveAspectFit
                source: "/InstrumentValueIcons/drone.svg"
            }
        }

        QGCMapLabel {
            id:                         vehicleLabel
            anchors.top:                parent.bottom
            anchors.horizontalCenter:   parent.horizontalCenter
            map:                        _map
            text:                       vehicleLabelText
            font.pointSize:             _adsbVehicle ? ScreenTools.defaultFontPointSize : ScreenTools.smallFontPointSize
            visible:                    _adsbVehicle ? !isNaN(altitude) : (_multiVehicle && !_showStatusCard)
            property string vehicleLabelText: visible ?
                                                  (_adsbVehicle ?
                                                       QGroundControl.unitsConversion.metersToAppSettingsVerticalDistanceUnits(altitude).toFixed(0) + " " + QGroundControl.unitsConversion.appSettingsHorizontalDistanceUnitsString + "\n" + callsign :
                                                       (_multiVehicle ? qsTr("Vehicle %1").arg(vehicle.id) : "")) :
                                                  ""

        }
    }
}
