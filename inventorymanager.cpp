#include "inventorymanager.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QDateTime>
#include <QDebug>

InventoryManager::InventoryManager(QObject *parent) : QObject(parent)
{
    initDatabase();
}

void InventoryManager::initDatabase()
{
    m_db = QSqlDatabase::addDatabase("QSQLITE");
    m_db.setDatabaseName("warehouse.db");

    if (!m_db.open()) {
        m_statusMessage = "Помилка підключення до БД!";
        emit statusChanged();
        return;
    }

    QSqlQuery query;
    // Таблиця товарів
    query.exec("CREATE TABLE IF NOT EXISTS Products ("
               "id INTEGER PRIMARY KEY AUTOINCREMENT, "
               "barcode TEXT UNIQUE, "
               "name TEXT, "
               "quantity REAL, "
               "unit TEXT)");

    // Таблиця історії списань
    query.exec("CREATE TABLE IF NOT EXISTS Transactions ("
               "id INTEGER PRIMARY KEY AUTOINCREMENT, "
               "barcode TEXT, "
               "quantity_written_off REAL, "
               "timestamp TEXT, "
               "operator TEXT)");
}

void InventoryManager::processBarcode(const QString &barcode)
{
    m_currentBarcode = barcode.trimmed();
    QSqlQuery query;
    query.prepare("SELECT name, quantity FROM Products WHERE barcode = ?");
    query.addBindValue(m_currentBarcode);

    if (query.exec() && query.next()) {
        m_productName = query.value(0).toString();
        m_productQuantity = query.value(1).toDouble();
        m_statusMessage = "Товар знайдено.";
    } else {
        m_productName = "Невідомий товар";
        m_productQuantity = 0.0;
        m_statusMessage = "Штрих-код не знайдено в базі! Додайте товар.";
    }
    emit productChanged();
    emit statusChanged();
}

void InventoryManager::writeOff(double amount)
{
    if (m_currentBarcode.isEmpty() || m_productQuantity <= 0) {
        m_statusMessage = "Неможливо списати: товар не вибрано.";
        emit statusChanged();
        return;
    }

    if (amount > m_productQuantity) {
        m_statusMessage = "Помилка: кількість для списання перевищує залишок!";
        emit statusChanged();
        return;
    }

    double newQuantity = m_productQuantity - amount;

    // Оновлення залишку в БД
    QSqlQuery updateQuery;
    updateQuery.prepare("UPDATE Products SET quantity = ? WHERE barcode = ?");
    updateQuery.addBindValue(newQuantity);
    updateQuery.addBindValue(m_currentBarcode);

    if (updateQuery.exec()) {
        // Запис транзакції списання
        QSqlQuery logQuery;
        logQuery.prepare("INSERT INTO Transactions (barcode, quantity_written_off, timestamp, operator) "
                         "VALUES (?, ?, ?, ?)");
        logQuery.addBindValue(m_currentBarcode);
        logQuery.addBindValue(amount);
        logQuery.addBindValue(QDateTime::currentDateTime().toString(Qt::ISODate));
        logQuery.addBindValue("Оператор 1");
        logQuery.exec();

        m_productQuantity = newQuantity;
        m_statusMessage = QString("Успішно списано %1 од.").arg(amount);
    } else {
        m_statusMessage = "Помилка бази даних при списанні!";
    }
    emit productChanged();
    emit statusChanged();
}

void InventoryManager::addProduct(const QString &barcode, const QString &name, double quantity, const QString &unit)
{
    if (barcode.trimmed().isEmpty() || name.trimmed().isEmpty()) {
        m_statusMessage = "Помилка: штрих-код і назва не можуть бути пустими!";
        emit statusChanged();
        return;
    }

    QSqlQuery query;
    query.prepare(
        "INSERT INTO Products (barcode, name, quantity, unit) VALUES (?, ?, ?, ?) "
        "ON CONFLICT(barcode) DO UPDATE SET "
        "quantity = quantity + excluded.quantity, "
        "name = excluded.name, "
        "unit = excluded.unit"
    );
    query.addBindValue(barcode.trimmed());
    query.addBindValue(name.trimmed());
    query.addBindValue(quantity);
    query.addBindValue(unit.trimmed());

    if (query.exec()) {
        m_statusMessage = QString("Товар '%1' успішно додано/оновлено!").arg(name);
    } else {
        m_statusMessage = "Помилка при додаванні товару до бази!";
    }
    emit statusChanged();
    emit productChanged();
}

QVariantMap InventoryManager::findProductByBarcode(const QString &barcode)
{
    QVariantMap result;
    result["found"] = false;

    QString trimmed = barcode.trimmed();
    if (trimmed.isEmpty()) {
        return result;
    }

    // Пошук за префіксом: дозволяє підставити товар ще під час набору коду,
    // до того як він буде введений повністю.
    QString pattern = trimmed;
    pattern.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_");
    pattern += "%";

    QSqlQuery query;
    query.prepare("SELECT name, quantity, unit FROM Products WHERE barcode LIKE ? ESCAPE '\\' LIMIT 2");
    query.addBindValue(pattern);

    if (!query.exec()) {
        return result;
    }

    int matches = 0;
    QString name, unit;
    double quantity = 0.0;
    while (query.next()) {
        matches++;
        if (matches == 1) {
            name = query.value(0).toString();
            quantity = query.value(1).toDouble();
            unit = query.value(2).toString();
        }
    }

    // Підставляємо, лише якщо введений префікс однозначно вказує на один товар.
    if (matches == 1) {
        result["found"] = true;
        result["name"] = name;
        result["quantity"] = quantity;
        result["unit"] = unit;
    }

    return result;
}

QVariantList InventoryManager::getAllProducts()
{
    QVariantList productList;
    QSqlQuery query("SELECT barcode, name, quantity, unit FROM Products");

    while (query.next()) {
        QVariantMap product;
        product["barcode"] = query.value(0).toString();
        product["name"] = query.value(1).toString();
        product["quantity"] = query.value(2).toDouble();
        product["unit"] = query.value(3).toString();
        productList.append(product);
    }

    return productList;
}