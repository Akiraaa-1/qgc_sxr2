import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

/// The PreFlightCheckButton supports creating a button which the user then has to verify/click to confirm a check.
/// It also supports failing the check based on values from within the system: telemetry or QGC app values. These
/// controls are normally placed within a PreFlightCheckGroup.
///
/// Two types of checks may be included on the button:
///     Manual - This is simply a check which the user must verify and confirm. It is not based on any system state.
///     Telemetry - This type of check can fail due to some state within the system. A telemetry check failure can be
///                 a hard stop in that there is no way to pass the checklist until the system state resolves itself.
///                 Or it can also optionally be override by the user.
/// If a button uses both manual and telemetry checks, the telemetry check takes precendence and must be passed first.
QGCButton {
    property string name:                           ""
    property string manualText:                     ""      ///< text to show for a manual check, "" signals no manual check
    property string telemetryTextFailure                    ///< text to show if telemetry check failed (override not allowed)
    property bool   telemetryFailure:               false   ///< true: telemetry check failing, false: telemetry check passing
    property bool   allowTelemetryFailureOverride:  false   ///< true: user can click past telemetry failure
    property bool   passed:                         _manualState === _statePassed && _telemetryState === _statePassed
    property bool   failed:                         _manualState === _stateFailed || _telemetryState === _stateFailed

    property int _manualState:          manualText === "" ? _statePassed : _statePending
    property int _telemetryState:       _statePassed
    property int _horizontalPadding:    ScreenTools.defaultFontPixelWidth
    property int _verticalPadding:      Math.round(ScreenTools.defaultFontPixelHeight / 2)
    property real _stateFlagWidth:      ScreenTools.defaultFontPixelWidth * 4

    readonly property int _statePending:    0   ///< Telemetry check is failing or manual check not yet verified, user can click to make it pass
    readonly property int _stateFailed:     1   ///< Telemetry check is failing, user cannot click to make it pass
    readonly property int _statePassed:     2   ///< Check has passed

    readonly property color _passedColor:   "#8FCB7B"
    readonly property color _pendingColor:  "#D9A441"
    readonly property color _failedColor:   "#D85D5D"
    readonly property color _panelColor:    "#242824"
    readonly property color _panelHoverColor: "#2D332D"
    readonly property color _borderColor:   "#3D463F"

    property string _text: "<b>" + name +"</b>: " +
                           ((_telemetryState !== _statePassed) ?
                               telemetryTextFailure :
                               (_manualState !== _statePassed ? manualText : qsTr("Passed")))
    property color  _color: _telemetryState === _statePassed && _manualState === _statePassed ?
                                _passedColor :
                                (_telemetryState == _stateFailed ?
                                     _failedColor :
                                     (_telemetryState === _statePending || _manualState === _statePending ?
                                          _pendingColor :
                                          _failedColor))

    width:          40 * ScreenTools.defaultFontPixelWidth
    topPadding:     0
    bottomPadding:  0
    leftPadding:    0
    rightPadding:   0
    implicitHeight: Math.max(ScreenTools.defaultFontPixelHeight * 2.45, checkText.implicitHeight + ScreenTools.defaultFontPixelHeight * 0.95)

    background: Rectangle {
        color:          pressed ? "#1E231E" : (hovered ? _panelHoverColor : _panelColor)
        radius:         ScreenTools.defaultFontPixelHeight * 0.28
        border.width:   1
        border.color:   _borderColor
        clip:           true

        Rectangle {
            color:          _color
            anchors.left:   parent.left
            anchors.top:    parent.top
            anchors.bottom: parent.bottom
            width:          ScreenTools.defaultFontPixelWidth * 0.45
        }

        Behavior on color { ColorAnimation { duration: 160 } }
    }

    contentItem: RowLayout {
        anchors.fill: parent
        anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 1.05
        anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.85
        anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.34
        anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.34
        spacing: ScreenTools.defaultFontPixelWidth * 0.55

        Rectangle {
            Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.62
            Layout.preferredHeight: Layout.preferredWidth
            Layout.alignment: Qt.AlignVCenter
            radius: width / 2
            color: Qt.rgba(_color.r, _color.g, _color.b, 0.16)
            border.width: 1
            border.color: _color

            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.42
                height: width
                radius: width / 2
                color: _color
            }
        }

        QGCLabel {
            id: checkText
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.alignment: Qt.AlignVCenter
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
            color: "#F0F3EA"
            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.62
            textFormat: Text.RichText
            lineHeight: 1.12
            lineHeightMode: Text.ProportionalHeight
            text: _text
        }
    }

    function _updateTelemetryState() {
        if (telemetryFailure) {
            // We have a new telemetry failure, reset user pass
            _telemetryState = allowTelemetryFailureOverride ? _statePending : _stateFailed
        } else {
            _telemetryState = _statePassed
        }
    }

    onTelemetryFailureChanged:              _updateTelemetryState()
    onAllowTelemetryFailureOverrideChanged: _updateTelemetryState()

    onClicked: {
        if (telemetryFailure && !allowTelemetryFailureOverride) {
            // No way to proceed past this failure
            return
        }
        if (telemetryFailure && allowTelemetryFailureOverride && _telemetryState !== _statePassed) {
            // User is allowed to proceed past this failure
            _telemetryState = _statePassed
            return
        }
        if (manualText !== "") {
            // User is confirming a manual check
            _manualState = (_manualState === _statePassed) ? _statePending : _statePassed
        }
    }

    onPassedChanged: callButtonPassedChanged()
    onParentChanged: callButtonPassedChanged()

    function callButtonPassedChanged() {
        if (typeof parent.buttonPassedChanged === "function") {
            parent.buttonPassedChanged()
        }
    }

    function reset() {
        _manualState = manualText === "" ? _statePassed : _statePending
        if (telemetryFailure) {
            _telemetryState = allowTelemetryFailureOverride ? _statePending : _stateFailed
        } else {
            _telemetryState = _statePassed
        }
    }

}
