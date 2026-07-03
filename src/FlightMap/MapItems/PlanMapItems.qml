import QtQuick
import QtLocation
import QtPositioning

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightMap
import QGroundControl.PlanView

// Adds visual items associated with the Flight Plan to the map.
// Currently only used by Fly View even though it's called PlanMapItems!
Item {
    id: _root

    property var    map                     ///< Map control to show items on
    property bool   largeMapView            ///< true: map takes up entire view, false: map is in small window
    property var    planMasterController    ///< Reference to PlanMasterController for vehicle
    property var    vehicle                 ///< Vehicle associated with these items

    property var    _map:                       map
    property var    _vehicle:                   vehicle
    property var    _missionController:         planMasterController.missionController
    property var    _geoFenceController:        planMasterController.geoFenceController
    property var    _rallyPointController:      planMasterController.rallyPointController
    property var    _guidedController:          globals.guidedControllerFlyView
    property var    _missionLineViewComponent
    property real   missionItemOpacity:         1
    property real   missionLineOpacity:         1
    property real   directionArrowOpacity:      1
    property color  missionLineColor:           QGroundControl.globalPalette.mapMissionTrajectory
    property color  directionArrowColor:        "white"

    property string fmode: vehicle.flightMode

    // Add the mission item visuals to the map
    Repeater {
        model: largeMapView && _root.missionItemOpacity > 0.01 ? _missionController.visualItems : 0

        delegate: MissionItemMapVisual {
            map:        _map
            vehicle:    _vehicle
            opacity:    _root.missionItemOpacity
            onClicked:  _guidedController.confirmAction(_guidedController.actionSetWaypoint, Math.max(object.sequenceNumber, 1))
        }
    }

    Component.onCompleted: {
        _missionLineViewComponent = missionLineViewComponent.createObject(map)
        if (_missionLineViewComponent.status === Component.Error)
            console.log(_missionLineViewComponent.errorString())
        map.addMapItemGroup(_missionLineViewComponent)
    }

    Component.onDestruction: {
        if (_missionLineViewComponent) {
            // Must remove MapItemGroup before destruction, otherwise we crash on quit
            map.removeMapItemGroup(_missionLineViewComponent)
            _missionLineViewComponent.destroy()
        }
    }

    Component {
        id: missionLineViewComponent

        MapItemGroup {
            MissionLineView {
                model:       _root.missionLineOpacity > 0.01 ? _missionController.simpleFlightPathSegments : 0
                lineColor:   _root.missionLineColor
                lineOpacity: _root.missionLineOpacity
            }

            MapItemView {
                model: _root.directionArrowOpacity > 0.01 ? _missionController.directionArrows : 0

                delegate: MapLineArrow {
                    sourceFromCoord: object ? object.coordinate1 : undefined
                    sourceToCoord:   object ? object.coordinate2 : undefined
                    arrowPosition:  3
                    arrowColor:     _root.directionArrowColor
                    opacity:        _root.directionArrowOpacity
                    z:              QGroundControl.zOrderWaypointLines + 1
                }
            }
        }
    }
}
