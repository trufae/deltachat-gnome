namespace Dc {

    /**
     * Converts markdown-formatted text to Pango markup for GTK labels.
     * Supports: bold, italic, strikethrough, inline code, code blocks,
     * headings, and URL linkification.
     */
    public class Markdown {

        public static bool enabled = false;

        /**
         * Format message text. Always linkifies URLs.
         * When enabled, also converts markdown syntax to Pango markup.
         */
        public static string format (string input) {
            var escaped = Markup.escape_text (input);
            if (!enabled) {
                return linkify (escaped);
            }
            try {
                return format_markdown (escaped);
            } catch (RegexError e) {
                return linkify (escaped);
            }
        }

        private static string format_markdown (string escaped) throws RegexError {
            var segments = new GenericArray<string> ();
            string work = escaped;

            /* Code blocks: ```lang\ncontent``` — extract first to protect contents */
            var cb_re = new Regex ("```(?:[a-zA-Z]*)\\n?([\\s\\S]*?)```");
            work = extract_code (cb_re, work, segments);

            /* Inline code: `content` */
            var ic_re = new Regex ("`([^`\\n]+)`");
            work = extract_code (ic_re, work, segments);

            /* Bold: **text** and __text__ */
            var bold_re = new Regex ("\\*\\*(.+?)\\*\\*");
            work = bold_re.replace (work, -1, 0, "<b>\\1</b>");
            var bold2_re = new Regex ("__(.+?)__");
            work = bold2_re.replace (work, -1, 0, "<b>\\1</b>");

            /* Italic: *text* and _text_ (after bold is consumed) */
            var italic_re = new Regex ("\\*([^\\*\\n]+)\\*");
            work = italic_re.replace (work, -1, 0, "<i>\\1</i>");
            var italic2_re = new Regex ("(?<!\\w)_([^_\\n]+)_(?!\\w)");
            work = italic2_re.replace (work, -1, 0, "<i>\\1</i>");

            /* Strikethrough: ~~text~~ */
            var strike_re = new Regex ("~~(.+?)~~");
            work = strike_re.replace (work, -1, 0, "<s>\\1</s>");

            /* Headings — process ### before ## before # */
            var h3_re = new Regex ("^### +(.+)$", RegexCompileFlags.MULTILINE);
            work = h3_re.replace (work, -1, 0, "<b>\\1</b>");
            var h2_re = new Regex ("^## +(.+)$", RegexCompileFlags.MULTILINE);
            work = h2_re.replace (work, -1, 0, "<span size=\"large\"><b>\\1</b></span>");
            var h1_re = new Regex ("^# +(.+)$", RegexCompileFlags.MULTILINE);
            work = h1_re.replace (work, -1, 0, "<span size=\"x-large\"><b>\\1</b></span>");

            /* Linkify URLs */
            work = linkify (work);

            /* Restore protected code segments */
            for (int i = 0; i < segments.length; i++) {
                work = work.replace ("\x01%d\x01".printf (i), segments[i]);
            }

            return work;
        }

        /**
         * Replace regex matches with numbered placeholders, storing the
         * matched content wrapped in <tt> tags for later restoration.
         */
        private static string extract_code (Regex re, string input,
                                             GenericArray<string> segments) throws RegexError {
            return re.replace_eval (input, -1, 0, 0, (mi, sb) => {
                int idx = (int) segments.length;
                segments.add ("<tt>" + mi.fetch (1) + "</tt>");
                sb.append ("\x01%d\x01".printf (idx));
                return false;
            });
        }

        private static string linkify (string escaped) {
            try {
                var re = new Regex ("(https?://[^\\s<>\"]+)");
                return re.replace_eval (escaped, -1, 0, 0, (mi, sb) => {
                    var url = mi.fetch (0);
                    sb.append ("<a href=\"");
                    sb.append (url);
                    sb.append ("\">");
                    sb.append (url);
                    sb.append ("</a>");
                    return false;
                });
            } catch (RegexError e) {
                return escaped;
            }
        }
    }
}
