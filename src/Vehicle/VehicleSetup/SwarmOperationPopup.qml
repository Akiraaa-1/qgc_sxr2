import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: swarmOpPopup

    property int sysId: 0
    property int opType: 0
    property int result: 0
    property int oldValue: 0
    property int newValue: 0
    property string message: ""
    property bool isSuccess: result === 0
    property var messageQueue: []
    property bool isShowing: false

    function operationTitle(type, success) {
        switch (type) {
        case 1:
            return qsTr("Group Updated")
        case 2:
            return qsTr("Role Updated")
        case 5:
            return qsTr("Takeoff")
        case 6:
            return qsTr("Land")
        case 7:
            return qsTr("Pause")
        case 8:
            return qsTr("Resume")
        default:
            return success ? qsTr("Operation Succeeded") : qsTr("Operation Failed")
        }
    }

    function operationAccent(type, success) {
        switch (type) {
        case 1:
            return "#5e81ac"
        case 2:
            return "#88c0d0"
        default:
            return success ? "#4CAF50" : "#f44336"
        }
    }

    width: Math.min(360, parent ? parent.width - 40 : 360)
    height: Math.max(86, popupRow.implicitHeight + 24)
    radius: 8
    color: Qt.darker(operationAccent(opType, isSuccess), 2.1)
    border.color: operationAccent(opType, isSuccess)
    border.width: 2
    visible: false
    opacity: 0

    anchors.right: parent ? parent.right : undefined
    anchors.top: parent ? parent.top : undefined
    anchors.rightMargin: 20
    anchors.topMargin: 100

    RowLayout {
        id: popupRow
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        Rectangle {
            width: 40
            height: 40
            radius: 20
            color: operationAccent(opType, isSuccess)

            Text {
                anchors.centerIn: parent
                text: isSuccess ? "\u2713" : "!"
                font.pixelSize: 24
                font.bold: true
                color: "white"
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Text {
                text: operationTitle(opType, isSuccess)
                font.pixelSize: 14
                font.bold: true
                color: "white"
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Text {
                text: message
                font.pixelSize: 12
                color: "#e0e0e0"
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                Layout.maximumWidth: 250
            }
        }

        Rectangle {
            width: 24
            height: 24
            radius: 12
            color: closeMouseArea.containsMouse ? "#ffffff30" : "transparent"

            Text {
                anchors.centerIn: parent
                text: "x"
                font.pixelSize: 16
                color: "#e0e0e0"
            }

            MouseArea {
                id: closeMouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: hidePopup()
            }
        }
    }

    Timer {
        id: autoCloseTimer
        interval: 6000
        onTriggered: hidePopup()
    }

    Timer {
        id: queueTimer
        interval: 500
        onTriggered: processQueue()
    }

    Behavior on opacity {
        NumberAnimation { duration: 200 }
    }

    Behavior on y {
        NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
    }

    function showPopup(nextSysId, nextOpType, nextResult, nextOldValue, nextNewValue, msg) {
        messageQueue.push({
            sysId: nextSysId,
            opType: nextOpType,
            result: nextResult,
            oldValue: nextOldValue,
            newValue: nextNewValue,
            message: msg
        })

        if (!isShowing) {
            processQueue()
        }
    }

    function processQueue() {
        if (messageQueue.length === 0) {
            return
        }

        var data = messageQueue.shift()
        swarmOpPopup.sysId = data.sysId
        swarmOpPopup.opType = data.opType
        swarmOpPopup.result = data.result
        swarmOpPopup.oldValue = data.oldValue
        swarmOpPopup.newValue = data.newValue
        swarmOpPopup.message = data.message

        isShowing = true
        visible = true
        opacity = 1
        autoCloseTimer.restart()
    }

    function hidePopup() {
        autoCloseTimer.stop()
        opacity = 0
        hideTimer.start()
    }

    Timer {
        id: hideTimer
        interval: 200
        onTriggered: {
            visible = false
            isShowing = false

            if (messageQueue.length > 0) {
                queueTimer.start()
            }
        }
    }
}
