import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.PlanView

// Editor for Fixed Wing Landing Pattern complex mission item
Rectangle {
    id:         _root
    height:     visible ? ((editorColumn.visible ? editorColumn.height : editorColumnNeedLandingPoint.height) + (_margin * 2)) : 0
    width:      availableWidth
    color:      theme.panelColor
    radius:     theme.radius
    border.width: 1
    border.color: theme.borderColor

    required property var missionItem
    required property real availableWidth

    property var    _masterControler:           missionItem.masterController
    property var    _missionController:         _masterControler.missionController
    property var    _missionVehicle:            _masterControler.controllerVehicle
    property real   _margin:                    ScreenTools.defaultFontPixelWidth / 2
    property real   _spacer:                    ScreenTools.defaultFontPixelWidth / 2
    property string _setToVehicleHeadingStr:    qsTr("设为飞行器航向")
    property string _setToVehicleLocationStr:   qsTr("设为飞行器位置")
    property int    _altitudeFrame:              missionItem.altitudesAreRelative ? QGroundControl.AltitudeFrameRelative : QGroundControl.AltitudeFrameAbsolute

    PlanEditorTheme { id: theme }

    Column {
        id:                 editorColumn
        anchors.margins:    _margin
        anchors.left:       parent.left
        anchors.right:      parent.right
        spacing:            _margin
        visible:            !editorColumnNeedLandingPoint.visible

        PlanSectionHeader {
            id:             finalApproachSection
            anchors.left:   parent.left
            anchors.right:  parent.right
            text:           qsTr("最终进近")
        }

        Column {
            anchors.left:       parent.left
            anchors.right:      parent.right
            spacing:            _margin
            visible:            finalApproachSection.checked

            Item { width: 1; height: _spacer }

            PlanFactCheckBox {
                text:       qsTr("盘旋至高度")
                fact:       missionItem.useLoiterToAlt
            }

            GridLayout {
                anchors.left:    parent.left
                anchors.right:   parent.right
                columns:         2

                QGCLabel { text: qsTr("高度"); color: theme.secondaryTextColor }

                PlanAltitudeFactTextField {
                    Layout.fillWidth:   true
                    fact:               missionItem.finalApproachAltitude
                    altitudeFrame:       _altitudeFrame
                }

                PlanFactCheckBox {
                    id:         flightSpeedCheckbox
                    text:       qsTr("飞行速度")
                    fact:       missionItem.useDoChangeSpeed
                }

                PlanFactTextField {
                    Layout.fillWidth:   true
                    fact:               missionItem.finalApproachSpeed
                    enabled:            flightSpeedCheckbox.checked
                }

                QGCLabel {
                    text:       qsTr("半径")
                    visible:    missionItem.useLoiterToAlt.rawValue
                    color:      theme.secondaryTextColor
                }

                PlanFactTextField {
                    Layout.fillWidth:   true
                    fact:               missionItem.loiterRadius
                    visible:            missionItem.useLoiterToAlt.rawValue
                }
            }

            Item { width: 1; height: _spacer }

            PlanFactCheckBox {
                text:       qsTr("顺时针盘旋")
                fact:       missionItem.loiterClockwise
                visible:    missionItem.useLoiterToAlt.rawValue
            }

            PlanButton {
                text:       _setToVehicleHeadingStr
                visible:    globals.activeVehicle
                onClicked:  missionItem.landingHeading.rawValue = globals.activeVehicle.heading.rawValue
            }
        }

        PlanSectionHeader {
            id:             landingPointSection
            anchors.left:   parent.left
            anchors.right:  parent.right
            text:           qsTr("降落点")
        }

        Column {
            anchors.left:       parent.left
            anchors.right:      parent.right
            spacing:            _margin
            visible:            landingPointSection.checked

            Item { width: 1; height: _spacer }

            GridLayout {
                anchors.left:    parent.left
                anchors.right:   parent.right
                columns:         2

                QGCLabel { text: qsTr("航向"); color: theme.secondaryTextColor }

                PlanFactTextField {
                    Layout.fillWidth:   true
                    fact:               missionItem.landingHeading
                }

                QGCLabel { text: qsTr("高度"); color: theme.secondaryTextColor }

                PlanAltitudeFactTextField {
                    Layout.fillWidth:   true
                    fact:               missionItem.landingAltitude
                    altitudeFrame:       _altitudeFrame
                }

                PlanRadioButton {
                    id:                 specifyLandingDistance
                    text:               qsTr("距离")
                    checked:            missionItem.valueSetIsDistance.rawValue
                    onClicked:          missionItem.valueSetIsDistance.rawValue = checked
                    Layout.fillWidth:   true
                }

                PlanFactTextField {
                    fact:               missionItem.landingDistance
                    enabled:            specifyLandingDistance.checked
                    Layout.fillWidth:   true
                }

                PlanRadioButton {
                    id:                 specifyGlideSlope
                    text:               qsTr("下滑角")
                    checked:            !missionItem.valueSetIsDistance.rawValue
                    onClicked:          missionItem.valueSetIsDistance.rawValue = !checked
                    Layout.fillWidth:   true
                }

                PlanFactTextField {
                    fact:               missionItem.glideSlope
                    enabled:            specifyGlideSlope.checked
                    Layout.fillWidth:   true
                }

                PlanButton {
                    text:               _setToVehicleLocationStr
                    visible:            globals.activeVehicle
                    Layout.columnSpan:  2
                    onClicked:          missionItem.landingCoordinate = globals.activeVehicle.coordinate
                }
            }
        }

        Item { width: 1; height: _spacer }

        PlanCheckBox {
            anchors.right:  parent.right
            text:           qsTr("高度相对起飞点")
            checked:        missionItem.altitudesAreRelative
            visible:        QGroundControl.corePlugin.options.showMissionAbsoluteAltitude || !missionItem.altitudesAreRelative
            onClicked:      missionItem.altitudesAreRelative = checked
        }

        PlanSectionHeader {
            id:             cameraSection
            anchors.left:   parent.left
            anchors.right:  parent.right
            text:           qsTr("Camera")
        }

        Column {
            anchors.left:       parent.left
            anchors.right:      parent.right
            spacing:            _margin
            visible:            cameraSection.checked

            Item { width: 1; height: _spacer }

            PlanFactCheckBox {
                text:       _stopTakingPhotos.shortDescription
                fact:       _stopTakingPhotos

                property Fact _stopTakingPhotos: missionItem.stopTakingPhotos
            }

            PlanFactCheckBox {
                text:       _stopTakingVideo.shortDescription
                fact:       _stopTakingVideo

                property Fact _stopTakingVideo: missionItem.stopTakingVideo
            }
        }

        Column {
            anchors.left:       parent.left
            anchors.right:      parent.right
            spacing:            0

            QGCLabel {
                anchors.left:           parent.left
                anchors.right:          parent.right
                wrapMode:               Text.WordWrap
                color:                  qgcPal.warningText
                font.pointSize:         ScreenTools.smallFontPointSize
                text:                   qsTr("* Approximate glide slope altitudes.")
            }

            QGCLabel {
                anchors.left:           parent.left
                anchors.right:          parent.right
                wrapMode:               Text.WordWrap
                color:                  qgcPal.warningText
                font.pointSize:         ScreenTools.smallFontPointSize
                text:                   qsTr("* Actual flight path will vary.")
            }

            QGCLabel {
                anchors.left:           parent.left
                anchors.right:          parent.right
                wrapMode:               Text.WordWrap
                color:                  qgcPal.warningText
                font.pointSize:         ScreenTools.smallFontPointSize
                text:                   qsTr("* Avoid tailwind on landing.")
            }
        }
    }

    Column {
        id:                 editorColumnNeedLandingPoint
        anchors.margins:    _margin
        anchors.top:        parent.top
        anchors.left:       parent.left
        anchors.right:      parent.right
        visible:            !missionItem.landingCoordSet || missionItem.wizardMode
        spacing:            ScreenTools.defaultFontPixelHeight

        Column {
            id:             landingCoordColumn
            anchors.left:   parent.left
            anchors.right:  parent.right
            spacing:        ScreenTools.defaultFontPixelHeight
            visible:        !missionItem.landingCoordSet

            QGCLabel {
                anchors.left:           parent.left
                anchors.right:          parent.right
                wrapMode:               Text.WordWrap
                horizontalAlignment:    Text.AlignHCenter
                text:                   qsTr("Click in map to set landing point.")
            }

            QGCLabel {
                anchors.left:           parent.left
                anchors.right:          parent.right
                horizontalAlignment:    Text.AlignHCenter
                text:                   qsTr("- or -")
                visible:                globals.activeVehicle
            }

            PlanButton {
                anchors.horizontalCenter:   parent.horizontalCenter
                text:                       _setToVehicleLocationStr
                visible:                    globals.activeVehicle

                onClicked: {
                    missionItem.landingCoordinate = globals.activeVehicle.coordinate
                    missionItem.landingHeading.rawValue = globals.activeVehicle.heading.rawValue
                    missionItem.setLandingHeadingToTakeoffHeading()
                }
            }
        }

        ColumnLayout {
            anchors.left:   parent.left
            anchors.right:  parent.right
            spacing:        ScreenTools.defaultFontPixelHeight / 2
            visible:        !landingCoordColumn.visible

            onVisibleChanged: {
                if (visible) {
                    console.log(missionItem.landingDistance.rawValue)
                }
            }

            QGCLabel {
                Layout.fillWidth:   true
                wrapMode:           Text.WordWrap
                text:               qsTr("拖动盘旋点以根据风向和障碍物调整降落方向。")
            }

            PlanFactCheckBox {
                text:       qsTr("顺时针盘旋")
                fact:       missionItem.loiterClockwise
                visible:    missionItem.useLoiterToAlt.rawValue
            }

            PlanButton {
                text:               qsTr("完成")
                Layout.fillWidth:   true
                onClicked: {
                    missionItem.wizardMode = false
                    missionItem.landingDragAngleOnly = false
                }
            }
        }
    }
}
