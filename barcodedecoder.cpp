#include "barcodedecoder.h"
#include <ReadBarcode.h>
#include <ImageView.h>
#include <QImage>

BarcodeDecoder::BarcodeDecoder(QObject *parent)
    : QObject(parent), m_videoSink(nullptr)
{
}

void BarcodeDecoder::processFrame(const QVideoFrame &frame)
{
    if (m_isProcessing) return;
    m_isProcessing = true;

    // Безпечно конвертуємо кадр камери у зручний для обробки QImage
    QImage image = frame.toImage().convertToFormat(QImage::Format_RGB888);

    if (!image.isNull()) {
        ZXing::ImageView imageView(
            image.bits(),
            image.width(),
            image.height(),
            ZXing::ImageFormat::RGB
            );

        auto result = ZXing::ReadBarcode(imageView);

        if (result.isValid()) {
            emit barcodeFound(QString::fromStdString(result.text()));
        }
    }

    m_isProcessing = false;
}

void BarcodeDecoder::setVideoSink(QVideoSink *sink)
{
    if (m_videoSink == sink) return;

    if (m_videoSink) {
        disconnect(m_videoSink, &QVideoSink::videoFrameChanged, this, &BarcodeDecoder::processFrame);
    }

    m_videoSink = sink;

    if (m_videoSink) {
        connect(m_videoSink, &QVideoSink::videoFrameChanged, this, &BarcodeDecoder::processFrame);
    }
}

// #include "barcodedecoder.h"
// #include <ReadBarcode.h>
// #include <ImageView.h>

// BarcodeDecoder::BarcodeDecoder(QObject *parent)
//     : QObject(parent), m_videoSink(nullptr)
// {
//     // Безпечна ініціалізація. Об'єкт не створюється даремно,
//     // а потік буде передано з QML через setVideoSink.
// }

// void BarcodeDecoder::processFrame(const QVideoFrame &frame)
// {
//     if (m_isProcessing) return; // Уникнення перевантаження CPU
//     m_isProcessing = true;

//     QVideoFrame f = frame;
//     if (f.map(QVideoFrame::ReadOnly)) {
//         ZXing::ImageView imageView(f.bits(0), f.width(), f.height(), ZXing::ImageFormat::RGBX);
//         auto result = ZXing::ReadBarcode(imageView);

//         if (result.isValid()) {
//             emit barcodeFound(QString::fromStdString(result.text()));
//         }
//         f.unmap();
//     }
//     m_isProcessing = false;
// }

// void BarcodeDecoder::setVideoSink(QVideoSink *sink)
// {
//     if (m_videoSink == sink) return;

//     // Якщо попередній sink існував, відключаємо його
//     if (m_videoSink) {
//         disconnect(m_videoSink, &QVideoSink::videoFrameChanged, this, &BarcodeDecoder::processFrame);
//     }

//     m_videoSink = sink;

//     // Підключаємо новий відеопотік від камери, коли він стає доступним
//     if (m_videoSink) {
//         connect(m_videoSink, &QVideoSink::videoFrameChanged, this, &BarcodeDecoder::processFrame);
//     }
// }

// #include "barcodedecoder.h"
// #include <ReadBarcode.h>
// #include <ImageView.h>

// BarcodeDecoder::BarcodeDecoder(QObject *parent) : QObject(parent)
// {
//     m_videoSink = new QVideoSink(this);
//     connect(m_videoSink, &QVideoSink::videoFrameChanged, this, &BarcodeDecoder::processFrame);
// }

// void BarcodeDecoder::processFrame(const QVideoFrame &frame)
// {
//     if (m_isProcessing) return; // Уникнення перевантаження CPU
//     m_isProcessing = true;

//     QVideoFrame f = frame;
//     if (f.map(QVideoFrame::ReadOnly)) {
//         ZXing::ImageView imageView(f.bits(0), f.width(), f.height(), ZXing::ImageFormat::RGBX);
//         auto result = ZXing::ReadBarcode(imageView);

//         if (result.isValid()) {
//             emit barcodeFound(QString::fromStdString(result.text()));
//         }
//         f.unmap();
//     }
//     m_isProcessing = false;
// }

// void BarcodeDecoder::setVideoSink(QVideoSink *sink)
// {
//     if (m_videoSink == sink) return;

//     // Якщо попередній sink існував, відключаємо його
//     if (m_videoSink) {
//         disconnect(m_videoSink, &QVideoSink::videoFrameChanged, this, &BarcodeDecoder::processFrame);
//     }

//     m_videoSink = sink;

//     // Підключаємо новий відеопотік від камери
//     if (m_videoSink) {
//         connect(m_videoSink, &QVideoSink::videoFrameChanged, this, &BarcodeDecoder::processFrame);
//     }
// }