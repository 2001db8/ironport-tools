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


static char* base64_table = 
"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

static char *
b64_encode(int len, const char *string)
{
   char* buf = next_pbuf();
   short trans_buf[4];
   int opos = 0;

   int num_triples = len / 3;
   int trailing    = len % 3;

   int times= num_triples * 3;
   int idx = 0;

   opos = sprintf (buf, "=?ascii?B?");

   for (idx = 0; idx < times; idx += 3) 
   {
	  trans_buf[0]  = (string[idx+0] & 0xFC) >> 2;
	  trans_buf[1]  = (string[idx+0] & 0x03) << 4;
	  trans_buf[1] |= (string[idx+1] & 0xF0) >> 4;
	  trans_buf[2]  = (string[idx+1] & 0x0F) << 2;
	  trans_buf[2] |= (string[idx+2] & 0xC0) >> 6;
	  trans_buf[3]  = (string[idx+2] & 0x3F);

	  buf[opos++] = base64_table[trans_buf[0]];
	  buf[opos++] = base64_table[trans_buf[1]];
	  buf[opos++] = base64_table[trans_buf[2]];
	  buf[opos++] = base64_table[trans_buf[3]];
   }

   if (trailing == 2) {
	  trans_buf[0]  = (string[times]   & 0xFC) >> 2;
	  trans_buf[1]  = (string[times]   & 0x03) << 4;
	  trans_buf[1] |= (string[times+1] & 0xF0) >> 4;
	  trans_buf[2]  = (string[times+1] & 0x0F) << 2;

	  buf[opos++] = base64_table[trans_buf[0]];
	  buf[opos++] = base64_table[trans_buf[1]];
	  buf[opos++] = base64_table[trans_buf[2]];
	  buf[opos++] = '=';
   }
   else if (trailing == 1) {
	  trans_buf[0]  = (string[times]   & 0xFC) >> 2;
	  trans_buf[1]  = (string[times]   & 0x03) << 4;

	  buf[opos++] = base64_table[trans_buf[0]];
	  buf[opos++] = base64_table[trans_buf[1]];
	  buf[opos++] = '=';
	  buf[opos++] = '=';
   }
	  
   buf[opos++] = '?';
   buf[opos++] = '=';
   buf[opos++] = '\0';

   return buf;
}

static char *
xml_encode(int len,  char *string)
{
   char* buf = next_pbuf();
   int opos = 0;
   int idx;
   char tmp;

   buf[0] = '\0';
   for (idx = 0; idx < len && opos < HSZ - 1; idx++) 
   {
	  tmp = string[idx];

	  if (tmp == '&')       opos += sprintf(buf + opos, "&amp;");
	  else if (tmp == '>')  opos += sprintf(buf + opos, "&lt;");
	  else if (tmp == '<')  opos += sprintf(buf + opos, "&gt;");
	  else if ( tmp == '"')  opos += sprintf(buf + opos, "&quot;");
	  /* else if (tmp == '\'') opos += sprintf(buf + opos, "&apos;"); */
	  else { buf[opos++] = tmp; }

	  if ( tmp <= 0x8 || tmp == 0xB || 
		   tmp == 0xC || (tmp >= 0xE && tmp <= 0x1F) || 
		   tmp >= 0x7F) 
	  {
		 opos = 0;
#define TESTING_XML_DUMP 0
#if TESTING_XML_DUMP == 1
		 return dump_print(len, string);
#else 
		 return b64_encode(len, string);
#endif
	  }
   }

   buf[opos++] = '\0';
   return buf;
}

void
xml_dump_errors(str_info_t *arr, int count)
{
   int idx;

   if (count == 0) { return; }

   if (count > 1) fprintf(outfile, "[");

   for (idx = 0; idx < count - 1; idx++) {
	  fprintf(outfile, "%s, ", xml_encode(arr[idx].len, arr[idx].val));
   }
   if (idx < count) {
	  fprintf(outfile, "%s", xml_encode(arr[idx].len, arr[idx].val));
   }

   if (count > 1) fprintf(outfile, "]");
}

void 
xml_dump_rcpt(rcpt_info_t *arr, int count, int dlen, char *dom)
{
   char* buf;
   int idx, bpos;

   if (count == 0) { return; }

   fprintf(outfile, "\n");

   for (idx = 0; idx < count; idx++) 
   {
          buf = next_pbuf();
          buf[0] = '\0';
	  memcpy(buf, arr[idx].address.val, arr[idx].address.len);
	  bpos = arr[idx].address.len;

	  if (dlen != 0) 
	  { 
		 buf[bpos++] = '@';
		 memcpy(buf+bpos, dom, dlen);
		 bpos += dlen;
	  }

	  fprintf(outfile, "     ");
	  fprintf(outfile, "<rcpt rid=\"%d\" to=\"%s\" attempts=\"%d\" />\n",
			  arr[idx].rcpt_id, 
			  xml_encode(bpos, buf),
			  arr[idx].attempt);
   }
}

void 
xml_dump_cust(cust_info_t *arr, int count)
{
   int idx;
   if (count == 0) { return; }

   fprintf(outfile, "     <customer_data>\n");

   for (idx = 0; idx < count; idx++) {
      fprintf(outfile, "        <header name=\"%s\"",
	      xml_encode(arr[idx].name.len, arr[idx].name.val));
      fprintf(outfile, " value=\"%s\"/>\n",
	      xml_encode(arr[idx].value.len, arr[idx].value.val));
   }

   fprintf(outfile, "     </customer_data>\n");
}

int
dump_start_record_local(start_rec_t *rec)
{
   assert(rec && rec->magic == MAGIC_START);
   fprintf(outfile, "<!-- start record %s ver %d f_ver %d -->\n", 
		   render_time(rec->log_secs, rec->log_usecs),
		   rec->version, rec->file_version);
   return 0;
}

int
dump_delv_record_normal(delv_rec_t *rec)
{
   assert(rec && rec->magic == MAGIC_DELV);

   fprintf(outfile, "  <success mid=\"%d\" bytes=\"%d\" ip=\"%s\"\n",
		   rec->mesg_id, rec->bytes, render_ip(rec->ip_addr));
   fprintf(outfile, "      from=\"%s\"\n", xml_encode(rec->from.len, rec->from.val));
   fprintf(outfile, "      del_time=\"%s\"\n", render_time(rec->log_secs, rec->log_usecs));
   fprintf(outfile, "      inj_time=\"%s\"", render_time(rec->entry_secs, rec->entry_usecs));

   /* handle v4 added fields */
   if (file_version >= 4) {
   	fprintf(outfile, "\n      source_ip=\"%s\"\n", render_ip(rec->src_ip));
   	fprintf(outfile, "      code=\"%s\"\n", xml_encode(rec->code.len, rec->code.val));
  	 fprintf(outfile, "      reply=\"%s\">\n",xml_encode(rec->reply.len, rec->reply.val)); 
   }
   else {
	fprintf(outfile, ">\n");
   }
   if (file_version < 3) {
       /* This is not necessarily correct; prior to version 3, we assumed
          the domain of the destination address was the same for all recipients
          and was equal to the queue they were in.  This is not actually true,
          since those recipients could've been redirected manually or with
          the alt-mailhost() filter action */
       xml_dump_rcpt(rec->rcpt_arr, rec->n_rcpt, rec->domain.len, rec->domain.val);
   } else {
       /* Version 3 started adding the individual domains to the recipients,
          so we don't need to tack on the extra */
       xml_dump_rcpt(rec->rcpt_arr, rec->n_rcpt, 0, NULL);
   }
   xml_dump_cust(rec->cust_arr, rec->n_cust);
   fprintf(outfile, "  </success>\n");
   return 0;
}

/* backward compatability output */
int
dump_delv_record_bc(delv_rec_t *rec)
{
   assert(rec && rec->magic == MAGIC_DELV);

   fprintf(outfile, "  <success mid=\"%d\" bytes=\"%d\" ip=\"%s\"\n",
		   rec->mesg_id, rec->bytes, render_ip(rec->ip_addr));
   fprintf(outfile, "      from=\"%s\"\n", xml_encode(rec->from.len, rec->from.val));
   fprintf(outfile, "      del_time=\"%s\"\n", render_time(rec->entry_secs, rec->entry_usecs));
   fprintf(outfile, "      inj_time=\"%s\"", render_time(rec->log_secs, rec->log_usecs));

   /* handle v4 added fields */
   if (file_version >= 4) {
   	fprintf(outfile, "\n      source_ip=\"%s\"\n", render_ip(rec->src_ip));
   	fprintf(outfile, "      code=\"%s\"\n", xml_encode(rec->code.len, rec->code.val));
  	 fprintf(outfile, "      reply=\"%s\">\n",xml_encode(rec->reply.len, rec->reply.val)); 
   }
   else {
	fprintf(outfile, ">\n");
   }
   if (file_version < 3) {
       /* This is not necessarily correct; prior to version 3, we assumed
          the domain of the destination address was the same for all recipients
          and was equal to the queue they were in.  This is not actually true,
          since those recipients could've been redirected manually or with
          the alt-mailhost() filter action */
       xml_dump_rcpt(rec->rcpt_arr, rec->n_rcpt, rec->domain.len, rec->domain.val);
   } else {
       /* Version 3 started adding the individual domains to the recipients,
          so we don't need to tack on the extra */
       xml_dump_rcpt(rec->rcpt_arr, rec->n_rcpt, 0, NULL);
   }
   xml_dump_cust(rec->cust_arr, rec->n_cust);
   fprintf(outfile, "  </success>\n");
   return 0;
}

int
dump_bounce_record_normal(bounce_rec_t *rec)
{
   assert(rec && rec->magic == MAGIC_BOUNCE);

   fprintf(outfile, "  <bounce mid=\"%d\" bytes=\"%d\" ip=\"%s\" code=\"%s\"\n",
		   rec->mesg_id, rec->bytes, render_ip(rec->ip_addr), 
		   xml_encode(rec->code.len, rec->code.val));
   fprintf(outfile, "      from=\"%s\"\n", xml_encode(rec->from.len, rec->from.val));
   fprintf(outfile, "      del_time=\"%s\"\n", render_time(rec->log_secs, rec->log_usecs));
   fprintf(outfile, "      inj_time=\"%s\"\n", render_time(rec->entry_secs, rec->entry_usecs));
   fprintf(outfile, "      error=\"");
   xml_dump_errors(rec->err_arr, rec->n_err);
   fprintf(outfile, "\" reason=\"%s\">\n", xml_encode(rec->reason.len, rec->reason.val));

   /* handle v4 added fields */
   if (file_version >= 4) {
   	fprintf(outfile, "      source_ip=\"%s\"\n", render_ip(rec->src_ip));
   } 

   xml_dump_rcpt(rec->rcpt_arr, rec->n_rcpt, 0, NULL);
   xml_dump_cust(rec->cust_arr, rec->n_cust);
   fprintf(outfile, "  </bounce>\n");
   return 0;
}

/* backwards compatability */
int
dump_bounce_record_bc(bounce_rec_t *rec)
{
   assert(rec && rec->magic == MAGIC_BOUNCE);

   fprintf(outfile, "  <bounce mid=\"%d\" bytes=\"%d\" ip=\"%s\" code=\"%s\"\n",
		   rec->mesg_id, rec->bytes, render_ip(rec->ip_addr), 
		   xml_encode(rec->code.len, rec->code.val));
   fprintf(outfile, "      from=\"%s\"\n", xml_encode(rec->from.len, rec->from.val));
   fprintf(outfile, "      del_time=\"%s\"\n", render_time(rec->entry_secs, rec->entry_usecs));
   fprintf(outfile, "      inj_time=\"%s\"\n", render_time(rec->log_secs, rec->log_usecs));
   fprintf(outfile, "      error=\"");
   xml_dump_errors(rec->err_arr, rec->n_err);
   fprintf(outfile, "\" reason=\"%s\">\n", xml_encode(rec->reason.len, rec->reason.val));

   /* handle v4 added fields */
   if (file_version >= 4) {
   	fprintf(outfile, "      source_ip=\"%s\"\n", render_ip(rec->src_ip));
   } 

   xml_dump_rcpt(rec->rcpt_arr, rec->n_rcpt, 0, NULL);
   xml_dump_cust(rec->cust_arr, rec->n_cust);
   fprintf(outfile, "  </bounce>\n");
   return 0;
}

int (*dump_delv_record)(delv_rec_t *rec);
int (*dump_bounce_record)(bounce_rec_t *rec);
int (*dump_start_record)(start_rec_t *rec);
int (*dump_end_record)(end_rec_t *rec);

int
dump_end_record_local(end_rec_t *rec)
{
   fprintf(outfile, "<!-- end record %s -->\n", 
		   render_time(rec->log_secs, rec->log_usecs));
   return 0;
}

/*
 * Begin a new report.  The report is enclosed in a XML element
 * called the <delivery-report>.  The version reported here describes
 * the presentation version, not the underlying datafile format.
 * (which is in an unused element called "file_version").
 */
void
start_report(int options[])
{
   if (options[BACKWARDS_COMPAT]) {
       dump_delv_record = &dump_delv_record_bc;
       dump_bounce_record = &dump_bounce_record_bc;
   }
   else {
       dump_delv_record = &dump_delv_record_normal;
       dump_bounce_record = &dump_bounce_record_normal;
   }
   dump_start_record = dump_start_record_local;
   dump_end_record = dump_end_record_local;
   fprintf(outfile, "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>\n");
   fprintf(outfile, "<delivery-report version=\"%d\">\n", options[OUTPUT_VER]);
   fprintf(outfile, "\n");
}

/*
 * finish off the XML report by attaching the </delivery-report> 
 * tag to the outpout.
 */
void
end_report()
{
   fprintf(outfile, "</delivery-report>\n");
}


void 
usage(const char *name)
{
   fprintf (stderr, "Usage: %s [ options ] log0 log1 ...\n", name);
   fprintf (stderr, "     -o               output file\n");
   fprintf (stderr, "     -H               don't display hard bounce messages\n");
   fprintf (stderr, "     -D               don't display delivery messages\n");
   fprintf (stderr, "     -B               backwards compatability\n");
   fprintf (stderr, "     -version         version information\n");
   fprintf (stderr, "     -h               this message\n");
   exit(1);
}
