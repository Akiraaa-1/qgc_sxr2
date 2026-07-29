import QtQuick

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id: root

    anchors.fill: parent
    color: "transparent"

    readonly property real _cardRadius: Math.max(ScreenTools.defaultFontPixelHeight * 0.95, 16)
    readonly property int _animDuration: 200
    readonly property color _cardColor: "#252525"
    readonly property color _cardHoverColor: "#2B2B2B"
    readonly property color _cardPressedColor: "#212121"
    readonly property color _borderColor: "#333333"
    readonly property color _primaryTextColor: "#FFFFFF"
    readonly property color _secondaryTextColor: "#FFFFFF"
    readonly property real _tileWidth: Math.max(ScreenTools.defaultFontPixelWidth * 8.7, 126)
    readonly property real _tileHeight: Math.max(ScreenTools.defaultFontPixelHeight * 6.5, 140)
    readonly property real _tileSpacing: ScreenTools.defaultFontPixelWidth * 2.4
    readonly property real _rowSpacing: ScreenTools.defaultFontPixelHeight * 1.9
    readonly property real _contentMargin: Math.max(ScreenTools.defaultFontPixelHeight, 16)
    readonly property real _stageHorizontalPadding: Math.max(ScreenTools.defaultFontPixelWidth * 3.2, 36)
    readonly property real _stageVerticalPadding: Math.max(ScreenTools.defaultFontPixelHeight * 2.2, 28)
    // Move menu upward by 21 mm in physical distance.
    readonly property real _stageVerticalOffset: -(Math.max(ScreenTools.realPixelDensity, 96 / 25.4) * 21)
    readonly property real _menuScale: {
        const availableWidth = Math.max(root.width - (root._contentMargin * 2), 1)
        const availableHeight = Math.max(root.height - (root._contentMargin * 2), 1)
        const scaleByWidth = availableWidth / Math.max(centerStage.width, 1)
        const scaleByHeight = availableHeight / Math.max(centerStage.height, 1)
        return Math.min(1, scaleByWidth, scaleByHeight)
    }

    function _componentByKeywords(keywords) {
        const vehicle = QGroundControl.multiVehicleManager.activeVehicle
        const autopilotPlugin = vehicle ? vehicle.autopilotPlugin : null
        if (!autopilotPlugin || !keywords || keywords.length === 0) {
            return null
        }

        const components = autopilotPlugin.vehicleComponents
        for (let i = 0; i < components.length; i++) {
            const component = components[i]
            if (!component) {
                continue
            }

            const name = component.name ? ("" + component.name).toLowerCase() : ""
            const setupSource = component.setupSource ? component.setupSource.toString().toLowerCase() : ""
            for (let j = 0; j < keywords.length; j++) {
                const keyword = ("" + keywords[j]).toLowerCase().trim()
                if (keyword !== "" && (name.indexOf(keyword) !== -1 || setupSource.indexOf(keyword) !== -1)) {
                    return component
                }
            }
        }

        return null
    }

    function _openComponent(keywords) {
        const component = _componentByKeywords(keywords)
        const setupView = panelLoader && panelLoader.vehicleConfigViewRef ? panelLoader.vehicleConfigViewRef : vehicleConfigView
        if (component && setupView && typeof setupView.showVehicleComponentPanel === "function") {
            setupView.showVehicleComponentPanel(component)
        }
    }

    function _componentForTile(modelData) {
        return _componentByKeywords(modelData.keys) || _componentByKeywords(modelData.fallbackKeys)
    }

    function _openTileComponent(modelData) {
        const component = _componentForTile(modelData)
        const setupView = panelLoader && panelLoader.vehicleConfigViewRef ? panelLoader.vehicleConfigViewRef : vehicleConfigView
        if (component && setupView && typeof setupView.showVehicleComponentPanel === "function") {
            setupView.showVehicleComponentPanel(component)
        }
    }

    function _specialTileAvailable(specialName) {
        const activeVehicle = QGroundControl.multiVehicleManager.activeVehicle
        switch (specialName) {
        case "parameters":
            return QGroundControl.multiVehicleManager.parameterReadyVehicleAvailable
                && !!activeVehicle
                && !activeVehicle.usingHighLatencyLink
                && QGroundControl.corePlugin.showAdvancedUI
        case "firmware":
            return !ScreenTools.isMobile && QGroundControl.corePlugin.options.showFirmwareUpgrade
        default:
            return false
        }
    }

    function _openSpecialPanel(specialName) {
        const setupView = panelLoader && panelLoader.vehicleConfigViewRef ? panelLoader.vehicleConfigViewRef : vehicleConfigView
        if (!setupView || typeof setupView.showPanel !== "function") {
            return
        }

        switch (specialName) {
        case "parameters":
            setupView.showPanel("parameters", "qrc:/qml/QGroundControl/VehicleSetup/SetupParameterEditor.qml")
            break
        case "firmware":
            setupView.showPanel("firmware", "qrc:/qml/QGroundControl/VehicleSetup/FirmwareUpgrade.qml")
            break
        default:
            break
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#1F2023"
    }

    Item {
        id: centerStage
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root._stageVerticalOffset
        width: centerContent.width + (root._stageHorizontalPadding * 2)
        height: centerContent.height + (root._stageVerticalPadding * 2)
        scale: root._menuScale
        transformOrigin: Item.Center

        Rectangle {
            anchors.fill: parent
            radius: Math.max(ScreenTools.defaultFontPixelHeight * 1.35, 20)
            border.width: 0
            border.color: "transparent"
            color: "transparent"
        }

        Item {
            id: centerContent
            anchors.centerIn: parent
            width: Math.max(titleCapsule.width, pageTitle.implicitWidth, rowOne.width, rowTwo.width)
            height: rowTwo.y + rowTwo.height

            Rectangle {
                id: titleCapsule
                anchors.horizontalCenter: parent.horizontalCenter
                y: 0
                width: Math.max(ScreenTools.defaultFontPixelWidth * 58, Math.min(root.width * 0.72, ScreenTools.defaultFontPixelWidth * 124))
                height: Math.max(ScreenTools.defaultFontPixelHeight * 6.0, 122)
                radius: height / 2
                border.width: 0
                border.color: "transparent"

                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.06) }
                    GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.035) }
                    GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.015) }
                }
                opacity: 0.48

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: 0

                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.05) }
                        GradientStop { position: 0.42; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.03) }
                    }
                }
            }

            QGCLabel {
                id: pageTitle
                anchors.horizontalCenter: parent.horizontalCenter
                y: titleCapsule.y + titleCapsule.height + Math.max(ScreenTools.defaultFontPixelHeight * 0.60, 12)
                text: qsTr("Vehicle Configuration")
                color: root._primaryTextColor
                font.family: "Times New Roman"
                font.bold: true
                font.pointSize: ScreenTools.largeFontPointSize * 1.55
            }

            Row {
                id: rowOne
                anchors.horizontalCenter: parent.horizontalCenter
                y: pageTitle.y + pageTitle.height + Math.max(ScreenTools.defaultFontPixelHeight * 1.9, 30)
                spacing: root._tileSpacing

                Repeater {
                    model: [
                        { title: qsTr("执行器"), icon: "/qmlimages/MotorComponentIcon.svg", keys: ["actuatorcomponent.qml", "actuators"], fallbackKeys: ["motorcomponent.qml"] },
                        { title: qsTr("传感器"), icon: "/qmlimages/SensorsComponentIcon.png", keys: ["sensor", "calibration"] },
                        { title: qsTr("安全"), icon: "/qmlimages/SafetyComponentIcon.png", keys: ["safety", "failsafe"] },
                        { title: qsTr("固件"), icon: "/qmlimages/FirmwareUpgradeIcon.png", special: "firmware" }
                    ]

                    delegate: Item {
                        required property var modelData

                        readonly property var _component: root._componentForTile(modelData)
                        readonly property bool _available: modelData.special !== undefined
                            ? root._specialTileAvailable(modelData.special)
                            : (_component !== null)
                        readonly property color _fillColor: !_available
                            ? root._cardColor
                            : (tileAreaTop.pressed
                                ? root._cardPressedColor
                                : (tileAreaTop.containsMouse ? root._cardHoverColor : root._cardColor))

                        visible: true
                        opacity: _available ? 1 : 0.55
                        width: root._tileWidth
                        height: root._tileHeight

                        Rectangle {
                            x: 0
                            y: tileAreaTop.containsMouse ? 2 : 1
                            width: parent.width
                            height: parent.height
                            radius: root._cardRadius + 1
                            color: "#000000"
                            opacity: tileAreaTop.containsMouse ? 0.32 : 0.24

                            Behavior on opacity {
                                NumberAnimation { duration: root._animDuration }
                            }
                            Behavior on y {
                                NumberAnimation { duration: root._animDuration }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: root._cardRadius
                            color: _fillColor
                            border.width: 1
                            border.color: root._borderColor

                            Behavior on color {
                                ColorAnimation { duration: root._animDuration }
                            }

                            MouseArea {
                                id: tileAreaTop
                                anchors.fill: parent
                                hoverEnabled: !ScreenTools.isMobile
                                cursorShape: _available ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (_available) {
                                        if (modelData.special !== undefined) {
                                            root._openSpecialPanel(modelData.special)
                                        } else {
                                            root._openTileComponent(modelData)
                                        }
                                    }
                                }
                            }

                            Column {
                                anchors.centerIn: parent
                                width: parent.width - (ScreenTools.defaultFontPixelWidth * 1.0)
                                spacing: ScreenTools.defaultFontPixelHeight * 0.52

                                Item {
                                    id: topIconWrap
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: ScreenTools.defaultFontPixelHeight * 2.35
                                    height: width

                                    QGCColoredImage {
                                        anchors.fill: parent
                                        anchors.leftMargin: -1
                                        source: modelData.icon
                                        fillMode: Image.PreserveAspectFit
                                        color: Qt.rgba(1, 1, 1, 0.22)
                                    }
                                    QGCColoredImage {
                                        anchors.fill: parent
                                        anchors.leftMargin: 1
                                        source: modelData.icon
                                        fillMode: Image.PreserveAspectFit
                                        color: Qt.rgba(1, 1, 1, 0.22)
                                    }
                                    QGCColoredImage {
                                        anchors.fill: parent
                                        anchors.topMargin: -1
                                        source: modelData.icon
                                        fillMode: Image.PreserveAspectFit
                                        color: Qt.rgba(1, 1, 1, 0.22)
                                    }
                                    QGCColoredImage {
                                        anchors.fill: parent
                                        anchors.topMargin: 1
                                        source: modelData.icon
                                        fillMode: Image.PreserveAspectFit
                                        color: Qt.rgba(1, 1, 1, 0.22)
                                    }
                                    QGCColoredImage {
                                        anchors.fill: parent
                                        source: modelData.icon
                                        fillMode: Image.PreserveAspectFit
                                        color: root._primaryTextColor
                                    }
                                }

                                QGCLabel {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    text: modelData.title
                                    color: _available ? root._secondaryTextColor : Qt.rgba(1, 1, 1, 0.62)
                                    font.pointSize: ScreenTools.defaultFontPointSize * 1.0
                                }
                            }
                        }
                    }
                }
            }

            Row {
                id: rowTwo
                anchors.horizontalCenter: parent.horizontalCenter
                y: rowOne.y + rowOne.height + root._rowSpacing
                spacing: root._tileSpacing

                Repeater {
                    model: [
                        { title: qsTr("电源"), icon: "/qmlimages/PowerComponentIcon.png", keys: ["power", "battery"] },
                        { title: qsTr("遥控器"), icon: "/qmlimages/RadioComponentIcon.png", keys: ["radio", "remote"] },
                        { title: qsTr("飞行模式"), icon: "/qmlimages/FlightModesComponentIcon.png", keys: ["flight mode", "flightmodes"] },
                        { title: qsTr("机架"), icon: "/qmlimages/AirframeComponentIcon.png", keys: ["airframe", "subframecomponent.qml", "apmairframecomponent.qml"] },
                        { title: qsTr("参数"), icon: "/qmlimages/subMenuButtonImage.png", special: "parameters" }
                    ]

                    delegate: Item {
                        required property var modelData

                        readonly property var _component: root._componentForTile(modelData)
                        readonly property bool _available: modelData.special !== undefined
                            ? root._specialTileAvailable(modelData.special)
                            : (_component !== null)
                        readonly property color _fillColor: !_available
                            ? root._cardColor
                            : (tileAreaBottom.pressed
                                ? root._cardPressedColor
                                : (tileAreaBottom.containsMouse ? root._cardHoverColor : root._cardColor))

                        visible: true
                        opacity: _available ? 1 : 0.55
                        width: root._tileWidth
                        height: root._tileHeight

                        Rectangle {
                            x: 0
                            y: tileAreaBottom.containsMouse ? 2 : 1
                            width: parent.width
                            height: parent.height
                            radius: root._cardRadius + 1
                            color: "#000000"
                            opacity: tileAreaBottom.containsMouse ? 0.32 : 0.24

                            Behavior on opacity {
                                NumberAnimation { duration: root._animDuration }
                            }
                            Behavior on y {
                                NumberAnimation { duration: root._animDuration }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: root._cardRadius
                            color: _fillColor
                            border.width: 1
                            border.color: root._borderColor

                            Behavior on color {
                                ColorAnimation { duration: root._animDuration }
                            }

                            MouseArea {
                                id: tileAreaBottom
                                anchors.fill: parent
                                hoverEnabled: !ScreenTools.isMobile
                                cursorShape: _available ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (_available) {
                                        if (modelData.special !== undefined) {
                                            root._openSpecialPanel(modelData.special)
                                        } else {
                                            root._openTileComponent(modelData)
                                        }
                                    }
                                }
                            }

                            Column {
                                anchors.centerIn: parent
                                width: parent.width - (ScreenTools.defaultFontPixelWidth * 1.0)
                                spacing: ScreenTools.defaultFontPixelHeight * 0.52

                                Item {
                                    id: bottomIconWrap
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: ScreenTools.defaultFontPixelHeight * 2.35
                                    height: width

                                    QGCColoredImage {
                                        anchors.fill: parent
                                        anchors.leftMargin: -1
                                        source: modelData.icon
                                        fillMode: Image.PreserveAspectFit
                                        color: Qt.rgba(1, 1, 1, 0.22)
                                    }
                                    QGCColoredImage {
                                        anchors.fill: parent
                                        anchors.leftMargin: 1
                                        source: modelData.icon
                                        fillMode: Image.PreserveAspectFit
                                        color: Qt.rgba(1, 1, 1, 0.22)
                                    }
                                    QGCColoredImage {
                                        anchors.fill: parent
                                        anchors.topMargin: -1
                                        source: modelData.icon
                                        fillMode: Image.PreserveAspectFit
                                        color: Qt.rgba(1, 1, 1, 0.22)
                                    }
                                    QGCColoredImage {
                                        anchors.fill: parent
                                        anchors.topMargin: 1
                                        source: modelData.icon
                                        fillMode: Image.PreserveAspectFit
                                        color: Qt.rgba(1, 1, 1, 0.22)
                                    }
                                    QGCColoredImage {
                                        anchors.fill: parent
                                        source: modelData.icon
                                        fillMode: Image.PreserveAspectFit
                                        color: root._primaryTextColor
                                    }
                                }

                                QGCLabel {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    text: modelData.title
                                    color: _available ? root._secondaryTextColor : Qt.rgba(1, 1, 1, 0.62)
                                    font.pointSize: ScreenTools.defaultFontPointSize * 1.0
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
