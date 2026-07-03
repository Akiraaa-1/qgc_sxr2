import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

QGCPopupDialog {
    id:                     escCalibrationDlg
    title:                  qsTr("ESC 校准")
    buttons:                Dialog.Ok
    acceptButtonEnabled:    false

    readonly property string _highlightPrefix: "<font color=\"" + qgcPal.warningText + "\">"
    readonly property string _highlightSuffix: "</font>"

    Connections {
        target: controller

        function onOldFirmware() {
            textLabel.text = _highlightPrefix + qsTr("ESC 校准失败。") + _highlightSuffix +
                qsTr("%1 无法使用当前固件版本执行 ESC 校准。你需要升级到更新的固件。").arg(QGroundControl.appName)
            escCalibrationDlg.acceptButtonEnabled = true
        }

        function onNewerFirmware() {
            textLabel.text = _highlightPrefix + qsTr("ESC 校准失败。") + _highlightSuffix +
                qsTr("%1 无法使用当前固件版本执行 ESC 校准。你需要升级 %1。").arg(QGroundControl.appName)
            escCalibrationDlg.acceptButtonEnabled = true
        }

        function onDisconnectBattery() {
            textLabel.text = _highlightPrefix + qsTr("ESC 校准失败。") + _highlightSuffix +
                qsTr("在执行 ESC 校准前必须断开电池。请断开电池后重试。")
            escCalibrationDlg.acceptButtonEnabled = true
        }

        function onConnectBattery() {
            textLabel.text = _highlightPrefix + qsTr("警告：在执行 ESC 校准前必须拆下螺旋桨。") + _highlightSuffix +
                qsTr(" 现在接通电池后将开始校准。")
        }

        function onBatteryConnected() {
            textLabel.text = qsTr("正在执行校准。这将需要几秒钟。")
        }

        function onCalibrationFailed(errorMessage) {
            escCalibrationDlg.acceptButtonEnabled = true
            textLabel.text = _highlightPrefix + qsTr("ESC 校准失败。") + _highlightSuffix + errorMessage
        }

        function onCalibrationSuccess() {
            escCalibrationDlg.acceptButtonEnabled = true
            textLabel.text = qsTr("校准完成。现在可以断开电池了。")
        }
    }

    Component.onCompleted: controller.calibrateEsc()

    ColumnLayout {
        QGCLabel {
            id:                     textLabel
            wrapMode:               Text.WordWrap
            text:                   qsTr("正在开始 ESC 校准...")
            Layout.fillWidth:       true
            Layout.maximumWidth:    mainWindow.width / 2
        }
    }
}
