#include "PlanMasterController.h"
#include "QGCApplication.h"
#include "QGCCorePlugin.h"
#include "MultiVehicleManager.h"
#include "Vehicle.h"
#include "SettingsManager.h"
#include "AppSettings.h"
#include "JsonHelper.h"
#include "JsonParsing.h"
#include "MissionManager.h"
#include "KMLPlanDomDocument.h"
#include "SurveyPlanCreator.h"
#include "StructureScanPlanCreator.h"
#include "CorridorScanPlanCreator.h"
#include "BlankPlanCreator.h"
#include "QmlObjectListModel.h"
#include "GeoFenceManager.h"
#include "RallyPointManager.h"
#include "QGCCompression.h"
#include "QGCCompressionJob.h"
#include "QGCLoggingCategory.h"

#include <QtCore/QDir>
#include <QtCore/QDirIterator>
#include <QtCore/QFileInfo>
#include <QtCore/QJsonDocument>
#include <QtCore/QJsonObject>
#include <QtCore/QRegularExpression>

QGC_LOGGING_CATEGORY(PlanMasterControllerLog, "PlanManager.PlanMasterController")

PlanMasterController::PlanMasterController(QObject* parent)
    : QObject               (parent)
    , _multiVehicleMgr      (MultiVehicleManager::instance())
    , _controllerVehicle    (new Vehicle(Vehicle::MAV_AUTOPILOT_TRACK, Vehicle::MAV_TYPE_TRACK, this))
    , _managerVehicle       (_controllerVehicle)
    , _missionController    (this)
    , _geoFenceController   (this)
    , _rallyPointController (this)
{
    _commonInit();
}

#ifdef QT_DEBUG
PlanMasterController::PlanMasterController(MAV_AUTOPILOT firmwareType, MAV_TYPE vehicleType, QObject* parent)
    : QObject               (parent)
    , _multiVehicleMgr      (MultiVehicleManager::instance())
    , _controllerVehicle    (new Vehicle(firmwareType, vehicleType))
    , _managerVehicle       (_controllerVehicle)
    , _missionController    (this)
    , _geoFenceController   (this)
    , _rallyPointController (this)
{
    _commonInit();
}
#endif

void PlanMasterController::_commonInit(void)
{
    connect(&_missionController,    &MissionController::dirtyChanged,               this, &PlanMasterController::_updateOverallDirty);
    connect(&_geoFenceController,   &GeoFenceController::dirtyChanged,              this, &PlanMasterController::_updateOverallDirty);
    connect(&_rallyPointController, &RallyPointController::dirtyChanged,            this, &PlanMasterController::_updateOverallDirty);

    connect(&_missionController,    &MissionController::containsItemsChanged,       this, &PlanMasterController::containsItemsChanged);
    connect(&_geoFenceController,   &GeoFenceController::containsItemsChanged,      this, &PlanMasterController::containsItemsChanged);
    connect(&_rallyPointController, &RallyPointController::containsItemsChanged,    this, &PlanMasterController::containsItemsChanged);

    connect(&_missionController,    &MissionController::syncInProgressChanged,      this, &PlanMasterController::syncInProgressChanged);
    connect(&_geoFenceController,   &GeoFenceController::syncInProgressChanged,     this, &PlanMasterController::syncInProgressChanged);
    connect(&_rallyPointController, &RallyPointController::syncInProgressChanged,   this, &PlanMasterController::syncInProgressChanged);

    // Offline vehicle can change firmware/vehicle type
    connect(_controllerVehicle,     &Vehicle::vehicleTypeChanged,                   this, &PlanMasterController::_updatePlanCreatorsList);
}


PlanMasterController::~PlanMasterController()
{

}

Vehicle* PlanMasterController::boundVehicle(void) const
{
    return _boundVehicle.data();
}

void PlanMasterController::start(void)
{
    if (_boundVehicleMode) {
        qCWarning(PlanMasterControllerLog) << "start called on a bound vehicle controller";
        return;
    }

    _startElementControllers();

    _activeVehicleChanged(_multiVehicleMgr->activeVehicle());
    if (!_trackingActiveVehicle) {
        connect(_multiVehicleMgr, &MultiVehicleManager::activeVehicleChanged, this, &PlanMasterController::_activeVehicleChanged);
        _trackingActiveVehicle = true;
    }

    _updatePlanCreatorsList();
}

void PlanMasterController::startStaticActiveVehicle(Vehicle* vehicle, bool deleteWhenSendCompleted)
{
    if (_trackingActiveVehicle) {
        disconnect(_multiVehicleMgr, &MultiVehicleManager::activeVehicleChanged, this, &PlanMasterController::_activeVehicleChanged);
        _trackingActiveVehicle = false;
    }
    _boundVehicleMode = false;
    _flyView = true;
    _deleteWhenSendCompleted = deleteWhenSendCompleted;
    _startElementControllers();
    _activeVehicleChanged(vehicle);
}

void PlanMasterController::startBoundVehicle(Vehicle* vehicle)
{
    if (_trackingActiveVehicle) {
        disconnect(_multiVehicleMgr, &MultiVehicleManager::activeVehicleChanged, this, &PlanMasterController::_activeVehicleChanged);
        _trackingActiveVehicle = false;
    }

    _boundVehicleMode = true;
    _flyView = false;
    _startElementControllers();

    if (_boundVehicle != vehicle) {
        _boundVehicle = vehicle;
        emit boundVehicleChanged(_boundVehicle.data());
    }

    if (_setManagerVehicle(vehicle ? vehicle : _controllerVehicle) && vehicle && !containsItems()) {
        _showPlanFromManagerVehicle();
    }
}

void PlanMasterController::detachVehicle(void)
{
    if (!_boundVehicleMode) {
        return;
    }

    cancelOperation();

    if (_boundVehicle) {
        _boundVehicle.clear();
        emit boundVehicleChanged(nullptr);
    }

    _setManagerVehicle(_controllerVehicle);
    if (containsItems()) {
        _setDirtyForUpload(true);
    }
}

void PlanMasterController::cancelOperation(void)
{
    const bool wasSyncing = syncInProgress();

    _sendToVehicleInProgress = false;
    _sendGeoFence = false;
    _sendRallyPoints = false;
    _removeAllGeoFence = false;
    _removeAllRallyPoints = false;
    _clearLoadTracking();

    if (_removeMissionFromVehicleInProgress) {
        _removeMissionFromVehicleInProgress = false;
        emit removeMissionFromVehicleInProgressChanged();
    }

    if (_removeAllFromVehicleInProgress) {
        _removeAllFromVehicleInProgress = false;
        emit removeAllFromVehicleInProgressChanged();
        emit syncInProgressChanged();
    }

    if (_managerVehicle && !_managerVehicle->isOfflineEditingVehicle()) {
        _managerVehicle->missionManager()->cancelTransaction();
        _managerVehicle->geoFenceManager()->cancelTransaction();
        _managerVehicle->rallyPointManager()->cancelTransaction();
    }

    if (containsItems()) {
        _setDirtyForUpload(true);
    }
    if (wasSyncing) {
        _setRemotePlanStateKnown(false);
    }

    if (wasSyncing != syncInProgress()) {
        emit syncInProgressChanged();
    }
}

void PlanMasterController::_startElementControllers(void)
{
    if (_started) {
        return;
    }

    _missionController.start    (_flyView);
    _geoFenceController.start   (_flyView);
    _rallyPointController.start (_flyView);
    _started = true;
}

bool PlanMasterController::_setManagerVehicle(Vehicle* managerVehicle)
{
    if (!managerVehicle) {
        managerVehicle = _controllerVehicle;
    }

    if (_managerVehicle == managerVehicle) {
        return false;
    }

    if (_managerVehicle) {
        // Disconnect old vehicle. Be careful of wildcarding disconnect too much since _managerVehicle may equal _controllerVehicle
        disconnect(_managerVehicle->missionManager(),       nullptr, this, nullptr);
        disconnect(_managerVehicle->geoFenceManager(),      nullptr, this, nullptr);
        disconnect(_managerVehicle->rallyPointManager(),    nullptr, this, nullptr);
    }

    _managerVehicle = managerVehicle;

    const bool oldOffline = _offline;
    _offline = _managerVehicle->isOfflineEditingVehicle();

    if (!_offline) {
        // Update controllerVehicle to the currently connected vehicle
        AppSettings* appSettings = SettingsManager::instance()->appSettings();
        appSettings->offlineEditingFirmwareClass()->setRawValue(QGCMAVLink::firmwareClass(_managerVehicle->firmwareType()));
        appSettings->offlineEditingVehicleClass()->setRawValue(QGCMAVLink::vehicleClass(_managerVehicle->vehicleType()));

        // We use these signals to sequence upload and download to the multiple controller/managers
        connect(_managerVehicle->missionManager(),      &MissionManager::newMissionItemsAvailable,  this, &PlanMasterController::_loadMissionComplete);
        connect(_managerVehicle->geoFenceManager(),     &GeoFenceManager::loadComplete,             this, &PlanMasterController::_loadGeoFenceComplete);
        connect(_managerVehicle->rallyPointManager(),   &RallyPointManager::loadComplete,           this, &PlanMasterController::_loadRallyPointsComplete);
        connect(_managerVehicle->missionManager(),      &MissionManager::error,                     this, &PlanMasterController::_managerPlanError);
        connect(_managerVehicle->geoFenceManager(),     &GeoFenceManager::error,                    this, &PlanMasterController::_managerPlanError);
        connect(_managerVehicle->rallyPointManager(),   &RallyPointManager::error,                  this, &PlanMasterController::_managerPlanError);
        connect(_managerVehicle->missionManager(),      &MissionManager::sendComplete,              this, static_cast<void (PlanMasterController::*)(bool)>(&PlanMasterController::_sendMissionComplete));
        connect(_managerVehicle->geoFenceManager(),     &GeoFenceManager::sendComplete,             this, static_cast<void (PlanMasterController::*)(bool)>(&PlanMasterController::_sendGeoFenceComplete));
        connect(_managerVehicle->rallyPointManager(),   &RallyPointManager::sendComplete,           this, static_cast<void (PlanMasterController::*)(bool)>(&PlanMasterController::_sendRallyPointsComplete));
        connect(_managerVehicle->missionManager(),      &MissionManager::removeAllComplete,         this, &PlanMasterController::_removeMissionComplete);
        connect(_managerVehicle->geoFenceManager(),     &GeoFenceManager::removeAllComplete,        this, &PlanMasterController::_removeGeoFenceComplete);
        connect(_managerVehicle->rallyPointManager(),   &RallyPointManager::removeAllComplete,      this, &PlanMasterController::_removeRallyPointsComplete);
    }

    if (oldOffline != _offline) {
        emit offlineChanged(offline());
    }
    emit managerVehicleChanged(_managerVehicle);

    return true;
}

void PlanMasterController::_activeVehicleChanged(Vehicle* activeVehicle)
{
    if (_boundVehicleMode) {
        return;
    }

    if (_managerVehicle == activeVehicle) {
        // We are already setup for this vehicle
        return;
    }

    qCDebug(PlanMasterControllerLog) << "_activeVehicleChanged" << activeVehicle;

    if (syncInProgress()) {
        cancelOperation();
    }

    _setManagerVehicle(activeVehicle ? activeVehicle : _controllerVehicle);
    const bool newOffline = offline();

    if (_flyView) {
        // We are in the Fly View
        if (newOffline) {
            // No active vehicle, clear mission
            qCDebug(PlanMasterControllerLog) << "_activeVehicleChanged: Fly View - No active vehicle, clearing stale plan";
            removeAll();
        } else {
            // Fly view has changed to a new active vehicle, update to show correct mission
            qCDebug(PlanMasterControllerLog) << "_activeVehicleChanged: Fly View - New active vehicle, loading new plan from manager vehicle";
            _showPlanFromManagerVehicle();
        }
    } else {
        // We are in the Plan view.
        if (containsItems()) {
            // We have a plan which is from a different vehicle than the new active vehicle. By definition this plan requires and upload.
            _setDirtyForUpload(true);

            // The plan view has a stale plan in it
            if (dirtyForSave()) {
                // Plan is dirty, the user must decide what to do in all cases
                qCDebug(PlanMasterControllerLog) << "_activeVehicleChanged: Plan View - Previous dirty plan exists, no new active vehicle, sending promptForPlanUsageOnVehicleChange signal";
                emit promptForPlanUsageOnVehicleChange();
            } else {
                // Plan is not dirty
                if (newOffline) {
                    // The active vehicle went away with no new active vehicle
                    qCDebug(PlanMasterControllerLog) << "_activeVehicleChanged: Plan View - Previous clean plan exists, no new active vehicle, clear stale plan";
                    removeAll();
                } else {
                    // We are transitioning from one active vehicle to another. Show the plan from the new vehicle.
                    qCDebug(PlanMasterControllerLog) << "_activeVehicleChanged: Plan View - Previous clean plan exists, new active vehicle, loading from new manager vehicle";
                    _showPlanFromManagerVehicle();
                }
            }
        } else {
            // There is no previous Plan in the view
            _setDirtyStates(false, false);
            if (newOffline) {
                // Nothing special to do in this case
                qCDebug(PlanMasterControllerLog) << "_activeVehicleChanged: Plan View - No previous plan, no longer connected to vehicle, nothing to do";
            } else {
                // Just show the plan from the new vehicle
                qCDebug(PlanMasterControllerLog) << "_activeVehicleChanged: Plan View - No previous plan, new active vehicle, loading from new manager vehicle";
                _showPlanFromManagerVehicle();
            }
        }
    }

    // Vehicle changed so we need to signal everything
    emit containsItemsChanged();
    emit syncInProgressChanged();
    emit dirtyForSaveChanged(dirtyForSave());
    emit dirtyForUploadChanged(dirtyForUpload());

    _updatePlanCreatorsList();
}

void PlanMasterController::loadFromVehicle(void)
{
    SharedLinkInterfacePtr sharedLink = _managerVehicle->vehicleLinkManager()->primaryLink().lock();
    if (sharedLink) {
        if (sharedLink->linkConfiguration()->isHighLatency()) {
            qgcApp()->showAppMessage(tr("Download not supported on high latency links."));
            return;
        }
    } else {
        // Vehicle is shutting down
        return;
    }

    if (offline()) {
        qCCritical(PlanMasterControllerLog) << "PlanMasterController::loadFromVehicle called while offline";
    } else if (_flyView) {
        qCCritical(PlanMasterControllerLog) << "PlanMasterController::loadFromVehicle called from Fly view";
    } else if (syncInProgress()) {
        qCCritical(PlanMasterControllerLog) << "PlanMasterController::loadFromVehicle called while syncInProgress";
    } else {
        _loadGeoFence = true;
        _loadRallyPoints = false;
        _loadFromVehicleInProgress = true;
        _loadFromVehicleGeneration = _remotePlanStateGeneration;
        _pendingVehiclePlanLoad = false;
        qCDebug(PlanMasterControllerLog) << "PlanMasterController::loadFromVehicle calling _missionController.loadFromVehicle";
        _missionController.loadFromVehicle();
    }
}


void PlanMasterController::_loadMissionComplete(void)
{
    if (!_flyView && _loadFromVehicleInProgress && _loadGeoFence) {
        _loadGeoFence = false;
        _loadRallyPoints = true;
        if (_geoFenceController.supported()) {
            qCDebug(PlanMasterControllerLog) << "PlanMasterController::_loadMissionComplete calling _geoFenceController.loadFromVehicle";
            _geoFenceController.loadFromVehicle();
        } else {
            qCDebug(PlanMasterControllerLog) << "PlanMasterController::_loadMissionComplete GeoFence not supported skipping";
            _geoFenceController.removeAll();
            _loadGeoFenceComplete();
        }
    }
}

void PlanMasterController::_loadGeoFenceComplete(void)
{
    if (!_flyView && _loadFromVehicleInProgress && _loadRallyPoints) {
        _loadRallyPoints = false;
        if (_rallyPointController.supported()) {
            qCDebug(PlanMasterControllerLog) << "PlanMasterController::_loadGeoFenceComplete calling _rallyPointController.loadFromVehicle";
            _rallyPointController.loadFromVehicle();
        } else {
            qCDebug(PlanMasterControllerLog) << "PlanMasterController::_loadMissionComplete Rally Points not supported skipping";
            _rallyPointController.removeAll();
            _loadRallyPointsComplete();
        }
    }
}

void PlanMasterController::_loadRallyPointsComplete(void)
{
    qCDebug(PlanMasterControllerLog) << "PlanMasterController::_loadRallyPointsComplete";

    const bool explicitLoadCompleted = _loadFromVehicleInProgress;
    const bool pendingVehiclePlanLoadCompleted = _pendingVehiclePlanLoad;
    if (!explicitLoadCompleted && !pendingVehiclePlanLoadCompleted) {
        return;
    }

    const bool loadStillCurrent = explicitLoadCompleted
            ? (_loadFromVehicleGeneration == _remotePlanStateGeneration)
            : _pendingVehiclePlanLoadStillCurrent();
    _clearLoadTracking();

    if (!loadStillCurrent) {
        qCWarning(PlanMasterControllerLog) << "Ignoring stale vehicle plan load completion";
        return;
    }

    _setDirtyStates(containsItems() /* dirtyForSave */, false /* dirtyForUpload */);
    if (!offline() && _managerVehicle && _managerVehicle->vehicleUID() != 0) {
        _setPlanVehicleIdentity(true, _managerVehicle->vehicleUID());
    }
    _setRemotePlanStateKnown(true);
}

void PlanMasterController::_managerPlanError(int errorCode, const QString& errorMsg)
{
    Q_UNUSED(errorCode)

    if (!_loadFromVehicleInProgress && !_pendingVehiclePlanLoad) {
        return;
    }

    qCWarning(PlanMasterControllerLog) << "Vehicle plan load failed" << errorMsg;
    _clearLoadTracking();
    _setRemotePlanStateKnown(false);
}

void PlanMasterController::_sendMissionComplete(void)
{
    _sendMissionComplete(false);
}

void PlanMasterController::_sendMissionComplete(bool error)
{
    if (!_sendToVehicleInProgress) {
        return;
    }

    if (error) {
        _finishSendSequence(true, tr("Mission upload failed. Vehicle plan state may be partially changed."));
        return;
    }

    if (_sendGeoFence) {
        _sendGeoFence = false;
        _sendRallyPoints = true;
        const bool geoFenceUploadNeeded = _geoFenceController.containsItems() || _geoFenceController.dirty();
        if (!_geoFenceController.supported() && geoFenceUploadNeeded) {
            _finishSendSequence(true, tr("GeoFence upload failed. Current vehicle does not support GeoFence mission items."));
        } else if (geoFenceUploadNeeded) {
            qCDebug(PlanMasterControllerLog) << "PlanMasterController::sendToVehicle start GeoFence sendToVehicle";
            _geoFenceController.sendToVehicle();
        } else {
            qCDebug(PlanMasterControllerLog) << "PlanMasterController::sendToVehicle GeoFence empty or not supported skipping";
            _sendGeoFenceComplete(false);
        }
    }
}

void PlanMasterController::_sendGeoFenceComplete(void)
{
    _sendGeoFenceComplete(false);
}

void PlanMasterController::_sendGeoFenceComplete(bool error)
{
    if (!_sendToVehicleInProgress) {
        return;
    }

    if (error) {
        _finishSendSequence(true, tr("GeoFence upload failed. Vehicle plan state may be partially changed."));
        return;
    }

    if (_sendRallyPoints) {
        _sendRallyPoints = false;
        const bool rallyPointUploadNeeded = _rallyPointController.containsItems() || _rallyPointController.dirty();
        if (!_rallyPointController.supported() && rallyPointUploadNeeded) {
            _finishSendSequence(true, tr("Rally point upload failed. Current vehicle does not support rally point mission items."));
        } else if (rallyPointUploadNeeded) {
            qCDebug(PlanMasterControllerLog) << "PlanMasterController::sendToVehicle start rally sendToVehicle";
            _rallyPointController.sendToVehicle();
        } else {
            qCDebug(PlanMasterControllerLog) << "PlanMasterController::sendToVehicle Rally Points empty or not supported skipping";
            _sendRallyPointsComplete(false);
        }
    }
}

void PlanMasterController::_sendRallyPointsComplete(void)
{
    _sendRallyPointsComplete(false);
}

void PlanMasterController::_sendRallyPointsComplete(bool error)
{
    if (!_sendToVehicleInProgress) {
        return;
    }

    if (error) {
        _finishSendSequence(true, tr("Rally point upload failed. Vehicle plan state may be partially changed."));
        return;
    }

    _finishSendSequence(false);
}

void PlanMasterController::_finishSendSequence(bool error, const QString& errorMessage)
{
    _sendToVehicleInProgress = false;
    _sendGeoFence = false;
    _sendRallyPoints = false;

    if (error) {
        qCWarning(PlanMasterControllerLog) << "Plan send failed" << errorMessage;
        _setDirtyForUpload(true);
        _setRemotePlanStateKnown(false);
        if (!errorMessage.isEmpty()) {
            qgcApp()->showAppMessage(errorMessage);
        }
    } else {
        qCDebug(PlanMasterControllerLog) << "PlanMasterController::sendToVehicle send complete";
        _setDirtyForUpload(false);
        if (!offline() && _managerVehicle && _managerVehicle->vehicleUID() != 0) {
            _setPlanVehicleIdentity(true, _managerVehicle->vehicleUID());
        }
        _setRemotePlanStateKnown(true);
    }

    if (_deleteWhenSendCompleted) {
        this->deleteLater();
    }
}

void PlanMasterController::sendToVehicle(void)
{
    const MissionController::SendToVehiclePreCheckState preCheckState = _missionController.sendToVehiclePreCheck(true /* allowFirmwareVehicleMismatch */);
    if (preCheckState != MissionController::SendToVehiclePreCheckStateOk) {
        const QString failureMessage = _missionController.sendToVehiclePreCheckFailureMessage();
        qCWarning(PlanMasterControllerLog) << "PlanMasterController::sendToVehicle blocked by precheck" << preCheckState << failureMessage;
        qgcApp()->showAppMessage(failureMessage.isEmpty() ? tr("Unable to upload plan to vehicle.") : failureMessage);
        return;
    }

    SharedLinkInterfacePtr sharedLink = _managerVehicle->vehicleLinkManager()->primaryLink().lock();
    if (sharedLink) {
        if (sharedLink->linkConfiguration()->isHighLatency()) {
            qgcApp()->showAppMessage(tr("Upload not supported on high latency links."));
            return;
        }
    } else {
        // Vehicle is shutting down
        return;
    }

    if (offline()) {
        qCCritical(PlanMasterControllerLog) << "PlanMasterController::sendToVehicle called while offline";
    } else if (syncInProgress()) {
        qCCritical(PlanMasterControllerLog) << "PlanMasterController::sendToVehicle called while syncInProgress";
    } else {
        qCDebug(PlanMasterControllerLog) << "PlanMasterController::sendToVehicle start mission sendToVehicle";
        _sendToVehicleInProgress = true;
        _sendGeoFence = true;
        _sendRallyPoints = false;
        _missionController.sendToVehicle();
    }
}

bool PlanMasterController::_loadPlanJson(const QJsonObject& json, QString& errorString)
{
    if (!_missionController.load(json[kJsonMissionObjectKey].toObject(), errorString)) {
        return false;
    }
    if (!_geoFenceController.load(json[kJsonGeoFenceObjectKey].toObject(), errorString)) {
        return false;
    }
    if (!_rallyPointController.load(json[kJsonRallyPointsObjectKey].toObject(), errorString)) {
        return false;
    }

    return true;
}

bool PlanMasterController::_loadPlanIdentity(const QJsonObject& json, bool& identityAvailable, quint64& vehicleUid, QString& errorString) const
{
    identityAvailable = false;
    vehicleUid = 0;

    if (!json.contains(kJsonBtfwObjectKey)) {
        return true;
    }

    if (!json[kJsonBtfwObjectKey].isObject()) {
        errorString = tr("BTFW plan identity is not stored as an object.");
        return false;
    }

    const QJsonObject btfwJson = json[kJsonBtfwObjectKey].toObject();
    if (!btfwJson.contains(kJsonBtfwIdentityVersionKey) || !btfwJson.contains(kJsonBtfwVehicleUidKey)) {
        errorString = tr("BTFW plan identity is missing required fields.");
        return false;
    }
    if (btfwJson[kJsonBtfwIdentityVersionKey].toInt() != kBtfwIdentityVersion) {
        errorString = tr("BTFW plan identity version %1 is not supported.").arg(btfwJson[kJsonBtfwIdentityVersionKey].toInt());
        return false;
    }

    bool conversionOk = false;
    const QJsonValue uidValue = btfwJson[kJsonBtfwVehicleUidKey];
    const quint64 parsedUid = uidValue.isString()
        ? uidValue.toString().toULongLong(&conversionOk)
        : uidValue.toVariant().toULongLong(&conversionOk);
    if (!conversionOk) {
        errorString = tr("BTFW plan vehicle identity is invalid.");
        return false;
    }

    if (parsedUid != 0) {
        identityAvailable = true;
        vehicleUid = parsedUid;
    }

    return true;
}

void PlanMasterController::loadFromFile(const QString& filename)
{
    QString errorString;
    QString errorMessage = tr("Error loading Plan file (%1). %2").arg(filename).arg("%1");

    if (filename.isEmpty()) {
        return;
    }

    QFileInfo fileInfo(filename);
    QFile file(filename);

    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        errorString = file.errorString() + QStringLiteral(" ") + filename;
        qgcApp()->showAppMessage(errorMessage.arg(errorString));
        return;
    }

    bool success = false;
    if (fileInfo.suffix() == AppSettings::waypointsFileExtension || fileInfo.suffix() == QStringLiteral("txt")) {
        if (!_missionController.loadTextFile(file, errorString)) {
            qgcApp()->showAppMessage(errorMessage.arg(errorString));
        } else {
            _setPlanVehicleIdentity(false, 0);
            success = true;
        }
    } else {
        QJsonDocument   jsonDoc;
        QByteArray      bytes = file.readAll();

        if (!JsonParsing::isJsonFile(bytes, jsonDoc, errorString)) {
            qgcApp()->showAppMessage(errorMessage.arg(errorString));
            return;
        }

        QJsonObject json = jsonDoc.object();
        //-- Allow plugins to pre process the load
        QGCCorePlugin::instance()->preLoadFromJson(this, json);

        int version;
        if (!JsonHelper::validateExternalQGCJsonFile(json, kPlanFileType, kPlanFileVersion, kPlanFileVersion, version, errorString)) {
            qgcApp()->showAppMessage(errorMessage.arg(errorString));
            return;
        }

        QList<JsonHelper::KeyValidateInfo> rgKeyInfo = {
            { kJsonMissionObjectKey,        QJsonValue::Object, true },
            { kJsonGeoFenceObjectKey,       QJsonValue::Object, true },
            { kJsonRallyPointsObjectKey,    QJsonValue::Object, true },
        };
        if (!JsonHelper::validateKeys(json, rgKeyInfo, errorString)) {
            qgcApp()->showAppMessage(errorMessage.arg(errorString));
            return;
        }

        bool loadedIdentityAvailable = false;
        quint64 loadedVehicleUid = 0;
        if (!_loadPlanIdentity(json, loadedIdentityAvailable, loadedVehicleUid, errorString)) {
            qgcApp()->showAppMessage(errorMessage.arg(errorString));
            return;
        }

        const QJsonObject previousPlan = saveToJson().object();
        const bool previousIdentityAvailable = _planVehicleIdentityAvailable;
        const quint64 previousVehicleUid = _planVehicleUid;
        const bool previousManualCreation = _manualCreation;
        const bool previousMissionDirty = _missionController.dirty();
        const bool previousGeoFenceDirty = _geoFenceController.dirty();
        const bool previousRallyPointDirty = _rallyPointController.dirty();
        const bool previousDirtyForSave = _dirtyForSave;
        const bool previousDirtyForUpload = _dirtyForUpload;

        _suppressOverallDirtyUpdate = true;
        if (!_loadPlanJson(json, errorString)) {
            QString restoreError;
            if (!_loadPlanJson(previousPlan, restoreError)) {
                qCCritical(PlanMasterControllerLog) << "Unable to restore plan after load failure:" << restoreError;
            }
            _missionController.setDirty(previousMissionDirty);
            _geoFenceController.setDirty(previousGeoFenceDirty);
            _rallyPointController.setDirty(previousRallyPointDirty);
            _setDirtyStates(previousDirtyForSave, previousDirtyForUpload);
            _setPlanVehicleIdentity(previousIdentityAvailable, previousVehicleUid);
            setManualCreation(previousManualCreation);
            _suppressOverallDirtyUpdate = false;
            qgcApp()->showAppMessage(errorMessage.arg(errorString));
        } else {
            //-- Allow plugins to post process the load
            QGCCorePlugin::instance()->postLoadFromJson(this, json);
            _setPlanVehicleIdentity(loadedIdentityAvailable, loadedVehicleUid);
            _suppressOverallDirtyUpdate = false;
            success = true;
        }
    }

    if (success){
        const bool oldRenamed = planFileRenamed();
        _currentPlanFile = QString::asprintf("%s/%s.%s", fileInfo.path().toLocal8Bit().data(), fileInfo.completeBaseName().toLocal8Bit().data(), AppSettings::planFileExtension);
        const bool currentNameChanged = (_currentPlanFileName != fileInfo.completeBaseName());
        const bool originalNameChanged = (_originalPlanFileName != fileInfo.completeBaseName());
        _currentPlanFileName = fileInfo.completeBaseName();
        _originalPlanFileName = _currentPlanFileName;
        _setDirtyStates(false /* dirtyForSave */, true /* dirtyForUpload */);
        emit currentPlanFileChanged();
        if (currentNameChanged) {
            emit currentPlanFileNameChanged();
        }
        if (originalNameChanged) {
            emit originalPlanFileNameChanged();
        }
        if (oldRenamed != planFileRenamed()) {
            emit planFileRenamedChanged();
        }
    }
}

QJsonDocument PlanMasterController::saveToJson()
{
    QJsonObject planJson;
    QGCCorePlugin::instance()->preSaveToJson(this, planJson);
    QJsonObject missionJson;
    QJsonObject fenceJson;
    QJsonObject rallyJson;
    JsonHelper::saveQGCJsonFileHeader(planJson, kPlanFileType, kPlanFileVersion);
    //-- Allow plugin to preemptly add its own keys to mission
    QGCCorePlugin::instance()->preSaveToMissionJson(this, missionJson);
    _missionController.save(missionJson);
    //-- Allow plugin to add its own keys to mission
    QGCCorePlugin::instance()->postSaveToMissionJson(this, missionJson);
    _geoFenceController.save(fenceJson);
    _rallyPointController.save(rallyJson);
    planJson[kJsonMissionObjectKey] = missionJson;
    planJson[kJsonGeoFenceObjectKey] = fenceJson;
    planJson[kJsonRallyPointsObjectKey] = rallyJson;
    if (_planVehicleIdentityAvailable && _planVehicleUid != 0) {
        QJsonObject btfwJson;
        btfwJson[kJsonBtfwIdentityVersionKey] = kBtfwIdentityVersion;
        btfwJson[kJsonBtfwVehicleUidKey] = QString::number(_planVehicleUid);
        planJson[kJsonBtfwObjectKey] = btfwJson;
    } else if (_boundVehicle && _boundVehicle->vehicleUID() != 0) {
        QJsonObject btfwJson;
        btfwJson[kJsonBtfwIdentityVersionKey] = kBtfwIdentityVersion;
        btfwJson[kJsonBtfwVehicleUidKey] = QString::number(_boundVehicle->vehicleUID());
        planJson[kJsonBtfwObjectKey] = btfwJson;
    }
    QGCCorePlugin::instance()->postSaveToJson(this, planJson);
    return QJsonDocument(planJson);
}

bool
PlanMasterController::saveToCurrent()
{
    if (!_currentPlanFile.isEmpty()) {
        const bool saveSuccess = saveToFile(_currentPlanFile);
        return saveSuccess;
    }

    return false;
}

bool PlanMasterController::saveToFile(const QString& filename)
{
    if (filename.isEmpty()) {
        return false;
    }

    QString planFilename = filename;
    if (!QFileInfo(filename).fileName().contains(".")) {
        planFilename += QString(".%1").arg(fileExtension());
    }

    QFile file(planFilename);

    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qgcApp()->showAppMessage(tr("Plan save error %1 : %2").arg(filename).arg(file.errorString()));
        return false;
    } else {
        const QByteArray saveBytes = saveToJson().toJson();
        const qint64 bytesWritten = file.write(saveBytes);
        if (bytesWritten != saveBytes.size()) {
            qgcApp()->showAppMessage(tr("Plan save error %1 : %2").arg(filename).arg(file.errorString()));
            return false;
        }
        if(_currentPlanFile != planFilename) {
            _currentPlanFile = planFilename;
            emit currentPlanFileChanged();
        }
        const bool wasRenamed = planFileRenamed();
        const QString savedBaseName = QFileInfo(planFilename).completeBaseName();
        if (_currentPlanFileName != savedBaseName) {
            _currentPlanFileName = savedBaseName;
            emit currentPlanFileNameChanged();
        }
        if (_originalPlanFileName != savedBaseName) {
            _originalPlanFileName = savedBaseName;
            emit originalPlanFileNameChanged();
        }
        if (wasRenamed != planFileRenamed()) {
            emit planFileRenamedChanged();
        }
        _setDirtyForSave(false);
    }

    return true;
}

void PlanMasterController::saveToKml(const QString& filename)
{
    if (filename.isEmpty()) {
        return;
    }

    QString kmlFilename = filename;
    if (!QFileInfo(filename).fileName().contains(".")) {
        kmlFilename += QString(".%1").arg(kmlFileExtension());
    }

    QFile file(kmlFilename);

    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qgcApp()->showAppMessage(tr("KML save error %1 : %2").arg(filename).arg(file.errorString()));
    } else {
        KMLPlanDomDocument planKML;
        _missionController.addMissionToKML(planKML);
        QTextStream stream(&file);
        stream << planKML.toString();
        file.close();
    }
}

void PlanMasterController::removeAll(void)
{
    _suppressOverallDirtyUpdate = true;
    _missionController.removeAll();
    _geoFenceController.removeAll();
    _rallyPointController.removeAll();
    _missionController.setDirty(false);
    _geoFenceController.setDirty(false);
    _rallyPointController.setDirty(false);
    _suppressOverallDirtyUpdate = false;

    _setDirtyStates(false, false);
    _setPlanVehicleIdentity(false, 0);
    if (_offline) {
        _clearFileNames();
    }
    setManualCreation(false);
}

void PlanMasterController::removeMissionFromVehicle(void)
{
    if (offline()) {
        qCCritical(PlanMasterControllerLog) << "PlanMasterController::removeMissionFromVehicle called while offline";
        return;
    }

    if (syncInProgress()) {
        qCCritical(PlanMasterControllerLog) << "PlanMasterController::removeMissionFromVehicle called while syncInProgress";
        return;
    }

    _removeMissionFromVehicleInProgress = true;
    emit removeMissionFromVehicleInProgressChanged();
    emit syncInProgressChanged();

    _missionController.removeAllFromVehicle();
}

void PlanMasterController::removeAllFromVehicle(void)
{
    if (offline()) {
        qCCritical(PlanMasterControllerLog) << "PlanMasterController::removeAllFromVehicle called while offline";
        return;
    }

    if (syncInProgress()) {
        qCCritical(PlanMasterControllerLog) << "PlanMasterController::removeAllFromVehicle called while syncInProgress";
        return;
    }

    GeoFenceManager* geoFenceManager = _managerVehicle ? _managerVehicle->geoFenceManager() : nullptr;
    RallyPointManager* rallyPointManager = _managerVehicle ? _managerVehicle->rallyPointManager() : nullptr;
    const bool planRequestComplete = _managerVehicle ? _managerVehicle->initialPlanRequestComplete() : false;
    const bool geoFenceKnownEmpty = geoFenceManager &&
                                    geoFenceManager->polygons().isEmpty() &&
                                    geoFenceManager->circles().isEmpty() &&
                                    !geoFenceManager->breachReturnPoint().isValid() &&
                                    _geoFenceController.isEmpty();
    const bool rallyPointsKnownEmpty = rallyPointManager &&
                                       rallyPointManager->points().isEmpty() &&
                                       _rallyPointController.isEmpty();

    _removeAllGeoFence = _geoFenceController.supported() && (!planRequestComplete || !geoFenceKnownEmpty);
    _removeAllRallyPoints = _rallyPointController.supported() && (!planRequestComplete || !rallyPointsKnownEmpty);
    _removeAllFromVehicleInProgress = true;
    emit removeAllFromVehicleInProgressChanged();
    emit syncInProgressChanged();

    _missionController.removeAllFromVehicle();
}

void PlanMasterController::_removeMissionComplete(bool error)
{
    if (_removeMissionFromVehicleInProgress) {
        _finishRemoveMissionFromVehicle(error, tr("Mission clear failed. Vehicle mission state is unknown."));
        return;
    }

    if (!_removeAllFromVehicleInProgress) {
        return;
    }
    if (error) {
        _finishRemoveAllFromVehicle(true, tr("Mission clear failed. Vehicle plan state is unknown."));
        return;
    }

    if (_removeAllGeoFence) {
        _removeAllGeoFence = false;
        _geoFenceController.removeAllFromVehicle();
    } else {
        _removeGeoFenceComplete(false);
    }
}

void PlanMasterController::_finishRemoveMissionFromVehicle(bool error, const QString& errorMessage)
{
    if (!_removeMissionFromVehicleInProgress) {
        return;
    }

    const bool wasSyncing = syncInProgress();
    _removeMissionFromVehicleInProgress = false;
    emit removeMissionFromVehicleInProgressChanged();

    if (error) {
        _setRemotePlanStateKnown(false);
        if (!errorMessage.isEmpty()) {
            qgcApp()->showAppMessage(errorMessage);
        }
    } else {
        _suppressOverallDirtyUpdate = true;
        _missionController.removeAll();
        _missionController.setDirty(false);
        _suppressOverallDirtyUpdate = false;

        // The vehicle now matches the Mission editor. Keep other plan elements
        // intact, but mark the changed local plan as needing a save.
        _setDirtyStates(true, false);
        _setRemotePlanStateKnown(true);
        setManualCreation(false);
        emit containsItemsChanged();
    }

    if (wasSyncing != syncInProgress()) {
        emit syncInProgressChanged();
    }
}

void PlanMasterController::_removeGeoFenceComplete(bool error)
{
    if (!_removeAllFromVehicleInProgress) {
        return;
    }
    if (error) {
        _finishRemoveAllFromVehicle(true, tr("GeoFence clear failed. Vehicle plan state is unknown."));
        return;
    }

    if (_removeAllRallyPoints) {
        _removeAllRallyPoints = false;
        _rallyPointController.removeAllFromVehicle();
    } else {
        _removeRallyPointsComplete(false);
    }
}

void PlanMasterController::_removeRallyPointsComplete(bool error)
{
    if (!_removeAllFromVehicleInProgress) {
        return;
    }
    if (error) {
        _finishRemoveAllFromVehicle(true, tr("Rally point clear failed. Vehicle plan state is unknown."));
        return;
    }

    _finishRemoveAllFromVehicle(false);
}

void PlanMasterController::_finishRemoveAllFromVehicle(bool error, const QString& errorMessage)
{
    _removeAllGeoFence = false;
    _removeAllRallyPoints = false;

    if (_removeAllFromVehicleInProgress) {
        _removeAllFromVehicleInProgress = false;
        emit removeAllFromVehicleInProgressChanged();
        emit syncInProgressChanged();
    }

    if (error) {
        _setDirtyForUpload(containsItems());
        _setRemotePlanStateKnown(false);
        if (!errorMessage.isEmpty()) {
            qgcApp()->showAppMessage(errorMessage);
        }
        return;
    }

    _suppressOverallDirtyUpdate = true;
    _missionController.removeAll();
    _geoFenceController.removeAll();
    _rallyPointController.removeAll();
    _missionController.setDirty(false);
    _geoFenceController.setDirty(false);
    _rallyPointController.setDirty(false);
    _suppressOverallDirtyUpdate = false;

    _setDirtyStates(false, false);
    _setPlanVehicleIdentity(false, 0);
    _setRemotePlanStateKnown(true);
    _clearFileNames();
    setManualCreation(false);
    emit containsItemsChanged();
}

bool PlanMasterController::containsItems(void) const
{
    return _missionController.containsItems() || _geoFenceController.containsItems() || _rallyPointController.containsItems();
}

QString PlanMasterController::fileExtension(void) const
{
    return AppSettings::planFileExtension;
}

void PlanMasterController::setCurrentPlanFileName(const QString& name)
{
    // Normalize to a base name: trim whitespace, strip known extension, remove illegal characters
    QString sanitized = name.trimmed();
    const QString ext = QStringLiteral(".") + fileExtension();
    if (sanitized.endsWith(ext, Qt::CaseInsensitive)) {
        sanitized.chop(ext.length());
        sanitized = sanitized.trimmed();
    }
    sanitized.remove(QRegularExpression(QStringLiteral("[/\\\\:*?\"<>|]")));
    if (_currentPlanFileName != sanitized) {
        const bool wasRenamed = planFileRenamed();
        _currentPlanFileName = sanitized;
        emit currentPlanFileNameChanged();
        if (wasRenamed != planFileRenamed()) {
            emit planFileRenamedChanged();
        }
    }
}

bool PlanMasterController::saveWithCurrentName()
{
    if (_currentPlanFileName.isEmpty()) {
        return false;
    }
    return saveToFile(_resolvedPlanFilePath());
}

bool PlanMasterController::planFileRenamed() const
{
    return !_originalPlanFileName.isEmpty() && _currentPlanFileName != _originalPlanFileName;
}

bool PlanMasterController::resolvedPlanFileExists() const
{
    if (_currentPlanFileName.isEmpty()) {
        return false;
    }
    return QFile::exists(_resolvedPlanFilePath());
}

QString PlanMasterController::_resolvedPlanFilePath() const
{
    const QString dir = _currentPlanFile.isEmpty()
        ? SettingsManager::instance()->appSettings()->missionSavePath()
        : QFileInfo(_currentPlanFile).path();
    return QStringLiteral("%1/%2.%3").arg(dir, _currentPlanFileName, fileExtension());
}

void PlanMasterController::_clearFileNames()
{
    const bool hadFile = !_currentPlanFile.isEmpty();
    const bool hadCurrentName = !_currentPlanFileName.isEmpty();
    const bool hadOriginalName = !_originalPlanFileName.isEmpty();
    const bool wasRenamed = planFileRenamed();
    _currentPlanFile.clear();
    _currentPlanFileName.clear();
    _originalPlanFileName.clear();
    if (hadFile) {
        emit currentPlanFileChanged();
    }
    if (hadCurrentName) {
        emit currentPlanFileNameChanged();
    }
    if (hadOriginalName) {
        emit originalPlanFileNameChanged();
    }
    if (wasRenamed != planFileRenamed()) {
        emit planFileRenamedChanged();
    }
}

QString PlanMasterController::kmlFileExtension(void) const
{
    return AppSettings::kmlFileExtension;
}

QStringList PlanMasterController::loadNameFilters(void) const
{
    QStringList filters;

    filters << tr("Supported types (*.%1 *.%2 *.%3)").arg(AppSettings::planFileExtension).arg(AppSettings::waypointsFileExtension).arg("txt") <<
               tr("All Files (*)");
    return filters;
}


QStringList PlanMasterController::saveNameFilters(void) const
{
    QStringList filters;

    filters << tr("Plan Files (*.%1)").arg(fileExtension()) << tr("All Files (*)");
    return filters;
}

void PlanMasterController::sendPlanToVehicle(Vehicle* vehicle, const QString& filename)
{
    // Use a transient PlanMasterController to accomplish this
    PlanMasterController* controller = new PlanMasterController();
    controller->startStaticActiveVehicle(vehicle, true /* deleteWhenSendCompleted */);
    controller->loadFromFile(filename);
    controller->sendToVehicle();
}

void PlanMasterController::_showPlanFromManagerVehicle(void)
{
    if (_managerVehicle->genericFirmware()) {
        qCDebug(PlanMasterControllerLog) << "_showPlanFromManagerVehicle: generic firmware, skipping plan load from vehicle";
        _setDirtyStates(containsItems() /* dirtyForSave */, containsItems() /* dirtyForUpload */);
        return;
    }

    if (!_managerVehicle->initialPlanRequestComplete()) {
        // We need to wait until initial load is complete before we show anything.
        _pendingVehiclePlanLoad = true;
        _pendingVehiclePlanLoadGeneration = _remotePlanStateGeneration;
        return;
    }

    // The crazy if structure is to handle the load propagating by itself through the system
    if (!_missionController.showPlanFromManagerVehicle()) {
        if (!_geoFenceController.showPlanFromManagerVehicle()) {
            _rallyPointController.showPlanFromManagerVehicle();
        }
    }

    // Showing the vehicle plan should leave both dirty states clean.
    _missionController.setDirty(false);
    _geoFenceController.setDirty(false);
    _rallyPointController.setDirty(false);
    _setDirtyStates(false, false);
    if (!_managerVehicle->isOfflineEditingVehicle() && _managerVehicle->vehicleUID() != 0) {
        _setPlanVehicleIdentity(true, _managerVehicle->vehicleUID());
    }
    _setRemotePlanStateKnown(true);
}

bool PlanMasterController::syncInProgress(void) const
{
    return _removeMissionFromVehicleInProgress ||
            _removeAllFromVehicleInProgress ||
            _missionController.syncInProgress() ||
            _geoFenceController.syncInProgress() ||
            _rallyPointController.syncInProgress();
}

bool PlanMasterController::isEmpty(void) const
{
    return _missionController.isEmpty() &&
            _geoFenceController.isEmpty() &&
            _rallyPointController.isEmpty();
}

void PlanMasterController::_setPlanVehicleIdentity(bool identityAvailable, quint64 vehicleUid)
{
    if (!identityAvailable) {
        vehicleUid = 0;
    }

    if (_planVehicleIdentityAvailable != identityAvailable || _planVehicleUid != vehicleUid) {
        _planVehicleIdentityAvailable = identityAvailable;
        _planVehicleUid = vehicleUid;
        emit planVehicleIdentityChanged();
    }
}

void PlanMasterController::_setRemotePlanStateKnown(bool remotePlanStateKnown)
{
    if (!remotePlanStateKnown) {
        _remotePlanStateGeneration++;
        _clearLoadTracking();
    }

    if (_remotePlanStateKnown != remotePlanStateKnown) {
        _remotePlanStateKnown = remotePlanStateKnown;
        emit remotePlanStateKnownChanged();
    }
}

void PlanMasterController::_clearLoadTracking(void)
{
    _loadGeoFence = false;
    _loadRallyPoints = false;
    _loadFromVehicleInProgress = false;
    _pendingVehiclePlanLoad = false;
}

bool PlanMasterController::_pendingVehiclePlanLoadStillCurrent(void) const
{
    return _pendingVehiclePlanLoad && _pendingVehiclePlanLoadGeneration == _remotePlanStateGeneration;
}

void PlanMasterController::_updateOverallDirty(void)
{
    if (syncInProgress() || _suppressOverallDirtyUpdate) {
        return;
    }

    const bool saveDirty = _missionController.dirty() || _geoFenceController.dirty() || _rallyPointController.dirty();
    if (saveDirty) {
        _setDirtyForSave(true);
    }
}

void PlanMasterController::_setDirtyForSave(bool dirtyForSave)
{
    if (_dirtyForSave != dirtyForSave) {
        _dirtyForSave = dirtyForSave;
        emit dirtyForSaveChanged(_dirtyForSave);

        if (_dirtyForSave) {
            _setDirtyForUpload(true);
        }
    }
}

void PlanMasterController::_setDirtyForUpload(bool dirtyForUpload)
{
    if (_dirtyForUpload != dirtyForUpload) {
        _dirtyForUpload = dirtyForUpload;
        emit dirtyForUploadChanged(_dirtyForUpload);
    }
}

void PlanMasterController::_setDirtyStates(bool dirtyForSave, bool dirtyForUpload)
{
    const bool saveChanged = (_dirtyForSave != dirtyForSave);
    const bool uploadChanged = (_dirtyForUpload != dirtyForUpload);

    _dirtyForSave = dirtyForSave;
    _dirtyForUpload = dirtyForUpload;

    if (saveChanged) {
        emit dirtyForSaveChanged(_dirtyForSave);
    }
    if (uploadChanged) {
        emit dirtyForUploadChanged(_dirtyForUpload);
    }
}

void PlanMasterController::_updatePlanCreatorsList(void)
{
    if (!_flyView) {
        if (!_planCreators) {
            _planCreators = new QmlObjectListModel(this);
            _planCreators->append(new BlankPlanCreator(this, this));
            _planCreators->append(new SurveyPlanCreator(this, this));
            _planCreators->append(new CorridorScanPlanCreator(this, this));
            emit planCreatorsChanged(_planCreators);
        }

        if (_managerVehicle->fixedWing()) {
            if (_planCreators->count() == 4) {
                _planCreators->removeAt(_planCreators->count() - 1);
            }
        } else {
            if (_planCreators->count() != 4) {
                _planCreators->append(new StructureScanPlanCreator(this, this));
            }
        }
    }
}

void PlanMasterController::showPlanFromManagerVehicle(void)
{
    if (offline()) {
        // There is no new vehicle so clear any previous plan
        qCDebug(PlanMasterControllerLog) << "showPlanFromManagerVehicle: Plan View - No new vehicle, clear any previous plan";
        removeAll();
    } else {
        // We have a new active vehicle, show the plan from that
        qCDebug(PlanMasterControllerLog) << "showPlanFromManagerVehicle: Plan View - New vehicle available, show plan from new manager vehicle";
        _showPlanFromManagerVehicle();
    }
}

void PlanMasterController::setManualCreation(bool manualCreation)
{
    if (_manualCreation != manualCreation) {
        _manualCreation = manualCreation;
        emit manualCreationChanged();
    }
}

void PlanMasterController::loadFromArchive(const QString& archivePath)
{
    if (archivePath.isEmpty()) {
        return;
    }

    if (!QFile::exists(archivePath)) {
        qgcApp()->showAppMessage(tr("Archive file not found: %1").arg(archivePath));
        return;
    }

    if (!QGCCompression::isArchiveFile(archivePath)) {
        qgcApp()->showAppMessage(tr("Not a supported archive format: %1").arg(archivePath));
        return;
    }

    const QString tempPath = QDir::temp().filePath(QStringLiteral("qgc_plan_") + QString::number(QDateTime::currentMSecsSinceEpoch()));
    if (!QDir().mkpath(tempPath)) {
        qgcApp()->showAppMessage(tr("Could not create temporary directory"));
        return;
    }

    _extractionOutputDir = tempPath;

    if (_extractionJob == nullptr) {
        _extractionJob = new QGCCompressionJob(this);
        connect(_extractionJob, &QGCCompressionJob::finished,
                this, &PlanMasterController::_handleExtractionFinished);
    }

    _extractionJob->extractArchive(archivePath, tempPath);
}

void PlanMasterController::_handleExtractionFinished(bool success)
{
    if (!success) {
        const QString error = _extractionJob != nullptr ? _extractionJob->errorString() : tr("Extraction failed");
        qgcApp()->showAppMessage(tr("Failed to extract plan archive: %1").arg(error));
        QDir(_extractionOutputDir).removeRecursively();
        _extractionOutputDir.clear();
        return;
    }

    QString planPath;
    const QString planExt = QStringLiteral("*.") + AppSettings::planFileExtension;
    QDirIterator it(_extractionOutputDir, {planExt}, QDir::Files, QDirIterator::Subdirectories);
    if (it.hasNext()) {
        planPath = it.next();
    }

    if (planPath.isEmpty()) {
        qgcApp()->showAppMessage(tr("No plan file found in archive"));
        QDir(_extractionOutputDir).removeRecursively();
        _extractionOutputDir.clear();
        return;
    }

    qCDebug(PlanMasterControllerLog) << "Found plan file in archive:" << planPath;
    loadFromFile(planPath);

    QDir(_extractionOutputDir).removeRecursively();
    _extractionOutputDir.clear();
}
