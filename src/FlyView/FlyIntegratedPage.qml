import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQml.Models

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightMap
import QGroundControl.FlyView
import QGroundControl.VehicleSetup

Item {
    id: root
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0

    property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property var _missionController: planControllerInternal ? planControllerInternal.missionController : null
    property var guidedController: guidedActionsController
    property var planController: planControllerInternal
    property bool _isFullWindowItemDark: mapView ? mapView.isSatelliteMap : false
    property bool _showFlightPath: true
    property string _vehicleSearchText: ""
    property int _vehicleStatusPageIndex: 0
    property bool _profilePanelExpanded: true
    property bool _profilePlaybackActive: false
    property real _profileProgress: 0
    property real _profilePlaybackSpeed: 1
    property string _mapNavigationSelection: ""
    property var _profileMissionPoints: []
    property bool _trafficViewVisible: false
    property bool _videoOverlayExpanded: false
    property bool _mapStripExpanded: true
    property bool _startMissionSliderVisible: false
    property bool _startMissionFeedbackVisible: false
    property bool _startMissionFeedbackIsError: false
    property string _startMissionFeedbackText: ""
    property bool _startMissionUnavailableDialogVisible: false
    property string _startMissionUnavailableDialogText: ""
    property int _mapPrimarySliderAction: 0
    property bool _useExternalStartMissionUi: false
    property bool _instrumentPanelVisible: false
    readonly property real _profilePanelTargetHeight: Math.max(ScreenTools.defaultFontPixelHeight * 12.8, height * 0.3)
    property real _profilePanelExpandedHeight: _profilePanelTargetHeight
    property bool _profileVehicleTreeExpanded: true
    property bool _profileMissionTreeExpanded: true
    property var _vehicleStatusIconMap: ({})
    property int _expandedClusterVehicleId: -1
    property var _clusterFeedbackByVehicleId: ({})
    property var _clusterPendingByVehicleId: ({})
    property var _clusterWorkspaceWindow: null
    readonly property var _vehicleStatusIconOptions: [
        { "source": "/InstrumentValueIcons/drone.svg",             "label": qsTr("Drone") },
        { "source": "/InstrumentValueIcons/airplane-outline.svg",  "label": qsTr("Airplane") }
    ]
    readonly property var _profileSiteGroups: root._buildProfileSiteGroups(root._profileMissionPoints)
    on_ActiveVehicleChanged: root._profileMissionPoints = root._buildMissionProfilePoints()
    Component.onCompleted: root._profileMissionPoints = root._buildMissionProfilePoints()

    readonly property real _margin: ScreenTools.defaultFontPixelHeight * 0.45
    readonly property real _radius: ScreenTools.defaultFontPixelHeight * 0.35
    readonly property real _vehicleStatusExtraHeight: ScreenTools.realPixelDensity * 15
    readonly property real _leftPaneMinWidth: ScreenTools.defaultFontPixelWidth * 20
    readonly property real _rightPaneMinWidth: ScreenTools.defaultFontPixelWidth * 24
    readonly property real _leftPaneWidth: {
        const totalWidth = Number(width)
        if (isNaN(totalWidth) || totalWidth <= 0) {
            return ScreenTools.defaultFontPixelWidth * 24
        }
        const desiredWidth = Math.max(ScreenTools.defaultFontPixelWidth * 24, totalWidth * 0.25)
        const maxAllowedWidth = Math.max(_leftPaneMinWidth, totalWidth - _margin - _rightPaneMinWidth)
        return Math.max(_leftPaneMinWidth, Math.min(desiredWidth, maxAllowedWidth))
    }
    readonly property real _profilePanelCollapsedHeight: ScreenTools.defaultFontPixelHeight * 2.3
    readonly property real _profilePanelMinExpandedHeight: Math.max(ScreenTools.defaultFontPixelHeight * 10.5, height * 0.22)
    readonly property real _profilePanelMaxExpandedHeight: Math.max(ScreenTools.defaultFontPixelHeight * 17, height * 0.48)
    readonly property real _rightPaneWidth: {
        const totalWidth = Number(width)
        const leftWidth = Number(_leftPaneWidth)
        const marginWidth = Number(_margin)
        if (isNaN(totalWidth) || isNaN(leftWidth) || isNaN(marginWidth)) {
            return 0
        }
        return Math.max(0, totalWidth - leftWidth - marginWidth)
    }

    function _compactVideoOverlayWidth(availableWidth) { return Math.min(availableWidth * 0.25, ScreenTools.defaultFontPixelWidth * 24) }
    function _expandedVideoOverlayWidth(availableWidth) { return Math.min(availableWidth * 0.38, ScreenTools.defaultFontPixelWidth * 34) }
    function _openPreFlightChecklist() {
        preFlightChecklistPopup.open()
    }
    function _clampProfilePanelHeight(value) {
        const numericValue = Number(value)
        const fallbackHeight = _profilePanelTargetHeight
        const safeValue = isNaN(numericValue) || numericValue <= 0 ? fallbackHeight : numericValue
        return Math.max(_profilePanelMinExpandedHeight, Math.min(_profilePanelMaxExpandedHeight, safeValue))
    }
    function _hasFactValue(fact) { return fact && !isNaN(Number(fact.rawValue)) }
    function _factText(fact, fallback = "--", includeUnits = true) {
        if (!_hasFactValue(fact)) { return fallback }
        const units = includeUnits && fact.units !== "" ? (" " + fact.units) : ""
        return fact.valueString + units
    }
    function _vehicleTitle(vehicle) {
        if (!vehicle) { return qsTr("Vehicle --") }
        const names = [vehicle.vehicleName, vehicle.name, vehicle.callsign, vehicle.displayName, vehicle.objectName]
        for (let i = 0; i < names.length; i++) {
            const name = names[i] === undefined || names[i] === null ? "" : ("" + names[i]).trim()
            if (name !== "") { return name }
        }
        return qsTr("Vehicle %1").arg(vehicle.id)
    }
    function _missionTitle() {
        if (_activeVehicle && _activeVehicle.id !== undefined && _activeVehicle.id !== null) {
            return qsTr("Mission %1").arg(_activeVehicle.id)
        }
        return qsTr("Mission %1").arg(Math.max(_profileMissionPoints.length, 1))
    }
    function _vehicleStatusIcon(vehicle) {
        const defaultIcon = root._vehicleStatusIconOptions[0].source
        if (!vehicle || vehicle.id === undefined || vehicle.id === null) {
            return defaultIcon
        }
        return root._vehicleStatusIconMap["" + vehicle.id] || defaultIcon
    }
    function _setVehicleStatusIcon(iconSource, vehicle = _activeVehicle) {
        if (!iconSource || !vehicle || vehicle.id === undefined || vehicle.id === null) {
            return
        }
        const nextMap = Object.assign({}, root._vehicleStatusIconMap)
        nextMap["" + vehicle.id] = iconSource
        root._vehicleStatusIconMap = nextMap
    }
    function _vehicleTypeIcon(vehicle) { return root._vehicleStatusIcon(vehicle) }
    function _setActiveVehicle(vehicle) { if (vehicle) { QGroundControl.multiVehicleManager.activeVehicle = vehicle } }
    function _batteryPercentForVehicle(vehicle) {
        if (!vehicle || !vehicle.batteries || vehicle.batteries.count === 0) { return NaN }
        const battery = vehicle.batteries.get(0)
        return battery && _hasFactValue(battery.percentRemaining) ? Number(battery.percentRemaining.rawValue) : NaN
    }
    function _activeBatteryForVehicle(vehicle) {
        if (!vehicle || !vehicle.batteries || vehicle.batteries.count === 0) { return null }
        return vehicle.batteries.get(0)
    }
    function _formatFactValue(fact, includeUnits = true, unavailableText = "--") {
        if (!_hasFactValue(fact)) { return unavailableText }
        const units = includeUnits && fact.units !== "" ? (" " + fact.units) : ""
        return fact.valueString + units
    }
    function _stripRichText(text) {
        if (text === undefined || text === null) {
            return ""
        }
        return ("" + text).replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim()
    }
    function _compactReadinessLevel(vehicle) {
        if (!vehicle) {
            return 1
        }
        if (vehicle.communicationLost) {
            return 2
        }
        const report = vehicle.healthAndArmingCheckReport
        if (report && report.supported) {
            if (vehicle.armed || vehicle.flying) {
                return report.canArm === false ? 2 : (report.hasWarningsOrErrors ? 1 : 0)
            }
            if (report.canArm === false) {
                return 2
            }
            return report.hasWarningsOrErrors ? 1 : 0
        }
        if (vehicle.readyToFlyAvailable !== undefined) {
            return vehicle.readyToFly ? 0 : 1
        }
        if (vehicle.allSensorsHealthy !== undefined && vehicle.autopilotPlugin) {
            return (vehicle.allSensorsHealthy && vehicle.autopilotPlugin.setupComplete) ? 0 : 1
        }
        return 1
    }
    function _compactReadinessText(vehicle) {
        if (!vehicle) {
            return qsTr("Not Ready")
        }
        if (vehicle.communicationLost) {
            return qsTr("Not Ready")
        }
        return _compactReadinessLevel(vehicle) >= 2 ? qsTr("Not Ready") : qsTr("Ready")
    }
    function _compactReadinessColor(vehicle) {
        const level = _compactReadinessLevel(vehicle)
        if (level >= 2) {
            return "#E26D71"
        }
        if (level === 1) {
            return "#D6A566"
        }
        return "#00BE8A"
    }
    function _compactPrearmReason(vehicle) {
        if (!vehicle) {
            return qsTr("Connect a vehicle to view readiness")
        }
        if (vehicle.communicationLost) {
            return qsTr("Communication lost")
        }

        const report = vehicle.healthAndArmingCheckReport
        if (report && report.supported && report.problemsForCurrentMode && report.problemsForCurrentMode.count > 0) {
            const problem = report.problemsForCurrentMode.get(0)
            if (problem && problem.message) {
                return _stripRichText(problem.message)
            }
        }

        if (!vehicle.armed && vehicle.prearmError) {
            const prearmError = _stripRichText(vehicle.prearmError)
            if (prearmError !== "") {
                return prearmError
            }
        }

        if (vehicle.readyToFlyAvailable !== undefined && !vehicle.readyToFly) {
            return qsTr("Vehicle is still completing pre-flight checks")
        }

        return _compactReadinessLevel(vehicle) === 0
            ? qsTr("Vehicle can arm")
            : qsTr("Review vehicle status before takeoff")
    }
    function _formatElapsedTime(fact) {
        if (!_hasFactValue(fact)) { return "--:--" }
        const totalSeconds = Math.max(0, Math.round(Number(fact.rawValue)))
        const hours = Math.floor(totalSeconds / 3600)
        const minutes = Math.floor((totalSeconds % 3600) / 60)
        const seconds = totalSeconds % 60
        const minutesText = minutes < 10 ? ("0" + minutes) : ("" + minutes)
        const secondsText = seconds < 10 ? ("0" + seconds) : ("" + seconds)
        if (hours > 0) {
            const hoursText = hours < 10 ? ("0" + hours) : ("" + hours)
            return hoursText + ":" + minutesText + ":" + secondsText
        }
        return minutesText + ":" + secondsText
    }
    function _formatSignedValue(value, precision = 0, suffix = "") {
        if (isNaN(Number(value))) { return "--" }
        const numericValue = Number(value)
        const fixed = numericValue.toFixed(precision)
        const signed = numericValue > 0 ? ("+" + fixed) : fixed
        return signed + suffix
    }
    function _batteryTextForVehicle(vehicle) {
        if (!vehicle || !vehicle.batteries || vehicle.batteries.count === 0) { return qsTr("Battery --") }
        const battery = vehicle.batteries.get(0)
        return battery && _hasFactValue(battery.percentRemaining)
            ? qsTr("Battery %1%2").arg(battery.percentRemaining.valueString).arg(battery.percentRemaining.units)
            : qsTr("Battery --")
    }
    function _vehicleParameterManager(vehicle) {
        return vehicle ? vehicle.parameterManager : null
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
        const parameterManager = _vehicleParameterManager(vehicle)
        if (!vehicle || !parameterManager) {
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
    function _clusterSyncDetail(vehicle) {
        const parameterManager = _vehicleParameterManager(vehicle)
        if (!vehicle || !parameterManager) {
            return qsTr("Cluster control is unavailable for this vehicle.")
        }
        if (!parameterManager.parametersReady) {
            return qsTr("Waiting for vehicle parameters to finish loading.")
        }
        if (!_clusterParameterExists(vehicle, "SWARM_GROUP_ID") && !_clusterParameterExists(vehicle, "SWARM_SET_LEADER")) {
            return qsTr("Current firmware does not expose cluster parameters.")
        }
        return ""
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
    function _toggleClusterPanel(vehicle) {
        if (!vehicle || vehicle.id === undefined || vehicle.id === null) {
            return
        }
        _expandedClusterVehicleId = (_expandedClusterVehicleId === vehicle.id) ? -1 : vehicle.id
    }
    function _setClusterGroup(vehicle, groupId) {
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
        _setClusterFeedback(vehicle, leader ? qsTr("Setting leader role...") : qsTr("Clearing leader role..."))
        leaderFact.setRawValue(leader ? 1 : 0)
    }
    function _buildMissionProfilePoints() {
        const points = []
        const missionController = planControllerInternal ? planControllerInternal.missionController : null
        const visualItems = missionController ? missionController.visualItems : null
        let distance = 0
        let previousCoord = null

        if (visualItems && visualItems.count > 0) {
            for (let i = 0; i < visualItems.count; i++) {
                const item = visualItems.get(i)
                if (!item || !item.coordinate || !item.coordinate.isValid) {
                    continue
                }
                const coord = item.coordinate
                const altitude = !isNaN(Number(coord.altitude))
                    ? Number(coord.altitude)
                    : ((item.altitude && _hasFactValue(item.altitude)) ? Number(item.altitude.rawValue) : NaN)
                if (isNaN(altitude)) {
                    continue
                }

                if (previousCoord && previousCoord.isValid) {
                    distance += previousCoord.distanceTo(coord)
                }
                previousCoord = coord

                const sequence = (item.sequenceNumber !== undefined && item.sequenceNumber !== null)
                    ? Number(item.sequenceNumber)
                    : points.length + 1
                points.push({
                    "label": sequence,
                    "distance": distance,
                    "altitude": altitude,
                    "coordinate": coord
                })
            }
        }

        if (points.length < 2 && _activeVehicle && _activeVehicle.trajectoryPoints) {
            const trajectory = _activeVehicle.trajectoryPoints.list()
            distance = 0
            previousCoord = null
            for (let i = 0; i < trajectory.length; i++) {
                const coord = trajectory[i]
                if (!coord || !coord.isValid || isNaN(Number(coord.altitude))) {
                    continue
                }
                if (previousCoord && previousCoord.isValid) {
                    distance += previousCoord.distanceTo(coord)
                }
                previousCoord = coord
                points.push({
                    "label": points.length + 1,
                    "distance": distance,
                    "altitude": Number(coord.altitude),
                    "coordinate": coord
                })
            }
        }

        if (points.length < 2) {
            const fallbackAlt = (_activeVehicle && _hasFactValue(_activeVehicle.altitudeRelative))
                ? Number(_activeVehicle.altitudeRelative.rawValue)
                : 20
            const baseCoord = (_activeVehicle && _activeVehicle.coordinate && _activeVehicle.coordinate.isValid)
                ? _activeVehicle.coordinate
                : null
            return [
                { "label": 1, "distance": 0,    "altitude": fallbackAlt + 8, "coordinate": baseCoord },
                { "label": 2, "distance": 950,  "altitude": fallbackAlt + 8, "coordinate": baseCoord },
                { "label": 3, "distance": 2000, "altitude": fallbackAlt - 4, "coordinate": baseCoord },
                { "label": 4, "distance": 3050, "altitude": fallbackAlt - 4, "coordinate": baseCoord },
                { "label": 5, "distance": 5000, "altitude": fallbackAlt + 2, "coordinate": baseCoord }
            ]
        }

        return points
    }
    function _profileStats(points) {
        if (!points || points.length === 0) {
            return { "minAlt": 0, "maxAlt": 40, "totalDistance": 5000 }
        }
        let minAlt = Number(points[0].altitude)
        let maxAlt = Number(points[0].altitude)
        for (let i = 1; i < points.length; i++) {
            const alt = Number(points[i].altitude)
            minAlt = Math.min(minAlt, alt)
            maxAlt = Math.max(maxAlt, alt)
        }
        if (Math.abs(maxAlt - minAlt) < 6) {
            maxAlt += 3
            minAlt -= 3
        }
        return {
            "minAlt": minAlt - 2,
            "maxAlt": maxAlt + 2,
            "totalDistance": Math.max(Number(points[points.length - 1].distance), 1)
        }
    }
    function _formatReplayTime(seconds) {
        const safeSeconds = Math.max(0, Math.floor(seconds))
        const mins = Math.floor(safeSeconds / 60)
        const secs = safeSeconds % 60
        const minuteText = mins < 10 ? ("0" + mins) : ("" + mins)
        const secondText = secs < 10 ? ("0" + secs) : ("" + secs)
        return minuteText + ":" + secondText
    }
    function _formatDurationClock(seconds, unavailableText = "--:--") {
        const numeric = Number(seconds)
        if (isNaN(numeric) || numeric < 0) {
            return unavailableText
        }
        const totalSeconds = Math.floor(numeric)
        const hours = Math.floor(totalSeconds / 3600)
        const minutes = Math.floor((totalSeconds % 3600) / 60)
        const secs = totalSeconds % 60
        const hh = hours < 10 ? ("0" + hours) : ("" + hours)
        const mm = minutes < 10 ? ("0" + minutes) : ("" + minutes)
        const ss = secs < 10 ? ("0" + secs) : ("" + secs)
        return hours > 0 ? (hh + ":" + mm + ":" + ss) : (mm + ":" + ss)
    }
    function _remainingFlightSeconds(vehicle) {
        const battery = _activeBatteryForVehicle(vehicle)
        if (!battery || !battery.timeRemaining || isNaN(Number(battery.timeRemaining.rawValue))) {
            return NaN
        }
        return Math.max(0, Number(battery.timeRemaining.rawValue))
    }
    function _missionRemainingSeconds(vehicle) {
        if (!_missionController) {
            return NaN
        }

        const totalMissionSeconds = Number(_missionController.missionTime)
        if (isNaN(totalMissionSeconds) || totalMissionSeconds <= 0) {
            return NaN
        }

        const visualItems = _missionController.visualItems
        const itemCount = visualItems ? Number(visualItems.count) : 0
        const currentMissionIndex = Number(_missionController.currentMissionIndex)
        if (isNaN(currentMissionIndex) || itemCount <= 1 || currentMissionIndex < 0) {
            return totalMissionSeconds
        }

        const progress = Math.max(0, Math.min(1, currentMissionIndex / Math.max(1, itemCount - 1)))
        return Math.max(0, totalMissionSeconds * (1 - progress))
    }
    function _homeIsValid(vehicle) {
        return !!(vehicle && vehicle.homePosition && vehicle.homePosition.isValid &&
                  vehicle.homePosition.latitude !== 0 && vehicle.homePosition.longitude !== 0)
    }
    function _distanceToHomeMeters(vehicle) {
        if (vehicle && vehicle.distanceToHome && !isNaN(Number(vehicle.distanceToHome.rawValue))) {
            return Number(vehicle.distanceToHome.rawValue)
        }
        if (vehicle && _homeIsValid(vehicle) && _vehicleHasPosition(vehicle)) {
            return vehicle.coordinate.distanceTo(vehicle.homePosition)
        }
        return NaN
    }
    function _timeToHomeSeconds(vehicle) {
        if (vehicle && vehicle.timeToHome && !isNaN(Number(vehicle.timeToHome.rawValue))) {
            return Math.max(0, Number(vehicle.timeToHome.rawValue))
        }

        const distanceToHome = _distanceToHomeMeters(vehicle)
        const groundSpeed = vehicle && vehicle.groundSpeed && !isNaN(Number(vehicle.groundSpeed.rawValue))
            ? Number(vehicle.groundSpeed.rawValue)
            : NaN
        if (isNaN(distanceToHome) || isNaN(groundSpeed) || groundSpeed <= 0.1) {
            return NaN
        }
        return Math.max(0, distanceToHome / groundSpeed)
    }
    function _ekfStatusLevel(vehicle) {
        if (!vehicle) {
            return 1
        }

        if (vehicle.allSensorsHealthy !== undefined && vehicle.sensorsUnhealthyBits !== undefined) {
            if (!vehicle.allSensorsHealthy && Number(vehicle.sensorsUnhealthyBits) > 0) {
                return 2
            }
            return vehicle.allSensorsHealthy ? 0 : 1
        } else if (vehicle.allSensorsHealthy !== undefined) {
            return vehicle.allSensorsHealthy ? 0 : 1
        }

        const report = vehicle.healthAndArmingCheckReport
        if (report && report.supported) {
            if (report.canArm === false) {
                return 2
            }
            if (report.hasWarningsOrErrors === true) {
                return 1
            }
            return 0
        }

        return 1
    }
    function _ekfStatusText(vehicle) {
        const level = _ekfStatusLevel(vehicle)
        if (level >= 2) {
            return qsTr("Fault")
        } else if (level === 1) {
            return qsTr("Check")
        }
        return qsTr("Good")
    }
    function _rtlSafetyLevel(vehicle) {
        if (!vehicle) {
            return 1
        }

        if (!_homeIsValid(vehicle)) {
            return 2
        }

        const gpsPercent = _networkGpsPercent(vehicle)
        const linkPercent = _communicationTelemetryQualityPercent(vehicle)
        const remainingFlight = _remainingFlightSeconds(vehicle)
        const timeHome = _timeToHomeSeconds(vehicle)
        const batteryPercent = _batteryPercentForVehicle(vehicle)

        if ((!isNaN(gpsPercent) && gpsPercent < 35) || (!isNaN(linkPercent) && linkPercent < 35)) {
            return 2
        }
        if (!isNaN(batteryPercent) && batteryPercent <= 20) {
            return 2
        }
        if (!isNaN(timeHome) && !isNaN(remainingFlight) && remainingFlight > 0 && timeHome > (remainingFlight * 0.9)) {
            return 2
        }
        if ((!isNaN(gpsPercent) && gpsPercent < 55) || (!isNaN(linkPercent) && linkPercent < 55)) {
            return 1
        }
        if (!isNaN(timeHome) && !isNaN(remainingFlight) && remainingFlight > 0 && timeHome > (remainingFlight * 0.65)) {
            return 1
        }

        return 0
    }
    function _rtlSafetyText(vehicle) {
        const level = _rtlSafetyLevel(vehicle)
        if (level >= 2) {
            return qsTr("Risky")
        } else if (level === 1) {
            return qsTr("Caution")
        }
        return qsTr("Safe")
    }
    function _summaryStateColor(level) {
        if (level >= 2) {
            return "#C66D72"
        } else if (level === 1) {
            return "#D6A566"
        }
        return "#00BE8A"
    }
    function _formatProfileAxisDistance(distanceMeters) {
        return (Math.max(0, Number(distanceMeters)) / 1000).toFixed(1) + "km"
    }
    function _formatProfileAltitude(altitudeMeters) {
        return Math.round(Number(altitudeMeters)) + "m"
    }
    function _headingCompassLabel(headingDegrees) {
        if (isNaN(Number(headingDegrees))) { return "--" }
        const normalized = ((Number(headingDegrees) % 360) + 360) % 360
        const directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        return directions[Math.round(normalized / 45) % directions.length]
    }
    function _profileTotalDurationSeconds(points) {
        const totalDistance = Math.max(Number(_profileStats(points).totalDistance), 1)
        const defaultSpeed = 4.5
        const speedFact = _activeVehicle ? _activeVehicle.groundSpeed : null
        const speed = _hasFactValue(speedFact) ? Math.max(0.5, Number(speedFact.rawValue)) : defaultSpeed
        return Math.max(180, Math.round(totalDistance / speed))
    }
    function _profileElapsedSeconds(points, progress) {
        return _profileTotalDurationSeconds(points) * Math.max(0, Math.min(1, Number(progress)))
    }
    function _profilePointIndexAtProgress(points, progress) {
        if (!points || points.length === 0) { return -1 }
        const totalDistance = Math.max(Number(_profileStats(points).totalDistance), 1)
        const targetDistance = totalDistance * Math.max(0, Math.min(1, Number(progress)))
        for (let i = 0; i < points.length; i++) {
            if (Number(points[i].distance) >= targetDistance) {
                return i
            }
        }
        return points.length - 1
    }
    function _profilePointAtProgress(points, progress) {
        const index = _profilePointIndexAtProgress(points, progress)
        return index >= 0 ? points[index] : null
    }
    function _buildProfileSiteGroups(points) {
        const groups = []
        if (!points || points.length === 0) {
            return groups
        }

        const requestedSiteCount = points.length > 1 ? 2 : 1
        const siteCount = Math.min(requestedSiteCount, points.length)
        const chunkSize = Math.ceil(points.length / siteCount)

        for (let i = 0; i < siteCount; i++) {
            const startIndex = i * chunkSize
            if (startIndex >= points.length) {
                break
            }
            const endIndex = Math.min(points.length - 1, ((i + 1) * chunkSize) - 1)
            const startPoint = points[startIndex]
            const endPoint = points[endIndex]
            groups.push({
                "label": qsTr("S2D Site %1").arg(i + 1),
                "startIndex": startIndex,
                "endIndex": endIndex,
                "startDistance": Number(startPoint.distance),
                "endDistance": Number(endPoint.distance),
                "altitude": Number(endPoint.altitude),
                "coordinate": startPoint.coordinate
            })
        }

        return groups
    }
    function _triggerMapStripAction(command) {
        if (command !== "startMission" && root._startMissionSliderVisible) {
            root._hideStartMissionSlider()
        }
        if (command !== "startMission" && root._startMissionFeedbackVisible) {
            root._hideStartMissionFeedback()
        }
        if (command !== "startMission" && root._startMissionUnavailableDialogVisible) {
            root._hideStartMissionUnavailableDialog()
        }
        switch (command) {
        case "traffic":
            root._trafficViewVisible = !root._trafficViewVisible
            if (root._trafficViewVisible) {
                root._instrumentPanelVisible = false
                trafficViewPanel.refresh()
            }
            break
        case "list":
            root._instrumentPanelVisible = !root._instrumentPanelVisible
            if (root._instrumentPanelVisible) {
                root._trafficViewVisible = false
            }
            break
        case "orbit":
            if (typeof mapView.bearing !== "undefined") {
                mapView.bearing = (mapView.bearing + 20) % 360
            }
            break
        case "lockOrbit":
            if (typeof mapView.bearing !== "undefined") {
                mapView.bearing = 0
            }
            break
        case "up":
            if (root._activeVehicle) {
                root._activeVehicle.guidedModeChangeAltitude(2, false)
            }
            break
        case "down":
            if (root._activeVehicle) {
                root._activeVehicle.guidedModeChangeAltitude(-2, false)
            }
            break
        case "rtl":
            if (root._activeVehicle) {
                guidedActionsController.confirmAction(guidedActionsController.actionRTL)
            }
            break
        case "play":
            if (guidedActionsController.showContinueMission) {
                guidedActionsController.confirmAction(guidedActionsController.actionContinueMission)
            }
            break
        case "startMission":
            root._showStartMissionSlider()
            break
        case "pause":
            if (root._activeVehicle) {
                guidedActionsController.confirmAction(guidedActionsController.actionPause)
            }
            break
        case "pan":
            if (root._mapNavigationSelection === "pan") {
                root._mapNavigationSelection = ""
                break
            }
            mapView._flyViewSettings.keepMapCenteredOnVehicle.rawValue = false
            mapView._disableVehicleTracking = true
            root._mapNavigationSelection = "pan"
            break
        case "locate":
            if (root._activeVehicle && mapView._activeVehicleCoordinate.isValid) {
                if (root._mapNavigationSelection === "locate") {
                    mapView._flyViewSettings.keepMapCenteredOnVehicle.rawValue = false
                    mapView._disableVehicleTracking = true
                    root._mapNavigationSelection = ""
                    break
                }
                mapView._flyViewSettings.keepMapCenteredOnVehicle.rawValue = true
                mapView._disableVehicleTracking = false
                mapView.center = mapView._activeVehicleCoordinate
                root._mapNavigationSelection = "locate"
            }
            break
        }
    }
    function _showStartMissionSlider() {
        const actionCode = root._mapPrimaryActionCode()
        if (!root._mapPrimaryActionAvailable()) {
            root._hideStartMissionSlider()
            root._showStartMissionUnavailableDialog()
            return
        }
        root._hideStartMissionFeedback()
        guidedActionsController.closeAll()
        root._mapPrimarySliderAction = actionCode
        root._startMissionSliderVisible = true
    }
    function _hideStartMissionSlider() {
        root._startMissionSliderVisible = false
        if (startMissionSliderSwitch.visible) {
            startMissionSliderSwitch.resetSpaceBarSliding()
        }
    }
    function _confirmStartMissionSlider() {
        if (!root._mapPrimaryActionAvailable()) {
            root._hideStartMissionSlider()
            root._showStartMissionUnavailableDialog()
            return
        }
        root._hideStartMissionSlider()
        switch (root._mapPrimarySliderAction) {
        case guidedActionsController.actionArm:
            root._showStartMissionFeedback(qsTr("Arm command sent. Verify vehicle state before takeoff."), false)
            break
        case guidedActionsController.actionForceArm:
            root._showStartMissionFeedback(qsTr("Force arm command sent. Verify vehicle state before takeoff."), false)
            break
        case guidedActionsController.actionContinueMission:
            root._showStartMissionFeedback(qsTr("Mission continue command sent. Verify vehicle state before takeoff."), false)
            break
        default:
            root._showStartMissionFeedback(qsTr("Mission start command sent. Verify vehicle state before takeoff."), false)
            break
        }
        guidedActionsController.executeAction(root._mapPrimarySliderAction, undefined, 0, false)
    }
    function _showStartMissionFeedback(message, isError) {
        root._startMissionFeedbackText = message
        root._startMissionFeedbackIsError = !!isError
        root._startMissionFeedbackVisible = true
        startMissionFeedbackTimer.restart()
    }
    function _showStartMissionUnavailableDialog() {
        root._hideStartMissionFeedback()
        root._startMissionUnavailableDialogText = root._startMissionUnavailableMessage()
        root._startMissionUnavailableDialogVisible = true
    }
    function _hideStartMissionUnavailableDialog() {
        root._startMissionUnavailableDialogVisible = false
    }
    function _hideStartMissionFeedback() {
        startMissionFeedbackTimer.stop()
        root._startMissionFeedbackVisible = false
    }
    function _startMissionUnavailableMessage() {
        if (!root._activeVehicle) {
            return qsTr("No active vehicle. Connect to a vehicle before starting the mission.")
        }
        switch (root._mapPrimaryActionCode()) {
        case guidedActionsController.actionArm:
            if (guidedActionsController._vehicleFlying) {
                return qsTr("The vehicle is already flying.")
            }
            if (!guidedActionsController._checklistPassed) {
                return qsTr("The preflight checklist has not passed yet.")
            }
            if (!guidedActionsController._canArm) {
                return qsTr("The vehicle is not ready to arm yet.")
            }
            return qsTr("The current vehicle state does not allow arming.")
        case guidedActionsController.actionForceArm:
            if (guidedActionsController._vehicleFlying) {
                return qsTr("The vehicle is already flying.")
            }
            return qsTr("Normal arming is currently blocked. Use force arm only if you understand the risk.")
        case guidedActionsController.actionContinueMission:
            return qsTr("The current vehicle state does not allow continuing the mission.")
        default:
            if (!guidedActionsController._missionAvailable) {
                return qsTr("No mission is available to start.")
            }
            if (guidedActionsController._missionActive) {
                return qsTr("The mission is already active.")
            }
            if (guidedActionsController._vehicleFlying) {
                return qsTr("The vehicle is already flying.")
            }
            if (!guidedActionsController._checklistPassed) {
                return qsTr("The preflight checklist has not passed yet.")
            }
            if (!guidedActionsController._canStartMission) {
                return qsTr("The vehicle is not ready to start the mission yet.")
            }
            return qsTr("The current vehicle state does not allow starting the mission.")
        }
    }
    function _isMapFollowMode() {
        return !!(root._activeVehicle &&
                  mapView &&
                  mapView._activeVehicleCoordinate &&
                  mapView._activeVehicleCoordinate.isValid &&
                  mapView._flyViewSettings.keepMapCenteredOnVehicle.rawValue &&
                  !mapView._disableVehicleTracking)
    }
    function _isMapPanMode() { return !!mapView && !_isMapFollowMode() }
    function _mapPrimaryActionKey() {
        if (!guidedActionsController || !root._activeVehicle) {
            return "startMission"
        }
        if (!guidedActionsController._vehicleArmed) {
            if (guidedActionsController.showArm) {
                return "arm"
            }
            if (guidedActionsController.showForceArm) {
                return "forceArm"
            }
        }
        if (guidedActionsController.showStartMission) {
            return "startMission"
        }
        if (guidedActionsController.showContinueMission) {
            return "continueMission"
        }
        return "startMission"
    }
    function _mapPrimaryActionText() {
        switch (_mapPrimaryActionKey()) {
        case "arm":
            return qsTr("ARM")
        case "forceArm":
            return qsTr("FORCE")
        case "continueMission":
            return qsTr("PLAY")
        default:
            return qsTr("START")
        }
    }
    function _mapPrimaryActionCode() {
        switch (_mapPrimaryActionKey()) {
        case "arm":
            return guidedActionsController.actionArm
        case "forceArm":
            return guidedActionsController.actionForceArm
        case "continueMission":
            return guidedActionsController.actionContinueMission
        default:
            return guidedActionsController.actionStartMission
        }
    }
    function _mapPrimaryActionAvailable() {
        switch (_mapPrimaryActionCode()) {
        case guidedActionsController.actionArm:
            return guidedActionsController.showArm
        case guidedActionsController.actionForceArm:
            return guidedActionsController.showForceArm
        case guidedActionsController.actionContinueMission:
            return guidedActionsController.showContinueMission
        default:
            return guidedActionsController.showStartMission
        }
    }
    function _mapPrimaryActionMessage() {
        switch (root._mapPrimarySliderAction || root._mapPrimaryActionCode()) {
        case guidedActionsController.actionArm:
            return guidedActionsController.armMessage
        case guidedActionsController.actionForceArm:
            return guidedActionsController.forceArmMessage
        case guidedActionsController.actionContinueMission:
            return guidedActionsController.continueMissionMessage
        default:
            return guidedActionsController.startMissionMessage
        }
    }
    function _triggerMapPrimaryAction() {
        root._showStartMissionSlider()
    }
    function _isMapStripActionEnabled(key, requiresVehicle) {
        if (key === "startMission") {
            return true
        }
        if (key === "locate") {
            return root._vehicleHasPosition(root._activeVehicle)
        }
        return !requiresVehicle || !!root._activeVehicle
    }
    function _isMapStripSelected(key) {
        if (key === "startMission") {
            return root._startMissionSliderVisible
        }
        if (key === "traffic") {
            return root._trafficViewVisible
        }
        if (key === "list") {
            return root._instrumentPanelVisible
        }
        if (key === "pan" || key === "locate") {
            return root._mapNavigationSelection === key
        }
        return false
    }
    function _batteryIcon(percent) {
        if (isNaN(percent)) { return "/InstrumentValueIcons/battery-half.svg" }
        if (percent <= 25) { return "/InstrumentValueIcons/battery-low.svg" }
        if (percent <= 60) { return "/InstrumentValueIcons/battery-half.svg" }
        return "/InstrumentValueIcons/battery-full.svg"
    }
    function _vehicleHasPosition(vehicle) {
        return !!(vehicle && vehicle.coordinate && vehicle.coordinate.isValid &&
                  vehicle.coordinate.latitude !== 0 && vehicle.coordinate.longitude !== 0)
    }
    function _trafficRangeStep(distanceMeters) {
        const steps = [500, 1000, 2000, 3000, 5000, 10000, 20000]
        for (let i = 0; i < steps.length; i++) {
            if (distanceMeters <= steps[i]) {
                return steps[i]
            }
        }
        return Math.ceil(distanceMeters / 5000) * 5000
    }
    function _vehicleLinkStrength(vehicle) {
        return vehicle && vehicle.rcRSSI !== undefined ? Number(vehicle.rcRSSI) : NaN
    }
    function _vehicleStatusIndicators(vehicle) {
        const batteryPercent = _batteryPercentForVehicle(vehicle)
        const linkStrength = _vehicleLinkStrength(vehicle)
        const hasPosition = _vehicleHasPosition(vehicle)
        const inMission = !!(vehicle && vehicle.flightMode && ("" + vehicle.flightMode).toLowerCase().indexOf("mission") !== -1)
        const isActive = !!(vehicle && (vehicle.flying || vehicle.armed))

        return [
            {
                "icon": _batteryIcon(batteryPercent),
                "color": isNaN(batteryPercent) ? "#7E8792" : (batteryPercent <= 25 ? "#BE7378" : (batteryPercent <= 60 ? "#C4B66D" : "#AFC4D7"))
            },
            {
                "icon": hasPosition ? "/InstrumentValueIcons/target.svg" : "/InstrumentValueIcons/view-hide.svg",
                "color": hasPosition ? "#8FC4AE" : "#7E8792"
            },
            {
                "icon": !isNaN(linkStrength) && linkStrength > 0 ? "/InstrumentValueIcons/radio.svg" : "/InstrumentValueIcons/notifications-outline.svg",
                "color": !isNaN(linkStrength) && linkStrength > 70 ? "#C6C16F" : (!isNaN(linkStrength) && linkStrength > 0 ? "#A8B6C9" : "#BE7378")
            },
            {
                "icon": inMission ? "/InstrumentValueIcons/navigation-more.svg" : (isActive ? "/InstrumentValueIcons/share-alt.svg" : "/InstrumentValueIcons/view-hide.svg"),
                "color": inMission ? "#AEA0D5" : (isActive ? "#AEA0D5" : "#7E8792")
            }
        ]
    }
    function _networkGpsSatelliteCount(vehicle) {
        if (!vehicle || !vehicle.gps || !vehicle.gps.count || isNaN(Number(vehicle.gps.count.rawValue))) { return NaN }
        return Number(vehicle.gps.count.rawValue)
    }
    function _networkGpsHdop(vehicle) {
        if (!vehicle || !vehicle.gps || !vehicle.gps.hdop || isNaN(Number(vehicle.gps.hdop.rawValue))) { return NaN }
        return Number(vehicle.gps.hdop.rawValue)
    }
    function _networkGpsLock(vehicle) {
        if (!vehicle || !vehicle.gps || !vehicle.gps.lock || isNaN(Number(vehicle.gps.lock.rawValue))) { return NaN }
        return Number(vehicle.gps.lock.rawValue)
    }
    function _networkTelemetryRssiToPercent(rawRssi) {
        const numeric = Number(rawRssi)
        if (isNaN(numeric)) { return NaN }
        if (numeric <= -30 && numeric >= -120) {
            return Math.max(0, Math.min(100, Math.round(((numeric + 120) / 90) * 100)))
        }
        if (numeric <= 0 || numeric >= 255) { return NaN }
        if (numeric <= 100) { return numeric }
        return Math.max(0, Math.min(100, Math.round((numeric / 254) * 100)))
    }
    function _networkGpsPercent(vehicle) {
        const lock = _networkGpsLock(vehicle)
        const satellites = _networkGpsSatelliteCount(vehicle)
        const hdop = _networkGpsHdop(vehicle)
        if (isNaN(lock) && isNaN(satellites) && isNaN(hdop)) { return NaN }

        let lockScore = 10
        if (!isNaN(lock)) {
            if (lock >= 3) {
                lockScore = 100
            } else if (lock === 2) {
                lockScore = 50
            } else if (lock === 1) {
                lockScore = 25
            } else {
                lockScore = 8
            }
        }

        let satelliteScore = lockScore
        if (!isNaN(satellites)) {
            if (satellites >= 14) {
                satelliteScore = 100
            } else if (satellites >= 10) {
                satelliteScore = 86
            } else if (satellites >= 7) {
                satelliteScore = 68
            } else if (satellites >= 5) {
                satelliteScore = 48
            } else if (satellites > 0) {
                satelliteScore = 24
            } else {
                satelliteScore = 0
            }
        }

        let hdopScore = satelliteScore
        if (!isNaN(hdop)) {
            if (hdop <= 0.8) {
                hdopScore = 100
            } else if (hdop <= 1.5) {
                hdopScore = 90
            } else if (hdop <= 2.5) {
                hdopScore = 70
            } else if (hdop <= 4.0) {
                hdopScore = 46
            } else if (hdop <= 8.0) {
                hdopScore = 22
            } else {
                hdopScore = 8
            }
        }

        return Math.max(0, Math.min(100, Math.round((lockScore * 0.35) + (satelliteScore * 0.35) + (hdopScore * 0.30))))
    }
    function _networkRcPercent(vehicle) {
        if (!vehicle || vehicle.rcRSSI === undefined || vehicle.rcRSSI === null) { return NaN }
        const numeric = Number(vehicle.rcRSSI)
        if (isNaN(numeric) || numeric <= 0 || numeric > 100) { return NaN }
        return numeric
    }
    function _networkTelemetryPercent(vehicle) {
        if (!vehicle) { return NaN }
        const localPercent = _networkTelemetryRssiToPercent(vehicle.telemetryLRSSI)
        const remotePercent = _networkTelemetryRssiToPercent(vehicle.telemetryRRSSI)
        const hasLocal = !isNaN(localPercent)
        const hasRemote = !isNaN(remotePercent)
        if (!hasLocal && !hasRemote) { return NaN }

        let percent = hasLocal && hasRemote
            ? ((localPercent + remotePercent) / 2)
            : (hasLocal ? localPercent : remotePercent)

        const lossPercent = vehicle.mavlinkLossPercent !== undefined ? Number(vehicle.mavlinkLossPercent) : NaN
        if (!isNaN(lossPercent) && lossPercent > 0) {
            percent = Math.max(0, percent - Math.min(lossPercent * 2, 45))
        }

        return Math.round(percent)
    }
    function _networkStatusText(percent) {
        if (isNaN(percent) || percent <= 0) { return qsTr("No Link") }
        if (percent >= 75) { return qsTr("Good") }
        if (percent >= 50) { return qsTr("Fair") }
        if (percent >= 25) { return qsTr("Weak") }
        return qsTr("Poor")
    }
    function _networkStatusColor(percent) {
        if (isNaN(percent) || percent <= 0) { return "#6A7078" }
        if (percent >= 75) { return "#00BE8A" }
        if (percent >= 50) { return "#65D4A7" }
        if (percent >= 25) { return "#D6A566" }
        return "#C66D72"
    }
    function _networkSignalIcon(percent) {
        if (isNaN(percent) || percent < 20) { return "/qmlimages/Signal0.svg" }
        if (percent < 40) { return "/qmlimages/Signal20.svg" }
        if (percent < 60) { return "/qmlimages/Signal40.svg" }
        if (percent < 80) { return "/qmlimages/Signal60.svg" }
        if (percent < 95) { return "/qmlimages/Signal80.svg" }
        return "/qmlimages/Signal100.svg"
    }
    function _networkSatelliteText(vehicle) {
        const satellites = _networkGpsSatelliteCount(vehicle)
        return isNaN(satellites) ? "--" : ("" + Math.round(satellites))
    }
    function _networkHdopText(vehicle) {
        const hdop = _networkGpsHdop(vehicle)
        return isNaN(hdop) ? "--" : hdop.toFixed(1)
    }
    function _communicationTelemetryRssiDbm(vehicle) {
        if (!vehicle) { return -65 }

        const rssiCandidates = [Number(vehicle.telemetryLRSSI), Number(vehicle.telemetryRRSSI)]
        const converted = []

        for (let i = 0; i < rssiCandidates.length; i++) {
            const rawValue = Number(rssiCandidates[i])
            if (isNaN(rawValue) || rawValue === 0) {
                continue
            }
            if (rawValue <= -30 && rawValue >= -120) {
                converted.push(rawValue)
                continue
            }
            if (rawValue > 0 && rawValue <= 254) {
                converted.push(-120 + ((rawValue / 254) * 90))
            }
        }

        if (converted.length === 0) {
            return -65
        }

        let total = 0
        for (let i = 0; i < converted.length; i++) {
            total += Number(converted[i])
        }
        return Math.round(total / converted.length)
    }
    function _communicationTelemetryLossPercent(vehicle) {
        if (!vehicle) { return 0 }

        const mavlinkLoss = Number(vehicle.mavlinkLossPercent)
        if (!isNaN(mavlinkLoss)) {
            return Math.max(0, Math.min(100, Math.round(mavlinkLoss)))
        }

        const received = Number(vehicle.messagesReceived)
        const lost = Number(vehicle.messagesLost)
        const total = received + lost
        if (!isNaN(total) && total > 0 && !isNaN(lost)) {
            return Math.max(0, Math.min(100, Math.round((lost / total) * 100)))
        }

        return 0
    }
    function _communicationTelemetryQualityPercent(vehicle) {
        if (!vehicle) {
            return 100
        }

        const telemetryPercent = _networkTelemetryPercent(vehicle)
        if (!isNaN(telemetryPercent)) {
            return Math.max(0, Math.min(100, Math.round(telemetryPercent)))
        }

        const rssiDbm = _communicationTelemetryRssiDbm(vehicle)
        if (!isNaN(rssiDbm)) {
            return Math.max(0, Math.min(100, Math.round(((rssiDbm + 120) / 90) * 100)))
        }

        return 100
    }
    function _communicationStatusColor(percent) {
        if (isNaN(percent) || percent < 0) { return "#6A7078" }
        if (percent >= 90) { return "#00C7A4" }
        if (percent >= 75) { return "#00BE8A" }
        if (percent >= 55) { return "#65D4A7" }
        if (percent >= 35) { return "#D6A566" }
        return "#C66D72"
    }
    function _communicationTelemetryStatusText(percent) {
        if (isNaN(percent)) { return qsTr("Good") }
        if (percent >= 75) { return qsTr("Good") }
        if (percent >= 55) { return qsTr("Fair") }
        if (percent >= 35) { return qsTr("Weak") }
        return qsTr("Poor")
    }
    function _communicationVideoStreamInfo(vehicle) {
        const cameraManager = vehicle ? vehicle.cameraManager : null
        const camera = cameraManager ? cameraManager.currentCameraInstance : null
        return camera ? camera.currentStreamInstance : null
    }
    function _communicationVideoBitrateMbps(vehicle) {
        if (!vehicle) { return 4.2 }

        const streamInfo = _communicationVideoStreamInfo(vehicle)
        const bitrateBits = streamInfo && streamInfo.bitrate !== undefined ? Number(streamInfo.bitrate) : NaN
        if (!isNaN(bitrateBits) && bitrateBits > 0) {
            return Math.round(((bitrateBits / 1000000) * 10)) / 10
        }

        const telemetryQuality = _communicationTelemetryQualityPercent(vehicle)
        if (isNaN(telemetryQuality)) {
            return 4.2
        }

        const estimated = 1.4 + (telemetryQuality * 0.028)
        return Math.round((Math.max(0.8, Math.min(9.5, estimated)) * 10)) / 10
    }
    function _communicationVideoLatencyMs(vehicle) {
        if (!vehicle) { return 110 }

        const telemetryQuality = _communicationTelemetryQualityPercent(vehicle)
        const lossPercent = Number(vehicle.mavlinkLossPercent)
        const rxErrors = Number(vehicle.telemetryRXErrors)
        let estimate = 92

        estimate += isNaN(telemetryQuality) ? 18 : ((100 - telemetryQuality) * 0.45)
        if (!isNaN(lossPercent)) {
            estimate += Math.min(120, Math.max(0, lossPercent) * 1.8)
        }
        if (!isNaN(rxErrors) && rxErrors > 0) {
            estimate += Math.min(70, Math.log(rxErrors + 1) * 9)
        }
        if (QGroundControl.videoManager && !QGroundControl.videoManager.hasVideo) {
            estimate += 8
        }

        return Math.round(Math.max(70, Math.min(360, estimate)))
    }
    function _communicationVideoFps(vehicle) {
        if (!vehicle) { return 25 }

        const streamInfo = _communicationVideoStreamInfo(vehicle)
        const framerate = streamInfo && streamInfo.framerate !== undefined ? Number(streamInfo.framerate) : NaN
        if (!isNaN(framerate) && framerate > 0) {
            return Math.round(Math.max(1, framerate))
        }

        const bitrate = _communicationVideoBitrateMbps(vehicle)
        if (isNaN(bitrate)) { return 25 }

        return Math.round(Math.max(8, Math.min(60, 16 + (bitrate * 2.2))))
    }
    function _communicationVideoQualityPercent(vehicle, bitrateMbps = NaN, fps = NaN, latencyMs = NaN) {
        if (!vehicle) { return 98 }

        const bitrate = isNaN(Number(bitrateMbps)) ? _communicationVideoBitrateMbps(vehicle) : Number(bitrateMbps)
        const frameRate = isNaN(Number(fps)) ? _communicationVideoFps(vehicle) : Number(fps)
        const latency = isNaN(Number(latencyMs)) ? _communicationVideoLatencyMs(vehicle) : Number(latencyMs)
        const loss = _communicationTelemetryLossPercent(vehicle)
        const telemetryQuality = _communicationTelemetryQualityPercent(vehicle)

        let score = 82
        score += (Math.max(0.8, Math.min(10, bitrate)) - 2.5) * 6
        score += (Math.max(8, Math.min(60, frameRate)) - 20) * 1.6
        score -= Math.max(0, latency - 90) * 0.45
        score -= Math.max(0, loss) * 1.5
        score = (score * 0.72) + (telemetryQuality * 0.28)

        return Math.round(Math.max(0, Math.min(100, score)))
    }
    function _communicationVideoStatusText(percent) {
        if (isNaN(percent)) { return qsTr("Excellent") }
        if (percent >= 90) { return qsTr("Excellent") }
        if (percent >= 75) { return qsTr("Good") }
        if (percent >= 55) { return qsTr("Fair") }
        return qsTr("Weak")
    }
    function _communicationMeshTotalNodes() {
        const vehicles = QGroundControl.multiVehicleManager.vehicles
        if (!vehicles || vehicles.count <= 0) { return 5 }
        return vehicles.count
    }
    function _communicationMeshOnlineNodes() {
        const vehicles = QGroundControl.multiVehicleManager.vehicles
        if (!vehicles || vehicles.count <= 0) { return 5 }

        let online = 0
        for (let i = 0; i < vehicles.count; i++) {
            const vehicle = vehicles.get(i)
            if (!vehicle) { continue }
            const telemetryQuality = _communicationTelemetryQualityPercent(vehicle)
            const communicationHealthy = (vehicle.communicationLost !== undefined) ? !vehicle.communicationLost : true
            if (communicationHealthy || (!isNaN(telemetryQuality) && telemetryQuality > 30)) {
                online++
            }
        }

        return Math.max(0, Math.min(vehicles.count, online))
    }
    function _communicationMeshLinkQualityPercent() {
        const vehicles = QGroundControl.multiVehicleManager.vehicles
        if (!vehicles || vehicles.count <= 0) { return 98 }

        let totalQuality = 0
        for (let i = 0; i < vehicles.count; i++) {
            const vehicle = vehicles.get(i)
            if (!vehicle) {
                continue
            }

            let quality = _communicationTelemetryQualityPercent(vehicle)
            if (isNaN(quality)) {
                quality = vehicle.communicationLost ? 45 : 88
            }

            totalQuality += Math.max(0, Math.min(100, quality))
        }

        const averageQuality = totalQuality / Math.max(1, vehicles.count)
        const onlineNodes = _communicationMeshOnlineNodes()
        const totalNodes = _communicationMeshTotalNodes()
        const coverage = Math.max(0, Math.min(1, onlineNodes / Math.max(totalNodes, 1)))
        const score = (averageQuality * 0.82) + ((coverage * 100) * 0.18)
        return Math.round(Math.max(0, Math.min(100, score)))
    }
    function _communicationMeshStatusText(percent, onlineNodes, totalNodes) {
        if (totalNodes <= 0) { return qsTr("Stable") }
        if (onlineNodes <= 0) { return qsTr("Down") }
        if (percent >= 90 && onlineNodes === totalNodes) { return qsTr("Stable") }
        if (percent >= 75 && onlineNodes >= Math.max(1, totalNodes - 1)) { return qsTr("Stable") }
        if (percent >= 55) { return qsTr("Degraded") }
        return qsTr("Unstable")
    }
    function _clampPercent(value) {
        const numeric = Number(value)
        if (isNaN(numeric)) { return NaN }
        return Math.max(0, Math.min(100, numeric))
    }
    function _sensorCpuLoadPercent(vehicle) {
        if (!vehicle) { return 15 }

        const txBuffer = vehicle.telemetryTXBuffer !== undefined ? _clampPercent(vehicle.telemetryTXBuffer) : NaN
        const lossPercent = vehicle.mavlinkLossPercent !== undefined ? _clampPercent(vehicle.mavlinkLossPercent) : NaN
        const rxErrors = vehicle.telemetryRXErrors !== undefined ? Number(vehicle.telemetryRXErrors) : NaN
        let estimate = 15

        if (!isNaN(txBuffer)) {
            estimate = 15 + ((100 - txBuffer) * 0.45)
        }
        if (!isNaN(lossPercent)) {
            estimate += Math.min(22, lossPercent * 0.7)
        }
        if (!isNaN(rxErrors) && rxErrors > 0) {
            estimate += Math.min(10, Math.log(rxErrors + 1) * 2)
        }

        return Math.round(Math.max(5, Math.min(95, estimate)))
    }
    function _sensorLogActive(vehicle) {
        if (!vehicle) { return false }
        const received = Number(vehicle.messagesReceived)
        const lossPercent = vehicle.mavlinkLossPercent !== undefined ? Number(vehicle.mavlinkLossPercent) : NaN
        return !isNaN(received) && received > 0 && (isNaN(lossPercent) || lossPercent < 80)
    }
    function _sensorBitEnabled(vehicle, sensorBit) {
        return !!(vehicle && (Number(vehicle.sensorsEnabledBits) & sensorBit))
    }
    function _sensorBitUnhealthy(vehicle, sensorBit) {
        return !!(vehicle && (Number(vehicle.sensorsUnhealthyBits) & sensorBit))
    }
    function _sensorBitHealthy(vehicle, sensorBit) {
        return _sensorBitEnabled(vehicle, sensorBit) && !_sensorBitUnhealthy(vehicle, sensorBit)
    }
    function _sensorStatusTextForBit(vehicle, sensorBit, healthyText, unhealthyText, disabledText = qsTr("Offline")) {
        if (!_sensorBitEnabled(vehicle, sensorBit)) {
            return disabledText
        }
        return _sensorBitUnhealthy(vehicle, sensorBit) ? unhealthyText : healthyText
    }
    function _sensorGpsSatelliteText(vehicle) {
        const satellites = _networkGpsSatelliteCount(vehicle)
        return isNaN(satellites) ? "10" : ("" + Math.round(satellites))
    }
    function _sensorHealthNominal(vehicle) {
        if (!vehicle) { return false }
        return !!vehicle.allSensorsHealthy && Number(vehicle.sensorsUnhealthyBits) === 0
    }
    function _vehicleConfigComponentByKeywords(keywords, vehicle = _activeVehicle) {
        const autopilotPlugin = vehicle ? vehicle.autopilotPlugin : null
        if (!autopilotPlugin || !keywords || keywords.length === 0) { return null }

        const components = autopilotPlugin.vehicleComponents
        for (let i = 0; i < components.length; i++) {
            const component = components[i]
            if (!component) { continue }

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
    function _vehicleSetupTuningComponent(vehicle = _activeVehicle) { return _vehicleConfigComponentByKeywords(["tuning", "pid"], vehicle) }
    function _vehicleSetupSensorComponent(vehicle = _activeVehicle) {
        const autopilotPlugin = vehicle ? vehicle.autopilotPlugin : null
        if (!autopilotPlugin) { return null }

        if (typeof autopilotPlugin.findKnownVehicleComponent === "function") {
            const sensorComponent = autopilotPlugin.findKnownVehicleComponent(AutoPilotPlugin.KnownSensorsVehicleComponent)
            if (sensorComponent) {
                return sensorComponent
            }
        }

        return _vehicleConfigComponentByKeywords(["sensor", "calibration"], vehicle)
    }
    function _vehicleSetupFirmwareAvailable() {
        return !!(!ScreenTools.isMobile &&
                  QGroundControl.corePlugin &&
                  QGroundControl.corePlugin.options &&
                  QGroundControl.corePlugin.options.showFirmwareUpgrade)
    }
    function _openVehicleSetupHome() {
        if (typeof mainWindow !== "undefined" && mainWindow && typeof mainWindow.showVehicleConfig === "function") {
            mainWindow.showVehicleConfig()
        }
    }
    function _openVehicleSetupTuning() {
        if (!_activeVehicle || !_vehicleSetupTuningComponent(_activeVehicle)) { return }
        if (typeof mainWindow !== "undefined" && mainWindow && typeof mainWindow.showVehicleConfigTuningPage === "function") {
            mainWindow.showVehicleConfigTuningPage()
        } else {
            _openVehicleSetupHome()
        }
    }
    function _openVehicleSetupSensors() {
        if (!_activeVehicle || _activeVehicle.armed || !_vehicleSetupSensorComponent(_activeVehicle)) { return }
        if (typeof mainWindow !== "undefined" && mainWindow && typeof mainWindow.showVehicleConfigSensorsPage === "function") {
            mainWindow.showVehicleConfigSensorsPage()
        } else if (typeof mainWindow !== "undefined" && mainWindow && typeof mainWindow.showKnownVehicleComponentConfigPage === "function") {
            mainWindow.showKnownVehicleComponentConfigPage(AutoPilotPlugin.KnownSensorsVehicleComponent)
        } else {
            _openVehicleSetupHome()
        }
    }
    function _openVehicleSetupFirmware() {
        if (!_vehicleSetupFirmwareAvailable() || (_activeVehicle && _activeVehicle.armed)) { return }
        if (typeof mainWindow !== "undefined" && mainWindow && typeof mainWindow.showVehicleConfigFirmwarePage === "function") {
            mainWindow.showVehicleConfigFirmwarePage()
        } else {
            _openVehicleSetupHome()
        }
    }
    function _openCommunicationLinkSettings() {
        if (typeof mainWindow !== "undefined" && mainWindow && typeof mainWindow.showSettingsTool === "function") {
            mainWindow.showSettingsTool(qsTr("Comm Links"))
        }
    }
    function _openClusterWorkspaceWindow() {
        if (root._clusterWorkspaceWindow) {
            root._clusterWorkspaceWindow.show()
            root._clusterWorkspaceWindow.raise()
            root._clusterWorkspaceWindow.requestActivate()
            return
        }

        if (typeof mainWindow === "undefined" || !mainWindow) {
            return
        }

        root._clusterWorkspaceWindow = clusterWorkspaceWindowComponent.createObject(null, {
            transientParent: mainWindow,
            visible: false
        })

        if (!root._clusterWorkspaceWindow) {
            console.warn("Failed to create swarm workspace window")
            if (mainWindow.showMessageDialog) {
                mainWindow.showMessageDialog(qsTr("Swarm"), qsTr("Failed to create the swarm workspace window."))
            }
            return
        }

        if (root._clusterWorkspaceWindow.width <= 0) {
            root._clusterWorkspaceWindow.width = ScreenTools.defaultFontPixelWidth * 110
        }
        if (root._clusterWorkspaceWindow.height <= 0) {
            root._clusterWorkspaceWindow.height = ScreenTools.defaultFontPixelHeight * 48
        }

        root._clusterWorkspaceWindow.closing.connect(function() {
            root._clusterWorkspaceWindow = null
        })

        root._clusterWorkspaceWindow.visible = true
        root._clusterWorkspaceWindow.raise()
        root._clusterWorkspaceWindow.requestActivate()
    }
    function _vehicleSetupTuningStatusText() {
        if (!_activeVehicle) { return qsTr("Connect a vehicle to tune") }
        if (!_vehicleSetupTuningComponent(_activeVehicle)) { return qsTr("Unavailable on this vehicle") }
        return qsTr("Ready")
    }
    function _vehicleSetupSensorStatusText() {
        if (!_activeVehicle) { return qsTr("Connect a vehicle to calibrate") }
        if (!_vehicleSetupSensorComponent(_activeVehicle)) { return qsTr("Sensor setup unavailable") }
        if (_activeVehicle.armed) { return qsTr("Disarm to calibrate") }
        return _vehicleSetupSensorComponent(_activeVehicle).setupComplete ? qsTr("Calibrated") : qsTr("Calibration required")
    }
    function _vehicleSetupFirmwareStatusText() {
        if (!_vehicleSetupFirmwareAvailable()) { return qsTr("Firmware update unavailable") }
        if (_activeVehicle && _activeVehicle.armed) { return qsTr("Disarm before update") }
        return qsTr("Ready")
    }
    function _normalizeSearchText(value) {
        return value === undefined || value === null ? "" : ("" + value).toLowerCase().trim()
    }
    function _vehicleSearchTokens(vehicle) {
        if (!vehicle) { return [] }

        const rawTokens = [
            _vehicleTitle(vehicle),
            "vehicle " + vehicle.id,
            "vehicle" + vehicle.id,
            "" + vehicle.id,
            vehicle.flightMode,
            vehicle.vehicleName,
            vehicle.name,
            vehicle.callsign,
            vehicle.displayName,
            vehicle.objectName,
            vehicle.armed ? qsTr("armed") : qsTr("disarmed"),
            vehicle.flying ? qsTr("flying") : qsTr("standby")
        ]

        const tokens = []
        for (let i = 0; i < rawTokens.length; i++) {
            const normalized = _normalizeSearchText(rawTokens[i])
            if (normalized !== "" && tokens.indexOf(normalized) === -1) {
                tokens.push(normalized)
            }
        }
        return tokens
    }
    function _matchingVehicleCount() {
        const vehicles = QGroundControl.multiVehicleManager.vehicles
        let count = 0
        for (let i = 0; i < vehicles.count; i++) {
            if (_searchMatch(vehicles.get(i))) {
                count++
            }
        }
        return count
    }
    function _tokenMatch(token, query) {
        if (!token || !query) { return false }
        if (token.indexOf(query) !== -1) { return true }
        let qi = 0
        for (let ti = 0; ti < token.length && qi < query.length; ti++) {
            if (token[ti] === query[qi]) { qi++ }
        }
        return qi === query.length
    }
    function _searchMatch(vehicle) {
        const query = _normalizeSearchText(_vehicleSearchText)
        if (!vehicle) { return false }
        if (query === "") { return true }
        const tokens = _vehicleSearchTokens(vehicle)
        const parts = query.split(/\s+/)
        for (let i = 0; i < parts.length; i++) {
            let matched = false
            for (let j = 0; j < tokens.length; j++) {
                if (_tokenMatch(tokens[j], parts[i])) { matched = true; break }
            }
            if (!matched) { return false }
        }
        return true
    }
    function _popupMenuInLeftPane(menu, anchorItem, minWidth = 0) {
        if (!menu || !anchorItem) {
            return
        }

        const anchorTop = anchorItem.mapToItem(root, 0, 0)
        const anchorBottom = anchorItem.mapToItem(root, 0, anchorItem.height)
        const contentWidth = menu.contentItem ? Number(menu.contentItem.implicitWidth) : 0
        const contentHeight = menu.contentItem ? Number(menu.contentItem.implicitHeight) : 0
        const desiredWidth = Math.max(
            Number(minWidth),
            Number(menu.implicitWidth),
            contentWidth + (ScreenTools.defaultFontPixelWidth * 2.5),
            ScreenTools.defaultFontPixelWidth * 8
        )
        const popupHeight = Math.max(
            Number(menu.implicitHeight),
            contentHeight + (ScreenTools.defaultFontPixelHeight * 1.2),
            ScreenTools.defaultFontPixelHeight * 3
        )
        const edgePadding = Math.max(root._margin * 0.25, ScreenTools.defaultFontPixelWidth * 0.2)
        const topGap = ScreenTools.defaultFontPixelHeight * 0.08

        menu.width = desiredWidth

        const minX = edgePadding
        const maxX = Math.max(minX, leftPane.width - desiredWidth - edgePadding)
        const popupX = Math.max(minX, Math.min(anchorTop.x, maxX))

        const belowY = anchorBottom.y + topGap
        const maxBelowY = root.height - popupHeight - edgePadding
        let popupY = belowY
        if (popupY > maxBelowY) {
            popupY = Math.max(edgePadding, anchorTop.y - popupHeight - topGap)
        }

        menu.popup(popupX, popupY)
    }
    function dropMainStatusIndicatorTool() {}

    QGCPalette { id: qgcPal; colorGroupEnabled: true }
    PlanMasterController { id: planControllerInternal; flyView: true; Component.onCompleted: start() }

    QGCToolInsets {
        id: toolInsets
        leftEdgeCenterInset: floatingMapStrip.width + (root._margin * 2)
        leftEdgeTopInset: root._margin
        leftEdgeBottomInset: root._margin
        rightEdgeTopInset: uavVideoOverlay.width + (root._margin * 2)
        rightEdgeCenterInset: root._margin
        rightEdgeBottomInset: root._margin
        topEdgeLeftInset: root._margin
        topEdgeCenterInset: root._margin
        topEdgeRightInset: root._margin
        bottomEdgeLeftInset: root._margin
        bottomEdgeCenterInset: root._margin
        bottomEdgeRightInset: root._margin
    }

    GuidedValueSlider { id: guidedValueSlider; anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.right: parent.right; visible: false; z: QGroundControl.zOrderTopMost }
    GuidedActionsController { id: guidedActionsController; guidedValueSlider: guidedValueSlider; missionController: planControllerInternal.missionController }
    FlyViewMissionCompleteDialog { geoFenceController: planControllerInternal.geoFenceController; missionController: planControllerInternal.missionController; rallyPointController: planControllerInternal.rallyPointController }
    FlyViewPreFlightChecklistPopup { id: preFlightChecklistPopup }

    Component {
        id: clusterWorkspaceWindowComponent

        Myswarm { }
    }

    Connections {
        target: guidedActionsController
        function onShowStartMissionChanged() {
            if (!guidedActionsController.showStartMission) {
                if (root._startMissionSliderVisible) {
                    root._showStartMissionUnavailableDialog()
                }
                root._hideStartMissionSlider()
            }
        }
    }

    Timer {
        id: startMissionFeedbackTimer
        interval: 2600
        repeat: false
        onTriggered: root._hideStartMissionFeedback()
    }

    Timer {
        id: profilePlaybackTimer
        interval: 250
        repeat: true
        running: root._profilePlaybackActive && root._profilePanelExpanded
        onTriggered: {
            root._profileProgress = Math.min(1, root._profileProgress + (0.006 * root._profilePlaybackSpeed))
            if (root._profileProgress >= 1) {
                root._profilePlaybackActive = false
            }
        }
    }

    Timer {
        id: profileRefreshTimer
        interval: 1200
        repeat: true
        running: true
        onTriggered: root._profileMissionPoints = root._buildMissionProfilePoints()
    }

    Connections {
        target: planControllerInternal.missionController
        ignoreUnknownSignals: true
        function onVisualItemsChanged() { root._profileMissionPoints = root._buildMissionProfilePoints() }
        function onNewItemsFromVehicle() { root._profileMissionPoints = root._buildMissionProfilePoints() }
        function onCurrentMissionIndexChanged() { root._profileMissionPoints = root._buildMissionProfilePoints() }
    }

    QGCMenu {
        id: vehicleMenu
        Instantiator {
            model: QGroundControl.multiVehicleManager.vehicles
            delegate: QGCMenuItem { required property var object; text: root._vehicleTitle(object); onTriggered: root._setActiveVehicle(object) }
            onObjectAdded: (index, object) => vehicleMenu.insertItem(index, object)
            onObjectRemoved: (index, object) => vehicleMenu.removeItem(object)
        }
    }

    QGCMenu {
        id: vehicleIconMenu

        Instantiator {
            model: root._vehicleStatusIconOptions

            delegate: QGCMenuItem {
                required property var modelData

                onTriggered: root._setVehicleStatusIcon(modelData.source)

                contentItem: RowLayout {
                    spacing: ScreenTools.defaultFontPixelWidth * 0.28

                    QGCColoredImage {
                        Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.72
                        Layout.preferredHeight: Layout.preferredWidth
                        color: "#FFFFFF"
                        fillMode: Image.PreserveAspectFit
                        source: modelData.source
                    }

                    QGCLabel {
                        Layout.fillWidth: true
                        color: "#000000"
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.66
                        text: modelData.label
                    }

                    QGCColoredImage {
                        Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.46
                        Layout.preferredHeight: Layout.preferredWidth
                        color: "#53B84F"
                        fillMode: Image.PreserveAspectFit
                        source: "/InstrumentValueIcons/checkmark.svg"
                        visible: root._vehicleStatusIcon(root._activeVehicle) === modelData.source
                    }
                }
            }

            onObjectAdded: (index, object) => vehicleIconMenu.insertItem(index, object)
            onObjectRemoved: (index, object) => vehicleIconMenu.removeItem(object)
        }
    }

    QGCMenu {
        id: flightModeMenu
        Instantiator {
            model: root._activeVehicle && root._activeVehicle.flightModeSetAvailable ? root._activeVehicle.flightModes : []
            delegate: QGCMenuItem { required property var modelData; text: modelData; onTriggered: root._activeVehicle.flightMode = modelData }
            onObjectAdded: (index, object) => flightModeMenu.insertItem(index, object)
            onObjectRemoved: (index, object) => flightModeMenu.removeItem(object)
        }
    }

    Item {
        anchors.fill: parent

        Rectangle {
            id: leftPane
            x: 0
            y: 0
            width: {
                const parentWidth = Number(parent ? parent.width : 0)
                if (isNaN(parentWidth) || parentWidth <= 0) {
                    return root._leftPaneWidth
                }
                const maxAllowedWidth = Math.max(root._leftPaneMinWidth, parentWidth - root._margin - root._rightPaneMinWidth)
                return Math.max(root._leftPaneMinWidth, Math.min(root._leftPaneWidth, maxAllowedWidth))
            }
            height: parent ? parent.height : 0
            color: qgcPal.windowShadeDark
            radius: 0

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 0
                anchors.rightMargin: root._margin * 0.6
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.4
                    color: qgcPal.windowShade
                    radius: 0

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: root._margin * 0.55
                        spacing: ScreenTools.defaultFontPixelWidth * 0.34

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.rightMargin: ScreenTools.defaultFontPixelWidth * 0.18
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.42
                            Layout.alignment: Qt.AlignVCenter
                            color: qgcPal.windowShadeDark
                            radius: ScreenTools.defaultFontPixelHeight * 0.12

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.14
                                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.18
                                spacing: ScreenTools.defaultFontPixelWidth * 0.12

                                QGCColoredImage {
                                    Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.58
                                    Layout.preferredHeight: Layout.preferredWidth
                                    Layout.leftMargin: Math.round(ScreenTools.realPixelDensity)
                                    color: "#FFFFFF"
                                    fillMode: Image.PreserveAspectFit
                                    source: "/InstrumentValueIcons/search.svg"
                                }
                                TextField {
                                    Layout.fillWidth: true
                                    color: text.length > 0 ? "#FFFFFF" : qgcPal.text
                                    placeholderText: qsTr("Search...")
                                    placeholderTextColor: qgcPal.windowShadeLight
                                    text: root._vehicleSearchText
                                    verticalAlignment: TextInput.AlignVCenter
                                    background: Item {}
                                    onTextEdited: root._vehicleSearchText = text
                                }
                            }
                        }

                        Repeater {
                            model: ["/InstrumentValueIcons/filter.svg", "/InstrumentValueIcons/add-outline.svg"]
                            delegate: Rectangle {
                                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 1.42
                                Layout.preferredHeight: Layout.preferredWidth
                                color: qgcPal.windowShadeDark
                                radius: ScreenTools.defaultFontPixelHeight * 0.12
                                QGCColoredImage { anchors.centerIn: parent; width: parent.height * 0.42; height: width; color: "#FFFFFF"; fillMode: Image.PreserveAspectFit; source: modelData }
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: Math.max(ScreenTools.defaultFontPixelWidth * 5.2, ScreenTools.defaultFontPixelHeight * 3.4)
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.42
                            Layout.alignment: Qt.AlignVCenter
                            color: clusterWorkspaceButtonMouseArea.pressed
                                ? qgcPal.buttonHighlight
                                : (clusterWorkspaceButtonMouseArea.containsMouse ? qgcPal.button : qgcPal.windowShadeDark)
                            radius: ScreenTools.defaultFontPixelHeight * 0.12
                            border.width: 1
                            border.color: qgcPal.buttonBorder

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.18
                                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.18

                                QGCLabel {
                                    Layout.fillWidth: true
                                    color: clusterWorkspaceButtonMouseArea.pressed ? qgcPal.buttonHighlightText : "#FFFFFF"
                                    horizontalAlignment: Text.AlignHCenter
                                    text: qsTr("Swarm")
                                }
                            }

                            QGCMouseArea {
                                id: clusterWorkspaceButtonMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root._openClusterWorkspaceWindow()
                            }
                        }
                    }
                }

                QGCListView {
                    id: vehicleList
                    readonly property real _targetHeight: Math.max(
                        ScreenTools.defaultFontPixelHeight * 1.8,
                        Math.min(ScreenTools.defaultFontPixelHeight * 6.6, contentHeight))
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Layout.preferredHeight: _targetHeight
                    Layout.maximumHeight: _targetHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.VerticalFlick
                    model: QGroundControl.multiVehicleManager.vehicles
                    spacing: 0
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    delegate: Rectangle {
                        required property var object
                        required property int index
                        property var vehicleObject: object
                        property bool expanded: root._expandedClusterVehicleId === vehicleObject.id
                        property bool selected: vehicleObject === root._activeVehicle
                        property bool showRow: root._searchMatch(vehicleObject)
                        property real batteryPercent: root._batteryPercentForVehicle(vehicleObject)
                        property var statusIndicators: root._vehicleStatusIndicators(vehicleObject)
                        property int clusterGroupId: root._clusterGroup(vehicleObject)
                        property bool clusterLeader: root._clusterLeader(vehicleObject)
                        property bool clusterGroupAvailable: root._clusterParameterExists(vehicleObject, "SWARM_GROUP_ID")
                        property bool clusterLeaderAvailable: root._clusterParameterExists(vehicleObject, "SWARM_SET_LEADER")
                        property bool clusterActionsAvailable: clusterGroupAvailable || clusterLeaderAvailable
                        readonly property color _selectedCardColor: "#32363A"
                        readonly property color _expandedPanelColor: "#2A2D31"
                        readonly property color _clusterActionActiveColor: "#4A5159"
                        readonly property color _clusterActionIdleColor: qgcPal.windowShadeDark
                        readonly property color _clusterActionBorderColor: Qt.rgba(1, 1, 1, 0.10)
                        readonly property real _clusterIndent: ScreenTools.defaultFontPixelHeight * 0.42
                        visible: showRow
                        width: vehicleList.width
                        height: visible ? (expanded ? ScreenTools.defaultFontPixelHeight * 6.25 : ScreenTools.defaultFontPixelHeight * 1.65) : 0
                        color: selected ? _selectedCardColor : (index % 2 === 0 ? qgcPal.window : qgcPal.windowShade)
                        readonly property real _headerTapHeight: expanded
                            ? ScreenTools.defaultFontPixelHeight * 1.32
                            : height

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.08
                            anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.16
                            anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.06
                            anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.06
                            spacing: ScreenTools.defaultFontPixelHeight * 0.03

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: ScreenTools.defaultFontPixelWidth * 0.1
                                Rectangle {
                                    Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.9
                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 0.9
                                    color: "transparent"

                                    QGCLabel {
                                        anchors.centerIn: parent
                                        horizontalAlignment: Text.AlignHCenter
                                        color: "#FFFFFF"
                                        text: expanded ? "\u25BE" : "\u25B8"
                                    }

                                    QGCMouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            root._setActiveVehicle(vehicleObject)
                                            root._toggleClusterPanel(vehicleObject)
                                        }
                                    }
                                }
                                QGCColoredImage { Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.82; Layout.preferredHeight: Layout.preferredWidth; color: "#FFFFFF"; fillMode: Image.PreserveAspectFit; source: root._vehicleTypeIcon(vehicleObject) }
                                Item { Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 0.22 }
                                QGCLabel { Layout.fillWidth: true; color: "#FFFFFF"; elide: Text.ElideRight; font.weight: Font.DemiBold; text: root._vehicleTitle(vehicleObject) }

                                Repeater {
                                    model: statusIndicators

                                    delegate: QGCColoredImage {
                                                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.58
                                        Layout.preferredHeight: Layout.preferredWidth
                                        Layout.leftMargin: ScreenTools.defaultFontPixelWidth * 0.1
                                        color: modelData.color
                                        fillMode: Image.PreserveAspectFit
                                        source: modelData.icon
                                    }
                                }

                                Item { Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 0.12 }

                                Repeater {
                                    model: vehicleObject && vehicleObject.flying ? ["/InstrumentValueIcons/arrow-thin-up.svg", "/InstrumentValueIcons/pause-outline.svg"] : ["/InstrumentValueIcons/lock-closed.svg", "/InstrumentValueIcons/play-outline.svg"]
                                    delegate: Rectangle {
                                                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 1.34
                                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.02
                                        color: qgcPal.windowShadeDark
                                        radius: ScreenTools.defaultFontPixelHeight * 0.14
                                        QGCColoredImage { anchors.centerIn: parent; width: parent.height * 0.56; height: width; color: "#FFFFFF"; fillMode: Image.PreserveAspectFit; source: modelData }
                                    }
                                }
                            }
                            QGCLabel {
                                Layout.leftMargin: _clusterIndent
                                visible: expanded
                                color: "#FFFFFF"
                                opacity: 0.84
                                text: root._batteryTextForVehicle(vehicleObject)
                            }

                            Rectangle {
                                Layout.leftMargin: _clusterIndent
                                Layout.rightMargin: ScreenTools.defaultFontPixelWidth * 0.02
                                Layout.fillWidth: true
                                visible: expanded
                                color: _expandedPanelColor
                                radius: ScreenTools.defaultFontPixelHeight * 0.12
                                border.width: 1
                                border.color: _clusterActionBorderColor
                                implicitHeight: clusterPanelColumn.implicitHeight + (ScreenTools.defaultFontPixelHeight * 0.34)

                                ColumnLayout {
                                    id: clusterPanelColumn
                                    anchors.fill: parent
                                    anchors.margins: ScreenTools.defaultFontPixelHeight * 0.18
                                    spacing: ScreenTools.defaultFontPixelHeight * 0.1

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: ScreenTools.defaultFontPixelWidth * 0.18

                                        QGCLabel {
                                            Layout.fillWidth: true
                                            color: "#FFFFFF"
                                            font.weight: Font.DemiBold
                                            text: qsTr("Cluster")
                                        }

                                        QGCLabel {
                                            color: "#FFFFFF"
                                            text: clusterGroupId > 0 ? qsTr("Group %1").arg(clusterGroupId) : qsTr("Unassigned")
                                        }

                                        QGCLabel {
                                            color: "#FFFFFF"
                                            text: clusterLeader ? qsTr("Leader") : qsTr("Member")
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: ScreenTools.defaultFontPixelWidth * 0.18

                                        QGCLabel {
                                            color: "#FFFFFF"
                                            opacity: 0.78
                                            text: qsTr("Sync")
                                        }

                                        QGCLabel {
                                            color: "#FFFFFF"
                                            opacity: 0.78
                                            text: root._clusterSyncState(vehicleObject)
                                        }

                                        Item { Layout.fillWidth: true }

                                        QGCLabel {
                                            visible: !clusterActionsAvailable || root._clusterSyncState(vehicleObject) === qsTr("Waiting")
                                            color: "#FFFFFF"
                                            opacity: 0.56
                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.48
                                            text: clusterActionsAvailable ? qsTr("Read only") : qsTr("Unavailable")
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: ScreenTools.defaultFontPixelWidth * 0.18

                                        QGCLabel {
                                            color: "#FFFFFF"
                                            opacity: 0.62
                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.48
                                            text: qsTr("Group Param")
                                        }

                                        QGCLabel {
                                            Layout.fillWidth: true
                                            color: clusterGroupAvailable ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.42)
                                            opacity: 0.72
                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.48
                                            elide: Text.ElideRight
                                            text: clusterGroupAvailable ? qsTr("SWARM_GROUP_ID detected") : qsTr("SWARM_GROUP_ID missing")
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: ScreenTools.defaultFontPixelWidth * 0.18

                                        QGCLabel {
                                            color: "#FFFFFF"
                                            opacity: 0.62
                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.48
                                            text: qsTr("Leader Param")
                                        }

                                        QGCLabel {
                                            Layout.fillWidth: true
                                            color: clusterLeaderAvailable ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.42)
                                            opacity: 0.72
                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.48
                                            elide: Text.ElideRight
                                            text: clusterLeaderAvailable ? qsTr("SWARM_SET_LEADER detected") : qsTr("SWARM_SET_LEADER missing")
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: ScreenTools.defaultFontPixelWidth * 0.12
                                        visible: clusterGroupAvailable

                                        Repeater {
                                            model: [1, 2, 3, 4]

                                            delegate: Rectangle {
                                                required property int modelData
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 0.86
                                                color: clusterGroupId === modelData ? _clusterActionActiveColor : _clusterActionIdleColor
                                                radius: ScreenTools.defaultFontPixelHeight * 0.12
                                                border.width: 1
                                                border.color: clusterGroupAvailable ? _clusterActionBorderColor : Qt.rgba(1, 1, 1, 0.05)
                                                opacity: clusterGroupAvailable ? 1 : 0.22

                                                QGCLabel {
                                                    anchors.centerIn: parent
                                                    color: clusterGroupAvailable ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.42)
                                                    text: qsTr("G%1").arg(modelData)
                                                }

                                                QGCMouseArea {
                                                    anchors.fill: parent
                                                    enabled: clusterGroupAvailable
                                                    onClicked: root._setClusterGroup(vehicleObject, modelData)
                                                }
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: ScreenTools.defaultFontPixelWidth * 0.12
                                        visible: clusterGroupAvailable || clusterLeaderAvailable

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 0.86
                                            color: _clusterActionIdleColor
                                            radius: ScreenTools.defaultFontPixelHeight * 0.12
                                            border.width: 1
                                            border.color: clusterGroupAvailable && clusterGroupId > 0 ? _clusterActionBorderColor : Qt.rgba(1, 1, 1, 0.05)
                                            opacity: clusterGroupAvailable && clusterGroupId > 0 ? 1 : 0.22

                                            QGCLabel {
                                                anchors.centerIn: parent
                                                color: clusterGroupAvailable && clusterGroupId > 0 ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.42)
                                                text: qsTr("Clear")
                                            }

                                            QGCMouseArea {
                                                anchors.fill: parent
                                                enabled: clusterGroupAvailable && clusterGroupId > 0
                                                onClicked: root._clearClusterGroup(vehicleObject)
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 0.86
                                            color: clusterLeader ? _clusterActionActiveColor : _clusterActionIdleColor
                                            radius: ScreenTools.defaultFontPixelHeight * 0.12
                                            border.width: 1
                                            border.color: clusterLeaderAvailable && clusterGroupId > 0 ? _clusterActionBorderColor : Qt.rgba(1, 1, 1, 0.05)
                                            opacity: clusterLeaderAvailable && clusterGroupId > 0 ? 1 : 0.22

                                            QGCLabel {
                                                anchors.centerIn: parent
                                                color: clusterLeaderAvailable && clusterGroupId > 0 ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.42)
                                                text: clusterLeader ? qsTr("Unset Leader") : qsTr("Set Leader")
                                            }

                                            QGCMouseArea {
                                                anchors.fill: parent
                                                enabled: clusterLeaderAvailable && clusterGroupId > 0
                                                onClicked: root._setClusterLeader(vehicleObject, !clusterLeader)
                                            }
                                        }
                                    }

                                    QGCLabel {
                                        Layout.fillWidth: true
                                        visible: root._clusterFeedback(vehicleObject) !== "" || root._clusterSyncDetail(vehicleObject) !== "" || !clusterGroupAvailable
                                        color: "#FFFFFF"
                                        opacity: 0.78
                                        wrapMode: Text.WordWrap
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5
                                        text: root._clusterFeedback(vehicleObject) !== ""
                                            ? root._clusterFeedback(vehicleObject)
                                            : root._clusterSyncDetail(vehicleObject)
                                    }
                                }
                            }
                        }

                        QGCMouseArea {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: _headerTapHeight
                            onClicked: {
                                if (root._activeVehicle === vehicleObject) {
                                    root._toggleClusterPanel(vehicleObject)
                                } else {
                                    root._setActiveVehicle(vehicleObject)
                                }
                            }
                            onDoubleClicked: root._toggleClusterPanel(vehicleObject)
                        }

                        Connections {
                            target: vehicleObject ? vehicleObject.parameterManager : null
                            ignoreUnknownSignals: true

                            function on_ParamSetSuccess(componentId, paramName) {
                                root._handleClusterParamSetSuccess(vehicleObject, componentId, paramName)
                            }

                            function on_ParamSetFailure(componentId, paramName) {
                                root._handleClusterParamSetFailure(vehicleObject, componentId, paramName)
                            }

                            function onPendingWritesChanged(pendingWrites) {
                                root._handleClusterPendingWritesChanged(vehicleObject, pendingWrites)
                            }
                        }
                    }
                }

                QGCLabel {
                    Layout.fillWidth: true
                    Layout.leftMargin: ScreenTools.defaultFontPixelWidth * 0.7
                    Layout.rightMargin: ScreenTools.defaultFontPixelWidth * 0.7
                    Layout.topMargin: ScreenTools.defaultFontPixelHeight * 0.22
                    visible: root._vehicleSearchText.trim() !== "" && root._matchingVehicleCount() === 0
                    color: qgcPal.windowShadeLight
                    opacity: 0.9
                    wrapMode: Text.WordWrap
                    text: qsTr("No matching vehicles")
                }

                Item {
                    id: leftPaneGap
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 4.5
                }

                Rectangle {
                    id: vehicleStatusCard

                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Layout.preferredHeight: Math.max(
                        ScreenTools.defaultFontPixelHeight * 23.3,
                        Math.min(ScreenTools.defaultFontPixelHeight * 31.8, leftPane.height * 0.55))
                        + root._vehicleStatusExtraHeight
                    Layout.maximumHeight: Layout.preferredHeight
                    Layout.minimumHeight: (ScreenTools.defaultFontPixelHeight * 23.3) + root._vehicleStatusExtraHeight
                    color: "#1F1F1F"
                    radius: 8
                    border.width: 1
                    border.color: "#333333"
                    clip: true

                    readonly property color _railColor: "#1E1E1E"
                    readonly property color _contentColor: "#2D2D2D"
                    readonly property color _blockColor: "#2D2D2D"
                    readonly property color _fieldColor: "#252525"
                    readonly property color _highlightColor: "#2563EB"
                    readonly property color _highlightHoverColor: "#1D4ED8"
                    readonly property color _highlightPressedColor: "#1E40AF"
                    readonly property color _buttonSecondaryColor: "#333333"
                    readonly property color _buttonSecondaryHoverColor: "#3D3D3D"
                    readonly property color _buttonSecondaryPressedColor: "#292929"
                    readonly property color _textPrimaryColor: "#FFFFFF"
                    readonly property color _textSecondaryColor: "#B0B0B0"
                    readonly property color _textDisabledColor: "#666666"
                    readonly property color _controlBorderColor: "#333333"
                    readonly property real _controlBorderWidth: 1
                    readonly property real _controlRadius: 8
                    readonly property int _transitionDuration: 200
                    readonly property real _sectionHeaderHeight: ScreenTools.defaultFontPixelHeight * 1.16
                    readonly property real _sectionHeaderSpacing: ScreenTools.defaultFontPixelWidth * 0.16
                    readonly property real _sectionHeaderTitleSize: ScreenTools.defaultFontPixelHeight * 0.64
                    readonly property real _sectionHeaderButtonSize: ScreenTools.defaultFontPixelHeight * 0.96
                    readonly property real _sectionHeaderButtonRightMargin: ScreenTools.defaultFontPixelWidth * 0.06
                    readonly property real _sectionHeaderIconScale: 0.52
                    readonly property real _sectionContentLeftMargin: ScreenTools.defaultFontPixelHeight * 0.18
                    readonly property real _sectionContentRightMargin: ScreenTools.defaultFontPixelHeight * 0.18
                    readonly property real _sectionContentTopMargin: ScreenTools.defaultFontPixelHeight * 0.12
                    readonly property real _sectionContentBottomMargin: ScreenTools.defaultFontPixelHeight * 0.12
                    readonly property real _sectionContentSpacing: ScreenTools.defaultFontPixelHeight * 0.11
                    readonly property var _statusPages: [
                        { "icon": "/InstrumentValueIcons/dashboard.svg",    "title": qsTr("INSTRUMENTS") },
                        { "icon": "/InstrumentValueIcons/bolt.svg",         "title": qsTr("VEHICLE STATUS") },
                        { "icon": "/InstrumentValueIcons/news-paper.svg",   "title": qsTr("DOCS") },
                        { "icon": "/InstrumentValueIcons/radio.svg",        "title": qsTr("SIGNAL") },
                        { "icon": "/InstrumentValueIcons/cog.svg",          "title": qsTr("PARAMS") },
                        { "icon": "/InstrumentValueIcons/chart.svg",        "title": qsTr("LOGS") },
                        { "icon": "/InstrumentValueIcons/battery-full.svg", "title": qsTr("BATTERY") },
                        { "icon": "/InstrumentValueIcons/show-sidebar.svg", "title": qsTr("ATTITUDE") },
                        { "icon": "/InstrumentValueIcons/shield.svg",       "title": qsTr("SAFETY") },
                        { "icon": "/InstrumentValueIcons/volume-up.svg",    "title": qsTr("AUDIO") }
                    ]

                    RowLayout {
                        anchors.fill: parent
                        spacing: 0

                        Rectangle {
                            Layout.fillHeight: true
                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 3.95
                            color: vehicleStatusCard._railColor
                            border.width: vehicleStatusCard._controlBorderWidth
                            border.color: vehicleStatusCard._controlBorderColor
                            Repeater {
                                model: vehicleStatusCard._statusPages
                                delegate: Rectangle {
                                    required property var modelData
                                        required property int index
                                    readonly property bool _selected: root._vehicleStatusPageIndex === index
                                    width: parent.width
                                    height: ScreenTools.defaultFontPixelHeight * 1.88
                                    color: _selected
                                        ? (sideRailMouseArea.pressed
                                            ? vehicleStatusCard._highlightPressedColor
                                            : (sideRailMouseArea.containsMouse ? vehicleStatusCard._highlightHoverColor : vehicleStatusCard._highlightColor))
                                        : (sideRailMouseArea.pressed
                                            ? "#181818"
                                            : (sideRailMouseArea.containsMouse ? "#262626" : vehicleStatusCard._railColor))
                                    y: index * height
                                    border.width: vehicleStatusCard._controlBorderWidth
                                    border.color: vehicleStatusCard._controlBorderColor

                                    Behavior on color {
                                        ColorAnimation { duration: vehicleStatusCard._transitionDuration }
                                    }

                                    QGCColoredImage {
                                        anchors.centerIn: parent
                                        width: parent.height * 0.42
                                        height: width
                                        color: vehicleStatusCard._textPrimaryColor
                                        fillMode: Image.PreserveAspectFit
                                        source: modelData.icon
                                    }

                                    QGCMouseArea {
                                        id: sideRailMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: root._vehicleStatusPageIndex = index
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillHeight: true
                            Layout.fillWidth: true
                            color: vehicleStatusCard._contentColor
                            border.width: vehicleStatusCard._controlBorderWidth
                            border.color: vehicleStatusCard._controlBorderColor
                            clip: true

                            StackLayout {
                                clip: true
                                anchors.fill: parent
                                anchors.leftMargin: ScreenTools.defaultFontPixelHeight * 0.46
                                anchors.rightMargin: ScreenTools.defaultFontPixelHeight * 0.46
                                anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.46
                                anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.44
                                currentIndex: root._vehicleStatusPageIndex === 0
                                              ? 1
                                              : (root._vehicleStatusPageIndex === 1 ? 0 : root._vehicleStatusPageIndex)

                                Item {
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: vehicleStatusCard._sectionContentLeftMargin
                                        anchors.rightMargin: vehicleStatusCard._sectionContentRightMargin
                                        anchors.topMargin: vehicleStatusCard._sectionContentTopMargin
                                        anchors.bottomMargin: vehicleStatusCard._sectionContentBottomMargin
                                        spacing: ScreenTools.defaultFontPixelHeight * 0.44

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: vehicleStatusCard._sectionHeaderHeight
                                            spacing: vehicleStatusCard._sectionHeaderSpacing

                                            QGCLabel {
                                                Layout.fillWidth: true
                                                Layout.alignment: Qt.AlignVCenter
                                                color: vehicleStatusCard._textPrimaryColor
                                                font.weight: Font.DemiBold
                                                font.pixelSize: vehicleStatusCard._sectionHeaderTitleSize
                                                text: qsTr("VEHICLE STATUS")
                                                verticalAlignment: Text.AlignVCenter
                                            }

                                            Rectangle {
                                                Layout.preferredWidth: vehicleStatusCard._sectionHeaderButtonSize
                                                Layout.preferredHeight: Layout.preferredWidth
                                                Layout.alignment: Qt.AlignVCenter
                                                Layout.rightMargin: vehicleStatusCard._sectionHeaderButtonRightMargin
                                                color: settingsMouseArea.pressed
                                                    ? vehicleStatusCard._buttonSecondaryPressedColor
                                                    : (settingsMouseArea.containsMouse ? vehicleStatusCard._buttonSecondaryHoverColor : vehicleStatusCard._buttonSecondaryColor)
                                                radius: vehicleStatusCard._controlRadius
                                                border.width: vehicleStatusCard._controlBorderWidth
                                                border.color: vehicleStatusCard._controlBorderColor

                                                Behavior on color {
                                                    ColorAnimation { duration: vehicleStatusCard._transitionDuration }
                                                }

                                                QGCColoredImage {
                                                    anchors.centerIn: parent
                                                    width: parent.height * vehicleStatusCard._sectionHeaderIconScale
                                                    height: width
                                                    color: vehicleStatusCard._textPrimaryColor
                                                    fillMode: Image.PreserveAspectFit
                                                    source: "/InstrumentValueIcons/cog.svg"
                                                }

                                                QGCMouseArea {
                                                    id: settingsMouseArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onClicked: root._openVehicleSetupHome()
                                                }
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: ScreenTools.defaultFontPixelWidth * 0.2

                                            Rectangle {
                                                id: vehicleIconDropdownField
                                                Layout.preferredWidth: parent.width * 0.23
                                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.82
                                                color: vehicleIconPickerMouseArea.pressed
                                                    ? vehicleStatusCard._buttonSecondaryPressedColor
                                                    : (vehicleIconPickerMouseArea.containsMouse ? vehicleStatusCard._buttonSecondaryHoverColor : vehicleStatusCard._fieldColor)
                                                radius: vehicleStatusCard._controlRadius
                                                border.width: vehicleStatusCard._controlBorderWidth
                                                border.color: vehicleStatusCard._controlBorderColor

                                                Behavior on color {
                                                    ColorAnimation { duration: vehicleStatusCard._transitionDuration }
                                                }

                                                QGCColoredImage {
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.34
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: ScreenTools.defaultFontPixelHeight * 0.7
                                                    height: width
                                                    color: vehicleStatusCard._textPrimaryColor
                                                    fillMode: Image.PreserveAspectFit
                                                    source: root._vehicleStatusIcon(root._activeVehicle)
                                                }

                                                QGCColoredImage {
                                                    anchors.right: parent.right
                                                    anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.28
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: ScreenTools.defaultFontPixelHeight * 0.36
                                                    height: width
                                                    color: vehicleStatusCard._textPrimaryColor
                                                    fillMode: Image.PreserveAspectFit
                                                    source: "/InstrumentValueIcons/cheveron-down.svg"
                                                }

                                                QGCMouseArea {
                                                    id: vehicleIconPickerMouseArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onClicked: root._popupMenuInLeftPane(vehicleIconMenu, vehicleIconDropdownField, vehicleIconDropdownField.width)
                                                }
                                            }

                                            Rectangle {
                                                id: vehicleSelectorDropdownField
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.82
                                                color: vehicleSelectorMouseArea.pressed
                                                    ? vehicleStatusCard._buttonSecondaryPressedColor
                                                    : (vehicleSelectorMouseArea.containsMouse ? vehicleStatusCard._buttonSecondaryHoverColor : vehicleStatusCard._fieldColor)
                                                radius: vehicleStatusCard._controlRadius
                                                border.width: vehicleStatusCard._controlBorderWidth
                                                border.color: vehicleNameField.activeFocus
                                                    ? vehicleStatusCard._highlightColor
                                                    : vehicleStatusCard._controlBorderColor

                                                Behavior on color {
                                                    ColorAnimation { duration: vehicleStatusCard._transitionDuration }
                                                }
                                                Behavior on border.color {
                                                    ColorAnimation { duration: vehicleStatusCard._transitionDuration }
                                                }

                                                TextField {
                                                    id: vehicleNameField

                                                    anchors.left: parent.left
                                                    anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.38
                                                    anchors.right: parent.right
                                                    anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.34
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    color: vehicleStatusCard._textPrimaryColor
                                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.72
                                                    readOnly: true
                                                    selectByMouse: true
                                                    text: root._vehicleTitle(root._activeVehicle)
                                                    verticalAlignment: TextInput.AlignVCenter

                                                    background: Item {
                                                    }
                                                }

                                                QGCMouseArea {
                                                    id: vehicleSelectorMouseArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onClicked: root._popupMenuInLeftPane(vehicleMenu, vehicleSelectorDropdownField, vehicleSelectorDropdownField.width)
                                                }
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.9
                                            color: vehicleStatusCard._blockColor
                                            radius: vehicleStatusCard._controlRadius
                                            border.width: vehicleStatusCard._controlBorderWidth
                                            border.color: vehicleStatusCard._controlBorderColor

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.38
                                                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.28
                                                spacing: ScreenTools.defaultFontPixelWidth * 0.28

                                                QGCLabel {
                                                    color: vehicleStatusCard._textPrimaryColor
                                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.72
                                                    text: qsTr("Flight Mode")
                                                }

                                                Item {
                                                    Layout.fillWidth: true
                                                }

                                                Rectangle {
                                                    id: flightModeDropdownField
                                                    Layout.preferredWidth: Math.max(ScreenTools.defaultFontPixelWidth * 10.5, parent.width * 0.4)
                                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.42
                                                    color: flightModeMouseArea.pressed
                                                        ? vehicleStatusCard._buttonSecondaryPressedColor
                                                        : (flightModeMouseArea.containsMouse ? vehicleStatusCard._buttonSecondaryHoverColor : vehicleStatusCard._fieldColor)
                                                    radius: vehicleStatusCard._controlRadius
                                                    border.width: vehicleStatusCard._controlBorderWidth
                                                    border.color: vehicleStatusCard._controlBorderColor

                                                    Behavior on color {
                                                        ColorAnimation { duration: vehicleStatusCard._transitionDuration }
                                                    }

                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.3
                                                        anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.24
                                                        spacing: ScreenTools.defaultFontPixelWidth * 0.18

                                                        QGCColoredImage {
                                                            Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.56
                                                            Layout.preferredHeight: Layout.preferredWidth
                                                            color: vehicleStatusCard._textPrimaryColor
                                                            fillMode: Image.PreserveAspectFit
                                                            source: "/InstrumentValueIcons/target.svg"
                                                        }

                                                        QGCLabel {
                                                            Layout.fillWidth: true
                                                            color: vehicleStatusCard._textPrimaryColor
                                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.68
                                                            text: root._activeVehicle && root._activeVehicle.flightMode ? root._activeVehicle.flightMode : qsTr("Auto")
                                                        }

                                                        QGCColoredImage {
                                                            Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.34
                                                            Layout.preferredHeight: Layout.preferredWidth
                                                            color: vehicleStatusCard._textPrimaryColor
                                                            fillMode: Image.PreserveAspectFit
                                                            source: "/InstrumentValueIcons/cheveron-down.svg"
                                                        }
                                                    }

                                                    QGCMouseArea {
                                                        id: flightModeMouseArea
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        onClicked: root._popupMenuInLeftPane(flightModeMenu, flightModeDropdownField, flightModeDropdownField.width)
                                                    }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            id: preFlightChecklistButton
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.82
                                            color: preFlightChecklistMouseArea.pressed
                                                ? vehicleStatusCard._highlightPressedColor
                                                : (preFlightChecklistMouseArea.containsMouse ? vehicleStatusCard._highlightHoverColor : vehicleStatusCard._highlightColor)
                                            radius: vehicleStatusCard._controlRadius
                                            border.width: vehicleStatusCard._controlBorderWidth
                                            border.color: vehicleStatusCard._controlBorderColor
                                            opacity: root._activeVehicle ? 1 : 0.45

                                            Behavior on color {
                                                ColorAnimation { duration: vehicleStatusCard._transitionDuration }
                                            }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.38
                                                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.28
                                                spacing: ScreenTools.defaultFontPixelWidth * 0.2

                                                QGCColoredImage {
                                                    Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.6
                                                    Layout.preferredHeight: Layout.preferredWidth
                                                    color: vehicleStatusCard._textPrimaryColor
                                                    fillMode: Image.PreserveAspectFit
                                                    source: "/InstrumentValueIcons/clipboard.svg"
                                                }

                                                QGCLabel {
                                                    Layout.fillWidth: true
                                                    color: vehicleStatusCard._textPrimaryColor
                                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.7
                                                    font.weight: Font.DemiBold
                                                    text: qsTr("Pre-Flight Checklist")
                                                }

                                                QGCLabel {
                                                    color: vehicleStatusCard._textPrimaryColor
                                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                                                    text: qsTr("Open")
                                                }
                                            }

                                            QGCMouseArea {
                                                id: preFlightChecklistMouseArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                enabled: !!root._activeVehicle
                                                onClicked: root._openPreFlightChecklist()
                                            }
                                        }

                                        Rectangle {
                                            id: setupVehicleDropdownField
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.82
                                            color: vehicleStatusCard._blockColor
                                            radius: vehicleStatusCard._controlRadius
                                            border.width: vehicleStatusCard._controlBorderWidth
                                            border.color: vehicleStatusCard._controlBorderColor

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.38
                                                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.28
                                                spacing: ScreenTools.defaultFontPixelWidth * 0.24

                                                QGCLabel {
                                                    color: vehicleStatusCard._textPrimaryColor
                                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.72
                                                    text: qsTr("Show Flight Path")
                                                }

                                                Item {
                                                    Layout.fillWidth: true
                                                }

                                                QGCCheckBoxSlider {
                                                    checked: root._showFlightPath
                                                    text: ""
                                                    onClicked: root._showFlightPath = checked
                                                }
                                            }
                                        }

                                        Repeater {
                                            model: [
                                                {
                                                    "background": vehicleStatusCard._buttonSecondaryColor,
                                                    "foreground": vehicleStatusCard._textPrimaryColor,
                                                    "icon": "/res/rtl.svg",
                                                    "label": qsTr("Return/RTL"),
                                                    "action": guidedActionsController.actionRTL
                                                },
                                                {
                                                    "background": vehicleStatusCard._buttonSecondaryColor,
                                                    "foreground": vehicleStatusCard._textPrimaryColor,
                                                    "icon": "/res/land.svg",
                                                    "label": qsTr("Land"),
                                                    "action": guidedActionsController.actionLand
                                                },
                                                {
                                                    "background": vehicleStatusCard._highlightColor,
                                                    "foreground": vehicleStatusCard._textPrimaryColor,
                                                    "icon": "/res/Stop.svg",
                                                    "label": qsTr("Emergency Stop"),
                                                    "action": guidedActionsController.actionEmergencyStop
                                                }
                                            ]

                                            delegate: Rectangle {
                
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.86
                                                color: actionButtonMouseArea.pressed
                                                    ? vehicleStatusCard._buttonSecondaryPressedColor
                                                    : (actionButtonMouseArea.containsMouse
                                                        ? (modelData.background === vehicleStatusCard._highlightColor ? vehicleStatusCard._highlightHoverColor : vehicleStatusCard._buttonSecondaryHoverColor)
                                                        : modelData.background)
                                                opacity: root._activeVehicle ? 1 : 0.45
                                                radius: vehicleStatusCard._controlRadius
                                                border.width: vehicleStatusCard._controlBorderWidth
                                                border.color: vehicleStatusCard._controlBorderColor

                                                Behavior on color {
                                                    ColorAnimation { duration: vehicleStatusCard._transitionDuration }
                                                }

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.38
                                                    anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.32
                                                    spacing: ScreenTools.defaultFontPixelWidth * 0.28

                                                    QGCColoredImage {
                                                        Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.7
                                                        Layout.preferredHeight: Layout.preferredWidth
                                                        color: modelData.foreground
                                                        fillMode: Image.PreserveAspectFit
                                                        source: modelData.icon
                                                    }

                                                    QGCLabel {
                                                        Layout.fillWidth: true
                                                        color: modelData.foreground
                                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.72
                                                        font.weight: Font.DemiBold
                                                        elide: Text.ElideRight
                                                        verticalAlignment: Text.AlignVCenter
                                                        text: modelData.label
                                                    }
                                                }

                                                QGCMouseArea {
                                                    id: actionButtonMouseArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    enabled: root._activeVehicle

                                                    onClicked: guidedActionsController.confirmAction(modelData.action)
                                                }
                                            }
                                        }

                                        Item {
                                            Layout.fillHeight: true
                                        }
                                    }
                                }

                                Item {
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: vehicleStatusCard._sectionContentLeftMargin
                                        anchors.rightMargin: vehicleStatusCard._sectionContentRightMargin
                                        anchors.topMargin: vehicleStatusCard._sectionContentTopMargin
                                        anchors.bottomMargin: vehicleStatusCard._sectionContentBottomMargin

                                        Item {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true

                                            FlyViewInstrumentPanel {
                                                anchors.fill: parent
                                                useLegacySelectableControl: false
                                                showHeader: true
                                                showHeaderAction: true
                                                headerTitle: qsTr("INSTRUMENTS")
                                                headerHeight: vehicleStatusCard._sectionHeaderHeight
                                                headerSpacing: vehicleStatusCard._sectionHeaderSpacing
                                                headerTitleSize: vehicleStatusCard._sectionHeaderTitleSize
                                                headerTitleColor: vehicleStatusCard._textPrimaryColor
                                                panelLeftMargin: 0
                                                panelRightMargin: 0
                                                panelTopMargin: 0
                                                panelBottomMargin: 0
                                                headerActionSize: vehicleStatusCard._sectionHeaderButtonSize
                                                headerActionRightMargin: vehicleStatusCard._sectionHeaderButtonRightMargin
                                                headerActionRadius: vehicleStatusCard._controlRadius
                                                headerActionIconScale: vehicleStatusCard._sectionHeaderIconScale
                                                headerActionIconColor: vehicleStatusCard._textSecondaryColor
                                                headerActionColor: vehicleStatusCard._buttonSecondaryColor
                                                headerActionHoverColor: vehicleStatusCard._buttonSecondaryHoverColor
                                                headerActionPressedColor: vehicleStatusCard._buttonSecondaryPressedColor
                                                headerActionBorderColor: vehicleStatusCard._controlBorderColor
                                                headerTransitionDuration: vehicleStatusCard._transitionDuration
                                            }

                                        }
                                    }
                                }

                                Item {
                                    FlyViewDocsChecklistPanel {
                                        anchors.fill: parent
                                        vehicle: root._activeVehicle
                                        panelColor: vehicleStatusCard._contentColor
                                        titleColor: vehicleStatusCard._textPrimaryColor
                                        detailColor: vehicleStatusCard._textSecondaryColor
                                        contentLeftMargin: vehicleStatusCard._sectionContentLeftMargin
                                        contentRightMargin: vehicleStatusCard._sectionContentRightMargin
                                        contentTopMargin: vehicleStatusCard._sectionContentTopMargin
                                        contentBottomMargin: vehicleStatusCard._sectionContentBottomMargin
                                        contentSpacing: vehicleStatusCard._sectionContentSpacing
                                        showHeaderAction: true
                                        headerHeight: vehicleStatusCard._sectionHeaderHeight
                                        headerSpacing: vehicleStatusCard._sectionHeaderSpacing
                                        headerTitleSize: vehicleStatusCard._sectionHeaderTitleSize
                                        headerActionSize: vehicleStatusCard._sectionHeaderButtonSize
                                        headerActionRightMargin: vehicleStatusCard._sectionHeaderButtonRightMargin
                                        headerActionRadius: vehicleStatusCard._controlRadius
                                        headerActionIconScale: vehicleStatusCard._sectionHeaderIconScale
                                        headerActionColor: vehicleStatusCard._buttonSecondaryColor
                                        headerActionHoverColor: vehicleStatusCard._buttonSecondaryHoverColor
                                        headerActionPressedColor: vehicleStatusCard._buttonSecondaryPressedColor
                                        headerActionBorderColor: vehicleStatusCard._controlBorderColor
                                        headerActionIconColor: vehicleStatusCard._textSecondaryColor
                                        headerTransitionDuration: vehicleStatusCard._transitionDuration
                                    }
                                }

                                Item {
                                    id: networkStatusPage

                                    readonly property real _gpsPercent: root._networkGpsPercent(root._activeVehicle)
                                    readonly property real _rcPercent: root._networkRcPercent(root._activeVehicle)
                                    readonly property real _telemetryPercent: root._networkTelemetryPercent(root._activeVehicle)
                                    readonly property real _titleFontSize: ScreenTools.defaultFontPixelHeight * 0.64
                                    readonly property real _primaryFontSize: ScreenTools.defaultFontPixelHeight * 0.68
                                    readonly property real _secondaryFontSize: ScreenTools.defaultFontPixelHeight * 0.64
                                    readonly property real _blockRadius: vehicleStatusCard._controlRadius
                                    readonly property real _innerLeftMargin: ScreenTools.defaultFontPixelWidth * 0.44
                                    readonly property real _innerRightMargin: ScreenTools.defaultFontPixelWidth * 0.34
                                    readonly property color _networkBlockColor: vehicleStatusCard._blockColor

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: vehicleStatusCard._sectionContentLeftMargin
                                        anchors.rightMargin: vehicleStatusCard._sectionContentRightMargin
                                        anchors.topMargin: vehicleStatusCard._sectionContentTopMargin
                                        anchors.bottomMargin: vehicleStatusCard._sectionContentBottomMargin
                                        spacing: vehicleStatusCard._sectionContentSpacing

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: vehicleStatusCard._sectionHeaderHeight
                                            spacing: vehicleStatusCard._sectionHeaderSpacing

                                            QGCLabel {
                                                Layout.fillWidth: true
                                                color: vehicleStatusCard._textPrimaryColor
                                                font.weight: Font.DemiBold
                                                font.pixelSize: vehicleStatusCard._sectionHeaderTitleSize
                                                text: qsTr("NETWORK")
                                                verticalAlignment: Text.AlignVCenter
                                            }

                                            Rectangle {
                                                Layout.preferredWidth: vehicleStatusCard._sectionHeaderButtonSize
                                                Layout.preferredHeight: Layout.preferredWidth
                                                Layout.rightMargin: vehicleStatusCard._sectionHeaderButtonRightMargin
                                                color: networkSettingsMouseArea.pressed
                                                    ? vehicleStatusCard._buttonSecondaryPressedColor
                                                    : (networkSettingsMouseArea.containsMouse ? vehicleStatusCard._buttonSecondaryHoverColor : vehicleStatusCard._buttonSecondaryColor)
                                                radius: vehicleStatusCard._controlRadius
                                                border.width: vehicleStatusCard._controlBorderWidth
                                                border.color: vehicleStatusCard._controlBorderColor

                                                Behavior on color {
                                                    ColorAnimation { duration: vehicleStatusCard._transitionDuration }
                                                }

                                                QGCColoredImage {
                                                    anchors.centerIn: parent
                                                    width: parent.height * vehicleStatusCard._sectionHeaderIconScale
                                                    height: width
                                                    color: vehicleStatusCard._textSecondaryColor
                                                    fillMode: Image.PreserveAspectFit
                                                    source: "/InstrumentValueIcons/cog.svg"
                                                }

                                                QGCMouseArea {
                                                    id: networkSettingsMouseArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onClicked: root._openCommunicationLinkSettings()
                                                }
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 4.32
                                            color: networkStatusPage._networkBlockColor
                                            radius: networkStatusPage._blockRadius
                                            border.width: vehicleStatusCard._controlBorderWidth
                                            border.color: vehicleStatusCard._controlBorderColor

                                            ColumnLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: networkStatusPage._innerLeftMargin
                                                anchors.rightMargin: networkStatusPage._innerRightMargin
                                                anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.16
                                                anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.16
                                                spacing: ScreenTools.defaultFontPixelHeight * 0.08

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.04
                                                    spacing: ScreenTools.defaultFontPixelWidth * 0.16

                                                    QGCLabel {
                                                        Layout.fillWidth: true
                                                        color: vehicleStatusCard._textPrimaryColor
                                                        font.pixelSize: networkStatusPage._primaryFontSize
                                                        text: qsTr("GPS Status")
                                                    }

                                                    QGCColoredImage {
                                                        Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.58
                                                        Layout.preferredHeight: Layout.preferredWidth
                                                        color: root._networkStatusColor(networkStatusPage._gpsPercent)
                                                        fillMode: Image.PreserveAspectFit
                                                        source: root._networkSignalIcon(networkStatusPage._gpsPercent)
                                                    }

                                                    QGCLabel {
                                                        color: root._networkStatusColor(networkStatusPage._gpsPercent)
                                                        font.pixelSize: networkStatusPage._primaryFontSize
                                                        font.weight: Font.DemiBold
                                                        text: root._networkStatusText(networkStatusPage._gpsPercent)
                                                    }
                                                }

                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: 1
                                                    color: vehicleStatusCard._controlBorderColor
                                                }

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 0.96
                                                    spacing: ScreenTools.defaultFontPixelWidth * 0.14

                                                    QGCLabel {
                                                        Layout.fillWidth: true
                                                        color: vehicleStatusCard._textSecondaryColor
                                                        font.pixelSize: networkStatusPage._secondaryFontSize
                                                        horizontalAlignment: Text.AlignHCenter
                                                        text: qsTr("Satellite Count")
                                                    }

                                                    QGCLabel {
                                                        color: vehicleStatusCard._textSecondaryColor
                                                        font.pixelSize: networkStatusPage._secondaryFontSize
                                                        horizontalAlignment: Text.AlignRight
                                                        text: root._networkSatelliteText(root._activeVehicle)
                                                    }
                                                }

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 0.96
                                                    spacing: ScreenTools.defaultFontPixelWidth * 0.14

                                                    QGCLabel {
                                                        Layout.fillWidth: true
                                                        color: vehicleStatusCard._textSecondaryColor
                                                        font.pixelSize: networkStatusPage._secondaryFontSize
                                                        horizontalAlignment: Text.AlignHCenter
                                                        text: qsTr("HDOP")
                                                    }

                                                    QGCLabel {
                                                        color: vehicleStatusCard._textSecondaryColor
                                                        font.pixelSize: networkStatusPage._secondaryFontSize
                                                        horizontalAlignment: Text.AlignRight
                                                        text: root._networkHdopText(root._activeVehicle)
                                                    }
                                                }
                                            }
                                        }

                                        Repeater {
                                            model: [
                                                {
                                                    "label": qsTr("RC RSSI"),
                                                    "percent": networkStatusPage._rcPercent
                                                },
                                                {
                                                    "label": qsTr("Telemetry RSSI"),
                                                    "percent": networkStatusPage._telemetryPercent
                                                }
                                            ]

                                            delegate: Rectangle {
                
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.8
                                                color: networkStatusPage._networkBlockColor
                                                radius: networkStatusPage._blockRadius
                                                border.width: vehicleStatusCard._controlBorderWidth
                                                border.color: vehicleStatusCard._controlBorderColor

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: networkStatusPage._innerLeftMargin
                                                    anchors.rightMargin: networkStatusPage._innerRightMargin
                                                    spacing: ScreenTools.defaultFontPixelWidth * 0.16

                                                    QGCLabel {
                                                        Layout.fillWidth: true
                                                        color: vehicleStatusCard._textPrimaryColor
                                                        font.pixelSize: networkStatusPage._primaryFontSize
                                                        text: modelData.label
                                                    }

                                                    QGCColoredImage {
                                                        Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.58
                                                        Layout.preferredHeight: Layout.preferredWidth
                                                        color: root._networkStatusColor(modelData.percent)
                                                        fillMode: Image.PreserveAspectFit
                                                        source: root._networkSignalIcon(modelData.percent)
                                                    }

                                                    QGCLabel {
                                                        color: root._networkStatusColor(modelData.percent)
                                                        font.pixelSize: networkStatusPage._primaryFontSize
                                                        font.weight: Font.DemiBold
                                                        text: root._networkStatusText(modelData.percent)
                                                    }
                                                }
                                            }
                                        }

                                        Item {
                                            Layout.fillHeight: true
                                        }
                                    }
                                }

                                Item {
                                    id: vehicleSetupPage

                                    readonly property real _titleFontSize: ScreenTools.defaultFontPixelHeight * 0.64
                                    readonly property real _moduleTitleFontSize: ScreenTools.defaultFontPixelHeight * 0.68
                                    readonly property real _statusFontSize: ScreenTools.defaultFontPixelHeight * 0.62
                                    readonly property real _blockRadius: vehicleStatusCard._controlRadius
                                    readonly property color _moduleColor: vehicleStatusCard._blockColor
                                    readonly property bool _tuningEnabled: !!root._vehicleSetupTuningComponent(root._activeVehicle)
                                    readonly property bool _sensorEnabled: !!root._vehicleSetupSensorComponent(root._activeVehicle) && !!root._activeVehicle && !root._activeVehicle.armed
                                    readonly property bool _firmwareEnabled: root._vehicleSetupFirmwareAvailable() && (!root._activeVehicle || !root._activeVehicle.armed)

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: vehicleStatusCard._sectionContentLeftMargin
                                        anchors.rightMargin: vehicleStatusCard._sectionContentRightMargin
                                        anchors.topMargin: vehicleStatusCard._sectionContentTopMargin
                                        anchors.bottomMargin: vehicleStatusCard._sectionContentBottomMargin
                                        spacing: vehicleStatusCard._sectionContentSpacing

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: vehicleStatusCard._sectionHeaderHeight
                                            spacing: vehicleStatusCard._sectionHeaderSpacing

                                            QGCLabel {
                                                Layout.fillWidth: true
                                                color: vehicleStatusCard._textPrimaryColor
                                                font.weight: Font.DemiBold
                                                font.pixelSize: vehicleStatusCard._sectionHeaderTitleSize
                                                text: qsTr("VEHICLE SETUP")
                                                verticalAlignment: Text.AlignVCenter
                                            }

                                            Rectangle {
                                                Layout.preferredWidth: vehicleStatusCard._sectionHeaderButtonSize
                                                Layout.preferredHeight: Layout.preferredWidth
                                                Layout.rightMargin: vehicleStatusCard._sectionHeaderButtonRightMargin
                                                color: setupSettingsMouseArea.pressed
                                                    ? vehicleStatusCard._buttonSecondaryPressedColor
                                                    : (setupSettingsMouseArea.containsMouse ? vehicleStatusCard._buttonSecondaryHoverColor : vehicleStatusCard._buttonSecondaryColor)
                                                radius: vehicleStatusCard._controlRadius
                                                border.width: vehicleStatusCard._controlBorderWidth
                                                border.color: vehicleStatusCard._controlBorderColor

                                                Behavior on color {
                                                    ColorAnimation { duration: vehicleStatusCard._transitionDuration }
                                                }

                                                QGCColoredImage {
                                                    anchors.centerIn: parent
                                                    width: parent.height * vehicleStatusCard._sectionHeaderIconScale
                                                    height: width
                                                    color: vehicleStatusCard._textSecondaryColor
                                                    fillMode: Image.PreserveAspectFit
                                                    source: "/InstrumentValueIcons/cog.svg"
                                                }

                                                QGCMouseArea {
                                                    id: setupSettingsMouseArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onClicked: root._openVehicleSetupHome()
                                                }
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.82
                                            color: setupVehicleMouseArea.pressed
                                                ? vehicleStatusCard._buttonSecondaryPressedColor
                                                : (setupVehicleMouseArea.containsMouse ? vehicleStatusCard._buttonSecondaryHoverColor : vehicleStatusCard._fieldColor)
                                            radius: vehicleStatusCard._controlRadius
                                            border.width: vehicleStatusCard._controlBorderWidth
                                            border.color: vehicleStatusCard._controlBorderColor

                                            Behavior on color {
                                                ColorAnimation { duration: vehicleStatusCard._transitionDuration }
                                            }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.42
                                                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.28
                                                spacing: ScreenTools.defaultFontPixelWidth * 0.16

                                                QGCLabel {
                                                    Layout.fillWidth: true
                                                    color: vehicleStatusCard._textPrimaryColor
                                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.68
                                                    text: root._vehicleTitle(root._activeVehicle)
                                                    verticalAlignment: Text.AlignVCenter
                                                }

                                                QGCColoredImage {
                                                    Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.36
                                                    Layout.preferredHeight: Layout.preferredWidth
                                                    color: vehicleStatusCard._textPrimaryColor
                                                    fillMode: Image.PreserveAspectFit
                                                    source: "/InstrumentValueIcons/cheveron-down.svg"
                                                }
                                            }

                                            QGCMouseArea {
                                                id: setupVehicleMouseArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                enabled: QGroundControl.multiVehicleManager.vehicles && QGroundControl.multiVehicleManager.vehicles.count > 0
                                                onClicked: root._popupMenuInLeftPane(vehicleMenu, setupVehicleDropdownField, setupVehicleDropdownField.width)
                                            }
                                        }

                                        Repeater {
                                            model: [
                                                {
                                                    "title": qsTr("Flight Controller Tuning"),
                                                    "buttonText": qsTr("Open"),
                                                    "statusText": root._vehicleSetupTuningStatusText(),
                                                    "statusColor": vehicleSetupPage._tuningEnabled ? "#AFC4D7" : "#8D939A",
                                                    "enabled": vehicleSetupPage._tuningEnabled,
                                                    "action": root._openVehicleSetupTuning
                                                },
                                                {
                                                    "title": qsTr("Sensor Calibration"),
                                                    "buttonText": qsTr("Calibrate"),
                                                    "statusText": root._vehicleSetupSensorStatusText(),
                                                    "statusColor": vehicleSetupPage._sensorEnabled ? "#AFC4D7" : (root._activeVehicle && root._activeVehicle.armed ? "#D6A566" : "#8D939A"),
                                                    "enabled": vehicleSetupPage._sensorEnabled,
                                                    "action": root._openVehicleSetupSensors
                                                },
                                                {
                                                    "title": qsTr("Firmware Update"),
                                                    "buttonText": qsTr("Update"),
                                                    "statusText": root._vehicleSetupFirmwareStatusText(),
                                                    "statusColor": vehicleSetupPage._firmwareEnabled ? "#AFC4D7" : "#8D939A",
                                                    "enabled": vehicleSetupPage._firmwareEnabled,
                                                    "action": root._openVehicleSetupFirmware
                                                }
                                            ]

                                            delegate: Rectangle {
                
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3.12
                                                color: vehicleSetupPage._moduleColor
                                                radius: vehicleSetupPage._blockRadius
                                                border.width: vehicleStatusCard._controlBorderWidth
                                                border.color: vehicleStatusCard._controlBorderColor

                                                ColumnLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.44
                                                    anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.34
                                                    anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.2
                                                    anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.2
                                                    spacing: ScreenTools.defaultFontPixelHeight * 0.16

                                                    QGCLabel {
                                                        Layout.fillWidth: true
                                                        color: vehicleStatusCard._textPrimaryColor
                                                        font.pixelSize: vehicleSetupPage._moduleTitleFontSize
                                                        text: modelData.title
                                                        verticalAlignment: Text.AlignVCenter
                                                    }

                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        spacing: ScreenTools.defaultFontPixelWidth * 0.24

                                                        Rectangle {
                                                            Layout.preferredWidth: Math.max(ScreenTools.defaultFontPixelWidth * 7.0, parent.width * 0.23)
                                                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.28
                                                            color: !modelData.enabled
                                                                ? vehicleStatusCard._buttonSecondaryColor
                                                                : (moduleActionMouseArea.pressed
                                                                    ? vehicleStatusCard._highlightPressedColor
                                                                    : (moduleActionMouseArea.containsMouse ? vehicleStatusCard._highlightHoverColor : vehicleStatusCard._highlightColor))
                                                            opacity: modelData.enabled ? 1 : 0.5
                                                            radius: vehicleStatusCard._controlRadius
                                                            border.width: vehicleStatusCard._controlBorderWidth
                                                            border.color: vehicleStatusCard._controlBorderColor

                                                            Behavior on color {
                                                                ColorAnimation { duration: vehicleStatusCard._transitionDuration }
                                                            }

                                                            QGCLabel {
                                                                anchors.centerIn: parent
                                                                color: vehicleStatusCard._textPrimaryColor
                                                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.62
                                                                font.weight: Font.DemiBold
                                                                text: modelData.buttonText
                                                            }

                                                            QGCMouseArea {
                                                                id: moduleActionMouseArea
                                                                anchors.fill: parent
                                                                hoverEnabled: true
                                                                enabled: modelData.enabled
                                                                onClicked: {
                                                                    if (typeof modelData.action === "function") {
                                                                        modelData.action()
                                                                    }
                                                                }
                                                            }
                                                        }

                                                        QGCLabel {
                                                            Layout.fillWidth: true
                                                            color: modelData.statusColor
                                                            font.pixelSize: vehicleSetupPage._statusFontSize
                                                            horizontalAlignment: Text.AlignRight
                                                            text: modelData.statusText
                                                        }
                                                    }

                                                    Item {
                                                        Layout.fillHeight: true
                                                    }
                                                }
                                            }
                                        }

                                        Item {
                                            Layout.fillHeight: true
                                        }
                                    }
                                }

                                Item {
                                    id: sensorsTelemetryPage

                                    readonly property real _titleFontSize: ScreenTools.defaultFontPixelHeight * 0.64
                                    readonly property real _sectionTitleFontSize: ScreenTools.defaultFontPixelHeight * 0.68
                                    readonly property real _textFontSize: ScreenTools.defaultFontPixelHeight * 0.58
                                    readonly property real _valueFontSize: ScreenTools.defaultFontPixelHeight * 0.62
                                    readonly property real _blockRadius: vehicleStatusCard._controlRadius
                                    readonly property color _moduleColor: vehicleStatusCard._blockColor
                                    readonly property color _statusCardColor: "#363636"
                                    readonly property color _summaryCardColor: "#333333"
                                    readonly property color _chartBackgroundColor: "#252525"
                                    readonly property color _okColor: "#32D296"
                                    readonly property int _seriesMaxCount: 100
                                    readonly property var _summaryModel: [
                                        { "title": qsTr("GPS"),           "bit": Vehicle.SysStatusSensorGPS,     "goodText": qsTr("Good"),       "badText": qsTr("Degraded"), "detail": "sat" },
                                        { "title": qsTr("Compass"),       "bit": Vehicle.SysStatusSensor3dMag,   "goodText": qsTr("Calibrated"), "badText": qsTr("Recheck"),  "detail": ""    },
                                        { "title": qsTr("Accelerometer"), "bit": Vehicle.SysStatusSensor3dAccel, "goodText": qsTr("Healthy"),    "badText": qsTr("Attention"),"detail": ""    },
                                        { "title": qsTr("Gyroscope"),     "bit": Vehicle.SysStatusSensor3dGyro,  "goodText": qsTr("Healthy"),    "badText": qsTr("Attention"),"detail": ""    }
                                    ]

                                    property real _cpuLoadPercent: 15
                                    property bool _logActive: false
                                    property bool _healthNominal: false
                                    property real _telemetryPhase: 0
                                    property real _lastHeading: NaN
                                    property real _baroBaseline: NaN
                                    property var _gyroSeries: []
                                    property var _accelSeries: []
                                    property var _magSeries: []
                                    property var _baroSeries: []

                                    function _factValue(fact) {
                                        return root._hasFactValue(fact) ? Number(fact.rawValue) : NaN
                                    }

                                    function _appendSample(series, value) {
                                        const numericValue = Number(value)
                                        if (series.length >= _seriesMaxCount) {
                                            series.shift()
                                        }
                                        series.push(isNaN(numericValue) ? 0 : numericValue)
                                    }

                                    function _fallbackWave(offset, amplitude, center) {
                                        const primary = Math.sin(_telemetryPhase + offset) * amplitude
                                        const secondary = Math.cos((_telemetryPhase * 0.62) + offset) * amplitude * 0.24
                                        return center + primary + secondary
                                    }

                                    function _refreshTelemetry() {
                                        const vehicle = root._activeVehicle
                                        _telemetryPhase += 0.18

                                        _cpuLoadPercent = root._sensorCpuLoadPercent(vehicle)
                                        _logActive = root._sensorLogActive(vehicle)
                                        _healthNominal = root._sensorHealthNominal(vehicle)

                                        const rollRate = _factValue(vehicle ? vehicle.rollRate : null)
                                        const pitchRate = _factValue(vehicle ? vehicle.pitchRate : null)
                                        const yawRate = _factValue(vehicle ? vehicle.yawRate : null)
                                        let gyroSample = NaN

                                        if (!isNaN(rollRate) || !isNaN(pitchRate) || !isNaN(yawRate)) {
                                            gyroSample = (Math.abs(isNaN(rollRate) ? 0 : rollRate) * 0.42) +
                                                         (Math.abs(isNaN(pitchRate) ? 0 : pitchRate) * 0.32) +
                                                         (Math.abs(isNaN(yawRate) ? 0 : yawRate) * 0.26)
                                        }
                                        if (isNaN(gyroSample)) {
                                            gyroSample = _fallbackWave(0.18, 0.42, 0.95)
                                        }

                                        const vibration = vehicle ? vehicle.vibration : null
                                        const vibX = _factValue(vibration ? vibration.xAxis : null)
                                        const vibY = _factValue(vibration ? vibration.yAxis : null)
                                        const vibZ = _factValue(vibration ? vibration.zAxis : null)
                                        let accelSample = NaN

                                        if (!isNaN(vibX) || !isNaN(vibY) || !isNaN(vibZ)) {
                                            const ax = isNaN(vibX) ? 0 : vibX
                                            const ay = isNaN(vibY) ? 0 : vibY
                                            const az = isNaN(vibZ) ? 0 : vibZ
                                            accelSample = Math.sqrt((ax * ax) + (ay * ay) + (az * az))
                                        }
                                        if (isNaN(accelSample)) {
                                            accelSample = _fallbackWave(1.05, 0.36, 0.78)
                                        }

                                        const heading = _factValue(vehicle ? vehicle.heading : null)
                                        let magSample = NaN
                                        if (!isNaN(heading)) {
                                            if (!isNaN(_lastHeading)) {
                                                let headingDelta = Math.abs(heading - _lastHeading)
                                                if (headingDelta > 180) {
                                                    headingDelta = 360 - headingDelta
                                                }
                                                magSample = headingDelta
                                            }
                                            _lastHeading = heading
                                        }
                                        if (isNaN(magSample)) {
                                            magSample = _fallbackWave(1.72, 0.26, 0.52)
                                        }

                                        const altitude = _factValue(vehicle ? vehicle.altitudeRelative : null)
                                        let baroSample = NaN
                                        if (!isNaN(altitude)) {
                                            if (isNaN(_baroBaseline)) {
                                                _baroBaseline = altitude
                                            }
                                            _baroBaseline = (_baroBaseline * 0.985) + (altitude * 0.015)
                                            baroSample = altitude - _baroBaseline
                                        }
                                        if (isNaN(baroSample)) {
                                            baroSample = _fallbackWave(2.2, 0.2, 0.45)
                                        }

                                        _appendSample(_gyroSeries, gyroSample)
                                        _appendSample(_accelSeries, accelSample)
                                        _appendSample(_magSeries, magSample)
                                        _appendSample(_baroSeries, baroSample)

                                        if (telemetryWaveCanvas) {
                                            telemetryWaveCanvas.requestPaint()
                                        }
                                        if (cpuLoadGaugeCanvas) {
                                            cpuLoadGaugeCanvas.requestPaint()
                                        }
                                    }

                                    on_CpuLoadPercentChanged: {
                                        if (cpuLoadGaugeCanvas) {
                                            cpuLoadGaugeCanvas.requestPaint()
                                        }
                                    }
                                    onVisibleChanged: {
                                        if (visible) {
                                            _refreshTelemetry()
                                        }
                                    }

                                    Timer {
                                        interval: 220
                                        repeat: true
                                        running: sensorsTelemetryPage.visible
                                        triggeredOnStart: true
                                        onTriggered: sensorsTelemetryPage._refreshTelemetry()
                                    }

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: vehicleStatusCard._sectionContentLeftMargin
                                        anchors.rightMargin: vehicleStatusCard._sectionContentRightMargin
                                        anchors.topMargin: vehicleStatusCard._sectionContentTopMargin
                                        anchors.bottomMargin: vehicleStatusCard._sectionContentBottomMargin
                                        spacing: vehicleStatusCard._sectionContentSpacing

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: vehicleStatusCard._sectionHeaderHeight
                                            spacing: vehicleStatusCard._sectionHeaderSpacing

                                            QGCLabel {
                                                Layout.fillWidth: true
                                                color: vehicleStatusCard._textPrimaryColor
                                                font.weight: Font.DemiBold
                                                font.pixelSize: vehicleStatusCard._sectionHeaderTitleSize
                                                horizontalAlignment: Text.AlignLeft
                                                text: qsTr("SENSORS/TELEMETRY")
                                                verticalAlignment: Text.AlignVCenter
                                            }

                                            Rectangle {
                                                Layout.preferredWidth: vehicleStatusCard._sectionHeaderButtonSize
                                                Layout.preferredHeight: Layout.preferredWidth
                                                Layout.rightMargin: vehicleStatusCard._sectionHeaderButtonRightMargin
                                                color: sensorSettingsMouseArea.pressed
                                                    ? vehicleStatusCard._buttonSecondaryPressedColor
                                                    : (sensorSettingsMouseArea.containsMouse ? vehicleStatusCard._buttonSecondaryHoverColor : vehicleStatusCard._buttonSecondaryColor)
                                                radius: vehicleStatusCard._controlRadius
                                                border.width: vehicleStatusCard._controlBorderWidth
                                                border.color: vehicleStatusCard._controlBorderColor

                                                Behavior on color {
                                                    ColorAnimation { duration: vehicleStatusCard._transitionDuration }
                                                }

                                                QGCColoredImage {
                                                    anchors.centerIn: parent
                                                    width: parent.height * vehicleStatusCard._sectionHeaderIconScale
                                                    height: width
                                                    color: vehicleStatusCard._textSecondaryColor
                                                    fillMode: Image.PreserveAspectFit
                                                    source: "/InstrumentValueIcons/cog.svg"
                                                }

                                                QGCMouseArea {
                                                    id: sensorSettingsMouseArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onClicked: root._openVehicleSetupSensors()
                                                }
                                            }
                                        }

                                        Flickable {
                                            id: sensorsTelemetryFlickable
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            contentWidth: width
                                            contentHeight: sensorsTelemetryContent.implicitHeight
                                            clip: true
                                            boundsBehavior: Flickable.StopAtBounds
                                            flickableDirection: Flickable.VerticalFlick
                                            ScrollBar.vertical: ScrollBar {
                                                id: sensorsTelemetryScrollBar
                                                policy: ScrollBar.AlwaysOn
                                            }

                                            WheelHandler {
                                                target: null
                                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                                onWheel: (event) => {
                                                    const step = ScreenTools.defaultFontPixelHeight * 2.2
                                                    const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : (event.pixelDelta ? event.pixelDelta.y : 0)
                                                    if (delta === 0) {
                                                        return
                                                    }
                                                    sensorsTelemetryFlickable.contentY = Math.max(
                                                        0,
                                                        Math.min(
                                                            sensorsTelemetryFlickable.contentHeight - sensorsTelemetryFlickable.height,
                                                            sensorsTelemetryFlickable.contentY - ((delta / 120) * step)
                                                        )
                                                    )
                                                }
                                            }

                                            ColumnLayout {
                                                id: sensorsTelemetryContent
                                                width: Math.max(1, sensorsTelemetryFlickable.width - sensorsTelemetryScrollBar.width - (ScreenTools.defaultFontPixelWidth * 0.1))
                                                spacing: ScreenTools.defaultFontPixelHeight * 0.11

                                                Rectangle {
                                                    id: fcStatusModule
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 4.85
                                            color: sensorsTelemetryPage._moduleColor
                                            radius: sensorsTelemetryPage._blockRadius
                                            border.width: vehicleStatusCard._controlBorderWidth
                                            border.color: vehicleStatusCard._controlBorderColor

                                            ColumnLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.38
                                                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.32
                                                anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.18
                                                anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.18
                                                spacing: ScreenTools.defaultFontPixelHeight * 0.12

                                                QGCLabel {
                                                    Layout.fillWidth: true
                                                    color: vehicleStatusCard._textPrimaryColor
                                                    font.weight: Font.DemiBold
                                                    font.pixelSize: sensorsTelemetryPage._sectionTitleFontSize
                                                    text: qsTr("Flight Controller Status")
                                                }

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    Layout.fillHeight: true
                                                    spacing: ScreenTools.defaultFontPixelWidth * 0.24

                                                    Item {
                                                        Layout.fillWidth: true
                                                        Layout.fillHeight: true

                                                        Rectangle {
                                                            anchors.centerIn: parent
                                                            width: Math.min(parent.width, parent.height)
                                                            height: width
                                                            color: sensorsTelemetryPage._statusCardColor
                                                            radius: sensorsTelemetryPage._blockRadius

                                                            Item {
                                                                anchors.fill: parent
                                                                anchors.margins: ScreenTools.defaultFontPixelHeight * 0.14

                                                                Canvas {
                                                                    id: cpuLoadGaugeCanvas
                                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                                    anchors.top: parent.top
                                                                    width: Math.min(parent.width, parent.height) * 0.56
                                                                    height: width

                                                                    onPaint: {
                                                                        const ctx = getContext("2d")
                                                                        ctx.clearRect(0, 0, width, height)
                                                                        const centerX = width * 0.5
                                                                        const centerY = height * 0.5
                                                                        const radius = Math.min(width, height) * 0.39
                                                                        const progress = Math.max(0, Math.min(1, sensorsTelemetryPage._cpuLoadPercent / 100))

                                                                        ctx.lineCap = "round"
                                                                        ctx.lineWidth = Math.max(2, width * 0.08)
                                                                        ctx.strokeStyle = "rgba(255,255,255,0.14)"
                                                                        ctx.beginPath()
                                                                        ctx.arc(centerX, centerY, radius, -Math.PI / 2, Math.PI * 1.5)
                                                                        ctx.stroke()

                                                                        ctx.strokeStyle = "#20D3BE"
                                                                        ctx.beginPath()
                                                                        ctx.arc(centerX, centerY, radius, -Math.PI / 2, (-Math.PI / 2) + (Math.PI * 2 * progress))
                                                                        ctx.stroke()
                                                                    }
                                                                }

                                                                QGCLabel {
                                                                    anchors.left: parent.left
                                                                    anchors.right: parent.right
                                                                    anchors.bottom: parent.bottom
                                                                    color: vehicleStatusCard._textSecondaryColor
                                                                    font.pixelSize: sensorsTelemetryPage._textFontSize
                                                                    horizontalAlignment: Text.AlignHCenter
                                                                    wrapMode: Text.WordWrap
                                                                    text: qsTr("CPU Load: %1%").arg(Math.round(sensorsTelemetryPage._cpuLoadPercent))
                                                                }
                                                            }
                                                        }
                                                    }

                                                    Item {
                                                        Layout.fillWidth: true
                                                        Layout.fillHeight: true

                                                        Rectangle {
                                                            anchors.centerIn: parent
                                                            width: Math.min(parent.width, parent.height)
                                                            height: width
                                                            color: sensorsTelemetryPage._statusCardColor
                                                            radius: sensorsTelemetryPage._blockRadius

                                                            Item {
                                                                anchors.fill: parent
                                                                anchors.margins: ScreenTools.defaultFontPixelHeight * 0.14

                                                                Rectangle {
                                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                                    anchors.top: parent.top
                                                                    width: Math.min(parent.width, parent.height) * 0.3
                                                                    height: width
                                                                    radius: width * 0.5
                                                                    color: sensorsTelemetryPage._okColor

                                                                    QGCColoredImage {
                                                                        anchors.centerIn: parent
                                                                        width: parent.height * 0.52
                                                                        height: width
                                                                        color: vehicleStatusCard._textPrimaryColor
                                                                        fillMode: Image.PreserveAspectFit
                                                                        source: "/InstrumentValueIcons/checkmark.svg"
                                                                    }
                                                                }

                                                                QGCLabel {
                                                                    anchors.left: parent.left
                                                                    anchors.right: parent.right
                                                                    anchors.bottom: parent.bottom
                                                                    color: vehicleStatusCard._textSecondaryColor
                                                                    font.pixelSize: sensorsTelemetryPage._textFontSize
                                                                    horizontalAlignment: Text.AlignHCenter
                                                                    wrapMode: Text.WordWrap
                                                                    text: qsTr("Log Status: %1").arg(sensorsTelemetryPage._logActive ? qsTr("Active") : qsTr("Inactive"))
                                                                }
                                                            }
                                                        }
                                                    }

                                                    Item {
                                                        Layout.fillWidth: true
                                                        Layout.fillHeight: true

                                                        Rectangle {
                                                            anchors.centerIn: parent
                                                            width: Math.min(parent.width, parent.height)
                                                            height: width
                                                            color: sensorsTelemetryPage._statusCardColor
                                                            radius: sensorsTelemetryPage._blockRadius

                                                            Item {
                                                                anchors.fill: parent
                                                                anchors.margins: ScreenTools.defaultFontPixelHeight * 0.14

                                                                QGCColoredImage {
                                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                                    anchors.top: parent.top
                                                                    width: Math.min(parent.width, parent.height) * 0.28
                                                                    height: width
                                                                    color: sensorsTelemetryPage._healthNominal ? sensorsTelemetryPage._okColor : "#F0BB6C"
                                                                    fillMode: Image.PreserveAspectFit
                                                                    source: "/InstrumentValueIcons/shield.svg"
                                                                }

                                                                QGCLabel {
                                                                    anchors.left: parent.left
                                                                    anchors.right: parent.right
                                                                    anchors.bottom: parent.bottom
                                                                    color: vehicleStatusCard._textSecondaryColor
                                                                    font.pixelSize: sensorsTelemetryPage._textFontSize
                                                                    horizontalAlignment: Text.AlignHCenter
                                                                    wrapMode: Text.WordWrap
                                                                    text: qsTr("Health: %1").arg(sensorsTelemetryPage._healthNominal ? qsTr("Nominal") : qsTr("Attention"))
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            id: telemetryModule
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 7.4
                                            color: sensorsTelemetryPage._moduleColor
                                            radius: sensorsTelemetryPage._blockRadius
                                            border.width: vehicleStatusCard._controlBorderWidth
                                            border.color: vehicleStatusCard._controlBorderColor

                                            ColumnLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.38
                                                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.32
                                                anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.18
                                                anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.18
                                                spacing: ScreenTools.defaultFontPixelHeight * 0.1

                                                QGCLabel {
                                                    Layout.fillWidth: true
                                                    color: vehicleStatusCard._textPrimaryColor
                                                    font.weight: Font.DemiBold
                                                    font.pixelSize: sensorsTelemetryPage._sectionTitleFontSize
                                                    text: qsTr("Sensor Live Telemetry")
                                                }

                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    Layout.fillHeight: true
                                                    color: sensorsTelemetryPage._chartBackgroundColor
                                                    radius: sensorsTelemetryPage._blockRadius

                                                    Canvas {
                                                        id: telemetryWaveCanvas
                                                        anchors.fill: parent

                                                        function drawSeries(ctx, left, top, plotWidth, plotHeight, samples, color) {
                                                            if (!samples || samples.length < 2) {
                                                                return
                                                            }
                                                            let minValue = Number(samples[0])
                                                            let maxValue = Number(samples[0])

                                                            for (let i = 1; i < samples.length; i++) {
                                                                const sampleValue = Number(samples[i])
                                                                if (!isNaN(sampleValue)) {
                                                                    minValue = Math.min(minValue, sampleValue)
                                                                    maxValue = Math.max(maxValue, sampleValue)
                                                                }
                                                            }

                                                            if (isNaN(minValue) || isNaN(maxValue)) {
                                                                return
                                                            }
                                                            if (Math.abs(maxValue - minValue) < 0.0001) {
                                                                maxValue += 0.5
                                                                minValue -= 0.5
                                                            }

                                                            const padding = (maxValue - minValue) * 0.18
                                                            minValue -= padding
                                                            maxValue += padding
                                                            const valueSpan = Math.max(maxValue - minValue, 0.001)

                                                            ctx.beginPath()
                                                            for (let i = 0; i < samples.length; i++) {
                                                                const sampleValue = Number(samples[i])
                                                                const x = left + ((plotWidth * i) / Math.max(samples.length - 1, 1))
                                                                const normalized = (sampleValue - minValue) / valueSpan
                                                                const y = top + plotHeight - (normalized * plotHeight)
                                                                if (i === 0) {
                                                                    ctx.moveTo(x, y)
                                                                } else {
                                                                    ctx.lineTo(x, y)
                                                                }
                                                            }
                                                            ctx.strokeStyle = color
                                                            ctx.lineWidth = 2
                                                            ctx.lineJoin = "round"
                                                            ctx.lineCap = "round"
                                                            ctx.stroke()
                                                        }

                                                        onPaint: {
                                                            const ctx = getContext("2d")
                                                            ctx.clearRect(0, 0, width, height)

                                                            const left = ScreenTools.defaultFontPixelWidth * 0.42
                                                            const right = ScreenTools.defaultFontPixelWidth * 0.32
                                                            const top = ScreenTools.defaultFontPixelHeight * 0.3
                                                            const bottom = ScreenTools.defaultFontPixelHeight * 0.28
                                                            const plotWidth = Math.max(1, width - left - right)
                                                            const plotHeight = Math.max(1, height - top - bottom)

                                                            ctx.strokeStyle = "rgba(255,255,255,0.10)"
                                                            ctx.lineWidth = 1

                                                            for (let column = 0; column <= 6; column++) {
                                                                const x = left + ((plotWidth * column) / 6)
                                                                ctx.beginPath()
                                                                ctx.moveTo(x, top)
                                                                ctx.lineTo(x, top + plotHeight)
                                                                ctx.stroke()
                                                            }

                                                            for (let row = 0; row <= 4; row++) {
                                                                const y = top + ((plotHeight * row) / 4)
                                                                ctx.beginPath()
                                                                ctx.moveTo(left, y)
                                                                ctx.lineTo(left + plotWidth, y)
                                                                ctx.stroke()
                                                            }

                                                            drawSeries(ctx, left, top, plotWidth, plotHeight, sensorsTelemetryPage._gyroSeries, "#4EA6FF")
                                                            drawSeries(ctx, left, top, plotWidth, plotHeight, sensorsTelemetryPage._accelSeries, "#FF696E")
                                                            drawSeries(ctx, left, top, plotWidth, plotHeight, sensorsTelemetryPage._magSeries, "#56D38A")
                                                            drawSeries(ctx, left, top, plotWidth, plotHeight, sensorsTelemetryPage._baroSeries, "#F2C94C")
                                                        }
                                                    }
                                                }

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: ScreenTools.defaultFontPixelWidth * 0.2

                                                    Repeater {
                                                        model: [
                                                            { "label": qsTr("IMU Gyro"),       "color": "#4EA6FF" },
                                                            { "label": qsTr("IMU Accel"),      "color": "#FF696E" },
                                                            { "label": qsTr("Magnetometer"),   "color": "#56D38A" },
                                                            { "label": qsTr("Barometer"),      "color": "#F2C94C" }
                                                        ]

                                                        delegate: RowLayout {
                                                                                        Layout.fillWidth: true
                                                            spacing: ScreenTools.defaultFontPixelWidth * 0.12

                                                            Rectangle {
                                                                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 0.82
                                                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 0.12
                                                                color: modelData.color
                                                                radius: height * 0.5
                                                            }

                                                            QGCLabel {
                                                                Layout.fillWidth: true
                                                                color: vehicleStatusCard._textSecondaryColor
                                                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5
                                                                elide: Text.ElideRight
                                                                text: modelData.label
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            id: sensorHealthModule
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 7.8
                                            color: sensorsTelemetryPage._moduleColor
                                            radius: sensorsTelemetryPage._blockRadius
                                            border.width: vehicleStatusCard._controlBorderWidth
                                            border.color: vehicleStatusCard._controlBorderColor

                                            ColumnLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.38
                                                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.32
                                                anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.18
                                                anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.18
                                                spacing: ScreenTools.defaultFontPixelHeight * 0.1

                                                QGCLabel {
                                                    Layout.fillWidth: true
                                                    color: vehicleStatusCard._textPrimaryColor
                                                    font.weight: Font.DemiBold
                                                    font.pixelSize: sensorsTelemetryPage._sectionTitleFontSize
                                                    text: qsTr("Sensor Health Summary")
                                                }

                                                GridLayout {
                                                    Layout.fillWidth: true
                                                    Layout.fillHeight: true
                                                    columns: 2
                                                    rowSpacing: ScreenTools.defaultFontPixelHeight * 0.12
                                                    columnSpacing: ScreenTools.defaultFontPixelWidth * 0.22

                                                    Repeater {
                                                        model: sensorsTelemetryPage._summaryModel

                                                        delegate: Rectangle {
                                                            id: summaryCard
                                                                                        readonly property bool _healthy: root._sensorBitHealthy(root._activeVehicle, modelData.bit)

                                                            Layout.fillWidth: true
                                                            Layout.fillHeight: true
                                                            color: sensorsTelemetryPage._summaryCardColor
                                                            radius: sensorsTelemetryPage._blockRadius
                                                            border.width: vehicleStatusCard._controlBorderWidth
                                                            border.color: vehicleStatusCard._controlBorderColor

                                                            RowLayout {
                                                                anchors.fill: parent
                                                                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.3
                                                                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.24
                                                                anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.12
                                                                anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.12
                                                                spacing: ScreenTools.defaultFontPixelWidth * 0.2

                                                                ColumnLayout {
                                                                    Layout.fillWidth: true
                                                                    spacing: ScreenTools.defaultFontPixelHeight * 0.03

                                                                    QGCLabel {
                                                                        color: vehicleStatusCard._textPrimaryColor
                                                                        font.pixelSize: sensorsTelemetryPage._valueFontSize
                                                                        font.weight: Font.DemiBold
                                                                        text: modelData.title
                                                                    }

                                                                    QGCLabel {
                                                                        color: summaryCard._healthy ? sensorsTelemetryPage._okColor : "#F0BB6C"
                                                                        font.pixelSize: sensorsTelemetryPage._textFontSize
                                                                        text: qsTr("Status: %1").arg(root._sensorStatusTextForBit(root._activeVehicle, modelData.bit, modelData.goodText, modelData.badText, qsTr("Offline")))
                                                                    }

                                                                    QGCLabel {
                                                                        visible: modelData.detail === "sat"
                                                                        color: vehicleStatusCard._textSecondaryColor
                                                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5
                                                                        text: qsTr("Satellites: %1").arg(root._sensorGpsSatelliteText(root._activeVehicle))
                                                                    }
                                                                }

                                                                Rectangle {
                                                                    Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.62
                                                                    Layout.preferredHeight: Layout.preferredWidth
                                                                    radius: Layout.preferredWidth * 0.5
                                                                    color: summaryCard._healthy ? sensorsTelemetryPage._okColor : "#F0BB6C"

                                                                    QGCColoredImage {
                                                                        anchors.centerIn: parent
                                                                        width: parent.height * 0.52
                                                                        height: width
                                                                        color: vehicleStatusCard._textPrimaryColor
                                                                        fillMode: Image.PreserveAspectFit
                                                                        source: summaryCard._healthy ? "/InstrumentValueIcons/checkmark.svg" : "/InstrumentValueIcons/exclamation-outline.svg"
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Item {
                                    id: flyPrepBatteryPage
                                    clip: true

                                    function _rowLabel(rowIndex) {
                                        switch (rowIndex) {
                                        case 0: return qsTr("Remaining Flight Time")
                                        case 1: return qsTr("Remaining Mission Time")
                                        case 2: return qsTr("Home")
                                        case 3: return qsTr("GPS")
                                        case 4: return qsTr("EKF")
                                        case 5: return qsTr("Link")
                                        case 6: return qsTr("RTL Safety")
                                        default: return ""
                                        }
                                    }
                                    function _rowValue(rowIndex) {
                                        const remainingFlightSeconds = root._remainingFlightSeconds(root._activeVehicle)
                                        const remainingMissionSeconds = root._missionRemainingSeconds(root._activeVehicle)
                                        const gpsPercent = root._networkGpsPercent(root._activeVehicle)
                                        const telemetryPercent = root._communicationTelemetryQualityPercent(root._activeVehicle)
                                        const distanceHomeMeters = root._distanceToHomeMeters(root._activeVehicle)
                                        switch (rowIndex) {
                                        case 0:
                                            return root._formatDurationClock(remainingFlightSeconds)
                                        case 1:
                                            return root._formatDurationClock(remainingMissionSeconds)
                                        case 2:
                                            if (!root._homeIsValid(root._activeVehicle)) {
                                                return qsTr("Not Set")
                                            }
                                            return isNaN(distanceHomeMeters)
                                                ? qsTr("Set")
                                                : qsTr("Set | %1 m").arg(Math.round(distanceHomeMeters))
                                        case 3:
                                            return isNaN(gpsPercent)
                                                ? qsTr("No Data")
                                                : qsTr("%1 | %2 sats").arg(root._networkStatusText(gpsPercent)).arg(root._networkSatelliteText(root._activeVehicle))
                                        case 4:
                                            return root._ekfStatusText(root._activeVehicle)
                                        case 5:
                                            return isNaN(telemetryPercent)
                                                ? qsTr("No Data")
                                                : qsTr("%1 | %2%").arg(root._communicationTelemetryStatusText(telemetryPercent)).arg(Math.round(telemetryPercent))
                                        case 6:
                                            return root._rtlSafetyText(root._activeVehicle)
                                        default:
                                            return "--"
                                        }
                                    }
                                    function _rowLevel(rowIndex) {
                                        const remainingFlightSeconds = root._remainingFlightSeconds(root._activeVehicle)
                                        const remainingMissionSeconds = root._missionRemainingSeconds(root._activeVehicle)
                                        const gpsPercent = root._networkGpsPercent(root._activeVehicle)
                                        const telemetryPercent = root._communicationTelemetryQualityPercent(root._activeVehicle)
                                        switch (rowIndex) {
                                        case 0:
                                            return isNaN(remainingFlightSeconds) ? 1 : (remainingFlightSeconds <= 120 ? 2 : (remainingFlightSeconds <= 300 ? 1 : 0))
                                        case 1:
                                            return (isNaN(remainingMissionSeconds) || isNaN(remainingFlightSeconds))
                                                ? 1
                                                : (remainingMissionSeconds > (remainingFlightSeconds * 0.95) ? 2 : (remainingMissionSeconds > (remainingFlightSeconds * 0.7) ? 1 : 0))
                                        case 2:
                                            return root._homeIsValid(root._activeVehicle) ? 0 : 2
                                        case 3:
                                            return isNaN(gpsPercent) ? 1 : (gpsPercent < 35 ? 2 : (gpsPercent < 60 ? 1 : 0))
                                        case 4:
                                            return root._ekfStatusLevel(root._activeVehicle)
                                        case 5:
                                            return isNaN(telemetryPercent) ? 1 : (telemetryPercent < 35 ? 2 : (telemetryPercent < 60 ? 1 : 0))
                                        case 6:
                                            return root._rtlSafetyLevel(root._activeVehicle)
                                        default:
                                            return 1
                                        }
                                    }

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: vehicleStatusCard._sectionContentLeftMargin
                                        anchors.rightMargin: vehicleStatusCard._sectionContentRightMargin
                                        anchors.topMargin: vehicleStatusCard._sectionContentTopMargin
                                        anchors.bottomMargin: vehicleStatusCard._sectionContentBottomMargin
                                        spacing: ScreenTools.defaultFontPixelHeight * 0.16

                                        QGCLabel {
                                            Layout.fillWidth: true
                                            color: vehicleStatusCard._textPrimaryColor
                                            font.weight: Font.DemiBold
                                            font.pixelSize: vehicleStatusCard._sectionHeaderTitleSize
                                            text: qsTr("FLY PREP")
                                        }

                                        Repeater {
                                            model: 7

                                            delegate: Rectangle {
                                                required property int index
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.16
                                                color: vehicleStatusCard._blockColor
                                                radius: vehicleStatusCard._controlRadius
                                                border.width: vehicleStatusCard._controlBorderWidth
                                                border.color: vehicleStatusCard._controlBorderColor

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.26
                                                    anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.26
                                                    spacing: ScreenTools.defaultFontPixelWidth * 0.24

                                                    Rectangle {
                                                        Layout.alignment: Qt.AlignVCenter
                                                        Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.4
                                                        Layout.preferredHeight: Layout.preferredWidth
                                                        radius: Layout.preferredWidth * 0.5
                                                        color: root._summaryStateColor(flyPrepBatteryPage._rowLevel(index))
                                                    }

                                                    QGCLabel {
                                                        Layout.fillWidth: true
                                                        color: vehicleStatusCard._textSecondaryColor
                                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.56
                                                        elide: Text.ElideRight
                                                        text: flyPrepBatteryPage._rowLabel(index)
                                                    }

                                                    QGCLabel {
                                                        color: root._summaryStateColor(flyPrepBatteryPage._rowLevel(index))
                                                        font.weight: Font.DemiBold
                                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.56
                                                        elide: Text.ElideRight
                                                        text: flyPrepBatteryPage._rowValue(index)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Repeater {
                                    model: vehicleStatusCard._statusPages.slice(7)

                                    delegate: Item {
                                                clip: true

                                        Flickable {
                                            anchors.fill: parent
                                            contentWidth: width
                                            contentHeight: placeholderColumn.implicitHeight
                                            boundsBehavior: Flickable.StopAtBounds
                                            flickableDirection: Flickable.VerticalFlick
                                            clip: true
                                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                                            ColumnLayout {
                                                id: placeholderColumn
                                                width: Math.min(parent.width - (ScreenTools.defaultFontPixelWidth * 1.8), ScreenTools.defaultFontPixelWidth * 18)
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                y: Math.max(ScreenTools.defaultFontPixelHeight * 0.72, (parent.height - implicitHeight) * 0.5)
                                                spacing: ScreenTools.defaultFontPixelHeight * 0.35

                                            QGCColoredImage {
                                                Layout.alignment: Qt.AlignHCenter
                                                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 2.0
                                                Layout.preferredHeight: Layout.preferredWidth
                                                color: vehicleStatusCard._highlightColor
                                                fillMode: Image.PreserveAspectFit
                                                source: modelData.icon
                                            }

                                            QGCLabel {
                                                Layout.alignment: Qt.AlignHCenter
                                                color: vehicleStatusCard._textPrimaryColor
                                                font.weight: Font.DemiBold
                                                text: modelData.title
                                            }

                                            QGCLabel {
                                                Layout.alignment: Qt.AlignHCenter
                                                color: vehicleStatusCard._textSecondaryColor
                                                horizontalAlignment: Text.AlignHCenter
                                                text: qsTr("This section is reserved for %1").arg(modelData.title)
                                                wrapMode: Text.WordWrap
                                            }
                                        }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

        }

        Item {
            id: rightPane
            anchors.left: leftPane.right
            anchors.leftMargin: root._margin
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            Rectangle {
                id: mapPanel
                x: 0
                y: 0
                width: parent ? parent.width : 0
                height: {
                    const parentHeight = Number(parent ? parent.height : 0)
                    const profileHeight = Number(profilePanel.height)
                    const safeParentHeight = isNaN(parentHeight) ? 0 : parentHeight
                    const safeProfileHeight = isNaN(profileHeight) ? root._profilePanelTargetHeight : profileHeight
                    return Math.max(0, safeParentHeight - safeProfileHeight - 1)
                }
                color: qgcPal.windowShadeDark
                radius: root._radius
                clip: true

                FlyViewMap {
                    id: mapView
                    anchors.fill: parent
                    mapName: "FlyIntegratedMap"
                    pipMode: false
                    showMissionPaths: root._showFlightPath
                    planMasterController: planControllerInternal
                    rightPanelWidth: 0
                    toolInsets: toolInsets
                }

                Connections {
                    target: mapView
                    ignoreUnknownSignals: true

                    function onMapPanStart() {
                        root._mapNavigationSelection = "pan"
                    }
                }

                Item {
                    id: floatingMapStripAnchor
                    anchors.left: parent.left
                    anchors.leftMargin: root._margin
                    y: Math.max(root._margin, (parent.height - floatingMapStrip._expandedHeight) * 0.5)
                    width: 1
                    height: 1
                }

                Rectangle {
                    id: floatingMapStrip
                    anchors.left: floatingMapStripAnchor.left
                    y: floatingMapStripAnchor.y
                    readonly property real _buttonHeight: ScreenTools.defaultFontPixelHeight * 2.18
                    readonly property real _toggleButtonSize: ScreenTools.defaultFontPixelHeight * 1.36
                    readonly property real _innerMargin: ScreenTools.defaultFontPixelHeight * 0.16
                    readonly property real _expandedWidth: ScreenTools.defaultFontPixelHeight * 2.75
                    readonly property real _collapsedWidth: (_innerMargin * 2) + _toggleButtonSize
                    readonly property real _expandedHeight: stripButtonColumn.implicitHeight + (ScreenTools.defaultFontPixelHeight * 0.38)
                    readonly property real _collapsedHeight: (_innerMargin * 2) + _toggleButtonSize + (ScreenTools.defaultFontPixelHeight * 0.38)
                    width: root._mapStripExpanded ? _expandedWidth : _collapsedWidth
                    height: root._mapStripExpanded ? _expandedHeight : _collapsedHeight
                    color: Qt.rgba(0.06, 0.06, 0.07, 0.9)
                    radius: ScreenTools.defaultFontPixelHeight * 0.18
                    clip: true

                    Behavior on width {
                        NumberAnimation { duration: 180; easing.type: Easing.InOutCubic }
                    }
                    Behavior on height {
                        NumberAnimation { duration: 180; easing.type: Easing.InOutCubic }
                    }

                    ColumnLayout {
                        id: stripButtonColumn
                        anchors.fill: parent
                        anchors.margins: floatingMapStrip._innerMargin
                        spacing: ScreenTools.defaultFontPixelHeight * 0.12

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: floatingMapStrip._toggleButtonSize
                            Layout.preferredHeight: floatingMapStrip._toggleButtonSize
                            color: stripToggleMouseArea.pressed ? "#1A1C1F" : "#121315"
                            radius: ScreenTools.defaultFontPixelHeight * 0.18
                            border.color: Qt.rgba(1, 1, 1, 0.12)
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: root._mapStripExpanded ? "<" : ">"
                                color: "#FFFFFF"
                                font.pixelSize: parent.height * 0.62
                                font.bold: true
                                renderType: Text.NativeRendering
                            }

                            QGCMouseArea {
                                id: stripToggleMouseArea
                                anchors.fill: parent
                                onClicked: root._mapStripExpanded = !root._mapStripExpanded
                            }
                        }

                        Repeater {
                            model: [
                                { "key": "traffic",   "icon": "/InstrumentValueIcons/border-outer.svg",   "accent": true,  "requiresVehicle": false, "slashed": false },
                                { "key": "list",      "icon": "/InstrumentValueIcons/clipboard.svg",      "accent": false, "requiresVehicle": false, "slashed": false },
                                { "key": "orbit",     "icon": "/InstrumentValueIcons/reload.svg",         "accent": false, "requiresVehicle": false, "slashed": false },
                                { "key": "lockOrbit", "icon": "/InstrumentValueIcons/reload.svg",         "accent": false, "requiresVehicle": false, "slashed": true  },
                                { "key": "up",        "icon": "/InstrumentValueIcons/arrow-base-up.svg",  "accent": false, "requiresVehicle": true,  "slashed": false },
                                { "key": "down",      "icon": "/InstrumentValueIcons/arrow-base-down.svg","accent": false, "requiresVehicle": true,  "slashed": false },
                                { "key": "rtl",       "icon": "/res/rtl.svg",                             "accent": false, "requiresVehicle": true,  "slashed": false },
                                { "key": "play",      "icon": "/InstrumentValueIcons/play-outline.svg",   "accent": false, "requiresVehicle": true,  "slashed": false, "visible": guidedActionsController.showContinueMission },
                                { "key": "pause",     "icon": "/InstrumentValueIcons/pause-outline.svg",  "accent": false, "requiresVehicle": true,  "slashed": false },
                                { "key": "pan",       "icon": "/InstrumentValueIcons/map-pan.svg",       "accent": false, "requiresVehicle": false, "slashed": false },
                                { "key": "locate",    "icon": "/InstrumentValueIcons/map-follow.svg",    "accent": false, "requiresVehicle": true, "slashed": false }
                            ]

                            delegate: Rectangle {
                                required property var modelData

                                visible: modelData.visible === undefined ? true : !!modelData.visible
                                readonly property bool _isStartMission: modelData.key === "startMission"
                                readonly property bool _enabled: root._isMapStripActionEnabled(modelData.key, modelData.requiresVehicle)
                                readonly property bool _selected: root._isMapStripSelected(modelData.key)

                                Layout.fillWidth: true
                                Layout.preferredHeight: visible
                                    ? (_isStartMission ? floatingMapStrip._buttonHeight * 1.08 : floatingMapStrip._buttonHeight)
                                    : 0
                                color: _selected
                                    ? "#2F6FC7"
                                    : (_isStartMission
                                        ? (stripMouseArea.pressed ? "#9A3412" : "#EA580C")
                                        : (stripMouseArea.pressed ? "#1A1C1F" : "#121315"))
                                opacity: root._mapStripExpanded ? (_enabled ? 1 : 0.42) : 0
                                radius: ScreenTools.defaultFontPixelHeight * 0.18
                                border.width: _isStartMission ? 2 : 0
                                border.color: _isStartMission ? Qt.rgba(1, 1, 1, 0.28) : "transparent"

                                Item {
                                    anchors.fill: parent

                                    QGCColoredImage {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.verticalCenterOffset: _isStartMission ? -(ScreenTools.defaultFontPixelHeight * 0.18) : 0
                                        width: parent.height * (_isStartMission ? 0.46 : 0.42)
                                        height: width
                                        color: _isStartMission ? "#FFF7ED" : "#FFFFFF"
                                        fillMode: Image.PreserveAspectFit
                                        source: modelData.icon
                                    }

                                    QGCLabel {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.12
                                        visible: _isStartMission
                                        text: qsTr("START")
                                        color: "#FFF7ED"
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.42
                                        font.bold: true
                                    }

                                    Rectangle {
                                        visible: _isStartMission
                                        anchors.top: parent.top
                                        anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.12
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: parent.width * 0.52
                                        height: ScreenTools.defaultFontPixelHeight * 0.1
                                        radius: height / 2
                                        color: Qt.rgba(1, 1, 1, 0.28)
                                    }

                                    Rectangle {
                                        visible: modelData.slashed
                                        anchors.centerIn: parent
                                        width: parent.height * 0.52
                                        height: ScreenTools.defaultFontPixelHeight * 0.1
                                        radius: height / 2
                                        color: "#FFFFFF"
                                        rotation: -32
                                    }
                                }

                                QGCMouseArea {
                                    id: stripMouseArea
                                    anchors.fill: parent
                                    enabled: root._mapStripExpanded && parent._enabled
                                    onClicked: root._triggerMapStripAction(modelData.key)
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: floatingMapStripToggleHandle
                    anchors.left: floatingMapStrip.right
                    anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.15
                    anchors.verticalCenter: floatingMapStrip.verticalCenter
                    width: ScreenTools.defaultFontPixelHeight * 1.05
                    height: ScreenTools.defaultFontPixelHeight * 1.9
                    color: Qt.rgba(0.08, 0.08, 0.09, 0.95)
                    radius: width * 0.45
                    border.color: Qt.rgba(1, 1, 1, 0.14)
                    border.width: 1
                    z: QGroundControl.zOrderWidgets + 1

                    Text {
                        anchors.centerIn: parent
                        text: root._mapStripExpanded ? "<" : ">"
                        color: "#FFFFFF"
                        font.pixelSize: parent.width * 0.78
                        font.bold: true
                        renderType: Text.NativeRendering
                    }

                    QGCMouseArea {
                        anchors.fill: parent
                        onClicked: root._mapStripExpanded = !root._mapStripExpanded
                    }
                }

                Rectangle {
                    id: compactReadinessPanel
                    x: floatingMapStripToggleHandle.x + floatingMapStripToggleHandle.width + (root._margin * 0.7)
                    y: parent.height - height - root._margin
                    width: Math.min(ScreenTools.defaultFontPixelWidth * 28, Math.max(ScreenTools.defaultFontPixelWidth * 18, parent.width * 0.34))
                    height: readinessContent.implicitHeight + (ScreenTools.defaultFontPixelHeight * 0.6)
                    color: Qt.rgba(0.08, 0.08, 0.09, 0.93)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    radius: ScreenTools.defaultFontPixelHeight * 0.16
                    z: QGroundControl.zOrderTopMost + 2

                    ColumnLayout {
                        id: readinessContent
                        anchors.fill: parent
                        anchors.margins: ScreenTools.defaultFontPixelHeight * 0.3
                        spacing: ScreenTools.defaultFontPixelHeight * 0.1

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: ScreenTools.defaultFontPixelWidth * 0.22

                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.42
                                Layout.preferredHeight: Layout.preferredWidth
                                radius: Layout.preferredWidth * 0.5
                                color: root._compactReadinessColor(root._activeVehicle)
                            }

                            QGCLabel {
                                color: "#D7DBDF"
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5
                                text: qsTr("Status")
                            }

                            QGCLabel {
                                color: root._compactReadinessColor(root._activeVehicle)
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                                font.weight: Font.DemiBold
                                text: root._compactReadinessText(root._activeVehicle)
                            }
                        }

                        QGCLabel {
                            Layout.fillWidth: true
                            color: "#EEF1F4"
                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.56
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            text: root._compactPrearmReason(root._activeVehicle)
                        }
                    }
                }

                Rectangle {
                    id: trafficViewPanel
                    anchors.left: floatingMapStrip.right
                    anchors.leftMargin: root._margin * 0.9
                    anchors.top: floatingMapStripAnchor.top
                    width: root._compactVideoOverlayWidth(parent.width) * 0.86
                    height: width * 0.75
                    visible: root._trafficViewVisible
                    color: Qt.rgba(0.07, 0.07, 0.08, 0.95)
                    border.color: Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    radius: ScreenTools.defaultFontPixelHeight * 0.18
                    clip: true
                    z: QGroundControl.zOrderWidgets

                    property var _adsbModel: QGroundControl.adsbVehicleManager ? QGroundControl.adsbVehicleManager.adsbVehicles : null
                    property var _referenceCoordinate: null
                    property int trafficCount: 0
                    property real displayRangeMeters: 2000
                    readonly property real _headerHeight: ScreenTools.defaultFontPixelHeight * 1.26
                    readonly property real _plotLeft: ScreenTools.defaultFontPixelWidth * 1.2
                    readonly property real _plotRight: ScreenTools.defaultFontPixelWidth * 0.75
                    readonly property real _plotTop: _headerHeight + (ScreenTools.defaultFontPixelHeight * 0.14)
                    readonly property real _plotBottom: ScreenTools.defaultFontPixelHeight * 0.72
                    readonly property real _plotWidth: Math.max(width - _plotLeft - _plotRight, 1)
                    readonly property real _plotHeight: Math.max(height - _plotTop - _plotBottom, 1)

                    function refresh() {
                        const adsbModel = _adsbModel
                        const referenceCoordinate = root._vehicleHasPosition(root._activeVehicle) ? root._activeVehicle.coordinate : null
                        let farthestDistance = 0
                        let validTrafficCount = 0

                        _referenceCoordinate = referenceCoordinate

                        if (adsbModel) {
                            for (let i = 0; i < adsbModel.count; i++) {
                                const trafficVehicle = adsbModel.get(i)
                                if (!trafficVehicle || !trafficVehicle.coordinate || !trafficVehicle.coordinate.isValid) {
                                    continue
                                }
                                validTrafficCount++
                                if (referenceCoordinate) {
                                    farthestDistance = Math.max(farthestDistance, referenceCoordinate.distanceTo(trafficVehicle.coordinate))
                                }
                            }
                        }

                        trafficCount = validTrafficCount
                        displayRangeMeters = root._trafficRangeStep(Math.max(farthestDistance * 1.15, 800))
                        trafficGrid.requestPaint()
                    }

                    function relativeTrafficPoint(trafficVehicle) {
                        if (!_referenceCoordinate || !trafficVehicle || !trafficVehicle.coordinate || !trafficVehicle.coordinate.isValid) {
                            return { "valid": false, "x": 0, "y": 0, "distance": NaN }
                        }

                        const distance = _referenceCoordinate.distanceTo(trafficVehicle.coordinate)
                        const azimuthRadians = _referenceCoordinate.azimuthTo(trafficVehicle.coordinate) * Math.PI / 180
                        const eastOffset = Math.sin(azimuthRadians) * distance
                        const northOffset = Math.cos(azimuthRadians) * distance
                        const xRatio = Math.max(-1, Math.min(1, eastOffset / Math.max(displayRangeMeters, 1)))
                        const yRatio = Math.max(-1, Math.min(1, northOffset / Math.max(displayRangeMeters, 1)))

                        return {
                            "valid": true,
                            "x": _plotLeft + (_plotWidth * 0.5) + (xRatio * _plotWidth * 0.5),
                            "y": _plotTop + (_plotHeight * 0.5) - (yRatio * _plotHeight * 0.5),
                            "distance": distance
                        }
                    }

                    function trafficColor(trafficVehicle, trafficPoint) {
                        if (trafficVehicle && trafficVehicle.alert) {
                            return "#FF6B55"
                        }
                        if (trafficPoint.valid && trafficPoint.distance <= Math.max(displayRangeMeters * 0.35, 450)) {
                            return "#D98C4D"
                        }
                        return "#89E0B5"
                    }

                    onVisibleChanged: {
                        if (visible) {
                            refresh()
                        }
                    }
                    onDisplayRangeMetersChanged: trafficGrid.requestPaint()
                    onWidthChanged: trafficGrid.requestPaint()
                    onHeightChanged: trafficGrid.requestPaint()

                    Timer {
                        interval: 700
                        repeat: true
                        running: trafficViewPanel.visible
                        triggeredOnStart: true
                        onTriggered: trafficViewPanel.refresh()
                    }

                    Connections {
                        target: trafficViewPanel._adsbModel
                        ignoreUnknownSignals: true
                        function onCountChanged() { trafficViewPanel.refresh() }
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.AllButtons
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: trafficViewPanel._headerHeight
                        color: Qt.rgba(0.10, 0.10, 0.11, 0.98)

                        QGCLabel {
                            anchors.left: parent.left
                            anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.72
                            anchors.verticalCenter: parent.verticalCenter
                            color: "#E8E8E8"
                            font.weight: Font.DemiBold
                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.62
                            text: qsTr("TRAFFIC VIEW")
                        }

                        QGCLabel {
                            anchors.right: parent.right
                            anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.68
                            anchors.verticalCenter: parent.verticalCenter
                            color: "#5FB5FF"
                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.46
                            text: trafficViewPanel.trafficCount > 0
                                ? qsTr("%1 LIVE").arg(trafficViewPanel.trafficCount)
                                : qsTr("LIVE")
                        }
                    }

                    Canvas {
                        id: trafficGrid
                        anchors.fill: parent

                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)

                            const left = trafficViewPanel._plotLeft
                            const top = trafficViewPanel._plotTop
                            const plotWidth = trafficViewPanel._plotWidth
                            const plotHeight = trafficViewPanel._plotHeight

                            ctx.strokeStyle = "rgba(255,255,255,0.05)"
                            ctx.lineWidth = 1

                            for (let i = 0; i <= 5; i++) {
                                const x = left + ((plotWidth * i) / 5)
                                ctx.beginPath()
                                ctx.moveTo(x, top)
                                ctx.lineTo(x, top + plotHeight)
                                ctx.stroke()
                            }

                            for (let i = 0; i <= 4; i++) {
                                const y = top + ((plotHeight * i) / 4)
                                ctx.beginPath()
                                ctx.moveTo(left, y)
                                ctx.lineTo(left + plotWidth, y)
                                ctx.stroke()
                            }
                        }
                    }

                    Rectangle {
                        width: ScreenTools.defaultFontPixelHeight * 0.36
                        height: width
                        radius: width / 2
                        color: "#49A7FF"
                        opacity: trafficViewPanel._referenceCoordinate ? 0.85 : 0
                        x: trafficViewPanel._plotLeft + (trafficViewPanel._plotWidth * 0.5) - (width * 0.5)
                        y: trafficViewPanel._plotTop + (trafficViewPanel._plotHeight * 0.5) - (height * 0.5)
                    }

                    Repeater {
                        model: trafficViewPanel._adsbModel

                        delegate: Item {
                            required property var object

                            readonly property var trafficPoint: trafficViewPanel.relativeTrafficPoint(object)
                            readonly property color pointColor: trafficViewPanel.trafficColor(object, trafficPoint)

                            visible: trafficPoint.valid
                            width: ScreenTools.defaultFontPixelHeight * 0.56
                            height: width
                            x: trafficPoint.x - (width * 0.5)
                            y: trafficPoint.y - (height * 0.5)

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: pointColor
                                border.width: 1
                                border.color: Qt.lighter(pointColor, 1.25)
                            }
                        }
                    }

                    QGCLabel {
                        anchors.left: parent.left
                        anchors.leftMargin: trafficViewPanel._plotLeft
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.18
                        color: "#7C8794"
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.46
                        text: qsTr("Range %1 km").arg((trafficViewPanel.displayRangeMeters / 1000).toFixed(1))
                    }

                    QGCLabel {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: ScreenTools.defaultFontPixelHeight * 0.18
                        visible: trafficViewPanel.trafficCount === 0 || !trafficViewPanel._referenceCoordinate
                        width: trafficViewPanel.width * 0.68
                        color: "#9CA3AF"
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.64
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: trafficViewPanel.trafficCount === 0
                            ? qsTr("Waiting for live traffic data")
                            : qsTr("Traffic detected. Waiting for vehicle position")
                    }
                }

                Rectangle {
                    id: instrumentPanel
                    anchors.left: floatingMapStrip.right
                    anchors.leftMargin: root._margin * 0.9
                    anchors.top: floatingMapStripAnchor.top
                    width: Math.min(parent.width * 0.46, ScreenTools.defaultFontPixelWidth * 56)
                    height: Math.min(parent.height - (root._margin * 2), ScreenTools.defaultFontPixelHeight * 31)
                    visible: root._instrumentPanelVisible
                    color: Qt.rgba(0.12, 0.12, 0.13, 0.96)
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1
                    radius: ScreenTools.defaultFontPixelHeight * 0.18
                    clip: true
                    z: QGroundControl.zOrderWidgets

                    property var _vehicle: root._activeVehicle
                    property var _activeBattery: root._activeBatteryForVehicle(_vehicle)
                    property var flightTimeFact: _vehicle ? _vehicle.getFact("flightTime") : null
                    property var batteryFact: _activeBattery ? _activeBattery.percentRemaining : null
                    property var altitudeFact: _vehicle ? _vehicle.altitudeRelative : null
                    property var headingFact: _vehicle ? _vehicle.heading : null
                    property var airSpeedFact: _vehicle ? _vehicle.airSpeed : null
                    property var climbRateFact: _vehicle ? _vehicle.climbRate : null
                    readonly property bool hasTurnValue: _vehicle && root._hasFactValue(_vehicle.roll)
                    readonly property real turnValue: hasTurnValue ? Number(_vehicle.roll.rawValue) : 0
                    readonly property real turnNeedleRotation: Math.max(-45, Math.min(45, turnValue))
                    readonly property bool hasClimbRate: root._hasFactValue(climbRateFact)
                    readonly property real climbRate: hasClimbRate ? Number(climbRateFact.rawValue) : 0
                    readonly property real verticalNeedleRotation: Math.max(-120, Math.min(120, climbRate * 35))
                    readonly property bool hasAirspeed: root._hasFactValue(airSpeedFact)
                    readonly property real airSpeedValue: hasAirspeed ? Math.max(0, Number(airSpeedFact.rawValue)) : 0
                    readonly property real airSpeedNeedleRotation: Math.max(-125, Math.min(125, (airSpeedValue / 20) * 250 - 125))
                    readonly property real _dialTitleSpacing: ScreenTools.defaultFontPixelHeight * 0.05
                    readonly property real _dialTopPull: ScreenTools.defaultFontPixelHeight * 0.12

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: ScreenTools.defaultFontPixelHeight * 0.34
                        spacing: ScreenTools.defaultFontPixelHeight * 0.24

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.35

                            QGCLabel {
                                text: qsTr("INSTRUMENTS")
                                color: "#ECECEC"
                                font.weight: Font.DemiBold
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.72
                            }

                            Item { Layout.fillWidth: true }

                            QGCColoredImage {
                                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.72
                                Layout.preferredHeight: Layout.preferredWidth
                                color: "#C8C9CB"
                                fillMode: Image.PreserveAspectFit
                                source: "/InstrumentValueIcons/cog.svg"
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.5
                            spacing: ScreenTools.defaultFontPixelWidth * 0.24

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: Qt.rgba(1, 1, 1, 0.06)
                                radius: ScreenTools.defaultFontPixelHeight * 0.08

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: ScreenTools.defaultFontPixelHeight * 0.26
                                    spacing: ScreenTools.defaultFontPixelWidth * 0.22

                                    QGCLabel {
                                        Layout.fillWidth: true
                                        color: "#D8D9DA"
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.68
                                        text: qsTr("Flight Time")
                                    }

                                    QGCLabel {
                                        color: "#EFEFEF"
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.74
                                        font.weight: Font.DemiBold
                                        text: root._formatElapsedTime(instrumentPanel.flightTimeFact)
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: Qt.rgba(1, 1, 1, 0.06)
                                radius: ScreenTools.defaultFontPixelHeight * 0.08

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: ScreenTools.defaultFontPixelHeight * 0.26
                                    spacing: ScreenTools.defaultFontPixelWidth * 0.18

                                    QGCLabel {
                                        Layout.fillWidth: true
                                        color: "#D8D9DA"
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.68
                                        text: qsTr("Battery")
                                    }

                                    QGCColoredImage {
                                        Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.66
                                        Layout.preferredHeight: Layout.preferredWidth
                                        color: root._hasFactValue(instrumentPanel.batteryFact)
                                               ? (Number(instrumentPanel.batteryFact.rawValue) <= 20 ? "#E35F63"
                                                  : (Number(instrumentPanel.batteryFact.rawValue) <= 40 ? "#D0B34D" : "#2DC46D"))
                                               : "#A5A8AC"
                                        fillMode: Image.PreserveAspectFit
                                        source: root._batteryIcon(root._batteryPercentForVehicle(instrumentPanel._vehicle))
                                    }

                                    QGCLabel {
                                        color: root._hasFactValue(instrumentPanel.batteryFact)
                                               ? (Number(instrumentPanel.batteryFact.rawValue) <= 20 ? "#E35F63"
                                                  : (Number(instrumentPanel.batteryFact.rawValue) <= 40 ? "#D0B34D" : "#2DC46D"))
                                               : "#E0E0E0"
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.74
                                        font.weight: Font.DemiBold
                                        text: root._formatFactValue(instrumentPanel.batteryFact, true, "--")
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: ScreenTools.defaultFontPixelWidth * 0.24

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: Qt.rgba(1, 1, 1, 0.06)
                                radius: ScreenTools.defaultFontPixelHeight * 0.08

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: ScreenTools.defaultFontPixelHeight * 0.26
                                    spacing: instrumentPanel._dialTitleSpacing

                                    QGCLabel { color: "#D8D9DA"; text: qsTr("Attitude"); font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.68 }

                                    Item {
                                        Layout.topMargin: -instrumentPanel._dialTopPull
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        QGCAttitudeWidget {
                                            anchors.centerIn: parent
                                            size: Math.min(parent.width, parent.height) * 0.84
                                            vehicle: instrumentPanel._vehicle
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: Qt.rgba(1, 1, 1, 0.06)
                                radius: ScreenTools.defaultFontPixelHeight * 0.08

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: ScreenTools.defaultFontPixelHeight * 0.26
                                    spacing: instrumentPanel._dialTitleSpacing

                                    QGCLabel { color: "#D8D9DA"; text: qsTr("Heading"); font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.68 }

                                    Item {
                                        Layout.topMargin: -instrumentPanel._dialTopPull
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        QGCCompassWidget {
                                            anchors.centerIn: parent
                                            size: Math.min(parent.width, parent.height) * 0.84
                                            vehicle: instrumentPanel._vehicle
                                        }
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: ScreenTools.defaultFontPixelWidth * 0.24

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: Qt.rgba(1, 1, 1, 0.06)
                                radius: ScreenTools.defaultFontPixelHeight * 0.08

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: ScreenTools.defaultFontPixelHeight * 0.26
                                    spacing: instrumentPanel._dialTitleSpacing

                                    QGCLabel { color: "#D8D9DA"; text: qsTr("Altitude"); font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.68 }

                                    Item {
                                        Layout.topMargin: -instrumentPanel._dialTopPull
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        Rectangle {
                                            id: altitudeDial
                                            width: Math.min(parent.width, parent.height) * 0.86
                                            height: width
                                            radius: width / 2
                                            color: Qt.rgba(0, 0, 0, 0.06)
                                            border.color: Qt.rgba(0.88, 0.88, 0.88, 0.88)
                                            border.width: 2
                                            anchors.centerIn: parent
                                        }

                                        QGCLabel {
                                            anchors.centerIn: altitudeDial
                                            color: "#F1F1F1"
                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 1.02
                                            font.weight: Font.DemiBold
                                            text: root._formatFactValue(instrumentPanel.altitudeFact, true, "--")
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: Qt.rgba(1, 1, 1, 0.06)
                                radius: ScreenTools.defaultFontPixelHeight * 0.08

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: ScreenTools.defaultFontPixelHeight * 0.26
                                    spacing: instrumentPanel._dialTitleSpacing

                                    QGCLabel { color: "#D8D9DA"; text: qsTr("Air Speed"); font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.68 }

                                    Item {
                                        Layout.topMargin: -instrumentPanel._dialTopPull
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        Rectangle {
                                            id: airSpeedDial
                                            width: Math.min(parent.width, parent.height) * 0.86
                                            height: width
                                            radius: width / 2
                                            color: Qt.rgba(0, 0, 0, 0.06)
                                            border.color: Qt.rgba(0.88, 0.88, 0.88, 0.88)
                                            border.width: 2
                                            anchors.centerIn: parent
                                        }

                                        Canvas {
                                            id: airSpeedArc
                                            anchors.fill: airSpeedDial

                                            onPaint: {
                                                const ctx = getContext("2d")
                                                const radius = width * 0.44
                                                const cx = width * 0.5
                                                const cy = height * 0.5
                                                ctx.clearRect(0, 0, width, height)
                                                ctx.lineWidth = Math.max(2, width * 0.035)
                                                ctx.lineCap = "round"

                                                const drawArc = (startDeg, endDeg, color) => {
                                                    ctx.beginPath()
                                                    ctx.strokeStyle = color
                                                    ctx.arc(cx, cy, radius, (startDeg - 90) * Math.PI / 180, (endDeg - 90) * Math.PI / 180, false)
                                                    ctx.stroke()
                                                }

                                                drawArc(210, 250, "#D1465C")
                                                drawArc(250, 285, "#D1B63A")
                                                drawArc(285, 355, "#4CAF50")
                                            }

                                            onWidthChanged: requestPaint()
                                            onHeightChanged: requestPaint()
                                        }

                                        Rectangle {
                                            width: airSpeedDial.width * 0.33
                                            height: Math.max(2, ScreenTools.defaultFontPixelWidth / 3)
                                            radius: height / 2
                                            x: airSpeedDial.x + (airSpeedDial.width / 2)
                                            y: airSpeedDial.y + ((airSpeedDial.height - height) / 2)
                                            transformOrigin: Item.Left
                                            rotation: instrumentPanel.airSpeedNeedleRotation
                                            color: "#E7E7E7"
                                        }

                                        Rectangle {
                                            width: ScreenTools.defaultFontPixelWidth
                                            height: width
                                            radius: width / 2
                                            color: "#E7E7E7"
                                            anchors.centerIn: airSpeedDial
                                        }

                                        QGCLabel {
                                            anchors.centerIn: airSpeedDial
                                            color: "#F1F1F1"
                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.96
                                            font.weight: Font.DemiBold
                                            text: root._formatFactValue(instrumentPanel.airSpeedFact, true, "--")
                                        }
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: ScreenTools.defaultFontPixelWidth * 0.24

                            Rectangle {
                                id: turnCoordinatorCard
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: Qt.rgba(1, 1, 1, 0.06)
                                radius: ScreenTools.defaultFontPixelHeight * 0.08

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: ScreenTools.defaultFontPixelHeight * 0.26
                                    spacing: instrumentPanel._dialTitleSpacing

                                    QGCLabel { color: "#D8D9DA"; text: qsTr("Turn Coordinator"); font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.68 }

                                    Item {
                                        Layout.topMargin: -instrumentPanel._dialTopPull
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        Rectangle {
                                            id: turnDial
                                            width: Math.min(parent.width, parent.height) * 0.86
                                            height: width
                                            radius: width / 2
                                            color: Qt.rgba(0, 0, 0, 0.06)
                                            border.color: Qt.rgba(0.88, 0.88, 0.88, 0.88)
                                            border.width: 2
                                            anchors.centerIn: parent
                                        }

                                        Rectangle {
                                            width: turnDial.width * 0.34
                                            height: Math.max(2, ScreenTools.defaultFontPixelWidth / 3)
                                            radius: height / 2
                                            x: turnDial.x + (turnDial.width / 2)
                                            y: turnDial.y + ((turnDial.height - height) / 2)
                                            transformOrigin: Item.Left
                                            rotation: instrumentPanel.turnNeedleRotation
                                            color: "#E7E7E7"
                                        }

                                        Rectangle {
                                            width: ScreenTools.defaultFontPixelWidth
                                            height: width
                                            radius: width / 2
                                            color: "#E7E7E7"
                                            anchors.centerIn: turnDial
                                        }

                                        QGCLabel {
                                            anchors.horizontalCenter: turnDial.horizontalCenter
                                            anchors.bottom: parent.bottom
                                            color: "#F1F1F1"
                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.88
                                            font.weight: Font.DemiBold
                                            text: instrumentPanel.hasTurnValue ? root._formatSignedValue(instrumentPanel.turnValue, 0, "\u00B0") : "--"
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                id: verticalSpeedCard
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: Qt.rgba(1, 1, 1, 0.06)
                                radius: ScreenTools.defaultFontPixelHeight * 0.08

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: ScreenTools.defaultFontPixelHeight * 0.26
                                    spacing: instrumentPanel._dialTitleSpacing

                                    QGCLabel { color: "#D8D9DA"; text: qsTr("Vertical Speed"); font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.68 }

                                    Item {
                                        Layout.topMargin: -instrumentPanel._dialTopPull
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        Rectangle {
                                            id: verticalSpeedDial
                                            width: Math.min(parent.width, parent.height) * 0.86
                                            height: width
                                            radius: width / 2
                                            color: Qt.rgba(0, 0, 0, 0.06)
                                            border.color: Qt.rgba(0.88, 0.88, 0.88, 0.88)
                                            border.width: 2
                                            anchors.centerIn: parent
                                        }

                                        Rectangle {
                                            width: verticalSpeedDial.width * 0.34
                                            height: Math.max(2, ScreenTools.defaultFontPixelWidth / 3)
                                            radius: height / 2
                                            x: verticalSpeedDial.x + (verticalSpeedDial.width / 2)
                                            y: verticalSpeedDial.y + ((verticalSpeedDial.height - height) / 2)
                                            transformOrigin: Item.Left
                                            rotation: instrumentPanel.verticalNeedleRotation
                                            color: "#D7DDE3"
                                        }

                                        Rectangle {
                                            width: ScreenTools.defaultFontPixelWidth
                                            height: width
                                            radius: width / 2
                                            color: "#D7DDE3"
                                            anchors.centerIn: verticalSpeedDial
                                        }

                                        QGCLabel {
                                            anchors.centerIn: verticalSpeedDial
                                            color: "#F1F1F1"
                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.88
                                            font.weight: Font.DemiBold
                                            text: root._formatFactValue(instrumentPanel.climbRateFact, true, "--")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                GuidedActionConfirm {
                    id: guidedConfirm
                    anchors.top: parent.top
                    anchors.topMargin: root._margin
                    anchors.horizontalCenter: parent.horizontalCenter
                    guidedController: guidedActionsController
                    guidedValueSlider: guidedValueSlider
                    height: ScreenTools.toolbarHeight
                    messageDisplay: guidedMessageDisplay
                }

                Rectangle {
                    id: guidedMessageDisplay
                    anchors.top: guidedConfirm.bottom
                    anchors.topMargin: root._margin
                    anchors.horizontalCenter: guidedConfirm.horizontalCenter
                    width: guidedMessageLabel.contentWidth + (root._margin * 2)
                    height: guidedMessageLabel.contentHeight + (root._margin * 1.2)
                    color: qgcPal.window
                    opacity: 0.9
                    radius: ScreenTools.defaultFontPixelHeight * 0.28
                    visible: guidedConfirm.visible
                    QGCLabel { id: guidedMessageLabel; anchors.centerIn: parent; width: ScreenTools.defaultFontPixelWidth * 30; horizontalAlignment: Text.AlignHCenter; text: guidedConfirm.message; wrapMode: Text.WordWrap }
                }

                Rectangle {
                    id: uavVideoOverlay
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: root._margin
                    anchors.rightMargin: root._margin
                    width: root._videoOverlayExpanded
                        ? root._expandedVideoOverlayWidth(parent.width)
                        : root._compactVideoOverlayWidth(parent.width)
                    height: width * 0.75
                    color: qgcPal.windowShadeDark
                    radius: ScreenTools.defaultFontPixelHeight * 0.1
                    clip: true
                    z: QGroundControl.zOrderWidgets

                    Behavior on width {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.InOutQuad
                        }
                    }

                    Behavior on height {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.InOutQuad
                        }
                    }

                    Loader { anchors.fill: parent; sourceComponent: QGroundControl.videoManager.hasVideo ? videoComponent : placeholderComponent }
                    Component { id: videoComponent; FlyViewVideo { pipView: null } }
                    Component {
                        id: placeholderComponent
                        Rectangle {
                            color: qgcPal.window
                            QGCColoredImage { anchors.centerIn: parent; width: ScreenTools.defaultFontPixelHeight * 2.4; height: width; color: "#FFFFFF"; fillMode: Image.PreserveAspectFit; source: "/InstrumentValueIcons/drone.svg" }
                        }
                    }

                    Repeater {
                        model: [
                            { "left": true,  "top": true,  "source": "/InstrumentValueIcons/window.svg" },
                            { "left": false, "top": true,  "source": "/InstrumentValueIcons/cheveron-outline-right.svg" },
                            { "left": true,  "top": false, "source": "/InstrumentValueIcons/view-tile.svg" },
                            { "left": false, "top": false, "source": "/InstrumentValueIcons/screen-full.svg", "toggleExpand": true }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            width: ScreenTools.defaultFontPixelHeight * 1.16
                            height: width
                            radius: ScreenTools.defaultFontPixelHeight * 0.08
                            color: Qt.rgba(0.1, 0.1, 0.1, 0.92)
                            anchors.left: modelData.left ? parent.left : undefined
                            anchors.right: modelData.left ? undefined : parent.right
                            anchors.top: modelData.top ? parent.top : undefined
                            anchors.bottom: modelData.top ? undefined : parent.bottom
                            anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.18
                            anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.18
                            anchors.topMargin: ScreenTools.defaultFontPixelWidth * 0.18
                            anchors.bottomMargin: ScreenTools.defaultFontPixelWidth * 0.18
                            QGCColoredImage {
                                anchors.centerIn: parent
                                width: parent.height * 0.48
                                height: width
                                color: "#FFFFFF"
                                fillMode: Image.PreserveAspectFit
                                source: modelData.toggleExpand && root._videoOverlayExpanded
                                    ? "/InstrumentValueIcons/window-open.svg"
                                    : modelData.source
                            }
                            QGCMouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (modelData.toggleExpand) {
                                        root._videoOverlayExpanded = !root._videoOverlayExpanded
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: startMissionFeedbackPanel
                x: Math.max(
                    root._margin,
                    Math.min(
                        mapPanel.width - width - root._margin,
                        startMissionMapButton.mapToItem(rightPane, 0, 0).x + ((startMissionMapButton.width - width) * 0.5)
                    )
                )
                y: Math.max(root._margin, startMissionMapButton.mapToItem(rightPane, 0, 0).y - height - (root._margin * 0.55))
                width: Math.min(ScreenTools.defaultFontPixelWidth * 32, Math.max(ScreenTools.defaultFontPixelWidth * 20, mapPanel.width - (root._margin * 2)))
                height: feedbackContent.implicitHeight + (ScreenTools.defaultFontPixelHeight * 0.9)
                visible: !root._useExternalStartMissionUi && root._startMissionFeedbackVisible && !root._startMissionSliderVisible
                color: root._startMissionFeedbackIsError ? Qt.rgba(0.28, 0.11, 0.11, 0.96) : Qt.rgba(0.08, 0.19, 0.30, 0.96)
                border.color: root._startMissionFeedbackIsError ? Qt.rgba(1.0, 0.52, 0.52, 0.35) : Qt.rgba(0.60, 0.84, 1.0, 0.28)
                border.width: 1
                radius: ScreenTools.defaultFontPixelHeight * 0.28
                z: QGroundControl.zOrderTopMost + 9

                ColumnLayout {
                    id: feedbackContent
                    anchors.fill: parent
                    anchors.margins: ScreenTools.defaultFontPixelHeight * 0.38
                    spacing: ScreenTools.defaultFontPixelHeight * 0.18

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: ScreenTools.defaultFontPixelWidth * 0.4

                        QGCLabel {
                            Layout.fillWidth: true
                            text: qsTr("Start Mission")
                            color: "#F8FAFC"
                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.74
                            font.bold: true
                        }

                        Rectangle {
                            Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 1.15
                            Layout.preferredHeight: Layout.preferredWidth
                            radius: width / 2
                            color: Qt.rgba(1, 1, 1, 0.14)

                            QGCColoredImage {
                                anchors.centerIn: parent
                                width: parent.width * 0.4
                                height: width
                                source: "/res/XDelete.svg"
                                color: "#FFFFFF"
                                fillMode: Image.PreserveAspectFit
                            }

                            QGCMouseArea {
                                anchors.fill: parent
                                onClicked: root._hideStartMissionFeedback()
                            }
                        }
                    }

                    QGCLabel {
                        Layout.fillWidth: true
                        text: root._startMissionFeedbackText
                        color: "#E5E7EB"
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.68
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Item {
                anchors.fill: mapPanel
                visible: !root._useExternalStartMissionUi && root._startMissionUnavailableDialogVisible
                z: QGroundControl.zOrderTopMost + 11

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 0.32)
                }

                QGCMouseArea {
                    anchors.fill: parent
                    onClicked: root._hideStartMissionUnavailableDialog()
                }

                Rectangle {
                    id: startMissionUnavailableDialog
                    anchors.centerIn: parent
                    width: Math.max(ScreenTools.defaultFontPixelWidth * 26, Math.min(ScreenTools.defaultFontPixelWidth * 42, parent.width * 0.38))
                    height: unavailableDialogContent.implicitHeight + (ScreenTools.defaultFontPixelHeight * 1.2)
                    color: Qt.rgba(0.12, 0.12, 0.13, 0.985)
                    border.color: Qt.rgba(1.0, 0.52, 0.52, 0.34)
                    border.width: 1
                    radius: ScreenTools.defaultFontPixelHeight * 0.34

                    ColumnLayout {
                        id: unavailableDialogContent
                        anchors.fill: parent
                        anchors.margins: ScreenTools.defaultFontPixelHeight * 0.48
                        spacing: ScreenTools.defaultFontPixelHeight * 0.34

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: ScreenTools.defaultFontPixelWidth * 0.38

                            QGCLabel {
                                Layout.fillWidth: true
                                text: qsTr("Start Mission")
                                color: "#F8FAFC"
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.78
                                font.bold: true
                            }

                            Rectangle {
                                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 1.12
                                Layout.preferredHeight: Layout.preferredWidth
                                radius: width / 2
                                color: Qt.rgba(1, 1, 1, 0.10)

                                QGCColoredImage {
                                    anchors.centerIn: parent
                                    width: parent.width * 0.42
                                    height: width
                                    source: "/res/XDelete.svg"
                                    color: "#FFFFFF"
                                    fillMode: Image.PreserveAspectFit
                                }

                                QGCMouseArea {
                                    anchors.fill: parent
                                    onClicked: root._hideStartMissionUnavailableDialog()
                                }
                            }
                        }

                        QGCLabel {
                            Layout.fillWidth: true
                            text: root._startMissionUnavailableDialogText
                            color: "#E5E7EB"
                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.7
                            wrapMode: Text.WordWrap
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: ScreenTools.defaultFontPixelHeight * 0.12

                            Item {
                                Layout.fillWidth: true
                            }

                            QGCButton {
                                text: qsTr("OK")
                                primary: true
                                onClicked: root._hideStartMissionUnavailableDialog()
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: startMissionSliderPanel
                x: Math.max(
                    root._margin,
                    Math.min(
                        mapPanel.width - width - root._margin,
                        startMissionMapButton.mapToItem(rightPane, 0, 0).x + ((startMissionMapButton.width - width) * 0.5)
                    )
                )
                y: Math.max(root._margin, startMissionMapButton.mapToItem(rightPane, 0, 0).y - height - (root._margin * 0.55))
                width: Math.min(ScreenTools.defaultFontPixelWidth * 38, Math.max(ScreenTools.defaultFontPixelWidth * 24, mapPanel.width - (root._margin * 2)))
                height: ScreenTools.defaultFontPixelHeight * 5.8
                visible: !root._useExternalStartMissionUi && root._startMissionSliderVisible
                color: Qt.rgba(0.10, 0.10, 0.11, 0.96)
                border.color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1
                radius: ScreenTools.defaultFontPixelHeight * 0.28
                z: QGroundControl.zOrderTopMost + 9

                onVisibleChanged: {
                    if (visible) {
                        startMissionSliderSwitch.forceActiveFocus()
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: ScreenTools.defaultFontPixelHeight * 0.42
                    spacing: ScreenTools.defaultFontPixelHeight * 0.3

                    QGCLabel {
                        Layout.fillWidth: true
                        text: root._mapPrimaryActionMessage()
                        color: "#F1F3F5"
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.72
                        wrapMode: Text.WordWrap
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: ScreenTools.defaultFontPixelWidth * 0.55

                        SliderSwitch {
                            id: startMissionSliderSwitch
                            Layout.fillWidth: true
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.45
                            focus: root._startMissionSliderVisible
                            confirmText: qsTr("Slide or hold spacebar")
                            onAccept: root._confirmStartMissionSlider()
                        }

                        Rectangle {
                            Layout.preferredWidth: startMissionSliderSwitch.height
                            Layout.preferredHeight: Layout.preferredWidth
                            radius: width / 2
                            color: "#9CC1D7"

                            QGCColoredImage {
                                anchors.centerIn: parent
                                width: parent.width * 0.42
                                height: width
                                source: "/res/XDelete.svg"
                                color: "#FFFFFF"
                                fillMode: Image.PreserveAspectFit
                            }

                            QGCMouseArea {
                                anchors.fill: parent
                                onClicked: root._hideStartMissionSlider()
                            }
                        }
                    }
                }
            }

            Rectangle {
                x: 0
                y: mapPanel.height
                width: parent ? parent.width : 0
                height: 1
                color: qgcPal.windowShade
            }

            Rectangle {
                id: profilePanel
                x: 0
                y: mapPanel.height + 1
                width: parent ? parent.width : 0
                height: root._profilePanelExpanded
                    ? root._clampProfilePanelHeight(root._profilePanelExpandedHeight)
                    : root._profilePanelCollapsedHeight
                color: qgcPal.windowShadeDark
                radius: root._radius
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    Rectangle {
                        id: profileResizeHandle
                        Layout.fillWidth: true
                        Layout.preferredHeight: root._profilePanelExpanded ? ScreenTools.defaultFontPixelHeight * 0.42 : 0
                        visible: root._profilePanelExpanded
                        color: Qt.rgba(1, 1, 1, 0.05)

                        Rectangle {
                            anchors.centerIn: parent
                            width: ScreenTools.defaultFontPixelWidth * 6
                            height: ScreenTools.defaultFontPixelHeight * 0.12
                            radius: height / 2
                            color: Qt.rgba(1, 1, 1, 0.28)
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.SizeVerCursor

                            property real _startMouseY: 0
                            property real _startHeight: 0

                            onPressed: (mouse) => {
                                _startMouseY = profileResizeHandle.mapToItem(root, mouse.x, mouse.y).y
                                _startHeight = root._profilePanelExpandedHeight
                            }

                            onPositionChanged: (mouse) => {
                                if (!pressed || !root._profilePanelExpanded) {
                                    return
                                }
                                const currentMouseY = profileResizeHandle.mapToItem(root, mouse.x, mouse.y).y
                                const deltaY = currentMouseY - _startMouseY
                                root._profilePanelExpandedHeight = root._clampProfilePanelHeight(_startHeight - deltaY)
                            }
                        }
                    }

                    Rectangle {
                        id: profileToolbar
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.1
                        color: "#2A2A2B"

                        RowLayout {
                            id: profileToolbarRow
                            anchors.fill: parent
                            anchors.leftMargin: root._margin * 0.5
                            anchors.rightMargin: root._margin * 0.42
                            spacing: ScreenTools.defaultFontPixelWidth * 0.28

                            Item {
                                id: profilePlaybackHost
                                Layout.preferredWidth: Math.max(ScreenTools.defaultFontPixelWidth * 18, profileLeftPanel.width)
                                Layout.maximumWidth: Layout.preferredWidth
                                Layout.fillHeight: true

                                RowLayout {
                                    id: playbackButtonStrip
                                    anchors.fill: parent
                                    spacing: ScreenTools.defaultFontPixelWidth * 0.28
                                    readonly property real buttonWidth: Math.max(
                                        ScreenTools.defaultFontPixelHeight * 1.92,
                                        (width - (spacing * 4)) / 5
                                    )

                                    Repeater {
                                        model: [
                                            { "key": "toStart", "icon": "/InstrumentValueIcons/fast-rewind.svg" },
                                            { "key": "stepBack", "icon": "/InstrumentValueIcons/step-backward.svg" },
                                            { "key": "toggle", "icon": "" },
                                            { "key": "stepForward", "icon": "/InstrumentValueIcons/step-forward.svg" },
                                            { "key": "toEnd", "icon": "/InstrumentValueIcons/fast-forward.svg" }
                                        ]

                                        delegate: Rectangle {
            
                                            Layout.preferredWidth: playbackButtonStrip.buttonWidth
                                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.92
                                            radius: ScreenTools.defaultFontPixelHeight * 0.06
                                            color: "#202020"
                                            border.width: 1
                                            border.color: Qt.rgba(1, 1, 1, 0.06)

                                            QGCColoredImage {
                                                anchors.centerIn: parent
                                                width: parent.height * 0.5
                                                height: width
                                                color: "#FFFFFF"
                                                fillMode: Image.PreserveAspectFit
                                                source: modelData.key === "toggle"
                                                        ? (root._profilePlaybackActive ? "/InstrumentValueIcons/pause-outline.svg" : "/InstrumentValueIcons/play-outline.svg")
                                                        : modelData.icon
                                            }

                                            QGCMouseArea {
                                                anchors.fill: parent
                                                onClicked: {
                                                    switch (modelData.key) {
                                                    case "toStart":
                                                        root._profilePlaybackActive = false
                                                        root._profileProgress = 0
                                                        break
                                                    case "stepBack":
                                                        root._profilePlaybackActive = false
                                                        root._profileProgress = Math.max(0, root._profileProgress - 0.05)
                                                        break
                                                    case "toggle":
                                                        root._profilePlaybackActive = !root._profilePlaybackActive
                                                        break
                                                    case "stepForward":
                                                        root._profilePlaybackActive = false
                                                        root._profileProgress = Math.min(1, root._profileProgress + 0.05)
                                                        break
                                                    case "toEnd":
                                                        root._profilePlaybackActive = false
                                                        root._profileProgress = 1
                                                        break
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Item {
                                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 1.6
                                Layout.fillHeight: true
                            }

                            Rectangle {
                                id: startMissionMapButton
                                visible: !root._useExternalStartMissionUi
                                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 2.9
                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.9
                                Layout.minimumWidth: ScreenTools.defaultFontPixelHeight * 2.9
                                Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 2.9
                                Layout.alignment: Qt.AlignVCenter
                                color: startMissionMapMouseArea.pressed
                                    ? "#9A3412"
                                    : (startMissionMapMouseArea.containsMouse ? "#F97316" : "#EA580C")
                                opacity: 0.98
                                radius: ScreenTools.defaultFontPixelHeight * 0.14
                                border.width: 2
                                border.color: Qt.rgba(1, 1, 1, 0.24)

                                Behavior on color {
                                    ColorAnimation { duration: 160 }
                                }

                                Item {
                                    anchors.fill: parent

                                    QGCColoredImage {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.verticalCenterOffset: -(ScreenTools.defaultFontPixelHeight * 0.26)
                                        width: parent.width * 0.4
                                        height: width
                                        color: "#FFF7ED"
                                        fillMode: Image.PreserveAspectFit
                                        source: "/res/takeoff.svg"
                                    }

                                    QGCLabel {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.18
                                        color: "#FFF7ED"
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.42
                                        font.bold: true
                                        text: root._mapPrimaryActionText()
                                    }

                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.16
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: parent.width * 0.5
                                        height: ScreenTools.defaultFontPixelHeight * 0.1
                                        radius: height / 2
                                        color: Qt.rgba(1, 1, 1, 0.28)
                                    }
                                }

                                QGCMouseArea {
                                    id: startMissionMapMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        if (root._startMissionSliderVisible) {
                                            root._hideStartMissionSlider()
                                            return
                                        }
                                        root._triggerMapPrimaryAction()
                                    }
                                }
                            }

                            Item {
                                id: startMissionToolbarGap
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                            }

                            Repeater {
                                model: [
                                    {
                                        "icon": "/InstrumentValueIcons/time.svg",
                                        "text": root._formatReplayTime(root._profileElapsedSeconds(root._profileMissionPoints, root._profileProgress))
                                    },
                                    {
                                        "icon": "/InstrumentValueIcons/navigation-more.svg",
                                        "text": root._activeVehicle && root._hasFactValue(root._activeVehicle.heading)
                                            ? (root._factText(root._activeVehicle.heading, "--", false) + "\u00B0 " + root._headingCompassLabel(Number(root._activeVehicle.heading.rawValue)))
                                            : qsTr("--")
                                    },
                                    {
                                        "icon": "/InstrumentValueIcons/airplane.svg",
                                        "text": root._activeVehicle ? root._factText(root._activeVehicle.groundSpeed, "--", true) : "--"
                                    },
                                    {
                                        "icon": "/InstrumentValueIcons/arrow-thin-up.svg",
                                        "text": root._activeVehicle ? root._factText(root._activeVehicle.altitudeRelative, "--", true) : "--"
                                    },
                                    {
                                        "icon": "/InstrumentValueIcons/arrow-simple-up.svg",
                                        "text": root._activeVehicle ? root._factText(root._activeVehicle.climbRate, "--", true) : "--"
                                    }
                                ]

                                delegate: Rectangle {
    
                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.15
                                    Layout.preferredWidth: metricRow.implicitWidth + (ScreenTools.defaultFontPixelWidth * 0.72)
                                    radius: ScreenTools.defaultFontPixelHeight * 0.08
                                    color: "#202020"
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.08)

                                    RowLayout {
                                        id: metricRow
                                        anchors.centerIn: parent
                                        spacing: ScreenTools.defaultFontPixelWidth * 0.16

                                        QGCColoredImage {
                                            Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.58
                                            Layout.preferredHeight: Layout.preferredWidth
                                            color: "#B7BCC7"
                                            fillMode: Image.PreserveAspectFit
                                            source: modelData.icon
                                        }

                                        QGCLabel {
                                            color: "#E6E6E6"
                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.56
                                            text: modelData.text
                                        }
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 7.4
                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.35
                                color: "#202020"
                                radius: ScreenTools.defaultFontPixelHeight * 0.08
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.08)

                                QGCLabel {
                                    anchors.centerIn: parent
                                    color: "#D9D9D9"
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.62
                                    text: root._formatReplayTime(root._profileTotalDurationSeconds(root._profileMissionPoints))
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 1.35
                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.35
                                radius: ScreenTools.defaultFontPixelHeight * 0.06
                                color: "#202020"
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.06)

                                QGCColoredImage {
                                    anchors.centerIn: parent
                                    width: parent.height * 0.4
                                    height: width
                                    color: "#FFFFFF"
                                    fillMode: Image.PreserveAspectFit
                                    source: root._profilePanelExpanded ? "/InstrumentValueIcons/cheveron-down.svg" : "/InstrumentValueIcons/cheveron-up.svg"
                                }

                                QGCMouseArea {
                                    anchors.fill: parent
                                    onClicked: root._profilePanelExpanded = !root._profilePanelExpanded
                                }
                            }
                        }
                    }

                    Item {
                        id: profileContentArea
                        Layout.fillWidth: true
                        Layout.fillHeight: root._profilePanelExpanded
                        Layout.preferredHeight: root._profilePanelExpanded ? Math.max(0, profilePanel.height - profileResizeHandle.height - (ScreenTools.defaultFontPixelHeight * 2.3)) : 0
                        Layout.maximumHeight: root._profilePanelExpanded ? 100000 : 0
                        visible: root._profilePanelExpanded
                        clip: true

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: root._margin * 0.5
                            anchors.rightMargin: root._margin * 0.5
                            anchors.topMargin: root._margin * 0.35
                            anchors.bottomMargin: root._margin * 0.35
                            spacing: ScreenTools.defaultFontPixelWidth * 0.35

                            Rectangle {
                                id: profileLeftPanel
                                Layout.preferredWidth: Math.max(ScreenTools.defaultFontPixelWidth * 18, parent.width * 0.24)
                                Layout.fillHeight: true
                                color: "#191A1C"
                                radius: ScreenTools.defaultFontPixelHeight * 0.08
                                clip: true

                                Flickable {
                                    id: profileTreeFlickable
                                    anchors.fill: parent
                                    contentWidth: width
                                    contentHeight: profileTreeColumn.implicitHeight
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds
                                    flickableDirection: Flickable.VerticalFlick
                                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                                    WheelHandler {
                                        target: null
                                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                        onWheel: (event) => {
                                            const step = ScreenTools.defaultFontPixelHeight * 2.2
                                            const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : (event.pixelDelta ? event.pixelDelta.y : 0)
                                            if (delta === 0) {
                                                return
                                            }
                                            profileTreeFlickable.contentY = Math.max(
                                                0,
                                                Math.min(
                                                    profileTreeFlickable.contentHeight - profileTreeFlickable.height,
                                                    profileTreeFlickable.contentY - ((delta / 120) * step)
                                                )
                                            )
                                        }
                                    }

                                    Column {
                                        id: profileTreeColumn
                                        width: profileLeftPanel.width
                                        spacing: 0

                                        Rectangle {
                                            width: parent.width
                                            height: ScreenTools.defaultFontPixelHeight * 2.05
                                            color: "#4A89D8"

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.26
                                                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.26
                                                spacing: ScreenTools.defaultFontPixelWidth * 0.22

                                                Item {
                                                    Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.82
                                                    Layout.fillHeight: true

                                                    QGCLabel {
                                                        anchors.centerIn: parent
                                                        text: root._profileVehicleTreeExpanded ? "\u25BE" : "\u25B8"
                                                        color: "#D7E6FF"
                                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5
                                                    }

                                                    QGCMouseArea {
                                                        anchors.fill: parent
                                                        onClicked: root._profileVehicleTreeExpanded = !root._profileVehicleTreeExpanded
                                                    }
                                                }

                                                QGCColoredImage { Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.8; Layout.preferredHeight: Layout.preferredWidth; color: "#DCEBFF"; fillMode: Image.PreserveAspectFit; source: "/InstrumentValueIcons/drone.svg" }
                                                QGCLabel {
                                                    Layout.fillWidth: true
                                                    color: "#F4F9FF"
                                                    font.weight: Font.DemiBold
                                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.72
                                                    elide: Text.ElideRight
                                                    text: root._activeVehicle ? root._vehicleTitle(root._activeVehicle) : qsTr("Vehicle --")
                                                }
                                            }
                                        }

                                        Rectangle {
                                            width: parent.width
                                            height: root._profileVehicleTreeExpanded ? ScreenTools.defaultFontPixelHeight * 2.0 : 0
                                            visible: height > 0
                                            color: "#1F2022"
                                            clip: true

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 1.28
                                                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.28
                                                spacing: ScreenTools.defaultFontPixelWidth * 0.22

                                                Item {
                                                    Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.74
                                                    Layout.fillHeight: true

                                                    QGCLabel {
                                                        anchors.centerIn: parent
                                                        text: root._profileMissionTreeExpanded ? "\u25BE" : "\u25B8"
                                                        color: "#D4D4D4"
                                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.48
                                                    }

                                                    QGCMouseArea {
                                                        anchors.fill: parent
                                                        onClicked: root._profileMissionTreeExpanded = !root._profileMissionTreeExpanded
                                                    }
                                                }

                                                QGCColoredImage { Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.72; Layout.preferredHeight: Layout.preferredWidth; color: "#61C3B1"; fillMode: Image.PreserveAspectFit; source: "/InstrumentValueIcons/map.svg" }
                                                QGCLabel {
                                                    Layout.fillWidth: true
                                                    color: "#E1E1E1"
                                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.68
                                                    elide: Text.ElideRight
                                                    text: root._missionTitle()
                                                }
                                            }

                                            Rectangle {
                                                x: ScreenTools.defaultFontPixelWidth * 0.82
                                                y: 0
                                                width: 1
                                                height: parent.height
                                                color: Qt.rgba(1, 1, 1, 0.08)
                                            }
                                        }

                                        Repeater {
                                            model: root._profileSiteGroups

                                            delegate: Rectangle {
                                                                required property int index

                                                readonly property bool _current: profileChart.currentPointIndex >= modelData.startIndex && profileChart.currentPointIndex <= modelData.endIndex

                                                width: parent.width
                                                height: (root._profileVehicleTreeExpanded && root._profileMissionTreeExpanded)
                                                    ? (ScreenTools.defaultFontPixelHeight * 1.82)
                                                    : 0
                                                visible: height > 0
                                                color: _current ? Qt.rgba(0.29, 0.54, 0.85, 0.18) : "transparent"
                                                clip: true

                                                Rectangle {
                                                    x: ScreenTools.defaultFontPixelWidth * 0.82
                                                    y: 0
                                                    width: 1
                                                    height: parent.height
                                                    color: Qt.rgba(1, 1, 1, 0.08)
                                                }

                                                Rectangle {
                                                    x: ScreenTools.defaultFontPixelWidth * 1.92
                                                    y: 0
                                                    width: 1
                                                    height: parent.height
                                                    color: Qt.rgba(1, 1, 1, 0.08)
                                                }

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 2.18
                                                    anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.3
                                                    spacing: ScreenTools.defaultFontPixelWidth * 0.22

                                                    QGCLabel { text: "\u25B8"; color: "#B7B7B7"; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.42 }
                                                    QGCColoredImage { Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.66; Layout.preferredHeight: Layout.preferredWidth; color: _current ? "#7FD0FF" : "#7AA0C8"; fillMode: Image.PreserveAspectFit; source: "/InstrumentValueIcons/drone.svg" }
                                                    QGCLabel {
                                                        Layout.fillWidth: true
                                                        color: _current ? "#F6F8FB" : "#D1D5DB"
                                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.64
                                                        elide: Text.ElideRight
                                                        text: modelData.label
                                                    }
                                                    QGCLabel {
                                                        color: "#8F98A3"
                                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.56
                                                        text: root._formatProfileAltitude(modelData.altitude)
                                                    }
                                                }

                                                QGCMouseArea {
                                                    anchors.fill: parent
                                                    onClicked: {
                                                        const totalDistance = Math.max(Number(root._profileStats(root._profileMissionPoints).totalDistance), 1)
                                                        root._profilePlaybackActive = false
                                                        root._profileProgress = Math.max(0, Math.min(1, Number(modelData.startDistance) / totalDistance))
                                                        if (modelData.coordinate && modelData.coordinate.isValid) {
                                                            mapView.center = modelData.coordinate
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                id: profileChart
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: "#202123"
                                radius: ScreenTools.defaultFontPixelHeight * 0.08
                                clip: true

                                property var points: root._profileMissionPoints
                                readonly property var stats: root._profileStats(points)
                                readonly property real currentDistance: Math.max(Number(stats.totalDistance), 1) * root._profileProgress
                                readonly property int currentPointIndex: root._profilePointIndexAtProgress(points, root._profileProgress)
                                readonly property var currentPoint: root._profilePointAtProgress(points, root._profileProgress)
                                readonly property real elapsedSeconds: root._profileElapsedSeconds(points, root._profileProgress)
                                readonly property real plotLeft: ScreenTools.defaultFontPixelWidth * 2.8
                                readonly property real plotRight: ScreenTools.defaultFontPixelWidth * 1.2
                                readonly property real plotTop: ScreenTools.defaultFontPixelHeight * 1.65
                                readonly property real plotBottom: ScreenTools.defaultFontPixelHeight * 1.55
                                readonly property real plotWidth: Math.max(width - plotLeft - plotRight, 1)
                                readonly property real plotHeight: Math.max(height - plotTop - plotBottom, 1)

                                function xForDistance(distance) {
                                    return plotLeft + (Math.max(0, Number(distance)) / Math.max(Number(stats.totalDistance), 1)) * plotWidth
                                }
                                function yForAltitude(altitude) {
                                    const maxAlt = Number(stats.maxAlt)
                                    const minAlt = Number(stats.minAlt)
                                    const ratio = (Math.max(minAlt, Math.min(maxAlt, Number(altitude))) - minAlt) / Math.max(maxAlt - minAlt, 1)
                                    return plotTop + (1 - ratio) * plotHeight
                                }
                                function altitudeAtProgress(progress) {
                                    if (!points || points.length === 0) {
                                        return Number(stats.minAlt)
                                    }
                                    const targetDistance = Math.max(Number(stats.totalDistance), 1) * Math.max(0, Math.min(1, progress))
                                    for (let i = 1; i < points.length; i++) {
                                        const prevPoint = points[i - 1]
                                        const nextPoint = points[i]
                                        if (targetDistance <= nextPoint.distance) {
                                            const span = Math.max(Number(nextPoint.distance) - Number(prevPoint.distance), 1)
                                            const t = (targetDistance - Number(prevPoint.distance)) / span
                                            return Number(prevPoint.altitude) + ((Number(nextPoint.altitude) - Number(prevPoint.altitude)) * t)
                                        }
                                    }
                                    return Number(points[points.length - 1].altitude)
                                }

                                Canvas {
                                    id: profileCanvas
                                    anchors.fill: parent

                                    onPaint: {
                                        const ctx = getContext("2d")
                                        ctx.clearRect(0, 0, width, height)

                                        const left = profileChart.plotLeft
                                        const top = profileChart.plotTop
                                        const plotWidth = profileChart.plotWidth
                                        const plotHeight = profileChart.plotHeight

                                        ctx.fillStyle = "#262729"
                                        ctx.fillRect(left, top, plotWidth, plotHeight)

                                        ctx.strokeStyle = "rgba(255,255,255,0.10)"
                                        ctx.lineWidth = 1
                                        for (let i = 0; i <= 8; i++) {
                                            const x = left + (plotWidth * i / 8)
                                            ctx.beginPath()
                                            ctx.moveTo(x, top)
                                            ctx.lineTo(x, top + plotHeight)
                                            ctx.stroke()
                                        }
                                        for (let i = 0; i <= 5; i++) {
                                            const y = top + (plotHeight * i / 5)
                                            ctx.beginPath()
                                            ctx.moveTo(left, y)
                                            ctx.lineTo(left + plotWidth, y)
                                            ctx.stroke()
                                        }

                                        const points = profileChart.points
                                        if (!points || points.length < 2) {
                                            return
                                        }

                                        ctx.lineCap = "round"
                                        ctx.lineJoin = "round"
                                        ctx.strokeStyle = "rgba(250, 146, 75, 0.28)"
                                        ctx.lineWidth = ScreenTools.defaultFontPixelHeight * 0.82
                                        ctx.beginPath()
                                        for (let i = 0; i < points.length; i++) {
                                            const point = points[i]
                                            const x = profileChart.xForDistance(point.distance)
                                            const y = profileChart.yForAltitude(point.altitude)
                                            if (i === 0) {
                                                ctx.moveTo(x, y)
                                            } else {
                                                ctx.lineTo(x, y)
                                            }
                                        }
                                        ctx.stroke()

                                        ctx.strokeStyle = "rgba(171, 138, 255, 0.58)"
                                        ctx.lineWidth = ScreenTools.defaultFontPixelHeight * 0.5
                                        ctx.beginPath()
                                        for (let i = 0; i < points.length; i++) {
                                            const point = points[i]
                                            const x = profileChart.xForDistance(point.distance)
                                            const y = profileChart.yForAltitude(point.altitude)
                                            if (i === 0) {
                                                ctx.moveTo(x, y)
                                            } else {
                                                ctx.lineTo(x, y)
                                            }
                                        }
                                        ctx.stroke()

                                        ctx.strokeStyle = "#E8893D"
                                        ctx.lineWidth = ScreenTools.defaultFontPixelHeight * 0.16
                                        ctx.beginPath()
                                        for (let i = 0; i < points.length; i++) {
                                            const point = points[i]
                                            const x = profileChart.xForDistance(point.distance)
                                            const y = profileChart.yForAltitude(point.altitude)
                                            if (i === 0) {
                                                ctx.moveTo(x, y)
                                            } else {
                                                ctx.lineTo(x, y)
                                            }
                                        }
                                        ctx.stroke()
                                    }
                                }

                                onPointsChanged: profileCanvas.requestPaint()
                                onWidthChanged: profileCanvas.requestPaint()
                                onHeightChanged: profileCanvas.requestPaint()
                                onStatsChanged: profileCanvas.requestPaint()

                                Rectangle {
                                    width: 1
                                    height: profileChart.plotHeight + (ScreenTools.defaultFontPixelHeight * 0.55)
                                    x: profileChart.xForDistance(profileChart.currentDistance)
                                    y: profileChart.plotTop - (ScreenTools.defaultFontPixelHeight * 0.52)
                                    color: "#3D9BFF"
                                    opacity: 0.8
                                }

                                Rectangle {
                                    width: ScreenTools.defaultFontPixelHeight * 0.52
                                    height: width
                                    radius: width / 2
                                    x: profileChart.xForDistance(profileChart.currentDistance) - (width * 0.5)
                                    y: profileChart.plotTop - (height * 0.8)
                                    color: "#56A7FF"
                                }

                                QGCLabel {
                                    x: Math.max(profileChart.plotLeft, Math.min(profileChart.width - width - profileChart.plotRight, profileChart.xForDistance(profileChart.currentDistance) - (width * 0.5)))
                                    y: ScreenTools.defaultFontPixelHeight * 0.12
                                    color: "#71757B"
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.48
                                    text: root._formatReplayTime(profileChart.elapsedSeconds)
                                }

                                Repeater {
                                    model: 4
                                    delegate: QGCLabel {
                                        required property int index
                                        color: "#696E74"
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.48
                                        text: root._formatReplayTime(root._profileTotalDurationSeconds(profileChart.points) * (index + 1) / 4)
                                        y: ScreenTools.defaultFontPixelHeight * 0.12
                                        x: profileChart.plotLeft + ((profileChart.plotWidth - width) * (index + 1) / 4)
                                    }
                                }

                                Repeater {
                                    model: 4
                                    delegate: QGCLabel {
                                        required property int index
                                        readonly property real altitudeValue: Number(profileChart.stats.maxAlt) - ((Number(profileChart.stats.maxAlt) - Number(profileChart.stats.minAlt)) * index / 3)
                                        x: ScreenTools.defaultFontPixelWidth * 0.2
                                        y: profileChart.plotTop + ((profileChart.plotHeight - height) * index / 3)
                                        color: "#A5A7AA"
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.54
                                        text: root._formatProfileAltitude(altitudeValue)
                                    }
                                }

                                Repeater {
                                    model: profileChart.points
                                    delegate: Item {
                                                required property int index

                                        readonly property bool _current: profileChart.currentPointIndex === index

                                        width: ScreenTools.defaultFontPixelHeight * 1.22
                                        height: width
                                        x: profileChart.xForDistance(modelData.distance) - (width * 0.5)
                                        y: profileChart.yForAltitude(modelData.altitude) - (height * 0.5)

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: width / 2
                                            color: _current ? "#53B84F" : "#9E5B2E"
                                            border.width: _current ? 2 : 1
                                            border.color: _current ? "#E9F7E8" : "#F2A462"
                                        }

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: parent.width + (ScreenTools.defaultFontPixelHeight * 0.75)
                                            height: width
                                            radius: width / 2
                                            visible: _current
                                            color: "transparent"
                                            border.width: 2
                                            border.color: Qt.rgba(1, 1, 1, 0.7)
                                        }

                                        QGCLabel {
                                            anchors.centerIn: parent
                                            color: "#FFFFFF"
                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                                            text: modelData.label
                                        }

                                        QGCMouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                const totalDistance = Math.max(Number(profileChart.stats.totalDistance), 1)
                                                root._profilePlaybackActive = false
                                                root._profileProgress = Math.max(0, Math.min(1, Number(modelData.distance) / totalDistance))
                                                if (modelData.coordinate && modelData.coordinate.isValid) {
                                                    mapView.center = modelData.coordinate
                                                }
                                            }
                                        }
                                    }
                                }

                                QGCColoredImage {
                                    width: ScreenTools.defaultFontPixelHeight * 1.55
                                    height: width
                                    color: "#55C2F8"
                                    fillMode: Image.PreserveAspectFit
                                    source: "/InstrumentValueIcons/drone.svg"
                                    x: profileChart.xForDistance(Number(profileChart.stats.totalDistance) * root._profileProgress) - (width * 0.5)
                                    y: profileChart.yForAltitude(profileChart.altitudeAtProgress(root._profileProgress)) - (height * 0.5)
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true

                                    function updateProgress(mouseX) {
                                        const ratio = (mouseX - profileChart.plotLeft) / Math.max(profileChart.plotWidth, 1)
                                        root._profilePlaybackActive = false
                                        root._profileProgress = Math.max(0, Math.min(1, ratio))
                                    }

                                    onPressed: (mouse) => updateProgress(mouse.x)
                                    onPositionChanged: (mouse) => {
                                        if (pressed) {
                                            updateProgress(mouse.x)
                                        }
                                    }
                                }

                                Repeater {
                                    model: 6
                                    delegate: QGCLabel {
                                        required property int index
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.18
                                        color: "#B5B5B5"
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.58
                                        text: root._formatProfileAxisDistance(Number(profileChart.stats.totalDistance) * index / 5)
                                        x: profileChart.plotLeft + ((profileChart.plotWidth - width) * index / 5)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
}
}


