import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Item {
    required property var editorMap
    required property var planMasterController
    property bool dockLeft: false
    property real uiScale: 1.0

    signal editingLayerChangeRequested(int layer)

    id: root

    property var  _missionController: planMasterController.missionController
    property real _toolsMargin:       ScreenTools.defaultFontPixelWidth * 0.75 * uiScale
    property real _panelRadius:       8 * uiScale

    PlanEditorTheme { id: theme }

    function selectNextNotReady() {
        for (var i = 0; i < _missionController.visualItems.count; i++) {
            var vmi = _missionController.visualItems.get(i)
            if (vmi.readyForSaveState === VisualMissionItem.NotReadyForSaveData) {
                _missionController.setCurrentPlanViewSeqNum(vmi.sequenceNumber, true)
                break
            }
        }
    }

    QGCPalette { id: qgcPal }

    Rectangle {
        id:             rightPanelBackground
        anchors.fill:   parent
        radius:         _panelRadius
        color:          theme.panelColor
        border.width:   1
        border.color:   theme.borderColor

        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0; color: theme.windowTopColor }
            GradientStop { position: 1; color: theme.windowBottomColor }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            radius: parent.radius + 1
            color: theme.shadowColor
            z: -1
        }
    }


    // Open/Close panel
    Item {
        id:                     panelOpenCloseButton
        anchors.right:          dockLeft ? undefined : parent.left
        anchors.left:           dockLeft ? parent.right : undefined
        anchors.verticalCenter: parent.verticalCenter
        width:                  toggleButtonRect.width - toggleButtonRect.radius
        height:                 toggleButtonRect.height
        clip:                   true

        property bool _expanded: dockLeft ? root.anchors.left == root.parent.left : root.anchors.right == root.parent.right

        Rectangle {
            id:             toggleButtonRect
            width:          ScreenTools.defaultFontPixelWidth * 2.25 * root.uiScale
            height:         width * 3
            radius:         _panelRadius
            color:          toggleArea.pressed ? theme.panelPressedColor : (toggleArea.containsMouse ? theme.panelHoverColor : theme.panelColor)
            border.width:   1
            border.color:   theme.borderColor

            Behavior on color { ColorAnimation { duration: theme.stateAnimationDuration } }

            QGCLabel {
                id:                 toggleButtonLabel
                anchors.centerIn:   parent
                text:               dockLeft ? (panelOpenCloseButton._expanded ? "<" : ">") : (panelOpenCloseButton._expanded ? ">" : "<")
                color:              theme.textColor
            }

        }

        QGCMouseArea {
            id: toggleArea
            anchors.fill: parent

            onClicked: {
                if (panelOpenCloseButton._expanded) {
                    // Close panel
                    if (dockLeft) {
                        root.anchors.left = undefined
                        root.anchors.right = root.parent.left
                    } else {
                        root.anchors.right = undefined
                        root.anchors.left = root.parent.right
                    }
                } else {
                    // Open panel
                    if (dockLeft) {
                        root.anchors.right = undefined
                        root.anchors.left = root.parent.left
                    } else {
                        root.anchors.left = undefined
                        root.anchors.right = root.parent.right
                    }
                }
            }
        }
    }

    //-------------------------------------------------------
    // Right Panel Controls
    Item {
        anchors.fill: rightPanelBackground

        DeadMouseArea {
            anchors.fill:   parent
        }

        PlanTreeView {
            id:                     planTreeView
            anchors.fill:           parent
            editorMap:              root.editorMap
            planMasterController:   root.planMasterController
            uiScale:                root.uiScale
            onEditingLayerChangeRequested: (layer) => root.editingLayerChangeRequested(layer)
        }
    }

    function selectLayer(nodeType) {
        // Ensure panel is open
        if (!panelOpenCloseButton._expanded) {
            if (dockLeft) {
                root.anchors.right = undefined
                root.anchors.left = root.parent.left
            } else {
                root.anchors.left = undefined
                root.anchors.right = root.parent.right
            }
        }
        planTreeView.selectLayer(nodeType)
    }
}
