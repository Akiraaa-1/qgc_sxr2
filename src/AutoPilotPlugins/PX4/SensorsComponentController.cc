#include "SensorsComponentController.h"
#include "QGCApplication.h"
#include "ParameterManager.h"
#include "Vehicle.h"
#include "QGCLoggingCategory.h"
#include "MAVLink/LibEvents/libevents_includes.h"
#include <QtCore/QElapsedTimer>

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
    , _orientationCalAction                     (OrientationCalActionWaiting)
    , _unknownFirmwareVersion                   (false)
    , _waitingForCancel                         (false)
{
    connect(_vehicle, &Vehicle::sensorsParametersResetAck, this, &SensorsComponentController::_handleParametersReset);
    _progressUpdateTimer.setInterval(100);
    _progressUpdateTimer.setSingleShot(true);
    connect(&_progressUpdateTimer, &QTimer::timeout, this, &SensorsComponentController::_applyPendingProgress);
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

    QElapsedTimer invokeTimer;
    invokeTimer.start();
    const QVariant varText = text;
    const bool invoked = QMetaObject::invokeMethod(_statusLog,
                                                   "append",
                                                   Q_ARG(QVariant, varText));
    if (!invoked) {
        qWarning() << "Unable to append sensor calibration status log";
    } else if (invokeTimer.elapsed() >= 50) {
        qCWarning(SensorsComponentControllerLog) << "Slow calibration status update" << invokeTimer.elapsed() << "ms";
    }
}

void SensorsComponentController::_queueProgressUpdate(int progress)
{
    _pendingProgress = qBound(0, progress, 100);
    if (!_progressUpdateTimer.isActive()) {
        _progressUpdateTimer.start();
    }
}

void SensorsComponentController::_applyPendingProgress(void)
{
    if (_pendingProgress < 0) {
        return;
    }

    const int progress = _pendingProgress;
    _pendingProgress = -1;
    if (_progressBar) {
        _progressBar->setProperty("value", static_cast<float>(progress / 100.0));
    }
}

void SensorsComponentController::_startLogCalibration(void)
{
    _unknownFirmwareVersion = false;
    _calibrationStopHandled = false;
    _structuredCalibrationEventsSeen = false;
    _lastStructuredProgress = -1;
    _pendingProgress = -1;
    _progressUpdateTimer.stop();
    _activeCalibrationType.clear();
    _lastCalibrationText.clear();
    _hideAllCalAreas();

    disconnect(_vehicle, &Vehicle::textMessageReceived, this, &SensorsComponentController::_handleUASTextMessage);
    disconnect(_vehicle, &Vehicle::calibrationEventReceived, this, &SensorsComponentController::_handleCalibrationEvent);
    connect(_vehicle, &Vehicle::textMessageReceived, this, &SensorsComponentController::_handleUASTextMessage, Qt::UniqueConnection);
    connect(_vehicle, &Vehicle::calibrationEventReceived, this, &SensorsComponentController::_handleCalibrationEvent, Qt::UniqueConnection);
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
    _setOrientationCalAction(OrientationCalActionWaiting);

    emit orientationCalSidesRotateChanged();
    emit orientationCalSidesDoneChanged();
    emit orientationCalSidesInProgressChanged();
}

void SensorsComponentController::_setOrientationCalAction(OrientationCalAction action)
{
    if (_orientationCalAction == action) {
        return;
    }

    _orientationCalAction = action;
    emit orientationCalActionChanged();
}

void SensorsComponentController::_setOrientationSideState(const QString& side, bool done, bool inProgress, bool rotate)
{
    bool* sideDone = nullptr;
    bool* sideInProgress = nullptr;
    bool* sideRotate = nullptr;

    if (side == QStringLiteral("down")) {
        sideDone = &_orientationCalDownSideDone;
        sideInProgress = &_orientationCalDownSideInProgress;
        sideRotate = &_orientationCalDownSideRotate;
    } else if (side == QStringLiteral("up")) {
        sideDone = &_orientationCalUpsideDownSideDone;
        sideInProgress = &_orientationCalUpsideDownSideInProgress;
        sideRotate = &_orientationCalUpsideDownSideRotate;
    } else if (side == QStringLiteral("left")) {
        sideDone = &_orientationCalLeftSideDone;
        sideInProgress = &_orientationCalLeftSideInProgress;
        sideRotate = &_orientationCalLeftSideRotate;
    } else if (side == QStringLiteral("right")) {
        sideDone = &_orientationCalRightSideDone;
        sideInProgress = &_orientationCalRightSideInProgress;
        sideRotate = &_orientationCalRightSideRotate;
    } else if (side == QStringLiteral("front")) {
        sideDone = &_orientationCalNoseDownSideDone;
        sideInProgress = &_orientationCalNoseDownSideInProgress;
        sideRotate = &_orientationCalNoseDownSideRotate;
    } else if (side == QStringLiteral("back")) {
        sideDone = &_orientationCalTailDownSideDone;
        sideInProgress = &_orientationCalTailDownSideInProgress;
        sideRotate = &_orientationCalTailDownSideRotate;
    } else {
        return;
    }

    const bool doneChanged = *sideDone != done;
    const bool inProgressChanged = *sideInProgress != inProgress;
    const bool rotateChanged = *sideRotate != rotate;

    *sideDone = done;
    *sideInProgress = inProgress;
    *sideRotate = rotate;

    if (doneChanged) {
        emit orientationCalSidesDoneChanged();
    }
    if (inProgressChanged) {
        emit orientationCalSidesInProgressChanged();
    }
    if (rotateChanged) {
        emit orientationCalSidesRotateChanged();
    }
}

void SensorsComponentController::_setActiveOrientationRotate(bool rotate)
{
    bool changed = false;
    if (_orientationCalDownSideInProgress && _orientationCalDownSideRotate != rotate) {
        _orientationCalDownSideRotate = rotate;
        changed = true;
    }
    if (_orientationCalUpsideDownSideInProgress && _orientationCalUpsideDownSideRotate != rotate) {
        _orientationCalUpsideDownSideRotate = rotate;
        changed = true;
    }
    if (_orientationCalLeftSideInProgress && _orientationCalLeftSideRotate != rotate) {
        _orientationCalLeftSideRotate = rotate;
        changed = true;
    }
    if (_orientationCalRightSideInProgress && _orientationCalRightSideRotate != rotate) {
        _orientationCalRightSideRotate = rotate;
        changed = true;
    }
    if (_orientationCalNoseDownSideInProgress && _orientationCalNoseDownSideRotate != rotate) {
        _orientationCalNoseDownSideRotate = rotate;
        changed = true;
    }
    if (_orientationCalTailDownSideInProgress && _orientationCalTailDownSideRotate != rotate) {
        _orientationCalTailDownSideRotate = rotate;
        changed = true;
    }
    if (changed) {
        emit orientationCalSidesRotateChanged();
    }
}

bool SensorsComponentController::_orientationSideDone(const QString& side) const
{
    if (side == QStringLiteral("down")) {
        return _orientationCalDownSideDone;
    } else if (side == QStringLiteral("up")) {
        return _orientationCalUpsideDownSideDone;
    } else if (side == QStringLiteral("left")) {
        return _orientationCalLeftSideDone;
    } else if (side == QStringLiteral("right")) {
        return _orientationCalRightSideDone;
    } else if (side == QStringLiteral("front")) {
        return _orientationCalNoseDownSideDone;
    } else if (side == QStringLiteral("back")) {
        return _orientationCalTailDownSideDone;
    }
    return false;
}

void SensorsComponentController::_handleOrientationDetected(const QString& side, OrientationCalAction action)
{
    if (_orientationSideDone(side) && action != OrientationCalActionAlreadyCompleted) {
        return;
    }

    switch (action) {
    case OrientationCalActionAlreadyCompleted:
        _setOrientationSideState(side, true, false, false);
        break;
    case OrientationCalActionRotate:
        _setOrientationSideState(side, false, true, true);
        break;
    case OrientationCalActionHoldStill:
        _setOrientationSideState(side, false, true, false);
        break;
    case OrientationCalActionNextOrientation:
    case OrientationCalActionWaiting:
        _setOrientationSideState(side, false, false, false);
        break;
    }
    _setOrientationCalAction(action);
}

void SensorsComponentController::_handleOrientationDone(const QString& side, OrientationCalAction action)
{
    _setOrientationSideState(side, true, false, false);
    _setOrientationCalAction(action);
}

void SensorsComponentController::_completeVisibleOrientationSides(void)
{
    if (_orientationCalDownSideVisible) {
        _orientationCalDownSideDone = true;
        _orientationCalDownSideInProgress = false;
        _orientationCalDownSideRotate = false;
    }
    if (_orientationCalUpsideDownSideVisible) {
        _orientationCalUpsideDownSideDone = true;
        _orientationCalUpsideDownSideInProgress = false;
        _orientationCalUpsideDownSideRotate = false;
    }
    if (_orientationCalLeftSideVisible) {
        _orientationCalLeftSideDone = true;
        _orientationCalLeftSideInProgress = false;
        _orientationCalLeftSideRotate = false;
    }
    if (_orientationCalRightSideVisible) {
        _orientationCalRightSideDone = true;
        _orientationCalRightSideInProgress = false;
        _orientationCalRightSideRotate = false;
    }
    if (_orientationCalNoseDownSideVisible) {
        _orientationCalNoseDownSideDone = true;
        _orientationCalNoseDownSideInProgress = false;
        _orientationCalNoseDownSideRotate = false;
    }
    if (_orientationCalTailDownSideVisible) {
        _orientationCalTailDownSideDone = true;
        _orientationCalTailDownSideInProgress = false;
        _orientationCalTailDownSideRotate = false;
    }

    emit orientationCalSidesDoneChanged();
    emit orientationCalSidesInProgressChanged();
    emit orientationCalSidesRotateChanged();
}

QString SensorsComponentController::_currentCalibrationType(void) const
{
    if (!_activeCalibrationType.isEmpty()) {
        return _activeCalibrationType;
    }
    if (_magCalInProgress) {
        return QStringLiteral("mag");
    }
    if (_accelCalInProgress) {
        return QStringLiteral("accel");
    }
    if (_gyroCalInProgress) {
        return QStringLiteral("gyro");
    }
    if (_levelCalInProgress) {
        return QStringLiteral("level");
    }
    if (_airspeedCalInProgress) {
        return QStringLiteral("airspeed");
    }
    return QString();
}

void SensorsComponentController::_stopCalibration(SensorsComponentController::StopCalibrationCode code)
{
    if (_calibrationStopHandled) {
        return;
    }
    _calibrationStopHandled = true;
    const QString calibrationType = _currentCalibrationType();

    disconnect(_vehicle, &Vehicle::textMessageReceived, this, &SensorsComponentController::_handleUASTextMessage);
    disconnect(_vehicle, &Vehicle::calibrationEventReceived, this, &SensorsComponentController::_handleCalibrationEvent);
    _progressUpdateTimer.stop();
    _pendingProgress = -1;

    if (code == StopCalibrationSuccess) {
        _completeVisibleOrientationSides();

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
            _appendStatusLog(tr("校准完成"));
            emit calibrationComplete(calibrationType);
            if (_magCalInProgress) {
                emit magCalComplete();
            }
            break;

        case StopCalibrationCancelled:
            emit calibrationCancelled(calibrationType);
            emit resetStatusTextArea();
            _hideAllCalAreas();
            break;

        default:
            // Assume failed
            _hideAllCalAreas();
            _appendStatusLog(tr("校准失败"));
            emit calibrationFailed(calibrationType);
            break;
    }

    _magCalInProgress = false;
    _accelCalInProgress = false;
    _gyroCalInProgress = false;
    _airspeedCalInProgress = false;
    _levelCalInProgress = false;
    _activeCalibrationType.clear();
    _lastCalibrationText.clear();
    _setOrientationCalAction(OrientationCalActionWaiting);

    emit calibrationActiveChanged();
}

uint64_t SensorsComponentController::_configuredMagCalibrationSides(void) const
{
    static constexpr uint64_t kAllCalibrationSides = (1 << 5) | (1 << 4) | (1 << 3) | (1 << 2) | (1 << 1) | (1 << 0);
    uint64_t sides = kAllCalibrationSides;

    if (_vehicle->parameterManager()->parameterExists(ParameterManager::defaultComponentId, "SENS_MAG_SIDES")) {
        sides = static_cast<uint64_t>(_vehicle->parameterManager()->getParameter(ParameterManager::defaultComponentId, "SENS_MAG_SIDES")->rawValue().toInt());
    } else if (_vehicle->parameterManager()->parameterExists(ParameterManager::defaultComponentId, "CAL_MAG_SIDES")) {
        sides = static_cast<uint64_t>(_vehicle->parameterManager()->getParameter(ParameterManager::defaultComponentId, "CAL_MAG_SIDES")->rawValue().toInt());
    }

    sides &= kAllCalibrationSides;
    return sides == 0 ? kAllCalibrationSides : sides;
}

void SensorsComponentController::_updateOrientationSidesFromRemaining(uint64_t visibleSides, uint64_t remainingSides)
{
    static constexpr uint64_t kAllCalibrationSides = (1 << 5) | (1 << 4) | (1 << 3) | (1 << 2) | (1 << 1) | (1 << 0);
    // required_sides is a progress snapshot and can arrive before the
    // corresponding cal_orientation_done event. Only the explicit orientation
    // event is authoritative for marking a side complete.
    Q_UNUSED(remainingSides);
    visibleSides &= kAllCalibrationSides;

    const uint8_t previousVisible =
        (_orientationCalTailDownSideVisible << 0) |
        (_orientationCalNoseDownSideVisible << 1) |
        (_orientationCalLeftSideVisible << 2) |
        (_orientationCalRightSideVisible << 3) |
        (_orientationCalUpsideDownSideVisible << 4) |
        (_orientationCalDownSideVisible << 5);
    const uint8_t previousDone =
        (_orientationCalTailDownSideDone << 0) |
        (_orientationCalNoseDownSideDone << 1) |
        (_orientationCalLeftSideDone << 2) |
        (_orientationCalRightSideDone << 3) |
        (_orientationCalUpsideDownSideDone << 4) |
        (_orientationCalDownSideDone << 5);
    const uint8_t previousInProgress =
        (_orientationCalTailDownSideInProgress << 0) |
        (_orientationCalNoseDownSideInProgress << 1) |
        (_orientationCalLeftSideInProgress << 2) |
        (_orientationCalRightSideInProgress << 3) |
        (_orientationCalUpsideDownSideInProgress << 4) |
        (_orientationCalDownSideInProgress << 5);
    const uint8_t previousRotate =
        (_orientationCalTailDownSideRotate << 0) |
        (_orientationCalNoseDownSideRotate << 1) |
        (_orientationCalLeftSideRotate << 2) |
        (_orientationCalRightSideRotate << 3) |
        (_orientationCalUpsideDownSideRotate << 4) |
        (_orientationCalDownSideRotate << 5);

    _orientationCalTailDownSideVisible = visibleSides & (1 << 0);
    _orientationCalNoseDownSideVisible = visibleSides & (1 << 1);
    _orientationCalLeftSideVisible = visibleSides & (1 << 2);
    _orientationCalRightSideVisible = visibleSides & (1 << 3);
    _orientationCalUpsideDownSideVisible = visibleSides & (1 << 4);
    _orientationCalDownSideVisible = visibleSides & (1 << 5);

    _orientationCalTailDownSideDone = _orientationCalTailDownSideVisible && _orientationCalTailDownSideDone;
    _orientationCalNoseDownSideDone = _orientationCalNoseDownSideVisible && _orientationCalNoseDownSideDone;
    _orientationCalLeftSideDone = _orientationCalLeftSideVisible && _orientationCalLeftSideDone;
    _orientationCalRightSideDone = _orientationCalRightSideVisible && _orientationCalRightSideDone;
    _orientationCalUpsideDownSideDone = _orientationCalUpsideDownSideVisible && _orientationCalUpsideDownSideDone;
    _orientationCalDownSideDone = _orientationCalDownSideVisible && _orientationCalDownSideDone;

    if (_orientationCalDownSideDone) {
        _orientationCalDownSideInProgress = false;
        _orientationCalDownSideRotate = false;
    }
    if (_orientationCalUpsideDownSideDone) {
        _orientationCalUpsideDownSideInProgress = false;
        _orientationCalUpsideDownSideRotate = false;
    }
    if (_orientationCalLeftSideDone) {
        _orientationCalLeftSideInProgress = false;
        _orientationCalLeftSideRotate = false;
    }
    if (_orientationCalRightSideDone) {
        _orientationCalRightSideInProgress = false;
        _orientationCalRightSideRotate = false;
    }
    if (_orientationCalNoseDownSideDone) {
        _orientationCalNoseDownSideInProgress = false;
        _orientationCalNoseDownSideRotate = false;
    }
    if (_orientationCalTailDownSideDone) {
        _orientationCalTailDownSideInProgress = false;
        _orientationCalTailDownSideRotate = false;
    }

    const uint8_t currentDone =
        (_orientationCalTailDownSideDone << 0) |
        (_orientationCalNoseDownSideDone << 1) |
        (_orientationCalLeftSideDone << 2) |
        (_orientationCalRightSideDone << 3) |
        (_orientationCalUpsideDownSideDone << 4) |
        (_orientationCalDownSideDone << 5);
    const uint8_t currentInProgress =
        (_orientationCalTailDownSideInProgress << 0) |
        (_orientationCalNoseDownSideInProgress << 1) |
        (_orientationCalLeftSideInProgress << 2) |
        (_orientationCalRightSideInProgress << 3) |
        (_orientationCalUpsideDownSideInProgress << 4) |
        (_orientationCalDownSideInProgress << 5);
    const uint8_t currentRotate =
        (_orientationCalTailDownSideRotate << 0) |
        (_orientationCalNoseDownSideRotate << 1) |
        (_orientationCalLeftSideRotate << 2) |
        (_orientationCalRightSideRotate << 3) |
        (_orientationCalUpsideDownSideRotate << 4) |
        (_orientationCalDownSideRotate << 5);

    if (previousVisible != visibleSides) {
        emit orientationCalSidesVisibleChanged();
    }
    if (previousDone != currentDone) {
        emit orientationCalSidesDoneChanged();
    }
    if (previousInProgress != currentInProgress) {
        emit orientationCalSidesInProgressChanged();
    }
    if (previousRotate != currentRotate) {
        emit orientationCalSidesRotateChanged();
    }
}

void SensorsComponentController::_handleCalibrationEvent(int uasId, int compId, int severity, QSharedPointer<events::parser::ParsedEvent> event)
{
    if (uasId != _vehicle->id() || !event) {
        return;
    }

    const QString eventType = QString::fromStdString(event->type());
    const bool isCalibrationEvent = eventType == QStringLiteral("cal_progress") ||
                                    eventType == QStringLiteral("cal_orientation_detected") ||
                                    eventType == QStringLiteral("cal_orientation_done") ||
                                    eventType == QStringLiteral("cal_done");
    if (isCalibrationEvent && eventType != QStringLiteral("cal_progress")) {
        _structuredCalibrationEventsSeen = true;
    }
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
    const auto orientationAction = [](uint64_t action) {
        switch (action) {
        case 0: return OrientationCalActionAlreadyCompleted;
        case 1: return OrientationCalActionNextOrientation;
        case 2: return OrientationCalActionRotate;
        case 3: return OrientationCalActionHoldStill;
        default: return OrientationCalActionWaiting;
        }
    };

    if (eventType == QStringLiteral("cal_progress") && event->numArguments() >= 3) {
        const QString calType = calTypeName(event->argumentValueInt(2));
        if (!calType.isEmpty() && !calibrationActive()) {
            _handleUASTextMessage(uasId, compId, severity, QStringLiteral("[cal] calibration started: 2 %1").arg(calType), QString());
        }
        _structuredCalibrationEventsSeen = true;
        if (event->numArguments() >= 4) {
            if (calType == QStringLiteral("accel")) {
                static constexpr uint64_t kAllCalibrationSides = (1 << 5) | (1 << 4) | (1 << 3) | (1 << 2) | (1 << 1) | (1 << 0);
                _updateOrientationSidesFromRemaining(kAllCalibrationSides, event->argumentValueInt(3));
            } else if (calType == QStringLiteral("mag")) {
                _updateOrientationSidesFromRemaining(_configuredMagCalibrationSides(), event->argumentValueInt(3));
            }
        }
        const int progress = qBound(0, static_cast<int>(event->argumentValueInt(1)), 100);
        if (progress != _lastStructuredProgress) {
            _lastStructuredProgress = progress;
            _queueProgressUpdate(progress);
        }
    } else if (eventType == QStringLiteral("cal_orientation_detected") && event->numArguments() >= 1) {
        const QString side = sideName(event->argumentValueInt(0));
        if (!side.isEmpty()) {
            const OrientationCalAction action = event->numArguments() >= 2
                ? orientationAction(event->argumentValueInt(1))
                : (_magCalInProgress ? OrientationCalActionRotate : OrientationCalActionHoldStill);
            const QString statusText = QStringLiteral("[cal] %1 orientation detected").arg(side);
            if (_lastCalibrationText != statusText) {
                _lastCalibrationText = statusText;
                _appendStatusLog(statusText);
            }
            _handleOrientationDetected(side, action);
        }
    } else if (eventType == QStringLiteral("cal_orientation_done") && event->numArguments() >= 1) {
        const QString side = sideName(event->argumentValueInt(0));
        if (!side.isEmpty()) {
            const OrientationCalAction action = event->numArguments() >= 2
                ? orientationAction(event->argumentValueInt(1))
                : OrientationCalActionNextOrientation;
            const QString statusText = QStringLiteral("[cal] %1 side done, rotate to a different side").arg(side);
            if (_lastCalibrationText != statusText) {
                _lastCalibrationText = statusText;
                _appendStatusLog(statusText);
            }
            _handleOrientationDone(side, action);
        }
    } else if (eventType == QStringLiteral("cal_done") && event->numArguments() >= 1) {
        const uint64_t result = event->argumentValueInt(0);
        if (result == 0) {
            _stopCalibration(StopCalibrationSuccess);
        } else if (result == 2) {
            _stopCalibration(_waitingForCancel ? StopCalibrationCancelled : StopCalibrationFailed);
        } else {
            _stopCalibration(StopCalibrationFailed);
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
            _queueProgressUpdate(p);
        }
        return;
    }

    if (text.startsWith(QStringLiteral("[cal] "))) {
        const QString calibrationText = text.mid(6);
        const bool duplicateStructuredText = _structuredCalibrationEventsSeen &&
                                              (calibrationText.startsWith(QStringLiteral("calibration started:"), Qt::CaseInsensitive) ||
                                               calibrationText.endsWith(QStringLiteral("orientation detected"), Qt::CaseInsensitive) ||
                                               calibrationText.endsWith(QStringLiteral("side done, rotate to a different side"), Qt::CaseInsensitive));
        if (duplicateStructuredText) {
            return;
        }
        if (text == _lastCalibrationText) {
            return;
        }
        _lastCalibrationText = text;
    }

    const bool repeatedCompassPreflightFailure = text.contains(QStringLiteral("Preflight Fail: Compass"), Qt::CaseInsensitive) &&
                                                 text.contains(QStringLiteral("uncalibrated"), Qt::CaseInsensitive);
    if (!repeatedCompassPreflightFailure) {
        _appendStatusLog(text);
    }
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

    if (text.startsWith(QStringLiteral("Rotate vehicle"), Qt::CaseInsensitive)) {
        _setActiveOrientationRotate(true);
        _setOrientationCalAction(OrientationCalActionRotate);
        return;
    }

    if (text.contains(QStringLiteral("detected rest position"), Qt::CaseInsensitive) ||
        text.contains(QStringLiteral("detected motion, hold still"), Qt::CaseInsensitive)) {
        _setActiveOrientationRotate(false);
        _setOrientationCalAction(OrientationCalActionHoldStill);
        return;
    }

    if (text.contains(QStringLiteral("hold vehicle still on a pending side"), Qt::CaseInsensitive)) {
        _setOrientationCalAction(OrientationCalActionWaiting);
        return;
    }

    QString calStartPrefix("calibration started: ");
    if (text.startsWith(calStartPrefix)) {
        text = text.right(text.length() - calStartPrefix.length());

        // Split version number and cal type
        QStringList parts = text.split(" ");
        if (parts.count() != 2 || parts[0].toInt() != _supportedFirmwareCalVersion) {
            _unknownFirmwareVersion = true;
            QString msg = tr("Unsupported calibration firmware version, using log");
            _appendStatusLog(msg);
            qDebug() << msg;
            return;
        }

        text = parts[1];
        if (calibrationActive()) {
            if (text == _activeCalibrationType) {
                return;
            }

            qCWarning(SensorsComponentControllerLog) << "Ignoring calibration start while another calibration is active" << text << _activeCalibrationType;
            return;
        }
        _activeCalibrationType = text;
        _startVisualCalibration();

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

                const uint64_t sides = _configuredMagCalibrationSides();

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
        _handleOrientationDetected(side, _magCalInProgress ? OrientationCalActionRotate : OrientationCalActionHoldStill);

        if (_magCalInProgress) {
            _orientationCalAreaHelpText->setProperty("text", tr("Rotate the vehicle continuously as shown in the diagram until marked as Completed"));
        } else {
            _orientationCalAreaHelpText->setProperty("text", tr("Hold still in the current orientation"));
        }

        return;
    }

    if (text.endsWith("side done, rotate to a different side")) {
        QString side = text.section(" ", 0, 0);
        qCDebug(SensorsComponentControllerLog) << "Side finished" << side;

        _handleOrientationDone(side, OrientationCalActionNextOrientation);

        _orientationCalAreaHelpText->setProperty("text", tr("Place you vehicle into one of the orientations shown below and hold it still"));

        return;
    }

    if (text.endsWith("side already completed")) {
        QString side = text.section(" ", 0, 0);
        _handleOrientationDetected(side, OrientationCalActionAlreadyCompleted);
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
    emit factoryResetCompleted(success);

    if (success) {
        qgcApp()->showAppMessage(tr("重置成功，请重启飞控后重新校准传感器。"));
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
