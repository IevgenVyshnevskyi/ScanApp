#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>        // Обов'язково для зв'язку з QML
#include "inventorymanager.h" // Підключаємо наш заголовочний файл
#include "barcodedecoder.h"

int main(int argc, char *argv[])
{
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
#endif
    QGuiApplication app(argc, argv);

    // 1. Створюємо об'єкт нашого менеджера бази даних та складу
    InventoryManager inventoryManager;
    // 2. Створюємо екземпляр декодера
    BarcodeDecoder barcodeDecoder;

    QQmlApplicationEngine engine;

    // 2. РЕЄСТРАЦІЯ ДЛЯ QML:
    // Пов'язуємо C++ об'єкт із ім'ям "inventoryManager", яке використовується в QML.
    // Тепер у main.qml ви можете писати: inventoryManager.currentProductName тощо.
    engine.rootContext()->setContextProperty("inventoryManager", &inventoryManager);
    engine.rootContext()->setContextProperty("barcodeDecoder", &barcodeDecoder);

    // Зв'язуємо сигнал знаходження штрих-коду з методом менеджера інвентаризації
    QObject::connect(&barcodeDecoder, &BarcodeDecoder::barcodeFound,
                     &inventoryManager, &InventoryManager::processBarcode);

    const QUrl url(QStringLiteral("qrc:/ScanApp/main.qml"));
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreated,
        &app,
        [url](QObject *obj, const QUrl &objUrl) {
            if (!obj && url == objUrl)
                QCoreApplication::exit(-1);
        },
        Qt::QueuedConnection);
    engine.load(url);

    return QGuiApplication::exec();
}
