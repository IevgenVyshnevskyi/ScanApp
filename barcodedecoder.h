#ifndef BARCODE_DECODER_H
#define BARCODE_DECODER_H

#include <QObject>
#include <QVideoSink>
#include <QVideoFrame>
#include <atomic>

class BarcodeDecoder : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVideoSink* videoSink READ videoSink CONSTANT)

public:
    explicit BarcodeDecoder(QObject *parent = nullptr);
    QVideoSink* videoSink() const { return m_videoSink; }
    Q_INVOKABLE void setVideoSink(QVideoSink *sink);

signals:
    void barcodeFound(QString barcode);

private slots:
    void processFrame(const QVideoFrame &frame);

private:
    QVideoSink *m_videoSink;
    std::atomic<bool> m_isProcessing{false};
};

#endif // BARCODE_DECODER_H

// #ifndef BARCODE_DECODER_H
// #define BARCODE_DECODER_H

// #include <QObject>
// #include <QVideoSink>
// #include <QVideoFrame>

// class BarcodeDecoder : public QObject
// {
//     Q_OBJECT
//     Q_PROPERTY(QVideoSink* videoSink READ videoSink CONSTANT)

// public:
//     explicit BarcodeDecoder(QObject *parent = nullptr);
//     QVideoSink* videoSink() const { return m_videoSink; }
//     Q_INVOKABLE void setVideoSink(QVideoSink *sink);

// signals:
//     void barcodeFound(QString barcode);

// private slots:
//     void processFrame(const QVideoFrame &frame);

// private:
//     QVideoSink *m_videoSink;
//     bool m_isProcessing = false;
// };

// #endif // BARCODE_DECODER_H