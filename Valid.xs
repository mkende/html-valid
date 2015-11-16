#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#include "tidy-html5.h"
#include "html-valid-perl.c"

typedef html_valid_t * HTML__Valid;

MODULE=HTML::Valid PACKAGE=HTML::Valid

PROTOTYPES: DISABLE

HTML::Valid
html_valid_new ()
CODE:
	Newxz (RETVAL, 1, html_valid_t);
	RETVAL->n_mallocs++;
	html_valid_create (RETVAL);
OUTPUT:
	RETVAL

void
set_filename (htv, filename)
	HTML::Valid htv;
	const char * filename;
CODE:
	SetFilename (htv->tdoc, filename);

void 
run (htv, html)
	HTML::Valid htv;
	SV * html;
PREINIT:
	SV * output;
	SV * errors;
PPCODE:
	html_valid_run (htv, html, & output, & errors);
	EXTEND (SP, 2);
	SvREFCNT_inc_simple_void_NN (output);
	PUSHs (sv_2mortal (output));
	SvREFCNT_inc_simple_void_NN (errors);
	PUSHs (sv_2mortal (errors));

void
DESTROY (htv)
	HTML::Valid htv;
CODE:
	html_valid_destroy (htv);
	htv->n_mallocs--;
	if (htv->n_mallocs != 0) {
		fprintf (stderr, "%s:%d: memory leak: n_mallocs=%d\n",
			 __FILE__, __LINE__, htv->n_mallocs);
	}
	Safefree (htv);

