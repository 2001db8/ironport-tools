/*
 * dlog_parser.h - header file for the IronPort delivery logs parser
 *
 * Copyright (C) 2002, IronPort Systems.  All rights reserved.
 * $Revision: 1.2 $
 */

#ifndef DLOG_PARSER_H
#define DLOG_PARSER_H


/*
 * This library parser IronPort DeliveryLog binary formatted mail
 * gateway logs.  A client that wishes to use the library registers
 * four functions with the library which are called back as the log
 * file is parsed.
 *
 * int start_callback (start_rec_t *rec):
 * -------------------------------------------
 * is called when a START record is encountered, see the
 * 'start_rec_t' description below.
 *
 * int end_callback (start_rec_t *rec):
 * -------------------------------------------
 * is called when an END record is encountered, see the
 * 'end_rec_t' description below.
 *
 * int delv_callback (start_rec_t *rec):
 * -------------------------------------------
 * is called when a DELIVERY record is encounterd.  (i.e. a successful
 * delivery to an external mail server was made.  See the 'delv_rec_t'
 * description below.
 *
 * int bounce_callback (start_rec_t *rec):
 * -------------------------------------------
 * is called when a HARD BOUNCE of a message is made.  The mail was
 * unable to be forwarded to another gateway and was dropped.  See the
 * 'bounce_rec_t' description below.
 *
 * The functions, above, must return '0' if the record was not
 * consumed by the client.  I.e. that the string data in the
 * 'str_info_t' was not free'd and the record itself was not free'd.
 * The '0' indicates that the library should free the record for the
 * client.
 *
 * The function 'free_dlog_record (magic, void*)' is supplied to the
 * client.  If this function is called then the client must return '1'
 * to the library to indicate that the record has been deallocated or
 * otherwise externally consumed.
 *
 * int
 * handle_start_record(start_rec_t *rec)
 * {
 *    assert(rec && rec->magic == MAGIC_START);
 *    printf ("<!-- start record -->\n");
 *    return 0;
 * }
 *
 * int
 * handle_bounce_record(start_rec_t *rec)
 * {
 *    assert(rec && rec->magic == MAGIC_BOUNCE);
 *    enqueue_record_elsewhere (rec);
 *    return 1;
 * }
 *
 * In elsewhere, 'dlog_record_free()' will be called.
 * 
 */

#define MAGIC_START  1
#define MAGIC_END    2
#define MAGIC_DELV   3
#define MAGIC_BOUNCE 4


#define BSZ 1280
#define HSZ 3000000
#define MAX_SANITY 5000
#define PBUF_SZ 16

enum {
       WANT_BOUNCE,
       WANT_DELV,
       VERBOSE,
       OUTPUT_VER,
       MSOFT_CSV,
       BACKWARDS_COMPAT,
       _N_OPTS
};


/* 'val' is null-terminated as well */
typedef struct
{
	  int   len;
	  char *val;
} str_info_t;

/* customer information consists of name,value pairs */
typedef struct
{
	  str_info_t name;
	  str_info_t value;
} cust_info_t;

/* recipient information consists of the following 3-tuple */
typedef struct
{
	  int rcpt_id;          /* id relative to current message */
	  int attempt;          /* delivery attempt */
	  str_info_t address;   /* recipient address */
} rcpt_info_t;

typedef struct 
{
	  unsigned magic;       /* always MAGIC_START */
	  unsigned log_secs;    /* logging time, seconds, in localtime */
	  unsigned log_usecs;   /* microseconds */
	  int      version;     /* library version, always '1' */
	  int      file_version;  /* file version one of [0,1,2] */
} start_rec_t;

typedef struct 
{
	  unsigned magic;       /* always MAGIC_END */
	  unsigned log_secs;    /* (see start_rec_t) */
	  unsigned log_usecs;
} end_rec_t;

typedef struct 
{
	  unsigned   magic;       /* always MAGIC_BOUNCE */
	  unsigned   log_secs;    /* (see start_rec_t) */
	  unsigned   log_usecs;
	  unsigned   entry_secs;  /* injection time */
	  unsigned   entry_usecs;
	  unsigned   bytes;       /* message bytes */
	  unsigned   mesg_id;     /* message ident */
	  unsigned   ip_addr;     /* ip address */
	  str_info_t from;        /* from header */
	  str_info_t code;        /* status code e.g. "000" */
	  str_info_t reason;      /* failure message */
	  unsigned   src_ip;	  /* source ip */
	  

	  int         n_err;      /* number of server errors returned */
	  int         n_cust;     /* number of customer info records */
	  int         n_rcpt;     /* number of recipient records */

	  str_info_t*  err_arr;   /* (see above) */
	  cust_info_t* cust_arr;  /* (see above) */
	  rcpt_info_t* rcpt_arr;  /* (see above) */

} bounce_rec_t;

typedef struct
{
	  unsigned   magic;       /* always MAGIC_DELV */
	  unsigned   log_secs;    /* (see above) */
	  unsigned   log_usecs;   /* (see above) */
	  unsigned   entry_secs;  /* (see above) */
	  unsigned   entry_usecs; /* (see above) */
	  unsigned   bytes;       /* (see above) */
	  unsigned   mesg_id;     /* (see above) */
	  unsigned   ip_addr;     /* (see above) */
	  str_info_t from;        /* (see above) */
	  str_info_t domain;      /* delivery domain */
	  unsigned   src_ip;	  /* (see above) */
	  str_info_t code;  	  /* (see above) */
	  str_info_t reply;	  /* response from remote system */

	  int         n_cust;     /* (see above) */
	  int         n_rcpt;     /* (see above) */

	  cust_info_t* cust_arr;  /* (see above) */
	  rcpt_info_t* rcpt_arr;  /* (see above) */

} delv_rec_t;


char* next_pbuf();
const char* render_time(time_t secs, time_t usecs);
const char* render_ip(unsigned ip);

void start_report(int opts[]) ;
void end_report() ;
void usage(const char *name);


#ifdef SunOS 
    typedef uint8_t  u_int8_t;
    typedef uint32_t u_int32_t;
#endif

#ifdef WIN32
    #define u_int32_t uint32_t
    #define u_int8_t  uint8_t
#endif


#endif
