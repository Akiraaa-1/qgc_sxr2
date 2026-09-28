#pragma once

#include <QtCore/QObject>
#include <QtCore/QString>
#include <QtCore/QTimer>
#include <QtQmlIntegration/QtQmlIntegration>

class Vehicle;

class VehicleReadiness : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Vehicle-owned")
    Q_MOC_INCLUDE("Vehicle.h")

    Q_PROPERTY(int source READ source NOTIFY changed)
    Q_PROPERTY(int armingVerdict READ armingVerdict NOTIFY changed)
    Q_PROPERTY(int takeoffVerdict READ takeoffVerdict NOTIFY changed)
    Q_PROPERTY(int missionStartVerdict READ missionStartVerdict NOTIFY changed)
    Q_PROPERTY(int missionResumeVerdict READ missionResumeVerdict NOTIFY changed)
    Q_PROPERTY(int statusLevel READ statusLevel NOTIFY changed)
    Q_PROPERTY(bool healthReportSupported READ healthReportSupported NOTIFY changed)
    Q_PROPERTY(bool hasHealthWarnings READ hasHealthWarnings NOTIFY changed)
    Q_PROPERTY(bool legacyPrearmAvailable READ legacyPrearmAvailable NOTIFY changed)
    Q_PROPERTY(bool legacyPrearmReady READ legacyPrearmReady NOTIFY changed)
    Q_PROPERTY(bool sysStatusReceived READ sysStatusReceived NOTIFY changed)
    Q_PROPERTY(bool basicSensorStatusAvailable READ basicSensorStatusAvailable NOTIFY changed)
    Q_PROPERTY(bool allSensorsHealthy READ allSensorsHealthy NOTIFY changed)
    Q_PROPERTY(bool setupComplete READ setupComplete NOTIFY changed)
    Q_PROPERTY(bool basicReady READ basicReady NOTIFY changed)
    Q_PROPERTY(bool armDenied READ armDenied NOTIFY changed)
    Q_PROPERTY(bool armUnconfirmed READ armUnconfirmed NOTIFY changed)
    Q_PROPERTY(bool armAllowed READ armAllowed NOTIFY changed)
    Q_PROPERTY(bool takeoffAllowed READ takeoffAllowed NOTIFY changed)
    Q_PROPERTY(bool missionStartAllowed READ missionStartAllowed NOTIFY changed)
    Q_PROPERTY(bool missionResumeAllowed READ missionResumeAllowed NOTIFY changed)
    Q_PROPERTY(bool canRequestArm READ canRequestArm NOTIFY changed)
    Q_PROPERTY(bool canRequestTakeoff READ canRequestTakeoff NOTIFY changed)
    Q_PROPERTY(bool canRequestMissionStart READ canRequestMissionStart NOTIFY changed)
    Q_PROPERTY(bool canRequestMissionResume READ canRequestMissionResume NOTIFY changed)
    Q_PROPERTY(bool armConfirmationRequired READ armConfirmationRequired NOTIFY changed)
    Q_PROPERTY(bool takeoffConfirmationRequired READ takeoffConfirmationRequired NOTIFY changed)
    Q_PROPERTY(bool missionStartConfirmationRequired READ missionStartConfirmationRequired NOTIFY changed)
    Q_PROPERTY(bool missionResumeConfirmationRequired READ missionResumeConfirmationRequired NOTIFY changed)
    Q_PROPERTY(QString armReason READ armReason NOTIFY changed)
    Q_PROPERTY(QString takeoffReason READ takeoffReason NOTIFY changed)
    Q_PROPERTY(QString missionStartReason READ missionStartReason NOTIFY changed)
    Q_PROPERTY(QString missionResumeReason READ missionResumeReason NOTIFY changed)
    Q_PROPERTY(int armRequestState READ armRequestState NOTIFY armRequestChanged)
    Q_PROPERTY(QString armRequestMessage READ armRequestMessage NOTIFY armRequestChanged)

public:
    enum Source {
        SourceUnavailable,
        SourceHealthReport,
        SourceLegacyPrearm,
        SourceBasicFallback,
        SourceWaitingForHealthReport,
    };
    Q_ENUM(Source)

    enum Verdict {
        VerdictUnknown,
        VerdictAllowed,
        VerdictDenied,
    };
    Q_ENUM(Verdict)

    enum StatusLevel {
        StatusReady,
        StatusAttention,
        StatusBlocked,
    };
    Q_ENUM(StatusLevel)

    enum ArmRequestState {
        ArmRequestIdle,
        ArmRequestAwaitingConfirmation,
        ArmRequestDispatched,
        ArmRequestAcknowledged,
        ArmRequestConfirmed,
        ArmRequestRejected,
        ArmRequestTimedOut,
        ArmRequestInvalidated,
    };
    Q_ENUM(ArmRequestState)

    explicit VehicleReadiness(Vehicle* vehicle, QObject* parent = nullptr);

    int source() const;
    int armingVerdict() const;
    int takeoffVerdict() const;
    int missionStartVerdict() const;
    int missionResumeVerdict() const;
    int statusLevel() const;

    bool healthReportSupported() const;
    bool hasHealthWarnings() const;
    bool legacyPrearmAvailable() const;
    bool legacyPrearmReady() const;
    bool sysStatusReceived() const;
    bool basicSensorStatusAvailable() const;
    bool allSensorsHealthy() const;
    bool setupComplete() const;
    bool basicReady() const;

    bool armDenied() const;
    bool armUnconfirmed() const;
    bool armAllowed() const;
    bool takeoffAllowed() const;
    bool missionStartAllowed() const;
    bool missionResumeAllowed() const;
    bool canRequestArm() const;
    bool canRequestTakeoff() const;
    bool canRequestMissionStart() const;
    bool canRequestMissionResume() const;
    bool armConfirmationRequired() const;
    bool takeoffConfirmationRequired() const;
    bool missionStartConfirmationRequired() const;
    bool missionResumeConfirmationRequired() const;

    QString armReason() const;
    QString takeoffReason() const;
    QString missionStartReason() const;
    QString missionResumeReason() const;

    int armRequestState() const { return _armRequestState; }
    const QString& armRequestMessage() const { return _armRequestMessage; }

    void refresh();
    void invalidate();
    void beginArmRequest();
    void rejectArmRequest(const QString& message);

signals:
    void changed();
    void armRequestChanged();

private:
    enum class ReadinessAction {
        Arm,
        Takeoff,
        MissionStart,
        MissionResume,
    };

    bool _isActionRequestable(ReadinessAction action, int verdict) const;
    bool _isActionConfirmationRequired(ReadinessAction action, int verdict) const;
    QString _reasonForAction(ReadinessAction action, int verdict, const QString& actionText) const;
    void _setArmRequestState(ArmRequestState state, const QString& message);
    void _mavCommandResult(int vehicleId, int targetComponent, int command, int ackResult, int failureCode);
    void _armedChanged(bool armed);

    Vehicle* const _vehicle;
    QTimer _armRequestTimer;
    ArmRequestState _armRequestState{ArmRequestIdle};
    QString _armRequestMessage;
};
