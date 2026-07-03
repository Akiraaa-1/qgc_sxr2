import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

QGCComboBox {
    property Fact fact: Fact { }
    property bool indexModel: fact ? fact.enumValues.length === 0 : true // true: Fact values are indices, false: Fact values are FactMetadata.enumValues

    function _translateEnumText(text) {
        const directTranslation = translations[text]
        if (directTranslation) {
            return directTranslation
        }

        if (/^(Yaw|Roll|Pitch) \d+°(?:, (Yaw|Roll|Pitch) \d+°)*$/.test(text)) {
            return text
            .replace(/Yaw/g, qsTr("偏航"))
            .replace(/Roll/g, qsTr("横滚"))
            .replace(/Pitch/g, qsTr("俯仰"))
        }

        return text
    }

    readonly property var _translatedEnumStrings: {
        if (!fact || !fact.enumStrings) {
            return null
        }

        return fact.enumStrings.map(text => _translateEnumText(text))
    }

    readonly property var translations: ({
            "Warning": qsTr("警告"),
            "Hold mode": qsTr("保持模式"),
            "Disabled": qsTr("禁用"),
            "Return mode": qsTr("返航模式"),
            "Land mode": qsTr("降落模式"),
            "Terminate": qsTr("终止"),
            "Disarm": qsTr("上锁"),
            "Hold and Disarm": qsTr("保持并上锁"),
            "Return at critical level, land at emergency level": qsTr("临界电量时返航，紧急电量时降落"),
            "None": qsTr("无"),
            "No rotation": qsTr("无旋转"),
            "MAV_CMD_NAV_WAYPOINT": qsTr("航点"),
            "MAV_FRAME_GLOBAL": qsTr("全球绝对高度"),
            "MAV_FRAME_GLOBAL_RELATIVE_ALT": qsTr("全球相对高度"),
            "MAV_FRAME_GLOBAL_TERRAIN_ALT": qsTr("全球地形高度"),
            "MAV_FRAME_GLOBAL_INT": qsTr("全球绝对高度"),
            "MAV_FRAME_GLOBAL_RELATIVE_ALT_INT": qsTr("全球相对高度"),
            "MAV_FRAME_GLOBAL_TERRAIN_ALT_INT": qsTr("全球地形高度"),
            "Power Module": qsTr("电源模块"),
            "External": qsTr("外部"),
            "ESCs": qsTr("电调"),
            "Motor 1": qsTr("电机 1"),
            "Motor 2": qsTr("电机 2"),
            "Motor 3": qsTr("电机 3"),
            "Motor 4": qsTr("电机 4"),
            "Motor 5": qsTr("电机 5"),
            "Motor 6": qsTr("电机 6"),
            "Motor 7": qsTr("电机 7"),
            "Motor 8": qsTr("电机 8"),
            "All Motors": qsTr("所有电机"),
            "RC Roll": qsTr("RC 横滚"),
            "RC Pitch": qsTr("RC 俯仰"),
            "RC Yaw": qsTr("RC 偏航"),
            "RC Throttle": qsTr("RC 油门"),
            "RC Flaps": qsTr("RC 襟翼"),
            "RC AUX 1": qsTr("RC 辅助 1"),
            "RC AUX 2": qsTr("RC 辅助 2"),
            "RC AUX 3": qsTr("RC 辅助 3"),
            "RC AUX 4": qsTr("RC 辅助 4"),
            "Landing Gear": qsTr("起落架"),
            "Parachute": qsTr("降落伞"),
            "Camera Trigger": qsTr("相机触发"),
            "Camera Capture": qsTr("相机拍摄"),
            "Gimbal Roll": qsTr("云台横滚"),
            "Gimbal Pitch": qsTr("云台俯仰"),
            "Gimbal Yaw": qsTr("云台偏航"),
            "Sensors Manual Config": qsTr("传感器手动配置"),
            "Sensors Automatic Config": qsTr("传感器自动配置"),
            "Sensors and Actuators (ESCs) Automatic Config": qsTr("传感器和执行器（电调）自动配置"),
            "Peripheral via Actuator Set 1": qsTr("通过执行器组 1 的外设"),
            "Peripheral via Actuator Set 2": qsTr("通过执行器组 2 的外设"),
            "Peripheral via Actuator Set 3": qsTr("通过执行器组 3 的外设"),
            "Peripheral via Actuator Set 4": qsTr("通过执行器组 4 的外设"),
            "Peripheral via Actuator Set 5": qsTr("通过执行器组 5 的外设"),
            "Peripheral via Actuator Set 6": qsTr("通过执行器组 6 的外设")
        })

    model: _translatedEnumStrings

    currentIndex: fact ? (indexModel ? fact.value : fact.enumIndex) : 0

    function _updateCurrentIndex() {
        Qt.callLater(function() {
            currentIndex = Qt.binding(function() {
                return fact ? (indexModel ? fact.value : fact.enumIndex) : 0
            })
        })
    }

    onModelChanged: {
        // When the model changes, the index gets reset to 0, so re-establish
        // the declarative currentIndex binding. callLater() avoids a binding
        // loop since enumIndex could trigger a model change.
        _updateCurrentIndex()
    }

    onFactChanged: {
        // When the fact changes to a different Fact object with the same
        // enumStrings, modelChanged does not fire, so the binding must be
        // re-established here to point at the new Fact.
        _updateCurrentIndex()
    }

    onActivated: (index) => {
        if (indexModel) {
            fact.value = index
        } else {
            fact.value = fact.enumValues[index]
        }
    }
}
