import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtLocation
import QtPositioning
import QtQuick.Layouts
import QtQuick.Window

import QGroundControl
import QGroundControl.FlightMap
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.FlyView
import QGroundControl.PlanView
import QGroundControl.Toolbar

Item {
    id: _root

    readonly property int   _decimalPlaces: 8
    readonly property real  _margin: ScreenTools.defaultFontPixelHeight * 0.5
    readonly property real  _toolsMargin: ScreenTools.defaultFontPixelWidth * 0.75
    readonly property real  _sidePanelWidth: width * 0.25
    readonly property real  _maxMissionSegmentLengthM: 50000
    readonly property color _selectedMissionGlowColor: Qt.rgba(0.52, 0.43, 0.96, 0.26)
    readonly property color _selectedMissionBandColor: Qt.rgba(0.56, 0.47, 0.92, 0.76)
    readonly property color _selectedMissionCoreColor: "#E8893D"

    property var    _planMasterController: planMasterController
    property var    _missionController: _planMasterController.missionController
    property var    _geoFenceController: _planMasterController.geoFenceController
    property var    _rallyPointController: _planMasterController.rallyPointController
    property var    _visualItems: _missionController.visualItems
    property int    _editingLayer: _layerMission
    property var    _appSettings: QGroundControl.settingsManager.appSettings
    property var    _planViewSettings: QGroundControl.settingsManager.planViewSettings
    property bool   _promptForPlanUsageShowing: false
    property bool   _addROIOnClick: false
    property bool   _addWaypointOnClick: false
    property bool   _homeTrackingMapCenter: true
    property bool   _updatingHomeFromMapCenter: false
    property var    _uploadStatusPanel: null
    property var    _uploadStatusSource: null
    property var    _patternDropPanel: null
    property bool   _toolStripUploadRequested: false
    property bool   _toolStripUploadInProgress: false
    property bool   _toolStripExpanded: true
    property bool   _promptForPlanUsageVehicleOffline: false
    property bool   _promptForPlanUsageDirtyForSave: false
    property bool   embeddedView: false

    readonly property bool _supportsSurveyPattern: _missionController.complexMissionItemNames.indexOf(_missionController.surveyComplexItemName) !== -1
    readonly property bool _supportsCorridorScanPattern: _missionController.complexMissionItemNames.indexOf(_missionController.corridorScanComplexItemName) !== -1
    readonly property bool _supportsStructureScanPattern: _missionController.complexMissionItemNames.indexOf(_missionController.structureScanComplexItemName) !== -1
    readonly property var _additionalComplexPatterns: {
        const additionalPatterns = []
        const excludedPatterns = [
            _missionController.surveyComplexItemName,
            _missionController.corridorScanComplexItemName,
            _missionController.structureScanComplexItemName
        ]
        for (let i = 0; i < _missionController.complexMissionItemNames.length; i++) {
            const patternName = _missionController.complexMissionItemNames[i]
            if (excludedPatterns.indexOf(patternName) === -1) {
                additionalPatterns.push(patternName)
            }
        }
        return additionalPatterns
    }
    readonly property bool _hasPatternChoices: _supportsSurveyPattern
                                                || _supportsCorridorScanPattern
                                                || _supportsStructureScanPattern
                                                || (_additionalComplexPatterns.length > 0)

    PlanEditorTheme { id: theme }

    function _displayComplexPatternName(patternName) {
        switch (patternName) {
        case _missionController.surveyComplexItemName:
            return qsTr("勘测")
        case _missionController.corridorScanComplexItemName:
            return qsTr("走廊扫描")
        case _missionController.structureScanComplexItemName:
            return qsTr("建筑扫描")
        default:
            return patternName
        }
    }

    readonly property int _layerMission: 1
    readonly property int _layerFence: 2
    readonly property int _layerRally: 3

    onVisibleChanged: {
        if(visible) {
            editorMap.zoomLevel = QGroundControl.flightMapZoom
            editorMap.center    = QGroundControl.mapDisplayCoordinate(QGroundControl.flightMapPosition)
        }
    }

    Connections {
        target: planToolBar
        function onToolbarButtonClicked() {
            _addWaypointOnClick = false
            _addROIOnClick = false
        }
    }

    Connections {
        target: _planMasterController

        function onSyncInProgressChanged() {
            if (!_toolStripUploadRequested) {
                return
            }

            if (_planMasterController.syncInProgress) {
                _toolStripUploadInProgress = true
                uploadStartWatchdog.stop()
                return
            }

            if (_toolStripUploadInProgress) {
                _toolStripUploadInProgress = false
                _toolStripUploadRequested = false

                if (!_planMasterController.dirtyForUpload) {
                    _openUploadStatusPanel(_uploadStatusSource,
                                           qsTr("Send To Vehicle"),
                                           qsTr("上传完成。"),
                                           null,
                                           qsTr("Ok"),
                                           false,
                                           1600)
                } else {
                    _openUploadStatusPanel(_uploadStatusSource,
                                           qsTr("Send To Vehicle"),
                                           qsTr("上传未完成。请查看飞行器消息了解详情。"))
                }
            }
        }
    }

    Timer {
        id: uploadStartWatchdog
        interval: 1500
        repeat: false
        onTriggered: {
            if (_toolStripUploadRequested && !_planMasterController.syncInProgress) {
                _toolStripUploadRequested = false
                _toolStripUploadInProgress = false
                _openUploadStatusPanel(_uploadStatusSource,
                                       qsTr("Send To Vehicle"),
                                       qsTr("无法开始上传。请检查飞行器连接状态后重试。"))
            }
        }
    }

    function mapCenter() {
        var coordinate = editorMap.center
        coordinate.latitude  = coordinate.latitude.toFixed(_decimalPlaces)
        coordinate.longitude = coordinate.longitude.toFixed(_decimalPlaces)
        coordinate.altitude  = coordinate.altitude.toFixed(_decimalPlaces)
        return coordinate
    }

    function missionLinePath(coord1, coord2) {
        if (!coord1 || !coord1.isValid || !coord2 || !coord2.isValid) {
            return []
        }

        const distance = coord1.distanceTo(coord2)
        if (distance <= _maxMissionSegmentLengthM) {
            return QGroundControl.mapDisplayCoordinates([coord1, coord2])
        }

        const pathPoints = [coord1]
        const numSegments = Math.ceil(distance / _maxMissionSegmentLengthM)

        for (let i = 1; i < numSegments; i++) {
            const segmentDist = (i * distance) / numSegments
            pathPoints.push(coord1.atDistanceAndAzimuth(segmentDist, coord1.azimuthTo(coord2)))
        }

        pathPoints.push(coord2)
        return QGroundControl.mapDisplayCoordinates(pathPoints)
    }

    function _closeUploadStatusPanel() {
        if (_uploadStatusPanel) {
            _uploadStatusPanel.close()
            _uploadStatusPanel = null
        }
    }

    function _closePatternPanel() {
        if (_patternDropPanel) {
            _patternDropPanel.close()
            _patternDropPanel = null
        }
    }

    function _openPatternPanel(source) {
        _closePatternPanel()

        if (!source) {
            return
        }

        let position = Qt.point(0, source.height / 2)
        position = source.mapToItem(globals.parent, position)

        _patternDropPanel = patternDropPanelComponent.createObject(mainWindow, {
            clickRect: Qt.rect(position.x, position.y, 0, 0)
        })
        Qt.callLater(function() {
            if (_patternDropPanel) {
                _patternDropPanel.open()
            }
        })
    }

    function _openUploadStatusPanel(source, title, message, confirmAction, confirmButtonText, busy, autoCloseMs) {
        _closeUploadStatusPanel()

        const panelSource = source || _uploadStatusSource
        if (panelSource) {
            _uploadStatusSource = panelSource
        }

        if (!panelSource) {
            QGroundControl.showMessageDialog(
                _root,
                title,
                message,
                confirmAction ? (Dialog.Ok | Dialog.Cancel) : Dialog.Ok,
                confirmAction || null
            )
            return
        }

        let position = Qt.point(0, panelSource.height / 2)
        position = panelSource.mapToItem(globals.parent, position)

        _uploadStatusPanel = uploadStatusDropPanelComponent.createObject(mainWindow, {
            clickRect: Qt.rect(position.x, position.y, 0, 0),
            uploadTitle: title,
            uploadMessage: message,
            confirmAction: confirmAction || null,
            confirmButtonText: confirmButtonText || qsTr("Ok"),
            uploadBusy: !!busy,
            autoCloseMs: autoCloseMs || 0
        })
        Qt.callLater(function() {
            if (_uploadStatusPanel) {
                _uploadStatusPanel.open()
            }
        })
    }

    function _triggerToolStripUpload(source) {
        _closeUploadStatusPanel()

        switch (_planMasterController.readyForSaveState()) {
        case VisualMissionItem.NotReadyForSaveData:
            _openUploadStatusPanel(source,
                                   qsTr("无法%1").arg(qsTr("上传")),
                                   qsTr("计划中有未完成的项目。请补全所有项目后重新%1。").arg(qsTr("上传")))
            return
        case VisualMissionItem.NotReadyForSaveTerrain:
            _openUploadStatusPanel(source,
                                   qsTr("无法%1").arg(qsTr("上传")),
                                   qsTr("计划正在等待服务器地形数据以计算正确高度。"))
            return
        }

        switch (_missionController.sendToVehiclePreCheck()) {
        case MissionController.SendToVehiclePreCheckStateOk:
            _toolStripUploadRequested = true
            _toolStripUploadInProgress = false
            _uploadStatusSource = source
            _openUploadStatusPanel(source,
                                   qsTr("Send To Vehicle"),
                                   qsTr("正在上传计划到飞行器..."),
                                   null,
                                   qsTr("Ok"),
                                   true)
            uploadStartWatchdog.restart()
            _planMasterController.sendToVehicle()
            return
        case MissionController.SendToVehiclePreCheckStateNoActiveVehicle:
            _openUploadStatusPanel(source,
                                   qsTr("Send To Vehicle"),
                                   qsTr("You must be connected to a vehicle in order to upload a Plan."))
            return
        case MissionController.SendToVehiclePreCheckStateActiveMission:
            _openUploadStatusPanel(source,
                                   qsTr("Send To Vehicle"),
                                   qsTr("上传新计划前必须先暂停当前任务。"))
            return
        case MissionController.SendToVehiclePreCheckStateFirwmareVehicleMismatch:
            _openUploadStatusPanel(source,
                                   qsTr("计划上传"),
                                   qsTr("此计划创建时使用的固件或机型与当前上传目标不一致，可能导致错误或异常行为。\n\n建议按当前固件和机型重新创建计划。\n\n点击“OK”仍然上传。"),
                                   function() { _planMasterController.sendToVehicle() })
            return
        }
    }

    function _triggerToolStripClear() {
        if (_planMasterController.syncInProgress || !_planMasterController.containsItems) {
            return
        }

        QGroundControl.showMessageDialog(
            _root,
            qsTr("清空航线"),
            qsTr("确定要移除计划编辑器中的所有项目吗？"),
            Dialog.Yes | Dialog.Cancel,
            function() { _planMasterController.removeAll() }
        )
    }

    MapFitFunctions {
        id: mapFitFunctions  // The name for this id cannot be changed without breaking references outside of this code. Beware!
        map: editorMap
        usePlannedHomePosition: true
        planMasterController: _planMasterController
    }

    PlanMasterController {
        id: planMasterController
        flyView: false

        Component.onCompleted: {
            _planMasterController.start()
            _missionController.setCurrentPlanViewSeqNum(0, true)
        }

        onPromptForPlanUsageOnVehicleChange: {
            if (!_promptForPlanUsageShowing) {
                _promptForPlanUsageVehicleOffline = _planMasterController.managerVehicle.isOfflineEditingVehicle
                _promptForPlanUsageDirtyForSave = _planMasterController.dirtyForSave
                _promptForPlanUsageShowing = true
                promptForPlanUsageOnVehicleChangePopupFactory.open()
            }
        }

        function waitingOnIncompleteDataMessage(save) {
            var saveOrUpload = save ? qsTr("保存") : qsTr("上传")
            QGroundControl.showMessageDialog(_root, qsTr("无法%1").arg(saveOrUpload), qsTr("计划中有未完成的项目。请补全所有项目后重新%1。").arg(saveOrUpload))
        }

        function waitingOnTerrainDataMessage(save) {
            var saveOrUpload = save ? qsTr("保存") : qsTr("上传")
            QGroundControl.showMessageDialog(_root, qsTr("无法%1").arg(saveOrUpload), qsTr("计划正在等待服务器地形数据以计算正确高度。"))
        }

        function checkReadyForSaveUpload(save) {
            if (readyForSaveState() == VisualMissionItem.NotReadyForSaveData) {
                waitingOnIncompleteDataMessage(save)
                return false
            } else if (readyForSaveState() == VisualMissionItem.NotReadyForSaveTerrain) {
                waitingOnTerrainDataMessage(save)
                return false
            }
            return true
        }

        function upload() {
            if (!checkReadyForSaveUpload(false /* save */)) {
                return
            }
            switch (_missionController.sendToVehiclePreCheck()) {
                case MissionController.SendToVehiclePreCheckStateOk: sendToVehicle()
                    break
                case MissionController.SendToVehiclePreCheckStateNoActiveVehicle: QGroundControl.showMessageDialog(_root, qsTr("发送到飞行器"), qsTr("必须连接飞行器后才能上传计划。"))
                    break
                case MissionController.SendToVehiclePreCheckStateActiveMission: QGroundControl.showMessageDialog(_root, qsTr("发送到飞行器"), qsTr("上传新计划前必须先暂停当前任务。"))
                    break
                case MissionController.SendToVehiclePreCheckStateFirwmareVehicleMismatch: QGroundControl.showMessageDialog(_root, qsTr("计划上传"),
                                                 qsTr("此计划创建时使用的固件或机型与当前上传目标不一致，可能导致错误或异常行为。\n\n建议按当前固件和机型重新创建计划。\n\n点击“OK”仍然上传。"),
                                                 Dialog.Ok | Dialog.Cancel,
                                                 function() { _planMasterController.sendToVehicle() })
                    break
            }
        }

        function loadFromSelectedFile() {
            fileDialog.title =          qsTr("选择计划文件")
            fileDialog.planFiles =      true
            fileDialog.nameFilters =    _planMasterController.loadNameFilters
            fileDialog.openForLoad()
        }

        function saveToSelectedFile() {
            if (!checkReadyForSaveUpload(true /* save */)) {
                return
            }
            fileDialog.title =          qsTr("保存计划")
            fileDialog.planFiles =      true
            fileDialog.nameFilters =    _planMasterController.saveNameFilters
            fileDialog.openForSave()
        }

        function fitViewportToItems() {
            mapFitFunctions.fitMapViewportToMissionItems()
        }

        function saveKmlToSelectedFile() {
            if (!checkReadyForSaveUpload(true /* save */)) {
                return
            }
            fileDialog.title =          qsTr("保存 KML")
            fileDialog.planFiles =      false
            fileDialog.nameFilters =    ShapeFileHelper.fileDialogKMLFilters
            fileDialog.openForSave()
        }
    }

    Connections {
        target: _missionController

        function onNewItemsFromVehicle() {
            if (_visualItems && _visualItems.count !== 1) {
                mapFitFunctions.fitMapViewportToMissionItems()
            }
            _missionController.setCurrentPlanViewSeqNum(0, true)
        }
    }

    // Stop tracking map center when the home position is changed externally (e.g. drag, file load)
    Connections {
        target: _visualItems.count > 0 ? _visualItems.get(0) : null
        function onCoordinateChanged() {
            if (!_updatingHomeFromMapCenter && !_planMasterController.containsItems) {
                _homeTrackingMapCenter = false
            }
        }
    }

    // Resume tracking when the plan becomes empty again
    Connections {
        target: _planMasterController
        function onContainsItemsChanged() {
            if (!_planMasterController.containsItems) {
                _homeTrackingMapCenter = true
                if (_visualItems.count > 0) {
                    _updatingHomeFromMapCenter = true
                    _visualItems.get(0).coordinate = editorMap.center
                    _updatingHomeFromMapCenter = false
                }
            }
        }
    }

    function insertSimpleItemAfterCurrent(coordinate) {
        var nextIndex = _missionController.currentPlanViewVIIndex + 1
        _missionController.insertSimpleMissionItem(coordinate, nextIndex, true /* makeCurrentItem */)
    }

    function insertROIAfterCurrent(coordinate) {
        var nextIndex = _missionController.currentPlanViewVIIndex + 1
        _missionController.insertROIMissionItem(coordinate, nextIndex, true /* makeCurrentItem */)
    }

    function insertCancelROIAfterCurrent() {
        var nextIndex = _missionController.currentPlanViewVIIndex + 1
        _missionController.insertCancelROIMissionItem(nextIndex, true /* makeCurrentItem */)
    }

    function insertComplexItemAfterCurrent(complexItemName) {
        var nextIndex = _missionController.currentPlanViewVIIndex + 1
        _missionController.insertComplexMissionItem(complexItemName, mapCenter(), nextIndex, true /* makeCurrentItem */)
    }

    function insertTakeoffItemAfterCurrent() {
        var nextIndex = _missionController.currentPlanViewVIIndex + 1
        _missionController.insertTakeoffItem(mapCenter(), nextIndex, true /* makeCurrentItem */)
    }

    function insertLandItemAfterCurrent() {
        var nextIndex = _missionController.currentPlanViewVIIndex + 1
        _missionController.insertLandItem(mapCenter(), nextIndex, true /* makeCurrentItem */)
    }

    function insertLandHereItemAfterCurrent() {
        var nextIndex = _missionController.currentPlanViewVIIndex + 1
        _missionController.insertLandHereItem(mapCenter(), nextIndex, true /* makeCurrentItem */)
    }

    QGCFileDialog {
        id: fileDialog
        folder: _appSettings ? _appSettings.missionSavePath : ""

        property bool planFiles: true    ///< true: working with plan files, false: working with kml file

        onAcceptedForSave: (file) => {
            if (planFiles) {
                if (_planMasterController.saveToFile(file)) {
                    close()
                }
            } else {
                _planMasterController.saveToKml(file)
                close()
            }
        }

        onAcceptedForLoad: (file) => {
            _planMasterController.loadFromFile(file)
            _planMasterController.fitViewportToItems()
            _missionController.setCurrentPlanViewSeqNum(0, true)
            close()
        }
    }

    PlanViewToolBar {
        id:                     planToolBar
        visible:                !_root.embeddedView
        height:                 visible ? ScreenTools.toolbarHeight : 0
        planMasterController:   _planMasterController
        showRallyPointsHelp:    _editingLayer === _layerRally
    }

    Item {
        id: mainPlanViewArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: planToolBar.bottom
        anchors.bottom: parent.bottom

        FlightMap {
            id: editorMap
            anchors.left: rightPanel.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            mapName: "MissionEditor"
            allowGCSLocationCenter: true
            allowVehicleLocationCenter: true
            planView: true

            zoomLevel: QGroundControl.flightMapZoom
            center: QGroundControl.flightMapPosition

            // This is the center rectangle of the map which is not obscured by tools
            property rect centerViewport: Qt.rect(_margin, _margin, Math.max(editorMap.width - _rightToolWidth - (_margin * 2), 0), (missionStatus.visible ? missionStatus.y : height - _margin) - _margin)

            property real _rightToolWidth: {
                if (!toolStrip.visible) {
                    return 0
                }

                const toolStripLeft = toolStrip.x - editorMap.x
                return Math.max(editorMap.width - toolStripLeft, 0)
            }
            property real _nonInteractiveOpacity: 0.5

            // Initial map position duplicates Fly view position
            Component.onCompleted: editorMap.center = QGroundControl.flightMapPosition

            onZoomLevelChanged: {
                QGroundControl.flightMapZoom = editorMap.zoomLevel
            }
            onCenterChanged: {
                QGroundControl.flightMapPosition = QGroundControl.mapSourceCoordinate(editorMap.center)
                if (_homeTrackingMapCenter && !_planMasterController.containsItems && _visualItems.count > 0) {
                    _updatingHomeFromMapCenter = true
                    _visualItems.get(0).coordinate = QGroundControl.mapSourceCoordinate(editorMap.center)
                    _updatingHomeFromMapCenter = false
                }
            }

            onMapClicked: (mouse) => {
                // Take focus to close any previous editing
                editorMap.focus = true

                // Collapse layer switcher on any map click
                layerSwitcher.expanded = false
                collapseTimer.stop()

                if (!mainWindow.allowViewSwitch()) {
                    return
                }
                var coordinate = QGroundControl.mapSourceCoordinate(editorMap.toCoordinate(Qt.point(mouse.x, mouse.y), false /* clipToViewPort */))
                coordinate.latitude = coordinate.latitude.toFixed(_decimalPlaces)
                coordinate.longitude = coordinate.longitude.toFixed(_decimalPlaces)
                coordinate.altitude = coordinate.altitude.toFixed(_decimalPlaces)

                switch (_editingLayer) {
                case _layerMission:
                    if (_addROIOnClick) {
                        _addROIOnClick = false
                        if (_missionController.isROIActive) {
                            var pos = Qt.point(mouse.x, mouse.y)
                            // For some strange reason using mainWindow in mapToItem doesn't work, so we use globals.parent instead which also gets us mainWindow
                            pos = editorMap.mapToItem(globals.parent, pos)
                            var dropPanel = insertOrCancelROIDropPanelComponent.createObject(mainWindow, { mapClickCoord: coordinate, clickRect: Qt.rect(pos.x, pos.y, 0, 0) })
                            dropPanel.open()
                        } else {
                            insertROIAfterCurrent(coordinate)
                        }
                    } else if (_addWaypointOnClick) {
                        insertSimpleItemAfterCurrent(coordinate)
                    }
                    break
                case _layerRally:
                    if (_rallyPointController.supported) {
                        _rallyPointController.addPoint(coordinate)
                    }
                    break
                }
            }

            // Add the mission item visuals to the map
            Repeater {
                model: _missionController.visualItems
                delegate: MissionItemMapVisual {
                    map: editorMap
                    opacity: _editingLayer == _layerMission ? 1 : editorMap._nonInteractiveOpacity
                    interactive: _editingLayer == _layerMission
                    vehicle: _planMasterController.controllerVehicle
                    onClicked: (sequenceNumber) => { _missionController.setCurrentPlanViewSeqNum(sequenceNumber, false) }
                }
            }

            // Add lines between waypoints (match Fly View visual style)
            MapItemView {
                model: _missionController.simpleFlightPathSegments

                delegate: MapPolyline {
                    readonly property bool _terrainCollision: object && object.terrainCollision

                    line.width: Math.max(10, ScreenTools.defaultFontPixelHeight * 0.96)
                    line.color: _terrainCollision ? "red" : _selectedMissionGlowColor
                    opacity: _editingLayer == _layerMission ? 1 : editorMap._nonInteractiveOpacity
                    z: QGroundControl.zOrderWaypointLines
                    path: missionLinePath(object ? object.coordinate1 : undefined, object ? object.coordinate2 : undefined)
                }
            }

            MapItemView {
                model: _missionController.simpleFlightPathSegments

                delegate: MapPolyline {
                    readonly property bool _terrainCollision: object && object.terrainCollision

                    line.width: Math.max(6, ScreenTools.defaultFontPixelHeight * 0.58)
                    line.color: _terrainCollision ? "red" : _selectedMissionBandColor
                    opacity: _editingLayer == _layerMission ? 1 : editorMap._nonInteractiveOpacity
                    z: QGroundControl.zOrderWaypointLines + 0.1
                    path: missionLinePath(object ? object.coordinate1 : undefined, object ? object.coordinate2 : undefined)
                }
            }

            MapItemView {
                model: _missionController.simpleFlightPathSegments

                delegate: MapPolyline {
                    readonly property bool _terrainCollision: object && object.terrainCollision

                    line.width: Math.max(2, ScreenTools.defaultFontPixelHeight * 0.18)
                    line.color: _terrainCollision ? "red" : _selectedMissionCoreColor
                    opacity: _editingLayer == _layerMission ? 1 : editorMap._nonInteractiveOpacity
                    z: QGroundControl.zOrderWaypointLines + 0.2
                    path: missionLinePath(object ? object.coordinate1 : undefined, object ? object.coordinate2 : undefined)
                }
            }

            // Direction arrows in waypoint lines
            MapItemView {
                model: _editingLayer == _layerMission ? _missionController.directionArrows : undefined

                delegate: MapLineArrow {
                    sourceFromCoord: object ? object.coordinate1 : undefined
                    sourceToCoord: object ? object.coordinate2 : undefined
                    arrowPosition: 3
                    arrowColor: _selectedMissionCoreColor
                    z: QGroundControl.zOrderWaypointLines + 1
                }
            }

            // UI for splitting the current segment
            MapQuickItem {
                id: splitSegmentItem
                anchorPoint.x: sourceItem.width / 2
                anchorPoint.y: sourceItem.height / 2
                z: QGroundControl.zOrderWaypointLines + 1
                visible: _editingLayer == _layerMission

                sourceItem: SplitIndicator {
                    onClicked: _missionController.insertSimpleMissionItem(splitSegmentItem.coordinate,
                                                                           _missionController.currentPlanViewVIIndex,
                                                                           true /* makeCurrentItem */)
                }

                function _updateSplitCoord() {
                    if (_missionController.splitSegment) {
                        var distance = _missionController.splitSegment.coordinate1.distanceTo(_missionController.splitSegment.coordinate2)
                        var azimuth = _missionController.splitSegment.coordinate1.azimuthTo(_missionController.splitSegment.coordinate2)
                        splitSegmentItem.coordinate = _missionController.splitSegment.coordinate1.atDistanceAndAzimuth(distance / 2, azimuth)
                    } else {
                        coordinate = QtPositioning.coordinate()
                    }
                }

                Connections {
                    target: _missionController
                    function onSplitSegmentChanged()  { splitSegmentItem._updateSplitCoord() }
                }

                Connections {
                    target: _missionController.splitSegment
                    function onCoordinate1Changed()   { splitSegmentItem._updateSplitCoord() }
                    function onCoordinate2Changed()   { splitSegmentItem._updateSplitCoord() }
                }
            }

            // Add the vehicles to the map
            MapItemView {
                model: QGroundControl.multiVehicleManager.vehicles
                delegate: VehicleMapItem {
                    vehicle: object
                    coordinate: object.coordinate
                    map: editorMap
                    size: ScreenTools.defaultFontPixelHeight * 3
                    z: QGroundControl.zOrderMapItems - 1
                }
            }

            GeoFenceMapVisuals {
                map: editorMap
                myGeoFenceController: _geoFenceController
                interactive: _editingLayer == _layerFence
                homePosition: _missionController.plannedHomePosition
                planView: true
                opacity: _editingLayer != _layerFence ? editorMap._nonInteractiveOpacity : 1
            }

            RallyPointMapVisuals {
                map: editorMap
                myRallyPointController: _rallyPointController
                interactive: _editingLayer == _layerRally
                planView: true
                opacity: _editingLayer != _layerRally ? editorMap._nonInteractiveOpacity : 1
            }

        }

        //-----------------------------------------------------------
        // Top-right tool strip
        ToolStrip {
            id: toolStrip
            anchors.margins: _toolsMargin
            anchors.right: editorMap.right
            anchors.top: editorMap.top
            z: QGroundControl.zOrderWidgets
            maxHeight: parent.height - toolStrip.y
            visible: _editingLayer == _layerMission && _toolStripExpanded
            width: ScreenTools.defaultFontPixelWidth * 7
            radius: ScreenTools.defaultFontPixelWidth / 2
            color: QGroundControl.globalPalette.windowTransparent
            showText: false
            fontSize: ScreenTools.smallFontPointSize

            property bool _isMissionLayer: _editingLayer == _layerMission

            Binding {
                target: waypointButton
                property: "checked"
                value: _addWaypointOnClick
            }

            Binding {
                target: roiButton
                property: "checked"
                value: _addROIOnClick
            }

            ToolStripActionList {
                id: toolStripActionList
                model: [
                    ToolStripAction {
                        text: qsTr("起飞")
                        iconSource: "/res/takeoff.svg"
                        enabled: _missionController.isInsertTakeoffValid
                        visible: toolStrip._isMissionLayer && !_planMasterController.controllerVehicle.rover
                        onTriggered: {
                            insertTakeoffItemAfterCurrent()
                        }
                    },
                    ToolStripAction {
                        text: qsTr("航线")
                        iconSource: "/qmlimages/MapDrawShape.svg"
                        enabled: _hasPatternChoices
                        visible: toolStrip._isMissionLayer
                        onTriggered: (source) => _openPatternPanel(source)
                    },
                    ToolStripAction {
                        id: waypointButton
                        text: qsTr("航点")
                        iconSource: "/res/waypoint.svg"
                        visible: toolStrip._isMissionLayer
                        checkable: true
                        onTriggered: { _addWaypointOnClick = !_addWaypointOnClick; if (_addWaypointOnClick) _addROIOnClick = false }
                    },
                    ToolStripAction {
                        id: roiButton
                        text: qsTr("ROI")
                        iconSource: "/qmlimages/roi.svg"
                        visible: toolStrip._isMissionLayer && _planMasterController.controllerVehicle.supports.roiMode
                        checkable: true
                        onTriggered: { _addROIOnClick = !_addROIOnClick; if (_addROIOnClick) _addWaypointOnClick = false }
                    },
                    ToolStripAction {
                        text: _planMasterController.controllerVehicle.multiRotor
                                    ? qsTr("返航")
                                    : _missionController.isInsertLandValid && _missionController.hasLandItem
                                      ? qsTr("备降")
                                      : qsTr("降落")
                        iconSource: "/res/rtl.svg"
                        enabled: _missionController.isInsertLandValid
                        visible: toolStrip._isMissionLayer
                        onTriggered: {
                            insertLandItemAfterCurrent()
                        }
                    },
                    ToolStripAction {
                        text: qsTr("就地降落")
                        iconSource: "/res/land.svg"
                        enabled: _missionController.isInsertLandValid
                        visible: toolStrip._isMissionLayer && _planMasterController.controllerVehicle.multiRotor
                        onTriggered: {
                            insertLandHereItemAfterCurrent()
                        }
                    },
                    ToolStripAction {
                        text: qsTr("清空航线")
                        iconSource: "/res/TrashCan.svg"
                        enabled: !_planMasterController.syncInProgress && _planMasterController.containsItems
                        visible: toolStrip._isMissionLayer
                        onTriggered: _triggerToolStripClear()
                    },
                    ToolStripAction {
                        text: qsTr("上传")
                        iconSource: "/res/UploadToVehicle.svg"
                        enabled: !_planMasterController.syncInProgress && _planMasterController.containsItems
                        visible: toolStrip._isMissionLayer
                        onTriggered: (source) => _triggerToolStripUpload(source)
                    },
                    ToolStripAction {
                        text: qsTr("统计")
                        iconSource: "/res/chevron-double-right.svg"
                        visible: missionStatus.hidden && QGroundControl.corePlugin.options.showMissionStatus
                        onTriggered: missionStatus.showMissionStatus()
                    }
                ]
            }

            model: toolStripActionList.model
        }

        Rectangle {
            id: toolStripOpenCloseButton
            anchors.right: _toolStripExpanded ? toolStrip.right : editorMap.right
            anchors.rightMargin: _toolStripExpanded ? (-width * 0.35) : (_toolsMargin * 0.2)
            anchors.verticalCenter: toolStrip.verticalCenter
            width: ScreenTools.defaultFontPixelWidth * 1.6
            height: ScreenTools.defaultFontPixelHeight * 3.6
            radius: theme.radius
            z: QGroundControl.zOrderWidgets + 1
            visible: _editingLayer == _layerMission
            color: stripToggleArea.pressed ? theme.panelPressedColor : (stripToggleArea.containsMouse ? theme.panelHoverColor : theme.panelColor)
            border.width: 1
            border.color: theme.borderColor

            Behavior on color { ColorAnimation { duration: theme.stateAnimationDuration } }

            QGCLabel {
                anchors.centerIn: parent
                text: _toolStripExpanded ? ">" : "<"
                color: theme.textColor
            }

            QGCMouseArea {
                id: stripToggleArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: _toolStripExpanded = !_toolStripExpanded
            }
        }

        MapScale {
            id: mapScale
            anchors.margins: _toolsMargin
            anchors.right: toolStrip.visible ? toolStrip.left : editorMap.right
            anchors.top: editorMap.top
            mapControl: editorMap
            autoHide: true
        }

        PlanViewRightPanel {
            id: rightPanel
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: _sidePanelWidth
            dockLeft: true
            planMasterController: _planMasterController
            editorMap: editorMap
            onEditingLayerChangeRequested: (layer) => _editingLayer = layer
        }

        // Layer switching icons — only active icon visible; click to expand choices leftward
        Item {
            id:                     layerSwitcher
            anchors.right:          mapScale.left
            anchors.rightMargin:    _toolsMargin
            anchors.top:            editorMap.top
            anchors.topMargin:      _toolsMargin
            width:                  layerRow.width
            height:                 _layerButtonSize
            z:                      QGroundControl.zOrderWidgets

            property bool   expanded: false
            property real   _layerButtonSize: ScreenTools.defaultFontPixelHeight * 2.0
            property real   _spacing: ScreenTools.defaultFontPixelHeight * 0.25

            readonly property var _layers: [
                { layer: _layerMission, icon: "/res/waypoint.svg",      nodeType: "missionGroup" },
                { layer: _layerFence,   icon: "/res/GeoFence.svg",      nodeType: "fenceGroup" },
                { layer: _layerRally,   icon: "/res/RallyPoint.svg",    nodeType: "rallyGroup" }
            ]

            Timer {
                id: collapseTimer
                interval: 5000
                onTriggered: layerSwitcher.expanded = false
            }

            function toggle() {
                expanded = !expanded
                if (expanded) {
                    collapseTimer.restart()
                } else {
                    collapseTimer.stop()
                }
            }

            function choose(nodeType) {
                expanded = false
                collapseTimer.stop()
                rightPanel.selectLayer(nodeType)
            }

            // Row laid out right-to-left: active icon on the right, choices expand left
            Row {
                id:             layerRow
                anchors.right:  parent.right
                spacing:        layerSwitcher._spacing
                layoutDirection: Qt.RightToLeft

                // Active layer button (always visible)
                Rectangle {
                    width:  layerSwitcher._layerButtonSize
                    height: width
                    radius: theme.radius
                    color:  toggleLayerMouseArea.pressed ? theme.accentHoverColor : (toggleLayerMouseArea.containsMouse ? theme.accentHoverColor : theme.accentColor)
                    border.width: 1
                    border.color: theme.accentColor

                    Behavior on color { ColorAnimation { duration: theme.stateAnimationDuration } }
                    Behavior on border.color { ColorAnimation { duration: theme.stateAnimationDuration } }

                    QGCColoredImage {
                        anchors.centerIn:   parent
                        width:              parent.width * 0.6
                        height:             width
                        source:             layerSwitcher._layers.find(l => l.layer === _editingLayer)?.icon ?? "/res/waypoint.svg"
                        color:              theme.textColor
                    }

                    QGCMouseArea {
                        id:          toggleLayerMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked:    layerSwitcher.toggle()
                    }
                }

                // Choice buttons (only layers that are NOT the current one)
                Repeater {
                    model: layerSwitcher._layers.filter(l => l.layer !== _editingLayer)

                    Rectangle {
                        required property var modelData
                        width:   layerSwitcher._layerButtonSize
                        height:  width
                        radius:  theme.radius
                        color:   choiceLayerMouseArea.pressed ? theme.panelPressedColor : (choiceLayerMouseArea.containsMouse ? theme.panelHoverColor : theme.panelColor)
                        border.width: 1
                        border.color: theme.borderColor
                        visible: opacity > 0
                        opacity: layerSwitcher.expanded ? 1 : 0

                        Behavior on opacity { NumberAnimation { duration: theme.stateAnimationDuration } }
                        Behavior on color { ColorAnimation { duration: theme.stateAnimationDuration } }
                        Behavior on border.color { ColorAnimation { duration: theme.stateAnimationDuration } }

                        QGCColoredImage {
                            anchors.centerIn:   parent
                            width:              parent.width * 0.6
                            height:             width
                            source:             modelData.icon
                            color:              choiceLayerMouseArea.containsMouse ? theme.textColor : theme.secondaryTextColor
                            Behavior on color { ColorAnimation { duration: theme.stateAnimationDuration } }
                        }

                        QGCMouseArea {
                            id:          choiceLayerMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked:    layerSwitcher.choose(modelData.nodeType)
                        }
                    }
                }
            }
        }

        RowLayout {
            id: missionStatus
            anchors.margins: _toolsMargin
            anchors.left: editorMap.left
            anchors.right: _calcRightAnchor()
            anchors.bottom: parent.bottom
            spacing: 0
            visible: !hidden && _editingLayer == _layerMission && QGroundControl.corePlugin.options.showMissionStatus

            readonly property bool hidden: _planViewSettings.showMissionItemStatus.rawValue ? false : true

            function showMissionStatus() {
                _planViewSettings.showMissionItemStatus.rawValue = true
            }

            function _calcRightAnchor() {
                if (!toolStrip.visible) {
                    return editorMap.right
                }
                let bottomOfToolStrip = toolStrip.y + toolStrip.height
                let largestStatsHeight = Math.max(terrainStatus.height, missionStats.height)
                if (bottomOfToolStrip + largestStatsHeight > parent.height - missionStatus.anchors.margins) {
                    return toolStrip.left
                }
                return editorMap.right
            }

            function _toggleMissionStatusVisibility() {
                _planViewSettings.showMissionItemStatus.rawValue = _planViewSettings.showMissionItemStatus.rawValue ? false : true
            }

            ColumnLayout {
                id: missionStatsButtonLayout
                Layout.alignment: Qt.AlignBottom
                spacing: 0

                property real _buttonImplicitWidth: ScreenTools.defaultFontPixelHeight * 1.5
                property real _buttonImageMargins: _buttonImplicitWidth * 0.15

                Rectangle {
                    id: terrainButton
                    implicitWidth: missionStatsButtonLayout._buttonImplicitWidth
                    implicitHeight: implicitWidth
                    radius: 8
                    border.width: 1
                    border.color: "#333333"
                    color: checked
                           ? (terrainMouseArea.pressed ? "#1E40AF" : (terrainMouseArea.containsMouse ? "#1D4ED8" : "#2563EB"))
                           : (terrainMouseArea.pressed ? "#2A2A2A" : (terrainMouseArea.containsMouse ? "#3D3D3D" : "#333333"))

                    property bool checked: true

                    Behavior on color {
                        ColorAnimation { duration: 200 }
                    }

                    QGCColoredImage {
                        anchors.margins: missionStatsButtonLayout._buttonImageMargins
                        anchors.fill: parent
                        source: "/res/terrain.svg"
                        color: "#FFFFFF"
                    }

                    QGCMouseArea {
                        id: terrainMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            terrainButton.checked = true
                            missionStatsButton.checked = false
                        }
                    }
                }

                Rectangle {
                    id: missionStatsButton
                    implicitWidth: missionStatsButtonLayout._buttonImplicitWidth
                    implicitHeight: implicitWidth
                    radius: 8
                    border.width: 1
                    border.color: "#333333"
                    color: checked
                           ? (missionStatsMouseArea.pressed ? "#1E40AF" : (missionStatsMouseArea.containsMouse ? "#1D4ED8" : "#2563EB"))
                           : (missionStatsMouseArea.pressed ? "#2A2A2A" : (missionStatsMouseArea.containsMouse ? "#3D3D3D" : "#333333"))

                    property bool checked: false

                    Behavior on color {
                        ColorAnimation { duration: 200 }
                    }

                    QGCColoredImage {
                        anchors.margins: missionStatsButtonLayout._buttonImageMargins
                        anchors.fill: parent
                        source: "/res/sliders.svg"
                        color: "#FFFFFF"
                    }

                    QGCMouseArea {
                        id: missionStatsMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            missionStatsButton.checked = true
                            terrainButton.checked = false
                        }
                    }
                }

                Rectangle {
                    id: bottomStatusOpenCloseButton
                    implicitWidth: missionStatsButtonLayout._buttonImplicitWidth
                    implicitHeight: implicitWidth
                    radius: 8
                    border.width: 1
                    border.color: "#333333"
                    color: closeButtonMouseArea.pressed ? "#2A2A2A" : (closeButtonMouseArea.containsMouse ? "#3D3D3D" : "#333333")

                    Behavior on color {
                        ColorAnimation { duration: 200 }
                    }

                    QGCColoredImage {
                        anchors.margins: missionStatsButtonLayout._buttonImageMargins
                        anchors.fill: parent
                        source: "/res/chevron-double-left.svg"
                        color: "#FFFFFF"
                    }

                    QGCMouseArea {
                        id: closeButtonMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: missionStatus._toggleMissionStatusVisibility()
                    }
                }
            }

            TerrainStatus {
                id: terrainStatus
                Layout.alignment: Qt.AlignBottom
                Layout.fillWidth: true
                height: ScreenTools.defaultFontPixelHeight * 7
                missionController: _missionController
                visible: terrainButton.checked
                onSetCurrentSeqNum: _missionController.setCurrentPlanViewSeqNum(seqNum, true)
            }

            MissionStats {
                id: missionStats
                Layout.alignment: Qt.AlignBottom
                Layout.fillWidth: true
                visible: missionStatsButton.checked
                planMasterController: _root._planMasterController
            }
        }
    }

        //- ToolStrip ToolStripDropPanel Components

    Component {
        id: patternDropPanelComponent

        DropPanel {
            id: patternDropPopup
            backgroundColor: popupStyle.popupBackground
            borderColor:     popupStyle.borderColor
            panelRadius:     popupStyle.cornerRadius
            sourceComponent: patternDropPanelContent

            QGCPopupStyle {
                id: popupStyle
            }

            onClosed: {
                if (_root._patternDropPanel === patternDropPopup) {
                    _root._patternDropPanel = null
                }
                destroy()
            }
        }
    }

    Component {
        id: patternDropPanelContent

        Item {
            id: patternPanelRoot
            implicitWidth:  ScreenTools.defaultFontPixelWidth * 17
            implicitHeight: Math.min(contentColumn.implicitHeight, maxPanelHeight)

            readonly property real panelPadding:   ScreenTools.defaultFontPixelWidth * 0.5
            readonly property real maxPanelHeight: Math.max(ScreenTools.defaultFontPixelHeight * 10, mainWindow.height * 0.34)

            QGCPopupStyle {
                id: popupStyle
            }

            Rectangle {
                anchors.fill: parent
                radius:       popupStyle.cornerRadius
                color:        Qt.rgba(0.18, 0.18, 0.18, 0.86)
                border.width: 1
                border.color: popupStyle.borderColor
            }

            QGCFlickable {
                id: patternPanelFlickable
                anchors.fill: parent
                anchors.margins: patternPanelRoot.panelPadding
                contentHeight: contentColumn.implicitHeight
                flickableDirection: Flickable.VerticalFlick
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                ColumnLayout {
                    id: contentColumn
                    width: patternPanelFlickable.width
                    spacing: ScreenTools.defaultFontPixelHeight * 0.22

                    QGCLabel {
                        text: qsTr("创建复杂航线：")
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        color: popupStyle.primaryTextColor
                        font.pointSize: 9
                    }

                    QGCButton {
                        text: _root._displayComplexPatternName(_root._missionController.surveyComplexItemName)
                        Layout.fillWidth: true
                        visible: _root._supportsSurveyPattern
                        showBorder: true
                        backRadius: popupStyle.cornerRadius
                        pointSize: 8
                        heightFactor: 0.22
                        _horizontalPadding: ScreenTools.defaultFontPixelWidth * 0.65
                        stateAnimationDuration: popupStyle.stateAnimationDuration
                        backgroundColor: Qt.rgba(0.20, 0.20, 0.20, 0.78)
                        borderColor: "#4A4A4A"

                        onClicked: {
                            _root.insertComplexItemAfterCurrent(_root._missionController.surveyComplexItemName)
                            dropPanel.hide()
                        }
                    }

                    QGCButton {
                        text: _root._displayComplexPatternName(_root._missionController.corridorScanComplexItemName)
                        Layout.fillWidth: true
                        visible: _root._supportsCorridorScanPattern
                        showBorder: true
                        backRadius: popupStyle.cornerRadius
                        pointSize: 8
                        heightFactor: 0.22
                        _horizontalPadding: ScreenTools.defaultFontPixelWidth * 0.65
                        stateAnimationDuration: popupStyle.stateAnimationDuration
                        backgroundColor: Qt.rgba(0.20, 0.20, 0.20, 0.78)
                        borderColor: "#4A4A4A"

                        onClicked: {
                            _root.insertComplexItemAfterCurrent(_root._missionController.corridorScanComplexItemName)
                            dropPanel.hide()
                        }
                    }

                    QGCButton {
                        text: _root._displayComplexPatternName(_root._missionController.structureScanComplexItemName)
                        Layout.fillWidth: true
                        visible: _root._supportsStructureScanPattern
                        showBorder: true
                        backRadius: popupStyle.cornerRadius
                        pointSize: 8
                        heightFactor: 0.22
                        _horizontalPadding: ScreenTools.defaultFontPixelWidth * 0.65
                        stateAnimationDuration: popupStyle.stateAnimationDuration
                        backgroundColor: Qt.rgba(0.20, 0.20, 0.20, 0.78)
                        borderColor: "#4A4A4A"

                        onClicked: {
                            _root.insertComplexItemAfterCurrent(_root._missionController.structureScanComplexItemName)
                            dropPanel.hide()
                        }
                    }

                    QGCLabel {
                        Layout.topMargin: ScreenTools.defaultFontPixelHeight * 0.18
                        Layout.fillWidth: true
                        visible: _root._additionalComplexPatterns.length > 0
                        text: qsTr("其他航线：")
                        wrapMode: Text.WordWrap
                        color: popupStyle.secondaryTextColor
                        font.pointSize: 8
                    }

                    Repeater {
                        model: _root._additionalComplexPatterns

                        QGCButton {
                            required property var modelData
                            text: _root._displayComplexPatternName(modelData)
                            Layout.fillWidth: true
                            showBorder: true
                            backRadius: popupStyle.cornerRadius
                            pointSize: 8
                            heightFactor: 0.22
                            _horizontalPadding: ScreenTools.defaultFontPixelWidth * 0.65
                            stateAnimationDuration: popupStyle.stateAnimationDuration
                            backgroundColor: Qt.rgba(0.20, 0.20, 0.20, 0.78)
                            borderColor: "#4A4A4A"

                            onClicked: {
                                _root.insertComplexItemAfterCurrent(modelData)
                                dropPanel.hide()
                            }
                        }
                    }
                }
            }
        }
    }

    QGCPopupDialogFactory {
        id: promptForPlanUsageOnVehicleChangePopupFactory

        dialogComponent: promptForPlanUsageOnVehicleChangePopupComponent
    }

    Component {
        id: promptForPlanUsageOnVehicleChangePopupComponent
        QGCPopupDialog {
            id: promptForPlanUsageDialog
            title: _promptForPlanUsageVehicleOffline ? qsTr("Plan View - Vehicle Disconnected") : qsTr("Plan View - Vehicle Changed")
            buttons: Dialog.NoButton

            property bool _choiceMade: false
            readonly property real _contentWidth: Math.max(headerMinWidth, ScreenTools.defaultFontPixelWidth * 26)

            onClosed: _promptForPlanUsageShowing = false

            ColumnLayout {
                width: promptForPlanUsageDialog._contentWidth
                spacing: ScreenTools.defaultFontPixelHeight * 0.75

                QGCLabel {
                    Layout.fillWidth: true
                    Layout.preferredWidth: promptForPlanUsageDialog._contentWidth
                    wrapMode: QGCLabel.WordWrap
                    text: _promptForPlanUsageVehicleOffline ?
                                                qsTr("The vehicle associated with the plan in the Plan View is no longer available. What would you like to do with that plan?") : qsTr("The plan being worked on in the Plan View is not from the current vehicle. What would you like to do with that plan?")
                }

                QGCButton {
                    Layout.fillWidth: true
                    Layout.preferredWidth: promptForPlanUsageDialog._contentWidth
                    enabled: !promptForPlanUsageDialog._choiceMade
                    text: (_promptForPlanUsageDirtyForSave) ?
                                            (_promptForPlanUsageVehicleOffline ?
                                                 qsTr("Discard Unsaved Changes") : qsTr("Discard Unsaved Changes, Load New Plan From Vehicle")) : qsTr("Load New Plan From Vehicle")
                    onClicked: {
                        if (promptForPlanUsageDialog._choiceMade) {
                            return
                        }
                        promptForPlanUsageDialog._choiceMade = true
                        _planMasterController.showPlanFromManagerVehicle()
                        close();
                    }
                }

                QGCButton {
                    Layout.fillWidth: true
                    Layout.preferredWidth: promptForPlanUsageDialog._contentWidth
                    enabled: !promptForPlanUsageDialog._choiceMade
                    text: _promptForPlanUsageVehicleOffline ?
                                            qsTr("Keep Current Plan") : qsTr("Keep Current Plan, Don't Update From Vehicle")
                    onClicked: {
                        if (promptForPlanUsageDialog._choiceMade) {
                            return
                        }
                        promptForPlanUsageDialog._choiceMade = true
                        close()
                    }
                }
            }
        }
    }

    Component {
        id: insertOrCancelROIDropPanelComponent

        DropPanel {
            id: insertOrCancelROIDropPanel
            onClosed: destroy()

            property var mapClickCoord

            sourceComponent: Component {
                ColumnLayout {
                    spacing: ScreenTools.defaultFontPixelWidth / 2

                    QGCButton {
                        Layout.fillWidth: true
                        text: qsTr("Insert ROI")

                        onClicked: {
                            insertOrCancelROIDropPanel.close()
                            insertROIAfterCurrent(mapClickCoord)
                        }
                    }

                    QGCButton {
                        Layout.fillWidth: true
                        text: qsTr("Insert Cancel ROI")

                        onClicked: {
                            insertOrCancelROIDropPanel.close()
                            insertCancelROIAfterCurrent()
                        }
                    }
                }
            }
        }
    }

    Component {
        id: uploadStatusDropPanelComponent

        DropPanel {
            id: uploadStatusDropPanel
            property string uploadTitle: ""
            property string uploadMessage: ""
            property string confirmButtonText: qsTr("Ok")
            property var confirmAction: null
            property bool uploadBusy: false
            property int autoCloseMs: 0

            onClosed: {
                if (_root._uploadStatusPanel === uploadStatusDropPanel) {
                    _root._uploadStatusPanel = null
                }
                destroy()
            }

            onOpened: {
                if (autoCloseMs > 0) {
                    autoCloseTimer.restart()
                }
            }

            Timer {
                id: autoCloseTimer
                interval: uploadStatusDropPanel.autoCloseMs
                repeat: false
                onTriggered: uploadStatusDropPanel.close()
            }

            sourceComponent: Component {
                ColumnLayout {
                    width: ScreenTools.defaultFontPixelWidth * 28
                    spacing: ScreenTools.defaultFontPixelHeight * 0.6

                    BusyIndicator {
                        Layout.alignment: Qt.AlignHCenter
                        running: uploadStatusDropPanel.uploadBusy
                        visible: running
                    }

                    QGCLabel {
                        Layout.fillWidth: true
                        font.bold: true
                        wrapMode: Text.WordWrap
                        text: uploadStatusDropPanel.uploadTitle
                    }

                    QGCLabel {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: uploadStatusDropPanel.uploadMessage
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        spacing: ScreenTools.defaultFontPixelWidth * 0.5
                        visible: !uploadStatusDropPanel.uploadBusy && uploadStatusDropPanel.autoCloseMs <= 0

                        QGCButton {
                            visible: !!uploadStatusDropPanel.confirmAction
                            text: qsTr("Cancel")
                            onClicked: uploadStatusDropPanel.close()
                        }

                        QGCButton {
                            text: uploadStatusDropPanel.confirmButtonText
                            onClicked: {
                                const action = uploadStatusDropPanel.confirmAction
                                uploadStatusDropPanel.close()
                                if (action) {
                                    action()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
