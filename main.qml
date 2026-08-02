import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

ApplicationWindow {
    visible: true
    width: 700
    height: 950
    title: "Облік та списання товарів"

    function recalcSum() {
        var qty = parseFloat(newQuantityField.text) || 0;
        var price = parseFloat(newPriceField.text) || 0;
        newSumField.text = (qty * price).toFixed(2);
    }

    header: TabBar {
        id: pageTabBar

        onCurrentIndexChanged: {
            if (currentIndex === 0) {
                barcodeInput.forceActiveFocus();
            }
        }

        TabButton {
            text: "🏠  Головна"
        }
        TabButton {
            text: "🧾  Історія оприбуткувань"
        }
        /* Тимчасово вимкнено
        TabButton {
            text: "📋  Картка обліку (М-14)"
        }
        */
    }

    StackLayout {
        anchors.fill: parent
        currentIndex: pageTabBar.currentIndex

        // ==================== СТОРІНКА 1: ГОЛОВНА ====================
        Flickable {
        anchors.fill: parent
        anchors.margins: 20
        contentWidth: width
        contentHeight: mainColumn.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
            id: mainColumn
            width: parent.width
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

            Component.onCompleted: forceActiveFocus()

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
                    listView.model = inventoryManager.getRecentProducts();
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
                        KeyNavigation.tab: productAutoFilled ? newQuantityField : newNameField
                        onTextChanged: {
                            var product = inventoryManager.findProductByBarcode(text);
                            if (product.found) {
                                newNameField.text = product.name;
                                newUnitField.editText = product.unit;
                                newPriceField.text = product.price.toFixed(2);
                                productAutoFilled = true;
                            } else if (productAutoFilled) {
                                newNameField.text = "";
                                newUnitField.editText = "шт";
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
                        KeyNavigation.tab: newQuantityField
                        KeyNavigation.backtab: newBarcodeField
                    }
                }

                Row {
                    spacing: 8
                    width: parent.width

                    TextField {
                        id: newQuantityField
                        width: parent.width * 0.22
                        placeholderText: "Кількість"
                        text: "1"
                        validator: DoubleValidator { bottom: 0.0; top: 1000000.0 }
                        font.pixelSize: 13
                        onTextChanged: recalcSum()
                        KeyNavigation.tab: newBarcodeField.productAutoFilled ? newPriceField : newUnitField
                        KeyNavigation.backtab: newBarcodeField.productAutoFilled ? newBarcodeField : newNameField
                    }

                    ComboBox {
                        id: newUnitField
                        width: parent.width * 0.20
                        font.pixelSize: 13
                        editable: true
                        model: ["шт", "кг", "г", "л", "мл", "м", "м²", "м³", "уп", "компл"]
                        currentIndex: 0
                        enabled: !newBarcodeField.productAutoFilled
                        KeyNavigation.tab: newPriceField
                        KeyNavigation.backtab: newQuantityField
                    }

                    TextField {
                        id: newPriceField
                        width: parent.width * 0.22
                        placeholderText: "Ціна, грн"
                        text: "0.00"
                        validator: DoubleValidator { bottom: 0.0; top: 1000000.0; decimals: 2; locale: "en_US" }
                        font.pixelSize: 13
                        onTextChanged: recalcSum()
                        KeyNavigation.tab: newSumField
                        KeyNavigation.backtab: newBarcodeField.productAutoFilled ? newQuantityField : newUnitField
                    }

                    TextField {
                        id: newSumField
                        width: parent.width * 0.22
                        placeholderText: "Сума, грн"
                        text: "0.00"
                        validator: DoubleValidator { bottom: 0.0; top: 100000000.0; decimals: 2; locale: "en_US" }
                        font.pixelSize: 13
                        KeyNavigation.tab: saveButton
                        KeyNavigation.backtab: newPriceField
                    }
                }

                Row {
                    width: parent.width

                    Button {
                        id: saveButton
                        text: "Зберегти"
                        width: parent.width
                        KeyNavigation.backtab: newSumField
                        onClicked: {
                            inventoryManager.addProduct(
                                newBarcodeField.text,
                                newNameField.text,
                                parseFloat(newQuantityField.text),
                                newUnitField.editText,
                                parseFloat(newPriceField.text),
                                parseFloat(newSumField.text)
                            );
                            newBarcodeField.text = "";
                            newNameField.text = "";
                            newQuantityField.text = "1";
                            newPriceField.text = "0.00";
                            newSumField.text = "0.00";
                            listView.model = inventoryManager.getRecentProducts();
                            receiptsListView.model = inventoryManager.getAllReceipts();
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
                    text: "Останні 5 товарів (за останньою дією):"
                    font.pixelSize: 16
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }

                Button {
                    text: "Оновити список"
                    onClicked: {
                        listView.model = inventoryManager.getRecentProducts();
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
                    clip: true

                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    // Початкове завантаження моделі
                    model: inventoryManager.getRecentProducts()

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

        // ==================== СТОРІНКА 2: ІСТОРІЯ ОПРИБУТКУВАНЬ ====================
        Item {
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 15

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "Історія оприбуткувань:"
                        font.pixelSize: 16
                        font.bold: true
                    }

                    Button {
                        text: "Оновити історію"
                        onClicked: {
                            receiptsListView.model = inventoryManager.getAllReceipts();
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#fafafa"
                    border.color: "#dddddd"
                    radius: 8

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 5
                        spacing: 0

                        // --- Заголовок таблиці ---
                        Rectangle {
                            Layout.fillWidth: true
                            height: 32
                            color: "#e8e8e8"
                            radius: 4

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                Text {
                                    text: "№"
                                    width: parent.width * 0.05
                                    font.pixelSize: 12
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Rectangle { width: 1; height: parent.height; color: "#cccccc" }
                                Text {
                                    text: "Назва товару"
                                    width: parent.width * 0.28
                                    font.pixelSize: 12
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Rectangle { width: 1; height: parent.height; color: "#cccccc" }
                                Text {
                                    text: "Кількість"
                                    width: parent.width * 0.11
                                    font.pixelSize: 12
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Rectangle { width: 1; height: parent.height; color: "#cccccc" }
                                Text {
                                    text: "Ціна"
                                    width: parent.width * 0.12
                                    font.pixelSize: 12
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Rectangle { width: 1; height: parent.height; color: "#cccccc" }
                                Text {
                                    text: "Сума"
                                    width: parent.width * 0.12
                                    font.pixelSize: 12
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Rectangle { width: 1; height: parent.height; color: "#cccccc" }
                                Text {
                                    text: "Дата та час"
                                    width: parent.width * 0.16
                                    font.pixelSize: 12
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Rectangle { width: 1; height: parent.height; color: "#cccccc" }
                                Text {
                                    text: "Штрих-код"
                                    width: parent.width * 0.15
                                    font.pixelSize: 12
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        // --- Рядки таблиці ---
                        ListView {
                            id: receiptsListView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                            model: inventoryManager.getAllReceipts()

                            delegate: Rectangle {
                                width: parent.width
                                height: 32
                                color: index % 2 === 0 ? "#ffffff" : "#f2f2f2"

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    Text {
                                        text: index + 1
                                        width: parent.width * 0.05
                                        font.pixelSize: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Rectangle { width: 1; height: parent.height; color: "#e0e0e0" }
                                    Text {
                                        text: modelData.name
                                        width: parent.width * 0.28
                                        elide: Text.ElideRight
                                        font.pixelSize: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Rectangle { width: 1; height: parent.height; color: "#e0e0e0" }
                                    Text {
                                        text: modelData.quantity + " " + modelData.unit
                                        width: parent.width * 0.11
                                        elide: Text.ElideRight
                                        font.pixelSize: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Rectangle { width: 1; height: parent.height; color: "#e0e0e0" }
                                    Text {
                                        text: modelData.price.toFixed(2) + " грн"
                                        width: parent.width * 0.12
                                        elide: Text.ElideRight
                                        font.pixelSize: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Rectangle { width: 1; height: parent.height; color: "#e0e0e0" }
                                    Text {
                                        text: modelData.sum.toFixed(2) + " грн"
                                        width: parent.width * 0.12
                                        elide: Text.ElideRight
                                        font.pixelSize: 12
                                        font.bold: true
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Rectangle { width: 1; height: parent.height; color: "#e0e0e0" }
                                    Text {
                                        text: modelData.timestamp.replace("T", " ")
                                        width: parent.width * 0.16
                                        font.pixelSize: 12
                                        color: "#555555"
                                        elide: Text.ElideRight
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Rectangle { width: 1; height: parent.height; color: "#e0e0e0" }
                                    Text {
                                        text: modelData.barcode
                                        width: parent.width * 0.15
                                        font.pixelSize: 12
                                        color: "#555555"
                                        elide: Text.ElideRight
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 1
                                    color: "#e0e0e0"
                                    anchors.bottom: parent.bottom
                                }
                            }
                        }
                    }
                }
            }
        }

        // ==================== СТОРІНКА 3: КАРТКА ОБЛІКУ (М-14) ====================
        /* Тимчасово вимкнено
        Item {
            id: stockCardPage
            property var stockCard: ({ found: false })

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 15

                Text {
                    text: "Картка складського обліку матеріалу (типова форма № М-14)"
                    font.pixelSize: 16
                    font.bold: true
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }

                TextField {
                    id: cardBarcodeField
                    Layout.fillWidth: true
                    placeholderText: "Введіть штрих-код товару..."
                    font.pixelSize: 14
                    onTextChanged: {
                        stockCardPage.stockCard = inventoryManager.getStockCard(text);
                    }
                }

                Text {
                    visible: cardBarcodeField.text.length > 0 && !stockCardPage.stockCard.found
                    text: "Товар з таким штрих-кодом не знайдено."
                    color: "#a33"
                    font.pixelSize: 13
                }

                Rectangle {
                    visible: stockCardPage.stockCard.found
                    Layout.fillWidth: true
                    height: 90
                    color: "#f0f0f0"
                    border.color: "#cccccc"
                    radius: 8

                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        width: parent.width - 40

                        Text {
                            text: "Матеріал: " + (stockCardPage.stockCard.name || "")
                            font.pixelSize: 15
                            font.bold: true
                        }
                        Text {
                            text: "Одиниця виміру: " + (stockCardPage.stockCard.unit || "")
                                  + "    Ціна: " + (stockCardPage.stockCard.price !== undefined ? stockCardPage.stockCard.price.toFixed(2) : "0.00") + " грн"
                            font.pixelSize: 13
                        }
                        Text {
                            text: "Поточний залишок: " + (stockCardPage.stockCard.quantity !== undefined ? stockCardPage.stockCard.quantity : "0")
                            font.pixelSize: 13
                            font.bold: true
                        }
                    }
                }

                Text {
                    visible: stockCardPage.stockCard.found
                    text: "Рух матеріалу (прихід / витрата / залишок):"
                    font.pixelSize: 14
                    font.bold: true
                }

                Rectangle {
                    visible: stockCardPage.stockCard.found
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#fafafa"
                    border.color: "#dddddd"
                    radius: 8

                    ListView {
                        id: movementsListView
                        anchors.fill: parent
                        anchors.margins: 5
                        clip: true
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        model: stockCardPage.stockCard.movements ? stockCardPage.stockCard.movements : []

                        delegate: Item {
                            width: parent.width
                            height: 30

                            Row {
                                anchors.fill: parent
                                spacing: 8

                                Text {
                                    text: modelData.date.replace("T", " ")
                                    width: parent.width * 0.18
                                    font.pixelSize: 12
                                    color: "#555555"
                                    elide: Text.ElideRight
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: modelData.type
                                    width: parent.width * 0.15
                                    font.pixelSize: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "прихід: " + (modelData.quantityIn > 0 ? modelData.quantityIn : "-")
                                    width: parent.width * 0.16
                                    font.pixelSize: 12
                                    color: "#2a7a2a"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "витрата: " + (modelData.quantityOut > 0 ? modelData.quantityOut : "-")
                                    width: parent.width * 0.17
                                    font.pixelSize: 12
                                    color: "#a33"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "залишок: " + modelData.balance
                                    width: parent.width * 0.16
                                    font.pixelSize: 12
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: modelData.info
                                    width: parent.width * 0.18
                                    font.pixelSize: 11
                                    color: "#777777"
                                    elide: Text.ElideRight
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }
            }
        }
        */
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