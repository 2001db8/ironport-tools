#!/usr/local/bin/python
# Copyright (c) 2007 IronPort Systems, Inc.
# All rights reserved.
# Unauthorized redistribution prohibited.
# $Revision: #5 $

import getopt
import os
import re
import sys

FILTER_MID = 1
FILTER_TO = 2
FILTER_FROM = 3
FILTER_SUBJECT = 4

BOUNCE = re.compile("^MID (\d+) was generated for bounce of MID (\d+)")
DCID_CLOSE = re.compile('^DCID (\d+) close')
DCID_OPEN = re.compile('^New SMTP DCID (\d+) interface')
DELIV_START = re.compile('^Delivery start DCID (\d+) MID (\d+)')
DONE = re.compile('^Message finished MID (\d+) done')
GENERATED = re.compile("^MID (\d+) was generated based on MID (\d+) by")
ICID_ACCEPT_RELAY = re.compile('^ICID (\d+) ACCEPT|ICID (\d+) RELAY')
ICID_CLOSE = re.compile('^ICID (\d+) close')
ICID_OPEN = re.compile('^New SMTP ICID (\d+)')
# MID should NOT have a starting anchor so it can match any other line
MID = re.compile('MID (\d+) ')
REWRITE = re.compile('^MID (\d+) rewritten to MID (\d+) ')
SPLIT = re.compile('^MID (\d+) was split creating MID (\d+) ')
START_MID = re.compile('^Start MID (\d+) ICID (\d+)')
STATUS = re.compile('^Status: ')
TLS_SUCCESS = re.compile('^DCID (\d+) TLS success')
TSTAMP = re.compile('(\w\w\w \w\w\w[ ]+\d+ \d\d:\d\d:\d\d \d\d\d\d) \w*: (.*)')

# time.time() - time.mktime(time.strptime("Fri May  4 23:12:02 2007"))

class mid_tracker:
    def __init__(self):
        self.dcids = {}
        self.icids = {}
        self.mids = {}
        self.open_mids = {}
        self.watch_dcids = {}
        self.watch_icids = {}

    def _fixup_mids(self, old_mid, new_mid, line):
        if new_mid in self.mids:
            # Check if we have a pending Start MID to output
            if self.open_mids.has_key(new_mid):
                print self.open_mids[new_mid]
                del self.open_mids[new_mid]
            # Output the actual line
            print line
        elif old_mid in self.mids:
            # Check if we have a pending Start MID to output
            if self.open_mids.has_key(new_mid):
                print self.open_mids[new_mid]
                del self.open_mids[new_mid]
            # We want to track the new MID
            self.mids[new_mid] = 1
            # Output the actual line
            print line

    def dump_logs(self, logs, mids):
        f = None

        # Scan a single MID
        self.mids = mids
        for l in logs:
            try:
                try:
                    f = open(l)
                    self.dump_log(f)
                except IOError:
                    pass
            finally:
                if f:
                    f.close()

    def dump_log(self, f):
        for line in f:

            # If we have no more MID's to track, early exit
            if not (self.mids or self.watch_dcids or self.watch_icids):
                return

            # Remove the trailing newline, break out the timestamp, remove
            # the log level and break out the real log entry so we don't
            # have to scan over it with the regex's.
            # Thus:
            #     line == full line (w/o trailing newline)
            #     log_time == time stamp portion of the line
            #     log_line == actual log entry portion of the line

            line = line.strip()
            time_match = TSTAMP.search(line)

            # Ignore malformed lines
            if not time_match:
                continue

            log_time = time_match.group(1)
            log_line = time_match.group(2)

            # Ignore the status lines which cause a false positive on "MID"
            if STATUS.search(log_line):
                continue

            # If we're tracking the new split, at least output the line.
            # If we find a split and we're tracking the old mid,
            # add the new one
            m = SPLIT.search(log_line)
            if m:
                old_mid = m.group(1)
                new_mid = m.group(2)
                if new_mid in self.mids:
                    print line
                elif old_mid in self.mids:
                    self.mids[new_mid] = 1
                    print line
                continue

            # Check for a bounce and treat like a split
            m = BOUNCE.search(log_line)
            if m:
                new_mid = m.group(1)
                old_mid = m.group(2)
                self._fixup_mids(old_mid, new_mid, line)
                continue

            # This should catch most filter and system generated splits
            m = GENERATED.search(log_line)
            if m:
                new_mid = m.group(1)
                old_mid = m.group(2)
                self._fixup_mids(old_mid, new_mid, line)
                continue

            # Catch message filter rewrite entries
            m = REWRITE.search(log_line)
            if m:
                old_mid = m.group(1)
                new_mid = m.group(2)
                self._fixup_mids(old_mid, new_mid, line)
                continue

            # Message done means we can stop tracking that mid, delete it
            m = DONE.search(log_line)
            if m:
                found_mid = m.group(1)
                if found_mid in self.mids:
                    del self.mids[found_mid]
                    print line
                # Do bookkeepping for potential bounce messages
                if self.open_mids.has_key(found_mid):
                    del self.open_mids[found_mid]
                continue

            # Save off the new ICID in case we need it
            m = ICID_OPEN.search(log_line)
            if m:
                self.icids[m.group(1)] = [line,]

            # ICID close means we can ignore that ICID
            m = ICID_CLOSE.search(log_line)
            if m:
                found_icid = m.group(1)
                if self.icids.has_key(found_icid):
                    del self.icids[found_icid]
                if self.watch_icids.has_key(found_icid):
                    del self.watch_icids[found_icid]
                    print line
                continue

            # For good measure, we'll add in any ACCEPT/RELAY log lines
            # since customers like that level of information.
            m = ICID_ACCEPT_RELAY.search(log_line)
            if m:
                found_icid = m.group(1)
                if self.icids.has_key(found_icid):
                    self.icids[found_icid].append(line)
                else:
                    self.icids[found_icid] = [line,]
                continue

            # New MID, check for a delayed ICID
            m = START_MID.search(log_line)
            if m:
                found_mid = m.group(1)
                found_icid = m.group(2)
                if found_mid in self.mids:
                    if found_icid in self.icids:
                        for l in self.icids[found_icid]:
                            print l
                        del self.icids[found_icid]
                    # Watch for ICID close
                    self.watch_icids[found_icid] = 1
                    print line
                elif found_icid == "0":
                    # Special case...keep track of "Start MID" in case
                    # this is a start of a bounce (hence the 0 ICID)
                    self.open_mids[found_mid] = line
                continue

            # Save off the new DCID line in case we need it
            m = TLS_SUCCESS.search(log_line)
            if m:
                found_dcid = m.group(1)
                if self.dcids.has_key(found_dcid):
                    self.dcids[found_dcid].append(line)
                else:
                    self.dcids[found_dcid] = [line,]
                continue

            # Save off the new DCID line in case we need it
            m = DCID_OPEN.search(log_line)
            if m:
                found_dcid = m.group(1)
                if self.dcids.has_key(found_dcid):
                    self.dcids[found_dcid].append(line)
                else:
                    self.dcids[found_dcid] = [line,]
                continue

            # DCID close means we can ignore that DCID
            m = DCID_CLOSE.search(log_line)
            if m:
                found_dcid = m.group(1)
                if self.dcids.has_key(found_dcid):
                    del self.dcids[found_dcid]
                if self.watch_dcids.has_key(found_dcid):
                    del self.watch_dcids[found_dcid]
                    print line
                continue

            # Does the delivery start match one of our mids?
            # Check to output a delayed DCID start
            m = DELIV_START.search(log_line)
            if m:
                found_dcid = m.group(1)
                found_mid = m.group(2)
                if found_mid in self.mids:
                    if found_dcid in self.dcids:
                        for l in self.dcids[found_dcid]:
                            print l
                        del self.dcids[found_dcid]
                    # Watch for DCID close
                    self.watch_dcids[found_dcid] = 1
                    print line
                continue

            # Catch all, is this mid being tracked?
            m = MID.search(log_line)
            if m and m.group(1) in self.mids:
                print line

    def scan_logs(self, filter_type, regex, case_ignore, logs):
        mids = {}
        f = None
        for l in logs:
            try:
                try:
                    f = open(l)
                    self.scan_log(filter_type, regex, case_ignore, f, mids)
                except IOError:
                    pass
            finally:
                if f:
                    f.close()
        return mids

    def scan_log(self, filter_type, regex, case_ignore, f, mids):
        if filter_type == FILTER_SUBJECT:
            re_type = re.compile('MID (\d+) Subject \'(.*)\'$')
        elif filter_type == FILTER_TO:
            re_type = re.compile('MID (\d+) ICID (\d+) RID \d+ To: (.*)')
        elif filter_type == FILTER_FROM:
            re_type = re.compile('MID (\d+) ICID (\d+) From: (.*)')

        flags = 0
        if case_ignore:
            flags = re.IGNORECASE

        re_match = re.compile(regex, flags)

        for line in f:
            line = line.strip()
            time_match = TSTAMP.search(line)

            # Ignore malformed lines
            if not time_match:
                continue

            log_time = time_match.group(1)
            log_line = time_match.group(2)

            m = re_type.search(log_line)
            if m:
                if filter_type == FILTER_SUBJECT:
                    if re_match.search(m.group(2)):
                        mids[m.group(1)] = [log_time, m.group(2)]
                else:
                    if re_match.search(m.group(3)):
                        # An ICID of 0 means a split, ignore it since we
                        # only want the original MID's during a scan.
                        if int(m.group(2)):
                            mids[m.group(1)] = [log_time, m.group(3)]
        return mids

if __name__ == '__main__':
    def usage():
        print """\
%s [-i] -F file [-f FROM | -m MID | -s SUBJECT -t TO]

Note:
    - Only the last -f, -m, -s, or -t will be used.
    - Multiple -F arguments can be specified but should be date
      ordered to give consistent results.
""" % (sys.argv[0],)

    try:
        opts, args = getopt.getopt(sys.argv[1:], "F:f:im:s:t:")
    except getopt.GetoptError:
        usage()
        sys.exit(2)

    files = []
    mid = 0
    re_match = ""
    re_type = None
    case_ignore = False
    for o, a in opts:
        if o == "-F":
            files.append(a)
        if o == "-f":
            re_match = a
            re_type = FILTER_FROM
        if o == "-i":
            case_ignore = True
        if o == "-m":
            mid = a
            re_type = FILTER_MID
        if o == "-s":
            re_match = a
            re_type = FILTER_SUBJECT
        if o == "-t":
            re_match = a
            re_type = FILTER_TO

    if not re_type:
        usage()
        sys.exit(2)
    if not files:
        usage()
        sys.exit(2)

    if re_type == FILTER_MID:
        mids = { mid : 1 }
        track = mid_tracker()
        track.dump_logs(files, mids)
    else:
        track = mid_tracker()
        mids = track.scan_logs(re_type, re_match, case_ignore, files)

        # Print out matches
        mid_list = mids.items()
        mid_list.sort(lambda a,b: cmp(int(a[0]), int(b[0])))
        for m, v in mid_list:
            print "MID %s (%s) %s" % (m, v[0], v[1])
