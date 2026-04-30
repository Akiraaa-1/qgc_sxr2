import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Cluster
import QGroundControl.Controls

Rectangle {
    id: root

    anchors.fill: parent
    color: qgcPal.window

    signal popout()

    readonly property var _vehicles: QGroundControl.multiVehicleManager.vehicles
    readonly property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    readonly property int _vehicleCount: _vehicles ? _vehicles.count : 0
    readonly property int _connectedCount: _countConnectedVehicles()
    readonly property int _armedCount: _countArmedVehicles()
    readonly property int _blockedCount: _countBlockedVehicles()

    readonly property real _pageMargins: ScreenTools.defaultFontPixelHeight * 1.1
    readonly property real _sectionSpacing: ScreenTools.defaultFontPixelHeight * 0.9
    readonly property real _cardPadding: ScreenTools.defaultFontPixelHeight * 0.9
    readonly property real _cardRadius: ScreenTools.defaultFontPixelHeight * 0.66
    readonly property color _cardBorderColor: "#333333"
    readonly property color _cardBaseColor: "#2D2D2D"
    readonly property color _cardMutedFill: "#252525"
    readonly property color _cardPrimaryTextColor: "#FFFFFF"
    readonly property color _cardSecondaryTextColor: "#B0B0B0"
    readonly property color _cardAccentColor: "#2563EB"
    readonly property color _cardSuccessColor: "#56B38A"
    readonly property color _cardWarningColor: "#D6A566"
    readonly property color _cardDangerColor: "#D95C5C"
    readonly property bool _hasCommandFeedback: clusterManager.lastCommandCode >= 0

    function _groupAssignedVehicleCount(groupId) {
        const groups = clusterManager.groupSummary
        for (let i = 0; i < groups.length; i++) {
            const group = groups[i]
            if (group.groupId === groupId) {
                return group.vehicleCount
            }
        }

        return 0
    }

    function _groupLeaderText(groupId) {
        const groups = clusterManager.groupSummary
        for (let i = 0; i < groups.length; i++) {
            const group = groups[i]
            if (group.groupId === groupId) {
                return group.leaderCount > 0
                    ? qsTr("Leader: Vehicle %1").arg(group.leaderId)
                    : qsTr("Leader: None")
            }
        }

        return qsTr("Leader: None")
    }

    function _feedbackColor() {
        if (clusterManager.lastCommandSuccess) {
            return root._cardSuccessColor
        }

        return clusterManager.lastCommandCode === ClusterManager.ResultNotImplemented
            ? root._cardWarningColor
            : root._cardDangerColor
    }

    function _feedbackTitle() {
        if (!root._hasCommandFeedback) {
            return ""
        }

        if (clusterManager.lastCommandSuccess) {
            return qsTr("Cluster Action Queued")
        }

        return clusterManager.lastCommandCode === ClusterManager.ResultNotImplemented
            ? qsTr("Bridge Ready")
            : qsTr("Action Blocked")
    }

    function _clusterGroupText(vehicle) {
        if (!vehicle) {
            return qsTr("Unassigned")
        }

        const groupId = clusterManager.vehicleGroup(vehicle.id)
        return groupId > 0 ? qsTr("Group %1").arg(groupId) : qsTr("Unassigned")
    }

    function _clusterRoleText(vehicle) {
        if (!vehicle) {
            return qsTr("Member")
        }

        return clusterManager.vehicleLeader(vehicle.id) ? qsTr("Leader") : qsTr("Member")
    }

    function _activeVehicleAssigned() {
        return clusterManager.activeVehicleGroup > 0
    }

    function _groupVehicles(groupId) {
        if (!_vehicles) {
            return []
        }

        const vehicles = []
        for (let i = 0; i < _vehicles.count; i++) {
            const vehicle = _vehicles.get(i)
            if (vehicle && clusterManager.vehicleGroup(vehicle.id) === groupId) {
                vehicles.push(vehicle)
            }
        }
        return vehicles
    }

    function _groupActionEnabled(groupId, action) {
        const vehicles = _groupVehicles(groupId)
        for (let i = 0; i < vehicles.length; i++) {
            const vehicle = vehicles[i]
            const report = vehicle.healthAndArmingCheckReport
            const canArm = !(report && report.supported && !report.canArm)
            const canTakeoff = !(report && report.supported && !report.canTakeoff)
            const canStartMission = !(report && report.supported && !report.canStartMission)

            if (action === "arm" && !vehicle.armed && canArm) {
                return true
            }
            if (action === "disarm" && vehicle.armed && !vehicle.flying) {
                return true
            }
            if (action === "takeoff" && vehicle.armed && !vehicle.flying && vehicle.supports
                    && (vehicle.supports.guidedTakeoffWithAltitude || vehicle.supports.guidedTakeoffWithoutAltitude) && canTakeoff) {
                return true
            }
            if (action === "land" && vehicle.armed && vehicle.flying && vehicle.supports && vehicle.supports.guidedMode) {
                return true
            }
            if (action === "pause" && vehicle.armed && vehicle.flying && vehicle.supports && vehicle.supports.pauseVehicle) {
                return true
            }
            if (action === "resume" && vehicle.armed && vehicle.flying && canStartMission) {
                return true
            }
        }

        return false
    }

    function _countConnectedVehicles() {
        if (!_vehicles) {
            return 0
        }

        let count = 0
        for (let i = 0; i < _vehicles.count; i++) {
            const vehicle = _vehicles.get(i)
            const linkManager = vehicle ? vehicle.vehicleLinkManager : null
            if (linkManager && !linkManager.communicationLost) {
                count++
            }
        }
        return count
    }

    function _countArmedVehicles() {
        if (!_vehicles) {
            return 0
        }

        let count = 0
        for (let i = 0; i < _vehicles.count; i++) {
            const vehicle = _vehicles.get(i)
            if (vehicle && vehicle.armed) {
                count++
            }
        }
        return count
    }

    function _countBlockedVehicles() {
        if (!_vehicles) {
            return 0
        }

        let count = 0
        for (let i = 0; i < _vehicles.count; i++) {
            const vehicle = _vehicles.get(i)
            const report = vehicle ? vehicle.healthAndArmingCheckReport : null
            if (report && report.supported && !report.canArm) {
                count++
            }
        }
        return count
    }

    function _vehicleTitle(vehicle) {
        return vehicle ? (qsTr("Vehicle %1").arg(vehicle.id)) : qsTr("Vehicle")
    }

    function _isVehicleConnected(vehicle) {
        const linkManager = vehicle ? vehicle.vehicleLinkManager : null
        return !!(linkManager && !linkManager.communicationLost)
    }

    function _linkStateText(vehicle) {
        return _isVehicleConnected(vehicle) ? qsTr("Link Healthy") : qsTr("Link Lost")
    }

    function _armingStateText(vehicle) {
        if (!vehicle) {
            return "--"
        }
        if (vehicle.armed) {
            return qsTr("Armed")
        }

        const report = vehicle.healthAndArmingCheckReport
        if (report && report.supported && !report.canArm) {
            return qsTr("Arm Blocked")
        }
        return qsTr("Standby")
    }

    function _armingStateColor(vehicle) {
        if (!vehicle) {
            return _cardSecondaryTextColor
        }
        if (vehicle.armed) {
            return _cardSuccessColor
        }

        const report = vehicle.healthAndArmingCheckReport
        if (report && report.supported && !report.canArm) {
            return _cardDangerColor
        }
        return _cardWarningColor
    }

    function _batteryText(vehicle) {
        if (!vehicle || !vehicle.batteries || vehicle.batteries.count <= 0) {
            return qsTr("Battery --")
        }

        const battery = vehicle.batteries.get(0)
        const percent = battery && battery.percentRemaining ? Number(battery.percentRemaining.rawValue) : NaN
        return isNaN(percent) ? qsTr("Battery --") : qsTr("Battery %1%").arg(Math.round(percent))
    }

    function _gpsText(vehicle) {
        const gps = vehicle ? vehicle.gps : null
        const count = gps && gps.count ? Number(gps.count.rawValue) : NaN
        return isNaN(count) ? qsTr("GPS --") : qsTr("GPS %1 sats").arg(Math.round(count))
    }

    function _readyText(vehicle) {
        if (!vehicle) {
            return "--"
        }

        const report = vehicle.healthAndArmingCheckReport
        if (report && report.supported) {
            return report.canArm ? qsTr("Ready") : qsTr("Not Ready")
        }

        if (vehicle.readyToFlyAvailable) {
            return vehicle.readyToFly ? qsTr("Ready") : qsTr("Not Ready")
        }

        return qsTr("Unknown")
    }

    function _readyColor(vehicle) {
        if (!vehicle) {
            return _cardSecondaryTextColor
        }

        const report = vehicle.healthAndArmingCheckReport
        if (report && report.supported) {
            return report.canArm ? _cardSuccessColor : _cardDangerColor
        }

        if (vehicle.readyToFlyAvailable) {
            return vehicle.readyToFly ? _cardSuccessColor : _cardDangerColor
        }

        return _cardWarningColor
    }

    function _selectVehicle(vehicle) {
        if (vehicle) {
            QGroundControl.multiVehicleManager.activeVehicle = vehicle
        }
    }

    QGCPalette {
        id: qgcPal
        colorGroupEnabled: enabled
    }

    ClusterManager {
        id: clusterManager
    }

    QGCFlickable {
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: contentColumn.implicitHeight + (root._pageMargins * 2)
        flickableDirection: Flickable.VerticalFlick

        ColumnLayout {
            id: contentColumn

            width: Math.min(parent.width - (root._pageMargins * 2), ScreenTools.defaultFontPixelWidth * 96)
            anchors.top: parent.top
            anchors.topMargin: root._pageMargins
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: root._sectionSpacing

            Rectangle {
                Layout.fillWidth: true
                color: root._cardBaseColor
                radius: root._cardRadius
                border.width: 1
                border.color: root._cardBorderColor
                implicitHeight: heroLayout.implicitHeight + (root._cardPadding * 2)

                ColumnLayout {
                    id: heroLayout

                    anchors.fill: parent
                    anchors.margins: root._cardPadding
                    spacing: ScreenTools.defaultFontPixelHeight * 0.6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: ScreenTools.defaultFontPixelWidth

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: ScreenTools.defaultFontPixelHeight * 0.18

                            QGCLabel {
                                text: qsTr("Cluster Workspace")
                                font.bold: true
                                font.pointSize: ScreenTools.defaultFontPointSize * 1.35
                                color: root._cardPrimaryTextColor
                            }

                            QGCLabel {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                text: qsTr("This page is now connected to your current multi-vehicle session. It reads existing vehicle state only, so we can build cluster capability step by step without changing Fly, Plan, or map rendering.")
                                color: root._cardSecondaryTextColor
                            }
                        }

                        QGCButton {
                            text: qsTr("Back")
                            onClicked: root.popout()
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: root._cardBorderColor
                    }

                    Rectangle {
                        visible: root._hasCommandFeedback
                        Layout.fillWidth: true
                        radius: root._cardRadius * 0.82
                        color: root._cardMutedFill
                        border.width: 1
                        border.color: root._feedbackColor()
                        implicitHeight: feedbackLayout.implicitHeight + (ScreenTools.defaultFontPixelHeight * 0.8)

                        RowLayout {
                            id: feedbackLayout

                            anchors.fill: parent
                            anchors.margins: ScreenTools.defaultFontPixelHeight * 0.4
                            spacing: ScreenTools.defaultFontPixelWidth * 0.7

                            Rectangle {
                                Layout.alignment: Qt.AlignTop
                                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.62
                                Layout.preferredHeight: Layout.preferredWidth
                                radius: Layout.preferredWidth / 2
                                color: root._feedbackColor()
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: ScreenTools.defaultFontPixelHeight * 0.08

                                QGCLabel {
                                    Layout.fillWidth: true
                                    text: root._feedbackTitle()
                                    font.bold: true
                                    color: root._cardPrimaryTextColor
                                }

                                QGCLabel {
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    text: clusterManager.lastCommandMessage
                                    color: root._cardSecondaryTextColor
                                }
                            }

                            QGCButton {
                                text: qsTr("Dismiss")
                                onClicked: clusterManager.clearLastCommandResult()
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: width >= ScreenTools.defaultFontPixelWidth * 72 ? 4 : 2
                        columnSpacing: ScreenTools.defaultFontPixelWidth * 0.8
                        rowSpacing: ScreenTools.defaultFontPixelHeight * 0.6

                        Repeater {
                            model: [
                                { "title": qsTr("Detected"), "value": root._vehicleCount, "detail": qsTr("Vehicles in current session"), "color": root._cardAccentColor },
                                { "title": qsTr("Online"), "value": root._connectedCount, "detail": qsTr("Links currently healthy"), "color": root._cardSuccessColor },
                                { "title": qsTr("Armed"), "value": root._armedCount, "detail": qsTr("Vehicles with motors enabled"), "color": root._cardWarningColor },
                                { "title": qsTr("Blocked"), "value": root._blockedCount, "detail": qsTr("Vehicles failing arm checks"), "color": root._cardDangerColor },
                                { "title": qsTr("Assigned"), "value": clusterManager.assignedVehicleCount, "detail": qsTr("Vehicles with cluster group"), "color": root._cardAccentColor },
                                { "title": qsTr("Leaders"), "value": clusterManager.leaderCount, "detail": qsTr("Vehicles marked as leader"), "color": root._cardSuccessColor }
                            ]

                            Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                radius: root._cardRadius * 0.8
                                color: root._cardMutedFill
                                border.width: 1
                                border.color: root._cardBorderColor
                                implicitHeight: tileLayout.implicitHeight + (ScreenTools.defaultFontPixelHeight * 0.85)

                                ColumnLayout {
                                    id: tileLayout

                                    anchors.fill: parent
                                    anchors.margins: ScreenTools.defaultFontPixelHeight * 0.42
                                    spacing: ScreenTools.defaultFontPixelHeight * 0.12

                                    RowLayout {
                                        Layout.fillWidth: true

                                        QGCLabel {
                                            Layout.fillWidth: true
                                            text: modelData.title
                                            color: root._cardSecondaryTextColor
                                        }

                                        Rectangle {
                                            Layout.alignment: Qt.AlignVCenter
                                            implicitWidth: ScreenTools.defaultFontPixelHeight * 0.58
                                            implicitHeight: implicitWidth
                                            radius: implicitWidth / 2
                                            color: modelData.color
                                        }
                                    }

                                    QGCLabel {
                                        text: modelData.value
                                        font.bold: true
                                        font.pointSize: ScreenTools.defaultFontPointSize * 1.12
                                        color: root._cardPrimaryTextColor
                                    }

                                    QGCLabel {
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                        text: modelData.detail
                                        color: root._cardSecondaryTextColor
                                        font.pointSize: ScreenTools.defaultFontPointSize * 0.9
                                    }
                                }
                            }
                        }
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width >= ScreenTools.defaultFontPixelWidth * 86 ? 2 : 1
                columnSpacing: root._sectionSpacing
                rowSpacing: root._sectionSpacing

                Rectangle {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    color: root._cardBaseColor
                    radius: root._cardRadius
                    border.width: 1
                    border.color: root._cardBorderColor
                    implicitHeight: activeVehicleLayout.implicitHeight + (root._cardPadding * 2)

                    ColumnLayout {
                        id: activeVehicleLayout

                        anchors.fill: parent
                        anchors.margins: root._cardPadding
                        spacing: ScreenTools.defaultFontPixelHeight * 0.45

                        RowLayout {
                            Layout.fillWidth: true

                            QGCLabel {
                                Layout.fillWidth: true
                                text: qsTr("Active Vehicle Focus")
                                font.bold: true
                                font.pointSize: ScreenTools.defaultFontPointSize * 1.08
                                color: root._cardPrimaryTextColor
                            }

                            Rectangle {
                                radius: ScreenTools.defaultFontPixelHeight * 0.42
                                color: root._readyColor(root._activeVehicle)
                                implicitHeight: ScreenTools.defaultFontPixelHeight * 1.2
                                implicitWidth: focusReadyText.implicitWidth + (ScreenTools.defaultFontPixelWidth * 1.5)

                                QGCLabel {
                                    id: focusReadyText
                                    anchors.centerIn: parent
                                    text: root._readyText(root._activeVehicle)
                                    font.bold: true
                                    color: "#111111"
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: root._cardBorderColor
                        }

                        QGCLabel {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: root._activeVehicle
                                ? qsTr("%1 is the current command focus vehicle for the existing QGC session. This keeps cluster entry aligned with the project's current multi-vehicle model.").arg(root._vehicleTitle(root._activeVehicle))
                                : qsTr("No active vehicle is available yet.")
                            color: root._cardSecondaryTextColor
                        }

                        Repeater {
                            model: root._activeVehicle ? [
                                { "title": qsTr("Flight Mode"), "value": root._activeVehicle.flightMode ? root._activeVehicle.flightMode : "--" },
                                { "title": qsTr("Link"), "value": root._linkStateText(root._activeVehicle) },
                                { "title": qsTr("Arming"), "value": root._armingStateText(root._activeVehicle) },
                                { "title": qsTr("Battery"), "value": root._batteryText(root._activeVehicle) },
                                { "title": qsTr("GPS"), "value": root._gpsText(root._activeVehicle) },
                                { "title": qsTr("Cluster Group"), "value": root._clusterGroupText(root._activeVehicle) },
                                { "title": qsTr("Cluster Role"), "value": root._clusterRoleText(root._activeVehicle) }
                            ] : []

                            Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                radius: root._cardRadius * 0.7
                                color: root._cardMutedFill
                                border.width: 1
                                border.color: root._cardBorderColor
                                implicitHeight: detailRow.implicitHeight + ScreenTools.defaultFontPixelHeight * 0.36

                                RowLayout {
                                    id: detailRow

                                    anchors.fill: parent
                                    anchors.margins: ScreenTools.defaultFontPixelHeight * 0.32
                                    spacing: ScreenTools.defaultFontPixelWidth * 0.6

                                    QGCLabel {
                                        Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 12
                                        text: modelData.title
                                        color: root._cardSecondaryTextColor
                                    }

                                    QGCLabel {
                                        Layout.fillWidth: true
                                        text: modelData.value
                                        font.bold: true
                                        color: root._cardPrimaryTextColor
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }
                            }
                        }

                        QGCLabel {
                            visible: !!root._activeVehicle
                            text: qsTr("Cluster Assignment")
                            font.bold: true
                            font.pointSize: ScreenTools.defaultFontPointSize
                            color: root._cardPrimaryTextColor
                        }

                        RowLayout {
                            visible: !!root._activeVehicle
                            Layout.fillWidth: true
                            spacing: ScreenTools.defaultFontPixelWidth * 0.45

                            Repeater {
                                model: [1, 2, 3, 4]

                                QGCButton {
                                    required property int modelData
                                    Layout.fillWidth: true
                                    text: qsTr("G%1").arg(modelData)
                                    primary: clusterManager.activeVehicleGroup === modelData
                                    onClicked: clusterManager.assignActiveVehicleToGroup(modelData)
                                }
                            }
                        }

                        RowLayout {
                            visible: !!root._activeVehicle
                            Layout.fillWidth: true
                            spacing: ScreenTools.defaultFontPixelWidth * 0.55

                            QGCButton {
                                Layout.fillWidth: true
                                text: clusterManager.activeVehicleLeader ? qsTr("Unset Leader") : qsTr("Set Leader")
                                primary: clusterManager.activeVehicleLeader
                                enabled: root._activeVehicleAssigned()
                                onClicked: clusterManager.toggleLeaderForActiveVehicle()
                            }

                            QGCButton {
                                Layout.fillWidth: true
                                text: qsTr("Clear Assignment")
                                enabled: root._activeVehicleAssigned()
                                onClicked: clusterManager.clearActiveVehicleAssignment()
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    color: root._cardBaseColor
                    radius: root._cardRadius
                    border.width: 1
                    border.color: root._cardBorderColor
                    implicitHeight: integrationLayout.implicitHeight + (root._cardPadding * 2)

                    ColumnLayout {
                        id: integrationLayout

                        anchors.fill: parent
                        anchors.margins: root._cardPadding
                        spacing: ScreenTools.defaultFontPixelHeight * 0.45

                        QGCLabel {
                            text: qsTr("Integration Boundary")
                            font.bold: true
                            font.pointSize: ScreenTools.defaultFontPointSize * 1.08
                            color: root._cardPrimaryTextColor
                        }

                        Repeater {
                            model: [
                                { "title": qsTr("Already Connected"), "detail": qsTr("Live multi-vehicle roster, active vehicle switching, and core vehicle telemetry."), "color": root._cardSuccessColor },
                                { "title": qsTr("Next Adapter Layer"), "detail": qsTr("Introduce cluster manager, swarm command bridge, and ACK handling without modifying map pages."), "color": root._cardAccentColor },
                                { "title": qsTr("Deferred Core Changes"), "detail": qsTr("Do not directly merge my_vehicles or myswarm_param_send into the current core in this stage."), "color": root._cardWarningColor }
                            ]

                            Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                radius: root._cardRadius * 0.7
                                color: root._cardMutedFill
                                border.width: 1
                                border.color: root._cardBorderColor
                                implicitHeight: boundaryRow.implicitHeight + ScreenTools.defaultFontPixelHeight * 0.42

                                RowLayout {
                                    id: boundaryRow

                                    anchors.fill: parent
                                    anchors.margins: ScreenTools.defaultFontPixelHeight * 0.34
                                    spacing: ScreenTools.defaultFontPixelWidth * 0.65

                                    Rectangle {
                                        Layout.alignment: Qt.AlignTop
                                        Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.62
                                        Layout.preferredHeight: Layout.preferredWidth
                                        radius: Layout.preferredWidth / 2
                                        color: modelData.color
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: ScreenTools.defaultFontPixelHeight * 0.08

                                        QGCLabel {
                                            Layout.fillWidth: true
                                            wrapMode: Text.WordWrap
                                            text: modelData.title
                                            font.bold: true
                                            color: root._cardPrimaryTextColor
                                        }

                                        QGCLabel {
                                            Layout.fillWidth: true
                                            wrapMode: Text.WordWrap
                                            text: modelData.detail
                                            color: root._cardSecondaryTextColor
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                color: root._cardBaseColor
                radius: root._cardRadius
                border.width: 1
                border.color: root._cardBorderColor
                implicitHeight: groupOpsLayout.implicitHeight + (root._cardPadding * 2)

                ColumnLayout {
                    id: groupOpsLayout

                    anchors.fill: parent
                    anchors.margins: root._cardPadding
                    spacing: ScreenTools.defaultFontPixelHeight * 0.45

                    RowLayout {
                        Layout.fillWidth: true

                        QGCLabel {
                            Layout.fillWidth: true
                            text: qsTr("Group Operations")
                            font.bold: true
                            font.pointSize: ScreenTools.defaultFontPointSize * 1.08
                            color: root._cardPrimaryTextColor
                        }

                        QGCLabel {
                            text: qsTr("Bridge stage")
                            color: root._cardSecondaryTextColor
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: root._cardBorderColor
                    }

                    QGCLabel {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: qsTr("These controls stay inside Cluster Workspace and currently use a low-risk bridge layer. They validate group selection, log the requested action, and report status without touching Fly, Plan, or map rendering.")
                        color: root._cardSecondaryTextColor
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: width >= ScreenTools.defaultFontPixelWidth * 88 ? 2 : 1
                        columnSpacing: root._sectionSpacing
                        rowSpacing: root._sectionSpacing

                        Repeater {
                            model: [1, 2, 3, 4]

                            Rectangle {
                                required property int modelData

                                readonly property int groupId: modelData
                                readonly property int assignedCount: root._groupAssignedVehicleCount(groupId)
                                readonly property bool hasAssignments: assignedCount > 0

                                Layout.fillWidth: true
                                radius: root._cardRadius * 0.8
                                color: root._cardMutedFill
                                border.width: 1
                                border.color: hasAssignments ? root._cardAccentColor : root._cardBorderColor
                                implicitHeight: groupOpsCardLayout.implicitHeight + (ScreenTools.defaultFontPixelHeight * 0.8)

                                ColumnLayout {
                                    id: groupOpsCardLayout

                                    anchors.fill: parent
                                    anchors.margins: ScreenTools.defaultFontPixelHeight * 0.42
                                    spacing: ScreenTools.defaultFontPixelHeight * 0.18

                                    RowLayout {
                                        Layout.fillWidth: true

                                        QGCLabel {
                                            Layout.fillWidth: true
                                            text: qsTr("Group %1").arg(groupId)
                                            font.bold: true
                                            color: root._cardPrimaryTextColor
                                        }

                                        Rectangle {
                                            radius: ScreenTools.defaultFontPixelHeight * 0.38
                                            color: hasAssignments ? root._cardAccentColor : "#3A3A3A"
                                            implicitHeight: ScreenTools.defaultFontPixelHeight * 1.06
                                            implicitWidth: groupOpsCountLabel.implicitWidth + (ScreenTools.defaultFontPixelWidth * 1.35)

                                            QGCLabel {
                                                id: groupOpsCountLabel
                                                anchors.centerIn: parent
                                                text: qsTr("%1 assigned").arg(assignedCount)
                                                font.bold: true
                                                color: root._cardPrimaryTextColor
                                            }
                                        }
                                    }

                                    QGCLabel {
                                        Layout.fillWidth: true
                                        text: root._groupLeaderText(groupId)
                                        color: root._cardSecondaryTextColor
                                    }

                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: 3
                                        columnSpacing: ScreenTools.defaultFontPixelWidth * 0.55
                                        rowSpacing: ScreenTools.defaultFontPixelHeight * 0.35

                                        QGCButton {
                                            Layout.fillWidth: true
                                            text: qsTr("Arm")
                                            enabled: hasAssignments && root._groupActionEnabled(groupId, "arm")
                                            onClicked: clusterManager.armGroup(groupId)
                                        }

                                        QGCButton {
                                            Layout.fillWidth: true
                                            text: qsTr("Disarm")
                                            enabled: hasAssignments && root._groupActionEnabled(groupId, "disarm")
                                            onClicked: clusterManager.disarmGroup(groupId)
                                        }

                                        QGCButton {
                                            Layout.fillWidth: true
                                            text: qsTr("Takeoff")
                                            enabled: hasAssignments && root._groupActionEnabled(groupId, "takeoff")
                                            onClicked: clusterManager.takeoffGroup(groupId)
                                        }

                                        QGCButton {
                                            Layout.fillWidth: true
                                            text: qsTr("Land")
                                            enabled: hasAssignments && root._groupActionEnabled(groupId, "land")
                                            onClicked: clusterManager.landGroup(groupId)
                                        }

                                        QGCButton {
                                            Layout.fillWidth: true
                                            text: qsTr("Pause")
                                            enabled: hasAssignments && root._groupActionEnabled(groupId, "pause")
                                            onClicked: clusterManager.pauseGroup(groupId)
                                        }

                                        QGCButton {
                                            Layout.fillWidth: true
                                            text: qsTr("Resume")
                                            enabled: hasAssignments && root._groupActionEnabled(groupId, "resume")
                                            onClicked: clusterManager.resumeGroup(groupId)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                color: root._cardBaseColor
                radius: root._cardRadius
                border.width: 1
                border.color: root._cardBorderColor
                implicitHeight: groupSummaryLayout.implicitHeight + (root._cardPadding * 2)

                ColumnLayout {
                    id: groupSummaryLayout

                    anchors.fill: parent
                    anchors.margins: root._cardPadding
                    spacing: ScreenTools.defaultFontPixelHeight * 0.45

                    RowLayout {
                        Layout.fillWidth: true

                        QGCLabel {
                            Layout.fillWidth: true
                            text: qsTr("Cluster Group Summary")
                            font.bold: true
                            font.pointSize: ScreenTools.defaultFontPointSize * 1.08
                            color: root._cardPrimaryTextColor
                        }

                        QGCButton {
                            text: qsTr("Clear All")
                            enabled: clusterManager.assignedVehicleCount > 0
                            onClicked: clusterManager.clearAllAssignments()
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: root._cardBorderColor
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: width >= ScreenTools.defaultFontPixelWidth * 72 ? 4 : 2
                        columnSpacing: ScreenTools.defaultFontPixelWidth * 0.75
                        rowSpacing: ScreenTools.defaultFontPixelHeight * 0.55

                        Repeater {
                            model: clusterManager.groupSummary

                            Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                radius: root._cardRadius * 0.8
                                color: root._cardMutedFill
                                border.width: 1
                                border.color: root._cardBorderColor
                                implicitHeight: groupCardLayout.implicitHeight + (ScreenTools.defaultFontPixelHeight * 0.8)

                                ColumnLayout {
                                    id: groupCardLayout

                                    anchors.fill: parent
                                    anchors.margins: ScreenTools.defaultFontPixelHeight * 0.42
                                    spacing: ScreenTools.defaultFontPixelHeight * 0.12

                                    QGCLabel {
                                        text: qsTr("Group %1").arg(modelData.groupId)
                                        font.bold: true
                                        color: root._cardPrimaryTextColor
                                    }

                                    QGCLabel {
                                        text: qsTr("%1 vehicles").arg(modelData.vehicleCount)
                                        color: root._cardSecondaryTextColor
                                    }

                                    QGCLabel {
                                        text: modelData.leaderCount > 0
                                            ? qsTr("Leader: Vehicle %1").arg(modelData.leaderId)
                                            : qsTr("Leader: None")
                                        color: root._cardSecondaryTextColor
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                color: root._cardBaseColor
                radius: root._cardRadius
                border.width: 1
                border.color: root._cardBorderColor
                implicitHeight: vehiclesLayout.implicitHeight + (root._cardPadding * 2)

                ColumnLayout {
                    id: vehiclesLayout

                    anchors.fill: parent
                    anchors.margins: root._cardPadding
                    spacing: ScreenTools.defaultFontPixelHeight * 0.5

                    RowLayout {
                        Layout.fillWidth: true

                        QGCLabel {
                            Layout.fillWidth: true
                            text: qsTr("Vehicle Roster")
                            font.bold: true
                            font.pointSize: ScreenTools.defaultFontPointSize * 1.08
                            color: root._cardPrimaryTextColor
                        }

                        QGCLabel {
                            text: qsTr("%1 total").arg(root._vehicleCount)
                            color: root._cardSecondaryTextColor
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: root._cardBorderColor
                    }

                    QGCLabel {
                        visible: root._vehicleCount === 0
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: qsTr("No vehicles are currently available. When multiple aircraft are connected in this ground station, they will appear here for the first-stage cluster workspace.")
                        color: root._cardSecondaryTextColor
                    }

                    Repeater {
                        model: root._vehicles

                        Rectangle {
                            required property var object

                            readonly property var vehicle: object
                            readonly property bool isActive: root._activeVehicle === vehicle
                            readonly property color toneColor: root._isVehicleConnected(vehicle)
                                ? (vehicle.armed ? root._cardWarningColor : root._cardSuccessColor)
                                : root._cardDangerColor

                            Layout.fillWidth: true
                            radius: root._cardRadius * 0.7
                            color: isActive ? "#303847" : root._cardMutedFill
                            border.width: 1
                            border.color: isActive ? root._cardAccentColor : root._cardBorderColor
                            implicitHeight: rosterLayout.implicitHeight + (ScreenTools.defaultFontPixelHeight * 0.7)

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root._selectVehicle(vehicle)
                            }

                            ColumnLayout {
                                id: rosterLayout

                                anchors.fill: parent
                                anchors.margins: ScreenTools.defaultFontPixelHeight * 0.4
                                spacing: ScreenTools.defaultFontPixelHeight * 0.3

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: ScreenTools.defaultFontPixelWidth * 0.7

                                    Rectangle {
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.68
                                        Layout.preferredHeight: Layout.preferredWidth
                                        radius: Layout.preferredWidth / 2
                                        color: toneColor
                                    }

                                    QGCLabel {
                                        text: root._vehicleTitle(vehicle)
                                        font.bold: true
                                        color: root._cardPrimaryTextColor
                                    }

                                    Rectangle {
                                        visible: isActive
                                        radius: ScreenTools.defaultFontPixelHeight * 0.42
                                        color: root._cardAccentColor
                                        implicitHeight: ScreenTools.defaultFontPixelHeight * 1.15
                                        implicitWidth: activeChipText.implicitWidth + (ScreenTools.defaultFontPixelWidth * 1.4)

                                        QGCLabel {
                                            id: activeChipText
                                            anchors.centerIn: parent
                                            text: qsTr("Active")
                                            font.bold: true
                                            color: root._cardPrimaryTextColor
                                        }
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    QGCLabel {
                                        text: vehicle.flightMode ? vehicle.flightMode : "--"
                                        color: root._cardSecondaryTextColor
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: ScreenTools.defaultFontPixelWidth * 1.1

                                    QGCLabel {
                                        text: root._linkStateText(vehicle)
                                        color: root._isVehicleConnected(vehicle) ? root._cardSuccessColor : root._cardDangerColor
                                        font.bold: true
                                    }

                                    QGCLabel {
                                        text: root._armingStateText(vehicle)
                                        color: root._armingStateColor(vehicle)
                                        font.bold: true
                                    }

                                    QGCLabel {
                                        text: root._batteryText(vehicle)
                                        color: root._cardSecondaryTextColor
                                    }

                                    QGCLabel {
                                        text: root._gpsText(vehicle)
                                        color: root._cardSecondaryTextColor
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: ScreenTools.defaultFontPixelWidth * 1.1

                                    Rectangle {
                                        radius: ScreenTools.defaultFontPixelHeight * 0.4
                                        color: clusterManager.vehicleGroup(vehicle.id) > 0 ? root._cardAccentColor : "#3A3A3A"
                                        implicitHeight: ScreenTools.defaultFontPixelHeight * 1.12
                                        implicitWidth: groupChipLabel.implicitWidth + (ScreenTools.defaultFontPixelWidth * 1.4)

                                        QGCLabel {
                                            id: groupChipLabel
                                            anchors.centerIn: parent
                                            text: root._clusterGroupText(vehicle)
                                            font.bold: true
                                            color: root._cardPrimaryTextColor
                                        }
                                    }

                                    Rectangle {
                                        radius: ScreenTools.defaultFontPixelHeight * 0.4
                                        color: clusterManager.vehicleLeader(vehicle.id) ? root._cardWarningColor : "#3A3A3A"
                                        implicitHeight: ScreenTools.defaultFontPixelHeight * 1.12
                                        implicitWidth: roleChipLabel.implicitWidth + (ScreenTools.defaultFontPixelWidth * 1.4)

                                        QGCLabel {
                                            id: roleChipLabel
                                            anchors.centerIn: parent
                                            text: root._clusterRoleText(vehicle)
                                            font.bold: true
                                            color: clusterManager.vehicleLeader(vehicle.id) ? "#111111" : root._cardPrimaryTextColor
                                        }
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    QGCButton {
                                        text: clusterManager.vehicleLeader(vehicle.id) ? qsTr("Leader") : qsTr("Make Leader")
                                        primary: clusterManager.vehicleLeader(vehicle.id)
                                        enabled: clusterManager.vehicleGroup(vehicle.id) > 0
                                        onClicked: clusterManager.toggleLeaderForVehicle(vehicle.id)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root._pageMargins
            }
        }
    }
}
