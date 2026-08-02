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
    Q_INVOKABLE void addProduct(const QString &barcode, const QString &name, double quantity, const QString &unit, double price, double sum);
    Q_INVOKABLE QVariantList getRecentProducts();
    Q_INVOKABLE QVariantMap findProductByBarcode(const QString &barcode);
    Q_INVOKABLE QVariantList getAllReceipts();
    Q_INVOKABLE QVariantMap getStockCard(const QString &barcode);
    Q_INVOKABLE QVariantList getWarehouses();
    Q_INVOKABLE bool addWarehouse(const QString &name);
    Q_INVOKABLE QVariantMap findDocProductByBarcode(const QString &barcode);
    Q_INVOKABLE int createDocument(const QString &docType, int warehouseId, int fromWarehouseId, int toWarehouseId,
                                    const QString &comment, const QVariantList &lines);
    Q_INVOKABLE QVariantList getDocuments();
    Q_INVOKABLE QVariantList getDocumentLines(int documentId);

signals:
    void productChanged();
    void statusChanged();

private:
    void initDatabase();
    void adjustStock(int warehouseId, const QString &barcode, double delta);

    QSqlDatabase m_db;
    QString m_currentBarcode;
    QString m_productName = "Товар не вибрано";
    double m_productQuantity = 0.0;
    QString m_statusMessage = "Очікування сканування...";
};

#endif // INVENTORY_MANAGER_H