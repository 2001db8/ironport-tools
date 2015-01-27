/*
 * un_pickle.c - parse the Python cPickle binary format
 *
 * Copyright (C) 2002, IronPort Systems.  All rights reserved.
 * $Revision: 1.8 $
 */

#ifdef DO_MEMCHECK
#include <sys/types.h>
#include <memcheck.h>
#endif

#include <sys/types.h>
#include <math.h>
#include <stdio.h>
#include <stdarg.h>
#include <assert.h>
#include <string.h>
#include <stdlib.h>

#include "un_pickle.h"

#define FREE free
#define CALLOC(_x) calloc(1, (_x))

#ifndef NULL
#define NULL 0 
#endif

#define BF_NEW_LINE -1
#define RAISE_ERROR 1
#define STK_DEBUG 0

#if STK_DEBUG
#define REMEMBER(x,y) remember(x,y)
#else
#define REMEMBER(x,y) assert(1)
#endif


/*
 * '_st_data' or 'stack_data' represents an element on the
 * pickle format parsing stack that this library uses. Stack
 * elements may also live in a 'memo' array in some cases.
 */

void _memo_to_stk(int pos);
void _stk_to_memo(int pos);

#define MAGIC_ALIVE 0x0ABC0123
#define MAGIC_DEAD  0xDEADBEEF

void free_stack_data(stack_data_t *);

#ifndef MAX
#define MAX(x,y) x > y ? x : y
#endif

static stack_data_t** gs_head;
static int            gs_alloc_sz;
static int            gs_insert_pos;

static stack_data_t** g_memo_list;
static int            g_memo_size;
static int            g_cleanup;

static stack_data_t** g_alloc_list;
static int            g_alloc_size;
static int            g_alloc_pos;

static char* (*CLIENT_FILL_BUFFER_LINE)(int*);
static char* (*CLIENT_FILL_BUFFER)(int, int*);


int
alloc_list_next()
{
   static const int GROW_SIZE = 100;

   if (g_alloc_pos == g_alloc_size) 
   {
	  stack_data_t **tmp = NULL;
	  int idx;

	  g_alloc_size += GROW_SIZE;
	  tmp = (stack_data_t**) CALLOC(g_alloc_size * sizeof(stack_data_t**));

	  if (g_alloc_list != NULL) 
	  { 
		 for (idx = 0; idx < gs_insert_pos; idx++) { 
			tmp[idx] = g_alloc_list[idx]; 
		 }

		 FREE(g_alloc_list); 
	  }
	  g_alloc_list = tmp;
   }


   return g_alloc_pos ++;
}

void
alloc_list_clean()
{
   int idx;

   assert(g_cleanup == 1);

   for (idx = 0; idx < g_alloc_pos; idx++) {
	  free_stack_data(g_alloc_list[idx]);
   }

   if (g_alloc_list != NULL) {
	  FREE(g_alloc_list);
   }

   g_alloc_list = 0;
   g_alloc_size = 0;
   g_alloc_pos = 0;
}

void
memo_list_set(stack_data_t* elem, int pos)
{
   if (g_memo_size <= pos) 
   {
	  int idx = 0;
	  stack_data_t** n_list = 
		 (stack_data_t**) CALLOC((pos+1) * sizeof(stack_data_t**));

	  assert (n_list != NULL);
	  while (idx < g_memo_size) { 
		 n_list[idx] = g_memo_list[idx]; 
		 idx++;
	  }

	  if (g_memo_list != NULL) { FREE(g_memo_list); }

	  g_memo_list = n_list;
	  g_memo_size = pos+1;
   }

   if (g_memo_list[pos] != NULL) 
   {
	  free_stack_data(g_memo_list[pos]);
   }

   g_memo_list[pos] = elem;
}

stack_data_t*
memo_list_get(int pos)
{
   assert (pos >= 0 && pos < g_memo_size);
   return g_memo_list[pos];
}

void 
parsing_stack_push(stack_data_t* elem)
{
   const int GROW_SIZE = 100;

   if (gs_insert_pos == gs_alloc_sz) 
   {
	  stack_data_t **tmp = NULL;
	  int idx;

	  gs_alloc_sz += GROW_SIZE;
	  tmp = (stack_data_t**) CALLOC(gs_alloc_sz * sizeof(stack_data_t**));

	  if (gs_head != NULL) 
	  { 
		 for (idx = 0; idx < gs_insert_pos; idx++) { 
			tmp[idx] = gs_head[idx]; 
		 }

		 FREE(gs_head); 
	  }
	  gs_head = tmp;
   }

   gs_head[gs_insert_pos] = elem;
   gs_insert_pos++;
}

stack_data_t*
parsing_stack_pop()
{
   if (gs_insert_pos > 0) {
	  gs_insert_pos --;
	  return gs_head[gs_insert_pos];
   }
   else {
	  return NULL;
   }
}

void 
_data_append(stack_data_t* dst, stack_data_t *val)
{
   int osz, pos;

   osz =    dst->l_sz;
   pos = ++ dst->l_pos;

   if (osz < pos)
   {
	  stack_data_t **tmp, **src_arr;
	  int idx, nsz;

	  nsz = MAX(8, osz * 2);

	  tmp = (stack_data_t**) CALLOC(nsz * sizeof(stack_data_t**));
	  src_arr = dst->l_arr;

	  for (idx = 0; idx < osz; idx++) { tmp[idx] = src_arr[idx]; }
	  if (src_arr != NULL) { FREE(src_arr); }
	  dst->l_sz = nsz;
	  dst->l_arr = tmp;
   }
   
   dst->l_arr[pos-1] = val;
}

void 
stk_set_buffers(char* (*rl)(int*), char* (*rb)(int, int*))
{
   CLIENT_FILL_BUFFER_LINE = rl;
   CLIENT_FILL_BUFFER = rb;
}

void _stk_dump(int, const char *, stack_data_t *);
void remember(const char* str, stack_data_t* elem)
{
   _stk_dump(0, str, elem);
}

void
print_stack()
{
   int idx =0;
   char note[32];
   fprintf(stderr, "Dumping parse stack\n");
   fprintf(stderr, "-------------------\n");
   for (idx = 0; idx < gs_insert_pos; idx++)
   {
	  sprintf (note, " head[%d]", idx);
	  _stk_dump(0, note, gs_head[idx]);
   }
}

void
_stk_dump(int offset, const char *msg, stack_data_t *elem)
{
   const char *typ;
   int pos = 0; 

   if (offset) { fprintf (stderr, "%*c", offset, ' '); }

   fprintf (stderr, msg);
   fprintf (stderr, ": ");
   if (elem == NULL) 
   {
	  fprintf (stderr, "(null object)\n");
	  return;
   }

   switch (elem->m_type) 
   {
	  case Typ_Alloc:  typ = "(alloc)"; break;
	  case Typ_Free:   typ = "(free)"; break;
	  case Typ_Marker: typ = "MARK"; break;
	  case Typ_String: typ = "STR"; break;
	  case Typ_UTF:    typ = "UTF"; break;
	  case Typ_Unicode:typ = "UNI"; break;
	  case Typ_Integer:typ = "INT"; break;
	  case Typ_Long:   typ = "LONG"; break;
	  case Typ_Float:  typ = "FLOAT"; break;
	  case Typ_None:   typ = "NONE"; break;
	  case Typ_Null:   typ = "NIL"; break;

	  case Typ_List:   typ = "LIST"; pos = elem->l_pos; break;
	  case Typ_Dict:   typ = "DICT"; pos = elem->l_pos; break;
	  case Typ_Tuple:  typ = "TUPLE"; pos = elem->l_pos; break;
	  default:         typ = "(error)"; assert(0); break;
		 
   }

   fprintf (stderr, " [@%p] id %d typ %s arr(%d) dbg [%s] ",
			(void*)elem, elem->id, typ, pos, elem->dbg_info);

   switch (elem->m_type) 
   {
	  case Typ_String:
	  case Typ_UTF:
	  case Typ_Unicode:
	  case Typ_Long:
		 fprintf (stderr, "val = %d: {%*.*s}\n", 
				  elem->s_sz,
				  elem->s_sz,
				  elem->s_sz,
				  elem->s_str);
		 break;

	  case Typ_Integer:
		 if (elem->m_signed) fprintf (stderr, "val = %ld\n", elem->data.ival);
		 else                fprintf (stderr, "val = %lu\n", elem->data.ival);
		 break;

	  case Typ_Float:
		 fprintf (stderr, "val = %.4f\n", elem->data.fval);
		 break;


	  case Typ_Tuple:
	  case Typ_List:
	  case Typ_Dict:
	  {
		 int idx;
		 fprintf (stderr, "\n");
		 for (idx = 0; idx < elem->l_pos; idx++) {
			_stk_dump (offset + 4, "+", elem->l_arr[idx]);
		 }
		 break;
	  }

	  default:
		 fprintf (stderr, "\n");
		 break;
   }
}

/* note, 'LONG' datatype is treated as a string here, bad.  We should
 * treat that as a numeric value ... (no bignum library right now) */

int 
_stk_equals (stack_data_t *lhs, stack_data_t *rhs)
{
   if (lhs == NULL || rhs == NULL) return 0;
   if (lhs == rhs) return 1;
   if (lhs->m_type != rhs->m_type) return 0;

   switch (lhs->m_type) 
   {

	  case Typ_Marker:
	  case Typ_List:
	  case Typ_Dict:
	  case Typ_Tuple:
		 return 0;

	  case Typ_Long:
	  case Typ_String:
	  case Typ_Unicode:
	  case Typ_UTF:
		 return 
			(lhs->s_sz == rhs->s_sz) &&
			(memcmp(lhs->s_str, rhs->s_str, lhs->s_sz) == 0);
		 
	  case Typ_Null:
	  case Typ_None:
		 return 1;

	  case Typ_Integer:
		 return (lhs->data.ival == rhs->data.ival);

	  case Typ_Float:
		 return (lhs->data.fval == rhs->data.fval);

	  default:
		 assert (! "impossible stack value found in _copy_internal");
		 return 0;
   }
   
}

int  READ_OKAY;
static char *bcurr;
static int   bsz;

stack_data_t* 
parsing_data_alloc(stack_type_t typ, const char *dbg) 
{ 
   stack_data_t* ne = (stack_data_t*) CALLOC(sizeof(stack_data_t));

   ne->id = alloc_list_next();
   ne->m_magic = MAGIC_ALIVE;
   ne->m_type = typ;
   ne->m_signed = 0;
   memset(& ne->data._padding[0], 0, PADDING_SIZE);
   ne->memo_next = NULL;
   ne->dbg_info = dbg ? dbg : NULL;
   g_alloc_list[ne->id] = ne;

   REMEMBER("Allocate stack element", ne);
   return ne; 
}

void _free_data_string (stack_data_t *elem)
{
   if (elem == NULL) { return; }

   if ((elem->m_type == Typ_Long ||
		elem->m_type == Typ_String ||
		elem->m_type == Typ_Unicode ||
		elem->m_type == Typ_UTF) &&
	   (elem->s_sz != 0))
   {
	  REMEMBER ("Freeing stack string", elem);
	  assert (elem->s_sz > 0);
	  FREE(elem->s_str);
	  elem->s_str = NULL;
	  elem->s_sz = -elem->s_sz;
   }
}

void _free_data_array (stack_data_t *elem)
{
   /* using global alloc list instead of ref-counting, for now. */
   if (elem == NULL) return;

   switch (elem->m_type)
   {
	  case Typ_List:
	  case Typ_Tuple:
	  case Typ_Dict:
		 if (elem->l_arr != NULL) {
			FREE(elem->l_arr);
			elem->l_pos = elem->l_sz = 0;
			elem->l_arr = NULL;
		 }
		 break;
	  default:
		 break;
   }
}

void free_stack_data(stack_data_t *elem)
{
   if (elem == NULL) return;

   if (g_cleanup == 0) {
	  REMEMBER("free-ing element", elem);
	  return;
   }

   assert (g_cleanup == 1);
   _free_data_array(elem);
   _free_data_string(elem);
   FREE(elem);
}

/*
 * FIND_MARKER: 
 *
 *   old stack: [ A ~MARKER~ B ~MARKER~ C  D (stack-top) ]
 *   new stack: [ A ~MARKER~ B (stack-top) ]
 *   returns:   [ C D ] (and destroys ~MARKER~ element)
 */
int
parsing_stack_marker()
{
   int pos;
   int head = gs_insert_pos - 1;

   for (pos = head; pos >= 0 && gs_head[pos]->m_type != Typ_Marker; pos --) 
   { }

   return pos;
}


#if 0
#define BSZ 10000
static char *
dump_print(int len, const char *src)
{
   const char *_chr, *end;
   char tmp;
   int pos = 0;
   static char buf[BSZ];

   end = (len > BSZ) ? src + (BSZ - 1) : src + len;
   buf[0] = '\0';

   for (_chr = src; _chr != end; _chr++)
   {
	  tmp = *_chr;
	  if (tmp < 32 || tmp >= 127)
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

/* utility: duplicate the string used in a 'stack_data' struct */
char* 
_my_strdup(int bytes, char *val)
{
   char *nv;
   
   if (bytes == 0) { return NULL; }

   nv = (char*) CALLOC(bytes + 1);
   memcpy (nv, val, bytes);
   *(nv+bytes) = '\0';

   /*
   fprintf (stderr, "saving {%d} [%s]\n", bytes, dump_print(bytes, nv));
   */

   return nv;
}

int
stk_copy_string(char **str, int *len, stack_data_t* src)
{
   if (src == NULL) { return 0; }

   switch(src->m_type) {
	  case Typ_String:
	  case Typ_UTF:
	  case Typ_Unicode:
	  case Typ_Long: {
		 *len = src->s_sz;
		 *str = _my_strdup(src->s_sz, src->s_str);
		 /* *str = (char*) CALLOC(src->s_sz + 1);
		    memcpy(*str, src->s_str, src->s_sz); */
		 return 1;
	  }

	  default:
		 return 0;
   }

   assert (! "impossible");
   return 0;
}

stack_data_t* _data_dup(stack_data_t *);

void
_stk_duplicate_list(stack_data_t *dst, stack_data_t *src)
{
   int src_sz = src->l_sz,
	  src_pos = src->l_pos, idx;
   

   assert (dst->l_sz == 0);
   dst->l_sz = src_sz;
   dst->l_pos = src_pos;
   dst->l_arr = (stack_data_t**) CALLOC(src_sz * sizeof(stack_data_t**));

   for (idx = 0; idx < src_pos; idx++) {
	  dst->l_arr[idx] = _data_dup(src->l_arr[idx]);
   }
}

/* utility: duplicate a stack element (deep copy) */
stack_data_t* 
_data_dup(stack_data_t *src)
{
   stack_data_t *ne = parsing_data_alloc(Typ_Alloc, "copy");

   ne->m_type = src->m_type;
   ne->data = src->data;
   switch (src->m_type) 
   {
	  case Typ_List:
	  case Typ_Dict:
	  case Typ_Tuple:
		 _stk_duplicate_list(ne, src);
		 break;

	  case Typ_Long:
	  case Typ_String:
	  case Typ_Unicode:
	  case Typ_UTF:
		 ne->s_sz = src->s_sz;
		 ne->s_str = _my_strdup(src->s_sz, src->s_str);
		 break;
		 
	  case Typ_None:
	  case Typ_Null:
	  case Typ_Integer:
	  case Typ_Float:
	  case Typ_Marker:
		 break;

	  default:
		 assert (! "impossible stack value found in _copy_internal");
   }

   return ne;
}

/* 
 * duplicate the topmost stack element 
 */
void handle_stk_dup_top()
{
   stack_data_t *src = parsing_stack_pop();
   stack_data_t *ne  = NULL;
   
   if (src != NULL) {
	  ne = _data_dup(src);
	  parsing_stack_push(src);
	  parsing_stack_push(ne);
   }
   else { 
	  assert (! "bad duplication of stack head");
   }
}

/* 
 * adds another marker to the stack
 */
void handle_stk_insert_marker()
{
   stack_data_t *value = parsing_data_alloc(Typ_Marker, "");
   parsing_stack_push(value);
}

/* 
 * remove and free the topmost stack element 
 */
void handle_stk_pop()
{
   stack_data_t *curr = parsing_stack_pop();
   free_stack_data(curr);
}

/* 
 * remove all elements up to and including the MARKER element
 */
void handle_stk_pop_mark()
{
   int marker = parsing_stack_marker();
   int idx;

   assert(marker >= 0);

   for (idx = marker; idx < gs_insert_pos - 1; idx++) 
   {
	  free_stack_data(gs_head[idx]);
	  gs_head[idx] = NULL;
   }

   gs_insert_pos = marker;
}

/* utility: fill the data buffer with a line,int,float, etc. */
void
__fill_buffer(int sz) 
{
   if (0 && STK_DEBUG) {
	  fprintf (stderr, "reading %d bytes from buffer\n", sz);
   }

   if (sz == BF_NEW_LINE) { 
	  bcurr = CLIENT_FILL_BUFFER_LINE(&bsz); 
   }
   else { 
	  bcurr = CLIENT_FILL_BUFFER(sz, &bsz); 
   }

   if (0 && STK_DEBUG) {
	  fprintf (stderr, "buffer sz is %d bytes / {%*.*s}\n", bsz, bsz, bsz, bcurr);
   }

}

/* utility: read a string from the data buffer */
char *
__read_line(int *bytes)
{
   __fill_buffer(BF_NEW_LINE);
   *bytes = bsz;
   return bcurr;
}

/* utility: read a string of bin-width */
char *
__read_bytes(int howmany)
{
   __fill_buffer(howmany);
   return bcurr;
}

/* utility: read an integer string from the data buffer */
long
__read_line_int()
{
   long res = 0;
   __fill_buffer(BF_NEW_LINE);
   
   /* fprintf(stderr, "read-line-int {%d} %s\n", bsz, bcurr); */
   sscanf(bcurr, "%ld", &res);
   return res;
}

/* utility: read an double precision float from the data buffer */
double
__read_line_float()
{
   double res = 0;
   __fill_buffer(BF_NEW_LINE);
   sscanf(bcurr, "%lf", &res);
   return res;
}

/* utility: read a char from the data buffer */
char
__read_char()
{
   char tmp;
   __fill_buffer(1);
   tmp = *bcurr ++;
   return tmp;
}

/* utility: read a byte from the data buffer */
unsigned
__read_int8()
{
   int tmp = __read_char();

#ifdef DEBUG_BINREAD
   printf (" **** {int8} %hx\n", tmp & 0xFF); 
#endif
   return (unsigned) (tmp & 0xFF);
}

/* utility: read a 16-bit short from the data buffer */
unsigned
__read_int16()
{
   char tmp1, tmp2;
   unsigned word;
   /* to read two byte */
   /* to read a single byte */
   __fill_buffer(2);

   tmp2 = *bcurr ++;
   tmp1 = *bcurr ++;

   word = ((tmp1 & 0xFF) << 8) | (tmp2 & 0xFF);
#ifdef DEBUG_BINREAD
   printf (" **** {int16} %hx %hx = %u\n", 
	   tmp2 & 0xFF, tmp1 & 0xFF, word);
#endif

   return 0xFFFF & word;
}

/* utility: read a 32-bit short from the data buffer */
int
__read_int32()
{
   char tmp4, tmp3, tmp2, tmp1;
   int word;
   /* to read four bytes */
   __fill_buffer(4);
   tmp4 = *bcurr ++;
   tmp3 = *bcurr ++;
   tmp2 = *bcurr ++;
   tmp1 = *bcurr ++;

   word = 
	  (tmp1 & 0xFF) << 24 |
	  (tmp2 & 0xFF) << 16 | 
	  (tmp3 & 0xFF) << 8 | 
	  (tmp4 & 0xFF);

#ifdef DEBUG_BINREAD
   printf (" **** {int32} %hx %hx %hx %hx = %d\n", 
		   tmp4 & 0xFF, tmp3 & 0xFF & 0xFF, 
		   tmp2 & 0xFF, tmp1 & 0xFF, word);
#endif

   return word;
}

/* utility: read a 64-bit double from the data buffer */
double
__read_float()
{
   char tmp8, tmp7, tmp6, tmp5, tmp4, tmp3, tmp2, tmp1;
   double result;
   /* to read four bytes */
   __fill_buffer(8);
   tmp1 = *bcurr ++;
   tmp2 = *bcurr ++;
   tmp3 = *bcurr ++;
   tmp4 = *bcurr ++;
   tmp5 = *bcurr ++;
   tmp6 = *bcurr ++;
   tmp7 = *bcurr ++;
   tmp8 = *bcurr ++;

#ifdef DEBUG_BINREAD
   fprintf (stderr, "G%c%c%c%c%c%c%c", tmp1, tmp2, tmp3, tmp4, tmp5, tmp6, 
			tmp7, tmp8);
   /* exit(0); */
#endif

   {
	  unsigned fhi, flo;
	  int sign = (tmp1 >> 7) & 0x01;
	  unsigned exp  = (tmp1 & 0x7F) << 4;

	  exp |= (tmp2 >> 4) & 0x0F;
	  
	  fhi  = (tmp2 & 0x0F) << 24;
	  fhi |= (tmp3 & 0xFF) << 16;
	  fhi |= (tmp4 & 0xFF) << 8;
	  fhi |= (tmp5 & 0xFF);

	  flo  = (tmp6 & 0xFF) << 16;
	  flo |= (tmp7 & 0xFF) << 8;
	  flo |= (tmp8 & 0xFF);

	  result  = (double) fhi + ((double) flo / (double)16777216.0);
	  result /= (double) 268435456.0;
	  /* printf ("1 RESULT IS %f exp %d\n", result, exp); */

	  if (exp == 0) { exp = -1022; }
	  else { result += 1.0; exp -= 1023; }
	  /* printf ("2 RESULT IS %f exp %d\n", result, exp); */

	  result = ldexp(result, exp);
	  if (sign) { result = -result; }
	  /* printf ("3 RESULT IS %f\n", result); */
   }
#ifdef DEBUG_BINREAD
   printf ("3 RESULT IS %f\n", result); 
#endif

   return result;
}

/*
 * Insert an integer element onto the parsing stack (32-bit max)
 */
void _stk_insert_int(long res, int sgn, const char* dbg) 
{
   stack_data_t *value = parsing_data_alloc(Typ_Integer, dbg);
   value->data.ival = res;
   value->m_signed = (sgn) ? 1 : 0;
   REMEMBER("Adding int value", value);
   parsing_stack_push(value);
}

/*
 * Insert a float (double prec.) onto the parsing stack 
 */
void _stk_insert_flt(double res, const char *dbg)
{
   stack_data_t *value = parsing_data_alloc(Typ_Float, dbg);
   value->data.fval = res;
   REMEMBER("Adding float value", value);
   parsing_stack_push(value);
}

/*
 * Insert a string onto the parsing stack 
 */
void _stk_insert_str(int type, int blen, char *buf, const char *dbg)
{
   stack_data_t tmp, *nv;
   tmp.m_type = (stack_type_t)type;
   tmp.s_sz = blen;
   tmp.s_str = buf;

   nv = _data_dup(&tmp);
   nv->dbg_info = dbg;
   parsing_stack_push(nv);
}


/* ----- */

/* 
 * These parsing functions read strings and number and place their
 * elements onto the parsing stack.  These constitute the simple
 * data elements found in the pickle binary format.  These are then
 * combined into tuples, lists, and dictionaries.  Objects are 
 * represented by this library as dictionaries with special keys
 * for object name, class, parameters, etc. 
 */

/* INT */
void handle_asc_int() {
   int res = __read_line_int();

   if (bcurr[bsz-1] == 'L') {
	  _stk_insert_str(Typ_Long, bsz, bcurr, "asc-long");
   }
   else {
	  _stk_insert_int(res, 1, "asc-int");
   }
}

/* INT -> OJBECT UNSUPPORTED */
void handle_asc_persid() {
   int res = __read_line_int();
   _stk_insert_int(res, 0, "asc-persid");
}

/* INT -> OJBECT UNSUPPORTED */
void handle_bin_persid() {
   return;
}

/* FLOAT */
void handle_asc_float() {
   double res = __read_line_float();
   _stk_insert_flt(res, "asc-float");
}

/* LONG -> STRING REPR */
void handle_asc_long() {
   int len;
   char *buf = __read_line(&len);
   _stk_insert_str(Typ_Long, len-1, buf, "asc-long");
}

/* STRING */
void handle_asc_string() {
   int  len;
   char *buf = __read_line(&len);
   _stk_insert_str(Typ_String, len, buf, "asc-string");
}

/* STRING */
void handle_asc_unicode() {
   int  len;
   char *buf = __read_line(&len);
   _stk_insert_str(Typ_Unicode, len, buf, "asc-unicode");
}

/* STRING */
void handle_bin_str8() {
   int  len  = __read_int8();
   char *buf = __read_bytes(len);

   _stk_insert_str(Typ_String, len, buf, "bin-str8");
}

/* STRING */
void handle_bin_str32() {
   int   len  = __read_int32();
   char *buf = __read_bytes(len);

   _stk_insert_str(Typ_String, len, buf, "bin-str32");
}

/* STRING */
void handle_bin_utf() {
   int  len  = __read_int32();
   char *buf = __read_bytes(len);

   _stk_insert_str(Typ_UTF, len, buf, "bin-str-utf");
}

/* FLOAT */
void handle_bin_float() {
   double res = __read_float();
   _stk_insert_flt(res, "bin-float");
}

/* INT */
void handle_bin_int8() {
   unsigned res = __read_int8();
   _stk_insert_int(res, 0, "bin-int8");
}

/* INT */
void handle_bin_int16() {
   unsigned res = __read_int16();
   _stk_insert_int(res, 0, "bin-int16");
}

/* INT */
void handle_bin_int32() {
   int res = __read_int32();
   _stk_insert_int(res, 1, "bin-int32");
}

/* ----- */

/* 'None' magic object */
void handle_stk_add_none() {
   stack_data_t *value = parsing_data_alloc(Typ_None, "");
   parsing_stack_push(value);
}

/* ----- */

/* 
 * These functions manipulate the memo field used by the parsing
 * stack.  The get and put functions move an stack object to, or
 * from the memo list. 
 */

/* MEMO[id] -> STACK */
void handle_asc_get()
{
   int res = __read_line_int();
   _memo_to_stk(res);
}

/* MEMO[id] -> STACK */
void handle_bin_get8()
{
   int res = __read_int8();
   _memo_to_stk(res);
}

/* MEMO[id] -> STACK */
void handle_bin_get32()
{
   int res = __read_int32();
   _memo_to_stk(res);
}

/* STACK -> MEMO[id] */
void handle_asc_put() {
   int res = __read_line_int();
   _stk_to_memo(res);
}

/* STACK -> MEMO[id] */
void handle_bin_put8() {
   int res = __read_int8();
   _stk_to_memo(res);
}

/* STACK -> MEMO[id] */
void handle_bin_put32() {
   int res = __read_int32();
   _stk_to_memo(res);
}

/* 
 *  Move an object at position 'pos' in the memo field to the top of
 *  the parsing stack.
 */
void 
_memo_to_stk(int pos)
{
   stack_data_t *new_top = memo_list_get(pos);

   if (new_top != NULL) {
	  parsing_stack_push(new_top);
   }
}

/* 
 * Move the object from the top of the parsing stack into position
 * 'pos' in the memo field.  This implementation allows duplicates
 * in the memo field -- reusing the memo field in that way is probably
 * an error and will not be encountered in valid pickle streams.
 */
void
_stk_to_memo(int pos)
{
   stack_data_t *top = parsing_stack_pop();
   parsing_stack_push(top);
   memo_list_set(top, pos);
}

/* ----- */

/* 
 * The following function manipulate the layout of the parsing stack.
 * These functions often use the MARKER stack element to record the
 * position where items are to be coerced into tuples, lists, or
 * dictionaries.
 */

/*
 *  layout:  [ A B C ~MARKER~ D E F G (stack-top) ]
 *
 *  new layout: [ A B C ~LIST(D E F G)~ (stack-top) ]
 */
void
handle_stk_to_list()
{
   int idx;
   int marker = parsing_stack_marker();
   stack_data_t *ne = parsing_data_alloc(Typ_List, "stk-to-list");

   for (idx = marker+1; idx < gs_insert_pos; idx++) {
	  _data_append(ne, gs_head[idx]);
	  gs_head[idx] = NULL;
   }

   free_stack_data(gs_head[marker]);
   gs_head[marker] = NULL;
   gs_insert_pos = marker;
   
   REMEMBER("new_list_elem", ne);
   parsing_stack_push(ne);
}

/*
 *  layout:  [ A B C ~MARKER~ D E F G (stack-top) ]
 *
 *  new layout: [ A B C ~TUPLE(D E F G)~ (stack-top) ]
 */
void
handle_stk_to_tuple()
{
   stack_data_t * top;

   handle_stk_to_list();
   top = parsing_stack_pop();
   top->m_type = Typ_Tuple;
   parsing_stack_push(top);
}

/*
 *  layout:  [ A B C (stack-top) ]
 *
 *  new layout:  [ A B C ~LIST()~ (stack-top) ]
 */
void
handle_stk_to_empty_list()
{
   stack_data_t *ne = parsing_data_alloc(Typ_List, "empty-list");
   parsing_stack_push(ne);
}

/*
 *  layout:  [ A B C (stack-top) ]
 *
 *  new layout:  [ A B C ~TUPLE()~ (stack-top) ]
 */
void
handle_stk_to_empty_tuple()
{
   stack_data_t *ne = parsing_data_alloc(Typ_Tuple, "empty-tuple");
   parsing_stack_push(ne);
}

/*
 *  layout:  [ A B C (stack-top) ]
 *
 *  new layout:  [ A B C ~DICTIONARY()~ (stack-top) ]
 */
void
handle_stk_to_empty_dict()
{
   stack_data_t *ne = parsing_data_alloc(Typ_Dict, "empty-dict");
   parsing_stack_push(ne);
}

/* utility: find 'key' of key/value pair in src data array */
int
_data_key_find(stack_data_t *src, stack_data_t *key)
{
   int olen = src->l_pos;
   int idx;

   for (idx = 0; idx < (olen-1); idx += 2) {
	  if (_stk_equals(src->l_arr[idx], key) == 1) {
		 return idx;
	  }
   }

   return -1;
}

/* utility: add stack elements (key, val) to a dictionary */
void
_data_set(stack_data_t *dst, stack_data_t *key, stack_data_t *val) 
{
   int idx = _data_key_find(dst, key);

   if (idx >= 0) {
	  stack_data_t *tmp = dst->l_arr[idx+1];
	  dst->l_arr[idx+1] = val;
	  free_stack_data (tmp);
   }

   else {
	  _data_append(dst, key);
	  _data_append(dst, val);
   }
}

/*
 *  layout:  [ A B C ~LIST(D)~ E (stack-top) ]
 *
 *  new layout:  [ A B C ~LIST(D E)~ (stack-top) ]
 */
void
handle_stk_list_add()
{
   stack_data_t *item = parsing_stack_pop();
   stack_data_t *list = parsing_stack_pop();

   _data_append(list, item);
   parsing_stack_push(list);
}

/*
 *  layout:  [ A B C ~LIST(D)~ ~MARKER~ E F G H (stack-top) ]
 *
 *  new layout:  [ A B C ~LIST(D E F G H)~ (stack-top) ]
 */
void
handle_stk_list_add_many()
{
   int idx;
   int marker = parsing_stack_marker();
   stack_data_t *tmp = gs_head[marker - 1];

   for (idx = marker+1; idx < gs_insert_pos; idx++) {
	  _data_append(tmp, gs_head[idx]);
	  gs_head[idx] = NULL;
   }

   free_stack_data (gs_head[marker]);
   gs_head[marker] = NULL;
   gs_insert_pos = marker;

   REMEMBER("List append many: ", gs_head[marker - 1]);
}

/*
 *  layout:  [ A B C ~MARKER~ D E F G (stack-top) ]
 *
 *  new layout:  [ A B C ~DICT(D => E, F => G)~ (stack-top) ]
 */
void
handle_stk_to_dict()
{
   int idx;
   int marker = parsing_stack_marker();
   stack_data_t *ne = parsing_data_alloc(Typ_Dict, "stk-to-dict");

   print_stack();
   REMEMBER("HERE", NULL);

   for (idx = marker+1; idx < gs_insert_pos; idx++) {
	  _data_append(ne, gs_head[idx]);
	  gs_head[idx] = NULL;
   }

   free_stack_data(gs_head[marker]);
   gs_head[marker] = NULL;
   gs_insert_pos = marker;

   REMEMBER("New dict: ", ne);
   parsing_stack_push(ne);
}

/*
 *  layout:  [ A B C ~DICT()~ E F (stack-top) ]
 *
 *  new layout:  [ A B C ~DICT(E => F)~ (stack-top) ]
 */
void
handle_stk_dict_set()
{
   stack_data_t *val  = parsing_stack_pop();
   stack_data_t *key  = parsing_stack_pop();
   stack_data_t *head = parsing_stack_pop();

   REMEMBER("Dict set: ", head);
   REMEMBER(" . key ", key);
   REMEMBER(" . val with ", val);

   _data_append(head, key);
   _data_append(head, val);
   parsing_stack_push(head);
}

/*
 *  layout:  [ A B C ~DICT()~ ~MARKER~ E F G H (stack-top) ]
 *
 *  new layout:  [ A B C ~DICT(E => F, G => H)~ (stack-top) ]
 */
void
handle_stk_dict_set_many()
{
   int idx;
   int marker = parsing_stack_marker();
   stack_data_t *tmp = gs_head[marker - 1];
   
   for (idx = marker+1; idx < gs_insert_pos; idx++) {
	  _data_append(tmp, gs_head[idx]);
	  gs_head[idx] = NULL;
   }

   free_stack_data(gs_head[marker]);
   gs_head[marker] = NULL;
   gs_insert_pos = marker;
}

void handle_excep()          { READ_OKAY = 0; }
void handle_parse_error()    { READ_OKAY = 0; }
void handle_parse_done()     { READ_OKAY = 0; }
int _check_parsing_state()   { return READ_OKAY == 1; }

const char*
_str_map(char _chr)
{
   switch (_chr) 
   {
	  case '(': return "~Marker";
	  case 'N': return "~None";
	  case '.': return "[op] stop_parsing";
	  case '0': return "[op] pop";
	  case '1': return "[op] pop-to-mark";
	  case '2': return "[op] dup-stack-top";
	  case 'I': return "asc-int";
	  case 'K': return "bin-int(8)";
	  case 'M': return "bin-int(16)";
	  case 'J': return "bin-int(32)";
	  case 'L': return "asc-long";
	  case 'F': return "asc-float";
	  case 'G': return "bin-float(64)";
	  case 'S': return "asc-string";
	  case 'V': return "asc-unicode";
	  case 'U': return "bin-string(8)";
	  case 'T': return "bin-string(32)";
	  case 'X': return "bin-utf(32)";
	  case 'P': return "~USSPT~ asc-persid";
	  case 'Q': return "~USSPT~ bin-persid";
	  case 'g': return "asc-get";
	  case 'h': return "bin-get(8)";
	  case 'j': return "bin-get(32)";
	  case 'p': return "asc-put";
	  case 'q': return "bin-put(8)";
	  case 'r': return "bin-put(32)";

	  case 'l': return "[op] stk-to-list";
	  case 't': return "[op] stk-to-tuple";
	  case 'd': return "[op] stk-to-dict";
	  case '}': return "empty-dict";
	  case ']': return "empty-list";
	  case ')': return "empty-tuple";
	  case 'a': return "[op] list-add";
	  case 'e': return "[op] list-add-many";
	  case 's': return "[op] dict-set";
	  case 'u': return "[op] dict-set-many";

	  case 'R': return "~USSPT~ [op] reduce";
	  case 'c': return "~USSPT~ read-global-cls";
	  case 'b': return "~USSPT~ read-build-obj";
	  case 'o': return "~USSPT~ read-obj";
	  case 'i': return "~USSPT~ read-inst";

	  case '\0': return "[err] NULL";
	  default:   return "[err] unknown-key";
   }

   assert (! "impossible case");
   return "BAD";
}

/* main switch for reading the pickle stream */
int
stk_parse_item()
{
   char _chr = __read_char();

   if (STK_DEBUG) {
	  fprintf (stderr, "Reading in type character: %c\n", _chr);
	  fprintf (stderr, "  . mapping to %s\n", _str_map(_chr));
   }

   switch (_chr) 
   {
	  case '.': handle_excep(); break;
	  case '(': handle_stk_insert_marker(); break; /* done */
	  case '0': handle_stk_pop(); break;           /* done */
	  case '1': handle_stk_pop_mark(); break;      /* done */
	  case '2': handle_stk_dup_top(); break;       /* done */
	  case 'N': handle_stk_add_none(); break;      /* done */

	  case 'I': handle_asc_int(); break;     /* done */
	  case 'K': handle_bin_int8(); break;    /* done */
	  case 'M': handle_bin_int16(); break;   /* done */
	  case 'J': handle_bin_int32(); break;   /* done */
	  case 'L': handle_asc_long(); break;    /* done */
	  case 'F': handle_asc_float(); break;   /* done */
	  case 'G': handle_bin_float(); break;   /* done */

	  case 'S': handle_asc_string();  break;    /* done */
	  case 'V': handle_asc_unicode(); break; /* done */
	  case 'U': handle_bin_str8();  break;   /* done */
	  case 'T': handle_bin_str32(); break;   /* done */
	  case 'X': handle_bin_utf();  break;    /* done */

	  case 'P': handle_asc_persid(); break;  /* done, partial */
	  case 'Q': handle_bin_persid(); break;  /* done, partial */

	  case 'g': handle_asc_get(); break;     /* done */
	  case 'h': handle_bin_get8(); break;    /* done */
	  case 'j': handle_bin_get32(); break;   /* done */

	  case 'p': handle_asc_put(); break;     /* done */
	  case 'q': handle_bin_put8(); break;    /* done */
	  case 'r': handle_bin_put32(); break;   /* done */

	  case 'l': handle_stk_to_list(); break;        /* done */
	  case 't': handle_stk_to_tuple(); break;       /* done */
	  case '}': handle_stk_to_empty_dict(); break;  /* done */
	  case ']': handle_stk_to_empty_list(); break;  /* done */
	  case ')': handle_stk_to_empty_tuple(); break; /* done */
	  case 'a': handle_stk_list_add(); break;       /* done */
	  case 'e': handle_stk_list_add_many(); break;  /* done */
	  case 'd': handle_stk_to_dict(); break;        /* done */
	  case 's': handle_stk_dict_set(); break;       /* done */
	  case 'u': handle_stk_dict_set_many(); break;  /* done */
	  case '\0': handle_parse_done(); break;

/* 	  case 'R': _stk_reduce(); break; */
/* 	  case 'c': _read_global_cls(); break; */
/* 	  case 'b': _read_build_obj(); break; */
/* 	  case 'o': _read_obj(); break; */
/* 	  case 'i': _read_inst(); break; */

	  default: handle_parse_error(); break;
   }

   return _check_parsing_state();
}

void
stk_parse_stream()
{
   while (stk_parse_item()) { }
}

void stk_cleanup()
{
  if (STK_DEBUG) {
	 fprintf (stderr, "MEMO SIZE is %d\n", g_memo_size);
	 fprintf (stderr, "STACK SIZE is %d\n", gs_alloc_sz);
  }

   if (gs_head != NULL) { 
	  FREE(gs_head);
	  gs_head = NULL;
   }

   if (g_memo_list != NULL) {
	  FREE(g_memo_list);
	  g_memo_list = NULL;
   }

   g_cleanup = 1;
   alloc_list_clean();
}

void stk_init_library()
{
   g_cleanup = 0;
   gs_head = NULL;
   gs_alloc_sz = 0;
   gs_insert_pos = 0;
   g_memo_list = NULL;
   g_memo_size = 0;
   READ_OKAY = 1;
}


#ifdef SELF_TEST

int pack_1(char* buf, char _chr) { buf[0] = _chr; return 1; }

int pack_2(char* buf, int word) { 
   buf[0] = (word >> 8) & 0xFF;
   buf[1] = (word) & 0xFF;
   return 2;
}

int pack_4(char* buf, int word) { 
   buf[0] = (word >> 24) & 0xFF;
   buf[1] = (word >> 16) & 0xFF;
   buf[2] = (word >> 8) & 0xFF;
   buf[3] = (word) & 0xFF;
   return 4;
}

int pack_2net(char* buf, int word) 
{
   buf[1] = (word >> 8) & 0xFF;
   buf[0] = (word) & 0xFF;
   return 2;
}

int pack_4net(char* buf, int word) 
{
   buf[3] = (word >> 24) & 0xFF;
   buf[2] = (word >> 16) & 0xFF;
   buf[1] = (word >> 8) & 0xFF;
   buf[0] = (word) & 0xFF;
   return 4;
}

char test_buf[1024];
int  offset;
int  E_O_BUF;

int
pack(char *buf, const char *format, ...)
{
   va_list ap;
   int bpos = 0;
   char ofm = '\0';

   va_start(ap, format);
   
   while (*format) 
   {
	  switch (*format++)
	  {
		 case 'C':
		 case 'a': 
			ofm = 'a'; 
			bpos += pack_1(buf+bpos, va_arg(ap, int)); 
			break;

		 case 's': 
			ofm = 's'; 
			bpos += pack_2(buf+bpos, va_arg(ap, int)); 
			break;

		 case 'n': 
			ofm = 'n'; 
			bpos += pack_2net(buf+bpos, va_arg(ap, int)); 
			break;

		 case 'N': 
			ofm = 'N'; 
			bpos += pack_4net(buf+bpos, va_arg(ap, int)); 
			break;

		 case '0':
		 case '1':
		 case '2':
		 case '3':
		 case '4':
		 case '5':
		 case '6':
		 case '7':
		 case '8':
		 case '9': 
		 {
			int idx, val, pos, tint;
			char tchr;

			format --;
			pos = sscanf(format, "%d", &val);

			/* printf ("READING %d formats [%c] \n", val, ofm); */
			format += pos;

			for (idx = 1; idx < val; idx++) 
			{
			   if (ofm == 'a') { 
				  tchr = va_arg(ap, int);
				  bpos += pack_1(buf+bpos, tchr);
			   }
			   else if (ofm == 's') { 
				  tint = va_arg(ap, int);
				  bpos += pack_2(buf+bpos, tint);
			   }
			   else if (ofm == 'n') {
				  tint = va_arg(ap, int);
				  bpos += pack_2net(buf+bpos, tint);
			   }
			   else if (ofm == 'N') {
				  tint = va_arg(ap, int);
				  bpos += pack_4net(buf+bpos, tint);
			   }
			}
			
			break;
		 }

		 default:
			va_end(ap);
			assert (! "unknown format char");
			return bpos;
			
	  }
   }

   va_end(ap);

   E_O_BUF += bpos;
   return bpos;
}

char* my_fill_line (int *bsz)
{
   int spos = offset;

   while ( test_buf[spos] != '\n' && spos != E_O_BUF)
	  spos ++;

   if (spos == E_O_BUF) { 
	  *bsz = E_O_BUF - offset;
	  return &test_buf[offset];
   }
   else {
	  int opos = offset;
	  *bsz = spos - opos;
	  offset = spos;
	  test_buf[offset] = '\0';
	  offset ++;
	  return &test_buf[opos];
   }
				  
}

char* my_fill (int sz, int *bsz)
{
   int start = offset;
   if (sz > (1024 - offset)) {
	  *bsz = 0;
	  return NULL;
   }
   else {
	  *bsz = sz;
	  offset += sz;

	  return  & test_buf[start];
   }
}

void check_item(char typ, ...)
{
   stack_data_t *stack_head = parsing_stack_pop();

   va_list ap;
   va_start(ap, typ);

   REMEMBER ("CHECKING", stack_head);

   switch (typ)
   {
	  case 'I': {
		 int _v = va_arg(ap, int);
		 assert (stack_head->m_type == Typ_Integer);

		 fprintf (stderr, "Checking %ld against INT %d\n", 
				  stack_head->data.ival, _v);
		 assert (stack_head->data.ival == _v);
		 break;
	  }
		 
	  case 'S': {
		 int len = va_arg(ap, int);
		 char *ptr = va_arg(ap, char*);
		 assert (stack_head->m_type == Typ_String);
		 assert (stack_head->s_sz == len);

		 fprintf (stderr, "Checking against STR %*.*s\n", len, len, ptr);
		 fprintf (stderr, " . TUP has %d %*.*s\n",
				  stack_head->s_sz,
				  stack_head->s_sz,
				  stack_head->s_sz,
				  stack_head->s_str);
		 
		 assert (memcmp(stack_head->s_str, ptr, len) == 0);
		 break;
	  }

	  case 'F': {
		 double _a = stack_head->data.fval + 0.0005;
		 double _b = stack_head->data.fval - 0.0005;
		 double _c = va_arg(ap, double);

		 fprintf (stderr, "Checking against %.6f vs %.6f\n", 
				  stack_head->data.fval, _c);
		 assert (_c < _a && _c > _b); 
		 break;
	  }

	  case 'A': {
		 assert (stack_head->m_type == Typ_List ||
				 stack_head->m_type == Typ_Tuple);
		 break;
	  }

	  case 'M': {
		 assert (stack_head->m_type == Typ_Marker);
		 break;
	  }

	  default:
		 break;
   }
   va_end(ap);

   free_stack_data(stack_head);
}

void test_1a()
{
   int sz;
   const char *str1 = "I123456\nI23\nI12\n";
   sz = sprintf(test_buf, str1);
   E_O_BUF = sz;
   stk_parse_item();
   stk_parse_item();
   stk_parse_item();

   print_stack();
   check_item ('I', 12);
   check_item ('I', 23);
   check_item ('I', 123456);
}

void test_1b()
{
   const char *fmt = "aNanaCaC";

   pack(test_buf, fmt, 
		'J', 12345,     /* J 30 39 00 00 */
		'M', 123,       /* M 7b 00 */
		'K', 12,        /* K 00 0C */
		'K', 255);      /* K 00 FF */

   stk_parse_item();
   stk_parse_item();
   stk_parse_item();
   stk_parse_item();

   print_stack();
   check_item ('I', 255);
   check_item ('I', 12);
   check_item ('I', 123);
   check_item ('I', 12345);
}

void test_1b2()
{
   const char *fmt = "aNanaCaC";

   pack(test_buf, fmt, 
		'J', -1,     /* J 30 39 00 00 */
		'M', -100,   /* M 7b 00 */
		'K', -8,     /* K 00 0C */
		'K', -125);  /* K 00 FF */

   stk_parse_item();
   stk_parse_item();
   stk_parse_item();
   stk_parse_item();

   print_stack();
/*
   check_item ('I', 255);
   check_item ('I', 12);
   check_item ('I', 123);
   check_item ('I', 12345);
*/
}

void test_1c()
{
   int pos = 0;
   const char *str = "F12.232432234\n";
   const char *fmt = "n9";

   pos = sprintf(test_buf, str);
   pos += pack (test_buf + pos, fmt,
			   0x3f47, 0xaef3, 0x7a14,   /*G {1.230} */
			   0x47e1, 0x47ae, 0x5e40,   /*G {123.0} */
			   0x00c0, 0x0000, 0x0000);     
   
   pos += sprintf(test_buf + pos, str);
   E_O_BUF = pos;

   stk_parse_item();
   stk_parse_item();
   stk_parse_item();
   stk_parse_item();

   print_stack();
   check_item ('F', (double)12.232432234);
   check_item ('F', (double)123.0);
   check_item ('F', (double)1.23);
   check_item ('F', (double)12.232432234);
		 
}

void test_2a()
{
   int pos = 0;
   /*   Place three ints on stack, and reverse them ... */
   
   const char *three_ints = "I123456\nI23\nI12\n";
   const char *put_fmt  = "p0\n0p1\n0p2\n0";
   const char *get_fmt  = "g0\ng1\ng2\n";
   /* const char *put_fmt  = "aCaaNa";
	  const char *get_fmt  = "aCaN"; */

   /* stack: [ 123456   123    12  (top) ]  */

   pos = sprintf (test_buf, three_ints);
   pos += sprintf (test_buf+pos, put_fmt);
   pos += sprintf (test_buf+pos, get_fmt);
   E_O_BUF = pos;

   /* place elems */
   stk_parse_item();
   stk_parse_item();
   stk_parse_item();

   /* move to memo */
   stk_parse_item();
   stk_parse_item();
   stk_parse_item();
   stk_parse_item();
   stk_parse_item();
   stk_parse_item();

   /* return to stack */
   stk_parse_item();
   stk_parse_item();
   stk_parse_item();

   /* stack: [ 12  123  123456 (top) ]  */
   print_stack();
   check_item ('I', 123456);
   check_item ('I', 23);
   check_item ('I', 12);
}

void test_3a()
{
   int pos = 0;
   
   const char *t1 = "I0\n22(I12\n22222";
   pos = sprintf (test_buf, t1);
   E_O_BUF = pos;
   stk_parse_stream();

   print_stack();
   check_item ('I', 12);
   check_item ('I', 12);
   check_item ('I', 12);
   check_item ('I', 12);
   check_item ('I', 12);
   check_item ('I', 12);
   check_item ('M');
   check_item ('I', 0);
   check_item ('I', 0);
   check_item ('I', 0);
}

void test_3b()
{
   int pos = 0;
   
   const char *t2 = "I0\n22(I12\n222221";
   pos = sprintf (test_buf, t2);
   stk_parse_stream();

   print_stack();
   check_item ('I', 0);
   check_item ('I', 0);
   check_item ('I', 0);
}

void test_3c()
{
   int pos = 0;
   
   const char *t1 = "I0\n(I1\n222l";
   const char *t2 = "I2\n(I3\n222t";
   pos = sprintf (test_buf, t1);
   pos += sprintf (test_buf+pos, t2);
   E_O_BUF = pos;
   stk_parse_stream();

   print_stack();
   check_item ('A');
   check_item ('I', 2);
   check_item ('A');
   check_item ('I', 0);
}

void test_3d()
{
   int pos = 0;
   
   const char *t1 = "Sbottom\n(Skey1\nSvalue1\nSkey2\nSvalue2\nd";
   pos = sprintf (test_buf, t1);
   E_O_BUF = pos;
   stk_parse_stream();
   stk_parse_stream();

   print_stack();
}


void test_3e()
{
   int pos = 0;
   
   const char *t1 = "}Skey1\nSvalue1\ns";
   const char *t2 = "}(Skey2\nSvalue2\nSkey3\nSvalue3\nu";
   pos = sprintf (test_buf, t1);
   pos += sprintf (test_buf+pos, t2);
   E_O_BUF = pos;
   stk_parse_stream();
   print_stack();
}

void test_neg_112()
{
   stack_data_t *stack_head;
   pack(test_buf, "n3", 
		0x904a,  
		0xffff, 
		0x00ff); /* J 220 377 377 377 */

   stk_parse_stream();
   stack_head = parsing_stack_pop();

   print_stack();
   stack_head->m_signed = 0;
   parsing_stack_push(stack_head);
   print_stack();
   
}

void test_int_huge()
{
   E_O_BUF = sprintf (test_buf, "I429496718412312L\nI-429496718412312L");
   stk_parse_stream();
   print_stack();
}

void sample_1()
{
   pack(test_buf, "n66",
		0x4a28, 0x8890, 0x3db4, 0x934d, 0x4d50, 0x0387, 0x324d, 0x4b26,
		0x5500, 0x751b, 0x6573, 0x3172, 0x3332, 0x7740, 0x6d75, 0x7570,
		0x2e73, 0x7269, 0x6e6f, 0x6f70, 0x7472, 0x632e, 0x6d6f, 0x0171,
		0x1c55, 0x2e35, 0x2e31, 0x2032, 0x202d, 0x6142, 0x2064, 0x6564,
		0x7473, 0x6e69, 0x7461, 0x6f69, 0x206e, 0x6f68, 0x7473, 0x0271,
		0x0355, 0x3030, 0x7130, 0x5d03, 0x0471, 0x715d, 0x2805, 0x004b,
		0x1855, 0x3639, 0x3635, 0x7740, 0x6d75, 0x7570, 0x2e73, 0x7269,
		0x6e6f, 0x6f70, 0x7472, 0x632e, 0x6d6f, 0x0671, 0x004b, 0x6174,
		0x7174, 0x2e07);

   stk_parse_stream();
   print_stack();
}


typedef void (*test_fn_t)();

void 
run_test(test_fn_t tst, const char *fmt, ...)
{
   va_list ap;

   offset = 0;
   memset(test_buf, 0, 1024);
   E_O_BUF = 0;
   stk_init_library();

   va_start(ap, fmt);
   vfprintf (stderr, fmt, ap);
   va_end(ap);
   fprintf (stderr, "\n--------------------\n");
   tst();
   stk_cleanup();
}

const char* ALL_TESTS_DESCR[] = { 
   "Test asc integers",
   "Test bin integers",
   "Test bin integers, negative conversions",
   "Test floating points",

   "Test put and get",

   "Test stack dup",
   "Test stack pop-till-mark",
   "Test stack-to-list, stack-to-tuple",
   "Test stack-to-dict",
   "Test stack-dict-add, stack-dict-add-many",

   "Test neg 112",
   "Test huge integer values",
   "sample input #1",
   NULL
};

test_fn_t ALL_TESTS[] = { 
   test_1a, 
   test_1b, 
   test_1b2, 
   test_1c,

   test_2a,

   test_3a, 
   test_3b, 
   test_3c,
   test_3d,
   test_3e,
   
   test_neg_112,
   test_int_huge,
   sample_1,
   NULL
};

int NUM_TESTS = (sizeof(ALL_TESTS) / sizeof(test_fn_t)) - 1;

#include <unistd.h>
#include <errno.h>

int 
which_test(int argc, char ** argv)
{
   int pos = 0;
   int ch = getopt(argc, argv, "at:");

   if (ch == 'a') {
	  return -1;
   }
   if (ch == 't') {
	  char* tmp = NULL;
	  int res = (int) strtol(optarg, &tmp, 10);

	  if (*tmp != '\0' || res < 0 || res >= NUM_TESTS) 
	  { 
		 goto error; 
	  }

	  return res;
   }

  error:
	  fprintf (stderr, "usage: test_program (-t num | -all)\n");
	  for (pos = 0; pos < NUM_TESTS; pos++) {
		 fprintf (stderr, 
				  "  . test %d => %s\n", 
				  pos, ALL_TESTS_DESCR[pos]);
	  }
	  exit(0);
	  return 0;
}

int 
main(int argc, char **argv)
{

   int tst = which_test(argc, argv);

   stk_set_buffers(my_fill_line, my_fill);

   if (tst >= 0) {
	  run_test(ALL_TESTS[tst], ALL_TESTS_DESCR[tst]);
   }
   else {
	  tst = 0;
	  while (tst != NUM_TESTS) {
		 run_test(ALL_TESTS[tst], ALL_TESTS_DESCR[tst]);
		 tst++;
	  }
   }

   fprintf (stderr, "\nDon't forget to check 'memcheck.log' for errors: ");
   fprintf (stderr, "a single 'never-freed' entry is okay.\n");

   return 0;
}

#endif
