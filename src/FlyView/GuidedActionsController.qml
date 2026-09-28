import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtLocation
import QtPositioning
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightMap

/// This provides the smarts behind the guided mode commands, minus the user interface. This way you can change UI
/// without affecting the underlying functionality.
Item {
    id: _root

    property var missionController
    property var confirmDialog
    property var guidedValueSlider
    property var fwdFlightGotoMapCircle
    property var orbitMapCircle
    property bool suppressAutomaticMissionPopups: false

    readonly property string emergencyStopTitle:            qsTr("EMERGENCY STOP")
    readonly property string armTitle:                      qsTr("Arm")
    readonly property string mvArmTitle:                    qsTr("Arm (MV)")
    readonly property string forceArmTitle:                 qsTr("Force Arm")
    readonly property string disarmTitle:                   qsTr("Disarm")
    readonly property string mvDisarmTitle:                 qsTr("Disarm (MV)")
    readonly property string rtlTitle:                      qsTr("返航")
    readonly property string takeoffTitle:                  qsTr("Takeoff")
    readonly property string landTitle:                     qsTr("立即降落")
    readonly property string startMissionTitle:             qsTr("Start Mission")
    readonly property string mvStartMissionTitle:           qsTr("Start Mission (MV)")
    readonly property string continueMissionTitle:          qsTr("继续任务")
    readonly property string resumeMissionUploadFailTitle:  qsTr("Resume FAILED")
    readonly property string pauseTitle:                    qsTr("暂停")
    readonly property string mvPauseTitle:                  qsTr("Pause (MV)")
    readonly property string changeAltTitle:                qsTr("Change Altitude")
    readonly property string changeLoiterRadiusTitle:       qsTr("Change Loiter Radius")
    readonly property string changeCruiseSpeedTitle:        qsTr("Change Max Ground Speed")
    readonly property string changeAirspeedTitle:           qsTr("Change Airspeed")
    readonly property string orbitTitle:                    qsTr("Orbit")
    readonly property string landAbortTitle:                qsTr("Land Abort")
    readonly property string setWaypointTitle:              qsTr("Set Waypoint")
    readonly property string gotoTitle:                     qsTr("Go To Location")
    readonly property string roiTitle:                      qsTr("ROI")
    readonly property string setHomeTitle:                  qsTr("Set Home")
    readonly property string setEstimatorOriginTitle:       qsTr("Set Estimator Origin")
    readonly property string setFlightMode:                 qsTr("Set Flight Mode")
    readonly property string changeHeadingTitle:            qsTr("Change Heading")

    readonly property string armMessage:                        qsTr("Arm the vehicle.")
    readonly property string mvArmMessage:                      qsTr("Arm selected vehicles.")
    readonly property string forceArmMessage:                   qsTr("WARNING: This will force arming of the vehicle bypassing any safety checks.")
    readonly property string disarmMessage:                     qsTr("Disarm the vehicle")
    readonly property string mvDisarmMessage:                   qsTr("Disarm selected vehicles.")
    readonly property string emergencyStopMessage:              qsTr("WARNING: THIS WILL STOP ALL MOTORS. IF VEHICLE IS CURRENTLY IN THE AIR IT WILL CRASH.")
    readonly property string takeoffMessage:                    qsTr("Takeoff and hold position")
    readonly property string startMissionMessage:               qsTr("Start the current mission")
    readonly property string mvStartMissionMessage:             qsTr("Start the current mission for selected vehicles")
    readonly property string continueMissionMessage:            qsTr("从当前航点继续执行任务")
    readonly property string resumeMissionUploadFailMessage:    qsTr("Upload of resume mission failed. Confirm to retry upload")
    readonly property string landMessage:                       qsTr("飞行器将进入 Land 模式并持续下降至落地，请确认下方区域安全")
    readonly property string rtlMessage:                        qsTr("返回起飞点或 Home 点")
    readonly property string changeAltMessage:                  qsTr("Change the altitude of the vehicle up or down")
    readonly property string changeLoiterRadiusMessage:         qsTr("Change the forward flight loiter radius")
    readonly property string changeCruiseSpeedMessage:          qsTr("Change the maximum horizontal cruise speed")
    readonly property string changeAirspeedMessage:             qsTr("Change the equivalent airspeed setpoint")
    readonly property string gotoMessage:                       qsTr("Move the vehicle to the specified location")
             property string setWaypointMessage:                qsTr("Adjust current waypoint to %1").arg(_actionData)
    readonly property string orbitMessage:                      qsTr("Orbit the vehicle around the specified location")
    readonly property string landAbortMessage:                  qsTr("Abort the landing sequence")
    readonly property string pauseMessage:                      qsTr("在当前位置暂停并保持")
    readonly property string mvPauseMessage:                    qsTr("Pause selected vehicles at their current position")
    readonly property string roiMessage:                        qsTr("Make the specified location a Region Of Interest")
    readonly property string setHomeMessage:                    qsTr("Set vehicle home as the specified location. This will affect Return to Home position")
    readonly property string setEstimatorOriginMessage:         qsTr("Make the specified location the estimator origin")
    readonly property string setFlightModeMessage:              qsTr("Set the vehicle flight mode to %1").arg(_actionData)
    readonly property string changeHeadingMessage:              qsTr("Set the vehicle heading towards the specified location")

    readonly property int actionRTL:                        1
    readonly property int actionLand:                       2
    readonly property int actionTakeoff:                    3
    readonly property int actionArm:                        4
    readonly property int actionDisarm:                     5
    readonly property int actionEmergencyStop:              6
    readonly property int actionChangeAlt:                  7
    readonly property int actionGoto:                       8
    readonly property int actionSetWaypoint:                9
    readonly property int actionOrbit:                      10
    readonly property int actionLandAbort:                  11
    readonly property int actionStartMission:               12
    readonly property int actionContinueMission:            13
    readonly property int actionResumeMission:              14
    readonly property int _actionUnused:                    15
    readonly property int actionResumeMissionUploadFail:    16
    readonly property int actionPause:                      17
    readonly property int actionMVPause:                    18
    readonly property int actionMVStartMission:             19
    readonly property int actionROI:                        20
    readonly property int actionForceArm:                   21
    readonly property int actionChangeSpeed:                22
    readonly property int actionSetHome:                    24
    readonly property int actionSetEstimatorOrigin:         25
    readonly property int actionSetFlightMode:              26
    readonly property int actionChangeHeading:              27
    readonly property int actionMVArm:                      28
    readonly property int actionMVDisarm:                   29
    readonly property int actionChangeLoiterRadius:         30

    readonly property int customActionStart:                10000 // Custom actions ids should start here so that they don't collide with the built in actions

    property var    _activeVehicle:             QGroundControl.multiVehicleManager.activeVehicle
    property var    _flyViewSettings:           QGroundControl.settingsManager.flyViewSettings
    property var    _unitsConversion:           QGroundControl.unitsConversion
    property bool   _useChecklist:              QGroundControl.settingsManager.appSettings.useChecklist.rawValue && QGroundControl.corePlugin.options.preFlightChecklistUrl.toString().length
    property bool   _enforceChecklist:          _useChecklist && QGroundControl.settingsManager.appSettings.enforceChecklist.rawValue
    property bool   _checklistPassed:           _activeVehicle ? (_useChecklist ? (_enforceChecklist ? _activeVehicle.checkListState === Vehicle.CheckListPassed : true) : true) : true
    property var    _readiness:                 _activeVehicle ? _activeVehicle.readiness : null
    property bool   _canArm:                    _checklistPassed && !!(_readiness && _readiness.canRequestArm)
    property bool   _canTakeoff:                _checklistPassed && !!(_readiness && _readiness.canRequestTakeoff)
    property bool   _canStartMission:           _checklistPassed && !!(_readiness && _readiness.canRequestMissionStart)
    property bool   _initialConnectComplete:    _activeVehicle ? _activeVehicle.initialConnectComplete : false

    property bool showEmergenyStop:         _guidedActionsEnabled && !_hideEmergenyStop && _vehicleArmed && _vehicleFlying
    property bool showArm:                  _guidedActionsEnabled && !_vehicleArmed && _canArm
    property bool showForceArm:             _guidedActionsEnabled && !_vehicleArmed
    property bool showDisarm:               _guidedActionsEnabled && _vehicleArmed && !_vehicleFlying
    property bool showRTL:                  _guidedActionsEnabled && _vehicleArmed && __guidedModeSupported && _vehicleFlying && !_vehicleInRTLMode
    property bool showTakeoff:              _guidedActionsEnabled && (__guidedTakeoffWithAltitudeSupported || __guidedTakeoffWithoutAltitudeSupported) && !_vehicleFlying && _canTakeoff
    property bool showLand:                 _guidedActionsEnabled && __guidedModeSupported && _vehicleArmed && !__fixedWing && !_vehicleInLandMode
    property bool showStartMission:         _guidedActionsEnabled && _missionAvailable && !_missionActive && !_vehicleFlying && _canStartMission
    property bool _hasRemainingMissionForContinue: _currentMissionIndex < _visualItemsCount - 1 || _vehiclePaused
    property bool showContinueMission:      _guidedActionsEnabled && _missionAvailable && !_missionActive && _vehicleArmed && _vehicleFlying && !!(_readiness && _readiness.canRequestMissionResume) && _hasRemainingMissionForContinue
    property bool showPause:                _guidedActionsEnabled && _vehicleArmed && __pauseVehicleSupported && _vehicleFlying && !_vehiclePaused && !_fixedWingOnApproach
    property bool showChangeAlt:            _guidedActionsEnabled && _vehicleFlying && __guidedModeSupported && _vehicleArmed && !_missionActive
    property bool showChangeLoiterRadius:   _guidedActionsEnabled && _vehicleFlying && __guidedModeSupported && _vehicleArmed && !_missionActive && _vehicleInFwdFlight && __fwdFlightGotoMapCircleVisible
    property bool showChangeSpeed:          _guidedActionsEnabled && _vehicleFlying && __guidedModeSupported && _vehicleArmed && !_missionActive && _speedLimitsAvailable
    property bool showOrbit:                _guidedActionsEnabled && _vehicleFlying && __orbitSupported && !_missionActive && __homePositionReady
    property bool showROI:                  _guidedActionsEnabled && _vehicleFlying && __roiSupported
    property bool showLandAbort:            _guidedActionsEnabled && _vehicleFlying && _fixedWingOnApproach
    property bool showGotoLocation:         _guidedActionsEnabled && _vehicleFlying
    property bool showSetHome:              _guidedActionsEnabled
    property bool showSetEstimatorOrigin:   _activeVehicle && !(_activeVehicle.sensorsPresentBits & Vehicle.SysStatusSensorGPS)
    property bool showChangeHeading:        _guidedActionsEnabled && _vehicleFlying

    property string changeSpeedTitle:   _vehicleInFwdFlight ? changeAirspeedTitle : changeCruiseSpeedTitle
    property string changeSpeedMessage: _vehicleInFwdFlight ? changeAirspeedMessage : changeCruiseSpeedMessage

    // Note: The '_visualItemsCount - 2' is a hack to not trigger resume mission when a mission ends with an RTL item
    property bool showResumeMission:    _activeVehicle && !_vehicleArmed && _vehicleWasFlying && _missionAvailable && _resumeMissionIndex > 0 && (_resumeMissionIndex < _visualItemsCount - 2)

    property bool guidedUIVisible:          !!(confirmDialog && confirmDialog.visible)

    property var    _corePlugin:            QGroundControl.corePlugin
    property var    _corePluginOptions:     QGroundControl.corePlugin.options
    property bool   _guidedActionsEnabled:  (!ScreenTools.isDebug && _corePluginOptions.guidedActionsRequireRCRSSI && _activeVehicle) ? _rcRSSIAvailable : !!_activeVehicle
    property string _flightMode:            _activeVehicle ? _activeVehicle.flightMode : ""
    property bool   _missionAvailable:      missionController ? missionController.containsItems : false
    property bool   _missionActive:         _activeVehicle ? _vehicleArmed && (_vehicleInLandMode || _vehicleInRTLMode || _vehicleInMissionMode) : false
    property bool   _vehicleArmed:          _activeVehicle ? _activeVehicle.armed  : false
    property bool   _vehicleFlying:         _activeVehicle ? _activeVehicle.flying  : false
    property bool   _vehicleLanding:        _activeVehicle ? _activeVehicle.landing  : false
    property bool   _vehiclePaused:         false
    property bool   _vehicleInMissionMode:  false
    property bool   _vehicleInRTLMode:      false
    property bool   _vehicleInLandMode:     false
    property int    _visualItemsCount:      missionController && missionController.visualItems ? missionController.visualItems.count : 0
    property int    _currentMissionIndex:   missionController ? missionController.currentMissionIndex : -1
    property int    _resumeMissionIndex:    missionController ? missionController.resumeMissionIndex : -1
    property bool   _hideEmergenyStop:      !_corePluginOptions.flyView.guidedBarShowEmergencyStop
    property bool   _hideOrbit:             !_corePluginOptions.flyView.guidedBarShowOrbit
    property bool   _hideROI:               !_corePluginOptions.flyView.guidedBarShowROI
    property bool   _vehicleWasFlying:      false
    property bool   _rcRSSIAvailable:       _activeVehicle ? _activeVehicle.rcRSSI > 0 && _activeVehicle.rcRSSI <= 100 : false
    property bool   _fixedWingOnApproach:   _activeVehicle ? _activeVehicle.fixedWing && _vehicleLanding : false
    property bool   _vehicleInFwdFlight:    _activeVehicle ? _activeVehicle.inFwdFlight : false
    property bool  _speedLimitsAvailable:   _activeVehicle && ((_vehicleInFwdFlight && _activeVehicle.haveFWSpeedLimits) || (!_vehicleInFwdFlight && _activeVehicle.haveMRSpeedLimits))

    // You can turn on log output for GuidedActionsController by turning on GuidedActionsControllerLog category
    property bool __guidedModeSupported:    _activeVehicle ? _activeVehicle.supports.guidedMode : false
    property bool __guidedTakeoffWithAltitudeSupported: _activeVehicle ? _activeVehicle.supports.guidedTakeoffWithAltitude : false
    property bool __guidedTakeoffWithoutAltitudeSupported: _activeVehicle ? _activeVehicle.supports.guidedTakeoffWithoutAltitude : false
    property bool __pauseVehicleSupported:  _activeVehicle ? _activeVehicle.supports.pauseVehicle : false
    property bool __smartRTLSupported:       _activeVehicle ? _activeVehicle.supports.smartRTL : false
    property bool __roiSupported:           _activeVehicle ? !_hideROI && _activeVehicle.supports.roiMode : false
    property bool __orbitSupported:         _activeVehicle ? !_hideOrbit && _activeVehicle.supports.orbitMode : false
    property bool __fixedWing:              _activeVehicle ? _activeVehicle.fixedWing : false
    property bool __homePositionReady:      _activeVehicle && _activeVehicle.homePosition ? _activeVehicle.homePosition.isValid && !isNaN(_activeVehicle.homePosition.altitude) : false
    property bool __fwdFlightGotoMapCircleVisible: fwdFlightGotoMapCircle ? fwdFlightGotoMapCircle.visible : false
    property bool __flightMode:             _flightMode

    // Allow custom builds to add custom actions by overriding CustomGuidedActionsController.qml
    CustomGuidedActionsController {
        id: customController
    }
    property var _customController: customController

    function _isGuidedActionsControllerLogEnabled() {
        return QGroundControl.categoryLoggingOn("GuidedActionsControllerLog")
    }

    function _outputState() {
        if (_isGuidedActionsControllerLogEnabled()) {
            console.log(qsTr("_activeVehicle(%1) _vehicleArmed(%2) guidedModeSupported(%3) _vehicleFlying(%4) _vehicleWasFlying(%5) _vehicleInRTLMode(%6) pauseVehicleSupported(%7) _vehiclePaused(%8) _flightMode(%9) _visualItemsCount(%10) roiSupported(%11) orbitSupported(%12) _missionActive(%13) _hideROI(%14) _hideOrbit(%15)").arg(_activeVehicle ? 1 : 0).arg(_vehicleArmed ? 1 : 0).arg(__guidedModeSupported ? 1 : 0).arg(_vehicleFlying ? 1 : 0).arg(_vehicleWasFlying ? 1 : 0).arg(_vehicleInRTLMode ? 1 : 0).arg(__pauseVehicleSupported ? 1 : 0).arg(_vehiclePaused ? 1 : 0).arg(_flightMode).arg(_visualItemsCount).arg(__roiSupported).arg(__orbitSupported).arg(_missionActive).arg(_hideROI).arg(_hideOrbit))
        }
    }

    function _actionRequiresActiveVehicle(actionCode) {
        switch (actionCode) {
        case actionMVArm:
        case actionMVDisarm:
        case actionMVStartMission:
        case actionMVPause:
            return false
        default:
            return actionCode < customActionStart
        }
    }

    function setupSlider(actionCode) {
        if (!_activeVehicle || !guidedValueSlider) {
            return
        }
        if (actionCode === actionTakeoff) {
            guidedValueSlider.setupSlider(
                GuidedValueSlider.SliderType.Takeoff,
                _unitsConversion.metersToAppSettingsVerticalDistanceUnits(_activeVehicle.minimumTakeoffAltitudeMeters()),
                _flyViewSettings.guidedMaximumAltitude.value,
                _unitsConversion.metersToAppSettingsVerticalDistanceUnits(_activeVehicle.minimumTakeoffAltitudeMeters()),
                qsTr("Height (rel)"))
        } else if (actionCode === actionChangeSpeed) {
            if (_vehicleInFwdFlight) {
                guidedValueSlider.setupSlider(
                    GuidedValueSlider.SliderType.Speed,
                    _unitsConversion.metersSecondToAppSettingsSpeedUnits(_activeVehicle.minimumEquivalentAirspeed()).toFixed(1),
                    _unitsConversion.metersSecondToAppSettingsSpeedUnits(_activeVehicle.maximumEquivalentAirspeed()).toFixed(1),
                    _unitsConversion.metersSecondToAppSettingsSpeedUnits(_activeVehicle.airSpeed.rawValue),
                    qsTr("Airspeed"))
            } else if (!_vehicleInFwdFlight && _activeVehicle.haveMRSpeedLimits) {
                guidedValueSlider.setupSlider(
                    GuidedValueSlider.SliderType.Speed,
                    _unitsConversion.metersSecondToAppSettingsSpeedUnits(0.1).toFixed(1),
                    _unitsConversion.metersSecondToAppSettingsSpeedUnits(_activeVehicle.maximumHorizontalSpeedMultirotorMetersSecond()).toFixed(1),
                    _unitsConversion.metersSecondToAppSettingsSpeedUnits(_activeVehicle.maximumHorizontalSpeedMultirotorMetersSecond()/2).toFixed(1),
                    qsTr("Speed"))
            } else {
                console.error("setupSlider called for inapproproate change speed action", _vehicleInFwdFlight, _activeVehicle ? _activeVehicle.haveMRSpeedLimits : false)
            }
        } else if (actionCode === actionChangeAlt || actionCode === actionOrbit || actionCode === actionGoto || actionCode === actionPause) {
            guidedValueSlider.setupSlider(
                GuidedValueSlider.SliderType.Altitude,
                _flyViewSettings.guidedMinimumAltitude.value,
                _flyViewSettings.guidedMaximumAltitude.value,
                _activeVehicle.altitudeRelative.value,
                qsTr("Alt (rel)"))
        }
    }

    on_ActiveVehicleChanged: {
        _vehicleWasFlying = false
        closeAll()
        _outputState()
    }

    Component.onCompleted:              _outputState()
    on_VehicleArmedChanged:             _outputState()
    on_VehicleInRTLModeChanged:         _outputState()
    on_VehiclePausedChanged:            _outputState()
    on__FlightModeChanged:              _outputState()
    on__GuidedModeSupportedChanged:     _outputState()
    on__PauseVehicleSupportedChanged:   _outputState()
    on__RoiSupportedChanged:            _outputState()
    on__OrbitSupportedChanged:          _outputState()
    on_VisualItemsCountChanged:         _outputState()
    on_MissionActiveChanged:            _outputState()

    on_CurrentMissionIndexChanged: {
        if (_isGuidedActionsControllerLogEnabled()) {
            console.log("_currentMissionIndex", _currentMissionIndex)
        }
    }
    on_ResumeMissionIndexChanged: {
        if (_isGuidedActionsControllerLogEnabled()) {
            console.log("_resumeMissionIndex", _resumeMissionIndex)
        }
    }
    onShowResumeMissionChanged: {
        if (_isGuidedActionsControllerLogEnabled()) {
            console.log("showResumeMission", showResumeMission)
        }
        _outputState()
    }
    onShowStartMissionChanged: {
        if (_isGuidedActionsControllerLogEnabled()) {
            console.log("showStartMission", showStartMission)
        }
        _outputState()
        if (showStartMission &&
            !suppressAutomaticMissionPopups &&
            _flyViewSettings.enableAutomaticMissionPopups.rawValue) {
            confirmAction(actionStartMission)
        }
    }
    onShowContinueMissionChanged: {
        if (_isGuidedActionsControllerLogEnabled()) {
            console.log("showContinueMission", showContinueMission)
        }
        _outputState()
        if (showContinueMission &&
            !suppressAutomaticMissionPopups &&
            _flyViewSettings.enableAutomaticMissionPopups.rawValue) {
            confirmAction(actionContinueMission)
        }
    }
    onShowRTLChanged: {
        if (_isGuidedActionsControllerLogEnabled()) {
            console.log("showRTL", showRTL)
        }
        _outputState()
    }
    onShowChangeAltChanged: {
        if (_isGuidedActionsControllerLogEnabled()) {
            console.log("showChangeAlt", showChangeAlt)
        }
        _outputState()
    }
    onShowROIChanged: {
        if (_isGuidedActionsControllerLogEnabled()) {
            console.log("showROI", showROI)
        }
        _outputState()
    }
    onShowOrbitChanged: {
        if (_isGuidedActionsControllerLogEnabled()) {
            console.log("showOrbit", showOrbit)
        }
        _outputState()
    }
    onShowGotoLocationChanged: {
        if (_isGuidedActionsControllerLogEnabled()) {
            console.log("showGotoLocation", showGotoLocation)
        }
        _outputState()
    }
    onShowLandAbortChanged: {
        if (showLandAbort) {
            confirmAction(actionLandAbort)
        }
    }

    on_VehicleFlyingChanged: {
        _outputState()
        if (_vehicleFlying) {
            // We use _vehicleWasFlying to help trigger Resume Mission only if the vehicle actually flew.
            // Otherwise it may trigger during the Start Mission sequence due to signal ordering or armed and resume mission index.
            _vehicleWasFlying = true
        }
    }

    property var _actionData

    on_FlightModeChanged: {
        _vehiclePaused =        _activeVehicle ? _flightMode === _activeVehicle.pauseFlightMode : false
        _vehicleInRTLMode =     _activeVehicle ? _flightMode === _activeVehicle.rtlFlightMode || _flightMode === _activeVehicle.smartRTLFlightMode : false
        _vehicleInLandMode =    _activeVehicle ? _flightMode === _activeVehicle.landFlightMode : false
        _vehicleInMissionMode = _activeVehicle ? _flightMode === _activeVehicle.missionFlightMode : false // Must be last to get correct signalling for showStartMission popups
    }

    Connections {
        target:                     missionController
        function onResumeMissionUploadFail() { confirmAction(actionResumeMissionUploadFail) }
    }

    Connections {
        target:                             mainWindow
        function onArmVehicleRequest() { armVehicleRequest() }
        function onForceArmVehicleRequest() { forceArmVehicleRequest() }
        function onDisarmVehicleRequest() { disarmVehicleRequest() }
    }

    function armVehicleRequest() {
        confirmAction(actionArm)
    }

    function forceArmVehicleRequest() {
        confirmAction(actionForceArm)
    }

    function disarmVehicleRequest() {
        if (showEmergenyStop) {
            confirmAction(actionEmergencyStop)
        } else {
            confirmAction(actionDisarm)
        }

    }

    function closeAll() {
        if (confirmDialog) {
            confirmDialog.visible = false
        }
        if (guidedValueSlider) {
            guidedValueSlider.visible = false
        }
    }

    // Called when an action is about to be executed in order to confirm
    function confirmAction(actionCode, actionData, mapIndicator) {
        if (!confirmDialog || (_actionRequiresActiveVehicle(actionCode) && !_activeVehicle)) {
            return
        }
        var showImmediate = true
        closeAll()
        confirmDialog.action = actionCode
        confirmDialog.actionData = actionData
        confirmDialog.hideTrigger = true
        confirmDialog.mapIndicator = mapIndicator
        confirmDialog.optionText = ""
        _actionData = actionData

        setupSlider(actionCode)

        switch (actionCode) {
        case actionArm:
            if (_vehicleFlying || !_guidedActionsEnabled) {
                return
            }
            confirmDialog.title = armTitle
            confirmDialog.message = armMessage
            confirmDialog.hideTrigger = Qt.binding(function() { return !showArm })
            break;
        case actionMVArm:
            confirmDialog.title = mvArmTitle
            confirmDialog.message = mvArmMessage
            confirmDialog.hideTrigger = true
            break;
        case actionForceArm:
            confirmDialog.title = forceArmTitle
            confirmDialog.message = forceArmMessage
            confirmDialog.hideTrigger = Qt.binding(function() { return !showForceArm })
            break;
        case actionDisarm:
            if (_vehicleFlying) {
                return
            }
            confirmDialog.title = disarmTitle
            confirmDialog.message = disarmMessage
            confirmDialog.hideTrigger = Qt.binding(function() { return !showDisarm })
            break;
        case actionMVDisarm:
            confirmDialog.title = mvDisarmTitle
            confirmDialog.message = mvDisarmMessage
            confirmDialog.hideTrigger = true
            break;
        case actionEmergencyStop:
            confirmDialog.title = emergencyStopTitle
            confirmDialog.message = emergencyStopMessage
            confirmDialog.hideTrigger = Qt.binding(function() { return !showEmergenyStop })
            break;
        case actionTakeoff:
            confirmDialog.title = takeoffTitle
            confirmDialog.message = takeoffMessage
            confirmDialog.hideTrigger = Qt.binding(function() { return !showTakeoff })
            if (guidedValueSlider) {
                guidedValueSlider.visible = __guidedTakeoffWithAltitudeSupported
            }
            break;
        case actionStartMission:
            showImmediate = false
            confirmDialog.title = startMissionTitle
            confirmDialog.message = startMissionMessage
            confirmDialog.hideTrigger = Qt.binding(function() { return !showStartMission })
            break;
        case actionMVStartMission:
            confirmDialog.title = mvStartMissionTitle
            confirmDialog.message = mvStartMissionMessage
            confirmDialog.hideTrigger = true
            break;
        case actionContinueMission:
            confirmDialog.title = continueMissionTitle
            confirmDialog.message = continueMissionMessage
            confirmDialog.hideTrigger = Qt.binding(function() { return !showContinueMission })
            break;
        case actionResumeMission:
            // Resume Mission is handled in mission end dialog
            return
        case actionResumeMissionUploadFail:
            confirmDialog.title = resumeMissionUploadFailTitle
            confirmDialog.message = resumeMissionUploadFailMessage
            confirmDialog.hideTrigger = Qt.binding(function() { return !showResumeMission })
            break;
        case actionLand:
            confirmDialog.title = landTitle
            confirmDialog.message = landMessage
            confirmDialog.hideTrigger = Qt.binding(function() { return !showLand })
            break;
        case actionRTL:
            confirmDialog.title = rtlTitle
            confirmDialog.message = rtlMessage
            if (__smartRTLSupported) {
                confirmDialog.optionText = qsTr("Smart RTL")
                confirmDialog.optionChecked = false
            }
            confirmDialog.hideTrigger = Qt.binding(function() { return !showRTL })
            break;
        case actionChangeAlt:
            confirmDialog.title = changeAltTitle
            confirmDialog.message = changeAltMessage
            confirmDialog.hideTrigger = Qt.binding(function() { return !showChangeAlt })
            if (guidedValueSlider) {
                guidedValueSlider.visible = true
            }
            break;
        case actionChangeLoiterRadius:
            confirmDialog.title = changeLoiterRadiusTitle
            confirmDialog.message = changeLoiterRadiusMessage
            confirmDialog.hideTrigger = Qt.binding(function() { return !showChangeLoiterRadius })
            confirmDialog.mapIndicator = fwdFlightGotoMapCircle
            if (fwdFlightGotoMapCircle) {
                fwdFlightGotoMapCircle.startLoiterRadiusEdit()
            }
            break
        case actionGoto:
            confirmDialog.title = gotoTitle
            confirmDialog.message = gotoMessage
            confirmDialog.hideTrigger = Qt.binding(function() { return !showGotoLocation })
            break;
        case actionSetWaypoint:
            confirmDialog.title = setWaypointTitle
            confirmDialog.message = setWaypointMessage
            break;
        case actionOrbit:
            confirmDialog.title = orbitTitle
            confirmDialog.message = orbitMessage
            confirmDialog.hideTrigger = Qt.binding(function() { return !showOrbit })
            if (guidedValueSlider) {
                guidedValueSlider.visible = true
            }
            break;
        case actionLandAbort:
            confirmDialog.title = landAbortTitle
            confirmDialog.message = landAbortMessage
            confirmDialog.hideTrigger = Qt.binding(function() { return !showLandAbort })
            break;
        case actionPause:
            confirmDialog.title = pauseTitle
            confirmDialog.message = pauseMessage
            confirmDialog.hideTrigger = Qt.binding(function() { return !showPause })
            break;
        case actionMVPause:
            confirmDialog.title = mvPauseTitle
            confirmDialog.message = mvPauseMessage
            confirmDialog.hideTrigger = true
            break;
        case actionROI:
            confirmDialog.title = roiTitle
            confirmDialog.message = roiMessage
            confirmDialog.hideTrigger = Qt.binding(function() { return !showROI })
            break;
        case actionChangeSpeed:
            confirmDialog.hideTrigger = true
            confirmDialog.title = changeSpeedTitle
            confirmDialog.message = changeSpeedMessage
            if (guidedValueSlider) {
                guidedValueSlider.visible = true
            }
            break
        case actionSetHome:
            confirmDialog.title = setHomeTitle
            confirmDialog.message = setHomeMessage
            confirmDialog.hideTrigger = Qt.binding(function() { return !showSetHome })
            break
        case actionSetEstimatorOrigin:
            confirmDialog.title = setEstimatorOriginTitle
            confirmDialog.message = setEstimatorOriginMessage
            break
        case actionSetFlightMode:
            confirmDialog.title = setFlightMode
            confirmDialog.message = setFlightModeMessage
            break
        case actionChangeHeading:
            confirmDialog.title = changeHeadingTitle
            confirmDialog.message = changeHeadingMessage
            break
        default:
            if (!customController.customConfirmAction(actionCode, actionData, mapIndicator, confirmDialog)) {
                console.warn("Unknown actionCode", actionCode)
                return
            }
        }
        confirmDialog.show(showImmediate)
    }

    // Executes the specified action
    // Returns false if the action failed and any associated map indicator should be restored
    function executeAction(actionCode, actionData, sliderOutputValue, optionChecked) {
        if (_actionRequiresActiveVehicle(actionCode) && !_activeVehicle) {
            return false
        }

        var i;
        var selectedVehicles;
        switch (actionCode) {
        case actionRTL:
            _activeVehicle.guidedModeRTL(optionChecked)
            break
        case actionLand:
            _activeVehicle.guidedModeLand()
            break
        case actionTakeoff:
            if (__guidedTakeoffWithAltitudeSupported) {
                var valueInMeters = _unitsConversion.appSettingsVerticalDistanceUnitsToMeters(sliderOutputValue)
                _activeVehicle.requestTakeoff(valueInMeters, true)
            } else {
                _activeVehicle.requestTakeoff(0, true)
            }
            break
        case actionResumeMission:
        case actionResumeMissionUploadFail:
            if (!missionController) {
                return false
            }
            missionController.resumeMission(_resumeMissionIndex)
            break
        case actionStartMission:
            _activeVehicle.requestStartMission(true)
            break
        case actionContinueMission:
            _activeVehicle.requestAirborneMissionResume(true)
            break
        case actionMVStartMission:
            selectedVehicles = QGroundControl.multiVehicleManager.selectedVehicles
            if (!selectedVehicles) {
                return false
            }
            for (i = 0; i < selectedVehicles.count; i++) {
                var vehicle = selectedVehicles.get(i)
                if (vehicle && vehicle.armed === true){
                    if (vehicle.flying) {
                        vehicle.requestAirborneMissionResume(true)
                    } else {
                        vehicle.requestStartMission(true)
                    }
                }
            }
            break
        case actionArm:
            _activeVehicle.requestArm(true)
            break
        case actionMVArm:
            selectedVehicles = QGroundControl.multiVehicleManager.selectedVehicles
            if (!selectedVehicles) {
                return false
            }
            for (i = 0; i < selectedVehicles.count; i++) {
                var armVehicle = selectedVehicles.get(i)
                if (armVehicle) {
                    armVehicle.requestArm(true)
                }
            }
            break
        case actionForceArm:
            _activeVehicle.forceArm()
            break
        case actionDisarm:
            _activeVehicle.armed = false
            break
        case actionMVDisarm:
            selectedVehicles = QGroundControl.multiVehicleManager.selectedVehicles
            if (!selectedVehicles) {
                return false
            }
            for (i = 0; i < selectedVehicles.count; i++) {
                var disarmVehicle = selectedVehicles.get(i)
                if (disarmVehicle) {
                    disarmVehicle.armed = false
                }
            }
            break
        case actionEmergencyStop:
            _activeVehicle.emergencyStop()
            break
        case actionChangeAlt:
            var valueInMeters = _unitsConversion.appSettingsVerticalDistanceUnitsToMeters(sliderOutputValue)
            var altitudeChangeInMeters = valueInMeters - _activeVehicle.altitudeRelative.rawValue
            _activeVehicle.guidedModeChangeAltitude(altitudeChangeInMeters, false /* pauseVehicle */)
            break
        case actionChangeLoiterRadius:
            if (!fwdFlightGotoMapCircle) {
                return false
            }
            if (!_activeVehicle.guidedModeGotoLocation(
                fwdFlightGotoMapCircle.coordinate,
                (fwdFlightGotoMapCircle.clockwiseRotation ? 1 : -1) *
                        Math.abs(fwdFlightGotoMapCircle.radius.rawValue)
            )) {
                return false
            }
            break
        case actionGoto:
            if (!_activeVehicle.guidedModeGotoLocation(
                actionData,
                _vehicleInFwdFlight /* forwardFlightLoiterRadius */
                    ? _flyViewSettings.forwardFlightGoToLocationLoiterRad.value
                    : 0
            )) {
                return false
            }
            break
        case actionSetWaypoint:
            _activeVehicle.setCurrentMissionSequence(actionData)
            break
        case actionOrbit:
            if (!orbitMapCircle || !__homePositionReady) {
                return false
            }
            var valueInMeters = _unitsConversion.appSettingsVerticalDistanceUnitsToMeters(sliderOutputValue)
            _activeVehicle.guidedModeOrbit(orbitMapCircle.center, orbitMapCircle.radius() * (orbitMapCircle.clockwiseRotation ? 1 : -1), _activeVehicle.homePosition.altitude + valueInMeters)
            break
        case actionLandAbort:
            _activeVehicle.abortLanding(50)     // hardcoded value for climbOutAltitude that is currently ignored
            break
        case actionPause:
            _activeVehicle.pauseVehicle()
            break
        case actionMVPause:
            selectedVehicles = QGroundControl.multiVehicleManager.selectedVehicles
            if (!selectedVehicles) {
                return false
            }
            for (i = 0; i < selectedVehicles.count; i++) {
                var pauseVehicle = selectedVehicles.get(i)
                if (pauseVehicle) {
                    pauseVehicle.pauseVehicle()
                }
            }
            break
        case actionROI:
            _activeVehicle.guidedModeROI(actionData)
            break
        case actionChangeSpeed:
            if (_activeVehicle) {
                // We need to convert back to m/s as that is what mavlink standard uses for MAV_CMD_DO_CHANGE_SPEED
                var metersSecondSpeed = _unitsConversion.appSettingsSpeedUnitsToMetersSecond(sliderOutputValue)
                if (_vehicleInFwdFlight) {
                   _activeVehicle.guidedModeChangeEquivalentAirspeedMetersSecond(metersSecondSpeed)
                } else {
                    _activeVehicle.guidedModeChangeGroundSpeedMetersSecond(metersSecondSpeed)
                }
            }
            break
        case actionSetHome:
            _activeVehicle.doSetHome(actionData)
            break
        case actionSetEstimatorOrigin:
            _activeVehicle.setEstimatorOrigin(actionData)
            break
        case actionSetFlightMode:
            _activeVehicle.flightMode = actionData
            break
        case actionChangeHeading:
            _activeVehicle.guidedModeChangeHeading(actionData)
            break
        default:
            if (!customController.customExecuteAction(actionCode, actionData, sliderOutputValue, optionChecked)) {
                console.warn(qsTr("Internal error: unknown actionCode"), actionCode)
                return false
            }
            break
        }
        return true
    }
}
