using Gtk.GConstants

function my_save_dialog(title::AbstractString, parent=GtkNullContainer(), filters::Union{AbstractVector,Tuple}=String[];
    current_folder::Union{AbstractString,Nothing}=nothing,
    current_name::Union{AbstractString,Nothing}=nothing, kwargs...)
    dlg = GtkFileChooserDialog(title, parent, GConstants.GtkFileChooserAction.SAVE,
        (("_Cancel", GConstants.GtkResponseType.CANCEL),
            ("_Save", GConstants.GtkResponseType.ACCEPT)); kwargs...)
    dlgp = GtkFileChooser(dlg)
    if !isempty(filters)
        Gtk.makefilters!(dlgp, filters)
    end
    if !isnothing(current_folder)
        ccall((:gtk_file_chooser_set_current_folder, Gtk.libgtk), Nothing, (Ptr{GObject}, Ptr{UInt8}), dlgp, current_folder)
    end
    if !isnothing(current_name)
        ccall((:gtk_file_chooser_set_current_name, Gtk.libgtk), Nothing, (Ptr{GObject}, Ptr{UInt8}), dlgp, current_name)
    end
    ccall((:gtk_file_chooser_set_do_overwrite_confirmation, Gtk.libgtk), Nothing, (Ptr{GObject}, Cint), dlg, true)
    response = run(dlg)
    if response == GConstants.GtkResponseType.ACCEPT
        selection = Gtk.bytestring(GAccessor.filename(dlgp))
    else
        selection = ""
    end
    destroy(dlg)
    return selection
end