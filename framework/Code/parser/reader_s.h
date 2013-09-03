#ifndef _READER_H_
#define _READER_H_

#include "reader_g.tab.h"

typedef struct _Scanner {
	/* Scanner state. */
    NSInteger cs;
    NSInteger act;
    NSInteger have;
    NSInteger curline;
    char *tokstart;
    char *tokend;
    char *p;
    char *pe;

	/* Token data */
	char *data;
	NSInteger len;
    NSInteger token;
	char *token_name;
	char *buf;
	
} Scanner;


#define TK_NO_TOKEN (-1)

#endif /* _READER_H_ */
