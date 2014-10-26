__module_name__ = "Queercraft"
__module_version__ = "1.0"
__module_description__ = "QueercraftBOT thingy"
__module_author__ = "SoniEx2"

import hexchat
import re

qc_msg_mask = re.compile(r"^<(01\[[^\]]+01\])(.+?)> (.*)")
qc_action_mask = re.compile(r"^06\* (01\[[^\]]+01\])([^ ]+)06 (.*)")

qc_connect_mask = re.compile(r"^\[([^ ]+) connected\]$")
qc_disconnect_mask = re.compile(r"^\[([^ ]+) disconnected\]$")

qc_player_host = r"player@mc.queercraft.net"

def is_qc(ctx, word):
    return (len(word) > 2 and
    hexchat.strip(word[0]) == "QueercraftBOT" and
    word[2] == "+" and
    ctx.get_info("channel").lower() == "#queercraft" and
    ctx.get_info("network").lower() == "espernet")

def qcbot_msg(word, word_eol, userdata, attributes):
    ctx = hexchat.get_context();
    if is_qc(ctx, word):
        match = userdata[1].match(word[1])
        if match:
            badge, nick, text = match.groups()
            if attributes.time:
                ctx.emit_print(userdata[0], nick, text, badge, time=attributes.time)
            else:
                ctx.emit_print(userdata[0], nick, text, badge)
            return hexchat.EAT_ALL
    return hexchat.EAT_NONE

def qcbot_connect(word, word_eol, userdata, attributes):
    ctx = hexchat.get_context();
    if is_qc(ctx, word):
        match = qc_connect_mask.match(word[1])
        if match:
            nick = match.group(1)
            if attributes.time:
                ctx.emit_print("Join", nick, ctx.get_info("channel"), qc_player_host, time=attributes.time)
            else:
                ctx.emit_print("Join", nick, ctx.get_info("channel"), qc_player_host)
            return hexchat.EAT_ALL
    return hexchat.EAT_NONE

def qcbot_disconnect(word, word_eol, userdata, attributes):
    ctx = hexchat.get_context();
    if is_qc(ctx, word):
        match = qc_disconnect_mask.match(word[1])
        if match:
            nick = match.group(1)
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
