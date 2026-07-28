#ifndef INVENTORY_MANAGER_H
#define INVENTORY_MANAGER_H

#include <QObject>
#include <QString>
#include <QSqlDatabase>
#include <QVariantList>

class InventoryManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString currentProductName READ currentProductName NOTIFY productChanged)
    Q_PROPERTY(double currentProductQuantity READ currentProductQuantity NOTIFY productChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY statusChanged)

public:
    explicit InventoryManager(QObject *parent = nullptr);

    QString currentProductName() const { return m_productName; }
    double currentProductQuantity() const { return m_productQuantity; }
    QString statusMessage() const { return m_statusMessage; }

    Q_INVOKABLE void processBarcode(const QString &barcode);
    Q_INVOKABLE void writeOff(double amount);
    Q_INVOKABLE void addProduct(const QString &barcode, const QString &name, double quantity, const QString &unit);
    Q_INVOKABLE QVariantList getAllProducts();
    Q_INVOKABLE QVariantMap findProductByBarcode(const QString &barcode);

signals:
    void productChanged();
    void statusChanged();

private:
    void initDatabase();

    QSqlDatabase m_db;
    QString m_currentBarcode;
    QString m_productName = "Товар не вибрано";
    double m_productQuantity = 0.0;
    QString m_statusMessage = "Очікування сканування...";
};

#endif // INVENTORY_MANAGER_H