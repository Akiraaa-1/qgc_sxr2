#include "TianDiTuProvider.h"
#include "SettingsManager.h"
#include "AppSettings.h"

#include <QtCore/QStringBuilder>

QString TianDiTuProvider::_getURL(int x, int y, int zoom) const
{
    const QString tiandituToken = SettingsManager::instance()->appSettings()->tiandituToken()->rawValue().toString();
    if (!tiandituToken.isEmpty()) {
        return QStringLiteral("https://t")
            % QString::number(_getServerNum(x, y, 8))
            % QStringLiteral(".tianditu.gov.cn/")
            % _mapType
            % QStringLiteral("/wmts?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0&LAYER=")
            % _layerName
            % QStringLiteral("&STYLE=default&TILEMATRIXSET=w&FORMAT=tiles&TILEMATRIX=")
            % QString::number(zoom)
            % QStringLiteral("&TILEROW=")
            % QString::number(y)
            % QStringLiteral("&TILECOL=")
            % QString::number(x)
            % QStringLiteral("&tk=")
            % tiandituToken;
    }
    return QString();
}
