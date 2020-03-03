# Copyright (C) 2001  MandrakeSoft S.A.
#
#   MandrakeSoft S.A.
#   43, rue d'Aboukir
#   75002 Paris - France
#   http://www.linux-mandrake.com/
#   http://www.mandrakesoft.com/
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA


.SUFFIXES: .cc


SHELL = /bin/sh



CC = gcc
CXX = g++
CFLAGS =  -fpascal-strings -fno-common -Wno-four-char-constants -Wno-unknown-pragmas -Dmacintosh -D_FILE_OFFSET_BITS=64 -D_LARGE_FILES  -I/usr/local/include/SDL -D_GNU_SOURCE=1 -D_THREAD_SAFE
CXXFLAGS =  -fpascal-strings -fno-common -Wno-four-char-constants -Wno-unknown-pragmas -Dmacintosh -D_FILE_OFFSET_BITS=64 -D_LARGE_FILES  -I/usr/local/include/SDL -D_GNU_SOURCE=1 -D_THREAD_SAFE

LDFLAGS = -L/usr/local/opt/openssl@1.1/lib
LIBS = 
RANLIB = ranlib


.cc.o:
	$(CXX) -c $(CXXFLAGS) $< -o $@


all: make_cmos_image

make_cmos_image: make_cmos_image.o
	$(LIBTOOL) --mode=link --tag CXX $(CXX) -o $@ $(CXXFLAGS) $(LDFLAGS) make_cmos_image.o

clean:
	rm -f  *.o
	rm -f  make_cmos_image

dist-clean: clean
	rm -f  Makefile
