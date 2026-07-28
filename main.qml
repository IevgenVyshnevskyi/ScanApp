import QtQuick
import QtQuick.Controls
import QtMultimedia

ApplicationWindow {
    visible: true
    width: 700
    height: 950
    title: "Облік та списання товарів"

    Column {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15

        // --- БЛОК КАМЕРИ ---
        Rectangle {
            width: parent.width
            height: 180
            color: "black"
            radius: 8
            clip: true

            CaptureSession {
                camera: Camera {
                    id: camera
                    active: true
                }
                videoOutput: videoOutput
            }

            VideoOutput {
                id: videoOutput
                anchors.fill: parent

                // Передаємо videoSink у C++ безпечним методом
                Component.onCompleted: {
                    barcodeDecoder.setVideoSink(videoOutput.videoSink);
                }
            }
        }

        // --- РЕЗЕРВНЕ ПОЛЕ ВВЕДЕННЯ ---
        TextField {
            id: barcodeInput
            width: parent.width
            placeholderText: "Або введіть штрих-код вручну..."
            font.pixelSize: 16

            onAccepted: {
                if (text.trim() !== "") {
                    inventoryManager.processBarcode(text);
                    text = "";
                }
            }
        }

        // --- КАРТКА ПОТОЧНОГО ТОВАРУ ---
        Rectangle {
            width: parent.width
            height: 100
            color: "#f0f0f0"
            border.color: "#cccccc"
            radius: 8

            Column {
                anchors.centerIn: parent
                spacing: 6
                width: parent.width - 40

                Text {
                    text: "Назва: " + inventoryManager.currentProductName
                    font.pixelSize: 16
                    font.bold: true
                }
                Text {
                    text: "Поточний залишок: " + inventoryManager.currentProductQuantity
                    font.pixelSize: 14
                }
            }
        }

        // --- БЛОК СПИСАННЯ ---
        Row {
            spacing: 10
            width: parent.width

            TextField {
                id: writeOffAmount
                width: 120
                text: "1"
                validator: DoubleValidator { bottom: 0.1; top: 100000.0 }
            }

            Button {
                text: "Списати товар"
                onClicked: {
                    inventoryManager.writeOff(parseFloat(writeOffAmount.text));
                    // Оновлюємо модель списку через властивість model
                    listView.model = inventoryManager.getAllProducts();
                }
            }
        }

        // --- БЛОК ДОДАВАННЯ НОВОГО ТОВАРУ ---
        Rectangle {
            width: parent.width
            height: 185
            color: "#f9f9f9"
            border.color: "#cccccc"
            radius: 8

            Column {
                anchors.centerIn: parent
                spacing: 8
                width: parent.width - 30

                Text {
                    text: "Додати / Оновити товар вручну:"
                    font.pixelSize: 14
                    font.bold: true
                }

                Row {
                    spacing: 8
                    width: parent.width

                    TextField {
                        id: newBarcodeField
                        width: parent.width * 0.45
                        placeholderText: "Штрих-код"
                        font.pixelSize: 13
                        property bool productAutoFilled: false
                        onTextChanged: {
                            var product = inventoryManager.findProductByBarcode(text);
                            if (product.found) {
                                newNameField.text = product.name;
                                newUnitField.text = product.unit;
                                newPriceField.text = product.price.toFixed(2);
                                productAutoFilled = true;
                            } else if (productAutoFilled) {
                                newNameField.text = "";
                                newUnitField.text = "шт";
                                newPriceField.text = "0.00";
                                productAutoFilled = false;
                            }
                        }
                    }

                    TextField {
                        id: newNameField
                        width: parent.width * 0.52
                        placeholderText: "Назва товару"
                        font.pixelSize: 13
                        readOnly: newBarcodeField.productAutoFilled
                        color: readOnly ? "#888888" : "#000000"
                    }
                }

                Row {
                    spacing: 8
                    width: parent.width

                    TextField {
                        id: newQuantityField
                        width: parent.width * 0.30
                        placeholderText: "Кількість"
                        text: "1"
                        validator: DoubleValidator { bottom: 0.0; top: 1000000.0 }
                        font.pixelSize: 13
                    }

                    TextField {
                        id: newUnitField
                        width: parent.width * 0.25
                        placeholderText: "Од. (шт/кг)"
                        text: "шт"
                        font.pixelSize: 13
                        readOnly: newBarcodeField.productAutoFilled
                        color: readOnly ? "#888888" : "#000000"
                    }

                    TextField {
                        id: newPriceField
                        width: parent.width * 0.30
                        placeholderText: "Ціна, грн"
                        text: "0.00"
                        validator: DoubleValidator { bottom: 0.0; top: 1000000.0; decimals: 2; locale: "en_US" }
                        font.pixelSize: 13
                    }
                }

                Row {
                    width: parent.width

                    Button {
                        text: "Зберегти"
                        width: parent.width
                        onClicked: {
                            inventoryManager.addProduct(
                                newBarcodeField.text,
                                newNameField.text,
                                parseFloat(newQuantityField.text),
                                newUnitField.text,
                                parseFloat(newPriceField.text)
                            );
                            newBarcodeField.text = "";
                            newNameField.text = "";
                            newQuantityField.text = "1";
                            newPriceField.text = "0.00";
                            listView.model = inventoryManager.getAllProducts();
                        }
                    }
                }
            }
        }

        // --- БЛОК ПЕРЕГЛЯДУ ВСІЄЇ БАЗИ ДАНИХ ---
        Column {
            width: parent.width
            spacing: 5

            Row {
                width: parent.width
                spacing: 10

                Text {
                    text: "Актуальні товари в базі:"
                    font.pixelSize: 16
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }

                Button {
                    text: "Оновити список"
                    onClicked: {
                        listView.model = inventoryManager.getAllProducts();
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 180
                color: "#fafafa"
                border.color: "#dddddd"
                radius: 8

                ListView {
                    id: listView // Надали чіткий ідентифікатор
                    anchors.fill: parent
                    anchors.margins: 5

                    // Початкове завантаження моделі
                    model: inventoryManager.getAllProducts()

                    delegate: Item {
                        width: parent.width
                        height: 35

                        Row {
                            anchors.fill: parent
                            spacing: 10

                            Text {
                                text: modelData.name + " (" + modelData.barcode + ")"
                                width: parent.width * 0.45
                                elide: Text.ElideRight
                                font.pixelSize: 13
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Залишок: " + modelData.quantity + " " + modelData.unit
                                width: parent.width * 0.3
                                elide: Text.ElideRight
                                font.pixelSize: 13
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: modelData.price.toFixed(2) + " грн"
                                font.pixelSize: 13
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }
        }

        // Статус операції
        Text {
            text: "Статус: " + inventoryManager.statusMessage
            font.pixelSize: 13
            color: "darkblue"
        }
    }
}

// import QtQuick
// import QtQuick.Controls
// import QtMultimedia

// ApplicationWindow {
//     visible: true
//     width: 700
//     height: 950 // Збільшили висоту для нового блоку
//     title: "Облік та списання товарів"

//     Column {
//         anchors.fill: parent
//         anchors.margins: 20
//         spacing: 15

//         // --- БЛОК КАМЕРИ ---
//         Rectangle {
//             width: parent.width
//             height: 180
//             color: "black"
//             radius: 8
//             clip: true

//             CaptureSession {
//                 camera: Camera {
//                     id: camera
//                     active: true
//                 }
//                 videoOutput: videoOutput
//             }

//             VideoOutput {
//                 id: videoOutput
//                 anchors.fill: parent
//                 Component.onCompleted: {
//                     videoOutput.videoSink.videoFrameChanged.connect(barcodeDecoder.processFrame)
//                 }
//             }
//         }

//         // --- РЕЗЕРВНЕ ПОЛЕ ВВЕДЕННЯ ---
//         TextField {
//             id: barcodeInput
//             width: parent.width
//             placeholderText: "Або введіть штрих-код вручну..."
//             font.pixelSize: 16

//             onAccepted: {
//                 if (text.trim() !== "") {
//                     inventoryManager.processBarcode(text);
//                     text = "";
//                 }
//             }
//         }

//         // --- КАРТКА ПОТОЧНОГО ТОВАРУ ---
//         Rectangle {
//             width: parent.width
//             height: 100
//             color: "#f0f0f0"
//             border.color: "#cccccc"
//             radius: 8

//             Column {
//                 anchors.centerIn: parent
//                 spacing: 6
//                 width: parent.width - 40

//                 Text {
//                     text: "Назва: " + inventoryManager.currentProductName
//                     font.pixelSize: 16
//                     font.bold: true
//                 }
//                 Text {
//                     text: "Поточний залишок: " + inventoryManager.currentProductQuantity
//                     font.pixelSize: 14
//                 }
//             }
//         }

//         // --- БЛОК СПИСАННЯ ---
//         Row {
//             spacing: 10
//             width: parent.width

//             TextField {
//                 id: writeOffAmount
//                 width: 120
//                 text: "1"
//                 validator: DoubleValidator { bottom: 0.1; top: 100000.0 }
//             }

//             Button {
//                 text: "Списати товар"
//                 onClicked: {
//                     inventoryManager.writeOff(parseFloat(writeOffAmount.text));
//                     databaseModel.modelData = inventoryManager.getAllProducts();
//                 }
//             }
//         }

//         // --- БЛОК ДОДАВАННЯ НОВОГО ТОВАРУ ---
//         Rectangle {
//             width: parent.width
//             height: 140
//             color: "#f9f9f9"
//             border.color: "#cccccc"
//             radius: 8

//             Column {
//                 anchors.centerIn: parent
//                 spacing: 8
//                 width: parent.width - 30

//                 Text {
//                     text: "Додати / Оновити товар вручну:"
//                     font.pixelSize: 14
//                     font.bold: true
//                 }

//                 Row {
//                     spacing: 8
//                     width: parent.width

//                     TextField {
//                         id: newBarcodeField
//                         width: parent.width * 0.45
//                         placeholderText: "Штрих-код"
//                         font.pixelSize: 13
//                     }

//                     TextField {
//                         id: newNameField
//                         width: parent.width * 0.52
//                         placeholderText: "Назва товару"
//                         font.pixelSize: 13
//                     }
//                 }

//                 Row {
//                     spacing: 8
//                     width: parent.width

//                     TextField {
//                         id: newQuantityField
//                         width: parent.width * 0.35
//                         placeholderText: "Кількість"
//                         text: "1"
//                         validator: DoubleValidator { bottom: 0.0; top: 1000000.0 }
//                         font.pixelSize: 13
//                     }

//                     TextField {
//                         id: newUnitField
//                         width: parent.width * 0.30
//                         placeholderText: "Од. (шт/кг)"
//                         text: "шт"
//                         font.pixelSize: 13
//                     }

//                     Button {
//                         text: "Зберегти"
//                         width: parent.width * 0.32
//                         onClicked: {
//                             inventoryManager.addProduct(
//                                 newBarcodeField.text,
//                                 newNameField.text,
//                                 parseFloat(newQuantityField.text),
//                                 newUnitField.text
//                             );
//                             newBarcodeField.text = "";
//                             newNameField.text = "";
//                             newQuantityField.text = "1";
//                             databaseModel.modelData = inventoryManager.getAllProducts();
//                         }
//                     }
//                 }
//             }
//         }

//         // --- БЛОК ПЕРЕГЛЯДУ ВСІЄЇ БАЗИ ДАНИХ ---
//         Column {
//             width: parent.width
//             spacing: 5

//             Row {
//                 width: parent.width
//                 spacing: 10

//                 Text {
//                     text: "Актуальні товари в базі:"
//                     font.pixelSize: 16
//                     font.bold: true
//                     anchors.verticalCenter: parent.verticalCenter
//                 }

//                 Button {
//                     text: "Оновити список"
//                     onClicked: {
//                         databaseModel.modelData = inventoryManager.getAllProducts();
//                     }
//                 }
//             }

//             Rectangle {
//                 width: parent.width
//                 height: 180
//                 color: "#fafafa"
//                 border.color: "#dddddd"
//                 radius: 8

//                 ListView {
//                     id: databaseModel
//                     anchors.fill: parent
//                     anchors.margins: 5
//                     Component.onCompleted: {
//                         modelData = inventoryManager.getAllProducts();
//                     }

//                     delegate: Item {
//                         width: parent.width
//                         height: 35

//                         Row {
//                             anchors.fill: parent
//                             spacing: 10

//                             Text {
//                                 text: modelData.name + " (" + modelData.barcode + ")"
//                                 width: parent.width * 0.6
//                                 elide: Text.ElideRight
//                                 font.pixelSize: 13
//                                 anchors.verticalCenter: parent.verticalCenter
//                             }
//                             Text {
//                                 text: "Залишок: " + modelData.quantity + " " + modelData.unit
//                                 font.pixelSize: 13
//                                 font.bold: true
//                                 anchors.verticalCenter: parent.verticalCenter
//                             }
//                         }
//                     }
//                 }
//             }
//         }

//         // Статус операції
//         Text {
//             text: "Статус: " + inventoryManager.statusMessage
//             font.pixelSize: 13
//             color: "darkblue"
//         }
//     }
// }

// import QtQuick
// import QtQuick.Controls
// import QtMultimedia

// ApplicationWindow {
//     visible: true
//     width: 700
//     height: 850 // Збільшили висоту для списку товарів
//     title: "Облік та списання товарів"

//     Column {
//         anchors.fill: parent
//         anchors.margins: 20
//         spacing: 15

//         // --- БЛОК КАМЕРИ ---
//         Rectangle {
//             width: parent.width
//             height: 180
//             color: "black"
//             radius: 8
//             clip: true

//             CaptureSession {
//                 camera: Camera {
//                     id: camera
//                     active: true
//                 }
//                 videoOutput: videoOutput
//             }

//             VideoOutput {
//                 id: videoOutput
//                 anchors.fill: parent
//                 Component.onCompleted: {
//                     videoOutput.videoSink.videoFrameChanged.connect(barcodeDecoder.processFrame)
//                 }
//             }
//         }

//         // --- РЕЗЕРВНЕ ПОЛЕ ВВЕДЕННЯ ---
//         TextField {
//             id: barcodeInput
//             width: parent.width
//             placeholderText: "Або введіть штрих-код вручну..."
//             font.pixelSize: 16

//             onAccepted: {
//                 if (text.trim() !== "") {
//                     inventoryManager.processBarcode(text);
//                     text = "";
//                 }
//             }
//         }

//         // --- КАРТКА ПОТОЧНОГО ТОВАРУ ---
//         Rectangle {
//             width: parent.width
//             height: 100
//             color: "#f0f0f0"
//             border.color: "#cccccc"
//             radius: 8

//             Column {
//                 anchors.centerIn: parent
//                 spacing: 6
//                 width: parent.width - 40

//                 Text {
//                     text: "Назва: " + inventoryManager.currentProductName
//                     font.pixelSize: 16
//                     font.bold: true
//                 }
//                 Text {
//                     text: "Поточний залишок: " + inventoryManager.currentProductQuantity
//                     font.pixelSize: 14
//                 }
//             }
//         }

//         // --- БЛОК СПИСАННЯ ---
//         Row {
//             spacing: 10
//             width: parent.width

//             TextField {
//                 id: writeOffAmount
//                 width: 120
//                 text: "1"
//                 validator: DoubleValidator { bottom: 0.1; top: 100000.0 }
//             }

//             Button {
//                 text: "Списати товар"
//                 onClicked: {
//                     inventoryManager.writeOff(parseFloat(writeOffAmount.text));
//                     // Оновлюємо список бази після списання
//                     databaseModel.modelData = inventoryManager.getAllProducts();
//                 }
//             }
//         }

//         // --- БЛОК ПЕРЕГЛЯДУ ВСІЄЇ БАЗИ ДАНИХ ---
//         Column {
//             width: parent.width
//             spacing: 5

//             Row {
//                 width: parent.width
//                 spacing: 10

//                 Text {
//                     text: "Актуальні товари в базі:"
//                     font.pixelSize: 16
//                     font.bold: true
//                     anchors.verticalCenter: parent.verticalCenter
//                 }

//                 Button {
//                     text: "Оновити список"
//                     onClicked: {
//                         // Завантажуємо актуальні дані з C++ у модель списку
//                         databaseModel.modelData = inventoryManager.getAllProducts();
//                     }
//                 }
//             }

//             // Список для виведення всіх товарів
//             Rectangle {
//                 width: parent.width
//                 height: 180
//                 color: "#fafafa"
//                 border.color: "#dddddd"
//                 radius: 8

//                 ListView {
//                     id: databaseModel
//                     anchors.fill: parent
//                     anchors.margins: 5
//                     // Автоматично завантажуємо дані при запуску
//                     Component.onCompleted: {
//                         modelData = inventoryManager.getAllProducts();
//                     }

//                     delegate: Item {
//                         width: parent.width
//                         height: 35

//                         Row {
//                             anchors.fill: parent
//                             spacing: 10

//                             Text {
//                                 text: modelData.name + " (" + modelData.barcode + ")"
//                                 width: parent.width * 0.6
//                                 elide: Text.ElideRight
//                                 font.pixelSize: 13
//                                 anchors.verticalCenter: parent.verticalCenter
//                             }
//                             Text {
//                                 text: "Залишок: " + modelData.quantity + " " + modelData.unit
//                                 font.pixelSize: 13
//                                 font.bold: true
//                                 anchors.verticalCenter: parent.verticalCenter
//                             }
//                         }
//                     }
//                 }
//             }
//         }

//         // Статус операції
//         Text {
//             text: "Статус: " + inventoryManager.statusMessage
//             font.pixelSize: 13
//             color: "darkblue"
//         }
//     }
// }

// import QtQuick
// import QtQuick.Controls
// import QtMultimedia // Обов'язково для роботи з камерою в Qt 6

// ApplicationWindow {
//     visible: true
//     width: 700
//     height: 700 // Збільшили висоту, щоб помістити вікно камери
//     title: "Облік та списання товарів"

//     Column {
//         anchors.fill: parent
//         anchors.margins: 20
//         spacing: 15

//         // --- БЛОК КАМЕРИ ТА СКАНУВАННЯ ---
//         Rectangle {
//             width: parent.width
//             height: 200
//             color: "black"
//             radius: 8
//             clip: true

//             // Сесія захоплення відео з камери
//             CaptureSession {
//                 camera: Camera {
//                     id: camera
//                     active: true // Автоматично запускаємо камеру при відкритті
//                 }
//                 videoOutput: videoOutput
//             }

//             // Компонент виводу відео на екран
//             VideoOutput {
//                 id: videoOutput
//                 anchors.fill: parent

//                 // Прив'язка videoSink до нашого C++ класу barcodeDecoder
//                 Component.onCompleted: {
//                     videoOutput.videoSink.videoFrameChanged.connect(barcodeDecoder.processFrame)
//                 }
//             }

//             Text {
//                 anchors.centerIn: parent
//                 text: "Наведіть камеру на штрих-код..."
//                 color: "white"
//                 opacity: 0.6
//                 font.pixelSize: 14
//                 // Ховаємо підказку, коли камера активна (опціонально)
//                 visible: !camera.active
//             }
//         }

//         // Поле для ручного введення (резервний варіант)
//         TextField {
//             id: barcodeInput
//             width: parent.width
//             placeholderText: "Або введіть штрих-код вручну..."
//             font.pixelSize: 18

//             onAccepted: {
//                 if (text.trim() !== "") {
//                     inventoryManager.processBarcode(text);
//                     text = "";
//                 }
//             }
//         }

//         // Картка знайденого товару
//         Rectangle {
//             width: parent.width
//             height: 130
//             color: "#f0f0f0"
//             border.color: "#cccccc"
//             radius: 8

//             Column {
//                 anchors.centerIn: parent
//                 spacing: 10
//                 width: parent.width - 40

//                 Text {
//                     text: "Назва: " + inventoryManager.currentProductName
//                     font.pixelSize: 18
//                     font.bold: true
//                 }
//                 Text {
//                     text: "Поточний залишок: " + inventoryManager.currentProductQuantity
//                     font.pixelSize: 16
//                 }
//             }
//         }

//         // Блок списання
//         Row {
//             spacing: 10
//             width: parent.width

//             TextField {
//                 id: writeOffAmount
//                 width: 150
//                 text: "1"
//                 validator: DoubleValidator { bottom: 0.1; top: 100000.0 }
//             }

//             Button {
//                 text: "Списати товар"
//                 onClicked: {
//                     inventoryManager.writeOff(parseFloat(writeOffAmount.text));
//                 }
//             }
//         }

//         // Статус операції
//         Text {
//             text: "Статус: " + inventoryManager.statusMessage
//             font.pixelSize: 14
//             color: "darkblue"
//         }
//     }
// }

// import QtQuick
// import QtQuick.Controls

// ApplicationWindow {
//     visible: true
//     width: 700
//     height: 500
//     title: "Облік та списання товарів"

//     Column {
//         anchors.fill: parent
//         anchors.margins: 20
//         spacing: 15

//         // Поле для сканера / ручного введення
//         TextField {
//             id: barcodeInput
//             width: parent.width
//             placeholderText: "Скануйте штрих-код або введіть вручну..."
//             font.pixelSize: 18
//             focus: true // Завжди тримаємо фокус

//             onAccepted: {
//                 if (text.trim() !== "") {
//                     inventoryManager.processBarcode(text);
//                     text = ""; // Очищуємо поле для наступного скану
//                 }
//             }
//         }

//         // Картка знайденого товару
//         Rectangle {
//             width: parent.width
//             height: 150
//             color: "#f0f0f0"
//             border.color: "#cccccc"
//             radius: 8

//             Column {
//                 anchors.centerIn: parent
//                 spacing: 10
//                 width: parent.width - 40

//                 Text {
//                     text: "Назва: " + inventoryManager.currentProductName
//                     font.pixelSize: 18
//                     font.bold: true
//                 }
//                 Text {
//                     text: "Поточний залишок: " + inventoryManager.currentProductQuantity
//                     font.pixelSize: 16
//                 }
//             }
//         }

//         // Блок списання
//         Row {
//             spacing: 10
//             width: parent.width

//             TextField {
//                 id: writeOffAmount
//                 width: 150
//                 text: "1"
//                 validator: DoubleValidator { bottom: 0.1; top: 100000.0 }
//             }

//             Button {
//                 text: "Списати товар"
//                 onClicked: {
//                     inventoryManager.writeOff(parseFloat(writeOffAmount.text));
//                 }
//             }
//         }

//         // Статус операції
//         Text {
//             text: "Статус: " + inventoryManager.statusMessage
//             font.pixelSize: 14
//             color: "darkblue"
//         }
//     }
// }