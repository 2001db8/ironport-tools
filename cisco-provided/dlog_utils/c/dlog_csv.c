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
char * revision = "$Name: DLOG_PARSING_TOOLS_1_4 $";
extern int LIBRARY_RECORD_VERSION;


#if 0
extern start_rec_t start_record;
extern end_rec_t end_record;
extern delv_rec_t delv_record;
extern bounce_rec_t bounce_record;
#endif
extern int file_version;



static int col_pos = 0;
static int msoft_output = 0;

static void add_col(char *fmt, ...)
{
   col_pos ++;

   if (col_pos > 1) {
       fputc(',', outfile);
   }

   if (msoft_output) {
       fputc('"', outfile);
   }

   {
      va_list ap;
      va_start(ap, fmt);
      vfprintf(outfile, fmt, ap);
      va_end(ap);
   }

   if (msoft_output) {
       fputc('"', outfile);
   }
}

static void add_colX(char *fmt, ...)
{
   static int colx_pos = 0;
   colx_pos = (colx_pos + 1) % 2;

   if (colx_pos == 1) {
       fputc(',', outfile);
       if (msoft_output) {
           fputc('"', outfile);
       } 

       {
          va_list ap;
          va_start(ap, fmt);
          vfprintf(outfile, fmt, ap);
          va_end(ap);
       }
   }

   else {
       fputc('=', outfile);  /* The INTERNAL SEP */

       {
          va_list ap;
          va_start(ap, fmt);
          vfprintf(outfile, fmt, ap);
          va_end(ap);
       }

       if (msoft_output) {
           fputc('"', outfile);
       }
   }
}

static void end_row()
{
   /* fputc('\r', outfile); */
   fputc('\n', outfile);
   col_pos = 0;
}

static void
render_csv_time(time_t secs, time_t usecs)
{
   char* fmt = next_pbuf();
   struct tm* l_time = localtime(&secs);
   strftime(fmt, BSZ, "%d-%b-%Y %H:%M:%S", l_time);

   add_col(fmt);
   add_col("%03d", usecs / 1000);
}

/* in this (simple format) escape anything that might not be simple text. */
static char *
csv_print_1(int len, char *src)
{
   char *_chr, *end, tmp;
   int pos = 0;
   char* buf = next_pbuf();

   end = (len > BSZ) ? src + (BSZ - 1) : src + len;

   for (_chr = src; _chr != end; _chr++)
   {
	  tmp = *_chr;
	  if (tmp < 40 || tmp >= 127 || tmp == '\\' || tmp == ',')
	  {
		 pos += sprintf(buf + pos, "\\%03o", tmp);
	  }
	  else {
		 buf[pos++] = tmp;
	  }
   }
   buf[pos] = '\0';

   return buf;
	  
}

/* (gorilla format) just need to double quotes. */
static char *
csv_print_2(int len, char *src)
{
   char *_chr, *end, tmp;
   int pos = 0;
   char* buf = next_pbuf();

   end = (len > BSZ) ? src + (BSZ - 1) : src + len;

   for (_chr = src; _chr != end; _chr++)
   {
	  tmp = *_chr;
	  if (tmp == '"')
	  {
		 buf [pos++] = tmp;
		 buf [pos++] = tmp;
	  }
	  else {
		 buf[pos++] = tmp;
	  }
   }
   buf[pos] = '\0';

   return buf;
	  
}

char* (*csv_print)(int len, char *src) = csv_print_1;

void 
dump_rcpt(rcpt_info_t *arr, int count)
{
   int idx;

   add_col("Rcpt");
   add_col("%d", count);

   if (count == 0) { return; }

   for (idx = 0; idx < count; ) 
   {
	  add_col ("Id");
	  add_col ("%d", arr[idx].rcpt_id);
	  add_col ("Attempt");
	  add_col ("%d", arr[idx].attempt);
	  add_col ("Email");
	  add_col ("%s", csv_print(arr[idx].address.len, arr[idx].address.val));
      idx++;
   }
}

void 
dump_rcpt_v2(rcpt_info_t *arr, int total, int idx)
{
   /* for malformed records: not likely but imaginable */
   if (total == 0) return;

   add_col ("Rcpt");
   add_col ("%d", total);
   add_col ("%d", idx);
   add_col ("%d", arr[idx].attempt);
   add_col ("%s", csv_print(arr[idx].address.len, arr[idx].address.val));
}

int 
cust_sort_func(cust_info_t** left, cust_info_t** right)
{
   return (strncmp(
      (*left)->name.val, 
      (*right)->name.val,
      ((*left)->name.len < (*right)->name.len ? (*left)->name.len : (*right)->name.len)));
}

void 
dump_cust(cust_info_t *arr, int count) 
{ 
   int idx;
   cust_info_t **sorted_arr;
   typedef int (*cmp_fn_t)(const void *, const void *);

   add_col ("Cust");
   add_col ("%d", count);

   if (count == 0) { return; }

   sorted_arr =  (cust_info_t**) malloc (count * sizeof(cust_info_t*));
   for (idx = 0; idx < count; idx++) { sorted_arr[idx] = &arr[idx]; }

   qsort(sorted_arr, count, sizeof(cust_info_t*), (cmp_fn_t)cust_sort_func); 

   for (idx = 0; idx < count; ) 
   {
      add_colX("%s", csv_print(sorted_arr[idx]->name.len, sorted_arr[idx]->name.val));
      add_colX("%s", csv_print(sorted_arr[idx]->value.len, sorted_arr[idx]->value.val));
      idx++;
   }

   free(sorted_arr);
}

void 
dump_cust_v2(cust_info_t *arr, int count) 
{ 
   int idx;
   cust_info_t **sorted_arr;
   typedef int (*cmp_fn_t)(const void *, const void *);

   add_col ("Cust");
   add_col ("%d", count);

   if (count == 0) { return; }

   sorted_arr =  (cust_info_t**) malloc (count * sizeof(cust_info_t*));
   for (idx = 0; idx < count; idx++) { sorted_arr[idx] = &arr[idx]; }

   qsort(sorted_arr, count, sizeof(cust_info_t*), (cmp_fn_t)cust_sort_func); 

   for (idx = 0; idx < count; ) 
   {
      add_colX("%s", csv_print(sorted_arr[idx]->name.len, sorted_arr[idx]->name.val));
      add_colX("%s", csv_print(sorted_arr[idx]->value.len, sorted_arr[idx]->value.val));
      idx++;
   }

   free(sorted_arr);
}

void
dump_errors(str_info_t *arr, int count)
{
   int idx;

   add_col ("Errors");
   add_col ("%d", count);

   if (count == 0) { return; }

   for (idx = 0; idx < count; ) 
   {
       add_col ("%s", csv_print(arr[idx].len, arr[idx].val));
       idx++;
   }
}

int
dump_start_record_local(start_rec_t *rec)
{
   assert(rec && rec->magic == MAGIC_START);
   add_col ("START");
   render_csv_time(rec->log_secs, rec->log_usecs); 
   add_col ("%d", rec->version);
   add_col ("%d", rec->file_version);
   end_row();
   return 0;
}

int
dump_delv_record_v1(delv_rec_t *rec)
{
   assert(rec && rec->magic == MAGIC_DELV);
   add_col ("DELV");
   render_csv_time(rec->log_secs, rec->log_usecs);
   render_csv_time(rec->entry_secs, rec->entry_usecs);
   add_col ("%d", rec->bytes);
   add_col ("%d", rec->mesg_id);
   add_col ("%s", render_ip(rec->ip_addr));
   add_col ("%s", csv_print(rec->from.len, rec->from.val));
   add_col ("%s", csv_print(rec->domain.len, rec->domain.val));
   dump_rcpt(rec->rcpt_arr, rec->n_rcpt);
   dump_cust(rec->cust_arr, rec->n_cust);
   end_row();
   return 0;
}


int
dump_delv_record_v2(delv_rec_t *rec)
{
   int rid_idx = 0;
   assert(rec && rec->magic == MAGIC_DELV);
	
   do
   {
       add_col ("DELV");
       render_csv_time(rec->log_secs, rec->log_usecs);
       render_csv_time(rec->entry_secs, rec->entry_usecs);
       add_col ("%d", rec->bytes);
       add_col ("%d", rec->mesg_id);
       add_col ("%s", render_ip(rec->ip_addr));
       add_col ("%s", csv_print(rec->from.len, rec->from.val));
       add_col ("%s", csv_print(rec->domain.len, rec->domain.val));

       /* handle v4 enhancements */
       if (file_version >= 4) {
       	   add_col ("%s", render_ip(rec->src_ip));
       	   add_col ("%s", csv_print(rec->code.len, rec->code.val));
       	   add_col ("%s", csv_print(rec->reply.len, rec->reply.val));
       }

       dump_rcpt_v2(rec->rcpt_arr, rec->n_rcpt, rid_idx);
       dump_cust(rec->cust_arr, rec->n_cust);
       end_row();
       rid_idx ++;
   }
   while (rid_idx < rec->n_rcpt);

   return 0;
}

int
dump_bounce_record_v1(bounce_rec_t *rec)
{
   assert(rec && rec->magic == MAGIC_BOUNCE);
   add_col ("BOUNCE");
   render_csv_time(rec->log_secs, rec->log_usecs);
   render_csv_time(rec->entry_secs, rec->entry_usecs);
   add_col ("%d", rec->bytes);
   add_col ("%d", rec->mesg_id);
   add_col ("%s", render_ip(rec->ip_addr));
   add_col ("%s", csv_print(rec->from.len, rec->from.val));
   add_col ("%s", csv_print(rec->reason.len, rec->reason.val));
   add_col ("%s", csv_print(rec->code.len, rec->code.val));
   dump_rcpt(rec->rcpt_arr, rec->n_rcpt);
   dump_cust(rec->cust_arr, rec->n_cust);
   dump_errors(rec->err_arr, rec->n_err);
   end_row();
   return 0;
}

int
dump_bounce_record_v2(bounce_rec_t *rec)
{
   int rid_idx = 0;
   assert(rec && rec->magic == MAGIC_BOUNCE);

   do
   {
       add_col ("BOUNCE");
       render_csv_time(rec->log_secs, rec->log_usecs);
       render_csv_time(rec->entry_secs, rec->entry_usecs);
       add_col ("%d", rec->bytes);
       add_col ("%d", rec->mesg_id);
       add_col ("%s", render_ip(rec->ip_addr));
       add_col ("%s", csv_print(rec->from.len, rec->from.val));
       add_col ("%s", csv_print(rec->reason.len, rec->reason.val));
       add_col ("%s", csv_print(rec->code.len, rec->code.val));

       /* handle v4 enhancements */
       if (file_version >= 4) {
       	   add_col ("%s", render_ip(rec->src_ip));
       }

       dump_rcpt_v2(rec->rcpt_arr, rec->n_rcpt, rid_idx);
       dump_cust(rec->cust_arr, rec->n_cust);
       dump_errors(rec->err_arr, rec->n_err);
       end_row();
       rid_idx ++;
   }
   while (rid_idx < rec->n_rcpt);
   return 0;
}

int (*dump_delv_record)(delv_rec_t *rec);
int (*dump_bounce_record)(bounce_rec_t *rec);
int (*dump_end_record)(end_rec_t *rec);
int (*dump_start_record)(start_rec_t *rec);  

int
dump_end_record_local(end_rec_t *rec)
{
   assert(rec && rec->magic == MAGIC_END);
   add_col ("END");
   render_csv_time(rec->log_secs, rec->log_usecs);
   end_row();
   return 0;
}

void start_report(int options[]) 
{ 
	int version = options[OUTPUT_VER];
        msoft_output = options[MSOFT_CSV];

        if (msoft_output) {
           csv_print = csv_print_2;
        }

    dump_start_record = dump_start_record_local;
    dump_end_record = dump_end_record_local;

	/* prepare the correct output handlers */
	if (version == 1) {
                LIBRARY_RECORD_VERSION = 1;
		dump_delv_record = &dump_delv_record_v1;
		dump_bounce_record = &dump_bounce_record_v1;
	}
	else {
                LIBRARY_RECORD_VERSION = 2;
   	 	dump_delv_record = &dump_delv_record_v2;
		dump_bounce_record = &dump_bounce_record_v2;


		if (options[VERBOSE]) 
                {
		    add_col ("NOTE");
                    add_col ("Start Record Format");
                    add_col ("'START' log_time log_time_ms output_version delivery_log_version");
                    end_row();

		    add_col ("NOTE");
                    add_col ("Delivery Record Format");
                    add_col ("'DELV' log_time log_time_ms inj_time inj_time_ms"
                             " mesg_bytes mid ip from domain"
                             " 'Rcpt' n_rcpts rid_id attempt_number address"
                             " *HEADERS");
                    end_row();

		    add_col ("NOTE");
                    add_col ("Bounce Record Format");
                    add_col ("'BOUNCE' log_time log_time_ms inj_time inj_time_ms"
                             " mesg_bytes mid ip from domain"
                             " failure_reason failure_code"
                             " 'Rcpt' n_rcpts rid_id attempt_number address"
                             " *HEADERS *ERRORS");
                    end_row();

		    add_col ("NOTE");
                    add_col ("End Record Format");
                    add_col ("'END' TIME MILLI_SECS");
                    end_row();

		    add_col ("NOTE");
                    add_col ("*HEADERS Format");
                    add_col ("'Cust' num_headers hdr1=val1 hdr2=val2 . . . hdrn=valn");
                    end_row();

		    add_col ("NOTE");
                    add_col ("*ERRORS Format");
                    add_col ("'Errors' num_errors err_1 err_2 . . . err_n");
                    end_row();
	       }
	}
}
void end_report() { }



void usage(const char *name)
{
   fprintf (stderr, "Usage: %s [ options ] log0 log1 ...\n", name);
   fprintf (stderr, "     -o               output file\n");
   fprintf (stderr, "     -H               don't display hard bounce messages\n");
   fprintf (stderr, "     -D               don't display delivery messages\n");
   fprintf (stderr, "     -V n             use output version n\n");
   fprintf (stderr, "     -1               use output version 1\n");
   fprintf (stderr, "     -m               output microsoft styled csv\n");
   fprintf (stderr, "     -v               more verbose output\n");
   fprintf (stderr, "     -version         version information\n");
   fprintf (stderr, "     -B               backwards compatability\n");
   fprintf (stderr, "     -h               this message\n");
   exit(1);
}
