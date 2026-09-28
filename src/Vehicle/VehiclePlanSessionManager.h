#pragma once

#include <QtCore/QHash>
#include <QtCore/QObject>
#include <QtCore/QPointer>
#include <QtCore/QSet>
#include <QtCore/QString>
#include <QtCore/QVariantMap>

class MultiVehicleManager;
class PlanMasterController;
class Vehicle;

class VehiclePlanSessionManager : public QObject
{
    Q_OBJECT
    Q_MOC_INCLUDE("PlanMasterController.h")
    Q_MOC_INCLUDE("Vehicle.h")

    Q_PROPERTY(PlanMasterController* activeController READ activeController NOTIFY activeSessionChanged)
    Q_PROPERTY(Vehicle* activeVehicle READ activeVehicle NOTIFY activeSessionChanged)
    Q_PROPERTY(QString activeSessionId READ activeSessionId NOTIFY activeSessionChanged)
    Q_PROPERTY(int bindingGeneration READ bindingGeneration NOTIFY activeSessionChanged)
    Q_PROPERTY(quint64 activeVehicleUid READ activeVehicleUid NOTIFY activeSessionChanged)
    Q_PROPERTY(bool activeSessionConnected READ activeSessionConnected NOTIFY activeSessionChanged)
    Q_PROPERTY(QString activeIdentityState READ activeIdentityState NOTIFY activeSessionChanged)

public:
    explicit VehiclePlanSessionManager(MultiVehicleManager* multiVehicleManager, QObject* parent = nullptr);
    ~VehiclePlanSessionManager();

    PlanMasterController* activeController() const;
    Vehicle* activeVehicle() const;
    QString activeSessionId() const;
    int bindingGeneration() const;
    quint64 activeVehicleUid() const;
    bool activeSessionConnected() const;
    QString activeIdentityState() const;

    Q_INVOKABLE QVariantMap makeOperationToken();
    Q_INVOKABLE bool tokenStillCurrent(const QVariantMap& token) const;
    Q_INVOKABLE bool sendToVehicleWithToken(const QVariantMap& token);
    Q_INVOKABLE bool loadFromVehicleWithToken(const QVariantMap& token);
    Q_INVOKABLE bool removeAllWithToken(const QVariantMap& token);
    Q_INVOKABLE bool removeMissionFromVehicleWithToken(const QVariantMap& token);
    Q_INVOKABLE bool removeAllFromVehicleWithToken(const QVariantMap& token);
    Q_INVOKABLE void cancelActiveOperation();

signals:
    void activeSessionChanged();
    void operationRejected(const QString& reason);

private:
    enum class VehicleMutation {
        Upload,
        ClearMission,
        ClearAll,
    };

    struct Session {
        QString sessionId;
        QString key;
        QPointer<Vehicle> vehicle;
        quint64 vehicleUid = 0;
        int vehicleSysId = 0;
        int bindingGeneration = 0;
        bool identityConflict = false;
        PlanMasterController* controller = nullptr;
    };

    Session* _createSession(const QString& key);
    Session* _ensureOfflineSession();
    Session* _ensureSessionForVehicle(Vehicle* vehicle);
    Session* _sessionForVehicle(Vehicle* vehicle) const;
    void _setActiveSession(Session* session);
    void _attachSessionToVehicle(Session* session, Vehicle* vehicle);
    QString _sessionKeyForVehicle(Vehicle* vehicle) const;
    QString _detachedSessionKey(Session* session) const;
    bool _localPlanTokenStillCurrent(const QVariantMap& token) const;
    bool _sessionHasLocalChanges(Session* session) const;
    bool _vehicleMutationAllowed(VehicleMutation mutation, QString& reason) const;
    QString _activeSessionUnavailableReason() const;
    void _updateIdentityConflicts();
    void _rejectOperation(const QString& reason) const;

    void _activeVehicleChanged(Vehicle* vehicle);
    void _vehicleAdded(Vehicle* vehicle);
    void _vehicleRemoved(Vehicle* vehicle);
    void _vehicleUIDChanged(Vehicle* vehicle);

    MultiVehicleManager* _multiVehicleManager = nullptr;
    QHash<QString, Session*> _sessions;
    QSet<Vehicle*> _trackedVehicles;
    Session* _offlineSession = nullptr;
    Session* _activeSession = nullptr;
    quint64 _nextOperationId = 0;
};
