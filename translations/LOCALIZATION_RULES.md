# Localization Rules

1. All localization source files must be saved as `UTF-8` without BOM.
2. Do not edit anything under `build/`, generated QML cache output, or copied resource output.
3. UI text from QML/C++ should be changed at the source call site: `qsTr(...)` or `tr(...)`.
4. Parameter descriptions, labels, enum strings, and generated setup pages must be changed in their source metadata files:
   `*.json`, `*.xml`, `*.cc`, `*.h`.
5. Do not patch generated pages to "fix" untranslated text if the page is generated from metadata.
6. Keep terminology consistent. Preferred terms:
   `Actuators -> 执行器`
   `Start Mission -> 开始任务`
   `Settings -> 设置`
   `Configure -> 配置`
   `Abort -> 中止`
   `Motor -> 电机`
7. Before committing localization work, search for the English source term across `src/` and `translations/` to avoid duplicate untranslated paths.
8. If a file becomes garbled, restore it from source control first, then re-apply only the intended localization changes.
9. Prefer one translation path per string:
   QML/C++ visible text: source string
   metadata-driven text: metadata source
   broad language pack text: `translations/qgc_source_zh_CN.ts` or `translations/qgc_json_zh_CN.ts`
10. When a string is visible in multiple places, update all active sources in the same change to avoid mixed Chinese/English UI.
