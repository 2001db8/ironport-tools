# This builds the C binaries to process the IronPort binary logs.
# The optimized C binaries are fast for crunching the binary logs.
# There are three #def'd drivers in the 'dlog_parser' source to produce:
#    - a CSV (comma separated value) datafile
#    - an XML datafile
#    - an ASCII dump (debugging) of the data files
# Change $(VER), above, to get the debug or memory-checked version of the
# binaries.
#
# Copyright (C) 2002, IronPort Systems.  All rights reserved.
# $Revision: 1.15 $

VER=opt
OS_VER=`uname -s`
#CFLAGS= -g -D$(OS_VER)
CFLAGS=-O3 -Wall -Wno-unused -D $(OS_VER)

CC=g++

all: clean
	@ echo '1' | od -x | grep -i 310a > /dev/null && ENDIEN=0 make build_all || ENDIEN=1 make build_all

build_all:
	@ PROGRAM=XML_DUMP_UTILITY OUT=dlog_xml IN=dlog_xml.c make $(VER);
	@ PROGRAM=ASCII_DUMP_UTILITY OUT=dlog_ascii IN=dlog_ascii.c make $(VER);
	@ PROGRAM=CSV_DUMP_UTILITY OUT=dlog_csv IN=dlog_csv.c make $(VER);
	@ make pickle_check

pickle_check: 
	$(CC) $(CFLAGS) -DSELF_TEST un_pickle.c -g -o pickle_check

# http://www.sound.net/~hald/projects/memcheck/
#   memcheck is a memory checking library, found in the BSD ports section.
#  'export MEMCHECK_REUSE=1'  if the datafile is large!

memcheck:
	$(CC) $(CFLAGS) -D$(PROGRAM) -DLITTLE_ENDIEN=$(ENDIEN) -I/usr/local/include -L/usr/local/lib -DDO_MEMCHECK dlog_parser.c un_pickle.c  -lmemcheck -g -o $(OUT)

debug:
	$(CC) $(CFLAGS)  -DLITTLE_ENDIEN=$(ENDIEN) dlog_parser.c un_pickle.c -g -o $(OUT)

opt:
	$(CC) $(CFLAGS)  -D LITTLE_ENDIEN=$(ENDIEN) $(IN) dlog_common.c un_pickle.c -o $(OUT)

clean:
	rm -f dlog_xml dlog_ascii dlog_csv pickle_check *.o
