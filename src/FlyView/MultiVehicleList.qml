import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightMap
import QGroundControl.FlyView

Item {
    property real   _margin:              ScreenTools.defaultFontPixelWidth / 2
    property real   _widgetHeight:        ScreenTools.defaultFontPixelHeight * 2.5
    property var    _guidedController:    globals.guidedControllerFlyView
    property var    _activeVehicleColor:  "green"
    property var    _activeVehicle:       QGroundControl.multiVehicleManager.activeVehicle
    property var    selectedVehicles:     QGroundControl.multiVehicleManager.selectedVehicles
    property int    _expandedVehicleId:   -1
    property var    _clusterFeedbackByVehicleId: ({})
    property var    _clusterPendingByVehicleId: ({})

    implicitHeight: vehicleList.contentHeight

    function _vehicleParameterManager(vehicle) {
        return vehicle ? vehicle.parameterManager : null
    }

    function _clusterParameterReady(vehicle) {
        const parameterManager = _vehicleParameterManager(vehicle)
        return !!(parameterManager && parameterManager.parametersReady)
    }

    function _clusterParameterExists(vehicle, paramName) {
        const parameterManager = _vehicleParameterManager(vehicle)
        return !!(parameterManager && parameterManager.parametersReady && parameterManager.parameterExists(-1, paramName))
    }

    function _clusterFact(vehicle, paramName) {
        if (!_clusterParameterExists(vehicle, paramName)) {
            return null
        }

        return vehicle.parameterManager.getParameter(-1, paramName)
    }

    function _clusterGroup(vehicle) {
        const fact = _clusterFact(vehicle, "SWARM_GROUP_ID")
        if (!fact) {
            return 0
        }

        const value = Number(fact.rawValue)
        return isNaN(value) ? 0 : Math.max(0, Math.round(value))
    }

    function _clusterLeader(vehicle) {
        const fact = _clusterFact(vehicle, "SWARM_SET_LEADER")
        if (!fact) {
            return false
        }

        const value = Number(fact.rawValue)
        return !isNaN(value) && value > 0
    }

    function _clusterSyncState(vehicle) {
        if (!vehicle) {
            return qsTr("Unavailable")
        }

        const parameterManager = _vehicleParameterManager(vehicle)
        if (!parameterManager) {
            return qsTr("Unavailable")
        }

        if (!parameterManager.parametersReady) {
            return qsTr("Waiting")
        }

        if (_clusterParameterExists(vehicle, "SWARM_GROUP_ID") || _clusterParameterExists(vehicle, "SWARM_SET_LEADER")) {
            return qsTr("Ready")
        }

        return qsTr("Param Missing")
    }

    function _clusterFeedback(vehicle) {
        if (!vehicle || vehicle.id === undefined || vehicle.id === null) {
            return ""
        }

        const value = _clusterFeedbackByVehicleId["" + vehicle.id]
        return value === undefined ? "" : value
    }

    function _setClusterFeedback(vehicle, message) {
        if (!vehicle || vehicle.id === undefined || vehicle.id === null) {
            return
        }

        const nextMap = Object.assign({}, _clusterFeedbackByVehicleId)
        nextMap["" + vehicle.id] = message
        _clusterFeedbackByVehicleId = nextMap
    }

    function _clusterPending(vehicle) {
        if (!vehicle || vehicle.id === undefined || vehicle.id === null) {
            return null
        }

        const value = _clusterPendingByVehicleId["" + vehicle.id]
        return value === undefined ? null : value
    }

    function _setClusterPending(vehicle, paramName, expectedValue, successText, failureText) {
        if (!vehicle || vehicle.id === undefined || vehicle.id === null) {
            return
        }

        const nextMap = Object.assign({}, _clusterPendingByVehicleId)
        nextMap["" + vehicle.id] = {
            "paramName": paramName,
            "expectedValue": expectedValue,
            "successText": successText,
            "failureText": failureText
        }
        _clusterPendingByVehicleId = nextMap
    }

    function _clearClusterPending(vehicle) {
        if (!vehicle || vehicle.id === undefined || vehicle.id === null) {
            return
        }

        const key = "" + vehicle.id
        if (_clusterPendingByVehicleId[key] === undefined) {
            return
        }

        const nextMap = Object.assign({}, _clusterPendingByVehicleId)
        delete nextMap[key]
        _clusterPendingByVehicleId = nextMap
    }

    function _handleClusterParamSetSuccess(vehicle, componentId, paramName) {
        const pending = _clusterPending(vehicle)
        if (!pending || pending.paramName !== paramName) {
            return
        }

        _setClusterFeedback(vehicle, pending.successText)
        _clearClusterPending(vehicle)
    }

    function _handleClusterParamSetFailure(vehicle, componentId, paramName) {
        const pending = _clusterPending(vehicle)
        if (!pending || pending.paramName !== paramName) {
            return
        }

        _setClusterFeedback(vehicle, pending.failureText)
        _clearClusterPending(vehicle)
    }

    function _handleClusterPendingWritesChanged(vehicle, pendingWrites) {
        const pending = _clusterPending(vehicle)
        if (!pending || pendingWrites) {
            return
        }

        const fact = _clusterFact(vehicle, pending.paramName)
        if (!fact) {
            _setClusterFeedback(vehicle, pending.failureText)
            _clearClusterPending(vehicle)
            return
        }

        const currentValue = Number(fact.rawValue)
        const expectedValue = Number(pending.expectedValue)
        if (!isNaN(currentValue) && !isNaN(expectedValue) && currentValue === expectedValue) {
            _setClusterFeedback(vehicle, pending.successText)
        } else {
            _setClusterFeedback(vehicle, pending.failureText)
        }
        _clearClusterPending(vehicle)
    }

    function _toggleClusterExpanded(vehicle) {
        if (!vehicle || vehicle.id === undefined || vehicle.id === null) {
            return
        }

        _expandedVehicleId = (_expandedVehicleId === vehicle.id) ? -1 : vehicle.id
    }

    function _setClusterGroup(vehicle, groupId) {
        if (!vehicle) {
            return
        }

        const groupFact = _clusterFact(vehicle, "SWARM_GROUP_ID")
        if (!groupFact) {
            _setClusterFeedback(vehicle, qsTr("SWARM_GROUP_ID unavailable"))
            return
        }

        _setClusterPending(
            vehicle,
            "SWARM_GROUP_ID",
            groupId,
            qsTr("Group %1 applied").arg(groupId),
            qsTr("Failed to set Group %1").arg(groupId)
        )
        _setClusterFeedback(vehicle, qsTr("Sending Group %1...").arg(groupId))
        groupFact.setRawValue(groupId)

        const leaderFact = _clusterFact(vehicle, "SWARM_SET_LEADER")
        if (leaderFact) {
            leaderFact.setRawValue(0)
        }
    }

    function _clearClusterGroup(vehicle) {
        if (!vehicle) {
            return
        }

        const groupFact = _clusterFact(vehicle, "SWARM_GROUP_ID")
        if (!groupFact) {
            _setClusterFeedback(vehicle, qsTr("SWARM_GROUP_ID unavailable"))
            return
        }

        _setClusterPending(
            vehicle,
            "SWARM_GROUP_ID",
            0,
            qsTr("Cluster assignment cleared"),
            qsTr("Failed to clear cluster assignment")
        )
        _setClusterFeedback(vehicle, qsTr("Clearing cluster assignment..."))
        groupFact.setRawValue(0)

        const leaderFact = _clusterFact(vehicle, "SWARM_SET_LEADER")
        if (leaderFact) {
            leaderFact.setRawValue(0)
        }
    }

    function _setClusterLeader(vehicle, leader) {
        if (!vehicle) {
            return
        }

        const leaderFact = _clusterFact(vehicle, "SWARM_SET_LEADER")
        if (!leaderFact) {
            _setClusterFeedback(vehicle, qsTr("SWARM_SET_LEADER unavailable"))
            return
        }

        _setClusterPending(
            vehicle,
            "SWARM_SET_LEADER",
            leader ? 1 : 0,
            leader ? qsTr("Leader role applied") : qsTr("Leader role cleared"),
            leader ? qsTr("Failed to set leader role") : qsTr("Failed to clear leader role")
        )
        _setClusterFeedback(vehicle, leader ? qsTr("Sending leader role...") : qsTr("Clearing leader role..."))
        leaderFact.setRawValue(leader ? 1 : 0)
    }

    function armAvailable() {
        for (var i = 0; i < selectedVehicles.count; i++) {
            var vehicle = selectedVehicles.get(i)
            if (vehicle.armed === false) {
                return true
            }
        }
        return false
    }


    function disarmAvailable() {
        for (var i = 0; i < selectedVehicles.count; i++) {
            var vehicle = selectedVehicles.get(i)
            if (vehicle.armed === true) {
                return true
            }
        }
        return false
    }

    function startAvailable() {
        for (var i = 0; i < selectedVehicles.count; i++) {
            var vehicle = selectedVehicles.get(i)
            if (vehicle.armed === true && vehicle.flightMode !== vehicle.missionFlightMode){
                return true
            }
        }
        return false
    }

    function pauseAvailable() {
        for (var i = 0; i < selectedVehicles.count; i++) {
            var vehicle = selectedVehicles.get(i)
            if (vehicle.armed === true && vehicle.supports.pauseVehicle) {
                return true
            }
        }
        return false
    }

    function selectVehicle(vehicleId) {
        QGroundControl.multiVehicleManager.selectVehicle(vehicleId)
    }

    function deselectVehicle(vehicleId) {
        QGroundControl.multiVehicleManager.deselectVehicle(vehicleId)
    }

    function toggleSelect(vehicleId) {
        if (!vehicleSelected(vehicleId)) {
            selectVehicle(vehicleId)
        } else {
            deselectVehicle(vehicleId)
        }
    }

    function selectAll() {
        var vehicles = QGroundControl.multiVehicleManager.vehicles
        for (var i = 0; i < vehicles.count; i++) {
            var vehicle = vehicles.get(i)
            var vehicleId = vehicle.id
            if (!vehicleSelected(vehicleId)) {
                selectVehicle(vehicleId)
            }
        }
    }

    function deselectAll() {
        QGroundControl.multiVehicleManager.deselectAllVehicles()
    }

    function vehicleSelected(vehicleId) {
        for (var i = 0; i < selectedVehicles.count; i++ ) {
            var currentId = selectedVehicles.get(i).id
            if (vehicleId === currentId) {
                return true
            }
        }
        return false
    }

    QGCListView {
        id:                 vehicleList
        anchors.left:       parent.left
        anchors.right:      parent.right
        anchors.top:        parent.top
        anchors.bottom:     parent.bottom
        spacing:            ScreenTools.defaultFontPixelWidth * 0.75 // _layoutMargin
        orientation:        ListView.Vertical
        model:              QGroundControl.multiVehicleManager.vehicles
        cacheBuffer:        _cacheBuffer < 0 ? 0 : _cacheBuffer
        clip:               true

        property real _cacheBuffer:     height * 2

        delegate: Rectangle {
            width:          vehicleList.width
            height:         innerColumn.height + _margin * 2
            color:          QGroundControl.multiVehicleManager.activeVehicle == _vehicle ? _activeVehicleColor : qgcPal.button
            radius:         _margin
            border.width:   _vehicle && vehicleSelected(_vehicle.id) ? 2 : 0
            border.color:   qgcPal.text

            property var    _vehicle:   object
            readonly property bool _clusterExpanded: _vehicle && _vehicle.id === _expandedVehicleId
            readonly property int _clusterGroupId: _clusterGroup(_vehicle)
            readonly property bool _clusterLeaderFlag: _clusterLeader(_vehicle)
            readonly property bool _clusterGroupAvailable: _clusterParameterExists(_vehicle, "SWARM_GROUP_ID")
            readonly property bool _clusterLeaderAvailable: _clusterParameterExists(_vehicle, "SWARM_SET_LEADER")
            readonly property bool _clusterActionsAvailable: _clusterGroupAvailable || _clusterLeaderAvailable

            QGCMouseArea {
                anchors.fill:       parent
                onClicked:          toggleSelect(_vehicle.id)
            }

            Column {
                id:                         innerColumn
                anchors.centerIn:           parent
                spacing:                    _margin

                RowLayout {
                    anchors.horizontalCenter:   parent.horizontalCenter
                    anchors.margins:    _margin
                    spacing:            _margin

                    QGCButton {
                        text: _clusterExpanded ? qsTr("v") : qsTr(">")
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 1.5
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.5
                        leftPadding: 0
                        rightPadding: 0
                        topPadding: 0
                        bottomPadding: 0
                        fontWeight: Font.DemiBold
                        backgroundColor: Qt.rgba(0, 0, 0, 0.12)
                        borderColor: Qt.rgba(1, 1, 1, 0.14)
                        textColor: qgcPal.text

                        onClicked: {
                            QGroundControl.multiVehicleManager.activeVehicle = _vehicle
                            _toggleClusterExpanded(_vehicle)
                        }
                    }

                    IntegratedCompassAttitude {
                        id: compassWidget
                        compassRadius:              _widgetHeight / 2 - attitudeSize / 2
                        compassBorder:              0
                        attitudeSize:               ScreenTools.defaultFontPixelWidth / 2
                        attitudeSpacing:            attitudeSize / 2
                        usedByMultipleVehicleList:   true
                        vehicle:                     _vehicle
                    }

                    QGCLabel {
                        text: " | "
                        font.pointSize:       ScreenTools.largeFontPointSize
                        color:                qgcPal.text
                        Layout.alignment:     Qt.AlignHCenter
                    }

                    QGCLabel {
                        text:                 _vehicle ? _vehicle.id : ""
                        font.pointSize:       ScreenTools.largeFontPointSize
                        color:                qgcPal.text
                        Layout.alignment:     Qt.AlignHCenter
                    }

                    QGCLabel {
                        text: " | "
                        font.pointSize:       ScreenTools.largeFontPointSize
                        color:                qgcPal.text
                        Layout.alignment:     Qt.AlignHCenter
                    }

                    ColumnLayout {
                        spacing:              _margin
                        Layout.rightMargin:   compassWidget.width / 4
                        Layout.alignment:     Qt.AlignCenter

                        FlightModeMenu {
                            Layout.alignment:     Qt.AlignHCenter
                            font.pointSize:       ScreenTools.largeFontPointSize
                            color:                qgcPal.text
                            currentVehicle:       _vehicle
                        }

                        QGCLabel {
                            Layout.alignment:     Qt.AlignHCenter
                            text:                 _vehicle && _vehicle.armed ? qsTr("Armed") : qsTr("Disarmed")
                            color:                qgcPal.text
                        }
                    }
                }

                QGCFlickable {
                    anchors.horizontalCenter:   parent.horizontalCenter
                    width:          Math.min(contentWidth, vehicleList.width)
                    height:         control.height
                    contentWidth:   control.width
                    contentHeight:  control.height

                    TelemetryValuesBar {
                        id:                     control
                        settingsGroup:          factValueGrid.vehicleCardSettingsGroup
                        specificVehicleForCard: _vehicle
                    }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: vehicleList.width - (_margin * 2)
                    visible: _clusterExpanded
                    color: Qt.rgba(0, 0, 0, 0.12)
                    radius: _margin
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.10)
                    implicitHeight: clusterPanelColumn.implicitHeight + (_margin * 2)

                    ColumnLayout {
                        id: clusterPanelColumn
                        anchors.fill: parent
                        anchors.margins: _margin
                        spacing: _margin

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: _margin

                            QGCLabel {
                                Layout.fillWidth: true
                                text: qsTr("Cluster")
                                font.bold: true
                                color: qgcPal.text
                            }

                            QGCLabel {
                                text: _clusterGroupId > 0 ? qsTr("Group %1").arg(_clusterGroupId) : qsTr("Unassigned")
                                color: qgcPal.text
                            }

                            QGCLabel {
                                text: _clusterLeaderFlag ? qsTr("Leader") : qsTr("Member")
                                color: qgcPal.text
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: ScreenTools.defaultFontPixelWidth

                            QGCLabel {
                                text: qsTr("Sync")
                                color: qgcPal.text
                            }

                            QGCLabel {
                                text: _clusterSyncState(_vehicle)
                                color: qgcPal.text
                                opacity: 0.8
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: ScreenTools.defaultFontPixelWidth * 0.5

                            Repeater {
                                model: [1, 2, 3, 4]

                                QGCButton {
                                    required property int modelData
                                    text: qsTr("G%1").arg(modelData)
                                    Layout.fillWidth: true
                                    heightFactor: 0.35
                                    primary: _clusterGroupId === modelData
                                    enabled: _clusterGroupAvailable
                                    onClicked: _setClusterGroup(_vehicle, modelData)
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: ScreenTools.defaultFontPixelWidth * 0.5

                            QGCButton {
                                text: qsTr("Clear")
                                Layout.fillWidth: true
                                heightFactor: 0.35
                                enabled: _clusterGroupAvailable && _clusterGroupId > 0
                                onClicked: _clearClusterGroup(_vehicle)
                            }

                            QGCButton {
                                text: _clusterLeaderFlag ? qsTr("Unset Leader") : qsTr("Set Leader")
                                Layout.fillWidth: true
                                heightFactor: 0.35
                                primary: _clusterLeaderFlag
                                enabled: _clusterLeaderAvailable && _clusterGroupId > 0
                                onClicked: _setClusterLeader(_vehicle, !_clusterLeaderFlag)
                            }
                        }

                        QGCLabel {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            visible: _clusterFeedback(_vehicle) !== "" || !_clusterActionsAvailable
                            text: _clusterActionsAvailable
                                ? _clusterFeedback(_vehicle)
                                : qsTr("Cluster parameters are not exposed by the current vehicle firmware.")
                            color: qgcPal.text
                            opacity: 0.8
                            font.pointSize: ScreenTools.defaultFontPointSize * 0.9
                        }
                    }
                }

                Connections {
                    target: _vehicle ? _vehicle.parameterManager : null
                    ignoreUnknownSignals: true

                    function on_ParamSetSuccess(componentId, paramName) {
                        _handleClusterParamSetSuccess(_vehicle, componentId, paramName)
                    }

                    function on_ParamSetFailure(componentId, paramName) {
                        _handleClusterParamSetFailure(_vehicle, componentId, paramName)
                    }

                    function onPendingWritesChanged(pendingWrites) {
                        _handleClusterPendingWritesChanged(_vehicle, pendingWrites)
                    }
                }
            }
        }
    }
}
