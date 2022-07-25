import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Layouts 1.3
import QtQuick.Controls 2.15
import QtQuick.Dialogs 1.3
import org.julialang 1.0

ApplicationWindow {
    visible: true
    minimumWidth: 640
    minimumHeight: 480
    id: applicationWindow
    title: qsTr("FunscriptDancer")

    JuliaSignals {
        signal loadStatus(var msg, var position)
        signal audioDataReady(var name, var duration)
        signal actionsReady()
        onLoadStatus: {
            loadStatus.text=msg
            loadProgress.value=position
        }
        onAudioDataReady: {
            audioPreview.enabled=true
            applicationWindow.title=qsTr("Funscript Dancer - " + name)
        }
        onActionsReady: {
            funscript.enabled=true
            save.enabled=true
        }
    }

    ColumnLayout {
        anchors.fill: parent
        GroupBox {
            title: "Audio processing"
            Layout.fillWidth: true
            RowLayout {
                Button {
                    id: loadButton
                    text: "Load"
                    onClicked: openDialog.open()
                }
                ColumnLayout {
                    TextArea {
                        id: loadStatus
                        text: "No media loaded"
                        Layout.fillWidth: true
                    }
                    ProgressBar {
                        id: loadProgress
                        from: 0
                        to: 6
                        Layout.fillWidth: true
                    }
                }
            }
        }
        GroupBox {
            id: audioPreview
            title: "Audio preview and cropping"
            Layout.fillWidth: true
            enabled: false
            ColumnLayout {
                anchors.fill: parent
                Canvas {
                    id: audioAnalysisCanvas
                    Layout.fillWidth: true
                }
                RangeSlider {
                    id: audioSlider
                    Layout.fillWidth: true
                }
            }
        }
        GroupBox {
            id: funscript
            title: "Funscript generation"
            Layout.fillWidth: true
            enabled: false
            ColumnLayout {
                anchors.fill: parent
                Slider {
                    id: multiplierSlider
                    Layout.fillWidth: true
                }

                Canvas {
                    id: heatmapCanvas
                    Layout.fillWidth: true
                }
            }
        }
        GroupBox {
            id: save
            title: "Export files"
            Layout.fillWidth: true
            enabled: false
            RowLayout {
                Layout.fillWidth: true
                Button {
                    id: saveFunscript
                    text: "Save Funscript"
                    onClicked: funscriptSaveDialog.open()
                }
                Button {
                    id: saveHeatmap
                    text: "Save heatmap"
                    onClicked: heatmapSaveDialog.open()
                }
            }
        }
    }
    FileDialog {
        id: openDialog
        title: "Choose a media file"
        nameFilters: ["Media files (*.mp4 *.avi *.mkv *.ogm *.mpg *.mpeg *.mov *.mp3 *.aac *.wav)","All files (*)"]
        folder: shortcuts.home
        onAccepted: {
            Julia.open_file(openDialog.fileUrl)
        }
    }

    FileDialog {
        id: funscriptSaveDialog
        title: "Choose a location to save the Funscript"
        defaultSuffix: "funscript"
        selectExisting: false
        folder: shortcuts.home
        onAccepted: {
            Julia.save_funscript(funscriptSaveDialog.fileUrl)
        }
    }

    FileDialog {
        id: heatmapSaveDialog
        title: "Choose a location to save the heatmap"
        defaultSuffix: "png"
        selectExisting: false
        folder: shortcuts.home
        onAccepted: {
            Julia.save_heatmap(heatmapSaveDialog.fileUrl)
        }
    }
}
