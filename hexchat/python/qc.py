# Copyright (c) 2014 SoniEx2
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

__module_name__ = "Queercraft"
__module_version__ = "3.0.0"
__module_description__ = "QueercraftBOT thingy"
__module_author__ = "SoniEx2"

import hexchat
import re


class BoolConfig:

    def __init__(self, name, default, **kwargs):
        self.name = name
        self.statusmsg = kwargs
        if hexchat.get_pluginpref("queercraft_{}".format(name)):
            self.setter(hexchat.get_pluginpref("queercraft_{}".format(name)) == "True")
        else:
            self.setter(default)

    def setter(self, value):
        self.value = value
        hexchat.set_pluginpref("queercraft_{}".format(self.name), str(value))
        if value and self.statusmsg.get("true", None):
            hexchat.prnt(self.statusmsg["true"])
        elif (not value) and self.statusmsg.get("false", None):
            hexchat.prnt(self.statusmsg["false"])

    def hexchat_setter(self, word, word_eol, userdata):
        if len(word) >= 2:
            if word[1][0].lower() == "t":
                self.setter(True)
            if word[1][0].lower() == "f":
                self.setter(False)
        return hexchat.EAT_ALL

    def __bool__(self):
        return self.value

#make color setting
_cols = BoolConfig("cols", True, true="Colors enabled", false="Colors disabled")
hexchat.hook_command("enableqccolors", _cols.hexchat_setter, help="/enableqccolors true|false")

#make badge setting
_badge = BoolConfig("badge", True, true="Rank symbols enabled", false="Rank symbols disabled")
hexchat.hook_command("enableqcranks", _badge.hexchat_setter, help="/enableqcranks true|false. "
    "Please see "
    "http://hexchat.readthedocs.org/en/latest/faq.html"  # use a full link here
    "#how-do-i-show-and-in-front-of-nicknames-that-are-op-and-voice-when-they-talk"
    " before using this.")

#hexchat parsing stuff
hexchat_textevent_parser = re.compile("%([%RIBOUCH])")
hexchat_textevent_map = {
    '%': '%',     # escape
    'R': '\x16',  # swap/reverse
    'I': '\x1d',  # italic
    'B': '\x02',  # bold
    'O': '\x0f',  # reset
    'U': '\x1f',  # underline
    'C': '\x03',  # color
    'H': '\x08',  # hidden
    }


def hexchat_sub_escape(matchobj):
    return hexchat_textevent_map[matchobj.group(1)]


def hexchat_parse(s):
    return hexchat_textevent_parser.sub(hexchat_sub_escape, s)


def compile_colors(s):
    return re.compile(hexchat_parse(s))


def compress_colors(s):
    skip = 0
    ns = []
    for pos, token in enumerate(s):
        if not skip:
            ns.append(token)
        else:
            skip -= 1
        if token == "\x03":
            try:
                if s[pos + 1] == "0" and s[pos + 2] in '0123456789' and not s[pos + 3] in '0123456789':
                    skip = 1
            except IndexError:
                try:
                    if s[pos + 1] == "0" and s[pos + 2] in '0123456789':
                        skip = 1
                except IndexError:
                    pass
    return "".join(ns)


class Formatting(object):
    """IRC Attribute/formatting stuff.

    Notes:
    Add target formatting to current formatting before printing.
    """
    # constants
    HIDDEN = True
    VISIBLE = False
    BOLD = True
    ITALIC = True
    UNDERLINE = True
    NORMAL = False

    # mIRC colors
    # this is ugly but idk better ;_; blame python 2
    class COLORS:
        DEFAULT = 99
        NO_CHANGE = -1
        DEFAULT_FG = -2
        DEFAULT_BG = -3
        WHITE = 0
        BLACK = 1
        BLUE = 2
        GREEN = 3
        RED = 4
        BROWN = 5
        PURPLE = 6
        ORANGE = 7
        YELLOW = 8
        LIGHT_GREEN = 9
        TEAL = 10
        LIGHT_CYAN = 11
        LIGHT_BLUE = 12
        PINK = 13
        GREY = 14
        LIGHT_GREY = 15
        # damn you english
        GRAY = 14
        LIGHT_GRAY = 15

        def __init__(self):
            raise TypeError

    # reset formatting
    # set outside class
    RESET = None

    # Formatting(Cf, Cb, H, B, I, U)
    def __init__(self, foreground, background, hidden, bold, italic, underline):
        self._foreground = foreground
        self._background = background
        self._foreground = self.foreground  # heh
        self._background = self.background
        self._hidden = hidden
        self._bold = bold
        self._italic = italic
        self._underline = underline

    @property
    def foreground(self):
        return self._foreground if self._foreground < 0 and self._foreground >= -3 else self._foreground % 100

    @property
    def background(self):
        return self._background if self._background < 0 and self._background >= -3 else self._background % 100

    @property
    def hidden(self):
        return self._hidden

    @property
    def bold(self):
        return self._bold

    @property
    def italic(self):
        return self._italic

    @property
    def underline(self):
        return self._underline

    def set_foreground(self, foreground):
        return Formatting(foreground, self.background, self.hidden, self.bold, self.italic, self.underline)

    def set_background(self, background):
        return Formatting(self.foreground, background, self.hidden, self.bold, self.italic, self.underline)

    def set_hidden(self, hidden):
        return Formatting(self.foreground, self.background, hidden, self.bold, self.italic, self.underline)

    def set_bold(self, bold):
        return Formatting(self.foreground, self.background, self.hidden, bold, self.italic, self.underline)

    def set_italic(self, italic):
        return Formatting(self.foreground, self.background, self.hidden, self.bold, italic, self.underline)

    def set_underline(self, underline):
        return Formatting(self.foreground, self.background, self.hidden, self.bold, self.italic, underline)

    def reverse(self):
        return Formatting(self.background, self.foreground, self.hidden, self.bold, self.italic, self.underline)

    def __repr__(self):
        # TODO use names
        return "Formatting({!r}, {!r}, {!r}, {!r}, {!r}, {!r})".format(
            self.foreground, self.background,
            self.hidden, self.bold, self.italic, self.underline
            )

    def __str__(self):
        return format(self)

    def __format__(self, format_spec):
        s = []
        if self.hidden:
            s.append("%H")
        if self.bold:
            s.append("%B")
        if self.italic:
            s.append("%I")
        if self.underline:
            s.append("%U")
        foreground = self.foreground
        background = self.background
        if foreground < -1:
            foreground = 99
        if background < -1:
            background = 99
        if foreground != Formatting.COLORS.NO_CHANGE:
            s.append("%C{:02d}".format(foreground))
            if background != Formatting.COLORS.NO_CHANGE:
                s.append(",{:02d}".format(background))
        if self.foreground == Formatting.COLORS.DEFAULT_BG or self.background == Formatting.COLORS.DEFAULT_FG:
            # TODO handle foreground == background
            s.append("%R")
        return hexchat_parse("".join(s))

    def __eq__(self, other):
        return (
            self.hidden == other.hidden and
            self.bold == other.bold and
            self.italic == other.italic and
            self.underline == other.underline and
            self.foreground == other.foreground and
            self.background == other.background
            )

    def __ne__(self, other):
        return not self == other

    # This gives you the result of combining self with other, that is:
    # Formatting(10, 10, HIDDEN, BOLD, ITALIC, UNDERLINE) +
    # Formatting(NO_CHANGE, NO_CHANGE, HIDDEN, BOLD, ITALIC, UNDERLINE) =
    # Formatting(10, 10, VISIBLE, NORMAL, NORMAL, NORMAL)
    def __add__(self, other):
        if not isinstance(self, Formatting) or not isinstance(other, Formatting):
            raise NotImplemented
        return Formatting(
            self.foreground if other.foreground == Formatting.COLORS.NO_CHANGE else other.foreground,
            self.background if other.background == Formatting.COLORS.NO_CHANGE else other.background,
            self.hidden ^ other.hidden,
            self.bold ^ other.bold,
            self.italic ^ other.italic,
            self.underline ^ other.underline
            )

    # This calculates a formatting that when combined with self returns other, that is:
    # Formatting(10, 10, HIDDEN, BOLD, ITALIC, UNDERLINE) -
    # Formatting(1, 1, HIDDEN, BOLD, ITALIC, UNDERLINE) =
    # Formatting(1, 1, VISIBLE, NORMAL, NORMAL, NORMAL)
    # Note: Color NO_CHANGE is special: anything - NO_CHANGE = anything
    def __sub__(self, other):
        if not isinstance(self, Formatting) or not isinstance(other, Formatting):
            raise NotImplemented
        return Formatting(
            self.foreground if other.foreground == Formatting.COLORS.NO_CHANGE else other.foreground,
            self.background if other.background == Formatting.COLORS.NO_CHANGE else other.background,
            self.hidden ^ other.hidden,
            self.bold ^ other.bold,
            self.italic ^ other.italic,
            self.underline ^ other.underline
            )

    def __hash__(self):
        h = (self.foreground if self.foreground >= 0 else 99) | (self.background if self.background >= 0 else 99) << 7
        if self.hidden:
            h |= 1 << 14
        if self.bold:
            h |= 1 << 15
        if self.underline:
            h |= 1 << 16
        if self.italic:
            h |= 1 << 17
        return h

    def __bool__(self):
        return self != Formatting.NO_CHANGE

# define RESET
Formatting.RESET = Formatting(
        Formatting.COLORS.DEFAULT_FG, Formatting.COLORS.DEFAULT_BG,
        Formatting.VISIBLE, Formatting.NORMAL, Formatting.NORMAL, Formatting.NORMAL
        )

Formatting.NO_CHANGE = Formatting(
        Formatting.COLORS.NO_CHANGE, Formatting.COLORS.NO_CHANGE,
        Formatting.VISIBLE, Formatting.NORMAL, Formatting.NORMAL, Formatting.NORMAL
        )

parse_mask = compile_colors(r"(%R|%I|%B|%O|%U|%C(\d{1,2},\d{1,2}|\d{0,2})?|%H)")
formattings = {
    #hexchat_parse("%R"): special
    hexchat_parse("%I"): Formatting(
                    Formatting.COLORS.NO_CHANGE, Formatting.COLORS.NO_CHANGE,
                    Formatting.VISIBLE, Formatting.NORMAL, Formatting.ITALIC, Formatting.NORMAL
                    ),
    hexchat_parse("%B"): Formatting(
                    Formatting.COLORS.NO_CHANGE, Formatting.COLORS.NO_CHANGE,
                    Formatting.VISIBLE, Formatting.BOLD, Formatting.NORMAL, Formatting.NORMAL
                    ),
    hexchat_parse("%O"): Formatting.RESET,
    hexchat_parse("%U"): Formatting(
                    Formatting.COLORS.NO_CHANGE, Formatting.COLORS.NO_CHANGE,
                    Formatting.VISIBLE, Formatting.NORMAL, Formatting.NORMAL, Formatting.UNDERLINE
                    ),
    #hexchat_parse("%C"): special
    hexchat_parse("%H"): Formatting(
                    Formatting.COLORS.NO_CHANGE, Formatting.COLORS.NO_CHANGE,
                    Formatting.HIDDEN, Formatting.NORMAL, Formatting.NORMAL, Formatting.NORMAL
                    )
    }


def parse(ircstring):
    """Parse attributes/formatting on an IRC string.

    The passed string MUST use mIRC attribute codes, NOT HexChat's %x attrubute codes.
    If you have a string with HexChat's attribute codes, pass it through hexchat_parse(s) first."""
    l = []
    last = 0
    for matchobj in parse_mask.finditer(ircstring):
        if matchobj.string[last:matchobj.start()]:
            l.append(matchobj.string[last:matchobj.start()])
        x = matchobj.group()[0]
        base = l.pop() if l and isinstance(l[-1], Formatting) else Formatting.NO_CHANGE
        if x == hexchat_parse("%C"):  # maybe I should cache this somewhere
            colors = [int(x) for x in matchobj.group(2).split(",") if x]
            if len(colors) == 0:
                l.append(base + Formatting(
                    Formatting.COLORS.DEFAULT, Formatting.COLORS.DEFAULT,
                    Formatting.VISIBLE, Formatting.NORMAL, Formatting.NORMAL, Formatting.NORMAL
                    )
                    )
            elif len(colors) == 1:
                l.append(base + Formatting(
                    colors[0], Formatting.COLORS.DEFAULT,
                    Formatting.VISIBLE, Formatting.NORMAL, Formatting.NORMAL, Formatting.NORMAL
                    )
                    )
            elif len(colors) == 2:
                l.append(base + Formatting(
                    colors[0], colors[1],
                    Formatting.VISIBLE, Formatting.NORMAL, Formatting.NORMAL, Formatting.NORMAL
                    )
                    )
        elif x == hexchat_parse("%R"):
            if base:
                l.append(base)
            for item in reversed(l):
                if isinstance(item, Formatting):
                    if item.background != -1 or item.foreground != -1:
                        l.append(item.reverse())
                        break
            else:
                l.append(Formatting.RESET.reverse())
        else:
            l.append(base + formattings[x])
        last = matchobj.end()
    if ircstring[last:]:
        l.append(ircstring[last:])
    return l


# For debugging uncomment lines below
#def test_parse(word, word_eol, userdata):
#    l = parse(hexchat_parse(word_eol[0]))
#    hexchat.prnt(repr(l))
#    hexchat.prnt(repr([str(x) for x in l]))
#    return hexchat.EAT_ALL
#
#hexchat.hook_command("testparse", test_parse)

qc_msg_mask = compile_colors(r"^<(%C01\[[^\]]+\%C01\])(.+?)%O> (.*)")
qc_action_mask = compile_colors(r"^%C06\* (%C01\[[^\]]+%C01\])([^ ]+)%C06 (.*)")

qc_connect_mask = compile_colors(r"^\[([^ ]+) joined the game\]$")
qc_disconnect_mask = compile_colors(r"^\[([^ ]+) left the game\]$")

qc_player_host = hexchat_parse(r"player@mc.queercraft.net")


def is_qc(ctx):
    return ctx.get_info("channel").lower() == "#queercraft"


def is_qcbot(ctx, word):
    return (len(word) > 2 and
    hexchat.strip(word[0]) == "QCChat" and
    word[2] == "+" and
    is_qc(ctx))


def qcbot_msg(word, word_eol, userdata, attributes):
    ctx = hexchat.get_context()
    if is_qcbot(ctx, word):
        match = userdata[1].match(word[1])
        if match:
            badge, nick, text = match.groups()

            if _badge:
                # to see this, see http://tinyurl.com/hexchatbadge
                if "Mod" in badge:
                    badge = "%B%C07&%O"
                elif "Op" in badge:  # or "SrOp" in badge:  # redundant :P
                    badge = "%B%C04@%O"
                elif "Owner" in badge or "Admin" in badge:
                    badge = "%B%C02~%O"
                elif "Newbie" in badge:
                    badge = "%B%C06?%O"
                else:  # for members
                    badge = ""
                badge = hexchat_parse(badge)

            # strip colors
            if not _cols:
                badge = hexchat.strip(badge)
                nick = hexchat.strip(nick)
            else:
                #evt = hexchat_parse(hexchat.get_info("event_text {}".format(userdata[0])))
                pass

            if attributes.time:
                ctx.emit_print(userdata[0], compress_colors(nick), text, badge, time=attributes.time)
            else:
                ctx.emit_print(userdata[0], compress_colors(nick), text, badge)
            return hexchat.EAT_ALL
    return hexchat.EAT_NONE


def qcbot_connect(word, word_eol, userdata, attributes):
    ctx = hexchat.get_context()
    if is_qcbot(ctx, word):
        match = qc_connect_mask.match(word[1])
        if match:
            nick = match.group(1)
            if not _cols:
                nick = hexchat.strip(nick)
            if attributes.time:
                ctx.emit_print("Join", compress_colors(nick), ctx.get_info("channel"), qc_player_host,
                    time=attributes.time)
            else:
                ctx.emit_print("Join", compress_colors(nick), ctx.get_info("channel"), qc_player_host)
            return hexchat.EAT_ALL
    return hexchat.EAT_NONE


def qcbot_disconnect(word, word_eol, userdata, attributes):
    ctx = hexchat.get_context()
    if is_qcbot(ctx, word):
        match = qc_disconnect_mask.match(word[1])
        if match:
            nick = match.group(1)
            if not _cols:
                nick = hexchat.strip(nick)
            if attributes.time:
                ctx.emit_print("Part", compress_colors(nick), qc_player_host, ctx.get_info("channel"),
                    time=attributes.time)
            else:
                ctx.emit_print("Part", compress_colors(nick), qc_player_host, ctx.get_info("channel"))
            return hexchat.EAT_ALL
    return hexchat.EAT_NONE

# Message/action hooks
hexchat.hook_print_attrs("Channel Message", qcbot_msg, userdata=["Channel Message", qc_msg_mask])
hexchat.hook_print_attrs("Channel Msg Hilight", qcbot_msg, userdata=["Channel Msg Hilight", qc_msg_mask])
hexchat.hook_print_attrs("Channel Message", qcbot_msg, userdata=["Channel Action", qc_action_mask])
hexchat.hook_print_attrs("Channel Msg Hilight", qcbot_msg, userdata=["Channel Action Hilight", qc_action_mask])

# Connect/disconnect hooks
hexchat.hook_print_attrs("Channel Message", qcbot_connect)
hexchat.hook_print_attrs("Channel Msg Hilight", qcbot_connect)
hexchat.hook_print_attrs("Channel Message", qcbot_disconnect)
hexchat.hook_print_attrs("Channel Msg Hilight", qcbot_disconnect)


def unload(userdata):
    print("qc.py unloaded")

hexchat.hook_unload(unload)

print("qc.py loaded")
