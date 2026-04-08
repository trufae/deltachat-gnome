namespace Dc {

    /**
     * Compose bar at the bottom of the message view.
     * Contains a text entry, file attach button, and send button.
     */
    public class ComposeBar : Gtk.Box {

        public signal void send_message (string text, string? file_path, string? file_name);
        public signal void edit_message (int msg_id, string new_text);

        private Gtk.Entry text_entry;
        private Gtk.Button send_button;
        private Gtk.Button attach_button;
        private Gtk.Button cancel_attach_button;
        private Gtk.Button cancel_edit_button;
        private string? pending_file = null;
        private string? pending_file_name = null;
        private int editing_msg_id = 0;

        public ComposeBar () {
            Object (
                orientation: Gtk.Orientation.HORIZONTAL,
                spacing: 6
            );
            add_css_class ("compose-bar");
            margin_start = 8;
            margin_end = 8;
            margin_top = 6;
            margin_bottom = 6;

            /* Attach button */
            attach_button = new Gtk.Button.from_icon_name ("mail-attachment-symbolic");
            attach_button.add_css_class ("flat");
            attach_button.tooltip_text = "Attach file";
            attach_button.valign = Gtk.Align.CENTER;
            attach_button.clicked.connect (on_attach_clicked);
            append (attach_button);

            /* Cancel attachment button (hidden by default) */
            cancel_attach_button = new Gtk.Button.from_icon_name ("edit-clear-symbolic");
            cancel_attach_button.add_css_class ("flat");
            cancel_attach_button.tooltip_text = "Remove attachment";
            cancel_attach_button.valign = Gtk.Align.CENTER;
            cancel_attach_button.visible = false;
            cancel_attach_button.clicked.connect (clear_attachment);
            append (cancel_attach_button);

            /* Cancel edit button (hidden by default) */
            cancel_edit_button = new Gtk.Button.from_icon_name ("edit-undo-symbolic");
            cancel_edit_button.add_css_class ("flat");
            cancel_edit_button.tooltip_text = "Cancel editing";
            cancel_edit_button.valign = Gtk.Align.CENTER;
            cancel_edit_button.visible = false;
            cancel_edit_button.clicked.connect (cancel_edit);
            append (cancel_edit_button);

            /* Text entry with paste handler */
            text_entry = new Gtk.Entry ();
            text_entry.hexpand = true;
            text_entry.placeholder_text = "Type a message…";
            text_entry.add_css_class ("compose-entry");
            text_entry.activate.connect (on_send);
            var paste_ctrl = new Gtk.EventControllerKey ();
            paste_ctrl.key_pressed.connect (on_entry_key_pressed);
            text_entry.add_controller (paste_ctrl);
            append (text_entry);

            /* Send button */
            send_button = new Gtk.Button.from_icon_name ("go-up-symbolic");
            send_button.add_css_class ("suggested-action");
            send_button.add_css_class ("circular");
            send_button.tooltip_text = "Send message";
            send_button.valign = Gtk.Align.CENTER;
            send_button.clicked.connect (on_send);
            append (send_button);
        }

        public void grab_entry_focus () {
            text_entry.grab_focus ();
        }

        public void clear () {
            text_entry.text = "";
            clear_attachment ();
        }

        public bool can_accept_attachment () {
            return editing_msg_id == 0;
        }

        public void set_pending_attachment (string file_path, string? file_name = null) {
            pending_file = file_path;
            pending_file_name = file_name ?? Path.get_basename (file_path);
            text_entry.text = "";
            text_entry.placeholder_text = "📎 %s — Type a caption…".printf (pending_file_name);
            cancel_attach_button.visible = true;
        }

        private void clear_attachment () {
            pending_file = null;
            pending_file_name = null;
            cancel_attach_button.visible = false;
            text_entry.placeholder_text = "Type a message…";
        }

        private void on_send () {
            string text = text_entry.text.strip ();
            if (editing_msg_id > 0) {
                if (text.length == 0) return;
                edit_message (editing_msg_id, text);
                cancel_edit ();
                return;
            }
            if (text.length == 0 && pending_file == null) return;
            send_message (text, pending_file, pending_file_name);
            clear ();
        }

        public void begin_edit (int msg_id, string current_text) {
            cancel_edit ();
            clear_attachment ();
            editing_msg_id = msg_id;
            text_entry.text = current_text;
            text_entry.placeholder_text = "Edit message…";
            cancel_edit_button.visible = true;
            attach_button.sensitive = false;
            text_entry.grab_focus ();
        }

        private void cancel_edit () {
            if (editing_msg_id == 0) return;
            editing_msg_id = 0;
            text_entry.text = "";
            text_entry.placeholder_text = "Type a message…";
            cancel_edit_button.visible = false;
            attach_button.sensitive = true;
        }

        private void on_attach_clicked () {
            var dialog = new Gtk.FileDialog ();
            dialog.title = "Select file to attach";
            var window = (Gtk.Window) get_root ();
            dialog.open.begin (window, null, (obj, res) => {
                try {
                    var file = dialog.open.end (res);
                    if (file != null) {
                        var path = file.get_path ();
                        if (path != null)
                            set_pending_attachment (path, file.get_basename ());
                    }
                } catch (Error e) {
                }
            });
        }

        private bool on_entry_key_pressed (uint keyval, uint keycode,
                                           Gdk.ModifierType state) {
            if (!can_accept_attachment ()) return false;
            bool ctrl_v = (state & Gdk.ModifierType.CONTROL_MASK) != 0
                        && (keyval == Gdk.Key.v || keyval == Gdk.Key.V);
            if (!ctrl_v && !((state & Gdk.ModifierType.SHIFT_MASK) != 0
                             && keyval == Gdk.Key.Insert)) return false;

            var clipboard = get_display ().get_clipboard ();
            var formats = clipboard.get_formats ();
            if (formats.contain_gtype (typeof (Gdk.FileList))) {
                paste_file_list.begin (clipboard);
                return true;
            }
            if (formats.contain_gtype (typeof (Gdk.Texture))) {
                paste_texture.begin (clipboard);
                return true;
            }
            return false;
        }

        private async void paste_file_list (Gdk.Clipboard clipboard) {
            try {
                var value = yield clipboard.read_value_async (typeof (Gdk.FileList),
                                                              Priority.DEFAULT, null);
                if (value == null) return;
                var fl = (Gdk.FileList?) value.get_boxed ();
                if (fl == null) return;
                var files = fl.get_files ();
                if (files != null && files.data != null) {
                    var path = files.data.get_path ();
                    if (path != null)
                        set_pending_attachment (path, files.data.get_basename ());
                }
            } catch (Error e) {
            }
        }

        private async void paste_texture (Gdk.Clipboard clipboard) {
            try {
                var texture = yield clipboard.read_texture_async (null);
                if (texture == null) return;
                GLib.FileIOStream stream;
                var tmp = GLib.File.new_tmp ("deltachat-gnome-XXXXXX.png", out stream);
                stream.close ();
                string path = tmp.get_path ();
                if (texture.save_to_png (path))
                    set_pending_attachment (path, "pasted-image.png");
            } catch (Error e) {
            }
        }
    }
}
