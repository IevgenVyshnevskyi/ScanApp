#include "inventorymanager.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QDateTime>
#include <QDebug>
#include <QVector>
#include <algorithm>

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

    // Міграція: додаємо колонку ціни, якщо база створена до її появи.
    bool hasPriceColumn = false;
    QSqlQuery columnCheck("PRAGMA table_info(Products)");
    while (columnCheck.next()) {
        if (columnCheck.value(1).toString() == "price") {
            hasPriceColumn = true;
            break;
        }
    }
    if (!hasPriceColumn) {
        query.exec("ALTER TABLE Products ADD COLUMN price REAL DEFAULT 0");
    }

    // Міграція: додаємо колонку часу останньої дії з товаром (додавання/списання),
    // щоб мати змогу показувати "останні товари, з якими працювали".
    bool hasLastUpdatedColumn = false;
    QSqlQuery lastUpdatedCheck("PRAGMA table_info(Products)");
    while (lastUpdatedCheck.next()) {
        if (lastUpdatedCheck.value(1).toString() == "last_updated") {
            hasLastUpdatedColumn = true;
            break;
        }
    }
    if (!hasLastUpdatedColumn) {
        query.exec("ALTER TABLE Products ADD COLUMN last_updated TEXT");
    }

    // Таблиця історії списань
    query.exec("CREATE TABLE IF NOT EXISTS Transactions ("
               "id INTEGER PRIMARY KEY AUTOINCREMENT, "
               "barcode TEXT, "
               "quantity_written_off REAL, "
               "timestamp TEXT, "
               "operator TEXT)");

    // Таблиця історії оприбуткувань
    query.exec("CREATE TABLE IF NOT EXISTS Receipts ("
               "id INTEGER PRIMARY KEY AUTOINCREMENT, "
               "barcode TEXT, "
               "name TEXT, "
               "quantity REAL, "
               "unit TEXT, "
               "price REAL, "
               "sum REAL, "
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
    updateQuery.prepare("UPDATE Products SET quantity = ?, last_updated = ? WHERE barcode = ?");
    updateQuery.addBindValue(newQuantity);
    updateQuery.addBindValue(QDateTime::currentDateTime().toString(Qt::ISODate));
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

void InventoryManager::addProduct(const QString &barcode, const QString &name, double quantity, const QString &unit, double price, double sum)
{
    if (barcode.trimmed().isEmpty() || name.trimmed().isEmpty()) {
        m_statusMessage = "Помилка: штрих-код і назва не можуть бути пустими!";
        emit statusChanged();
        return;
    }

    QString now = QDateTime::currentDateTime().toString(Qt::ISODate);

    QSqlQuery query;
    query.prepare(
        "INSERT INTO Products (barcode, name, quantity, unit, price, last_updated) VALUES (?, ?, ?, ?, ?, ?) "
        "ON CONFLICT(barcode) DO UPDATE SET "
        "quantity = quantity + excluded.quantity, "
        "name = excluded.name, "
        "unit = excluded.unit, "
        "price = excluded.price, "
        "last_updated = excluded.last_updated"
    );
    query.addBindValue(barcode.trimmed());
    query.addBindValue(name.trimmed());
    query.addBindValue(quantity);
    query.addBindValue(unit.trimmed());
    query.addBindValue(price);
    query.addBindValue(now);

    if (query.exec()) {
        // Запис в історію оприбуткувань
        QSqlQuery logQuery;
        logQuery.prepare(
            "INSERT INTO Receipts (barcode, name, quantity, unit, price, sum, timestamp, operator) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
        );
        logQuery.addBindValue(barcode.trimmed());
        logQuery.addBindValue(name.trimmed());
        logQuery.addBindValue(quantity);
        logQuery.addBindValue(unit.trimmed());
        logQuery.addBindValue(price);
        logQuery.addBindValue(sum);
        logQuery.addBindValue(now);
        logQuery.addBindValue("Оператор 1");
        logQuery.exec();

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

    // Точний збіг: штрих-код - це ідентифікатор товару, а не пошуковий рядок.
    // Пошук за префіксом тут не годиться - введений код може бути самостійним,
    // коротшим штрих-кодом іншого товару, а не незавершеним набором довшого.
    QSqlQuery query;
    query.prepare("SELECT name, quantity, unit, price FROM Products WHERE barcode = ?");
    query.addBindValue(trimmed);

    if (query.exec() && query.next()) {
        result["found"] = true;
        result["name"] = query.value(0).toString();
        result["quantity"] = query.value(1).toDouble();
        result["unit"] = query.value(2).toString();
        result["price"] = query.value(3).toDouble();
    }

    return result;
}

QVariantList InventoryManager::getRecentProducts()
{
    QVariantList productList;
    QSqlQuery query("SELECT barcode, name, quantity, unit, price FROM Products "
                     "ORDER BY last_updated DESC LIMIT 5");

    while (query.next()) {
        QVariantMap product;
        product["barcode"] = query.value(0).toString();
        product["name"] = query.value(1).toString();
        product["quantity"] = query.value(2).toDouble();
        product["unit"] = query.value(3).toString();
        product["price"] = query.value(4).toDouble();
        productList.append(product);
    }

    return productList;
}

QVariantList InventoryManager::getAllReceipts()
{
    QVariantList receiptList;
    QSqlQuery query("SELECT barcode, name, quantity, unit, price, sum, timestamp "
                     "FROM Receipts ORDER BY id DESC");

    while (query.next()) {
        QVariantMap receipt;
        receipt["barcode"] = query.value(0).toString();
        receipt["name"] = query.value(1).toString();
        receipt["quantity"] = query.value(2).toDouble();
        receipt["unit"] = query.value(3).toString();
        receipt["price"] = query.value(4).toDouble();
        receipt["sum"] = query.value(5).toDouble();
        receipt["timestamp"] = query.value(6).toString();
        receiptList.append(receipt);
    }

    return receiptList;
}

QVariantMap InventoryManager::getStockCard(const QString &barcode)
{
    QVariantMap result;
    result["found"] = false;

    QString trimmed = barcode.trimmed();
    if (trimmed.isEmpty()) {
        return result;
    }

    QSqlQuery productQuery;
    productQuery.prepare("SELECT name, quantity, unit, price FROM Products WHERE barcode = ?");
    productQuery.addBindValue(trimmed);
    if (!productQuery.exec() || !productQuery.next()) {
        return result;
    }

    result["found"] = true;
    result["barcode"] = trimmed;
    result["name"] = productQuery.value(0).toString();
    result["quantity"] = productQuery.value(1).toDouble();
    result["unit"] = productQuery.value(2).toString();
    result["price"] = productQuery.value(3).toDouble();

    // Об'єднуємо надходження та списання в одну хронологію руху товару
    // (аналог граф "прихід/витрата/залишок" картки складського обліку, форма М-14).
    struct Movement {
        QString timestamp;
        QString type;
        QString info;
        double quantityIn;
        double quantityOut;
    };
    QVector<Movement> movements;

    QSqlQuery receiptsQuery;
    receiptsQuery.prepare("SELECT quantity, price, sum, timestamp FROM Receipts WHERE barcode = ?");
    receiptsQuery.addBindValue(trimmed);
    receiptsQuery.exec();
    while (receiptsQuery.next()) {
        Movement m;
        m.timestamp = receiptsQuery.value(3).toString();
        m.type = "Оприбуткування";
        m.info = QString("ціна %1, сума %2")
                     .arg(receiptsQuery.value(1).toDouble(), 0, 'f', 2)
                     .arg(receiptsQuery.value(2).toDouble(), 0, 'f', 2);
        m.quantityIn = receiptsQuery.value(0).toDouble();
        m.quantityOut = 0.0;
        movements.append(m);
    }

    QSqlQuery transactionsQuery;
    transactionsQuery.prepare("SELECT quantity_written_off, timestamp, operator FROM Transactions WHERE barcode = ?");
    transactionsQuery.addBindValue(trimmed);
    transactionsQuery.exec();
    while (transactionsQuery.next()) {
        Movement m;
        m.timestamp = transactionsQuery.value(1).toString();
        m.type = "Списання";
        m.info = transactionsQuery.value(2).toString();
        m.quantityIn = 0.0;
        m.quantityOut = transactionsQuery.value(0).toDouble();
        movements.append(m);
    }

    std::sort(movements.begin(), movements.end(), [](const Movement &a, const Movement &b) {
        return a.timestamp < b.timestamp;
    });

    QVariantList movementList;
    double runningBalance = 0.0;
    for (const Movement &m : movements) {
        runningBalance += m.quantityIn - m.quantityOut;

        QVariantMap row;
        row["date"] = m.timestamp;
        row["type"] = m.type;
        row["info"] = m.info;
        row["quantityIn"] = m.quantityIn;
        row["quantityOut"] = m.quantityOut;
        row["balance"] = runningBalance;
        movementList.append(row);
    }
    result["movements"] = movementList;

    return result;
}