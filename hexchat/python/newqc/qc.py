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
"""Queercraft Self-Contained Self-Extracing Self-Building HexChat Plugin."""
__module_name__ = "Queercraft"
__module_version__ = "3.4-0.0.0"  # PythonMajor.PythonMinor-Major.minor.patch
__module_description__ = "Queercraft Self-Contained Self-Extracing Self-Building HexChat Plugin."
__module_author__ = "SoniEx2"
# THE EMPTY LINE BELOW IS REQUIRED FOR THIS PROGRAM TO WORK! DO NOT REMOVE!

import importlib


class QcImporter(importlib.abc.SourceLoader, importlib.abc.MetaPathFinder):

    def __init__(self):
        super(QcImporter, self).__init__()

    def find_spec(fullname, path, target=None):
        if fullname.split(".")[0] == "qc":
            pass