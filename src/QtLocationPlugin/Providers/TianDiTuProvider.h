#pragma once

#include "MapProvider.h"

static constexpr const quint32 AVERAGE_TIANDITU_STREET_MAP = 1297;
static constexpr const quint32 AVERAGE_TIANDITU_SAT_MAP    = 19597;

class TianDiTuProvider : public MapProvider
{
protected:
    TianDiTuProvider(const QString &mapName, const QString &mapTypeCode, const QString &imageFormat, quint32 averageSize,
                    QGeoMapType::MapStyle mapType)
        : MapProvider(mapName, QStringLiteral("https://map.tianditu.gov.cn/"), imageFormat, averageSize, mapType)
        , _mapType(mapTypeCode)
        , _layerName(mapTypeCode.first(3)) {}

private:
    QString _getURL(int x, int y, int zoom) const final;

    const QString _mapType;
    const QString _layerName;
};

class TianDiTuRoadProvider : public TianDiTuProvider
{
public:
    TianDiTuRoadProvider()
        : TianDiTuProvider(
            QObject::tr("TianDiTu Road"),
            QStringLiteral("vec_w"),
            QStringLiteral("png"),
            AVERAGE_TIANDITU_STREET_MAP,
            QGeoMapType::StreetMap) {}
};

class TianDiTuSatelliteProvider : public TianDiTuProvider
{
public:
    TianDiTuSatelliteProvider()
        : TianDiTuProvider(
            QObject::tr("TianDiTu Satellite"),
            QStringLiteral("img_w"),
            QStringLiteral("jpg"),
            AVERAGE_TIANDITU_SAT_MAP,
            QGeoMapType::SatelliteMapDay) {}
};
