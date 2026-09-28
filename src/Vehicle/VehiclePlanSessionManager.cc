#include "VehiclePlanSessionManager.h"

#include "MultiVehicleManager.h"
#include "PlanMasterController.h"
#include "QGCApplication.h"
#include "QGCLoggingCategory.h"
#include "Vehicle.h"
#include "VehicleLinkManager.h"

#include <QtCore/QList>
#include <QtCore/QtAlgorithms>
#include <QtCore/QUuid>

QGC_LOGGING_CATEGORY(VehiclePlanSessionManagerLog, "Vehicle.VehiclePlanSessionManager")

VehiclePlanSessionManager::VehiclePlanSessionManager(MultiVehicleManager* multiVehicleManager, QObject* parent)
    : QObject(parent)
    , _multiVehicleManager(multiVehicleManager)
{
    (void) connect(_multiVehicleManager, &MultiVehicleManager::activeVehicleChanged, this, &VehiclePlanSessionManager::_activeVehicleChanged);
    (void) connect(_multiVehicleManager, &MultiVehicleManager::vehicleAdded, this, &VehiclePlanSessionManager::_vehicleAdded);
    (void) connect(_multiVehicleManager, &MultiVehicleManager::vehicleRemoved, this, &VehiclePlanSessionManager::_vehicleRemoved);

    _setActiveSession(_ensureOfflineSession());
    _activeVehicleChanged(_multiVehicleManager->activeVehicle());
}

VehiclePlanSessionManager::~VehiclePlanSessionManager()
{
    qDeleteAll(_sessions);
    _sessions.clear();
}

PlanMasterController* VehiclePlanSessionManager::activeController() const
{
    return _activeSession ? _activeSession->controller : nullptr;
}

Vehicle* VehiclePlanSessionManager::activeVehicle() const
{
    return _activeSession ? _activeSession->vehicle.data() : nullptr;
}

QString VehiclePlanSessionManager::activeSessionId() const
{
    return _activeSession ? _activeSession->sessionId : QString();
}

int VehiclePlanSessionManager::bindingGeneration() const
{
    return _activeSession ? _activeSession->bindingGeneration : 0;
}

quint64 VehiclePlanSessionManager::activeVehicleUid() const
{
    return _activeSession ? _activeSession->vehicleUid : 0;
}

bool VehiclePlanSessionManager::activeSessionConnected() const
{
    Vehicle* const vehicle = activeVehicle();
    if (!vehicle) {
        return false;
    }

    VehicleLinkManager* const linkManager = vehicle->vehicleLinkManager();
    return linkManager && linkManager->primaryLink().lock() && !linkManager->communicationLost();
}

QString VehiclePlanSessionManager::activeIdentityState() const
{
    if (!_activeSession || !_activeSession->vehicle) {
        return QStringLiteral("UnboundDraft");
    }
    if (!activeSessionConnected()) {
        return QStringLiteral("Disconnected");
    }
    if (_activeSession->identityConflict) {
        return QStringLiteral("Conflict");
    }
    if (_activeSession->vehicleUid == 0) {
        return QStringLiteral("TemporaryIdentity");
    }

    PlanMasterController* const controller = _activeSession->controller;
    if (controller && controller->planVehicleIdentityAvailable() && controller->planVehicleUid() != _activeSession->vehicleUid) {
        return QStringLiteral("IdentityMismatch");
    }
    if (controller && !controller->remotePlanStateKnown()) {
        return QStringLiteral("RemoteStateUnknown");
    }

    return QStringLiteral("VerifiedIdentity");
}

QVariantMap VehiclePlanSessionManager::makeOperationToken()
{
    QVariantMap token;
    if (!_activeSession) {
        return token;
    }

    token[QStringLiteral("sessionId")] = _activeSession->sessionId;
    token[QStringLiteral("bindingGeneration")] = _activeSession->bindingGeneration;
    token[QStringLiteral("operationId")] = ++_nextOperationId;
    token[QStringLiteral("vehicleUid")] = QString::number(_activeSession->vehicleUid);
    token[QStringLiteral("vehicleSysId")] = _activeSession->vehicleSysId;
    token[QStringLiteral("connected")] = activeSessionConnected();
    token[QStringLiteral("identityState")] = activeIdentityState();
    return token;
}

bool VehiclePlanSessionManager::tokenStillCurrent(const QVariantMap& token) const
{
    if (!_activeSession) {
        return false;
    }

    if (token.value(QStringLiteral("sessionId")).toString() != _activeSession->sessionId) {
        return false;
    }
    if (token.value(QStringLiteral("bindingGeneration")).toInt() != _activeSession->bindingGeneration) {
        return false;
    }
    if (token.value(QStringLiteral("vehicleSysId")).toInt() != _activeSession->vehicleSysId) {
        return false;
    }

    bool tokenUidOk = false;
    const quint64 tokenUid = token.value(QStringLiteral("vehicleUid")).toString().toULongLong(&tokenUidOk);
    return tokenUidOk && tokenUid == _activeSession->vehicleUid;
}

bool VehiclePlanSessionManager::sendToVehicleWithToken(const QVariantMap& token)
{
    if (!tokenStillCurrent(token)) {
        _rejectOperation(tr("The active plan target changed. Please confirm the upload again."));
        return false;
    }
    if (!activeSessionConnected() || !activeController() || activeController()->offline()) {
        _rejectOperation(_activeSessionUnavailableReason());
        return false;
    }
    QString reason;
    if (!_vehicleMutationAllowed(VehicleMutation::Upload, reason)) {
        _rejectOperation(reason);
        return false;
    }

    activeController()->sendToVehicle();
    return activeController()->syncInProgress();
}

bool VehiclePlanSessionManager::loadFromVehicleWithToken(const QVariantMap& token)
{
    if (!tokenStillCurrent(token)) {
        _rejectOperation(tr("The active plan target changed. Please confirm the download again."));
        return false;
    }
    if (!activeSessionConnected() || !activeController() || activeController()->offline()) {
        _rejectOperation(_activeSessionUnavailableReason());
        return false;
    }
    if (activeController()->syncInProgress()) {
        _rejectOperation(tr("The active plan is already synchronizing with the vehicle. Wait for it to finish before downloading again."));
        return false;
    }

    activeController()->loadFromVehicle();
    return activeController()->syncInProgress();
}

bool VehiclePlanSessionManager::removeAllWithToken(const QVariantMap& token)
{
    if (!_localPlanTokenStillCurrent(token) || !activeController()) {
        _rejectOperation(tr("The active plan changed. Please confirm the clear operation again."));
        return false;
    }
    if (activeController()->syncInProgress()) {
        _rejectOperation(tr("The active plan is synchronizing with the vehicle. Wait for it to finish before clearing the local plan."));
        return false;
    }

    activeController()->removeAll();
    return true;
}

bool VehiclePlanSessionManager::removeMissionFromVehicleWithToken(const QVariantMap& token)
{
    if (!tokenStillCurrent(token)) {
        _rejectOperation(tr("The active plan target changed. Please confirm the mission clear operation again."));
        return false;
    }
    if (!activeSessionConnected() || !activeController() || activeController()->offline()) {
        _rejectOperation(_activeSessionUnavailableReason());
        return false;
    }
    QString reason;
    if (!_vehicleMutationAllowed(VehicleMutation::ClearMission, reason)) {
        _rejectOperation(reason);
        return false;
    }

    activeController()->removeMissionFromVehicle();
    return activeController()->removeMissionFromVehicleInProgress();
}

bool VehiclePlanSessionManager::removeAllFromVehicleWithToken(const QVariantMap& token)
{
    if (!tokenStillCurrent(token)) {
        _rejectOperation(tr("The active plan target changed. Please confirm the clear operation again."));
        return false;
    }
    if (!activeSessionConnected() || !activeController() || activeController()->offline()) {
        _rejectOperation(_activeSessionUnavailableReason());
        return false;
    }
    QString reason;
    if (!_vehicleMutationAllowed(VehicleMutation::ClearAll, reason)) {
        _rejectOperation(reason);
        return false;
    }

    activeController()->removeAllFromVehicle();
    return activeController()->removeAllFromVehicleInProgress();
}

void VehiclePlanSessionManager::cancelActiveOperation()
{
    if (activeController()) {
        activeController()->cancelOperation();
    }
}

VehiclePlanSessionManager::Session* VehiclePlanSessionManager::_ensureOfflineSession()
{
    if (_offlineSession) {
        return _offlineSession;
    }

    _offlineSession = _createSession(QStringLiteral("offline"));
    _offlineSession->controller->startBoundVehicle(nullptr);
    return _offlineSession;
}

VehiclePlanSessionManager::Session* VehiclePlanSessionManager::_createSession(const QString& key)
{
    Session* const session = new Session;
    session->sessionId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    session->key = key;
    session->controller = new PlanMasterController(this);
    _sessions.insert(session->key, session);

    (void) connect(session->controller, &PlanMasterController::planVehicleIdentityChanged, this, [this, session]() {
        if (_activeSession == session) {
            emit activeSessionChanged();
        }
    });
    (void) connect(session->controller, &PlanMasterController::remotePlanStateKnownChanged, this, [this, session]() {
        if (_activeSession == session) {
            emit activeSessionChanged();
        }
    });

    return session;
}

VehiclePlanSessionManager::Session* VehiclePlanSessionManager::_ensureSessionForVehicle(Vehicle* vehicle)
{
    if (!vehicle) {
        return _ensureOfflineSession();
    }

    const QString key = _sessionKeyForVehicle(vehicle);
    Session* session = _sessions.value(key, nullptr);
    if (session && session->vehicle && session->vehicle != vehicle) {
        _rejectOperation(tr("Another connected vehicle already owns this plan identity. A separate temporary plan session was created."));
        const QString conflictKey = QStringLiteral("sysid:%1").arg(vehicle->id());
        session = _sessions.value(conflictKey, nullptr);
        if (!session) {
            session = _createSession(conflictKey);
        }
    }
    if (!session) {
        session = _createSession(key);
    }

    _attachSessionToVehicle(session, vehicle);
    return session;
}

VehiclePlanSessionManager::Session* VehiclePlanSessionManager::_sessionForVehicle(Vehicle* vehicle) const
{
    if (!vehicle) {
        return _offlineSession;
    }

    for (Session* session: _sessions) {
        if (session->vehicle == vehicle) {
            return session;
        }
    }

    return _sessions.value(_sessionKeyForVehicle(vehicle), nullptr);
}

void VehiclePlanSessionManager::_setActiveSession(Session* session)
{
    if (!session) {
        session = _ensureOfflineSession();
    }

    if (_activeSession == session) {
        emit activeSessionChanged();
        return;
    }

    _activeSession = session;
    emit activeSessionChanged();
}

void VehiclePlanSessionManager::_attachSessionToVehicle(Session* session, Vehicle* vehicle)
{
    if (!session || !vehicle) {
        return;
    }

    if (session->vehicle == vehicle && session->controller && !session->controller->offline()) {
        return;
    }

    session->vehicle = vehicle;
    session->vehicleUid = vehicle->vehicleUID();
    session->vehicleSysId = vehicle->id();
    session->bindingGeneration++;
    session->controller->startBoundVehicle(vehicle);
    _updateIdentityConflicts();
}

QString VehiclePlanSessionManager::_sessionKeyForVehicle(Vehicle* vehicle) const
{
    if (!vehicle) {
        return QStringLiteral("offline");
    }

    const quint64 vehicleUid = vehicle->vehicleUID();
    if (vehicleUid != 0) {
        return QStringLiteral("uid:%1").arg(vehicleUid);
    }

    return QStringLiteral("sysid:%1").arg(vehicle->id());
}

QString VehiclePlanSessionManager::_detachedSessionKey(Session* session) const
{
    const QString sessionId = session && !session->sessionId.isEmpty()
        ? session->sessionId
        : QUuid::createUuid().toString(QUuid::WithoutBraces);
    const QString baseKey = QStringLiteral("detached:%1").arg(sessionId);
    QString key = baseKey;
    int index = 1;
    while (_sessions.contains(key)) {
        key = QStringLiteral("%1:%2").arg(baseKey).arg(index++);
    }
    return key;
}

bool VehiclePlanSessionManager::_localPlanTokenStillCurrent(const QVariantMap& token) const
{
    // Local clear does not send a vehicle command. A UID confirmation can
    // advance the binding generation while retaining the same plan session.
    return _activeSession &&
            token.value(QStringLiteral("sessionId")).toString() == _activeSession->sessionId;
}

bool VehiclePlanSessionManager::_sessionHasLocalChanges(Session* session) const
{
    PlanMasterController* const controller = session ? session->controller : nullptr;
    return controller && (controller->dirtyForSave() || controller->dirtyForUpload());
}

bool VehiclePlanSessionManager::_vehicleMutationAllowed(VehicleMutation mutation, QString& reason) const
{
    if (!activeSessionConnected() || !activeController() || activeController()->offline()) {
        reason = _activeSessionUnavailableReason();
        return false;
    }
    if (activeController()->syncInProgress()) {
        reason = tr("The active plan is already synchronizing with the vehicle. Wait for it to finish before changing the vehicle plan.");
        return false;
    }
    if (_activeSession->identityConflict) {
        reason = tr("Another connected vehicle reports the same vehicle identity. Upload and clear operations are disabled until the duplicate identity is resolved.");
        return false;
    }
    if (_activeSession->vehicleUid == 0) {
        reason = tr("The active vehicle has not reported a stable vehicle identity yet. Upload and clear operations are disabled until vehicle identity is confirmed.");
        return false;
    }
    if (activeController()->planVehicleIdentityAvailable() && activeController()->planVehicleUid() != _activeSession->vehicleUid) {
        reason = tr("This plan belongs to a different vehicle. Upload and clear operations are disabled for the current target.");
        return false;
    }
    if (mutation == VehicleMutation::Upload && !activeController()->remotePlanStateKnown()) {
        reason = tr("The vehicle plan state is unknown after an interrupted or failed operation. Download the plan from the vehicle or clear the vehicle mission before uploading again.");
        return false;
    }

    return true;
}

QString VehiclePlanSessionManager::_activeSessionUnavailableReason() const
{
    if (!_activeSession || !_activeSession->vehicle) {
        return tr("No vehicle is bound to the active plan session.");
    }

    return tr("The active vehicle link is lost. Restore communication before changing the vehicle plan.");
}

void VehiclePlanSessionManager::_updateIdentityConflicts()
{
    QHash<quint64, QList<Session*>> sessionsByUid;
    bool activeChanged = false;

    for (Session* session: _sessions) {
        const bool previousConflict = session->identityConflict;
        session->identityConflict = false;
        if (session->vehicle && session->vehicleUid != 0) {
            sessionsByUid[session->vehicleUid].append(session);
        }
        if (session == _activeSession && previousConflict != session->identityConflict) {
            activeChanged = true;
        }
    }

    for (const QList<Session*>& uidSessions: sessionsByUid) {
        if (uidSessions.count() <= 1) {
            continue;
        }
        for (Session* session: uidSessions) {
            if (!session->identityConflict) {
                session->identityConflict = true;
                if (session == _activeSession) {
                    activeChanged = true;
                }
            }
        }
    }

    if (activeChanged) {
        emit activeSessionChanged();
    }
}

void VehiclePlanSessionManager::_rejectOperation(const QString& reason) const
{
    emit const_cast<VehiclePlanSessionManager*>(this)->operationRejected(reason);
    qgcApp()->showAppMessage(reason);
}

void VehiclePlanSessionManager::_activeVehicleChanged(Vehicle* vehicle)
{
    if (!vehicle) {
        if (_activeSession && !_activeSession->vehicle && _activeSession != _offlineSession) {
            emit activeSessionChanged();
            return;
        }
        _setActiveSession(_ensureOfflineSession());
        return;
    }

    _vehicleAdded(vehicle);
    _setActiveSession(_ensureSessionForVehicle(vehicle));
}

void VehiclePlanSessionManager::_vehicleAdded(Vehicle* vehicle)
{
    if (!vehicle) {
        return;
    }

    if (_trackedVehicles.contains(vehicle)) {
        return;
    }
    _trackedVehicles.insert(vehicle);

    (void) connect(vehicle, &Vehicle::vehicleUIDChanged, this, [this, vehicle]() {
        _vehicleUIDChanged(vehicle);
    });
    if (VehicleLinkManager* const linkManager = vehicle->vehicleLinkManager()) {
        (void) connect(linkManager, &VehicleLinkManager::communicationLostChanged, this, [this, vehicle](bool) {
            if (activeVehicle() == vehicle) {
                emit activeSessionChanged();
            }
        });
        (void) connect(linkManager, &VehicleLinkManager::primaryLinkChanged, this, [this, vehicle]() {
            if (activeVehicle() == vehicle) {
                emit activeSessionChanged();
            }
        });
    }
}

void VehiclePlanSessionManager::_vehicleRemoved(Vehicle* vehicle)
{
    Session* session = _sessionForVehicle(vehicle);
    if (!session) {
        return;
    }

    _trackedVehicles.remove(vehicle);
    session->controller->detachVehicle();
    session->vehicle.clear();
    session->bindingGeneration++;
    _updateIdentityConflicts();

    if (_activeSession == session) {
        emit activeSessionChanged();
    }
}

void VehiclePlanSessionManager::_vehicleUIDChanged(Vehicle* vehicle)
{
    Session* session = _sessionForVehicle(vehicle);
    if (!session || session == _offlineSession) {
        return;
    }

    const QString newKey = _sessionKeyForVehicle(vehicle);
    bool sessionChanged = false;
    if (newKey != session->key) {
        Session* const existingSession = _sessions.value(newKey, nullptr);
        if (!existingSession) {
            _sessions.remove(session->key);
            session->key = newKey;
            _sessions.insert(session->key, session);
        } else if (existingSession != session && !existingSession->vehicle) {
            if (_sessionHasLocalChanges(session)) {
                _sessions.remove(existingSession->key);
                existingSession->key = _detachedSessionKey(existingSession);
                _sessions.insert(existingSession->key, existingSession);

                _sessions.remove(session->key);
                session->key = newKey;
                _sessions.insert(session->key, session);
                sessionChanged = true;
                qCDebug(VehiclePlanSessionManagerLog) << "Preserving active draft during vehicle UID confirmation";
            } else {
                session->controller->detachVehicle();
                session->vehicle.clear();
                session->bindingGeneration++;
                _attachSessionToVehicle(existingSession, vehicle);
                if (_activeSession == session) {
                    _setActiveSession(existingSession);
                } else if (_activeSession == existingSession) {
                    emit activeSessionChanged();
                }
                return;
            }
        }
    }

    if (session->vehicleUid != vehicle->vehicleUID()) {
        session->vehicleUid = vehicle->vehicleUID();
        session->bindingGeneration++;
        sessionChanged = true;
    }

    if (_activeSession == session && sessionChanged) {
        emit activeSessionChanged();
    }
    _updateIdentityConflicts();
}
