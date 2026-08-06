import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

TextArea {
    id:                     messageText
    Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 50
    height:                 contentHeight
    readOnly:               true
    textFormat:             TextEdit.RichText
    color:                  qgcPal.text
    placeholderText:        qsTr("暂无消息")
    placeholderTextColor:   qgcPal.text
    padding:                0
    wrapMode:               TextEdit.Wrap

    property bool noMessages: messageText.length === 0

    property var _fact: null

    function localizeVehicleMessage(message) {
        let localizedMessage = message || ""
        const exactTranslations = [
            { "source": "Calibration: Disabling RC input", "text": qsTr("校准：正在禁用 RC 输入") },
            { "source": "Calibration: Restoring RC input", "text": qsTr("校准：正在恢复 RC 输入") },
            { "source": "Navigation error: No valid position estimate", "text": qsTr("导航错误：无有效位置估计") }
        ]
        for (let i = 0; i < exactTranslations.length; i++) {
            const item = exactTranslations[i]
            const escapedSource = item.source.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
            localizedMessage = localizedMessage.replace(new RegExp(escapedSource, "gi"), qsTr("%1（%2）").arg(item.text).arg(item.source))
        }
        const replacements = [
            { "pattern": /No valid mission available, loitering/gi, "text": qsTr("没有可执行的有效任务，飞行器正在保持/盘旋") },
            { "pattern": /No valid mission available/gi, "text": qsTr("没有可执行的有效任务") },
            { "pattern": /loitering/gi, "text": qsTr("正在保持/盘旋") },
            { "pattern": /Mission rejected/gi, "text": qsTr("任务被拒绝") },
            { "pattern": /Mission upload failed/gi, "text": qsTr("任务上传失败") },
            { "pattern": /Mission transfer failed/gi, "text": qsTr("任务传输失败") },
            { "pattern": /Mission accepted/gi, "text": qsTr("任务已接受") },
            { "pattern": /Mission finished/gi, "text": qsTr("任务已完成") },
            { "pattern": /Preflight Fail: No connection to the GCS/gi, "text": qsTr("起飞前检查失败：未连接到地面站") },
            { "pattern": /Preflight Fail/gi, "text": qsTr("起飞前检查失败") },
            { "pattern": /Geofence violation/gi, "text": qsTr("触发地理围栏限制") },
            { "pattern": /Failsafe enabled/gi, "text": qsTr("失效保护已触发") },
            { "pattern": /Failsafe activated/gi, "text": qsTr("失效保护已激活") },
            { "pattern": /Battery low/gi, "text": qsTr("电池电量低") },
            { "pattern": /GPS signal lost/gi, "text": qsTr("GPS 信号丢失") },
            { "pattern": /Manual control lost/gi, "text": qsTr("手动控制链路丢失") },
            { "pattern": /Data link lost/gi, "text": qsTr("数传链路丢失") },
            { "pattern": /Return to launch/gi, "text": qsTr("正在返航") },
            { "pattern": /Takeoff detected/gi, "text": qsTr("检测到起飞") },
            { "pattern": /Landing detected/gi, "text": qsTr("检测到降落") },
            { "pattern": /GCS connection regained/gi, "text": qsTr("地面站连接已恢复") },
            { "pattern": /GCS connection lost/gi, "text": qsTr("地面站连接丢失") },
            { "pattern": /Switching to mode 'Position control' is currently not possible No manual control input/gi, "text": qsTr("当前无法切换到“位置控制”模式：没有手动控制输入") },
            { "pattern": /No manual control input/gi, "text": qsTr("没有手动控制输入") }
        ]

        for (let i = 0; i < replacements.length; i++) {
            localizedMessage = localizedMessage.replace(replacements[i].pattern, replacements[i].text)
        }
        return localizedMessage
    }

    function formatMessage(message) {
        message = localizeVehicleMessage(message)
        message = message.replace(new RegExp("<#E>", "g"), "color: " + qgcPal.warningText + "; font: " + (ScreenTools.defaultFontPointSize.toFixed(0) - 1) + "pt monospace;");
        message = message.replace(new RegExp("<#I>", "g"), "color: " + qgcPal.warningText + "; font: " + (ScreenTools.defaultFontPointSize.toFixed(0) - 1) + "pt monospace;");
        message = message.replace(new RegExp("<#N>", "g"), "color: " + qgcPal.text + "; font: " + (ScreenTools.defaultFontPointSize.toFixed(0) - 1) + "pt monospace;");
        return message;
    }

    Component.onCompleted: {
        messageText.text = formatMessage(_activeVehicle.formattedMessages)
        if (_activeVehicle) {
            _activeVehicle.resetAllMessages()
        }
    }

    Connections {
        target: _activeVehicle
        function onNewFormattedMessage(formattedMessage) { messageText.insert(0, formatMessage(formattedMessage)) }
    }

    FactPanelController {
        id: controller
    }

    onLinkActivated: (link) => {
        if (link.startsWith('param://')) {
            var paramName = link.substr(8);
            _fact = controller.getParameterFact(-1, paramName, true)
            if (_fact != null) {
                paramEditorDialogFactory.open()
            }
        } else {
            Qt.openUrlExternally(link);
        }
    }

    QGCPopupDialogFactory {
        id: paramEditorDialogFactory

        dialogComponent: paramEditorDialogComponent
    }

    Component {
        id: paramEditorDialogComponent

        ParameterEditorDialog {
            title:          qsTr("Edit Parameter")
            fact:           messageText._fact
            destroyOnClose: true
        }
    }

    Rectangle {
        anchors.right:   parent.right
        anchors.top:     parent.top
        width:                      ScreenTools.defaultFontPixelHeight * 1.25
        height:                     width
        radius:                     width / 2
        color:                      QGroundControl.globalPalette.button
        border.color:               QGroundControl.globalPalette.buttonText
        visible:                    !noMessages

        QGCColoredImage {
            anchors.margins:    ScreenTools.defaultFontPixelHeight * 0.25
            anchors.centerIn:   parent
            anchors.fill:       parent
            sourceSize.height:  height
            source:             "/res/TrashDelete.svg"
            fillMode:           Image.PreserveAspectFit
            mipmap:             true
            smooth:             true
            color:              qgcPal.text
        }

        QGCMouseArea {
            fillItem: parent
            onClicked: {
                _activeVehicle.clearMessages()
                mainWindow.closeIndicatorDrawer()
            }
        }
    }
}
