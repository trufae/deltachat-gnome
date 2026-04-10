namespace Dc {

    /**
     * Compose bar at the bottom of the message view.
     * Contains a text entry, file attach button, and send button.
     */
    public class ComposeBar : Gtk.Box {

        public signal void send_message (string text, string? file_path, string? file_name, int quote_msg_id);
        public signal void edit_message (int msg_id, string new_text);

        private Gtk.Entry text_entry;
        private Gtk.Button send_button;
        private Gtk.Button attach_button;
        private Gtk.Button cancel_attach_button;
        private Gtk.Button cancel_edit_button;
        private Gtk.Button cancel_reply_button;
        private Gtk.Label reply_label;
        private Gtk.Box reply_bar;
        private string? pending_file = null;
        private string? pending_file_name = null;
        private int editing_msg_id = 0;
        private int replying_msg_id = 0;

        public ComposeBar () {
            Object (
                orientation: Gtk.Orientation.VERTICAL,
                spacing: 0
            );
            add_css_class ("compose-bar");
            margin_start = 8;
            margin_end = 8;
            margin_top = 6;
            margin_bottom = 6;

            /* Reply indicator bar (hidden by default) */
            reply_bar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            reply_bar.add_css_class ("reply-bar");
            reply_bar.visible = false;

            reply_label = new Gtk.Label ("");
            reply_label.add_css_class ("reply-label");
            reply_label.halign = Gtk.Align.START;
            reply_label.hexpand = true;
            reply_label.ellipsize = Pango.EllipsizeMode.END;
            reply_bar.append (reply_label);

            cancel_reply_button = new Gtk.Button.from_icon_name ("window-close-symbolic");
            cancel_reply_button.add_css_class ("flat");
            cancel_reply_button.add_css_class ("circular");
            cancel_reply_button.tooltip_text = "Cancel reply";
            cancel_reply_button.valign = Gtk.Align.CENTER;
            cancel_reply_button.clicked.connect (cancel_reply);
            reply_bar.append (cancel_reply_button);

            append (reply_bar);

            /* Input row */
            var input_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);

            /* Attach button */
            attach_button = new Gtk.Button.from_icon_name ("mail-attachment-symbolic");
            attach_button.add_css_class ("flat");
            attach_button.tooltip_text = "Attach file";
            attach_button.valign = Gtk.Align.CENTER;
            attach_button.clicked.connect (on_attach_clicked);
            input_row.append (attach_button);

            /* Cancel attachment button (hidden by default) */
            cancel_attach_button = new Gtk.Button.from_icon_name ("edit-clear-symbolic");
            cancel_attach_button.add_css_class ("flat");
            cancel_attach_button.tooltip_text = "Remove attachment";
            cancel_attach_button.valign = Gtk.Align.CENTER;
            cancel_attach_button.visible = false;
            cancel_attach_button.clicked.connect (clear_attachment);
            input_row.append (cancel_attach_button);

            /* Cancel edit button (hidden by default) */
            cancel_edit_button = new Gtk.Button.from_icon_name ("edit-undo-symbolic");
            cancel_edit_button.add_css_class ("flat");
            cancel_edit_button.tooltip_text = "Cancel editing";
            cancel_edit_button.valign = Gtk.Align.CENTER;
            cancel_edit_button.visible = false;
            cancel_edit_button.clicked.connect (cancel_edit);
            input_row.append (cancel_edit_button);

            /* Text entry with paste handler */
            text_entry = new Gtk.Entry ();
            text_entry.hexpand = true;
            text_entry.placeholder_text = "Type a message…";
            text_entry.add_css_class ("compose-entry");
            text_entry.activate.connect (on_send);
            var paste_ctrl = new Gtk.EventControllerKey ();
            paste_ctrl.key_pressed.connect (on_entry_key_pressed);
            text_entry.add_controller (paste_ctrl);
            input_row.append (text_entry);

            /* Send button */
            send_button = new Gtk.Button.from_icon_name ("go-up-symbolic");
            send_button.add_css_class ("suggested-action");
            send_button.add_css_class ("circular");
            send_button.tooltip_text = "Send message";
            send_button.valign = Gtk.Align.CENTER;
            send_button.clicked.connect (on_send);
            input_row.append (send_button);

            append (input_row);
        }

        public void grab_entry_focus () {
            /* Use grab_focus_without_selecting so that text the user is
               currently typing is not selected (and thus replaced on the
               next keystroke) when async events — e.g. an incoming message
               triggering a chatlist reload — steal focus back to the entry. */
            text_entry.grab_focus_without_selecting ();
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
            int qid = replying_msg_id;
            send_message (text, pending_file, pending_file_name, qid);
            cancel_reply ();
            clear ();
        }

        public void begin_reply (int msg_id, string sender_name, string preview) {
            cancel_edit ();
            replying_msg_id = msg_id;
            reply_label.label = "%s: %s".printf (sender_name, preview);
            reply_bar.visible = true;
            text_entry.grab_focus_without_selecting ();
        }

        private void cancel_reply () {
            replying_msg_id = 0;
            reply_bar.visible = false;
            reply_label.label = "";
        }

        public void begin_edit (int msg_id, string current_text) {
            cancel_edit ();
            cancel_reply ();
            clear_attachment ();
            editing_msg_id = msg_id;
            text_entry.text = current_text;
            text_entry.placeholder_text = "Edit message…";
            cancel_edit_button.visible = true;
            attach_button.sensitive = false;
            text_entry.grab_focus_without_selecting ();
            text_entry.set_position (-1);
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
