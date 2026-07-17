import QGroundControl
import QGroundControl.Cluster
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.FlightMap
import QGroundControl.FlyView
import QGroundControl.Toolbar
import QGroundControl.VehicleSetup
import QtQml.Models
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Window

Item {
    id: root

    property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property bool _activeVehicleSwitchPending: false
    property bool _allowTakeoffSegment: true  // 控制是否允许进入起飞段
    property var _clusterWorkspaceWindow: null
    readonly property real _defaultRtlReturnAltMeters: 40  // 默认返航高度，可以在这里修改

    readonly property bool _flightModeConfirmationVisible: !!_activeVehicle && (_pendingFlightModeVehicleId === _activeVehicle.id) && (_pendingFlightMode !== "") && (_pendingFlightMode !== _activeVehicle.flightMode)
    property bool _instrumentPanelVisible: false
    property bool _isFullWindowItemDark: (typeof mapView !== "undefined" && mapView) ? mapView.isSatelliteMap : false
    // 用于减少日志输出的变量
    property real _lastLoggedAltitude: NaN
    property string _lastLoggedSegment: ""
    property int _latestVehicleMessageLevel: 0
    property string _latestVehicleMessageText: ""
    property bool _latestVehicleMessageVisible: false
    property var _recentVehicleAlertMessages: []
    property bool _vehicleAlertUrgentAcknowledged: false
    property bool _vehicleAlertFlashActive: false
    readonly property real _leftPaneMaxWidth: ScreenTools.defaultFontPixelWidth * 42
    readonly property real _leftPaneMinWidth: ScreenTools.defaultFontPixelWidth * 20
    readonly property real _leftPaneWidth: {
        const totalWidth = Number(width);
        if (isNaN(totalWidth) || totalWidth <= 0) {
            return ScreenTools.defaultFontPixelWidth * 24;
        }
        const desiredWidth = Math.max(ScreenTools.defaultFontPixelWidth * 24, Math.min(totalWidth * 0.23, _leftPaneMaxWidth));
        const maxAllowedWidth = Math.max(_leftPaneMinWidth, totalWidth - _margin - _rightPaneMinWidth);
        return Math.max(_leftPaneMinWidth, Math.min(desiredWidth, maxAllowedWidth));
    }
    property string _mapNavigationSelection: ""
    property int _mapPrimarySliderAction: 0
    property bool _mapStripExpanded: true
    readonly property real _margin: ScreenTools.defaultFontPixelHeight * 0.45
    property var _missionController: planControllerInternal ? planControllerInternal.missionController : null
    property bool _missionPathSwitchSuppressed: false
    property string _pendingFlightMode: ""
    property int _pendingFlightModeVehicleId: -1
    property int _pendingStartMissionAttempts: 0
    property int _pendingStartMissionSequence: -1
    property bool _profileDebugLogging: false
    property real _profileLiveAltitude: NaN
    property real _profileLiveDistance: 0
    property int _profileLivePointIndex: -1
    property string _profileLiveSegment: ""
    property var _profileMissionPoints: []
    property bool _profileMissionTreeExpanded: true
    readonly property real _profilePanelCollapsedHeight: ScreenTools.defaultFontPixelHeight * 2.3
    property bool _profilePanelExpanded: true
    property real _profilePanelExpandedHeight: _profilePanelTargetHeight
    readonly property real _profilePanelMaxExpandedHeight: Math.max(ScreenTools.defaultFontPixelHeight * 17, height * 0.48)
    readonly property real _profilePanelMinExpandedHeight: Math.max(ScreenTools.defaultFontPixelHeight * 10.5, height * 0.22)
    readonly property real _profilePanelTargetHeight: Math.max(ScreenTools.defaultFontPixelHeight * 12.8, height * 0.3)
    property bool _profilePlaybackActive: false
    property real _profilePlaybackSpeed: 1
    property real _profileProgress: 0
    property real _profileReturnAltitudeSnapshot: NaN
    property bool _profileReturnSegmentActive: false
    readonly property var _profileSiteGroups: root._buildProfileSiteGroups(root._profileMissionPoints)
    property bool _profileVehicleTreeExpanded: true
    readonly property real _radius: ScreenTools.defaultFontPixelHeight * 0.35
    readonly property real _rightPaneMinWidth: ScreenTools.defaultFontPixelWidth * 24
    readonly property real _rightPaneWidth: {
        const totalWidth = Number(width);
        const leftWidth = Number(_leftPaneWidth);
        const marginWidth = Number(_margin);
        if (isNaN(totalWidth) || isNaN(leftWidth) || isNaN(marginWidth)) {
            return 0;
        }
        return Math.max(0, totalWidth - leftWidth - marginWidth);
    }
    property bool _showFlightPath: true
    readonly property bool _startMissionAlreadyStarted: !!(guidedActionsController && guidedActionsController._missionActive)
    property bool _startMissionCommandIssued: false
    readonly property bool _startMissionEntryVisible: !!guidedActionsController &&
                                                      !!root._activeVehicle &&
                                                      root._hasStartMissionItems() &&
                                                      !root._startMissionCommandIssued &&
                                                      !root._startMissionAlreadyStarted &&
                                                      (guidedActionsController.showContinueMission ||
                                                       (!root._startMissionVehicleInAir &&
                                                        root._missionReadyForStart()))
    readonly property int _startMissionExecuteMaxAttempts: 12
    property bool _startMissionFeedbackIsError: false
    property string _startMissionFeedbackText: ""
    property string _startMissionFeedbackTitle: ""
    property bool _startMissionFeedbackVisible: false
    property bool _startMissionSliderVisible: false
    property string _startMissionUnavailableDialogText: ""
    property bool _startMissionUnavailableDialogVisible: false
    readonly property bool _startMissionVehicleInAir: {
        const altitude = root._activeVehicle && root._activeVehicle.altitudeRelative ? Number(root._activeVehicle.altitudeRelative.rawValue) : NaN;
        return !!((guidedActionsController && guidedActionsController._vehicleFlying) || (root._activeVehicle && root._activeVehicle.flying) || (!isNaN(altitude) && altitude > 2.0));
    }
    property bool _trafficViewVisible: false
    property bool _useExternalStartMissionUi: false
    property real _vehicleActualAltitude: NaN
    property real _vehicleClimbRate: NaN
    property bool _vehicleIsFlying: _activeVehicle !== null && _activeVehicle.flying === true
    property string _vehicleSearchText: ""

    ClusterManager {
        id: clusterManager
    }
    readonly property real _vehicleStatusExtraHeight: ScreenTools.realPixelDensity * 15
    property var _vehicleStatusIconMap: ({})
    readonly property var _vehicleStatusIconOptions: [
        {
            "source": "/InstrumentValueIcons/drone.svg",
            "label": qsTr("Drone")
        },
        {
            "source": "/InstrumentValueIcons/airplane-outline.svg",
            "label": qsTr("Airplane")
        }
    ]
    property int _vehicleStatusPageIndex: 0
    property bool _videoOverlayExpanded: false
    property var activeVehicleFactsController: activeVehicleFactsLoader.item
    property var guidedController: guidedActionsController
    property real last_x: 0
    property var planController: planControllerInternal
    property alias preFlightChecklistPopupItem: preFlightChecklistPopup

    function _activeBatteryForVehicle(vehicle) {
        if (!vehicle || !vehicle.batteries || vehicle.batteries.count === 0) {
            return null;
        }
        return vehicle.batteries.get(0);
    }

    function _altitudeInterpolatedSegmentPosition(points, fromIndex, toIndex, liveAltitude, vehicleCoord, anchorAtFromPoint) {
        //console.log("=== _altitudeInterpolatedSegmentPosition ===")
        // console.log("fromIndex:", fromIndex, "toIndex:", toIndex, "liveAltitude:", liveAltitude, "anchorAtFromPoint:", anchorAtFromPoint)

        if (!points || fromIndex < 0 || toIndex >= points.length || isNaN(liveAltitude)) {
            //  console.log("Invalid input parameters")
            return {
                "valid": false
            };
        }

        const fromPoint = points[fromIndex];
        const toPoint = points[toIndex];
        if (!fromPoint || !toPoint || !fromPoint.coordinate || !toPoint.coordinate || !fromPoint.coordinate.isValid || !toPoint.coordinate.isValid) {
            // console.log("Invalid points or coordinates")
            return {
                "valid": false
            };
        }

        const fromAltitude = Number(fromPoint.altitude);
        const toAltitude = Number(toPoint.altitude);
        const altitudeSpan = toAltitude - fromAltitude;
        // console.log("fromAltitude:", fromAltitude, "toAltitude:", toAltitude, "altitudeSpan:", altitudeSpan)

        if (Math.abs(altitudeSpan) < 0.5) {
            // console.log("Altitude span too small")
            return {
                "valid": false
            };
        }

        // 放宽位置检查：只要高度在范围内，就认为可能在这个垂直段
        const minAltitude = Math.min(fromAltitude, toAltitude) - 1.0;
        const maxAltitude = Math.max(fromAltitude, toAltitude) + 1.0;
        // console.log("Altitude range: [", minAltitude, ",", maxAltitude, "]")

        if (liveAltitude < minAltitude || liveAltitude > maxAltitude) {
            // console.log("Live altitude out of range")
            return {
                "valid": false
            };
        }

        // 如果有位置信息，检查是否在合理范围内（放宽到 50 米）
        if (vehicleCoord && vehicleCoord.isValid) {
            const anchorCoordinate = anchorAtFromPoint ? fromPoint.coordinate : toPoint.coordinate;
            const anchorThreshold = 50;  // 统一使用 50 米阈值
            const coordClose = _coordinatesClose(vehicleCoord, anchorCoordinate, anchorThreshold);
            // console.log("Vehicle coord close to anchor (50m):", coordClose)

            if (!coordClose) {
                // 位置不匹配，但如果高度匹配得很好，仍然可以使用
                const altitudeMatch = Math.abs(liveAltitude - fromAltitude) < 2.0 || Math.abs(liveAltitude - toAltitude) < 2.0;
                // console.log("Position not close, altitude match:", altitudeMatch)
                if (!altitudeMatch) {
                    return {
                        "valid": false
                    };
                }
            }
        }

        // 使用高度比例计算距离
        // 对于起飞段（anchorAtFromPoint=true），允许负值范围以处理飞机在起点下方的情况
        // 对于其他垂直段，严格限制在 [0, 1] 范围内
        const ratio = (Number(liveAltitude) - fromAltitude) / altitudeSpan;
        const clampedRatio = anchorAtFromPoint ? Math.max(-0.5, Math.min(1.5, ratio))  // 起飞段：允许 [-0.5, 1.5] 范围
        : Math.max(0, Math.min(1, ratio));       // 其他段：严格 [0, 1] 范围

        // 根据高度比例计算距离（用于进度跟踪）
        const segmentDistance = Number(fromPoint.distance) + ((Number(toPoint.distance) - Number(fromPoint.distance)) * clampedRatio);
        const pointIndex = toIndex;

        return {
            "valid": true,
            "distance": segmentDistance,
            "altitude": Number(liveAltitude),
            "ratio": clampedRatio,
            "pointIndex": pointIndex
        };
    }

    function _appendReturnProfilePoints(points, distance, returnAnchor = null) {
        if (!points || points.length === 0) {
            return distance;
        }

        const homeCoord = _missionHomeCoordinate();
        const anchor = returnAnchor || _missionReturnAnchor();
        const anchorCoordinate = anchor && anchor.coordinate && anchor.coordinate.isValid ? anchor.coordinate : null;
        const anchorAltitude = anchor && !isNaN(Number(anchor.altitude)) ? Number(anchor.altitude) : NaN;
        const lastPoint = points[points.length - 1];
        const sourceCoordinate = anchorCoordinate || (lastPoint && lastPoint.coordinate && lastPoint.coordinate.isValid ? lastPoint.coordinate : null);
        const sourceAltitude = !isNaN(anchorAltitude) ? anchorAltitude : (lastPoint ? Number(lastPoint.altitude) : NaN);
        if (!homeCoord || !homeCoord.isValid || !sourceCoordinate || !sourceCoordinate.isValid) {
            return distance;
        }

        const returnDistance = Number(sourceCoordinate.distanceTo(homeCoord));
        if (isNaN(returnDistance) || returnDistance <= 0.5) {
            return distance;
        }

        root._profileReturnAltitudeSnapshot = root._plannedReturnAltitudeMeters(sourceAltitude, returnDistance);
        const returnAltitude = isNaN(root._profileReturnAltitudeSnapshot) ? (isNaN(sourceAltitude) ? 0 : sourceAltitude) : Number(root._profileReturnAltitudeSnapshot);

        // Add a pure climb leg at the last mission coordinate so RTL renders as climb -> cruise -> descend.
        points.push({
            "label": "",
            "distance": distance,
            "altitude": returnAltitude,
            "coordinate": sourceCoordinate,
            "profileGenerated": true,
            "profileHiddenMarker": true
        });

        distance += returnDistance;

        points.push({
            "label": "R",
            "distance": distance,
            "altitude": returnAltitude,
            "coordinate": homeCoord,
            "profileGenerated": true
        });

        points.push({
            "label": "H",
            "distance": distance,
            "altitude": 0,
            "coordinate": homeCoord,
            "profileGenerated": true
        });

        return distance;
    }

    function _batteryIcon(percent) {
        if (isNaN(percent)) {
            return "/InstrumentValueIcons/battery-half.svg";
        }
        if (percent <= 25) {
            return "/InstrumentValueIcons/battery-low.svg";
        }
        if (percent <= 60) {
            return "/InstrumentValueIcons/battery-half.svg";
        }
        return "/InstrumentValueIcons/battery-full.svg";
    }

    function _batteryPercentForVehicle(vehicle) {
        if (!vehicle || !vehicle.batteries || vehicle.batteries.count === 0) {
            return NaN;
        }
        const battery = vehicle.batteries.get(0);
        return battery && _hasFactValue(battery.percentRemaining) ? Number(battery.percentRemaining.rawValue) : NaN;
    }

    function _batteryTextForVehicle(vehicle) {
        if (!vehicle || !vehicle.batteries || vehicle.batteries.count === 0) {
            return qsTr("Battery --");
        }
        const battery = vehicle.batteries.get(0);
        return battery && _hasFactValue(battery.percentRemaining) ? qsTr("Battery %1%2").arg(battery.percentRemaining.valueString).arg(battery.percentRemaining.units) : qsTr("Battery --");
    }

    function _buildMissionProfilePoints() {
        const points = [];
        root._profileReturnAltitudeSnapshot = NaN;
        const missionController = planControllerInternal ? planControllerInternal.missionController : null;
        const visualItems = missionController ? missionController.visualItems : null;
        if (!visualItems || visualItems.count <= 1) {
            return [];
        }

        let distance = 0;
        let previousCoord = null;

        // Add an explicit ground-origin point at home so takeoff can render as a climb from 0 m.
        const homeCoord = _missionHomeCoordinate();
        if (homeCoord && homeCoord.isValid) {
            points.push({
                "label": "",
                "distance": 0,
                "altitude": 0,
                "coordinate": homeCoord,
                "profileHiddenMarker": true,
                "profileGroundOrigin": true
            });
            previousCoord = homeCoord;
        }

        const generatedTakeoffPoint = _generatedTakeoffProfilePoint(homeCoord, visualItems);
        if (generatedTakeoffPoint) {
            points.push(generatedTakeoffPoint);
        }

        if (visualItems && visualItems.count > 0) {
            for (let i = 0; i < visualItems.count; i++) {
                const pointData = _missionProfileItemData(visualItems.get(i), points.length + 1);
                if (!pointData) {
                    continue;
                }

                const coord = pointData.coordinate;
                let pointDistance = Number(pointData.distance);
                if (isNaN(pointDistance)) {
                    if (previousCoord && previousCoord.isValid) {
                        distance += previousCoord.distanceTo(coord);
                    }
                    pointDistance = distance;
                }
                previousCoord = coord;
                distance = pointDistance;

                points.push({
                    "label": pointData.label,
                    "distance": pointDistance,
                    "altitude": pointData.altitude,
                    "coordinate": coord
                });
            }
        }

        const returnSourcePoint = points.length > 0 ? points[points.length - 1] : null;
        distance = _appendReturnProfilePoints(points, distance, returnSourcePoint);

        if (points.length < 2) {
            return [];
        }

        return points;
    }

    function _buildProfileSiteGroups(points) {
        const groups = [];
        if (!points || points.length === 0) {
            return groups;
        }

        const visiblePoints = points.filter(point => point.profileHiddenMarker !== true);
        if (visiblePoints.length === 0) {
            return groups;
        }

        const requestedSiteCount = visiblePoints.length > 1 ? 2 : 1;
        const siteCount = Math.min(requestedSiteCount, visiblePoints.length);
        const chunkSize = Math.ceil(visiblePoints.length / siteCount);

        for (let i = 0; i < siteCount; i++) {
            const startIndex = i * chunkSize;
            if (startIndex >= visiblePoints.length) {
                break;
            }
            const endIndex = Math.min(visiblePoints.length - 1, ((i + 1) * chunkSize) - 1);
            const startPoint = visiblePoints[startIndex];
            const endPoint = visiblePoints[endIndex];
            groups.push({
                "label": qsTr("测区 %1").arg(i + 1),
                "startIndex": startIndex,
                "endIndex": endIndex,
                "startDistance": Number(startPoint.distance),
                "endDistance": Number(endPoint.distance),
                "altitude": Number(endPoint.altitude),
                "coordinate": startPoint.coordinate
            });
        }

        return groups;
    }

    function _clampPercent(value) {
        const numeric = Number(value);
        if (isNaN(numeric)) {
            return NaN;
        }
        return Math.max(0, Math.min(100, numeric));
    }

    function _clampProfilePanelHeight(value) {
        const numericValue = Number(value);
        const fallbackHeight = _profilePanelTargetHeight;
        const safeValue = isNaN(numericValue) || numericValue <= 0 ? fallbackHeight : numericValue;
        return Math.max(_profilePanelMinExpandedHeight, Math.min(_profilePanelMaxExpandedHeight, safeValue));
    }

    function _cleanVehicleMessageText(message) {
        let text = message || "";
        text = text.replace(/<[^>]*>/g, " ");
        text = text.replace(/&nbsp;/g, " ");
        text = text.replace(/&lt;/g, "<");
        text = text.replace(/&gt;/g, ">");
        text = text.replace(/&amp;/g, "&");
        text = text.replace(/\s+/g, " ").trim();
        text = text.replace(/No valid mission available, loitering/gi, qsTr("没有可执行的有效任务，飞行器正在保持/盘旋"));
        text = text.replace(/No valid mission available/gi, qsTr("没有可执行的有效任务"));
        text = text.replace(/Mission rejected/gi, qsTr("任务被拒绝"));
        text = text.replace(/Mission upload failed/gi, qsTr("任务上传失败"));
        text = text.replace(/Mission transfer failed/gi, qsTr("任务传输失败"));
        text = text.replace(/Mission accepted/gi, qsTr("任务已接受"));
        text = text.replace(/Mission finished/gi, qsTr("任务已完成"));
        text = text.replace(/Geofence violation/gi, qsTr("触发地理围栏限制"));
        text = text.replace(/Failsafe enabled/gi, qsTr("失效保护已触发"));
        text = text.replace(/Failsafe activated/gi, qsTr("失效保护已激活"));
        text = text.replace(/Battery low/gi, qsTr("电池电量低"));
        text = text.replace(/GPS signal lost/gi, qsTr("GPS 信号丢失"));
        text = text.replace(/Manual control lost/gi, qsTr("手动控制链路丢失"));
        text = text.replace(/Data link lost/gi, qsTr("数传链路丢失"));
        text = text.replace(/Return to launch/gi, qsTr("正在返航"));
        text = text.replace(/Takeoff detected/gi, qsTr("检测到起飞"));
        text = text.replace(/Landing detected/gi, qsTr("检测到降落"));
        text = text.replace(/Switching to mode 'Position control' is currently not possible No manual control input/gi, qsTr("当前无法切换到“位置控制”模式：没有手动控制输入"));
        text = text.replace(/No manual control input/gi, qsTr("没有手动控制输入"));
        text = text.replace(/GCS connection regained/gi, qsTr("地面站连接已恢复"));
        text = text.replace(/GCS connection lost/gi, qsTr("地面站连接丢失"));
        return text;
    }

    function _vehicleMessageLevelFromText(message) {
        const text = (message || "").toString();
        if (/\b(Emergency|Alert|Critical|Error)\b/i.test(text)) {
            return 3;
        }
        if (/\bWarning\b/i.test(text)) {
            return 2;
        }
        return 1;
    }

    function _rememberVehicleAlertMessage(message, level = -1) {
        const cleanMessage = root._cleanVehicleMessageText(message);
        if (cleanMessage === "") {
            return;
        }
        const alertLevel = Number(level) > 0 ? Number(level) : root._vehicleMessageLevelFromText(message);

        const nextMessages = [
            {
                "text": cleanMessage,
                "level": alertLevel
            }
        ];
        for (let i = 0; i < root._recentVehicleAlertMessages.length && nextMessages.length < 8; i++) {
            const existingMessage = root._recentVehicleAlertMessages[i];
            const existingText = existingMessage && existingMessage.text !== undefined ? existingMessage.text : existingMessage;
            if (existingText !== cleanMessage) {
                nextMessages.push(existingMessage);
            }
        }
        root._recentVehicleAlertMessages = nextMessages;
    }

    function _triggerVehicleAlertFlash(level) {
        if (Number(level) < 2) {
            return;
        }
        root._vehicleAlertUrgentAcknowledged = false;
        root._vehicleAlertFlashActive = false;
        root._vehicleAlertFlashActive = true;
        vehicleAlertFlashTimer.restart();
    }

    function _stopVehicleAlertFlash() {
        root._vehicleAlertFlashActive = false;
        vehicleAlertFlashTimer.stop();
    }

    function _acknowledgeVehicleAlertMessages() {
        root._vehicleAlertUrgentAcknowledged = true;
        root._stopVehicleAlertFlash();
    }

    function _clearClusterVehicleState(vehicle) {
    }

    function _clearPendingFlightMode() {
        _pendingFlightMode = "";
        _pendingFlightModeVehicleId = -1;
    }

    function _clearPendingStartMission() {
        root._pendingStartMissionAttempts = 0;
        root._pendingStartMissionSequence = -1;
        startMissionExecuteTimer.stop();
    }

    function _clusterFact(vehicle, paramName) {
        if (!_clusterParameterExists(vehicle, paramName)) {
            return null;
        }
        return vehicle.parameterManager.getParameter(-1, paramName);
    }

    function _clusterGroup(vehicle) {
        const fact = _clusterFact(vehicle, "SWARM_GROUP_ID");
        if (!fact) {
            return 0;
        }
        const value = Number(fact.rawValue);
        return isNaN(value) ? 0 : Math.max(0, Math.round(value));
    }

    function _clusterLeader(vehicle) {
        const fact = _clusterFact(vehicle, "SWARM_SET_LEADER");
        if (!fact) {
            return false;
        }
        const value = Number(fact.rawValue);
        return !isNaN(value) && value > 0;
    }

    function _clusterParameterExists(vehicle, paramName) {
        const parameterManager = _vehicleParameterManager(vehicle);
        return !!(parameterManager && parameterManager.parametersReady && parameterManager.parameterExists(-1, paramName));
    }

    function _communicationMeshLinkQualityPercent() {
        const vehicles = QGroundControl.multiVehicleManager.vehicles;
        if (!vehicles || vehicles.count <= 0) {
            return 98;
        }

        let totalQuality = 0;
        for (let i = 0; i < vehicles.count; i++) {
            const vehicle = vehicles.get(i);
            if (!vehicle) {
                continue;
            }

            let quality = _communicationTelemetryQualityPercent(vehicle);
            if (isNaN(quality)) {
                quality = vehicle.communicationLost ? 45 : 88;
            }

            totalQuality += Math.max(0, Math.min(100, quality));
        }

        const averageQuality = totalQuality / Math.max(1, vehicles.count);
        const onlineNodes = _communicationMeshOnlineNodes();
        const totalNodes = _communicationMeshTotalNodes();
        const coverage = Math.max(0, Math.min(1, onlineNodes / Math.max(totalNodes, 1)));
        const score = (averageQuality * 0.82) + ((coverage * 100) * 0.18);
        return Math.round(Math.max(0, Math.min(100, score)));
    }

    function _communicationMeshOnlineNodes() {
        const vehicles = QGroundControl.multiVehicleManager.vehicles;
        if (!vehicles || vehicles.count <= 0) {
            return 5;
        }

        let online = 0;
        for (let i = 0; i < vehicles.count; i++) {
            const vehicle = vehicles.get(i);
            if (!vehicle) {
                continue;
            }
            const telemetryQuality = _communicationTelemetryQualityPercent(vehicle);
            const communicationHealthy = (vehicle.communicationLost !== undefined) ? !vehicle.communicationLost : true;
            if (communicationHealthy || (!isNaN(telemetryQuality) && telemetryQuality > 30)) {
                online++;
            }
        }

        return Math.max(0, Math.min(vehicles.count, online));
    }

    function _communicationMeshStatusText(percent, onlineNodes, totalNodes) {
        if (totalNodes <= 0) {
            return qsTr("Stable");
        }
        if (onlineNodes <= 0) {
            return qsTr("Down");
        }
        if (percent >= 90 && onlineNodes === totalNodes) {
            return qsTr("Stable");
        }
        if (percent >= 75 && onlineNodes >= Math.max(1, totalNodes - 1)) {
            return qsTr("Stable");
        }
        if (percent >= 55) {
            return qsTr("Degraded");
        }
        return qsTr("Unstable");
    }

    function _communicationMeshTotalNodes() {
        const vehicles = QGroundControl.multiVehicleManager.vehicles;
        if (!vehicles || vehicles.count <= 0) {
            return 5;
        }
        return vehicles.count;
    }

    function _communicationStatusColor(percent) {
        if (isNaN(percent) || percent < 0) {
            return "#6A7078";
        }
        if (percent >= 90) {
            return "#00C7A4";
        }
        if (percent >= 75) {
            return "#00BE8A";
        }
        if (percent >= 55) {
            return "#65D4A7";
        }
        if (percent >= 35) {
            return "#D6A566";
        }
        return "#C66D72";
    }

    function _communicationTelemetryLossPercent(vehicle) {
        if (!vehicle) {
            return 0;
        }

        const mavlinkLoss = Number(vehicle.mavlinkLossPercent);
        if (!isNaN(mavlinkLoss)) {
            return Math.max(0, Math.min(100, Math.round(mavlinkLoss)));
        }

        const received = Number(vehicle.messagesReceived);
        const lost = Number(vehicle.messagesLost);
        const total = received + lost;
        if (!isNaN(total) && total > 0 && !isNaN(lost)) {
            return Math.max(0, Math.min(100, Math.round((lost / total) * 100)));
        }

        return 0;
    }

    function _communicationTelemetryQualityPercent(vehicle) {
        if (!vehicle) {
            return 100;
        }

        const telemetryPercent = _networkTelemetryPercent(vehicle);
        if (!isNaN(telemetryPercent)) {
            return Math.max(0, Math.min(100, Math.round(telemetryPercent)));
        }

        const rssiDbm = _communicationTelemetryRssiDbm(vehicle);
        if (!isNaN(rssiDbm)) {
            return Math.max(0, Math.min(100, Math.round(((rssiDbm + 120) / 90) * 100)));
        }

        return 100;
    }

    function _communicationTelemetryRssiDbm(vehicle) {
        if (!vehicle) {
            return -65;
        }

        const rssiCandidates = [Number(vehicle.telemetryLRSSI), Number(vehicle.telemetryRRSSI)];
        const converted = [];

        for (let i = 0; i < rssiCandidates.length; i++) {
            const rawValue = Number(rssiCandidates[i]);
            if (isNaN(rawValue) || rawValue === 0) {
                continue;
            }
            if (rawValue <= -30 && rawValue >= -120) {
                converted.push(rawValue);
                continue;
            }
            if (rawValue > 0 && rawValue <= 254) {
                converted.push(-120 + ((rawValue / 254) * 90));
            }
        }

        if (converted.length === 0) {
            return -65;
        }

        let total = 0;
        for (let i = 0; i < converted.length; i++) {
            total += Number(converted[i]);
        }
        return Math.round(total / converted.length);
    }

    function _communicationTelemetryStatusText(percent) {
        if (isNaN(percent)) {
            return qsTr("Good");
        }
        if (percent >= 75) {
            return qsTr("Good");
        }
        if (percent >= 55) {
            return qsTr("Fair");
        }
        if (percent >= 35) {
            return qsTr("Weak");
        }
        return qsTr("Poor");
    }

    function _communicationVideoBitrateMbps(vehicle) {
        if (!vehicle) {
            return 4.2;
        }

        const streamInfo = _communicationVideoStreamInfo(vehicle);
        const bitrateBits = streamInfo && streamInfo.bitrate !== undefined ? Number(streamInfo.bitrate) : NaN;
        if (!isNaN(bitrateBits) && bitrateBits > 0) {
            return Math.round(((bitrateBits / 1000000) * 10)) / 10;
        }

        const telemetryQuality = _communicationTelemetryQualityPercent(vehicle);
        if (isNaN(telemetryQuality)) {
            return 4.2;
        }

        const estimated = 1.4 + (telemetryQuality * 0.028);
        return Math.round((Math.max(0.8, Math.min(9.5, estimated)) * 10)) / 10;
    }

    function _communicationVideoFps(vehicle) {
        if (!vehicle) {
            return 25;
        }

        const streamInfo = _communicationVideoStreamInfo(vehicle);
        const framerate = streamInfo && streamInfo.framerate !== undefined ? Number(streamInfo.framerate) : NaN;
        if (!isNaN(framerate) && framerate > 0) {
            return Math.round(Math.max(1, framerate));
        }

        const bitrate = _communicationVideoBitrateMbps(vehicle);
        if (isNaN(bitrate)) {
            return 25;
        }

        return Math.round(Math.max(8, Math.min(60, 16 + (bitrate * 2.2))));
    }

    function _communicationVideoLatencyMs(vehicle) {
        if (!vehicle) {
            return 110;
        }

        const telemetryQuality = _communicationTelemetryQualityPercent(vehicle);
        const lossPercent = Number(vehicle.mavlinkLossPercent);
        const rxErrors = Number(vehicle.telemetryRXErrors);
        let estimate = 92;

        estimate += isNaN(telemetryQuality) ? 18 : ((100 - telemetryQuality) * 0.45);
        if (!isNaN(lossPercent)) {
            estimate += Math.min(120, Math.max(0, lossPercent) * 1.8);
        }
        if (!isNaN(rxErrors) && rxErrors > 0) {
            estimate += Math.min(70, Math.log(rxErrors + 1) * 9);
        }
        if (QGroundControl.videoManager && !QGroundControl.videoManager.hasVideo) {
            estimate += 8;
        }

        return Math.round(Math.max(70, Math.min(360, estimate)));
    }

    function _communicationVideoQualityPercent(vehicle, bitrateMbps = NaN, fps = NaN, latencyMs = NaN) {
        if (!vehicle) {
            return 98;
        }

        const bitrate = isNaN(Number(bitrateMbps)) ? _communicationVideoBitrateMbps(vehicle) : Number(bitrateMbps);
        const frameRate = isNaN(Number(fps)) ? _communicationVideoFps(vehicle) : Number(fps);
        const latency = isNaN(Number(latencyMs)) ? _communicationVideoLatencyMs(vehicle) : Number(latencyMs);
        const loss = _communicationTelemetryLossPercent(vehicle);
        const telemetryQuality = _communicationTelemetryQualityPercent(vehicle);

        let score = 82;
        score += (Math.max(0.8, Math.min(10, bitrate)) - 2.5) * 6;
        score += (Math.max(8, Math.min(60, frameRate)) - 20) * 1.6;
        score -= Math.max(0, latency - 90) * 0.45;
        score -= Math.max(0, loss) * 1.5;
        score = (score * 0.72) + (telemetryQuality * 0.28);

        return Math.round(Math.max(0, Math.min(100, score)));
    }

    function _communicationVideoStatusText(percent) {
        if (isNaN(percent)) {
            return qsTr("Excellent");
        }
        if (percent >= 90) {
            return qsTr("Excellent");
        }
        if (percent >= 75) {
            return qsTr("Good");
        }
        if (percent >= 55) {
            return qsTr("Fair");
        }
        return qsTr("Weak");
    }

    function _communicationVideoStreamInfo(vehicle) {
        const cameraManager = vehicle ? vehicle.cameraManager : null;
        const camera = cameraManager ? cameraManager.currentCameraInstance : null;
        return camera ? camera.currentStreamInstance : null;
    }

    function _compactPrearmReason(vehicle) {
        if (!vehicle) {
            return qsTr("连接飞行器后查看就绪状态");
        }
        if (vehicle.communicationLost) {
            return qsTr("通信已中断");
        }

        const report = vehicle.healthAndArmingCheckReport;
        if (report && report.supported && report.problemsForCurrentMode && report.problemsForCurrentMode.count > 0) {
            const problem = report.problemsForCurrentMode.get(0);
            if (problem && problem.message) {
                return _stripRichText(problem.message);
            }
        }

        if (!vehicle.armed && vehicle.prearmError) {
            const prearmError = _stripRichText(vehicle.prearmError);
            if (prearmError !== "") {
                return prearmError;
            }
        }

        if (vehicle.readyToFlyAvailable !== undefined && !vehicle.readyToFly) {
            return qsTr("飞行器仍在完成飞行前检查");
        }

        return _compactReadinessLevel(vehicle) === 0 ? qsTr("飞行器可以解锁") : qsTr("起飞前请检查飞行器状态");
    }

    function _compactReadinessColor(vehicle) {
        const level = _compactReadinessLevel(vehicle);
        if (level >= 2) {
            return "#E26D71";
        }
        if (level === 1) {
            return "#D6A566";
        }
        return "#00BE8A";
    }

    function _compactReadinessLevel(vehicle) {
        if (!vehicle) {
            return 1;
        }
        if (vehicle.communicationLost) {
            return 2;
        }
        const report = vehicle.healthAndArmingCheckReport;
        if (report && report.supported) {
            if (vehicle.armed || vehicle.flying) {
                return report.canArm === false ? 2 : (report.hasWarningsOrErrors ? 1 : 0);
            }
            if (report.canArm === false) {
                return 2;
            }
            return report.hasWarningsOrErrors ? 1 : 0;
        }
        if (vehicle.readyToFlyAvailable !== undefined) {
            return vehicle.readyToFly ? 0 : 1;
        }
        if (vehicle.allSensorsHealthy !== undefined && vehicle.autopilotPlugin) {
            return (vehicle.allSensorsHealthy && vehicle.autopilotPlugin.setupComplete) ? 0 : 1;
        }
        return 1;
    }

    function _compactReadinessText(vehicle) {
        if (!vehicle) {
            return qsTr("Not Ready");
        }
        if (vehicle.communicationLost) {
            return qsTr("Not Ready");
        }
        return _compactReadinessLevel(vehicle) >= 2 ? qsTr("Not Ready") : qsTr("Ready");
    }

    function _compactVideoOverlayWidth(availableWidth) {
        return Math.min(availableWidth * 0.25, ScreenTools.defaultFontPixelWidth * 24);
    }

    function _computeVehicleProgressAlongMission(includeReturnSegment = false) {
        const vCoord = _activeVehicle ? _activeVehicle.coordinate : null;
        if (!vCoord || !vCoord.isValid)
            return -1;
        const pts = root._profileMissionPoints;
        if (!pts || pts.length < 2)
            return -1;
        const totalDist = Math.max(Number(_profileStats(pts).totalDistance), 1);
        let bestDist = -1;
        let minPerpDistSq = Infinity;
        if (includeReturnSegment && _coordinatesClose(vCoord, pts[0].coordinate, 2) && root._vehicleClimbRate < -0.5) {
            if (_coordinatesClose(vCoord, pts[0].coordinate, 1))
                return 1;
            //console.log("near home")
            return root.last_x;
        }

        for (let i = 1; i < pts.length; i++) {
            const A = pts[i - 1];
            const B = pts[i];
            if (!A.coordinate || !A.coordinate.isValid || !B.coordinate || !B.coordinate.isValid)
                continue;
            if (!includeReturnSegment && (A.profileGenerated || B.profileGenerated)) {
                //console.log("_computeVehicleProgressAlongMission",A.profileGenerated,B.profileGenerated,)
                continue;
            }
            const segLen = A.coordinate.distanceTo(B.coordinate);
            if (segLen < 0.1)
                continue;
            const vA = A.coordinate.distanceTo(vCoord);
            const vB = B.coordinate.distanceTo(vCoord);
            const t = Math.max(0, Math.min(1, (segLen * segLen + vA * vA - vB * vB) / (2 * segLen * segLen)));
            const projDist = t * segLen;
            const perpDistSq = Math.max(0, vA * vA - projDist * projDist);
            if (perpDistSq < minPerpDistSq) {
                minPerpDistSq = perpDistSq;
                bestDist = Number(A.distance) + projDist;
            }
        }
        root.last_x = bestDist >= 0 ? Math.max(0, Math.min(1, bestDist / totalDist)) : -1;
        return root.last_x;
    }

    function _confirmMapStripAltitudeChange(altitudeChange) {
        if (!root._activeVehicle) {
            root._showMapStripUnavailable(altitudeChange > 0 ? "up" : "down", true);
            return;
        }

        const isClimb = altitudeChange > 0;
        const title = isClimb ? qsTr("上升") : qsTr("下降");
        const absChange = Math.abs(altitudeChange);
        QGroundControl.showMessageDialog(root, title, isClimb ? qsTr("确认让飞行器上升 %1 米？").arg(absChange) : qsTr("确认让飞行器下降 %1 米？").arg(absChange), Dialog.Yes | Dialog.Cancel, function () {
            if (!root._activeVehicle) {
                return;
            }
            root._activeVehicle.guidedModeChangeAltitude(altitudeChange, false);
            root._showStartMissionFeedback(isClimb ? qsTr("上升 %1 米指令已发送。").arg(absChange) : qsTr("下降 %1 米指令已发送。").arg(absChange), false, title);
        });
    }

    function _confirmMapStripArmDisarm() {
        if (!root._activeVehicle) {
            root._showMapStripUnavailable("armDisarm", true);
            return;
        }

        const arm = !root._activeVehicle.armed;
        QGroundControl.showMessageDialog(root, arm ? qsTr("解锁") : qsTr("上锁"), arm ? qsTr("确认解锁飞行器？") : qsTr("确认上锁飞行器？"), Dialog.Yes | Dialog.Cancel, function () {
            if (root._activeVehicle) {
                root._activeVehicle.armed = arm;
            }
        });
    }

    function _confirmOneKeyRTL() {
        if (!root._activeVehicle) {
            root._showMapStripUnavailable("oneKeyRTL", true);
            return;
        }
        if (!root._isGuidedPanelActionAvailable(guidedActionsController.actionRTL)) {
            QGroundControl.showMessageDialog(root, qsTr("一键返航"), root._guidedPanelActionUnavailableMessage(guidedActionsController.actionRTL));
            return;
        }

        QGroundControl.showMessageDialog(root, qsTr("一键返航"), qsTr("确认执行一键返航？"), Dialog.Yes | Dialog.Cancel, function () {
            if (root._activeVehicle) {
                root._activeVehicle.guidedModeRTL(false);
                QGroundControl.showMessageDialog(root, qsTr("一键返航"), qsTr("返航指令已发送。"));
            }
        });
    }

    function _confirmPendingFlightMode() {
        if (!_flightModeConfirmationVisible || !_activeVehicle) {
            return;
        }
        const targetFlightMode = _pendingFlightMode;
        _activeVehicle.flightMode = targetFlightMode;
        if (_activeVehicle.flightMode === targetFlightMode) {
            _clearPendingFlightMode();
        }
    }

    function _confirmStartMissionSlider() {
        const actionToExecute = root._mapPrimarySliderAction || root._mapPrimaryActionCode();
        if (actionToExecute === guidedActionsController.actionStartMission && root._startMissionVehicleInAir) {
            root._hideStartMissionSlider();
            root._showStartMissionUnavailableDialog(qsTr("飞行器已经在飞行中，不能重新开始任务。"));
            return;
        }
        if (!root._mapPrimaryActionAvailable()) {
            root._hideStartMissionSlider();
            root._showStartMissionUnavailableDialog();
            return;
        }
        root._hideStartMissionSlider();
        switch (root._mapPrimarySliderAction) {
        case guidedActionsController.actionArm:
            root._showStartMissionFeedback(qsTr("解锁指令已发送。起飞前请确认飞行器状态。"), false);
            break;
        case guidedActionsController.actionForceArm:
            root._showStartMissionFeedback(qsTr("强制解锁指令已发送。起飞前请确认飞行器状态。"), false);
            break;
        case guidedActionsController.actionContinueMission:
            root._showStartMissionFeedback(qsTr("继续任务指令已发送。起飞前请确认飞行器状态。"), false);
            break;
        default:
            break;
        }

        if (actionToExecute === guidedActionsController.actionStartMission) {
            const firstSequence = root._firstStartMissionSequence();
            if (root._activeVehicle && firstSequence >= 0) {
                root._startMissionCommandIssued = true;
                root._pendingStartMissionAttempts = 0;
                root._pendingStartMissionSequence = firstSequence;
                root._activeVehicle.setCurrentMissionSequence(firstSequence);
                startMissionExecuteTimer.restart();
                return;
            }
        }

        if (actionToExecute === guidedActionsController.actionStartMission) {
            root._startMissionCommandIssued = true;
        }
        guidedActionsController.executeAction(actionToExecute, undefined, 0, false);
    }

    function _coordinatesClose(coord1, coord2, thresholdMeters = 3) {
        if (!coord1 || !coord2 || !coord1.isValid || !coord2.isValid) {
            return false;
        }
        return Number(coord1.distanceTo(coord2)) <= Number(thresholdMeters);
    }

    function _currentVehicleProfilePosition(points, progress, liveAltitude = NaN, liveClimbRate = NaN) {
        if (!points || points.length === 0) {
            return {
                "distance": 0,
                "altitude": liveAltitude,
                "pointIndex": -1
            };
        }

        const totalDistance = Math.max(Number(points[points.length - 1].distance), 1);
        const clampedProgress = Math.max(0, Math.min(1, Number(progress)));
        const shouldUseVehicleTrack = !!(_activeVehicle && (_vehicleIsFlying || _activeVehicle.armed));
        let currentDistance = totalDistance * clampedProgress;

        const vehicleCoord = _activeVehicle ? _activeVehicle.coordinate : null;

        if (!isNaN(liveAltitude) && points.length >= 2) {
            const takeoffPosition = _takeoffLivePosition(points, liveAltitude, vehicleCoord);
            const landingPosition = _verticalSegmentLivePosition(points, points.length - 2, points.length - 1, liveAltitude, vehicleCoord, 80);

            // 检查返航爬升段
            const returnClimbPosition = points.length >= 4 ? _verticalSegmentLivePosition(points, points.length - 4, points.length - 3, liveAltitude, vehicleCoord, 80) : {
                "valid": false
            };

            const returnModeActive = _isVehicleInReturnMode();
            const landingModeActive = _isVehicleInLandingMode();
            const descendingToHome = !isNaN(liveClimbRate) && liveClimbRate < -0.15;
            const previousSegment = root._profileLiveSegment || "";

            // 只有在真正的返航/降落模式下才认为是返航序列
            const returnSequenceActive = returnModeActive || landingModeActive;
            const includeReturnSegment = _shouldTrackReturnProfileSegment(landingPosition.valid, liveClimbRate);
            const computedProgress = shouldUseVehicleTrack ? _computeVehicleProgressAlongMission(includeReturnSegment) : -1;
            const projectedDistance = computedProgress >= 0 ? (totalDistance * computedProgress) : NaN;
            if (computedProgress >= 0) {
                currentDistance = projectedDistance;
            }
            const takeoffSegment = _takeoffProfileSegment(points);
            const takeoffAnchorPoint = takeoffSegment.valid ? points[takeoffSegment.fromIndex] : null;
            const takeoffTargetPoint = takeoffSegment.valid ? points[takeoffSegment.toIndex] : null;
            const takeoffAnchorDistance = takeoffAnchorPoint ? Number(takeoffAnchorPoint.distance) : NaN;
            const takeoffTargetAltitude = takeoffTargetPoint ? Number(takeoffTargetPoint.altitude) : NaN;
            const nearTakeoffAnchor = (!vehicleCoord || !vehicleCoord.isValid) || !!(takeoffAnchorPoint && takeoffAnchorPoint.coordinate && takeoffAnchorPoint.coordinate.isValid && _coordinatesClose(vehicleCoord, takeoffAnchorPoint.coordinate, 80));
            const takeoffStillClimbing = isNaN(takeoffTargetAltitude) || Number(liveAltitude) < (takeoffTargetAltitude - 0.5);
            const takeoffMovedAlongPath = !isNaN(projectedDistance) && !isNaN(takeoffAnchorDistance) && projectedDistance > (takeoffAnchorDistance + 3);
            const takeoffShouldUse = takeoffPosition.valid && !returnSequenceActive && !descendingToHome && !takeoffMovedAlongPath && (nearTakeoffAnchor || (previousSegment === "takeoff" && takeoffStillClimbing)) && (isNaN(takeoffTargetAltitude) || Number(liveAltitude) <= (takeoffTargetAltitude + 1.0)) && previousSegment !== "landing" && root._allowTakeoffSegment;  // 只有允许时才能进入起飞段

            // 调试：检查为什么不能进入起飞段
            if (takeoffPosition.valid && nearTakeoffAnchor && !takeoffShouldUse) {
                /*console.log(">>> 起飞段被阻止: allowTakeoff=" + root._allowTakeoffSegment
                    + " prevSeg=" + previousSegment
                    + " returnSeq=" + returnSequenceActive
                    + " descending=" + descendingToHome
                    + " moved=" + takeoffMovedAlongPath)*/
            }

            const returnClimbAnchorPoint = points.length >= 4 ? points[points.length - 4] : null;
            const returnClimbTargetPoint = points.length >= 3 ? points[points.length - 3] : null;
            const returnClimbAnchorAltitude = returnClimbAnchorPoint ? Number(returnClimbAnchorPoint.altitude) : NaN;
            const returnClimbTargetAltitude = returnClimbTargetPoint ? Number(returnClimbTargetPoint.altitude) : NaN;
            const returnClimbAnchorDistance = returnClimbAnchorPoint ? Number(returnClimbAnchorPoint.distance) : NaN;
            const nearReturnClimbAnchor = (!vehicleCoord || !vehicleCoord.isValid) || !!(returnClimbAnchorPoint && returnClimbAnchorPoint.coordinate && returnClimbAnchorPoint.coordinate.isValid && _coordinatesClose(vehicleCoord, returnClimbAnchorPoint.coordinate, 80));
            const returnClimbStillAscending = isNaN(returnClimbTargetAltitude) || Number(liveAltitude) < (returnClimbTargetAltitude - 0.5);
            const returnClimbMovedAlongPath = !isNaN(projectedDistance) && !isNaN(returnClimbAnchorDistance) && projectedDistance > (returnClimbAnchorDistance + 3);
            const returnClimbShouldUse = returnClimbPosition.valid && !descendingToHome && (returnModeActive || previousSegment === "return-climb") && !returnClimbMovedAlongPath && (nearReturnClimbAnchor || (previousSegment === "return-climb" && returnClimbStillAscending)) && (previousSegment !== "landing") && (!returnModeActive ? (!isNaN(returnClimbAnchorAltitude) && Number(liveAltitude) >= (returnClimbAnchorAltitude - 0.5)) : true) && (isNaN(returnClimbTargetAltitude) || Number(liveAltitude) <= (returnClimbTargetAltitude + 1.0));

            // 优先级：起飞 > 返航爬升 > 降落
            if (takeoffShouldUse) {
                //console.log(">>> 使用起飞段 (allowTakeoff=" + root._allowTakeoffSegment + ")")
                takeoffPosition.segment = "takeoff";
                return takeoffPosition;
            }

            // 处理返航爬升段
            if (returnClimbShouldUse) {
                returnClimbPosition.segment = "return-climb";
                //console.log("✓ USING RETURN-CLIMB SEGMENT")
                //console.log("=== _currentVehicleProfilePosition END ===\n")
                return returnClimbPosition;
            }

            if (landingPosition.valid && (landingModeActive || (returnSequenceActive && (previousSegment === "landing" || previousSegment === "return-climb" || previousSegment !== "path")))) {
                landingPosition.segment = "landing";
                return landingPosition;
            }

            // 如果在返航模式但landingPosition无效，仍然使用landing segment
            if ((landingModeActive || returnSequenceActive) && !isNaN(liveAltitude)) {
                const lastPoint = points[points.length - 1];
                if (lastPoint && lastPoint.coordinate && lastPoint.coordinate.isValid) {
                    return {
                        "valid": true,
                        "distance": Number(lastPoint.distance),
                        "altitude": Math.max(0, Number(liveAltitude)),
                        "pointIndex": points.length - 1,
                        "segment": "landing"
                    };
                }
            }
        }

        const currentAltitude = !isNaN(liveAltitude) ? Number(liveAltitude) : _profileAltitudeAtDistance(points, currentDistance);

        return {
            "distance": currentDistance,
            "altitude": currentAltitude,
            "pointIndex": _profilePointIndexAtDistance(points, currentDistance, currentAltitude),
            "segment": "path"
        };
    }

    function _debugCoordinate(coord) {
        if (!coord || !coord.isValid) {
            return "invalid";
        }
        return coord.latitude.toFixed(6) + "," + coord.longitude.toFixed(6) + "," + _debugNumber(coord.altitude);
    }

    function _debugNumber(value) {
        const numericValue = Number(value);
        return isNaN(numericValue) ? "NaN" : numericValue.toFixed(2);
    }

    function _distanceToHomeMeters(vehicle) {
        if (vehicle && vehicle.distanceToHome && !isNaN(Number(vehicle.distanceToHome.rawValue))) {
            return Number(vehicle.distanceToHome.rawValue);
        }
        if (vehicle && _homeIsValid(vehicle) && _vehicleHasPosition(vehicle)) {
            return vehicle.coordinate.distanceTo(vehicle.homePosition);
        }
        return NaN;
    }

    function _ekfStatusLevel(vehicle) {
        if (!vehicle) {
            return 1;
        }

        if (vehicle.allSensorsHealthy !== undefined && vehicle.sensorsUnhealthyBits !== undefined) {
            if (!vehicle.allSensorsHealthy && Number(vehicle.sensorsUnhealthyBits) > 0) {
                return 2;
            }
            return vehicle.allSensorsHealthy ? 0 : 1;
        } else if (vehicle.allSensorsHealthy !== undefined) {
            return vehicle.allSensorsHealthy ? 0 : 1;
        }

        const report = vehicle.healthAndArmingCheckReport;
        if (report && report.supported) {
            if (report.canArm === false) {
                return 2;
            }
            if (report.hasWarningsOrErrors === true) {
                return 1;
            }
            return 0;
        }

        return 1;
    }

    function _ekfStatusText(vehicle) {
        const level = _ekfStatusLevel(vehicle);
        if (level >= 2) {
            return qsTr("Fault");
        } else if (level === 1) {
            return qsTr("Check");
        }
        return qsTr("Good");
    }

    function _expandedVideoOverlayWidth(availableWidth) {
        return Math.min(availableWidth * 0.38, ScreenTools.defaultFontPixelWidth * 34);
    }

    function _factMetersValue(fact, parameterName = "") {
        if (!_hasFactValue(fact)) {
            return NaN;
        }

        const rawValue = Number(fact.rawValue);
        if (isNaN(rawValue)) {
            return NaN;
        }

        if (parameterName === "RTL_ALT") {
            // ArduPilot RTL_ALT is in centimeters
            return rawValue / 100;
        }
        if (parameterName === "RTL_ALT_M") {
            const rtlAltIsMeters = activeVehicleFactsController ? activeVehicleFactsController.parameterExists(-1, "noremap.RTL_ALT_M") : false;
            return rtlAltIsMeters ? rawValue : (rawValue / 100);
        }
        if (parameterName === "RTL_ALTITUDE") {
            return rawValue < 0 ? NaN : (rawValue / 100);
        }
        return rawValue;
    }

    function _factText(fact, fallback = "--", includeUnits = true) {
        if (!_hasFactValue(fact)) {
            return fallback;
        }
        const units = includeUnits && fact.units !== "" ? (" " + fact.units) : "";
        return fact.valueString + units;
    }

    function _firstHealthProblemText(vehicle) {
        const report = vehicle ? vehicle.healthAndArmingCheckReport : null;
        const problems = report ? report.problemsForCurrentMode : null;
        if (problems && problems.count > 0) {
            const problem = problems.get(0);
            if (problem && problem.message) {
                return problem.message;
            }
        }
        return "";
    }

    function _firstStartMissionSequence() {
        const missionController = planControllerInternal ? planControllerInternal.missionController : null;
        const visualItems = missionController ? missionController.visualItems : null;
        if (!visualItems || visualItems.count <= 1) {
            return -1;
        }

        for (let i = 1; i < visualItems.count; i++) {
            const item = visualItems.get(i);
            if (item && item.sequenceNumber !== undefined && item.sequenceNumber !== null) {
                const sequence = Number(item.sequenceNumber);
                if (!isNaN(sequence) && sequence >= 0) {
                    return sequence;
                }
            }
        }

        return -1;
    }

    function _flightModeDisplayName(flightMode) {
        const rawMode = flightMode === undefined || flightMode === null ? "" : ("" + flightMode);
        const mode = rawMode.trim();
        const normalizedMode = mode.toLowerCase();

        if (normalizedMode.indexOf("precision lan") === 0 || normalizedMode === "precland") {
            return qsTr("精准降落");
        }
        if (normalizedMode.indexOf("safe recovery") === 0) {
            return qsTr("安全恢复");
        }
        if (normalizedMode.indexOf("position slow") === 0) {
            return qsTr("慢速位置");
        }
        if (normalizedMode.indexOf("follow target") === 0) {
            return qsTr("跟随目标");
        }
        if (normalizedMode.indexOf("vtol takeoff") === 0) {
            return qsTr("VTOL 起飞");
        }
        if (normalizedMode.indexOf("manual") >= 0) {
            return qsTr("手动");
        }
        if (normalizedMode.indexOf("stabilized") >= 0) {
            return qsTr("自稳");
        }
        if (normalizedMode.indexOf("acro") >= 0) {
            return qsTr("特技");
        }
        if (normalizedMode.indexOf("rattitude") >= 0) {
            return qsTr("半自稳");
        }
        if (normalizedMode.indexOf("offboard") >= 0) {
            return qsTr("板外控制");
        }
        if (normalizedMode.indexOf("position") >= 0) {
            return qsTr("定点");
        }
        if (normalizedMode.indexOf("return") >= 0 || normalizedMode.indexOf("rtl") >= 0) {
            return qsTr("返航");
        }

        switch (mode) {
        case "":
            return qsTr("自动");
        case "Hold":
            return qsTr("保持");
        case "Mission":
            return qsTr("任务");
        case "Return":
        case "RTL":
            return qsTr("返航");
        case "Land":
            return qsTr("降落");
        case "Takeoff":
            return qsTr("起飞");
        case "Manual":
            return qsTr("手动");
        case "Position":
        case "Position Hold":
            return qsTr("定点");
        case "Altitude":
        case "Altitude Hold":
            return qsTr("定高");
        case "Stabilized":
            return qsTr("自稳");
        case "Acro":
            return qsTr("特技");
        case "Rattitude":
            return qsTr("半自稳");
        case "Offboard":
            return qsTr("板外控制");
        case "Orbit":
            return qsTr("环绕");
        case "Descend":
            return qsTr("下降");
        case "Unknown":
            return qsTr("未知");
        default:
            return mode;
        }
    }

    function _flightModeMenuMinimumWidth() {
        const modes = root._activeVehicle && root._activeVehicle.flightModeSetAvailable ? root._activeVehicle.flightModes : [];
        let widestText = 0;
        for (let i = 0; i < modes.length; i++) {
            flightModeMenuTextMetrics.text = root._flightModeDisplayName(modes[i]);
            widestText = Math.max(widestText, flightModeMenuTextMetrics.advanceWidth);
        }

        return widestText + (ScreenTools.defaultFontPixelWidth * 5.5);
    }

    function _formatDurationClock(seconds, unavailableText = "--:--") {
        const numeric = Number(seconds);
        if (isNaN(numeric) || numeric < 0) {
            return unavailableText;
        }
        const totalSeconds = Math.floor(numeric);
        const hours = Math.floor(totalSeconds / 3600);
        const minutes = Math.floor((totalSeconds % 3600) / 60);
        const secs = totalSeconds % 60;
        const hh = hours < 10 ? ("0" + hours) : ("" + hours);
        const mm = minutes < 10 ? ("0" + minutes) : ("" + minutes);
        const ss = secs < 10 ? ("0" + secs) : ("" + secs);
        return hours > 0 ? (hh + ":" + mm + ":" + ss) : (mm + ":" + ss);
    }

    function _formatElapsedTime(fact) {
        if (!_hasFactValue(fact)) {
            return "--:--";
        }
        const totalSeconds = Math.max(0, Math.round(Number(fact.rawValue)));
        const hours = Math.floor(totalSeconds / 3600);
        const minutes = Math.floor((totalSeconds % 3600) / 60);
        const seconds = totalSeconds % 60;
        const minutesText = minutes < 10 ? ("0" + minutes) : ("" + minutes);
        const secondsText = seconds < 10 ? ("0" + seconds) : ("" + seconds);
        if (hours > 0) {
            const hoursText = hours < 10 ? ("0" + hours) : ("" + hours);
            return hoursText + ":" + minutesText + ":" + secondsText;
        }
        return minutesText + ":" + secondsText;
    }

    function _formatFactValue(fact, includeUnits = true, unavailableText = "--") {
        if (!_hasFactValue(fact)) {
            return unavailableText;
        }
        const units = includeUnits && fact.units !== "" ? (" " + fact.units) : "";
        return fact.valueString + units;
    }

    function _formatProfileAltitude(altitudeMeters) {
        return Math.round(Number(altitudeMeters)) + "m";
    }

    function _formatProfileAxisDistance(distanceMeters) {
        return (Math.max(0, Number(distanceMeters)) / 1000).toFixed(1) + "km";
    }

    function _formatReplayTime(seconds) {
        const safeSeconds = Math.max(0, Math.floor(seconds));
        const mins = Math.floor(safeSeconds / 60);
        const secs = safeSeconds % 60;
        const minuteText = mins < 10 ? ("0" + mins) : ("" + mins);
        const secondText = secs < 10 ? ("0" + secs) : ("" + secs);
        return minuteText + ":" + secondText;
    }

    function _formatSignedValue(value, precision = 0, suffix = "") {
        if (isNaN(Number(value))) {
            return "--";
        }
        const numericValue = Number(value);
        const fixed = numericValue.toFixed(precision);
        const signed = numericValue > 0 ? ("+" + fixed) : fixed;
        return signed + suffix;
    }

    function _generatedTakeoffProfilePoint(homeCoord, visualItems) {
        if (!homeCoord || !homeCoord.isValid || !visualItems || visualItems.count <= 0) {
            return null;
        }

        for (let i = 0; i < visualItems.count; i++) {
            const pointData = _missionProfileItemData(visualItems.get(i), i);
            if (!pointData) {
                continue;
            }
            if (!pointData.coordinate || !pointData.coordinate.isValid) {
                continue;
            }

            const pointAltitude = Number(pointData.altitude);
            if (isNaN(pointAltitude) || pointAltitude <= 0.1) {
                return null;
            }

            if (_coordinatesClose(pointData.coordinate, homeCoord, 1.5)) {
                return null;
            }

            return {
                "label": "0",
                "distance": 0,
                "altitude": pointAltitude,
                "coordinate": homeCoord
            };
        }

        return null;
    }

    function _guidedPanelActionMessage(action) {
        switch (action) {
        case guidedActionsController.actionRTL:
            return guidedActionsController.rtlMessage;
        case guidedActionsController.actionLand:
            return guidedActionsController.landMessage;
        case guidedActionsController.actionEmergencyStop:
            return guidedActionsController.emergencyStopMessage;
        default:
            return qsTr("Execute the selected action?");
        }
    }

    function _guidedPanelActionTitle(action) {
        switch (action) {
        case guidedActionsController.actionRTL:
            return guidedActionsController.rtlTitle;
        case guidedActionsController.actionLand:
            return guidedActionsController.landTitle;
        case guidedActionsController.actionEmergencyStop:
            return guidedActionsController.emergencyStopTitle;
        default:
            return qsTr("Confirm");
        }
    }

    function _guidedPanelActionUnavailableMessage(action) {
        switch (action) {
        case guidedActionsController.actionRTL:
            return qsTr("返航/RTL 仅在飞行器已解锁、正在飞行并支持引导模式时可用。");
        case guidedActionsController.actionLand:
            return qsTr("降落仅在飞行器已解锁并支持引导降落时可用。");
        case guidedActionsController.actionEmergencyStop:
            return qsTr("紧急停止仅在飞行器已解锁且正在飞行时可用。");
        default:
            return qsTr("当前无法执行此操作。");
        }
    }

    function _hasFactValue(fact) {
        return fact && !isNaN(Number(fact.rawValue));
    }

    function _hasStartMissionItems() {
        const missionController = planControllerInternal ? planControllerInternal.missionController : null;
        return !!(missionController && missionController.containsItems);
    }

    function _headingCompassLabel(headingDegrees) {
        if (isNaN(Number(headingDegrees))) {
            return "--";
        }
        const normalized = ((Number(headingDegrees) % 360) + 360) % 360;
        const directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
        return directions[Math.round(normalized / 45) % directions.length];
    }

    function _healthProblemAlertLevel(vehicle) {
        const report = vehicle ? vehicle.healthAndArmingCheckReport : null;
        const problems = report ? report.problemsForCurrentMode : null;
        if (problems && problems.count > 0) {
            for (let i = 0; i < problems.count; i++) {
                const problem = problems.get(i);
                if (problem && problem.severity === "error") {
                    return 3;
                }
            }
            return 2;
        }
        if (report && report.supported && report.canArm === false) {
            return 3;
        }
        if (report && report.hasWarningsOrErrors) {
            return 2;
        }
        return 0;
    }

    function _hideStartMissionFeedback() {
        startMissionFeedbackTimer.stop();
        root._startMissionFeedbackVisible = false;
        if (!root._missionAlreadyStarted()) {
            root._startMissionCommandIssued = false;
        }
    }

    function _hideStartMissionSlider() {
        root._startMissionSliderVisible = false;
    }

    function _hideStartMissionUnavailableDialog() {
        root._startMissionUnavailableDialogVisible = false;
    }

    function _homeIsValid(vehicle) {
        return !!(vehicle && vehicle.homePosition && vehicle.homePosition.isValid && vehicle.homePosition.latitude !== 0 && vehicle.homePosition.longitude !== 0);
    }

    function _isGuidedPanelActionAvailable(action) {
        if (!root._activeVehicle || !guidedActionsController) {
            return false;
        }

        switch (action) {
        case guidedActionsController.actionRTL:
            return root._activeVehicle.armed && root._activeVehicle.flying && root._activeVehicle.supports.guidedMode && root._activeVehicle.flightMode !== root._activeVehicle.rtlFlightMode && root._activeVehicle.flightMode !== root._activeVehicle.smartRTLFlightMode;
        case guidedActionsController.actionLand:
            return root._activeVehicle.armed && root._activeVehicle.supports.guidedMode && !root._activeVehicle.fixedWing && root._activeVehicle.flightMode !== root._activeVehicle.landFlightMode;
        case guidedActionsController.actionEmergencyStop:
            return root._activeVehicle.armed && root._activeVehicle.flying;
        default:
            return true;
        }
    }

    function _isMapFollowMode() {
        return !!(root._activeVehicle && mapView && mapView._activeVehicleCoordinate && mapView._activeVehicleCoordinate.isValid && mapView._flyViewSettings.keepMapCenteredOnVehicle.rawValue && !mapView._disableVehicleTracking);
    }

    function _isMapPanMode() {
        return !!mapView && !_isMapFollowMode();
    }

    function _isMapStripActionEnabled(key, requiresVehicle) {
        if (key === "startMission") {
            return root._startMissionEntryVisible;
        }
        if (key === "locate") {
            return root._vehicleHasPosition(root._activeVehicle);
        }
        if (key === "rtl") {
            return guidedActionsController.showRTL;
        }
        if (key === "oneKeyRTL") {
            return guidedActionsController.showRTL;
        }
        if (key === "pause") {
            return guidedActionsController.showPause;
        }
        if (key === "play") {
            return guidedActionsController.showContinueMission;
        }
        if (key === "up" || key === "down") {
            return guidedActionsController.showChangeAlt;
        }
        if (key === "land") {
            return root._isGuidedPanelActionAvailable(guidedActionsController.actionLand);
        }
        if (key === "emergencyStop") {
            return root._isGuidedPanelActionAvailable(guidedActionsController.actionEmergencyStop);
        }
        if (key === "flightMode") {
            return !!(root._activeVehicle && root._activeVehicle.flightModeSetAvailable);
        }
        return !requiresVehicle || !!root._activeVehicle;
    }

    function _isMapStripSelected(key) {
        if (key === "startMission") {
            return root._startMissionSliderVisible;
        }
        if (key === "traffic") {
            return root._trafficViewVisible;
        }
        if (key === "list") {
            return root._instrumentPanelVisible;
        }
        if (key === "pan" || key === "locate") {
            return root._mapNavigationSelection === key;
        }
        if (key === "showPath") {
            return root._showFlightPath;
        }
        if (key === "armDisarm") {
            return !!(root._activeVehicle && root._activeVehicle.armed);
        }
        return false;
    }

    function _isVehicleInLandingMode() {
        if (!_activeVehicle) {
            return false;
        }

        const modeText = (_activeVehicle.flightMode === undefined || _activeVehicle.flightMode === null) ? "" : ("" + _activeVehicle.flightMode).toLowerCase().trim();
        if (modeText === "") {
            return false;
        }

        const landMode = (_activeVehicle.landFlightMode === undefined || _activeVehicle.landFlightMode === null) ? "" : ("" + _activeVehicle.landFlightMode).toLowerCase().trim();
        if (landMode !== "" && modeText === landMode) {
            return true;
        }

        return modeText.indexOf("land") !== -1;
    }

    function _isVehicleInReturnMode() {
        if (!_activeVehicle) {
            return false;
        }

        const modeText = (_activeVehicle.flightMode === undefined || _activeVehicle.flightMode === null) ? "" : ("" + _activeVehicle.flightMode).toLowerCase().trim();
        if (modeText === "") {
            return false;
        }

        const returnModes = [_activeVehicle.rtlFlightMode, _activeVehicle.smartRTLFlightMode];
        for (let i = 0; i < returnModes.length; i++) {
            const returnMode = (returnModes[i] === undefined || returnModes[i] === null) ? "" : ("" + returnModes[i]).toLowerCase().trim();
            if (returnMode !== "" && modeText === returnMode) {
                return true;
            }
        }

        return modeText.indexOf("rtl") !== -1 || modeText.indexOf("return") !== -1 || modeText.indexOf("safe recovery") !== -1;
    }

    function _logProfileDebugState() {
        if (!_profileDebugLogging || !_activeVehicle) {
            return;
        }

        const points = _profileMissionPoints;
        const vehicleCoord = _activeVehicle.coordinate;
        const liveAltitude = _vehicleActualAltitude;
        const liveClimbRate = _vehicleClimbRate;
        const landingPosition = points.length >= 2 ? _verticalSegmentLivePosition(points, points.length - 2, points.length - 1, liveAltitude, vehicleCoord) : {
            "valid": false
        };
        const computedProgress = _computeVehicleProgressAlongMission(_shouldTrackReturnProfileSegment(landingPosition.valid, liveClimbRate));
        const livePosition = _currentVehicleProfilePosition(points, _profileProgress, liveAltitude, liveClimbRate);
        const takeoffPosition = livePosition.segment === "takeoff" && points.length >= 2 ? _takeoffLivePosition(points, liveAltitude, vehicleCoord) : {
            "valid": false
        };
        const firstPoint = points.length > 0 ? points[0] : null;
        const secondPoint = points.length > 1 ? points[1] : null;
        const lastPoint = points.length > 0 ? points[points.length - 1] : null;
        const prevLastPoint = points.length > 1 ? points[points.length - 2] : null;
        let returnSourcePoint = null;
        let returnSourceIndex = -1;
        for (let i = points.length - 1; i >= 0; i--) {
            if (points[i].profileGenerated !== true) {
                returnSourcePoint = points[i];
                returnSourceIndex = i;
                break;
            }
        }
        const homeCoord = _missionHomeCoordinate();
        const returnDistance = (returnSourcePoint && returnSourcePoint.coordinate && returnSourcePoint.coordinate.isValid && homeCoord && homeCoord.isValid) ? Number(returnSourcePoint.coordinate.distanceTo(homeCoord)) : NaN;
        const returnThreshold = (_activeVehicle && _activeVehicle.px4Firmware) ? _px4RtlReturnDistanceThresholdMeters() : NaN;
    }

    function _mapPrimaryActionAvailable() {
        switch (_mapPrimaryActionCode()) {
        case guidedActionsController.actionArm:
            return guidedActionsController.showArm;
        case guidedActionsController.actionForceArm:
            return guidedActionsController.showForceArm;
        case guidedActionsController.actionContinueMission:
            return guidedActionsController.showContinueMission;
        default:
            return !root._startMissionVehicleInAir && guidedActionsController.showStartMission && root._missionReadyForStart();
        }
    }

    function _mapPrimaryActionCode() {
        switch (_mapPrimaryActionKey()) {
        case "arm":
            return guidedActionsController.actionArm;
        case "forceArm":
            return guidedActionsController.actionForceArm;
        case "continueMission":
            return guidedActionsController.actionContinueMission;
        default:
            return guidedActionsController.actionStartMission;
        }
    }

    function _mapPrimaryActionDialogTitle() {
        switch (root._mapPrimarySliderAction || root._mapPrimaryActionCode()) {
        case guidedActionsController.actionArm:
            return qsTr("解锁");
        case guidedActionsController.actionForceArm:
            return qsTr("强制解锁");
        case guidedActionsController.actionContinueMission:
            return qsTr("继续任务");
        default:
            return qsTr("开始任务");
        }
    }

    function _mapPrimaryActionKey() {
        if (!guidedActionsController || !root._activeVehicle) {
            return "startMission";
        }
        if (guidedActionsController.showContinueMission) {
            return "continueMission";
        }
        if (root._startMissionEntryVisible) {
            return "startMission";
        }
        return "startMission";
    }

    function _mapPrimaryActionMessage() {
        switch (root._mapPrimarySliderAction || root._mapPrimaryActionCode()) {
        case guidedActionsController.actionArm:
            return guidedActionsController.armMessage;
        case guidedActionsController.actionForceArm:
            return guidedActionsController.forceArmMessage;
        case guidedActionsController.actionStartMission:
            return guidedActionsController.startMissionMessage;
        case guidedActionsController.actionContinueMission:
            return guidedActionsController.continueMissionMessage;
        default:
            return qsTr("滑动确认执行当前操作");
        }
    }

    function _mapPrimaryActionText() {
        switch (_mapPrimaryActionKey()) {
        case "arm":
            return qsTr("解锁");
        case "forceArm":
            return qsTr("强制");
        case "continueMission":
            return qsTr("继续");
        default:
            return qsTr("开始");
        }
    }

    function _mapStripActionTitle(key) {
        switch (key) {
        case "traffic":
            return qsTr("态势");
        case "list":
            return qsTr("仪表");
        case "orbit":
            return qsTr("旋转地图");
        case "lockOrbit":
            return qsTr("锁定朝向");
        case "up":
            return qsTr("上升");
        case "down":
            return qsTr("下降");
        case "rtl":
            return qsTr("返航");
        case "oneKeyRTL":
            return qsTr("一键返航");
        case "play":
            return qsTr("继续任务");
        case "pause":
            return qsTr("暂停");
        case "pan":
            return qsTr("平移");
        case "locate":
            return qsTr("定位");
        case "checklist":
            return qsTr("飞行前检查单");
        case "showPath":
            return qsTr("显示航迹");
        case "armDisarm":
            return root._activeVehicle && root._activeVehicle.armed ? qsTr("上锁") : qsTr("解锁");
        case "land":
            return qsTr("降落");
        case "emergencyStop":
            return qsTr("紧急停止");
        case "flightMode":
            return qsTr("飞行模式");
        default:
            return qsTr("操作不可用");
        }
    }

    function _mapStripFlightModeText() {
        const text = root._activeVehicle && root._activeVehicle.flightMode ? root._flightModeDisplayName(root._activeVehicle.flightMode) : qsTr("模式");
        const compactText = ("" + text).replace(/\s+/g, "");
        if (compactText.length <= 3) {
            return compactText;
        }
        if (compactText.length === 4) {
            return compactText.slice(0, 2) + "\n" + compactText.slice(2);
        }
        const splitIndex = Math.ceil(compactText.length / 2);
        return compactText.slice(0, splitIndex) + "\n" + compactText.slice(splitIndex);
    }

    function _mapStripUnavailableMessage(key, requiresVehicle) {
        if (requiresVehicle && !root._activeVehicle) {
            return qsTr("当前没有连接飞行器。");
        }
        switch (key) {
        case "locate":
            return qsTr("当前飞行器还没有有效定位。");
        case "rtl":
        case "oneKeyRTL":
            if (root._activeVehicle && !root._activeVehicle.armed) {
                return qsTr("返航仅在飞行器已解锁后可用。");
            }
            if (root._activeVehicle && !root._activeVehicle.flying) {
                return qsTr("返航仅在飞行器正在飞行时可用。");
            }
            if (root._activeVehicle && !root._activeVehicle.supports.guidedMode) {
                return qsTr("当前飞控不支持引导返航。");
            }
            return qsTr("当前状态不允许执行返航。");
        case "pause":
            if (root._activeVehicle && !root._activeVehicle.armed) {
                return qsTr("暂停仅在飞行器已解锁后可用。");
            }
            if (root._activeVehicle && !root._activeVehicle.flying) {
                return qsTr("暂停仅在飞行器正在飞行时可用。");
            }
            if (root._activeVehicle && !root._activeVehicle.supports.pauseVehicle) {
                return qsTr("当前飞控不支持暂停飞行器。");
            }
            return qsTr("当前飞行模式不允许暂停。");
        case "play":
            return qsTr("当前没有可继续的任务。");
        case "up":
        case "down":
            if (root._activeVehicle && !root._activeVehicle.armed) {
                return qsTr("高度调整仅在飞行器已解锁后可用。");
            }
            if (root._activeVehicle && !root._activeVehicle.flying) {
                return qsTr("高度调整仅在飞行器正在飞行时可用。");
            }
            return qsTr("当前飞行模式不允许直接调整高度。");
        case "armDisarm":
            return qsTr("当前没有连接飞行器。");
        case "land":
            return root._guidedPanelActionUnavailableMessage(guidedActionsController.actionLand);
        case "emergencyStop":
            return root._guidedPanelActionUnavailableMessage(guidedActionsController.actionEmergencyStop);
        case "flightMode":
            return qsTr("当前飞控不支持从地面站切换飞行模式。");
        default:
            return qsTr("当前状态下无法执行此操作。");
        }
    }

    function _matchingVehicleCount() {
        const vehicles = QGroundControl.multiVehicleManager.vehicles;
        let count = 0;
        for (let i = 0; i < vehicles.count; i++) {
            if (_searchMatch(vehicles.get(i))) {
                count++;
            }
        }
        return count;
    }

    function _missionAlreadyStarted() {
        return root._startMissionAlreadyStarted;
    }

    function _missionHomeAltitude() {
        const homeCoord = _missionHomeCoordinate();
        const homeAltitude = homeCoord && homeCoord.isValid ? Number(homeCoord.altitude) : NaN;
        return isNaN(homeAltitude) ? NaN : homeAltitude;
    }

    function _missionHomeCoordinate() {
        if (_missionController && _missionController.plannedHomePosition && _missionController.plannedHomePosition.isValid) {
            return _missionController.plannedHomePosition;
        }
        if (_activeVehicle && _activeVehicle.homePosition && _activeVehicle.homePosition.isValid) {
            return _activeVehicle.homePosition;
        }
        return null;
    }

    function _missionPlanDirtyForUpload() {
        return !!(planControllerInternal && planControllerInternal.dirtyForUpload);
    }

    function _missionPlanSyncInProgress() {
        const missionController = planControllerInternal ? planControllerInternal.missionController : null;
        return !!((planControllerInternal && planControllerInternal.syncInProgress) || (missionController && missionController.syncInProgress));
    }

    function _missionProfileItemData(item, fallbackLabel = null) {
        if (!item || item.homePosition === true || item.specifiesCoordinate !== true || item.isStandaloneCoordinate === true) {
            return null;
        }

        const isSimpleItem = item.isSimpleItem === true;
        const coord = item.exitCoordinate && item.exitCoordinate.isValid ? item.exitCoordinate : (item.coordinate && item.coordinate.isValid ? item.coordinate : null);
        if (!coord) {
            return null;
        }

        const altitude = !isNaN(Number(item.amslExitAlt)) ? _profileAltitudeFromAMSL(item.amslExitAlt) : (!isNaN(Number(coord.altitude)) ? Number(coord.altitude) : ((item.altitude && _hasFactValue(item.altitude)) ? Number(item.altitude.rawValue) : NaN));
        if (isNaN(altitude)) {
            return null;
        }

        const itemDistanceFromStart = Number(item.distanceFromStart);
        const itemComplexDistance = (!isSimpleItem && !isNaN(Number(item.complexDistance))) ? Number(item.complexDistance) : 0;
        const sequence = (item.sequenceNumber !== undefined && item.sequenceNumber !== null) ? Number(item.sequenceNumber) : fallbackLabel;

        return {
            "label": sequence,
            "distance": !isNaN(itemDistanceFromStart) ? (itemDistanceFromStart + itemComplexDistance) : NaN,
            "altitude": altitude,
            "coordinate": coord
        };
    }

    function _missionReadyForStart() {
        return !!(root._activeVehicle && root._hasStartMissionItems() && !root._missionPlanSyncInProgress() && !root._missionPlanDirtyForUpload());
    }

    function _missionRemainingSeconds(vehicle) {
        if (!_missionController) {
            return NaN;
        }

        const totalMissionSeconds = Number(_missionController.missionTime);
        if (isNaN(totalMissionSeconds) || totalMissionSeconds <= 0) {
            return NaN;
        }

        const visualItems = _missionController.visualItems;
        const itemCount = visualItems ? Number(visualItems.count) : 0;
        const currentMissionIndex = Number(_missionController.currentMissionIndex);
        if (isNaN(currentMissionIndex) || itemCount <= 1 || currentMissionIndex < 0) {
            return totalMissionSeconds;
        }

        const progress = Math.max(0, Math.min(1, currentMissionIndex / Math.max(1, itemCount - 1)));
        return Math.max(0, totalMissionSeconds * (1 - progress));
    }

    function _missionReturnAnchor() {
        const missionController = planControllerInternal ? planControllerInternal.missionController : null;
        const visualItems = missionController ? missionController.visualItems : null;
        if (!visualItems || visualItems.count <= 1) {
            return null;
        }

        for (let i = visualItems.count - 1; i >= 1; i--) {
            const pointData = _missionProfileItemData(visualItems.get(i), i);
            if (!pointData) {
                continue;
            }

            return {
                "index": i,
                "coordinate": pointData.coordinate,
                "altitude": pointData.altitude
            };
        }

        return null;
    }

    function _missionTitle() {
        if (_activeVehicle && _activeVehicle.id !== undefined && _activeVehicle.id !== null) {
            return qsTr("任务 %1").arg(_activeVehicle.id);
        }
        return qsTr("任务 %1").arg(Math.max(_profileMissionPoints.length, 1));
    }

    function _networkGpsHdop(vehicle) {
        if (!vehicle || !vehicle.gps || !vehicle.gps.hdop || isNaN(Number(vehicle.gps.hdop.rawValue))) {
            return NaN;
        }
        return Number(vehicle.gps.hdop.rawValue);
    }

    function _networkGpsLock(vehicle) {
        if (!vehicle || !vehicle.gps || !vehicle.gps.lock || isNaN(Number(vehicle.gps.lock.rawValue))) {
            return NaN;
        }
        return Number(vehicle.gps.lock.rawValue);
    }

    function _networkGpsPercent(vehicle) {
        const lock = _networkGpsLock(vehicle);
        const satellites = _networkGpsSatelliteCount(vehicle);
        const hdop = _networkGpsHdop(vehicle);
        if (isNaN(lock) && isNaN(satellites) && isNaN(hdop)) {
            return NaN;
        }

        let lockScore = 10;
        if (!isNaN(lock)) {
            if (lock >= 3) {
                lockScore = 100;
            } else if (lock === 2) {
                lockScore = 50;
            } else if (lock === 1) {
                lockScore = 25;
            } else {
                lockScore = 8;
            }
        }

        let satelliteScore = lockScore;
        if (!isNaN(satellites)) {
            if (satellites >= 14) {
                satelliteScore = 100;
            } else if (satellites >= 10) {
                satelliteScore = 86;
            } else if (satellites >= 7) {
                satelliteScore = 68;
            } else if (satellites >= 5) {
                satelliteScore = 48;
            } else if (satellites > 0) {
                satelliteScore = 24;
            } else {
                satelliteScore = 0;
            }
        }

        let hdopScore = satelliteScore;
        if (!isNaN(hdop)) {
            if (hdop <= 0.8) {
                hdopScore = 100;
            } else if (hdop <= 1.5) {
                hdopScore = 90;
            } else if (hdop <= 2.5) {
                hdopScore = 70;
            } else if (hdop <= 4.0) {
                hdopScore = 46;
            } else if (hdop <= 8.0) {
                hdopScore = 22;
            } else {
                hdopScore = 8;
            }
        }

        return Math.max(0, Math.min(100, Math.round((lockScore * 0.35) + (satelliteScore * 0.35) + (hdopScore * 0.30))));
    }

    function _networkGpsSatelliteCount(vehicle) {
        if (!vehicle || !vehicle.gps || !vehicle.gps.count || isNaN(Number(vehicle.gps.count.rawValue))) {
            return NaN;
        }
        return Number(vehicle.gps.count.rawValue);
    }

    function _networkHdopText(vehicle) {
        const hdop = _networkGpsHdop(vehicle);
        return isNaN(hdop) ? "--" : hdop.toFixed(1);
    }

    function _networkRcPercent(vehicle) {
        if (!vehicle || vehicle.rcRSSI === undefined || vehicle.rcRSSI === null) {
            return NaN;
        }
        const numeric = Number(vehicle.rcRSSI);
        if (isNaN(numeric) || numeric <= 0 || numeric > 100) {
            return NaN;
        }
        return numeric;
    }

    function _networkSatelliteText(vehicle) {
        const satellites = _networkGpsSatelliteCount(vehicle);
        return isNaN(satellites) ? "--" : ("" + Math.round(satellites));
    }

    function _networkSignalIcon(percent) {
        if (isNaN(percent) || percent < 20) {
            return "/qmlimages/Signal0.svg";
        }
        if (percent < 40) {
            return "/qmlimages/Signal20.svg";
        }
        if (percent < 60) {
            return "/qmlimages/Signal40.svg";
        }
        if (percent < 80) {
            return "/qmlimages/Signal60.svg";
        }
        if (percent < 95) {
            return "/qmlimages/Signal80.svg";
        }
        return "/qmlimages/Signal100.svg";
    }

    function _networkStatusColor(percent) {
        if (isNaN(percent) || percent <= 0) {
            return "#6A7078";
        }
        if (percent >= 75) {
            return "#00BE8A";
        }
        if (percent >= 50) {
            return "#65D4A7";
        }
        if (percent >= 25) {
            return "#D6A566";
        }
        return "#C66D72";
    }

    function _networkStatusText(percent) {
        if (isNaN(percent) || percent <= 0) {
            return qsTr("未连接");
        }
        if (percent >= 75) {
            return qsTr("良好");
        }
        if (percent >= 50) {
            return qsTr("一般");
        }
        if (percent >= 25) {
            return qsTr("较弱");
        }
        return qsTr("差");
    }

    function _networkTelemetryPercent(vehicle) {
        if (!vehicle) {
            return NaN;
        }
        const localPercent = _networkTelemetryRssiToPercent(vehicle.telemetryLRSSI);
        const remotePercent = _networkTelemetryRssiToPercent(vehicle.telemetryRRSSI);
        const hasLocal = !isNaN(localPercent);
        const hasRemote = !isNaN(remotePercent);
        if (!hasLocal && !hasRemote) {
            return NaN;
        }

        let percent = hasLocal && hasRemote ? ((localPercent + remotePercent) / 2) : (hasLocal ? localPercent : remotePercent);

        const lossPercent = vehicle.mavlinkLossPercent !== undefined ? Number(vehicle.mavlinkLossPercent) : NaN;
        if (!isNaN(lossPercent) && lossPercent > 0) {
            percent = Math.max(0, percent - Math.min(lossPercent * 2, 45));
        }

        return Math.round(percent);
    }

    function _networkTelemetryRssiToPercent(rawRssi) {
        const numeric = Number(rawRssi);
        if (isNaN(numeric)) {
            return NaN;
        }
        if (numeric <= -30 && numeric >= -120) {
            return Math.max(0, Math.min(100, Math.round(((numeric + 120) / 90) * 100)));
        }
        if (numeric <= 0 || numeric >= 255) {
            return NaN;
        }
        if (numeric <= 100) {
            return numeric;
        }
        return Math.max(0, Math.min(100, Math.round((numeric / 254) * 100)));
    }

    function _normalizeSearchText(value) {
        return value === undefined || value === null ? "" : ("" + value).toLowerCase().trim();
    }

    function _openClusterWorkspaceWindow() {
        if (typeof mainWindow !== "undefined" && mainWindow && typeof mainWindow._ensureMainInterfaceAccess === "function" && !mainWindow._ensureMainInterfaceAccess(mainWindow._flyTabIndex, true)) {
            return;
        }

        if (root._clusterWorkspaceWindow) {
            root._clusterWorkspaceWindow.show();
            root._clusterWorkspaceWindow.raise();
            root._clusterWorkspaceWindow.requestActivate();
            return;
        }

        const swarmComponent = Qt.createComponent("qrc:/qml/QGroundControl/VehicleSetup/Myswarm.qml");
        if (swarmComponent.status === Component.Error) {
            console.warn("Failed to load swarm workspace component:", swarmComponent.errorString());
            if (typeof mainWindow !== "undefined" && mainWindow && mainWindow.showMessageDialog) {
                mainWindow.showMessageDialog(qsTr("集群"), qsTr("加载集群工作区窗口失败。"));
            }
            return;
        }

        root._clusterWorkspaceWindow = swarmComponent.createObject(null, {
            transientParent: (typeof mainWindow !== "undefined" && mainWindow) ? mainWindow : null,
            visible: false,
            initialVehicleId: root._activeVehicle ? Number(root._activeVehicle.id) : -1
        });

        if (!root._clusterWorkspaceWindow) {
            console.warn("Failed to create swarm workspace window");
            if (typeof mainWindow !== "undefined" && mainWindow && mainWindow.showMessageDialog) {
                mainWindow.showMessageDialog(qsTr("集群"), qsTr("创建集群工作区窗口失败。"));
            }
            return;
        }

        if (root._clusterWorkspaceWindow.width <= 0) {
            root._clusterWorkspaceWindow.width = ScreenTools.defaultFontPixelWidth * 110;
        }
        if (root._clusterWorkspaceWindow.height <= 0) {
            root._clusterWorkspaceWindow.height = ScreenTools.defaultFontPixelHeight * 48;
        }

        root._clusterWorkspaceWindow.closing.connect(function () {
            root._clusterWorkspaceWindow = null;
        });

        root._clusterWorkspaceWindow.visible = true;
        root._clusterWorkspaceWindow.raise();
        root._clusterWorkspaceWindow.requestActivate();

        if (QGroundControl.multiVehicleManager && typeof QGroundControl.multiVehicleManager.replayVehicleState === "function") {
            QGroundControl.multiVehicleManager.replayVehicleState();
        }
    }

    function _openCommunicationLinkSettings() {
        if (typeof mainWindow !== "undefined" && mainWindow && typeof mainWindow.showSettingsTool === "function") {
            mainWindow.showSettingsTool(qsTr("Comm Links"));
        }
    }

    function _openPreFlightChecklist() {
        preFlightChecklistPopup.open();
    }

    function _openVehicleMessages(sourceItem) {
        if (root._activeVehicle) {
            mainWindow.showIndicatorDrawer(vehicleMessagesIndicatorComponent, sourceItem);
        }
    }

    function _openVehicleSetupFirmware() {
        if (!_vehicleSetupFirmwareAvailable() || (_activeVehicle && _activeVehicle.armed)) {
            return;
        }
        if (typeof mainWindow !== "undefined" && mainWindow && typeof mainWindow.showVehicleConfigFirmwarePage === "function") {
            mainWindow.showVehicleConfigFirmwarePage();
        } else {
            _openVehicleSetupHome();
        }
    }

    function _openVehicleSetupHome() {
        if (typeof mainWindow !== "undefined" && mainWindow && typeof mainWindow.showVehicleConfig === "function") {
            mainWindow.showVehicleConfig();
        }
    }

    function _openVehicleSetupSensors() {
        if (!_activeVehicle || _activeVehicle.armed || !_vehicleSetupSensorComponent(_activeVehicle)) {
            return;
        }
        if (typeof mainWindow !== "undefined" && mainWindow && typeof mainWindow.showVehicleConfigSensorsPage === "function") {
            mainWindow.showVehicleConfigSensorsPage();
        } else if (typeof mainWindow !== "undefined" && mainWindow && typeof mainWindow.showKnownVehicleComponentConfigPage === "function") {
            mainWindow.showKnownVehicleComponentConfigPage(AutoPilotPlugin.KnownSensorsVehicleComponent);
        } else {
            _openVehicleSetupHome();
        }
    }

    function _openVehicleSetupTuning() {
        if (!_activeVehicle || !_vehicleSetupTuningComponent(_activeVehicle)) {
            return;
        }
        if (typeof mainWindow !== "undefined" && mainWindow && typeof mainWindow.showVehicleConfigTuningPage === "function") {
            mainWindow.showVehicleConfigTuningPage();
        } else {
            _openVehicleSetupHome();
        }
    }

    function _pendingStartMissionSequenceReady() {
        if (root._pendingStartMissionSequence < 0) {
            return true;
        }

        const missionController = planControllerInternal ? planControllerInternal.missionController : null;
        const currentMissionIndex = missionController ? Number(missionController.currentMissionIndex) : NaN;
        return !isNaN(currentMissionIndex) && currentMissionIndex === root._pendingStartMissionSequence;
    }

    function _plannedReturnAltitudeMeters(fallbackAltitude = NaN, returnDistance = NaN) {
        const lastAltitude = Number(fallbackAltitude);
        const safeLastAltitude = isNaN(lastAltitude) ? NaN : Math.max(0, lastAltitude);
        const px4Firmware = !!(_activeVehicle && _activeVehicle.px4Firmware);
        const apmFirmware = !!(_activeVehicle && _activeVehicle.apmFirmware);
        const multiRotor = !!(_activeVehicle && _activeVehicle.multiRotor);
        const fixedWing = !!(_activeVehicle && _activeVehicle.fixedWing);

        if (px4Firmware) {
            // 使用 activeVehicleFactsController 来获取当前 vehicle 的参数
            let returnAltMeters = NaN;

            if (activeVehicleFactsController) {
                const returnAltFact = activeVehicleFactsController.getParameterFact(-1, "RTL_RETURN_ALT", false);
                if (returnAltFact && _hasFactValue(returnAltFact)) {
                    returnAltMeters = Number(returnAltFact.rawValue);
                }
            }

            const thresholdMeters = _px4RtlReturnDistanceThresholdMeters();
            const isNearHome = !isNaN(Number(returnDistance)) && Number(returnDistance) <= thresholdMeters;

            // PX4 keeps the RTL climb at current altitude when the return point is already near home.
            if (isNearHome) {
                if (!isNaN(safeLastAltitude)) {
                    return safeLastAltitude;
                }
                const result = !isNaN(returnAltMeters) ? Math.max(0, returnAltMeters) : 0;
                return result;
            }

            // When far from home, always climb to RTL_RETURN_ALT or higher
            if (!isNaN(returnAltMeters)) {
                const result = !isNaN(safeLastAltitude) ? Math.max(safeLastAltitude, returnAltMeters) : Math.max(0, returnAltMeters);
                return result;
            }

            // 如果仍然无法获取参数，返回当前高度
            const result = !isNaN(safeLastAltitude) ? safeLastAltitude : 0;
            return result;
        }

        if (apmFirmware && multiRotor) {
            const rtlAltFact = activeVehicleFactsController ? activeVehicleFactsController.getParameterFact(-1, "RTL_ALT", false) : null;
            const rtlAltMeters = _factMetersValue(rtlAltFact, "RTL_ALT");

            // ArduPilot多旋翼：如果RTL_ALT > 0，则爬升到该高度或当前高度（取较大值）
            if (!isNaN(rtlAltMeters) && rtlAltMeters > 0) {
                const result = !isNaN(safeLastAltitude) ? Math.max(safeLastAltitude, rtlAltMeters) : rtlAltMeters;
                return result;
            }
            const result = !isNaN(safeLastAltitude) ? safeLastAltitude : 0;
            return result;
        }

        if (apmFirmware && fixedWing) {
            const rtlAltFact = activeVehicleFactsController ? activeVehicleFactsController.getParameterFact(-1, "RTL_ALTITUDE", false) : null;
            const rtlAltMeters = _factMetersValue(rtlAltFact, "RTL_ALTITUDE");
            if (!isNaN(rtlAltMeters)) {
                const result = !isNaN(safeLastAltitude) ? Math.max(safeLastAltitude, rtlAltMeters) : rtlAltMeters;
                return result;
            }
            const result = !isNaN(safeLastAltitude) ? safeLastAltitude : 0;
            return result;
        }

        const fallback = !isNaN(safeLastAltitude) ? safeLastAltitude : 0;
        return fallback;
    }

    function _popupMenuInLeftPane(menu, anchorItem, minWidth = 0) {
        if (!menu || !anchorItem) {
            return;
        }

        const anchorTop = anchorItem.mapToItem(root, 0, 0);
        const anchorBottom = anchorItem.mapToItem(root, 0, anchorItem.height);
        const contentWidth = menu.contentItem ? Number(menu.contentItem.implicitWidth) : 0;
        const contentHeight = menu.contentItem ? Number(menu.contentItem.implicitHeight) : 0;
        const desiredWidth = Math.max(Number(minWidth), Number(menu.implicitWidth), contentWidth + (ScreenTools.defaultFontPixelWidth * 2.5), ScreenTools.defaultFontPixelWidth * 8);
        const popupHeight = Math.max(Number(menu.implicitHeight), contentHeight + (ScreenTools.defaultFontPixelHeight * 1.2), ScreenTools.defaultFontPixelHeight * 3);
        const edgePadding = Math.max(root._margin * 0.25, ScreenTools.defaultFontPixelWidth * 0.2);
        const topGap = ScreenTools.defaultFontPixelHeight * 0.08;

        menu.width = desiredWidth;

        const minX = edgePadding;
        const maxX = Math.max(minX, root.width - desiredWidth - edgePadding);
        const popupX = Math.max(minX, Math.min(anchorTop.x, maxX));

        const belowY = anchorBottom.y + topGap;
        const maxBelowY = root.height - popupHeight - edgePadding;
        let popupY = belowY;
        if (popupY > maxBelowY) {
            popupY = Math.max(edgePadding, anchorTop.y - popupHeight - topGap);
        }

        menu.popup(popupX, popupY);
    }

    function _profileAltitudeAtDistance(points, distance) {
        if (!points || points.length === 0) {
            return NaN;
        }
        const targetDistance = Math.max(0, Number(distance));
        if (points.length === 1 || targetDistance <= Number(points[0].distance)) {
            return Number(points[0].altitude);
        }
        for (let i = 1; i < points.length; i++) {
            const prevPoint = points[i - 1];
            const nextPoint = points[i];
            if (targetDistance <= Number(nextPoint.distance)) {
                const span = Math.max(Number(nextPoint.distance) - Number(prevPoint.distance), 1);
                const t = (targetDistance - Number(prevPoint.distance)) / span;
                return Number(prevPoint.altitude) + ((Number(nextPoint.altitude) - Number(prevPoint.altitude)) * t);
            }
        }
        return Number(points[points.length - 1].altitude);
    }

    function _profileAltitudeFromAMSL(amslAltitude) {
        const numericAltitude = Number(amslAltitude);
        if (isNaN(numericAltitude)) {
            return NaN;
        }

        const homeAltitude = _missionHomeAltitude();
        return isNaN(homeAltitude) ? numericAltitude : (numericAltitude - homeAltitude);
    }

    function _profileElapsedSeconds(points, progress) {
        return _profileTotalDurationSeconds(points) * Math.max(0, Math.min(1, Number(progress)));
    }

    function _profilePlaybackControlsEnabled() {
        const vehicle = root._activeVehicle;
        const hasLiveTelemetry = !!(vehicle && (!isNaN(Number(root._vehicleActualAltitude)) || !isNaN(Number(root._profileLiveAltitude)) || !isNaN(Number(root._vehicleClimbRate)) || (vehicle.coordinate && vehicle.coordinate.isValid)));
        return !hasLiveTelemetry && !(vehicle && (vehicle.flying || vehicle.armed));
    }

    function _profilePointAtProgress(points, progress) {
        const index = _profilePointIndexAtProgress(points, progress);
        return index >= 0 ? points[index] : null;
    }

    function _profilePointIndexAtDistance(points, distance, altitude = NaN) {
        if (!points || points.length === 0) {
            return -1;
        }

        const numericDistance = Number(distance);
        const targetDistance = isNaN(numericDistance) ? 0 : Math.max(0, numericDistance);
        let bestIndex = -1;
        let bestDistanceDelta = Infinity;
        let bestAltitudeDelta = Infinity;

        for (let i = 0; i < points.length; i++) {
            if (points[i].profileHiddenMarker === true) {
                continue;
            }
            const pointDistanceDelta = Math.abs(Number(points[i].distance) - targetDistance);
            const pointAltitudeDelta = isNaN(altitude) ? 0 : Math.abs(Number(points[i].altitude) - Number(altitude));
            if (pointDistanceDelta < (bestDistanceDelta - 0.001)) {
                bestIndex = i;
                bestDistanceDelta = pointDistanceDelta;
                bestAltitudeDelta = pointAltitudeDelta;
            } else if (Math.abs(pointDistanceDelta - bestDistanceDelta) <= 0.001 && pointAltitudeDelta < bestAltitudeDelta) {
                bestIndex = i;
                bestAltitudeDelta = pointAltitudeDelta;
            }
        }

        return bestIndex;
    }

    function _profilePointIndexAtProgress(points, progress) {
        if (!points || points.length === 0) {
            return -1;
        }
        const totalDistance = Math.max(Number(_profileStats(points).totalDistance), 1);
        const targetDistance = totalDistance * Math.max(0, Math.min(1, Number(progress)));
        for (let i = 0; i < points.length; i++) {
            if (Number(points[i].distance) >= targetDistance) {
                return i;
            }
        }
        return points.length - 1;
    }

    function _profilePointMarkerVisible(points, index, currentIndex) {
        if (!points || index < 0 || index >= points.length) {
            return false;
        }

        const point = points[index];
        if (!point || point.profileHiddenMarker === true) {
            return false;
        }

        if (index === currentIndex || index === 0 || index === points.length - 1) {
            return true;
        }

        if (point.profileGenerated === true && (point.label === "R" || point.label === "H")) {
            return true;
        }

        const visiblePoints = [];
        for (let i = 0; i < points.length; i++) {
            if (points[i] && points[i].profileHiddenMarker !== true) {
                visiblePoints.push({
                    "point": points[i],
                    "index": i
                });
            }
        }

        if (visiblePoints.length <= 8) {
            return true;
        }

        return false;
    }

    function _profileStats(points, liveAltitude = NaN) {
        if (!points || points.length === 0) {
            return {
                "minAlt": 0,
                "maxAlt": 40,
                "totalDistance": 5000
            };
        }
        let minAlt = Number(points[0].altitude);
        let maxAlt = Number(points[0].altitude);
        for (let i = 1; i < points.length; i++) {
            const alt = Number(points[i].altitude);
            minAlt = Math.min(minAlt, alt);
            maxAlt = Math.max(maxAlt, alt);
        }
        if (!isNaN(Number(liveAltitude))) {
            minAlt = Math.min(minAlt, Number(liveAltitude));
            maxAlt = Math.max(maxAlt, Number(liveAltitude));
        }
        if (!isNaN(root._profileReturnAltitudeSnapshot)) {
            maxAlt = Math.max(maxAlt, Number(root._profileReturnAltitudeSnapshot));
        }
        if (Math.abs(maxAlt - minAlt) < 6) {
            maxAlt += 3;
            minAlt -= 3;
        }
        return {
            "minAlt": minAlt - 2,
            "maxAlt": maxAlt + 2,
            "totalDistance": Math.max(Number(points[points.length - 1].distance), 1)
        };
    }

    function _profileTotalDurationSeconds(points) {
        const totalDistance = Math.max(Number(_profileStats(points).totalDistance), 1);
        const defaultSpeed = 4.5;
        const speedFact = _activeVehicle ? _activeVehicle.groundSpeed : null;
        const speed = _hasFactValue(speedFact) ? Math.max(0.5, Number(speedFact.rawValue)) : defaultSpeed;
        return Math.max(180, Math.round(totalDistance / speed));
    }

    function _px4RtlReturnDistanceThresholdMeters() {
        const rtlMinDistFact = activeVehicleFactsController ? activeVehicleFactsController.getParameterFact(-1, "RTL_MIN_DIST", false) : null;
        const rtlMinDistMeters = _factMetersValue(rtlMinDistFact, "RTL_MIN_DIST");
        return isNaN(rtlMinDistMeters) ? 10 : Math.max(0, rtlMinDistMeters);
    }

    function _rebuildActiveVehicleFactsController() {
        activeVehicleFactsLoader.sourceComponent = null;
        if (_activeVehicle) {
            activeVehicleFactsLoader.sourceComponent = activeVehicleFactsControllerComponent;
        }
    }

    function _refreshVehicleTelemetry() {
        const altitudeFact = _activeVehicle ? _activeVehicle.altitudeRelative : null;
        const climbRateFact = _activeVehicle ? _activeVehicle.climbRate : null;
        const rawAltitude = altitudeFact ? Number(altitudeFact.rawValue) : NaN;
        const rawClimbRate = climbRateFact ? Number(climbRateFact.rawValue) : NaN;

        root._vehicleActualAltitude = isNaN(rawAltitude) ? NaN : rawAltitude;
        root._vehicleClimbRate = isNaN(rawClimbRate) ? NaN : rawClimbRate;
    }

    function _remainingFlightSeconds(vehicle) {
        const battery = _activeBatteryForVehicle(vehicle);
        if (!battery || !battery.timeRemaining || isNaN(Number(battery.timeRemaining.rawValue))) {
            return NaN;
        }
        return Math.max(0, Number(battery.timeRemaining.rawValue));
    }

    function _requestFlightModeChange(flightMode) {
        const vehicle = root._activeVehicle;
        if (!vehicle || !vehicle.flightModeSetAvailable) {
            return;
        }

        const targetMode = flightMode === undefined || flightMode === null ? "" : ("" + flightMode);
        const currentMode = vehicle.flightMode === undefined || vehicle.flightMode === null ? "" : ("" + vehicle.flightMode);
        if (targetMode === "" || targetMode === currentMode) {
            return;
        }

        QGroundControl.showMessageDialog(root, qsTr("切换飞行模式"), qsTr("将飞行模式切换为 %1？").arg(root._flightModeDisplayName(targetMode)), Dialog.Yes | Dialog.Cancel, function () {
            if (vehicle) {
                vehicle.flightMode = targetMode;
            }
        });
    }

    function _resolvedProfilePointIndex(points, preferredIndex, distance, altitude = NaN) {
        if (!points || points.length === 0) {
            return -1;
        }

        const numericPreferredIndex = Number(preferredIndex);
        if (!isNaN(numericPreferredIndex) && numericPreferredIndex >= 0 && numericPreferredIndex < points.length && points[numericPreferredIndex].profileHiddenMarker !== true) {
            return numericPreferredIndex;
        }

        return _profilePointIndexAtDistance(points, distance, altitude);
    }

    function _rtlSafetyLevel(vehicle) {
        if (!vehicle) {
            return 1;
        }

        if (!_homeIsValid(vehicle)) {
            return 2;
        }

        const gpsPercent = _networkGpsPercent(vehicle);
        const linkPercent = _communicationTelemetryQualityPercent(vehicle);
        const remainingFlight = _remainingFlightSeconds(vehicle);
        const timeHome = _timeToHomeSeconds(vehicle);
        const batteryPercent = _batteryPercentForVehicle(vehicle);

        if ((!isNaN(gpsPercent) && gpsPercent < 35) || (!isNaN(linkPercent) && linkPercent < 35)) {
            return 2;
        }
        if (!isNaN(batteryPercent) && batteryPercent <= 20) {
            return 2;
        }
        if (!isNaN(timeHome) && !isNaN(remainingFlight) && remainingFlight > 0 && timeHome > (remainingFlight * 0.9)) {
            return 2;
        }
        if ((!isNaN(gpsPercent) && gpsPercent < 55) || (!isNaN(linkPercent) && linkPercent < 55)) {
            return 1;
        }
        if (!isNaN(timeHome) && !isNaN(remainingFlight) && remainingFlight > 0 && timeHome > (remainingFlight * 0.65)) {
            return 1;
        }

        return 0;
    }

    function _rtlSafetyText(vehicle) {
        const level = _rtlSafetyLevel(vehicle);
        if (level >= 2) {
            return qsTr("Risky");
        } else if (level === 1) {
            return qsTr("Caution");
        }
        return qsTr("Safe");
    }

    function _searchMatch(vehicle) {
        const query = _normalizeSearchText(_vehicleSearchText);
        if (!vehicle) {
            return false;
        }
        if (query === "") {
            return true;
        }
        const tokens = _vehicleSearchTokens(vehicle);
        const parts = query.split(/\s+/);
        for (let i = 0; i < parts.length; i++) {
            let matched = false;
            for (let j = 0; j < tokens.length; j++) {
                if (_tokenMatch(tokens[j], parts[i])) {
                    matched = true;
                    break;
                }
            }
            if (!matched) {
                return false;
            }
        }
        return true;
    }

    function _sensorBitEnabled(vehicle, sensorBit) {
        return !!(vehicle && (Number(vehicle.sensorsEnabledBits) & sensorBit));
    }

    function _sensorBitHealthy(vehicle, sensorBit) {
        return _sensorBitEnabled(vehicle, sensorBit) && !_sensorBitUnhealthy(vehicle, sensorBit);
    }

    function _sensorBitUnhealthy(vehicle, sensorBit) {
        return !!(vehicle && (Number(vehicle.sensorsUnhealthyBits) & sensorBit));
    }

    function _sensorCpuLoadPercent(vehicle) {
        if (!vehicle) {
            return 15;
        }

        const txBuffer = vehicle.telemetryTXBuffer !== undefined ? _clampPercent(vehicle.telemetryTXBuffer) : NaN;
        const lossPercent = vehicle.mavlinkLossPercent !== undefined ? _clampPercent(vehicle.mavlinkLossPercent) : NaN;
        const rxErrors = vehicle.telemetryRXErrors !== undefined ? Number(vehicle.telemetryRXErrors) : NaN;
        let estimate = 15;

        if (!isNaN(txBuffer)) {
            estimate = 15 + ((100 - txBuffer) * 0.45);
        }
        if (!isNaN(lossPercent)) {
            estimate += Math.min(22, lossPercent * 0.7);
        }
        if (!isNaN(rxErrors) && rxErrors > 0) {
            estimate += Math.min(10, Math.log(rxErrors + 1) * 2);
        }

        return Math.round(Math.max(5, Math.min(95, estimate)));
    }

    function _sensorGpsSatelliteText(vehicle) {
        const satellites = _networkGpsSatelliteCount(vehicle);
        return isNaN(satellites) ? "10" : ("" + Math.round(satellites));
    }

    function _sensorHealthNominal(vehicle) {
        if (!vehicle) {
            return false;
        }
        return !!vehicle.allSensorsHealthy && Number(vehicle.sensorsUnhealthyBits) === 0;
    }

    function _sensorLogActive(vehicle) {
        if (!vehicle) {
            return false;
        }
        const received = Number(vehicle.messagesReceived);
        const lossPercent = vehicle.mavlinkLossPercent !== undefined ? Number(vehicle.mavlinkLossPercent) : NaN;
        return !isNaN(received) && received > 0 && (isNaN(lossPercent) || lossPercent < 80);
    }

    function _sensorStatusTextForBit(vehicle, sensorBit, healthyText, unhealthyText, disabledText = qsTr("Offline")) {
        if (!_sensorBitEnabled(vehicle, sensorBit)) {
            return disabledText;
        }
        return _sensorBitUnhealthy(vehicle, sensorBit) ? unhealthyText : healthyText;
    }

    function _setActiveVehicle(vehicle) {
        if (vehicle && vehicle !== QGroundControl.multiVehicleManager.activeVehicle && !_activeVehicleSwitchPending) {
            _activeVehicleSwitchPending = true;
            _missionPathSwitchSuppressed = true;
            console.log("FlyIntegratedPage: switching active vehicle to", vehicle.id);
            QGroundControl.multiVehicleManager.activeVehicle = vehicle;
            activeVehicleSwitchGuard.restart();
            missionPathSwitchGuard.restart();
        }
    }

    function _setPendingFlightMode(flightMode) {
        if (!_activeVehicle || !flightMode) {
            _clearPendingFlightMode();
            return;
        }
        if (!_activeVehicle.flightModeSetAvailable || !_activeVehicle.flightModes || _activeVehicle.flightModes.indexOf(flightMode) === -1) {
            _clearPendingFlightMode();
            return;
        }
        if (flightMode === _activeVehicle.flightMode) {
            _clearPendingFlightMode();
            return;
        }
        _pendingFlightMode = flightMode;
        _pendingFlightModeVehicleId = _activeVehicle.id;
    }

    function _setVehicleStatusIcon(iconSource, vehicle = _activeVehicle) {
        if (!iconSource || !vehicle || vehicle.id === undefined || vehicle.id === null) {
            return;
        }
        const nextMap = Object.assign({}, root._vehicleStatusIconMap);
        nextMap["" + vehicle.id] = iconSource;
        root._vehicleStatusIconMap = nextMap;
    }

    function _shouldTrackReturnProfileSegment(landingPositionValid, liveClimbRate = NaN) {
        if (_isVehicleInReturnMode()) {
            return true;
        }
        if (_isVehicleInLandingMode()) {
            return true;
        }
        return !!(landingPositionValid && (root._profileLiveSegment === "return-climb" || root._profileLiveSegment === "landing"));
    }

    function _showMapStripUnavailable(key, requiresVehicle) {
        root._hideStartMissionUnavailableDialog();
        root._hideStartMissionSlider();
        root._hideStartMissionFeedback();
        QGroundControl.showMessageDialog(root, root._mapStripActionTitle(key), root._mapStripUnavailableMessage(key, requiresVehicle));
    }

    function _showStartMissionFeedback(message, isError, title) {
        root._startMissionFeedbackTitle = title === undefined || title === "" ? root._mapPrimaryActionDialogTitle() : title;
        root._startMissionFeedbackText = message;
        root._startMissionFeedbackIsError = !!isError;
        root._startMissionFeedbackVisible = true;
        startMissionFeedbackTimer.restart();
    }

    function _showStartMissionSlider() {
        const actionCode = root._mapPrimaryActionCode();
        if (actionCode === guidedActionsController.actionStartMission && root._startMissionVehicleInAir) {
            root._hideStartMissionSlider();
            root._showStartMissionUnavailableDialog(qsTr("飞行器已经在飞行中，不能重新开始任务。"));
            return;
        }
        if (!root._mapPrimaryActionAvailable()) {
            root._hideStartMissionSlider();
            root._showStartMissionUnavailableDialog();
            return;
        }
        root._hideStartMissionFeedback();
        guidedActionsController.closeAll();
        root._mapPrimarySliderAction = actionCode;
        root._startMissionSliderVisible = true;
    }

    function _showStartMissionUnavailableDialog(message) {
        root._hideStartMissionFeedback();
        root._startMissionUnavailableDialogText = message === undefined ? root._startMissionUnavailableMessage() : message;
        root._startMissionUnavailableDialogVisible = true;
    }

    function _startMissionDistanceText() {
        const stats = root._profileStats(root._profileMissionPoints);
        const distanceMeters = stats ? Number(stats.totalDistance) : NaN;
        if (isNaN(distanceMeters) || distanceMeters <= 1) {
            return "--";
        }
        if (distanceMeters >= 1000) {
            const decimals = distanceMeters >= 10000 ? 0 : 1;
            return qsTr("%1 km").arg((distanceMeters / 1000).toFixed(decimals));
        }
        return qsTr("%1 m").arg(Math.round(distanceMeters));
    }

    function _startMissionFirstSequenceText() {
        const sequence = root._firstStartMissionSequence();
        return sequence >= 0 ? ("#" + sequence) : "--";
    }

    function _startMissionItemCountText() {
        const missionController = planControllerInternal ? planControllerInternal.missionController : null;
        const visualItems = missionController ? missionController.visualItems : null;
        const count = visualItems ? Math.max(0, Number(visualItems.count) - 1) : 0;
        return count > 0 ? qsTr("%1 个").arg(count) : "--";
    }

    function _startMissionSyncStateText() {
        if (root._missionPlanSyncInProgress()) {
            return qsTr("同步中");
        }
        if (root._missionPlanDirtyForUpload()) {
            return qsTr("待上传");
        }
        return qsTr("已同步");
    }

    function _startMissionUnavailableMessage() {
        if (!root._activeVehicle) {
            return qsTr("当前没有活动飞行器。开始任务前请先连接飞行器。");
        }
        if (root._mapPrimaryActionCode() === guidedActionsController.actionStartMission && root._startMissionVehicleInAir) {
            return qsTr("飞行器已经在飞行中，不能重新开始任务。");
        }
        switch (root._mapPrimaryActionCode()) {
        case guidedActionsController.actionArm:
            if (guidedActionsController._vehicleFlying) {
                return qsTr("飞行器已经在飞行中。");
            }
            if (!guidedActionsController._checklistPassed) {
                return qsTr("飞行前检查单尚未通过。");
            }
            if (!guidedActionsController._canArm) {
                return qsTr("飞行器当前尚未准备好解锁。");
            }
            return qsTr("飞行器当前状态不允许解锁。");
        case guidedActionsController.actionForceArm:
            if (guidedActionsController._vehicleFlying) {
                return qsTr("飞行器已经在飞行中。");
            }
            return qsTr("当前普通解锁被阻止。只有在明确了解风险时才使用强制解锁。");
        case guidedActionsController.actionContinueMission:
            return qsTr("飞行器当前状态不允许继续任务。");
        default:
            if (!guidedActionsController._missionAvailable) {
                return qsTr("当前没有可开始的任务。");
            }
            if (root._missionPlanSyncInProgress()) {
                return qsTr("航线正在上传或同步中，请等待完成后再开始任务。");
            }
            if (root._missionPlanDirtyForUpload()) {
                return qsTr("航线还有未上传的修改，请先上传航线后再开始任务。");
            }
            if (guidedActionsController._missionActive) {
                return qsTr("任务已经处于活动状态。");
            }
            if (guidedActionsController._vehicleFlying) {
                return qsTr("飞行器已经在飞行中。");
            }
            if (!guidedActionsController._checklistPassed) {
                return qsTr("飞行前检查单尚未通过。");
            }
            if (!guidedActionsController._canStartMission) {
                const reason = root._compactPrearmReason(root._activeVehicle);
                return reason !== "" ? qsTr("飞行器当前尚未准备好开始任务：%1").arg(reason) : qsTr("飞行器当前尚未准备好开始任务。");
            }
            return qsTr("飞行器当前状态不允许开始任务。");
        }
    }

    function _stripRichText(text) {
        if (text === undefined || text === null) {
            return "";
        }
        return ("" + text).replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim();
    }

    function _summaryStateColor(level) {
        if (level >= 2) {
            return "#C66D72";
        } else if (level === 1) {
            return "#D6A566";
        }
        return "#00BE8A";
    }

    function _syncPendingFlightMode() {
        if (!_activeVehicle) {
            _clearPendingFlightMode();
            return;
        }
        if (_pendingFlightModeVehicleId !== _activeVehicle.id) {
            _clearPendingFlightMode();
            return;
        }
        if (_pendingFlightMode === "" || _pendingFlightMode === _activeVehicle.flightMode) {
            _clearPendingFlightMode();
        }
    }

    function _takeoffLivePosition(points, liveAltitude, vehicleCoord) {
        if (!points || points.length < 2 || isNaN(liveAltitude)) {
            return {
                "valid": false
            };
        }

        const takeoffSegment = _takeoffProfileSegment(points);
        if (!takeoffSegment.valid) {
            return {
                "valid": false
            };
        }

        // 打印起飞段的高度信息
        const fromPoint = points[takeoffSegment.fromIndex];
        const toPoint = points[takeoffSegment.toIndex];
        const useVerticalSegment = !!(fromPoint && toPoint && fromPoint.coordinate && toPoint.coordinate && fromPoint.coordinate.isValid && toPoint.coordinate.isValid && _coordinatesClose(fromPoint.coordinate, toPoint.coordinate, 1.5));
        const result = useVerticalSegment ? _verticalSegmentLivePosition(points, takeoffSegment.fromIndex, takeoffSegment.toIndex, liveAltitude, vehicleCoord, 80) : _altitudeInterpolatedSegmentPosition(points, takeoffSegment.fromIndex, takeoffSegment.toIndex, liveAltitude, vehicleCoord, true);
        if (result.valid) {
            const minAltitude = Number(points[takeoffSegment.fromIndex].altitude);
            const maxAltitude = Number(points[takeoffSegment.toIndex].altitude);
            result.altitude = Math.max(minAltitude, Math.min(maxAltitude, Number(liveAltitude)));
        }
        return result;
    }

    function _takeoffProfileSegment(points) {
        if (!points || points.length < 2) {
            return {
                "valid": false
            };
        }

        let fromIndex = -1;
        for (let i = 0; i < points.length; i++) {
            if (points[i].profileGroundOrigin === true) {
                fromIndex = i;
                break;
            }
        }
        if (fromIndex < 0) {
            fromIndex = 0;
        }

        const fromPoint = points[fromIndex];
        const fromAltitude = fromPoint ? Number(fromPoint.altitude) : NaN;
        if (!fromPoint || isNaN(fromAltitude)) {
            return {
                "valid": false
            };
        }

        for (let i = fromIndex + 1; i < points.length; i++) {
            const candidate = points[i];
            if (!candidate || isNaN(Number(candidate.altitude))) {
                continue;
            }
            if (Number(candidate.altitude) <= fromAltitude + 0.5) {
                continue;
            }
            return {
                "valid": true,
                "fromIndex": fromIndex,
                "toIndex": i
            };
        }

        return {
            "valid": false
        };
    }

    function _timeToHomeSeconds(vehicle) {
        if (vehicle && vehicle.timeToHome && !isNaN(Number(vehicle.timeToHome.rawValue))) {
            return Math.max(0, Number(vehicle.timeToHome.rawValue));
        }

        const distanceToHome = _distanceToHomeMeters(vehicle);
        const groundSpeed = vehicle && vehicle.groundSpeed && !isNaN(Number(vehicle.groundSpeed.rawValue)) ? Number(vehicle.groundSpeed.rawValue) : NaN;
        if (isNaN(distanceToHome) || isNaN(groundSpeed) || groundSpeed <= 0.1) {
            return NaN;
        }
        return Math.max(0, distanceToHome / groundSpeed);
    }

    function _tokenMatch(token, query) {
        if (!token || !query) {
            return false;
        }
        if (token.indexOf(query) !== -1) {
            return true;
        }
        let qi = 0;
        for (let ti = 0; ti < token.length && qi < query.length; ti++) {
            if (token[ti] === query[qi]) {
                qi++;
            }
        }
        return qi === query.length;
    }

    function _trafficRangeStep(distanceMeters) {
        const steps = [500, 1000, 2000, 3000, 5000, 10000, 20000];
        for (let i = 0; i < steps.length; i++) {
            if (distanceMeters <= steps[i]) {
                return steps[i];
            }
        }
        return Math.ceil(distanceMeters / 5000) * 5000;
    }

    function _triggerGuidedPanelAction(action) {
        if (!root._activeVehicle || !guidedActionsController) {
            return;
        }

        if (!root._isGuidedPanelActionAvailable(action)) {
            QGroundControl.showMessageDialog(root, root._guidedPanelActionTitle(action), root._guidedPanelActionUnavailableMessage(action));
            return;
        }

        QGroundControl.showMessageDialog(root, root._guidedPanelActionTitle(action), root._guidedPanelActionMessage(action), Dialog.Yes | Dialog.Cancel, function () {
            guidedActionsController.executeAction(action, null, 0, false);
        });
    }

    function _triggerMapPrimaryAction() {
        root._showStartMissionSlider();
    }

    function _triggerMapStripAction(command, sourceItem) {
        if (command !== "startMission" && root._startMissionSliderVisible) {
            root._hideStartMissionSlider();
        }
        if (command !== "startMission" && root._startMissionFeedbackVisible) {
            root._hideStartMissionFeedback();
        }
        if (command !== "startMission" && root._startMissionUnavailableDialogVisible) {
            root._hideStartMissionUnavailableDialog();
        }
        switch (command) {
        case "traffic":
            root._trafficViewVisible = !root._trafficViewVisible;
            if (root._trafficViewVisible) {
                root._instrumentPanelVisible = false;
                trafficViewPanel.refresh();
            }
            break;
        case "list":
            root._instrumentPanelVisible = !root._instrumentPanelVisible;
            if (root._instrumentPanelVisible) {
                root._trafficViewVisible = false;
            }
            break;
        case "orbit":
            if (typeof mapView.bearing !== "undefined") {
                mapView.bearing = (mapView.bearing + 20) % 360;
            }
            break;
        case "lockOrbit":
            if (typeof mapView.bearing !== "undefined") {
                mapView.bearing = 0;
            }
            break;
        case "up":
            if (root._activeVehicle) {
                root._confirmMapStripAltitudeChange(2);
            }
            break;
        case "down":
            if (root._activeVehicle) {
                root._confirmMapStripAltitudeChange(-2);
            }
            break;
        case "rtl":
            if (root._activeVehicle) {
                root._triggerGuidedPanelAction(guidedActionsController.actionRTL);
            }
            break;
        case "oneKeyRTL":
            root._confirmOneKeyRTL();
            break;
        case "play":
            if (guidedActionsController.showContinueMission) {
                guidedActionsController.confirmAction(guidedActionsController.actionContinueMission);
            }
            break;
        case "startMission":
            root._showStartMissionSlider();
            break;
        case "pause":
            if (root._activeVehicle) {
                guidedActionsController.confirmAction(guidedActionsController.actionPause);
            }
            break;
        case "pan":
            if (root._mapNavigationSelection === "pan") {
                root._mapNavigationSelection = "";
                break;
            }
            mapView._flyViewSettings.keepMapCenteredOnVehicle.rawValue = false;
            mapView._disableVehicleTracking = true;
            root._mapNavigationSelection = "pan";
            break;
        case "locate":
            if (root._activeVehicle && mapView._activeVehicleCoordinate.isValid) {
                if (root._mapNavigationSelection === "locate") {
                    mapView._flyViewSettings.keepMapCenteredOnVehicle.rawValue = false;
                    mapView._disableVehicleTracking = true;
                    root._mapNavigationSelection = "";
                    break;
                }
                mapView._flyViewSettings.keepMapCenteredOnVehicle.rawValue = true;
                mapView._disableVehicleTracking = false;
                mapView.center = QGroundControl.mapDisplayCoordinate(mapView._activeVehicleCoordinate);
                root._mapNavigationSelection = "locate";
            }
            break;
        case "checklist":
            preFlightChecklistPopup.open();
            break;
        case "showPath":
            root._showFlightPath = !root._showFlightPath;
            break;
        case "armDisarm":
            root._confirmMapStripArmDisarm();
            break;
        case "land":
            root._triggerGuidedPanelAction(guidedActionsController.actionLand);
            break;
        case "emergencyStop":
            root._triggerGuidedPanelAction(guidedActionsController.actionEmergencyStop);
            break;
        case "flightMode":
            if (root._activeVehicle && root._activeVehicle.flightModeSetAvailable) {
                root._popupMenuInLeftPane(flightModeMenu, sourceItem || floatingMapStrip, Math.max(flightModeMenu.implicitWidth, root._flightModeMenuMinimumWidth()));
            }
            break;
        }
    }

    function _updateProfileLiveState() {
        const points = _profileMissionPoints;
        if (!points || points.length === 0) {
            root._profileLiveDistance = 0;
            root._profileLiveAltitude = NaN;
            root._profileLivePointIndex = -1;
            root._profileLiveSegment = "";
            return;
        }

        root._refreshVehicleTelemetry();
        const liveAltitude = root._vehicleActualAltitude;
        const liveClimbRate = root._vehicleClimbRate;
        const livePosition = _currentVehicleProfilePosition(points, _profileProgress, liveAltitude, liveClimbRate);

        // 只在高度变化超过0.5米或段类型变化时打印日志
        const altitudeChanged = isNaN(_lastLoggedAltitude) || Math.abs(liveAltitude - _lastLoggedAltitude) > 0.5;
        const segmentChanged = _lastLoggedSegment !== livePosition.segment;
        if (altitudeChanged || segmentChanged) {
            const actualAlt = !isNaN(liveAltitude) ? liveAltitude.toFixed(2) : "NaN";
            const liveAlt = !isNaN(root._profileLiveAltitude) ? root._profileLiveAltitude.toFixed(2) : "NaN";
            const dist = !isNaN(livePosition.distance) ? livePosition.distance.toFixed(2) : "NaN";
            const flying = _vehicleIsFlying ? "flying" : "not-flying";
            const armed = _activeVehicle && _activeVehicle.armed ? "armed" : "not-armed";
            //console.log(">>> PROFILE: ActualAlt:", actualAlt, "LiveAlt:", liveAlt, "Seg:", livePosition.segment, "Dist:", dist, "[", flying, armed, "]")
            _lastLoggedAltitude = liveAltitude;
            _lastLoggedSegment = livePosition.segment;
        }

        let liveDistance = Number(livePosition.distance);
        if (root._profileLiveSegment === "takeoff" && livePosition.segment === "path" && !isNaN(Number(root._profileLiveDistance)) && !isNaN(liveDistance) && liveDistance < Number(root._profileLiveDistance)) {
            // Avoid a visible "jump back" right after takeoff interpolation hands over to path tracking.
            liveDistance = Number(root._profileLiveDistance);
        }

        root._profileReturnSegmentActive = livePosition.segment === "landing";

        root._profileLiveDistance = liveDistance;
        // 始终使用实时高度，直接从 vehicle 读取最新值以避免延迟
        root._profileLiveAltitude = !isNaN(liveAltitude) ? liveAltitude : Number(livePosition.altitude);
        root._profileLivePointIndex = (livePosition.pointIndex !== undefined && livePosition.pointIndex !== null) ? Number(livePosition.pointIndex) : -1;

        // 更新段类型并控制起飞段标志
        const previousSegment = root._profileLiveSegment;
        const newSegment = livePosition.segment || "";

        // 如果从起飞段离开，禁止再次进入起飞段
        if (previousSegment === "takeoff" && newSegment !== "takeoff") {
            root._allowTakeoffSegment = false;
            console.log(">>> 离开起飞段: " + previousSegment + " -> " + newSegment + ", 禁止再次进入起飞段");
        }

        // 如果降落完成（降落段且高度很低），允许再次进入起飞段
        if (newSegment === "landing" && !isNaN(liveAltitude) && liveAltitude < 2.0) {
            if (!root._allowTakeoffSegment) {
                root._allowTakeoffSegment = true;
                console.log(">>> 降落完成 (高度=" + liveAltitude.toFixed(2) + "m), 允许再次进入起飞段");
            }
        }

        root._profileLiveSegment = newSegment;
    }

    function _vehicleAlertAccentColor() {
        switch (root._vehicleAlertLevel()) {
        case 3:
            return "#F87171";
        case 2:
            return "#FACC15";
        case 1:
            return "#60A5FA";
        default:
            return "transparent";
        }
    }

    function _vehicleAlertColor() {
        switch (root._vehicleAlertLevel()) {
        case 3:
            return "#B91C1C";
        case 2:
            return "#A16207";
        case 1:
            return "#1F2937";
        default:
            return "transparent";
        }
    }

    function _vehicleAlertLevel() {
        const vehicle = root._activeVehicle;
        if (!vehicle) {
            return 0;
        }
        if (vehicle.communicationLost || vehicle.messageTypeError) {
            return 3;
        }
        const healthLevel = root._healthProblemAlertLevel(vehicle);
        if (healthLevel > 0) {
            return healthLevel;
        }
        if (!vehicle.armed && vehicle.prearmError) {
            return 2;
        }
        if (vehicle.messageTypeWarning) {
            return 2;
        }
        if (root._latestVehicleMessageVisible && root._latestVehicleMessageLevel > 0) {
            return root._latestVehicleMessageLevel;
        }
        if (vehicle.messageCount > 0) {
            return 1;
        }
        return 0;
    }

    function _vehicleAlertText() {
        const vehicle = root._activeVehicle;
        if (!vehicle) {
            return "";
        }
        if (vehicle.communicationLost) {
            return qsTr("通信丢失");
        }
        const latestMessage = root._cleanVehicleMessageText(root._latestVehicleMessageText);
        if (latestMessage !== "") {
            return latestMessage;
        }
        const formattedMessage = root._cleanVehicleMessageText(vehicle.formattedMessages).split("\n")[0];
        if (formattedMessage !== "") {
            return formattedMessage;
        }
        const healthProblemText = root._firstHealthProblemText(vehicle);
        if (healthProblemText !== "") {
            return root._cleanVehicleMessageText(healthProblemText);
        }
        if (!vehicle.armed && vehicle.prearmError) {
            const prearmError = root._cleanVehicleMessageText(vehicle.prearmError);
            if (prearmError !== "") {
                return prearmError;
            }
        }
        if (vehicle.messageCount > 0) {
            return qsTr("飞行器消息 %1 条").arg(vehicle.messageCount);
        }
        if (vehicle.healthAndArmingCheckReport && vehicle.healthAndArmingCheckReport.hasWarningsOrErrors) {
            return qsTr("飞行器状态存在警告");
        }
        return "";
    }

    function _vehicleAlertMessagesForDisplay(maxCount = 4, urgentOnly = false) {
        const vehicle = root._activeVehicle;
        const messages = [];

        function addMessage(message, level = -1) {
            if (message && message.text !== undefined) {
                const objectLevel = Number(message.level) > 0 ? Number(message.level) : Number(level);
                addMessage(message.text, objectLevel);
                return;
            }
            const cleanMessage = root._cleanVehicleMessageText(message);
            if (cleanMessage === "") {
                return;
            }
            const alertLevel = Number(level) > 0 ? Number(level) : root._vehicleMessageLevelFromText(message);
            if (urgentOnly && alertLevel < 2) {
                return;
            }
            for (let i = 0; i < messages.length; i++) {
                if (messages[i].text === cleanMessage) {
                    return;
                }
            }
            messages.push({
                "text": cleanMessage,
                "level": alertLevel
            });
        }

        if (!vehicle) {
            return messages;
        }
        if (vehicle.communicationLost) {
            addMessage(qsTr("通信丢失"), 3);
        }
        addMessage(root._latestVehicleMessageText, root._latestVehicleMessageLevel);

        for (let recentIndex = 0; recentIndex < root._recentVehicleAlertMessages.length && messages.length < maxCount; recentIndex++) {
            addMessage(root._recentVehicleAlertMessages[recentIndex]);
        }

        const rawFormattedMessages = vehicle.formattedMessages || "";
        const rawMessageParts = rawFormattedMessages
                .replace(/<font/gi, "\n<font")
                .split(/<br\s*\/?>|\n/gi);
        for (let i = 0; i < rawMessageParts.length && messages.length < maxCount; i++) {
            addMessage(rawMessageParts[i]);
        }

        addMessage(root._firstHealthProblemText(vehicle), root._healthProblemAlertLevel(vehicle));
        if (!vehicle.armed && vehicle.prearmError) {
            addMessage(vehicle.prearmError, 2);
        }
        if (messages.length === 0 && vehicle.messageCount > 0) {
            addMessage(qsTr("飞行器消息 %1 条").arg(vehicle.messageCount));
        }
        if (messages.length === 0 && vehicle.healthAndArmingCheckReport && vehicle.healthAndArmingCheckReport.hasWarningsOrErrors) {
            addMessage(qsTr("飞行器状态存在警告"), 2);
        }

        return messages.slice(0, maxCount);
    }

    function _vehicleAlertDisplayHasUrgentMessage() {
        const messages = root._vehicleAlertMessagesForDisplay(6, true);
        for (let i = 0; i < messages.length; i++) {
            if (messages[i] && Number(messages[i].level) >= 2) {
                return true;
            }
        }
        return false;
    }

    function _vehicleConfigComponentByKeywords(keywords, vehicle = _activeVehicle) {
        const autopilotPlugin = vehicle ? vehicle.autopilotPlugin : null;
        if (!autopilotPlugin || !keywords || keywords.length === 0) {
            return null;
        }

        const components = autopilotPlugin.vehicleComponents;
        for (let i = 0; i < components.length; i++) {
            const component = components[i];
            if (!component) {
                continue;
            }

            const name = component.name ? ("" + component.name).toLowerCase() : "";
            const setupSource = component.setupSource ? component.setupSource.toString().toLowerCase() : "";
            for (let j = 0; j < keywords.length; j++) {
                const keyword = ("" + keywords[j]).toLowerCase().trim();
                if (keyword !== "" && (name.indexOf(keyword) !== -1 || setupSource.indexOf(keyword) !== -1)) {
                    return component;
                }
            }
        }

        return null;
    }

    function _vehicleHasPosition(vehicle) {
        return !!(vehicle && vehicle.coordinate && vehicle.coordinate.isValid && vehicle.coordinate.latitude !== 0 && vehicle.coordinate.longitude !== 0);
    }

    function _vehicleLinkStrength(vehicle) {
        return vehicle && vehicle.rcRSSI !== undefined ? Number(vehicle.rcRSSI) : NaN;
    }

    function _vehicleMessageLevelFromSeverity(severity) {
        const numericSeverity = Number(severity);
        if (isNaN(numericSeverity)) {
            return 1;
        }
        if (numericSeverity <= 3) {
            return 3;
        }
        if (numericSeverity <= 5) {
            return 2;
        }
        return 1;
    }

    function _vehicleParameterManager(vehicle) {
        return vehicle ? vehicle.parameterManager : null;
    }

    function _vehicleRelativeAltitudeMeters() {
        return root._vehicleActualAltitude;
    }

    function _vehicleSearchTokens(vehicle) {
        if (!vehicle) {
            return [];
        }

        const rawTokens = [_vehicleTitle(vehicle), "vehicle " + vehicle.id, "vehicle" + vehicle.id, "" + vehicle.id, vehicle.flightMode, vehicle.vehicleName, vehicle.name, vehicle.callsign, vehicle.displayName, vehicle.objectName, vehicle.armed ? qsTr("armed") : qsTr("disarmed"), vehicle.flying ? qsTr("flying") : qsTr("standby")];

        const tokens = [];
        for (let i = 0; i < rawTokens.length; i++) {
            const normalized = _normalizeSearchText(rawTokens[i]);
            if (normalized !== "" && tokens.indexOf(normalized) === -1) {
                tokens.push(normalized);
            }
        }
        return tokens;
    }

    function _vehicleSetupFirmwareAvailable() {
        return !!(!ScreenTools.isMobile && QGroundControl.corePlugin && QGroundControl.corePlugin.options && QGroundControl.corePlugin.options.showFirmwareUpgrade);
    }

    function _vehicleSetupFirmwareStatusText() {
        if (!_vehicleSetupFirmwareAvailable()) {
            return qsTr("固件更新不可用");
        }
        if (_activeVehicle && _activeVehicle.armed) {
            return qsTr("上锁后更新");
        }
        return qsTr("就绪");
    }

    function _vehicleSetupSensorComponent(vehicle = _activeVehicle) {
        const autopilotPlugin = vehicle ? vehicle.autopilotPlugin : null;
        if (!autopilotPlugin) {
            return null;
        }

        if (typeof autopilotPlugin.findKnownVehicleComponent === "function") {
            const sensorComponent = autopilotPlugin.findKnownVehicleComponent(AutoPilotPlugin.KnownSensorsVehicleComponent);
            if (sensorComponent) {
                return sensorComponent;
            }
        }

        return _vehicleConfigComponentByKeywords(["sensor", "calibration"], vehicle);
    }

    function _vehicleSetupSensorStatusText() {
        if (!_activeVehicle) {
            return qsTr("连接飞行器后校准");
        }
        if (!_vehicleSetupSensorComponent(_activeVehicle)) {
            return qsTr("传感器设置不可用");
        }
        if (_activeVehicle.armed) {
            return qsTr("上锁后校准");
        }
        return _vehicleSetupSensorComponent(_activeVehicle).setupComplete ? qsTr("已校准") : qsTr("需要校准");
    }

    function _vehicleSetupTuningComponent(vehicle = _activeVehicle) {
        return _vehicleConfigComponentByKeywords(["tuning", "pid"], vehicle);
    }

    function _vehicleSetupTuningStatusText() {
        if (!_activeVehicle) {
            return qsTr("连接飞行器后调参");
        }
        if (!_vehicleSetupTuningComponent(_activeVehicle)) {
            return qsTr("此飞行器不可用");
        }
        return qsTr("就绪");
    }

    function _vehicleStatusIcon(vehicle) {
        const defaultIcon = root._vehicleStatusIconOptions[0].source;
        if (!vehicle || vehicle.id === undefined || vehicle.id === null) {
            return defaultIcon;
        }
        return root._vehicleStatusIconMap["" + vehicle.id] || defaultIcon;
    }

    function _vehicleStatusIndicators(vehicle) {
        const batteryPercent = _batteryPercentForVehicle(vehicle);
        const linkStrength = _vehicleLinkStrength(vehicle);
        const hasPosition = _vehicleHasPosition(vehicle);
        const inMission = !!(vehicle && vehicle.flightMode && ("" + vehicle.flightMode).toLowerCase().indexOf("mission") !== -1);
        const isActive = !!(vehicle && (vehicle.flying || vehicle.armed));

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
        ];
    }

    function _vehicleStatusStackIndex(pageIndex) {
        if (pageIndex === 9) {
            return 8;
        }
        return pageIndex === 0 ? 1 : pageIndex;
    }

    function _clusterGroupText(groupId) {
        const numericGroup = Number(groupId);
        return !isNaN(numericGroup) && numericGroup >= 0 ? qsTr("%1 组").arg(numericGroup + 1) : qsTr("未分组");
    }

    function _clusterRoleText(vehicle) {
        if (!vehicle) {
            return qsTr("离线");
        }
        const groupId = clusterManager.vehicleGroup(vehicle.id);
        if (groupId < 0) {
            return qsTr("未分组");
        }
        return clusterManager.vehicleLeader(vehicle.id) ? qsTr("领机") : qsTr("僚机");
    }

    function _clusterVehicleSubtitle(vehicle) {
        if (!vehicle) {
            return qsTr("未连接");
        }
        return qsTr("%1 | %2").arg(_clusterGroupText(clusterManager.vehicleGroup(vehicle.id))).arg(_clusterRoleText(vehicle));
    }

    function _clusterLastResultText() {
        if (clusterManager.lastCommandMessage && clusterManager.lastCommandMessage !== "") {
            return clusterManager.lastCommandMessage;
        }
        if (clusterManager.lastAckMessage && clusterManager.lastAckMessage !== "") {
            return clusterManager.lastAckMessage;
        }
        return qsTr("等待集群操作");
    }

    function _vehicleTitle(vehicle) {
        if (!vehicle) {
            return qsTr("飞行器 --");
        }
        const names = [vehicle.vehicleName, vehicle.name, vehicle.callsign, vehicle.displayName, vehicle.objectName];
        for (let i = 0; i < names.length; i++) {
            const name = names[i] === undefined || names[i] === null ? "" : ("" + names[i]).trim();
            if (name !== "") {
                return name;
            }
        }
        return qsTr("飞行器 %1").arg(vehicle.id);
    }

    function _vehicleTypeIcon(vehicle) {
        return root._vehicleStatusIcon(vehicle);
    }

    function _verticalSegmentLivePosition(points, fromIndex, toIndex, liveAltitude, vehicleCoord, coordThreshold = 50) {
        //console.log("=== _verticalSegmentLivePosition ===")
        // console.log("fromIndex:", fromIndex, "toIndex:", toIndex, "liveAltitude:", liveAltitude)

        if (!points || fromIndex < 0 || toIndex >= points.length || isNaN(liveAltitude)) {
            //console.log("Invalid input parameters")
            return {
                "valid": false
            };
        }

        const fromPoint = points[fromIndex];
        const toPoint = points[toIndex];
        if (!fromPoint || !toPoint || !_coordinatesClose(fromPoint.coordinate, toPoint.coordinate, 1.5)) {
            //console.log("Invalid points or coordinates not close")
            return {
                "valid": false
            };
        }

        // console.log("fromPoint.altitude:", fromPoint.altitude, "toPoint.altitude:", toPoint.altitude)
        // console.log("fromPoint.distance:", fromPoint.distance, "toPoint.distance:", toPoint.distance)

        // 放宽位置检查到 50 米
        if (vehicleCoord && vehicleCoord.isValid) {
            const coordClose = _coordinatesClose(vehicleCoord, toPoint.coordinate, coordThreshold);
            if (!coordClose) {
                return {
                    "valid": false
                };
            }
        }

        const fromAltitude = Number(fromPoint.altitude);
        const toAltitude = Number(toPoint.altitude);
        const minAltitude = Math.min(fromAltitude, toAltitude);
        const maxAltitude = Math.max(fromAltitude, toAltitude);
        // console.log("Altitude range: [", minAltitude - 1.0, ",", maxAltitude + 1.0, "]")

        if (liveAltitude < (minAltitude - 1.0) || liveAltitude > (maxAltitude + 1.0)) {
            // console.log("Live altitude out of range")
            return {
                "valid": false
            };
        }

        // 使用高度插值计算距离，使飞机图标在垂直段平滑移动
        const altitudeSpan = toAltitude - fromAltitude;
        const ratio = Math.abs(altitudeSpan) > 0.5 ? Math.max(0, Math.min(1, (Number(liveAltitude) - fromAltitude) / altitudeSpan)) : 0.5;
        const segmentDistance = Number(fromPoint.distance) + ((Number(toPoint.distance) - Number(fromPoint.distance)) * ratio);
        const pointIndex = toPoint.profileHiddenMarker === true ? fromIndex : toIndex;

        //  console.log("Valid! ratio:", ratio, "segmentDistance:", segmentDistance)
        return {
            "valid": true,
            "distance": segmentDistance,
            "altitude": Number(liveAltitude),
            "pointIndex": pointIndex
        };
    }

    function dropMainStatusIndicatorTool() {
    }

    height: parent ? parent.height : 0
    width: parent ? parent.width : 0

    Component.onCompleted: {
        root._rebuildActiveVehicleFactsController();
        root._refreshVehicleTelemetry();
        root._profileMissionPoints = root._buildMissionProfilePoints();
        root._profileReturnAltitudeSnapshot = NaN;
        root._profileReturnSegmentActive = false;
        root._profileLiveDistance = 0;
        root._profileLiveAltitude = NaN;
        root._profileLivePointIndex = -1;
        root._profileLiveSegment = "";
        root._updateProfileLiveState();
    }
    on_ActiveVehicleChanged: {
        if (flightModeMenu.opened) {
            flightModeMenu.close();
        }
        root._rebuildActiveVehicleFactsController();
        root._refreshVehicleTelemetry();
        profileVehicleSwitchRefresh.restart();
        root._profileReturnAltitudeSnapshot = NaN;
        root._profileReturnSegmentActive = false;
        root._profileLiveDistance = 0;
        root._profileLiveAltitude = NaN;
        root._profileLivePointIndex = -1;
        root._profileLiveSegment = "";
        root._latestVehicleMessageText = root._activeVehicle ? root._cleanVehicleMessageText(root._activeVehicle.formattedMessages).split("\n")[0] : "";
        root._latestVehicleMessageLevel = root._latestVehicleMessageText === "" ? 0 : 1;
        root._latestVehicleMessageVisible = root._latestVehicleMessageText !== "";
        root._syncPendingFlightMode();
    }
    on_StartMissionAlreadyStartedChanged: {
        if (root._startMissionAlreadyStarted) {
            root._clearPendingStartMission();
            root._hideStartMissionSlider();
            root._hideStartMissionUnavailableDialog();
            root._hideStartMissionFeedback();
        }
    }
    on_StartMissionVehicleInAirChanged: {
        if (root._startMissionVehicleInAir) {
            root._clearPendingStartMission();
            root._hideStartMissionSlider();
            root._hideStartMissionUnavailableDialog();
            root._hideStartMissionFeedback();
        }
    }
    on_VehicleStatusPageIndexChanged: {
        if (_vehicleStatusPageIndex === 1) {
            _vehicleStatusPageIndex = 0;
        }
    }

    FactPanelController {
        id: profileFactsController

    }

    Component {
        id: activeVehicleFactsControllerComponent

        FactPanelController {
        }
    }

    Loader {
        id: activeVehicleFactsLoader

    }

    QGCPalette {
        id: qgcPal

        colorGroupEnabled: true
    }

    TextMetrics {
        id: flightModeMenuTextMetrics

    }

    PlanMasterController {
        id: planControllerInternal

        flyView: true

        Component.onCompleted: start()
    }

    QGCToolInsets {
        id: toolInsets

        bottomEdgeCenterInset: root._margin
        bottomEdgeLeftInset: root._margin
        bottomEdgeRightInset: root._margin
        leftEdgeBottomInset: root._margin
        leftEdgeCenterInset: floatingMapStrip.width + (root._margin * 2)
        leftEdgeTopInset: root._margin
        rightEdgeBottomInset: root._margin
        rightEdgeCenterInset: root._margin
        rightEdgeTopInset: uavVideoOverlay.width + (root._margin * 2)
        topEdgeCenterInset: root._margin
        topEdgeLeftInset: root._margin
        topEdgeRightInset: root._margin
    }

    GuidedValueSlider {
        id: guidedValueSlider

        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.top: parent.top
        visible: false
        z: QGroundControl.zOrderTopMost
    }

    GuidedActionsController {
        id: guidedActionsController

        guidedValueSlider: guidedValueSlider
        missionController: planControllerInternal.missionController
        suppressAutomaticMissionPopups: true
    }

    FlyViewMissionCompleteDialog {
        geoFenceController: planControllerInternal.geoFenceController
        missionController: planControllerInternal.missionController
        planMasterController: planControllerInternal
        rallyPointController: planControllerInternal.rallyPointController
    }

    FlyViewPreFlightChecklistPopup {
        id: preFlightChecklistPopup

    }

    Component {
        id: vehicleMessagesIndicatorComponent

        ToolIndicatorPage {
            showExpand: false
            waitForParameters: false

            contentComponent: Component {
                ColumnLayout {
                    spacing: ScreenTools.defaultFontPixelHeight * 0.5

                    QGCLabel {
                        Layout.fillWidth: true
                        color: qgcPal.text
                        font.weight: Font.DemiBold
                        text: qsTr("飞行器消息")
                    }

                    VehicleMessageList {
                        id: flyViewVehicleMessageList

                        visible: !noMessages
                    }

                    QGCLabel {
                        color: qgcPal.text
                        text: qsTr("暂无新的飞行器消息")
                        visible: flyViewVehicleMessageList.noMessages
                    }
                }
            }
        }
    }

    Connections {
        function onNewFormattedMessage(formattedMessage) {
            root._rememberVehicleAlertMessage(formattedMessage);
            if (root._latestVehicleMessageText === "") {
                root._latestVehicleMessageText = root._cleanVehicleMessageText(formattedMessage);
                root._latestVehicleMessageLevel = 1;
                root._latestVehicleMessageVisible = root._latestVehicleMessageText !== "";
                if (root._latestVehicleMessageVisible) {
                    vehicleAlertMessageTimer.interval = 10000;
                    vehicleAlertMessageTimer.restart();
                }
            }
        }

        function onTextMessageReceived(sysid, componentid, severity, text, description) {
            const messageText = root._cleanVehicleMessageText(text);
            if (messageText === "") {
                return;
            }

            root._latestVehicleMessageText = messageText;
            root._latestVehicleMessageLevel = root._vehicleMessageLevelFromSeverity(severity);
            root._rememberVehicleAlertMessage(messageText, root._latestVehicleMessageLevel);
            root._triggerVehicleAlertFlash(root._latestVehicleMessageLevel);
            root._latestVehicleMessageVisible = true;
            vehicleAlertMessageTimer.interval = root._latestVehicleMessageLevel >= 2 ? 30000 : 10000;
            vehicleAlertMessageTimer.restart();
        }

        ignoreUnknownSignals: true
        target: root._activeVehicle
    }

    Timer {
        id: vehicleAlertMessageTimer

        interval: 10000
        repeat: false

        onTriggered: {
            root._latestVehicleMessageVisible = false;
            if (root._activeVehicle && root._activeVehicle.messageCount === 0) {
                root._latestVehicleMessageText = "";
                root._latestVehicleMessageLevel = 0;
            }
        }
    }

    Timer {
        id: vehicleAlertFlashTimer

        interval: 10000
        repeat: false

        onTriggered: root._stopVehicleAlertFlash()
    }

    Connections {
        function onShowStartMissionChanged() {
            if (!guidedActionsController.showStartMission) {
                root._startMissionCommandIssued = false;
                if (root._missionAlreadyStarted()) {
                    root._hideStartMissionSlider();
                    root._hideStartMissionUnavailableDialog();
                    root._hideStartMissionFeedback();
                    return;
                }
                if (root._startMissionSliderVisible) {
                    root._showStartMissionUnavailableDialog();
                }
                root._hideStartMissionSlider();
            }
        }

        target: guidedActionsController
    }

    Timer {
        id: startMissionFeedbackTimer

        interval: 2600
        repeat: false

        onTriggered: root._hideStartMissionFeedback()
    }

    Timer {
        id: startMissionExecuteTimer

        interval: 250
        repeat: true

        onTriggered: {
            if (!root._activeVehicle || !guidedActionsController) {
                root._clearPendingStartMission();
                root._showStartMissionUnavailableDialog();
                return;
            }

            if (root._missionReadyForStart() && guidedActionsController.showStartMission && (root._pendingStartMissionAttempts >= 4 || root._pendingStartMissionSequenceReady())) {
                root._clearPendingStartMission();
                root._startMissionCommandIssued = true;
                guidedActionsController.executeAction(guidedActionsController.actionStartMission, undefined, 0, false);
                root._showStartMissionFeedback(qsTr("开始任务指令已发送。起飞前请确认飞行器状态。"), false);
                return;
            }

            root._pendingStartMissionAttempts++;
            if (root._pendingStartMissionAttempts >= root._startMissionExecuteMaxAttempts) {
                root._clearPendingStartMission();
                root._showStartMissionUnavailableDialog();
            }
        }
    }

    Timer {
        id: activeVehicleSwitchGuard

        interval: 300
        repeat: false

        onTriggered: root._activeVehicleSwitchPending = false
    }

    Timer {
        id: missionPathSwitchGuard

        interval: 1000
        repeat: false

        onTriggered: root._missionPathSwitchSuppressed = false
    }

    Timer {
        id: profileVehicleSwitchRefresh

        interval: 100
        repeat: false

        onTriggered: {
            root._profileMissionPoints = root._buildMissionProfilePoints();
            root._updateProfileLiveState();
        }
    }

    Timer {
        id: profilePlaybackTimer

        interval: 250
        repeat: true
        running: root._profilePlaybackActive && root._profilePanelExpanded && !root._vehicleIsFlying

        onTriggered: {
            root._profileProgress = Math.min(1, root._profileProgress + (0.006 * root._profilePlaybackSpeed));
            if (root._profileProgress >= 1) {
                root._profilePlaybackActive = false;
            }
        }
    }

    Timer {
        id: vehicleMissionTrackTimer

        interval: 100
        repeat: true
        running: root._profilePanelExpanded && root._activeVehicle && (root._vehicleIsFlying || root._activeVehicle.armed)

        onTriggered: {
            root._refreshVehicleTelemetry();
            const points = root._profileMissionPoints;
            const vehicleCoord = root._activeVehicle ? root._activeVehicle.coordinate : null;
            const liveAltitude = root._vehicleActualAltitude;
            const liveClimbRate = root._vehicleClimbRate;
            const landingPosition = points && points.length >= 2 ? root._verticalSegmentLivePosition(points, points.length - 2, points.length - 1, liveAltitude, vehicleCoord) : {
                "valid": false
            };
            const includeReturnSegment = root._shouldTrackReturnProfileSegment(landingPosition.valid, liveClimbRate);
            const progress = root._computeVehicleProgressAlongMission(includeReturnSegment);
            if (progress >= 0) {
                root._profileProgress = progress;
                // console.log("now progress: ",points,liveAltitude,liveClimbRate,progress,includeReturnSegment)
            }
            root._updateProfileLiveState();
        }
    }

    Timer {
        id: profileDebugTimer

        interval: 1000
        repeat: true
        running: root._profileDebugLogging && root._profilePanelExpanded && root._activeVehicle && (root._vehicleIsFlying || root._activeVehicle.armed)

        onTriggered: root._logProfileDebugState()
    }

    Timer {
        id: profileRefreshTimer

        interval: 1200
        repeat: true
        running: true

        onTriggered: {
            root._profileMissionPoints = root._buildMissionProfilePoints();
            root._updateProfileLiveState();
        }
    }

    Connections {
        function onCurrentMissionIndexChanged() {
            root._profileMissionPoints = root._buildMissionProfilePoints();
            root._updateProfileLiveState();
        }

        function onNewItemsFromVehicle() {
            root._profileReturnAltitudeSnapshot = NaN;
            root._profileMissionPoints = root._buildMissionProfilePoints();
            root._updateProfileLiveState();
        }

        function onPlannedHomePositionChanged() {
            root._profileReturnAltitudeSnapshot = NaN;
            root._profileMissionPoints = root._buildMissionProfilePoints();
            root._updateProfileLiveState();
        }

        function onVisualItemsChanged() {
            root._profileReturnAltitudeSnapshot = NaN;
            root._profileMissionPoints = root._buildMissionProfilePoints();
            root._updateProfileLiveState();
        }

        ignoreUnknownSignals: true
        target: planControllerInternal.missionController
    }

    Connections {
        function onArmedChanged() {
            // 解锁时重置起飞段标志，允许进入起飞段
            if (root._activeVehicle && root._activeVehicle.armed) {
                root._allowTakeoffSegment = true;
                console.log(">>> 飞机解锁，允许进入起飞段");
            } else {
                root._clearPendingStartMission();
                root._startMissionCommandIssued = false;
                root._allowTakeoffSegment = true;
            }
            root._refreshVehicleTelemetry();
            root._updateProfileLiveState();
        }

        function onCoordinateChanged() {
            root._updateProfileLiveState();
        }

        function onFlightModeChanged() {
            root._profileMissionPoints = root._buildMissionProfilePoints();
            root._updateProfileLiveState();
            root._syncPendingFlightMode();
        }

        function onFlyingChanged() {
            if (root._activeVehicle && !root._activeVehicle.flying) {
                root._clearPendingStartMission();
                root._startMissionCommandIssued = false;
                root._allowTakeoffSegment = true;
            }
            root._refreshVehicleTelemetry();
            root._updateProfileLiveState();
        }

        function onHomePositionChanged() {
            root._profileReturnAltitudeSnapshot = NaN;
            root._profileMissionPoints = root._buildMissionProfilePoints();
            root._updateProfileLiveState();
        }

        ignoreUnknownSignals: true
        target: root._activeVehicle
    }

    Connections {
        function onParametersReadyChanged(parametersReady) {
            if (!parametersReady) {
                return;
            }
            root._profileReturnAltitudeSnapshot = NaN;
            root._profileMissionPoints = root._buildMissionProfilePoints();
            root._updateProfileLiveState();
        }

        ignoreUnknownSignals: true
        target: root._activeVehicle ? root._activeVehicle.parameterManager : null
    }

    Connections {
        function onRawValueChanged() {
            root._refreshVehicleTelemetry();
            root._updateProfileLiveState();
        }

        ignoreUnknownSignals: true
        target: root._activeVehicle ? root._activeVehicle.altitudeRelative : null
    }

    Connections {
        function onRawValueChanged() {
            root._refreshVehicleTelemetry();
            root._updateProfileLiveState();
        }

        ignoreUnknownSignals: true
        target: root._activeVehicle ? root._activeVehicle.climbRate : null
    }

    Connections {
        function onVehicleRemoved(vehicle) {
            root._clearClusterVehicleState(vehicle);
        }

        ignoreUnknownSignals: true
        target: QGroundControl.multiVehicleManager
    }

    QGCMenu {
        id: vehicleMenu

        Instantiator {
            model: QGroundControl.multiVehicleManager.vehicles

            delegate: QGCMenuItem {
                required property var object

                text: root._vehicleTitle(object)

                onTriggered: root._setActiveVehicle(object)
            }

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

                contentItem: RowLayout {
                    spacing: ScreenTools.defaultFontPixelWidth * 0.28

                    QGCColoredImage {
                        Layout.preferredHeight: Layout.preferredWidth
                        Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.72
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
                        Layout.preferredHeight: Layout.preferredWidth
                        Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.46
                        color: "#53B84F"
                        fillMode: Image.PreserveAspectFit
                        source: "/InstrumentValueIcons/checkmark.svg"
                        visible: root._vehicleStatusIcon(root._activeVehicle) === modelData.source
                    }
                }

                onTriggered: root._setVehicleStatusIcon(modelData.source)
            }

            onObjectAdded: (index, object) => vehicleIconMenu.insertItem(index, object)
            onObjectRemoved: (index, object) => vehicleIconMenu.removeItem(object)
        }
    }

    QGCMenu {
        id: flightModeMenu

        parent: Overlay.overlay
        width: Math.max(implicitWidth, root._flightModeMenuMinimumWidth())

        Instantiator {
            model: root._activeVehicle && root._activeVehicle.flightModeSetAvailable ? root._activeVehicle.flightModes : []

            delegate: QGCMenuItem {
                required property var modelData

                text: root._flightModeDisplayName(modelData)

                onTriggered: root._requestFlightModeChange(modelData)
            }

            onObjectAdded: (index, object) => flightModeMenu.insertItem(index, object)
            onObjectRemoved: (index, object) => flightModeMenu.removeItem(object)
        }
    }

    Item {
        anchors.fill: parent

        Rectangle {
            id: leftPane

            color: qgcPal.windowShadeDark
            height: parent ? parent.height : 0
            radius: 0
            width: {
                const parentWidth = Number(parent ? parent.width : 0);
                if (isNaN(parentWidth) || parentWidth <= 0) {
                    return root._leftPaneWidth;
                }
                const maxAllowedWidth = Math.max(root._leftPaneMinWidth, parentWidth - root._margin - root._rightPaneMinWidth);
                return Math.max(root._leftPaneMinWidth, Math.min(root._leftPaneWidth, root._leftPaneMaxWidth, maxAllowedWidth));
            }
            x: 0
            y: 0

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
                            Layout.alignment: Qt.AlignVCenter
                            Layout.fillWidth: true
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.42
                            Layout.rightMargin: ScreenTools.defaultFontPixelWidth * 0.18
                            color: qgcPal.windowShadeDark
                            radius: ScreenTools.defaultFontPixelHeight * 0.12

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.14
                                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.18
                                spacing: ScreenTools.defaultFontPixelWidth * 0.12

                                QGCColoredImage {
                                    Layout.leftMargin: Math.round(ScreenTools.realPixelDensity)
                                    Layout.preferredHeight: Layout.preferredWidth
                                    Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.58
                                    color: "#FFFFFF"
                                    fillMode: Image.PreserveAspectFit
                                    source: "/InstrumentValueIcons/search.svg"
                                }

                                TextField {
                                    Layout.fillWidth: true
                                    color: text.length > 0 ? "#FFFFFF" : qgcPal.text
                                    placeholderText: qsTr("搜索...")
                                    placeholderTextColor: qgcPal.windowShadeLight
                                    text: root._vehicleSearchText
                                    verticalAlignment: TextInput.AlignVCenter

                                    background: Item {
                                    }

                                    onTextEdited: root._vehicleSearchText = text
                                }
                            }
                        }

                        Repeater {
                            model: ["/InstrumentValueIcons/filter.svg", "/InstrumentValueIcons/add-outline.svg"]

                            delegate: Rectangle {
                                Layout.preferredHeight: Layout.preferredWidth
                                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 1.42
                                color: qgcPal.windowShadeDark
                                radius: ScreenTools.defaultFontPixelHeight * 0.12

                                QGCColoredImage {
                                    anchors.centerIn: parent
                                    color: "#FFFFFF"
                                    fillMode: Image.PreserveAspectFit
                                    height: width
                                    source: modelData
                                    width: parent.height * 0.42
                                }
                            }
                        }

                    }
                }

                QGCListView {
                    id: vehicleList

                    readonly property real _targetHeight: Math.max(ScreenTools.defaultFontPixelHeight * 1.8, Math.min(ScreenTools.defaultFontPixelHeight * 6.6, contentHeight))

                    Layout.fillHeight: false
                    Layout.fillWidth: true
                    Layout.maximumHeight: _targetHeight
                    Layout.preferredHeight: _targetHeight
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                    flickableDirection: Flickable.VerticalFlick
                    model: QGroundControl.multiVehicleManager.vehicles
                    spacing: 0

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }
                    delegate: Rectangle {
                        readonly property color _selectedCardColor: "#32363A"
                        property real batteryPercent: root._batteryPercentForVehicle(vehicleObject)
                        required property int index
                        required property var object
                        property bool selected: vehicleObject === root._activeVehicle
                        property bool showRow: root._searchMatch(vehicleObject)
                        property var vehicleObject: object

                        color: selected ? _selectedCardColor : (index % 2 === 0 ? qgcPal.window : qgcPal.windowShade)
                        height: visible ? ScreenTools.defaultFontPixelHeight * 1.65 : 0
                        visible: showRow
                        width: vehicleList.width

                        ColumnLayout {
                            anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.06
                            anchors.fill: parent
                            anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.08
                            anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.16
                            anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.06
                            spacing: ScreenTools.defaultFontPixelHeight * 0.03

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: ScreenTools.defaultFontPixelWidth * 0.1

                                Rectangle {
                                    readonly property color _iconColor: selected ? "#EAF7EF" : (switchMouse.containsMouse ? "#FFFFFF" : "#D7DCE0")

                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.02
                                    Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 1.28
                                    border.color: selected ? "#70D6A2" : (switchMouse.containsMouse ? "#8E969D" : "#4B535A")
                                    border.width: 1
                                    color: selected ? Qt.rgba(0.18, 0.46, 0.35, 0.95) : (switchMouse.containsMouse ? Qt.rgba(0.24, 0.27, 0.30, 0.96) : Qt.rgba(0.13, 0.14, 0.16, 0.94))
                                    opacity: root._activeVehicleSwitchPending ? 0.55 : 1
                                    radius: ScreenTools.defaultFontPixelHeight * 0.16

                                    QGCLabel {
                                        anchors.centerIn: parent
                                        color: parent._iconColor
                                        font.pixelSize: selected ? ScreenTools.defaultFontPixelHeight * 0.42 : ScreenTools.defaultFontPixelHeight * 0.52
                                        font.weight: Font.DemiBold
                                        horizontalAlignment: Text.AlignHCenter
                                        text: selected ? "\u2713" : "\u25B8"
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    QGCMouseArea {
                                        id: switchMouse

                                        anchors.fill: parent
                                        enabled: !selected && !root._activeVehicleSwitchPending
                                        hoverEnabled: true

                                        onClicked: root._setActiveVehicle(vehicleObject)
                                    }
                                }

                                QGCColoredImage {
                                    Layout.preferredHeight: Layout.preferredWidth
                                    Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.82
                                    color: "#FFFFFF"
                                    fillMode: Image.PreserveAspectFit
                                    source: root._vehicleTypeIcon(vehicleObject)
                                }

                                Item {
                                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 0.22
                                }

                                QGCLabel {
                                    Layout.fillWidth: true
                                    color: "#FFFFFF"
                                    elide: Text.ElideRight
                                    font.weight: Font.DemiBold
                                    text: root._vehicleTitle(vehicleObject)
                                }

                                Rectangle {
                                    id: vehicleModePill

                                    readonly property real _horizontalPadding: ScreenTools.defaultFontPixelWidth * 0.8
                                    readonly property string modeText: root._flightModeDisplayName(vehicleObject ? vehicleObject.flightMode : "")

                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.leftMargin: ScreenTools.defaultFontPixelWidth * 0.16
                                    Layout.maximumWidth: ScreenTools.defaultFontPixelWidth * 8.4
                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.02
                                    Layout.preferredWidth: Math.min(Math.max(modeLabel.implicitWidth + _horizontalPadding, ScreenTools.defaultFontPixelWidth * 4.8), ScreenTools.defaultFontPixelWidth * 8.4)
                                    border.color: selected ? "#79B8D9" : "#43515C"
                                    border.width: 1
                                    color: selected ? Qt.rgba(0.20, 0.34, 0.43, 0.96) : Qt.rgba(0.10, 0.13, 0.16, 0.94)
                                    radius: ScreenTools.defaultFontPixelHeight * 0.16

                                    QGCLabel {
                                        id: modeLabel

                                        anchors.fill: parent
                                        anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.36
                                        anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.36
                                        color: selected ? "#D9F1FF" : "#BFD5E4"
                                        elide: Text.ElideRight
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.48
                                        font.weight: Font.DemiBold
                                        horizontalAlignment: Text.AlignHCenter
                                        text: vehicleModePill.modeText
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }

                                Item {
                                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 0.12
                                }

                                Repeater {
                                    model: vehicleObject && vehicleObject.flying ? ["/InstrumentValueIcons/arrow-thin-up.svg", "/InstrumentValueIcons/pause-outline.svg"] : (vehicleObject && vehicleObject.armed ? ["/InstrumentValueIcons/lock-open.svg", "/InstrumentValueIcons/play-outline.svg"] : ["/InstrumentValueIcons/lock-closed.svg", "/InstrumentValueIcons/play-outline.svg"])

                                    delegate: Rectangle {
                                        required property var modelData

                                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.02
                                        Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 1.34
                                        color: qgcPal.windowShadeDark
                                        radius: ScreenTools.defaultFontPixelHeight * 0.14

                                        QGCColoredImage {
                                            anchors.centerIn: parent
                                            color: "#FFFFFF"
                                            fillMode: Image.PreserveAspectFit
                                            height: width
                                            source: modelData
                                            width: parent.height * 0.56
                                        }
                                    }
                                }
                            }

                        }
                    }
                }

                QGCLabel {
                    Layout.fillWidth: true
                    Layout.leftMargin: ScreenTools.defaultFontPixelWidth * 0.7
                    Layout.rightMargin: ScreenTools.defaultFontPixelWidth * 0.7
                    Layout.topMargin: ScreenTools.defaultFontPixelHeight * 0.22
                    color: qgcPal.windowShadeLight
                    opacity: 0.9
                    text: qsTr("No matching vehicles")
                    visible: root._vehicleSearchText.trim() !== "" && root._matchingVehicleCount() === 0
                    wrapMode: Text.WordWrap
                }

                Item {
                    id: leftPaneGap

                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 4.5
                }

                Rectangle {
                    id: vehicleStatusCard

                    readonly property color _blockColor: "#2D2D2D"
                    readonly property color _buttonSecondaryColor: "#333333"
                    readonly property color _buttonSecondaryHoverColor: "#3D3D3D"
                    readonly property color _buttonSecondaryPressedColor: "#292929"
                    readonly property color _contentColor: "#2D2D2D"
                    readonly property color _controlBorderColor: "#333333"
                    readonly property real _controlBorderWidth: 1
                    readonly property real _controlRadius: 8
                    readonly property color _fieldColor: "#252525"
                    readonly property color _highlightColor: "#2563EB"
                    readonly property color _highlightHoverColor: "#1D4ED8"
                    readonly property color _highlightPressedColor: "#1E40AF"
                    readonly property color _railColor: "#1E1E1E"
                    readonly property real _sectionContentBottomMargin: ScreenTools.defaultFontPixelHeight * 0.12
                    readonly property real _sectionContentLeftMargin: ScreenTools.defaultFontPixelHeight * 0.18
                    readonly property real _sectionContentRightMargin: ScreenTools.defaultFontPixelHeight * 0.18
                    readonly property real _sectionContentSpacing: ScreenTools.defaultFontPixelHeight * 0.11
                    readonly property real _sectionContentTopMargin: ScreenTools.defaultFontPixelHeight * 0.12
                    readonly property real _sectionHeaderButtonRightMargin: ScreenTools.defaultFontPixelWidth * 0.06
                    readonly property real _sectionHeaderButtonSize: ScreenTools.defaultFontPixelHeight * 0.96
                    readonly property real _sectionHeaderHeight: ScreenTools.defaultFontPixelHeight * 1.16
                    readonly property real _sectionHeaderIconScale: 0.52
                    readonly property real _sectionHeaderSpacing: ScreenTools.defaultFontPixelWidth * 0.16
                    readonly property real _sectionHeaderTitleSize: ScreenTools.defaultFontPixelHeight * 0.64
                    readonly property var _statusPages: [
                        {
                            "icon": "/InstrumentValueIcons/dashboard.svg",
                            "title": qsTr("仪表")
                        },
                        {
                            "icon": "/InstrumentValueIcons/bolt.svg",
                            "title": qsTr("飞行器状态")
                        },
                        {
                            "icon": "/InstrumentValueIcons/news-paper.svg",
                            "title": qsTr("文档")
                        },
                        {
                            "icon": "/InstrumentValueIcons/radio.svg",
                            "title": qsTr("信号")
                        },
                        {
                            "icon": "/InstrumentValueIcons/cog.svg",
                            "title": qsTr("参数")
                        },
                        {
                            "icon": "/InstrumentValueIcons/chart.svg",
                            "title": qsTr("日志")
                        },
                        {
                            "icon": "/InstrumentValueIcons/battery-full.svg",
                            "title": qsTr("电池")
                        },
                        {
                            "icon": "/InstrumentValueIcons/show-sidebar.svg",
                            "title": qsTr("姿态")
                        },
                        {
                            "icon": "/InstrumentValueIcons/shield.svg",
                            "title": qsTr("安全")
                        },
                        {
                            "icon": "/InstrumentValueIcons/drone-swarm.svg",
                            "title": qsTr("集群")
                        }
                    ]
                    readonly property color _textDisabledColor: "#666666"
                    readonly property color _textPrimaryColor: "#FFFFFF"
                    readonly property color _textSecondaryColor: "#B0B0B0"
                    readonly property int _transitionDuration: 200

                    Layout.fillHeight: false
                    Layout.fillWidth: true
                    Layout.maximumHeight: Layout.preferredHeight
                    Layout.minimumHeight: (ScreenTools.defaultFontPixelHeight * 23.3) + root._vehicleStatusExtraHeight
                    Layout.preferredHeight: Math.max(ScreenTools.defaultFontPixelHeight * 23.3, Math.min(ScreenTools.defaultFontPixelHeight * 31.8, leftPane.height * 0.55)) + root._vehicleStatusExtraHeight
                    border.color: "#333333"
                    border.width: 1
                    clip: true
                    color: "#1F1F1F"
                    radius: 8

                    RowLayout {
                        anchors.fill: parent
                        spacing: 0

                        Rectangle {
                            Layout.fillHeight: true
                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 3.95
                            border.color: vehicleStatusCard._controlBorderColor
                            border.width: vehicleStatusCard._controlBorderWidth
                            color: vehicleStatusCard._railColor

                            Repeater {
                                model: vehicleStatusCard._statusPages

                                delegate: Rectangle {
                                    readonly property bool _selected: root._vehicleStatusPageIndex === index
                                    required property int index
                                    required property var modelData

                                    border.color: vehicleStatusCard._controlBorderColor
                                    border.width: vehicleStatusCard._controlBorderWidth
                                    color: _selected ? (sideRailMouseArea.pressed ? vehicleStatusCard._highlightPressedColor : (sideRailMouseArea.containsMouse ? vehicleStatusCard._highlightHoverColor : vehicleStatusCard._highlightColor)) : (sideRailMouseArea.pressed ? "#181818" : (sideRailMouseArea.containsMouse ? "#262626" : vehicleStatusCard._railColor))
                                    height: visible ? ScreenTools.defaultFontPixelHeight * 1.88 : 0
                                    visible: index !== 1
                                    width: parent.width
                                    y: (index > 1 ? index - 1 : index) * ScreenTools.defaultFontPixelHeight * 1.88

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: vehicleStatusCard._transitionDuration
                                        }
                                    }

                                    QGCColoredImage {
                                        anchors.centerIn: parent
                                        color: vehicleStatusCard._textPrimaryColor
                                        fillMode: Image.PreserveAspectFit
                                        height: width
                                        source: modelData.icon
                                        width: parent.height * 0.42
                                    }

                                    QGCMouseArea {
                                        id: sideRailMouseArea

                                        anchors.fill: parent
                                        hoverEnabled: true

                                        onClicked: {
                                            if (index !== 1) {
                                                root._vehicleStatusPageIndex = index;
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillHeight: true
                            Layout.fillWidth: true
                            border.color: vehicleStatusCard._controlBorderColor
                            border.width: vehicleStatusCard._controlBorderWidth
                            clip: true
                            color: vehicleStatusCard._contentColor

                            StackLayout {
                                anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.44
                                anchors.fill: parent
                                anchors.leftMargin: ScreenTools.defaultFontPixelHeight * 0.46
                                anchors.rightMargin: ScreenTools.defaultFontPixelHeight * 0.46
                                anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.46
                                clip: true
                                currentIndex: root._vehicleStatusStackIndex(root._vehicleStatusPageIndex)

                                Item {
                                    ColumnLayout {
                                        anchors.bottomMargin: vehicleStatusCard._sectionContentBottomMargin
                                        anchors.fill: parent
                                        anchors.leftMargin: vehicleStatusCard._sectionContentLeftMargin
                                        anchors.rightMargin: vehicleStatusCard._sectionContentRightMargin
                                        anchors.topMargin: vehicleStatusCard._sectionContentTopMargin
                                        spacing: ScreenTools.defaultFontPixelHeight * 0.44

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: vehicleStatusCard._sectionHeaderHeight
                                            spacing: vehicleStatusCard._sectionHeaderSpacing

                                            QGCLabel {
                                                Layout.alignment: Qt.AlignVCenter
                                                Layout.fillWidth: true
                                                color: vehicleStatusCard._textPrimaryColor
                                                font.pixelSize: vehicleStatusCard._sectionHeaderTitleSize
                                                font.weight: Font.DemiBold
                                                text: qsTr("飞行器状态")
                                                verticalAlignment: Text.AlignVCenter
                                            }

                                            Rectangle {
                                                Layout.alignment: Qt.AlignVCenter
                                                Layout.preferredHeight: Layout.preferredWidth
                                                Layout.preferredWidth: vehicleStatusCard._sectionHeaderButtonSize
                                                Layout.rightMargin: vehicleStatusCard._sectionHeaderButtonRightMargin
                                                border.color: vehicleStatusCard._controlBorderColor
                                                border.width: vehicleStatusCard._controlBorderWidth
                                                color: settingsMouseArea.pressed ? vehicleStatusCard._buttonSecondaryPressedColor : (settingsMouseArea.containsMouse ? vehicleStatusCard._buttonSecondaryHoverColor : vehicleStatusCard._buttonSecondaryColor)
                                                radius: vehicleStatusCard._controlRadius

                                                Behavior on color {
                                                    ColorAnimation {
                                                        duration: vehicleStatusCard._transitionDuration
                                                    }
                                                }

                                                QGCColoredImage {
                                                    anchors.centerIn: parent
                                                    color: vehicleStatusCard._textPrimaryColor
                                                    fillMode: Image.PreserveAspectFit
                                                    height: width
                                                    source: "/InstrumentValueIcons/cog.svg"
                                                    width: parent.height * vehicleStatusCard._sectionHeaderIconScale
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

                                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.82
                                                Layout.preferredWidth: parent.width * 0.23
                                                border.color: vehicleStatusCard._controlBorderColor
                                                border.width: vehicleStatusCard._controlBorderWidth
                                                color: vehicleIconPickerMouseArea.pressed ? vehicleStatusCard._buttonSecondaryPressedColor : (vehicleIconPickerMouseArea.containsMouse ? vehicleStatusCard._buttonSecondaryHoverColor : vehicleStatusCard._fieldColor)
                                                radius: vehicleStatusCard._controlRadius

                                                Behavior on color {
                                                    ColorAnimation {
                                                        duration: vehicleStatusCard._transitionDuration
                                                    }
                                                }

                                                QGCColoredImage {
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.34
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    color: vehicleStatusCard._textPrimaryColor
                                                    fillMode: Image.PreserveAspectFit
                                                    height: width
                                                    source: root._vehicleStatusIcon(root._activeVehicle)
                                                    width: ScreenTools.defaultFontPixelHeight * 0.7
                                                }

                                                QGCColoredImage {
                                                    anchors.right: parent.right
                                                    anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.28
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    color: vehicleStatusCard._textPrimaryColor
                                                    fillMode: Image.PreserveAspectFit
                                                    height: width
                                                    source: "/InstrumentValueIcons/cheveron-down.svg"
                                                    width: ScreenTools.defaultFontPixelHeight * 0.36
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
                                                border.color: vehicleNameField.activeFocus ? vehicleStatusCard._highlightColor : vehicleStatusCard._controlBorderColor
                                                border.width: vehicleStatusCard._controlBorderWidth
                                                color: vehicleSelectorMouseArea.pressed ? vehicleStatusCard._buttonSecondaryPressedColor : (vehicleSelectorMouseArea.containsMouse ? vehicleStatusCard._buttonSecondaryHoverColor : vehicleStatusCard._fieldColor)
                                                radius: vehicleStatusCard._controlRadius

                                                Behavior on border.color {
                                                    ColorAnimation {
                                                        duration: vehicleStatusCard._transitionDuration
                                                    }
                                                }
                                                Behavior on color {
                                                    ColorAnimation {
                                                        duration: vehicleStatusCard._transitionDuration
                                                    }
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
                                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 4.55
                                            border.color: vehicleStatusCard._highlightColor
                                            border.width: vehicleStatusCard._controlBorderWidth
                                            color: vehicleStatusCard._blockColor
                                            radius: vehicleStatusCard._controlRadius
                                            visible: root._flightModeConfirmationVisible

                                            ColumnLayout {
                                                anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.22
                                                anchors.fill: parent
                                                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.38
                                                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.28
                                                anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.22
                                                spacing: ScreenTools.defaultFontPixelHeight * 0.2

                                                QGCLabel {
                                                    Layout.fillWidth: true
                                                    color: vehicleStatusCard._textPrimaryColor
                                                    elide: Text.ElideRight
                                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.62
                                                    maximumLineCount: 1
                                                    text: qsTr("待确认：%1").arg(root._flightModeDisplayName(root._pendingFlightMode))
                                                }

                                                Rectangle {
                                                    id: flightModeConfirmSlider

                                                    readonly property real _confirmThreshold: 0.94
                                                    property real _dragProgress: 0
                                                    readonly property real _knobMargin: ScreenTools.defaultFontPixelWidth * 0.16
                                                    readonly property real _travelWidth: Math.max(0, width - sliderKnob.width - (_knobMargin * 2))

                                                    function _completeIfNeeded() {
                                                        if (!root._flightModeConfirmationVisible) {
                                                            _resetHandle();
                                                            return;
                                                        }

                                                        if (_dragProgress >= _confirmThreshold) {
                                                            _dragProgress = 1;
                                                            root._confirmPendingFlightMode();
                                                        }

                                                        if (root._flightModeConfirmationVisible) {
                                                            _resetHandle();
                                                        }
                                                    }

                                                    function _resetHandle() {
                                                        _dragProgress = 0;
                                                    }

                                                    Layout.alignment: Qt.AlignHCenter
                                                    Layout.fillWidth: true
                                                    Layout.maximumWidth: parent.width - (ScreenTools.defaultFontPixelWidth * 0.2)
                                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.34
                                                    Layout.preferredWidth: Math.max(ScreenTools.defaultFontPixelWidth * 12, parent.width - (ScreenTools.defaultFontPixelWidth * 0.9))
                                                    border.color: root._flightModeConfirmationVisible ? vehicleStatusCard._highlightColor : vehicleStatusCard._controlBorderColor
                                                    border.width: vehicleStatusCard._controlBorderWidth
                                                    clip: true
                                                    color: root._flightModeConfirmationVisible ? Qt.rgba(vehicleStatusCard._highlightColor.r, vehicleStatusCard._highlightColor.g, vehicleStatusCard._highlightColor.b, 0.22) : vehicleStatusCard._buttonSecondaryColor
                                                    radius: vehicleStatusCard._controlRadius

                                                    Behavior on border.color {
                                                        ColorAnimation {
                                                            duration: vehicleStatusCard._transitionDuration
                                                        }
                                                    }
                                                    Behavior on color {
                                                        ColorAnimation {
                                                            duration: vehicleStatusCard._transitionDuration
                                                        }
                                                    }

                                                    onVisibleChanged: {
                                                        if (!visible) {
                                                            _resetHandle();
                                                        }
                                                    }

                                                    Connections {
                                                        function on_PendingFlightModeChanged() {
                                                            flightModeConfirmSlider._resetHandle();
                                                        }

                                                        target: root
                                                    }

                                                    QGCLabel {
                                                        anchors.centerIn: parent
                                                        color: vehicleStatusCard._textPrimaryColor
                                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.56
                                                        opacity: sliderMouseArea.pressed ? 0.55 : 0.9
                                                        text: qsTr("滑动确认")
                                                    }

                                                    Rectangle {
                                                        id: sliderFill

                                                        color: Qt.rgba(vehicleStatusCard._highlightColor.r, vehicleStatusCard._highlightColor.g, vehicleStatusCard._highlightColor.b, 0.34)
                                                        height: flightModeConfirmSlider.height - (flightModeConfirmSlider._knobMargin * 2)
                                                        radius: Math.max(0, flightModeConfirmSlider.radius - flightModeConfirmSlider._knobMargin)
                                                        width: sliderKnob.x + sliderKnob.width - flightModeConfirmSlider._knobMargin
                                                        x: flightModeConfirmSlider._knobMargin
                                                        y: flightModeConfirmSlider._knobMargin
                                                    }

                                                    Rectangle {
                                                        id: sliderKnob

                                                        border.color: root._flightModeConfirmationVisible ? vehicleStatusCard._highlightColor : vehicleStatusCard._controlBorderColor
                                                        border.width: vehicleStatusCard._controlBorderWidth
                                                        color: root._flightModeConfirmationVisible ? vehicleStatusCard._highlightColor : vehicleStatusCard._buttonSecondaryColor
                                                        height: flightModeConfirmSlider.height - (flightModeConfirmSlider._knobMargin * 2)
                                                        radius: Math.min(vehicleStatusCard._controlRadius, height / 2)
                                                        width: Math.max(ScreenTools.defaultFontPixelHeight * 1.12, flightModeConfirmSlider.height - (flightModeConfirmSlider._knobMargin * 2))
                                                        x: flightModeConfirmSlider._knobMargin + (flightModeConfirmSlider._travelWidth * flightModeConfirmSlider._dragProgress)
                                                        y: flightModeConfirmSlider._knobMargin

                                                        Behavior on x {
                                                            enabled: !sliderMouseArea.pressed

                                                            NumberAnimation {
                                                                duration: vehicleStatusCard._transitionDuration
                                                            }
                                                        }

                                                        QGCColoredImage {
                                                            anchors.centerIn: parent
                                                            color: vehicleStatusCard._textPrimaryColor
                                                            fillMode: Image.PreserveAspectFit
                                                            height: width
                                                            source: "/InstrumentValueIcons/cheveron-right.svg"
                                                            width: ScreenTools.defaultFontPixelHeight * 0.6
                                                        }
                                                    }

                                                    MouseArea {
                                                        id: sliderMouseArea

                                                        function _updateDrag(mouseX) {
                                                            const limitedX = Math.max(flightModeConfirmSlider._knobMargin, Math.min(mouseX - (sliderKnob.width / 2), flightModeConfirmSlider._knobMargin + flightModeConfirmSlider._travelWidth));
                                                            flightModeConfirmSlider._dragProgress = flightModeConfirmSlider._travelWidth > 0 ? (limitedX - flightModeConfirmSlider._knobMargin) / flightModeConfirmSlider._travelWidth : 0;
                                                        }

                                                        anchors.fill: parent
                                                        cursorShape: enabled ? Qt.OpenHandCursor : Qt.ArrowCursor
                                                        enabled: root._flightModeConfirmationVisible
                                                        hoverEnabled: !ScreenTools.isMobile

                                                        onCanceled: {
                                                            cursorShape = Qt.OpenHandCursor;
                                                            flightModeConfirmSlider._resetHandle();
                                                        }
                                                        onPositionChanged: mouse => {
                                                            if (pressed) {
                                                                _updateDrag(mouse.x);
                                                            }
                                                        }
                                                        onPressed: mouse => {
                                                            _updateDrag(mouse.x);
                                                            cursorShape = Qt.ClosedHandCursor;
                                                        }
                                                        onReleased: {
                                                            cursorShape = Qt.OpenHandCursor;
                                                            flightModeConfirmSlider._completeIfNeeded();
                                                        }
                                                    }
                                                }

                                                Item {
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.34

                                                    QGCButton {
                                                        anchors.right: parent.right
                                                        anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.36
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        backRadius: vehicleStatusCard._controlRadius
                                                        backgroundColor: vehicleStatusCard._buttonSecondaryColor
                                                        borderColor: vehicleStatusCard._controlBorderColor
                                                        height: ScreenTools.defaultFontPixelHeight * 1.5
                                                        horizontalAlignment: Text.AlignHCenter
                                                        hoverOverlayOpacity: 0.20
                                                        overlayColor: vehicleStatusCard._buttonSecondaryHoverColor
                                                        pointSize: ScreenTools.smallFontPointSize
                                                        pressedOverlayOpacity: 0.34
                                                        showBorder: true
                                                        text: qsTr("取消")
                                                        textColor: vehicleStatusCard._textPrimaryColor
                                                        width: Math.max(implicitWidth, ScreenTools.defaultFontPixelWidth * 7.8)

                                                        onClicked: root._clearPendingFlightMode()
                                                    }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            id: preFlightChecklistButton

                                            Layout.fillWidth: true
                                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.82
                                            border.color: vehicleStatusCard._controlBorderColor
                                            border.width: vehicleStatusCard._controlBorderWidth
                                            color: preFlightChecklistMouseArea.pressed ? vehicleStatusCard._highlightPressedColor : (preFlightChecklistMouseArea.containsMouse ? vehicleStatusCard._highlightHoverColor : vehicleStatusCard._highlightColor)
                                            opacity: root._activeVehicle ? 1 : 0.45
                                            radius: vehicleStatusCard._controlRadius

                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: vehicleStatusCard._transitionDuration
                                                }
                                            }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.38
                                                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.28
                                                spacing: ScreenTools.defaultFontPixelWidth * 0.2

                                                QGCColoredImage {
                                                    Layout.preferredHeight: Layout.preferredWidth
                                                    Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.6
                                                    color: vehicleStatusCard._textPrimaryColor
                                                    fillMode: Image.PreserveAspectFit
                                                    source: "/InstrumentValueIcons/clipboard.svg"
                                                }

                                                QGCLabel {
                                                    Layout.fillWidth: true
                                                    color: vehicleStatusCard._textPrimaryColor
                                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.7
                                                    font.weight: Font.DemiBold
                                                    text: qsTr("飞行前检查单")
                                                }

                                                QGCLabel {
                                                    color: vehicleStatusCard._textPrimaryColor
                                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6
                                                    text: qsTr("打开")
                                                }
                                            }

                                            QGCMouseArea {
                                                id: preFlightChecklistMouseArea

                                                anchors.fill: parent
                                                enabled: !!root._activeVehicle
                                                hoverEnabled: true

                                                onClicked: root._openPreFlightChecklist()
                                            }
                                        }

                                        Rectangle {
                                            id: setupVehicleDropdownField

                                            Layout.fillWidth: true
                                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.82
                                            border.color: vehicleStatusCard._controlBorderColor
                                            border.width: vehicleStatusCard._controlBorderWidth
                                            color: vehicleStatusCard._blockColor
                                            radius: vehicleStatusCard._controlRadius

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.38
                                                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.28
                                                spacing: ScreenTools.defaultFontPixelWidth * 0.24

                                                QGCLabel {
                                                    color: vehicleStatusCard._textPrimaryColor
                                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.72
                                                    text: qsTr("显示航迹")
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

                                        // Arm/Disarm Slider
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.82
                                            color: vehicleStatusCard._blockColor
                                            radius: 4
                                            visible: true

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.38
                                                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.28
                                                spacing: ScreenTools.defaultFontPixelWidth * 0.24

                                                QGCLabel {
                                                    color: root._activeVehicle ? "#FFFFFF" : "#888888"
                                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.72
                                                    text: root._activeVehicle ? (root._activeVehicle.armed ? qsTr("滑动上锁") : qsTr("滑动解锁")) : qsTr("未连接飞行器")
                                                }

                                                Item {
                                                    Layout.fillWidth: true
                                                }

                                                QGCSlider {
                                                    id: armDisarmSlider

                                                    property bool _dragInProgress: false
                                                    property color _sliderColor: root._activeVehicle ? (root._activeVehicle.armed ? "#C85C6A" : "#4CAF50") : "#888888"

                                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.5
                                                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 10
                                                    enabled: root._activeVehicle
                                                    from: 0
                                                    to: 100
                                                    value: 0

                                                    // Custom background with progress indication
                                                    background: Rectangle {
                                                        border.color: armDisarmSlider._sliderColor
                                                        border.width: 1
                                                        color: "#333333"
                                                        height: implicitHeight
                                                        implicitHeight: ScreenTools.defaultFontPixelHeight * 0.6
                                                        implicitWidth: ScreenTools.defaultFontPixelWidth * 10
                                                        radius: height / 2
                                                        width: armDisarmSlider.availableWidth
                                                        x: armDisarmSlider.leftPadding
                                                        y: armDisarmSlider.topPadding + armDisarmSlider.availableHeight / 2 - height / 2

                                                        Rectangle {
                                                            color: armDisarmSlider._sliderColor
                                                            height: parent.height
                                                            opacity: 0.3
                                                            radius: height / 2
                                                            width: armDisarmSlider.visualPosition * parent.width
                                                        }
                                                    }

                                                    // Custom handle with icon
                                                    handle: Rectangle {
                                                        border.color: armDisarmSlider._sliderColor
                                                        border.width: 2
                                                        color: "#FFFFFF"
                                                        implicitHeight: ScreenTools.defaultFontPixelHeight * 1.5
                                                        implicitWidth: ScreenTools.defaultFontPixelHeight * 1.5
                                                        radius: width / 2
                                                        x: armDisarmSlider.leftPadding + armDisarmSlider.visualPosition * (armDisarmSlider.availableWidth - width)
                                                        y: armDisarmSlider.topPadding + armDisarmSlider.availableHeight / 2 - height / 2

                                                        QGCColoredImage {
                                                            anchors.centerIn: parent
                                                            color: armDisarmSlider._sliderColor
                                                            fillMode: Image.PreserveAspectFit
                                                            height: width
                                                            source: root._activeVehicle && root._activeVehicle.armed ? "/res/LockClosed.svg" : "/res/LockOpen.svg"
                                                            width: parent.width * 0.6
                                                        }
                                                    }

                                                    onPressedChanged: {
                                                        if (pressed) {
                                                            _dragInProgress = true;
                                                        } else {
                                                            // 延迟重置，让onValueChanged有机会处理
                                                            if (value < 95) {
                                                                _dragInProgress = false;
                                                                value = 0;
                                                            }
                                                        }
                                                    }
                                                    onValueChanged: {
                                                        if (_dragInProgress && value >= 95) {
                                                            console.log("Slider triggered at value:", value);
                                                            console.log("Vehicle armed:", root._activeVehicle ? root._activeVehicle.armed : "no vehicle");

                                                            if (root._activeVehicle && root._activeVehicle.armed) {
                                                                // Disarm the vehicle
                                                                console.log("Disarming vehicle");
                                                                root._activeVehicle.armed = false;
                                                            } else if (root._activeVehicle) {
                                                                // Arm the vehicle
                                                                console.log("Arming vehicle");
                                                                root._activeVehicle.armed = true;
                                                            }
                                                            _dragInProgress = false;
                                                            value = 0;
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        Repeater {
                                            model: [
                                                {
                                                    "background": vehicleStatusCard._buttonSecondaryColor,
                                                    "foreground": vehicleStatusCard._textPrimaryColor,
                                                    "icon": "/res/rtl.svg",
                                                    "label": qsTr("返航/RTL"),
                                                    "action": guidedActionsController.actionRTL
                                                },
                                                {
                                                    "background": vehicleStatusCard._buttonSecondaryColor,
                                                    "foreground": vehicleStatusCard._textPrimaryColor,
                                                    "icon": "/res/land.svg",
                                                    "label": qsTr("降落"),
                                                    "action": guidedActionsController.actionLand
                                                },
                                                {
                                                    "background": vehicleStatusCard._buttonSecondaryColor,
                                                    "foreground": vehicleStatusCard._textPrimaryColor,
                                                    "icon": "/res/Stop.svg",
                                                    "label": qsTr("紧急停止"),
                                                    "emphasis": false,
                                                    "action": guidedActionsController.actionEmergencyStop
                                                }
                                            ]

                                            delegate: Rectangle {
                                                readonly property bool _actionAvailable: root._isGuidedPanelActionAvailable(modelData.action)
                                                required property var modelData

                                                Layout.fillWidth: true
                                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.86
                                                border.color: vehicleStatusCard._controlBorderColor
                                                border.width: vehicleStatusCard._controlBorderWidth
                                                color: actionButtonMouseArea.pressed ? vehicleStatusCard._buttonSecondaryPressedColor : (actionButtonMouseArea.containsMouse ? (modelData.emphasis ? vehicleStatusCard._highlightHoverColor : vehicleStatusCard._buttonSecondaryHoverColor) : modelData.background)
                                                opacity: _actionAvailable ? 1 : 0.45
                                                radius: vehicleStatusCard._controlRadius

                                                Behavior on color {
                                                    ColorAnimation {
                                                        duration: vehicleStatusCard._transitionDuration
                                                    }
                                                }

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.38
                                                    anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.32
                                                    spacing: ScreenTools.defaultFontPixelWidth * 0.28

                                                    QGCColoredImage {
                                                        Layout.preferredHeight: Layout.preferredWidth
                                                        Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.7
                                                        color: modelData.foreground
                                                        fillMode: Image.PreserveAspectFit
                                                        source: modelData.icon
                                                    }

                                                    QGCLabel {
                                                        Layout.fillWidth: true
                                                        color: modelData.foreground
                                                        elide: Text.ElideRight
                                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.72
                                                        font.weight: Font.DemiBold
                                                        text: modelData.label
                                                        verticalAlignment: Text.AlignVCenter
                                                    }
                                                }

                                                QGCMouseArea {
                                                    id: actionButtonMouseArea

                                                    anchors.fill: parent
                                                    enabled: root._activeVehicle
                                                    hoverEnabled: true

                                                    onClicked: root._triggerGuidedPanelAction(modelData.action)
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
                                        anchors.bottomMargin: vehicleStatusCard._sectionContentBottomMargin
                                        anchors.fill: parent
                                        anchors.leftMargin: vehicleStatusCard._sectionContentLeftMargin
                                        anchors.rightMargin: vehicleStatusCard._sectionContentRightMargin
                                        anchors.topMargin: vehicleStatusCard._sectionContentTopMargin

                                        Item {
                                            Layout.fillHeight: true
                                            Layout.fillWidth: true

                                            ColumnLayout {
                                                anchors.fill: parent
                                                spacing: vehicleStatusCard._sectionContentSpacing

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: vehicleStatusCard._sectionHeaderHeight
                                                    spacing: vehicleStatusCard._sectionHeaderSpacing

                                                    QGCLabel {
                                                        Layout.fillWidth: true
                                                        color: vehicleStatusCard._textPrimaryColor
                                                        font.pixelSize: vehicleStatusCard._sectionHeaderTitleSize
                                                        font.weight: Font.DemiBold
                                                        text: qsTr("仪表")
                                                        verticalAlignment: Text.AlignVCenter
                                                    }

                                                    Rectangle {
                                                        Layout.alignment: Qt.AlignVCenter
                                                        Layout.preferredHeight: Layout.preferredWidth
                                                        Layout.preferredWidth: vehicleStatusCard._sectionHeaderButtonSize
                                                        Layout.rightMargin: vehicleStatusCard._sectionHeaderButtonRightMargin
                                                        border.color: vehicleStatusCard._controlBorderColor
                                                        border.width: vehicleStatusCard._controlBorderWidth
                                                        color: instrumentSettingsMouseArea.pressed ? vehicleStatusCard._buttonSecondaryPressedColor : (instrumentSettingsMouseArea.containsMouse ? vehicleStatusCard._buttonSecondaryHoverColor : vehicleStatusCard._buttonSecondaryColor)
                                                        radius: vehicleStatusCard._controlRadius

                                                        Behavior on color {
                                                            ColorAnimation {
                                                                duration: vehicleStatusCard._transitionDuration
                                                            }
                                                        }

                                                        QGCColoredImage {
                                                            anchors.centerIn: parent
                                                            color: vehicleStatusCard._textSecondaryColor
                                                            fillMode: Image.PreserveAspectFit
                                                            height: width
                                                            source: "/InstrumentValueIcons/cog.svg"
                                                            width: parent.height * vehicleStatusCard._sectionHeaderIconScale
                                                        }

                                                        QGCMouseArea {
                                                            id: instrumentSettingsMouseArea

                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                        }
                                                    }
                                                }

                                                Rectangle {
                                                    id: flightModeDropdownField

                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.9
                                                    border.color: vehicleStatusCard._controlBorderColor
                                                    border.width: vehicleStatusCard._controlBorderWidth
                                                    color: vehicleStatusCard._blockColor
                                                    radius: vehicleStatusCard._controlRadius

                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.38
                                                        anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.28
                                                        spacing: ScreenTools.defaultFontPixelWidth * 0.28

                                                        QGCLabel {
                                                            Layout.alignment: Qt.AlignVCenter
                                                            color: vehicleStatusCard._textPrimaryColor
                                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.56
                                                            text: qsTr("飞行模式")
                                                        }

                                                        Item {
                                                            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 0.12
                                                        }

                                                        Rectangle {
                                                            Layout.fillWidth: true
                                                            Layout.minimumWidth: 0
                                                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.42
                                                            border.color: vehicleStatusCard._controlBorderColor
                                                            border.width: vehicleStatusCard._controlBorderWidth
                                                            color: flightModeMouseArea.pressed ? vehicleStatusCard._buttonSecondaryPressedColor : (flightModeMouseArea.containsMouse ? vehicleStatusCard._buttonSecondaryHoverColor : vehicleStatusCard._fieldColor)
                                                            radius: vehicleStatusCard._controlRadius

                                                            Behavior on color {
                                                                ColorAnimation {
                                                                    duration: vehicleStatusCard._transitionDuration
                                                                }
                                                            }

                                                            RowLayout {
                                                                anchors.fill: parent
                                                                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.3
                                                                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.24
                                                                spacing: ScreenTools.defaultFontPixelWidth * 0.18

                                                                QGCColoredImage {
                                                                    Layout.alignment: Qt.AlignVCenter
                                                                    Layout.preferredHeight: Layout.preferredWidth
                                                                    Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.56
                                                                    color: vehicleStatusCard._textPrimaryColor
                                                                    fillMode: Image.PreserveAspectFit
                                                                    source: "/InstrumentValueIcons/target.svg"
                                                                }

                                                                QGCLabel {
                                                                    Layout.alignment: Qt.AlignVCenter
                                                                    Layout.fillWidth: true
                                                                    Layout.minimumWidth: 0
                                                                    color: vehicleStatusCard._textPrimaryColor
                                                                    elide: Text.ElideRight
                                                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.56
                                                                    fontSizeMode: Text.Fit
                                                                    maximumLineCount: 1
                                                                    minimumPixelSize: 8
                                                                    text: root._activeVehicle && root._activeVehicle.flightMode ? root._flightModeDisplayName(root._activeVehicle.flightMode) : qsTr("自动")
                                                                }

                                                                QGCColoredImage {
                                                                    Layout.alignment: Qt.AlignVCenter
                                                                    Layout.preferredHeight: Layout.preferredWidth
                                                                    Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.34
                                                                    color: vehicleStatusCard._textPrimaryColor
                                                                    fillMode: Image.PreserveAspectFit
                                                                    source: "/InstrumentValueIcons/cheveron-down.svg"
                                                                }
                                                            }

                                                            QGCMouseArea {
                                                                id: flightModeMouseArea

                                                                anchors.fill: parent
                                                                hoverEnabled: true

                                                                onClicked: root._popupMenuInLeftPane(flightModeMenu, flightModeDropdownField, Math.max(flightModeDropdownField.width, root._flightModeMenuMinimumWidth()))
                                                            }
                                                        }
                                                    }
                                                }

                                                FlyViewInstrumentPanel {
                                                    Layout.fillHeight: true
                                                    Layout.fillWidth: true
                                                    panelBottomMargin: 0
                                                    panelLeftMargin: 0
                                                    panelRightMargin: 0
                                                    panelTopMargin: 0
                                                    showHeader: false
                                                    showHeaderAction: false
                                                    useLegacySelectableControl: false
                                                }
                                            }
                                        }
                                    }
                                }

                                Item {
                                    FlyViewDocsChecklistPanel {
                                        anchors.fill: parent
                                        contentBottomMargin: vehicleStatusCard._sectionContentBottomMargin
                                        contentLeftMargin: vehicleStatusCard._sectionContentLeftMargin
                                        contentRightMargin: vehicleStatusCard._sectionContentRightMargin
                                        contentSpacing: vehicleStatusCard._sectionContentSpacing
                                        contentTopMargin: vehicleStatusCard._sectionContentTopMargin
                                        detailColor: vehicleStatusCard._textSecondaryColor
                                        headerActionBorderColor: vehicleStatusCard._controlBorderColor
                                        headerActionColor: vehicleStatusCard._buttonSecondaryColor
                                        headerActionHoverColor: vehicleStatusCard._buttonSecondaryHoverColor
                                        headerActionIconColor: vehicleStatusCard._textSecondaryColor
                                        headerActionIconScale: vehicleStatusCard._sectionHeaderIconScale
                                        headerActionPressedColor: vehicleStatusCard._buttonSecondaryPressedColor
                                        headerActionRadius: vehicleStatusCard._controlRadius
                                        headerActionRightMargin: vehicleStatusCard._sectionHeaderButtonRightMargin
                                        headerActionSize: vehicleStatusCard._sectionHeaderButtonSize
                                        headerHeight: vehicleStatusCard._sectionHeaderHeight
                                        headerSpacing: vehicleStatusCard._sectionHeaderSpacing
                                        headerTitleSize: vehicleStatusCard._sectionHeaderTitleSize
                                        headerTransitionDuration: vehicleStatusCard._transitionDuration
                                        panelColor: vehicleStatusCard._contentColor
                                        showHeaderAction: true
                                        titleColor: vehicleStatusCard._textPrimaryColor
                                        vehicle: root._activeVehicle
                                    }
                                }

                                Item {
                                    id: networkStatusPage

                                    readonly property real _blockRadius: vehicleStatusCard._controlRadius
                                    readonly property real _gpsPercent: root._networkGpsPercent(root._activeVehicle)
                                    readonly property real _innerLeftMargin: ScreenTools.defaultFontPixelWidth * 0.44
                                    readonly property real _innerRightMargin: ScreenTools.defaultFontPixelWidth * 0.34
                                    readonly property color _networkBlockColor: vehicleStatusCard._blockColor
                                    readonly property real _primaryFontSize: ScreenTools.defaultFontPixelHeight * 0.68
                                    readonly property real _rcPercent: root._networkRcPercent(root._activeVehicle)
                                    readonly property real _secondaryFontSize: ScreenTools.defaultFontPixelHeight * 0.64
                                    readonly property real _telemetryPercent: root._networkTelemetryPercent(root._activeVehicle)
                                    readonly property real _titleFontSize: ScreenTools.defaultFontPixelHeight * 0.64

                                    ColumnLayout {
                                        anchors.bottomMargin: vehicleStatusCard._sectionContentBottomMargin
                                        anchors.fill: parent
                                        anchors.leftMargin: vehicleStatusCard._sectionContentLeftMargin
                                        anchors.rightMargin: vehicleStatusCard._sectionContentRightMargin
                                        anchors.topMargin: vehicleStatusCard._sectionContentTopMargin
                                        spacing: vehicleStatusCard._sectionContentSpacing

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: vehicleStatusCard._sectionHeaderHeight
                                            spacing: vehicleStatusCard._sectionHeaderSpacing

                                            QGCLabel {
                                                Layout.fillWidth: true
                                                color: vehicleStatusCard._textPrimaryColor
                                                font.pixelSize: vehicleStatusCard._sectionHeaderTitleSize
                                                font.weight: Font.DemiBold
                                                text: qsTr("网络")
                                                verticalAlignment: Text.AlignVCenter
                                            }

                                            Rectangle {
                                                Layout.preferredHeight: Layout.preferredWidth
                                                Layout.preferredWidth: vehicleStatusCard._sectionHeaderButtonSize
                                                Layout.rightMargin: vehicleStatusCard._sectionHeaderButtonRightMargin
                                                border.color: vehicleStatusCard._controlBorderColor
                                                border.width: vehicleStatusCard._controlBorderWidth
                                                color: networkSettingsMouseArea.pressed ? vehicleStatusCard._buttonSecondaryPressedColor : (networkSettingsMouseArea.containsMouse ? vehicleStatusCard._buttonSecondaryHoverColor : vehicleStatusCard._buttonSecondaryColor)
                                                radius: vehicleStatusCard._controlRadius

                                                Behavior on color {
                                                    ColorAnimation {
                                                        duration: vehicleStatusCard._transitionDuration
                                                    }
                                                }

                                                QGCColoredImage {
                                                    anchors.centerIn: parent
                                                    color: vehicleStatusCard._textSecondaryColor
                                                    fillMode: Image.PreserveAspectFit
                                                    height: width
                                                    source: "/InstrumentValueIcons/cog.svg"
                                                    width: parent.height * vehicleStatusCard._sectionHeaderIconScale
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
                                            border.color: vehicleStatusCard._controlBorderColor
                                            border.width: vehicleStatusCard._controlBorderWidth
                                            color: networkStatusPage._networkBlockColor
                                            radius: networkStatusPage._blockRadius

                                            ColumnLayout {
                                                anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.16
                                                anchors.fill: parent
                                                anchors.leftMargin: networkStatusPage._innerLeftMargin
                                                anchors.rightMargin: networkStatusPage._innerRightMargin
                                                anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.16
                                                spacing: ScreenTools.defaultFontPixelHeight * 0.08

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.04
                                                    spacing: ScreenTools.defaultFontPixelWidth * 0.16

                                                    QGCLabel {
                                                        Layout.fillWidth: true
                                                        color: vehicleStatusCard._textPrimaryColor
                                                        font.pixelSize: networkStatusPage._primaryFontSize
                                                        text: qsTr("GPS 状态")
                                                    }

                                                    QGCColoredImage {
                                                        Layout.preferredHeight: Layout.preferredWidth
                                                        Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.58
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
                                                        text: qsTr("卫星数量")
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
                                                    "label": qsTr("RC 信号"),
                                                    "percent": networkStatusPage._rcPercent
                                                },
                                                {
                                                    "label": qsTr("遥测信号"),
                                                    "percent": networkStatusPage._telemetryPercent
                                                }
                                            ]

                                            delegate: Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.8
                                                border.color: vehicleStatusCard._controlBorderColor
                                                border.width: vehicleStatusCard._controlBorderWidth
                                                color: networkStatusPage._networkBlockColor
                                                radius: networkStatusPage._blockRadius

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
                                                        Layout.preferredHeight: Layout.preferredWidth
                                                        Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.58
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

                                    readonly property real _blockRadius: vehicleStatusCard._controlRadius
                                    readonly property bool _firmwareEnabled: root._vehicleSetupFirmwareAvailable() && (!root._activeVehicle || !root._activeVehicle.armed)
                                    readonly property color _moduleColor: vehicleStatusCard._blockColor
                                    readonly property real _moduleTitleFontSize: ScreenTools.defaultFontPixelHeight * 0.68
                                    readonly property bool _sensorEnabled: !!root._vehicleSetupSensorComponent(root._activeVehicle) && !!root._activeVehicle && !root._activeVehicle.armed
                                    readonly property real _statusFontSize: ScreenTools.defaultFontPixelHeight * 0.62
                                    readonly property real _titleFontSize: ScreenTools.defaultFontPixelHeight * 0.64
                                    readonly property bool _tuningEnabled: !!root._vehicleSetupTuningComponent(root._activeVehicle)

                                    ColumnLayout {
                                        anchors.bottomMargin: vehicleStatusCard._sectionContentBottomMargin
                                        anchors.fill: parent
                                        anchors.leftMargin: vehicleStatusCard._sectionContentLeftMargin
                                        anchors.rightMargin: vehicleStatusCard._sectionContentRightMargin
                                        anchors.topMargin: vehicleStatusCard._sectionContentTopMargin
                                        spacing: vehicleStatusCard._sectionContentSpacing

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: vehicleStatusCard._sectionHeaderHeight
                                            spacing: vehicleStatusCard._sectionHeaderSpacing

                                            QGCLabel {
                                                Layout.fillWidth: true
                                                color: vehicleStatusCard._textPrimaryColor
                                                font.pixelSize: vehicleStatusCard._sectionHeaderTitleSize
                                                font.weight: Font.DemiBold
                                                text: qsTr("飞行器设置")
                                                verticalAlignment: Text.AlignVCenter
                                            }

                                            Rectangle {
                                                Layout.preferredHeight: Layout.preferredWidth
                                                Layout.preferredWidth: vehicleStatusCard._sectionHeaderButtonSize
                                                Layout.rightMargin: vehicleStatusCard._sectionHeaderButtonRightMargin
                                                border.color: vehicleStatusCard._controlBorderColor
                                                border.width: vehicleStatusCard._controlBorderWidth
                                                color: setupSettingsMouseArea.pressed ? vehicleStatusCard._buttonSecondaryPressedColor : (setupSettingsMouseArea.containsMouse ? vehicleStatusCard._buttonSecondaryHoverColor : vehicleStatusCard._buttonSecondaryColor)
                                                radius: vehicleStatusCard._controlRadius

                                                Behavior on color {
                                                    ColorAnimation {
                                                        duration: vehicleStatusCard._transitionDuration
                                                    }
                                                }

                                                QGCColoredImage {
                                                    anchors.centerIn: parent
                                                    color: vehicleStatusCard._textSecondaryColor
                                                    fillMode: Image.PreserveAspectFit
                                                    height: width
                                                    source: "/InstrumentValueIcons/cog.svg"
                                                    width: parent.height * vehicleStatusCard._sectionHeaderIconScale
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
                                            id: setupVehicleSelectorField

                                            Layout.fillWidth: true
                                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.82
                                            border.color: vehicleStatusCard._controlBorderColor
                                            border.width: vehicleStatusCard._controlBorderWidth
                                            color: setupVehicleMouseArea.pressed ? vehicleStatusCard._buttonSecondaryPressedColor : (setupVehicleMouseArea.containsMouse ? vehicleStatusCard._buttonSecondaryHoverColor : vehicleStatusCard._fieldColor)
                                            radius: vehicleStatusCard._controlRadius

                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: vehicleStatusCard._transitionDuration
                                                }
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
                                                    Layout.preferredHeight: Layout.preferredWidth
                                                    Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.36
                                                    color: vehicleStatusCard._textPrimaryColor
                                                    fillMode: Image.PreserveAspectFit
                                                    source: "/InstrumentValueIcons/cheveron-down.svg"
                                                }
                                            }

                                            QGCMouseArea {
                                                id: setupVehicleMouseArea

                                                anchors.fill: parent
                                                enabled: QGroundControl.multiVehicleManager.vehicles && QGroundControl.multiVehicleManager.vehicles.count > 0
                                                hoverEnabled: true

                                                onClicked: root._popupMenuInLeftPane(vehicleMenu, setupVehicleSelectorField, setupVehicleSelectorField.width)
                                            }
                                        }

                                        Repeater {
                                            model: [
                                                {
                                                    "title": qsTr("飞控调参"),
                                                    "buttonText": qsTr("打开"),
                                                    "statusText": root._vehicleSetupTuningStatusText(),
                                                    "statusColor": vehicleSetupPage._tuningEnabled ? "#AFC4D7" : "#8D939A",
                                                    "enabled": vehicleSetupPage._tuningEnabled,
                                                    "action": root._openVehicleSetupTuning
                                                },
                                                {
                                                    "title": qsTr("传感器校准"),
                                                    "buttonText": qsTr("校准"),
                                                    "statusText": root._vehicleSetupSensorStatusText(),
                                                    "statusColor": vehicleSetupPage._sensorEnabled ? "#AFC4D7" : (root._activeVehicle && root._activeVehicle.armed ? "#D6A566" : "#8D939A"),
                                                    "enabled": vehicleSetupPage._sensorEnabled,
                                                    "action": root._openVehicleSetupSensors
                                                },
                                                {
                                                    "title": qsTr("固件更新"),
                                                    "buttonText": qsTr("更新"),
                                                    "statusText": root._vehicleSetupFirmwareStatusText(),
                                                    "statusColor": vehicleSetupPage._firmwareEnabled ? "#AFC4D7" : "#8D939A",
                                                    "enabled": vehicleSetupPage._firmwareEnabled,
                                                    "action": root._openVehicleSetupFirmware
                                                }
                                            ]

                                            delegate: Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3.12
                                                border.color: vehicleStatusCard._controlBorderColor
                                                border.width: vehicleStatusCard._controlBorderWidth
                                                color: vehicleSetupPage._moduleColor
                                                radius: vehicleSetupPage._blockRadius

                                                ColumnLayout {
                                                    anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.2
                                                    anchors.fill: parent
                                                    anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.44
                                                    anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.34
                                                    anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.2
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
                                                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.28
                                                            Layout.preferredWidth: Math.max(ScreenTools.defaultFontPixelWidth * 7.0, parent.width * 0.23)
                                                            border.color: vehicleStatusCard._controlBorderColor
                                                            border.width: vehicleStatusCard._controlBorderWidth
                                                            color: !modelData.enabled ? vehicleStatusCard._buttonSecondaryColor : (moduleActionMouseArea.pressed ? vehicleStatusCard._highlightPressedColor : (moduleActionMouseArea.containsMouse ? vehicleStatusCard._highlightHoverColor : vehicleStatusCard._highlightColor))
                                                            opacity: modelData.enabled ? 1 : 0.5
                                                            radius: vehicleStatusCard._controlRadius

                                                            Behavior on color {
                                                                ColorAnimation {
                                                                    duration: vehicleStatusCard._transitionDuration
                                                                }
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
                                                                enabled: modelData.enabled
                                                                hoverEnabled: true

                                                                onClicked: {
                                                                    if (typeof modelData.action === "function") {
                                                                        modelData.action();
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

                                    property var _accelSeries: []
                                    property real _baroBaseline: NaN
                                    property var _baroSeries: []
                                    readonly property real _blockRadius: vehicleStatusCard._controlRadius
                                    readonly property color _chartBackgroundColor: "#252525"
                                    property real _cpuLoadPercent: 15
                                    property var _gyroSeries: []
                                    property bool _healthNominal: false
                                    property real _lastHeading: NaN
                                    property bool _logActive: false
                                    property var _magSeries: []
                                    readonly property color _moduleColor: vehicleStatusCard._blockColor
                                    readonly property color _okColor: "#32D296"
                                    readonly property real _sectionTitleFontSize: ScreenTools.defaultFontPixelHeight * 0.68
                                    readonly property int _seriesMaxCount: 100
                                    readonly property color _statusCardColor: "#363636"
                                    readonly property color _summaryCardColor: "#333333"
                                    readonly property var _summaryModel: [
                                        {
                                            "title": qsTr("GPS"),
                                            "bit": Vehicle.SysStatusSensorGPS,
                                            "goodText": qsTr("良好"),
                                            "badText": qsTr("降级"),
                                            "detail": "sat"
                                        },
                                        {
                                            "title": qsTr("罗盘"),
                                            "bit": Vehicle.SysStatusSensor3dMag,
                                            "goodText": qsTr("已校准"),
                                            "badText": qsTr("复检"),
                                            "detail": ""
                                        },
                                        {
                                            "title": qsTr("加速度计"),
                                            "bit": Vehicle.SysStatusSensor3dAccel,
                                            "goodText": qsTr("正常"),
                                            "badText": qsTr("注意"),
                                            "detail": ""
                                        },
                                        {
                                            "title": qsTr("陀螺仪"),
                                            "bit": Vehicle.SysStatusSensor3dGyro,
                                            "goodText": qsTr("正常"),
                                            "badText": qsTr("注意"),
                                            "detail": ""
                                        }
                                    ]
                                    property real _telemetryPhase: 0
                                    readonly property real _textFontSize: ScreenTools.defaultFontPixelHeight * 0.58
                                    readonly property real _titleFontSize: ScreenTools.defaultFontPixelHeight * 0.64
                                    readonly property real _valueFontSize: ScreenTools.defaultFontPixelHeight * 0.62

                                    function _appendSample(series, value) {
                                        const numericValue = Number(value);
                                        if (series.length >= _seriesMaxCount) {
                                            series.shift();
                                        }
                                        series.push(isNaN(numericValue) ? 0 : numericValue);
                                    }

                                    function _factValue(fact) {
                                        return root._hasFactValue(fact) ? Number(fact.rawValue) : NaN;
                                    }

                                    function _fallbackWave(offset, amplitude, center) {
                                        const primary = Math.sin(_telemetryPhase + offset) * amplitude;
                                        const secondary = Math.cos((_telemetryPhase * 0.62) + offset) * amplitude * 0.24;
                                        return center + primary + secondary;
                                    }

                                    function _refreshTelemetry() {
                                        const vehicle = root._activeVehicle;
                                        _telemetryPhase += 0.18;

                                        _cpuLoadPercent = root._sensorCpuLoadPercent(vehicle);
                                        _logActive = root._sensorLogActive(vehicle);
                                        _healthNominal = root._sensorHealthNominal(vehicle);

                                        const rollRate = _factValue(vehicle ? vehicle.rollRate : null);
                                        const pitchRate = _factValue(vehicle ? vehicle.pitchRate : null);
                                        const yawRate = _factValue(vehicle ? vehicle.yawRate : null);
                                        let gyroSample = NaN;

                                        if (!isNaN(rollRate) || !isNaN(pitchRate) || !isNaN(yawRate)) {
                                            gyroSample = (Math.abs(isNaN(rollRate) ? 0 : rollRate) * 0.42) + (Math.abs(isNaN(pitchRate) ? 0 : pitchRate) * 0.32) + (Math.abs(isNaN(yawRate) ? 0 : yawRate) * 0.26);
                                        }
                                        if (isNaN(gyroSample)) {
                                            gyroSample = _fallbackWave(0.18, 0.42, 0.95);
                                        }

                                        const vibration = vehicle ? vehicle.vibration : null;
                                        const vibX = _factValue(vibration ? vibration.xAxis : null);
                                        const vibY = _factValue(vibration ? vibration.yAxis : null);
                                        const vibZ = _factValue(vibration ? vibration.zAxis : null);
                                        let accelSample = NaN;

                                        if (!isNaN(vibX) || !isNaN(vibY) || !isNaN(vibZ)) {
                                            const ax = isNaN(vibX) ? 0 : vibX;
                                            const ay = isNaN(vibY) ? 0 : vibY;
                                            const az = isNaN(vibZ) ? 0 : vibZ;
                                            accelSample = Math.sqrt((ax * ax) + (ay * ay) + (az * az));
                                        }
                                        if (isNaN(accelSample)) {
                                            accelSample = _fallbackWave(1.05, 0.36, 0.78);
                                        }

                                        const heading = _factValue(vehicle ? vehicle.heading : null);
                                        let magSample = NaN;
                                        if (!isNaN(heading)) {
                                            if (!isNaN(_lastHeading)) {
                                                let headingDelta = Math.abs(heading - _lastHeading);
                                                if (headingDelta > 180) {
                                                    headingDelta = 360 - headingDelta;
                                                }
                                                magSample = headingDelta;
                                            }
                                            _lastHeading = heading;
                                        }
                                        if (isNaN(magSample)) {
                                            magSample = _fallbackWave(1.72, 0.26, 0.52);
                                        }

                                        const altitude = _factValue(vehicle ? vehicle.altitudeRelative : null);
                                        let baroSample = NaN;
                                        if (!isNaN(altitude)) {
                                            if (isNaN(_baroBaseline)) {
                                                _baroBaseline = altitude;
                                            }
                                            _baroBaseline = (_baroBaseline * 0.985) + (altitude * 0.015);
                                            baroSample = altitude - _baroBaseline;
                                        }
                                        if (isNaN(baroSample)) {
                                            baroSample = _fallbackWave(2.2, 0.2, 0.45);
                                        }

                                        _appendSample(_gyroSeries, gyroSample);
                                        _appendSample(_accelSeries, accelSample);
                                        _appendSample(_magSeries, magSample);
                                        _appendSample(_baroSeries, baroSample);

                                        if (telemetryWaveCanvas) {
                                            telemetryWaveCanvas.requestPaint();
                                        }
                                        if (cpuLoadGaugeCanvas) {
                                            cpuLoadGaugeCanvas.requestPaint();
                                        }
                                    }

                                    onVisibleChanged: {
                                        if (visible) {
                                            _refreshTelemetry();
                                        }
                                    }
                                    on_CpuLoadPercentChanged: {
                                        if (cpuLoadGaugeCanvas) {
                                            cpuLoadGaugeCanvas.requestPaint();
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
                                        anchors.bottomMargin: vehicleStatusCard._sectionContentBottomMargin
                                        anchors.fill: parent
                                        anchors.leftMargin: vehicleStatusCard._sectionContentLeftMargin
                                        anchors.rightMargin: vehicleStatusCard._sectionContentRightMargin
                                        anchors.topMargin: vehicleStatusCard._sectionContentTopMargin
                                        spacing: vehicleStatusCard._sectionContentSpacing

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: vehicleStatusCard._sectionHeaderHeight
                                            spacing: vehicleStatusCard._sectionHeaderSpacing

                                            QGCLabel {
                                                Layout.fillWidth: true
                                                color: vehicleStatusCard._textPrimaryColor
                                                font.pixelSize: vehicleStatusCard._sectionHeaderTitleSize
                                                font.weight: Font.DemiBold
                                                horizontalAlignment: Text.AlignLeft
                                                text: qsTr("传感器/遥测")
                                                verticalAlignment: Text.AlignVCenter
                                            }

                                            Rectangle {
                                                Layout.preferredHeight: Layout.preferredWidth
                                                Layout.preferredWidth: vehicleStatusCard._sectionHeaderButtonSize
                                                Layout.rightMargin: vehicleStatusCard._sectionHeaderButtonRightMargin
                                                border.color: vehicleStatusCard._controlBorderColor
                                                border.width: vehicleStatusCard._controlBorderWidth
                                                color: sensorSettingsMouseArea.pressed ? vehicleStatusCard._buttonSecondaryPressedColor : (sensorSettingsMouseArea.containsMouse ? vehicleStatusCard._buttonSecondaryHoverColor : vehicleStatusCard._buttonSecondaryColor)
                                                radius: vehicleStatusCard._controlRadius

                                                Behavior on color {
                                                    ColorAnimation {
                                                        duration: vehicleStatusCard._transitionDuration
                                                    }
                                                }

                                                QGCColoredImage {
                                                    anchors.centerIn: parent
                                                    color: vehicleStatusCard._textSecondaryColor
                                                    fillMode: Image.PreserveAspectFit
                                                    height: width
                                                    source: "/InstrumentValueIcons/cog.svg"
                                                    width: parent.height * vehicleStatusCard._sectionHeaderIconScale
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

                                            Layout.fillHeight: true
                                            Layout.fillWidth: true
                                            boundsBehavior: Flickable.StopAtBounds
                                            clip: true
                                            contentHeight: sensorsTelemetryContent.implicitHeight
                                            contentWidth: width
                                            flickableDirection: Flickable.VerticalFlick

                                            ScrollBar.vertical: ScrollBar {
                                                id: sensorsTelemetryScrollBar

                                                policy: ScrollBar.AlwaysOn
                                            }

                                            WheelHandler {
                                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                                target: null

                                                onWheel: event => {
                                                    const step = ScreenTools.defaultFontPixelHeight * 2.2;
                                                    const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : (event.pixelDelta ? event.pixelDelta.y : 0);
                                                    if (delta === 0) {
                                                        return;
                                                    }
                                                    sensorsTelemetryFlickable.contentY = Math.max(0, Math.min(sensorsTelemetryFlickable.contentHeight - sensorsTelemetryFlickable.height, sensorsTelemetryFlickable.contentY - ((delta / 120) * step)));
                                                }
                                            }

                                            ColumnLayout {
                                                id: sensorsTelemetryContent

                                                spacing: ScreenTools.defaultFontPixelHeight * 0.11
                                                width: Math.max(1, sensorsTelemetryFlickable.width - sensorsTelemetryScrollBar.width - (ScreenTools.defaultFontPixelWidth * 0.1))

                                                Rectangle {
                                                    id: fcStatusModule

                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 4.85
                                                    border.color: vehicleStatusCard._controlBorderColor
                                                    border.width: vehicleStatusCard._controlBorderWidth
                                                    color: sensorsTelemetryPage._moduleColor
                                                    radius: sensorsTelemetryPage._blockRadius

                                                    ColumnLayout {
                                                        anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.18
                                                        anchors.fill: parent
                                                        anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.38
                                                        anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.32
                                                        anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.18
                                                        spacing: ScreenTools.defaultFontPixelHeight * 0.12

                                                        QGCLabel {
                                                            Layout.fillWidth: true
                                                            color: vehicleStatusCard._textPrimaryColor
                                                            font.pixelSize: sensorsTelemetryPage._sectionTitleFontSize
                                                            font.weight: Font.DemiBold
                                                            text: qsTr("飞控状态")
                                                        }

                                                        RowLayout {
                                                            Layout.fillHeight: true
                                                            Layout.fillWidth: true
                                                            spacing: ScreenTools.defaultFontPixelWidth * 0.24

                                                            Item {
                                                                Layout.fillHeight: true
                                                                Layout.fillWidth: true

                                                                Rectangle {
                                                                    anchors.centerIn: parent
                                                                    color: sensorsTelemetryPage._statusCardColor
                                                                    height: width
                                                                    radius: sensorsTelemetryPage._blockRadius
                                                                    width: Math.min(parent.width, parent.height)

                                                                    Item {
                                                                        anchors.fill: parent
                                                                        anchors.margins: ScreenTools.defaultFontPixelHeight * 0.14

                                                                        Canvas {
                                                                            id: cpuLoadGaugeCanvas

                                                                            anchors.horizontalCenter: parent.horizontalCenter
                                                                            anchors.top: parent.top
                                                                            height: width
                                                                            width: Math.min(parent.width, parent.height) * 0.56

                                                                            onPaint: {
                                                                                const ctx = getContext("2d");
                                                                                ctx.clearRect(0, 0, width, height);
                                                                                const centerX = width * 0.5;
                                                                                const centerY = height * 0.5;
                                                                                const radius = Math.min(width, height) * 0.39;
                                                                                const progress = Math.max(0, Math.min(1, sensorsTelemetryPage._cpuLoadPercent / 100));

                                                                                ctx.lineCap = "round";
                                                                                ctx.lineWidth = Math.max(2, width * 0.08);
                                                                                ctx.strokeStyle = "rgba(255,255,255,0.14)";
                                                                                ctx.beginPath();
                                                                                ctx.arc(centerX, centerY, radius, -Math.PI / 2, Math.PI * 1.5);
                                                                                ctx.stroke();

                                                                                ctx.strokeStyle = "#20D3BE";
                                                                                ctx.beginPath();
                                                                                ctx.arc(centerX, centerY, radius, -Math.PI / 2, (-Math.PI / 2) + (Math.PI * 2 * progress));
                                                                                ctx.stroke();
                                                                            }
                                                                        }

                                                                        QGCLabel {
                                                                            anchors.bottom: parent.bottom
                                                                            anchors.left: parent.left
                                                                            anchors.right: parent.right
                                                                            color: vehicleStatusCard._textSecondaryColor
                                                                            font.pixelSize: sensorsTelemetryPage._textFontSize
                                                                            horizontalAlignment: Text.AlignHCenter
                                                                            text: qsTr("CPU 负载：%1%").arg(Math.round(sensorsTelemetryPage._cpuLoadPercent))
                                                                            wrapMode: Text.WordWrap
                                                                        }
                                                                    }
                                                                }
                                                            }

                                                            Item {
                                                                Layout.fillHeight: true
                                                                Layout.fillWidth: true

                                                                Rectangle {
                                                                    anchors.centerIn: parent
                                                                    color: sensorsTelemetryPage._statusCardColor
                                                                    height: width
                                                                    radius: sensorsTelemetryPage._blockRadius
                                                                    width: Math.min(parent.width, parent.height)

                                                                    Item {
                                                                        anchors.fill: parent
                                                                        anchors.margins: ScreenTools.defaultFontPixelHeight * 0.14

                                                                        Rectangle {
                                                                            anchors.horizontalCenter: parent.horizontalCenter
                                                                            anchors.top: parent.top
                                                                            color: sensorsTelemetryPage._okColor
                                                                            height: width
                                                                            radius: width * 0.5
                                                                            width: Math.min(parent.width, parent.height) * 0.3

                                                                            QGCColoredImage {
                                                                                anchors.centerIn: parent
                                                                                color: vehicleStatusCard._textPrimaryColor
                                                                                fillMode: Image.PreserveAspectFit
                                                                                height: width
                                                                                source: "/InstrumentValueIcons/checkmark.svg"
                                                                                width: parent.height * 0.52
                                                                            }
                                                                        }

                                                                        QGCLabel {
                                                                            anchors.bottom: parent.bottom
                                                                            anchors.left: parent.left
                                                                            anchors.right: parent.right
                                                                            color: vehicleStatusCard._textSecondaryColor
                                                                            font.pixelSize: sensorsTelemetryPage._textFontSize
                                                                            horizontalAlignment: Text.AlignHCenter
                                                                            text: qsTr("日志状态：%1").arg(sensorsTelemetryPage._logActive ? qsTr("活动") : qsTr("未活动"))
                                                                            wrapMode: Text.WordWrap
                                                                        }
                                                                    }
                                                                }
                                                            }

                                                            Item {
                                                                Layout.fillHeight: true
                                                                Layout.fillWidth: true

                                                                Rectangle {
                                                                    anchors.centerIn: parent
                                                                    color: sensorsTelemetryPage._statusCardColor
                                                                    height: width
                                                                    radius: sensorsTelemetryPage._blockRadius
                                                                    width: Math.min(parent.width, parent.height)

                                                                    Item {
                                                                        anchors.fill: parent
                                                                        anchors.margins: ScreenTools.defaultFontPixelHeight * 0.14

                                                                        QGCColoredImage {
                                                                            anchors.horizontalCenter: parent.horizontalCenter
                                                                            anchors.top: parent.top
                                                                            color: sensorsTelemetryPage._healthNominal ? sensorsTelemetryPage._okColor : "#F0BB6C"
                                                                            fillMode: Image.PreserveAspectFit
                                                                            height: width
                                                                            source: "/InstrumentValueIcons/shield.svg"
                                                                            width: Math.min(parent.width, parent.height) * 0.28
                                                                        }

                                                                        QGCLabel {
                                                                            anchors.bottom: parent.bottom
                                                                            anchors.left: parent.left
                                                                            anchors.right: parent.right
                                                                            color: vehicleStatusCard._textSecondaryColor
                                                                            font.pixelSize: sensorsTelemetryPage._textFontSize
                                                                            horizontalAlignment: Text.AlignHCenter
                                                                            text: qsTr("健康状态：%1").arg(sensorsTelemetryPage._healthNominal ? qsTr("正常") : qsTr("注意"))
                                                                            wrapMode: Text.WordWrap
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
                                                    border.color: vehicleStatusCard._controlBorderColor
                                                    border.width: vehicleStatusCard._controlBorderWidth
                                                    color: sensorsTelemetryPage._moduleColor
                                                    radius: sensorsTelemetryPage._blockRadius

                                                    ColumnLayout {
                                                        anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.18
                                                        anchors.fill: parent
                                                        anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.38
                                                        anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.32
                                                        anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.18
                                                        spacing: ScreenTools.defaultFontPixelHeight * 0.1

                                                        QGCLabel {
                                                            Layout.fillWidth: true
                                                            color: vehicleStatusCard._textPrimaryColor
                                                            font.pixelSize: sensorsTelemetryPage._sectionTitleFontSize
                                                            font.weight: Font.DemiBold
                                                            text: qsTr("传感器实时遥测")
                                                        }

                                                        Rectangle {
                                                            Layout.fillHeight: true
                                                            Layout.fillWidth: true
                                                            color: sensorsTelemetryPage._chartBackgroundColor
                                                            radius: sensorsTelemetryPage._blockRadius

                                                            Canvas {
                                                                id: telemetryWaveCanvas

                                                                function drawSeries(ctx, left, top, plotWidth, plotHeight, samples, color) {
                                                                    if (!samples || samples.length < 2) {
                                                                        return;
                                                                    }
                                                                    let minValue = Number(samples[0]);
                                                                    let maxValue = Number(samples[0]);

                                                                    for (let i = 1; i < samples.length; i++) {
                                                                        const sampleValue = Number(samples[i]);
                                                                        if (!isNaN(sampleValue)) {
                                                                            minValue = Math.min(minValue, sampleValue);
                                                                            maxValue = Math.max(maxValue, sampleValue);
                                                                        }
                                                                    }

                                                                    if (isNaN(minValue) || isNaN(maxValue)) {
                                                                        return;
                                                                    }
                                                                    if (Math.abs(maxValue - minValue) < 0.0001) {
                                                                        maxValue += 0.5;
                                                                        minValue -= 0.5;
                                                                    }

                                                                    const padding = (maxValue - minValue) * 0.18;
                                                                    minValue -= padding;
                                                                    maxValue += padding;
                                                                    const valueSpan = Math.max(maxValue - minValue, 0.001);

                                                                    ctx.beginPath();
                                                                    for (let i = 0; i < samples.length; i++) {
                                                                        const sampleValue = Number(samples[i]);
                                                                        const x = left + ((plotWidth * i) / Math.max(samples.length - 1, 1));
                                                                        const normalized = (sampleValue - minValue) / valueSpan;
                                                                        const y = top + plotHeight - (normalized * plotHeight);
                                                                        if (i === 0) {
                                                                            ctx.moveTo(x, y);
                                                                        } else {
                                                                            ctx.lineTo(x, y);
                                                                        }
                                                                    }
                                                                    ctx.strokeStyle = color;
                                                                    ctx.lineWidth = 2;
                                                                    ctx.lineJoin = "round";
                                                                    ctx.lineCap = "round";
                                                                    ctx.stroke();
                                                                }

                                                                anchors.fill: parent

                                                                onPaint: {
                                                                    const ctx = getContext("2d");
                                                                    ctx.clearRect(0, 0, width, height);

                                                                    const left = ScreenTools.defaultFontPixelWidth * 0.42;
                                                                    const right = ScreenTools.defaultFontPixelWidth * 0.32;
                                                                    const top = ScreenTools.defaultFontPixelHeight * 0.3;
                                                                    const bottom = ScreenTools.defaultFontPixelHeight * 0.28;
                                                                    const plotWidth = Math.max(1, width - left - right);
                                                                    const plotHeight = Math.max(1, height - top - bottom);

                                                                    ctx.strokeStyle = "rgba(255,255,255,0.10)";
                                                                    ctx.lineWidth = 1;

                                                                    for (let column = 0; column <= 6; column++) {
                                                                        const x = left + ((plotWidth * column) / 6);
                                                                        ctx.beginPath();
                                                                        ctx.moveTo(x, top);
                                                                        ctx.lineTo(x, top + plotHeight);
                                                                        ctx.stroke();
                                                                    }

                                                                    for (let row = 0; row <= 4; row++) {
                                                                        const y = top + ((plotHeight * row) / 4);
                                                                        ctx.beginPath();
                                                                        ctx.moveTo(left, y);
                                                                        ctx.lineTo(left + plotWidth, y);
                                                                        ctx.stroke();
                                                                    }

                                                                    drawSeries(ctx, left, top, plotWidth, plotHeight, sensorsTelemetryPage._gyroSeries, "#4EA6FF");
                                                                    drawSeries(ctx, left, top, plotWidth, plotHeight, sensorsTelemetryPage._accelSeries, "#FF696E");
                                                                    drawSeries(ctx, left, top, plotWidth, plotHeight, sensorsTelemetryPage._magSeries, "#56D38A");
                                                                    drawSeries(ctx, left, top, plotWidth, plotHeight, sensorsTelemetryPage._baroSeries, "#F2C94C");
                                                                }
                                                            }
                                                        }

                                                        RowLayout {
                                                            Layout.fillWidth: true
                                                            spacing: ScreenTools.defaultFontPixelWidth * 0.2

                                                            Repeater {
                                                                model: [
                                                                    {
                                                                        "label": qsTr("IMU 陀螺仪"),
                                                                        "color": "#4EA6FF"
                                                                    },
                                                                    {
                                                                        "label": qsTr("IMU 加速度计"),
                                                                        "color": "#FF696E"
                                                                    },
                                                                    {
                                                                        "label": qsTr("磁力计"),
                                                                        "color": "#56D38A"
                                                                    },
                                                                    {
                                                                        "label": qsTr("气压计"),
                                                                        "color": "#F2C94C"
                                                                    }
                                                                ]

                                                                delegate: RowLayout {
                                                                    Layout.fillWidth: true
                                                                    spacing: ScreenTools.defaultFontPixelWidth * 0.12

                                                                    Rectangle {
                                                                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 0.12
                                                                        Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 0.82
                                                                        color: modelData.color
                                                                        radius: height * 0.5
                                                                    }

                                                                    QGCLabel {
                                                                        Layout.fillWidth: true
                                                                        color: vehicleStatusCard._textSecondaryColor
                                                                        elide: Text.ElideRight
                                                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5
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
                                                    border.color: vehicleStatusCard._controlBorderColor
                                                    border.width: vehicleStatusCard._controlBorderWidth
                                                    color: sensorsTelemetryPage._moduleColor
                                                    radius: sensorsTelemetryPage._blockRadius

                                                    ColumnLayout {
                                                        anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.18
                                                        anchors.fill: parent
                                                        anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.38
                                                        anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.32
                                                        anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.18
                                                        spacing: ScreenTools.defaultFontPixelHeight * 0.1

                                                        QGCLabel {
                                                            Layout.fillWidth: true
                                                            color: vehicleStatusCard._textPrimaryColor
                                                            font.pixelSize: sensorsTelemetryPage._sectionTitleFontSize
                                                            font.weight: Font.DemiBold
                                                            text: qsTr("传感器健康摘要")
                                                        }

                                                        GridLayout {
                                                            Layout.fillHeight: true
                                                            Layout.fillWidth: true
                                                            columnSpacing: ScreenTools.defaultFontPixelWidth * 0.22
                                                            columns: 2
                                                            rowSpacing: ScreenTools.defaultFontPixelHeight * 0.12

                                                            Repeater {
                                                                model: sensorsTelemetryPage._summaryModel

                                                                delegate: Rectangle {
                                                                    id: summaryCard

                                                                    readonly property bool _healthy: root._sensorBitHealthy(root._activeVehicle, modelData.bit)

                                                                    Layout.fillHeight: true
                                                                    Layout.fillWidth: true
                                                                    border.color: vehicleStatusCard._controlBorderColor
                                                                    border.width: vehicleStatusCard._controlBorderWidth
                                                                    color: sensorsTelemetryPage._summaryCardColor
                                                                    radius: sensorsTelemetryPage._blockRadius

                                                                    RowLayout {
                                                                        anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.12
                                                                        anchors.fill: parent
                                                                        anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.3
                                                                        anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.24
                                                                        anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.12
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
                                                                                text: qsTr("状态：%1").arg(root._sensorStatusTextForBit(root._activeVehicle, modelData.bit, modelData.goodText, modelData.badText, qsTr("离线")))
                                                                            }

                                                                            QGCLabel {
                                                                                color: vehicleStatusCard._textSecondaryColor
                                                                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5
                                                                                text: qsTr("卫星：%1").arg(root._sensorGpsSatelliteText(root._activeVehicle))
                                                                                visible: modelData.detail === "sat"
                                                                            }
                                                                        }

                                                                        Rectangle {
                                                                            Layout.preferredHeight: Layout.preferredWidth
                                                                            Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.62
                                                                            color: summaryCard._healthy ? sensorsTelemetryPage._okColor : "#F0BB6C"
                                                                            radius: Layout.preferredWidth * 0.5

                                                                            QGCColoredImage {
                                                                                anchors.centerIn: parent
                                                                                color: vehicleStatusCard._textPrimaryColor
                                                                                fillMode: Image.PreserveAspectFit
                                                                                height: width
                                                                                source: summaryCard._healthy ? "/InstrumentValueIcons/checkmark.svg" : "/InstrumentValueIcons/exclamation-outline.svg"
                                                                                width: parent.height * 0.52
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

                                            function _rowLabel(rowIndex) {
                                                switch (rowIndex) {
                                                case 0:
                                                    return qsTr("Remaining Flight Time");
                                                case 1:
                                                    return qsTr("Remaining Mission Time");
                                                case 2:
                                                    return qsTr("Home");
                                                case 3:
                                                    return qsTr("GPS");
                                                case 4:
                                                    return qsTr("EKF");
                                                case 5:
                                                    return qsTr("Link");
                                                case 6:
                                                    return qsTr("RTL Safety");
                                                default:
                                                    return "";
                                                }
                                            }

                                            function _rowLevel(rowIndex) {
                                                const remainingFlightSeconds = root._remainingFlightSeconds(root._activeVehicle);
                                                const remainingMissionSeconds = root._missionRemainingSeconds(root._activeVehicle);
                                                const gpsPercent = root._networkGpsPercent(root._activeVehicle);
                                                const telemetryPercent = root._communicationTelemetryQualityPercent(root._activeVehicle);
                                                switch (rowIndex) {
                                                case 0:
                                                    return isNaN(remainingFlightSeconds) ? 1 : (remainingFlightSeconds <= 120 ? 2 : (remainingFlightSeconds <= 300 ? 1 : 0));
                                                case 1:
                                                    return (isNaN(remainingMissionSeconds) || isNaN(remainingFlightSeconds)) ? 1 : (remainingMissionSeconds > (remainingFlightSeconds * 0.95) ? 2 : (remainingMissionSeconds > (remainingFlightSeconds * 0.7) ? 1 : 0));
                                                case 2:
                                                    return root._homeIsValid(root._activeVehicle) ? 0 : 2;
                                                case 3:
                                                    return isNaN(gpsPercent) ? 1 : (gpsPercent < 35 ? 2 : (gpsPercent < 60 ? 1 : 0));
                                                case 4:
                                                    return root._ekfStatusLevel(root._activeVehicle);
                                                case 5:
                                                    return isNaN(telemetryPercent) ? 1 : (telemetryPercent < 35 ? 2 : (telemetryPercent < 60 ? 1 : 0));
                                                case 6:
                                                    return root._rtlSafetyLevel(root._activeVehicle);
                                                default:
                                                    return 1;
                                                }
                                            }

                                            function _rowValue(rowIndex) {
                                                const remainingFlightSeconds = root._remainingFlightSeconds(root._activeVehicle);
                                                const remainingMissionSeconds = root._missionRemainingSeconds(root._activeVehicle);
                                                const gpsPercent = root._networkGpsPercent(root._activeVehicle);
                                                const telemetryPercent = root._communicationTelemetryQualityPercent(root._activeVehicle);
                                                const distanceHomeMeters = root._distanceToHomeMeters(root._activeVehicle);
                                                switch (rowIndex) {
                                                case 0:
                                                    return root._formatDurationClock(remainingFlightSeconds);
                                                case 1:
                                                    return root._formatDurationClock(remainingMissionSeconds);
                                                case 2:
                                                    if (!root._homeIsValid(root._activeVehicle)) {
                                                        return qsTr("Not Set");
                                                    }
                                                    return isNaN(distanceHomeMeters) ? qsTr("Set") : qsTr("Set | %1 m").arg(Math.round(distanceHomeMeters));
                                                case 3:
                                                    return isNaN(gpsPercent) ? qsTr("No Data") : qsTr("%1 | %2 sats").arg(root._networkStatusText(gpsPercent)).arg(root._networkSatelliteText(root._activeVehicle));
                                                case 4:
                                                    return root._ekfStatusText(root._activeVehicle);
                                                case 5:
                                                    return isNaN(telemetryPercent) ? qsTr("No Data") : qsTr("%1 | %2%").arg(root._communicationTelemetryStatusText(telemetryPercent)).arg(Math.round(telemetryPercent));
                                                case 6:
                                                    return root._rtlSafetyText(root._activeVehicle);
                                                default:
                                                    return "--";
                                                }
                                            }

                                            clip: true

                                            ColumnLayout {
                                                anchors.bottomMargin: vehicleStatusCard._sectionContentBottomMargin
                                                anchors.fill: parent
                                                anchors.leftMargin: vehicleStatusCard._sectionContentLeftMargin
                                                anchors.rightMargin: vehicleStatusCard._sectionContentRightMargin
                                                anchors.topMargin: vehicleStatusCard._sectionContentTopMargin
                                                spacing: ScreenTools.defaultFontPixelHeight * 0.16

                                                QGCLabel {
                                                    Layout.fillWidth: true
                                                    color: vehicleStatusCard._textPrimaryColor
                                                    font.pixelSize: vehicleStatusCard._sectionHeaderTitleSize
                                                    font.weight: Font.DemiBold
                                                    text: qsTr("飞行准备")
                                                }

                                                Repeater {
                                                    model: 7

                                                    delegate: Rectangle {
                                                        required property int index

                                                        Layout.fillWidth: true
                                                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.16
                                                        border.color: vehicleStatusCard._controlBorderColor
                                                        border.width: vehicleStatusCard._controlBorderWidth
                                                        color: vehicleStatusCard._blockColor
                                                        radius: vehicleStatusCard._controlRadius

                                                        RowLayout {
                                                            anchors.fill: parent
                                                            anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.26
                                                            anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.26
                                                            spacing: ScreenTools.defaultFontPixelWidth * 0.24

                                                            Rectangle {
                                                                Layout.alignment: Qt.AlignVCenter
                                                                Layout.preferredHeight: Layout.preferredWidth
                                                                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.4
                                                                color: root._summaryStateColor(flyPrepBatteryPage._rowLevel(index))
                                                                radius: Layout.preferredWidth * 0.5
                                                            }

                                                            QGCLabel {
                                                                Layout.fillWidth: true
                                                                color: vehicleStatusCard._textSecondaryColor
                                                                elide: Text.ElideRight
                                                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.56
                                                                text: flyPrepBatteryPage._rowLabel(index)
                                                            }

                                                            QGCLabel {
                                                                color: root._summaryStateColor(flyPrepBatteryPage._rowLevel(index))
                                                                elide: Text.ElideRight
                                                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.56
                                                                font.weight: Font.DemiBold
                                                                text: flyPrepBatteryPage._rowValue(index)
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        Repeater {
                                            model: vehicleStatusCard._statusPages.slice(7, 9)

                                            delegate: Item {
                                                readonly property bool _isClusterPage: modelData.title === qsTr("集群")
                                                clip: true

                                                Flickable {
                                                    anchors.fill: parent
                                                    boundsBehavior: Flickable.StopAtBounds
                                                    clip: true
                                                    contentHeight: placeholderColumn.implicitHeight
                                                    contentWidth: width
                                                    flickableDirection: Flickable.VerticalFlick

                                                    ScrollBar.vertical: ScrollBar {
                                                        policy: ScrollBar.AsNeeded
                                                    }

                                                    ColumnLayout {
                                                        id: placeholderColumn

                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        spacing: _isClusterPage ? ScreenTools.defaultFontPixelHeight * 0.18 : ScreenTools.defaultFontPixelHeight * 0.35
                                                        width: _isClusterPage ? parent.width : Math.min(parent.width - (ScreenTools.defaultFontPixelWidth * 1.8), ScreenTools.defaultFontPixelWidth * 18)
                                                        y: _isClusterPage ? 0 : Math.max(ScreenTools.defaultFontPixelHeight * 0.72, (parent.height - implicitHeight) * 0.5)

                                                        QGCColoredImage {
                                                            Layout.alignment: Qt.AlignHCenter
                                                            Layout.preferredHeight: Layout.preferredWidth
                                                            Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 2.0
                                                            color: vehicleStatusCard._highlightColor
                                                            fillMode: Image.PreserveAspectFit
                                                            source: modelData.icon
                                                            visible: !_isClusterPage
                                                        }

                                                        QGCLabel {
                                                            Layout.alignment: Qt.AlignHCenter
                                                            color: vehicleStatusCard._textPrimaryColor
                                                            font.weight: Font.DemiBold
                                                            text: modelData.title
                                                            visible: !_isClusterPage
                                                        }

                                                        QGCLabel {
                                                            Layout.alignment: Qt.AlignHCenter
                                                            color: vehicleStatusCard._textSecondaryColor
                                                            horizontalAlignment: Text.AlignHCenter
                                                            text: qsTr("此区域预留给%1").arg(modelData.title)
                                                            visible: !_isClusterPage
                                                            wrapMode: Text.WordWrap
                                                        }

                                                        RowLayout {
                                                            Layout.fillWidth: true
                                                            Layout.preferredHeight: vehicleStatusCard._sectionHeaderHeight
                                                            spacing: vehicleStatusCard._sectionHeaderSpacing
                                                            visible: _isClusterPage

                                                            QGCLabel {
                                                                Layout.fillWidth: true
                                                                color: vehicleStatusCard._textPrimaryColor
                                                                font.pixelSize: vehicleStatusCard._sectionHeaderTitleSize
                                                                font.weight: Font.DemiBold
                                                                text: qsTr("集群快捷")
                                                                verticalAlignment: Text.AlignVCenter
                                                            }

                                                            Rectangle {
                                                                Layout.preferredHeight: vehicleStatusCard._sectionHeaderButtonSize
                                                                Layout.preferredWidth: Math.max(openClusterLabel.implicitWidth + ScreenTools.defaultFontPixelWidth * 1.0, ScreenTools.defaultFontPixelWidth * 5.8)
                                                                border.color: vehicleStatusCard._controlBorderColor
                                                                border.width: vehicleStatusCard._controlBorderWidth
                                                                color: openClusterMouseArea.pressed ? vehicleStatusCard._highlightPressedColor : (openClusterMouseArea.containsMouse ? vehicleStatusCard._highlightHoverColor : vehicleStatusCard._highlightColor)
                                                                radius: vehicleStatusCard._controlRadius

                                                                QGCLabel {
                                                                    id: openClusterLabel

                                                                    anchors.centerIn: parent
                                                                    color: vehicleStatusCard._textPrimaryColor
                                                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.56
                                                                    font.weight: Font.DemiBold
                                                                    text: qsTr("完整界面")
                                                                }

                                                                QGCMouseArea {
                                                                    id: openClusterMouseArea

                                                                    anchors.fill: parent
                                                                    hoverEnabled: true

                                                                    onClicked: root._openClusterWorkspaceWindow()
                                                                }
                                                            }
                                                        }

                                                        GridLayout {
                                                            Layout.fillWidth: true
                                                            columnSpacing: ScreenTools.defaultFontPixelWidth * 0.18
                                                            columns: 3
                                                            rowSpacing: ScreenTools.defaultFontPixelHeight * 0.12
                                                            visible: _isClusterPage

                                                            Repeater {
                                                                model: [
                                                                    {
                                                                        "label": qsTr("在线"),
                                                                        "value": QGroundControl.multiVehicleManager.vehicles ? QGroundControl.multiVehicleManager.vehicles.count : 0
                                                                    },
                                                                    {
                                                                        "label": qsTr("已分配"),
                                                                        "value": clusterManager.assignedVehicleCount
                                                                    },
                                                                    {
                                                                        "label": qsTr("领机"),
                                                                        "value": clusterManager.leaderCount
                                                                    }
                                                                ]

                                                                delegate: Rectangle {
                                                                    Layout.fillWidth: true
                                                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.15
                                                                    border.color: vehicleStatusCard._controlBorderColor
                                                                    border.width: vehicleStatusCard._controlBorderWidth
                                                                    color: vehicleStatusCard._blockColor
                                                                    radius: vehicleStatusCard._controlRadius

                                                                    ColumnLayout {
                                                                        anchors.centerIn: parent
                                                                        spacing: ScreenTools.defaultFontPixelHeight * 0.02
                                                                        width: parent.width - ScreenTools.defaultFontPixelWidth * 0.3

                                                                        QGCLabel {
                                                                            Layout.alignment: Qt.AlignHCenter
                                                                            color: vehicleStatusCard._textPrimaryColor
                                                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.78
                                                                            font.weight: Font.DemiBold
                                                                            text: modelData.value
                                                                        }

                                                                        QGCLabel {
                                                                            Layout.alignment: Qt.AlignHCenter
                                                                            color: vehicleStatusCard._textSecondaryColor
                                                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.48
                                                                            text: modelData.label
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                        }

                                                        Rectangle {
                                                            Layout.fillWidth: true
                                                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.52
                                                            border.color: vehicleStatusCard._controlBorderColor
                                                            border.width: vehicleStatusCard._controlBorderWidth
                                                            color: vehicleStatusCard._fieldColor
                                                            radius: vehicleStatusCard._controlRadius
                                                            visible: _isClusterPage

                                                            RowLayout {
                                                                anchors.fill: parent
                                                                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.34
                                                                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.3
                                                                spacing: ScreenTools.defaultFontPixelWidth * 0.18

                                                                QGCLabel {
                                                                    color: vehicleStatusCard._textSecondaryColor
                                                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.54
                                                                    text: qsTr("当前")
                                                                }

                                                                QGCLabel {
                                                                    Layout.fillWidth: true
                                                                    color: vehicleStatusCard._textPrimaryColor
                                                                    elide: Text.ElideRight
                                                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.58
                                                                    font.weight: Font.DemiBold
                                                                    text: root._activeVehicle ? root._clusterVehicleSubtitle(root._activeVehicle) : qsTr("未连接飞行器")
                                                                }
                                                            }
                                                        }

                                                        QGCListView {
                                                            Layout.fillWidth: true
                                                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 7.2
                                                            boundsBehavior: Flickable.StopAtBounds
                                                            clip: true
                                                            model: _isClusterPage ? QGroundControl.multiVehicleManager.vehicles : null
                                                            spacing: ScreenTools.defaultFontPixelHeight * 0.1
                                                            visible: _isClusterPage

                                                            ScrollBar.vertical: ScrollBar {
                                                                policy: ScrollBar.AsNeeded
                                                            }

                                                            delegate: Rectangle {
                                                                required property var object
                                                                readonly property bool _current: object === root._activeVehicle

                                                                width: ListView.view.width
                                                                height: ScreenTools.defaultFontPixelHeight * 1.62
                                                                border.color: _current ? "#5B8FD6" : vehicleStatusCard._controlBorderColor
                                                                border.width: vehicleStatusCard._controlBorderWidth
                                                                color: _current ? Qt.rgba(0.12, 0.22, 0.35, 0.96) : vehicleStatusCard._blockColor
                                                                radius: vehicleStatusCard._controlRadius

                                                                RowLayout {
                                                                    anchors.fill: parent
                                                                    anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.34
                                                                    anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.28
                                                                    spacing: ScreenTools.defaultFontPixelWidth * 0.22

                                                                    Rectangle {
                                                                        Layout.preferredHeight: Layout.preferredWidth
                                                                        Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.46
                                                                        color: clusterManager.vehicleGroup(object.id) >= 0 ? "#65D4A7" : "#7E8792"
                                                                        radius: Layout.preferredWidth * 0.5
                                                                    }

                                                                    QGCLabel {
                                                                        Layout.fillWidth: true
                                                                        color: vehicleStatusCard._textPrimaryColor
                                                                        elide: Text.ElideRight
                                                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.58
                                                                        font.weight: Font.DemiBold
                                                                        text: root._vehicleTitle(object)
                                                                    }

                                                                    QGCLabel {
                                                                        color: vehicleStatusCard._textSecondaryColor
                                                                        elide: Text.ElideRight
                                                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.52
                                                                        text: root._clusterVehicleSubtitle(object)
                                                                    }
                                                                }

                                                                QGCMouseArea {
                                                                    anchors.fill: parent
                                                                    hoverEnabled: true

                                                                    onClicked: root._setActiveVehicle(object)
                                                                }
                                                            }
                                                        }

                                                        GridLayout {
                                                            Layout.fillWidth: true
                                                            columnSpacing: ScreenTools.defaultFontPixelWidth * 0.18
                                                            columns: 2
                                                            rowSpacing: ScreenTools.defaultFontPixelHeight * 0.12
                                                            visible: _isClusterPage

                                                            Repeater {
                                                                model: [
                                                                    {
                                                                        "label": qsTr("暂停本组"),
                                                                        "enabled": clusterManager.activeVehicleGroup >= 0,
                                                                        "action": function () { clusterManager.pauseGroup(clusterManager.activeVehicleGroup); }
                                                                    },
                                                                    {
                                                                        "label": qsTr("继续本组"),
                                                                        "enabled": clusterManager.activeVehicleGroup >= 0,
                                                                        "action": function () { clusterManager.resumeGroup(clusterManager.activeVehicleGroup); }
                                                                    },
                                                                    {
                                                                        "label": qsTr("清除当前"),
                                                                        "enabled": !!root._activeVehicle && clusterManager.activeVehicleGroup >= 0,
                                                                        "action": function () { clusterManager.clearActiveVehicleAssignment(); }
                                                                    },
                                                                    {
                                                                        "label": qsTr("完整界面"),
                                                                        "enabled": true,
                                                                        "action": function () { root._openClusterWorkspaceWindow(); }
                                                                    }
                                                                ]

                                                                delegate: Rectangle {
                                                                    readonly property bool _enabled: modelData.enabled

                                                                    Layout.fillWidth: true
                                                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.58
                                                                    border.color: vehicleStatusCard._controlBorderColor
                                                                    border.width: vehicleStatusCard._controlBorderWidth
                                                                    color: !_enabled ? vehicleStatusCard._buttonSecondaryColor : (clusterActionMouseArea.pressed ? vehicleStatusCard._highlightPressedColor : (clusterActionMouseArea.containsMouse ? vehicleStatusCard._highlightHoverColor : vehicleStatusCard._buttonSecondaryColor))
                                                                    opacity: _enabled ? 1 : 0.45
                                                                    radius: vehicleStatusCard._controlRadius

                                                                    QGCLabel {
                                                                        anchors.centerIn: parent
                                                                        color: vehicleStatusCard._textPrimaryColor
                                                                        elide: Text.ElideRight
                                                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.56
                                                                        font.weight: Font.DemiBold
                                                                        horizontalAlignment: Text.AlignHCenter
                                                                        text: modelData.label
                                                                        width: parent.width - ScreenTools.defaultFontPixelWidth * 0.5
                                                                    }

                                                                    QGCMouseArea {
                                                                        id: clusterActionMouseArea

                                                                        anchors.fill: parent
                                                                        enabled: parent._enabled
                                                                        hoverEnabled: true

                                                                        onClicked: modelData.action()
                                                                    }
                                                                }
                                                            }
                                                        }

                                                        QGCLabel {
                                                            Layout.fillWidth: true
                                                            color: clusterManager.lastCommandSuccess || clusterManager.lastAckSuccess ? "#65D4A7" : vehicleStatusCard._textSecondaryColor
                                                            elide: Text.ElideRight
                                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5
                                                            text: root._clusterLastResultText()
                                                            visible: _isClusterPage
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        Item {
                                            id: clusterQuickPage

                                            clip: true

                                            Flickable {
                                                anchors.fill: parent
                                                boundsBehavior: Flickable.StopAtBounds
                                                clip: true
                                                contentHeight: clusterQuickColumn.implicitHeight
                                                contentWidth: width
                                                flickableDirection: Flickable.VerticalFlick

                                                ScrollBar.vertical: ScrollBar {
                                                    policy: ScrollBar.AsNeeded
                                                }

                                                ColumnLayout {
                                                    id: clusterQuickColumn

                                                    spacing: ScreenTools.defaultFontPixelHeight * 0.18
                                                    width: parent.width

                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        Layout.preferredHeight: vehicleStatusCard._sectionHeaderHeight
                                                        spacing: vehicleStatusCard._sectionHeaderSpacing

                                                        QGCLabel {
                                                            Layout.fillWidth: true
                                                            color: vehicleStatusCard._textPrimaryColor
                                                            font.pixelSize: vehicleStatusCard._sectionHeaderTitleSize
                                                            font.weight: Font.DemiBold
                                                            text: qsTr("集群快捷")
                                                            verticalAlignment: Text.AlignVCenter
                                                        }

                                                        Rectangle {
                                                            Layout.preferredHeight: vehicleStatusCard._sectionHeaderButtonSize
                                                            Layout.preferredWidth: Math.max(clusterOpenLabel.implicitWidth + ScreenTools.defaultFontPixelWidth * 1.0, ScreenTools.defaultFontPixelWidth * 5.8)
                                                            border.color: vehicleStatusCard._controlBorderColor
                                                            border.width: vehicleStatusCard._controlBorderWidth
                                                            color: clusterOpenMouseArea.pressed ? vehicleStatusCard._highlightPressedColor : (clusterOpenMouseArea.containsMouse ? vehicleStatusCard._highlightHoverColor : vehicleStatusCard._highlightColor)
                                                            radius: vehicleStatusCard._controlRadius

                                                            QGCLabel {
                                                                id: clusterOpenLabel

                                                                anchors.centerIn: parent
                                                                color: vehicleStatusCard._textPrimaryColor
                                                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.56
                                                                font.weight: Font.DemiBold
                                                                text: qsTr("完整界面")
                                                            }

                                                            QGCMouseArea {
                                                                id: clusterOpenMouseArea

                                                                anchors.fill: parent
                                                                hoverEnabled: true

                                                                onClicked: root._openClusterWorkspaceWindow()
                                                            }
                                                        }
                                                    }

                                                    GridLayout {
                                                        Layout.fillWidth: true
                                                        columnSpacing: ScreenTools.defaultFontPixelWidth * 0.18
                                                        columns: 3
                                                        rowSpacing: ScreenTools.defaultFontPixelHeight * 0.12

                                                        Repeater {
                                                            model: [
                                                                {
                                                                    "label": qsTr("在线"),
                                                                    "value": QGroundControl.multiVehicleManager.vehicles ? QGroundControl.multiVehicleManager.vehicles.count : 0
                                                                },
                                                                {
                                                                    "label": qsTr("已分配"),
                                                                    "value": clusterManager.assignedVehicleCount
                                                                },
                                                                {
                                                                    "label": qsTr("领机"),
                                                                    "value": clusterManager.leaderCount
                                                                }
                                                            ]

                                                            delegate: Rectangle {
                                                                Layout.fillWidth: true
                                                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.15
                                                                border.color: vehicleStatusCard._controlBorderColor
                                                                border.width: vehicleStatusCard._controlBorderWidth
                                                                color: vehicleStatusCard._blockColor
                                                                radius: vehicleStatusCard._controlRadius

                                                                ColumnLayout {
                                                                    anchors.centerIn: parent
                                                                    spacing: ScreenTools.defaultFontPixelHeight * 0.02
                                                                    width: parent.width - ScreenTools.defaultFontPixelWidth * 0.3

                                                                    QGCLabel {
                                                                        Layout.alignment: Qt.AlignHCenter
                                                                        color: vehicleStatusCard._textPrimaryColor
                                                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.78
                                                                        font.weight: Font.DemiBold
                                                                        text: modelData.value
                                                                    }

                                                                    QGCLabel {
                                                                        Layout.alignment: Qt.AlignHCenter
                                                                        color: vehicleStatusCard._textSecondaryColor
                                                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.48
                                                                        text: modelData.label
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }

                                                    Rectangle {
                                                        Layout.fillWidth: true
                                                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.52
                                                        border.color: vehicleStatusCard._controlBorderColor
                                                        border.width: vehicleStatusCard._controlBorderWidth
                                                        color: vehicleStatusCard._fieldColor
                                                        radius: vehicleStatusCard._controlRadius

                                                        RowLayout {
                                                            anchors.fill: parent
                                                            anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.34
                                                            anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.3
                                                            spacing: ScreenTools.defaultFontPixelWidth * 0.18

                                                            QGCLabel {
                                                                color: vehicleStatusCard._textSecondaryColor
                                                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.54
                                                                text: qsTr("当前")
                                                            }

                                                            QGCLabel {
                                                                Layout.fillWidth: true
                                                                color: vehicleStatusCard._textPrimaryColor
                                                                elide: Text.ElideRight
                                                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.58
                                                                font.weight: Font.DemiBold
                                                                text: root._activeVehicle ? root._clusterVehicleSubtitle(root._activeVehicle) : qsTr("未连接飞行器")
                                                            }
                                                        }
                                                    }

                                                    QGCListView {
                                                        Layout.fillWidth: true
                                                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 7.2
                                                        boundsBehavior: Flickable.StopAtBounds
                                                        clip: true
                                                        model: QGroundControl.multiVehicleManager.vehicles
                                                        spacing: ScreenTools.defaultFontPixelHeight * 0.1

                                                        ScrollBar.vertical: ScrollBar {
                                                            policy: ScrollBar.AsNeeded
                                                        }

                                                        delegate: Rectangle {
                                                            required property var object
                                                            readonly property bool _current: object === root._activeVehicle

                                                            border.color: _current ? "#5B8FD6" : vehicleStatusCard._controlBorderColor
                                                            border.width: vehicleStatusCard._controlBorderWidth
                                                            color: _current ? Qt.rgba(0.12, 0.22, 0.35, 0.96) : vehicleStatusCard._blockColor
                                                            height: ScreenTools.defaultFontPixelHeight * 1.62
                                                            radius: vehicleStatusCard._controlRadius
                                                            width: ListView.view.width

                                                            RowLayout {
                                                                anchors.fill: parent
                                                                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.34
                                                                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.28
                                                                spacing: ScreenTools.defaultFontPixelWidth * 0.22

                                                                Rectangle {
                                                                    Layout.preferredHeight: Layout.preferredWidth
                                                                    Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.46
                                                                    color: clusterManager.vehicleGroup(object.id) >= 0 ? "#65D4A7" : "#7E8792"
                                                                    radius: Layout.preferredWidth * 0.5
                                                                }

                                                                QGCLabel {
                                                                    Layout.fillWidth: true
                                                                    color: vehicleStatusCard._textPrimaryColor
                                                                    elide: Text.ElideRight
                                                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.58
                                                                    font.weight: Font.DemiBold
                                                                    text: root._vehicleTitle(object)
                                                                }

                                                                QGCLabel {
                                                                    color: vehicleStatusCard._textSecondaryColor
                                                                    elide: Text.ElideRight
                                                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.52
                                                                    text: root._clusterVehicleSubtitle(object)
                                                                }
                                                            }

                                                            QGCMouseArea {
                                                                anchors.fill: parent
                                                                hoverEnabled: true

                                                                onClicked: root._setActiveVehicle(object)
                                                            }
                                                        }
                                                    }

                                                    GridLayout {
                                                        Layout.fillWidth: true
                                                        columnSpacing: ScreenTools.defaultFontPixelWidth * 0.18
                                                        columns: 2
                                                        rowSpacing: ScreenTools.defaultFontPixelHeight * 0.12

                                                        Repeater {
                                                            model: [
                                                                {
                                                                    "label": qsTr("暂停本组"),
                                                                    "enabled": clusterManager.activeVehicleGroup >= 0,
                                                                    "action": function () { clusterManager.pauseGroup(clusterManager.activeVehicleGroup); }
                                                                },
                                                                {
                                                                    "label": qsTr("继续本组"),
                                                                    "enabled": clusterManager.activeVehicleGroup >= 0,
                                                                    "action": function () { clusterManager.resumeGroup(clusterManager.activeVehicleGroup); }
                                                                },
                                                                {
                                                                    "label": qsTr("清除当前"),
                                                                    "enabled": !!root._activeVehicle && clusterManager.activeVehicleGroup >= 0,
                                                                    "action": function () { clusterManager.clearActiveVehicleAssignment(); }
                                                                },
                                                                {
                                                                    "label": qsTr("完整界面"),
                                                                    "enabled": true,
                                                                    "action": function () { root._openClusterWorkspaceWindow(); }
                                                                }
                                                            ]

                                                            delegate: Rectangle {
                                                                readonly property bool _enabled: modelData.enabled

                                                                Layout.fillWidth: true
                                                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.58
                                                                border.color: vehicleStatusCard._controlBorderColor
                                                                border.width: vehicleStatusCard._controlBorderWidth
                                                                color: !_enabled ? vehicleStatusCard._buttonSecondaryColor : (quickClusterActionMouseArea.pressed ? vehicleStatusCard._highlightPressedColor : (quickClusterActionMouseArea.containsMouse ? vehicleStatusCard._highlightHoverColor : vehicleStatusCard._buttonSecondaryColor))
                                                                opacity: _enabled ? 1 : 0.45
                                                                radius: vehicleStatusCard._controlRadius

                                                                QGCLabel {
                                                                    anchors.centerIn: parent
                                                                    color: vehicleStatusCard._textPrimaryColor
                                                                    elide: Text.ElideRight
                                                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.56
                                                                    font.weight: Font.DemiBold
                                                                    horizontalAlignment: Text.AlignHCenter
                                                                    text: modelData.label
                                                                    width: parent.width - ScreenTools.defaultFontPixelWidth * 0.5
                                                                }

                                                                QGCMouseArea {
                                                                    id: quickClusterActionMouseArea

                                                                    anchors.fill: parent
                                                                    enabled: parent._enabled
                                                                    hoverEnabled: true

                                                                    onClicked: modelData.action()
                                                                }
                                                            }
                                                        }
                                                    }

                                                    QGCLabel {
                                                        Layout.fillWidth: true
                                                        color: clusterManager.lastCommandSuccess || clusterManager.lastAckSuccess ? "#65D4A7" : vehicleStatusCard._textSecondaryColor
                                                        elide: Text.ElideRight
                                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5
                                                        text: root._clusterLastResultText()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 3.95
                            anchors.right: parent.right
                            anchors.top: parent.top
                            border.color: vehicleStatusCard._controlBorderColor
                            border.width: vehicleStatusCard._controlBorderWidth
                            clip: true
                            color: vehicleStatusCard._contentColor
                            visible: root._vehicleStatusPageIndex === 9
                            z: 100

                            ColumnLayout {
                                anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.44
                                anchors.fill: parent
                                anchors.leftMargin: ScreenTools.defaultFontPixelHeight * 0.46
                                anchors.rightMargin: ScreenTools.defaultFontPixelHeight * 0.46
                                anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.46
                                spacing: ScreenTools.defaultFontPixelHeight * 0.2

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: vehicleStatusCard._sectionHeaderHeight

                                    QGCLabel {
                                        Layout.fillWidth: true
                                        color: vehicleStatusCard._textPrimaryColor
                                        font.pixelSize: vehicleStatusCard._sectionHeaderTitleSize
                                        font.weight: Font.DemiBold
                                        text: qsTr("集群快捷")
                                    }

                                    Rectangle {
                                        Layout.preferredHeight: vehicleStatusCard._sectionHeaderButtonSize
                                        Layout.preferredWidth: Math.max(clusterCardOpenLabel.implicitWidth + ScreenTools.defaultFontPixelWidth * 1.0, ScreenTools.defaultFontPixelWidth * 5.8)
                                        border.color: vehicleStatusCard._controlBorderColor
                                        border.width: vehicleStatusCard._controlBorderWidth
                                        color: clusterCardOpenMouseArea.pressed ? vehicleStatusCard._highlightPressedColor : (clusterCardOpenMouseArea.containsMouse ? vehicleStatusCard._highlightHoverColor : vehicleStatusCard._highlightColor)
                                        radius: vehicleStatusCard._controlRadius

                                        QGCLabel {
                                            id: clusterCardOpenLabel

                                            anchors.centerIn: parent
                                            color: vehicleStatusCard._textPrimaryColor
                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.56
                                            font.weight: Font.DemiBold
                                            text: qsTr("完整界面")
                                        }

                                        QGCMouseArea {
                                            id: clusterCardOpenMouseArea

                                            anchors.fill: parent
                                            hoverEnabled: true

                                            onClicked: root._openClusterWorkspaceWindow()
                                        }
                                    }
                                }

                                GridLayout {
                                    Layout.fillWidth: true
                                    columnSpacing: ScreenTools.defaultFontPixelWidth * 0.18
                                    columns: 3
                                    rowSpacing: ScreenTools.defaultFontPixelHeight * 0.12

                                    Repeater {
                                        model: [
                                            { "label": qsTr("在线"), "value": QGroundControl.multiVehicleManager.vehicles ? QGroundControl.multiVehicleManager.vehicles.count : 0 },
                                            { "label": qsTr("已分配"), "value": clusterManager.assignedVehicleCount },
                                            { "label": qsTr("领机"), "value": clusterManager.leaderCount }
                                        ]

                                        delegate: Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.15
                                            border.color: vehicleStatusCard._controlBorderColor
                                            border.width: vehicleStatusCard._controlBorderWidth
                                            color: vehicleStatusCard._blockColor
                                            radius: vehicleStatusCard._controlRadius

                                            ColumnLayout {
                                                anchors.centerIn: parent
                                                spacing: 0

                                                QGCLabel {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    color: vehicleStatusCard._textPrimaryColor
                                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.78
                                                    font.weight: Font.DemiBold
                                                    text: modelData.value
                                                }

                                                QGCLabel {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    color: vehicleStatusCard._textSecondaryColor
                                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.48
                                                    text: modelData.label
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.52
                                    border.color: vehicleStatusCard._controlBorderColor
                                    border.width: vehicleStatusCard._controlBorderWidth
                                    color: vehicleStatusCard._fieldColor
                                    radius: vehicleStatusCard._controlRadius

                                    QGCLabel {
                                        anchors.fill: parent
                                        anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.34
                                        anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.3
                                        color: vehicleStatusCard._textPrimaryColor
                                        elide: Text.ElideRight
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.58
                                        text: root._activeVehicle ? qsTr("当前：%1").arg(root._clusterVehicleSubtitle(root._activeVehicle)) : qsTr("当前：未连接飞行器")
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }

                                QGCListView {
                                    Layout.fillHeight: true
                                    Layout.fillWidth: true
                                    boundsBehavior: Flickable.StopAtBounds
                                    clip: true
                                    model: QGroundControl.multiVehicleManager.vehicles
                                    spacing: ScreenTools.defaultFontPixelHeight * 0.1

                                    ScrollBar.vertical: ScrollBar {
                                        policy: ScrollBar.AsNeeded
                                    }

                                    delegate: Rectangle {
                                        required property var object
                                        readonly property bool _current: object === root._activeVehicle

                                        border.color: _current ? "#5B8FD6" : vehicleStatusCard._controlBorderColor
                                        border.width: vehicleStatusCard._controlBorderWidth
                                        color: _current ? Qt.rgba(0.12, 0.22, 0.35, 0.96) : vehicleStatusCard._blockColor
                                        height: ScreenTools.defaultFontPixelHeight * 1.62
                                        radius: vehicleStatusCard._controlRadius
                                        width: ListView.view.width

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.34
                                            anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.28
                                            spacing: ScreenTools.defaultFontPixelWidth * 0.22

                                            Rectangle {
                                                Layout.preferredHeight: Layout.preferredWidth
                                                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.46
                                                color: clusterManager.vehicleGroup(object.id) >= 0 ? "#65D4A7" : "#7E8792"
                                                radius: Layout.preferredWidth * 0.5
                                            }

                                            QGCLabel {
                                                Layout.fillWidth: true
                                                color: vehicleStatusCard._textPrimaryColor
                                                elide: Text.ElideRight
                                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.58
                                                font.weight: Font.DemiBold
                                                text: root._vehicleTitle(object)
                                            }

                                            QGCLabel {
                                                color: vehicleStatusCard._textSecondaryColor
                                                elide: Text.ElideRight
                                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.52
                                                text: root._clusterVehicleSubtitle(object)
                                            }
                                        }

                                        QGCMouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true

                                            onClicked: root._setActiveVehicle(object)
                                        }
                                    }
                                }

                                GridLayout {
                                    Layout.fillWidth: true
                                    columnSpacing: ScreenTools.defaultFontPixelWidth * 0.18
                                    columns: 2
                                    rowSpacing: ScreenTools.defaultFontPixelHeight * 0.12

                                    Repeater {
                                        model: [
                                            { "label": qsTr("暂停本组"), "enabled": clusterManager.activeVehicleGroup >= 0, "action": function () { clusterManager.pauseGroup(clusterManager.activeVehicleGroup); } },
                                            { "label": qsTr("继续本组"), "enabled": clusterManager.activeVehicleGroup >= 0, "action": function () { clusterManager.resumeGroup(clusterManager.activeVehicleGroup); } },
                                            { "label": qsTr("清除当前"), "enabled": !!root._activeVehicle && clusterManager.activeVehicleGroup >= 0, "action": function () { clusterManager.clearActiveVehicleAssignment(); } },
                                            { "label": qsTr("完整界面"), "enabled": true, "action": function () { root._openClusterWorkspaceWindow(); } }
                                        ]

                                        delegate: Rectangle {
                                            readonly property bool _enabled: modelData.enabled

                                            Layout.fillWidth: true
                                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.58
                                            border.color: vehicleStatusCard._controlBorderColor
                                            border.width: vehicleStatusCard._controlBorderWidth
                                            color: !_enabled ? vehicleStatusCard._buttonSecondaryColor : (clusterCardActionMouseArea.pressed ? vehicleStatusCard._highlightPressedColor : (clusterCardActionMouseArea.containsMouse ? vehicleStatusCard._highlightHoverColor : vehicleStatusCard._buttonSecondaryColor))
                                            opacity: _enabled ? 1 : 0.45
                                            radius: vehicleStatusCard._controlRadius

                                            QGCLabel {
                                                anchors.centerIn: parent
                                                color: vehicleStatusCard._textPrimaryColor
                                                elide: Text.ElideRight
                                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.56
                                                font.weight: Font.DemiBold
                                                horizontalAlignment: Text.AlignHCenter
                                                text: modelData.label
                                                width: parent.width - ScreenTools.defaultFontPixelWidth * 0.5
                                            }

                                            QGCMouseArea {
                                                id: clusterCardActionMouseArea

                                                anchors.fill: parent
                                                enabled: parent._enabled
                                                hoverEnabled: true

                                                onClicked: modelData.action()
                                            }
                                        }
                                    }
                                }

                                QGCLabel {
                                    Layout.fillWidth: true
                                    color: clusterManager.lastCommandSuccess || clusterManager.lastAckSuccess ? "#65D4A7" : vehicleStatusCard._textSecondaryColor
                                    elide: Text.ElideRight
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5
                                    text: root._clusterLastResultText()
                                }
                            }
                        }
                    }
                }

                Item {
                    id: rightPane

                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    Layout.leftMargin: root._margin

                    Rectangle {
                        id: mapPanel

                        clip: true
                        color: qgcPal.windowShadeDark
                        height: {
                            const parentHeight = Number(parent ? parent.height : 0);
                            const profileHeight = Number(profilePanel.height);
                            const safeParentHeight = isNaN(parentHeight) ? 0 : parentHeight;
                            const safeProfileHeight = isNaN(profileHeight) ? root._profilePanelTargetHeight : profileHeight;
                            return Math.max(0, safeParentHeight - safeProfileHeight - 1);
                        }
                        radius: root._radius
                        width: parent ? parent.width : 0
                        x: 0
                        y: 0

                        FlyViewMap {
                            id: mapView

                            anchors.fill: parent
                            autoFitMissionOnLoad: false
                            autoResumeVehicleTracking: false
                            mapName: "FlyIntegratedMap"
                            pipMode: false
                            planMasterController: planControllerInternal
                            rightPanelWidth: 0
                            showMissionPaths: root._showFlightPath && !root._missionPathSwitchSuppressed
                            toolInsets: toolInsets
                        }

                        Connections {
                            function onMapPanStart() {
                                root._mapNavigationSelection = "pan";
                            }

                            ignoreUnknownSignals: true
                            target: mapView
                        }

                        Item {
                            id: floatingMapStripAnchor

                            anchors.left: parent.left
                            anchors.leftMargin: root._margin
                            height: 1
                            width: 1
                            y: Math.max(root._margin, (parent.height - floatingMapStrip.height) * 0.5)
                        }

                        Rectangle {
                            id: floatingMapStrip

                            readonly property real _buttonHeight: ScreenTools.defaultFontPixelHeight * 2.18
                            readonly property real _buttonSpacing: ScreenTools.defaultFontPixelHeight * 0.12
                            readonly property real _collapsedHeight: (_innerMargin * 2) + _toggleButtonSize + (ScreenTools.defaultFontPixelHeight * 0.38)
                            readonly property real _collapsedWidth: (_innerMargin * 2) + _toggleButtonSize
                            readonly property real _expandedHeight: (_innerMargin * 2) + _toggleButtonSize + _buttonSpacing + stripActionColumn.implicitHeight
                            readonly property real _expandedWidth: ScreenTools.defaultFontPixelHeight * 2.75
                            readonly property real _innerMargin: ScreenTools.defaultFontPixelHeight * 0.16
                            readonly property real _toggleButtonSize: ScreenTools.defaultFontPixelHeight * 1.36

                            anchors.left: floatingMapStripAnchor.left
                            clip: true
                            color: Qt.rgba(0.06, 0.06, 0.07, 0.9)
                            height: root._mapStripExpanded ? Math.min(_expandedHeight, Math.max(0, parent.height - (root._margin * 2))) : _collapsedHeight
                            radius: ScreenTools.defaultFontPixelHeight * 0.18
                            width: root._mapStripExpanded ? _expandedWidth : _collapsedWidth
                            y: floatingMapStripAnchor.y
                            z: QGroundControl.zOrderTopMost + 3

                            Behavior on height {
                                NumberAnimation {
                                    duration: 180
                                    easing.type: Easing.InOutCubic
                                }
                            }
                            Behavior on width {
                                NumberAnimation {
                                    duration: 180
                                    easing.type: Easing.InOutCubic
                                }
                            }

                            ColumnLayout {
                                id: stripButtonColumn

                                anchors.fill: parent
                                anchors.margins: floatingMapStrip._innerMargin
                                spacing: floatingMapStrip._buttonSpacing

                                Rectangle {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredHeight: floatingMapStrip._toggleButtonSize
                                    Layout.preferredWidth: floatingMapStrip._toggleButtonSize
                                    border.color: Qt.rgba(1, 1, 1, 0.12)
                                    border.width: 1
                                    color: stripToggleMouseArea.pressed ? "#1A1C1F" : "#121315"
                                    radius: ScreenTools.defaultFontPixelHeight * 0.18

                                    Text {
                                        anchors.centerIn: parent
                                        color: "#FFFFFF"
                                        font.bold: true
                                        font.pixelSize: parent.height * 0.62
                                        renderType: Text.NativeRendering
                                        text: root._mapStripExpanded ? "<" : ">"
                                    }

                                    QGCMouseArea {
                                        id: stripToggleMouseArea

                                        anchors.fill: parent

                                        onClicked: root._mapStripExpanded = !root._mapStripExpanded
                                    }
                                }

                                Flickable {
                                    id: stripActionFlickable

                                    Layout.fillHeight: true
                                    Layout.fillWidth: true
                                    boundsBehavior: Flickable.StopAtBounds
                                    clip: true
                                    contentHeight: stripActionColumn.implicitHeight
                                    contentWidth: width
                                    interactive: root._mapStripExpanded && contentHeight > height

                                    ScrollBar.vertical: ScrollBar {
                                        policy: stripActionFlickable.contentHeight > stripActionFlickable.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                                        width: ScreenTools.defaultFontPixelWidth * 0.35
                                    }

                                    ColumnLayout {
                                        id: stripActionColumn

                                        spacing: floatingMapStrip._buttonSpacing
                                        width: stripActionFlickable.width

                                        Repeater {
                                            model: [
                                                {
                                                    "key": "traffic",
                                                    "icon": "/InstrumentValueIcons/border-outer.svg",
                                                    "accent": true,
                                                    "requiresVehicle": false,
                                                    "slashed": false
                                                },
                                                {
                                                    "key": "showPath",
                                                    "icon": "/InstrumentValueIcons/view-show.svg",
                                                    "accent": false,
                                                    "requiresVehicle": false,
                                                    "slashed": false
                                                },
                                                {
                                                    "key": "armDisarm",
                                                    "icon": root._activeVehicle && root._activeVehicle.armed ? "/res/LockClosed.svg" : "/res/LockOpen.svg",
                                                    "accent": false,
                                                    "requiresVehicle": true,
                                                    "slashed": false
                                                },
                                                {
                                                    "key": "play",
                                                    "icon": "/InstrumentValueIcons/play-outline.svg",
                                                    "accent": false,
                                                    "requiresVehicle": true,
                                                    "slashed": false,
                                                    "visible": guidedActionsController.showContinueMission
                                                },
                                                {
                                                    "key": "pause",
                                                    "icon": "/InstrumentValueIcons/pause-outline.svg",
                                                    "accent": false,
                                                    "requiresVehicle": true,
                                                    "slashed": false
                                                },
                                                {
                                                    "key": "oneKeyRTL",
                                                    "label": qsTr("一键\n返航"),
                                                    "accent": true,
                                                    "requiresVehicle": true,
                                                    "slashed": false
                                                },
                                                {
                                                    "key": "land",
                                                    "icon": "/res/land.svg",
                                                    "accent": false,
                                                    "requiresVehicle": true,
                                                    "slashed": false
                                                },
                                                {
                                                    "key": "emergencyStop",
                                                    "icon": "/res/Stop.svg",
                                                    "accent": false,
                                                    "requiresVehicle": true,
                                                    "slashed": false
                                                },
                                                {
                                                    "key": "flightMode",
                                                    "icon": "",
                                                    "accent": false,
                                                    "requiresVehicle": true,
                                                    "slashed": false
                                                },
                                                {
                                                    "key": "up",
                                                    "icon": "/InstrumentValueIcons/arrow-base-up.svg",
                                                    "accent": false,
                                                    "requiresVehicle": true,
                                                    "slashed": false
                                                },
                                                {
                                                    "key": "down",
                                                    "icon": "/InstrumentValueIcons/arrow-base-down.svg",
                                                    "accent": false,
                                                    "requiresVehicle": true,
                                                    "slashed": false
                                                },
                                                {
                                                    "key": "locate",
                                                    "icon": "/InstrumentValueIcons/map-follow.svg",
                                                    "accent": false,
                                                    "requiresVehicle": true,
                                                    "slashed": false
                                                }
                                            ]

                                            delegate: Rectangle {
                                                readonly property bool _enabled: !_isSeparator && root._isMapStripActionEnabled(modelData.key, modelData.requiresVehicle)
                                                readonly property bool _isFlightMode: modelData.key === "flightMode"
                                                readonly property bool _isSeparator: modelData.separator === true
                                                readonly property bool _isStartMission: modelData.key === "startMission"
                                                readonly property bool _selected: !_isSeparator && root._isMapStripSelected(modelData.key)
                                                required property var modelData

                                                Layout.fillWidth: true
                                                Layout.preferredHeight: visible ? (_isSeparator ? ScreenTools.defaultFontPixelHeight * 0.42 : (_isStartMission ? floatingMapStrip._buttonHeight * 1.08 : floatingMapStrip._buttonHeight)) : 0
                                                border.color: _isStartMission ? Qt.rgba(1, 1, 1, 0.28) : "transparent"
                                                border.width: _isStartMission ? 2 : 0
                                                color: _isSeparator ? "transparent" : (_selected ? "#2F6FC7" : (_isStartMission ? (stripMouseArea.pressed ? "#9A3412" : "#EA580C") : (_isFlightMode ? (stripMouseArea.pressed ? "#1A1C1F" : "#121315") : (stripMouseArea.pressed ? "#1A1C1F" : "#121315"))))
                                                opacity: root._mapStripExpanded ? (_isSeparator ? 1 : (_enabled ? 1 : 0.42)) : 0
                                                radius: ScreenTools.defaultFontPixelHeight * 0.18
                                                visible: modelData.visible === undefined ? true : !!modelData.visible

                                                Rectangle {
                                                    anchors.centerIn: parent
                                                    color: Qt.rgba(1, 1, 1, 0.18)
                                                    height: 1
                                                    visible: parent._isSeparator
                                                    width: parent.width * 0.58
                                                }

                                                Item {
                                                    anchors.fill: parent
                                                    visible: !parent._isSeparator

                                                    Rectangle {
                                                        anchors.left: parent.left
                                                        anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.14
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        color: "#7FD0FF"
                                                        height: parent.height * 0.62
                                                        opacity: 0.8
                                                        radius: width / 2
                                                        visible: parent.parent._isFlightMode
                                                        width: ScreenTools.defaultFontPixelWidth * 0.22
                                                    }

                                                    QGCColoredImage {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        anchors.verticalCenterOffset: _isStartMission ? -(ScreenTools.defaultFontPixelHeight * 0.18) : 0
                                                        color: _isStartMission ? "#FFF7ED" : "#FFFFFF"
                                                        fillMode: Image.PreserveAspectFit
                                                        height: width
                                                        source: modelData.icon || ""
                                                        visible: !parent.parent._isFlightMode && !modelData.label
                                                        width: parent.height * (_isStartMission ? 0.46 : 0.42)
                                                    }

                                                    QGCLabel {
                                                        anchors.centerIn: parent
                                                        color: "#FFFFFF"
                                                        font.bold: true
                                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.48
                                                        horizontalAlignment: Text.AlignHCenter
                                                        lineHeight: ScreenTools.defaultFontPixelHeight * 0.58
                                                        lineHeightMode: Text.FixedHeight
                                                        maximumLineCount: 2
                                                        text: modelData.label || ""
                                                        verticalAlignment: Text.AlignVCenter
                                                        visible: !parent.parent._isFlightMode && !!modelData.label
                                                        width: parent.width - (ScreenTools.defaultFontPixelWidth * 0.4)
                                                        wrapMode: Text.Wrap
                                                    }

                                                    QGCLabel {
                                                        anchors.centerIn: parent
                                                        color: "#FFFFFF"
                                                        elide: Text.ElideRight
                                                        font.bold: true
                                                        font.pixelSize: Math.max(ScreenTools.defaultFontPixelHeight * 0.36, Math.min(ScreenTools.defaultFontPixelHeight * 0.54, parent.width / Math.max(2.2, text.replace(/\n/g, "").length * 0.56)))
                                                        horizontalAlignment: Text.AlignHCenter
                                                        lineHeight: ScreenTools.defaultFontPixelHeight * 0.62
                                                        lineHeightMode: Text.FixedHeight
                                                        maximumLineCount: 2
                                                        text: root._mapStripFlightModeText()
                                                        verticalAlignment: Text.AlignVCenter
                                                        visible: parent.parent._isFlightMode
                                                        width: parent.width - (ScreenTools.defaultFontPixelWidth * 0.7)
                                                        wrapMode: Text.Wrap
                                                    }

                                                    QGCLabel {
                                                        anchors.bottom: parent.bottom
                                                        anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.12
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        color: "#FFF7ED"
                                                        font.bold: true
                                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.42
                                                        text: qsTr("开始")
                                                        visible: _isStartMission
                                                    }

                                                    Rectangle {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        anchors.top: parent.top
                                                        anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.12
                                                        color: Qt.rgba(1, 1, 1, 0.28)
                                                        height: ScreenTools.defaultFontPixelHeight * 0.1
                                                        radius: height / 2
                                                        visible: _isStartMission
                                                        width: parent.width * 0.52
                                                    }

                                                    Rectangle {
                                                        anchors.centerIn: parent
                                                        color: "#FFFFFF"
                                                        height: ScreenTools.defaultFontPixelHeight * 0.1
                                                        radius: height / 2
                                                        rotation: -32
                                                        visible: modelData.slashed
                                                        width: parent.height * 0.52
                                                    }
                                                }

                                                QGCMouseArea {
                                                    id: stripMouseArea

                                                    anchors.fill: parent
                                                    enabled: root._mapStripExpanded && !parent._isSeparator

                                                    onClicked: {
                                                        if (parent._enabled) {
                                                            root._triggerMapStripAction(modelData.key, parent);
                                                        } else {
                                                            root._showMapStripUnavailable(modelData.key, modelData.requiresVehicle);
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: vehicleAlertBanner

                            border.color: Qt.rgba(1, 1, 1, 0.18)
                            border.width: 1
                            color: root._vehicleAlertColor()
                            height: ScreenTools.defaultFontPixelHeight * 1.9
                            opacity: 0.96
                            radius: ScreenTools.defaultFontPixelHeight * 0.18
                            visible: root._vehicleAlertLevel() > 0
                            width: Math.min(ScreenTools.defaultFontPixelWidth * 38, Math.max(ScreenTools.defaultFontPixelWidth * 18, parent.width - x - (root._margin * 1.2)))
                            x: floatingMapStrip.x + floatingMapStrip.width + (root._margin * 0.7)
                            y: root._margin
                            z: QGroundControl.zOrderTopMost + 4

                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.top: parent.top
                                color: root._vehicleAlertAccentColor()
                                radius: vehicleAlertBanner.radius
                                width: ScreenTools.defaultFontPixelWidth * 0.28
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.9
                                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.75
                                spacing: ScreenTools.defaultFontPixelWidth * 0.55

                                QGCColoredImage {
                                    Layout.preferredHeight: Layout.preferredWidth
                                    Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.9
                                    color: root._vehicleAlertAccentColor()
                                    fillMode: Image.PreserveAspectFit
                                    source: "/res/VehicleMessages.png"
                                    sourceSize.width: width
                                }

                                QGCLabel {
                                    Layout.fillHeight: true
                                    Layout.fillWidth: true
                                    color: "#FFFFFF"
                                    elide: Text.ElideRight
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.62
                                    font.weight: root._vehicleAlertLevel() >= 2 ? Font.DemiBold : Font.Normal
                                    maximumLineCount: 1
                                    text: root._vehicleAlertText()
                                    verticalAlignment: Text.AlignVCenter
                                }

                                QGCLabel {
                                    color: Qt.rgba(1, 1, 1, 0.78)
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.52
                                    text: root._activeVehicle ? qsTr("%1 条").arg(root._activeVehicle.messageCount) : ""
                                    verticalAlignment: Text.AlignVCenter
                                    visible: root._activeVehicle && root._activeVehicle.messageCount > 1
                                }
                            }

                            QGCMouseArea {
                                cursorShape: Qt.PointingHandCursor
                                fillItem: parent

                                onClicked: root._openVehicleMessages(vehicleAlertBanner)
                            }
                        }

                        Rectangle {
                            id: floatingMapStripToggleHandle

                            anchors.left: floatingMapStrip.right
                            anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.15
                            anchors.verticalCenter: floatingMapStrip.verticalCenter
                            border.color: Qt.rgba(1, 1, 1, 0.14)
                            border.width: 1
                            color: Qt.rgba(0.08, 0.08, 0.09, 0.95)
                            height: ScreenTools.defaultFontPixelHeight * 1.9
                            radius: width * 0.45
                            width: ScreenTools.defaultFontPixelHeight * 1.05
                            z: QGroundControl.zOrderTopMost + 4

                            Text {
                                anchors.centerIn: parent
                                color: "#FFFFFF"
                                font.bold: true
                                font.pixelSize: parent.width * 0.78
                                renderType: Text.NativeRendering
                                text: root._mapStripExpanded ? "<" : ">"
                            }

                            QGCMouseArea {
                                anchors.fill: parent

                                onClicked: root._mapStripExpanded = !root._mapStripExpanded
                            }
                        }

                        Rectangle {
                            id: compactReadinessPanel

                            border.color: Qt.rgba(1, 1, 1, 0.08)
                            border.width: 1
                            color: Qt.rgba(0.08, 0.08, 0.09, 0.93)
                            height: readinessContent.implicitHeight + (ScreenTools.defaultFontPixelHeight * 0.6)
                            radius: ScreenTools.defaultFontPixelHeight * 0.16
                            width: Math.min(ScreenTools.defaultFontPixelWidth * 28, Math.max(ScreenTools.defaultFontPixelWidth * 18, parent.width * 0.34))
                            x: floatingMapStripToggleHandle.x + floatingMapStripToggleHandle.width + (root._margin * 0.7)
                            y: parent.height - height - root._margin
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
                                        Layout.preferredHeight: Layout.preferredWidth
                                        Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.42
                                        color: root._compactReadinessColor(root._activeVehicle)
                                        radius: Layout.preferredWidth * 0.5
                                    }

                                    QGCLabel {
                                        color: "#D7DBDF"
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5
                                        text: qsTr("状态")
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
                                    elide: Text.ElideRight
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.56
                                    font.weight: Font.DemiBold
                                    text: root._compactPrearmReason(root._activeVehicle)
                                }
                            }
                        }

                        Rectangle {
                            id: trafficViewPanel

                            property var _adsbModel: QGroundControl.adsbVehicleManager ? QGroundControl.adsbVehicleManager.adsbVehicles : null
                            readonly property real _headerHeight: ScreenTools.defaultFontPixelHeight * 1.26
                            readonly property real _plotBottom: ScreenTools.defaultFontPixelHeight * 0.72
                            readonly property real _plotHeight: Math.max(height - _plotTop - _plotBottom, 1)
                            readonly property real _plotLeft: ScreenTools.defaultFontPixelWidth * 1.2
                            readonly property real _plotRight: ScreenTools.defaultFontPixelWidth * 0.75
                            readonly property real _plotTop: _headerHeight + (ScreenTools.defaultFontPixelHeight * 0.14)
                            readonly property real _plotWidth: Math.max(width - _plotLeft - _plotRight, 1)
                            property var _referenceCoordinate: null
                            property real displayRangeMeters: 2000
                            property int trafficCount: 0

                            function refresh() {
                                const adsbModel = _adsbModel;
                                const referenceCoordinate = root._vehicleHasPosition(root._activeVehicle) ? root._activeVehicle.coordinate : null;
                                let farthestDistance = 0;
                                let validTrafficCount = 0;

                                _referenceCoordinate = referenceCoordinate;

                                if (adsbModel) {
                                    for (let i = 0; i < adsbModel.count; i++) {
                                        const trafficVehicle = adsbModel.get(i);
                                        if (!trafficVehicle || !trafficVehicle.coordinate || !trafficVehicle.coordinate.isValid) {
                                            continue;
                                        }
                                        validTrafficCount++;
                                        if (referenceCoordinate) {
                                            farthestDistance = Math.max(farthestDistance, referenceCoordinate.distanceTo(trafficVehicle.coordinate));
                                        }
                                    }
                                }

                                trafficCount = validTrafficCount;
                                displayRangeMeters = root._trafficRangeStep(Math.max(farthestDistance * 1.15, 800));
                                trafficGrid.requestPaint();
                            }

                            function relativeTrafficPoint(trafficVehicle) {
                                if (!_referenceCoordinate || !trafficVehicle || !trafficVehicle.coordinate || !trafficVehicle.coordinate.isValid) {
                                    return {
                                        "valid": false,
                                        "x": 0,
                                        "y": 0,
                                        "distance": NaN
                                    };
                                }

                                const distance = _referenceCoordinate.distanceTo(trafficVehicle.coordinate);
                                const azimuthRadians = _referenceCoordinate.azimuthTo(trafficVehicle.coordinate) * Math.PI / 180;
                                const eastOffset = Math.sin(azimuthRadians) * distance;
                                const northOffset = Math.cos(azimuthRadians) * distance;
                                const xRatio = Math.max(-1, Math.min(1, eastOffset / Math.max(displayRangeMeters, 1)));
                                const yRatio = Math.max(-1, Math.min(1, northOffset / Math.max(displayRangeMeters, 1)));

                                return {
                                    "valid": true,
                                    "x": _plotLeft + (_plotWidth * 0.5) + (xRatio * _plotWidth * 0.5),
                                    "y": _plotTop + (_plotHeight * 0.5) - (yRatio * _plotHeight * 0.5),
                                    "distance": distance
                                };
                            }

                            function trafficColor(trafficVehicle, trafficPoint) {
                                if (trafficVehicle && trafficVehicle.alert) {
                                    return "#FF6B55";
                                }
                                if (trafficPoint.valid && trafficPoint.distance <= Math.max(displayRangeMeters * 0.35, 450)) {
                                    return "#D98C4D";
                                }
                                return "#89E0B5";
                            }

                            anchors.left: floatingMapStrip.right
                            anchors.leftMargin: root._margin * 0.9
                            anchors.top: floatingMapStripAnchor.top
                            border.color: Qt.rgba(1, 1, 1, 0.05)
                            border.width: 1
                            clip: true
                            color: Qt.rgba(0.07, 0.07, 0.08, 0.95)
                            height: width * 0.75
                            radius: ScreenTools.defaultFontPixelHeight * 0.18
                            visible: root._trafficViewVisible
                            width: root._compactVideoOverlayWidth(parent.width) * 0.86
                            z: QGroundControl.zOrderWidgets

                            onDisplayRangeMetersChanged: trafficGrid.requestPaint()
                            onHeightChanged: trafficGrid.requestPaint()
                            onVisibleChanged: {
                                if (visible) {
                                    refresh();
                                }
                            }
                            onWidthChanged: trafficGrid.requestPaint()

                            Timer {
                                interval: 700
                                repeat: true
                                running: trafficViewPanel.visible
                                triggeredOnStart: true

                                onTriggered: trafficViewPanel.refresh()
                            }

                            Connections {
                                function onCountChanged() {
                                    trafficViewPanel.refresh();
                                }

                                ignoreUnknownSignals: true
                                target: trafficViewPanel._adsbModel
                            }

                            MouseArea {
                                acceptedButtons: Qt.AllButtons
                                anchors.fill: parent
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                color: Qt.rgba(0.10, 0.10, 0.11, 0.98)
                                height: trafficViewPanel._headerHeight

                                QGCLabel {
                                    anchors.left: parent.left
                                    anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.72
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: "#E8E8E8"
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.62
                                    font.weight: Font.DemiBold
                                    text: qsTr("交通视图")
                                }

                                QGCLabel {
                                    anchors.right: parent.right
                                    anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.68
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: "#5FB5FF"
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.46
                                    text: trafficViewPanel.trafficCount > 0 ? qsTr("实时 %1").arg(trafficViewPanel.trafficCount) : qsTr("实时")
                                }
                            }

                            Canvas {
                                id: trafficGrid

                                anchors.fill: parent

                                onPaint: {
                                    const ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);

                                    const left = trafficViewPanel._plotLeft;
                                    const top = trafficViewPanel._plotTop;
                                    const plotWidth = trafficViewPanel._plotWidth;
                                    const plotHeight = trafficViewPanel._plotHeight;

                                    ctx.strokeStyle = "rgba(255,255,255,0.05)";
                                    ctx.lineWidth = 1;

                                    for (let i = 0; i <= 5; i++) {
                                        const x = left + ((plotWidth * i) / 5);
                                        ctx.beginPath();
                                        ctx.moveTo(x, top);
                                        ctx.lineTo(x, top + plotHeight);
                                        ctx.stroke();
                                    }

                                    for (let i = 0; i <= 4; i++) {
                                        const y = top + ((plotHeight * i) / 4);
                                        ctx.beginPath();
                                        ctx.moveTo(left, y);
                                        ctx.lineTo(left + plotWidth, y);
                                        ctx.stroke();
                                    }
                                }
                            }

                            Rectangle {
                                color: "#49A7FF"
                                height: width
                                opacity: trafficViewPanel._referenceCoordinate ? 0.85 : 0
                                radius: width / 2
                                width: ScreenTools.defaultFontPixelHeight * 0.36
                                x: trafficViewPanel._plotLeft + (trafficViewPanel._plotWidth * 0.5) - (width * 0.5)
                                y: trafficViewPanel._plotTop + (trafficViewPanel._plotHeight * 0.5) - (height * 0.5)
                            }

                            Repeater {
                                model: trafficViewPanel._adsbModel

                                delegate: Item {
                                    required property var object
                                    readonly property color pointColor: trafficViewPanel.trafficColor(object, trafficPoint)
                                    readonly property var trafficPoint: trafficViewPanel.relativeTrafficPoint(object)

                                    height: width
                                    visible: trafficPoint.valid
                                    width: ScreenTools.defaultFontPixelHeight * 0.56
                                    x: trafficPoint.x - (width * 0.5)
                                    y: trafficPoint.y - (height * 0.5)

                                    Rectangle {
                                        anchors.fill: parent
                                        border.color: Qt.lighter(pointColor, 1.25)
                                        border.width: 1
                                        color: pointColor
                                        radius: width / 2
                                    }
                                }
                            }

                            QGCLabel {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.18
                                anchors.left: parent.left
                                anchors.leftMargin: trafficViewPanel._plotLeft
                                color: "#7C8794"
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.46
                                text: qsTr("范围 %1 km").arg((trafficViewPanel.displayRangeMeters / 1000).toFixed(1))
                            }

                            QGCLabel {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: ScreenTools.defaultFontPixelHeight * 0.18
                                color: "#9CA3AF"
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.64
                                horizontalAlignment: Text.AlignHCenter
                                text: trafficViewPanel.trafficCount === 0 ? qsTr("等待实时交通数据") : qsTr("已检测到交通目标，等待飞行器位置")
                                visible: trafficViewPanel.trafficCount === 0 || !trafficViewPanel._referenceCoordinate
                                width: trafficViewPanel.width * 0.68
                                wrapMode: Text.WordWrap
                            }
                        }

                        Rectangle {
                            id: instrumentPanel

                            property var _activeBattery: root._activeBatteryForVehicle(_vehicle)
                            readonly property real _cardMargin: ScreenTools.defaultFontPixelHeight * 0.26 * _layoutScale
                            readonly property real _columnSpacing: ScreenTools.defaultFontPixelWidth * 0.24 * _layoutScale
                            readonly property real _dialTitleSpacing: ScreenTools.defaultFontPixelHeight * 0.05 * _layoutScale
                            readonly property real _dialTopPull: ScreenTools.defaultFontPixelHeight * 0.12 * _layoutScale
                            readonly property real _dialValueFontSize: Math.max(10, Math.min(ScreenTools.defaultFontPixelHeight * 0.96, width * 0.052))
                            readonly property real _headerFontSize: Math.max(10, Math.min(ScreenTools.defaultFontPixelHeight * 0.72, width * 0.04))
                            readonly property real _labelFontSize: Math.max(9, Math.min(ScreenTools.defaultFontPixelHeight * 0.68, width * 0.038))
                            readonly property real _layoutScale: Math.max(0.78, Math.min(1.04, Math.min(width / (ScreenTools.defaultFontPixelWidth * 56), height / (ScreenTools.defaultFontPixelHeight * 31))))
                            readonly property real _panelMargin: ScreenTools.defaultFontPixelHeight * 0.34 * _layoutScale
                            readonly property real _rowSpacing: ScreenTools.defaultFontPixelHeight * 0.24 * _layoutScale
                            readonly property real _valueFontSize: Math.max(10, Math.min(ScreenTools.defaultFontPixelHeight * 0.74, width * 0.044))
                            property var _vehicle: root._activeVehicle
                            property var airSpeedFact: _vehicle ? _vehicle.airSpeed : null
                            readonly property real airSpeedNeedleRotation: Math.max(-125, Math.min(125, (airSpeedValue / 20) * 250 - 125))
                            readonly property real airSpeedValue: hasAirspeed ? Math.max(0, Number(airSpeedFact.rawValue)) : 0
                            property var altitudeFact: _vehicle ? _vehicle.altitudeRelative : null
                            property var batteryFact: _activeBattery ? _activeBattery.percentRemaining : null
                            readonly property real climbRate: hasClimbRate ? Number(climbRateFact.rawValue) : 0
                            property var climbRateFact: _vehicle ? _vehicle.climbRate : null
                            property var flightTimeFact: _vehicle ? _vehicle.getFact("flightTime") : null
                            property var gpsFactGroup: _vehicle ? _vehicle.gps : null
                            property var gpsHdopFact: gpsFactGroup ? gpsFactGroup.hdop : null
                            property var gpsSatelliteFact: gpsFactGroup ? gpsFactGroup.count : null
                            property var gpsVdopFact: gpsFactGroup ? gpsFactGroup.vdop : null
                            readonly property bool hasAirspeed: root._hasFactValue(airSpeedFact)
                            readonly property bool hasClimbRate: root._hasFactValue(climbRateFact)
                            property var headingFact: _vehicle ? _vehicle.heading : null
                            property var pitchFact: _vehicle ? _vehicle.pitch : null
                            property var rollFact: _vehicle ? _vehicle.roll : null
                            readonly property real verticalNeedleRotation: Math.max(-120, Math.min(120, climbRate * 35))

                            anchors.left: floatingMapStrip.right
                            anchors.leftMargin: root._margin * 0.9
                            anchors.top: floatingMapStripAnchor.top
                            border.color: Qt.rgba(1, 1, 1, 0.08)
                            border.width: 1
                            clip: true
                            color: Qt.rgba(0.12, 0.12, 0.13, 0.96)
                            height: Math.min(parent.height - (root._margin * 2), ScreenTools.defaultFontPixelHeight * 31)
                            radius: ScreenTools.defaultFontPixelHeight * 0.18
                            visible: root._instrumentPanelVisible
                            width: Math.min(Math.max(ScreenTools.defaultFontPixelWidth * 32, parent.width * 0.42), Math.min(ScreenTools.defaultFontPixelWidth * 56, Math.max(ScreenTools.defaultFontPixelWidth * 24, parent.width - floatingMapStrip.width - (root._margin * 2.4))))
                            z: QGroundControl.zOrderWidgets

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: instrumentPanel._panelMargin
                                spacing: instrumentPanel._rowSpacing

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.35

                                    QGCLabel {
                                        color: "#ECECEC"
                                        elide: Text.ElideRight
                                        font.pixelSize: instrumentPanel._headerFontSize
                                        font.weight: Font.DemiBold
                                        text: qsTr("仪表")
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    QGCColoredImage {
                                        Layout.preferredHeight: Layout.preferredWidth
                                        Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.72
                                        color: "#C8C9CB"
                                        fillMode: Image.PreserveAspectFit
                                        source: "/InstrumentValueIcons/cog.svg"
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.5
                                    spacing: instrumentPanel._columnSpacing

                                    Rectangle {
                                        Layout.fillHeight: true
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        color: Qt.rgba(1, 1, 1, 0.06)
                                        radius: ScreenTools.defaultFontPixelHeight * 0.08

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: instrumentPanel._cardMargin
                                            spacing: instrumentPanel._columnSpacing * 0.9

                                            QGCLabel {
                                                Layout.fillWidth: true
                                                Layout.minimumWidth: 0
                                                color: "#D8D9DA"
                                                elide: Text.ElideRight
                                                font.pixelSize: instrumentPanel._labelFontSize
                                                text: qsTr("飞行时间")
                                            }

                                            QGCLabel {
                                                color: "#EFEFEF"
                                                font.pixelSize: instrumentPanel._valueFontSize
                                                font.weight: Font.DemiBold
                                                horizontalAlignment: Text.AlignRight
                                                text: root._formatElapsedTime(instrumentPanel.flightTimeFact)
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillHeight: true
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        color: Qt.rgba(1, 1, 1, 0.06)
                                        radius: ScreenTools.defaultFontPixelHeight * 0.08

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: instrumentPanel._cardMargin
                                            spacing: instrumentPanel._columnSpacing * 0.75

                                            QGCLabel {
                                                Layout.fillWidth: true
                                                Layout.minimumWidth: 0
                                                color: "#D8D9DA"
                                                elide: Text.ElideRight
                                                font.pixelSize: instrumentPanel._labelFontSize
                                                text: qsTr("电池")
                                            }

                                            QGCColoredImage {
                                                Layout.preferredHeight: Layout.preferredWidth
                                                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.66
                                                color: root._hasFactValue(instrumentPanel.batteryFact) ? (Number(instrumentPanel.batteryFact.rawValue) <= 20 ? "#E35F63" : (Number(instrumentPanel.batteryFact.rawValue) <= 40 ? "#D0B34D" : "#2DC46D")) : "#A5A8AC"
                                                fillMode: Image.PreserveAspectFit
                                                source: root._batteryIcon(root._batteryPercentForVehicle(instrumentPanel._vehicle))
                                            }

                                            QGCLabel {
                                                color: root._hasFactValue(instrumentPanel.batteryFact) ? (Number(instrumentPanel.batteryFact.rawValue) <= 20 ? "#E35F63" : (Number(instrumentPanel.batteryFact.rawValue) <= 40 ? "#D0B34D" : "#2DC46D")) : "#E0E0E0"
                                                font.pixelSize: instrumentPanel._valueFontSize
                                                font.weight: Font.DemiBold
                                                horizontalAlignment: Text.AlignRight
                                                text: root._formatFactValue(instrumentPanel.batteryFact, true, "--")
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillHeight: true
                                    Layout.fillWidth: true
                                    spacing: instrumentPanel._columnSpacing

                                    Rectangle {
                                        Layout.fillHeight: true
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        color: Qt.rgba(1, 1, 1, 0.06)
                                        radius: ScreenTools.defaultFontPixelHeight * 0.08

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: instrumentPanel._cardMargin
                                            spacing: instrumentPanel._dialTitleSpacing

                                            QGCLabel {
                                                Layout.fillWidth: true
                                                Layout.minimumWidth: 0
                                                color: "#D8D9DA"
                                                elide: Text.ElideRight
                                                font.pixelSize: instrumentPanel._labelFontSize
                                                text: qsTr("姿态")
                                            }

                                            Item {
                                                Layout.fillHeight: true
                                                Layout.fillWidth: true
                                                Layout.topMargin: -instrumentPanel._dialTopPull

                                                Item {
                                                    anchors.bottom: attitudeValuesRow.top
                                                    anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.04
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    anchors.top: parent.top

                                                    QGCAttitudeWidget {
                                                        anchors.centerIn: parent
                                                        size: Math.min(parent.width, parent.height) * 0.88
                                                        vehicle: instrumentPanel._vehicle
                                                    }
                                                }

                                                RowLayout {
                                                    id: attitudeValuesRow

                                                    anchors.bottom: parent.bottom
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    height: ScreenTools.defaultFontPixelHeight * 1.15
                                                    spacing: instrumentPanel._columnSpacing * 0.6

                                                    QGCLabel {
                                                        Layout.fillWidth: true
                                                        Layout.minimumWidth: 0
                                                        color: "#F1F1F1"
                                                        font.pixelSize: instrumentPanel._dialValueFontSize * 0.64
                                                        fontSizeMode: Text.Fit
                                                        horizontalAlignment: Text.AlignHCenter
                                                        minimumPixelSize: 8
                                                        text: qsTr("滚转 %1").arg(root._hasFactValue(instrumentPanel.rollFact) ? (Number(instrumentPanel.rollFact.rawValue).toFixed(1) + "\u00B0") : "--")
                                                        verticalAlignment: Text.AlignVCenter
                                                    }

                                                    QGCLabel {
                                                        Layout.fillWidth: true
                                                        Layout.minimumWidth: 0
                                                        color: "#F1F1F1"
                                                        font.pixelSize: instrumentPanel._dialValueFontSize * 0.64
                                                        fontSizeMode: Text.Fit
                                                        horizontalAlignment: Text.AlignHCenter
                                                        minimumPixelSize: 8
                                                        text: qsTr("俯仰 %1").arg(root._hasFactValue(instrumentPanel.pitchFact) ? (Number(instrumentPanel.pitchFact.rawValue).toFixed(1) + "\u00B0") : "--")
                                                        verticalAlignment: Text.AlignVCenter
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillHeight: true
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        color: Qt.rgba(1, 1, 1, 0.06)
                                        radius: ScreenTools.defaultFontPixelHeight * 0.08

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: instrumentPanel._cardMargin
                                            spacing: instrumentPanel._dialTitleSpacing

                                            QGCLabel {
                                                Layout.fillWidth: true
                                                Layout.minimumWidth: 0
                                                color: "#D8D9DA"
                                                elide: Text.ElideRight
                                                font.pixelSize: instrumentPanel._labelFontSize
                                                text: qsTr("航向")
                                            }

                                            Item {
                                                Layout.fillHeight: true
                                                Layout.fillWidth: true
                                                Layout.topMargin: -instrumentPanel._dialTopPull

                                                Item {
                                                    anchors.bottom: integratedHeadingValueLabel.top
                                                    anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.08
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    anchors.top: parent.top

                                                    QGCCompassWidget {
                                                        anchors.centerIn: parent
                                                        showHeadingText: false
                                                        size: Math.min(parent.width, parent.height) * 0.84
                                                        vehicle: instrumentPanel._vehicle
                                                    }
                                                }

                                                QGCLabel {
                                                    id: integratedHeadingValueLabel

                                                    anchors.bottom: parent.bottom
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    color: "#F1F1F1"
                                                    font.pixelSize: instrumentPanel._dialValueFontSize * 0.82
                                                    font.weight: Font.DemiBold
                                                    fontSizeMode: Text.Fit
                                                    height: ScreenTools.defaultFontPixelHeight * 1.05
                                                    horizontalAlignment: Text.AlignHCenter
                                                    minimumPixelSize: 8
                                                    text: root._hasFactValue(instrumentPanel.headingFact) ? (Number(instrumentPanel.headingFact.rawValue).toFixed(0) + "\u00B0") : "--"
                                                    verticalAlignment: Text.AlignVCenter
                                                    width: parent.width
                                                }
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillHeight: true
                                    Layout.fillWidth: true
                                    spacing: instrumentPanel._columnSpacing

                                    Rectangle {
                                        Layout.fillHeight: true
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        color: Qt.rgba(1, 1, 1, 0.06)
                                        radius: ScreenTools.defaultFontPixelHeight * 0.08

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: instrumentPanel._cardMargin
                                            spacing: instrumentPanel._dialTitleSpacing

                                            QGCLabel {
                                                Layout.fillWidth: true
                                                Layout.minimumWidth: 0
                                                color: "#D8D9DA"
                                                elide: Text.ElideRight
                                                font.pixelSize: instrumentPanel._labelFontSize
                                                text: qsTr("高度")
                                            }

                                            Item {
                                                Layout.fillHeight: true
                                                Layout.fillWidth: true
                                                Layout.topMargin: -instrumentPanel._dialTopPull

                                                Rectangle {
                                                    id: altitudeDial

                                                    anchors.centerIn: parent
                                                    border.color: Qt.rgba(0.88, 0.88, 0.88, 0.88)
                                                    border.width: 2
                                                    color: Qt.rgba(0, 0, 0, 0.06)
                                                    height: width
                                                    radius: width / 2
                                                    width: Math.min(parent.width, parent.height) * 0.86
                                                }

                                                QGCLabel {
                                                    anchors.centerIn: altitudeDial
                                                    color: "#F1F1F1"
                                                    font.pixelSize: instrumentPanel._dialValueFontSize
                                                    font.weight: Font.DemiBold
                                                    fontSizeMode: Text.Fit
                                                    height: altitudeDial.height * 0.32
                                                    horizontalAlignment: Text.AlignHCenter
                                                    minimumPixelSize: 8
                                                    text: root._formatFactValue(instrumentPanel.altitudeFact, true, "--")
                                                    verticalAlignment: Text.AlignVCenter
                                                    width: altitudeDial.width * 0.78
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillHeight: true
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        color: Qt.rgba(1, 1, 1, 0.06)
                                        radius: ScreenTools.defaultFontPixelHeight * 0.08

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: instrumentPanel._cardMargin
                                            spacing: instrumentPanel._dialTitleSpacing

                                            QGCLabel {
                                                Layout.fillWidth: true
                                                Layout.minimumWidth: 0
                                                color: "#D8D9DA"
                                                elide: Text.ElideRight
                                                font.pixelSize: instrumentPanel._labelFontSize
                                                text: qsTr("空速")
                                            }

                                            Item {
                                                Layout.fillHeight: true
                                                Layout.fillWidth: true
                                                Layout.topMargin: -instrumentPanel._dialTopPull

                                                Rectangle {
                                                    id: airSpeedDial

                                                    anchors.centerIn: parent
                                                    border.color: Qt.rgba(0.88, 0.88, 0.88, 0.88)
                                                    border.width: 2
                                                    color: Qt.rgba(0, 0, 0, 0.06)
                                                    height: width
                                                    radius: width / 2
                                                    width: Math.min(parent.width, parent.height) * 0.86
                                                }

                                                Canvas {
                                                    id: airSpeedArc

                                                    anchors.fill: airSpeedDial

                                                    onHeightChanged: requestPaint()
                                                    onPaint: {
                                                        const ctx = getContext("2d");
                                                        const radius = width * 0.44;
                                                        const cx = width * 0.5;
                                                        const cy = height * 0.5;
                                                        ctx.clearRect(0, 0, width, height);
                                                        ctx.lineWidth = Math.max(2, width * 0.035);
                                                        ctx.lineCap = "round";

                                                        const drawArc = (startDeg, endDeg, color) => {
                                                            ctx.beginPath();
                                                            ctx.strokeStyle = color;
                                                            ctx.arc(cx, cy, radius, (startDeg - 90) * Math.PI / 180, (endDeg - 90) * Math.PI / 180, false);
                                                            ctx.stroke();
                                                        };

                                                        drawArc(210, 250, "#D1465C");
                                                        drawArc(250, 285, "#D1B63A");
                                                        drawArc(285, 355, "#4CAF50");
                                                    }
                                                    onWidthChanged: requestPaint()
                                                }

                                                Rectangle {
                                                    color: "#E7E7E7"
                                                    height: Math.max(2, ScreenTools.defaultFontPixelWidth / 3)
                                                    radius: height / 2
                                                    rotation: instrumentPanel.airSpeedNeedleRotation
                                                    transformOrigin: Item.Left
                                                    width: airSpeedDial.width * 0.33
                                                    x: airSpeedDial.x + (airSpeedDial.width / 2)
                                                    y: airSpeedDial.y + ((airSpeedDial.height - height) / 2)
                                                }

                                                Rectangle {
                                                    anchors.centerIn: airSpeedDial
                                                    color: "#E7E7E7"
                                                    height: width
                                                    radius: width / 2
                                                    width: ScreenTools.defaultFontPixelWidth
                                                }

                                                QGCLabel {
                                                    anchors.centerIn: airSpeedDial
                                                    color: "#F1F1F1"
                                                    font.pixelSize: instrumentPanel._dialValueFontSize
                                                    font.weight: Font.DemiBold
                                                    fontSizeMode: Text.Fit
                                                    height: airSpeedDial.height * 0.3
                                                    horizontalAlignment: Text.AlignHCenter
                                                    minimumPixelSize: 8
                                                    text: root._formatFactValue(instrumentPanel.airSpeedFact, true, "--")
                                                    verticalAlignment: Text.AlignVCenter
                                                    width: airSpeedDial.width * 0.76
                                                }
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillHeight: true
                                    Layout.fillWidth: true
                                    spacing: instrumentPanel._columnSpacing

                                    Rectangle {
                                        id: gpsStatusCard

                                        Layout.fillHeight: true
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        color: Qt.rgba(1, 1, 1, 0.06)
                                        radius: ScreenTools.defaultFontPixelHeight * 0.08

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: instrumentPanel._cardMargin
                                            spacing: instrumentPanel._dialTitleSpacing

                                            QGCLabel {
                                                Layout.fillWidth: true
                                                Layout.minimumWidth: 0
                                                color: "#D8D9DA"
                                                elide: Text.ElideRight
                                                font.pixelSize: instrumentPanel._labelFontSize
                                                text: qsTr("GPS")
                                            }

                                            ColumnLayout {
                                                Layout.fillHeight: true
                                                Layout.fillWidth: true
                                                Layout.topMargin: -instrumentPanel._dialTopPull
                                                spacing: instrumentPanel._columnSpacing

                                                RowLayout {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    Layout.fillHeight: true
                                                    spacing: instrumentPanel._columnSpacing * 0.8

                                                    QGCLabel {
                                                        color: "#F1F1F1"
                                                        font.pixelSize: instrumentPanel._dialValueFontSize * 1.35
                                                        font.weight: Font.DemiBold
                                                        fontSizeMode: Text.Fit
                                                        horizontalAlignment: Text.AlignHCenter
                                                        minimumPixelSize: 8
                                                        text: root._formatFactValue(instrumentPanel.gpsSatelliteFact, false, "--")
                                                        verticalAlignment: Text.AlignVCenter
                                                    }

                                                    QGCLabel {
                                                        color: "#D8D9DA"
                                                        font.pixelSize: instrumentPanel._labelFontSize
                                                        text: qsTr("星数")
                                                        verticalAlignment: Text.AlignVCenter
                                                    }
                                                }

                                                GridLayout {
                                                    Layout.fillWidth: true
                                                    columnSpacing: instrumentPanel._columnSpacing
                                                    columns: 2
                                                    rowSpacing: instrumentPanel._rowSpacing

                                                    QGCLabel {
                                                        color: "#D8D9DA"
                                                        font.pixelSize: instrumentPanel._labelFontSize
                                                        text: qsTr("HDOP")
                                                    }

                                                    QGCLabel {
                                                        Layout.alignment: Qt.AlignRight
                                                        color: "#F1F1F1"
                                                        font.pixelSize: instrumentPanel._dialValueFontSize * 0.82
                                                        font.weight: Font.DemiBold
                                                        text: root._formatFactValue(instrumentPanel.gpsHdopFact, false, "--")
                                                    }

                                                    QGCLabel {
                                                        color: "#D8D9DA"
                                                        font.pixelSize: instrumentPanel._labelFontSize
                                                        text: qsTr("VDOP")
                                                    }

                                                    QGCLabel {
                                                        Layout.alignment: Qt.AlignRight
                                                        color: "#F1F1F1"
                                                        font.pixelSize: instrumentPanel._dialValueFontSize * 0.82
                                                        font.weight: Font.DemiBold
                                                        text: root._formatFactValue(instrumentPanel.gpsVdopFact, false, "--")
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        id: verticalSpeedCard

                                        Layout.fillHeight: true
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        color: Qt.rgba(1, 1, 1, 0.06)
                                        radius: ScreenTools.defaultFontPixelHeight * 0.08

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: instrumentPanel._cardMargin
                                            spacing: instrumentPanel._dialTitleSpacing

                                            QGCLabel {
                                                Layout.fillWidth: true
                                                Layout.minimumWidth: 0
                                                color: "#D8D9DA"
                                                elide: Text.ElideRight
                                                font.pixelSize: instrumentPanel._labelFontSize
                                                text: qsTr("垂直速度")
                                            }

                                            Item {
                                                Layout.fillHeight: true
                                                Layout.fillWidth: true
                                                Layout.topMargin: -instrumentPanel._dialTopPull

                                                Rectangle {
                                                    id: verticalSpeedDial

                                                    anchors.centerIn: parent
                                                    border.color: Qt.rgba(0.88, 0.88, 0.88, 0.88)
                                                    border.width: 2
                                                    color: Qt.rgba(0, 0, 0, 0.06)
                                                    height: width
                                                    radius: width / 2
                                                    width: Math.min(parent.width, parent.height) * 0.86
                                                }

                                                Rectangle {
                                                    color: "#D7DDE3"
                                                    height: Math.max(2, ScreenTools.defaultFontPixelWidth / 3)
                                                    radius: height / 2
                                                    rotation: instrumentPanel.verticalNeedleRotation
                                                    transformOrigin: Item.Left
                                                    width: verticalSpeedDial.width * 0.34
                                                    x: verticalSpeedDial.x + (verticalSpeedDial.width / 2)
                                                    y: verticalSpeedDial.y + ((verticalSpeedDial.height - height) / 2)
                                                }

                                                Rectangle {
                                                    anchors.centerIn: verticalSpeedDial
                                                    color: "#D7DDE3"
                                                    height: width
                                                    radius: width / 2
                                                    width: ScreenTools.defaultFontPixelWidth
                                                }

                                                QGCLabel {
                                                    anchors.centerIn: verticalSpeedDial
                                                    color: "#F1F1F1"
                                                    font.pixelSize: instrumentPanel._dialValueFontSize * 0.92
                                                    font.weight: Font.DemiBold
                                                    fontSizeMode: Text.Fit
                                                    height: verticalSpeedDial.height * 0.3
                                                    horizontalAlignment: Text.AlignHCenter
                                                    minimumPixelSize: 8
                                                    text: root._formatFactValue(instrumentPanel.climbRateFact, true, "--")
                                                    verticalAlignment: Text.AlignVCenter
                                                    width: verticalSpeedDial.width * 0.76
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        GuidedActionConfirm {
                            id: guidedConfirm

                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: root._margin
                            guidedController: guidedActionsController
                            guidedValueSlider: guidedValueSlider
                            height: ScreenTools.toolbarHeight
                            messageDisplay: guidedMessageDisplay
                        }

                        Rectangle {
                            id: guidedMessageDisplay

                            anchors.horizontalCenter: guidedConfirm.horizontalCenter
                            anchors.top: guidedConfirm.bottom
                            anchors.topMargin: root._margin
                            color: qgcPal.window
                            height: guidedMessageLabel.contentHeight + (root._margin * 1.2)
                            opacity: 0.9
                            radius: ScreenTools.defaultFontPixelHeight * 0.28
                            visible: guidedConfirm.visible
                            width: guidedMessageLabel.contentWidth + (root._margin * 2)

                            QGCLabel {
                                id: guidedMessageLabel

                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                                text: guidedConfirm.message
                                width: ScreenTools.defaultFontPixelWidth * 30
                                wrapMode: Text.WordWrap
                            }
                        }

                        Rectangle {
                            id: uavVideoOverlay

                            anchors.right: parent.right
                            anchors.rightMargin: root._margin
                            anchors.top: parent.top
                            anchors.topMargin: root._margin
                            clip: true
                            color: qgcPal.windowShadeDark
                            height: width * 0.75
                            radius: ScreenTools.defaultFontPixelHeight * 0.1
                            width: root._videoOverlayExpanded ? root._expandedVideoOverlayWidth(parent.width) : root._compactVideoOverlayWidth(parent.width)
                            z: QGroundControl.zOrderWidgets

                            Behavior on height {
                                NumberAnimation {
                                    duration: 180
                                    easing.type: Easing.InOutQuad
                                }
                            }
                            Behavior on width {
                                NumberAnimation {
                                    duration: 180
                                    easing.type: Easing.InOutQuad
                                }
                            }

                            Loader {
                                anchors.fill: parent
                                sourceComponent: QGroundControl.videoManager.hasVideo ? videoComponent : placeholderComponent
                            }

                            Component {
                                id: videoComponent

                                FlyViewVideo {
                                    pipView: null
                                }
                            }

                            Component {
                                id: placeholderComponent

                                Rectangle {
                                    color: qgcPal.window

                                    QGCColoredImage {
                                        anchors.centerIn: parent
                                        color: "#FFFFFF"
                                        fillMode: Image.PreserveAspectFit
                                        height: width
                                        source: "/InstrumentValueIcons/drone.svg"
                                        width: ScreenTools.defaultFontPixelHeight * 2.4
                                    }
                                }
                            }

                            Repeater {
                                model: [
                                    {
                                        "left": true,
                                        "top": true,
                                        "source": "/InstrumentValueIcons/window.svg"
                                    },
                                    {
                                        "left": false,
                                        "top": true,
                                        "source": "/InstrumentValueIcons/cheveron-outline-right.svg"
                                    },
                                    {
                                        "left": true,
                                        "top": false,
                                        "source": "/InstrumentValueIcons/view-tile.svg"
                                    },
                                    {
                                        "left": false,
                                        "top": false,
                                        "source": "/InstrumentValueIcons/screen-full.svg",
                                        "toggleExpand": true
                                    }
                                ]

                                delegate: Rectangle {
                                    required property var modelData

                                    anchors.bottom: modelData.top ? undefined : parent.bottom
                                    anchors.bottomMargin: ScreenTools.defaultFontPixelWidth * 0.18
                                    anchors.left: modelData.left ? parent.left : undefined
                                    anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.18
                                    anchors.right: modelData.left ? undefined : parent.right
                                    anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.18
                                    anchors.top: modelData.top ? parent.top : undefined
                                    anchors.topMargin: ScreenTools.defaultFontPixelWidth * 0.18
                                    color: Qt.rgba(0.1, 0.1, 0.1, 0.92)
                                    height: width
                                    radius: ScreenTools.defaultFontPixelHeight * 0.08
                                    width: ScreenTools.defaultFontPixelHeight * 1.16

                                    QGCColoredImage {
                                        anchors.centerIn: parent
                                        color: "#FFFFFF"
                                        fillMode: Image.PreserveAspectFit
                                        height: width
                                        source: modelData.toggleExpand && root._videoOverlayExpanded ? "/InstrumentValueIcons/window-open.svg" : modelData.source
                                        width: parent.height * 0.48
                                    }

                                    QGCMouseArea {
                                        anchors.fill: parent

                                        onClicked: {
                                            if (modelData.toggleExpand) {
                                                root._videoOverlayExpanded = !root._videoOverlayExpanded;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: startMissionFeedbackPanel

                        border.color: root._startMissionFeedbackIsError ? Qt.rgba(1.0, 0.52, 0.52, 0.35) : Qt.rgba(0.60, 0.84, 1.0, 0.28)
                        border.width: 1
                        color: root._startMissionFeedbackIsError ? Qt.rgba(0.28, 0.11, 0.11, 0.96) : Qt.rgba(0.08, 0.19, 0.30, 0.96)
                        height: feedbackContent.implicitHeight + (ScreenTools.defaultFontPixelHeight * 0.9)
                        radius: ScreenTools.defaultFontPixelHeight * 0.28
                        visible: !root._useExternalStartMissionUi && root._startMissionFeedbackVisible && !root._startMissionSliderVisible
                        width: Math.min(ScreenTools.defaultFontPixelWidth * 32, Math.max(ScreenTools.defaultFontPixelWidth * 20, mapPanel.width - (root._margin * 2)))
                        x: Math.max(root._margin, Math.min(mapPanel.width - width - root._margin, startMissionMapButton.mapToItem(rightPane, 0, 0).x + ((startMissionMapButton.width - width) * 0.5)))
                        y: Math.max(root._margin, startMissionMapButton.mapToItem(rightPane, 0, 0).y - height - (root._margin * 0.55))
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
                                    color: "#F8FAFC"
                                    font.bold: true
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.74
                                    text: root._startMissionFeedbackTitle
                                }

                                Rectangle {
                                    Layout.preferredHeight: Layout.preferredWidth
                                    Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 1.15
                                    color: Qt.rgba(1, 1, 1, 0.14)
                                    radius: width / 2

                                    QGCColoredImage {
                                        anchors.centerIn: parent
                                        color: "#FFFFFF"
                                        fillMode: Image.PreserveAspectFit
                                        height: width
                                        source: "/res/XDelete.svg"
                                        width: parent.width * 0.4
                                    }

                                    QGCMouseArea {
                                        anchors.fill: parent

                                        onClicked: root._hideStartMissionFeedback()
                                    }
                                }
                            }

                            QGCLabel {
                                Layout.fillWidth: true
                                color: "#E5E7EB"
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.68
                                text: root._startMissionFeedbackText
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
                            border.color: Qt.rgba(1.0, 0.52, 0.52, 0.34)
                            border.width: 1
                            color: Qt.rgba(0.12, 0.12, 0.13, 0.985)
                            height: unavailableDialogContent.implicitHeight + (ScreenTools.defaultFontPixelHeight * 1.2)
                            radius: ScreenTools.defaultFontPixelHeight * 0.34
                            width: Math.max(ScreenTools.defaultFontPixelWidth * 26, Math.min(ScreenTools.defaultFontPixelWidth * 42, parent.width * 0.38))

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
                                        color: "#F8FAFC"
                                        font.bold: true
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.78
                                        text: root._mapPrimaryActionDialogTitle()
                                    }

                                    Rectangle {
                                        Layout.preferredHeight: Layout.preferredWidth
                                        Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 1.12
                                        color: Qt.rgba(1, 1, 1, 0.10)
                                        radius: width / 2

                                        QGCColoredImage {
                                            anchors.centerIn: parent
                                            color: "#FFFFFF"
                                            fillMode: Image.PreserveAspectFit
                                            height: width
                                            source: "/res/XDelete.svg"
                                            width: parent.width * 0.42
                                        }

                                        QGCMouseArea {
                                            anchors.fill: parent

                                            onClicked: root._hideStartMissionUnavailableDialog()
                                        }
                                    }
                                }

                                QGCLabel {
                                    Layout.fillWidth: true
                                    color: "#E5E7EB"
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.7
                                    text: root._startMissionUnavailableDialogText
                                    wrapMode: Text.WordWrap
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.topMargin: ScreenTools.defaultFontPixelHeight * 0.12

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    QGCButton {
                                        primary: true
                                        text: qsTr("OK")

                                        onClicked: root._hideStartMissionUnavailableDialog()
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: startMissionSliderPanel

                        border.color: Qt.rgba(0.45, 0.74, 0.78, 0.20)
                        border.width: 1
                        color: Qt.rgba(0.07, 0.10, 0.12, 0.96)
                        height: startMissionConfirmContent.implicitHeight + (ScreenTools.defaultFontPixelHeight * 0.58)
                        radius: ScreenTools.defaultFontPixelHeight * 0.22
                        visible: !root._useExternalStartMissionUi && root._startMissionSliderVisible && !root._startMissionAlreadyStarted
                        width: Math.min(ScreenTools.defaultFontPixelWidth * 34, Math.max(ScreenTools.defaultFontPixelWidth * 22, mapPanel.width - (root._margin * 2)))
                        x: Math.max(root._margin, Math.min(mapPanel.width - width - root._margin, startMissionMapButton.mapToItem(rightPane, 0, 0).x + ((startMissionMapButton.width - width) * 0.5)))
                        y: Math.max(root._margin, startMissionMapButton.mapToItem(rightPane, 0, 0).y - height - (root._margin * 0.55))
                        z: QGroundControl.zOrderTopMost + 9

                        onVisibleChanged: {
                            if (!visible) {
                                startMissionHoldAnimation.stop();
                                startMissionHoldButton.holding = false;
                                startMissionHoldButton.holdProgress = 0;
                            }
                        }

                        ColumnLayout {
                            id: startMissionConfirmContent

                            anchors.fill: parent
                            anchors.margins: ScreenTools.defaultFontPixelHeight * 0.30
                            spacing: ScreenTools.defaultFontPixelHeight * 0.22

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: ScreenTools.defaultFontPixelWidth * 0.32

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    QGCLabel {
                                        Layout.fillWidth: true
                                        color: "#F5FBFC"
                                        elide: Text.ElideRight
                                        font.bold: true
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.72
                                        text: root._mapPrimaryActionDialogTitle()
                                    }

                                    QGCLabel {
                                        Layout.fillWidth: true
                                        color: "#8FB0B8"
                                        elide: Text.ElideRight
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.52
                                        text: qsTr("确认航线状态后长按执行")
                                    }
                                }

                                Rectangle {
                                    Layout.preferredHeight: Layout.preferredWidth
                                    Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.96
                                    color: Qt.rgba(1, 1, 1, 0.09)
                                    radius: width / 2

                                    QGCColoredImage {
                                        anchors.centerIn: parent
                                        color: "#FFFFFF"
                                        fillMode: Image.PreserveAspectFit
                                        height: width
                                        source: "/res/XDelete.svg"
                                        width: parent.width * 0.42
                                    }

                                    QGCMouseArea {
                                        anchors.fill: parent

                                        onClicked: root._hideStartMissionSlider()
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: ScreenTools.defaultFontPixelWidth * 0.35

                                Repeater {
                                    model: [
                                        {
                                            "label": qsTr("航点"),
                                            "value": root._startMissionItemCountText()
                                        },
                                        {
                                            "label": qsTr("首点"),
                                            "value": root._startMissionFirstSequenceText()
                                        },
                                        {
                                            "label": qsTr("状态"),
                                            "value": root._startMissionSyncStateText()
                                        }
                                    ]

                                    delegate: Rectangle {
                                        required property var modelData

                                        Layout.fillWidth: true
                                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.48
                                        border.color: Qt.rgba(0.45, 0.74, 0.78, 0.12)
                                        border.width: 1
                                        color: Qt.rgba(0.09, 0.15, 0.18, 0.92)
                                        radius: ScreenTools.defaultFontPixelHeight * 0.12

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: ScreenTools.defaultFontPixelHeight * 0.14
                                            spacing: 0

                                            QGCLabel {
                                                Layout.fillWidth: true
                                                color: "#7E9AA4"
                                                elide: Text.ElideRight
                                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.40
                                                horizontalAlignment: Text.AlignHCenter
                                                text: modelData.label
                                            }

                                            QGCLabel {
                                                Layout.fillWidth: true
                                                color: "#E7F7F9"
                                                elide: Text.ElideRight
                                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.56
                                                font.weight: Font.DemiBold
                                                horizontalAlignment: Text.AlignHCenter
                                                text: modelData.value
                                            }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: ScreenTools.defaultFontPixelWidth * 0.32

                                QGCLabel {
                                    Layout.fillWidth: true
                                    color: "#8FB0B8"
                                    elide: Text.ElideRight
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.50
                                    text: qsTr("距离 %1").arg(root._startMissionDistanceText())
                                }

                                QGCLabel {
                                    color: "#CBE5EA"
                                    elide: Text.ElideRight
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.50
                                    text: root._mapPrimaryActionMessage()
                                }
                            }

                            Rectangle {
                                id: startMissionHoldButton

                                property real holdProgress: 0
                                property bool holding: false

                                Layout.fillWidth: true
                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.02
                                border.color: Qt.rgba(0.82, 1, 0.96, 0.24)
                                border.width: 1
                                clip: true
                                color: startMissionHoldMouseArea.pressed ? "#0F5F58" : (startMissionHoldMouseArea.containsMouse ? "#199688" : "#147C72")
                                radius: ScreenTools.defaultFontPixelHeight * 0.16

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    color: Qt.rgba(1, 1, 1, 0.14)
                                    width: parent.width * startMissionHoldButton.holdProgress
                                }

                                QGCLabel {
                                    anchors.centerIn: parent
                                    color: "#EFFFFC"
                                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.66
                                    font.weight: Font.DemiBold
                                    horizontalAlignment: Text.AlignHCenter
                                    text: startMissionHoldButton.holding ? qsTr("保持按住 %1%").arg(Math.round(startMissionHoldButton.holdProgress * 100)) : qsTr("长按开始任务")
                                    verticalAlignment: Text.AlignVCenter
                                }

                                NumberAnimation {
                                    id: startMissionHoldAnimation

                                    duration: 1250
                                    easing.type: Easing.InOutQuad
                                    from: 0
                                    property: "holdProgress"
                                    target: startMissionHoldButton
                                    to: 1

                                    onStopped: {
                                        if (startMissionHoldButton.holding && startMissionHoldButton.holdProgress >= 0.999) {
                                            startMissionHoldButton.holding = false;
                                            root._confirmStartMissionSlider();
                                        }
                                    }
                                }

                                QGCMouseArea {
                                    id: startMissionHoldMouseArea

                                    anchors.fill: parent
                                    hoverEnabled: true

                                    onCanceled: {
                                        startMissionHoldAnimation.stop();
                                        startMissionHoldButton.holding = false;
                                        startMissionHoldButton.holdProgress = 0;
                                    }
                                    onExited: {
                                        if (pressed && startMissionHoldButton.holding) {
                                            startMissionHoldAnimation.stop();
                                            startMissionHoldButton.holding = false;
                                            startMissionHoldButton.holdProgress = 0;
                                        }
                                    }
                                    onPressed: {
                                        if (!root._mapPrimaryActionAvailable()) {
                                            root._confirmStartMissionSlider();
                                            return;
                                        }
                                        startMissionHoldAnimation.stop();
                                        startMissionHoldButton.holdProgress = 0;
                                        startMissionHoldButton.holding = true;
                                        startMissionHoldAnimation.restart();
                                    }
                                    onReleased: {
                                        if (startMissionHoldButton.holding && startMissionHoldButton.holdProgress < 0.999) {
                                            startMissionHoldAnimation.stop();
                                            startMissionHoldButton.holding = false;
                                            startMissionHoldButton.holdProgress = 0;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        color: qgcPal.windowShade
                        height: 1
                        width: parent ? parent.width : 0
                        x: 0
                        y: mapPanel.height
                    }

                    Rectangle {
                        id: profilePanel

                        clip: true
                        color: qgcPal.windowShadeDark
                        height: root._profilePanelExpanded ? root._clampProfilePanelHeight(root._profilePanelExpandedHeight) : root._profilePanelCollapsedHeight
                        radius: root._radius
                        width: parent ? parent.width : 0
                        x: 0
                        y: mapPanel.height + 1

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 0

                            Rectangle {
                                id: profileResizeHandle

                                Layout.fillWidth: true
                                Layout.preferredHeight: root._profilePanelExpanded ? ScreenTools.defaultFontPixelHeight * 0.42 : 0
                                color: Qt.rgba(1, 1, 1, 0.05)
                                visible: root._profilePanelExpanded

                                Rectangle {
                                    anchors.centerIn: parent
                                    color: Qt.rgba(1, 1, 1, 0.28)
                                    height: ScreenTools.defaultFontPixelHeight * 0.12
                                    radius: height / 2
                                    width: ScreenTools.defaultFontPixelWidth * 6
                                }

                                MouseArea {
                                    property real _startHeight: 0
                                    property real _startMouseY: 0

                                    anchors.fill: parent
                                    cursorShape: Qt.SizeVerCursor

                                    onPositionChanged: mouse => {
                                        if (!pressed || !root._profilePanelExpanded) {
                                            return;
                                        }
                                        const currentMouseY = profileResizeHandle.mapToItem(root, mouse.x, mouse.y).y;
                                        const deltaY = currentMouseY - _startMouseY;
                                        root._profilePanelExpandedHeight = root._clampProfilePanelHeight(_startHeight - deltaY);
                                    }
                                    onPressed: mouse => {
                                        _startMouseY = profileResizeHandle.mapToItem(root, mouse.x, mouse.y).y;
                                        _startHeight = root._profilePanelExpandedHeight;
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

                                        Layout.fillHeight: true
                                        Layout.maximumWidth: Layout.preferredWidth
                                        Layout.preferredWidth: Math.max(ScreenTools.defaultFontPixelWidth * 18, profileLeftPanel.width)

                                        RowLayout {
                                            id: playbackButtonStrip

                                            readonly property real buttonWidth: Math.max(ScreenTools.defaultFontPixelHeight * 1.92, (width - (spacing * 4)) / 5)

                                            anchors.fill: parent
                                            spacing: ScreenTools.defaultFontPixelWidth * 0.28

                                            Repeater {
                                                model: [
                                                    {
                                                        "key": "toStart",
                                                        "icon": "/InstrumentValueIcons/fast-rewind.svg"
                                                    },
                                                    {
                                                        "key": "stepBack",
                                                        "icon": "/InstrumentValueIcons/step-backward.svg"
                                                    },
                                                    {
                                                        "key": "toggle",
                                                        "icon": ""
                                                    },
                                                    {
                                                        "key": "stepForward",
                                                        "icon": "/InstrumentValueIcons/step-forward.svg"
                                                    },
                                                    {
                                                        "key": "toEnd",
                                                        "icon": "/InstrumentValueIcons/fast-forward.svg"
                                                    }
                                                ]

                                                delegate: Rectangle {
                                                    readonly property bool _enabled: root._profilePlaybackControlsEnabled()

                                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.92
                                                    Layout.preferredWidth: playbackButtonStrip.buttonWidth
                                                    border.color: Qt.rgba(1, 1, 1, 0.06)
                                                    border.width: 1
                                                    color: playbackMouseArea.pressed && _enabled ? "#1A1C1F" : "#202020"
                                                    opacity: _enabled ? 1 : 0.42
                                                    radius: ScreenTools.defaultFontPixelHeight * 0.06

                                                    QGCColoredImage {
                                                        anchors.centerIn: parent
                                                        color: "#FFFFFF"
                                                        fillMode: Image.PreserveAspectFit
                                                        height: width
                                                        source: modelData.key === "toggle" ? (root._profilePlaybackActive ? "/InstrumentValueIcons/pause-outline.svg" : "/InstrumentValueIcons/play-outline.svg") : modelData.icon
                                                        width: parent.height * 0.5
                                                    }

                                                    QGCMouseArea {
                                                        id: playbackMouseArea

                                                        anchors.fill: parent
                                                        enabled: parent._enabled

                                                        onClicked: {
                                                            switch (modelData.key) {
                                                            case "toStart":
                                                                root._profilePlaybackActive = false;
                                                                root._profileProgress = 0;
                                                                break;
                                                            case "stepBack":
                                                                root._profilePlaybackActive = false;
                                                                root._profileProgress = Math.max(0, root._profileProgress - 0.05);
                                                                break;
                                                            case "toggle":
                                                                root._profilePlaybackActive = !root._profilePlaybackActive;
                                                                break;
                                                            case "stepForward":
                                                                root._profilePlaybackActive = false;
                                                                root._profileProgress = Math.min(1, root._profileProgress + 0.05);
                                                                break;
                                                            case "toEnd":
                                                                root._profilePlaybackActive = false;
                                                                root._profileProgress = 1;
                                                                break;
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Item {
                                        Layout.fillHeight: true
                                        Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 1.6
                                    }

                                    Rectangle {
                                        id: startMissionMapButton

                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 2.9
                                        Layout.minimumWidth: ScreenTools.defaultFontPixelHeight * 2.9
                                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.9
                                        Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 2.9
                                        border.color: Qt.rgba(1, 1, 1, 0.24)
                                        border.width: 2
                                        color: startMissionMapMouseArea.pressed ? "#9A3412" : (startMissionMapMouseArea.containsMouse ? "#F97316" : "#EA580C")
                                        opacity: 0.98
                                        radius: ScreenTools.defaultFontPixelHeight * 0.14
                                        visible: !root._useExternalStartMissionUi && root._startMissionEntryVisible

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 160
                                            }
                                        }

                                        Item {
                                            anchors.fill: parent

                                            QGCColoredImage {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.verticalCenterOffset: -(ScreenTools.defaultFontPixelHeight * 0.26)
                                                color: "#FFF7ED"
                                                fillMode: Image.PreserveAspectFit
                                                height: width
                                                source: "/res/takeoff.svg"
                                                width: parent.width * 0.4
                                            }

                                            QGCLabel {
                                                anchors.bottom: parent.bottom
                                                anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.18
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                color: "#FFF7ED"
                                                font.bold: true
                                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.42
                                                text: root._mapPrimaryActionText()
                                            }

                                            Rectangle {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                anchors.top: parent.top
                                                anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.16
                                                color: Qt.rgba(1, 1, 1, 0.28)
                                                height: ScreenTools.defaultFontPixelHeight * 0.1
                                                radius: height / 2
                                                width: parent.width * 0.5
                                            }
                                        }

                                        QGCMouseArea {
                                            id: startMissionMapMouseArea

                                            anchors.fill: parent
                                            hoverEnabled: true

                                            onClicked: {
                                                if (root._startMissionSliderVisible) {
                                                    root._hideStartMissionSlider();
                                                    return;
                                                }
                                                root._triggerMapPrimaryAction();
                                            }
                                        }
                                    }

                                    Item {
                                        id: startMissionToolbarGap

                                        Layout.fillHeight: true
                                        Layout.fillWidth: true
                                    }

                                    Repeater {
                                        model: [
                                            {
                                                "icon": "/InstrumentValueIcons/time.svg",
                                                "text": root._formatReplayTime(root._profileElapsedSeconds(root._profileMissionPoints, root._profileProgress))
                                            },
                                            {
                                                "icon": "/InstrumentValueIcons/navigation-more.svg",
                                                "text": root._activeVehicle && root._hasFactValue(root._activeVehicle.heading) ? (root._factText(root._activeVehicle.heading, "--", false) + "\u00B0 " + root._headingCompassLabel(Number(root._activeVehicle.heading.rawValue))) : qsTr("--")
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
                                            border.color: Qt.rgba(1, 1, 1, 0.08)
                                            border.width: 1
                                            color: "#202020"
                                            radius: ScreenTools.defaultFontPixelHeight * 0.08

                                            RowLayout {
                                                id: metricRow

                                                anchors.centerIn: parent
                                                spacing: ScreenTools.defaultFontPixelWidth * 0.16

                                                QGCColoredImage {
                                                    Layout.preferredHeight: Layout.preferredWidth
                                                    Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.58
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

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    Rectangle {
                                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.35
                                        Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 7.4
                                        border.color: Qt.rgba(1, 1, 1, 0.08)
                                        border.width: 1
                                        color: "#202020"
                                        radius: ScreenTools.defaultFontPixelHeight * 0.08

                                        QGCLabel {
                                            anchors.centerIn: parent
                                            color: "#D9D9D9"
                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.62
                                            text: root._formatReplayTime(root._profileTotalDurationSeconds(root._profileMissionPoints))
                                        }
                                    }

                                    Rectangle {
                                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.35
                                        Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 1.35
                                        border.color: Qt.rgba(1, 1, 1, 0.06)
                                        border.width: 1
                                        color: "#202020"
                                        radius: ScreenTools.defaultFontPixelHeight * 0.06

                                        QGCColoredImage {
                                            anchors.centerIn: parent
                                            color: "#FFFFFF"
                                            fillMode: Image.PreserveAspectFit
                                            height: width
                                            source: root._profilePanelExpanded ? "/InstrumentValueIcons/cheveron-down.svg" : "/InstrumentValueIcons/cheveron-up.svg"
                                            width: parent.height * 0.4
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

                                Layout.fillHeight: root._profilePanelExpanded
                                Layout.fillWidth: true
                                Layout.maximumHeight: root._profilePanelExpanded ? 100000 : 0
                                Layout.preferredHeight: root._profilePanelExpanded ? Math.max(0, profilePanel.height - profileResizeHandle.height - (ScreenTools.defaultFontPixelHeight * 2.3)) : 0
                                clip: true
                                visible: root._profilePanelExpanded

                                RowLayout {
                                    anchors.bottomMargin: root._margin * 0.35
                                    anchors.fill: parent
                                    anchors.leftMargin: root._margin * 0.5
                                    anchors.rightMargin: root._margin * 0.5
                                    anchors.topMargin: root._margin * 0.35
                                    spacing: ScreenTools.defaultFontPixelWidth * 0.35

                                    Rectangle {
                                        id: profileLeftPanel

                                        Layout.fillHeight: true
                                        Layout.preferredWidth: Math.max(ScreenTools.defaultFontPixelWidth * 18, parent.width * 0.24)
                                        clip: true
                                        color: "#191A1C"
                                        radius: ScreenTools.defaultFontPixelHeight * 0.08

                                        Flickable {
                                            id: profileTreeFlickable

                                            anchors.fill: parent
                                            boundsBehavior: Flickable.StopAtBounds
                                            clip: true
                                            contentHeight: profileTreeColumn.implicitHeight
                                            contentWidth: width
                                            flickableDirection: Flickable.VerticalFlick

                                            ScrollBar.vertical: ScrollBar {
                                                policy: ScrollBar.AsNeeded
                                            }

                                            WheelHandler {
                                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                                target: null

                                                onWheel: event => {
                                                    const step = ScreenTools.defaultFontPixelHeight * 2.2;
                                                    const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : (event.pixelDelta ? event.pixelDelta.y : 0);
                                                    if (delta === 0) {
                                                        return;
                                                    }
                                                    profileTreeFlickable.contentY = Math.max(0, Math.min(profileTreeFlickable.contentHeight - profileTreeFlickable.height, profileTreeFlickable.contentY - ((delta / 120) * step)));
                                                }
                                            }

                                            Column {
                                                id: profileTreeColumn

                                                spacing: 0
                                                width: profileLeftPanel.width

                                                Rectangle {
                                                    color: "#4A89D8"
                                                    height: ScreenTools.defaultFontPixelHeight * 2.05
                                                    width: parent.width

                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.26
                                                        anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.26
                                                        spacing: ScreenTools.defaultFontPixelWidth * 0.22

                                                        Item {
                                                            Layout.fillHeight: true
                                                            Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.82

                                                            QGCLabel {
                                                                anchors.centerIn: parent
                                                                color: "#D7E6FF"
                                                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5
                                                                text: root._profileVehicleTreeExpanded ? "\u25BE" : "\u25B8"
                                                            }

                                                            QGCMouseArea {
                                                                anchors.fill: parent

                                                                onClicked: root._profileVehicleTreeExpanded = !root._profileVehicleTreeExpanded
                                                            }
                                                        }

                                                        QGCColoredImage {
                                                            Layout.preferredHeight: Layout.preferredWidth
                                                            Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.8
                                                            color: "#DCEBFF"
                                                            fillMode: Image.PreserveAspectFit
                                                            source: "/InstrumentValueIcons/drone.svg"
                                                        }

                                                        QGCLabel {
                                                            Layout.fillWidth: true
                                                            color: "#F4F9FF"
                                                            elide: Text.ElideRight
                                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.72
                                                            font.weight: Font.DemiBold
                                                            text: root._activeVehicle ? root._vehicleTitle(root._activeVehicle) : qsTr("飞行器 --")
                                                        }
                                                    }
                                                }

                                                Rectangle {
                                                    clip: true
                                                    color: "#1F2022"
                                                    height: root._profileVehicleTreeExpanded ? ScreenTools.defaultFontPixelHeight * 2.0 : 0
                                                    visible: height > 0
                                                    width: parent.width

                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 1.28
                                                        anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.28
                                                        spacing: ScreenTools.defaultFontPixelWidth * 0.22

                                                        Item {
                                                            Layout.fillHeight: true
                                                            Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.74

                                                            QGCLabel {
                                                                anchors.centerIn: parent
                                                                color: "#D4D4D4"
                                                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.48
                                                                text: root._profileMissionTreeExpanded ? "\u25BE" : "\u25B8"
                                                            }

                                                            QGCMouseArea {
                                                                anchors.fill: parent

                                                                onClicked: root._profileMissionTreeExpanded = !root._profileMissionTreeExpanded
                                                            }
                                                        }

                                                        QGCColoredImage {
                                                            Layout.preferredHeight: Layout.preferredWidth
                                                            Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.72
                                                            color: "#61C3B1"
                                                            fillMode: Image.PreserveAspectFit
                                                            source: "/InstrumentValueIcons/map.svg"
                                                        }

                                                        QGCLabel {
                                                            Layout.fillWidth: true
                                                            color: "#E1E1E1"
                                                            elide: Text.ElideRight
                                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.68
                                                            text: root._missionTitle()
                                                        }
                                                    }

                                                    Rectangle {
                                                        color: Qt.rgba(1, 1, 1, 0.08)
                                                        height: parent.height
                                                        width: 1
                                                        x: ScreenTools.defaultFontPixelWidth * 0.82
                                                        y: 0
                                                    }
                                                }

                                                Repeater {
                                                    model: root._profileSiteGroups

                                                    delegate: Rectangle {
                                                        readonly property bool _current: profileChart.currentDistance >= Number(modelData.startDistance) && profileChart.currentDistance <= Number(modelData.endDistance)
                                                        required property int index
                                                        required property var modelData

                                                        clip: true
                                                        color: _current ? Qt.rgba(0.29, 0.54, 0.85, 0.18) : "transparent"
                                                        height: (root._profileVehicleTreeExpanded && root._profileMissionTreeExpanded) ? (ScreenTools.defaultFontPixelHeight * 1.82) : 0
                                                        visible: height > 0
                                                        width: parent.width

                                                        Rectangle {
                                                            color: Qt.rgba(1, 1, 1, 0.08)
                                                            height: parent.height
                                                            width: 1
                                                            x: ScreenTools.defaultFontPixelWidth * 0.82
                                                            y: 0
                                                        }

                                                        Rectangle {
                                                            color: Qt.rgba(1, 1, 1, 0.08)
                                                            height: parent.height
                                                            width: 1
                                                            x: ScreenTools.defaultFontPixelWidth * 1.92
                                                            y: 0
                                                        }

                                                        RowLayout {
                                                            anchors.fill: parent
                                                            anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 2.18
                                                            anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.3
                                                            spacing: ScreenTools.defaultFontPixelWidth * 0.22

                                                            QGCLabel {
                                                                color: "#B7B7B7"
                                                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.42
                                                                text: "\u25B8"
                                                            }

                                                            QGCColoredImage {
                                                                Layout.preferredHeight: Layout.preferredWidth
                                                                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.66
                                                                color: _current ? "#7FD0FF" : "#7AA0C8"
                                                                fillMode: Image.PreserveAspectFit
                                                                source: "/InstrumentValueIcons/drone.svg"
                                                            }

                                                            QGCLabel {
                                                                Layout.fillWidth: true
                                                                color: _current ? "#F6F8FB" : "#D1D5DB"
                                                                elide: Text.ElideRight
                                                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.64
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
                                                                const totalDistance = Math.max(Number(root._profileStats(root._profileMissionPoints).totalDistance), 1);
                                                                root._profilePlaybackActive = false;
                                                                root._profileProgress = Math.max(0, Math.min(1, Number(modelData.startDistance) / totalDistance));
                                                                if (modelData.coordinate && modelData.coordinate.isValid) {
                                                                    mapView.center = modelData.coordinate;
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

                                        // 强制日志：每次 currentAltitude 变化都打印
                                        property real _lastLoggedCurrentAlt: NaN

                                        // 获取图标的X坐标，垂直段时固定在起点或终点
                                        readonly property real _segmentLockedIconX: {
                                            //readonly property real iconX: {
                                            const segment = root._profileLiveSegment;
                                            if (useLiveState && (segment === "takeoff" || segment === "return-climb" || segment === "landing")) {
                                                // 垂直段：固定X坐标
                                                if (segment === "takeoff") {
                                                    // 起飞段：固定在起点（距离0）
                                                    const takeoffSegment = root._takeoffProfileSegment(points);
                                                    const takeoffPoint = takeoffSegment.valid ? points[takeoffSegment.fromIndex] : null;
                                                    return takeoffPoint ? xForDistance(takeoffPoint.distance) : xForDistance(currentDistance);
                                                } else if (segment === "landing") {
                                                    // 降落段：固定在终点（最后一个点的距离）
                                                    const lastPoint = points && points.length > 0 ? points[points.length - 1] : null;
                                                    return lastPoint ? xForDistance(lastPoint.distance) : xForDistance(currentDistance);
                                                } else if (segment === "return-climb") {
                                                    // 返航爬升段：固定在倒数第4个点的距离
                                                    const returnPoint = points && points.length >= 4 ? points[points.length - 4] : null;
                                                    return returnPoint ? xForDistance(returnPoint.distance) : xForDistance(currentDistance);
                                                }
                                            }
                                            // 非垂直段：使用当前距离
                                            return xForDistance(currentDistance);
                                        }
                                        readonly property real currentAltitude: {
                                            if (!useLiveState) {
                                                return root._profileAltitudeAtDistance(points, currentDistance);
                                            }
                                            if (!isNaN(Number(liveAltitude))) {
                                                return Number(liveAltitude);
                                            }
                                            if (!isNaN(Number(root._vehicleActualAltitude))) {
                                                return Number(root._vehicleActualAltitude);
                                            }
                                            return root._profileAltitudeAtDistance(points, currentDistance);
                                        }
                                        readonly property real currentDistance: useLiveState ? Number(root._profileLiveDistance) : (Math.max(Number(stats.totalDistance), 1) * root._profileProgress)
                                        readonly property var currentPoint: currentPointIndex >= 0 && currentPointIndex < points.length ? points[currentPointIndex] : null
                                        readonly property int currentPointIndex: useLiveState ? root._resolvedProfilePointIndex(points, root._profileLivePointIndex, currentDistance, currentAltitude) : root._resolvedProfilePointIndex(points, -1, currentDistance, currentAltitude)
                                        readonly property real elapsedSeconds: root._profileElapsedSeconds(points, Math.max(0, Math.min(1, currentDistance / Math.max(Number(stats.totalDistance), 1))))
                                        readonly property bool hasLiveTelemetry: !!(root._activeVehicle && (!isNaN(Number(root._vehicleActualAltitude)) || !isNaN(Number(root._profileLiveAltitude)) || !isNaN(Number(root._vehicleClimbRate)) || (root._activeVehicle.coordinate && root._activeVehicle.coordinate.isValid)))
                                        readonly property real iconX: {
                                            const segment = root._profileLiveSegment;
                                            const lastPoint = points && points.length > 0 ? points[points.length - 1] : null;
                                            const lastDist = lastPoint ? lastPoint.distance : 0;

                                            if (useLiveState) {
                                                if (segment === "takeoff") {
                                                    return xForDistance(0);
                                                } else if (segment === "return-climb" || segment === "landing") {
                                                    return lastPoint ? xForDistance(lastPoint.distance) : xForDistance(currentDistance);
                                                }
                                            }
                                            return xForDistance(currentDistance);
                                        }
                                        readonly property real iconY: yForAltitude(currentAltitude) - (aircraftIcon.height * 0.5)
                                        readonly property real liveAltitude: Number(root._profileLiveAltitude)
                                        readonly property real liveClimbRate: Number(root._vehicleClimbRate)
                                        readonly property real plotBottom: ScreenTools.defaultFontPixelHeight * 1.55
                                        readonly property real plotHeight: Math.max(height - plotTop - plotBottom, 1)
                                        readonly property real plotLeft: ScreenTools.defaultFontPixelWidth * 2.8
                                        readonly property real plotRight: ScreenTools.defaultFontPixelWidth * 1.2
                                        readonly property real plotTop: ScreenTools.defaultFontPixelHeight * 1.65
                                        readonly property real plotWidth: Math.max(width - plotLeft - plotRight, 1)
                                        property var points: root._profileMissionPoints
                                        readonly property var stats: root._profileStats(points, useLiveState ? liveAltitude : NaN)
                                        readonly property bool useLiveState: hasLiveTelemetry || !!(root._activeVehicle && (root._vehicleIsFlying || root._activeVehicle.armed))

                                        function altitudeAtProgress(progress) {
                                            if (!points || points.length === 0) {
                                                return Number(stats.minAlt);
                                            }
                                            const targetDistance = Math.max(Number(stats.totalDistance), 1) * Math.max(0, Math.min(1, progress));
                                            return root._profileAltitudeAtDistance(points, targetDistance);
                                        }

                                        function xForDistance(distance) {
                                            return plotLeft + (Math.max(0, Number(distance)) / Math.max(Number(stats.totalDistance), 1)) * plotWidth;
                                        }

                                        function yForAltitude(altitude) {
                                            const maxAlt = Number(stats.maxAlt);
                                            const minAlt = Number(stats.minAlt);
                                            const ratio = (Math.max(minAlt, Math.min(maxAlt, Number(altitude))) - minAlt) / Math.max(maxAlt - minAlt, 1);
                                            return plotTop + (1 - ratio) * plotHeight;
                                        }

                                        Layout.fillHeight: true
                                        Layout.fillWidth: true
                                        clip: true
                                        color: "#202123"
                                        radius: ScreenTools.defaultFontPixelHeight * 0.08

                                        onCurrentAltitudeChanged: {
                                            if (useLiveState && (isNaN(_lastLoggedCurrentAlt) || Math.abs(currentAltitude - _lastLoggedCurrentAlt) > 0.5)) {
                                                //console.log("@@@ currentAltitude:", currentAltitude.toFixed(2), "_profileLiveAltitude:", root._profileLiveAltitude.toFixed(2), "useLiveState:", useLiveState)
                                                _lastLoggedCurrentAlt = currentAltitude;
                                            }
                                        }
                                        onHeightChanged: profileCanvas.requestPaint()

                                        // 调试：监控 iconX 的变化
                                        onIconXChanged: {
                                            if (useLiveState) {
                                                //console.log("$$$ iconX changed:", iconX.toFixed(2), "segment:", root._profileLiveSegment)
                                            }
                                        }
                                        onPointsChanged: profileCanvas.requestPaint()
                                        onStatsChanged: profileCanvas.requestPaint()
                                        onWidthChanged: profileCanvas.requestPaint()

                                        Canvas {
                                            id: profileCanvas

                                            anchors.fill: parent

                                            onPaint: {
                                                const ctx = getContext("2d");
                                                ctx.clearRect(0, 0, width, height);

                                                const left = profileChart.plotLeft;
                                                const top = profileChart.plotTop;
                                                const plotWidth = profileChart.plotWidth;
                                                const plotHeight = profileChart.plotHeight;

                                                ctx.fillStyle = "#262729";
                                                ctx.fillRect(left, top, plotWidth, plotHeight);

                                                ctx.strokeStyle = "rgba(255,255,255,0.10)";
                                                ctx.lineWidth = 1;
                                                for (let i = 0; i <= 8; i++) {
                                                    const x = left + (plotWidth * i / 8);
                                                    ctx.beginPath();
                                                    ctx.moveTo(x, top);
                                                    ctx.lineTo(x, top + plotHeight);
                                                    ctx.stroke();
                                                }
                                                for (let i = 0; i <= 5; i++) {
                                                    const y = top + (plotHeight * i / 5);
                                                    ctx.beginPath();
                                                    ctx.moveTo(left, y);
                                                    ctx.lineTo(left + plotWidth, y);
                                                    ctx.stroke();
                                                }

                                                const points = profileChart.points;
                                                if (!points || points.length < 2) {
                                                    return;
                                                }

                                                ctx.lineCap = "round";
                                                ctx.lineJoin = "round";
                                                ctx.strokeStyle = "rgba(250, 146, 75, 0.28)";
                                                ctx.lineWidth = ScreenTools.defaultFontPixelHeight * 0.82;
                                                ctx.beginPath();
                                                for (let i = 0; i < points.length; i++) {
                                                    const point = points[i];
                                                    const x = profileChart.xForDistance(point.distance);
                                                    const y = profileChart.yForAltitude(point.altitude);
                                                    if (i === 0) {
                                                        ctx.moveTo(x, y);
                                                    } else {
                                                        ctx.lineTo(x, y);
                                                    }
                                                }
                                                ctx.stroke();

                                                ctx.strokeStyle = "rgba(171, 138, 255, 0.58)";
                                                ctx.lineWidth = ScreenTools.defaultFontPixelHeight * 0.5;
                                                ctx.beginPath();
                                                for (let i = 0; i < points.length; i++) {
                                                    const point = points[i];
                                                    const x = profileChart.xForDistance(point.distance);
                                                    const y = profileChart.yForAltitude(point.altitude);
                                                    if (i === 0) {
                                                        ctx.moveTo(x, y);
                                                    } else {
                                                        ctx.lineTo(x, y);
                                                    }
                                                }
                                                ctx.stroke();

                                                ctx.strokeStyle = "#E8893D";
                                                ctx.lineWidth = ScreenTools.defaultFontPixelHeight * 0.16;
                                                ctx.beginPath();
                                                for (let i = 0; i < points.length; i++) {
                                                    const point = points[i];
                                                    const x = profileChart.xForDistance(point.distance);
                                                    const y = profileChart.yForAltitude(point.altitude);
                                                    if (i === 0) {
                                                        ctx.moveTo(x, y);
                                                    } else {
                                                        ctx.lineTo(x, y);
                                                    }
                                                }
                                                ctx.stroke();
                                            }
                                        }

                                        Rectangle {
                                            color: "#3D9BFF"
                                            height: profileChart.plotHeight + (ScreenTools.defaultFontPixelHeight * 0.55)
                                            opacity: 0.8
                                            width: 1
                                            x: profileChart.iconX
                                            y: profileChart.plotTop - (ScreenTools.defaultFontPixelHeight * 0.52)
                                        }

                                        Rectangle {
                                            color: "#56A7FF"
                                            height: width
                                            radius: width / 2
                                            width: ScreenTools.defaultFontPixelHeight * 0.52
                                            x: profileChart.iconX - (width * 0.5)
                                            y: profileChart.plotTop - (height * 0.8)
                                        }

                                        QGCLabel {
                                            color: "#71757B"
                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.48
                                            text: root._formatReplayTime(profileChart.elapsedSeconds)
                                            x: Math.max(profileChart.plotLeft, Math.min(profileChart.width - width - profileChart.plotRight, profileChart.iconX - (width * 0.5)))
                                            y: ScreenTools.defaultFontPixelHeight * 0.12
                                        }

                                        Repeater {
                                            model: 4

                                            delegate: QGCLabel {
                                                required property int index

                                                color: "#696E74"
                                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.48
                                                text: root._formatReplayTime(root._profileTotalDurationSeconds(profileChart.points) * (index + 1) / 4)
                                                x: profileChart.plotLeft + ((profileChart.plotWidth - width) * (index + 1) / 4)
                                                y: ScreenTools.defaultFontPixelHeight * 0.12
                                            }
                                        }

                                        Repeater {
                                            model: 4

                                            delegate: QGCLabel {
                                                readonly property real altitudeValue: Number(profileChart.stats.maxAlt) - ((Number(profileChart.stats.maxAlt) - Number(profileChart.stats.minAlt)) * index / 3)
                                                required property int index

                                                color: "#A5A7AA"
                                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.54
                                                text: root._formatProfileAltitude(altitudeValue)
                                                x: ScreenTools.defaultFontPixelWidth * 0.2
                                                y: profileChart.plotTop + ((profileChart.plotHeight - height) * index / 3)
                                            }
                                        }

                                        Repeater {
                                            model: profileChart.points

                                            delegate: Item {
                                                readonly property bool _current: profileChart.currentPointIndex === index
                                                required property int index
                                                required property var modelData

                                                height: width
                                                visible: root._profilePointMarkerVisible(profileChart.points, index, profileChart.currentPointIndex)
                                                width: ScreenTools.defaultFontPixelHeight * 1.22
                                                x: profileChart.xForDistance(modelData.distance) - (width * 0.5)
                                                y: profileChart.yForAltitude(modelData.altitude) - (height * 0.5)

                                                Rectangle {
                                                    anchors.fill: parent
                                                    border.color: _current ? "#E9F7E8" : "#F2A462"
                                                    border.width: _current ? 2 : 1
                                                    color: _current ? "#53B84F" : "#9E5B2E"
                                                    radius: width / 2
                                                }

                                                Rectangle {
                                                    anchors.centerIn: parent
                                                    border.color: Qt.rgba(1, 1, 1, 0.7)
                                                    border.width: 2
                                                    color: "transparent"
                                                    height: width
                                                    radius: width / 2
                                                    visible: _current
                                                    width: parent.width + (ScreenTools.defaultFontPixelHeight * 0.75)
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
                                                        const totalDistance = Math.max(Number(profileChart.stats.totalDistance), 1);
                                                        root._profilePlaybackActive = false;
                                                        root._profileProgress = Math.max(0, Math.min(1, Number(modelData.distance) / totalDistance));
                                                        if (modelData.coordinate && modelData.coordinate.isValid) {
                                                            mapView.center = modelData.coordinate;
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        QGCColoredImage {
                                            id: aircraftIcon

                                            color: "#55C2F8"
                                            fillMode: Image.PreserveAspectFit
                                            height: width
                                            source: "/InstrumentValueIcons/drone.svg"
                                            width: ScreenTools.defaultFontPixelHeight * 1.55
                                            x: profileChart.iconX - (width * 0.5)
                                            y: profileChart.iconY
                                            z: 100
                                        }

                                        MouseArea {
                                            function updateProgress(mouseX) {
                                                const ratio = (mouseX - profileChart.plotLeft) / Math.max(profileChart.plotWidth, 1);
                                                root._profilePlaybackActive = false;
                                                root._profileProgress = Math.max(0, Math.min(1, ratio));
                                            }

                                            anchors.fill: parent
                                            hoverEnabled: true

                                            onPositionChanged: mouse => {
                                                if (pressed) {
                                                    updateProgress(mouse.x);
                                                }
                                            }
                                            onPressed: mouse => updateProgress(mouse.x)
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
