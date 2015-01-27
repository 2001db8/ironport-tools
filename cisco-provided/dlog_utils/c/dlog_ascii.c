/*
 * dlog_parser.c - dump IronPort delivery logs in CSV, XML and ascii
 *
 * Copyright (C) 2002, IronPort Systems.  All rights reserved.
 * $Revision: 1.2 $
 */

#ifdef DO_MEMCHECK
/* 
 * memcheck checks for bounds reads/writes, allocation errors, etc.
 *
 * export MEMCHECK_REUSE = 1
 * if processing large files, o.w. memory will just grow
 */
#include <sys/types.h>
#include <memcheck.h>
#endif

#include <stdarg.h> /* problematic for some OSes? */

#include <sys/types.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <time.h>
#include <string.h>
#include <stdlib.h>

#include "dlog_common.h"
#include "un_pickle.h"


#define MAX_SUPPORTED_VERSION 4

extern FILE * outfile; /* = stdout; */
char* revision = "$Name: DLOG_PARSING_TOOLS_1_4 $";

#if 0
extern start_rec_t start_record;
extern end_rec_t end_record;
extern delv_rec_t delv_record;
extern bounce_rec_t bounce_record;
#endif
extern int file_version;


void
dump_errors_normal(str_info_t *arr, int count)
{
   int idx;

   if (count == 0) { return; }

   fprintf (outfile, "\nError Data: (%d elem)\n", count);

   for (idx = 0; idx < count; idx++) {
	  fprintf (outfile, " .. %*.*s\n", arr[idx].len, arr[idx].len, arr[idx].val);
   }
}

void
dump_errors_bc(str_info_t *arr, int count)
{
   int idx;

   if (count == 0) { return; }

   fprintf (outfile, "\nError Data (%d elem)\n", count);

   for (idx = 0; idx < count; idx++) {
	  fprintf (outfile, " .. %*.*s\n", arr[idx].len, arr[idx].len, arr[idx].val);
   }
}

void(*dump_errors)(str_info_t *, int);

static char *
ascii_print(int len, char *src)
{
   char *_chr, *end, tmp;
   int pos = 0;
   char* buf = next_pbuf();

   end = (len > BSZ) ? src + (BSZ - 1) : src + len;

   for (_chr = src; _chr != end; _chr++)
   {
	  tmp = *_chr;
	  if (tmp < 40 || tmp >= 127 || tmp == '\\')
	  {
		 /* fprintf(outfile, "%d {%*.*s}\n", len, len, len, src); */
		 pos += sprintf(buf + pos, "\\%03o", tmp);
	  }
	  else {
		 buf[pos++] = tmp;
	  }
   }
   buf[pos] = '\0';

   return buf;
	  
}

void 
dump_rcpt(rcpt_info_t *arr, int count)
{
   int idx;

   if (count == 0) { return; }

   fprintf (outfile, "\nRcpt Data: (%d elem)\n", count);

   for (idx = 0; idx < count; idx++) {
	  fprintf (outfile, " .. Rcpt_Id %d\n", arr[idx].rcpt_id);
	  fprintf (outfile, " ..   Attempt_Number %d\n", arr[idx].attempt);
	  fprintf (outfile, " ..   Email %s\n", 
			  ascii_print(arr[idx].address.len, arr[idx].address.val));
   }
}


void 
dump_cust(cust_info_t *arr, int count)
{
   int idx;

   if (count == 0) { return; }

   fprintf (outfile, "\nCust Data: (%d elem)\n", count);

   for (idx = 0; idx < count; idx++) {
	  fprintf (outfile, " .. %*.*s => %*.*s\n", 
			  arr[idx].name.len,
			  arr[idx].name.len,
			  arr[idx].name.val,
			  arr[idx].value.len,
			  arr[idx].value.len,
			  arr[idx].value.val);
   }
}


int
dump_start_record_local(start_rec_t *rec)
{
   printf ("opening up\n");
   assert(rec && rec->magic == MAGIC_START);
   fprintf (outfile, "START %s\n", render_time(rec->log_secs, rec->log_usecs));
   fprintf (outfile, ". Version %d\n", rec->version);
   fprintf (outfile, ". File Version %d\n", rec->file_version);
   fprintf (outfile, "\n");
   return 0;
}

int
dump_delv_record_local(delv_rec_t *rec)
{
   assert(rec && rec->magic == MAGIC_DELV);
   fprintf (outfile, "DELIVERY %s\n", render_time(rec->log_secs, rec->log_usecs));
   fprintf (outfile, ". Time   %s\n", render_time(rec->entry_secs, rec->entry_usecs));
   fprintf (outfile, ". Bytes  %u\n", rec->bytes);
   fprintf (outfile, ". Msg_Id %u\n", rec->mesg_id);
   fprintf (outfile, ". IP     %s\n", render_ip(rec->ip_addr));
   fprintf (outfile, ". From   %*.*s\n", rec->from.len, rec->from.len, rec->from.val);
   fprintf (outfile, ". Domain %*.*s\n", rec->domain.len, rec->domain.len, rec->domain.val);

   /* handle v4 record additions */
   if (file_version >= 4) {
   	fprintf (outfile, ". Src_IP %s\n", render_ip(rec->src_ip));
   	fprintf (outfile, ". Code   %*.*s\n", rec->code.len, rec->code.len, rec->code.val);
   	fprintf (outfile, ". Reply  %*.*s\n", rec->reply.len, rec->reply.len, rec->reply.val);
   } 
   dump_rcpt(rec->rcpt_arr, rec->n_rcpt);
   dump_cust(rec->cust_arr, rec->n_cust);
   fprintf (outfile, "\n");
   return 0;
}

int
dump_bounce_record_local(bounce_rec_t *rec)
{
   assert(rec && rec->magic == MAGIC_BOUNCE);
   fprintf (outfile, "BOUNCE %s\n", render_time(rec->log_secs, rec->log_usecs));
   fprintf (outfile, ". Time   %s\n", render_time(rec->entry_secs, rec->entry_usecs));
   fprintf (outfile, ". Bytes  %u\n", rec->bytes);
   fprintf (outfile, ". Msg_Id %u\n", rec->mesg_id);
   fprintf (outfile, ". IP     %s\n", render_ip(rec->ip_addr));
   fprintf (outfile, ". From   %*.*s\n", rec->from.len, rec->from.len, rec->from.val);
   fprintf (outfile, ". Reason %*.*s\n", rec->reason.len, rec->reason.len, rec->reason.val);
   fprintf (outfile, ". Code   %*.*s\n", rec->code.len, rec->code.len, rec->code.val);

   /* handle v4 added fields */  
   if (file_version >= 4) {
   	fprintf (outfile, ". Src_IP %s\n", render_ip(rec->src_ip));
   }
   dump_rcpt(rec->rcpt_arr, rec->n_rcpt);
   dump_cust(rec->cust_arr, rec->n_cust);
   dump_errors(rec->err_arr, rec->n_err);
   fprintf (outfile, "\n");
   return 0;
}


int
dump_end_record_local(end_rec_t *rec)
{
   assert(rec && rec->magic == MAGIC_END);
   fprintf (outfile, "END %s\n", render_time(rec->log_secs, rec->log_usecs));
   fprintf (outfile, "\n");
   return 0;
}

int (*dump_delv_record)(delv_rec_t *rec);
int (*dump_bounce_record)(bounce_rec_t *rec);
int (*dump_start_record)(start_rec_t *rec);
int (*dump_end_record)(end_rec_t *rec);

void start_report(int opts[]) { 
   dump_errors = opts[BACKWARDS_COMPAT] ? &dump_errors_bc : &dump_errors_normal;
   dump_start_record = dump_start_record_local;
   dump_end_record = dump_end_record_local;
   dump_delv_record = dump_delv_record_local;
   dump_bounce_record = dump_bounce_record_local;
}
 
void end_report() { }


void usage(const char *name)
{
   fprintf (stderr, "Usage: %s [ options ] log0 log1 ...\n", name);
   fprintf (stderr, "     -o               output file\n");
   fprintf (stderr, "     -H               don't display hard bounce messages\n");
   fprintf (stderr, "     -D               don't display delivery messages\n");
   fprintf (stderr, "     -version         version information\n");
   fprintf (stderr, "     -B               backwards compatability\n");
   fprintf (stderr, "     -h               this message\n");
   exit(1);
}

