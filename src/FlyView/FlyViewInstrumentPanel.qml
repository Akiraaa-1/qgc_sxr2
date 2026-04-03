import QtQuick

import QGroundControl
import QGroundControl.Controls

Item {
    id: root

    z: QGroundControl.zOrderWidgets
    implicitWidth: _activePanel ? _activePanel.implicitWidth : 0
    implicitHeight: _activePanel ? _activePanel.implicitHeight : 0

    property bool useLegacySelectableControl: true
    property var missionController: _missionController
    property real extraInset: root.useLegacySelectableControl
        ? (legacySelectablePanel.innerControl && legacySelectablePanel.innerControl.extraInset !== undefined ? legacySelectablePanel.innerControl.extraInset : 0)
        : (instrumentCardsPanel.extraInset !== undefined ? instrumentCardsPanel.extraInset : 0)
    property real extraValuesWidth: root.useLegacySelectableControl
        ? (legacySelectablePanel.innerControl && legacySelectablePanel.innerControl.extraValuesWidth !== undefined ? legacySelectablePanel.innerControl.extraValuesWidth : 0)
        : (instrumentCardsPanel.extraValuesWidth !== undefined ? instrumentCardsPanel.extraValuesWidth : 0)
    readonly property Item _activePanel: root.useLegacySelectableControl ? legacySelectablePanel : instrumentCardsPanel

    SelectableControl {
        id: legacySelectablePanel
        anchors.fill: parent
        visible: root.useLegacySelectableControl
        selectionUIRightAnchor: true
        selectedControl: QGroundControl.settingsManager.flyViewSettings.instrumentQmlFile2
    }

    FlyViewInstrumentCards {
        id: instrumentCardsPanel
        visible: !root.useLegacySelectableControl
        anchors.fill: parent
    }
}
