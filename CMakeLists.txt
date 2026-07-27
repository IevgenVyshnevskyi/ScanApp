cmake_minimum_required(VERSION 3.16)

project(ScanApp VERSION 0.1 LANGUAGES CXX)

set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(QT NAMES Qt6 Qt5 REQUIRED COMPONENTS Core Gui Quick Sql Multimedia)
find_package(Qt${QT_VERSION_MAJOR} REQUIRED COMPONENTS Core Gui Quick Sql Multimedia)

# Автоматичне завантаження бібліотеки ZXing-cpp для камери
include(FetchContent)
FetchContent_Declare(
    zxing-cpp
    GIT_REPOSITORY https://github.com/zxing-cpp/zxing-cpp.git
    GIT_TAG v2.2.1
)
set(BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(BUILD_UNIT_TESTS OFF CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(zxing-cpp)

# Виключено зайвий qrc.qrc, оскільки використовується qt_add_qml_module
set(PROJECT_SOURCES
    main.cpp
    barcodedecoder.h
    barcodedecoder.cpp
    inventorymanager.h
    inventorymanager.cpp
)

if(${QT_VERSION_MAJOR} GREATER_EQUAL 6)
    qt_add_executable(ScanApp
        MANUAL_FINALIZATION
        ${PROJECT_SOURCES}
    )

    # Підключення ресурсів QML через сучасний модуль
    qt_add_qml_module(ScanApp
        URI ScanApp
        QML_FILES main.qml
    )
else()
    add_executable(ScanApp
        ${PROJECT_SOURCES}
        main.qml
    )
endif()

target_link_libraries(ScanApp PRIVATE
    Qt${QT_VERSION_MAJOR}::Core
    Qt${QT_VERSION_MAJOR}::Quick
    Qt${QT_VERSION_MAJOR}::Gui
    Qt${QT_VERSION_MAJOR}::Sql
    Qt${QT_VERSION_MAJOR}::Multimedia
    ZXing::ZXing
)

target_include_directories(ScanApp PRIVATE
    ${zxing-cpp_SOURCE_DIR}/core/src
)

set_target_properties(ScanApp PROPERTIES
    WIN32_EXECUTABLE TRUE
)

include(GNUInstallDirs)
install(TARGETS ScanApp
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

if(QT_VERSION_MAJOR EQUAL 6)
    qt_import_qml_plugins(ScanApp)
    qt_finalize_executable(ScanApp)
endif()