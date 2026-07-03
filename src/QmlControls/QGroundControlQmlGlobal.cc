#include "QGroundControlQmlGlobal.h"

#include "QGCApplication.h"
#include "QGCCorePlugin.h"
#include "LinkManager.h"
#include "MAVLinkProtocol.h"
#include "FirmwarePluginManager.h"
#include "AppSettings.h"
#include "FlightMapSettings.h"
#include "SettingsManager.h"
#include "PositionManager.h"
#include "QGCMapEngineManager.h"
#include "ADSBVehicleManager.h"
#include "AudioOutput.h"
#include "NTRIPManager.h"
#include "MAVLinkSigningKeys.h"
#include "MissionCommandTree.h"
#include "VideoManager.h"
#include "MultiVehicleManager.h"
#include "QGCLoggingCategory.h"
#ifndef QGC_NO_SERIAL_LINK
#include "GPSManager.h"
#include "GPSRtk.h"
#endif
#ifdef QT_DEBUG
#include "MockLink.h"
#endif

#include <QtCore/QSettings>
#include <QtCore/QLineF>
#include <QtCore/QVariant>
#include <QtMath>

namespace
{
constexpr double kChinaPi = 3.1415926535897932384626;
constexpr double kChinaSemiMajorAxis = 6378245.0;
constexpr double kChinaEccentricitySquared = 0.00669342162296594323;

double transformLatitude(double x, double y)
{
    double result = -100.0 + (2.0 * x) + (3.0 * y) + (0.2 * y * y) + (0.1 * x * y) + (0.2 * qSqrt(qAbs(x)));
    result += ((20.0 * qSin(6.0 * x * kChinaPi)) + (20.0 * qSin(2.0 * x * kChinaPi))) * 2.0 / 3.0;
    result += ((20.0 * qSin(y * kChinaPi)) + (40.0 * qSin((y / 3.0) * kChinaPi))) * 2.0 / 3.0;
    result += ((160.0 * qSin((y / 12.0) * kChinaPi)) + (320.0 * qSin((y * kChinaPi) / 30.0))) * 2.0 / 3.0;
    return result;
}

double transformLongitude(double x, double y)
{
    double result = 300.0 + x + (2.0 * y) + (0.1 * x * x) + (0.1 * x * y) + (0.1 * qSqrt(qAbs(x)));
    result += ((20.0 * qSin(6.0 * x * kChinaPi)) + (20.0 * qSin(2.0 * x * kChinaPi))) * 2.0 / 3.0;
    result += ((20.0 * qSin(x * kChinaPi)) + (40.0 * qSin((x / 3.0) * kChinaPi))) * 2.0 / 3.0;
    result += ((150.0 * qSin((x / 12.0) * kChinaPi)) + (300.0 * qSin((x / 30.0) * kChinaPi))) * 2.0 / 3.0;
    return result;
}

bool isInsideChina(const QGeoCoordinate &coordinate)
{
    return coordinate.isValid()
        && coordinate.longitude() >= 72.004
        && coordinate.longitude() <= 137.8347
        && coordinate.latitude() >= 0.8293
        && coordinate.latitude() <= 55.8271;
}

QGeoCoordinate wgs84ToGcj02(const QGeoCoordinate &coordinate)
{
    if (!isInsideChina(coordinate)) {
        return coordinate;
    }

    const double latitude = coordinate.latitude();
    const double longitude = coordinate.longitude();
    const double deltaLat = transformLatitude(longitude - 105.0, latitude - 35.0);
    const double deltaLon = transformLongitude(longitude - 105.0, latitude - 35.0);
    const double radLat = qDegreesToRadians(latitude);
    const double magic = 1.0 - (kChinaEccentricitySquared * qPow(qSin(radLat), 2.0));
    const double sqrtMagic = qSqrt(magic);

    const double adjustedLat = latitude + ((deltaLat * 180.0) / (((kChinaSemiMajorAxis * (1.0 - kChinaEccentricitySquared)) / (magic * sqrtMagic)) * kChinaPi));
    const double adjustedLon = longitude + ((deltaLon * 180.0) / ((kChinaSemiMajorAxis / sqrtMagic) * qCos(radLat) * kChinaPi));

    return QGeoCoordinate(adjustedLat, adjustedLon, coordinate.altitude());
}

QGeoCoordinate gcj02ToWgs84(const QGeoCoordinate &coordinate)
{
    if (!isInsideChina(coordinate)) {
        return coordinate;
    }

    const QGeoCoordinate gcjEstimate = wgs84ToGcj02(coordinate);
    return QGeoCoordinate(
        coordinate.latitude() * 2.0 - gcjEstimate.latitude(),
        coordinate.longitude() * 2.0 - gcjEstimate.longitude(),
        coordinate.altitude());
}
}

QGC_LOGGING_CATEGORY(GuidedActionsControllerLog, "QMLControls.GuidedActionsController")

QGeoCoordinate QGroundControlQmlGlobal::_coord = QGeoCoordinate(0.0,0.0);
double QGroundControlQmlGlobal::_zoom = 2;

QGroundControlQmlGlobal::QGroundControlQmlGlobal(QObject *parent)
    : QObject(parent)
    , _mapEngineManager(QGCMapEngineManager::instance())
    , _adsbVehicleManager(ADSBVehicleManager::instance())
    , _ntripManager(NTRIPManager::instance())
    , _qgcPositionManager(QGCPositionManager::instance())
    , _missionCommandTree(MissionCommandTree::instance())
    , _mavlinkSigningKeys(MAVLinkSigningKeys::instance())
    , _videoManager(VideoManager::instance())
    , _linkManager(LinkManager::instance())
    , _multiVehicleManager(MultiVehicleManager::instance())
    , _settingsManager(SettingsManager::instance())
    , _corePlugin(QGCCorePlugin::instance())
    , _globalPalette(new QGCPalette(this))
#ifndef QGC_NO_SERIAL_LINK
    , _gpsRtkFactGroup(GPSManager::instance()->gpsRtk()->gpsRtkFactGroup())
#endif
{
    // We clear the parent on this object since we run into shutdown problems caused by hybrid qml app. Instead we let it leak on shutdown.
    // setParent(nullptr);

    // Load last coordinates and zoom from config file
    QSettings settings;
    settings.beginGroup(_flightMapPositionSettingsGroup);
    _coord.setLatitude(settings.value(_flightMapPositionLatitudeSettingsKey,    _coord.latitude()).toDouble());
    _coord.setLongitude(settings.value(_flightMapPositionLongitudeSettingsKey,  _coord.longitude()).toDouble());
    _zoom = settings.value(_flightMapZoomSettingsKey, _zoom).toDouble();
    _flightMapPositionSettledTimer.setSingleShot(true);
    _flightMapPositionSettledTimer.setInterval(1000);
    (void) connect(&_flightMapPositionSettledTimer, &QTimer::timeout, this, []() {
        // When they settle, save flightMapPosition and Zoom to the config file
        QSettings settingsInner;
        settingsInner.beginGroup(_flightMapPositionSettingsGroup);
        settingsInner.setValue(_flightMapPositionLatitudeSettingsKey, _coord.latitude());
        settingsInner.setValue(_flightMapPositionLongitudeSettingsKey, _coord.longitude());
        settingsInner.setValue(_flightMapZoomSettingsKey, _zoom);
    });
    connect(this, &QGroundControlQmlGlobal::flightMapPositionChanged, this, [this](QGeoCoordinate){
        if (!_flightMapPositionSettledTimer.isActive()) {
            _flightMapPositionSettledTimer.start();
        }
    });
    connect(this, &QGroundControlQmlGlobal::flightMapZoomChanged, this, [this](double){
        if (!_flightMapPositionSettledTimer.isActive()) {
            _flightMapPositionSettledTimer.start();
        }
    });
}

QGroundControlQmlGlobal::~QGroundControlQmlGlobal()
{
}

void QGroundControlQmlGlobal::saveGlobalSetting (const QString& key, const QString& value)
{
    QSettings settings;
    settings.beginGroup(kQmlGlobalKeyName);
    settings.setValue(key, value);
}

QString QGroundControlQmlGlobal::loadGlobalSetting (const QString& key, const QString& defaultValue)
{
    QSettings settings;
    settings.beginGroup(kQmlGlobalKeyName);
    return settings.value(key, defaultValue).toString();
}

void QGroundControlQmlGlobal::saveBoolGlobalSetting (const QString& key, bool value)
{
    QSettings settings;
    settings.beginGroup(kQmlGlobalKeyName);
    settings.setValue(key, value);
}

bool QGroundControlQmlGlobal::loadBoolGlobalSetting (const QString& key, bool defaultValue)
{
    QSettings settings;
    settings.beginGroup(kQmlGlobalKeyName);
    return settings.value(key, defaultValue).toBool();
}

void QGroundControlQmlGlobal::startPX4MockLink(bool sendStatusText, bool enableCamera, bool enableGimbal)
{
#ifdef QT_DEBUG
    MockLink::startPX4MockLink(sendStatusText, enableCamera, enableGimbal);
#else
    Q_UNUSED(sendStatusText);
    Q_UNUSED(enableCamera);
    Q_UNUSED(enableGimbal);
#endif
}

void QGroundControlQmlGlobal::startGenericMockLink(bool sendStatusText, bool enableCamera, bool enableGimbal)
{
#ifdef QT_DEBUG
    MockLink::startGenericMockLink(sendStatusText, enableCamera, enableGimbal);
#else
    Q_UNUSED(sendStatusText);
    Q_UNUSED(enableCamera);
    Q_UNUSED(enableGimbal);
#endif
}

void QGroundControlQmlGlobal::startAPMArduCopterMockLink(bool sendStatusText, bool enableCamera, bool enableGimbal)
{
#ifdef QT_DEBUG
    MockLink::startAPMArduCopterMockLink(sendStatusText, enableCamera, enableGimbal);
#else
    Q_UNUSED(sendStatusText);
    Q_UNUSED(enableCamera);
    Q_UNUSED(enableGimbal);
#endif
}

void QGroundControlQmlGlobal::startAPMArduPlaneMockLink(bool sendStatusText, bool enableCamera, bool enableGimbal)
{
#ifdef QT_DEBUG
    MockLink::startAPMArduPlaneMockLink(sendStatusText, enableCamera, enableGimbal);
#else
    Q_UNUSED(sendStatusText);
    Q_UNUSED(enableCamera);
    Q_UNUSED(enableGimbal);
#endif
}

void QGroundControlQmlGlobal::startAPMArduSubMockLink(bool sendStatusText, bool enableCamera, bool enableGimbal)
{
#ifdef QT_DEBUG
    MockLink::startAPMArduSubMockLink(sendStatusText, enableCamera, enableGimbal);
#else
    Q_UNUSED(sendStatusText);
    Q_UNUSED(enableCamera);
    Q_UNUSED(enableGimbal);
#endif
}

void QGroundControlQmlGlobal::startAPMArduRoverMockLink(bool sendStatusText, bool enableCamera, bool enableGimbal)
{
#ifdef QT_DEBUG
    MockLink::startAPMArduRoverMockLink(sendStatusText, enableCamera, enableGimbal);
#else
    Q_UNUSED(sendStatusText);
    Q_UNUSED(enableCamera);
    Q_UNUSED(enableGimbal);
#endif
}

void QGroundControlQmlGlobal::stopOneMockLink(void)
{
#ifdef QT_DEBUG
    QList<SharedLinkInterfacePtr> sharedLinks = LinkManager::instance()->links();

    for (int i=0; i<sharedLinks.count(); i++) {
        LinkInterface* link = sharedLinks[i].get();
        MockLink* mockLink = qobject_cast<MockLink*>(link);
        if (mockLink) {
            mockLink->disconnect();
            return;
        }
    }
#endif
}

bool QGroundControlQmlGlobal::singleFirmwareSupport(void)
{
    return FirmwarePluginManager::instance()->supportedFirmwareClasses().count() == 1;
}

bool QGroundControlQmlGlobal::singleVehicleSupport(void)
{
    if (singleFirmwareSupport()) {
        return FirmwarePluginManager::instance()->supportedVehicleClasses(FirmwarePluginManager::instance()->supportedFirmwareClasses()[0]).count() == 1;
    }

    return false;
}

bool QGroundControlQmlGlobal::px4ProFirmwareSupported()
{
    return FirmwarePluginManager::instance()->supportedFirmwareClasses().contains(QGCMAVLink::FirmwareClassPX4);
}

bool QGroundControlQmlGlobal::apmFirmwareSupported()
{
    return FirmwarePluginManager::instance()->supportedFirmwareClasses().contains(QGCMAVLink::FirmwareClassArduPilot);
}

bool QGroundControlQmlGlobal::linesIntersect(QPointF line1A, QPointF line1B, QPointF line2A, QPointF line2B)
{
    QPointF intersectPoint;

    auto intersect = QLineF(line1A, line1B).intersects(QLineF(line2A, line2B), &intersectPoint);

    return  intersect == QLineF::BoundedIntersection &&
            intersectPoint != line1A && intersectPoint != line1B;
}

bool QGroundControlQmlGlobal::isChinaOffsetMapActive() const
{
    return _settingsManager
        && _settingsManager->flightMapSettings()
        && (_settingsManager->flightMapSettings()->mapProvider()->rawValue().toString() == QStringLiteral("TianDiTu"));
}

QGeoCoordinate QGroundControlQmlGlobal::mapDisplayCoordinate(const QGeoCoordinate &coordinate) const
{
    return isChinaOffsetMapActive() ? wgs84ToGcj02(coordinate) : coordinate;
}

QGeoCoordinate QGroundControlQmlGlobal::mapSourceCoordinate(const QGeoCoordinate &coordinate) const
{
    return isChinaOffsetMapActive() ? gcj02ToWgs84(coordinate) : coordinate;
}

QVariantList QGroundControlQmlGlobal::mapDisplayCoordinates(const QVariantList &coordinates) const
{
    QVariantList displayCoordinates;
    displayCoordinates.reserve(coordinates.size());

    for (const QVariant &coordinateValue: coordinates) {
        const QGeoCoordinate coordinate = coordinateValue.value<QGeoCoordinate>();
        displayCoordinates.append(QVariant::fromValue(mapDisplayCoordinate(coordinate)));
    }

    return displayCoordinates;
}

void QGroundControlQmlGlobal::setFlightMapPosition(QGeoCoordinate& coordinate)
{
    if (coordinate != flightMapPosition()) {
        _coord.setLatitude(coordinate.latitude());
        _coord.setLongitude(coordinate.longitude());
        emit flightMapPositionChanged(coordinate);
    }
}

void QGroundControlQmlGlobal::setFlightMapZoom(double zoom)
{
    if (zoom != flightMapZoom()) {
        _zoom = zoom;
        emit flightMapZoomChanged(zoom);
    }
}

QString QGroundControlQmlGlobal::qgcVersion(void)
{
    QString versionStr = QCoreApplication::applicationVersion();
    if(QSysInfo::buildAbi().contains("32"))
    {
        versionStr += QStringLiteral(" %1").arg(tr("32 bit"));
    }
    else if(QSysInfo::buildAbi().contains("64"))
    {
        versionStr += QStringLiteral(" %1").arg(tr("64 bit"));
    }
    return versionStr;
}

QString QGroundControlQmlGlobal::altitudeFrameExtraUnits(AltitudeFrame altFrame)
{
    switch (altFrame) {
    case AltitudeFrameNone:
        return QString();
    case AltitudeFrameRelative:
        return tr("Rel");
    case AltitudeFrameAbsolute:
        return tr("AMSL");
    case AltitudeFrameCalcAboveTerrain:
        return tr("AGLC");
    case AltitudeFrameTerrain:
        return tr("AGL");
    case AltitudeFrameMixed:
        return tr("Mixed");
    }

    // Should never get here but makes some compilers happy
    return QString();
}

QString QGroundControlQmlGlobal::altitudeFrameShortDescription(AltitudeFrame altFrame)
{
    switch (altFrame) {
    case AltitudeFrameNone:
        return QString();
    case AltitudeFrameRelative:
        return tr("Relative (%1)").arg(altitudeFrameExtraUnits(altFrame));
    case AltitudeFrameAbsolute:
        return tr("Absolute (%1)").arg(altitudeFrameExtraUnits(altFrame));
    case AltitudeFrameCalcAboveTerrain:
        return tr("Above Terrain Calced (%1)").arg(altitudeFrameExtraUnits(altFrame));
    case AltitudeFrameTerrain:
        return tr("Above Terrain (%1)").arg(altitudeFrameExtraUnits(altFrame));
    case AltitudeFrameMixed:
        return tr("Mixed");
    }

    // Should never get here but makes some compilers happy
    return QString();
}

void QGroundControlQmlGlobal::showMessageDialog(
    QObject* owner,
    const QString& title,
    const QString& text,
    int buttons,
    QJSValue acceptFunction,
    QJSValue closeFunction)
{
    emit showMessageDialogRequested(owner, title, text, buttons, acceptFunction, closeFunction);
}

void QGroundControlQmlGlobal::testAudioOutput()
{
    AudioOutput::instance()->testAudioOutput();
}

QString QGroundControlQmlGlobal::elevationProviderName()
{
    return _settingsManager->flightMapSettings()->elevationMapProvider()->rawValue().toString();
}

QString QGroundControlQmlGlobal::elevationProviderNotice()
{
    return _settingsManager->flightMapSettings()->elevationMapProvider()->rawValue().toString();
}

QString QGroundControlQmlGlobal::parameterFileExtension() const
{
    return AppSettings::parameterFileExtension;
}

QString QGroundControlQmlGlobal::telemetryFileExtension() const
{
    return AppSettings::telemetryFileExtension;
}

QString QGroundControlQmlGlobal::appName()
{
    return QCoreApplication::applicationName();
}

QmlObjectListModel *QGroundControlQmlGlobal::treeLoggingCategoriesModel()
{
    return QGCLoggingCategoryManager::instance()->treeCategoryModel();
}

QmlObjectListModel *QGroundControlQmlGlobal::flatLoggingCategoriesModel()
{
    return QGCLoggingCategoryManager::instance()->flatCategoryModel();
}

void QGroundControlQmlGlobal::setCategoryLoggingOn(const QString &category, bool enable)
{
    QGCLoggingCategoryManager::instance()->setCategoryLoggingOn(category, enable);
}

bool QGroundControlQmlGlobal::categoryLoggingOn(const QString &category)
{
    return QGCLoggingCategoryManager::categoryLoggingOn(category);
}

void QGroundControlQmlGlobal::disableAllLoggingCategories()
{
    QGCLoggingCategoryManager::instance()->disableAllCategories();
}
