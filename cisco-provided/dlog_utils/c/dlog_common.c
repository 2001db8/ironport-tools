/*
 * dlog_parser.c - dump IronPort delivery logs in CSV, XML and ascii
 *
 * Copyright (C) 2002, IronPort Systems.  All rights reserved.
 * $Revision: 1.3 $
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

#ifndef WIN32 
	#include <sys/uio.h>
	#include <libgen.h>
#endif

#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <time.h>
#include <string.h>
#include <stdlib.h>

#ifdef WIN32
    #include <stdint.h>
#endif 

#include <iostream>
#include <fstream>

#include "dlog_common.h"
#include "un_pickle.h"

int LIBRARY_RECORD_VERSION = 1;
#define MAX_SUPPORTED_VERSION 4

FILE * outfile; /* = stdout; */


extern char* revision;
static char version[100];

static char data_buffer[HSZ];
static int  data_buffer_len = 0;
static int  data_buffer_read_pos = 0;
int  file_version = 0;

/* rediculously large */
static char print_buffer[PBUF_SZ][HSZ];
static int  pbuf_idx = 0;

start_rec_t start_record;
end_rec_t end_record;
delv_rec_t delv_record;
bounce_rec_t bounce_record;
str_info_t NULL_STR = { 0, "" };

int (*cli_start_hook)(start_rec_t*);
int (*cli_end_hook)(end_rec_t*);
int (*cli_delv_hook)(delv_rec_t*);
int (*cli_bounce_hook)(bounce_rec_t*);

static int rec_load_errors(int *, str_info_t**, int, stack_data_t *); 
static int rec_load_rcpt(int *, rcpt_info_t **, int, stack_data_t *);
static int rec_load_cust(int *, cust_info_t **, int, stack_data_t *);
static int rec_set_string(str_info_t *, int, stack_data_t*);
static int rec_set_unsigned(unsigned *, int, stack_data_t*);
static int _process_start_record ( unsigned, unsigned, stack_data_t *);
static int _process_end_record ( unsigned, unsigned, stack_data_t *);
static int _process_delv_record ( unsigned, unsigned, stack_data_t *);
static int _process_bounce_record ( unsigned, unsigned, stack_data_t *);

extern int (*dump_delv_record)(delv_rec_t *rec);
extern int (*dump_bounce_record)(bounce_rec_t *rec);
extern int (*dump_end_record)(end_rec_t *rec);
extern int (*dump_start_record)(start_rec_t *rec);

char* next_pbuf()
{
   char* pb = &print_buffer[(++pbuf_idx) % PBUF_SZ][0];
   *pb = '\0';
   return pb;
}

static int is_supported (int rec_version) {
   return ((rec_version >= 0) && (rec_version <= MAX_SUPPORTED_VERSION));
}

#if 0
static char *
dump_print(int len, const char *src)
{
   const char *_chr, *end;
   char tmp;
   int pos = 0;
   char* buf = next_pbuf();

   end = (len > BSZ) ? src + (BSZ - 1) : src + len;
   buf[0] = '\0';

   for (_chr = src; _chr != end; _chr++)
   {
	  tmp = *_chr;
	  if (tmp < 32 || tmp >= 127 || tmp == '\\')
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
#endif

static char* 
data_buffer_read_line(int *bsz)
{
   int spos = data_buffer_read_pos;

   while (
	  data_buffer[spos] != '\n' && 
	  spos != data_buffer_len)
   {
	  spos ++;
   }

   if (spos == data_buffer_len) { 
	  *bsz = data_buffer_len - data_buffer_read_pos;
	  return &data_buffer[data_buffer_read_pos];
   }
   else {
	  int opos = data_buffer_read_pos;
	  *bsz = spos - opos;
	  data_buffer_read_pos = spos;
	  data_buffer[data_buffer_read_pos] = '\0';
	  data_buffer_read_pos ++;
	  return &data_buffer[opos];
   }
}

static char* 
data_buffer_read_bytes (int sz, int *bsz)
{
   int start = data_buffer_read_pos;
   if (sz > (HSZ - data_buffer_read_pos)) {
	  *bsz = 0;
	  return NULL;
   }
   else {
	  *bsz = sz;
	  data_buffer_read_pos += sz;
	  return  & data_buffer[start];
   }
}

/*
 * pretty print the sec/usec pair.
 */
const char*
render_time(time_t secs, time_t usecs)
{
   char* buf = next_pbuf();
   char* fmt = next_pbuf();
   struct tm* l_time = localtime(&secs);
   strftime(fmt, BSZ, "%a %b %d %H:%M:%S.%%03d %Y", l_time);
   snprintf(buf, BSZ, fmt, usecs / 1000);
   return buf;
}

const char*
render_ip(unsigned ip)
{
   char* buf = next_pbuf();
   sprintf(buf, "%u.%u.%u.%u",
		   (ip >> 24 ) & 0xFF,
		   (ip >> 16 ) & 0xFF,
		   (ip >> 8 ) & 0xFF,
		   (ip >> 0 ) & 0xFF);

   return buf;
}

/*
 *  '<<' initial log record
 *  '>>' final log record
 *  'HB' log entry for a "hard bounce"
 *  'MD' log entry for a "message delivery"
 */
typedef enum 
{
   LOG_START,
   LOG_END,
   LOG_HARD_BOUNCE,
   LOG_MESG_DELV,
   LOG_UNKNOWN

} rec_type_t;

/* 
 * Record data element 
 * TYPE
 * LENGTH-IN-BYTES
 * TIME-OF-DAY (local-time) in Seconds
 * TIME-OF-DAY (local-time), MicroSecond fraction
 */
typedef struct 
{
	  char       rec_dbg[2];
	  rec_type_t rec_type;
	  u_int32_t  d_len;
	  u_int32_t  t_secs;
	  u_int32_t  t_usecs;
} record_t;

/* for debugging */
static const char *
rec_type_string(rec_type_t typ) 
{
   if (typ == LOG_START) return "start-record";
   if (typ == LOG_END) return "end-record";
   if (typ == LOG_HARD_BOUNCE) return "hard-bounce";
   if (typ == LOG_MESG_DELV) return "message-delivery";
   if (typ == LOG_UNKNOWN) return "(unknown-record-type)";
   return "(error, bad record!)";
}

/* for debugging */
static void 
dump_record(record_t *rec)
{
   fprintf (outfile, "TYPE %s\n", rec_type_string(rec->rec_type));
   fprintf (outfile, "  CHAR %c %c\n", rec->rec_dbg[0], rec->rec_dbg[1]);
   fprintf (outfile, "  DLEN %u\n", rec->d_len);
   fprintf (outfile, "  SECS %u\n", rec->t_secs);
   fprintf (outfile, "  USEC %u\n", rec->t_usecs);
   fprintf (outfile, "  TIME is %s\n", render_time(rec->t_secs, rec->t_usecs));
}

/* input helper */
typedef union 
{
	  u_int8_t arr[4];
	  u_int32_t val;
} val_input_t;

static rec_type_t
get_type(char one, char two)
{
   if (one == '<' && two == '<') return LOG_START;
   if (one == '>' && two == '>') return LOG_END;
   if (one == 'M' && two == 'D') return LOG_MESG_DELV;
   if (one == 'H' && two == 'B') return LOG_HARD_BOUNCE;
   return LOG_UNKNOWN;
}

#if LITTLE_ENDIEN == 1

static u_int32_t 
val_fix(val_input_t val)
{
   val_input_t tmp;
   tmp.arr[0] = val.arr[3];
   tmp.arr[1] = val.arr[2];
   tmp.arr[2] = val.arr[1];
   tmp.arr[3] = val.arr[0];

   return tmp.val;
}

#else
static u_int32_t 
val_fix(val_input_t val)
{
   return val.val;
}
#endif

static int
read_log_record(std::ifstream *input)
{
   int bytes;
   char rec_type[2];
   val_input_t vals[3];
   record_t n_rec;

   memset(rec_type, 0, 2);
   memset(vals, 0, sizeof(u_int32_t) * 3);

   /* read the type */
   input->read(rec_type,2);

   if (input->eof() || (2 != input->gcount())) {
		return 0;
   }

   /* the integers */
   input->read((char *)vals, sizeof(u_int32_t) * 3);
   if (3*sizeof(u_int32_t) != input->gcount()) {
		return 0;
   }

   n_rec.rec_dbg[0] = rec_type[0];
   n_rec.rec_dbg[1] = rec_type[1];
   n_rec.rec_type = get_type(rec_type[0], rec_type[1]);
   n_rec.d_len   = val_fix(vals[0]);
   n_rec.t_secs  = val_fix(vals[1]);
   n_rec.t_usecs = val_fix(vals[2]);

//#define DEBUG_RECORD
#ifdef DEBUG_RECORD
   dump_record((record_t*) &n_rec); 
#endif

   if (!input->eof () && n_rec.d_len < HSZ) {
     input->read((char *) data_buffer, n_rec.d_len);
     bytes = input->gcount();
	  if (bytes != n_rec.d_len) {
		 /* short-read */
		 return 0;
	  }

	  else {
		 /* 
			off_t here = lseek(fd, 0, 1);
			printf ("HERE is %d\n", here);
		 */

		 /* callout to pickle back-end */
		 stk_init_library();
		 data_buffer_len = bytes;
		 data_buffer_read_pos = 0;
		 stk_parse_stream();

		 switch (n_rec.rec_type) {
			case LOG_START:
			   _process_start_record(
				  n_rec.t_secs,
				  n_rec.t_usecs,
				  parsing_stack_pop());
			   break;

			case LOG_END:
			   _process_end_record(
				  n_rec.t_secs,
				  n_rec.t_usecs,
				  parsing_stack_pop());
			   break;
			case LOG_HARD_BOUNCE:
			   _process_bounce_record(
				  n_rec.t_secs,
				  n_rec.t_usecs,
				  parsing_stack_pop());
			   break;
			case LOG_MESG_DELV:
			   _process_delv_record(
				  n_rec.t_secs,
				  n_rec.t_usecs,
				  parsing_stack_pop());
			   break;

			default:
			   print_stack();
			   break;
		 };

		 stk_cleanup();
	  }
   }
   else { 
	  /* error callout */
	  return 0; 
   }

   return 1;
}

void close_dlog_library() 
{
   stk_cleanup();
}

int init_dlog_library()
{
   /* START RECORD PROTOTYPE */
   start_record.magic = MAGIC_START;
   start_record.version = LIBRARY_RECORD_VERSION;
   start_record.log_secs = 0;
   start_record.log_usecs = 0;

   /* END RECORD PROTOTYPE */
   end_record.magic = MAGIC_END;
   end_record.log_secs = 0;
   end_record.log_usecs = 0;

   /* DELV RECORD PROTOTYPE */
   delv_record.magic = MAGIC_DELV;
   delv_record.log_secs = 0;
   delv_record.log_usecs = 0;

   delv_record.entry_secs = 0;
   delv_record.entry_usecs = 0;
   delv_record.bytes = 0;
   delv_record.mesg_id = 0;
   delv_record.ip_addr = 0;
   delv_record.from = NULL_STR;
   delv_record.domain = NULL_STR;
   delv_record.n_cust = 0;
   delv_record.n_rcpt = 0;
   delv_record.cust_arr = NULL;
   delv_record.rcpt_arr = NULL;
   delv_record.src_ip = 0;
   delv_record.code = NULL_STR;
   delv_record.reply = NULL_STR;

   /* BOUNCE RECORD PROTOTYPE */
   bounce_record.magic = MAGIC_BOUNCE;
   bounce_record.log_secs = 0;
   bounce_record.log_usecs = 0;

   bounce_record.entry_secs = 0;
   bounce_record.entry_usecs = 0;
   bounce_record.bytes = 0;
   bounce_record.mesg_id = 0;
   bounce_record.ip_addr = 0;
   bounce_record.from = NULL_STR;
   bounce_record.code = NULL_STR;
   bounce_record.reason = NULL_STR;
   bounce_record.n_err = 0;
   bounce_record.n_cust = 0;
   bounce_record.n_rcpt = 0;
   bounce_record.err_arr = NULL;
   bounce_record.cust_arr = NULL;
   bounce_record.rcpt_arr = NULL;
   bounce_record.src_ip = 0;

   cli_start_hook = NULL;
   cli_end_hook = NULL;
   cli_delv_hook = NULL;
   cli_bounce_hook = NULL;

   stk_init_library();
   stk_set_buffers(
	  data_buffer_read_line,
	  data_buffer_read_bytes);

   memset(data_buffer, 0, HSZ);
   data_buffer_len = 0;
   data_buffer_read_pos = 0;

   return 1;
}

static int
client_callout(int magic, void *record)
{
   int ret = 0;
   if (magic == MAGIC_START && cli_start_hook != NULL) {
	  ret = cli_start_hook((start_rec_t*) record);
   }
   else if (magic == MAGIC_END && cli_end_hook != NULL) {
	  ret = cli_end_hook((end_rec_t*) record);
   }
   else if (magic == MAGIC_DELV && cli_delv_hook != NULL) {
	  ret = cli_delv_hook((delv_rec_t*) record);
   }
   else if (magic == MAGIC_BOUNCE && cli_bounce_hook != NULL) {
	  ret = cli_bounce_hook((bounce_rec_t*) record);
   }

   return ret;
}

static void 
free_str(str_info_t* string) 
{ 
   if (string->val != NULL) 
   { 
	  free(string->val); 
   } 
}

static void
free_cust(cust_info_t* arr, int len) 
{
   int idx;

   if (arr == NULL) {  return; }

   for (idx = 0; idx < len; idx++) 
   {
	  free_str(&arr[idx].name);
	  free_str(&arr[idx].value);
   }
   free(arr);
}

static void
free_err(str_info_t* arr, int len)
{
   int idx;
   if (arr == NULL) {  return; }

   for (idx = 0; idx < len; idx++) {
	  free_str(&arr[idx]);
   }
   free(arr);
}

static void
free_rcpt(rcpt_info_t* arr, int len) 
{
   int idx;

   if (arr == NULL) {  return; }

   for (idx = 0; idx < len; idx++) {
	  free_str(&arr[idx].address);
   }
   free(arr);
}

static void
free_record(int magic, void *record)
{
   if (record == NULL) { return; }
   if (magic == MAGIC_START) {
	  start_rec_t* start = (start_rec_t*) record;
	  free (start);
	  return;
   }

   if (magic == MAGIC_END) {
	  end_rec_t* end = (end_rec_t*) record;
	  free (end);
	  return;
   }

   if (magic == MAGIC_DELV) {
	  delv_rec_t* delv = (delv_rec_t*) record;
	  free_str (&delv->from);
	  free_str (&delv->domain);
	  free_cust (delv->cust_arr, delv->n_cust);
	  free_rcpt (delv->rcpt_arr, delv->n_rcpt);
	  free(delv);
	  return;
   }

   if (magic == MAGIC_BOUNCE) {
	  bounce_rec_t* bounce = (bounce_rec_t*) record;
	  free_str (&bounce->from);
	  free_str (&bounce->reason);
	  free_str (&bounce->code);
	  free_cust (bounce->cust_arr, bounce->n_cust);
	  free_rcpt (bounce->rcpt_arr, bounce->n_rcpt);
	  free_err (bounce->err_arr, bounce->n_err);
	  free(bounce);
	  return;
   }

   assert (! "impossible");
}

static int
_process_start_record (
   unsigned log_sec,
   unsigned log_usec,
   stack_data_t *arr)
{
   int cres;
   start_rec_t* s_record;

   if (arr == NULL || arr->m_type != Typ_Integer) {
	  return 0;
   }

   s_record = (start_rec_t*) malloc(sizeof(start_rec_t));
   *s_record = start_record;
   s_record->log_secs = log_sec;
   s_record->log_usecs = log_usec;
   file_version = arr->data.ival;
   s_record->file_version = file_version;

   if (!is_supported(file_version)) {
	  /* ERROR CALLOUT :: wrong version */
	  return 0;
   }
   
   cres = client_callout (MAGIC_START, s_record);
   if (cres == 0) { free_record(MAGIC_START, s_record); }

   return cres;
}

static int
_process_end_record (
   unsigned log_sec,
   unsigned log_usec,
   stack_data_t *arr)
{
   int cres;
   end_rec_t* e_record;

   if (arr == NULL || arr->m_type != Typ_None) {
	  return 0; 
   }

   if (!is_supported(file_version)) {
	  /* ERROR CALLOUT :: wrong version */
	  return 0;
   }

   /* DO CALLOUT end_record */
   e_record = (end_rec_t*) malloc(sizeof(end_rec_t));
   *e_record = end_record;
   e_record->log_secs = log_sec;
   e_record->log_usecs = log_usec;

   cres = client_callout (MAGIC_END, e_record);
   if (cres == 0) { free_record(MAGIC_END, e_record); }

   return 0;
}

static int
_process_delv_record (
   unsigned log_sec,
   unsigned log_usec,
   stack_data_t *arr)
{
   int cres;
   delv_rec_t* d_record;

   if (arr == NULL || arr->m_type != Typ_Tuple) {
	  return 0; 
   }
   if (!is_supported(file_version)) {
	  /* ERROR CALLOUT :: wrong version */
	  return 0;
   }

   d_record = (delv_rec_t*) malloc(sizeof(delv_rec_t));
   *d_record = delv_record;
   d_record->log_secs = log_sec;
   d_record->log_usecs = log_usec;

   if (file_version == 0) 
   {
	  rec_set_unsigned(&d_record->entry_secs, 0, arr);
	  rec_set_unsigned(&d_record->entry_usecs, 1, arr);
	  rec_set_unsigned(&d_record->bytes, 2, arr);
	  rec_set_unsigned(&d_record->mesg_id, 3, arr);
	  rec_set_unsigned(&d_record->ip_addr, 4, arr);
	  rec_set_string(&d_record->from, 5, arr);
	  rec_set_string(&d_record->domain, 6, arr);

	  rec_load_rcpt(&d_record->n_rcpt, &d_record->rcpt_arr, 7, arr);
	  rec_load_cust(&d_record->n_cust, &d_record->cust_arr, 8, arr);
   }
   else if (file_version < 4 ) {
	  rec_set_unsigned(&d_record->entry_secs, 0, arr);
	  rec_set_unsigned(&d_record->entry_usecs, 1, arr);
	  rec_set_unsigned(&d_record->bytes, 2, arr);
	  rec_set_unsigned(&d_record->mesg_id, 3, arr);
	  rec_set_unsigned(&d_record->ip_addr, 4, arr);
	  rec_set_string(&d_record->from, 5, arr);
	  rec_set_string(&d_record->domain, 6, arr);

	  rec_load_rcpt(&d_record->n_rcpt, &d_record->rcpt_arr, 7, arr);
	  rec_load_cust(&d_record->n_cust, &d_record->cust_arr, 8, arr);
   }
   else if (is_supported(file_version)) {
	  rec_set_unsigned(&d_record->entry_secs, 0, arr);
	  rec_set_unsigned(&d_record->entry_usecs, 1, arr);
	  rec_set_unsigned(&d_record->bytes, 2, arr);
	  rec_set_unsigned(&d_record->mesg_id, 3, arr);
	  rec_set_unsigned(&d_record->ip_addr, 4, arr);
	  rec_set_string(&d_record->from, 5, arr);
	  rec_set_string(&d_record->domain, 6, arr);

	  rec_load_rcpt(&d_record->n_rcpt, &d_record->rcpt_arr, 7, arr);
	  rec_load_cust(&d_record->n_cust, &d_record->cust_arr, 8, arr);
   

	  rec_set_unsigned(&d_record->src_ip, 9, arr);
	  rec_set_string(&d_record->code, 10, arr);
	  rec_set_string(&d_record->reply, 11, arr);
}
   else {
	  assert (! "impossible, already checked!");
   }

   /* DO CALLOUT delv_record */
   cres = client_callout (MAGIC_DELV, d_record);
   if (cres == 0) { free_record(MAGIC_DELV, d_record); }

   return 0;
}

static int
_process_bounce_record (
   unsigned log_sec,
   unsigned log_usec,
   stack_data_t *arr)
{
   int cres;
   bounce_rec_t* b_record;

   if (arr == NULL || arr->m_type != Typ_Tuple) {
	  return 0; 
   }
   if (!is_supported(file_version)) {
	  /* ERROR CALLOUT :: wrong version */
	  return 0;
   }

   b_record = (bounce_rec_t*) malloc(sizeof(bounce_rec_t));
   *b_record = bounce_record;
   b_record->log_secs = log_sec;
   b_record->log_usecs = log_usec;

   if (file_version == 0) 
   {
	  rec_set_unsigned(&b_record->entry_secs, 0, arr);
	  rec_set_unsigned(&b_record->entry_usecs, 1, arr);
	  rec_set_unsigned(&b_record->bytes, 2, arr);
	  rec_set_unsigned(&b_record->mesg_id, 3, arr);
	  rec_set_unsigned(&b_record->ip_addr, 4, arr);
	  rec_set_string(&b_record->from, 5, arr);
	  rec_set_string(&b_record->code, 6, arr);
	  /* rec_set_string_val(&b_record->reason, ""); */

	  rec_load_errors(&b_record->n_err, &b_record->err_arr, 7, arr);
	  rec_load_rcpt(&b_record->n_rcpt, &b_record->rcpt_arr, 8, arr);
	  rec_load_cust(&b_record->n_cust, &b_record->cust_arr, 10, arr);
   }
   else if (file_version < 4) {
	  rec_set_unsigned(&b_record->entry_secs, 0, arr);
	  rec_set_unsigned(&b_record->entry_usecs, 1, arr);
	  rec_set_unsigned(&b_record->bytes, 2, arr);
	  rec_set_unsigned(&b_record->mesg_id, 3, arr);
	  rec_set_unsigned(&b_record->ip_addr, 4, arr);
	  rec_set_string(&b_record->from, 5, arr);
	  rec_set_string(&b_record->reason, 6, arr);
	  rec_set_string(&b_record->code, 7, arr);

	  rec_load_errors(&b_record->n_err, &b_record->err_arr, 8, arr);
	  rec_load_rcpt(&b_record->n_rcpt, &b_record->rcpt_arr, 9, arr);
	  rec_load_cust(&b_record->n_cust, &b_record->cust_arr, 10, arr);
   }
   else if (is_supported(file_version)) {
          rec_set_unsigned(&b_record->entry_secs, 0, arr);
	  rec_set_unsigned(&b_record->entry_usecs, 1, arr);
	  rec_set_unsigned(&b_record->bytes, 2, arr);
	  rec_set_unsigned(&b_record->mesg_id, 3, arr);
	  rec_set_unsigned(&b_record->ip_addr, 4, arr);
	  rec_set_string(&b_record->from, 5, arr);
	  rec_set_string(&b_record->reason, 6, arr);
	  rec_set_string(&b_record->code, 7, arr);

	  rec_load_errors(&b_record->n_err, &b_record->err_arr, 8, arr);
	  rec_load_rcpt(&b_record->n_rcpt, &b_record->rcpt_arr, 9, arr);
	  rec_load_cust(&b_record->n_cust, &b_record->cust_arr, 10, arr);
   
	  rec_set_unsigned(&b_record->src_ip, 11, arr);
}

   else {
	  assert (! "impossible, already checked!");
   }

   /* DO CALLOUT bounce_record */
   cres = client_callout (MAGIC_BOUNCE, b_record);
   if (cres == 0) { free_record(MAGIC_BOUNCE, b_record); }

   return 0;
}

static int
rec_set_unsigned(
   unsigned *val, 
   int pos, stack_data_t* arr)
{
   stack_data_t* rec;
   int max_pos = arr->l_pos;
   
   if (pos >= max_pos) { /* ERROR */ return 1; }

   rec = arr->l_arr[pos];
   if (rec == NULL) { /* ERROR */ return 1; }

   /* okay, now process the data */

   if (rec->m_type != Typ_Integer) { return 1; }

   *val = (unsigned) rec->data.ival;
   return 0;
}

static int
rec_set_string(str_info_t *str, int pos, stack_data_t* arr)
{
   stack_data_t* rec;
   int max_pos = arr->l_pos, len;
   
   if (str == NULL || arr == NULL) { return 1; }

   if (max_pos < pos || (rec = arr->l_arr[pos]) == NULL) { return 1; }

   if (rec->m_type != Typ_String &&
	   rec->m_type != Typ_Unicode &&
	   rec->m_type != Typ_UTF &&
	   rec->m_type != Typ_Long)
   {
	  return 1;
   }

   len = rec->s_sz;
   str->len = len;
   str->val = (char *) malloc(len+1);
   str->val[len] = '\0';
   memcpy(str->val, rec->s_str, len);

   /* correlates to _my_strdup() in the un_pickle.c file ... */
   /* fprintf(outfile, "set {%d} [%s]\n", len, dump_print(len, str->val)); */

   return 0;
}

static int
rec_load_cust(
   int *count, 
   cust_info_t **dst,
   int pos, 
   stack_data_t *arr)
{
   stack_data_t *rec;
   int idx;

   if (count == NULL || dst == NULL || arr == NULL) { return 1; }
   if (arr->l_pos <= pos || pos < 0) { return 1 ;}

   rec = arr->l_arr[pos];

   if (rec == NULL) { 
	  *dst = NULL;
	  *count = 0;
	  return 0; 
   }
   else if (
	  rec->m_type != Typ_List &&
	  rec->m_type != Typ_Tuple &&
	  rec->m_type != Typ_Dict) 
   {
	  return 1;
   }
   else {
	  cust_info_t proto;
	  proto.name.len = 0;
	  proto.value.len = 0;
	  proto.name.val = NULL;
	  proto.value.val = NULL;

	  *count = rec->l_pos;

	  if (*count <= 0 || *count > MAX_SANITY) { return 1; }
	  *dst = (cust_info_t*) malloc(*count * sizeof(cust_info_t));

	  for (idx = 0; idx < *count; idx++)
	  {
	         stack_data_t *header;

		 (*dst)[idx] = proto;

		 if (rec->m_type != Typ_Tuple && rec->m_type != Typ_List) {
		   continue;
		 }

		 header = rec->l_arr[idx];

		 rec_set_string(&(*dst)[idx].name, 0, header);
		 rec_set_string(&(*dst)[idx].value, 1, header);
	  }
	  
	  return 0;
   }

   assert (! "impossible case");
   return 1;
}

/* load tuple of ( rcpt_id, address, attempt number ) */
static int
rec_load_rcpt_1 (
   rcpt_info_t* result, 
   stack_data_t* tupl)
{
   if (result == NULL || tupl == NULL) { return 1; }
   if (tupl->m_type != Typ_Tuple && tupl->m_type != Typ_List) { return 1 ;}
   if (tupl->l_pos != 3) { return 1; }

   /* load RCPT_ID */
   if (tupl->l_arr[0]->m_type != Typ_Integer) { return 1; }
   result->rcpt_id = tupl->l_arr[0]->data.ival;

   /* load ADDRESS */
#if 0
   typ = tupl->l_arr[1]->m_type;
   if (typ != Typ_String && typ != Typ_Unicode && typ != Typ_UTF) { return 1; }
   result->address.len = tupl->l_arr[1]->s_sz;

   if (result->address.len < 0) { return 1; }
   result->address.val = (char*) malloc (result->address.len);
   memcpy(result->address.val, tupl->l_arr[1]->s_str, result->address.len);
#endif
   rec_set_string(&result->address, 1, tupl);

   /* load ATTEMPT */
   if (tupl->l_arr[2]->m_type != Typ_Integer) { return 1; }
   result->attempt = tupl->l_arr[2]->data.ival + 1;
   

   return 0;
}

static int
rec_load_rcpt(
   int *count, 
   rcpt_info_t **dst,
   int pos, 
   stack_data_t *arr)
{
   stack_data_t *rec;
   int idx;

   if (count == NULL || dst == NULL || arr == NULL) { return 1; }
   if (arr->l_pos <= pos || pos < 0) { return 1 ;}

   rec = arr->l_arr[pos];

   if (rec == NULL) { 
	  *dst = NULL;
	  *count = 0;
	  return 0; 
   }
   else if (
	  rec->m_type != Typ_List &&
	  rec->m_type != Typ_Tuple &&
	  rec->m_type != Typ_Dict) 
   {
	  return 1;
   }

   else 
   {
	  rcpt_info_t proto, tmp;
	  proto.address.len = 0;
	  proto.address.val = 0;
	  proto.attempt = 0;
	  proto.rcpt_id = 0;

	  *count = rec->l_pos;
	  if (*count < 0 || *count > MAX_SANITY) { return 1; }
	  *dst = (rcpt_info_t*) malloc(*count * sizeof(rcpt_info_t));

	  for (idx = 0; idx < *count; idx++) 
	  {
		 tmp = proto;
		 rec_load_rcpt_1(&tmp, rec->l_arr[idx]);
		 (*dst)[idx] = tmp;
	  }
	  
	  return 0;
   }

   assert (! "impossible case");
   return 1;
}
			  
static int
rec_load_errors(
   int *count,
   str_info_t **dst,
   int pos,
   stack_data_t *arr) 
{ 
   stack_data_t *rec;
   int idx;

   if (count == NULL || dst == NULL || arr == NULL) { return 1; }
   if (arr->l_pos <= pos || pos < 0) { return 1 ;}

   rec = arr->l_arr[pos];

   if (rec == NULL) { 
	  *dst = NULL;
	  *count = 0;
	  return 0; 
   }

   else if (rec->m_type != Typ_List && rec->m_type != Typ_Tuple) { 
	  return 1; 
   }

   else 
   {
	  str_info_t proto;
	  proto.len = 0;
	  proto.val = NULL;

	  *count = rec->l_pos;
	  if (*count <= 0 || *count > MAX_SANITY) { return 1; }
	  *dst = (str_info_t*) malloc(*count * sizeof(str_info_t));

	  for (idx = 0; idx < *count; idx++) {
		 (*dst)[idx] = proto;
		 rec_set_string(&(*dst)[idx], idx, rec);
	  }
	  
	  return 0;
   }

   assert (! "impossible case");
   return 1;
}


#ifdef WIN32
char *
basename(char *path)
{
	int i = 0;
	int p = 0;
        static char *buf = NULL;

	if (NULL == buf) {
		buf = (char *)malloc(sizeof(char) * 300);
	}

	for (i = 0; path[i] != 0; i++) {
		if (path[i] == '/' || path[i] == '\\' ) {
			p = i + 1;
		}	
        }

	for (i = 0; path[p+i] != 0; i++) {
		buf[i] = path[p+i];
	}
	buf[i] = 0;
	return buf;	
}
#endif


static void
scan_input_files (int start, int stop, char **argv)
{
   int idx;
   for (idx = start; idx < stop; idx++)
   {
       if (access(argv[idx], R_OK) < 0) {
           perror(argv[idx]);
           usage(basename(argv[0]));
           exit(2);
       }
   }
}

static int
open_options (
   char ** argv,
   int argc,
   int options[],
   FILE **outfile)
{
   int ch;

   *outfile = stdout;

   options[WANT_BOUNCE] = 1;
   options[WANT_DELV]   = 1;
   options[VERBOSE]     = 0;
   options[OUTPUT_VER]  = 2;
   options[MSOFT_CSV]   = 0;
   options[BACKWARDS_COMPAT] = 0;

   while ((ch = getopt(argc, argv, "vo:1mV:DHhB")) != -1)
   {
       switch (ch) {
           case 'm':
                   options[MSOFT_CSV] = 1;
                   break;
           case 'H':
                   options[WANT_BOUNCE] = 0;
                   break;
           case 'D':
                   options[WANT_DELV] = 0;
                   break;
           case 'v':
                   options[VERBOSE] = 1;
                   break;
           case '1': /* may not be supported */
                   options[OUTPUT_VER] = 1;
                   break;
           case 'o': 
                   if ((*outfile = fopen(optarg, "w")) == NULL) {
                       perror(optarg);
                       exit(1); 
                   }
                   break;
           case 'V':
                   options[OUTPUT_VER] = atoi(optarg);
                   break;
           case 'B':
                   options[BACKWARDS_COMPAT] = 1;
                   break;
           default:
                   usage(basename(argv[0]));
                   exit(1);
                   break;
       }
   }

   scan_input_files(optind, argc, argv);
   return optind;
}

std::ifstream *
open_next (int idx, char **argv)
{
   std::ifstream *inputStream = new std::ifstream();
   inputStream->open(argv[idx], std::ios::in | std::ios::binary);

   if (!inputStream->is_open()) {
      fprintf(stderr, "Error reading %s\n", *argv);
		delete inputStream;
		return NULL;
	}

   return inputStream;
}

static void
print_version(char *name, char *revision) 
{
    int i;
    int p = 0;
    int p2 = 0;
    char *n;
    char buf[100];

    strncpy(buf, revision, 100);

    n = basename(name);

    for (i = 0; buf[i] != 0; i++) {
        if (buf[i] == ':') {
            p2 = i+1;
        }
        if (buf[i] == '$') {
            buf[i] = ' ';
        }
    }
    
    printf("\n\t%s version %s\t\n\n", n, buf+ p2);
}


int 
main(int argc, char **argv)
{
   int idx;
   int count;
   int fd;
   int options[_N_OPTS];
   int i;
   std::ifstream *inputStream;
	
   

   outfile = stdout;
   //snprintf(version, 100, "%s version %s", argv[0], revision);   

    #if 0
   printf("we have %d args\n", argc);

  
   for (i = 0; i < argc; i++) {
       printf( "arg %d is %s\n", i, argv[i]);
   }
    #endif
    
   if (argc >= 2 && !strncmp("-version", argv[1], strlen("-version"))) {
       print_version(argv[0], revision);
       exit(0);
   }
   count = open_options (argv, argc, options, &outfile);
   //snprintf(version, 100, "%s version %s", argv[0], revision);   


   if ((argc-count) == 0) { usage(basename(argv[0])); }

   /* initial setup */
   start_report(options);

   init_dlog_library();
   cli_start_hook  = dump_start_record;
   cli_end_hook    = dump_end_record;
   cli_bounce_hook = options[WANT_BOUNCE] ? dump_bounce_record : NULL;
   cli_delv_hook   = options[WANT_DELV] ? dump_delv_record : NULL;

   for (idx = count; idx < argc; idx++) 
   {
	  inputStream = open_next(idx, argv);
     if (!inputStream) {
	  		break; 
	  }

	  else if (inputStream && !inputStream->eof()) { 
		 while (read_log_record(inputStream)) { }
	  }
	  inputStream->close();
     delete inputStream;
   }

   end_report();
   close_dlog_library();
   stk_cleanup();

   return 0;
}

