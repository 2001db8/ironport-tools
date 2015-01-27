/*
 * un_pickle.h - header file for cPickle code
 *
 * Copyright (C) 2002, IronPort Systems.  All rights reserved.
 * $Revision: 1.3 $
 */

/*
 *  The 'Un-Pickle' support library attempts to grok (sufficiently
 *  understand) the python 'Pickle' data format and reconstruct the
 *  marshalled objects into a C structure. 
 *
 *  This library does not support complex objects like objects
 *  and classes, but does support ints, longs, floats, arrays, tuples,
 *  and lists.
 *
 *  This library is used by the 'dlog_parser' program to convert
 *  IronPort Delivery logs to XML, ASCII, and other formats.
 */

#ifndef UN_PICKLE_H
#define UN_PICKLE_H

#include <sys/types.h>
#include <math.h>
#include <stdio.h>
#include <stdarg.h>
#include <assert.h>

#define PADDING_SIZE 38

typedef enum {

   /* specials */
   Typ_Marker,
   Typ_Null,
   Typ_None,
   Typ_Free,
   Typ_Alloc,

   /* strings */
   Typ_String,
   Typ_Unicode,
   Typ_UTF,

   /* numerics */
   Typ_Integer,
   Typ_Long,
   Typ_Float,
   
   /* containers */
   Typ_List,
   Typ_Dict,
   Typ_Tuple,

   Typ_Count
} stack_type_t;

#define MAGIC_ALIVE 0x0ABC0123
#define MAGIC_DEAD  0xDEADBEEF

/*
 * STACK_DATA: is used to represent the core types in python:
 *             like 'float', 'int', 'string', and 'object'; as well
 *             as internal parsing information such as
 *             marker-position, and memo-field location.
 *
 *    layout [ pos | type | UNION (float, int, class, string, list) |
 *             up | down ]
 *
 *      The 'list' data element also represents dictionaries as it
 *      supports name/value pairs.
 *
 *      pos :  memo field position, when part of the memo list.
 *      type:  data type: float, int, etc. or internal type like 'marker'
 *      data:  union of data values
 *        up:  next element towards the top of stack, or null.
 *      down:  next element away from of stack, or null.
 */
typedef struct _st_data 
{
	  unsigned m_magic;
	  stack_type_t m_type;
	  short id;

	  short m_signed;
	  /* unsigned m_in_freelist:1; */

	  union {
			double fval;
			long   ival;
			struct {int bytes; char *val; } sval;
			struct {int pos; int sz; struct _st_data **val;} lval;
			char   _padding[PADDING_SIZE]; /* debugging use */
	  } data;

	  struct _st_data* memo_next;
	  const char *dbg_info;

} stack_data_t;

int stk_copy_string(char **str, int *len, stack_data_t* src);
void stk_set_buffers(char* (*rl)(int*), char* (*rb)(int, int*));

void stk_init_library();
void stk_cleanup();

stack_data_t* parsing_stack_pop();
void print_stack();
void stk_parse_stream();

#define s_str data.sval.val
#define s_sz  data.sval.bytes

#define l_arr data.lval.val
#define l_sz  data.lval.sz
#define l_pos data.lval.pos

#endif
