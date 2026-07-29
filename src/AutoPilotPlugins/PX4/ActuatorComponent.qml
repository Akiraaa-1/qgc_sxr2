import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.AutoPilotPlugins.PX4

SetupPage {
    id:             actuatorPage
    pageComponent:  actuators ? pageComponent : unavailableComponent
    showAdvanced:   true
    centerPageLoader: true
    property bool _qgcPopupChrome: true

    property var actuators:       globals.activeVehicle ? globals.activeVehicle.actuators : null

    property var _showAdvanced:              advanced
    readonly property real _margins:         ScreenTools.defaultFontPixelHeight

    QGCPopupStyle { id: popupStyle }

    Component {
        id: unavailableComponent

        Item {
            width: Math.min(actuatorPage.availableWidth, ScreenTools.defaultFontPixelWidth * 68)
            height: Math.max(messagePanel.implicitHeight + (_margins * 4), ScreenTools.defaultFontPixelHeight * 14)

            Rectangle {
                id: messagePanel
                anchors.centerIn: parent
                width: parent.width
                implicitHeight: messageColumn.implicitHeight + (_margins * 2)
                radius: popupStyle.cornerRadius
                color: popupStyle.panelBackground
                border.color: popupStyle.borderColor
                border.width: 1

                Column {
                    id: messageColumn
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        margins: _margins
                    }
                    spacing: _margins

                    QGCLabel {
                        width: parent.width
                        text: qsTr("执行器信息正在加载")
                        font.pointSize: ScreenTools.mediumFontPointSize
                        font.bold: true
                        color: popupStyle.primaryTextColor
                        horizontalAlignment: Text.AlignHCenter
                    }

                    QGCLabel {
                        width: parent.width
                        text: qsTr("当前飞行器还没有提供执行器 metadata。请保持连接，参数加载完成后返回菜单再进入。")
                        wrapMode: Text.WordWrap
                        color: popupStyle.secondaryTextColor
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }

    function _translatedActuatorText(text) {
        if (text && text.indexOf("Rev Range") !== -1) {
            return qsTr("反向范围（舵机）")
        }

        switch (text) {
        case "Geometry":
            return qsTr("几何")
        case "Multirotor":
            return qsTr("多旋翼")
        case "Motors":
            return qsTr("电机")
        case "Position X":
            return qsTr("X 位置")
        case "Position Y":
            return qsTr("Y 位置")
        case "Position Z":
            return qsTr("Z 位置")
        case "Direction CCW":
            return qsTr("逆时针方向")
        case "Axis":
            return qsTr("轴向")
        case "Bidirectional Slew Rate":
            return qsTr("双向响应速率")
        case "Function":
            return qsTr("功能")
        case "Disarmed":
            return qsTr("未解锁")
        case "Minimum":
            return qsTr("最小值")
        case "Maximum":
            return qsTr("最大值")
        case "Center":
        case "Trim":
        case "Neutral":
            return qsTr("中位")
        case "Actuator Outputs":
            return qsTr("执行器输出")
        case "ESCs":
            return qsTr("电调")
        case "PWM AUX":
            return qsTr("PWM 辅助")
        case "PWM MAIN":
            return qsTr("PWM 主")
        case "Configure":
            return qsTr("配置")
        case "Bitrate":
            return qsTr("比特率")
        default:
            return text
        }
    }

    function _translatedMixerTitle(title) {
        return _translatedActuatorText(title)
    }

    function _translatedChannelLabel(label) {
        const auxMatch = label.match(/^AUX (\d+(?:-\d+)?)$/)
        if (auxMatch) {
            return qsTr("AUX %1").arg(auxMatch[1])
        }
        const motorMatch = label.match(/^Motor (\d+)$/)
        if (motorMatch) {
            return qsTr("电机 %1").arg(motorMatch[1])
        }
        return _translatedActuatorText(label)
    }

    Component {
        id: pageComponent

        Item {
            id: pageRoot

            readonly property real _columnSpacing:      ScreenTools.defaultFontPixelWidth * 4
            readonly property real _outerPadding:       _margins
            readonly property real _leftColumnWidth:    Math.max(actuatorTesting.implicitWidth, mixerUi.implicitWidth) + (_margins * 2)
            readonly property real _contentWidth:       contentRow.implicitWidth

            width:          Math.max(_contentWidth + (_outerPadding * 2), Math.min(actuatorPage.availableWidth, _leftColumnWidth + (_outerPadding * 2)))
            height:         contentRow.implicitHeight + (_outerPadding * 2)
            implicitWidth:  width
            implicitHeight: height

            Rectangle {
                anchors.fill: parent
                radius: popupStyle.cornerRadius
                border.color: popupStyle.borderColor
                border.width: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#1E1E1E" }
                    GradientStop { position: 1.0; color: "#222222" }
                }
            }

            Row {
                id: contentRow
                anchors.top: parent.top
                anchors.topMargin: pageRoot._outerPadding
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: pageRoot._columnSpacing

                ColumnLayout {
                spacing:                    ScreenTools.defaultFontPixelHeight
                implicitWidth:              pageRoot._leftColumnWidth

                // mixer ui
                RowLayout {
                    Layout.preferredWidth:      pageRoot._leftColumnWidth
                    visible:                    actuators.mixer.groups.count > 0
                    QGCLabel {
                        text:                   actuatorPage._translatedActuatorText("Geometry") + (actuators.mixer.title ? ": " + actuatorPage._translatedMixerTitle(actuators.mixer.title) : "")
                        font.pointSize:         ScreenTools.mediumFontPointSize
                        Layout.fillWidth:       true
                    }
                    QGCLabel {
                        text:                   "<a href='"+actuators.mixer.helpUrl+"'>?</a>"
                        font.pointSize:         ScreenTools.mediumFontPointSize
                        visible:                actuators.mixer.helpUrl
                        textFormat:             Text.RichText
                        color:                  popupStyle.secondaryTextColor
                        onLinkActivated: (link) => {
                            Qt.openUrlExternally(link);
                        }
                    }
                }

                Rectangle {
                    implicitWidth:          pageRoot._leftColumnWidth
                    implicitHeight:         mixerUi.height + (_margins * 2)
                    color:                  popupStyle.panelBackground
                    border.color:           popupStyle.borderColor
                    border.width:           1
                    radius:                 popupStyle.cornerRadius
                    visible:                actuators.mixer.groups.count > 0

                    Column {
                        id:                 mixerUi
                        spacing:            _margins
                        anchors {
                            left:           parent.left
                            leftMargin:     _margins
                            verticalCenter: parent.verticalCenter
                        }
                        enabled:            !safetySwitch.checked && !actuators.motorAssignmentActive
                        Repeater {
                            model:          actuators.mixer.groups
                            ColumnLayout {
                                property var mixerGroup: object

                                RowLayout {
                                    QGCLabel {
                                        text:                    actuatorPage._translatedActuatorText(mixerGroup.label)
                                        font.bold:               true
                                        rightPadding:            ScreenTools.defaultFontPixelWidth * 3
                                    }
                                    ActuatorFact {
                                        property var countParam: mixerGroup.countParam
                                        visible:                 countParam != null
                                        fact:                    countParam ? countParam.fact : null
                                    }
                                }

                                GridLayout {
                                    rows:       1 + mixerGroup.channels.count
                                    columns:    1 + mixerGroup.channelConfigs.count

                                    QGCLabel {
                                        text:   ""
                                    }

                                    // param config labels
                                        Repeater {
                                            model:              mixerGroup.channelConfigs
                                            QGCLabel {
                                                text:           actuatorPage._translatedActuatorText(object.label)
                                                color:          popupStyle.secondaryTextColor
                                                visible:        object.visible && (_showAdvanced || !object.advanced)
                                                Layout.row:     0
                                                Layout.column:  1 + index
                                        }
                                    }
                                    // param instances
                                        Repeater {
                                            model:              mixerGroup.channels
                                            QGCLabel {
                                                text:           actuatorPage._translatedChannelLabel(object.label) + ":"
                                                color:          popupStyle.secondaryTextColor
                                                Layout.row:     1 + index
                                                Layout.column:  0
                                            }
                                    }
                                    Repeater {
                                        model:              mixerGroup.channels
                                        Repeater {
                                            property var channel: object
                                            property var channelIndex: index

                                            model: object.configInstances

                                            ActuatorFact {
                                                fact:           object.fact
                                                Layout.row:     1 + channelIndex
                                                Layout.column:  1 + index
                                                visible:        object.config.visible && (_showAdvanced || !object.config.advanced) && object.visible
                                                enabled:        object.enabled
                                            }
                                        }
                                    }
                                }

                                // extra group config params
                                Repeater {
                                    model: mixerGroup.configParams

                                    RowLayout {
                                        spacing:     ScreenTools.defaultFontPixelWidth
                                        QGCLabel {
                                            text:    actuatorPage._translatedActuatorText(object.label) + ":"
                                            color:   popupStyle.secondaryTextColor
                                            visible: _showAdvanced || !object.advanced
                                        }
                                        ActuatorFact {
                                            fact: object.fact
                                            visible: _showAdvanced || !object.advanced
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // actuator image
                Image {
                    id:                     actuatorImage
                    source:                 "image://actuators/geometry"+refreshFlag
                    sourceSize.width:       imageSize
                    sourceSize.height:      imageSize
                    Layout.preferredWidth:  imageSize
                    Layout.preferredHeight: imageSize
                    Layout.alignment:       Qt.AlignHCenter
                    visible:                actuators.isMultirotor
                    cache:                  false

                    property var refreshFlag:         actuators.imageRefreshFlag
                    readonly property real imageSize: 9 * ScreenTools.defaultFontPixelHeight

                    MouseArea {
                        anchors.fill:  parent
                        onClicked: (mouse) => {
                            if (mouse.button == Qt.LeftButton) {
                                actuators.imageClicked(Qt.size(width, height), mouse.x, mouse.y);
                            }
                        }
                    }
                }

                // actuator testing
                QGCLabel {
                    text:               qsTr("执行器测试")
                    font.pointSize:     ScreenTools.mediumFontPointSize
                }

                Rectangle {
                    implicitWidth:            pageRoot._leftColumnWidth
                    implicitHeight:           actuatorTesting.height + (_margins * 2)
                    color:                    popupStyle.panelBackground
                    border.color:             popupStyle.borderColor
                    border.width:             1
                    radius:                   popupStyle.cornerRadius

                    Column {
                        id:                   actuatorTesting
                        spacing:              _margins
                        anchors {
                            left:             parent.left
                            leftMargin:       _margins
                            verticalCenter:   parent.verticalCenter
                        }

                        QGCLabel {
                            text: qsTr("请先配置输出，然后再进行测试。")
                            color: popupStyle.secondaryTextColor
                            visible: actuators.actuatorTest.actuators.count == 0
                        }

                        Row {
                            spacing: ScreenTools.defaultFontPixelWidth
                            visible: actuators.actuatorTest.actuators.count > 0

                            Switch {
                                id:      safetySwitch
                                enabled: !actuators.motorAssignmentActive &&  !actuators.actuatorTest.hadFailure
                                Connections {
                                    target: actuators.actuatorTest
                                    onHadFailureChanged: {
                                        if (actuators.actuatorTest.hadFailure) {
                                            safetySwitch.checked = false;
                                            safetySwitch.switchUpdated();
                                        }
                                    }
                                }
                                onClicked: {
                                    switchUpdated();
                                }
                                function switchUpdated() {
                                    if (!checked) {
                                        for (var channelIdx=0; channelIdx<sliderRepeater.count; channelIdx++) {
                                            sliderRepeater.itemAt(channelIdx).stop();
                                        }
                                        if (allMotorsLoader.item != null)
                                            allMotorsLoader.item.stop();
                                    }
                                    actuators.actuatorTest.setActive(checked);
                                }
                            }

                            QGCLabel {
                                color:  popupStyle.secondaryTextColor
                                text: safetySwitch.checked ? qsTr("注意：执行器滑块已启用") : qsTr("确认已拆除螺旋桨 - 启用滑块")
                            }
                        } // Row

                        Row {
                            spacing: ScreenTools.defaultFontPixelWidth * 2
                            enabled: safetySwitch.checked

                            // (optional) slider for all motors
                            Loader {
                                id:                allMotorsLoader
                                sourceComponent:   actuators.actuatorTest.allMotorsActuator ?  allMotorsComponent : null
                                Layout.alignment:  Qt.AlignTop
                            }
                            Component {
                                id:                allMotorsComponent
                                ActuatorSlider {
                                    channel:       actuators.actuatorTest.allMotorsActuator
                                    rightPadding:  ScreenTools.defaultFontPixelWidth * 3
                                    onActuatorValueChanged: (value, sliderValue) => {
                                        stopTimer();
                                        for (var channelIdx=0; channelIdx<sliderRepeater.count; channelIdx++) {
                                            var channelSlider = sliderRepeater.itemAt(channelIdx);
                                            if (channelSlider.channel.isMotor) {
                                                channelSlider.value = sliderValue;
                                            }
                                        }
                                    }
                                }
                            }

                            // all channels
                            Repeater {
                                id:         sliderRepeater
                                model:      actuators.actuatorTest.actuators

                                ActuatorSlider {
                                    channel: object
                                    onActuatorValueChanged: (value) =>{
                                        if (isNaN(value)) {
                                            actuators.actuatorTest.stopControl(index);
                                            stop();
                                        } else {
                                            actuators.actuatorTest.setChannelTo(index, value);
                                        }
                                    }
                                }
                            } // Repeater
                        } // Row

                        // actuator actions
                        Column {
                            visible: actuators.actuatorActions.count > 0
                            enabled: !safetySwitch.checked && !actuators.motorAssignmentActive
                            Row {
                                spacing: ScreenTools.defaultFontPixelWidth * 2
                                Repeater {
                                    model: actuators.actuatorActions

                                    QGCButton {
                                        property var actionGroup: object
                                        text:          actionGroup.label
                                        onClicked:     actionMenu.popup()
                                        QGCMenu {
                                            id:                 actionMenu

                                            Instantiator {
                                                model:              actionGroup.actions
                                                QGCMenuItem {
                                                    text:           object.label
                                                    onTriggered:    object.trigger()
                                                }
                                                onObjectAdded:      (index, object) => actionMenu.insertItem(index, object)
                                                onObjectRemoved:    (index, object) => actionMenu.removeItem(object)
                                            }
                                        }
                                    }
                                }
                            }

                        } // Column

                    } // Column
                } // Rectangle
            }

            // Right column
            Column {
                id: actuatorOutputsColumn

                QGCLabel {
                    text:               actuatorPage._translatedActuatorText("Actuator Outputs")
                    font.pointSize:     ScreenTools.mediumFontPointSize
                    bottomPadding:      ScreenTools.defaultFontPixelHeight
                }
                QGCLabel {
                    text:          qsTr("仍有一个或多个执行器需要分配到输出。")
                    visible:       actuators.hasUnsetRequiredFunctions
                    color:         popupStyle.secondaryTextColor
                    bottomPadding: ScreenTools.defaultFontPixelHeight
                }


                // actuator output selection tabs
                QGCTabBar {
                    id: actuatorOutputsTabs

                    Repeater {
                        model: actuators.actuatorOutputs
                        QGCTabButton {
                            text:                   "   " + actuatorPage._translatedActuatorText(object.label) + "   "
                            width:                  implicitWidth
                            showBorder:             true
                            backRadius:             popupStyle.cornerRadius
                            buttonColor:            popupStyle.borderColor
                            hoverButtonColor:       popupStyle.hoverColor(popupStyle.borderColor)
                            checkedButtonColor:     Qt.rgba(popupStyle.accentColor.r, popupStyle.accentColor.g, popupStyle.accentColor.b, 0.24)
                            buttonBorderColor:      checked ? popupStyle.accentColor : popupStyle.borderColor
                            buttonTextColor:        popupStyle.secondaryTextColor
                            checkedButtonTextColor: popupStyle.primaryTextColor
                            separatorColor:         popupStyle.borderColor
                        }
                    }
                    onCurrentIndexChanged: {
                        actuators.selectActuatorOutput(currentIndex)
                    }
                }

                // actuator outputs
                Rectangle {
                    id:                             selActuatorOutput
                    implicitWidth:                  actuatorGroupColumn.implicitWidth + (_margins * 2)
                    implicitHeight:                 actuatorGroupColumn.implicitHeight + (_margins * 2)
                    color:                          popupStyle.panelBackground
                    border.color:                   popupStyle.borderColor
                    border.width:                   1
                    radius:                         popupStyle.cornerRadius

                    property var actuatorOutput:    actuators.selectedActuatorOutput

                    Column {
                        id:               actuatorGroupColumn
                        spacing:          _margins
                        anchors.centerIn: parent

                        // Motor assignment
                        Row {
                            visible:           actuators.isMultirotor
                            enabled:           !safetySwitch.checked
                            anchors.right:     parent.right
                            spacing:           _margins
                            QGCButton {
                                text:          qsTr("识别并分配电机")
                                primary:       true
                                visible:       !actuators.motorAssignmentActive && selActuatorOutput.actuatorOutput.groupsVisible
                                enabled:       actuators.motorAssignmentEnabled
                                onClicked: {
                                    var success = actuators.initMotorAssignment()
                                    if (success) {
                                        motorAssignmentConfirmDialog.open()
                                    } else {
                                        motorAssignmentFailureDialog.open()
                                    }
                                }
                                MessageDialog {
                                    id:         motorAssignmentConfirmDialog
                                    visible:    false
                                    //icon:       StandardIcon.Warning
                                    buttons:    MessageDialog.Yes | MessageDialog.No
                                    title:      qsTr("电机顺序识别与分配")
                                    text:       actuators.motorAssignmentMessage
                                    onButtonClicked: function (button, role) {
                                        switch (button) {
                                        case MessageDialog.Yes:
                                            actuators.startMotorAssignment()
                                            break;
                                        }
                                    }
                                }
                                MessageDialog {
                                    id:         motorAssignmentFailureDialog
                                    visible:    false
                                    //icon:       StandardIcon.Critical
                                    buttons:    MessageDialog.Ok
                                    title:      qsTr("错误")
                                    text:       actuators.motorAssignmentMessage
                                }
                            }
                            QGCButton {
                                text:          qsTr("重新转动电机")
                                visible:       actuators.motorAssignmentActive
                                onClicked: {
                                    actuators.spinCurrentMotor()
                                }
                            }
                            QGCButton {
                                text:          qsTr("中止")
                                visible:       actuators.motorAssignmentActive
                                onClicked: {
                                    actuators.abortMotorAssignment()
                                }
                            }
                        }

                        Column {
                            enabled:          !safetySwitch.checked && !actuators.motorAssignmentActive
                            spacing:          _margins

                            RowLayout {
                                property var enableParam:     selActuatorOutput.actuatorOutput.enableParam
                                QGCLabel {
                                    visible:                  parent.enableParam != null
                                    text:                     parent.enableParam ? actuatorPage._translatedActuatorText(parent.enableParam.label) + ":" : ""
                                    color:                    popupStyle.secondaryTextColor
                                }
                                ActuatorFact {
                                    visible:                  parent.enableParam != null
                                    fact:                     parent.enableParam ?  parent.enableParam.fact : null
                                }
                            }


                            Repeater {
                                model: selActuatorOutput.actuatorOutput.subgroups

                                ColumnLayout {
                                    property var subgroup: object
                                    visible:               selActuatorOutput.actuatorOutput.groupsVisible

                                    RowLayout {
                                        visible: subgroup.label != ""
                                        QGCLabel {
                                            text:                    actuatorPage._translatedChannelLabel(subgroup.label)
                                            font.bold:               true
                                            rightPadding:            ScreenTools.defaultFontPixelWidth * 3
                                        }
                                        ActuatorFact {
                                            property var primaryParam: subgroup.primaryParam
                                            visible:                   primaryParam != null
                                            fact:                      primaryParam ? primaryParam.fact : null
                                        }
                                    }

                                    GridLayout {
                                        rows:      1 + subgroup.channels.count
                                        columns:   1 + subgroup.channelConfigs.count

                                        QGCLabel {
                                            text: ""
                                        }

                                        // param config labels
                                            Repeater {
                                                model: subgroup.channelConfigs
                                                QGCLabel {
                                                    text:           actuatorPage._translatedActuatorText(object.label)
                                                    color:          popupStyle.secondaryTextColor
                                                    visible:        object.visible && (_showAdvanced || !object.advanced)
                                                    Layout.row:     0
                                                    Layout.column:  1 + index
                                            }
                                        }
                                        // param instances
                                            Repeater {
                                                model: subgroup.channels
                                                QGCLabel {
                                                    text:            actuatorPage._translatedChannelLabel(object.label) + ":"
                                                    color:           popupStyle.secondaryTextColor
                                                    Layout.row:      1 + index
                                                    Layout.column:   0
                                                }
                                        }
                                        Repeater {
                                            model: subgroup.channels
                                            Repeater {
                                                property var channel:      object
                                                property var channelIndex: index
                                                model:                     object.configInstances
                                                ActuatorFact {
                                                    fact:           object.fact
                                                    Layout.row:     1 + channelIndex
                                                    Layout.column:  1 + index
                                                    visible:        object.config.visible && (_showAdvanced || !object.config.advanced)
                                                }
                                            }
                                        }
                                    }

                                    // extra subgroup config params
                                    Repeater {
                                    model: subgroup.configParams

                                        RowLayout {
                                            visible: !!object.fact
                                            QGCLabel {
                                                text: actuatorPage._translatedActuatorText(object.label) + ":"
                                                color: popupStyle.secondaryTextColor
                                            }
                                            ActuatorFact {
                                                fact: object.fact
                                            }
                                        }
                                    }

                                }
                            } // subgroup Repeater

                            // extra actuator config params
                            Repeater {
                                model: selActuatorOutput.actuatorOutput.configParams

                                RowLayout {
                                    visible: !!object.fact
                                    QGCLabel {
                                        text: actuatorPage._translatedActuatorText(object.label) + ":"
                                        color: popupStyle.secondaryTextColor
                                    }
                                    ActuatorFact {
                                        fact: object.fact
                                    }
                                }
                            }

                            // notes
                            Repeater {
                                model: selActuatorOutput.actuatorOutput.notes
                                ColumnLayout {
                                    spacing: ScreenTools.defaultFontPixelHeight
                                    QGCLabel {
                                        text:       modelData
                                        color:      popupStyle.secondaryTextColor
                                    }
                                }
                            }
                        }
                    }
                } // Rectangle
            } // Column
        } // Row
        } // Item

    } // Component
}
