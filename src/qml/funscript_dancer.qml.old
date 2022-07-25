import QtQuick 2.2
import QtQuick.Dialogs 1.0
import QtQuick.Controls 1.0
import org.julialang 1.0

ApplicationWindow {
  title: "FileDialog"
  width: 640
  height: 480
  visible: true

  FileDialog {
      id: fileDialog
      title: "Please choose a media file"
      selectMultiple: false
      folder: shortcuts.home
      onAccepted: {
          Julia.open_file(fileDialog.fileUrl)
          Qt.quit()
      }
      onRejected: {
          console.log("Canceled")
          Qt.quit()
      }
      Component.onCompleted: visible = true
  }
}