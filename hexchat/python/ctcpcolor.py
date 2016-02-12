import hexchat
__module_author__ = "SoniEx2"
__module_name__ = "CTCP Color"
__module_description__ = "Formatting codes in CTCP format"
__module_version__ = "1.0"

import re

ctcp = re.compile("\x01(.*?)\x01")

def replacement(match):
  if len(match.group(1)) > 2 and match.group(1)[0:2] == "F ":
    parse = match.group(1)[2:]
    parsed = []
    parseiter = iter(parse)
    enumerated = enumerate(parseiter)
    for i, c in enumerated:
      if c in '0123456789':
        parsed += ['\x03']
        if (parse[i+1:i+2] or ' ') in '0123456789':
          parsed += [c, next(enumerated)[1]]
        else:
          parsed += ['0', c]
        parsed += ['\x02'*2] # dummy to prevent funky formatting
      elif c == '#':
        try:
          for _ in range(6):
            next(enumerated)
        except:
          pass
      elif c == ',':
        parsed += ['\x03']
        if (parse[i+1:i+2] or ' ') in '0123456789':
          _c = next(enumerated)[1]
          if (parse[i+2:i+3] or ' ') in '0123456789':
            parsed += [',', _c, next(enumerated)[1]]
          else:
            parsed += [',', '0', _c]
        elif (parse[i+1:i+2] or ' ') == '#':
          try:
            for _ in range(6):
              next(enumerated)
          except:
            pass
        parsed += ['\x02'*2] # dummy to prevent funky formatting
      elif c == 'b':
        parsed += ['\x02']
      elif c == 'i':
        parsed += ['\x1D']
      elif c == 'u':
        parsed += ['\x1F']
      elif c == 'r':
        parsed += ['\x0F']
      elif c == 'n':
        parsed += ['\x16']
    return ''.join(parsed)
  else:
    return match.group(0)

skip = False

def privmsg(word, word_eol, userdata):
  global skip
  if skip:
    return hexchat.EAT_NONE
  i=3
  if word[0][0] == "@":
    i+=1
  newtext=re.sub(ctcp, replacement, word_eol[i])
  line=' '.join(["recv"]+word[0:i]+[newtext])
  skip = True
  hexchat.command(line)
  skip = False
  return hexchat.EAT_ALL

def notice(word, word_eol, userdata):
  global skip
  if skip:
    return hexchat.EAT_NONE
  i=3
  if word[0][0] == "@":
    i+=1
  newtext=re.sub(ctcp, replacement, word_eol[i])
  line=' '.join(["recv"]+word[0:i]+[newtext])
  skip = True
  hexchat.command(line)
  skip = False
  return hexchat.EAT_ALL

hexchat.hook_server("PRIVMSG", privmsg, priority=hexchat.PRI_HIGHEST)
hexchat.hook_server("NOTICE", notice, priority=hexchat.PRI_HIGHEST)
