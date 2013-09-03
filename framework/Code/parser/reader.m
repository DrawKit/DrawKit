#line 1 "reader.rl"
#include "reader_s.h"
#include <stdio.h>
#include <string.h>

#ifndef SCOPE
#define SCOPE
#endif


	#line 79 "reader.rl"

SCOPE void scan_init_buf( Scanner *s, char *buf );
SCOPE NSInteger scan( Scanner *s );
SCOPE void scan_finalize(Scanner *s);



#line 16 "reader.m"
static const NSInteger Scanner_start = 22;

static const NSInteger Scanner_first_final = 22;

static const NSInteger Scanner_error = 0;

#line 84 "reader.rl"



SCOPE void scan_init_buf( Scanner *s, char *buf )
{
#warning 64BIT: Inspect use of sizeof
	bzero (s, sizeof(Scanner));
	s->curline = 1;
	s->buf = buf;
	s->p = s->buf;
	
#line 34 "reader.m"
	{
	 s->cs = Scanner_start;
	 s->tokstart = 0;
	 s->tokend = 0;
	 s->act = 0;
	}
#line 93 "reader.rl"

}

SCOPE void scan_finalize( Scanner *s )
{
	#pragma unused(s)
}

#define ret_tok( _tok ) token = _tok; s->data = s->tokstart; s->token_name = #_tok
#define ret_char( _tok ) token = _tok; s->data = s->tokstart; s->token_name = "TK_Char"

SCOPE NSInteger scan( Scanner *s )
{
	char *p = s->p;
	char *pe = s->pe;
	NSInteger token = TK_NO_TOKEN;

	while ( 1 ) {

		
#line 61 "reader.m"
	{
	if ( p == pe )
		goto _out;
	switch (  s->cs )
	{
tr1:
#line 43 "reader.rl"
	{ s->tokend = p+1;{ ret_tok (TK_String); {{p = (( s->tokend))-1;}goto _out22;} }{p = (( s->tokend))-1;}}
	goto st22;
tr4:
#line 42 "reader.rl"
	{ s->tokend = p+1;{ ret_tok (TK_String); {{p = (( s->tokend))-1;}goto _out22;} }{p = (( s->tokend))-1;}}
	goto st22;
tr7:
#line 14 "reader.rl"
	{s->curline += 1;}
#line 64 "reader.rl"
	{ s->tokend = p+1;{p = (( s->tokend))-1;}}
	goto st22;
tr8:
#line 1 "reader.rl"
	{	switch(  s->act ) {
	case 7:
	{	ret_tok (TK_Integer); {{p = (( s->tokend))-1;}goto _out22;} }
	break;
	case 9:
	{ ret_tok (TK_Integer); {{p = (( s->tokend))-1;}goto _out22;} }
	break;
	default: break;
	}
	{p = (( s->tokend))-1;}}
	goto st22;
tr12:
#line 55 "reader.rl"
	{{ ret_tok (TK_Integer); {{p = (( s->tokend))-1;}goto _out22;} }{p = (( s->tokend))-1;}}
	goto st22;
tr14:
#line 57 "reader.rl"
	{{ ret_tok (TK_Real); {{p = (( s->tokend))-1;}goto _out22;} }{p = (( s->tokend))-1;}}
	goto st22;
tr19:
#line 51 "reader.rl"
	{{	ret_tok (TK_Integer); {{p = (( s->tokend))-1;}goto _out22;} }{p = (( s->tokend))-1;}}
	goto st22;
tr21:
#line 53 "reader.rl"
	{{ ret_tok (TK_Real); {{p = (( s->tokend))-1;}goto _out22;} }{p = (( s->tokend))-1;}}
	goto st22;
tr31:
#line 75 "reader.rl"
	{ s->tokend = p+1;{ ret_char( *p ); {{p = (( s->tokend))-1;}goto _out22;} }{p = (( s->tokend))-1;}}
	goto st22;
tr32:
#line 71 "reader.rl"
	{ s->tokend = p+1;{ ret_tok( TK_EOF ); {{p = (( s->tokend))-1;}goto _out22;} }{p = (( s->tokend))-1;}}
	goto st22;
tr33:
#line 46 "reader.rl"
	{ s->tokend = p+1;{p = (( s->tokend))-1;}}
	goto st22;
tr34:
#line 14 "reader.rl"
	{s->curline += 1;}
#line 22 "reader.rl"
	{ s->tokend = p+1;{p = (( s->tokend))-1;}}
	goto st22;
tr41:
#line 75 "reader.rl"
	{ s->tokend = p;{ ret_char( *p ); {{p = (( s->tokend))-1;}goto _out22;} }{p = (( s->tokend))-1;}}
	goto st22;
tr42:
#line 66 "reader.rl"
	{ s->tokend = p+1;{ {{p = (( s->tokend))-1;}{goto st20;}} }{p = (( s->tokend))-1;}}
	goto st22;
tr43:
#line 51 "reader.rl"
	{ s->tokend = p;{	ret_tok (TK_Integer); {{p = (( s->tokend))-1;}goto _out22;} }{p = (( s->tokend))-1;}}
	goto st22;
tr49:
#line 55 "reader.rl"
	{ s->tokend = p;{ ret_tok (TK_Integer); {{p = (( s->tokend))-1;}goto _out22;} }{p = (( s->tokend))-1;}}
	goto st22;
tr52:
#line 57 "reader.rl"
	{ s->tokend = p;{ ret_tok (TK_Real); {{p = (( s->tokend))-1;}goto _out22;} }{p = (( s->tokend))-1;}}
	goto st22;
tr54:
#line 53 "reader.rl"
	{ s->tokend = p;{ ret_tok (TK_Real); {{p = (( s->tokend))-1;}goto _out22;} }{p = (( s->tokend))-1;}}
	goto st22;
tr58:
#line 59 "reader.rl"
	{ s->tokend = p;{ ret_tok (TK_Hex); {{p = (( s->tokend))-1;}goto _out22;} }{p = (( s->tokend))-1;}}
	goto st22;
tr59:
#line 34 "reader.rl"
	{ s->tokend = p;{ ret_tok( TK_Identifier ); {{p = (( s->tokend))-1;}goto _out22;} }{p = (( s->tokend))-1;}}
	goto st22;
tr60:
#line 37 "reader.rl"
	{ s->tokend = p+1;{
			ret_tok (TK_Keyword); {{p = (( s->tokend))-1;}goto _out22;}
		}{p = (( s->tokend))-1;}}
	goto st22;
st22:
#line 1 "reader.rl"
	{ s->tokstart = 0;}
	if ( ++p == pe )
		goto _out22;
case 22:
#line 1 "reader.rl"
	{ s->tokstart = p;}
#line 174 "reader.m"
	switch( (*p) ) {
		case 0: goto tr32;
		case 9: goto tr33;
		case 10: goto tr34;
		case 32: goto tr33;
		case 34: goto tr35;
		case 39: goto tr36;
		case 47: goto tr37;
		case 48: goto tr38;
		case 95: goto st39;
	}
	if ( (*p) < 65 ) {
		if ( 49 <= (*p) && (*p) <= 57 )
			goto tr39;
	} else if ( (*p) > 90 ) {
		if ( 97 <= (*p) && (*p) <= 122 )
			goto st39;
	} else
		goto st39;
	goto tr31;
tr35:
#line 1 "reader.rl"
	{ s->tokend = p+1;}
	goto st23;
st23:
	if ( ++p == pe )
		goto _out23;
case 23:
#line 203 "reader.m"
	switch( (*p) ) {
		case 34: goto tr1;
		case 92: goto st2;
	}
	goto st1;
st1:
	if ( ++p == pe )
		goto _out1;
case 1:
	switch( (*p) ) {
		case 34: goto tr1;
		case 92: goto st2;
	}
	goto st1;
st2:
	if ( ++p == pe )
		goto _out2;
case 2:
	goto st1;
tr36:
#line 1 "reader.rl"
	{ s->tokend = p+1;}
	goto st24;
st24:
	if ( ++p == pe )
		goto _out24;
case 24:
#line 231 "reader.m"
	switch( (*p) ) {
		case 39: goto tr4;
		case 92: goto st4;
	}
	goto st3;
st3:
	if ( ++p == pe )
		goto _out3;
case 3:
	switch( (*p) ) {
		case 39: goto tr4;
		case 92: goto st4;
	}
	goto st3;
st4:
	if ( ++p == pe )
		goto _out4;
case 4:
	goto st3;
tr37:
#line 1 "reader.rl"
	{ s->tokend = p+1;}
	goto st25;
st25:
	if ( ++p == pe )
		goto _out25;
case 25:
#line 259 "reader.m"
	switch( (*p) ) {
		case 42: goto tr42;
		case 47: goto st5;
	}
	goto tr41;
st5:
	if ( ++p == pe )
		goto _out5;
case 5:
	if ( (*p) == 10 )
		goto tr7;
	goto st5;
tr38:
#line 1 "reader.rl"
	{ s->tokend = p+1;}
#line 51 "reader.rl"
	{ s->act = 7;}
	goto st26;
st26:
	if ( ++p == pe )
		goto _out26;
case 26:
#line 282 "reader.m"
	switch( (*p) ) {
		case 44: goto st6;
		case 46: goto st14;
		case 69: goto st17;
		case 101: goto st17;
		case 120: goto st19;
	}
	if ( 48 <= (*p) && (*p) <= 57 )
		goto tr46;
	goto tr43;
st6:
	if ( ++p == pe )
		goto _out6;
case 6:
	if ( 48 <= (*p) && (*p) <= 57 )
		goto st7;
	goto tr8;
st7:
	if ( ++p == pe )
		goto _out7;
case 7:
	if ( 48 <= (*p) && (*p) <= 57 )
		goto st8;
	goto tr8;
st8:
	if ( ++p == pe )
		goto _out8;
case 8:
	if ( 48 <= (*p) && (*p) <= 57 )
		goto tr11;
	goto tr8;
tr11:
#line 1 "reader.rl"
	{ s->tokend = p+1;}
#line 55 "reader.rl"
	{ s->act = 9;}
	goto st27;
st27:
	if ( ++p == pe )
		goto _out27;
case 27:
#line 324 "reader.m"
	switch( (*p) ) {
		case 44: goto st6;
		case 46: goto st9;
		case 69: goto st12;
		case 101: goto st12;
	}
	goto tr49;
st9:
	if ( ++p == pe )
		goto _out9;
case 9:
	if ( 48 <= (*p) && (*p) <= 57 )
		goto tr13;
	goto tr12;
tr13:
#line 1 "reader.rl"
	{ s->tokend = p+1;}
	goto st28;
st28:
	if ( ++p == pe )
		goto _out28;
case 28:
#line 347 "reader.m"
	switch( (*p) ) {
		case 69: goto st10;
		case 101: goto st10;
	}
	if ( 48 <= (*p) && (*p) <= 57 )
		goto tr13;
	goto tr52;
st10:
	if ( ++p == pe )
		goto _out10;
case 10:
	switch( (*p) ) {
		case 43: goto st11;
		case 45: goto st11;
	}
	if ( 48 <= (*p) && (*p) <= 57 )
		goto st29;
	goto tr14;
st11:
	if ( ++p == pe )
		goto _out11;
case 11:
	if ( 48 <= (*p) && (*p) <= 57 )
		goto st29;
	goto tr14;
st29:
	if ( ++p == pe )
		goto _out29;
case 29:
	if ( 48 <= (*p) && (*p) <= 57 )
		goto st29;
	goto tr52;
st12:
	if ( ++p == pe )
		goto _out12;
case 12:
	switch( (*p) ) {
		case 43: goto st13;
		case 45: goto st13;
	}
	if ( 48 <= (*p) && (*p) <= 57 )
		goto st30;
	goto tr12;
st13:
	if ( ++p == pe )
		goto _out13;
case 13:
	if ( 48 <= (*p) && (*p) <= 57 )
		goto st30;
	goto tr12;
st30:
	if ( ++p == pe )
		goto _out30;
case 30:
	if ( 48 <= (*p) && (*p) <= 57 )
		goto st30;
	goto tr49;
st14:
	if ( ++p == pe )
		goto _out14;
case 14:
	if ( 48 <= (*p) && (*p) <= 57 )
		goto tr20;
	goto tr19;
tr20:
#line 1 "reader.rl"
	{ s->tokend = p+1;}
	goto st31;
st31:
	if ( ++p == pe )
		goto _out31;
case 31:
#line 420 "reader.m"
	switch( (*p) ) {
		case 69: goto st15;
		case 101: goto st15;
	}
	if ( 48 <= (*p) && (*p) <= 57 )
		goto tr20;
	goto tr54;
st15:
	if ( ++p == pe )
		goto _out15;
case 15:
	switch( (*p) ) {
		case 43: goto st16;
		case 45: goto st16;
	}
	if ( 48 <= (*p) && (*p) <= 57 )
		goto st32;
	goto tr21;
st16:
	if ( ++p == pe )
		goto _out16;
case 16:
	if ( 48 <= (*p) && (*p) <= 57 )
		goto st32;
	goto tr21;
st32:
	if ( ++p == pe )
		goto _out32;
case 32:
	if ( 48 <= (*p) && (*p) <= 57 )
		goto st32;
	goto tr54;
tr46:
#line 1 "reader.rl"
	{ s->tokend = p+1;}
#line 51 "reader.rl"
	{ s->act = 7;}
	goto st33;
st33:
	if ( ++p == pe )
		goto _out33;
case 33:
#line 463 "reader.m"
	switch( (*p) ) {
		case 44: goto st6;
		case 46: goto st14;
		case 69: goto st17;
		case 101: goto st17;
	}
	if ( 48 <= (*p) && (*p) <= 57 )
		goto tr56;
	goto tr43;
tr56:
#line 1 "reader.rl"
	{ s->tokend = p+1;}
#line 51 "reader.rl"
	{ s->act = 7;}
	goto st34;
st34:
	if ( ++p == pe )
		goto _out34;
case 34:
#line 483 "reader.m"
	switch( (*p) ) {
		case 44: goto st6;
		case 46: goto st14;
		case 69: goto st17;
		case 101: goto st17;
	}
	if ( 48 <= (*p) && (*p) <= 57 )
		goto tr57;
	goto tr43;
tr57:
#line 1 "reader.rl"
	{ s->tokend = p+1;}
	goto st35;
st35:
	if ( ++p == pe )
		goto _out35;
case 35:
#line 501 "reader.m"
	switch( (*p) ) {
		case 46: goto st14;
		case 69: goto st17;
		case 101: goto st17;
	}
	if ( 48 <= (*p) && (*p) <= 57 )
		goto tr57;
	goto tr43;
st17:
	if ( ++p == pe )
		goto _out17;
case 17:
	switch( (*p) ) {
		case 43: goto st18;
		case 45: goto st18;
	}
	if ( 48 <= (*p) && (*p) <= 57 )
		goto st36;
	goto tr19;
st18:
	if ( ++p == pe )
		goto _out18;
case 18:
	if ( 48 <= (*p) && (*p) <= 57 )
		goto st36;
	goto tr19;
st36:
	if ( ++p == pe )
		goto _out36;
case 36:
	if ( 48 <= (*p) && (*p) <= 57 )
		goto st36;
	goto tr43;
st19:
	if ( ++p == pe )
		goto _out19;
case 19:
	if ( (*p) < 65 ) {
		if ( 48 <= (*p) && (*p) <= 57 )
			goto st37;
	} else if ( (*p) > 70 ) {
		if ( 97 <= (*p) && (*p) <= 102 )
			goto st37;
	} else
		goto st37;
	goto tr19;
st37:
	if ( ++p == pe )
		goto _out37;
case 37:
	if ( (*p) < 65 ) {
		if ( 48 <= (*p) && (*p) <= 57 )
			goto st37;
	} else if ( (*p) > 70 ) {
		if ( 97 <= (*p) && (*p) <= 102 )
			goto st37;
	} else
		goto st37;
	goto tr58;
tr39:
#line 1 "reader.rl"
	{ s->tokend = p+1;}
#line 51 "reader.rl"
	{ s->act = 7;}
	goto st38;
st38:
	if ( ++p == pe )
		goto _out38;
case 38:
#line 571 "reader.m"
	switch( (*p) ) {
		case 44: goto st6;
		case 46: goto st14;
		case 69: goto st17;
		case 101: goto st17;
	}
	if ( 48 <= (*p) && (*p) <= 57 )
		goto tr46;
	goto tr43;
st39:
	if ( ++p == pe )
		goto _out39;
case 39:
	switch( (*p) ) {
		case 58: goto tr60;
		case 95: goto st39;
	}
	if ( (*p) < 65 ) {
		if ( 48 <= (*p) && (*p) <= 57 )
			goto st39;
	} else if ( (*p) > 90 ) {
		if ( 97 <= (*p) && (*p) <= 122 )
			goto st39;
	} else
		goto st39;
	goto tr59;
tr28:
#line 14 "reader.rl"
	{s->curline += 1;}
	goto st20;
st20:
#line 1 "reader.rl"
	{ s->tokstart = 0;}
	if ( ++p == pe )
		goto _out20;
case 20:
#line 608 "reader.m"
	switch( (*p) ) {
		case 10: goto tr28;
		case 42: goto st21;
	}
	goto st20;
st21:
	if ( ++p == pe )
		goto _out21;
case 21:
	switch( (*p) ) {
		case 10: goto tr28;
		case 42: goto st21;
		case 47: goto tr30;
	}
	goto st20;
tr30:
#line 18 "reader.rl"
	{{goto st22;}}
	goto st40;
st40:
	if ( ++p == pe )
		goto _out40;
case 40:
#line 632 "reader.m"
	goto st0;
st0:
	goto _out0;
	}
	_out22:  s->cs = 22; goto _out; 
	_out23:  s->cs = 23; goto _out; 
	_out1:  s->cs = 1; goto _out; 
	_out2:  s->cs = 2; goto _out; 
	_out24:  s->cs = 24; goto _out; 
	_out3:  s->cs = 3; goto _out; 
	_out4:  s->cs = 4; goto _out; 
	_out25:  s->cs = 25; goto _out; 
	_out5:  s->cs = 5; goto _out; 
	_out26:  s->cs = 26; goto _out; 
	_out6:  s->cs = 6; goto _out; 
	_out7:  s->cs = 7; goto _out; 
	_out8:  s->cs = 8; goto _out; 
	_out27:  s->cs = 27; goto _out; 
	_out9:  s->cs = 9; goto _out; 
	_out28:  s->cs = 28; goto _out; 
	_out10:  s->cs = 10; goto _out; 
	_out11:  s->cs = 11; goto _out; 
	_out29:  s->cs = 29; goto _out; 
	_out12:  s->cs = 12; goto _out; 
	_out13:  s->cs = 13; goto _out; 
	_out30:  s->cs = 30; goto _out; 
	_out14:  s->cs = 14; goto _out; 
	_out31:  s->cs = 31; goto _out; 
	_out15:  s->cs = 15; goto _out; 
	_out16:  s->cs = 16; goto _out; 
	_out32:  s->cs = 32; goto _out; 
	_out33:  s->cs = 33; goto _out; 
	_out34:  s->cs = 34; goto _out; 
	_out35:  s->cs = 35; goto _out; 
	_out17:  s->cs = 17; goto _out; 
	_out18:  s->cs = 18; goto _out; 
	_out36:  s->cs = 36; goto _out; 
	_out19:  s->cs = 19; goto _out; 
	_out37:  s->cs = 37; goto _out; 
	_out38:  s->cs = 38; goto _out; 
	_out39:  s->cs = 39; goto _out; 
	_out20:  s->cs = 20; goto _out; 
	_out21:  s->cs = 21; goto _out; 
	_out40:  s->cs = 40; goto _out; 
	_out0:  s->cs = 0; goto _out; 

	_out: {}
	}
#line 112 "reader.rl"
		
		if ( s->cs == Scanner_error )
			return TK_ERR;

		if ( token != TK_NO_TOKEN ) {
			/* Save p and pe. fbreak does not advance p. */
			s->p = p + 1;
			s->pe = pe;
			s->len = s->p - s->data;
			s->token = token;
			return token;
		}
	}
}

#ifdef TEST

void output(Scanner *ss)
{
	NSInteger tok;
	
	while ( 1 ) {
		tok = scan (ss);
		if ( tok == TK_EOF ) {
			printf ("parser: EOF\n");
			break;
		}
		else if ( tok == TK_ERR ) {
			printf ("parser: ERR\n");
			break;
		}
		else {
#warning 64BIT: Check formatting arguments
			printf ("parser: %s(%d):%d \"", ss->token_name, tok, ss->curline);
			fwrite ( ss->data, 1, ss->len, stdout );
			printf ("\"\n" );
		}
	}
}

#define BUFSIZE 2048

int main (int argc, char** argv)
{
	Scanner ss;
   	char buf[BUFSIZE];

	NSInteger len = fread ( buf, sizeof(char), BUFSIZE, stdin );
	buf[len] = '\0';
	scan_init_buf (&ss, buf);

//	char *input = "(do with:1,345.99 and: \"some string\")";
//	scan_init_buf(&ss, input);
	
	output (&ss);
	scan_finalize (&ss);
	
	return 0;
}

#endif
