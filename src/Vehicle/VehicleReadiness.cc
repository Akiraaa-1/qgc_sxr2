#include "VehicleReadiness.h"

#include <QtCore/QMetaObject>

#include "AutoPilotPlugin.h"
#include "HealthAndArmingCheckReport.h"
#include "Vehicle.h"
#include "VehicleLinkManager.h"

VehicleReadiness::VehicleReadiness(Vehicle* vehicle, QObject* parent)
    : QObject(parent)
    , _vehicle(vehicle)
{
    _armRequestTimer.setSingleShot(true);
    _armRequestTimer.setInterval(7000);

    connect(&_armRequestTimer, &QTimer::timeout, this, [this]() {
        if (_armRequestState == ArmRequestDispatched || _armRequestState == ArmRequestAcknowledged) {
            _setArmRequestState(ArmRequestTimedOut, tr("No arming confirmation was received from the vehicle."));
        }
    });

    if (!_vehicle) {
        return;
    }

    connect(_vehicle, &Vehicle::armedChanged, this, &VehicleReadiness::_armedChanged);
    connect(_vehicle, &Vehicle::mavCommandResult, this, &VehicleReadiness::_mavCommandResult);
    connect(_vehicle, &Vehicle::readyToFlyAvailableChanged, this, &VehicleReadiness::refresh);
    connect(_vehicle, &Vehicle::readyToFlyChanged, this, &VehicleReadiness::refresh);
    connect(_vehicle, &Vehicle::allSensorsHealthyChanged, this, &VehicleReadiness::refresh);
    connect(_vehicle, &Vehicle::sysStatusReceivedChanged, this, &VehicleReadiness::refresh);
    connect(_vehicle, &Vehicle::initialConnectComplete, this, &VehicleReadiness::refresh);
    connect(_vehicle->healthAndArmingCheckReport(), &HealthAndArmingCheckReport::updated, this, &VehicleReadiness::refresh);

    VehicleLinkManager* const linkManager = _vehicle->vehicleLinkManager();
    if (linkManager) {
        connect(linkManager, &VehicleLinkManager::communicationLostChanged, this, &VehicleReadiness::refresh);
    }
}

int VehicleReadiness::source() const
{
    if (!_vehicle || _vehicle->isOfflineEditingVehicle()) {
        return SourceUnavailable;
    }

    VehicleLinkManager* const linkManager = _vehicle->vehicleLinkManager();
    if (!linkManager || linkManager->communicationLost()) {
        return SourceUnavailable;
    }

    const HealthAndArmingCheckReport* const report = _vehicle->healthAndArmingCheckReport();
    if (report->healthAndArmingChecksSupported()) {
        return report->valid() ? SourceHealthReport : SourceWaitingForHealthReport;
    }

    if (!_vehicle->isInitialConnectComplete()) {
        return SourceWaitingForHealthReport;
    }

    return legacyPrearmAvailable() ? SourceLegacyPrearm : SourceBasicFallback;
}

int VehicleReadiness::armingVerdict() const
{
    const HealthAndArmingCheckReport* const report = _vehicle ? _vehicle->healthAndArmingCheckReport() : nullptr;
    if (source() == SourceHealthReport && report && report->armCheckValid()) {
        return report->canArm() ? VerdictAllowed : VerdictDenied;
    }
    if (source() == SourceLegacyPrearm && !legacyPrearmReady()) {
        return VerdictDenied;
    }
    return VerdictUnknown;
}

int VehicleReadiness::takeoffVerdict() const
{
    const HealthAndArmingCheckReport* const report = _vehicle ? _vehicle->healthAndArmingCheckReport() : nullptr;
    if (source() == SourceHealthReport && report && report->takeoffCheckValid()) {
        return report->canTakeoff() ? VerdictAllowed : VerdictDenied;
    }
    return VerdictUnknown;
}

int VehicleReadiness::missionStartVerdict() const
{
    const HealthAndArmingCheckReport* const report = _vehicle ? _vehicle->healthAndArmingCheckReport() : nullptr;
    if (source() == SourceHealthReport && report && report->missionStartCheckValid()) {
        return report->canStartMission() ? VerdictAllowed : VerdictDenied;
    }
    return VerdictUnknown;
}

int VehicleReadiness::missionResumeVerdict() const
{
    const HealthAndArmingCheckReport* const report = _vehicle ? _vehicle->healthAndArmingCheckReport() : nullptr;
    if (source() == SourceHealthReport && report && report->missionResumeCheckValid()) {
        return report->canResumeMission() ? VerdictAllowed : VerdictDenied;
    }
    return VerdictUnknown;
}

int VehicleReadiness::statusLevel() const
{
    if (source() == SourceUnavailable) {
        return StatusBlocked;
    }
    if (armingVerdict() == VerdictDenied) {
        return StatusBlocked;
    }
    if (source() != SourceHealthReport || hasHealthWarnings()) {
        return StatusAttention;
    }
    return StatusReady;
}

bool VehicleReadiness::healthReportSupported() const
{
    return source() == SourceHealthReport;
}

bool VehicleReadiness::hasHealthWarnings() const
{
    return healthReportSupported() && _vehicle->healthAndArmingCheckReport()->hasWarningsOrErrors();
}

bool VehicleReadiness::legacyPrearmAvailable() const
{
    return _vehicle && _vehicle->readyToFlyAvailable();
}

bool VehicleReadiness::legacyPrearmReady() const
{
    return legacyPrearmAvailable() && _vehicle->readyToFly();
}

bool VehicleReadiness::sysStatusReceived() const
{
    return _vehicle && _vehicle->sysStatusReceived();
}

bool VehicleReadiness::basicSensorStatusAvailable() const
{
    return sysStatusReceived() && _vehicle->sensorsEnabledBits() != 0;
}

bool VehicleReadiness::allSensorsHealthy() const
{
    return _vehicle && _vehicle->allSensorsHealthy();
}

bool VehicleReadiness::setupComplete() const
{
    return _vehicle && _vehicle->autopilotPlugin() && _vehicle->autopilotPlugin()->setupComplete();
}

bool VehicleReadiness::basicReady() const
{
    return basicSensorStatusAvailable() && allSensorsHealthy() && setupComplete();
}

bool VehicleReadiness::armDenied() const
{
    return armingVerdict() == VerdictDenied;
}

bool VehicleReadiness::armUnconfirmed() const
{
    return armingVerdict() == VerdictUnknown;
}

bool VehicleReadiness::armAllowed() const
{
    return armingVerdict() == VerdictAllowed;
}

bool VehicleReadiness::takeoffAllowed() const
{
    return takeoffVerdict() == VerdictAllowed;
}

bool VehicleReadiness::missionStartAllowed() const
{
    return missionStartVerdict() == VerdictAllowed;
}

bool VehicleReadiness::missionResumeAllowed() const
{
    return missionResumeVerdict() == VerdictAllowed;
}

bool VehicleReadiness::canRequestArm() const
{
    return _isActionRequestable(ReadinessAction::Arm, armingVerdict());
}

bool VehicleReadiness::canRequestTakeoff() const
{
    return _isActionRequestable(ReadinessAction::Takeoff, takeoffVerdict());
}

bool VehicleReadiness::canRequestMissionStart() const
{
    return _isActionRequestable(ReadinessAction::MissionStart, missionStartVerdict());
}

bool VehicleReadiness::canRequestMissionResume() const
{
    return _isActionRequestable(ReadinessAction::MissionResume, missionResumeVerdict());
}

bool VehicleReadiness::armConfirmationRequired() const
{
    return _isActionConfirmationRequired(ReadinessAction::Arm, armingVerdict());
}

bool VehicleReadiness::takeoffConfirmationRequired() const
{
    return _isActionConfirmationRequired(ReadinessAction::Takeoff, takeoffVerdict());
}

bool VehicleReadiness::missionStartConfirmationRequired() const
{
    return _isActionConfirmationRequired(ReadinessAction::MissionStart, missionStartVerdict());
}

bool VehicleReadiness::missionResumeConfirmationRequired() const
{
    return _isActionConfirmationRequired(ReadinessAction::MissionResume, missionResumeVerdict());
}

QString VehicleReadiness::armReason() const
{
    return _reasonForAction(ReadinessAction::Arm, armingVerdict(), tr("arming"));
}

QString VehicleReadiness::takeoffReason() const
{
    return _reasonForAction(ReadinessAction::Takeoff, takeoffVerdict(), tr("takeoff"));
}

QString VehicleReadiness::missionStartReason() const
{
    return _reasonForAction(ReadinessAction::MissionStart, missionStartVerdict(), tr("mission start"));
}

QString VehicleReadiness::missionResumeReason() const
{
    return _reasonForAction(ReadinessAction::MissionResume, missionResumeVerdict(), tr("mission resume"));
}

void VehicleReadiness::refresh()
{
    emit changed();
}

void VehicleReadiness::invalidate()
{
    _armRequestTimer.stop();
    if (_armRequestState == ArmRequestDispatched || _armRequestState == ArmRequestAcknowledged) {
        _setArmRequestState(ArmRequestInvalidated, tr("The vehicle connection changed before arming was confirmed."));
    }
    emit changed();
}

void VehicleReadiness::beginArmRequest()
{
    _setArmRequestState(ArmRequestDispatched, tr("Arming command sent. Waiting for vehicle acknowledgement."));
    _armRequestTimer.start();
}

void VehicleReadiness::rejectArmRequest(const QString& message)
{
    _armRequestTimer.stop();
    _setArmRequestState(ArmRequestRejected, message);
}

bool VehicleReadiness::_isActionRequestable(ReadinessAction action, int verdict) const
{
    if (verdict == VerdictAllowed) {
        return true;
    }
    if (verdict == VerdictDenied) {
        return false;
    }

    const int currentSource = source();
    if (currentSource == SourceLegacyPrearm && !legacyPrearmReady()) {
        return false;
    }

    const bool sourceAllowsConfirmedFallback = currentSource == SourceLegacyPrearm
                                            || currentSource == SourceBasicFallback
                                            || currentSource == SourceWaitingForHealthReport;
    return sourceAllowsConfirmedFallback
        && (action == ReadinessAction::Arm
            || action == ReadinessAction::Takeoff
            || action == ReadinessAction::MissionStart
            || action == ReadinessAction::MissionResume);
}

bool VehicleReadiness::_isActionConfirmationRequired(ReadinessAction action, int verdict) const
{
    return verdict == VerdictUnknown && _isActionRequestable(action, verdict);
}

QString VehicleReadiness::_reasonForAction(ReadinessAction action, int verdict, const QString& actionText) const
{
    if (source() == SourceUnavailable) {
        return tr("Communication is unavailable, so the current %1 state cannot be determined.").arg(actionText);
    }
    if (source() == SourceLegacyPrearm && !legacyPrearmReady()) {
        return tr("The flight controller reports pre-arm checks are not ready, so %1 is blocked.").arg(actionText);
    }
    if (verdict == VerdictDenied) {
        return tr("The flight-controller health report is blocking %1.").arg(actionText);
    }
    if (verdict == VerdictUnknown) {
        if (_isActionRequestable(action, verdict)) {
            return tr("The flight controller has not provided a current %1 decision. Confirmation sends a normal command, and the flight controller still performs its checks.").arg(actionText);
        }
        return tr("The flight controller has not provided an explicit %1 decision. A current health report is required before this action.").arg(actionText);
    }
    if (hasHealthWarnings()) {
        return tr("The flight controller allows %1, but reports warnings.").arg(actionText);
    }
    return tr("The flight controller allows %1.").arg(actionText);
}

void VehicleReadiness::_setArmRequestState(ArmRequestState state, const QString& message)
{
    if (_armRequestState == state && _armRequestMessage == message) {
        return;
    }

    _armRequestState = state;
    _armRequestMessage = message;
    emit armRequestChanged();
}

void VehicleReadiness::_mavCommandResult(int, int, int command, int ackResult, int)
{
    if (command != MAV_CMD_COMPONENT_ARM_DISARM || _armRequestState != ArmRequestDispatched) {
        return;
    }

    if (ackResult == MAV_RESULT_ACCEPTED) {
        _setArmRequestState(ArmRequestAcknowledged, tr("Arming command accepted. Waiting for vehicle state confirmation."));
    } else {
        _armRequestTimer.stop();
        _setArmRequestState(ArmRequestRejected, tr("The flight controller rejected the arming command."));
    }
}

void VehicleReadiness::_armedChanged(bool armed)
{
    if (!armed || (_armRequestState != ArmRequestDispatched && _armRequestState != ArmRequestAcknowledged)) {
        return;
    }

    _armRequestTimer.stop();
    _setArmRequestState(ArmRequestConfirmed, tr("Vehicle arming state confirmed."));
}
