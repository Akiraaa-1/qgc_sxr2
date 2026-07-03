import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

Item {
    id:         _root

    property bool   _qgcPopupChrome: true
    property Fact   _editorDialogFact: Fact { }
    property int    _rowHeight:         ScreenTools.defaultFontPixelHeight * 2
    property int    _rowWidth:          10 // Dynamic adjusted at runtime
    property bool   _searchFilter:      searchText.text.trim() != "" || controller.showModifiedOnly || controller.showFavoritesOnly  ///< true: showing results of search
    property var    _searchResults      ///< List of parameter names from search results
    property var    _activeVehicle:     QGroundControl.multiVehicleManager.activeVehicle
    property bool   _showRCToParam:     _activeVehicle.px4Firmware
    property var    _appSettings:       QGroundControl.settingsManager.appSettings
    property var    _controller:        controller
    property var    _favorites:         controller.favoriteParameterNames
    property var    _parameterGroupNameTranslations: null
    property var    _parameterHeaderTranslations: null
    property var    _parameterDescriptionTranslations: null
    property var    _parameterDisplayDescriptionCache: ({})
    property var    _parameterValueTranslations: null
    property real   _margins:           ScreenTools.defaultFontPixelHeight / 2
    readonly property real _pageOuterMargin: Math.max(ScreenTools.defaultFontPixelHeight, 16)
    readonly property real _pageInnerMargin: Math.max(ScreenTools.defaultFontPixelHeight * 0.9, 14)
    readonly property real _panelInnerMargin: Math.max(ScreenTools.defaultFontPixelHeight * 0.7, 10)
    readonly property real _panelSpacing: Math.max(ScreenTools.defaultFontPixelWidth * 0.9, 10)
    readonly property real _cardWidth: {
        const availableWidth = Math.max(ScreenTools.defaultFontPixelWidth * 34, width - (_pageOuterMargin * 2))
        const targetWidth = ScreenTools.defaultFontPixelWidth * 118
        const compactWidth = ScreenTools.defaultFontPixelWidth * 56
        return availableWidth < compactWidth ? availableWidth : Math.min(targetWidth, availableWidth)
    }
    readonly property real _cardHeight: {
        const availableHeight = Math.max(ScreenTools.defaultFontPixelHeight * 18, height - (_pageOuterMargin * 2))
        const targetHeight = ScreenTools.defaultFontPixelHeight * 42
        const compactHeight = ScreenTools.defaultFontPixelHeight * 28
        return availableHeight < compactHeight ? availableHeight : Math.min(targetHeight, availableHeight)
    }
    readonly property real _groupPanelWidth: Math.min(ScreenTools.defaultFontPixelWidth * 27, Math.max(ScreenTools.defaultFontPixelWidth * 20, _cardWidth * 0.27))
    readonly property real _toolsMenuWidth: Math.max(ScreenTools.defaultFontPixelWidth * 42, ScreenTools.implicitButtonWidth * 2.8)
    readonly property real _favoriteColumnWidth: ScreenTools.implicitCheckBoxHeight + ScreenTools.defaultFontPixelWidth
    readonly property real _nameColumnWidth: ScreenTools.defaultFontPixelWidth * 22
    readonly property real _valueColumnWidth: ScreenTools.defaultFontPixelWidth * 18

    QGCPopupStyle { id: popupStyle }

    function _openToolsMenu() {
        const menuMargin = ScreenTools.defaultFontPixelWidth
        const popupPoint = toolsButton.mapToItem(_root, 0, toolsButton.height)
        const popupHeight = Math.max(toolsMenu.implicitHeight, ScreenTools.implicitButtonHeight)
        const popupGap = Math.max(2, ScreenTools.defaultFontPixelHeight * 0.08)
        const maxX = Math.max(menuMargin, _root.width - toolsMenu.width - menuMargin)
        const maxY = Math.max(menuMargin, _root.height - popupHeight - menuMargin)
        const popupX = Math.max(menuMargin, Math.min(popupPoint.x + toolsButton.width - toolsMenu.width, maxX))
        const popupY = Math.max(menuMargin, Math.min(popupPoint.y + popupGap, maxY))

        toolsMenu.popup(popupX, popupY)
    }

    function _displayParameterGroupName(name) {
        if (!_parameterGroupNameTranslations) {
            _parameterGroupNameTranslations = {
            "ADSB": qsTr("ADSB"),
            "Actuator Outputs": qsTr("执行器输出"),
            "Airspeed Validator": qsTr("空速验证器"),
            "Attitude Q estimator": qsTr("姿态四元数估计器"),
            "Autotune": qsTr("自动调参"),
            "Standard": qsTr("标准"),
            "Battery Calibration": qsTr("电池校准"),
            "Camera trigger": qsTr("相机触发"),
            "Circuit Breaker": qsTr("断路器"),
            "Magnetometer": qsTr("磁力计"),
            "Sensors": qsTr("传感器"),
            "Camera Control": qsTr("相机控制"),
            "Geometry": qsTr("几何布局"),
            "Commander": qsTr("指挥器"),
            "Developer": qsTr("开发者"),
            "EKF2": qsTr("EKF2"),
            "Events": qsTr("事件"),
            "FW Attitude Control": qsTr("固定翼姿态控制"),
            "FW Auto Landing": qsTr("固定翼自动降落"),
            "FW Auto Takeoff": qsTr("固定翼自动起飞"),
            "FW General": qsTr("固定翼通用"),
            "FW Lateral Control": qsTr("固定翼横向控制"),
            "FW Longitudinal Control": qsTr("固定翼纵向控制"),
            "FW NPFG Control": qsTr("固定翼 NPFG 控制"),
            "FW Performance": qsTr("固定翼性能"),
            "FW Rate Control": qsTr("固定翼角速率控制"),
            "Failure Detector": qsTr("故障检测器"),
            "Flight Task Orbit": qsTr("绕点飞行任务"),
            "Follow target": qsTr("跟随目标"),
            "GPS": qsTr("GPS"),
            "Geofence": qsTr("地理围栏"),
            "Hover Thrust Estimator": qsTr("悬停推力估计器"),
            "Land Detector": qsTr("着陆检测器"),
            "Landing Target Estimator": qsTr("降落目标估计器"),
            "Local Position Estimator": qsTr("本地位置估计器"),
            "MAVLink": qsTr("MAVLink"),
            "Magnetometer Bias Estimator": qsTr("磁力计偏置估计器"),
            "Manual Control": qsTr("手动控制"),
            "Mission": qsTr("任务"),
            "Mixer Output": qsTr("混控输出"),
            "Mount": qsTr("云台"),
            "Multicopter Acro Mode": qsTr("多旋翼特技模式"),
            "Multicopter Attitude Control": qsTr("多旋翼姿态控制"),
            "Multicopter Position Control": qsTr("多旋翼位置控制"),
            "Multicopter Position Slow Mode": qsTr("多旋翼慢速位置模式"),
            "Multicopter Rate Control": qsTr("多旋翼角速率控制"),
            "OSD": qsTr("OSD"),
            "PWM Outputs": qsTr("PWM 输出"),
            "Payload Deliverer": qsTr("载荷投放"),
            "Precision Land": qsTr("精准降落"),
            "Pure Pursuit": qsTr("Pure Pursuit"),
            "Radio Calibration": qsTr("遥控器校准"),
            "Radio Switches": qsTr("遥控器开关"),
            "Return Mode": qsTr("返航模式"),
            "Return To Land": qsTr("返航降落"),
            "Rover Ackermann": qsTr("阿克曼无人车"),
            "Rover Attitude Control": qsTr("无人车姿态控制"),
            "Rover Differential": qsTr("差速无人车"),
            "Rover Mecanum": qsTr("麦克纳姆无人车"),
            "Rover Rate Control": qsTr("无人车角速率控制"),
            "Rover Velocity Control": qsTr("无人车速度控制"),
            "Runway Takeoff": qsTr("跑道起飞"),
            "SD Logging": qsTr("SD 日志"),
            "SITL": qsTr("SITL"),
            "Sensor Calibration": qsTr("传感器校准"),
            "Septentrio": qsTr("Septentrio"),
            "Simulation In Hardware": qsTr("硬件在环仿真"),
            "Simulator": qsTr("模拟器"),
            "System": qsTr("系统"),
            "Testing": qsTr("测试"),
            "Thermal Compensation": qsTr("热补偿"),
            "UUV Attitude Control": qsTr("UUV 姿态控制"),
            "UUV Position Control": qsTr("UUV 位置控制"),
            "UXRCE-DDS Client": qsTr("uXRCE-DDS 客户端"),
            "VTOL Attitude Control": qsTr("VTOL 姿态控制"),
            "VTOL Takeoff": qsTr("VTOL 起飞"),
            "DShot": qsTr("DShot"),
            }
        }
        return _parameterGroupNameTranslations[name] || name
    }

    function _displayParameterHeader(text) {
        if (!_parameterHeaderTranslations) {
            _parameterHeaderTranslations = {
            "Fav": qsTr("收藏"),
            "Name": qsTr("名称"),
            "Value": qsTr("值"),
            "Description": qsTr("说明"),
            }
        }
        return _parameterHeaderTranslations[text] || text
    }

    function _cacheParameterDescription(name, text) {
        _parameterDisplayDescriptionCache[name] = text
        return text
    }

    function _displayParameterValueText(valueText) {
        if (!_parameterValueTranslations) {
            _parameterValueTranslations = {
                "Disabled": qsTr("禁用"),
                "Enabled": qsTr("启用"),
                "Enable": qsTr("启用"),
                "Disable": qsTr("禁用"),
                "No": qsTr("否"),
                "Yes": qsTr("是"),
                "None": qsTr("无"),
                "Auto": qsTr("自动"),
                "normal": qsTr("正常"),
                "Normal": qsTr("正常"),
                "Reverse": qsTr("反向"),
                "Return": qsTr("返航"),
                "Return mode": qsTr("返航模式"),
                "Altitude mode": qsTr("高度模式"),
                "Position mode": qsTr("位置模式"),
                "Terrain hold": qsTr("地形保持"),
                "2 sample averaging": qsTr("2 次采样平均"),
                "4 sample averaging": qsTr("4 次采样平均"),
                "8 sample averaging": qsTr("8 次采样平均"),
                "16 sample averaging": qsTr("16 次采样平均"),
                "Six side calibration": qsTr("六面校准"),
            }
        }
        return _parameterValueTranslations[valueText] || valueText
    }

    function _displayParameterDescriptionFromTemplate(description) {
        let match = description.match(/^Serial Configuration for (.+)$/)
        if (match) {
            return qsTr("%1 串口配置").arg(match[1])
        }

        match = description.match(/^Baudrate for the (.+) Serial Port$/)
        if (match) {
            return qsTr("%1 串口波特率").arg(match[1])
        }

        match = description.match(/^(.+) telemetry Enable$/)
        if (match) {
            return qsTr("启用 %1 遥测").arg(match[1])
        }

        match = description.match(/^(.+) Telemetry$/)
        if (match) {
            return qsTr("%1 遥测").arg(match[1])
        }

        if (description === "Configure") {
            return qsTr("配置")
        }
        if (description === "Bitrate") {
            return qsTr("比特率")
        }
        if (description === "UAVCAN mode") {
            return qsTr("UAVCAN 模式")
        }
        if (description === "Enable USB autostart") {
            return qsTr("启用 USB 自动启动")
        }
        if (description === "Specify USB MAVLink mode") {
            return qsTr("指定 USB MAVLink 模式")
        }
        if (description.indexOf("Deadzone for sticks in manual piloted") === 0) {
            return qsTr("手动驾驶模式下摇杆死区")
        }

        return ""
    }

    function _displayParameterDescription(fact, description) {
        if (!fact) {
            return description
        }

        const cachedDescription = _parameterDisplayDescriptionCache[fact.name]
        if (cachedDescription !== undefined) {
            return cachedDescription
        }

        if (!_parameterDescriptionTranslations) {
            _parameterDescriptionTranslations = {
            "BAT_A_PER_V": qsTr("已弃用，请使用 BAT1_A_PER_V"),
            "BAT_V_DIV": qsTr("已弃用，请使用 BAT1_V_DIV"),

            "BAT1_A_PER_V": qsTr("电池 1 每伏电流 (A/V)"),
            "BAT1_CAPACITY": qsTr("电池 1 容量"),
            "BAT1_I_CHANNEL": qsTr("电池 1 电流 ADC 通道"),
            "BAT1_I_OVERWRITE": qsTr("电池 1 空闲电流覆盖值"),
            "BAT1_N_CELLS": qsTr("电池 1 电芯数量"),
            "BAT1_R_INTERNAL": qsTr("电池 1 单节电芯内阻"),
            "BAT1_SOURCE": qsTr("电池 1 监测来源"),
            "BAT1_V_CHANNEL": qsTr("电池 1 电压 ADC 通道"),
            "BAT1_V_CHARGED": qsTr("电池 1 满电单节电压"),
            "BAT1_V_DIV": qsTr("电池 1 电压分压系数 (V divider)"),
            "BAT1_V_EMPTY": qsTr("电池 1 空电单节电压"),

            "BAT2_A_PER_V": qsTr("电池 2 每伏电流 (A/V)"),
            "BAT2_CAPACITY": qsTr("电池 2 容量"),
            "BAT2_I_CHANNEL": qsTr("电池 2 电流 ADC 通道"),
            "BAT2_I_OVERWRITE": qsTr("电池 2 空闲电流覆盖值"),
            "BAT2_N_CELLS": qsTr("电池 2 电芯数量"),
            "BAT2_R_INTERNAL": qsTr("电池 2 单节电芯内阻"),
            "BAT2_SOURCE": qsTr("电池 2 监测来源"),
            "BAT2_V_CHANNEL": qsTr("电池 2 电压 ADC 通道"),
            "BAT2_V_CHARGED": qsTr("电池 2 满电单节电压"),
            "BAT2_V_DIV": qsTr("电池 2 电压分压系数 (V divider)"),
            "BAT2_V_EMPTY": qsTr("电池 2 空电单节电压"),

            "BAT3_A_PER_V": qsTr("电池 3 每伏电流 (A/V)"),
            "BAT3_CAPACITY": qsTr("电池 3 容量"),
            "BAT3_I_CHANNEL": qsTr("电池 3 电流 ADC 通道"),
            "BAT3_I_OVERWRITE": qsTr("电池 3 空闲电流覆盖值"),
            "BAT3_N_CELLS": qsTr("电池 3 电芯数量"),
            "BAT3_R_INTERNAL": qsTr("电池 3 单节电芯内阻"),
            "BAT3_SOURCE": qsTr("电池 3 监测来源"),
            "BAT3_V_CHANNEL": qsTr("电池 3 电压 ADC 通道"),
            "BAT3_V_CHARGED": qsTr("电池 3 满电单节电压"),
            "BAT3_V_DIV": qsTr("电池 3 电压分压系数 (V divider)"),
            "BAT3_V_EMPTY": qsTr("电池 3 空电单节电压"),

            "BAT_AVRG_CURRENT": qsTr("预计飞行电流"),
            "BAT_LOW_THR": qsTr("低电量阈值"),
            "BAT_CRIT_THR": qsTr("严重低电量阈值"),
            "BAT_EMERGEN_THR": qsTr("紧急低电量阈值"),
            "BAT_V_OFFS_CURR": qsTr("电流 ADC 输入端看到的电压偏移"),

            "BMM350_AVG": qsTr("BMM350 数据平均"),
            "BMM350_DRIVE": qsTr("BMM350 引脚驱动强度设置"),
            "BMM350_ODR": qsTr("BMM350 输出数据速率"),

            "TRIG_ACT_TIME": qsTr("相机触发激活时间"),
            "TRIG_DISTANCE": qsTr("相机触发距离"),
            "TRIG_INTERFACE": qsTr("相机触发接口"),
            "TRIG_INTERVAL": qsTr("相机触发间隔"),
            "TRIG_MIN_INTERVA": qsTr("最小相机触发间隔"),
            "TRIG_MODE": qsTr("相机触发模式"),
            "TRIG_POLARITY": qsTr("相机触发极性"),
            "TRIG_PWM_NEUTRAL": qsTr("触发引脚的 PWM 中位输出"),
            "TRIG_PWM_SHOOT": qsTr("执行拍摄的 PWM 输出"),

            "CBRK_BUZZER": qsTr("用于禁用蜂鸣器的断路器"),
            "CBRK_FLIGHTTERM": qsTr("用于飞行终止的断路器"),
            "CBRK_IO_SAFETY": qsTr("用于 IO 安全的断路器"),
            "CBRK_SUPPLY_CHK": qsTr("用于电源检查的断路器"),
            "CBRK_USB_CHK": qsTr("用于 USB 链路检查的断路器"),
            "CBRK_VTOLARMING": qsTr("用于固定翼模式解锁检查的断路器"),

            "COM_ACT_FAIL_ACT": qsTr("执行器故障失控保护模式"),
            "COM_ARMABLE": qsTr("允许解锁标志"),
            "COM_ARM_AUTH_ID": qsTr("解锁授权系统 ID"),
            "COM_ARM_AUTH_MET": qsTr("解锁授权方法"),
            "COM_ARM_AUTH_REQ": qsTr("解锁时要求授权"),
            "COM_ARM_AUTH_TO": qsTr("解锁授权超时"),
            "COM_ARM_BAT_MIN": qsTr("允许解锁的最低电池电量"),
            "COM_ARM_CHK_ESCS": qsTr("启用带遥测 ESC 的检查"),
            "COM_ARM_HFLT_CHK": qsTr("启用 FMU SD card 硬故障/看门狗检测"),
            "COM_ARM_IMU_ACC": qsTr("允许解锁的最大加速度计不一致"),
            "COM_ARM_IMU_GYR": qsTr("允许解锁的最大陀螺仪角速率不一致"),
            "COM_ARM_MAG_ANG": qsTr("允许解锁的最大磁场不一致"),
            "COM_ARM_MAG_STR": qsTr("启用磁场强度预飞检查"),
            "COM_ARM_MIS_REQ": qsTr("解锁时要求有效任务"),
            "COM_ARM_ODID": qsTr("启用 Drone ID 系统检测和健康检查"),
            "COM_ARM_SDCARD": qsTr("启用 FMU SD card 检测"),
            "COM_ARM_SWISBTN": qsTr("解锁开关为瞬时按钮"),
            "COM_ARM_TRAFF": qsTr("启用交通避让系统检测"),
            "COM_ARM_WO_GPS": qsTr("无 GNSS 配置时的解锁设置"),
            "COM_CPU_MAX": qsTr("仍允许解锁的最大 CPU 负载"),
            "COM_DISARM_LAND": qsTr("着陆后自动上锁超时"),
            "COM_DISARM_MAN": qsTr("允许在多旋翼手动油门模式下通过开关/摇杆/按钮上锁"),
            "COM_DISARM_PRFLT": qsTr("解锁后未起飞自动上锁超时"),
            "COM_DLL_EXCEPT": qsTr("数据链路丢失例外"),
            "COM_DL_LOSS_T": qsTr("GCS 连接丢失时间阈值"),
            "COM_FAIL_ACT_T": qsTr("失控保护条件触发到执行动作的延迟"),
            "COM_FLIGHT_UUID": qsTr("下一次飞行 UUID"),
            "COM_FLTMODE1": qsTr("飞行模式槽位 1"),
            "COM_FLTMODE2": qsTr("飞行模式槽位 2"),
            "COM_FLTMODE3": qsTr("飞行模式槽位 3"),
            "COM_FLTMODE4": qsTr("飞行模式槽位 4"),
            "COM_FLTMODE5": qsTr("飞行模式槽位 5"),
            "COM_FLTMODE6": qsTr("飞行模式槽位 6"),
            "COM_FLTT_LOW_ACT": qsTr("剩余飞行时间过低失控保护"),
            "COM_FLT_PROFILE": qsTr("用户飞行配置"),
            "COM_FLT_TIME_MAX": qsTr("最大允许飞行时间"),
            "COM_FORCE_SAFETY": qsTr("启用强制安全"),
            "COM_HLDL_LOSS_T": qsTr("高延迟数据链路丢失时间阈值"),
            "COM_HLDL_REG_T": qsTr("高延迟数据链路恢复时间阈值"),
            "COM_HOME_EN": qsTr("启用 Home 点"),
            "COM_HOME_IN_AIR": qsTr("允许起飞后设置 Home 点"),
            "COM_IMB_PROP_ACT": qsTr("螺旋桨不平衡失控保护模式"),
            "COM_KILL_DISARM": qsTr("Kill 开关触发后的上锁超时"),
            "COM_LKDOWN_TKO": qsTr("起飞后故障检测超时"),
            "COM_LOW_BAT_ACT": qsTr("电池低电量失控保护模式"),
            "COM_MODE0_HASH": qsTr("外部模式标识符 0"),
            "COM_MODE1_HASH": qsTr("外部模式标识符 1"),
            "COM_MODE2_HASH": qsTr("外部模式标识符 2"),
            "COM_MODE3_HASH": qsTr("外部模式标识符 3"),
            "COM_MODE4_HASH": qsTr("外部模式标识符 4"),
            "COM_MODE5_HASH": qsTr("外部模式标识符 5"),
            "COM_MODE6_HASH": qsTr("外部模式标识符 6"),
            "COM_MODE7_HASH": qsTr("外部模式标识符 7"),
            "COM_MODE_ARM_CHK": qsTr("允许解锁状态下注册外部模式"),
            "COM_MOT_TEST_EN": qsTr("启用执行器测试"),
            "COM_OBC_LOSS_T": qsTr("机载计算机连接丢失警告超时"),
            "COM_OBL_RC_ACT": qsTr("Offboard 丢失失控保护模式"),
            "COM_OF_LOSS_T": qsTr("Offboard 连接丢失后触发动作的超时"),
            "COM_PARACHUTE": qsTr("要求 MAVLink 降落伞系统存在且健康"),
            "COM_POSCTL_NAVL": qsTr("位置模式导航丢失响应"),
            "COM_POS_FS_EPH": qsTr("悬停系统水平位置误差阈值"),
            "COM_POS_LOW_ACT": qsTr("位置精度低时的动作"),
            "COM_POS_LOW_EPH": qsTr("位置精度低失控保护阈值"),
            "COM_POWER_COUNT": qsTr("所需冗余电源模块数量"),
            "COM_PREARM_MODE": qsTr("进入预解锁模式的条件"),
            "COM_QC_ACT": qsTr("QuadChute 后的动作"),
            "COM_RAM_MAX": qsTr("通过检查所允许的最大 RAM 使用率"),
            "COM_RC_ARM_HYST": qsTr("RC 输入解锁/上锁命令持续时间"),
            "COM_RCL_EXCEPT": qsTr("手动控制丢失例外"),
            "COM_RC_IN_MODE": qsTr("手动控制输入源配置"),
            "COM_RC_LOSS_T": qsTr("手动控制丢失超时"),
            "COM_RC_OVERRIDE": qsTr("启用手动控制摇杆接管"),
            "COM_RC_STICK_OV": qsTr("摇杆接管阈值"),
            "COM_SPOOLUP_TIME": qsTr("解锁到进一步导航之间的强制延迟"),
            "COM_TAKEOFF_ACT": qsTr("TAKEOFF 被接受后的动作"),
            "COM_THROW_EN": qsTr("启用抛飞启动"),
            "COM_THROW_SPEED": qsTr("抛飞启动的最小速度"),
            "COM_VEL_FS_EVH": qsTr("水平速度误差阈值"),
            "COM_WIND_MAX": qsTr("大风失控保护阈值"),
            "COM_WIND_MAX_ACT": qsTr("大风失控保护模式"),
            "COM_WIND_WARN": qsTr("风速警告阈值"),
            "NAV_DLL_ACT": qsTr("GCS 连接丢失失控保护模式"),
            "NAV_RCL_ACT": qsTr("手动控制丢失失控保护模式"),

            "EKF2_ABIAS_INIT": qsTr("1-sigma IMU 加速度计上电偏置"),
            "EKF2_ABL_ACCLIM": qsTr("允许 IMU 偏置学习的最大加速度幅值"),
            "EKF2_ABL_GYRLIM": qsTr("允许 IMU 偏置学习的最大陀螺仪角速率幅值"),
            "EKF2_ABL_LIM": qsTr("加速度计偏置学习限制"),
            "EKF2_ABL_TAU": qsTr("加速度计偏置学习抑制时间常数"),
            "EKF2_ACC_B_NOISE": qsTr("IMU 加速度计偏置预测过程噪声"),
            "EKF2_ACC_NOISE": qsTr("协方差预测的加速度计噪声"),
            "EKF2_AGP_CTRL": qsTr("辅助全局位置 (AGP) 传感器辅助"),
            "EKF2_AGP_DELAY": qsTr("辅助全局位置估计器延迟（相对 IMU）"),
            "EKF2_AGP_GATE": qsTr("辅助全局位置融合门限大小"),
            "EKF2_AGP_NOISE": qsTr("辅助全局位置测量噪声"),
            "EKF2_AGP0_CTRL": qsTr("辅助全局位置 (AGP) 传感器辅助"),
            "EKF2_AGP0_DELAY": qsTr("辅助全局位置估计器延迟（相对 IMU）"),
            "EKF2_AGP0_GATE": qsTr("辅助全局位置融合门限大小"),
            "EKF2_AGP0_ID": qsTr("辅助全局位置传感器 0 ID"),
            "EKF2_AGP0_MODE": qsTr("传感器 0 融合重置模式"),
            "EKF2_AGP0_NOISE": qsTr("辅助全局位置测量噪声"),
            "EKF2_AGP1_CTRL": qsTr("辅助全局位置 (AGP) 传感器 1 辅助"),
            "EKF2_AGP1_DELAY": qsTr("辅助全局位置传感器 1 延迟（相对 IMU）"),
            "EKF2_AGP1_GATE": qsTr("辅助全局位置传感器 1 融合门限大小"),
            "EKF2_AGP1_ID": qsTr("辅助全局位置传感器 1 ID"),
            "EKF2_AGP1_MODE": qsTr("传感器 1 融合重置模式"),
            "EKF2_AGP1_NOISE": qsTr("辅助全局位置传感器 1 测量噪声"),
            "EKF2_AGP2_CTRL": qsTr("辅助全局位置 (AGP) 传感器 2 辅助"),
            "EKF2_AGP2_DELAY": qsTr("辅助全局位置传感器 2 延迟（相对 IMU）"),
            "EKF2_AGP2_GATE": qsTr("辅助全局位置传感器 2 融合门限大小"),
            "EKF2_AGP2_ID": qsTr("辅助全局位置传感器 2 ID"),
            "EKF2_AGP2_MODE": qsTr("传感器 2 融合重置模式"),
            "EKF2_AGP2_NOISE": qsTr("辅助全局位置传感器 2 测量噪声"),
            "EKF2_AGP3_CTRL": qsTr("辅助全局位置 (AGP) 传感器 3 辅助"),
            "EKF2_AGP3_DELAY": qsTr("辅助全局位置传感器 3 延迟（相对 IMU）"),
            "EKF2_AGP3_GATE": qsTr("辅助全局位置传感器 3 融合门限大小"),
            "EKF2_AGP3_ID": qsTr("辅助全局位置传感器 3 ID"),
            "EKF2_AGP3_MODE": qsTr("传感器 3 融合重置模式"),
            "EKF2_AGP3_NOISE": qsTr("辅助全局位置传感器 3 测量噪声"),
            "EKF2_ANGERR_INIT": qsTr("重力矢量对齐后的 1-sigma 倾角不确定度"),
            "EKF2_ARSP_THR": qsTr("空速融合阈值"),
            "EKF2_ASPD_MAX": qsTr("气压静压补偿使用的最大空速"),
            "EKF2_ASP_DELAY": qsTr("空速测量延迟（相对 IMU 测量）"),
            "EKF2_AVEL_DELAY": qsTr("辅助速度估计延迟（相对 IMU 测量）"),
            "EKF2_BARO_CTRL": qsTr("气压计高度辅助"),
            "EKF2_BARO_DELAY": qsTr("气压计测量延迟（相对 IMU 测量）"),
            "EKF2_BARO_GATE": qsTr("气压和 GPS 高度融合门限"),
            "EKF2_BARO_NOISE": qsTr("气压高度测量噪声"),
            "EKF2_BCOEF_X": qsTr("多旋翼风估计使用的 X 轴弹道系数"),
            "EKF2_BCOEF_Y": qsTr("多旋翼风估计使用的 Y 轴弹道系数"),
            "EKF2_BETA_GATE": qsTr("合成侧滑融合门限"),
            "EKF2_BETA_NOISE": qsTr("合成侧滑融合噪声"),
            "EKF2_DECL_TYPE": qsTr("控制磁偏角处理的整型位掩码"),
            "EKF2_DELAY_MAX": qsTr("所有辅助传感器的最大延迟"),
            "EKF2_DRAG_CTRL": qsTr("多旋翼风估计选择"),
            "EKF2_DRAG_NOISE": qsTr("比阻力观测噪声方差"),
            "EKF2_EAS_NOISE": qsTr("空速融合测量噪声"),
            "EKF2_EN": qsTr("启用 EKF2"),
            "EKF2_ENGINE_WRM": qsTr("发动机预热期间启用恒定位置融合"),
            "EKF2_EVA_NOISE": qsTr("视觉角度测量噪声"),
            "EKF2_EVP_GATE": qsTr("视觉位置融合门限"),
            "EKF2_EVP_NOISE": qsTr("视觉位置测量噪声"),
            "EKF2_EVV_GATE": qsTr("视觉速度估计融合门限"),
            "EKF2_EVV_NOISE": qsTr("视觉速度测量噪声"),
            "EKF2_EV_CTRL": qsTr("外部视觉 (EV) 传感器辅助"),
            "EKF2_EV_DELAY": qsTr("视觉位置估计器延迟（相对 IMU 测量）"),
            "EKF2_EV_NOISE_MD": qsTr("外部视觉 (EV) 噪声模式"),
            "EKF2_EV_POS_X": qsTr("VI 传感器焦点在机体系中的 X 位置"),
            "EKF2_EV_POS_Y": qsTr("VI 传感器焦点在机体系中的 Y 位置"),
            "EKF2_EV_POS_Z": qsTr("VI 传感器焦点在机体系中的 Z 位置"),
            "EKF2_EV_QMIN": qsTr("外部视觉 (EV) 最低质量（可选）"),
            "EKF2_FUSE_BETA": qsTr("启用合成侧滑融合"),
            "EKF2_GBIAS_INIT": qsTr("1-sigma IMU 陀螺仪上电偏置"),
            "EKF2_GND_EFF_DZ": qsTr("高度融合的气压死区范围"),
            "EKF2_GND_MAX_HGT": qsTr("地面效应区离地高度"),
            "EKF2_GPS_CHECK": qsTr("控制 GPS 检查的整型位掩码"),
            "EKF2_GPS_CTRL": qsTr("GNSS 传感器辅助"),
            "EKF2_GPS_DELAY": qsTr("GPS 测量延迟（相对 IMU 测量）"),
            "EKF2_GPS_MODE": qsTr("融合重置模式"),
            "EKF2_GPS_POS_X": qsTr("GPS 天线在机体系中的 X 位置"),
            "EKF2_GPS_POS_Y": qsTr("GPS 天线在机体系中的 Y 位置"),
            "EKF2_GPS_POS_Z": qsTr("GPS 天线在机体系中的 Z 位置"),
            "EKF2_GPS_P_GATE": qsTr("GNSS 位置融合门限"),
            "EKF2_GPS_P_NOISE": qsTr("GNSS 位置测量噪声"),
            "EKF2_GPS_V_GATE": qsTr("GNSS 速度融合门限"),
            "EKF2_GPS_V_NOISE": qsTr("GNSS 速度测量噪声"),
            "EKF2_GPS_YAW_OFF": qsTr("双天线 GPS 航向/Yaw 偏移"),
            "EKF2_GRAV_NOISE": qsTr("基于重力观测的加速度计测量噪声"),
            "EKF2_GSF_TAS": qsTr("EKF-GSF AHRS 计算使用的默认真空速"),
            "EKF2_GYR_B_LIM": qsTr("陀螺仪偏置学习限制"),
            "EKF2_GYR_B_NOISE": qsTr("IMU 角速率陀螺仪偏置预测过程噪声"),
            "EKF2_GYR_NOISE": qsTr("协方差预测的角速率陀螺仪噪声"),
            "EKF2_HDG_GATE": qsTr("航向融合门限"),
            "EKF2_HEAD_NOISE": qsTr("磁航向融合测量噪声"),
            "EKF2_HGT_REF": qsTr("EKF 使用的高度数据参考源"),
            "EKF2_IMU_CTRL": qsTr("IMU 控制"),
            "EKF2_IMU_POS_X": qsTr("IMU 在机体系中的 X 位置"),
            "EKF2_IMU_POS_Y": qsTr("IMU 在机体系中的 Y 位置"),
            "EKF2_IMU_POS_Z": qsTr("IMU 在机体系中的 Z 位置"),
            "EKF2_LOG_VERBOSE": qsTr("详细日志"),
            "EKF2_MAG_ACCLIM": qsTr("航向可观测性检查使用的水平加速度阈值"),
            "EKF2_MAG_B_NOISE": qsTr("机体磁场预测过程噪声"),
            "EKF2_MAG_CHECK": qsTr("磁场强度测试选择"),
            "EKF2_MAG_CHK_INC": qsTr("磁场倾角检查容差"),
            "EKF2_MAG_CHK_STR": qsTr("磁场强度检查容差"),
            "EKF2_MAG_DECL": qsTr("磁偏角"),
            "EKF2_MAG_DELAY": qsTr("磁力计测量延迟（相对 IMU 测量）"),
            "EKF2_MAG_E_NOISE": qsTr("地磁场预测过程噪声"),
            "EKF2_MAG_GATE": qsTr("磁力计 XYZ 分量融合门限"),
            "EKF2_MAG_NOISE": qsTr("磁力计三轴融合测量噪声"),
            "EKF2_MAG_TYPE": qsTr("磁力计融合类型"),
            "EKF2_MCOEF": qsTr("多旋翼风估计的螺旋桨动量阻力系数"),
            "EKF2_MIN_RNG": qsTr("地面时预期的测距仪读数"),
            "EKF2_MULTI_IMU": qsTr("Multi-EKF 使用的 IMU 数量"),
            "EKF2_MULTI_MAG": qsTr("Multi-EKF 使用的磁力计数量"),
            "EKF2_NOAID_NOISE": qsTr("无辅助位置保持测量噪声"),
            "EKF2_NOAID_TOUT": qsTr("最大惯性航位推算时间"),
            "EKF2_OF_CTRL": qsTr("光流辅助"),
            "EKF2_OF_DELAY": qsTr("光流测量延迟（相对 IMU 测量）"),
            "EKF2_OF_GATE": qsTr("光流融合门限"),
            "EKF2_OF_GYR_SRC": qsTr("光流角速率补偿来源"),
            "EKF2_OF_N_MAX": qsTr("光流最大噪声"),
            "EKF2_OF_N_MIN": qsTr("光流最小噪声"),
            "EKF2_OF_POS_X": qsTr("光流焦点在机体系中的 X 位置"),
            "EKF2_OF_POS_Y": qsTr("光流焦点在机体系中的 Y 位置"),
            "EKF2_OF_POS_Z": qsTr("光流焦点在机体系中的 Z 位置"),
            "EKF2_OF_QMIN": qsTr("空中光流最低质量"),
            "EKF2_OF_QMIN_GND": qsTr("地面光流最低质量"),
            "EKF2_PCOEF_XN": qsTr("负 X 轴静压位置误差系数"),
            "EKF2_PCOEF_XP": qsTr("正 X 轴静压位置误差系数"),
            "EKF2_PCOEF_YN": qsTr("负 Y 轴压力位置误差系数"),
            "EKF2_PCOEF_YP": qsTr("正 Y 轴压力位置误差系数"),
            "EKF2_PCOEF_Z": qsTr("Z 轴静压位置误差系数"),
            "EKF2_PREDICT_US": qsTr("EKF 预测周期"),
            "EKF2_REQ_EPH": qsTr("使用 GPS 所需 EPH"),
            "EKF2_REQ_EPV": qsTr("使用 GPS 所需 EPV"),
            "EKF2_REQ_FIX": qsTr("所需 GPS 定位类型"),
            "EKF2_REQ_GPS_H": qsTr("启动时所需 GPS 健康时间"),
            "EKF2_REQ_HDRIFT": qsTr("使用 GPS 的最大水平漂移速度"),
            "EKF2_REQ_NSATS": qsTr("使用 GPS 所需卫星数量"),
            "EKF2_REQ_PDOP": qsTr("使用 GPS 的最大 PDOP"),
            "EKF2_REQ_SACC": qsTr("使用 GPS 所需速度精度"),
            "EKF2_REQ_VDRIFT": qsTr("使用 GPS 的最大垂直漂移速度"),
            "EKF2_RNG_A_HMAX": qsTr("条件测距辅助模式允许的最大离地高度"),
            "EKF2_RNG_A_VMAX": qsTr("条件测距辅助模式允许的最大水平速度"),
            "EKF2_RNG_CTRL": qsTr("测距传感器高度辅助"),
            "EKF2_RNG_DELAY": qsTr("测距仪测量延迟（相对 IMU 测量）"),
            "EKF2_RNG_FOG": qsTr("测距仪可能检测到雾的最大距离"),
            "EKF2_RNG_GATE": qsTr("测距仪融合门限"),
            "EKF2_RNG_K_GATE": qsTr("测距仪运动学一致性检查门限"),
            "EKF2_RNG_NOISE": qsTr("测距仪融合测量噪声"),
            "EKF2_RNG_PITCH": qsTr("测距传感器俯仰偏移"),
            "EKF2_RNG_POS_X": qsTr("测距仪原点在机体系中的 X 位置"),
            "EKF2_RNG_POS_Y": qsTr("测距仪原点在机体系中的 Y 位置"),
            "EKF2_RNG_POS_Z": qsTr("测距仪原点在机体系中的 Z 位置"),
            "EKF2_RNG_QLTY_T": qsTr("最小测距有效持续时间"),
            "EKF2_RNG_SFE": qsTr("测距仪距离相关噪声缩放系数"),
            "EKF2_SEL_ERR_RED": qsTr("选择器误差降低阈值"),
            "EKF2_SEL_IMU_ACC": qsTr("选择器加速度阈值"),
            "EKF2_SEL_IMU_ANG": qsTr("选择器角度阈值"),
            "EKF2_SEL_IMU_RAT": qsTr("选择器角速率阈值"),
            "EKF2_SEL_IMU_VEL": qsTr("选择器速度阈值"),
            "EKF2_SYNT_MAG_Z": qsTr("启用合成磁力计 Z 分量测量"),
            "EKF2_TAS_GATE": qsTr("TAS 融合门限"),
            "EKF2_TAU_POS": qsTr("输出预测器位置时间常数"),
            "EKF2_TAU_VEL": qsTr("速度输出预测和平滑滤波时间常数"),
            "EKF2_TERR_GRAD": qsTr("地形坡度幅值"),
            "EKF2_TERR_NOISE": qsTr("地形高度过程噪声"),
            "EKF2_VEL_LIM": qsTr("速度限制"),
            "EKF2_WIND_NSD": qsTr("风速预测过程噪声谱密度"),

            "EV_TSK_RC_LOSS": qsTr("RC 丢失告警"),
            "EV_TSK_STAT_DIS": qsTr("状态显示"),

            "FW_MAN_P_MAX": qsTr("最大手动俯仰角"),
            "FW_MAN_R_MAX": qsTr("最大手动横滚角"),
            "FW_MAN_YR_MAX": qsTr("最大手动附加偏航速率"),
            "FW_PSP_OFF": qsTr("俯仰设定点偏移（平飞俯仰）"),
            "FW_P_RMAX_NEG": qsTr("最大负向/下俯俯仰速率设定点"),
            "FW_P_RMAX_POS": qsTr("最大正向/上仰俯仰速率设定点"),
            "FW_P_TC": qsTr("姿态俯仰时间常数"),
            "FW_R_RMAX": qsTr("最大横滚速率设定点"),
            "FW_R_TC": qsTr("姿态横滚时间常数"),
            "FW_WR_FF": qsTr("轮式转向速率前馈"),
            "FW_WR_I": qsTr("轮式转向速率积分增益"),
            "FW_WR_IMAX": qsTr("轮式转向速率积分限制"),
            "FW_WR_P": qsTr("轮式转向速率比例增益"),
            "FW_W_EN": qsTr("启用轮式转向控制器"),
            "FW_W_RMAX": qsTr("最大轮式转向速率"),
            "FW_Y_RMAX": qsTr("最大偏航速率设定点"),

            "FW_FLAPS_LND_SCL": qsTr("降落期间襟翼设置"),
            "FW_LND_ABORT": qsTr("自动降落中止条件位掩码"),
            "FW_LND_AIRSPD": qsTr("降落空速"),
            "FW_LND_ANG": qsTr("最大降落下滑角"),
            "FW_LND_EARLYCFG": qsTr("提前展开降落配置"),
            "FW_LND_FLALT": qsTr("降落拉平高度（相对降落高度）"),
            "FW_LND_FL_PMAX": qsTr("拉平最大俯仰角"),
            "FW_LND_FL_PMIN": qsTr("拉平最小俯仰角"),
            "FW_LND_FL_SINK": qsTr("降落拉平下沉率"),
            "FW_LND_FL_TIME": qsTr("降落拉平时间"),
            "FW_LND_NUDGE": qsTr("降落接地点微调选项"),
            "FW_LND_TD_OFF": qsTr("接地点最大横向位置偏移"),
            "FW_LND_TD_TIME": qsTr("降落接地时间（自拉平开始）"),
            "FW_LND_THRTC_SC": qsTr("降落和低高度飞行的高度时间常数系数"),
            "FW_LND_USETER": qsTr("降落期间使用地形估计"),
            "FW_SPOILERS_LND": qsTr("降落扰流板设置"),

            "FW_FLAPS_TO_SCL": qsTr("起飞期间襟翼设置"),
            "FW_LAUN_AC_T": qsTr("触发时间"),
            "FW_LAUN_AC_THLD": qsTr("触发加速度阈值"),
            "FW_LAUN_CS_LK_DY": qsTr("发射后舵面锁定延迟"),
            "FW_LAUN_DETCN_ON": qsTr("固定翼发射检测"),
            "FW_LAUN_MOT_DEL": qsTr("电机延迟"),
            "FW_TKO_AIRSPD": qsTr("起飞空速"),
            "FW_TKO_PITCH_MIN": qsTr("起飞期间最小俯仰角"),

            "FW_GPSF_LT": qsTr("GPS 故障盘旋时间"),
            "FW_GPSF_R": qsTr("GPS 故障固定横滚角"),
            "FW_POS_STK_CONF": qsTr("自定义摇杆配置"),
            "FW_P_LIM_MAX": qsTr("最大俯仰角设定点"),
            "FW_P_LIM_MIN": qsTr("最小俯仰角设定点"),
            "FW_R_LIM": qsTr("最大横滚角设定点"),
            "FW_THR_IDLE": qsTr("怠速油门"),
            "FW_THR_MAX": qsTr("最大油门限制"),
            "FW_THR_MIN": qsTr("最小油门限制"),
            "FW_T_CLMB_R_SP": qsTr("默认目标爬升率"),
            "FW_T_SINK_R_SP": qsTr("默认目标下沉率"),
            "FW_T_SPDWEIGHT": qsTr("速度 <--> 高度权重"),
            "FW_WING_HEIGHT": qsTr("飞机在地面时机翼离地高度 (AGL)"),
            "FW_WING_SPAN": qsTr("飞机翼展（翼尖到翼尖长度）"),

            "FW_PN_R_SLEW_MAX": qsTr("路径导航横滚变化率限制"),

            "FW_GND_SPD_MIN": qsTr("最小地速"),
            "FW_THR_SLEW_MAX": qsTr("最大油门变化率"),
            "FW_T_ALT_TC": qsTr("高度误差时间常数"),
            "FW_T_F_ALT_ERR": qsTr("快速下降：最小高度误差"),
            "FW_T_HRATE_FF": qsTr("高度变化率前馈"),
            "FW_T_I_GAIN_PIT": qsTr("俯仰积分增益"),
            "FW_T_PTCH_DAMP": qsTr("俯仰阻尼增益"),
            "FW_T_RLL2THR": qsTr("横滚 -> 油门前馈"),
            "FW_T_SEB_R_FF": qsTr("比总能量平衡率前馈增益"),
            "FW_T_SINK_MAX": qsTr("最大下降率"),
            "FW_T_SPD_DEV_STD": qsTr("空速变化率测量标准差"),
            "FW_T_SPD_PRC_STD": qsTr("空速变化率过程噪声标准差"),
            "FW_T_SPD_STD": qsTr("空速测量标准差"),
            "FW_T_STE_R_TC": qsTr("比总能量率一阶滤波时间常数"),
            "FW_T_TAS_TC": qsTr("真空速误差时间常数"),
            "FW_T_THR_DAMPING": qsTr("油门阻尼系数"),
            "FW_T_THR_INTEG": qsTr("油门积分增益"),
            "FW_T_THR_LOW_HGT": qsTr("更紧高度跟踪的低高度阈值"),
            "FW_T_VERT_ACC": qsTr("最大垂直加速度"),
            "FW_WIND_ARSP_SC": qsTr("基于风速的空速缩放系数"),

            "NPFG_DAMPING": qsTr("NPFG 阻尼比"),
            "NPFG_LB_PERIOD": qsTr("启用 NPFG 周期自动下限"),
            "NPFG_PERIOD": qsTr("NPFG 周期"),
            "NPFG_PERIOD_SF": qsTr("周期安全系数"),
            "NPFG_ROLL_TC": qsTr("横滚时间常数"),
            "NPFG_SW_DST_MLT": qsTr("NPFG 切换距离倍数"),
            "NPFG_UB_PERIOD": qsTr("启用 NPFG 周期自动上限"),

            "FW_AIRSPD_FLP_SC": qsTr("全襟翼时空速缩放"),
            "FW_AIRSPD_MAX": qsTr("最大空速 (CAS)"),
            "FW_AIRSPD_MIN": qsTr("最小空速 (CAS)"),
            "FW_AIRSPD_STALL": qsTr("失速空速 (CAS)"),
            "FW_AIRSPD_TRIM": qsTr("配平（巡航）空速"),
            "FW_SERVICE_CEIL": qsTr("实用升限"),
            "FW_THR_ASPD_MAX": qsTr("最大空速时油门"),
            "FW_THR_ASPD_MIN": qsTr("最小空速时油门"),
            "FW_THR_TRIM": qsTr("配平油门"),
            "FW_T_CLMB_MAX": qsTr("最大爬升率"),
            "FW_T_SINK_MIN": qsTr("最小下降率"),
            "WEIGHT_BASE": qsTr("飞行器基准重量"),
            "WEIGHT_GROSS": qsTr("飞行器总重"),

            "FW_ACRO_X_MAX": qsTr("Acro 机体横滚最大角速率设定点"),
            "FW_ACRO_YAW_EN": qsTr("在 Acro 中启用偏航角速率控制器"),
            "FW_ACRO_Y_MAX": qsTr("Acro 机体俯仰最大角速率设定点"),
            "FW_ACRO_Z_MAX": qsTr("Acro 机体偏航最大角速率设定点"),
            "FW_ARSP_SCALE_EN": qsTr("启用空速缩放"),
            "FW_BAT_SCALE_EN": qsTr("启用按电池电量缩放油门"),
            "FW_DTRIM_P_VMAX": qsTr("最大空速时俯仰配平增量"),
            "FW_DTRIM_P_VMIN": qsTr("最小空速时俯仰配平增量"),
            "FW_DTRIM_R_VMAX": qsTr("最大空速时横滚配平增量"),
            "FW_DTRIM_R_VMIN": qsTr("最小空速时横滚配平增量"),
            "FW_DTRIM_Y_VMAX": qsTr("最大空速时偏航配平增量"),
            "FW_DTRIM_Y_VMIN": qsTr("最小空速时偏航配平增量"),
            "FW_GC_EN": qsTr("启用角速率增益压缩"),
            "FW_GC_GAIN_MIN": qsTr("压缩增益下限"),
            "FW_MAN_P_SC": qsTr("手动俯仰缩放"),
            "FW_MAN_R_SC": qsTr("手动横滚缩放"),
            "FW_MAN_Y_SC": qsTr("手动偏航缩放"),
            "FW_PR_D": qsTr("俯仰角速率微分增益"),
            "FW_PR_FF": qsTr("俯仰角速率前馈"),
            "FW_PR_I": qsTr("俯仰角速率积分增益"),
            "FW_PR_IMAX": qsTr("俯仰角速率积分限制"),
            "FW_PR_P": qsTr("俯仰角速率比例增益"),
            "FW_RLL_TO_YAW_FF": qsTr("横滚控制到偏航控制前馈增益"),
            "FW_RR_D": qsTr("横滚角速率微分增益"),
            "FW_RR_FF": qsTr("横滚角速率前馈"),
            "FW_RR_I": qsTr("横滚角速率积分增益"),
            "FW_RR_IMAX": qsTr("横滚积分限制"),
            "FW_RR_P": qsTr("横滚角速率比例增益"),
            "FW_SPOILERS_MAN": qsTr("手动飞行中的扰流板输入"),
            "FW_USE_AIRSPD": qsTr("使用空速进行控制"),
            "FW_YR_D": qsTr("偏航角速率微分增益"),
            "FW_YR_FF": qsTr("偏航角速率前馈"),
            "FW_YR_I": qsTr("偏航角速率积分增益"),
            "FW_YR_IMAX": qsTr("偏航角速率积分限制"),
            "FW_YR_P": qsTr("偏航角速率比例增益"),

            "FD_ACT_EN": qsTr("启用执行器故障检查"),
            "FD_ACT_HIGH_OFF": qsTr("电机过流故障限制偏移"),
            "FD_ACT_LOW_OFF": qsTr("电机欠流故障限制偏移"),
            "FD_ACT_MOT_C2T": qsTr("电机故障电流/油门比例"),
            "FD_ACT_MOT_THR": qsTr("电机故障推力阈值"),
            "FD_ACT_MOT_TOUT": qsTr("电机故障滞后时间"),
            "FD_ESCS_EN": qsTr("启用上报解锁状态 ESC 的检查"),
            "FD_EXT_ATS_EN": qsTr("启用外部自动触发系统 (ATS) 的 PWM 失控保护输入"),
            "FD_EXT_ATS_TRIG": qsTr("外部自动触发系统触发失控保护的 PWM 阈值"),
            "FD_FAIL_P": qsTr("故障检测最大俯仰角"),
            "FD_FAIL_P_TTRI": qsTr("俯仰故障触发时间"),
            "FD_FAIL_R": qsTr("故障检测最大横滚角"),
            "FD_FAIL_R_TTRI": qsTr("横滚故障触发时间"),
            "FD_IMB_PROP_THR": qsTr("螺旋桨不平衡检查阈值"),

            "MC_ORBIT_RAD_MAX": qsTr("最大环绕半径"),
            "MC_ORBIT_YAW_MOD": qsTr("环绕飞行期间的偏航行为"),

            "FLW_TGT_ALT_M": qsTr("高度控制模式"),
            "FLW_TGT_DST": qsTr("跟随目标距离"),
            "FLW_TGT_FA": qsTr("跟随角度设置"),
            "FLW_TGT_HT": qsTr("跟随目标高度"),
            "FLW_TGT_MAX_VEL": qsTr("生成跟随环绕轨迹的最大切向速度"),
            "FLW_TGT_RS": qsTr("目标估计器对目标运动的响应性"),

            "GPS_1_GNSS": qsTr("主 GPS 使用的 GNSS 系统（整型位掩码）"),
            "GPS_1_PROTOCOL": qsTr("主 GPS 协议"),
            "GPS_2_GNSS": qsTr("副 GPS 使用的 GNSS 系统（整型位掩码）"),
            "GPS_2_PROTOCOL": qsTr("副 GPS 协议"),
            "GPS_CFG_WIPE": qsTr("清除 UBX 模块的 Flash 配置"),
            "GPS_DUMP_COMM": qsTr("记录 GPS 通信数据"),
            "GPS_SAT_INFO": qsTr("启用卫星信息（如可用）"),
            "GPS_UBX_BAUD2": qsTr("u-blox F9P UART2 波特率"),
            "GPS_UBX_CFG_INTF": qsTr("接口的 u-blox 协议配置"),
            "GPS_UBX_DGNSS_TO": qsTr("u-blox GPS DGNSS 超时"),
            "GPS_UBX_DYNMODEL": qsTr("u-blox GPS 动态平台模型"),
            "GPS_UBX_JAM_DET": qsTr("u-blox GPS 干扰检测高灵敏度模式"),
            "GPS_UBX_MIN_CNO": qsTr("u-blox GPS 导航最小卫星信号电平"),
            "GPS_UBX_MIN_ELEV": qsTr("u-blox GPS 导航使用 GNSS 卫星的最小仰角"),
            "GPS_UBX_MODE": qsTr("u-blox GPS 模式"),
            "GPS_UBX_PPK": qsTr("启用 PPK 流程的 MSM7 消息输出"),
            "GPS_UBX_RATE": qsTr("u-blox GPS 输出频率"),
            "GPS_YAW_OFFSET": qsTr("双天线 GPS 航向/Yaw 偏移"),

            "GF_ACTION": qsTr("地理围栏违规动作"),
            "GF_MAX_HOR_DIST": qsTr("距 Home 的最大水平距离"),
            "GF_MAX_VER_DIST": qsTr("距 Home 的最大垂直距离"),
            "GF_PREDICT": qsTr("[实验性] 使用预触发地理围栏"),
            "GF_SOURCE": qsTr("地理围栏位置来源"),

            "CA_AIRFRAME": qsTr("机架选择"),
            "CA_CS_LAUN_LK": qsTr("启用舵面发射锁定"),
            "CA_FAILURE_MODE": qsTr("电机故障处理模式"),
            "CA_HELI_PITCH_C0": qsTr("位置 0 的总距曲线"),
            "CA_HELI_PITCH_C1": qsTr("位置 1 的总距曲线"),
            "CA_HELI_PITCH_C2": qsTr("位置 2 的总距曲线"),
            "CA_HELI_PITCH_C3": qsTr("位置 3 的总距曲线"),
            "CA_HELI_PITCH_C4": qsTr("位置 4 的总距曲线"),
            "CA_HELI_RPM_I": qsTr("RPM 控制积分增益"),
            "CA_HELI_RPM_P": qsTr("RPM 控制比例增益"),
            "CA_HELI_RPM_SP": qsTr("主旋翼 RPM 设定点"),
            "CA_HELI_THR_C0": qsTr("位置 0 的油门曲线"),
            "CA_HELI_THR_C1": qsTr("位置 1 的油门曲线"),
            "CA_HELI_THR_C2": qsTr("位置 2 的油门曲线"),
            "CA_HELI_THR_C3": qsTr("位置 3 的油门曲线"),
            "CA_HELI_THR_C4": qsTr("位置 4 的油门曲线"),
            "CA_HELI_YAW_CCW": qsTr("主旋翼逆时针旋转"),
            "CA_HELI_YAW_CP_O": qsTr("基于总距的偏航补偿偏移"),
            "CA_HELI_YAW_CP_S": qsTr("基于总距的偏航补偿缩放"),
            "CA_HELI_YAW_TH_S": qsTr("基于油门的偏航补偿缩放"),
            "CA_ICE_PERIOD": qsTr("除冰循环周期"),
            "CA_MAX_SVO_THROW": qsTr("线性化时斜盘舵机最大指令舵角"),
            "CA_METHOD": qsTr("控制分配方法"),
            "CA_R0_SLEW": qsTr("电机 0 变化率限制"),
            "CA_R1_SLEW": qsTr("电机 1 变化率限制"),
            "CA_R2_SLEW": qsTr("电机 2 变化率限制"),
            "CA_R3_SLEW": qsTr("电机 3 变化率限制"),
            "CA_R4_SLEW": qsTr("电机 4 变化率限制"),
            "CA_R5_SLEW": qsTr("电机 5 变化率限制"),
            "CA_R6_SLEW": qsTr("电机 6 变化率限制"),
            "CA_R7_SLEW": qsTr("电机 7 变化率限制"),
            "CA_R8_SLEW": qsTr("电机 8 变化率限制"),
            "CA_R9_SLEW": qsTr("电机 9 变化率限制"),
            "CA_R10_SLEW": qsTr("电机 10 变化率限制"),
            "CA_R11_SLEW": qsTr("电机 11 变化率限制"),
            "CA_ROTOR_COUNT": qsTr("旋翼数量"),
            "CA_SV_CS_COUNT": qsTr("舵面数量"),
            "CA_SV_FLAP_SLEW": qsTr("襟翼变化率限制"),
            "CA_SV_TL_COUNT": qsTr("倾转舵机数量"),

            "HTE_ACC_GATE": qsTr("加速度融合门限"),
            "HTE_HT_ERR_INIT": qsTr("1-sigma 初始悬停推力不确定度"),
            "HTE_HT_NOISE": qsTr("悬停推力过程噪声"),
            "HTE_THR_RANGE": qsTr("相对 MPC_THR_HOVER 的最大偏差"),
            "HTE_VXY_THR": qsTr("降低灵敏度的水平速度阈值"),
            "HTE_VZ_THR": qsTr("降低灵敏度的垂直速度阈值"),

            "LNDFW_AIRSPD_MAX": qsTr("固定翼着陆检测：最大空速"),
            "LNDFW_ROT_MAX": qsTr("固定翼着陆检测：最大旋转速度"),
            "LNDFW_TRIG_TIME": qsTr("固定翼着陆检测触发时间"),
            "LNDFW_VEL_XY_MAX": qsTr("固定翼着陆检测：最大水平速度阈值"),
            "LNDFW_VEL_Z_MAX": qsTr("固定翼着陆检测：最大垂直速度阈值"),
            "LNDFW_XYACC_MAX": qsTr("固定翼着陆检测：最大水平加速度"),
            "LNDMC_ALT_GND": qsTr("多旋翼地面效应高度"),
            "LNDMC_ROT_MAX": qsTr("多旋翼最大旋转速度"),
            "LNDMC_XY_VEL_MAX": qsTr("多旋翼最大水平速度"),
            "LNDMC_Z_VEL_MAX": qsTr("多旋翼垂直速度阈值"),
            "LND_FLIGHT_T_HI": qsTr("总飞行时间（微秒）高 32 位"),
            "LND_FLIGHT_T_LO": qsTr("总飞行时间（微秒）低 32 位"),

            "LTEST_ACC_UNC": qsTr("加速度不确定度"),
            "LTEST_MEAS_UNC": qsTr("降落目标测量不确定度"),
            "LTEST_MODE": qsTr("降落目标模式"),
            "LTEST_POS_UNC_IN": qsTr("初始降落目标位置不确定度"),
            "LTEST_SCALE_X": qsTr("传感器 X 轴测量缩放系数"),
            "LTEST_SCALE_Y": qsTr("传感器 Y 轴测量缩放系数"),
            "LTEST_SENS_POS_X": qsTr("IRLOCK 在机体系中的 X 位置（前向）"),
            "LTEST_SENS_POS_Y": qsTr("IRLOCK 在机体系中的 Y 位置（右向）"),
            "LTEST_SENS_POS_Z": qsTr("IRLOCK 在机体系中的 Z 位置（向下）"),
            "LTEST_SENS_ROT": qsTr("IRLOCK 传感器相对机架的旋转"),
            "LTEST_VEL_UNC_IN": qsTr("初始降落目标速度不确定度"),

            "LPE_ACC_XY": qsTr("加速度计 XY 噪声密度"),
            "LPE_ACC_Z": qsTr("加速度计 Z 噪声密度"),
            "LPE_BAR_Z": qsTr("气压高度 Z 标准差"),
            "LPE_EN": qsTr("启用本地位置估计器（不支持）"),
            "LPE_EPH_MAX": qsTr("GPS 初始化允许的最大 EPH"),
            "LPE_EPV_MAX": qsTr("GPS 初始化允许的最大 EPV"),
            "LPE_FAKE_ORIGIN": qsTr("启用发布虚拟全局位置"),
            "LPE_FGYRO_HP": qsTr("光流陀螺仪高通滤波截止频率"),
            "LPE_FLW_OFF_Z": qsTr("光流相对中心的 Z 偏移"),
            "LPE_FLW_QMIN": qsTr("光流最低质量阈值"),
            "LPE_FLW_R": qsTr("光流旋转（横滚/俯仰）噪声增益"),
            "LPE_FLW_RR": qsTr("光流角速度噪声增益"),
            "LPE_FLW_SCALE": qsTr("光流缩放"),
            "LPE_FUSION": qsTr("控制数据融合的整型位掩码"),
            "LPE_GPS_DELAY": qsTr("GPS 延迟补偿"),
            "LPE_GPS_VXY": qsTr("GPS XY 速度标准差"),
            "LPE_GPS_VZ": qsTr("GPS Z 速度标准差"),
            "LPE_GPS_XY": qsTr("最小 GPS XY 标准差"),
            "LPE_GPS_Z": qsTr("最小 GPS Z 标准差"),
            "LPE_LAND_VXY": qsTr("着陆检测器 XY 速度标准差"),
            "LPE_LAND_Z": qsTr("着陆检测器 Z 标准差"),
            "LPE_LAT": qsTr("无 GPS 导航的本地原点纬度"),
            "LPE_LDR_OFF_Z": qsTr("激光雷达相对飞行器中心的 Z 偏移（向下为正）"),
            "LPE_LDR_Z": qsTr("激光雷达 Z 标准差"),
            "LPE_LON": qsTr("无 GPS 导航的本地原点经度"),
            "LPE_LT_COV": qsTr("最小降落目标标准协方差"),
            "LPE_PN_B": qsTr("加速度偏置传播噪声密度"),
            "LPE_PN_P": qsTr("位置传播噪声密度"),
            "LPE_PN_T": qsTr("地形随机游走噪声密度"),
            "LPE_PN_V": qsTr("速度传播噪声密度"),
            "LPE_SNR_OFF_Z": qsTr("声呐相对飞行器中心的 Z 偏移（向下为正）"),
            "LPE_SNR_Z": qsTr("声呐 Z 标准差"),
            "LPE_T_MAX_GRADE": qsTr("最大地形坡度百分比"),
            "LPE_VIC_P": qsTr("Vicon 位置标准差"),
            "LPE_VIS_DELAY": qsTr("视觉延迟补偿"),
            "LPE_VIS_XY": qsTr("视觉 XY 标准差"),
            "LPE_VIS_Z": qsTr("视觉 Z 标准差"),
            "LPE_VXY_PUB": qsTr("发布位置所需 XY 速度标准差"),
            "LPE_X_LP": qsTr("状态发布截止频率"),
            "LPE_Z_PUB": qsTr("发布高度/地形所需 Z 标准差"),

            "MAV_COMP_ID": qsTr("MAVLink 组件 ID"),
            "MAV_FWDEXTSP": qsTr("转发外部设定点消息"),
            "MAV_HASH_CHK_EN": qsTr("参数哈希检查"),
            "MAV_HB_FORW_EN": qsTr("心跳消息转发"),
            "MAV_PROTO_VER": qsTr("MAVLink 协议版本"),
            "MAV_RADIO_TOUT": qsTr("RADIO_STATUS 报告超时"),
            "MAV_SIGN_CFG": qsTr("MAVLink 协议签名"),
            "MAV_SIK_RADIO_ID": qsTr("MAVLink SiK 电台 ID"),
            "MAV_SYS_ID": qsTr("MAVLink 系统 ID"),
            "MAV_S_FORWARD": qsTr("在 TELEM2 上启用 MAVLink 转发"),
            "MAV_S_MODE": qsTr("SOM 到 FMU 通信通道的 MAVLink 模式"),
            "MAV_TYPE": qsTr("MAVLink 机架类型"),
            "MAV_USEHILGPS": qsTr("即使不在 HIL 模式也使用/接受 HIL GPS 消息"),

            "MBE_ENABLE": qsTr("启用在线磁力计偏置校准"),
            "MBE_LEARN_GAIN": qsTr("磁偏置估计器学习增益"),

            "MAN_ARM_GESTURE": qsTr("启用摇杆解锁/上锁手势"),
            "MAN_DEADZONE": qsTr("摇杆死区（仅特定用例）"),
            "MAN_KILL_GEST_T": qsTr("Kill 摇杆手势触发时间"),

            "MIS_COMMAND_TOUT": qsTr("允许载荷执行任务命令的超时"),
            "MIS_DIST_1WP": qsTr("Home 到第一个航点的最大水平距离"),
            "MIS_LND_ABRT_ALT": qsTr("降落中止最小高度"),
            "MIS_MNT_YAW_CTL": qsTr("启用挂载偏航控制"),
            "MIS_TAKEOFF_ALT": qsTr("默认起飞高度"),
            "MIS_TKO_LAND_REQ": qsTr("任务起飞/降落要求"),
            "MIS_YAW_ERR": qsTr("航点航向接受所需的最大偏航误差"),
            "MIS_YAW_TMT": qsTr("强制航向航点等待目标航向的时间"),
            "MPC_YAW_MODE": qsTr("自主模式中的航向行为"),
            "NAV_ACC_RAD": qsTr("接受半径"),
            "NAV_FORCE_VT": qsTr("强制 VTOL 模式起飞和降落"),
            "NAV_FW_ALTL_RAD": qsTr("降落前固定翼高度接受半径"),
            "NAV_FW_ALT_RAD": qsTr("固定翼高度接受半径"),
            "NAV_LOITER_RAD": qsTr("盘旋半径（仅固定翼）"),
            "NAV_MC_ALT_RAD": qsTr("多旋翼高度接受半径"),
            "NAV_MIN_GND_DIST": qsTr("Mission 和 RTL 期间最小离地高度"),
            "NAV_MIN_LTR_ALT": qsTr("最小盘旋高度"),
            "NAV_TRAFF_AVOID": qsTr("交通避让模式"),
            "NAV_TRAFF_A_HOR": qsTr("交通避让水平距离"),
            "NAV_TRAFF_A_VER": qsTr("交通避让垂直距离"),
            "NAV_TRAFF_COLL_T": qsTr("预计碰撞时间"),

            "MC_AIRMODE": qsTr("多旋翼 Air-mode"),

            "MNT_DO_STAB": qsTr("稳定挂载"),
            "MNT_LND_P_MAX": qsTr("着陆状态最大俯仰角"),
            "MNT_LND_P_MIN": qsTr("着陆状态最小俯仰角"),
            "MNT_MAN_PITCH": qsTr("控制俯仰的辅助通道"),
            "MNT_MAN_ROLL": qsTr("控制横滚的辅助通道"),
            "MNT_MAN_YAW": qsTr("控制偏航的辅助通道"),
            "MNT_MAV_COMPID": qsTr("挂载的 MAVLink 组件 ID"),
            "MNT_MAV_SYSID": qsTr("挂载的 MAVLink 系统 ID"),
            "MNT_MAX_PITCH": qsTr("俯仰设定点最大正角度"),
            "MNT_MIN_PITCH": qsTr("俯仰设定点最小负角度"),
            "MNT_MODE_IN": qsTr("挂载输入模式"),
            "MNT_MODE_OUT": qsTr("挂载输出模式"),
            "MNT_RANGE_ROLL": qsTr("横滚通道输出范围"),
            "MNT_RANGE_YAW": qsTr("偏航通道输出范围"),
            "MNT_RATE_PITCH": qsTr("手动输入的俯仰角速率"),
            "MNT_RATE_YAW": qsTr("手动输入的偏航角速率"),
            "MNT_RC_IN_MODE": qsTr("RC 云台输入模式"),
            "MNT_TAU": qsTr("开环 AUX 挂载控制 Alpha 滤波时间常数"),

            "MC_ACRO_EXPO": qsTr("Acro 模式横滚/俯仰 Expo 系数"),
            "MC_ACRO_EXPO_Y": qsTr("Acro 模式偏航 Expo 系数"),
            "MC_ACRO_P_MAX": qsTr("Acro 模式最大俯仰角速率"),
            "MC_ACRO_R_MAX": qsTr("Acro 模式最大横滚角速率"),
            "MC_ACRO_SUPEXPO": qsTr("Acro 模式横滚/俯仰 Super Expo 系数"),
            "MC_ACRO_SUPEXPOY": qsTr("Acro 模式偏航 Super Expo 系数"),
            "MC_ACRO_Y_MAX": qsTr("Acro 模式最大偏航角速率"),

            "MC_PITCHRATE_MAX": qsTr("最大俯仰角速率"),
            "MC_PITCH_P": qsTr("俯仰 P 增益"),
            "MC_ROLLRATE_MAX": qsTr("最大横滚角速率"),
            "MC_ROLL_P": qsTr("横滚 P 增益"),
            "MC_YAWRATE_MAX": qsTr("最大偏航角速率"),
            "MC_YAW_P": qsTr("偏航 P 增益"),
            "MC_YAW_WEIGHT": qsTr("偏航权重"),
            "MPC_YAWRAUTO_ACC": qsTr("自主模式最大偏航加速度"),
            "MPC_YAWRAUTO_MAX": qsTr("自主模式最大偏航角速率"),

            "CP_DELAY": qsTr("测距传感器消息平均延迟与位置控制器跟踪延迟"),
            "CP_DIST": qsTr("飞行器应与所有障碍物保持的最小距离"),
            "CP_GO_NO_DATA": qsTr("允许向无传感器数据方向移动"),
            "CP_GUIDE_ANG": qsTr("避障算法可改变设定点方向的左右角度"),
            "MC_MAN_TILT_TAU": qsTr("手动倾斜输入滤波时间常数"),
            "MPC_ACC_DECOUPLE": qsTr("加速度到倾斜的耦合"),
            "MPC_ACC_DOWN_MAX": qsTr("爬升率控制模式最大向下加速度"),
            "MPC_HOLD_MAX_XY": qsTr("启用位置保持的最大水平速度"),
            "MPC_HOLD_MAX_Z": qsTr("启用位置保持的最大垂直速度"),
            "MPC_JERK_AUTO": qsTr("自主模式加加速度限制"),
            "MPC_JERK_MAX": qsTr("Position/Altitude 模式最大水平和垂直加加速度"),
            "MPC_LAND_ALT1": qsTr("慢速降落第 1 阶段高度（下降）"),
            "MPC_LAND_ALT2": qsTr("慢速降落第 2 阶段高度（降落）"),
            "MPC_LAND_ALT3": qsTr("慢速降落第 3 阶段高度"),
            "MPC_LAND_CRWL": qsTr("降落爬行下降率"),
            "MPC_LAND_RADIUS": qsTr("用户辅助降落半径"),
            "MPC_LAND_RC_HELP": qsTr("自主降落期间启用用户输入微调"),
            "MPC_LAND_SPEED": qsTr("降落下降率"),
            "MPC_MANTHR_MIN": qsTr("Stabilized 模式最小总推力"),
            "MPC_MAN_TILT_MAX": qsTr("Stabilized、Altitude 和 Altitude Cruise 模式最大倾斜角"),
            "MPC_MAN_Y_MAX": qsTr("Stabilized、Altitude、Position 模式最大手动偏航角速率"),
            "MPC_MAN_Y_TAU": qsTr("手动偏航角速率输入滤波时间常数"),
            "MPC_POS_MODE": qsTr("Position/Altitude 模式变体"),
            "MPC_THR_CURVE": qsTr("Stabilized 模式推力曲线映射"),
            "MPC_THR_HOVER": qsTr("悬停所需垂直推力"),
            "MPC_THR_MAX": qsTr("爬升率控制模式最大总推力"),
            "MPC_THR_MIN": qsTr("爬升率控制模式最小总推力"),
            "MPC_THR_XY_MARG": qsTr("水平推力余量"),
            "MPC_TILTMAX_AIR": qsTr("空中最大倾斜角"),
            "MPC_TILTMAX_LND": qsTr("初始起飞斜坡期间最大倾斜角"),
            "MPC_TKO_RAMP_T": qsTr("平滑起飞斜坡时间常数"),
            "MPC_TKO_SPEED": qsTr("起飞爬升率"),
            "MPC_USE_HTE": qsTr("在高度控制中使用悬停推力估计"),
            "MPC_VELD_LP": qsTr("速度微分低通截止频率"),
            "MPC_VEL_LP": qsTr("速度低通截止频率"),
            "MPC_VEL_MANUAL": qsTr("Position 模式最大水平速度设定点"),
            "MPC_VEL_MAN_BACK": qsTr("Position 模式最大后退速度"),
            "MPC_VEL_MAN_SIDE": qsTr("Position 模式最大侧向速度"),
            "MPC_VEL_NF_BW": qsTr("速度陷波滤波器带宽"),
            "MPC_VEL_NF_FRQ": qsTr("速度陷波滤波器频率"),
            "MPC_XY_CRUISE": qsTr("自主模式默认水平速度"),
            "MPC_XY_ERR_MAX": qsTr("轨迹生成器允许的最大水平误差"),
            "MPC_XY_MAN_EXPO": qsTr("手动位置控制摇杆 Expo 曲线系数"),
            "MPC_XY_P": qsTr("水平位置误差比例增益"),
            "MPC_XY_TRAJ_P": qsTr("水平轨迹位置误差比例增益"),
            "MPC_XY_VEL_ALL": qsTr("总体水平速度限制"),
            "MPC_XY_VEL_D_ACC": qsTr("水平速度误差微分增益"),
            "MPC_XY_VEL_I_ACC": qsTr("水平速度误差积分增益"),
            "MPC_XY_VEL_MAX": qsTr("最大水平速度"),
            "MPC_XY_VEL_P_ACC": qsTr("水平速度误差比例增益"),
            "MPC_Z_P": qsTr("垂直位置误差比例增益"),
            "MPC_Z_VEL_ALL": qsTr("总体垂直速度限制"),
            "MPC_Z_VEL_D_ACC": qsTr("垂直速度误差微分增益"),
            "MPC_Z_VEL_I_ACC": qsTr("垂直速度误差积分增益"),
            "MPC_Z_VEL_MAX_DN": qsTr("最大下降速度"),
            "MPC_Z_VEL_MAX_UP": qsTr("最大上升速度"),
            "MPC_Z_VEL_P_ACC": qsTr("垂直速度误差比例增益"),
            "MPC_Z_V_AUTO_DN": qsTr("自主模式下降速度"),
            "MPC_Z_V_AUTO_UP": qsTr("自主模式上升速度"),
            "SYS_VEHICLE_RESP": qsTr("响应性"),
            "WV_EN": qsTr("启用风标效应"),
            "WV_ROLL_MIN": qsTr("风标控制器请求偏航角速率的最小横滚角设定点"),
            "WV_YRATE_MAX": qsTr("风标控制器允许请求的最大偏航角速率"),

            "MC_SLOW_DEF_HVEL": qsTr("默认水平速度限制"),
            "MC_SLOW_DEF_VVEL": qsTr("默认垂直速度限制"),
            "MC_SLOW_DEF_YAWR": qsTr("默认偏航角速率限制"),
            "MC_SLOW_MAP_HVEL": qsTr("位置慢速模式中缩放水平速度的手动输入映射"),
            "MC_SLOW_MAP_PTCH": qsTr("位置慢速模式中云台俯仰角速率控制输入映射"),
            "MC_SLOW_MAP_VVEL": qsTr("位置慢速模式中缩放垂直速度的手动输入映射"),
            "MC_SLOW_MAP_YAWR": qsTr("位置慢速模式中缩放偏航角速率的手动输入映射"),
            "MC_SLOW_MIN_HVEL": qsTr("水平速度下限"),
            "MC_SLOW_MIN_VVEL": qsTr("垂直速度下限"),
            "MC_SLOW_MIN_YAWR": qsTr("偏航角速率下限"),

            "MC_BAT_SCALE_EN": qsTr("电池电量缩放"),
            "MC_PITCHRATE_D": qsTr("俯仰角速率 D 增益"),
            "MC_PITCHRATE_FF": qsTr("俯仰角速率前馈"),
            "MC_PITCHRATE_I": qsTr("俯仰角速率 I 增益"),
            "MC_PITCHRATE_K": qsTr("俯仰角速率控制器增益"),
            "MC_PITCHRATE_P": qsTr("俯仰角速率 P 增益"),
            "MC_PR_INT_LIM": qsTr("俯仰角速率积分限制"),
            "MC_ROLLRATE_D": qsTr("横滚角速率 D 增益"),
            "MC_ROLLRATE_FF": qsTr("横滚角速率前馈"),
            "MC_ROLLRATE_I": qsTr("横滚角速率 I 增益"),
            "MC_ROLLRATE_K": qsTr("横滚角速率控制器增益"),
            "MC_ROLLRATE_P": qsTr("横滚角速率 P 增益"),
            "MC_RR_INT_LIM": qsTr("横滚角速率积分限制"),
            "MC_YAWRATE_D": qsTr("偏航角速率 D 增益"),
            "MC_YAWRATE_FF": qsTr("偏航角速率前馈"),
            "MC_YAWRATE_I": qsTr("偏航角速率 I 增益"),
            "MC_YAWRATE_K": qsTr("偏航角速率控制器增益"),
            "MC_YAWRATE_P": qsTr("偏航角速率 P 增益"),
            "MC_YAW_TQ_CUTOFF": qsTr("偏航力矩设定点低通滤波截止频率"),
            "MC_YR_INT_LIM": qsTr("偏航角速率积分限制"),

            "OSD_CH_HEIGHT": qsTr("OSD 十字准线高度"),
            "OSD_DWELL_TIME": qsTr("OSD 停留时间 (ms)"),
            "OSD_LOG_LEVEL": qsTr("OSD 警告级别"),
            "OSD_RC_STICK": qsTr("OSD RC 摇杆命令"),
            "OSD_SCROLL_RATE": qsTr("OSD 滚动速率 (ms)"),
            "OSD_SYMBOLS": qsTr("OSD 符号选择"),

            "THR_MDL_FAC": qsTr("推力到电机控制信号模型参数"),

            "PD_GRIPPER_TO": qsTr("抓取器动作成功确认超时"),
            "PD_GRIPPER_TYPE": qsTr("抓取器类型"),

            "PLD_BTOUT": qsTr("降落目标超时"),
            "PLD_FAPPR_ALT": qsTr("最终进近高度"),
            "PLD_HACC_RAD": qsTr("水平接受半径"),
            "PLD_MAX_SRCH": qsTr("最大搜索次数"),
            "PLD_SRCH_ALT": qsTr("搜索高度"),
            "PLD_SRCH_TOUT": qsTr("搜索超时"),

            "PP_LOOKAHD_GAIN": qsTr("Pure Pursuit 控制器调参参数"),
            "PP_LOOKAHD_MAX": qsTr("Pure Pursuit 控制器最大前视距离"),
            "PP_LOOKAHD_MIN": qsTr("Pure Pursuit 控制器最小前视距离"),

            "RC_CHAN_CNT": qsTr("RC 通道数量"),
            "RC_FAILS_THR": qsTr("失控通道 PWM 阈值"),
            "RC_MAP_ENG_MOT": qsTr("主电机接合 RC 通道"),
            "RC_MAP_FAILSAFE": qsTr("失控通道映射"),
            "RC_MAP_PITCH": qsTr("俯仰控制通道映射"),
            "RC_MAP_ROLL": qsTr("横滚控制通道映射"),
            "RC_MAP_THROTTLE": qsTr("油门控制通道映射"),
            "RC_MAP_YAW": qsTr("偏航控制通道映射"),
            "RC_RSSI_PWM_CHAN": qsTr("提供 RSSI 的 PWM 输入通道"),
            "RC_RSSI_PWM_MAX": qsTr("RSSI 读数最大输入值"),
            "RC_RSSI_PWM_MIN": qsTr("RSSI 读数最小输入值"),
            "TRIM_PITCH": qsTr("俯仰配平"),
            "TRIM_ROLL": qsTr("横滚配平"),
            "TRIM_YAW": qsTr("偏航配平"),

            "RC_ARMSWITCH_TH": qsTr("解锁开关阈值"),
            "RC_ENG_MOT_TH": qsTr("主电机接合选择阈值"),
            "RC_GEAR_TH": qsTr("起落架开关阈值"),
            "RC_KILLSWITCH_TH": qsTr("急停开关阈值"),
            "RC_LOITER_TH": qsTr("悬停模式选择阈值"),
            "RC_MAP_ARM_SW": qsTr("解锁开关通道"),
            "RC_MAP_FLAPS": qsTr("襟翼通道"),
            "RC_MAP_FLTMODE": qsTr("单通道飞行模式选择"),
            "RC_MAP_FLTM_BTN": qsTr("按钮式飞行模式选择"),
            "RC_MAP_GEAR_SW": qsTr("起落架开关通道"),
            "RC_MAP_KILL_SW": qsTr("紧急急停开关通道"),
            "RC_MAP_LOITER_SW": qsTr("悬停开关通道"),
            "RC_MAP_MODE_SW": qsTr("模式开关通道映射（已弃用）"),
            "RC_MAP_OFFB_SW": qsTr("Offboard 开关通道"),
            "RC_MAP_PAY_SW": qsTr("载荷电源开关 RC 通道"),
            "RC_MAP_RETURN_SW": qsTr("返航开关通道"),
            "RC_MAP_TERM_SW": qsTr("终止开关通道"),
            "RC_MAP_TRANS_SW": qsTr("VTOL 转换开关通道映射"),
            "RC_OFFB_TH": qsTr("Offboard 模式选择阈值"),
            "RC_PAYLOAD_MIDTH": qsTr("载荷电源开关中位阈值"),
            "RC_PAYLOAD_TH": qsTr("载荷电源开关开启阈值"),
            "RC_RETURN_TH": qsTr("返航模式选择阈值"),
            "RC_TRANS_TH": qsTr("VTOL 转换开关阈值"),

            "RTL_CONE_ANG": qsTr("返航模式高度锥半角"),
            "RTL_DESCEND_ALT": qsTr("返航模式盘旋高度"),
            "RTL_LAND_DELAY": qsTr("返航模式延时"),
            "RTL_LOITER_RAD": qsTr("返航下降盘旋半径"),
            "RTL_MIN_DIST": qsTr("返航特殊规则适用的水平半径"),
            "RTL_PLD_MD": qsTr("RTL 精准降落模式"),
            "RTL_RETURN_ALT": qsTr("返航模式返航高度"),
            "RTL_TYPE": qsTr("返航类型"),

            "RTL_APPR_FORCE": qsTr("RTL 强制进近降落"),
            "RTL_TIME_FACTOR": qsTr("RTL 时间估算安全裕度系数"),
            "RTL_TIME_MARGIN": qsTr("RTL 时间估算安全裕度偏移"),

            "RA_ACC_RAD_GAIN": qsTr("弯道切角调参参数"),
            "RA_ACC_RAD_MAX": qsTr("航点最大接受半径"),
            "RA_MAX_STR_ANG": qsTr("最大转向角"),
            "RA_STR_RATE_LIM": qsTr("转向速率限制"),
            "RA_WHEEL_BASE": qsTr("轴距"),

            "RO_YAW_P": qsTr("闭环偏航控制器比例增益"),

            "RD_TRANS_DRV_TRN": qsTr("行驶切换到原地转向的偏航误差阈值"),
            "RD_TRANS_TRN_DRV": qsTr("原地转向切换到行驶的偏航误差阈值"),
            "RD_WHEEL_TRACK": qsTr("轮距"),
            "RD_YAW_STK_GAIN": qsTr("Manual 模式偏航摇杆增益"),

            "RM_COURSE_CTL_TH": qsTr("手动位置模式航向控制更新阈值"),
            "RM_WHEEL_TRACK": qsTr("轮距"),
            "RM_YAW_STK_GAIN": qsTr("Manual 模式偏航摇杆增益"),

            "RO_YAW_ACCEL_LIM": qsTr("偏航加速度限制"),
            "RO_YAW_DECEL_LIM": qsTr("偏航减速度限制"),
            "RO_YAW_EXPO": qsTr("偏航角速率指数系数"),
            "RO_YAW_RATE_CORR": qsTr("偏航角速率修正系数"),
            "RO_YAW_RATE_I": qsTr("闭环偏航角速率控制器积分增益"),
            "RO_YAW_RATE_LIM": qsTr("偏航角速率限制"),
            "RO_YAW_RATE_P": qsTr("闭环偏航角速率控制器比例增益"),
            "RO_YAW_RATE_TH": qsTr("偏航角速率测量阈值"),
            "RO_YAW_STICK_DZ": qsTr("偏航摇杆死区"),
            "RO_YAW_SUPEXPO": qsTr("偏航角速率超级指数系数"),

            "RO_ACCEL_LIM": qsTr("加速度限制"),
            "RO_DECEL_LIM": qsTr("减速度限制"),
            "RO_JERK_LIM": qsTr("加加速度限制"),
            "RO_MAX_THR_SPEED": qsTr("最大油门时的地面车速度"),
            "RO_SPEED_I": qsTr("地速控制器积分增益"),
            "RO_SPEED_LIM": qsTr("速度限制"),
            "RO_SPEED_P": qsTr("地速控制器比例增益"),
            "RO_SPEED_RED": qsTr("基于航向误差的速度降低调参参数"),
            "RO_SPEED_TH": qsTr("速度测量阈值"),

            "RWTO_MAX_THR": qsTr("跑道起飞油门"),
            "RWTO_NUDGE": qsTr("跑道滑跑时允许用偏航摇杆微调机轮"),
            "RWTO_PSP": qsTr("滑行/起飞拉起前俯仰设定点"),
            "RWTO_RAMP_TIME": qsTr("跑道起飞油门渐增时间"),
            "RWTO_ROT_AIRSPD": qsTr("起飞拉起空速"),
            "RWTO_ROT_TIME": qsTr("起飞拉起时间"),
            "RWTO_TKOFF": qsTr("带起落架跑道起飞"),

            "SDLOG_BACKEND": qsTr("日志后端（整数位掩码）"),
            "SDLOG_BOOT_BAT": qsTr("仅电池供电时记录日志"),
            "SDLOG_DIRS_MAX": qsTr("保留的最大日志目录数"),
            "SDLOG_MISSION": qsTr("任务日志"),
            "SDLOG_MODE": qsTr("日志记录模式"),
            "SDLOG_PROFILE": qsTr("日志主题配置（整数位掩码）"),
            "SDLOG_UTC_OFFSET": qsTr("UTC 偏移（单位：分钟）"),
            "SDLOG_UUID": qsTr("日志 UUID"),

            "SIM_BAT_DRAIN": qsTr("模拟器电池耗电间隔"),
            "SIM_BAT_ENABLE": qsTr("启用模拟器电池"),
            "SIM_BAT_MIN_PCT": qsTr("模拟器电池最低百分比"),

            "CAL_MAG_COMP_TYP": qsTr("磁力计补偿类型"),
            "SENS_DPRES_ANSC": qsTr("差压传感器模拟缩放"),
            "SENS_DPRES_OFF": qsTr("差压传感器偏移"),
            "SENS_DPRES_REV": qsTr("反转差压传感器读数"),
            "SENS_FLOW_MAXHGT": qsTr("依赖光流时的最大离地高度"),
            "SENS_FLOW_MAXR": qsTr("光流传感器可靠测量的最大角流速幅值"),
            "SENS_FLOW_MINHGT": qsTr("依赖光流时的最小离地高度"),

            "CAL_AIR_CMODEL": qsTr("SDP3x 空速传感器补偿模型"),
            "CAL_AIR_TUBED_MM": qsTr("空速传感器管径"),
            "CAL_AIR_TUBELEN": qsTr("空速传感器管长"),
            "CAL_MAG_SIDES": qsTr("仅用于旧版 QGC 支持"),
            "IMU_ACCEL_CUTOFF": qsTr("加速度计低通滤波截止频率"),
            "IMU_DGYRO_CUTOFF": qsTr("角加速度截止频率（D 项滤波器）"),
            "IMU_GYRO_CAL_EN": qsTr("启用 IMU 陀螺仪自动校准"),
            "IMU_GYRO_CUTOFF": qsTr("陀螺仪低通滤波截止频率"),
            "IMU_GYRO_DNF_BW": qsTr("IMU 陀螺仪 ESC 陷波滤波器带宽"),
            "IMU_GYRO_DNF_EN": qsTr("IMU 陀螺仪动态陷波滤波"),
            "IMU_GYRO_DNF_HMC": qsTr("IMU 陀螺仪动态陷波滤波器谐波"),
            "IMU_GYRO_DNF_MIN": qsTr("IMU 陀螺仪动态陷波滤波器最低频率"),
            "IMU_GYRO_FFT_EN": qsTr("启用 IMU 陀螺仪 FFT"),
            "IMU_GYRO_FFT_LEN": qsTr("IMU 陀螺仪 FFT 长度"),
            "IMU_GYRO_FFT_MAX": qsTr("IMU 陀螺仪 FFT 最高频率"),
            "IMU_GYRO_FFT_MIN": qsTr("IMU 陀螺仪 FFT 最低频率"),
            "IMU_GYRO_FFT_SNR": qsTr("IMU 陀螺仪 FFT 信噪比"),
            "IMU_GYRO_NF0_BW": qsTr("陀螺仪陷波滤波器带宽"),
            "IMU_GYRO_NF0_FRQ": qsTr("陀螺仪陷波滤波器频率"),
            "IMU_GYRO_NF1_BW": qsTr("陀螺仪陷波滤波器 1 带宽"),
            "IMU_GYRO_NF1_FRQ": qsTr("陀螺仪陷波滤波器 2 频率"),
            "IMU_GYRO_RATEMAX": qsTr("陀螺仪控制数据最大发布速率（内环速率）"),
            "IMU_INTEG_RATE": qsTr("IMU 积分速率"),
            "SENS_BARO_QNH": qsTr("气压计 QNH"),
            "SENS_BARO_RATE": qsTr("气压计最大速率"),
            "SENS_BAR_AUTOCAL": qsTr("气压计自动校准"),
            "SENS_BOARD_ROT": qsTr("板载旋转"),
            "SENS_BOARD_X_OFF": qsTr("板载旋转 X（横滚）偏移"),
            "SENS_BOARD_Y_OFF": qsTr("板载旋转 Y（俯仰）偏移"),
            "SENS_BOARD_Z_OFF": qsTr("板载旋转 Z（偏航）偏移"),
            "SENS_EN_AGPSIM": qsTr("模拟辅助全局位置 (AGP)"),
            "SENS_EN_ARSPDSIM": qsTr("启用模拟空速传感器实例"),
            "SENS_EN_BAROSIM": qsTr("启用模拟气压计传感器实例"),
            "SENS_EN_BATT": qsTr("SMBus 智能电池驱动 BQ40Z50"),
            "SENS_EN_GPSSIM": qsTr("启用模拟 GPS 实例"),
            "SENS_EN_LL40LS": qsTr("Lidar-Lite (LL40LS) 测距传感器"),
            "SENS_EN_MAGSIM": qsTr("启用模拟磁力计传感器实例"),
            "SENS_EN_PAA3905": qsTr("PAA3905 光流传感器"),
            "SENS_EN_PAW3902": qsTr("PAW3902/PAW3903 光流传感器"),
            "SENS_EN_PMW3901": qsTr("PMW3901 光流传感器"),
            "SENS_EN_PX4FLOW": qsTr("PX4Flow 光流传感器"),
            "SENS_EN_SF1XX": qsTr("Lightware SF1xx/SF20/LW20 激光测距仪"),
            "SENS_EN_TF02PRO": qsTr("TF02 Pro 距离传感器 (I2C)"),
            "SENS_EN_THERMAL": qsTr("传感器温度热控"),
            "SENS_EN_TRANGER": qsTr("TeraRanger 测距仪 (I2C)"),
            "SENS_EN_VL53L0X": qsTr("VL53L0X 距离传感器"),
            "SENS_EN_VL53L1X": qsTr("VL53L1X 距离传感器"),
            "SENS_EXT_I2C_PRB": qsTr("外部 I2C 探测"),
            "SENS_FLOW_RATE": qsTr("光流最大速率"),
            "SENS_FLOW_ROT": qsTr("光流旋转"),
            "SENS_FLOW_SCALE": qsTr("光流缩放系数"),
            "SENS_GPS_MASK": qsTr("多 GPS 融合控制掩码"),
            "SENS_GPS_PRIME": qsTr("多 GPS 主实例"),
            "SENS_GPS_TAU": qsTr("多 GPS 融合时间常数"),
            "SENS_IMU_AUTOCAL": qsTr("IMU 自动校准"),
            "SENS_IMU_CLPNOTI": qsTr("IMU 削波通知"),
            "SENS_IMU_MODE": qsTr("传感器 Hub IMU 模式"),
            "SENS_INT_BARO_EN": qsTr("启用内部气压计"),
            "SENS_MAG_AUTOCAL": qsTr("磁力计自动校准"),
            "SENS_MAG_AUTOROT": qsTr("自动设置外部旋转"),
            "SENS_MAG_MODE": qsTr("传感器 Hub 磁力计模式"),
            "SENS_MAG_RATE": qsTr("磁力计最大速率"),
            "SENS_MAG_SIDES": qsTr("选择磁力计校准面的位字段"),
            "SENS_SF0X_CFG": qsTr("Lightware 激光测距仪串口配置"),
            "SENS_TFLOW_CFG": qsTr("ThoneFlow-3901U 串口配置"),
            "SENS_TFMINI_CFG": qsTr("Benewake TFmini 串口配置"),
            "SENS_ULAND_CFG": qsTr("uLanding 雷达串口配置"),
            "SENS_VN_CFG": qsTr("VectorNav 串口配置"),
            "SIM_ARSPD_FAIL": qsTr("动态模拟空速传感器实例故障"),

            "CAM_CAP_FBACK": qsTr("相机拍摄反馈"),

            "DSHOT_3D_DEAD_H": qsTr("DShot 3D 高死区"),
            "DSHOT_3D_DEAD_L": qsTr("DShot 3D 低死区"),
            "DSHOT_3D_ENABLE": qsTr("使用 DShot 时允许 3D 模式"),
            "DSHOT_BIDIR_EN": qsTr("启用双向 DShot"),
            "DSHOT_MIN": qsTr("DShot 电机最小输出"),
            "DSHOT_TEL_CFG": qsTr("DShot 驱动串口配置"),
            "MOT_POLE_COUNT": qsTr("电机磁极数量"),

            "SEP_AUTO_CONFIG": qsTr("切换自动接收机配置"),
            "SEP_CONST_USAGE": qsTr("不同卫星星座的使用"),
            "SEP_DUMP_COMM": qsTr("记录 GPS 通信数据"),
            "SEP_HARDW_SETUP": qsTr("硬件设置和预期用途"),
            "SEP_LOG_FORCE": qsTr("覆盖或追加现有日志"),
            "SEP_LOG_HZ": qsTr("接收机日志频率"),
            "SEP_LOG_LEVEL": qsTr("接收机日志级别"),
            "SEP_OUTP_HZ": qsTr("主 SBF 数据块输出频率"),
            "SEP_PITCH_OFFS": qsTr("双天线 GPS 俯仰偏移"),
            "SEP_SAT_INFO": qsTr("启用卫星信息"),
            "SEP_STREAM_LOG": qsTr("自动配置使用的日志流"),
            "SEP_STREAM_MAIN": qsTr("自动配置使用的主数据流"),
            "SEP_YAW_OFFS": qsTr("双天线 GPS 航向/偏航偏移"),

            "SIH_DISTSNSR_MAX": qsTr("距离传感器最大量程"),
            "SIH_DISTSNSR_MIN": qsTr("距离传感器最小量程"),
            "SIH_DISTSNSR_OVR": qsTr("距离传感器测量覆盖值"),
            "SIH_IXX": qsTr("飞行器 X 轴转动惯量"),
            "SIH_IXY": qsTr("飞行器 xy 交叉惯量项"),
            "SIH_IXZ": qsTr("飞行器 xz 交叉惯量项"),
            "SIH_IYY": qsTr("飞行器 Y 轴转动惯量"),
            "SIH_IYZ": qsTr("飞行器 yz 交叉惯量项"),
            "SIH_IZZ": qsTr("飞行器 Z 轴转动惯量"),
            "SIH_KDV": qsTr("一阶阻力系数"),
            "SIH_KDW": qsTr("一阶角阻尼系数"),
            "SIH_LOC_H0": qsTr("初始 AMSL 地面高度"),
            "SIH_LOC_LAT0": qsTr("初始大地纬度"),
            "SIH_LOC_LON0": qsTr("初始大地经度"),
            "SIH_L_PITCH": qsTr("俯仰力臂长度"),
            "SIH_L_ROLL": qsTr("横滚力臂长度"),
            "SIH_MASS": qsTr("飞行器质量"),
            "SIH_Q_MAX": qsTr("最大螺旋桨力矩"),
            "SIH_T_MAX": qsTr("最大螺旋桨推力"),
            "SIH_T_TAU": qsTr("推进器时间常数 tau"),
            "SIH_VEHICLE_TYPE": qsTr("飞行器类型"),
            "SIH_WIND_E": qsTr("东向风速"),
            "SIH_WIND_N": qsTr("北向风速"),

            "SIM_AGP_FAIL": qsTr("AGP 故障模式"),
            "SIM_BARO_OFF_P": qsTr("模拟气压计压力偏移"),
            "SIM_BARO_OFF_T": qsTr("模拟气压计温度偏移"),
            "SIM_GPS_USED": qsTr("模拟 GPS 使用的卫星数量"),
            "SIM_MAG_OFFSET_X": qsTr("模拟磁力计 X 偏移"),
            "SIM_MAG_OFFSET_Y": qsTr("模拟磁力计 Y 偏移"),
            "SIM_MAG_OFFSET_Z": qsTr("模拟磁力计 Z 偏移"),

            "SYS_AUTOCONFIG": qsTr("自动配置默认值"),
            "SYS_AUTOSTART": qsTr("自启动脚本索引"),
            "SYS_BL_UPDATE": qsTr("Bootloader 更新"),
            "SYS_CAL_ACCEL": qsTr("下次上电时自动开始加速度计热校准"),
            "SYS_CAL_BARO": qsTr("下次上电时自动开始气压计热校准"),
            "SYS_CAL_GYRO": qsTr("下次上电时自动开始角速率陀螺仪热校准"),
            "SYS_CAL_TDEL": qsTr("热校准所需温升"),
            "SYS_CAL_TMAX": qsTr("热校准最高起始温度"),
            "SYS_CAL_TMIN": qsTr("热校准最低起始温度"),
            "SYS_DM_BACKEND": qsTr("Dataman 存储后端"),
            "SYS_FAC_CAL_MODE": qsTr("启用工厂校准模式"),
            "SYS_FAILURE_EN": qsTr("启用故障注入"),
            "SYS_HAS_BARO": qsTr("控制飞行器是否有气压计"),
            "SYS_HAS_GPS": qsTr("控制飞行器是否有 GPS"),
            "SYS_HAS_MAG": qsTr("控制预期磁力计数量"),
            "SYS_HAS_NUM_ASPD": qsTr("控制飞行器是否有空速传感器"),
            "SYS_HAS_NUM_DIST": qsTr("需要检查可用的距离传感器数量"),
            "SYS_HAS_NUM_OF": qsTr("需要可用的光流传感器数量"),
            "SYS_HITL": qsTr("下次启动启用 HITL/SIH 模式"),
            "SYS_PARAM_VER": qsTr("参数版本"),
            "SYS_RGB_MAXBRT": qsTr("RGB LED 亮度限制"),
            "SYS_STCK_EN": qsTr("启用栈检查"),

            "TC_A_ENABLE": qsTr("加速度计传感器热补偿"),
            "TC_B_ENABLE": qsTr("气压传感器热补偿"),
            "TC_G_ENABLE": qsTr("角速率陀螺仪传感器热补偿"),
            "TC_M_ENABLE": qsTr("磁力计传感器热补偿"),

            "UUV_HGT_B_DOWN": qsTr("高度 RC 按钮下降"),
            "UUV_HGT_B_UP": qsTr("高度 RC 按钮上升"),
            "UUV_HGT_D": qsTr("高度微分增益"),
            "UUV_HGT_I": qsTr("高度积分增益"),
            "UUV_HGT_I_SPD": qsTr("积分增益误差累加速度"),
            "UUV_HGT_MAX_DIFF": qsTr("手动输入控制的最大高度差"),
            "UUV_HGT_P": qsTr("高度比例增益"),
            "UUV_HGT_STR": qsTr("手动输入高度变化强度"),
            "UUV_MGM_PITCH": qsTr("Manual 控制模式手动输入俯仰增益"),
            "UUV_MGM_ROLL": qsTr("Manual 控制模式手动输入横滚增益"),
            "UUV_MGM_THRTL": qsTr("Manual 控制模式手动输入油门增益"),
            "UUV_MGM_YAW": qsTr("Manual 控制模式手动输入偏航增益"),
            "UUV_PITCH_D": qsTr("俯仰微分增益"),
            "UUV_PITCH_P": qsTr("俯仰比例增益"),
            "UUV_RGM_PITCH": qsTr("速率控制模式手动输入俯仰增益"),
            "UUV_RGM_ROLL": qsTr("速率控制模式手动输入横滚增益"),
            "UUV_RGM_THRTL": qsTr("速率控制模式手动输入油门增益"),
            "UUV_RGM_YAW": qsTr("速率控制模式手动输入偏航增益"),
            "UUV_ROLL_D": qsTr("横滚微分增益"),
            "UUV_ROLL_P": qsTr("横滚比例增益"),
            "UUV_SGM_PITCH": qsTr("姿态控制模式手动输入俯仰增益"),
            "UUV_SGM_ROLL": qsTr("姿态控制模式手动输入横滚增益"),
            "UUV_SGM_THRTL": qsTr("姿态控制模式手动输入油门增益"),
            "UUV_SGM_YAW": qsTr("姿态控制模式手动输入偏航增益"),
            "UUV_SP_MAX_AGE": qsTr("重置设定点前的最长时间"),
            "UUV_STICK_MODE": qsTr("摇杆模式选择"),
            "UUV_THRUST_SAT": qsTr("UUV 推力设定点饱和"),
            "UUV_TORQUE_SAT": qsTr("UUV 力矩设定点饱和"),
            "UUV_YAW_D": qsTr("偏航微分增益"),
            "UUV_YAW_P": qsTr("偏航比例增益"),

            "UUV_GAIN_X_D": qsTr("X 轴 D 控制器增益"),
            "UUV_GAIN_X_P": qsTr("X 轴 P 控制器增益"),
            "UUV_GAIN_Y_D": qsTr("Y 轴 D 控制器增益"),
            "UUV_GAIN_Y_P": qsTr("Y 轴 P 控制器增益"),
            "UUV_GAIN_Z_D": qsTr("Z 轴 D 控制器增益"),
            "UUV_GAIN_Z_P": qsTr("Z 轴 P 控制器增益"),
            "UUV_PGM_VEL": qsTr("位置控制速度设定点更新增益"),
            "UUV_POS_MODE": qsTr("稳定模式或位置控制"),
            "UUV_POS_STICK_DB": qsTr("改变位置设定点的死区"),
            "UUV_STAB_MODE": qsTr("稳定模式或位置控制"),

            "UXRCE_DDS_AG_IP": qsTr("uXRCE-DDS Agent IP 地址"),
            "UXRCE_DDS_DOM_ID": qsTr("uXRCE-DDS 域 ID"),
            "UXRCE_DDS_FLCTRL": qsTr("启用 UXRCE 接口串口流控"),
            "UXRCE_DDS_KEY": qsTr("uXRCE-DDS 会话密钥"),
            "UXRCE_DDS_NS_IDX": qsTr("定义基于索引的消息命名空间"),
            "UXRCE_DDS_PRT": qsTr("uXRCE-DDS UDP 端口"),
            "UXRCE_DDS_PTCFG": qsTr("uXRCE-DDS 参与者配置"),
            "UXRCE_DDS_RX_TO": qsTr("RX 速率超时配置"),
            "UXRCE_DDS_SYNCC": qsTr("启用 uXRCE-DDS 系统时钟同步"),
            "UXRCE_DDS_SYNCT": qsTr("启用 uXRCE-DDS 时间戳同步"),
            "UXRCE_DDS_TX_TO": qsTr("TX 速率超时配置"),

            "VT_ARSP_BLEND": qsTr("转换混合空速"),
            "VT_ARSP_TRANS": qsTr("转换空速"),
            "VT_BT_TILT_DUR": qsTr("反向转换中电机上倾持续时间"),
            "VT_B_DEC_I": qsTr("反向转换减速度设定点到倾转 I 增益"),
            "VT_B_DEC_MSS": qsTr("反向转换期间近似减速度"),
            "VT_B_TRANS_DUR": qsTr("反向转换最长持续时间"),
            "VT_B_TRANS_RAMP": qsTr("反向转换 MC 电机渐增时间"),
            "VT_ELEV_MC_LOCK": qsTr("悬停时锁定操纵面"),
            "VT_FWD_THRUST_EN": qsTr("悬停时使用固定翼执行机构向前加速"),
            "VT_FWD_THRUST_SC": qsTr("悬停时固定翼执行机构推力缩放"),
            "VT_FW_DIFTHR_EN": qsTr("前飞差动推力"),
            "VT_FW_DIFTHR_S_P": qsTr("前飞俯仰差动推力系数"),
            "VT_FW_DIFTHR_S_R": qsTr("前飞横滚差动推力系数"),
            "VT_FW_DIFTHR_S_Y": qsTr("前飞偏航差动推力系数"),
            "VT_FW_MIN_ALT": qsTr("Quad-chute 高度"),
            "VT_FW_QC_HMAX": qsTr("Quad-chute 最大高度"),
            "VT_FW_QC_P": qsTr("Quad-chute 最大俯仰阈值"),
            "VT_FW_QC_R": qsTr("Quad-chute 最大横滚阈值"),
            "VT_F_TRANS_DUR": qsTr("正向转换持续时间"),
            "VT_F_TRANS_THR": qsTr("转换到固定翼飞行的目标油门值"),
            "VT_F_TR_OL_TM": qsTr("无空速正向转换时间（开环）"),
            "VT_LND_PITCH_MIN": qsTr("悬停降落期间最小俯仰角"),
            "VT_PITCH_MIN": qsTr("悬停期间最小俯仰角"),
            "VT_PSHER_SLEW": qsTr("推进电机油门渐增变化率"),
            "VT_QC_ALT_LOSS": qsTr("Quad-chute 非指令下降阈值"),
            "VT_QC_T_ALT_LOSS": qsTr("Quad-chute 转换高度损失阈值"),
            "VT_SPOILER_MC_LD": qsTr("降落（悬停）时扰流板设置"),
            "VT_TILT_FW": qsTr("FW 模式归一化倾转"),
            "VT_TILT_MC": qsTr("Hover 模式归一化倾转"),
            "VT_TILT_TRANS": qsTr("转换到 FW 时归一化倾转"),
            "VT_TRANS_MIN_TM": qsTr("正向转换最短时间"),
            "VT_TRANS_P2_DUR": qsTr("正向转换第 2 阶段持续时间"),
            "VT_TRANS_TIMEOUT": qsTr("正向转换超时"),
            "VT_TYPE": qsTr("VTOL 类型"),
            "WV_GAIN": qsTr("风标横滚角到偏航角速率"),

            "VTO_LOITER_ALT": qsTr("VTOL 起飞相对盘旋高度"),

            "ADSB_CALLSIGN_1": qsTr("CALLSIGN 前 4 个字符"),
            "ADSB_CALLSIGN_2": qsTr("CALLSIGN 后 4 个字符"),
            "ADSB_EMERGC": qsTr("ADSB-Out 紧急状态"),
            "ADSB_EMIT_TYPE": qsTr("ADSB-Out 飞行器发射机类型"),
            "ADSB_GPS_OFF_LAT": qsTr("ADSB-Out GPS 纬度偏移"),
            "ADSB_GPS_OFF_LON": qsTr("ADSB-Out GPS 经度偏移"),
            "ADSB_ICAO_ID": qsTr("ADSB-Out ICAO 配置"),
            "ADSB_ICAO_SPECL": qsTr("ADSB-In 特殊 ICAO 配置"),
            "ADSB_IDENT": qsTr("ADSB-Out Ident 配置"),
            "ADSB_LEN_WIDTH": qsTr("ADSB-Out 飞行器尺寸配置"),
            "ADSB_LIST_MAX": qsTr("ADSB-In 飞行器列表大小"),
            "ADSB_MAX_SPEED": qsTr("ADSB-Out 飞行器最大速度"),
            "ADSB_SQUAWK": qsTr("ADSB-Out 应答机代码配置"),

            "PWM_MAIN_REV": qsTr("反转 SIM 输出范围"),

            "ASPD_BETA_GATE": qsTr("侧滑角融合门限大小"),
            "ASPD_BETA_NOISE": qsTr("风速估计器侧滑测量噪声"),
            "ASPD_DO_CHECKS": qsTr("启用空速传感器检查"),
            "ASPD_FALLBACK": qsTr("备用选项"),
            "ASPD_FP_T_WINDOW": qsTr("第一原理空速检查时间窗口"),
            "ASPD_FS_INNOV": qsTr("空速故障创新阈值"),
            "ASPD_FS_INTEG": qsTr("空速故障创新积分阈值"),
            "ASPD_FS_T_START": qsTr("空速失控保护启动延迟"),
            "ASPD_FS_T_STOP": qsTr("空速失控保护停止延迟"),
            "ASPD_PRIMARY": qsTr("主空速测量源索引"),
            "ASPD_SCALE_APPLY": qsTr("控制何时应用新的空速缩放"),
            "ASPD_SCALE_NSD": qsTr("风速估计器真空速缩放过程噪声谱密度"),
            "ASPD_TAS_GATE": qsTr("真空速融合门限大小"),
            "ASPD_TAS_NOISE": qsTr("风速估计器真空速测量噪声"),
            "ASPD_WERR_THR": qsTr("有效地速减风速的水平风不确定性阈值"),
            "ASPD_WIND_NSD": qsTr("风速估计器风过程噪声谱密度"),

            "ATT_ACC_COMP": qsTr("基于 GPS 速度的加速度补偿"),
            "ATT_BIAS_MAX": qsTr("陀螺仪偏置限制"),
            "ATT_EN": qsTr("独立姿态估计器启用（不支持）"),
            "ATT_EXT_HDG_M": qsTr("外部航向使用模式（来自动作捕捉/视觉）"),
            "ATT_MAG_DECL": qsTr("磁偏角（度）"),
            "ATT_MAG_DECL_A": qsTr("基于 GPS 的自动磁偏角补偿"),
            "ATT_W_ACC": qsTr("互补滤波器加速度计权重"),
            "ATT_W_EXT_HDG": qsTr("互补滤波器外部航向权重"),
            "ATT_W_GYRO_BIAS": qsTr("互补滤波器陀螺仪偏置权重"),
            "ATT_W_MAG": qsTr("互补滤波器磁力计权重"),

            "FW_AT_APPLY": qsTr("控制何时应用新增益"),
            "FW_AT_AXES": qsTr("调参轴选择"),
            "FW_AT_MAN_AUX": qsTr("通过手动控制 AUX 输入启用/禁用自动调参"),
            "FW_AT_SYSID_F0": qsTr("注入信号起始频率"),
            "FW_AT_SYSID_F1": qsTr("注入信号结束频率"),
            "FW_AT_SYSID_TIME": qsTr("每个轴的机动时间"),
            "FW_AT_SYSID_TYPE": qsTr("输入信号类型"),
            "MC_AT_APPLY": qsTr("控制何时应用新增益"),
            "MC_AT_EN": qsTr("启用多旋翼自动调参模块"),
            "MC_AT_RISE_TIME": qsTr("期望角速率闭环上升时间"),
            "MC_AT_START": qsTr("启动自动调参流程"),
            "MC_AT_SYSID_AMP": qsTr("注入信号幅值"),

            "CA_R_REV": qsTr("双向/可反转电机"),
            "CA_SP0_COUNT": qsTr("斜盘舵机数量"),

            "LNDMC_TRIG_TIME": qsTr("多旋翼着陆检测触发时间"),
            "MPC_ACC_HOR": qsTr("自主和手动模式加速度"),
            "MPC_ACC_HOR_MAX": qsTr("最大水平加速度"),
            "MPC_ACC_UP_MAX": qsTr("爬升率控制模式最大上升加速度"),
            "MPC_ALT_MODE": qsTr("高度参考模式"),
            "MPC_HOLD_DZ": qsTr("手动驾驶模式下摇杆死区"),
            "MPC_YAW_EXPO": qsTr("手动控制摇杆偏航旋转 Expo 曲线系数"),
            "MPC_Z_MAN_EXPO": qsTr("手动控制摇杆垂直 Expo 曲线系数"),
            "UAVCAN_ENABLE": qsTr("UAVCAN 模式"),
            "TEL_BST_EN": qsTr("启用 BlackSheep 遥测"),
            }
        }

        const translatedDescription = _parameterDescriptionTranslations[fact.name]
        if (translatedDescription) {
            return _cacheParameterDescription(fact.name, translatedDescription)
        }

        const rcCalibrationMatch = fact.name.match(/^RC(\d+)_(DZ|MAX|MIN|REV|TRIM)$/)
        if (rcCalibrationMatch) {
            const channel = rcCalibrationMatch[1]
            const fields = {
                "DZ": qsTr("死区"),
                "MAX": qsTr("最大值"),
                "MIN": qsTr("最小值"),
                "REV": qsTr("反向"),
                "TRIM": qsTr("中位值"),
            }
            return _cacheParameterDescription(fact.name, qsTr("RC 通道 %1 %2").arg(channel).arg(fields[rcCalibrationMatch[2]]))
        }

        const rcAuxMatch = fact.name.match(/^RC_MAP_AUX(\d+)$/)
        if (rcAuxMatch) {
            return _cacheParameterDescription(fact.name, qsTr("AUX%1 透传 RC 通道").arg(rcAuxMatch[1]))
        }

        const rcParamMatch = fact.name.match(/^RC_MAP_PARAM(\d+)$/)
        if (rcParamMatch) {
            return _cacheParameterDescription(fact.name, qsTr("PARAM%1 调参通道").arg(rcParamMatch[1]))
        }

        const pwmOutputMatch = fact.name.match(/^PWM_(AUX|MAIN)_(DIS|FAIL|FUNC)(\d+)$/)
        if (pwmOutputMatch) {
            const busName = pwmOutputMatch[1] === "AUX" ? qsTr("PWM AUX") : qsTr("PWM MAIN")
            const fieldNames = {
                "DIS": qsTr("通道 %1 未解锁输出值"),
                "FAIL": qsTr("通道 %1 故障保护输出值"),
                "FUNC": qsTr("通道 %1 输出功能"),
            }
            return _cacheParameterDescription(fact.name, qsTr("%1 %2").arg(busName).arg(fieldNames[pwmOutputMatch[2]].arg(pwmOutputMatch[3])))
        }

        const simPwmOutputMatch = fact.name.match(/^PWM_MAIN_FUNC(\d+)$/)
        if (simPwmOutputMatch) {
            return _cacheParameterDescription(fact.name, qsTr("SIM 通道 %1 输出功能").arg(simPwmOutputMatch[1]))
        }

        const airspeedScaleMatch = fact.name.match(/^ASPD_SCALE_(\d+)$/)
        if (airspeedScaleMatch) {
            return _cacheParameterDescription(fact.name, qsTr("空速传感器 %1 缩放").arg(airspeedScaleMatch[1]))
        }

        const swashPlateMatch = fact.name.match(/^CA_SP0_(ANG|ARM_L)(\d+)$/)
        if (swashPlateMatch) {
            const fieldName = swashPlateMatch[1] === "ANG" ? qsTr("角度") : qsTr("力臂长度")
            return _cacheParameterDescription(fact.name, qsTr("斜盘舵机 %1 %2").arg(swashPlateMatch[2]).arg(fieldName))
        }

        const sensorCalibrationMatch = fact.name.match(/^CAL_(ACC|GYRO|BARO|MAG)(\d+)_(.+)$/)
        if (sensorCalibrationMatch) {
            const sensorIndex = sensorCalibrationMatch[2]
            const sensorNames = {
                "ACC": qsTr("加速度计"),
                "GYRO": qsTr("陀螺仪"),
                "BARO": qsTr("气压计"),
                "MAG": qsTr("磁力计"),
            }
            const calibrationFields = {
                "ID": qsTr("校准设备 ID"),
                "PRIO": qsTr("优先级"),
                "ROT": qsTr("相对机架旋转"),
                "OFF": qsTr("偏移"),
                "PITCH": qsTr("自定义欧拉俯仰角"),
                "ROLL": qsTr("自定义欧拉横滚角"),
                "YAW": qsTr("自定义欧拉偏航角"),
                "XCOMP": qsTr("X 轴油门补偿"),
                "YCOMP": qsTr("Y 轴油门补偿"),
                "ZCOMP": qsTr("Z 轴油门补偿"),
                "XODIAG": qsTr("X 轴非对角缩放系数"),
                "YODIAG": qsTr("Y 轴非对角缩放系数"),
                "ZODIAG": qsTr("Z 轴非对角缩放系数"),
                "XOFF": qsTr("X 轴偏移"),
                "YOFF": qsTr("Y 轴偏移"),
                "ZOFF": qsTr("Z 轴偏移"),
                "XSCALE": qsTr("X 轴缩放系数"),
                "YSCALE": qsTr("Y 轴缩放系数"),
                "ZSCALE": qsTr("Z 轴缩放系数"),
            }
            const sensorName = sensorNames[sensorCalibrationMatch[1]]
            const fieldName = calibrationFields[sensorCalibrationMatch[3]]
            if (sensorName && fieldName) {
                return _cacheParameterDescription(fact.name, qsTr("%1 %2 %3").arg(sensorName).arg(sensorIndex).arg(fieldName))
            }
        }

        const thermalCompensationMatch = fact.name.match(/^TC_([ABGM])(\d+)_(ID|TMAX|TMIN|TREF)$/)
        if (thermalCompensationMatch) {
            const sensorNames = {
                "A": qsTr("加速度计"),
                "B": qsTr("气压计"),
                "G": qsTr("陀螺仪"),
                "M": qsTr("磁力计"),
            }
            const thermalFields = {
                "ID": qsTr("校准对应的设备 ID"),
                "TMAX": qsTr("校准最高温度"),
                "TMIN": qsTr("校准最低温度"),
                "TREF": qsTr("校准参考温度"),
            }
            return _cacheParameterDescription(fact.name, qsTr("%1 %2 %3").arg(sensorNames[thermalCompensationMatch[1]]).arg(thermalCompensationMatch[2]).arg(thermalFields[thermalCompensationMatch[3]]))
        }

        const thermalPolynomialMatch = fact.name.match(/^TC_([AGM])(\d+)_X(\d)_(\d)$/)
        if (thermalPolynomialMatch) {
            const sensorNames = {
                "A": qsTr("加速度计"),
                "G": qsTr("陀螺仪角速率"),
                "M": qsTr("磁力计"),
            }
            const axisNames = {
                "0": qsTr("X 轴"),
                "1": qsTr("Y 轴"),
                "2": qsTr("Z 轴"),
            }
            return _cacheParameterDescription(fact.name, qsTr("%1 %2 偏移温度 %3 阶多项式系数 - %4").arg(sensorNames[thermalPolynomialMatch[1]]).arg(thermalPolynomialMatch[2]).arg(thermalPolynomialMatch[3]).arg(axisNames[thermalPolynomialMatch[4]]))
        }

        const baroThermalPolynomialMatch = fact.name.match(/^TC_B(\d+)_X(\d)$/)
        if (baroThermalPolynomialMatch) {
            return _cacheParameterDescription(fact.name, qsTr("气压计 %1 偏移温度 %2 阶多项式系数").arg(baroThermalPolynomialMatch[1]).arg(baroThermalPolynomialMatch[2]))
        }

        const rotorMatch = fact.name.match(/^CA_ROTOR(\d+)_(AX|AY|AZ|CT|KM|PX|PY|PZ|TILT)$/)
        if (rotorMatch) {
            const rotorIndex = rotorMatch[1]
            const rotorFields = {
                "AX": qsTr("推力矢量 X 轴分量"),
                "AY": qsTr("推力矢量 Y 轴分量"),
                "AZ": qsTr("推力矢量 Z 轴分量"),
                "CT": qsTr("推力系数"),
                "KM": qsTr("力矩系数"),
                "PX": qsTr("相对重心的 X 轴位置"),
                "PY": qsTr("相对重心的 Y 轴位置"),
                "PZ": qsTr("相对重心的 Z 轴位置"),
                "TILT": qsTr("倾转分配"),
            }
            return _cacheParameterDescription(fact.name, qsTr("旋翼 %1 %2").arg(rotorIndex).arg(rotorFields[rotorMatch[2]]))
        }

        const servoSlewMatch = fact.name.match(/^CA_SV(\d+)_SLEW$/)
        if (servoSlewMatch) {
            return _cacheParameterDescription(fact.name, qsTr("舵机 %1 变化率限制").arg(servoSlewMatch[1]))
        }

        const controlSurfaceMatch = fact.name.match(/^CA_SV_CS(\d+)_(FLAP|SPOIL|TRIM|TRQ_P|TRQ_R|TRQ_Y|TYPE)$/)
        if (controlSurfaceMatch) {
            const surfaceIndex = controlSurfaceMatch[1]
            const surfaceFields = {
                "FLAP": qsTr("襟翼缩放"),
                "SPOIL": qsTr("扰流板缩放"),
                "TRIM": qsTr("配平"),
                "TRQ_P": qsTr("俯仰力矩缩放"),
                "TRQ_R": qsTr("横滚力矩缩放"),
                "TRQ_Y": qsTr("偏航力矩缩放"),
                "TYPE": qsTr("类型"),
            }
            return _cacheParameterDescription(fact.name, qsTr("舵面 %1 %2").arg(surfaceIndex).arg(surfaceFields[controlSurfaceMatch[2]]))
        }

        const tiltMatch = fact.name.match(/^CA_SV_TL(\d+)_(CT|MAXA|MINA|TD)$/)
        if (tiltMatch) {
            const tiltIndex = tiltMatch[1]
            let tiltField = ""
            if (tiltMatch[2] === "CT") {
                tiltField = qsTr("控制类型")
            } else if (tiltMatch[2] === "MAXA") {
                tiltField = qsTr("最大倾转角")
            } else if (tiltMatch[2] === "MINA") {
                tiltField = qsTr("最小倾转角")
            } else if (tiltMatch[2] === "TD") {
                tiltField = qsTr("倾转方向")
            }
            return _cacheParameterDescription(fact.name, qsTr("倾转舵机 %1 %2").arg(tiltIndex).arg(tiltField))
        }

        const mavlinkInstanceMatch = fact.name.match(/^MAV_(\d+)_(BROADCAST|FLOW_CTRL|FORWARD|HL_FREQ|MODE|RADIO_CTL|RATE|REMOTE_PRT|UDP_PRT)$/)
        if (mavlinkInstanceMatch) {
            const instanceIndex = mavlinkInstanceMatch[1]
            const mavlinkFields = {
                "BROADCAST": qsTr("在本地网络广播心跳"),
                "FLOW_CTRL": qsTr("启用串口流控"),
                "FORWARD": qsTr("启用 MAVLink 消息转发"),
                "HL_FREQ": qsTr("HIGH_LATENCY2 数据流频率"),
                "MODE": qsTr("MAVLink 模式"),
                "RADIO_CTL": qsTr("启用 MAVLink 软件限速"),
                "RATE": qsTr("最大 MAVLink 发送速率"),
                "REMOTE_PRT": qsTr("MAVLink 远程端口"),
                "UDP_PRT": qsTr("MAVLink 网络端口"),
            }
            return _cacheParameterDescription(fact.name, qsTr("MAVLink 实例 %1 %2").arg(instanceIndex).arg(mavlinkFields[mavlinkInstanceMatch[2]]))
        }

        const templateDescription = _displayParameterDescriptionFromTemplate(description)
        if (templateDescription !== "") {
            return _cacheParameterDescription(fact.name, templateDescription)
        }

        return _cacheParameterDescription(fact.name, description)
    }

    ParameterEditorController {
        id: controller
    }

    Rectangle {
        anchors.fill: parent
        color: popupStyle.popupBackground
    }

    Rectangle {
        id: editorCard
        anchors.centerIn: parent
        width: _cardWidth
        height: _cardHeight
        color: popupStyle.panelBackground
        border.width: 1
        border.color: popupStyle.borderColor
        radius: popupStyle.cornerRadius
    }

    Rectangle {
        id: groupPanel
        anchors.left: editorCard.left
        anchors.leftMargin: _pageInnerMargin
        anchors.top: tabBar.bottom
        anchors.topMargin: _panelSpacing
        anchors.bottom: editorCard.bottom
        anchors.bottomMargin: _pageInnerMargin
        width: _groupPanelWidth
        visible: !_searchFilter
        color: popupStyle.panelBackground
        border.width: 1
        border.color: popupStyle.borderColor
        radius: popupStyle.cornerRadius
    }

    Rectangle {
        id: tablePanel
        anchors.left: _searchFilter ? editorCard.left : groupPanel.right
        anchors.leftMargin: _searchFilter ? _pageInnerMargin : _panelSpacing
        anchors.top: tabBar.bottom
        anchors.topMargin: _panelSpacing
        anchors.right: editorCard.right
        anchors.rightMargin: _pageInnerMargin
        anchors.bottom: editorCard.bottom
        anchors.bottomMargin: _pageInnerMargin
        color: popupStyle.panelBackground
        border.width: 1
        border.color: popupStyle.borderColor
        radius: popupStyle.cornerRadius
    }

    Timer {
        id:         clearTimer
        interval:   100;
        running:    false;
        repeat:     false
        onTriggered: {
            searchText.text = ""
            controller.searchText = ""
        }
    }

    QGCMenu {
        id:                 toolsMenu
        width:              _toolsMenuWidth

        QGCMenuItem {
            text:           qsTr("刷新")
            onTriggered:	controller.refresh()
        }
        QGCMenuItem {
            text:           qsTr("重置为固件默认值")
            onTriggered:    QGroundControl.showMessageDialog(_root, qsTr("全部重置"),
                                                         qsTr("选择重置会将所有参数恢复为默认值。\n\n注意：这也会完全重置所有内容，包括 UAVCAN 节点、全部飞行器设置、配置和校准。"),
                                                         Dialog.Cancel | Dialog.Reset,
                                                         function() { controller.resetAllToDefaults() })
        }
        QGCMenuItem {
            text:           qsTr("重置为飞行器配置默认值")
            visible:        !_activeVehicle.apmFirmware
            onTriggered:    QGroundControl.showMessageDialog(_root, qsTr("全部重置"),
                                                         qsTr("选择重置会将所有参数恢复为飞行器配置默认值。"),
                                                         Dialog.Cancel | Dialog.Reset,
                                                         function() { controller.resetAllToVehicleConfiguration() })
        }
        QGCMenuSeparator { }
        QGCMenuItem {
            text:           qsTr("从文件加载并查看...")
            onTriggered: {
                fileDialog.title =          qsTr("加载参数")
                fileDialog.openForLoad()
            }
        }
        QGCMenuItem {
            text:           qsTr("保存到文件...")
            onTriggered: {
                fileDialog.title =          qsTr("保存参数")
                fileDialog.openForSave()
            }
        }
        QGCMenuSeparator { }
        QGCMenuItem {
            text:           qsTr("清除所有收藏")
            onTriggered:    controller.clearAllFavorites()
        }
        QGCMenuSeparator { visible: _showRCToParam }
        QGCMenuItem {
            text:           qsTr("清除所有 RC 到参数映射")
            onTriggered:	_activeVehicle.clearAllParamMapRC()
            visible:        _showRCToParam
        }
        QGCMenuSeparator { }
        QGCMenuItem {
            text:           qsTr("重启飞行器")
            onTriggered:    QGroundControl.showMessageDialog(_root, qsTr("重启飞行器"),
                                                         qsTr("选择确定以重启飞行器。"),
                                                         Dialog.Cancel | Dialog.Ok,
                                                         function() { _activeVehicle.rebootVehicle() })
        }
    }


    QGCFileDialog {
        id:             fileDialog
        folder:         _appSettings.parameterSavePath
        nameFilters:    [ qsTr("参数文件 (*.%1)").arg(_appSettings.parameterFileExtension) , qsTr("所有文件 (*)") ]

        onAcceptedForSave: (file) => {
            controller.saveToFile(file)
            close()
        }

        onAcceptedForLoad: (file) => {
            close()
            if (controller.buildDiffFromFile(file)) {
                parameterDiffDialogFactory.open()
            }
        }
    }

    QGCPopupDialogFactory {
        id: editorDialogFactory

        dialogComponent: editorDialogComponent
    }

    Component {
        id: editorDialogComponent

        ParameterEditorDialog {
            fact:           _editorDialogFact
            showRCToParam:  _showRCToParam
        }
    }

    QGCPopupDialogFactory {
        id: parameterDiffDialogFactory

        dialogComponent: parameterDiffDialog
    }

    Component {
        id: parameterDiffDialog

        ParameterDiffDialog {
            paramController: _controller
        }
    }

    RowLayout {
        id:             header
        anchors.left:   editorCard.left
        anchors.leftMargin: _pageInnerMargin
        anchors.right:  editorCard.right
        anchors.rightMargin: _pageInnerMargin
        anchors.top:    editorCard.top
        anchors.topMargin: _pageInnerMargin
        spacing:        _panelSpacing

        RowLayout {
            Layout.alignment:   Qt.AlignLeft
            Layout.fillWidth:   true
            spacing:            ScreenTools.defaultFontPixelWidth

            QGCTextField {
                id:                     searchText
                Layout.preferredWidth:  Math.min(editorCard.width * 0.42, ScreenTools.defaultFontPixelWidth * 30)
                placeholderText:        qsTr("搜索")
                onDisplayTextChanged:   controller.searchText = displayText
            }

            QGCButton {
                text: qsTr("清除")
                onClicked: {
                    if(ScreenTools.isMobile) {
                        Qt.inputMethod.hide();
                    }
                    clearTimer.start()
                }
            }
        }

        QGCButton {
            id:                 toolsButton
            Layout.alignment:   Qt.AlignRight
            text:               qsTr("工具")
            onClicked:          _root._openToolsMenu()
        }
    }

    QGCTabBar {
        id:             tabBar
        anchors.left:   editorCard.left
        anchors.leftMargin: _pageInnerMargin
        anchors.right:  editorCard.right
        anchors.rightMargin: _pageInnerMargin
        anchors.top:        header.bottom
        anchors.topMargin:  _panelSpacing

        QGCTabButton {
            text:                   qsTr("完整列表")
            showBorder:             true
            backRadius:             popupStyle.cornerRadius
            buttonColor:            popupStyle.secondaryButtonColor
            checkedButtonColor:     popupStyle.accentColor
            hoverButtonColor:       popupStyle.secondaryButtonHoverColor()
            buttonBorderColor:      popupStyle.borderColor
            buttonTextColor:        popupStyle.secondaryTextColor
            checkedButtonTextColor: popupStyle.primaryTextColor
        }
        QGCTabButton {
            text:                   qsTr("已修改")
            showBorder:             true
            backRadius:             popupStyle.cornerRadius
            buttonColor:            popupStyle.secondaryButtonColor
            checkedButtonColor:     popupStyle.accentColor
            hoverButtonColor:       popupStyle.secondaryButtonHoverColor()
            buttonBorderColor:      popupStyle.borderColor
            buttonTextColor:        popupStyle.secondaryTextColor
            checkedButtonTextColor: popupStyle.primaryTextColor
        }
        QGCTabButton {
            text:                   qsTr("收藏")
            showBorder:             true
            backRadius:             popupStyle.cornerRadius
            buttonColor:            popupStyle.secondaryButtonColor
            checkedButtonColor:     popupStyle.accentColor
            hoverButtonColor:       popupStyle.secondaryButtonHoverColor()
            buttonBorderColor:      popupStyle.borderColor
            buttonTextColor:        popupStyle.secondaryTextColor
            checkedButtonTextColor: popupStyle.primaryTextColor
        }

        onCurrentIndexChanged: {
            controller.showModifiedOnly  = (currentIndex === 1)
            controller.showFavoritesOnly = (currentIndex === 2)
        }
    }

    /// Group buttons
    QGCFlickable {
        id :                groupScroll
        anchors.fill:       groupPanel
        anchors.margins:    _panelInnerMargin
        width:              parent ? Math.max(0, parent.width - (_panelInnerMargin * 2)) : 0
        clip:               true
        pixelAligned:       true
        contentHeight:      groupedViewCategoryColumn.height
        flickableDirection: Flickable.VerticalFlick
        visible:            !_searchFilter

        ColumnLayout {
            id:             groupedViewCategoryColumn
            anchors.left:   parent.left
            anchors.right:  parent.right
            spacing:        Math.ceil(ScreenTools.defaultFontPixelHeight * 0.25)

            Repeater {
                model: controller.categories

                Column {
                    Layout.fillWidth:   true
                    spacing:            Math.ceil(ScreenTools.defaultFontPixelHeight * 0.25)


                    SectionHeader {
                        id:             categoryHeader
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        text:           _root._displayParameterGroupName(object.name)
                        color:          popupStyle.primaryTextColor
                        checked:        object == controller.currentCategory

                        onCheckedChanged: {
                            if (checked) {
                                controller.currentCategory  = object
                            }
                        }
                    }

                    Repeater {
                        model: categoryHeader.checked ? object.groups : 0

                        QGCButton {
                            width:          groupedViewCategoryColumn.width
                            text:           _root._displayParameterGroupName(object.name)
                            height:         _rowHeight
                            checked:        object == controller.currentGroup
                            autoExclusive:  true
                            fontWeight:     checked ? Font.DemiBold : Font.Normal
                            textColor:      checked ? popupStyle.primaryTextColor : popupStyle.secondaryTextColor

                            onClicked: {
                                if (!checked) _rowWidth = 10
                                checked = true
                                controller.currentGroup = object
                            }
                        }
                    }
                }
            }
        }
    }

    HorizontalHeaderView {
        id:                 headerView
        anchors.left:       tableView.left
        anchors.right:      tableView.right
        anchors.top:        tablePanel.top
        anchors.topMargin:  _panelInnerMargin
        syncView:           tableView
        clip:               true

        delegate: Rectangle {
            implicitWidth:  tableView.columnWidthProvider(column)
            implicitHeight: headerLabel.contentHeight + ScreenTools.defaultFontPixelHeight * 0.5
            color:          popupStyle.inputBackground

            QGCLabel {
                id:                     headerLabel
                anchors.left:           parent.left
                anchors.leftMargin:     ScreenTools.defaultFontPixelWidth / 2
                anchors.verticalCenter: parent.verticalCenter
                text:                   _root._displayParameterHeader(display)
                font.bold:              true
                color:                  popupStyle.secondaryTextColor
            }

            // Top border
            Rectangle {
                anchors.top:    parent.top
                width:          parent.width
                height:         1
                color:          popupStyle.borderColor
            }

            // Left border
            Rectangle {
                anchors.left:   parent.left
                height:         parent.height
                width:          1
                color:          popupStyle.borderColor
            }

            // Right border (last column only)
            Rectangle {
                anchors.right:  parent.right
                height:         parent.height
                width:          1
                color:          popupStyle.borderColor
                visible:        column == 3
            }

            // Bottom border
            Rectangle {
                anchors.bottom: parent.bottom
                width:          parent.width
                height:         1
                color:          popupStyle.borderColor
            }
        }
    }

    TableView {
        id:                 tableView
        anchors.leftMargin: _panelInnerMargin
        anchors.top:        headerView.bottom
        anchors.bottom:     tablePanel.bottom
        anchors.bottomMargin: _panelInnerMargin
        anchors.left:       tablePanel.left
        anchors.right:      tablePanel.right
        anchors.rightMargin: _panelInnerMargin
        columnSpacing:      0
        rowSpacing:         0
        model:              controller.parameters
        contentWidth:       width
        clip:               true
        columnWidthProvider: function(column) {
            if (column === 0) {
                return _favoriteColumnWidth
            }
            if (column === 1) {
                return Math.min(_nameColumnWidth, Math.max(ScreenTools.defaultFontPixelWidth * 17, tableView.width * 0.30))
            }
            if (column === 2) {
                return Math.min(_valueColumnWidth, Math.max(ScreenTools.defaultFontPixelWidth * 12, tableView.width * 0.22))
            }
            return Math.max(ScreenTools.defaultFontPixelWidth * 20, tableView.width - tableView.columnWidthProvider(0) - tableView.columnWidthProvider(1) - tableView.columnWidthProvider(2))
        }

        onModelChanged: {
            positionViewAtRow(0, TableView.AlignLeft | TableView.AlignTop)
            forceLayout()
        }
        onWidthChanged: forceLayout()

        delegate: Rectangle {
            implicitWidth:  tableView.columnWidthProvider(column)
            implicitHeight: label.contentHeight + ScreenTools.defaultFontPixelHeight * 0.5
            color:          row % 2 === 0 ? popupStyle.panelBackground : popupStyle.inputBackground
            clip:           true

            // Bottom grid line
            Rectangle {
                anchors.bottom: parent.bottom
                width:          parent.width
                height:         1
                color:          popupStyle.borderColor
            }

            // Left grid line
            Rectangle {
                anchors.left:   parent.left
                height:         parent.height
                width:          1
                color:          popupStyle.borderColor
            }

            // Right grid line (last column only)
            Rectangle {
                anchors.right:  parent.right
                height:         parent.height
                width:          1
                color:          popupStyle.borderColor
                visible:        column == 3
            }

            QGCCheckBox {
                visible:                column === 0
                anchors.centerIn:       parent
                checked:                _root._favorites.indexOf(fact.name) >= 0
                z:                      1
                onClicked:              controller.toggleFavorite(fact.name)
            }

            QGCLabel {
                id:                 label
                visible:            column !== 0
                anchors.left:       parent.left
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth / 2
                anchors.right:      parent.right
                anchors.rightMargin: ScreenTools.defaultFontPixelWidth / 2
                anchors.verticalCenter: parent.verticalCenter
                text:               column == 2 ? col1String() : (column == 3 ? _root._displayParameterDescription(fact, display) : display)
                color:              column == 2 && fact.defaultValueAvailable && !fact.valueEqualsDefault
                                        ? qgcPal.modifiedParamValue
                                        : (column === 1 ? popupStyle.primaryTextColor : popupStyle.secondaryTextColor)
                font.bold:          column == 2 && fact.defaultValueAvailable && !fact.valueEqualsDefault
                maximumLineCount:   1
                elide:              Text.ElideRight

                function col1String() {
                    if (fact.enumStrings.length === 0) {
                        return fact.valueString + " " + fact.units
                    }
                    if (fact.bitmaskStrings.length != 0) {
                        return _root._displayParameterValueText(fact.selectedBitmaskStrings.join(','))
                    }
                    return _root._displayParameterValueText(fact.enumStringValue)
                }
            }

            QGCMouseArea {
                anchors.fill: parent
                visible:      column !== 0
                onClicked: mouse => {
                    _editorDialogFact = fact
                    editorDialogFactory.open()
                }
            }
        }
    }
}
