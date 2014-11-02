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
__module_version__ = "2.0.0"
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
        if value and self.statusmsg.get("true",None):
            hexchat.prnt(self.statusmsg["true"])
        elif (not value) and self.statusmsg.get("false",None):
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
    "http://hexchat.readthedocs.org/en/latest/faq.html#how-do-i-show-and-in-front-of-nicknames-that-are-op-and-voice-when-they-talk"
    " before using this.")

def _fmt(s, *args):
    # TODO bold/underline/etc ?
    return s.format(C="\x03",R="\x0f",*args)

def _compile(s, *args):
    return re.compile(_fmt(s, *args))

qc_msg_mask = _compile(r"^<({C}01\[[^\]]+\{C}01\])(.+?){R}> (.*)")
qc_action_mask = _compile(r"^{C}06\* ({C}01\[[^\]]+{C}01\])([^ ]+){C}06 (.*)")

qc_connect_mask = _compile(r"^\[([^ ]+) connected\]$")
qc_disconnect_mask = _compile(r"^\[([^ ]+) disconnected\]$")

qc_player_host = _fmt(r"player@mc.queercraft.net")

def is_qc(ctx):
    return ctx.get_info("channel").lower() == "#queercraft"

def is_qcbot(ctx, word):
    return (len(word) > 2 and
    hexchat.strip(word[0]) == "QueercraftBOT" and
    word[2] == "+" and
    is_qc(ctx))

def qcbot_msg(word, word_eol, userdata, attributes):
    ctx = hexchat.get_context();
    if is_qcbot(ctx, word):
        match = userdata[1].match(word[1])
        if match:
            badge, nick, text = match.groups()

            # strip colors
            if not _cols:
                badge = hexchat.strip(badge)
                nick = hexchat.strip(nick)

            if _badge:
                # to see this, see http://hexchat.readthedocs.org/en/latest/faq.html#how-do-i-show-and-in-front-of-nicknames-that-are-op-and-voice-when-they-talk
                if "Mod" in badge:
                    badge = "\x02\x0307&\x0f"
                elif "Op" in badge:  # or "SrOp" in badge:  # redundant :P
                    badge = "\x02\x0304@\x0f"
                elif "Owner" in badge or "Admin" in badge:
                    badge = "\x02\x0302~\x0f"
                elif "Newbie" in badge:
                    badge = "\x02\x0306?\x0f"
                else:  # for members
                    badge = ""

            if attributes.time:
                ctx.emit_print(userdata[0], nick, text, badge, time=attributes.time)
            else:
                ctx.emit_print(userdata[0], nick, text, badge)
            return hexchat.EAT_ALL
    return hexchat.EAT_NONE

def qcbot_connect(word, word_eol, userdata, attributes):
    ctx = hexchat.get_context();
    if is_qcbot(ctx, word):
        match = qc_connect_mask.match(word[1])
        if match:
            nick = match.group(1)
            if not _cols:
                nick = hexchat.strip(nick)
            if attributes.time:
                ctx.emit_print("Join", nick, ctx.get_info("channel"), qc_player_host, time=attributes.time)
            else:
                ctx.emit_print("Join", nick, ctx.get_info("channel"), qc_player_host)
            return hexchat.EAT_ALL
    return hexchat.EAT_NONE

def qcbot_disconnect(word, word_eol, userdata, attributes):
    ctx = hexchat.get_context();
    if is_qcbot(ctx, word):
        match = qc_disconnect_mask.match(word[1])
        if match:
            nick = match.group(1)
            if not _cols:
                nick = hexchat.strip(nick)
            if attributes.time:
                ctx.emit_print("Part", nick, qc_player_host, ctx.get_info("channel"), time=attributes.time)
            else:
                ctx.emit_print("Part", nick, qc_player_host, ctx.get_info("channel"))
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
