# -*- Mode: Python -*-
#
# dlog_to_xml.py - convert from IronPort delivery log format to XML
#
# Copyright (c) 2002, IronPort Systems, All rights reserved.
# P/N: 110-0001 $Revision: 1.18 $

import struct
import cPickle
import exceptions
import time

SUPPORTED_VERSIONS = (0, 1, 2, 3, 4)
KIND_MSG_DONE      = 'MD'
KIND_HARD_BOUNCE   = 'HB'
KIND_BEGIN_LOGFILE = '<<'
KIND_END_LOGFILE   = '>>'

class FormatError (exceptions.Exception):
    pass

class VersionError (exceptions.Exception):
    pass

header_format = '>2siii'
header_size = struct.calcsize ('>2siii')

def read_record (file):
    header = file.read (header_size)
    if not header:
        raise EOFError
    kind, data_len, td_s, td_m = struct.unpack (header_format, header)
    data = file.read (data_len)
    return kind, cPickle.loads (data), (td_s, td_m)

def render_time (sec, usec):
    # render a time in something that is very close to a ctime()
    # but with a floating-point second.
    tt = time.localtime (sec)
    return time.strftime ("%a %b %d %H:%M:%S.%%03d %Y", tt) % (usec / 1000)

def unpack_ip (n):
    d = n & 0xff
    n = n >> 8
    c = n & 0xff
    n = n >> 8
    b = n & 0xff
    n = n >> 8
    a = n & 0xff
    return '.'.join (map (str, (a,b,c,d)))

def quote_for_xml (s):
    return s.replace ('&', '&amp;').replace ('<', '&lt;').replace ('>', '&gt;').replace ('"', '&quot;')

def process_file (in_file, out_file, (skip_del, skip_hard, skip_soft)):
    kind, version, when = read_record (in_file)
    if kind != KIND_BEGIN_LOGFILE:
        raise FormatError, "log file does not start with BEGIN_LOGFILE"
    if version not in SUPPORTED_VERSIONS:
        raise VersionError, "unsupported log file version %d" % version
    while 1:
        try:
            kind, data, (tl_sec, tl_usec) = read_record (in_file)
        except EOFError:
            break
        if kind == KIND_END_LOGFILE:
            break
        elif kind == KIND_MSG_DONE:
            if skip_del:
                continue
            customer_data = []
            source_ip = 0
            code = '000'
            reply = ''
            if version==0 or version==1:
                ti_sec, ti_usec, bytes, mid, ip, env_from, domain, rcpt_data = data
            elif version == 2 or version == 3:
                ti_sec, ti_usec, bytes, mid, ip, env_from, domain, rcpt_data, customer_data = data                
            else:
                ti_sec, ti_usec, bytes, mid, ip, env_from, domain, rcpt_data, customer_data, source_ip, code, reply = data                
            out_file.write (
                '<success del_time="%s" inj_time="%s" bytes="%d" mid="%d" ip="%s" from="%s" source_ip="%s" code="%s" reply="%s">\n' % (
                    render_time (tl_sec, tl_usec),
                    render_time (ti_sec, ti_usec),
                    bytes,
                    mid,
                    unpack_ip (ip),
                    quote_for_xml (env_from),
                    unpack_ip (source_ip),
                    quote_for_xml (code),
                    quote_for_xml (reply),
                    )
                )
            if version < 3:
                for rid, user, attempts in rcpt_data:
                    out_file.write ('  <rcpt rid="%d" to="%s@%s" attempts="%d" />\n' % (rid, quote_for_xml (user), domain, attempts+1))
            else:
                # In version 3, the recipient address has already had its
                # domain appended...
                for rid, user, attempts in rcpt_data:
                    out_file.write ('  <rcpt rid="%d" to="%s" attempts="%d" />\n' % (rid, quote_for_xml (user), attempts+1))
            if customer_data:
                write_customer_data (out_file, customer_data)
            out_file.write ('</success>\n')
        elif kind == KIND_HARD_BOUNCE:
            if skip_hard:
                continue
            reason = ''
            customer_data = []
            source_ip = 0
            if version==0:
                ti_sec, ti_usec, bytes, mid, ip, env_from, code, error, rcpt_data = data
            elif version==1:
                ti_sec, ti_usec, bytes, mid, ip, env_from, reason, code, error, rcpt_data = data
            elif version == 2 or version == 3:
                ti_sec, ti_usec, bytes, mid, ip, env_from, reason, code, error, rcpt_data, customer_data = data                
            else:
                ti_sec, ti_usec, bytes, mid, ip, env_from, reason, code, error, rcpt_data, customer_data, source_ip = data                

            if type(error) == type([]) and len(error) == 0:
                error = ""
            elif type(error) == type([]) and len(error) == 1:
                error = error[0]
            else:
                error = repr(error)

            out_file.write (
                '<bounce del_time="%s" inj_time="%s" bytes="%d" mid="%d" ip="%s" from="%s" source_ip="%s" reason="%s" code="%s" error="%s">\n' % (
                    render_time (ti_sec, ti_usec),
                    render_time (tl_sec, tl_usec),
                    bytes,
                    mid,
                    unpack_ip (ip),
                    quote_for_xml (env_from),
                    unpack_ip (source_ip),
                    quote_for_xml (reason),
                    code,
                    quote_for_xml (str(error)),
                    )
                )
            for rid, email, attempts in rcpt_data:
                out_file.write ('  <rcpt rid="%d" to="%s" attempts="%d" />\n' % (rid, quote_for_xml (email), attempts+1))
            if customer_data:
                write_customer_data (out_file, customer_data)
            out_file.write ('</bounce>\n')
        else:
            raise FormatError, "unexpected type code: %r" % kind

def write_customer_data (out_file, customer_data):
    out_file.write ('  <customer_data>\n')
    for header_name, header_value in customer_data:
        out_file.write (
            '    <header name="%s" value="%s"/>\n' % (
                quote_for_xml (header_name),
                quote_for_xml (header_value)
                )
            )
    out_file.write ('  </customer_data>\n')                

def process_files (files, output, skips):
    output.write ('<?xml version="1.0"?>\n')
    output.write ('<delivery-report>\n')
    for filename in files:
        file = open (filename, 'rb')
        process_file (file, output, skips)
    output.write ('</delivery-report>\n')

if __name__ == '__main__':
    import sys
    if len(sys.argv) == 1:
        # soft bounces aren't included [yet]
        print "%s [-d] [-h] log_file_0, log_file_1, ..." % sys.argv[0]
        print "  Emit binary delivery logs as xml"
        print "    -d : don't output delivery events"
        print "    -h : don't output hard-bounce events"
    else:
        skip_del  = '-d' in sys.argv and (sys.argv.remove ('-d') or 1)
        skip_hard = '-h' in sys.argv and (sys.argv.remove ('-h') or 1)
        skip_soft = '-s' in sys.argv and (sys.argv.remove ('-s') or 1)
        files = sys.argv[1:]
        # get them in time order...
        files.sort()
        # think about a pipe to gzip
        #output_file = open ('ironport.log.xml', 'wb')
        output_file = sys.stdout
        process_files (files, output_file, (skip_del, skip_hard, skip_soft))
