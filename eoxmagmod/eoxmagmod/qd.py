#-------------------------------------------------------------------------------
#
#  Quasi-Dipole Apex Coordinates / Geomagnetism Library
#
# Project: Earth magnetic field in Python.
# Author: Martin Paces <martin.paces@eox.at>
#
#-------------------------------------------------------------------------------
# Copyright (C) 2015 EOX IT Services GmbH
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies of this Software or works derived from this Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#-------------------------------------------------------------------------------

from os.path import join, dirname, isfile
from warnings import warn
import _pyqd

# location of the data files
_DIRNAME = join(dirname(__file__), 'data')
DATA_APEX_2015 = join(_DIRNAME, 'apexsh_1995-2015.txt')
DATA_APEX_2020 = join(_DIRNAME, 'apexsh_1980-2020.txt')
DATA_APEX = DATA_APEX_2020

def eval_apex(gclat, gclon, gcrad, time, fname=DATA_APEX):
    """
        The use of this function is not recommended as the MLT values
        is not correct! Use eval_qdlatlon() and eval_mlt() instead!

          Evaluate magnetic quasi-dipole coordinates and the magnetic
          local time for a single or multiple input coordinates.

          Inputs:
            gclat - geocentric latitude(s).
            gclon - geocentric longitude(s).
            gcrad - geocentric radial coordinate(s) in km.
            time  - decimal year time(s)
            fname - file-name of the model text file.

          Outputs:
            qdlat - quasi-dipole latitude(s).
            qdlon - quasi-dipole longitude(s).
            mlt - magnetic local time(s).
    """
    warn(
        "You are calling eval_apex() which returns incorrect MLT values! "
        "Use eval_qdlatlon() and eval_mlt() instead!", Warning
    )
    if not isfile(fname):
        raise IOError("File not found! fname=%r" % fname)
    return _pyqd.eval_apex(gclat, gclon, gcrad, time, fname)[:3]


def eval_qdlatlon(gclat, gclon, gcrad, time, fname=DATA_APEX):
    """
          Evaluate magnetic quasi-dipole coordinates a single or multiple input
          coordinates.

          Inputs:
            gclat - geocentric latitude(s).
            gclon - geocentric longitude(s).
            gcrad - geocentric radial coordinate(s) in km.
            time  - decimal year time(s)
            fname - file-name of the model text file.

          Outputs:
            qdlat - quasi-dipole latitude(s).
            qdlon - quasi-dipole longitude(s).
    """
    if not isfile(fname):
        raise IOError("File not found! fname=%r" % fname)
    return _pyqd.eval_qdlatlon(gclat, gclon, gcrad, time, fname)


def eval_mlt(qdlon, time, fname=DATA_APEX):
    """
          Evaluate magnetic local time for given quasi dipole longitudes.

          Inputs:
            qdlon - quasi-dipole longitudes(s).
            time  - MJD2000 time(s)
            fname - file-name of the model text file.

          Outputs:
            mlt - magnetic local time(s).
    """
    if not isfile(fname):
        raise IOError("File not found! fname=%r" % fname)
    return _pyqd.eval_mlt(qdlon, time, fname)


def eval_subsol(time):
    """
          Evaluate sub-solar point coordinates.

          Inputs:
            time  - MJD2000 time(s)

          Outputs:
            gdlat - sub-solar point latitude(s).
            gdlon - sub-solar point longitude(s).
    """
    return _pyqd.eval_subsol(time)
