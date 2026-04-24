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
    property bool showHeader: true
    property bool showHeaderAction: true
    property string headerTitle: qsTr("INSTRUMENTS")
    property real headerHeight: ScreenTools.defaultFontPixelHeight * 1.08
    property real headerSpacing: ScreenTools.defaultFontPixelWidth * 0.16
    property real headerTitleSize: ScreenTools.defaultFontPixelHeight * 0.66
    property color headerTitleColor: qgcPal.text
    property real headerActionSize: ScreenTools.defaultFontPixelHeight * 1.08
    property real headerActionRightMargin: ScreenTools.defaultFontPixelWidth * 0.06
    property real headerActionRadius: ScreenTools.defaultFontPixelHeight * 0.12
    property real headerActionIconScale: 0.46
    property color headerActionColor: "transparent"
    property color headerActionHoverColor: "transparent"
    property color headerActionPressedColor: "transparent"
    property color headerActionBorderColor: "transparent"
    property color headerActionIconColor: qgcPal.text
    property int headerTransitionDuration: 200
    property real panelLeftMargin: ScreenTools.defaultFontPixelHeight * 0.35
    property real panelRightMargin: ScreenTools.defaultFontPixelHeight * 0.35
    property real panelTopMargin: ScreenTools.defaultFontPixelHeight * 0.16
    property real panelBottomMargin: ScreenTools.defaultFontPixelHeight * 0.35
    signal headerActionTriggered()
    readonly property Item _activePanel: root.useLegacySelectableControl ? legacySelectablePanel : instrumentCardsPanel

    QGCPalette {
        id: qgcPal
        colorGroupEnabled: true
    }

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
        showHeader: root.showHeader
        showHeaderAction: root.showHeaderAction
        headerTitle: root.headerTitle
        headerHeight: root.headerHeight
        headerSpacing: root.headerSpacing
        headerTitleSize: root.headerTitleSize
        headerTitleColor: root.headerTitleColor
        headerActionSize: root.headerActionSize
        headerActionRightMargin: root.headerActionRightMargin
        headerActionRadius: root.headerActionRadius
        headerActionIconScale: root.headerActionIconScale
        headerActionColor: root.headerActionColor
        headerActionHoverColor: root.headerActionHoverColor
        headerActionPressedColor: root.headerActionPressedColor
        headerActionBorderColor: root.headerActionBorderColor
        headerActionIconColor: root.headerActionIconColor
        headerTransitionDuration: root.headerTransitionDuration
        panelLeftMargin: root.panelLeftMargin
        panelRightMargin: root.panelRightMargin
        panelTopMargin: root.panelTopMargin
        panelBottomMargin: root.panelBottomMargin
        onHeaderActionTriggered: root.headerActionTriggered()
    }
}
