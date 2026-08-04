#include "SensorsComponentController.h"
#include "QGCApplication.h"
#include "ParameterManager.h"
#include "Vehicle.h"
#include "QGCLoggingCategory.h"
#include "MAVLink/LibEvents/libevents_includes.h"

QGC_LOGGING_CATEGORY(SensorsComponentControllerLog, "AutoPilotPlugins.SensorsComponentController")

SensorsComponentController::SensorsComponentController(void)
    : _statusLog                                (nullptr)
    , _progressBar                              (nullptr)
    , _showOrientationCalArea                   (false)
    , _gyroCalInProgress                        (false)
    , _magCalInProgress                         (false)
    , _accelCalInProgress                       (false)
    , _airspeedCalInProgress                    (false)
    , _levelCalInProgress                       (false)
    , _orientationCalDownSideDone               (false)
    , _orientationCalUpsideDownSideDone         (false)
    , _orientationCalLeftSideDone               (false)
    , _orientationCalRightSideDone              (false)
    , _orientationCalNoseDownSideDone           (false)
    , _orientationCalTailDownSideDone           (false)
    , _orientationCalDownSideVisible            (false)
    , _orientationCalUpsideDownSideVisible      (false)
    , _orientationCalLeftSideVisible            (false)
    , _orientationCalRightSideVisible           (false)
    , _orientationCalNoseDownSideVisible        (false)
    , _orientationCalTailDownSideVisible        (false)
    , _orientationCalDownSideInProgress         (false)
    , _orientationCalUpsideDownSideInProgress   (false)
    , _orientationCalLeftSideInProgress         (false)
    , _orientationCalRightSideInProgress        (false)
    , _orientationCalNoseDownSideInProgress     (false)
    , _orientationCalTailDownSideInProgress     (false)
    , _orientationCalDownSideRotate             (false)
    , _orientationCalUpsideDownSideRotate       (false)
    , _orientationCalLeftSideRotate             (false)
    , _orientationCalRightSideRotate            (false)
    , _orientationCalNoseDownSideRotate         (false)
    , _orientationCalTailDownSideRotate         (false)
    , _unknownFirmwareVersion                   (false)
    , _waitingForCancel                         (false)
{
    connect(_vehicle, &Vehicle::sensorsParametersResetAck, this, &SensorsComponentController::_handleParametersReset);

}

bool SensorsComponentController::usingUDPLink(void)
{
    SharedLinkInterfacePtr sharedLink = _vehicle->vehicleLinkManager()->primaryLink().lock();
    if (sharedLink) {
        return sharedLink->linkConfiguration()->type() == LinkConfiguration::TypeUdp;
    } else {
        return false;
    }
}

/// Appends the specified text to the status log area in the ui
void SensorsComponentController::_appendStatusLog(const QString& text)
{
    if (!_statusLog) {
        qWarning() << "Internal error";
        return;
    }

    QString varText = text;
    QMetaObject::invokeMethod(_statusLog,
                              "append",
                              Q_ARG(QString, varText));
}

void SensorsComponentController::_startLogCalibration(void)
{
    _unknownFirmwareVersion = false;
    _hideAllCalAreas();

    connect(_vehicle, &Vehicle::textMessageReceived, this, &SensorsComponentController::_handleUASTextMessage);
    connect(_vehicle, &Vehicle::calibrationEventReceived, this, &SensorsComponentController::_handleCalibrationEvent);
}

void SensorsComponentController::_startVisualCalibration(void)
{
    _resetInternalState();

    _progressBar->setProperty("value", 0);
}

void SensorsComponentController::_resetInternalState(void)
{
    _orientationCalDownSideDone = true;
    _orientationCalUpsideDownSideDone = true;
    _orientationCalLeftSideDone = true;
    _orientationCalRightSideDone = true;
    _orientationCalTailDownSideDone = true;
    _orientationCalNoseDownSideDone = true;
    _orientationCalDownSideInProgress = false;
    _orientationCalUpsideDownSideInProgress = false;
    _orientationCalLeftSideInProgress = false;
    _orientationCalRightSideInProgress = false;
    _orientationCalNoseDownSideInProgress = false;
    _orientationCalTailDownSideInProgress = false;
    _orientationCalDownSideRotate = false;
    _orientationCalUpsideDownSideRotate = false;
    _orientationCalLeftSideRotate = false;
    _orientationCalRightSideRotate = false;
    _orientationCalNoseDownSideRotate = false;
    _orientationCalTailDownSideRotate = false;

    emit orientationCalSidesRotateChanged();
    emit orientationCalSidesDoneChanged();
    emit orientationCalSidesInProgressChanged();
}

void SensorsComponentController::_stopCalibration(SensorsComponentController::StopCalibrationCode code)
{
    disconnect(_vehicle, &Vehicle::textMessageReceived, this, &SensorsComponentController::_handleUASTextMessage);
    disconnect(_vehicle, &Vehicle::calibrationEventReceived, this, &SensorsComponentController::_handleCalibrationEvent);

    if (code == StopCalibrationSuccess) {
        _resetInternalState();

        _progressBar->setProperty("value", 1);
    } else {
        _progressBar->setProperty("value", 0);
    }

    _waitingForCancel = false;
    emit waitingForCancelChanged();

    _refreshParams();

    switch (code) {
        case StopCalibrationSuccess:
            _orientationCalAreaHelpText->setProperty("text", tr("校准完成"));
            if (!_airspeedCalInProgress && !_levelCalInProgress) {
                _appendStatusLog(tr("校准完成"));
            }
            if (_magCalInProgress) {
                emit magCalComplete();
            }
            break;

        case StopCalibrationCancelled:
            emit resetStatusTextArea();
            _hideAllCalAreas();
            break;

        default:
            // Assume failed
            _hideAllCalAreas();
            qgcApp()->showAppMessage(tr("校准失败。将显示校准日志。"));
            break;
    }

    _magCalInProgress = false;
    _accelCalInProgress = false;
    _gyroCalInProgress = false;
    _airspeedCalInProgress = false;
    _levelCalInProgress = false;

    emit calibrationActiveChanged();
}

void SensorsComponentController::_updateAccelSidesFromRemaining(uint64_t remainingSides)
{
    _orientationCalDownSideVisible = true;
    _orientationCalUpsideDownSideVisible = true;
    _orientationCalLeftSideVisible = true;
    _orientationCalRightSideVisible = true;
    _orientationCalTailDownSideVisible = true;
    _orientationCalNoseDownSideVisible = true;

    _orientationCalTailDownSideDone = !(remainingSides & 1);
    _orientationCalNoseDownSideDone = !(remainingSides & 2);
    _orientationCalLeftSideDone = !(remainingSides & 4);
    _orientationCalRightSideDone = !(remainingSides & 8);
    _orientationCalUpsideDownSideDone = !(remainingSides & 16);
    _orientationCalDownSideDone = !(remainingSides & 32);

    if (_orientationCalDownSideDone) {
        _orientationCalDownSideInProgress = false;
    }
    if (_orientationCalUpsideDownSideDone) {
        _orientationCalUpsideDownSideInProgress = false;
    }
    if (_orientationCalLeftSideDone) {
        _orientationCalLeftSideInProgress = false;
    }
    if (_orientationCalRightSideDone) {
        _orientationCalRightSideInProgress = false;
    }
    if (_orientationCalNoseDownSideDone) {
        _orientationCalNoseDownSideInProgress = false;
    }
    if (_orientationCalTailDownSideDone) {
        _orientationCalTailDownSideInProgress = false;
    }

    emit orientationCalSidesVisibleChanged();
    emit orientationCalSidesDoneChanged();
    emit orientationCalSidesInProgressChanged();
}

void SensorsComponentController::_handleCalibrationEvent(int uasId, int compId, int severity, QSharedPointer<events::parser::ParsedEvent> event)
{
    if (uasId != _vehicle->id() || !event) {
        return;
    }

    const QString eventType = QString::fromStdString(event->type());
    const auto sideName = [](uint64_t side) {
        switch (side) {
        case 1:  return QStringLiteral("back");
        case 2:  return QStringLiteral("front");
        case 4:  return QStringLiteral("left");
        case 8:  return QStringLiteral("right");
        case 16: return QStringLiteral("up");
        case 32: return QStringLiteral("down");
        default: return QString();
        }
    };
    const auto calTypeName = [](uint64_t calType) {
        if (calType & 1) {
            return QStringLiteral("accel");
        } else if (calType & 2) {
            return QStringLiteral("mag");
        } else if (calType & 4) {
            return QStringLiteral("gyro");
        } else if (calType & 8) {
            return QStringLiteral("level");
        } else if (calType & 16) {
            return QStringLiteral("airspeed");
        }
        return QString();
    };

    if (eventType == QStringLiteral("cal_progress") && event->numArguments() >= 3) {
        const QString calType = calTypeName(event->argumentValueInt(2));
        if (!calType.isEmpty() && !calibrationActive()) {
            _handleUASTextMessage(uasId, compId, severity, QStringLiteral("[cal] calibration started: 2 %1").arg(calType), QString());
        }
        if (calType == QStringLiteral("accel") && event->numArguments() >= 4) {
            _updateAccelSidesFromRemaining(event->argumentValueInt(3));
        }
        _handleUASTextMessage(uasId, compId, severity, QStringLiteral("progress <%1>").arg(event->argumentValueInt(1)), QString());
    } else if (eventType == QStringLiteral("cal_orientation_detected") && event->numArguments() >= 1) {
        const QString side = sideName(event->argumentValueInt(0));
        if (!side.isEmpty()) {
            _handleUASTextMessage(uasId, compId, severity, QStringLiteral("[cal] %1 orientation detected").arg(side), QString());
        }
    } else if (eventType == QStringLiteral("cal_orientation_done") && event->numArguments() >= 1) {
        const QString side = sideName(event->argumentValueInt(0));
        if (!side.isEmpty()) {
            _handleUASTextMessage(uasId, compId, severity, QStringLiteral("[cal] %1 side done, rotate to a different side").arg(side), QString());
        }
    } else if (eventType == QStringLiteral("cal_done") && event->numArguments() >= 1) {
        const uint64_t result = event->argumentValueInt(0);
        if (result == 0) {
            _handleUASTextMessage(uasId, compId, severity, QStringLiteral("[cal] calibration done:"), QString());
        } else if (result == 2) {
            _handleUASTextMessage(uasId, compId, severity, QStringLiteral("[cal] calibration cancelled"), QString());
        } else {
            _handleUASTextMessage(uasId, compId, severity, QStringLiteral("[cal] calibration failed"), QString());
        }
    }
}

void SensorsComponentController::calibrateGyro(void)
{
    _startLogCalibration();
    _vehicle->startCalibration(QGCMAVLink::CalibrationGyro);
}

void SensorsComponentController::calibrateCompass(void)
{
    _startLogCalibration();
    _vehicle->startCalibration(QGCMAVLink::CalibrationMag);
}

void SensorsComponentController::calibrateAccel(void)
{
    _startLogCalibration();
    _vehicle->startCalibration(QGCMAVLink::CalibrationAccel);
}

void SensorsComponentController::calibrateLevel(void)
{
    _startLogCalibration();
    _vehicle->startCalibration(QGCMAVLink::CalibrationLevel);
}

void SensorsComponentController::calibrateAirspeed(void)
{
    _startLogCalibration();
    _vehicle->startCalibration(QGCMAVLink::CalibrationPX4Airspeed);
}

void SensorsComponentController::_handleUASTextMessage(int uasId, int compId, int severity, QString text, const QString &description)
{
    Q_UNUSED(compId);
    Q_UNUSED(severity);
    Q_UNUSED(description);

    if (uasId != _vehicle->id()) {
        return;
    }

    // Needed for level horizon calibration
    text.replace("&lt;", "<");
    text.replace("&gt;", ">");

    if (text.contains("progress <")) {
        QString percent = text.split("<").last().split(">").first();
        bool ok;
        int p = percent.toInt(&ok);
        if (ok) {
            if (_progressBar) {
                _progressBar->setProperty("value", (float)(p / 100.0));
            } else {
                qWarning() << "Internal error";
            }
        }
        return;
    }

    _appendStatusLog(text);
    qCDebug(SensorsComponentControllerLog) << text;

    if (_unknownFirmwareVersion) {
        // We don't know how to do visual cal with the version of firwmare
        return;
    }

    // All calibration messages start with [cal]
    QString calPrefix("[cal] ");
    if (!text.startsWith(calPrefix)) {
        return;
    }
    text = text.right(text.length() - calPrefix.length());

    QString calStartPrefix("calibration started: ");
    if (text.startsWith(calStartPrefix)) {
        text = text.right(text.length() - calStartPrefix.length());

        // Split version number and cal type
        QStringList parts = text.split(" ");
        if (parts.count() != 2 && parts[0].toInt() != _supportedFirmwareCalVersion) {
            _unknownFirmwareVersion = true;
            QString msg = tr("Unsupported calibration firmware version, using log");
            _appendStatusLog(msg);
            qDebug() << msg;
            return;
        }

        _startVisualCalibration();

        text = parts[1];
        if (text == "accel" || text == "mag" || text == "gyro") {
            // Reset all progress indication
            _orientationCalDownSideDone = false;
            _orientationCalUpsideDownSideDone = false;
            _orientationCalLeftSideDone = false;
            _orientationCalRightSideDone = false;
            _orientationCalTailDownSideDone = false;
            _orientationCalNoseDownSideDone = false;
            _orientationCalDownSideInProgress = false;
            _orientationCalUpsideDownSideInProgress = false;
            _orientationCalLeftSideInProgress = false;
            _orientationCalRightSideInProgress = false;
            _orientationCalNoseDownSideInProgress = false;
            _orientationCalTailDownSideInProgress = false;

            // Reset all visibility
            _orientationCalDownSideVisible = false;
            _orientationCalUpsideDownSideVisible = false;
            _orientationCalLeftSideVisible = false;
            _orientationCalRightSideVisible = false;
            _orientationCalTailDownSideVisible = false;
            _orientationCalNoseDownSideVisible = false;

            _orientationCalAreaHelpText->setProperty("text", tr("Place your vehicle into one of the Incomplete orientations shown below and hold it still"));

            if (text == "accel") {
                _accelCalInProgress = true;
                _orientationCalDownSideVisible = true;
                _orientationCalUpsideDownSideVisible = true;
                _orientationCalLeftSideVisible = true;
                _orientationCalRightSideVisible = true;
                _orientationCalTailDownSideVisible = true;
                _orientationCalNoseDownSideVisible = true;
            } else if (text == "mag") {

                // Work out what the autopilot is configured to
                int sides = 0;

                if (_vehicle->parameterManager()->parameterExists(ParameterManager::defaultComponentId, "CAL_MAG_SIDES")) {
                    // Read the requested calibration directions off the system
                    sides = _vehicle->parameterManager()->getParameter(ParameterManager::defaultComponentId, "CAL_MAG_SIDES")->rawValue().toFloat();
                } else {
                    // There is no valid setting, default to all six sides
                    sides = (1 << 5) | (1 << 4) | (1 << 3) | (1 << 2) | (1 << 1) | (1 << 0);
                }

                _magCalInProgress = true;
                _orientationCalTailDownSideVisible =   ((sides & (1 << 0)) > 0);
                _orientationCalNoseDownSideVisible =   ((sides & (1 << 1)) > 0);
                _orientationCalLeftSideVisible =       ((sides & (1 << 2)) > 0);
                _orientationCalRightSideVisible =      ((sides & (1 << 3)) > 0);
                _orientationCalUpsideDownSideVisible = ((sides & (1 << 4)) > 0);
                _orientationCalDownSideVisible =       ((sides & (1 << 5)) > 0);
            } else if (text == "gyro") {
                _gyroCalInProgress = true;
                _orientationCalDownSideVisible = true;
            } else {
                qWarning() << "Unknown calibration message type" << text;
            }
            emit orientationCalSidesDoneChanged();
            emit orientationCalSidesVisibleChanged();
            emit orientationCalSidesInProgressChanged();
            _updateAndEmitShowOrientationCalArea(true);
        } else if (text == "airspeed") {
            _airspeedCalInProgress = true;
        } else if (text == "level") {
            _levelCalInProgress = true;
        }
        emit calibrationActiveChanged();
        return;
    }

    if (text.endsWith("orientation detected")) {
        QString side = text.section(" ", 0, 0);
        qCDebug(SensorsComponentControllerLog) << "Side started" << side;

        if (side == "down") {
            _orientationCalDownSideInProgress = true;
            if (_magCalInProgress) {
                _orientationCalDownSideRotate = true;
            }
        } else if (side == "up") {
            _orientationCalUpsideDownSideInProgress = true;
            if (_magCalInProgress) {
                _orientationCalUpsideDownSideRotate = true;
            }
        } else if (side == "left") {
            _orientationCalLeftSideInProgress = true;
            if (_magCalInProgress) {
                _orientationCalLeftSideRotate = true;
            }
        } else if (side == "right") {
            _orientationCalRightSideInProgress = true;
            if (_magCalInProgress) {
                _orientationCalRightSideRotate = true;
            }
        } else if (side == "front") {
            _orientationCalNoseDownSideInProgress = true;
            if (_magCalInProgress) {
                _orientationCalNoseDownSideRotate = true;
            }
        } else if (side == "back") {
            _orientationCalTailDownSideInProgress = true;
            if (_magCalInProgress) {
                _orientationCalTailDownSideRotate = true;
            }
        }

        if (_magCalInProgress) {
            _orientationCalAreaHelpText->setProperty("text", tr("Rotate the vehicle continuously as shown in the diagram until marked as Completed"));
        } else {
            _orientationCalAreaHelpText->setProperty("text", tr("Hold still in the current orientation"));
        }

        emit orientationCalSidesInProgressChanged();
        emit orientationCalSidesRotateChanged();
        return;
    }

    if (text.endsWith("side done, rotate to a different side")) {
        QString side = text.section(" ", 0, 0);
        qCDebug(SensorsComponentControllerLog) << "Side finished" << side;

        if (side == "down") {
            _orientationCalDownSideInProgress = false;
            _orientationCalDownSideDone = true;
            _orientationCalDownSideRotate = false;
        } else if (side == "up") {
            _orientationCalUpsideDownSideInProgress = false;
            _orientationCalUpsideDownSideDone = true;
            _orientationCalUpsideDownSideRotate = false;
        } else if (side == "left") {
            _orientationCalLeftSideInProgress = false;
            _orientationCalLeftSideDone = true;
            _orientationCalLeftSideRotate = false;
        } else if (side == "right") {
            _orientationCalRightSideInProgress = false;
            _orientationCalRightSideDone = true;
            _orientationCalRightSideRotate = false;
        } else if (side == "front") {
            _orientationCalNoseDownSideInProgress = false;
            _orientationCalNoseDownSideDone = true;
            _orientationCalNoseDownSideRotate = false;
        } else if (side == "back") {
            _orientationCalTailDownSideInProgress = false;
            _orientationCalTailDownSideDone = true;
            _orientationCalTailDownSideRotate = false;
        }

        _orientationCalAreaHelpText->setProperty("text", tr("Place you vehicle into one of the orientations shown below and hold it still"));

        emit orientationCalSidesInProgressChanged();
        emit orientationCalSidesDoneChanged();
        emit orientationCalSidesRotateChanged();
        return;
    }

    if (text.endsWith("side already completed")) {
        _orientationCalAreaHelpText->setProperty("text", tr("Orientation already completed, place you vehicle into one of the incomplete orientations shown below and hold it still"));
        return;
    }

    QString calCompletePrefix("calibration done:");
    if (text.startsWith(calCompletePrefix)) {
        _stopCalibration(StopCalibrationSuccess);
        return;
    }

    if (text.startsWith("calibration cancelled")) {
        _stopCalibration(_waitingForCancel ? StopCalibrationCancelled : StopCalibrationFailed);
        return;
    }

    if (text.startsWith("calibration failed")) {
        _stopCalibration(StopCalibrationFailed);
        return;
    }
}

void SensorsComponentController::_refreshParams(void)
{
    QStringList fastRefreshList;

    // We ask for a refresh on these first so that the rotation combo show up as fast as possible
    fastRefreshList << "CAL_MAG0_ID" << "CAL_MAG1_ID" << "CAL_MAG2_ID" << "CAL_MAG0_ROT" << "CAL_MAG1_ROT" << "CAL_MAG2_ROT";
    for (const QString &paramName : std::as_const(fastRefreshList)) {
        _vehicle->parameterManager()->refreshParameter(ParameterManager::defaultComponentId, paramName);
    }

    // Now ask for all to refresh
    _vehicle->parameterManager()->refreshParametersPrefix(ParameterManager::defaultComponentId, "CAL_");
    _vehicle->parameterManager()->refreshParametersPrefix(ParameterManager::defaultComponentId, "SENS_");
}

void SensorsComponentController::_updateAndEmitShowOrientationCalArea(bool show)
{
    _showOrientationCalArea = show;
    emit showOrientationCalAreaChanged();
}

void SensorsComponentController::_hideAllCalAreas(void)
{
    _updateAndEmitShowOrientationCalArea(false);
}

void SensorsComponentController::cancelCalibration(void)
{
    // The firmware doesn't allow us to cancel calibration. The best we can do is wait
    // for it to timeout.
    _waitingForCancel = true;
    emit waitingForCancelChanged();
    _vehicle->stopCalibration(true /* showError */);
}

void SensorsComponentController::_handleParametersReset(bool success)
{
    if (success) {
        qgcApp()->showAppMessage(tr("重置成功"));

        QTimer::singleShot(1000, this, [this]() {
            _refreshParams();
        });
    }
    else {
        qgcApp()->showAppMessage(tr("重置失败"));
    }
}

void SensorsComponentController::resetFactoryParameters()
{
    auto compId = _vehicle->defaultComponentId();

    _vehicle->sendMavCommand(compId,
                             MAV_CMD_PREFLIGHT_STORAGE,
                             true,  // showError
                             3,     // Reset factory parameters
                             -1);   // Don't do anything with mission storage

    QTimer::singleShot(1000, this, [this]() {
        _clearSensorCalibrationIds();
    });
}

void SensorsComponentController::_clearSensorCalibrationIds()
{
    static constexpr const char* kSensorCalibrationIdParams[] = {
        "CAL_ACC0_ID",
        "CAL_ACC1_ID",
        "CAL_ACC2_ID",
        "CAL_ACC3_ID",
        "CAL_GYRO0_ID",
        "CAL_GYRO1_ID",
        "CAL_GYRO2_ID",
        "CAL_GYRO3_ID",
        "CAL_MAG0_ID",
        "CAL_MAG1_ID",
        "CAL_MAG2_ID",
        "CAL_MAG3_ID",
    };

    ParameterManager *parameterManager = _vehicle->parameterManager();
    for (const char *paramName : kSensorCalibrationIdParams) {
        if (parameterManager->parameterExists(ParameterManager::defaultComponentId, paramName)) {
            parameterManager->getParameter(ParameterManager::defaultComponentId, paramName)->setCookedValue(0);
        }
    }

    qgcApp()->showAppMessage(tr("已恢复为未校准状态，请重启飞控后重新校准传感器。"));
}

void SensorsComponentController::clearBoardLevelOffsets()
{
    static constexpr const char* kBoardOffsetParams[] = {
        "SENS_BOARD_X_OFF",
        "SENS_BOARD_Y_OFF",
        "SENS_BOARD_Z_OFF",
    };

    ParameterManager *parameterManager = _vehicle->parameterManager();
    for (const char *paramName : kBoardOffsetParams) {
        if (parameterManager->parameterExists(ParameterManager::defaultComponentId, paramName)) {
            parameterManager->getParameter(ParameterManager::defaultComponentId, paramName)->setCookedValue(0.0);
        }
    }

    QTimer::singleShot(1000, this, [this]() {
        _vehicle->parameterManager()->refreshParameter(ParameterManager::defaultComponentId, "SENS_BOARD_X_OFF");
        _vehicle->parameterManager()->refreshParameter(ParameterManager::defaultComponentId, "SENS_BOARD_Y_OFF");
        _vehicle->parameterManager()->refreshParameter(ParameterManager::defaultComponentId, "SENS_BOARD_Z_OFF");
    });

    qgcApp()->showAppMessage(tr("已清除水平偏置，请重启飞控后重新校准加速度计和地平线。"));
}
