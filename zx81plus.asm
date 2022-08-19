; ===========================================================
; An Assembly Listing of the Operating System of the ZX81 ROM
; ===========================================================

; Last updated: 13-DEC-2004
; 2011		Updated to remove -, +, /, *, &, 
;		characters from labels (which confuse assemblers)
;
; 2011		Updated for conditional assembly of ORIGINAL or "Shoulders of Giants" ROM
;
; 2014-08-01	Updated to add CHARS_PER_LINE_WINDOW  which is normally 32.
;
;	The ideal pixel rates for square pixels on a PAL system are
;	14.75  MHz (interlaced) and
;	 7.375 MHz (non-interlaced, which the ZX80/ZX81 are).
;	These are not commonly available but fortunately one can buy
;	baud-rate generator frequencies such as
;	14.7456 and 7.3728 MHz that are only 0.03% low
;	which is more than close enough.
;
;	ZX video normally has 6.5 MHz pixel rate,
;	so 32 characters take 256 pixels in 39.4 microseconds.
;	A 7.3728 MHz clock and 40 characters produces 
;	320 pixels in 43.4 microseconds.
;
;	ZX80 video generation is software defined so it is
;	easy to get square pixels simply by subtracting 8 from the bytes
;	at hex addresses 287, 2AA and 2B8.
;	The video will appear to the left of the screen but
;	the characters will be square and a diagonal graphic line
;	will be at 45 degrees.
;
;	ZX81 video generation in fast mode exactly the same as the ZX80.
;
;	ZX81 video generation in slow mode is problematic, in that
;	the NMI generator expects a 3.25 MHz CPU clock 
;	(3.25MHz / 208 = 15.625 kHz = 64 microsecond line period)
;	It is inside the ULA where it cannot be modified.
;
;	Simply fitting a 7.3728 MHz crystal would reduce the line period to
;	57.3 microseconds. Slow mode would require the CPU clock to be
;	divided by 236.
;
;	Square pixels on NTSC requires 11+3/11 = 11.272... MHz (interlaced)
;	or 5.63.. non-interlaced which is slower than the original 6.5 MHz.
;	The NTSC line period is still 64 microseconds, so 256 pixels
;	stretch over 45 microseconds, and 320 pixels over 56 microseconds.
;	Thus it is possible to get square pixels on an NTSC display,
;	it is not possible to get 40 column text as well.
;	That would require the PAL clock, but pixels would not be square.
;
;	The ZX printer is fixed in hardware.
;	It will not work in 40-column mode.
;
;
;
;	PIXEL_CLOCK:	equ	7372500
;
; on-line assembler complains about the line above
;
; CHARS_PER_LINE_WINDOW always 32 for 6.5   MHz pixel rate
;                       always 40 for 7.375 MHz PAL square pixel rate
;
;CHARS_PER_LINE_WINDOW:	equ	40	; 32	originally
CHARS_PER_LINE_WINDOW:	equ	32
;
; CHARS_PER_LINE always 32 for 6.5 MHz pixel rate
;                but 32 or 40 if using PAL square pixel rate
;
;CHARS_HORIZONTAL:	equ	40	; 32	originally
CHARS_HORIZONTAL:	equ	32
CHARS_VERTICAL:		equ	24
;
; 2014-08-01
; Largely working but some bugs remain.
; Working:
; You can type text and it takes 40 characters before new line.
; 40 characters are nicely centred in the screen.
; PLOT X,Y accepts X from 0 to 79.
; Faulty:
; System crashing in an authentic ZX81 fashion,
; I don't know if this is due to software bugs
; or socket joint disturbance from key presses.
; 
;
; 2018-01-09 add org
; Assembles using on-line assembler "zasm" at:
;
; http://k1.spdns.de/cgi-bin/zasm.cgi
;
	org	0
	
FALSE:		equ	0

ORIGINAL:	equ	1
NOT_BODGED:	equ	1

; 2018-02-09 CHARS_HORIZONTAL placed in SCROLL routine.
;		Thanks to Adam Klotblixt for testing code and spotting this bug.
;	Also added to some G007 routines.
;


;
; Work in progress.
; This file will cross-assemble an original version of the "Improved"
; ZX81 ROM.
; The file can be modified to change the behaviour of the ROM
; when used in emulators although there is no spare space available.
;
; The documentation is incomplete and if you can find a copy
; of "The Complete Spectrum ROM Disassembly" then many routines
; such as POINTERS and most of the mathematical routines are
; similar and often identical.
;
; I've used the labels from the above book in this file and also
; some from the more elusive Complete ZX81 ROM Disassembly
; by the same publishers, Melbourne House.

; define stuff sensibly:
;
; I/O locations:
;
IO_PORT_TAPE:		equ	$FF	; write
IO_PORT_SCREEN:		equ	$FF	; write

IO_PORT_KEYBOARD_RD:	equ	$FE	; A0 low
IO_PORT_NMI_GEN_ON:	equ	$FE	; A0 low
IO_PORT_NMI_GEN_OFF:	equ	$FD	; A1 low
IO_PORT_PRINTER:		equ	$FB	; A2 low

;
; System variables:
;
RAMBASE:		equ	$4000
ERR_NR:		equ	$4000		; The report code. Incremented before printing.
FLAGS:		equ	$4001		; Bit 0: Suppression of leading space.
					; Bit 1: Control Flag for the printer.
					; Bit 2: Selects K or F mode; or, F or G
					; Bit 6: FP no. or string parameters.
					; Bit 7: Reset during syntax checking."
ERR_SP:		equ	$4002		; Pointer to the GOSUB stack.
RAMTOP:		equ	$4004		; The top of available RAM, or as specified.
MODE:		equ	$4006		; Holds the code for K or F
PPC:		equ	$4007		; Line number of the current statement.
PPC_hi:		equ	PPC+1
VERSN:		equ	$4009		; Marks the start of the RAM that is saved.
E_PPC:		equ	$400A		; The BASIC line with the cursor
D_FILE:		equ	$400C		; Pointer to Display file
DF_CC:		equ	$400E		; Address for PRINT AT position
VARS:		equ	$4010		; Pointer to variable area
DEST:		equ	$4012		; Address of current variable in program area
E_LINE:		equ	$4014		; Pointer to workspace
E_LINE_hi:	equ	E_LINE+1
CH_ADD:		equ	$4016		; Pointer for scanning a line, in program or workspace
X_PTR:		equ	$4018		; Pointer to syntax error.
X_PTR_lo:	equ	X_PTR
X_PTR_hi:	equ	X_PTR+1
STKBOT:		equ	$401A		; Pointer to calculator stack bottom.
STKEND:		equ	$401C		; Pointer to calculator stack end.
BERG:		equ	$401E		; Used for many different counting purposes
MEM:		equ	$401F		; Pointer to base of table of fp. nos, either in calc. stack or variable area.
;					; Unused by ZX BASIC. Or FLAG Y for G007
DF_SZ:		equ	$4022		; Number of lines in the lower screen
S_TOP:		equ	$4023		; Current line number of automatic listing
LAST_K:		equ	$4025		; Last Key pressed
DEBOUNCE_VAR:	equ	$4027		; The de-bounce status
MARGIN:		equ	$4028		; Adjusts for differing TV standards
NXTLIN:		equ	$4029		; Next BASIC line to be interpreted
OLDPPC:		equ	$402B		; Last line number, in case needed.
FLAGX:		equ	$402D		; Bit 0: Reset indicates an arrayed variable
					; Bit 1: Reset indicates a given variable exists
					; Bit 5: Set during INPUT mode
					; Bit 7: Set when INPUT is to be numeric
STRLEN:		equ	$402E		; Length of a string, or a BASIC line
STRLEN_lo:	equ	STRLEN		; 
T_ADDR:		equ	$4030		; Pointer to parameter table. & distinguishes between PLOT & UNPLOT
SEED:		equ	$4032		; For RANDOM function
FRAMES:		equ	$4034		; Frame counter
FRAMES_hi:	equ	FRAMES+1	; 
COORDS:		equ	$4036		; X & Y for PLOT
COORDS_x:	equ	COORDS		; 
PR_CC:		equ	$4038		; Print buffer counter
S_POSN:		equ	$4039		; Line & Column for PRINT AT
S_POSN_x:	equ	$4039		; 
S_POSN_y:	equ	$403A		; 
CDFLAG:		equ	$403B		; Bit 6 = the true fast/slow flag
					; Bit 7 = copy of the fast/slow flag. RESET when FAST needed
PRBUFF:		equ	$403C		; Printer buffer
PRBUFF_END:	equ	$405C		; 
MEM_0_1st:	equ	$405D		; room for 5 floating point numbers (meme_0 to mem_ 5???)
;			$407B		; unused. Or RESTART to G007
;			$407D		; The BASIC program starts here
;:		equ	$40
;:		equ	$40
;:		equ	$40
; First byte after system variables:
USER_RAM:	equ	$407D
MAX_RAM:		equ	$7FFF

;===============================
; ZX81 constants:
;===============================
; ZX characters (not the same as ASCII)
;-------------------------------
ZX_SPACE:	equ	$00
;	ZX_graphic:		equ	$01
;	ZX_graphic:		equ	$02
;	ZX_graphic:		equ	$03
;	ZX_graphic:		equ	$04
;	ZX_graphic:		equ	$05
;	ZX_graphic:		equ	$06
;	ZX_graphic:		equ	$07
;	ZX_graphic:		equ	$08
;	ZX_graphic:		equ	$09
;	ZX_graphic:		equ	$0A
ZX_QUOTE:		equ	$0B
ZX_POUND:		equ	$0C
ZX_DOLLAR:		equ	$0D
ZX_COLON:		equ	$0E
ZX_QUERY:		equ	$0F
ZX_BRACKET_LEFT:		equ	$10
ZX_BRACKET_RIGHT:	equ	$11
ZX_GREATER_THAN:		equ	$12
ZX_LESS_THAN:		equ	$13
ZX_EQUAL:		equ	$14
ZX_PLUS:			equ	$15
ZX_MINUS:		equ	$16
ZX_STAR:			equ	$17
ZX_SLASH:		equ	$18
ZX_SEMICOLON:		equ	$19
ZX_COMMA:		equ	$1A
ZX_PERIOD:		equ	$1B
ZX_0:		equ	$1C
ZX_1:		equ	$1D
ZX_2:		equ	$1E
ZX_3:		equ	$1F
ZX_4:		equ	$20
ZX_5:		equ	$21
ZX_6:		equ	$22
ZX_7:		equ	$23
ZX_8:		equ	$24
ZX_9:		equ	$25
ZX_A:		equ	$26
ZX_B:		equ	$27
ZX_C:		equ	$28
ZX_D:		equ	$29
ZX_E:		equ	$2A
ZX_F:		equ	$2B
ZX_G:		equ	$2C
ZX_H:		equ	$2D
ZX_I:		equ	$2E
ZX_J:		equ	$2F
ZX_K:		equ	$30
ZX_L:		equ	$31
ZX_M:		equ	$32
ZX_N:		equ	$33
ZX_O:		equ	$34
ZX_P:		equ	$35
ZX_Q:		equ	$36
ZX_R:		equ	$37
ZX_S:		equ	$38
ZX_T:		equ	$39
ZX_U:		equ	$3A
ZX_V:		equ	$3B
ZX_W:		equ	$3C
ZX_X:		equ	$3D
ZX_Y:		equ	$3E
ZX_Z:		equ	$3F
ZX_RND:			equ	$40
ZX_INKEY_STR:		equ	$41
ZX_PI:			equ	$42
;
; $43 to $6F not used
;
ZX_cursor_up:		equ	$70
ZX_cursor_down:		equ	$71
ZX_cursor_left:		equ	$72
ZX_cursor_right:		equ	$73

ZX_GRAPHICS:		equ	$74
ZX_EDIT:			equ	$75
ZX_NEWLINE:		equ	$76
ZX_RUBOUT:		equ	$77
ZX_KL:			equ	$78
ZX_FUNCTION:		equ	$79
;
; $7A to $7F not used
;
ZX_CURSOR:		equ	$7F
;
; $80 to $BF are inverses of $00 to $3F
;
;	ZX_graphic:		equ	$80	 ; inverse space
;	ZX_graphic:		equ	$81
;	ZX_graphic:		equ	$82
;	ZX_graphic:		equ	$83
;	ZX_graphic:		equ	$84
;	ZX_graphic:		equ	$85
;	ZX_graphic:		equ	$86
;	ZX_graphic:		equ	$87
;	ZX_graphic:		equ	$88
;	ZX_graphic:		equ	$89
;	ZX_graphic:		equ	$8A
ZX_INV_QUOTE:		equ	$8B
ZX_INV_POUND:		equ	$8C
ZX_INV_DOLLAR:		equ	$8D
ZX_INV_COLON:		equ	$8E
ZX_INV_QUERY:		equ	$8F
ZX_INV_BRACKET_RIGHT:	equ	$90
ZX_INV_BRACKET_LEFT:	equ	$91
ZX_INV_GT:		equ	$92

ZX_INV_PLUS:		equ	$95
ZX_INV_MINUS:		equ	$96

ZX_INV_K:		equ	$B0
ZX_INV_S:		equ	$B8

ZX_DOUBLE_QUOTE:		equ	$C0
ZX_AT:			equ	$C1
ZX_TAB:			equ	$C2
; not used:		equ	$C3
ZX_CODE:			equ	$C4
ZX_VAL:			equ	$C5
ZX_LEN:			equ	$C6
ZX_SIN:			equ	$C7
ZX_COS:			equ	$C8
ZX_TAN:			equ	$C9
ZX_ASN:			equ	$CA
ZX_ACS:			equ	$CB
ZX_ATN:			equ	$CC
ZX_LN:			equ	$CD
ZX_EXP:			equ	$CE
ZX_INT:			equ	$CF

ZX_SQR:			equ	$D0
ZX_SGN:			equ	$D1
ZX_ABS:			equ	$D2
ZX_PEEK:			equ	$D3
ZX_USR:			equ	$D4
ZX_STR_STR:		equ	$D5		; STR$
ZX_CHR_STR:		equ	$D6		; CHR$
ZX_NOT:			equ	$D7
ZX_POWER:		equ	$D8
ZX_OR:			equ	$D9
ZX_AND:			equ	$DA
ZX_LESS_OR_EQUAL:	equ	$DB
ZX_GREATER_OR_EQUAL:	equ	$DC
ZX_NOT_EQUAL:		equ	$DD
ZX_THEN:			equ	$DE
ZX_TO:			equ	$DF

ZX_STEP:			equ	$E0
ZX_LPRINT:		equ	$E1
ZX_LLIST:		equ	$E2
ZX_STOP:			equ	$E3
ZX_SLOW:			equ	$E4
ZX_FAST:			equ	$E5
ZX_NEW:			equ	$E6
ZX_SCROLL:		equ	$E7
ZX_CONT:			equ	$E8
ZX_DIM:			equ	$E9
ZX_REM:			equ	$EA
ZX_FOR:			equ	$EB
ZX_GOTO:			equ	$EC
ZX_GOSUB:		equ	$ED
ZX_INPUT:		equ	$EE
ZX_LOAD:			equ	$EF

ZX_LIST:			equ	$F0
ZX_LET:			equ	$F1
ZX_PAUSE:		equ	$F2
ZX_NEXT:			equ	$F3
ZX_POKE:			equ	$F4
ZX_PRINT:		equ	$F5
ZX_PLOT:			equ	$F6
ZX_RUN:			equ	$F7
ZX_SAVE:			equ	$F8
ZX_RAND:			equ	$F9
ZX_IF:			equ	$FA
ZX_CLS:			equ	$FB
ZX_UNPLOT:		equ	$FC
ZX_CLEAR:		equ	$FD
ZX_RETURN:		equ	$FE
ZX_COPY:			equ	$FF


;
_CLASS_00:	equ	0
_CLASS_01:	equ	1
_CLASS_02:	equ	2
_CLASS_03:	equ	3
_CLASS_04:	equ	4
_CLASS_05:	equ	5
_CLASS_06:	equ	6



; These values taken from BASIC manual
; 
;
ERROR_CODE_SUCCESS:			equ	0
ERROR_CODE_CONTROL_VARIABLE:		equ	1
ERROR_CODE_UNDEFINED_VARIABLE:		equ	2
ERROR_CODE_SUBSCRIPT_OUT_OF_RANGE:	equ	3
ERROR_CODE_NOT_ENOUGH_MEMORY:		equ	4
ERROR_CODE_NO_ROOM_ON_SCREEN:		equ	5
ERROR_CODE_ARITHMETIC_OVERFLOW:		equ	6
ERROR_CODE_RETURN_WITHOUT_GOSUB:		equ	7
ERROR_CODE_INPUT_AS_A_COMMAND:		equ	8
ERROR_CODE_STOP:				equ	9
ERROR_CODE_INVALID_ARGUMENT:		equ	10

ERROR_CODE_INTEGER_OUT_OF_RANGE:		equ	11
ERROR_CODE_VAL_STRING_INVALID:		equ	12
ERROR_CODE_BREAK:			equ	13

ERROR_CODE_EMPTY_PROGRAM_NAME:		equ	15

;
; codes for Forth-like calculator
;
__jump_true:		equ	$00
__exchange:		equ	$01
__delete:		equ	$02
__subtract:		equ	$03
__multiply:		equ	$04
__division:		equ	$05
__to_power:		equ	$06
__or:			equ	$07
__boolean_num_and_num:	equ	$08
__num_l_eql:		equ	$09
__num_gr_eql:		equ	$0A
__nums_neql:		equ	$0B
__num_grtr:		equ	$0C
__num_less:		equ	$0D
__nums_eql:		equ	$0E
__addition:		equ	$0F
__strs_and_num:		equ	$10
__str_l_eql:		equ	$11
__str_gr_eql:		equ	$12
__strs_neql:		equ	$13
__str_grtr:		equ	$14
__str_less:		equ	$15
__strs_eql:		equ	$16
__strs_add:		equ	$17
__negate:		equ	$18
__code:			equ	$19
__val:			equ	$1A 
__len:			equ	$1B 
__sin:			equ	$1C
__cos:			equ	$1D
__tan:			equ	$1E
__asn:			equ	$1F
__acs:			equ	$20
__atn:			equ	$21
__ln:			equ	$22
__exp:			equ	$23
__int:			equ	$24
__sqr:			equ	$25
__sgn:			equ	$26
__abs:			equ	$27
__peek:			equ	$28
__usr_num:		equ	$29
__str_dollar:		equ	$2A
__chr_dollar:		equ	$2B
__not:			equ	$2C
__duplicate:		equ	$2D
__n_mod_m:		equ	$2E
__jump:			equ	$2F
__stk_data:		equ	$30
__dec_jr_nz:		equ	$31
__less_0:		equ	$32
__greater_0:		equ	$33
__end_calc:		equ	$34
__get_argt:		equ	$35
__truncate:		equ	$36
__fp_calc_2:		equ	$37
__e_to_fp:		equ	$38

;
; __series_xx:			equ	$39 : $80__$9F.
; tells the stack machine to push 
; 0 to 31 floating-point values on the stack.
;
__series_06:		equ	$86
__series_08:		equ	$88
__series_0C:		equ	$8C
;	__stk_const_xx:			equ	$3A : $A0__$BF.
;	__st_mem_xx:			equ	$3B : $C0__$DF.
;	__get_mem_xx:			equ	$3C : $E0__$FF.

__st_mem_0:			equ	$C0
__st_mem_1:			equ	$C1
__st_mem_2:			equ	$C2
__st_mem_3:			equ	$C3
__st_mem_4:			equ	$C4
__st_mem_5:			equ	$C5
__st_mem_6:			equ	$C6
__st_mem_7:			equ	$C7


__get_mem_0:			equ	$E0
__get_mem_1:			equ	$E1
__get_mem_2:			equ	$E2
__get_mem_3:			equ	$E3
__get_mem_4:			equ	$E4


__stk_zero:			equ	$A0
__stk_one:			equ	$A1
__stk_half:			equ	$A2
__stk_half_pi:			equ	$A3
__stk_ten:			equ	$A4

;*****************************************
;** Part 1. RESTART ROUTINES AND TABLES **
;*****************************************


; THE 'START'

; All Z80 chips start at location zero.
; At start-up the Interrupt Mode is 0, ZX computers use Interrupt Mode 1.
; Interrupts are disabled .

mark_0000:
START:
	OUT	(IO_PORT_NMI_GEN_OFF),A	; Turn off the NMI generator if this ROM is 
				; running in ZX81 hardware. This does nothing 
				; if this ROM is running within an upgraded
				; ZX80.
	LD	BC,MAX_RAM	; Set BC to the top of possible RAM.
				; The higher unpopulated addresses are used for
				; video generation.
	JP	RAM_CHECK	; Jump forward to RAM_CHECK.


; THE 'ERROR' RESTART

; The error restart deals immediately with an error.
; ZX computers execute the same code in runtime as when checking syntax.
; If the error occurred while running a program
; then a brief report is produced.
; If the error occurred while entering a BASIC line or in input etc., 
; then the error marker indicates the exact point at which the error lies.

mark_0008:
ERROR_1:
	LD	HL,(CH_ADD)	; fetch character address from CH_ADD.
	LD	(X_PTR),HL	; and set the error pointer X_PTR.
	JR	ERROR_2		; forward to continue at ERROR_2.


; THE 'PRINT A CHARACTER' RESTART

; This restart prints the character in the accumulator using the alternate
; register set so there is no requirement to save the main registers.
; There is sufficient room available to separate a space (zero) from other
; characters as leading spaces need not be considered with a space.

mark_0010:
PRINT_A:
	AND	A		; test for zero - space.
	JP	NZ,PRINT_CH	; jump forward if not to PRINT_CH.

	JP	PRINT_SP	; jump forward to PRINT_SP.

; ___
if ORIGINAL
	DEFB	$FF		; unused location.
else
	DEFB	$01		;+ unused location. Version. PRINT PEEK 23
endif


; THE 'COLLECT A CHARACTER' RESTART

; The character addressed by the system variable CH_ADD is fetched and if it
; is a non-space, non-cursor character it is returned else CH_ADD is 
; incremented and the new addressed character tested until it is not a space.

mark_0018:
GET_CHAR:
	LD	HL,(CH_ADD)	; set HL to character address CH_ADD.
	LD	A,(HL)		; fetch addressed character to A.

TEST_SP:
	AND	A		; test for space.
	RET	NZ		; return if not a space

	NOP			; else trickle through
	NOP			; to the next routine.


; THE 'COLLECT NEXT CHARACTER' RESTART

; The character address is incremented and the new addressed character is 
; returned if not a space, or cursor, else the process is repeated.

mark_0020:
NEXT_CHAR:
	CALL	CH_ADD_PLUS_1	; gets next immediate
				; character.
	JR	TEST_SP		; back
; ___

	DEFB	$FF, $FF, $FF	; unused locations.


; THE 'FLOATING POINT CALCULATOR' RESTART

; this restart jumps to the recursive floating-point calculator.
; the ZX81's internal, FORTH-like, stack-based language.
;
; In the five remaining bytes there is, appropriately, enough room for the
; end-calc literal - the instruction which exits the calculator.

mark_0028:
FP_CALC:
if ORIGINAL
	JP	CALCULATE	; jump immediately to the CALCULATE routine.
else

	JP	CALCULATE	;+ jump to the NEW calculate routine address.
endif

mark_002B:
end_calc:
	POP	AF		; drop the calculator return address RE_ENTRY
	EXX			; switch to the other set.

	EX	(SP),HL		; transfer H'L' to machine stack for the
				; return address.
				; when exiting recursion then the previous
				; pointer is transferred to H'L'.

	EXX			; back to main set.
	RET			; return.



; THE 'MAKE BC SPACES' RESTART

; This restart is used eight times to create, in workspace, the number of
; spaces passed in the BC register.

mark_0030:
BC_SPACES:
	PUSH	BC		; push number of spaces on stack.
	LD	HL,(E_LINE)	; fetch edit line location from E_LINE.
	PUSH	HL		; save this value on stack.
	JP	RESERVE		; jump forward to continue at RESERVE.



_START:		equ	$00
_ERROR_1:	equ	$08
_PRINT_A:	equ	$10
_GET_CHAR:	equ	$18
_NEXT_CHAR:	equ	$20
_FP_CALC:	equ	$28
_BC_SPACES:	equ	$30

; THE 'INTERRUPT' RESTART

;	The Mode 1 Interrupt routine is concerned solely with generating the central
;	television picture.
;	On the ZX81 interrupts are enabled only during the interrupt routine, 
;	although the interrupt 
;
;	This Interrupt Service Routine automatically disables interrupts at the 
;	outset and the last interrupt in a cascade exits before the interrupts are
;	enabled.
;
;	There is no DI instruction in the ZX81 ROM.
;
;	A maskable interrupt is triggered when bit 6 of the Z80's Refresh register
;	changes from set to reset.
;
;	The Z80 will always be executing a HALT (NEWLINE) when the interrupt occurs.
;	A HALT instruction repeatedly executes NOPS but the seven lower bits
;	of the Refresh register are incremented each time as they are when any 
;	simple instruction is executed. (The lower 7 bits are incremented twice for
;	a prefixed instruction)
;
;	This is controlled by the Sinclair Computer Logic Chip - manufactured from 
;	a Ferranti Uncommitted Logic Array.
;
;	When a Mode 1 Interrupt occurs the Program Counter, which is the address in
;	the upper echo display following the NEWLINE/HALT instruction, goes on the 
;	machine stack.	193 interrupts are required to generate the last part of
;	the 56th border line and then the 192 lines of the central TV picture and, 
;	although each interrupt interrupts the previous one, there are no stack 
;	problems as the 'return address' is discarded each time.
;
;	The scan line counter in C counts down from 8 to 1 within the generation of
;	each text line. For the first interrupt in a cascade the initial value of 
;	C is set to 1 for the last border line.
;	Timing is of the utmost importance as the RH border, horizontal retrace
;	and LH border are mostly generated in the 58 clock cycles this routine 
;	takes .



MARK_0038:
INTERRUPT:
	DEC	C		; (4)	decrement C - the scan line counter.
	JP	NZ,SCAN_LINE	; (10/10) JUMP forward if not zero to SCAN_LINE

	POP	HL		; (10) point to start of next row in display 
				;	file.

	DEC	B		; (4)	decrement the row counter. (4)
	RET	Z		; (11/5) return when picture complete to R_IX_1_LAST_NEWLINE
				;	with interrupts disabled.

	SET	3,C		; (8)	Load the scan line counter with eight.
				;	Note. LD C,$08 is 7 clock cycles which 
				;	is way too fast.

; ->

mark_0041:
WAIT_INT:
;
; NB $DD is for 32-column display
;
	LD	R,A		; (9) Load R with initial rising value $DD.

	EI			; (4) Enable Interrupts.	[ R is now $DE ].

	JP	(HL)		; (4) jump to the echo display file in upper
				;	memory and execute characters $00 - $3F 
				;	as NOP instructions.	The video hardware 
				;	is able to read these characters and, 
				;	with the I register is able to convert 
				;	the character bitmaps in this ROM into a 
				;	line of bytes. Eventually the NEWLINE/HALT
				;	will be encountered before R reaches $FF. 
				;	It is however the transition from $FF to 
				;	$80 that triggers the next interrupt.
				;	[ The Refresh register is now $DF ]

; ___

mark_0045:
SCAN_LINE:
	POP	DE		; (10) discard the address after NEWLINE as the 
				;	same text line has to be done again
				;	eight times. 

	RET	Z		; (5)	Harmless Nonsensical Timing.
				;	(condition never met)

	JR	WAIT_INT	; (12) back to WAIT_INT

;	Note. that a computer with less than 4K or RAM will have a collapsed
;	display file and the above mechanism deals with both types of display.
;
;	With a full display, the 32 characters in the line are treated as NOPS
;	and the Refresh register rises from $E0 to $FF and, at the next instruction 
;	- HALT, the interrupt occurs.
;	With a collapsed display and an initial NEWLINE/HALT, it is the NOPs 
;	generated by the HALT that cause the Refresh value to rise from $E0 to $FF,
;	triggering an Interrupt on the next transition.
;	This works happily for all display lines between these extremes and the 
;	generation of the 32 character, 1 pixel high, line will always take 128 
;	clock cycles.


; THE 'INCREMENT CH_ADD' SUBROUTINE

; This is the subroutine that increments the character address system variable
; and returns if it is not the cursor character. The ZX81 has an actual 
; character at the cursor position rather than a pointer system variable
; as is the case with prior and subsequent ZX computers.

mark_0049:
CH_ADD_PLUS_1:
	LD	HL,(CH_ADD)	; fetch character address to CH_ADD.

mark_004C:
TEMP_PTR1:
	INC	HL		; address next immediate location.

mark_004D:
TEMP_PTR2:
	LD	(CH_ADD),HL	; update system variable CH_ADD.

	LD	A,(HL)		; fetch the character.
	CP	ZX_CURSOR	; compare to cursor character.
	RET	NZ		; return if not the cursor.

	JR	TEMP_PTR1	; back for next character to TEMP_PTR1.


; THE 'ERROR_2' BRANCH

; This is a continuation of the error restart.
; If the error occurred in runtime then the error stack pointer will probably
; lead to an error report being printed unless it occurred during input.
; If the error occurred when checking syntax then the error stack pointer
; will be an editing routine and the position of the error will be shown
; when the lower screen is reprinted.

mark_0056:
ERROR_2:
	POP	HL		; pop the return address which points to the
				; DEFB, error code, after the RST 08.
	LD	L,(HL)		; load L with the error code. HL is not needed
				; anymore.

mark_0058:
ERROR_3:
	LD	(IY+ERR_NR-RAMBASE),L	; place error code in system variable ERR_NR
	LD	SP,(ERR_SP)	; set the stack pointer from ERR_SP
	CALL	SLOW_FAST	; selects slow mode.
	JP	SET_MIN		; exit to address on stack via routine SET_MIN.

; ___

	DEFB	$FF		; unused.


; THE 'NON MASKABLE INTERRUPT' ROUTINE

;	Jim Westwood's technical dodge using Non-Maskable Interrupts solved the
;	flicker problem of the ZX80 and gave the ZX81 a multi-tasking SLOW mode 
;	with a steady display.	Note that the AF' register is reserved for this 
;	function and its interaction with the display routines.	When counting 
;	TV lines, the NMI makes no use of the main registers.
;	The circuitry for the NMI generator is contained within the SCL (Sinclair 
;	Computer Logic) chip. 
;	( It takes 32 clock cycles while incrementing towards zero ). 

mark_0066:
NMI:
	EX	AF,AF'		; (4) switch in the NMI's copy of the 
				;	accumulator.
	INC	A		; (4) increment.
	JP	M,NMI_RET	; (10/10) jump, if minus, to NMI_RET as this is
				;	part of a test to see if the NMI 
				;	generation is working or an intermediate 
				;	value for the ascending negated blank 
				;	line counter.

	JR	Z,NMI_CONT	; (12) forward to NMI_CONT
				;	when line count has incremented to zero.

; Note. the synchronizing NMI when A increments from zero to one takes this
; 7 clock cycle route making 39 clock cycles in all.

mark_006D:
NMI_RET:
	EX	AF,AF'		; (4)	switch out the incremented line counter
				;	or test result $80
	RET			; (10) return to User application for a while.

; ___

;	This branch is taken when the 55 (or 31) lines have been drawn.

mark_006F:
NMI_CONT:
	EX	AF,AF'		; (4) restore the main accumulator.

	PUSH	AF		; (11) *		Save Main Registers
	PUSH	BC		; (11) **
	PUSH	DE		; (11) ***
	PUSH	HL		; (11) ****

;	the next set-up procedure is only really applicable when the top set of 
;	blank lines have been generated.

	LD	HL,(D_FILE)	; (16) fetch start of Display File from D_FILE
				;      points to the HALT at beginning.
	SET	7,H		; (8)  point to upper 32K 'echo display file'

	HALT			; (1)  HALT synchronizes with NMI.
				;      Used with special hardware connected to the
				;      Z80 HALT and WAIT lines to take 1 clock cycle.


;	the NMI has been generated - start counting.
;	The cathode ray is at the RH side of the TV.
;
;	First the NMI servicing, similar to CALL		=	17 clock cycles.
;	Then the time taken by the NMI for zero-to-one path	=	39 cycles
;	The HALT above						=	01 cycles.
;	The two instructions below				=	19 cycles.
;	The code at R_IX_1 up to and including the CALL		=	43 cycles.
;	The Called routine at DISPLAY_5				=	24 cycles.
;	--------------------------------------				---
;	Total Z80 instructions					=	143 cycles.
;
;	Meanwhile in TV world,
;	Horizontal retrace					=	15 cycles.
;	Left blanking border 8 character positions		=	32 cycles
;	Generation of 75% scanline from the first NEWLINE	=	96 cycles
;	---------------------------------------				---
;								=	143 cycles
;
;	Since at the time the first JP (HL) is encountered to execute the echo
;	display another 8 character positions have to be put out, then the
;	Refresh register need to hold $F8. Working back and counteracting 
;	the fact that every instruction increments the Refresh register then
;	the value that is loaded into R needs to be $F5.	:-)
;
;
	OUT	(IO_PORT_NMI_GEN_OFF),A		; (11) Stop the NMI generator.

	JP	(IX)				; (8) forward to R_IX_1 (after top) or R_IX_2

; ****************
; ** KEY TABLES **
; ****************


; THE 'UNSHIFTED' CHARACTER CODES


mark_007E:
K_UNSHIFT:
	DEFB	ZX_Z
	DEFB	ZX_X
	DEFB	ZX_C
	DEFB	ZX_V

	DEFB	ZX_A
	DEFB	ZX_S
	DEFB	ZX_D
	DEFB	ZX_F
	DEFB	ZX_G

	DEFB	ZX_Q
	DEFB	ZX_W
	DEFB	ZX_E
	DEFB	ZX_R
	DEFB	ZX_T

	DEFB	ZX_1
	DEFB	ZX_2
	DEFB	ZX_3
	DEFB	ZX_4
	DEFB	ZX_5

	DEFB	ZX_0
	DEFB	ZX_9
	DEFB	ZX_8
	DEFB	ZX_7
	DEFB	ZX_6

	DEFB	ZX_P
	DEFB	ZX_O
	DEFB	ZX_I
	DEFB	ZX_U
	DEFB	ZX_Y

	DEFB	ZX_NEWLINE
	DEFB	ZX_L
	DEFB	ZX_K
	DEFB	ZX_J
	DEFB	ZX_H

	DEFB	ZX_SPACE
	DEFB	ZX_PERIOD
	DEFB	ZX_M
	DEFB	ZX_N
	DEFB	ZX_B



; THE 'SHIFTED' CHARACTER CODES



mark_00A5:
K_SHIFT:
	DEFB	ZX_COLON	; :
	DEFB	ZX_SEMICOLON	; ;
	DEFB	ZX_QUERY	; ?
	DEFB	ZX_SLASH	; /
	DEFB	ZX_STOP
	DEFB	ZX_LPRINT
	DEFB	ZX_SLOW
	DEFB	ZX_FAST
	DEFB	ZX_LLIST
	DEFB	$C0		; ""
	DEFB	ZX_OR
	DEFB	ZX_STEP
	DEFB	$DB		; <=
	DEFB	$DD		; <>
	DEFB	ZX_EDIT
	DEFB	ZX_AND
	DEFB	ZX_THEN
	DEFB	ZX_TO
	DEFB	$72		; cursor-left
	DEFB	ZX_RUBOUT
	DEFB	ZX_GRAPHICS
	DEFB	$73		; cursor-right
	DEFB	$70		; cursor-up
	DEFB	$71		; cursor-down
	DEFB	ZX_QUOTE	; "
	DEFB	$11		; )
	DEFB	$10		; (
	DEFB	ZX_DOLLAR	; $
	DEFB	$DC		; >=
	DEFB	ZX_FUNCTION
	DEFB	ZX_EQUAL
	DEFB	ZX_PLUS
	DEFB	ZX_MINUS
	DEFB	ZX_POWER	; **
	DEFB	ZX_POUND	; � 
	DEFB	ZX_COMMA	; ,
	DEFB	ZX_GREATER_THAN	; >
	DEFB	ZX_LESS_THAN	; <
	DEFB	ZX_STAR		; *


; THE 'FUNCTION' CHARACTER CODES



mark_00CC:
K_FUNCT:
	DEFB	ZX_LN
	DEFB	ZX_EXP
	DEFB	ZX_AT
	DEFB	ZX_KL
	DEFB	ZX_ASN
	DEFB	ZX_ACS
	DEFB	ZX_ATN
	DEFB	ZX_SGN
	DEFB	ZX_ABS
	DEFB	ZX_SIN
	DEFB	ZX_COS
	DEFB	ZX_TAN
	DEFB	ZX_INT
	DEFB	ZX_RND
	DEFB	ZX_KL
	DEFB	ZX_KL
	DEFB	ZX_KL
	DEFB	ZX_KL
	DEFB	ZX_KL
	DEFB	ZX_KL
	DEFB	ZX_KL
	DEFB	ZX_KL
	DEFB	ZX_KL
	DEFB	ZX_KL
	DEFB	ZX_TAB
	DEFB	ZX_PEEK
	DEFB	ZX_CODE
	DEFB	ZX_CHR_STR	;	CHR$
	DEFB	ZX_STR_STR	;	STR$
	DEFB	ZX_KL
	DEFB	ZX_USR
	DEFB	ZX_LEN
	DEFB	ZX_VAL
	DEFB	ZX_SQR
	DEFB	ZX_KL
	DEFB	ZX_KL
	DEFB	ZX_PI
	DEFB	ZX_NOT
	DEFB	ZX_INKEY_STR



; THE 'GRAPHIC' CHARACTER CODES



mark_00F3:
K_GRAPH:
	DEFB	$08		; graphic
	DEFB	$0A		; graphic
	DEFB	$09		; graphic
	DEFB	$8A		; graphic
	DEFB	$89		; graphic

	DEFB	$81		; graphic
	DEFB	$82		; graphic
	DEFB	$07		; graphic
	DEFB	$84		; graphic
	DEFB	$06		; graphic

	DEFB	$01		; graphic
	DEFB	$02		; graphic
	DEFB	$87		; graphic
	DEFB	$04		; graphic
	DEFB	$05		; graphic

	DEFB	ZX_RUBOUT
	DEFB	ZX_KL
	DEFB	$85		; graphic
	DEFB	$03		; graphic
	DEFB	$83		; graphic

	DEFB	$8B		; graphic
	DEFB	$91		; inverse )
	DEFB	$90		; inverse (
	DEFB	$8D		; inverse $
	DEFB	$86		; graphic

	DEFB	ZX_KL
	DEFB	$92		; inverse >
	DEFB	$95		; inverse +
	DEFB	$96		; inverse -
	DEFB	$88		; graphic


; THE 'TOKEN' TABLES



mark_0111:
TOKEN_TABLE:
	DEFB	ZX_QUERY						+$80; '?'
	DEFB	ZX_QUOTE,	ZX_QUOTE				+$80; ""
	DEFB	ZX_A,	ZX_T						+$80; AT
	DEFB	ZX_T,	ZX_A,	ZX_B					+$80; TAB
	DEFB	ZX_QUERY						+$80; '?'
	DEFB	ZX_C,	ZX_O,	ZX_D,	ZX_E				+$80; CODE
	DEFB	ZX_V,	ZX_A,	ZX_L					+$80; VAL
	DEFB	ZX_L,	ZX_E,	ZX_N					+$80; LEN
	DEFB	ZX_S,	ZX_I,	ZX_N					+$80; SIN
	DEFB	ZX_C,	ZX_O,	ZX_S					+$80; COS
	DEFB	ZX_T,	ZX_A,	ZX_N					+$80; TAN
	DEFB	ZX_A,	ZX_S,	ZX_N					+$80; ASN
	DEFB	ZX_A,	ZX_C,	ZX_S					+$80; ACS
	DEFB	ZX_A,	ZX_T,	ZX_N					+$80; ATN
	DEFB	ZX_L,	ZX_N						+$80; LN
	DEFB	ZX_E,	ZX_X,	ZX_P					+$80; EXP
	DEFB	ZX_I,	ZX_N,	ZX_T					+$80; INT
	DEFB	ZX_S,	ZX_Q,	ZX_R					+$80; SQR
	DEFB	ZX_S,	ZX_G,	ZX_N					+$80; SGN
	DEFB	ZX_A,	ZX_B,	ZX_S					+$80; ABS
	DEFB	ZX_P,	ZX_E,	ZX_E,	ZX_K				+$80; PEEK
	DEFB	ZX_U,	ZX_S,	ZX_R					+$80; USR
	DEFB	ZX_S,	ZX_T,	ZX_R,	ZX_DOLLAR			+$80; STR$
	DEFB	ZX_C,	ZX_H,	ZX_R,	ZX_DOLLAR			+$80; CHR$
	DEFB	ZX_N,	ZX_O,	ZX_T					+$80; NOT
	DEFB	ZX_STAR,	ZX_STAR					+$80; **
	DEFB	ZX_O,	ZX_R						+$80; OR
	DEFB	ZX_A,	ZX_N,	ZX_D					+$80; AND
	DEFB	ZX_LESS_THAN,		ZX_EQUAL			+$80; >=
	DEFB	ZX_GREATER_THAN,	ZX_EQUAL			+$80; <=
	DEFB	ZX_LESS_THAN,		ZX_GREATER_THAN			+$80; ><
	DEFB	ZX_T,	ZX_H,	ZX_E,	ZX_N				+$80; THEN
	DEFB	ZX_T,	ZX_O						+$80; TO
	DEFB	ZX_S,	ZX_T,	ZX_E,	ZX_P				+$80; STEP
	DEFB	ZX_L,	ZX_P,	ZX_R,	ZX_I,	ZX_N,	ZX_T		+$80; LPRINT
	DEFB	ZX_L,	ZX_L,	ZX_I,	ZX_S,	ZX_T			+$80; LLIST
	DEFB	ZX_S,	ZX_T,	ZX_O,	ZX_P				+$80; STOP
	DEFB	ZX_S,	ZX_L,	ZX_O,	ZX_W				+$80; SLOW
	DEFB	ZX_F,	ZX_A,	ZX_S,	ZX_T				+$80; FAST
	DEFB	ZX_N,	ZX_E,	ZX_W					+$80; NEW
	DEFB	ZX_S,	ZX_C,	ZX_R,	ZX_O,	ZX_L,	ZX_L		+$80; SCROLL
	DEFB	ZX_C,	ZX_O,	ZX_N,	ZX_T				+$80; CONT
	DEFB	ZX_D,	ZX_I,	ZX_M					+$80; DIM
	DEFB	ZX_R,	ZX_E,	ZX_M					+$80; REM
	DEFB	ZX_F,	ZX_O,	ZX_R					+$80; FOR
	DEFB	ZX_G,	ZX_O,	ZX_T,	ZX_O				+$80; GOTO
	DEFB	ZX_G,	ZX_O,	ZX_S,	ZX_U,	ZX_B			+$80; GOSUB
	DEFB	ZX_I,	ZX_N,	ZX_P,	ZX_U,	ZX_T			+$80; INPUT
	DEFB	ZX_L,	ZX_O,	ZX_A,	ZX_D				+$80; LOAD
	DEFB	ZX_L,	ZX_I,	ZX_S,	ZX_T				+$80; LIST
	DEFB	ZX_L,	ZX_E,	ZX_T					+$80; LET
	DEFB	ZX_P,	ZX_A,	ZX_U,	ZX_S,	ZX_E			+$80; PAUSE
	DEFB	ZX_N,	ZX_E,	ZX_X,	ZX_T				+$80; NEXT
	DEFB	ZX_P,	ZX_O,	ZX_K,	ZX_E				+$80; POKE
	DEFB	ZX_P,	ZX_R,	ZX_I,	ZX_N,	ZX_T			+$80; PRINT
	DEFB	ZX_P,	ZX_L,	ZX_O,	ZX_T				+$80; PLOT
	DEFB	ZX_R,	ZX_U,	ZX_N					+$80; RUN
	DEFB	ZX_S,	ZX_A,	ZX_V,	ZX_E				+$80; SAVE
	DEFB	ZX_R,	ZX_A,	ZX_N,	ZX_D				+$80; RAND
	DEFB	ZX_I,	ZX_F						+$80; IF
	DEFB	ZX_C,	ZX_L,	ZX_S					+$80; CLS
	DEFB	ZX_U,	ZX_N,	ZX_P,	ZX_L,	ZX_O,	ZX_T		+$80; UNPLOT
	DEFB	ZX_C,	ZX_L,	ZX_E,	ZX_A,	ZX_R			+$80; CLEAR
	DEFB	ZX_R,	ZX_E,	ZX_T,	ZX_U,	ZX_R,	ZX_N		+$80; RETURN
	DEFB	ZX_C,	ZX_O,	ZX_P,	ZX_Y				+$80; COPY
	DEFB	ZX_R,	ZX_N,	ZX_D					+$80; RND
	DEFB	ZX_I,	ZX_N,	ZX_K,	ZX_E,	ZX_Y,	ZX_DOLLAR	+$80; INKEY$
	DEFB	ZX_P,	ZX_I						+$80; PI


; THE 'LOAD_SAVE UPDATE' ROUTINE

;
;

mark_01FC:
LOAD_SAVE:
	INC	HL		;
	EX	DE,HL		;
	LD	HL,(E_LINE)	; system variable edit line E_LINE.
	SCF			; set carry flag
	SBC	HL,DE		;
	EX	DE,HL		;
	RET	NC		; return if more bytes to LOAD_SAVE.

	POP	HL		; else drop return address


; THE 'DISPLAY' ROUTINES

;
;

mark_0207:
SLOW_FAST:
	LD	HL,CDFLAG	; Address the system variable CDFLAG.
	LD	A,(HL)		; Load value to the accumulator.
	RLA			; rotate bit 6 to position 7.
	XOR	(HL)		; exclusive or with original bit 7.
	RLA			; rotate result out to carry.
	RET	NC		; return if both bits were the same.

;	Now test if this really is a ZX81 or a ZX80 running the upgraded ROM.
;	The standard ZX80 did not have an NMI generator.

	LD	A,$7F		; Load accumulator with %011111111
	EX	AF,AF'		; save in AF'

	LD	B,17		; A counter within which an NMI should occur
				; if this is a ZX81.
	OUT	(IO_PORT_NMI_GEN_ON),A	; start the NMI generator.

;	Note that if this is a ZX81 then the NMI will increment AF'.

mark_0216:
LOOP_11:

	DJNZ	LOOP_11		; self loop to give the NMI a chance to kick in.
				; = 16*13 clock cycles + 8 = 216 clock cycles.

	OUT	(IO_PORT_NMI_GEN_OFF),A	; Turn off the NMI generator.
	EX	AF,AF'		; bring back the AF' value.
	RLA			; test bit 7.
	JR	NC,NO_SLOW	; forward, if bit 7 is still reset, to NO_SLOW.

;	If the AF' was incremented then the NMI generator works and SLOW mode can
;	be set.

	SET	7,(HL)		; Indicate SLOW mode - Compute and Display.

	PUSH	AF		; *		Save Main Registers
	PUSH	BC		; **
	PUSH	DE		; ***
	PUSH	HL		; ****

	JR	DISPLAY_1	; skip forward - to DISPLAY_1.

; ___

mark_0226:
NO_SLOW:
	RES	6,(HL)		; reset bit 6 of CDFLAG.
	RET			; return.


; THE 'MAIN DISPLAY' LOOP

; This routine is executed once for every frame displayed.

mark_0229:
DISPLAY_1:

	LD	HL,(FRAMES)	; fetch two-byte system variable FRAMES.
	DEC	HL		; decrement frames counter.
mark_022D:
DISPLAY_P:
	LD	A,$7F		; prepare a mask
	AND	H		; pick up bits 6-0 of H.
	OR	L		; and any bits of L.
	LD	A,H		; reload A with all bits of H for PAUSE test.

;	Note both branches must take the same time.

	JR	NZ,ANOTHER	; (12/7) forward if bits 14-0 are not zero 
				; to ANOTHER

	RLA			; (4) test bit 15 of FRAMES.
	JR	OVER_NC		; (12) forward with result to OVER_NC

; ___

mark_0237:
ANOTHER:
	LD	B,(HL)		; (7) Note. Harmless Nonsensical Timing weight.
	SCF			; (4) Set Carry Flag.

; Note. the branch to here takes either (12)(7)(4) cyles or (7)(4)(12) cycles.

mark_0239:
OVER_NC:
	LD	H,A		; (4)	set H to zero
	LD	(FRAMES),HL	; (16) update system variable FRAMES 
	RET	NC		; (11/5) return if FRAMES is in use by PAUSE 
				; command.

mark_023E:
DISPLAY_2:
	CALL	KEYBOARD	; gets the key row in H and the column in L. 
				; Reading the ports also starts
				; the TV frame synchronization pulse. (VSYNC)

	LD	BC,(LAST_K)	; fetch the last key values
	LD	(LAST_K),HL	; update LAST_K with new values.

	LD	A,B		; load A with previous column - will be $FF if
				; there was no key.
	ADD	A,2		; adding two will set carry if no previous key.

	SBC	HL,BC		; subtract with the carry the two key values.

; If the same key value has been returned twice then HL will be zero.

	LD	A,(DEBOUNCE_VAR)
	OR	H		; and OR with both bytes of the difference
	OR	L		; setting the zero flag for the upcoming branch.

	LD	E,B		; transfer the column value to E
	LD	B,11		; and load B with eleven 

	LD	HL,CDFLAG	; address system variable CDFLAG
	RES	0,(HL)		; reset the rightmost bit of CDFLAG
	JR	NZ,NO_KEY	; skip forward if debounce/diff >0 to NO_KEY

	BIT	7,(HL)		; test compute and display bit of CDFLAG
	SET	0,(HL)		; set the rightmost bit of CDFLAG.
	RET	Z		; return if bit 7 indicated fast mode.

	DEC	B		; (4) decrement the counter.
	NOP			; (4) Timing - 4 clock cycles. ??
	SCF			; (4) Set Carry Flag

mark_0264:
NO_KEY:

	LD	HL,DEBOUNCE_VAR	;
	CCF			; Complement Carry Flag
	RL	B		; rotate left B picking up carry
				;	C<-76543210<-C






mark_026A:
LOOP_B:

	DJNZ	LOOP_B		; self-loop while B>0 to LOOP_B

	LD	B,(HL)		; fetch value of DEBOUNCE_VAR to B
	LD	A,E		; transfer column value
	CP	$FE		;
	SBC	A,A		; A = A-A-C = 0-Carry
if 1
; I think this truncating DEBOUNCE_VAR 
; which would explain why the VSYNC time didn't match
; my calculations that assumed debouncing for 255 loops.
;
;
	LD	B,$1F		; binary 000 11111
	OR	(HL)		;
	AND	B		; truncate column, 0 to 31
endif
	RRA			;
	LD	(HL),A		;

	OUT	(IO_PORT_SCREEN),A	; end the TV frame synchronization pulse.

	LD	HL,(D_FILE)	; (12) set HL to the Display File from D_FILE
	SET	7,H		; (8) set bit 15 to address the echo display.

	CALL	DISPLAY_3	; (17) routine DISPLAY_3 displays the top set 
				; of blank lines.


; THE 'VIDEO_1' ROUTINE


mark_0281:
R_IX_1:
	LD	A,R		; (9)	Harmless Nonsensical Timing
				;	or something very clever?
	LD	BC,25*256+1	; (10)	25 lines, 1 scanline in first. ($1901)

; 32 characters, use $F5 (i.e. minus 11)
; 40 characters, use $ED (i.e. minus 19)
;

mark_0286:
	LD	A,277-CHARS_PER_LINE_WINDOW	; $F5 for 6.5MHz clocked machines
				; (7)	This value will be loaded into R and 
				; ensures that the cycle starts at the right 
				; part of the display	- after last character 
				; position.

	CALL	DISPLAY_5	; (17) routine DISPLAY_5 completes the current 
				; blank line and then generates the display of 
				; the live picture using INT interrupts
				; The final interrupt returns to the next 
				; address.
R_IX_1_LAST_NEWLINE:
	DEC	HL		; point HL to the last NEWLINE/HALT.

	CALL	DISPLAY_3	; displays the bottom set of blank lines.

; ___

mark_028F:
R_IX_2:
	JP	DISPLAY_1	; JUMP back to DISPLAY_1


; THE 'DISPLAY BLANK LINES' ROUTINE 

;	This subroutine is called twice (see above) to generate first the blank 
;	lines at the top of the television display and then the blank lines at the
;	bottom of the display. 
;
;	It is actually pretty bad.
;	PAL or NTSC = 312 or 
;   1 to   5 = 5 long and 5 short sync
;   6 to  23 = blank
;  24 to 309 = image
; 310 to 312 = 6 short sync
;
; The ZX80 generates either 62 or 110 blank lines
;
; 262 - 31 - 31 = 200
; 312 - 55 - 55 = 202
;
; This does not include 'VSYNC' line periods.
;

mark_0292:
DISPLAY_3:
	POP	IX		; pop the return address to IX register.
				; will be either R_IX_1 or R_IX_2 - see above.

	LD	C,(IY+MARGIN-RAMBASE)	; load C with value of system constant MARGIN.
	BIT	7,(IY+CDFLAG-RAMBASE)	; test CDFLAG for compute and display.
	JR	Z,DISPLAY_4	; forward, with FAST mode, to DISPLAY_4

	LD	A,C		; move MARGIN to A	- 31d or 55d.
	NEG			; Negate
	INC	A		;
	EX	AF,AF'		; place negative count of blank lines in A'

	OUT	(IO_PORT_NMI_GEN_ON),A	; enable the NMI generator.

	POP	HL		; ****
	POP	DE		; ***
	POP	BC		; **
	POP	AF		; *		Restore Main Registers

	RET			; return - end of interrupt.	Return is to 
				; user's program - BASIC or machine code.
				; which will be interrupted by every NMI.


; THE 'FAST MODE' ROUTINES


mark_02A9:

DISPLAY_4:

	LD	A,284-CHARS_PER_LINE_WINDOW	; $FC for 6.5MHz clocked machines
				; (7)	load A with first R delay value

	LD	B,1		; (7)	one row only.

	CALL	DISPLAY_5	; (17) routine DISPLAY_5

	DEC	HL		; (6)	point back to the HALT.
	EX	(SP),HL		; (19) Harmless Nonsensical Timing if paired.
	EX	(SP),HL		; (19) Harmless Nonsensical Timing.
	JP	(IX)		; (8)	to R_IX_1 or R_IX_2


; THE 'DISPLAY_5' SUBROUTINE

;	This subroutine is called from SLOW mode and FAST mode to generate the 
;	central TV picture. With SLOW mode the R register is incremented, with
;	each instruction, to $F7 by the time it completes.	With fast mode, the 
;	final R value will be $FF and an interrupt will occur as soon as the 
;	Program Counter reaches the HALT.	(24 clock cycles)

mark_02B5:
DISPLAY_5:
	LD	R,A		; (9) Load R from A.	R = slow: $F5 fast: $FC

;; Original, for 32 column display:
;;
;;	LD	A,$DD		; (7) load future R value.	$F6	$FD
;;
;; For other display widths,
;; need to count down three instructions then the number of characters
;;
	LD	A,256-3-CHARS_PER_LINE_WINDOW	; (7) load future R value.	$F6	$FD

	EI			; (4) Enable Interrupts		$F7	$FE

	JP	(HL)		; (4) jump to the echo display.	$F8	$FF


; THE 'KEYBOARD SCANNING' SUBROUTINE

; The keyboard is read during the vertical sync interval while no video is 
; being displayed.	Reading a port with address bit 0 low i.e. $FE starts the 
; vertical sync pulse.

mark_02BB:
KEYBOARD:
	LD	HL,$FFFF	; (16) prepare a buffer to take key.
	LD	BC,$FEFE	; (20) set BC to port $FEFE. The B register, 
				;	with its single reset bit also acts as 
				;	an 8-counter.
	IN	A,(C)		; (11) read the port - all 16 bits are put on 
				;	the address bus.	Start VSYNC pulse.
	OR	$01		; (7)	set the rightmost bit so as to ignore 
				;	the SHIFT key.

mark_02C5:
EACH_LINE:
	OR	$E0		; [7] OR %11100000
	LD	D,A		; [4] transfer to D.
	CPL			; [4] complement - only bits 4-0 meaningful now.
	CP	1		; [7] sets carry if A is zero.
	SBC	A,A		; [4] $FF if $00 else zero.
	OR	B		; [7] $FF or port FE,FD,FB....
	AND	L		; [4] unless more than one key, L will still be 
				;	$FF. if more than one key is pressed then A is 
				;	now invalid.
	LD	L,A		; [4] transfer to L.

; now consider the column identifier.

	LD	A,H		; [4] will be $FF if no previous keys.
	AND	D		; [4] 111xxxxx
	LD	H,A		; [4] transfer A to H

; since only one key may be pressed, H will, if valid, be one of
; 11111110, 11111101, 11111011, 11110111, 11101111
; reading from the outer column, say Q, to the inner column, say T.

	RLC	B		; [8]	rotate the 8-counter/port address.
				;	sets carry if more to do.
	IN	A,(C)		; [10] read another half-row.
				;	all five bits this time.

	JR	C,EACH_LINE	; [12](7) loop back, until done, to EACH_LINE

;	The last row read is SHIFT,Z,X,C,V	for the second time.

	RRA			; (4) test the shift key - carry will be reset
				;	if the key is pressed.
	RL	H		; (8) rotate left H picking up the carry giving
				;	column values -
				;	$FD, $FB, $F7, $EF, $DF.
				;	or $FC, $FA, $F6, $EE, $DE if shifted.

;	We now have H identifying the column and L identifying the row in the
;	keyboard matrix.

;	This is a good time to test if this is an American or British machine.
;	The US machine has an extra diode that causes bit 6 of a byte read from
;	a port to be reset.

	RLA			; (4) compensate for the shift test.
	RLA			; (4) rotate bit 7 out.
	RLA			; (4) test bit 6.

	SBC	A,A		; (4)		$FF or 0 {USA}
	AND	$18		; (7)		24 or 0
	ADD	A,31		; (7)		55 or 31

;	result is either 31 (USA) or 55 (UK) blank lines above and below the TV 
;	picture.

	LD	(MARGIN),A	; (13) update system variable MARGIN

	RET			; (10) return


; THE 'SET FAST MODE' SUBROUTINE

;
;

mark_02E7:
SET_FAST:
	BIT	7,(IY+CDFLAG-RAMBASE)
	RET	Z		;

	HALT			; Wait for Interrupt
	OUT	(IO_PORT_NMI_GEN_OFF),A	;
	RES	7,(IY+CDFLAG-RAMBASE)
	RET			; return.



; THE 'REPORT_F'


mark_02F4:
REPORT_F:
	RST	_ERROR_1
	DEFB	$0E		; Error Report: No Program Name supplied.


; THE 'SAVE COMMAND' ROUTINE

;
;

mark_02F6:
SAVE:
	CALL	NAME
	JR	C,REPORT_F	; back with null name

	EX	DE,HL		;




;
; The next 6 bytes differ
;
if NOT_BODGED
; what ZASM assembled:
; 02FC: 11CB12
	LD	DE,$12CB	; five seconds timing value (4811 decimal)
; 02FF: CD460F
mark_02FF:
HEADER:
	CALL	BREAK_1

else
; what the SG ROM disassembled to:
;	02FC   ED;FD
			LDIR			; Patch tape SAVE
;	02FE   C3;07;02
			JP	SLOW_FAST	; to $0207
;	0301   0F
			RRCA
endif


mark_0302:
	JR	NC,BREAK_2

mark_0304:
DELAY_1:
	DJNZ	DELAY_1

	DEC	DE		;
	LD	A,D		;
	OR	E		;
	JR	NZ,HEADER	; back for delay to HEADER

mark_030B:
OUT_NAME:
	CALL	OUT_BYTE
	BIT	7,(HL)		; test for inverted bit.
	INC	HL		; address next character of name.
	JR	Z,OUT_NAME	; back if not inverted to OUT_NAME

; now start saving the system variables onwards.

	LD	HL,VERSN	; set start of area to VERSN thereby
				; preserving RAMTOP etc.

mark_0316:
OUT_PROG:
	CALL	OUT_BYTE

	CALL	LOAD_SAVE	; 			>>
	JR	OUT_PROG	; loop back


; THE 'OUT_BYTE' SUBROUTINE

; This subroutine outputs a byte a bit at a time to a domestic tape recorder.

mark_031E:
OUT_BYTE:
	LD	E,(HL)		; fetch byte to be saved.
	SCF			; set carry flag - as a marker.

mark_0320:
EACH_BIT:
	RL	E		; C < 76543210 < C
	RET	Z		; return when the marker bit has passed 
				; right through.			>>

	SBC	A,A		; $FF if set bit or $00 with no carry.
	AND	$05		; $05 "  "   "   "  $00
	ADD	A,$04		; $09 "  "   "   "  $04
	LD	C,A		; transfer timer to C. a set bit has a longer
				; pulse than a reset bit.

mark_0329:
PULSES:
	OUT	(IO_PORT_TAPE),A	; pulse to cassette.
	LD	B,$23		; set timing constant

mark_032D:
DELAY_2:
	DJNZ	DELAY_2		; self-loop

	CALL	BREAK_1		; test for BREAK key.

mark_0332:
BREAK_2:
	JR	NC,REPORT_D	; forward with break to REPORT_D

	LD	B,$1E		; set timing value.

mark_0336:
DELAY_3:

	DJNZ	DELAY_3		; self-loop

	DEC	C		; decrement counter
	JR	NZ,PULSES	; loop back

mark_033B:
DELAY_4:
	AND	A		; clear carry for next bit test.
	DJNZ	DELAY_4		; self loop (B is zero - 256)

	JR	EACH_BIT	; loop back


; THE 'LOAD COMMAND' ROUTINE


mark_0340:
LOAD:
	CALL	NAME

; DE points to start of name in RAM.

	RL	D		; pick up carry 
	RRC	D		; carry now in bit 7.

mark_0347:



if NOT_BODGED

LNEXT_PROG:
	CALL	IN_BYTE
	JR	LNEXT_PROG	; loop


; THE 'IN_BYTE' SUBROUTINE


mark_034C:
IN_BYTE:
	LD	C,$01		; prepare an eight counter 00000001.

mark_034E:
NEXT_BIT:
	LD	B,$00		; set counter to 256

else
; what the SG ROM has:
;0347   EB
			EX DE,HL            ; NEXT-PROG
;0348   ED;FC
			LDIR                ; Patch tape LOAD
;034A   C3;07;02
			JP SLOW_FAST
;034D   01;06;00
			LD BC,6          
endif




mark_0350:
BREAK_3:
	LD	A,$7F		; read the keyboard row 
	IN	A,(IO_PORT_KEYBOARD_RD)	; with the SPACE key.

	OUT	(IO_PORT_SCREEN),A	; output signal to screen.

	RRA			; test for SPACE pressed.
	JR	NC,BREAK_4	; forward if so to BREAK_4

	RLA			; reverse above rotation
	RLA			; test tape bit.
	JR	C,GET_BIT	; forward if set to GET_BIT

	DJNZ	BREAK_3		; loop back

	POP	AF		; drop the return address.
	CP	D		; ugh.

mark_0361:
RESTART:
	JP	NC,INITIAL	; jump forward to INITIAL if D is zero 
				; to reset the system
				; if the tape signal has timed out for example
				; if the tape is stopped. Not just a simple 
				; report as some system variables will have
				; been overwritten.

	LD	H,D		; else transfer the start of name
	LD	L,E		; to the HL register

mark_0366:
IN_NAME:
	CALL	IN_BYTE		; is sort of recursion for name
				; part. received byte in C.
	BIT	7,D		; is name the null string ?
	LD	A,C		; transfer byte to A.
	JR	NZ,MATCHING	; forward with null string

	CP	(HL)		; else compare with string in memory.
	JR	NZ,LNEXT_PROG	; back with mis-match
				; (seemingly out of subroutine but return 
				; address has been dropped).


mark_0371:
MATCHING:
	INC	HL		; address next character of name
	RLA			; test for inverted bit.
	JR	NC,IN_NAME	; back if not

; the name has been matched in full. 
; proceed to load the data but first increment the high byte of E_LINE, which
; is one of the system variables to be loaded in. Since the low byte is loaded
; before the high byte, it is possible that, at the in-between stage, a false
; value could cause the load to end prematurely - see	LOAD_SAVE check.

	INC	(IY+E_LINE_hi-RAMBASE)	; increment E_LINE_hi.
	LD	HL,VERSN	; start loading at VERSN.

mark_037B:
IN_PROG:
	LD	D,B		; set D to zero as indicator.
	CALL	IN_BYTE		; loads a byte
	LD	(HL),C		; insert assembled byte in memory.
	CALL	LOAD_SAVE		; 		>>
	JR	IN_PROG		; loop back

; ___

; this branch assembles a full byte before exiting normally
; from the IN_BYTE subroutine.

mark_0385:
GET_BIT:
	PUSH	DE		; save the 
	LD	E,$94		; timing value.

mark_0388:
TRAILER:
	LD	B,26		; counter to twenty six.

mark_038A:
COUNTER:
	DEC	E		; decrement the measuring timer.
	IN	A,(IO_PORT_KEYBOARD_RD)	; read the tape input
	RLA			;
	BIT	7,E		;
	LD	A,E		;
	JR	C,TRAILER	; loop back with carry to TRAILER

	DJNZ	COUNTER

	POP	DE		;
	JR	NZ,BIT_DONE

	CP	$56		;
	JR	NC,NEXT_BIT

mark_039C:
BIT_DONE:
	CCF			; complement carry flag
	RL	C		;
	JR	NC,NEXT_BIT

	RET			; return with full byte.

; ___

; if break is pressed while loading data then perform a reset.
; if break pressed while waiting for program on tape then OK to break.

mark_03A2:
BREAK_4:
	LD	A,D		; transfer indicator to A.
	AND	A		; test for zero.
	JR	Z,RESTART	; back if so


mark_03A6:
REPORT_D:
	RST	_ERROR_1
	DEFB	$0C		; Error Report: BREAK - CONT repeats


; THE 'PROGRAM NAME' SUBROUTINE


mark_03A8:
NAME:
	CALL	SCANNING
	LD	A,(FLAGS)	; sv
	ADD	A,A		;
	JP	M,REPORT_C

	POP	HL		;
	RET	NC		;

	PUSH	HL		;
	CALL	SET_FAST
	CALL	STK_FETCH
	LD	H,D		;
	LD	L,E		;
	DEC	C		;
	RET	M		;

	ADD	HL,BC		;
	SET	7,(HL)		;
	RET			;


; THE 'NEW' COMMAND ROUTINE


mark_03C3:
NEW:
	CALL	SET_FAST
	LD	BC,(RAMTOP)	; fetch value of system variable RAMTOP
	DEC	BC		; point to last system byte.


; THE 'RAM CHECK' ROUTINE


mark_03CB:
RAM_CHECK:
	LD	H,B		;
	LD	L,C		;
	LD	A,$3F		;

mark_03CF:
RAM_FILL:
	LD	(HL),$02	;
	DEC	HL		;
	CP	H		;
	JR	NZ,RAM_FILL

mark_03D5:
RAM_READ:
	AND	A		;
	SBC	HL,BC		;
	ADD	HL,BC		;
	INC	HL		;
	JR	NC,SET_TOP

	DEC	(HL)		;
	JR	Z,SET_TOP

	DEC	(HL)		;
	JR	Z,RAM_READ

mark_03E2:
SET_TOP:
	LD	(RAMTOP),HL	; set system variable RAMTOP to first byte 
				; above the BASIC system area.


; THE 'INITIALIZATION' ROUTINE


mark_03E5:
INITIAL:
	LD	HL,(RAMTOP)	; fetch system variable RAMTOP.
	DEC	HL		; point to last system byte.
	LD	(HL),$3E	; make GO SUB end-marker $3E - too high for
				; high order byte of line number.
				; (was $3F on ZX80)
	DEC	HL		; point to unimportant low-order byte.
	LD	SP,HL		; and initialize the stack-pointer to this
				; location.
	DEC	HL		; point to first location on the machine stack
	DEC	HL		; which will be filled by next CALL/PUSH.
	LD	(ERR_SP),HL	; set the error stack pointer ERR_SP to
				; the base of the now empty machine stack.

; Now set the I register so that the video hardware knows where to find the
; character set. This ROM only uses the character set when printing to 
; the ZX Printer. The TV picture is formed by the external video hardware. 
; Consider also, that this 8K ROM can be retro-fitted to the ZX80 instead of 
; its original 4K ROM so the video hardware could be on the ZX80.

	LD	A,$1E		; address for this ROM is $1E00.
	LD	I,A		; set I register from A.
	IM	1		; select Z80 Interrupt Mode 1.

	LD	IY,ERR_NR	; set IY to the start of RAM so that the 
				; system variables can be indexed.

	LD	(IY+CDFLAG-RAMBASE),%01000000
				; Bit 6 indicates Compute and Display required.

	LD	HL,USER_RAM	; The first location after System Variables -
				; 16509 decimal.
	LD	(D_FILE),HL	; set system variable D_FILE to this value.
	LD	B,$19		; prepare minimal screen of 24 NEWLINEs
				; following an initial NEWLINE.

mark_0408:
LINE:
	LD	(HL),ZX_NEWLINE	; insert NEWLINE (HALT instruction)
	INC	HL		; point to next location.
	DJNZ	LINE		; loop back for all twenty five to LINE

	LD	(VARS),HL	; set system variable VARS to next location

	CALL	CLEAR		; sets $80 end-marker and the 
				; dynamic memory pointers E_LINE, STKBOT and
				; STKEND.

mark_0413:
N_L_ONLY:
	CALL	CURSOR_IN	; inserts the cursor and 
				; end-marker in the Edit Line also setting
				; size of lower display to two lines.

	CALL	SLOW_FAST	; selects COMPUTE and DISPLAY


; THE 'BASIC LISTING' SECTION


mark_0419:
UPPER:
	CALL	CLS
	LD	HL,(E_PPC)	; sv
	LD	DE,(S_TOP)	; sv
	AND	A		;
	SBC	HL,DE		;
	EX	DE,HL		;
	JR	NC,ADDR_TOP

	ADD	HL,DE		;
	LD	(S_TOP),HL	; sv

mark_042D:
ADDR_TOP:
	CALL	LINE_ADDR
	JR	Z,LIST_TOP

	EX	DE,HL		;

mark_0433:
LIST_TOP:
	CALL	LIST_PROG
	DEC	(IY+BERG-RAMBASE)
	JR	NZ,LOWER

	LD	HL,(E_PPC)	; sv
	CALL	LINE_ADDR
	LD	HL,(CH_ADD)	; sv
	SCF			; Set Carry Flag
	SBC	HL,DE		;
	LD	HL,S_TOP	; sv
	JR	NC,INC_LINE

	EX	DE,HL		;
	LD	A,(HL)		;
	INC	HL		;
	LDI			;
	LD	(DE),A		;
	JR	UPPER
; ___

mark_0454:
DOWN_KEY:

	LD	HL,E_PPC	; sv

mark_0457:
INC_LINE:
	LD	E,(HL)		;
	INC	HL		;
	LD	D,(HL)		;
	PUSH	HL		;
	EX	DE,HL		;
	INC	HL		;
	CALL	LINE_ADDR
	CALL	LINE_NUM
	POP	HL		;

mark_0464:
KEY_INPUT:
	BIT	5,(IY+FLAGX-RAMBASE)
	JR	NZ,LOWER	; forward

	LD	(HL),D		;
	DEC	HL		;
	LD	(HL),E		;
	JR	UPPER


; THE 'EDIT LINE COPY' SECTION

; This routine sets the edit line to just the cursor when
; 1) There is not enough memory to edit a BASIC line.
; 2) The edit key is used during input.
; The entry point LOWER


mark_046F:
EDIT_INP:
	CALL	CURSOR_IN	; sets cursor only edit line.

; ->

mark_0472:
LOWER:
	LD	HL,(E_LINE)	; fetch edit line start from E_LINE.

mark_0475:
EACH_CHAR:
	LD	A,(HL)		; fetch a character from edit line.
	CP	$7E		; compare to the number marker.
	JR	NZ,END_LINE	; forward if not

	LD	BC,6		; else six invisible bytes to be removed.
	CALL	RECLAIM_2
	JR	EACH_CHAR	; back
; ___

mark_0482:
END_LINE:
	CP	ZX_NEWLINE		;
	INC	HL		;
	JR	NZ,EACH_CHAR

mark_0487:
EDIT_LINE:
	CALL	CURSOR		; sets cursor K or L.

mark_048A:
EDIT_ROOM:
	CALL	LINE_ENDS
	LD	HL,(E_LINE)	; sv
	LD	(IY+ERR_NR-RAMBASE),$FF
	CALL	COPY_LINE
	BIT	7,(IY+ERR_NR-RAMBASE)
	JR	NZ,DISPLAY_6

	LD	A,(DF_SZ)	; 
	CP	CHARS_VERTICAL	; $18 = 24
	JR	NC,DISPLAY_6

	INC	A		;
	LD	(DF_SZ),A	; 
	LD	B,A		;
	LD	C,1		;
	CALL	LOC_ADDR
	LD	D,H		;
	LD	E,L		;
	LD	A,(HL)		;

mark_04B1:
FREE_LINE:
	DEC	HL		;
	CP	(HL)		;
	JR	NZ,FREE_LINE

	INC	HL		;
	EX	DE,HL		;
	LD	A,(RAMTOP+1)	; sv RAMTOP_hi
	CP	$4D		;
	CALL	C,RECLAIM_1
	JR	EDIT_ROOM


; THE 'WAIT FOR KEY' SECTION


mark_04C1:
DISPLAY_6:
	LD	HL,$0000	;
	LD	(X_PTR),HL	; sv

	LD	HL,CDFLAG	; system variable CDFLAG




if NOT_BODGED
	BIT	7,(HL)		;

	CALL	Z,DISPLAY_1

mark_04CF:
SLOW_DISP:
	BIT	0,(HL)		;
	JR	Z,SLOW_DISP

else
;	04CA   D3;00
			OUT ($00),A         ; PORT 0
;	04CC   CB;46
L04CC:
			BIT 0,(HL)           
;	04CE   28;FC
			JR Z,L04CC
;	04D0   D3;01
			OUT ($01),A         ; PORT 1
;	04D2   00
			NOP


endif




	LD	BC,(LAST_K)	; sv
	CALL	DEBOUNCE
	CALL	DECODE

	JR	NC,LOWER	; back


; THE 'KEYBOARD DECODING' SECTION

;	The decoded key value is in E and HL points to the position in the 
;	key table. D contains zero.

mark_04DF:
K_DECODE:
	LD	A,(MODE)	; Fetch value of system variable MODE
	DEC	A		; test the three values together

	JP	M,FETCH_2	; forward, if was zero

	JR	NZ,FETCH_1	; forward, if was 2

;	The original value was one and is now zero.

	LD	(MODE),A	; update the system variable MODE

	DEC	E		; reduce E to range $00 - $7F
	LD	A,E		; place in A
	SUB	39		; subtract 39 setting carry if range 00 - 38
	JR	C,FUNC_BASE	; forward, if so

	LD	E,A		; else set E to reduced value

mark_04F2:
FUNC_BASE:
	LD	HL,K_FUNCT	; address of K_FUNCT table for function keys.
	JR	TABLE_ADD	; forward
; ___
mark_04F7:
FETCH_1:
	LD	A,(HL)		;
	CP	ZX_NEWLINE	;
	JR	Z,K_L_KEY

	CP	ZX_RND		; $40
	SET	7,A		;
	JR	C,ENTER

	LD	HL,$00C7	; (expr reqd)

mark_0505:
TABLE_ADD:
	ADD	HL,DE		;
	JR	FETCH_3

; ___

mark_0508:
FETCH_2:
	LD	A,(HL)		;
	BIT	2,(IY+FLAGS-RAMBASE)	; K or L mode ?
	JR	NZ,TEST_CURS

	ADD	A,$C0		;
	CP	$E6		;
	JR	NC,TEST_CURS

mark_0515:
FETCH_3:
	LD	A,(HL)		;

mark_0516:
TEST_CURS:
	CP	$F0		;
	JP	PE,KEY_SORT

mark_051B:
ENTER:
	LD	E,A		;
	CALL	CURSOR

	LD	A,E		;
	CALL	ADD_CHAR

mark_0523:
BACK_NEXT:
	JP	LOWER		; back


; THE 'ADD CHARACTER' SUBROUTINE

mark_0526:
ADD_CHAR:
	CALL	ONE_SPACE
	LD	(DE),A		;
	RET			;


; THE 'CURSOR KEYS' ROUTINE

mark_052B:
K_L_KEY:
	LD	A,ZX_KL		;

mark_052D:
KEY_SORT:
	LD	E,A		;
	LD	HL,$0482	; base address of ED_KEYS (exp reqd)
	ADD	HL,DE		;
	ADD	HL,DE		;
	LD	C,(HL)		;
	INC	HL		;
	LD	B,(HL)		;
	PUSH	BC		;

mark_0537:
CURSOR:
	LD	HL,(E_LINE)	; sv
	BIT	5,(IY+FLAGX-RAMBASE)
	JR	NZ,L_MODE

mark_0540:
K_MODE:
	RES	2,(IY+FLAGS-RAMBASE)	; Signal use K mode

mark_0544:
TEST_CHAR:
	LD	A,(HL)		;
	CP	ZX_CURSOR	;
	RET	Z		; return

	INC	HL		;
	CALL	NUMBER
	JR	Z,TEST_CHAR

	CP	ZX_A		; $26
	JR	C,TEST_CHAR

	CP	$DE		; ZX_THEN ??
	JR	Z,K_MODE

mark_0556:
L_MODE:
	SET	2,(IY+FLAGS-RAMBASE)	; Signal use L mode
	JR	TEST_CHAR


; THE 'CLEAR_ONE' SUBROUTINE

mark_055C:
CLEAR_ONE:
	LD	BC,$0001	;
	JP	RECLAIM_2


; THE 'EDITING KEYS' TABLE

mark_0562:
ED_KEYS:
	DEFW	UP_KEY
	DEFW	DOWN_KEY
	DEFW	LEFT_KEY
	DEFW	RIGHT_KEY
	DEFW	FUNCTION
	DEFW	EDIT_KEY
	DEFW	N_L_KEY
	DEFW	RUBOUT
	DEFW	FUNCTION
	DEFW	FUNCTION



; THE 'CURSOR LEFT' ROUTINE

;
;

mark_LEFT_KEY:
LEFT_KEY:
	CALL	LEFT_EDGE
	LD	A,(HL)		;
	LD	(HL),ZX_CURSOR	;
	INC	HL		;
	JR	GET_CODE


; THE 'CURSOR RIGHT' ROUTINE


mark_RIGHT_KEY:
RIGHT_KEY:
	INC	HL		;
	LD	A,(HL)		;
	CP	ZX_NEWLINE		;
	JR	Z,ENDED_2

	LD	(HL),ZX_CURSOR	;
	DEC	HL		;

mark_0588:
GET_CODE:
	LD	(HL),A		;

mark_0589:
ENDED_1:
	JR	BACK_NEXT


; THE 'RUBOUT' ROUTINE


mark_058B:
RUBOUT:
	CALL	LEFT_EDGE
	CALL	CLEAR_ONE
	JR	ENDED_1


; THE 'ED_EDGE' SUBROUTINE

;
;

mark_0593:
LEFT_EDGE:
	DEC	HL		;
	LD	DE,(E_LINE)	; sv
	LD	A,(DE)		;
	CP	ZX_CURSOR	;
	RET	NZ		;

	POP	DE		;

mark_059D:
ENDED_2:
	JR	ENDED_1


; THE 'CURSOR UP' ROUTINE

;
;

mark_059F:
UP_KEY:
	LD	HL,(E_PPC)	; sv
	CALL	LINE_ADDR
	EX	DE,HL		;
	CALL	LINE_NUM
	LD	HL,E_PPC+1	; point to system variable E_PPC_hi
	JP	KEY_INPUT	; jump back


; THE 'FUNCTION KEY' ROUTINE

;
;

mark_FUNCTION:
FUNCTION:
	LD	A,E		;
	AND	$07		;
	LD	(MODE),A	; sv
	JR	ENDED_2		; back


; THE 'COLLECT LINE NUMBER' SUBROUTINE

mark_05B7:
ZERO_DE:
	EX	DE,HL		;
	LD	DE,DISPLAY_6 + 1	; $04C2 - a location addressing two zeros.

; ->

mark_05BB:
LINE_NUM:
	LD	A,(HL)		;
	AND	$C0		;
	JR	NZ,ZERO_DE

	LD	D,(HL)		;
	INC	HL		;
	LD	E,(HL)		;
	RET			;


; THE 'EDIT KEY' ROUTINE


mark_EDIT_KEY:
EDIT_KEY:
	CALL	LINE_ENDS	; clears lower display.

	LD	HL,EDIT_INP	; Address: EDIT_INP
	PUSH	HL		; ** is pushed as an error looping address.

	BIT	5,(IY+FLAGX-RAMBASE)	; test FLAGX
	RET	NZ		; indirect jump if in input mode
				; to EDIT_INP (begin again).

;

	LD	HL,(E_LINE)	; fetch E_LINE
	LD	(DF_CC),HL	; and use to update the screen cursor DF_CC

; so now RST $10 will print the line numbers to the edit line instead of screen.
; first make sure that no newline/out of screen can occur while sprinting the
; line numbers to the edit line.

				; prepare line 0, column 0.

	LD	HL,256*CHARS_VERTICAL + CHARS_HORIZONTAL + 1
;
	LD	(S_POSN),HL	; update S_POSN with these dummy values.

	LD	HL,(E_PPC)	; fetch current line from E_PPC may be a 
				; non-existent line e.g. last line deleted.
	CALL	LINE_ADDR	; gets address or that of
				; the following line.
	CALL	LINE_NUM	; gets line number if any in DE
				; leaving HL pointing at second low byte.

	LD	A,D		; test the line number for zero.
	OR	E		;
	RET	Z		; return if no line number - no program to edit.

	DEC	HL		; point to high byte.
	CALL	OUT_NO		; writes number to edit line.

	INC	HL		; point to length bytes.
	LD	C,(HL)		; low byte to C.
	INC	HL		;
	LD	B,(HL)		; high byte to B.

	INC	HL		; point to first character in line.
	LD	DE,(DF_CC)	; fetch display file cursor DF_CC

	LD	A,ZX_CURSOR	; prepare the cursor character.
	LD	(DE),A		; and insert in edit line.
	INC	DE		; increment intended destination.

	PUSH	HL		; * save start of BASIC.

	LD	HL,29		; set an overhead of 29 bytes.
	ADD	HL,DE		; add in the address of cursor.
	ADD	HL,BC		; add the length of the line.
	SBC	HL,SP		; subtract the stack pointer.

	POP	HL		; * restore pointer to start of BASIC.

	RET	NC		; return if not enough room to EDIT_INP EDIT_INP.
				; the edit key appears not to work.

	LDIR			; else copy bytes from program to edit line.
				; Note. hidden floating point forms are also
				; copied to edit line.

	EX	DE,HL		; transfer free location pointer to HL

	POP	DE		; ** remove address EDIT_INP from stack.

	CALL	SET_STK_B	; sets STKEND from HL.

	JR	ENDED_2		; back to ENDED_2 and after 3 more jumps
				; to LOWER, LOWER.
				; Note. The LOWER routine removes the hidden 
				; floating-point numbers from the edit line.


; THE 'NEWLINE KEY' ROUTINE


mark_060C:
N_L_KEY:
	CALL	LINE_ENDS

	LD	HL,LOWER	; prepare address: LOWER

	BIT	5,(IY+FLAGX-RAMBASE)
	JR	NZ,NOW_SCAN

	LD	HL,(E_LINE)	; sv
	LD	A,(HL)		;
	CP	$FF		;
	JR	Z,STK_UPPER

	CALL	CLEAR_PRB
	CALL	CLS

mark_0626:
STK_UPPER:
	LD	HL,UPPER	; Address: UPPER

mark_0629:
NOW_SCAN:
	PUSH	HL		; push routine address (LOWER or UPPER).
	CALL	LINE_SCAN
	POP	HL		;
	CALL	CURSOR
	CALL	CLEAR_ONE
	CALL	E_LINE_NUM
	JR	NZ,N_L_INP

	LD	A,B		;
	OR	C		;
	JP	NZ,N_L_LINE

	DEC	BC		;
	DEC	BC		;
	LD	(PPC),BC	; sv
	LD	(IY+DF_SZ-RAMBASE),2
	LD	DE,(D_FILE)	; sv

	JR	TEST_NULL	; forward

; ___

mark_064E:
N_L_INP:
	CP	ZX_NEWLINE	;
	JR	Z,N_L_NULL

	LD	BC,(T_ADDR)	; 
	CALL	LOC_ADDR
	LD	DE,(NXTLIN)	; 
	LD	(IY+DF_SZ-RAMBASE),2

mark_0661:
TEST_NULL:
	RST	_GET_CHAR
	CP	ZX_NEWLINE	;

mark_0664:
N_L_NULL:
	JP	Z,N_L_ONLY

	LD	(IY+FLAGS-RAMBASE),$80
	EX	DE,HL		;

mark_066C:
NEXT_LINE:
	LD	(NXTLIN),HL	; 
	EX	DE,HL		;
	CALL	TEMP_PTR2
	CALL	LINE_RUN
	RES	1,(IY+FLAGS-RAMBASE)	; Signal printer not in use
	LD	A,$C0		;
;;	LD	(IY+X_PTR_lo-RAMBASE),A		;; ERROR IN htm SOURCE! IY+$19 is X_PTR_hi
	LD	(IY+X_PTR_hi-RAMBASE),A
	CALL	X_TEMP
	RES	5,(IY+FLAGX-RAMBASE)
	BIT	7,(IY+ERR_NR-RAMBASE)
	JR	Z,STOP_LINE

	LD	HL,(NXTLIN)	;
	AND	(HL)		;
	JR	NZ,STOP_LINE

	LD	D,(HL)		;
	INC	HL		;
	LD	E,(HL)		;
	LD	(PPC),DE	;
	INC	HL		;
	LD	E,(HL)		;
	INC	HL		;
	LD	D,(HL)		;
	INC	HL		;
	EX	DE,HL		;
	ADD	HL,DE		;
	CALL	BREAK_1
	JR	C,NEXT_LINE

	LD	HL,ERR_NR
	BIT	7,(HL)
	JR	Z,STOP_LINE

	LD	(HL),$0C

mark_06AE:
STOP_LINE:
	BIT	7,(IY+PR_CC-RAMBASE)
	CALL	Z,COPY_BUFF
;
if 0
	LD	BC,$0121	;
else
	LD	BC,256*1 + CHARS_HORIZONTAL + 1
endif
;
;
	CALL	LOC_ADDR
	LD	A,(ERR_NR)
	LD	BC,(PPC)
	INC	A
	JR	Z,REPORT

	CP	$09
	JR	NZ,CONTINUE

	INC	BC

mark_06CA:
CONTINUE:
	LD	(OLDPPC),BC	;
	JR	NZ,REPORT

	DEC	BC		;

mark_06D1:
REPORT:
	CALL	OUT_CODE
	LD	A,ZX_SLASH

	RST	_PRINT_A
	CALL	OUT_NUM
	CALL	CURSOR_IN
	JP	DISPLAY_6

; ___

mark_06E0:
N_L_LINE:
	LD	(E_PPC),BC	;
	LD	HL,(CH_ADD)	;
	EX	DE,HL		;
	LD	HL,N_L_ONLY
	PUSH	HL		;
	LD	HL,(STKBOT)	;
	SBC	HL,DE		;
	PUSH	HL		;
	PUSH	BC		;
	CALL	SET_FAST
	CALL	CLS
	POP	HL		;
	CALL	LINE_ADDR
	JR	NZ,COPY_OVER

	CALL	NEXT_ONE
	CALL	RECLAIM_2

mark_0705:
COPY_OVER:
	POP	BC		;
	LD	A,C		;
	DEC	A		;
	OR	B		;
	RET	Z		;

	PUSH	BC		;
	INC	BC		;
	INC	BC		;
	INC	BC		;
	INC	BC		;
	DEC	HL		;
	CALL	MAKE_ROOM
	CALL	SLOW_FAST
	POP	BC		;
	PUSH	BC		;
	INC	DE		;
	LD	HL,(STKBOT)	;
	DEC	HL		;
	LDDR			; copy bytes
	LD	HL,(E_PPC)	;
	EX	DE,HL		;
	POP	BC		;
	LD	(HL),B		;
	DEC	HL		;
	LD	(HL),C		;
	DEC	HL		;
	LD	(HL),E		;
	DEC	HL		;
	LD	(HL),D		;

	RET			; return.


; THE 'LIST' AND 'LLIST' COMMAND ROUTINES


mark_072C:
LLIST:
	SET	1,(IY+FLAGS-RAMBASE)	; signal printer in use

mark_0730:
LIST:
	CALL	FIND_INT

	LD	A,B		; fetch high byte of user-supplied line number.
	AND	$3F		; and crudely limit to range 1-16383.

	LD	H,A		;
	LD	L,C		;
	LD	(E_PPC),HL	;
	CALL	LINE_ADDR

mark_073E:
LIST_PROG:
	LD	E,$00		;

mark_0740:
UNTIL_END:
	CALL	OUT_LINE	; lists one line of BASIC
				; making an early return when the screen is
				; full or the end of program is reached.
	JR	UNTIL_END	; loop back to UNTIL_END


; THE 'PRINT A BASIC LINE' SUBROUTINE


mark_0745:
OUT_LINE:
	LD	BC,(E_PPC)	; sv
	CALL	CP_LINES
	LD	D,$92		;
	JR	Z,TEST_END

	LD	DE,$0000	;
	RL	E		;

mark_0755:
TEST_END:
	LD	(IY+BERG-RAMBASE),E
	LD	A,(HL)		;
	CP	$40		;
	POP	BC		;
	RET	NC		;

	PUSH	BC		;
	CALL	OUT_NO
	INC	HL		;
	LD	A,D		;

	RST	_PRINT_A
	INC	HL		;
	INC	HL		;

mark_0766:
COPY_LINE:
	LD	(CH_ADD),HL	;
	SET	0,(IY+FLAGS-RAMBASE)	; Suppress leading space

mark_076D:
MORE_LINE:
	LD	BC,(X_PTR)	;
	LD	HL,(CH_ADD)	;
	AND	A		;
	SBC	HL,BC		;
	JR	NZ,TEST_NUM

	LD	A,ZX_INV_S	; $B8	; 

	RST	_PRINT_A

mark_077C:
TEST_NUM:
	LD	HL,(CH_ADD)	;
	LD	A,(HL)		;
	INC	HL		;
	CALL	NUMBER
	LD	(CH_ADD),HL	;
	JR	Z,MORE_LINE

	CP	ZX_CURSOR	;
	JR	Z,OUT_CURS

	CP	ZX_NEWLINE		;
	JR	Z,OUT_CH

	BIT	6,A		;
	JR	Z,NOT_TOKEN

	CALL	TOKENS
	JR	MORE_LINE
; ___

mark_079A:
NOT_TOKEN:
	RST	_PRINT_A
	JR	MORE_LINE
; ___

mark_079D:
OUT_CURS:
	LD	A,(MODE)	; Fetch value of system variable MODE
	LD	B,$AB		; Prepare an inverse [F] for function cursor.

	AND	A		; Test for zero -
	JR	NZ,FLAGS_2	; forward if not to FLAGS_2

	LD	A,(FLAGS)	; Fetch system variable FLAGS.
	LD	B,ZX_INV_K	; Prepare an inverse [K] for keyword cursor.

mark_07AA:
FLAGS_2:
	RRA			; 00000?00 -> 000000?0
	RRA			; 000000?0 -> 0000000?
	AND	$01		; 0000000?	0000000x

	ADD	A,B		; Possibly [F] -> [G]	or	[K] -> [L]

	CALL	PRINT_SP
	JR	MORE_LINE


; THE 'NUMBER' SUBROUTINE


mark_07B4:
NUMBER:
	CP	$7E		;
	RET	NZ		;

	INC	HL		;
	INC	HL		;
	INC	HL		;
	INC	HL		;
	INC	HL		;
	RET			;


; THE 'KEYBOARD DECODE' SUBROUTINE


mark_07BD:
DECODE:
	LD	D,0		;
	SRA	B		; shift bit from B to Carry
	SBC	A,A		; A = 0 - Carry
	OR	$26		; %00100110
	LD	L,5		;
	SUB	L		;

mark_07C7:
KEY_LINE:
	ADD	A,L		;
	SCF			; Set Carry Flag
	RR	C		;
	JR	C,KEY_LINE

	INC	C		;
	RET	NZ		;

	LD	C,B		;
	DEC	L		;
	LD	L,1		;
	JR	NZ,KEY_LINE

	LD	HL,$007D	; (expr reqd)
	LD	E,A		;
	ADD	HL,DE		;
	SCF			; Set Carry Flag
	RET			;


; THE 'PRINTING' SUBROUTINE


mark_07DC:
LEAD_SP:
	LD	A,E		;
	AND	A		;
	RET	M		;

	JR	PRINT_CH

; ___
; HL is typically -10000, -1000, -100, -10 
; and repeatedly subtracted from BC
; i.e. it print
;
;
mark_07E1:
OUT_DIGIT:
	XOR	A		; assume the digit is zero to begin with

mark_07E2:
DIGIT_INC:
	ADD	HL,BC		; HL += -ve number
	INC	A		;
	JR	C,DIGIT_INC	; loop

	SBC	HL,BC		; undo last iteration
	DEC	A		; undo last iteration
	JR	Z,LEAD_SP	; leading zeros shown as spaces

mark_07EB:
OUT_CODE:
	LD	E,ZX_0		; $1C
	ADD	A,E		;

mark_07EE:
OUT_CH:
	AND	A		;
	JR	Z,PRINT_SP

mark_07F1:
PRINT_CH:
	RES	0,(IY+FLAGS-RAMBASE)	; signal leading space permitted

mark_07F5:
PRINT_SP:
	EXX			;
	PUSH	HL		;
	BIT	1,(IY+FLAGS-RAMBASE)	; is printer in use ?
	JR	NZ,LPRINT_A

	CALL	ENTER_CH
	JR	PRINT_EXX

; ___

mark_0802:
LPRINT_A:
	CALL	LPRINT_CH

mark_0805:
PRINT_EXX:
	POP	HL		;
	EXX			;
	RET			;

; ___

mark_0808:
ENTER_CH:
	LD	D,A		;
	LD	BC,(S_POSN)	;
	LD	A,C		;
	CP	CHARS_HORIZONTAL+1	;
	JR	Z,TEST_LOW

mark_0812:
TEST_N_L:
	LD	A,ZX_NEWLINE		;
	CP	D		;
	JR	Z,WRITE_N_L

	LD	HL,(DF_CC)	;
	CP	(HL)		;
	LD	A,D		;
	JR	NZ,WRITE_CH

	DEC	C		;
	JR	NZ,EXPAND_1

	INC	HL			;
	LD	(DF_CC),HL		;
	LD	C,CHARS_HORIZONTAL+1	; $21 = 33 normally
	DEC	B			;
	LD	(S_POSN),BC		;

mark_082C:
TEST_LOW:
	LD	A,B		;
	CP	(IY+DF_SZ-RAMBASE)
	JR	Z,REPORT_5

	AND	A		;
	JR	NZ,TEST_N_L

mark_0835:
REPORT_5:
	LD	L,4		; 'No more room on screen'
	JP	ERROR_3

; ___

mark_083A:
EXPAND_1:
	CALL	ONE_SPACE
	EX	DE,HL		;

mark_083E:
WRITE_CH:
	LD	(HL),A		;
	INC	HL		;
	LD	(DF_CC),HL	;
	DEC	(IY+S_POSN_x-RAMBASE)
	RET			;

; ___

mark_0847:
WRITE_N_L:
	LD	C,CHARS_HORIZONTAL+1	; $21 = 33
	DEC	B		;
	SET	0,(IY+FLAGS-RAMBASE)	; Suppress leading space
	JP	LOC_ADDR


; THE 'LPRINT_CH' SUBROUTINE

; This routine sends a character to the ZX-Printer placing the code for the
; character in the Printer Buffer.
; Note. PR_CC contains the low byte of the buffer address. The high order byte 
; is always constant. 


mark_0851:
LPRINT_CH:
	CP	ZX_NEWLINE	; compare to NEWLINE.
	JR	Z,COPY_BUFF	; forward if so

	LD	C,A		; take a copy of the character in C.
	LD	A,(PR_CC)	; fetch print location from PR_CC
	AND	$7F		; ignore bit 7 to form true position.
	CP	$5C		; compare to 33rd location

	LD	L,A		; form low-order byte.
	LD	H,$40		; the high-order byte is fixed.

	CALL	Z,COPY_BUFF	; to send full buffer to 
				; the printer if first 32 bytes full.
				; (this will reset HL to start.)

	LD	(HL),C		; place character at location.
	INC	L		; increment - will not cross a 256 boundary.
	LD	(IY+PR_CC-RAMBASE),L	; update system variable PR_CC
				; automatically resetting bit 7 to show that
				; the buffer is not empty.
	RET			; return.


; THE 'COPY' COMMAND ROUTINE

; The full character-mapped screen is copied to the ZX-Printer.
; All twenty-four text/graphic lines are printed.

mark_0869:
COPY:
;
; check - is this $16==22 or 24?
;
;;	LD	D,$16		; prepare to copy twenty four text lines.
	LD	D,22		; prepare to copy twenty four text lines.
	LD	HL,(D_FILE)	; set HL to start of display file from D_FILE.
	INC	HL		; 
	JR	COPY_D		; forward

; ___

; A single character-mapped printer buffer is copied to the ZX-Printer.

mark_0871:
COPY_BUFF:
	LD	D,1		; prepare to copy a single text line.
	LD	HL,PRBUFF	; set HL to start of printer buffer PRBUFF.

; both paths converge here.

mark_0876:
COPY_D:
	CALL	SET_FAST

	PUSH	BC		; *** preserve BC throughout.
				; a pending character may be present 
				; in C from LPRINT_CH

mark_087A:
COPY_LOOP:
	PUSH	HL		; save first character of line pointer. (*)
	XOR	A		; clear accumulator.
	LD	E,A		; set pixel line count, range 0-7, to zero.

; this inner loop deals with each horizontal pixel line.

mark_087D:
COPY_TIME:
	OUT	(IO_PORT_PRINTER),A	; bit 2 reset starts the printer motor
				; with an inactive stylus - bit 7 reset.
	POP	HL		; pick up first character of line pointer (*)
				; on inner loop.

mark_0880:
COPY_BRK:
	CALL	BREAK_1
	JR	C,COPY_CONT	; forward with no keypress to COPY_CONT

; else A will hold 11111111 0

	RRA			; 0111 1111
	OUT	(IO_PORT_PRINTER),A	; stop ZX printer motor, de-activate stylus.

mark_0888:
REPORT_D2:
	RST	_ERROR_1
	DEFB	$0C		; Error Report: BREAK - CONT repeats

; ___

mark_088A:
COPY_CONT:
	IN	A,(IO_PORT_PRINTER)	; read from printer port.
	ADD	A,A		; test bit 6 and 7
	JP	M,COPY_END	; jump forward with no printer to COPY_END

	JR	NC,COPY_BRK	; back if stylus not in position to COPY_BRK

	PUSH	HL		; save first character of line pointer (*)
	PUSH	DE		; ** preserve character line and pixel line.

	LD	A,D		; text line count to A?
	CP	2		; sets carry if last line.
	SBC	A,A		; now $FF if last line else zero.

; now cleverly prepare a printer control mask setting bit 2 (later moved to 1)
; of D to slow printer for the last two pixel lines ( E = 6 and 7)

	AND	E		; and with pixel line offset 0-7
	RLCA			; shift to left.
	AND	E		; and again.
	LD	D,A		; store control mask in D.

mark_089C:
COPY_NEXT:
	LD	C,(HL)		; load character from screen or buffer.
	LD	A,C		; save a copy in C for later inverse test.
	INC	HL		; update pointer for next time.
	CP	ZX_NEWLINE	; is character a NEWLINE ?
	JR	Z,COPY_N_L	; forward, if so, to COPY_N_L

	PUSH	HL		; * else preserve the character pointer.

	SLA	A		; (?) multiply by two
	ADD	A,A		; multiply by four
	ADD	A,A		; multiply by eight

	LD	H,$0F		; load H with half the address of character set.
	RL	H		; now $1E or $1F (with carry)
	ADD	A,E		; add byte offset 0-7
	LD	L,A		; now HL addresses character source byte

	RL	C		; test character, setting carry if inverse.
	SBC	A,A		; accumulator now $00 if normal, $FF if inverse.

	XOR	(HL)		; combine with bit pattern at end or ROM.
	LD	C,A		; transfer the byte to C.
	LD	B,8		; count eight bits to output.

mark_08B5:
COPY_BITS:
	LD	A,D		; fetch speed control mask from D.
	RLC	C		; rotate a bit from output byte to carry.
	RRA			; pick up in bit 7, speed bit to bit 1
	LD	H,A		; store aligned mask in H register.

mark_08BA:
COPY_WAIT:
	IN	A,(IO_PORT_PRINTER)	; read the printer port
	RRA				; test for alignment signal from encoder.
	JR	NC,COPY_WAIT		; loop if not present to COPY_WAIT

	LD	A,H			; control byte to A.
	OUT	(IO_PORT_PRINTER),A	; and output to printer port.
	DJNZ	COPY_BITS		; loop for all eight bits to COPY_BITS

	POP	HL			; * restore character pointer.
	JR	COPY_NEXT		; back for adjacent character line to COPY_NEXT

; ___

; A NEWLINE has been encountered either following a text line or as the 
; first character of the screen or printer line.

mark_08C7:
COPY_N_L:
	IN	A,(IO_PORT_PRINTER)	; read printer port.
	RRA			; wait for encoder signal.
	JR	NC,COPY_N_L	; loop back if not to COPY_N_L

	LD	A,D		; transfer speed mask to A.
	RRCA			; rotate speed bit to bit 1. 
				; bit 7, stylus control is reset.
	OUT	(IO_PORT_PRINTER),A	; set the printer speed.

	POP	DE		; ** restore character line and pixel line.
	INC	E		; increment pixel line 0-7.
	BIT	3,E		; test if value eight reached.
	JR	Z,COPY_TIME	; back if not

; eight pixel lines, a text line have been completed.

	POP	BC		; lose the now redundant first character 
				; pointer
	DEC	D		; decrease text line count.
	JR	NZ,COPY_LOOP	; back if not zero

	LD	A,$04			; stop the already slowed printer motor.
	OUT	(IO_PORT_PRINTER),A	; output to printer port.

mark_08DE:
COPY_END:
	CALL	SLOW_FAST
	POP	BC		; *** restore preserved BC.


; THE 'CLEAR PRINTER BUFFER' SUBROUTINE

; This subroutine sets 32 bytes of the printer buffer to zero (space) and
; the 33rd character is set to a NEWLINE.
; This occurs after the printer buffer is sent to the printer but in addition
; after the 24 lines of the screen are sent to the printer. 
; Note. This is a logic error as the last operation does not involve the 
; buffer at all. Logically one should be able to use 
; 10 LPRINT "HELLO ";
; 20 COPY
; 30 LPRINT ; "WORLD"
; and expect to see the entire greeting emerge from the printer.
; Surprisingly this logic error was never discovered and although one can argue
; if the above is a bug, the repetition of this error on the Spectrum was most
; definitely a bug.
; Since the printer buffer is fixed at the end of the system variables, and
; the print position is in the range $3C - $5C, then bit 7 of the system
; variable is set to show the buffer is empty and automatically reset when
; the variable is updated with any print position - neat.

mark_08E2:
CLEAR_PRB:
	LD	HL,PRBUFF_END	; address fixed end of PRBUFF
	LD	(HL),ZX_NEWLINE	; place a newline at last position.
	LD	B,32		; prepare to blank 32 preceding characters. 
;
; NB the printer is fixed at 32 characters, maybe it can be tweaked ???
;
mark_08E9:
PRB_BYTES:
	DEC	HL		; decrement address - could be DEC L.
	LD	(HL),0		; place a zero byte.
	DJNZ	PRB_BYTES	; loop for all thirty-two

	LD	A,L		; fetch character print position.
	SET	7,A		; signal the printer buffer is clear.
	LD	(PR_CC),A	; update one-byte system variable PR_CC
	RET			; return.


; THE 'PRINT AT' SUBROUTINE

;
;
;
mark_08F5:
PRINT_AT:

	LD	A,CHARS_VERTICAL-1	; originally 23
	SUB	B		;
	JR	C,WRONG_VAL

mark_08FA:
TEST_VAL:
	CP	(IY+DF_SZ-RAMBASE)
	JP	C,REPORT_5

	INC	A		;
	LD	B,A		;
	LD	A,CHARS_HORIZONTAL-1	; originally 31

	SUB	C		;

mark_0905:
WRONG_VAL:
	JP	C,REPORT_B

	ADD	A,2		;
	LD	C,A		;

mark_090B:
SET_FIELD:
	BIT	1,(IY+FLAGS-RAMBASE)	; Is printer in use?
	JR	Z,LOC_ADDR

	LD	A,$5D		;
	SUB	C		;
	LD	(PR_CC),A	;
	RET			;


; THE 'LOCATE ADDRESS' ROUTINE

;
; I'm guessing this locates the address of a character at X,Y 
; on the screen, with 0,0 being on the bottom left?
; S_POSN_x:    equ $4039
; S_POSN_y:    equ $403A
; so when BC is stored there, B is Y and C is X
;
mark_0918:
LOC_ADDR:
	LD	(S_POSN),BC	;
	LD	HL,(VARS)	;
	LD	D,C		;
	LD	A,CHARS_HORIZONTAL+2	; $22 == 34 originally.
	SUB	C		;
	LD	C,A		;
	LD	A,ZX_NEWLINE	;
	INC	B		;

mark_0927:
LOOK_BACK:
	DEC	HL		;
	CP	(HL)		;
	JR	NZ,LOOK_BACK

	DJNZ	LOOK_BACK

	INC	HL		;
	CPIR			;
	DEC	HL		;
	LD	(DF_CC),HL	;
	SCF			; Set Carry Flag
	RET	PO		;

	DEC	D		;
	RET	Z		;

	PUSH	BC		;
	CALL	MAKE_ROOM
	POP	BC		;
	LD	B,C		;
	LD	H,D		; HL := DE
	LD	L,E		;

mark_0940:
EXPAND_2:
;
; Writes B spaces to HL--
;
	LD	(HL),ZX_SPACE	;
	DEC	HL		;
	DJNZ	EXPAND_2

	EX	DE,HL		; restore HL
	INC	HL		;
	LD	(DF_CC),HL	;
	RET			;


; THE 'EXPAND TOKENS' SUBROUTINE


mark_094B:
TOKENS:
	PUSH	AF		;
	CALL	TOKEN_ADD
	JR	NC,ALL_CHARS

	BIT	0,(IY+FLAGS-RAMBASE)	; Leading space if set
	JR	NZ,ALL_CHARS

	XOR	A		; A = 0 = ZX_SPACE

	RST	_PRINT_A

mark_0959:
ALL_CHARS:
	LD	A,(BC)		;
	AND	$3F		; truncate to printable values ???

	RST	_PRINT_A
	LD	A,(BC)		;
	INC	BC		;
	ADD	A,A		;
	JR	NC,ALL_CHARS

	POP	BC		;
	BIT	7,B		;
	RET	Z		;

	CP	ZX_COMMA	; $1A == 26
	JR	Z,TRAIL_SP

	CP	ZX_S		; $38 == 56
	RET	C		;

mark_096D:
TRAIL_SP:
	XOR	A		;
	SET	0,(IY+FLAGS-RAMBASE)	; Suppress leading space
	JP	PRINT_SP

; ___

mark_0975:
TOKEN_ADD:
	PUSH	HL		;
	LD	HL,TOKEN_TABLE
	BIT	7,A		;
	JR	Z,TEST_HIGH

	AND	$3F		;

mark_097F:
TEST_HIGH:
	CP	$43		;
	JR	NC,FOUND

	LD	B,A		;
	INC	B		;

mark_0985:
WORDS:
	BIT	7,(HL)		;
	INC	HL		;
	JR	Z,WORDS

	DJNZ	WORDS

	BIT	6,A		;
	JR	NZ,COMP_FLAG

	CP	$18		;

mark_0992:
COMP_FLAG:
	CCF			; Complement Carry Flag

mark_0993:
FOUND:
	LD	B,H		;
	LD	C,L		;
	POP	HL		;
	RET	NC		;

	LD	A,(BC)		;
	ADD	A,$E4		;
	RET			;


; THE 'ONE_SPACE' SUBROUTINE


mark_099B:
ONE_SPACE:
	LD	BC,$0001	;


; THE 'MAKE ROOM' SUBROUTINE

;
;

mark_099E:
MAKE_ROOM:
	PUSH	HL		;
	CALL	TEST_ROOM
	POP	HL		;
	CALL	POINTERS
	LD	HL,(STKEND)	;
	EX	DE,HL		;
	LDDR			; Copy Bytes
	RET			;


; THE 'POINTERS' SUBROUTINE


mark_09AD:
POINTERS:
	PUSH	AF		;
	PUSH	HL		;
	LD	HL,D_FILE	;
	LD	A,$09		;

mark_09B4:
NEXT_PTR:
	LD	E,(HL)		;
	INC	HL		;
	LD	D,(HL)		;
	EX	(SP),HL	;
	AND	A		;
	SBC	HL,DE		;
	ADD	HL,DE		;
	EX	(SP),HL	;
	JR	NC,PTR_DONE

	PUSH	DE		;
	EX	DE,HL		;
	ADD	HL,BC		;
	EX	DE,HL		;
	LD	(HL),D		;
	DEC	HL		;
	LD	(HL),E		;
	INC	HL		;
	POP	DE		;

mark_09C8:
PTR_DONE:
	INC	HL		;
	DEC	A		;
	JR	NZ,NEXT_PTR

	EX	DE,HL		;
	POP	DE		;
	POP	AF		;
	AND	A		;
	SBC	HL,DE		;
	LD	B,H		;
	LD	C,L		;
	INC	BC		;
	ADD	HL,DE		;
	EX	DE,HL		;
	RET			;


; THE 'LINE ADDRESS' SUBROUTINE


mark_09D8:
LINE_ADDR:
	PUSH	HL		;
	LD	HL,USER_RAM	;
	LD	D,H		;
	LD	E,L		;

mark_09DE:
NEXT_TEST:
	POP	BC		;
	CALL	CP_LINES
	RET	NC		;

	PUSH	BC		;
	CALL	NEXT_ONE
	EX	DE,HL		;
	JR	NEXT_TEST


; THE 'COMPARE LINE NUMBERS' SUBROUTINE


mark_09EA:
CP_LINES:
	LD	A,(HL)		;
	CP	B		;
	RET	NZ		;

	INC	HL		;
	LD	A,(HL)		;
	DEC	HL		;
	CP	C		;
	RET			;


; THE 'NEXT LINE OR VARIABLE' SUBROUTINE


mark_09F2:
NEXT_ONE:
	PUSH	HL		;
	LD	A,(HL)		;
	CP	$40		;
	JR	C,LINES

	BIT	5,A		;
	JR	Z,NEXT_0_4	; skip forward

	ADD	A,A		;
	JP	M,NEXT_PLUS_FIVE

	CCF			; Complement Carry Flag

mark_0A01:
NEXT_PLUS_FIVE:
	LD	BC,$0005	;
	JR	NC,NEXT_LETT

	LD	C,$11		; 17

mark_0A08:
NEXT_LETT:
	RLA			;
	INC	HL		;
	LD	A,(HL)		;
	JR	NC,NEXT_LETT	; loop 

	JR	NEXT_ADD
; ___

mark_0A0F:
LINES:
	INC	HL		;

mark_0A10:
NEXT_0_4:
	INC	HL		; BC = word at HL++
	LD	C,(HL)		;
	INC	HL		;
	LD	B,(HL)		;
	INC	HL		;

mark_0A15:
NEXT_ADD:
	ADD	HL,BC		;
	POP	DE		;


; THE 'DIFFERENCE' SUBROUTINE


mark_0A17:
DIFFER:
	AND	A		;
	SBC	HL,DE		;
	LD	B,H		; BC := (HL-DE)
	LD	C,L		;
	ADD	HL,DE		;
	EX	DE,HL		; DE := old HL ???
	RET			;


; THE 'LINE_ENDS' SUBROUTINE


mark_0A1F:
LINE_ENDS:
	LD	B,(IY+DF_SZ-RAMBASE)
	PUSH	BC		;
	CALL	B_LINES
	POP	BC		;
	DEC	B		;
	JR	B_LINES


; THE 'CLS' COMMAND ROUTINE


mark_0A2A:
CLS:
	LD	B,CHARS_VERTICAL	; number of lines to clear. $18 = 24 originally.

mark_0A2C:
B_LINES:
	RES	1,(IY+FLAGS-RAMBASE)	; Signal printer not in use
	LD	C,CHARS_HORIZONTAL+1	; $21		; extra 1 is for HALT opcode ?
	PUSH	BC		;
	CALL	LOC_ADDR
	POP	BC		;
	LD	A,(RAMTOP+1)	; is RAMTOP_hi
	CP	$4D		;
	JR	C,COLLAPSED
;
; If RAMTOP less then 4D00, RAM less than D00 = 3.25 K, 
; uses collapsed display.
;

	SET	7,(IY+S_POSN_y-RAMBASE)

mark_0A42:
CLEAR_LOC:
	XOR	A		; prepare a space
	CALL	PRINT_SP	; prints a space
	LD	HL,(S_POSN)	;
	LD	A,L		;
	OR	H		;
	AND	$7E		; 
	JR	NZ,CLEAR_LOC

	JP	LOC_ADDR

; ___

mark_0A52:
COLLAPSED:
	LD	D,H		; DE := HL
	LD	E,L		;
	DEC	HL		;
	LD	C,B		;
	LD	B,0		; Will loop 256 times
	LDIR			; Copy Bytes
	LD	HL,(VARS)	;


; THE 'RECLAIMING' SUBROUTINES


mark_0A5D:
RECLAIM_1:
	CALL	DIFFER

mark_0A60:
RECLAIM_2:
	PUSH	BC		;
	LD	A,B		;
	CPL			;
	LD	B,A		;
	LD	A,C		;
	CPL			;
	LD	C,A		;
	INC	BC		;
	CALL	POINTERS
	EX	DE,HL		;
	POP	HL		;
	ADD	HL,DE		;
	PUSH	DE		;
	LDIR			; Copy Bytes
	POP	HL		;
	RET			;


; THE 'E_LINE NUMBER' SUBROUTINE


mark_0A73:
E_LINE_NUM:
	LD	HL,(E_LINE)	;
	CALL	TEMP_PTR2

	RST	_GET_CHAR
	BIT	5,(IY+FLAGX-RAMBASE)
	RET	NZ		;

	LD	HL,MEM_0_1st	;
	LD	(STKEND),HL	;
	CALL	INT_TO_FP
	CALL	FP_TO_BC
	JR	C,NO_NUMBER	; to NO_NUMBER

	LD	HL,-10000	; $D8F0	; value '-10000'
	ADD	HL,BC		;

mark_0A91:
NO_NUMBER:
	JP	C,REPORT_C	; to REPORT_C

	CP	A		;
	JP	SET_MIN


; THE 'REPORT AND LINE NUMBER' PRINTING SUBROUTINES


mark_0A98:
OUT_NUM:
	PUSH	DE		;
	PUSH	HL		;
	XOR	A		;
	BIT	7,B		;
	JR	NZ,UNITS

	LD	H,B		; HL := BC
	LD	L,C		;
	LD	E,$FF		;
	JR	THOUSAND
; ___

mark_0AA5:
OUT_NO:
	PUSH	DE		;
	LD	D,(HL)		;
	INC	HL		;
	LD	E,(HL)		;
	PUSH	HL		;
	EX	DE,HL		;
	LD	E,ZX_SPACE	; set E to leading space.

mark_0AAD:
THOUSAND:
	LD	BC,-1000	; $FC18	;
	CALL	OUT_DIGIT
	LD	BC,-100		; $FF9C	;
	CALL	OUT_DIGIT
	LD	C,-10		; $F6		; B is already FF, so saves a byte.
	CALL	OUT_DIGIT
	LD	A,L		;

mark_0ABF:
UNITS:
	CALL	OUT_CODE
	POP	HL		;
	POP	DE		;
	RET			;


; THE 'UNSTACK_Z' SUBROUTINE


; This subroutine is used to return early from a routine when checking syntax.
; On the ZX81 the same routines that execute commands also check the syntax
; on line entry. This enables precise placement of the error marker in a line
; that fails syntax.
; The sequence CALL SYNTAX_Z ; RET Z can be replaced by a call to this routine
; although it has not replaced every occurrence of the above two instructions.
; Even on the ZX80 this routine was not fully utilized.

mark_0AC5:
UNSTACK_Z:
	CALL	SYNTAX_Z		; resets the ZERO flag if
				; checking syntax.
	POP	HL		; drop the return address.
	RET	Z		; return to previous calling routine if 
				; checking syntax.

	JP	(HL)		; else jump to the continuation address in
				; the calling routine as RET would have done.


; THE 'LPRINT' COMMAND ROUTINE

;
;

mark_0ACB:
LPRINT:
	SET	1,(IY+FLAGS-RAMBASE)	; Signal printer in use


; THE 'PRINT' COMMAND ROUTINE


mark_0ACF:
PRINT:
	LD	A,(HL)		;
	CP	ZX_NEWLINE		;
	JP	Z,PRINT_END	; to PRINT_END

mark_0AD5:
PRINT_1:
	SUB	ZX_COMMA	; $1A == 26
	ADC	A,$00		; 
	JR	Z,SPACING	; to SPACING
				; 
				; Compare with AT, 
				; less comma recently subtracted.
				; 
	CP	ZX_AT-ZX_COMMA	; $A7 == 167
	JR	NZ,NOT_AT	;


	RST	_NEXT_CHAR
	CALL	CLASS_6
	CP	ZX_COMMA	; $1A = 26
	JP	NZ,REPORT_C	;

	RST	_NEXT_CHAR
	CALL	CLASS_6
	CALL	SYNTAX_ON

	RST	_FP_CALC	;;
	DEFB	__exchange	;;
	DEFB	__end_calc	;;

	CALL	STK_TO_BC
	CALL	PRINT_AT
	JR	PRINT_ON
; ___

mark_0AFA:
NOT_AT:
	CP	ZX_TAB-ZX_COMMA	; $A8 == 168
	JR	NZ,NOT_TAB


	RST	_NEXT_CHAR
	CALL	CLASS_6
	CALL	SYNTAX_ON
	CALL	STK_TO_A
	JP	NZ,REPORT_B

	AND	$1F		; truncate to 0 to 31 characters ???
	LD	C,A		;
	BIT	1,(IY+FLAGS-RAMBASE)	; Is printer in use
	JR	Z,TAB_TEST

	SUB	(IY+PR_CC-RAMBASE)
	SET	7,A		;
	ADD	A,$3C		; 60
	CALL	NC,COPY_BUFF

mark_0B1E:
TAB_TEST:
	ADD	A,(IY+S_POSN_x-RAMBASE)	; screen position X
	CP	CHARS_HORIZONTAL+1	; 33 (characters horizontal plus newline ???)
	LD	A,(S_POSN_y)		; screen position Y
	SBC	A,1			;
	CALL	TEST_VAL
	SET	0,(IY+FLAGS-RAMBASE)	; sv FLAGS	- Suppress leading space
	JR	PRINT_ON
; ___

mark_0B31:
NOT_TAB:
	CALL	SCANNING
	CALL	PRINT_STK

mark_0B37:
PRINT_ON:
	RST	_GET_CHAR
	SUB	ZX_COMMA	;  $1A
	ADC	A,0		;
	JR	Z,SPACING

	CALL	CHECK_END
	JP	PRINT_END
; ___
mark_0B44:
SPACING:
	CALL	NC,FIELD

	RST	_NEXT_CHAR
	CP	ZX_NEWLINE	;
	RET	Z		;

	JP	PRINT_1
; ___
mark_0B4E:
SYNTAX_ON:
	CALL	SYNTAX_Z
	RET	NZ		;

	POP	HL		;
	JR	PRINT_ON
; ___
mark_0B55:
PRINT_STK:
	CALL	UNSTACK_Z
	BIT	6,(IY+FLAGS-RAMBASE)	; Numeric or string result?
	CALL	Z,STK_FETCH
	JR	Z,PR_STR_4

	JP	PRINT_FP		; jump forward
; ___

mark_0B64:
PR_STR_1:
	LD	A,ZX_QUOTE	; $0B

mark_0B66:
PR_STR_2:
	RST	_PRINT_A

mark_0B67:
PR_STR_3:
	LD	DE,(X_PTR)	;

mark_0B6B:
PR_STR_4:
	LD	A,B		;
	OR	C		;
	DEC	BC		;
	RET	Z		;

	LD	A,(DE)		;
	INC	DE		;
	LD	(X_PTR),DE	;
	BIT	6,A		;
	JR	Z,PR_STR_2

	CP	$C0		;
	JR	Z,PR_STR_1

	PUSH	BC		;
	CALL	TOKENS
	POP	BC		;
	JR	PR_STR_3

; ___

mark_0B84:
PRINT_END:
	CALL	UNSTACK_Z
	LD	A,ZX_NEWLINE		;

	RST	_PRINT_A
	RET			;

; ___

mark_0B8B:
FIELD:
	CALL	UNSTACK_Z
	SET	0,(IY+FLAGS-RAMBASE)	; Suppress leading space
	XOR	A		;

	RST	_PRINT_A
	LD	BC,(S_POSN)	;
	LD	A,C		;
	BIT	1,(IY+FLAGS-RAMBASE)	; Is printer in use
	JR	Z,CENTRE

	LD	A,$5D		;
	SUB	(IY+PR_CC-RAMBASE)

mark_0BA4:
CENTRE:
	LD	C,$11		;
	CP	C		;
	JR	NC,RIGHT

	LD	C,$01		;

mark_0BAB:
RIGHT:
	CALL	SET_FIELD
	RET			;


; THE 'PLOT AND UNPLOT' COMMAND ROUTINES


mark_0BAF:
PLOT_UNPLOT:
;
; Of the 24 lines, only top 22 ar used for plotting.
;
	CALL	STK_TO_BC
	LD	(COORDS_x),BC	;
;;	LD	A,$2B		; originally $2B == 32+11 = 43 = 2*22-1
	LD	A,2*(CHARS_VERTICAL-2)-1	; 
	SUB	B		;
	JP	C,REPORT_B

	LD	B,A		;
	LD	A,$01		;
	SRA	B		;
	JR	NC,COLUMNS

	LD	A,$04		;

mark_0BC5:
COLUMNS:
	SRA	C		;
	JR	NC,FIND_ADDR

	RLCA			;

mark_0BCA:
FIND_ADDR:
	PUSH	AF		;
	CALL	PRINT_AT
	LD	A,(HL)		;
	RLCA			;
	CP	ZX_BRACKET_LEFT	; $10
	JR	NC,TABLE_PTR

	RRCA			;
	JR	NC,SQ_SAVED

	XOR	$8F		;

mark_0BD9:
SQ_SAVED:
	LD	B,A		;

mark_0BDA:
TABLE_PTR:
	LD	DE,P_UNPLOT	; Address: P_UNPLOT
	LD	A,(T_ADDR)	; get T_ADDR_lo
	SUB	E		;
	JP	M,PLOT

	POP	AF		;
	CPL			;
	AND	B		;
	JR	UNPLOT

; ___

mark_0BE9:
PLOT:
	POP	AF		;
	OR	B		;

mark_0BEB:
UNPLOT:
	CP	8		; Only apply to graphic characters (0 to 7)
	JR	C,PLOT_END

	XOR	$8F		; binary 1000 1111

mark_0BF1:
PLOT_END:
	EXX			;

	RST	_PRINT_A
	EXX			;
	RET			;


; THE 'STACK_TO_BC' SUBROUTINE

mark_0BF5:
STK_TO_BC:
	CALL	STK_TO_A
	LD	B,A		;
	PUSH	BC		;
	CALL	STK_TO_A
	LD	E,C		;
	POP	BC		;
	LD	D,C		;
	LD	C,A		;
	RET			;


; THE 'STACK_TO_A' SUBROUTINE


mark_0C02:
STK_TO_A:
	CALL	FP_TO_A
	JP	C,REPORT_B

	LD	C,$01		; 
	RET	Z		;

	LD	C,$FF		;
	RET			;


; THE 'SCROLL' SUBROUTINE


mark_0C0E:
SCROLL:
	LD	B,(IY+DF_SZ-RAMBASE)
	LD	C,CHARS_HORIZONTAL+1		;
	CALL	LOC_ADDR
	CALL	ONE_SPACE
	LD	A,(HL)		;
	LD	(DE),A		;
	INC	(IY+S_POSN_y-RAMBASE)
	LD	HL,(D_FILE)	;
	INC	HL		;
	LD	D,H		;
	LD	E,L		;
	CPIR			;
	JP	RECLAIM_1


; THE 'SYNTAX' TABLES


; i) The Offset table

mark_0C29:
offset_t:
	DEFB	P_LPRINT - $	; 8B offset
	DEFB	P_LLIST - $	; 8D offset
	DEFB	P_STOP - $	; 2D offset
	DEFB	P_SLOW - $	; 7F offset
	DEFB	P_FAST - $	; 81 offset
	DEFB	P_NEW - $	; 49 offset
	DEFB	P_SCROLL - $	; 75 offset
	DEFB	P_CONT - $	; 5F offset
	DEFB	P_DIM - $	; 40 offset
	DEFB	P_REM - $	; 42 offset
	DEFB	P_FOR - $	; 2B offset
	DEFB	P_GOTO - $	; 17 offset
	DEFB	P_GOSUB - $	; 1F offset
	DEFB	P_INPUT - $	; 37 offset
	DEFB	P_LOAD - $	; 52 offset
	DEFB	P_LIST - $	; 45 offset
	DEFB	P_LET - $	; 0F offset
	DEFB	P_PAUSE - $	; 6D offset
	DEFB	P_NEXT - $	; 2B offset
	DEFB	P_POKE - $	; 44 offset
	DEFB	P_PRINT - $	; 2D offset
	DEFB	P_PLOT - $	; 5A offset
	DEFB	P_RUN - $	; 3B offset
	DEFB	P_SAVE - $	; 4C offset
	DEFB	P_RAND - $	; 45 offset
	DEFB	P_IF - $	; 0D offset
	DEFB	P_CLS - $	; 52 offset
	DEFB	P_UNPLOT - $	; 5A offset
	DEFB	P_CLEAR - $	; 4D offset
	DEFB	P_RETURN - $	; 15 offset
	DEFB	P_COPY - $	; 6A offset

; ii) The parameter table.

mark_0C48:
P_LET:
	DEFB	_CLASS_01	; A variable is required.
	DEFB	ZX_EQUAL	; Separator:	'='
	DEFB	_CLASS_02	; An expression, numeric or string,
				; must follow.

mark_0C4B:
P_GOTO:
	DEFB	_CLASS_06	; A numeric expression must follow.
	DEFB	_CLASS_00	; No further operands.
	DEFW	GOTO

mark_0C4F:
P_IF:
	DEFB	_CLASS_06	; A numeric expression must follow.
	DEFB	ZX_THEN		; Separator:	'THEN'
	DEFB	_CLASS_05	; Variable syntax checked entirely
				; by routine.
	DEFW	IF

mark_0C54:
P_GOSUB:
	DEFB	_CLASS_06	; A numeric expression must follow.
	DEFB	_CLASS_00	; No further operands.
	DEFW	GOSUB

mark_0C58:
P_STOP:
	DEFB	_CLASS_00	; No further operands.
	DEFW	STOP

mark_0C5B:
P_RETURN:
	DEFB	_CLASS_00	; No further operands.
	DEFW	RETURN

mark_0C5E:
P_FOR:
	DEFB	_CLASS_04	; A single character variable must
				; follow.
	DEFB	ZX_EQUAL	; Separator:	'='
	DEFB	_CLASS_06	; A numeric expression must follow.
	DEFB	ZX_TO		; Separator:	'TO'
	DEFB	_CLASS_06	; A numeric expression must follow.
	DEFB	_CLASS_05	; Variable syntax checked entirely
				; by routine.
	DEFW	FOR

mark_0C66:
P_NEXT:
	DEFB	_CLASS_04	; A single character variable must
				; follow.
	DEFB	_CLASS_00	; No further operands.
	DEFW	NEXT

mark_0C6A:
P_PRINT:
	DEFB	_CLASS_05	; Variable syntax checked entirely
				; by routine.
	DEFW	PRINT		; not LPRINT ???

mark_0C6D:
P_INPUT:
	DEFB	_CLASS_01	; A variable is required.
	DEFB	_CLASS_00	; No further operands.
	DEFW	INPUT

mark_0C71:
P_DIM:
	DEFB	_CLASS_05	; Variable syntax checked entirely
				; by routine.
	DEFW	DIM

mark_0C74:
P_REM:
	DEFB	_CLASS_05	; Variable syntax checked entirely
				; by routine.
	DEFW	REM

mark_0C77:
P_NEW:
	DEFB	_CLASS_00	; No further operands.
	DEFW	NEW

mark_0C7A:
P_RUN:
	DEFB	_CLASS_03	; A numeric expression may follow
				; else default to zero.
	DEFW	RUN

mark_0C7D:
P_LIST:
	DEFB	_CLASS_03	; A numeric expression may follow
				; else default to zero.
	DEFW	LIST

mark_0C80:
P_POKE:
	DEFB	_CLASS_06	; A numeric expression must follow.
	DEFB	ZX_COMMA	; Separator:	','
	DEFB	_CLASS_06	; A numeric expression must follow.
	DEFB	_CLASS_00	; No further operands.
	DEFW	POKE

mark_0C86:
P_RAND:
	DEFB	_CLASS_03	; A numeric expression may follow
				; else default to zero.
	DEFW	RAND

mark_0C89:
P_LOAD:
	DEFB	_CLASS_05	; Variable syntax checked entirely
				; by routine.
	DEFW	LOAD

mark_0C8C:
P_SAVE:
	DEFB	_CLASS_05	; Variable syntax checked entirely
				; by routine.
	DEFW	SAVE

mark_0C8F:
P_CONT:
	DEFB	_CLASS_00	; No further operands.
	DEFW	CONT

mark_0C92:
P_CLEAR:
	DEFB	_CLASS_00	; No further operands.
	DEFW	CLEAR

mark_0C95:
P_CLS:
	DEFB	_CLASS_00	; No further operands.
	DEFW	CLS

mark_0C98:
P_PLOT:
	DEFB	_CLASS_06	; A numeric expression must follow.
	DEFB	ZX_COMMA	; Separator:	','
	DEFB	_CLASS_06	; A numeric expression must follow.
	DEFB	_CLASS_00	; No further operands.
	DEFW	PLOT_UNPLOT

mark_0C9E:
P_UNPLOT:
	DEFB	_CLASS_06	; A numeric expression must follow.
	DEFB	ZX_COMMA	; Separator:	','
	DEFB	_CLASS_06	; A numeric expression must follow.
	DEFB	_CLASS_00	; No further operands.
	DEFW	PLOT_UNPLOT

mark_0CA4:
P_SCROLL:
	DEFB	_CLASS_00	; No further operands.
	DEFW	SCROLL

mark_0CA7:
P_PAUSE:
	DEFB	_CLASS_06	; A numeric expression must follow.
	DEFB	_CLASS_00	; No further operands.
	DEFW	PAUSE

mark_0CAB:
P_SLOW:
	DEFB	_CLASS_00	; No further operands.
	DEFW	SLOW

mark_0CAE:
P_FAST:
	DEFB	_CLASS_00	; No further operands.
	DEFW	FAST

mark_0CB1:
P_COPY:
	DEFB	_CLASS_00	; No further operands.
	DEFW	COPY

mark_0CB4:
P_LPRINT:
	DEFB	_CLASS_05	; Variable syntax checked entirely
				; by routine.
	DEFW	LPRINT

mark_0CB7:
P_LLIST:
	DEFB	_CLASS_03	; A numeric expression may follow
				; else default to zero.
	DEFW	LLIST



; THE 'LINE SCANNING' ROUTINE


mark_0CBA:
LINE_SCAN:
	LD	(IY+FLAGS-RAMBASE),1
	CALL	E_LINE_NUM

mark_0CC1:
LINE_RUN:
	CALL	SET_MIN
	LD	HL,ERR_NR	;
	LD	(HL),$FF	;
	LD	HL,FLAGX	;
	BIT	5,(HL)		;
	JR	Z,LINE_NULL

	CP	$E3		; 'STOP' ?
	LD	A,(HL)		;
	JP	NZ,INPUT_REP

	CALL	SYNTAX_Z
	RET	Z		;


	RST	_ERROR_1
	DEFB	$0C		; Error Report: BREAK - CONT repeats



; THE 'STOP' COMMAND ROUTINE

;
;

mark_0CDC:
STOP:
	RST	_ERROR_1
	DEFB	$08		; Error Report: STOP statement
; ___

; the interpretation of a line continues with a check for just spaces
; followed by a carriage return.
; The IF command also branches here with a true value to execute the
; statement after the THEN but the statement can be null so
; 10 IF 1 = 1 THEN
; passes syntax (on all ZX computers).

mark_0CDE:
LINE_NULL:
	RST	_GET_CHAR
	LD	B,$00		; prepare to index - early.
	CP	ZX_NEWLINE		; compare to NEWLINE.
	RET	Z		; return if so.





	LD	C,A		; transfer character to C.

	RST	_NEXT_CHAR	; advances.
	LD	A,C		; character to A
	SUB	$E1		; subtract 'LPRINT' - lowest command.
	JR	C,REPORT_C2	; forward if less

	LD	C,A		; reduced token to C
	LD	HL,offset_t	; set HL to address of offset table.
	ADD	HL,BC		; index into offset table.
	LD	C,(HL)		; fetch offset
	ADD	HL,BC		; index into parameter table.
	JR	GET_PARAM
; ___

mark_0CF4:
SCAN_LOOP:
	LD	HL,(T_ADDR)	;

; -> Entry Point to Scanning Loop

mark_0CF7:
GET_PARAM:
	LD	A,(HL)		;
	INC	HL		;
	LD	(T_ADDR),HL	;

	LD	BC,SCAN_LOOP
	PUSH	BC		; is pushed on machine stack.

	LD	C,A		;
	CP	ZX_QUOTE	; $0B
	JR	NC,SEPARATOR

	LD	HL,class_tbl	; class_tbl - the address of the class table.
	LD	B,$00		;
	ADD	HL,BC		;
	LD	C,(HL)		;
	ADD	HL,BC		;
	PUSH	HL		;

	RST	_GET_CHAR
	RET			; indirect jump to class routine and
				; by subsequent RET to SCAN_LOOP.


; THE 'SEPARATOR' ROUTINE


mark_0D10:
SEPARATOR:
	RST	_GET_CHAR
	CP	C		;
	JR	NZ,REPORT_C2
				; 'Nonsense in BASIC'

	RST	_NEXT_CHAR
	RET			; return



; THE 'COMMAND CLASS' TABLE

;
mark_0D16:
class_tbl:
	DEFB	CLASS_0 - $	; 17 offset to; Address: CLASS_0
	DEFB	CLASS_1 - $	; 25 offset to; Address: CLASS_1
	DEFB	CLASS_2 - $	; 53 offset to; Address: CLASS_2
	DEFB	CLASS_3 - $	; 0F offset to; Address: CLASS_3
	DEFB	CLASS_4 - $	; 6B offset to; Address: CLASS_4
	DEFB	CLASS_5 - $	; 13 offset to; Address: CLASS_5
	DEFB	CLASS_6 - $	; 76 offset to; Address: CLASS_6


; THE 'CHECK END' SUBROUTINE

; Check for end of statement and that no spurious characters occur after
; a correctly parsed statement. Since only one statement is allowed on each
; line, the only character that may follow a statement is a NEWLINE.
;
mark_0D1D:
CHECK_END:
	CALL	SYNTAX_Z
	RET	NZ		; return in runtime.

	POP	BC		; else drop return address.

mark_0D22:
CHECK_2:
	LD	A,(HL)		; fetch character.
	CP	ZX_NEWLINE	; compare to NEWLINE.
	RET	Z		; return if so.

mark_0D26:
REPORT_C2:
	JR	REPORT_C
				; 'Nonsense in BASIC'


; COMMAND CLASSES 03, 00, 05


mark_0D28:
CLASS_3:
	CP	ZX_NEWLINE		;
	CALL	NUMBER_TO_STK

mark_0D2D:
CLASS_0:
	CP	A		;

mark_0D2E:
CLASS_5:
	POP	BC		;
	CALL	Z,CHECK_END
	EX	DE,HL		;
	LD	HL,(T_ADDR)	;
	LD	C,(HL)		;
	INC	HL		;
	LD	B,(HL)		;
	EX	DE,HL		;

mark_0D3A:
CLASS_END:
	PUSH	BC		;
	RET			;


; COMMAND CLASSES 01, 02, 04, 06


mark_0D3C:
CLASS_1:
	CALL	LOOK_VARS

mark_0D3F:
CLASS_4_2:
	LD	(IY+FLAGX-RAMBASE),$00
	JR	NC,SET_STK

	SET	1,(IY+FLAGX-RAMBASE)
	JR	NZ,SET_STRLN


mark_0D4B:
REPORT_2:
	RST	_ERROR_1
	DEFB	$01		; Error Report: Variable not found
; ___

mark_0D4D:
SET_STK:
	CALL	Z,STK_VAR
	BIT	6,(IY+FLAGS-RAMBASE)	; Numeric or string result?
	JR	NZ,SET_STRLN

	XOR	A		;
	CALL	SYNTAX_Z
	CALL	NZ,STK_FETCH
	LD	HL,FLAGX	; 
	OR	(HL)		;
	LD	(HL),A		;
	EX	DE,HL		;

mark_0D63:
SET_STRLN:
	LD	(STRLEN),BC	;
	LD	(DEST),HL	; 

; THE 'REM' COMMAND ROUTINE

mark_0D6A:
REM:
	RET			;

; ___

mark_0D6B:
CLASS_2:
	POP	BC		;
	LD	A,(FLAGS)	; sv

mark_0D6F:
INPUT_REP:
	PUSH	AF		;
	CALL	SCANNING
	POP	AF		;
	LD	BC,LET	; Address: LET
	LD	D,(IY+FLAGS-RAMBASE)
	XOR	D		;
	AND	$40		;
	JR	NZ,REPORT_C	; to REPORT_C

	BIT	7,D		;
	JR	NZ,CLASS_END	; to CLASS_END

	JR	CHECK_2		; to CHECK_2
; ___

mark_0D85:
CLASS_4:
	CALL	LOOK_VARS
	PUSH	AF		;
	LD	A,C		;
	OR	$9F		;
	INC	A		;
	JR	NZ,REPORT_C	; to REPORT_C

	POP	AF		;
	JR	CLASS_4_2		; to CLASS_4_2

; ___

mark_0D92:
CLASS_6:
	CALL	SCANNING
	BIT	6,(IY+FLAGS-RAMBASE)	; Numeric or string result?
	RET	NZ		;


mark_0D9A:
REPORT_C:
	RST	_ERROR_1
	DEFB	$0B		; Error Report: Nonsense in BASIC


; THE 'NUMBER TO STACK' SUBROUTINE

;
;

mark_0D9C:
NUMBER_TO_STK:
	JR	NZ,CLASS_6	; back to CLASS_6 with a non-zero number.

	CALL	SYNTAX_Z
	RET	Z		; return if checking syntax.

; in runtime a zero default is placed on the calculator stack.

	RST	_FP_CALC	;;
	DEFB	__stk_zero	;;
	DEFB	__end_calc	;;

	RET			; return.


; THE 'SYNTAX_Z' SUBROUTINE

; This routine returns with zero flag set if checking syntax.
; Calling this routine uses three instruction bytes compared to four if the
; bit test is implemented inline.

mark_0DA6:
SYNTAX_Z:
	BIT	7,(IY+FLAGS-RAMBASE)	; checking syntax only?
	RET			; return.


; THE 'IF' COMMAND ROUTINE

; In runtime, the class routines have evaluated the test expression and
; the result, true or false, is on the stack.

mark_0DAB:
IF:
	CALL	SYNTAX_Z
	JR	Z,IF_END	; forward if checking syntax

; else delete the Boolean value on the calculator stack.

	RST	_FP_CALC	;;
	DEFB	__delete	;;
	DEFB	__end_calc	;;

; register DE points to exponent of floating point value.

	LD	A,(DE)		; fetch exponent.
	AND	A		; test for zero - FALSE.
	RET	Z		; return if so.

mark_0DB6:
IF_END:
	JP	LINE_NULL		; jump back


; THE 'FOR' COMMAND ROUTINE

;
;

mark_0DB9:
FOR:
	CP	ZX_STEP		; is current character 'STEP' ?
	JR	NZ,F_USE_ONE	; forward if not


	RST	_NEXT_CHAR
	CALL	CLASS_6		; stacks the number
	CALL	CHECK_END
	JR	F_REORDER	; forward to F_REORDER
; ___

mark_0DC6:
F_USE_ONE:
	CALL	CHECK_END

	RST	_FP_CALC	;;
	DEFB	__stk_one	;;
	DEFB	__end_calc	;;



mark_0DCC:
F_REORDER:
	RST	_FP_CALC	;;	v, l, s.
	DEFB	__st_mem_0	;;	v, l, s.
	DEFB	__delete	;;	v, l.
	DEFB	__exchange	;;	l, v.
	DEFB	__get_mem_0	;;	l, v, s.
	DEFB	__exchange	;;	l, s, v.
	DEFB	__end_calc	;;	l, s, v.

	CALL	LET

	LD	(MEM),HL	; set MEM to address variable.
	DEC	HL		; point to letter.
	LD	A,(HL)		;
	SET	7,(HL)		;
	LD	BC,$0006	;
	ADD	HL,BC		;
	RLCA			;
	JR	C,F_LMT_STP

	SLA	C		;
	CALL	MAKE_ROOM
	INC	HL		;

mark_0DEA:
F_LMT_STP:
	PUSH	HL		;

	RST	_FP_CALC	;; 
	DEFB	__delete	;;
	DEFB	__delete	;;
	DEFB	__end_calc	;;

	POP	HL		;
	EX	DE,HL		;

	LD	C,$0A		; ten bytes to be moved.
	LDIR			; copy bytes

	LD	HL,(PPC)	; set HL to system variable PPC current line.
	EX	DE,HL		; transfer to DE, variable pointer to HL.
	INC	DE		; loop start will be this line + 1 at least.
	LD	(HL),E		;
	INC	HL		;
	LD	(HL),D		;
	CALL	NEXT_LOOP	; considers an initial pass.
	RET	NC		; return if possible.

; else program continues from point following matching NEXT.

	BIT	7,(IY+PPC_hi-RAMBASE)
	RET	NZ		; return if over 32767 ???

	LD	B,(IY+STRLEN_lo-RAMBASE)	; fetch variable name from STRLEN_lo
	RES	6,B		; make a true letter.
	LD	HL,(NXTLIN)	; set HL from NXTLIN

; now enter a loop to look for matching next.

mark_0E0E:
NXTLIN_NO:
	LD	A,(HL)		; fetch high byte of line number.
	AND	$C0		; mask off low bits $3F
	JR	NZ,FOR_END	; forward at end of program

	PUSH	BC		; save letter
	CALL	NEXT_ONE	; finds next line.
	POP	BC		; restore letter

	INC	HL		; step past low byte
	INC	HL		; past the
	INC	HL		; line length.
	CALL	TEMP_PTR1	; sets CH_ADD

	RST	_GET_CHAR
	CP	ZX_NEXT		;
	EX	DE,HL		; next line to HL.
	JR	NZ,NXTLIN_NO	; back with no match

;

	EX	DE,HL		; restore pointer.

	RST	_NEXT_CHAR	; advances and gets letter in A.
	EX	DE,HL		; save pointer
	CP	B		; compare to variable name.
	JR	NZ,NXTLIN_NO	; back with mismatch

mark_0E2A:
FOR_END:
	LD	(NXTLIN),HL	; update system variable NXTLIN
	RET			; return.


; THE 'NEXT' COMMAND ROUTINE

;
;

mark_0E2E:
NEXT:
	BIT	1,(IY+FLAGX-RAMBASE)
	JP	NZ,REPORT_2

	LD	HL,(DEST)
	BIT	7,(HL)
	JR	Z,REPORT_1

	INC	HL		;
	LD	(MEM),HL	;

	RST	_FP_CALC	;;
	DEFB	__get_mem_0	;;
	DEFB	__get_mem_2	;;
	DEFB	__addition	;;
	DEFB	__st_mem_0	;;
	DEFB	__delete	;;
	DEFB	__end_calc	;;

	CALL	NEXT_LOOP
	RET	C		;

	LD	HL,(MEM)	; 
	LD	DE,$000F	;
	ADD	HL,DE		;
	LD	E,(HL)		;
	INC	HL		;
	LD	D,(HL)		;
	EX	DE,HL		;
	JR	GOTO_2
; ___

mark_0E58:
REPORT_1:
	RST	_ERROR_1
	DEFB	$00		; Error Report: NEXT without FOR



; THE 'NEXT_LOOP' SUBROUTINE

;
;

mark_0E5A:
NEXT_LOOP:
	RST	_FP_CALC	;;
	DEFB	__get_mem_1	;;
	DEFB	__get_mem_0	;;
	DEFB	__get_mem_2	;;
	DEFB	__less_0	;;
	DEFB	__jump_true	;;
	DEFB	LMT_V_VAL - $	;;

	DEFB	__exchange	;;

mark_0E62:
LMT_V_VAL:
	DEFB	__subtract	;;
	DEFB	__greater_0	;;
	DEFB	__jump_true	;;
	DEFB	IMPOSS - $	;;

	DEFB	__end_calc	;;

	AND	A		; clear carry flag
	RET			; return.
; ___

mark_0E69:
IMPOSS:
	DEFB	__end_calc	;;

	SCF			; set carry flag
	RET			; return.


; THE 'RAND' COMMAND ROUTINE

; The keyword was 'RANDOMISE' on the ZX80, is 'RAND' here on the ZX81 and
; becomes 'RANDOMIZE' on the ZX Spectrum.
; In all invocations the procedure is the same - to set the SEED system variable
; with a supplied integer value or to use a time-based value if no number, or
; zero, is supplied.

mark_0E6C:
RAND:
	CALL	FIND_INT
	LD	A,B		; test value
	OR	C		; for zero
	JR	NZ,SET_SEED	; forward if not zero

	LD	BC,(FRAMES)	; fetch value of FRAMES system variable.

mark_0E77:
SET_SEED:
	LD	(SEED),BC	; update the SEED system variable.
	RET			; return.


; THE 'CONT' COMMAND ROUTINE

; Another abbreviated command. ROM space was really tight.
; CONTINUE at the line number that was set when break was pressed.
; Sometimes the current line, sometimes the next line.

mark_0E7C:
CONT:
	LD	HL,(OLDPPC)	; set HL from system variable OLDPPC
	JR	GOTO_2		; forward


; THE 'GOTO' COMMAND ROUTINE

; This token also suffered from the shortage of room and there is no space
; getween GO and TO as there is on the ZX80 and ZX Spectrum. The same also 
; applies to the GOSUB keyword.

mark_0E81:
GOTO:
	CALL	FIND_INT
	LD	H,B		;
	LD	L,C		;

mark_0E86:
GOTO_2:
	LD	A,H		;
	CP	$F0		; ZX_LIST ???
	JR	NC,REPORT_B

	CALL	LINE_ADDR
	LD	(NXTLIN),HL	; sv
	RET			;


; THE 'POKE' COMMAND ROUTINE


mark_0E92:
POKE:
	CALL	FP_TO_A
	JR	C,REPORT_B	; forward, with overflow

	JR	Z,POKE_SAVE	; forward, if positive

	NEG			; negate

mark_0E9B:
POKE_SAVE:
	PUSH	AF		; preserve value.
	CALL	FIND_INT		; gets address in BC
				; invoking the error routine with overflow
				; or a negative number.
	POP	AF		; restore value.

; Note. the next two instructions are legacy code from the ZX80 and
; inappropriate here.

	BIT	7,(IY+ERR_NR-RAMBASE)	; test ERR_NR - is it still $FF ?
	RET	Z		; return with error.

	LD	(BC),A		; update the address contents.
	RET			; return.


; THE 'FIND INTEGER' SUBROUTINE


mark_0EA7:
FIND_INT:
	CALL	FP_TO_BC
	JR	C,REPORT_B	; forward with overflow

	RET	Z		; return if positive (0-65535).


mark_0EAD:
REPORT_B:
	RST	_ERROR_1
	DEFB	$0A		; Error Report: Integer out of range
;
; Seems stupid, $0A is 10 but the ERROR_CODE_INTEGER_OUT_OF_RANGE is 11
; maybe gets incremented ???


; THE 'RUN' COMMAND ROUTINE


mark_0EAF:
RUN:
	CALL	GOTO
	JP	CLEAR


; THE 'GOSUB' COMMAND ROUTINE


mark_0EB5:
GOSUB:
	LD	HL,(PPC)	;
	INC	HL		;
	EX	(SP),HL		;
	PUSH	HL		;
	LD	(ERR_SP),SP	; set the error stack pointer - ERR_SP
	CALL	GOTO
	LD	BC,6		;


; THE 'TEST ROOM' SUBROUTINE

;
; checks ther is room for 36 bytes on the stack
;
mark_0EC5:
TEST_ROOM:
	LD	HL,(STKEND)	;
	ADD	HL,BC		; HL = STKEND + BC
	JR	C,REPORT_4

	EX	DE,HL		; DE = STKEND + BC
	LD	HL,$0024	; 36 decimal
	ADD	HL,DE		; HL = 36 + STKEND + BC
	SBC	HL,SP		; HL = 36 + STKEND + BC - SP
	RET	C		;

mark_0ED3:
REPORT_4:
	LD	L,3		;
	JP	ERROR_3


; THE 'RETURN' COMMAND ROUTINE


mark_0ED8:
RETURN:
	POP	HL		;
	EX	(SP),HL	;
	LD	A,H		;
	CP	$3E		;
	JR	Z,REPORT_7

	LD	(ERR_SP),SP	;
	JR	GOTO_2		; back
; ___

mark_0EE5:
REPORT_7:
	EX	(SP),HL	;
	PUSH	HL		;

	RST	_ERROR_1
	DEFB	6		; Error Report: RETURN without GOSUB

;
; Contradicts BASIC manual:
; 7 is ERROR_CODE_RETURN_WITHOUT_GOSUB
; 6 is ERROR_CODE_ARITHMETIC_OVERFLOW
;


; THE 'INPUT' COMMAND ROUTINE


mark_0EE9:
INPUT:
	BIT	7,(IY+PPC_hi-RAMBASE)
	JR	NZ,REPORT_8	; to REPORT_8

	CALL	X_TEMP
	LD	HL,FLAGX	; 
	SET	5,(HL)		;
	RES	6,(HL)		;
	LD	A,(FLAGS)	;
	AND	$40		; 64
	LD	BC,2		;
	JR	NZ,PROMPT	; to PROMPT

	LD	C,$04		;

mark_0F05:
PROMPT:
	OR	(HL)		;
	LD	(HL),A		;

	RST	_BC_SPACES
	LD	(HL),ZX_NEWLINE
	LD	A,C		;
	RRCA			;
	RRCA			;
	JR	C,ENTER_CUR

	LD	A,$0B		; ZX_QUOTE ???
	LD	(DE),A		;
	DEC	HL		;
	LD	(HL),A		;

mark_0F14:
ENTER_CUR:
	DEC	HL		;
	LD	(HL),ZX_CURSOR	;
	LD	HL,(S_POSN)	;
	LD	(T_ADDR),HL	;
	POP	HL		;
	JP	LOWER

; ___

mark_0F21:
REPORT_8:
	RST	_ERROR_1
	DEFB	7		; Error Report: End of file


; THE 'PAUSE' COMMAND ROUTINE


mark_0F23:
FAST:
	CALL	SET_FAST
	RES	6,(IY+CDFLAG-RAMBASE)
	RET			; return.


; THE 'SLOW' COMMAND ROUTINE


mark_0F2B:
SLOW:
	SET	6,(IY+CDFLAG-RAMBASE)
	JP	SLOW_FAST


; THE 'PAUSE' COMMAND ROUTINE


mark_0F32:
PAUSE:
	CALL	FIND_INT
	CALL	SET_FAST
	LD	H,B		;
	LD	L,C		;
	CALL	DISPLAY_P

	LD	(IY+FRAMES_hi-RAMBASE),$FF

	CALL	SLOW_FAST
	JR	DEBOUNCE


; THE 'BREAK' SUBROUTINE


mark_0F46:
BREAK_1:
	LD	A,$7F			; read port $7FFE - keys B,N,M,.,SPACE.
	IN	A,(IO_PORT_KEYBOARD_RD)	;
	RRA				; carry will be set if space not pressed.


; THE 'DEBOUNCE' SUBROUTINE


mark_0F4B:
DEBOUNCE:
	RES	0,(IY+CDFLAG-RAMBASE)	; update
	LD	A,$FF		;
	LD	(DEBOUNCE_VAR),A	; update
	RET			; return.



; THE 'SCANNING' SUBROUTINE

; This recursive routine is where the ZX81 gets its power.
; Provided there is enough memory it can evaluate 
; an expression of unlimited complexity.
; Note. there is no unary plus so, as on the ZX80, PRINT +1 gives a syntax error.
; PRINT +1 works on the Spectrum but so too does PRINT + "STRING".

mark_0F55:
SCANNING:
	RST	_GET_CHAR
	LD	B,0		; set B register to zero.
	PUSH	BC		; stack zero as a priority end-marker.

mark_0F59:
S_LOOP_1:
	CP	ZX_RND
	JR	NZ,S_TEST_PI	; forward, if not, to S_TEST_PI


; THE 'RND' FUNCTION

RND:

	CALL	SYNTAX_Z
	JR	Z,S_JPI_END	; forward if checking syntax to S_JPI_END

	LD	BC,(SEED)	; sv
	CALL	STACK_BC

	RST	_FP_CALC	;;
	DEFB	__stk_one	;;
	DEFB	__addition	;;
	DEFB	__stk_data	;;
	DEFB	$37		;;Exponent: $87, Bytes: 1
	DEFB	$16		;;(+00,+00,+00)
	DEFB	__multiply	;;
	DEFB	__stk_data	;;
	DEFB	$80		;;Bytes: 3
	DEFB	$41		;;Exponent $91
	DEFB	$00,$00,$80	;;(+00)
	DEFB	__n_mod_m	;;
	DEFB	__delete	;;
	DEFB	__stk_one	;;
	DEFB	__subtract	;;
	DEFB	__duplicate	;;
	DEFB	__end_calc	;;

	CALL	FP_TO_BC
	LD	(SEED),BC	; update the SEED system variable.
	LD	A,(HL)		; HL addresses the exponent of the last value.
	AND	A		; test for zero
	JR	Z,S_JPI_END	; forward, if so

	SUB	$10		; else reduce exponent by sixteen
	LD	(HL),A		; thus dividing by 65536 for last value.

mark_0F8A:
S_JPI_END:
	JR	S_PI_END	; forward

; ___

mark_0F8C:
S_TEST_PI:
	CP	ZX_PI		; the 'PI' character
	JR	NZ,S_TST_INK	; forward, if not


; THE 'PI' EVALUATION


	CALL	SYNTAX_Z
	JR	Z,S_PI_END	; forward if checking syntax


	RST	_FP_CALC	;;
	DEFB	__stk_half_pi	;;
	DEFB	__end_calc	;;

	INC	(HL)		; double the exponent giving PI on the stack.

mark_0F99:
S_PI_END:
	RST	_NEXT_CHAR	; advances character pointer.

	JP	S_NUMERIC	; jump forward to set the flag
				; to signal numeric result before advancing.

; ___

mark_0F9D:
S_TST_INK:
	CP	ZX_INKEY_STR	;
	JR	NZ,S_ALPHANUM	; forward, if not


; THE 'INKEY$' EVALUATION


	CALL	KEYBOARD
	LD	B,H		;
	LD	C,L		;
	LD	D,C		;
	INC	D		;
	CALL	NZ,DECODE
	LD	A,D		;
	ADC	A,D		;
	LD	B,D		;
	LD	C,A		;
	EX	DE,HL		;
	JR	S_STRING		; forward

; ___

mark_0FB2:
S_ALPHANUM:
	CALL	ALPHANUM
	JR	C,S_LTR_DGT	; forward, if alphanumeric

	CP	ZX_PERIOD	; is character a '.' ?
	JP	Z,S_DECIMAL	; jump forward if so

	LD	BC,$09D8	; prepare priority 09, operation 'subtract'
	CP	ZX_MINUS	; is character unary minus '-' ?
	JR	Z,S_PUSH_PO	; forward, if so

	CP	ZX_BRACKET_LEFT	; is character a '(' ?
	JR	NZ,S_QUOTE	; forward if not

	CALL	CH_ADD_PLUS_1	; advances character pointer.

	CALL	SCANNING	; recursively call to evaluate the sub_expression.

	CP	ZX_BRACKET_RIGHT; is subsequent character a ')' ?
	JR	NZ,S_RPT_C	; forward if not


	CALL	CH_ADD_PLUS_1	; advances.
	JR	S_J_CONT_3	; relative jump to S_JP_CONT3 and then S_CONT3

; ___

; consider a quoted string e.g. PRINT "Hooray!"
; Note. quotes are not allowed within a string.

mark_0FD6:
S_QUOTE:
	CP	ZX_QUOTE	; is character a quote (") ?
	JR	NZ,S_FUNCTION	; forward, if not

	CALL	CH_ADD_PLUS_1	; advances
	PUSH	HL		; * save start of string.
	JR	S_QUOTE_S	; forward

; ___


mark_0FE0:
S_Q_AGAIN:
	CALL	CH_ADD_PLUS_1

mark_0FE3:
S_QUOTE_S:
	CP	ZX_QUOTE	; is character a '"' ?
	JR	NZ,S_Q_NL	; forward if not to S_Q_NL

	POP	DE		; * retrieve start of string
	AND	A		; prepare to subtract.
	SBC	HL,DE		; subtract start from current position.
	LD	B,H		; transfer this length
	LD	C,L		; to the BC register pair.

mark_0FED:
S_STRING:
	LD	HL,FLAGS	; address system variable FLAGS
	RES	6,(HL)		; signal string result
	BIT	7,(HL)		; test if checking syntax.

	CALL	NZ,STK_STO_STR	; in run-time stacks the
				; string descriptor - start DE, length BC.

	RST	_NEXT_CHAR	; advances pointer.

mark_0FF8:
S_J_CONT_3:
	JP	S_CONT_3

; ___

; A string with no terminating quote has to be considered.

mark_0FFB:
S_Q_NL:
	CP	ZX_NEWLINE
	JR	NZ,S_Q_AGAIN	; loop back if not

mark_0FFF:
S_RPT_C:
	JP	REPORT_C
; ___

mark_1002:
S_FUNCTION:
	SUB	$C4		; subtract 'CODE' reducing codes
				; CODE thru '<>' to range $00 - $XX
	JR	C,S_RPT_C	; back, if less

; test for NOT the last function in character set.

	LD	BC,$04EC	; prepare priority $04, operation 'not'
	CP	$13		; compare to 'NOT'	( - CODE)
	JR	Z,S_PUSH_PO	; forward, if so

	JR	NC,S_RPT_C	; back with anything higher

; else is a function 'CODE' thru 'CHR$'

	LD	B,$10		; priority sixteen binds all functions to
				; arguments removing the need for brackets.

	ADD	A,$D9		; add $D9 to give range $D9 thru $EB
				; bit 6 is set to show numeric argument.
				; bit 7 is set to show numeric result.

; now adjust these default argument/result indicators.

	LD	C,A		; save code in C

	CP	$DC		; separate 'CODE', 'VAL', 'LEN'
	JR	NC,S_NUMBER_TO_STRING	; skip forward if string operand

	RES	6,C		; signal string operand.

mark_101A:
S_NUMBER_TO_STRING:
	CP	$EA		; isolate top of range 'STR$' and 'CHR$'
	JR	C,S_PUSH_PO	; skip forward with others

	RES	7,C		; signal string result.

mark_1020:
S_PUSH_PO:
	PUSH	BC		; push the priority/operation

	RST	_NEXT_CHAR
	JP	S_LOOP_1		; jump back
; ___

mark_1025:
S_LTR_DGT:
	CP	ZX_A		; compare to 'A'.
	JR	C,S_DECIMAL	; forward if less to S_DECIMAL

	CALL	LOOK_VARS
	JP	C,REPORT_2	; back if not found
				; a variable is always 'found' when checking
				; syntax.

	CALL	Z,STK_VAR	; stacks string parameters or
				; returns cell location if numeric.

	LD	A,(FLAGS)	; fetch FLAGS
	CP	$C0		; compare to numeric result/numeric operand
	JR	C,S_CONT_2	; forward if not numeric

	INC	HL		; address numeric contents of variable.
	LD	DE,(STKEND)	; set destination to STKEND
	CALL	MOVE_FP		; stacks the five bytes
	EX	DE,HL		; transfer new free location from DE to HL.
	LD	(STKEND),HL	; update STKEND system variable.
	JR	S_CONT_2		; forward
; ___

; The Scanning Decimal routine is invoked when a decimal point or digit is
; found in the expression.
; When checking syntax, then the 'hidden floating point' form is placed
; after the number in the BASIC line.
; In run-time, the digits are skipped and the floating point number is picked
; up.

mark_1047:
S_DECIMAL:
	CALL	SYNTAX_Z
	JR	NZ,S_STK_DEC	; forward in run-time

	CALL	DEC_TO_FP

	RST	_GET_CHAR	; advances HL past digits
	LD	BC,$0006	; six locations are required.
	CALL	MAKE_ROOM
	INC	HL		; point to first new location
	LD	(HL),$7E	; insert the number marker 126 decimal.
	INC	HL		; increment
	EX	DE,HL		; transfer destination to DE.
	LD	HL,(STKEND)	; set HL from STKEND which points to the
				; first location after the 'last value'
	LD	C,$05		; five bytes to move.
	AND	A		; clear carry.
	SBC	HL,BC		; subtract five pointing to 'last value'.
	LD	(STKEND),HL	; update STKEND thereby 'deleting the value.

	LDIR			; copy the five value bytes.

	EX	DE,HL		; basic pointer to HL which may be white-space
				; following the number.
	DEC	HL		; now points to last of five bytes.
	CALL	TEMP_PTR1		; advances the character
				; address skipping any white-space.
	JR	S_NUMERIC		; forward
				; to signal a numeric result.
; ___
; In run-time the branch is here when a digit or point is encountered.

mark_106F:
S_STK_DEC:
	RST	_NEXT_CHAR
	CP	$7E		; compare to 'number marker'
	JR	NZ,S_STK_DEC	; loop back until found
				; skipping all the digits.

	INC	HL		; point to first of five hidden bytes.
	LD	DE,(STKEND)	; set destination from STKEND system variable
	CALL	MOVE_FP		; stacks the number.
	LD	(STKEND),DE	; update system variable STKEND.
	LD	(CH_ADD),HL	; update system variable CH_ADD.

mark_1083:
S_NUMERIC:
	SET	6,(IY+FLAGS-RAMBASE)	; Signal numeric result

mark_1087:
S_CONT_2:
	RST	_GET_CHAR

mark_1088:
S_CONT_3:
	CP	ZX_BRACKET_LEFT		; compare to opening bracket '('
	JR	NZ,S_OPERTR	; forward if not

	BIT	6,(IY+FLAGS-RAMBASE)	; Numeric or string result?
	JR	NZ,S_LOOP	; forward if numeric

; else is a string

	CALL	SLICING

	RST	_NEXT_CHAR
	JR	S_CONT_3	; back
; ___
; the character is now manipulated to form an equivalent in the table of
; calculator literals. This is quite cumbersome and in the ZX Spectrum a
; simple look-up table was introduced at this point.

mark_1098:
S_OPERTR:
	LD	BC,$00C3	; prepare operator 'subtract' as default.
				; also set B to zero for later indexing.

	CP	ZX_GREATER_THAN	; is character '>' ?
	JR	C,S_LOOP	; forward if less, as
				; we have reached end of meaningful expression

	SUB	ZX_MINUS	; is character '-' ?
	JR	NC,SUBMLTDIV	; forward with - * / and '**' '<>'

	ADD	A,13		; increase others by thirteen
				; $09 '>' thru $0C '+'
	JR	GET_PRIO	; forward

; ___

mark_10A7:
SUBMLTDIV:
	CP	$03		; isolate $00 '-', $01 '*', $02 '/'
	JR	C,GET_PRIO	; forward if so

; else possibly originally $D8 '**' thru $DD '<>' already reduced by $16

	SUB	$C2		; giving range $00 to $05
	JR	C,S_LOOP	; forward if less

	CP	$06		; test the upper limit for nonsense also
	JR	NC,S_LOOP	; forward if so

	ADD	A,$03		; increase by 3 to give combined operators of

				; $00 '-'
				; $01 '*'
				; $02 '/'

				; $03 '**'
				; $04 'OR'
				; $05 'AND'
				; $06 '<='
				; $07 '>='
				; $08 '<>'

				; $09 '>'
				; $0A '<'
				; $0B '='
				; $0C '+'

mark_10B5:
GET_PRIO:
	ADD	A,C		; add to default operation 'sub' ($C3)
	LD	C,A		; and place in operator byte - C.

	LD	HL,tbl_pri - $C3	; theoretical base of the priorities table.
	ADD	HL,BC		; add C ( B is zero)
	LD	B,(HL)		; pick up the priority in B

mark_10BC:
S_LOOP:
	POP	DE		; restore previous
	LD	A,D		; load A with priority.
	CP	B		; is present priority higher
	JR	C,S_TIGHTER	; forward if so to S_TIGHTER

	AND	A		; are both priorities zero
	JP	Z,GET_CHAR	; exit if zero via GET_CHAR

	PUSH	BC		; stack present values
	PUSH	DE		; stack last values
	CALL	SYNTAX_Z
	JR	Z,S_SYNTEST	; forward is checking syntax

	LD	A,E		; fetch last operation
	AND	$3F		; mask off the indicator bits to give true
				; calculator literal.
	LD	B,A		; place in the B register for BERG

; perform the single operation

	RST	_FP_CALC	;;
	DEFB	__fp_calc_2	;;
	DEFB	__end_calc	;;

	JR	S_RUNTEST	; forward

; ___

mark_10D5:
S_SYNTEST:
	LD	A,E			; transfer masked operator to A
	XOR	(IY+FLAGS-RAMBASE)	; XOR with FLAGS like results will reset bit 6
	AND	$40			; test bit 6

mark_10DB:
S_RPORT_C:
	JP	NZ,REPORT_C	; back if results do not agree.

; ___

; in run-time impose bit 7 of the operator onto bit 6 of the FLAGS

mark_10DE:
S_RUNTEST:
	POP	DE		; restore last operation.
	LD	HL,FLAGS	; address system variable FLAGS
	SET	6,(HL)		; presume a numeric result
	BIT	7,E		; test expected result in operation
	JR	NZ,S_LOOPEND	; forward if numeric

	RES	6,(HL)		; reset to signal string result

mark_10EA:
S_LOOPEND:
	POP	BC		; restore present values
	JR	S_LOOP		; back

; ___

mark_10ED:
S_TIGHTER:
	PUSH	DE		; push last values and consider these

	LD	A,C		; get the present operator.
	BIT	6,(IY+FLAGS-RAMBASE)	; Numeric or string result?
	JR	NZ,S_NEXT	; forward if numeric to S_NEXT

	AND	$3F		; strip indicator bits to give clear literal.
	ADD	A,$08		; add eight - augmenting numeric to equivalent
				; string literals.
	LD	C,A		; place plain literal back in C.
	CP	$10		; compare to 'AND'
	JR	NZ,S_NOT_AND	; forward if not

	SET	6,C		; set the numeric operand required for 'AND'
	JR	S_NEXT		; forward to S_NEXT

; ___

mark_1102:
S_NOT_AND:
	JR	C,S_RPORT_C	; back if less than 'AND'
				; Nonsense if '-', '*' etc.

	CP	__strs_add	; compare to 'strs_add' literal
	JR	Z,S_NEXT	; forward if so signaling string result

	SET	7,C		; set bit to numeric (Boolean) for others.

mark_110A:
S_NEXT:
	PUSH	BC		; stack 'present' values

	RST	_NEXT_CHAR
	JP	S_LOOP_1	; jump back




; THE 'TABLE OF PRIORITIES'


mark_110F:
tbl_pri:
	DEFB	6		;	'-'
	DEFB	8		;	'*'
	DEFB	8		;	'/'
	DEFB	10		;	'**'
	DEFB	2		;	'OR'
	DEFB	3		;	'AND'
	DEFB	5		;	'<='
	DEFB	5		;	'>='
	DEFB	5		;	'<>'
	DEFB	5		;	'>'
	DEFB	5		;	'<'
	DEFB	5		;	'='
	DEFB	6		;	'+'


; THE 'LOOK_VARS' SUBROUTINE


mark_111C:
LOOK_VARS:
	SET	6,(IY+FLAGS-RAMBASE)	; Signal numeric result

	RST	_GET_CHAR
	CALL	ALPHA
	JP	NC,REPORT_C	; to REPORT_C

	PUSH	HL		;
	LD	C,A		;

	RST	_NEXT_CHAR
	PUSH	HL		;
	RES	5,C		;
	CP	$10		; $10
	JR	Z,V_RUN_SYN

	SET	6,C		;
	CP	ZX_DOLLAR	; $0D
	JR	Z,V_STR_VAR	; forward

	SET	5,C		;

mark_1139:
V_CHAR:
	CALL	ALPHANUM
	JR	NC,V_RUN_SYN	; forward when not

	RES	6,C		;

	RST	_NEXT_CHAR
	JR	V_CHAR		; loop back

; ___

mark_1143:
V_STR_VAR:
	RST	_NEXT_CHAR
	RES	6,(IY+FLAGS-RAMBASE)	; Signal string result

mark_1148:
V_RUN_SYN:
	LD	B,C		;
	CALL	SYNTAX_Z
	JR	NZ,V_RUN	; forward

	LD	A,C		;
	AND	$E0		;
	SET	7,A		;
	LD	C,A		;
	JR	V_SYNTAX	; forward

; ___

mark_1156:
V_RUN:
	LD	HL,(VARS)	; sv

mark_1159:
V_EACH:
	LD	A,(HL)		;
	AND	$7F		;
	JR	Z,V_80_BYTE	;

	CP	C		;
	JR	NZ,V_NEXT	;

	RLA			;
	ADD	A,A		;
	JP	P,V_FOUND_2

	JR	C,V_FOUND_2

	POP	DE		;
	PUSH	DE		;
	PUSH	HL		;

mark_116B:
V_MATCHES:
	INC	HL		;

mark_116C:
V_SPACES:
	LD	A,(DE)		;
	INC	DE		;
	AND	A		;
	JR	Z,V_SPACES	; back

	CP	(HL)		;
	JR	Z,V_MATCHES	; back

	OR	$80		;
	CP	(HL)		;
	JR	NZ,V_GET_PTR	; forward

	LD	A,(DE)		;
	CALL	ALPHANUM
	JR	NC,V_FOUND_1	; forward

mark_117F:
V_GET_PTR:
	POP	HL		;

mark_1180:
V_NEXT:
	PUSH	BC		;
	CALL	NEXT_ONE
	EX	DE,HL		;
	POP	BC		;
	JR	V_EACH		; back

; ___

mark_1188:
V_80_BYTE:
	SET	7,B		;

mark_118A:
V_SYNTAX:
	POP	DE		;

	RST	_GET_CHAR
	CP	$10		;
	JR	Z,V_PASS	; forward

	SET	5,B		;
	JR	V_END		; forward

; ___

mark_1194:
V_FOUND_1:
	POP	DE		;

mark_1195:
V_FOUND_2:
	POP	DE		;
	POP	DE		;
	PUSH	HL		;

	RST	_GET_CHAR

mark_1199:
V_PASS:
	CALL	ALPHANUM
	JR	NC,V_END	; forward if not alphanumeric


	RST	_NEXT_CHAR
	JR	V_PASS		; back

; ___

mark_11A1:
V_END:
	POP	HL		;
	RL	B		;
	BIT	6,B		;
	RET			;


; THE 'STK_VAR' SUBROUTINE


mark_11A7:
STK_VAR:
	XOR	A		;
	LD	B,A		;
	BIT	7,C		;
	JR	NZ,SV_COUNT	; forward

	BIT	7,(HL)		;
	JR	NZ,SV_ARRAYS	; forward

	INC	A		;

mark_11B2:
SV_SIMPLE_STR:
	INC	HL		;
	LD	C,(HL)		;
	INC	HL		;
	LD	B,(HL)		;
	INC	HL		;
	EX	DE,HL		;
	CALL	STK_STO_STR

	RST	_GET_CHAR
	JP	SV_SLICE_QUERY	; jump forward

; ___

mark_11BF:
SV_ARRAYS:
	INC	HL		;
	INC	HL		;
	INC	HL		;
	LD	B,(HL)		;
	BIT	6,C		;
	JR	Z,SV_PTR	; forward

	DEC	B		;
	JR	Z,SV_SIMPLE_STR	; forward

	EX	DE,HL		;

	RST	_GET_CHAR
	CP	$10		;
	JR	NZ,REPORT_3	; forward

	EX	DE,HL		;

mark_11D1:
SV_PTR:
	EX	DE,HL		;
	JR	SV_COUNT	; forward
; ___
mark_11D4:
SV_COMMA:
	PUSH	HL		;

	RST	_GET_CHAR
	POP	HL		;
	CP	ZX_COMMA	; $1A == 26
	JR	Z,SV_LOOP	; forward

	BIT	7,C		;
	JR	Z,REPORT_3	; forward

	BIT	6,C		;
	JR	NZ,SV_CLOSE	; forward

	CP	ZX_BRACKET_RIGHT		; $11
	JR	NZ,SV_RPT_C	; forward


	RST	_NEXT_CHAR
	RET			;
; ___
mark_11E9:
SV_CLOSE:
	CP	ZX_BRACKET_RIGHT		; $11
	JR	Z,SV_DIM	; forward

	CP	$DF		;
	JR	NZ,SV_RPT_C	; forward

mark_11F1:
SV_CH_ADD:
	RST	_GET_CHAR
	DEC	HL		;
	LD	(CH_ADD),HL	; sv
	JR	SV_SLICE	; forward

; ___

mark_11F8:
SV_COUNT:
	LD	HL,$0000	;

mark_11FB:
SV_LOOP:
	PUSH	HL		;

	RST	_NEXT_CHAR
	POP	HL		;
	LD	A,C		;
	CP	ZX_DOUBLE_QUOTE	;
	JR	NZ,SV_MULT	; forward


	RST	_GET_CHAR
	CP	ZX_BRACKET_RIGHT
	JR	Z,SV_DIM	; forward

	CP	ZX_TO		;
	JR	Z,SV_CH_ADD	; back

mark_120C:
SV_MULT:
	PUSH	BC		;
	PUSH	HL		;
	CALL	DE_DE_PLUS_ONE
	EX	(SP),HL	;
	EX	DE,HL		;
	CALL	INT_EXP1
	JR	C,REPORT_3

	DEC	BC		;
	CALL	GET_HL_TIMES_DE
	ADD	HL,BC		;
	POP	DE		;
	POP	BC		;
	DJNZ	SV_COMMA		; loop back

	BIT	7,C		;

mark_1223:
SV_RPT_C:
	JR	NZ,SL_RPT_C

	PUSH	HL		;
	BIT	6,C		;
	JR	NZ,SV_ELEM_STR

	LD	B,D		;
	LD	C,E		;

	RST	_GET_CHAR
	CP	ZX_BRACKET_RIGHT; is character a ')' ?
	JR	Z,SV_NUMBER	; skip forward


mark_1231:
REPORT_3:
	RST	_ERROR_1
	DEFB	$02		; Error Report: Subscript wrong


mark_1233:
SV_NUMBER:
	RST	_NEXT_CHAR
	POP	HL		;
	LD	DE,$0005	;
	CALL	GET_HL_TIMES_DE
	ADD	HL,BC		;
	RET			; return				>>

; ___

mark_123D:
SV_ELEM_STR:
	CALL	DE_DE_PLUS_ONE
	EX	(SP),HL	;
	CALL	GET_HL_TIMES_DE
	POP	BC		;
	ADD	HL,BC		;
	INC	HL		;
	LD	B,D		;
	LD	C,E		;
	EX	DE,HL		;
	CALL	STK_ST_0

	RST	_GET_CHAR
	CP	ZX_BRACKET_RIGHT ; is it ')' ?
	JR	Z,SV_DIM	; forward if so

	CP	ZX_COMMA	; $1A == 26		; is it ',' ?
	JR	NZ,REPORT_3	; back if not

mark_1256:
SV_SLICE:
	CALL	SLICING

mark_1259:
SV_DIM:
	RST	_NEXT_CHAR

mark_125A:
SV_SLICE_QUERY:
	CP	$10		;
	JR	Z,SV_SLICE	; back

	RES	6,(IY+FLAGS-RAMBASE)	; Signal string result
	RET			; return.


; THE 'SLICING' SUBROUTINE

;
;

mark_1263:
SLICING:
	CALL	SYNTAX_Z
	CALL	NZ,STK_FETCH

	RST	_NEXT_CHAR
	CP	ZX_BRACKET_RIGHT; is it ')' ?
	JR	Z,SL_STORE	; forward if so

	PUSH	DE		;
	XOR	A		;
	PUSH	AF		;
	PUSH	BC		;
	LD	DE,$0001	;

	RST	_GET_CHAR
	POP	HL		;
	CP	ZX_TO		; is it 'TO' ?
	JR	Z,SL_SECOND	; forward if so

	POP	AF		;
	CALL	INT_EXP2
	PUSH	AF		;
	LD	D,B		;
	LD	E,C		;
	PUSH	HL		;

	RST	_GET_CHAR
	POP	HL		;
	CP	ZX_TO		; is it 'TO' ?
	JR	Z,SL_SECOND	; forward if so

	CP	ZX_BRACKET_RIGHT; $11

mark_128B:
SL_RPT_C:
	JP	NZ,REPORT_C

	LD	H,D		;
	LD	L,E		;
	JR	SL_DEFINE		; forward

; ___

mark_1292:
SL_SECOND:
	PUSH	HL		;

	RST	_NEXT_CHAR
	POP	HL		;
	CP	ZX_BRACKET_RIGHT; is it ')' ?
	JR	Z,SL_DEFINE	; forward if so

	POP	AF		;
	CALL	INT_EXP2
	PUSH	AF		;

	RST	_GET_CHAR
	LD	H,B		;
	LD	L,C		;
	CP	ZX_BRACKET_RIGHT; is it ')' ?
	JR	NZ,SL_RPT_C	; back if not

mark_12A5:
SL_DEFINE:
	POP	AF		;
	EX	(SP),HL	;
	ADD	HL,DE		;
	DEC	HL		;
	EX	(SP),HL	;
	AND	A		;
	SBC	HL,DE		;
	LD	BC,$0000	;
	JR	C,SL_OVER	; forward

	INC	HL		;
	AND	A		;
	JP	M,REPORT_3	; jump back

	LD	B,H		;
	LD	C,L		;

mark_12B9:
SL_OVER:
	POP	DE		;
	RES	6,(IY+FLAGS-RAMBASE)	; Signal string result

mark_12BE:
SL_STORE:
	CALL	SYNTAX_Z
	RET	Z		; return if checking syntax.


; THE 'STK_STORE' SUBROUTINE

;
;

mark_12C2:
STK_ST_0:
	XOR	A		;

mark_12C3:
STK_STO_STR:
	PUSH	BC		;
	CALL	TEST_5_SP
	POP	BC		;
	LD	HL,(STKEND)	; sv
	LD	(HL),A		;
	INC	HL		;
	LD	(HL),E		;
	INC	HL		;
	LD	(HL),D		;
	INC	HL		;
	LD	(HL),C		;
	INC	HL		;
	LD	(HL),B		;
	INC	HL		;
	LD	(STKEND),HL	; sv
	RES	6,(IY+FLAGS-RAMBASE)	; Signal string result
	RET			; return.


; THE 'INT EXP' SUBROUTINES

;
;

mark_12DD:
INT_EXP1:
	XOR	A		;

mark_12DE:
INT_EXP2:
	PUSH	DE		;
	PUSH	HL		;
	PUSH	AF		;
	CALL	CLASS_6
	POP	AF		;
	CALL	SYNTAX_Z
	JR	Z,I_RESTORE	; forward if checking syntax

	PUSH	AF		;
	CALL	FIND_INT
	POP	DE		;
	LD	A,B		;
	OR	C		;
	SCF			; Set Carry Flag
	JR	Z,I_CARRY	; forward

	POP	HL		;
	PUSH	HL		;
	AND	A		;
	SBC	HL,BC		;

mark_12F9:
I_CARRY:
	LD	A,D		;
	SBC	A,$00		;

mark_12FC:
I_RESTORE:
	POP	HL		;
	POP	DE		;
	RET			;


; THE 'DE,(DE+1)' SUBROUTINE

; INDEX and LOAD Z80 subroutine. 
; This emulates the 6800 processor instruction LDX 1,X which loads a two_byte
; value from memory into the register indexing it. Often these are hardly worth
; the bother of writing as subroutines and this one doesn't save any time or 
; memory. The timing and space overheads have to be offset against the ease of
; writing and the greater program readability from using such toolkit routines.

mark_12FF:
DE_DE_PLUS_ONE:
	EX	DE,HL		; move index address into HL.
	INC	HL		; increment to address word.
	LD	E,(HL)		; pick up word low_order byte.
	INC	HL		; index high_order byte and 
	LD	D,(HL)		; pick it up.
	RET			; return with DE = word.


; THE 'GET_HL_TIMES_DE' SUBROUTINE

;

mark_1305:
GET_HL_TIMES_DE:
	CALL	SYNTAX_Z
	RET	Z		;

	PUSH	BC		;
	LD	B,$10		;
	LD	A,H		;
	LD	C,L		;
	LD	HL,$0000	;

mark_1311:
HL_LOOP:
	ADD	HL,HL		;
	JR	C,HL_END	; forward with carry

	RL	C		;
	RLA			;
	JR	NC,HL_AGAIN	; forward with no carry

	ADD	HL,DE		;

mark_131A:
HL_END:
	JP	C,REPORT_4

mark_131D:
HL_AGAIN:
	DJNZ	HL_LOOP		; loop back

	POP	BC		;
	RET			; return.


; THE 'LET' SUBROUTINE

;
;

mark_1321:
LET:
	LD	HL,(DEST)
	BIT	1,(IY+FLAGX-RAMBASE)
	JR	Z,L_EXISTS	; forward

	LD	BC,$0005	;

mark_132D:
L_EACH_CH:
	INC	BC		;

; check

mark_132E:
L_NO_SP:
	INC	HL		;
	LD	A,(HL)		;
	AND	A		;
	JR	Z,L_NO_SP	; back

	CALL	ALPHANUM
	JR	C,L_EACH_CH	; back

	CP	ZX_DOLLAR	; is it '$' ?
	JP	Z,L_NEW_STR	; forward if so


	RST	_BC_SPACES		; BC_SPACES
	PUSH	DE		;
	LD	HL,(DEST)	; 
	DEC	DE		;
	LD	A,C		;
	SUB	$06		;
	LD	B,A		;
	LD	A,$40		;
	JR	Z,L_SINGLE

mark_134B:
L_CHAR:
	INC	HL		;
	LD	A,(HL)		;
	AND	A		; is it a space ?
	JR	Z,L_CHAR	; back

	INC	DE		;
	LD	(DE),A		;
	DJNZ	L_CHAR		; loop back

	OR	$80		;
	LD	(DE),A		;
	LD	A,$80		;

mark_1359:
L_SINGLE:
	LD	HL,(DEST)	; 
	XOR	(HL)		;
	POP	HL		;
	CALL	L_FIRST

mark_1361:
L_NUMERIC:
	PUSH	HL		;

	RST	_FP_CALC	;;
	DEFB	__delete	;;
	DEFB	__end_calc	;;

	POP	HL		;
	LD	BC,$0005	;
	AND	A		;
	SBC	HL,BC		;
	JR	L_ENTER		; forward

; ___

mark_136E:
L_EXISTS:
	BIT	6,(IY+FLAGS-RAMBASE)	; Numeric or string result?
	JR	Z,L_DELETE_STR	; forward

	LD	DE,$0006	;
	ADD	HL,DE		;
	JR	L_NUMERIC		; back

; ___

mark_137A:
L_DELETE_STR:
	LD	HL,(DEST)	; 
	LD	BC,(STRLEN)	;
	BIT	0,(IY+FLAGX-RAMBASE)
	JR	NZ,L_ADD_STR	; forward

	LD	A,B		;
	OR	C		;
	RET	Z		;

	PUSH	HL		;

	RST	_BC_SPACES
	PUSH	DE		;
	PUSH	BC		;
	LD	D,H		;
	LD	E,L		;
	INC	HL		;
	LD	(HL),$00	;
	LDDR			; Copy Bytes
	PUSH	HL		;
	CALL	STK_FETCH
	POP	HL		;
	EX	(SP),HL	;
	AND	A		;
	SBC	HL,BC		;
	ADD	HL,BC		;
	JR	NC,L_LENGTH	; forward

	LD	B,H		;
	LD	C,L		;

mark_13A3:
L_LENGTH:
	EX	(SP),HL	;
	EX	DE,HL		;
	LD	A,B		;
	OR	C		;
	JR	Z,L_IN_W_S	; forward if zero

	LDIR			; Copy Bytes

mark_13AB:
L_IN_W_S:
	POP	BC		;
	POP	DE		;
	POP	HL		;


; THE 'L_ENTER' SUBROUTINE
;
;   Part of the LET command contains a natural subroutine which is a 
;   conditional LDIR. The copy only occurs of BC is non-zero.

mark_13AE:
L_ENTER:
	EX	DE,HL		;
if ORIGINAL
else
COND_MV:
endif
	LD	A,B		;
	OR	C		;
	RET	Z		;

	PUSH	DE		;
	LDIR			; Copy Bytes
	POP	HL		;
	RET			; return.

mark_13B7:
L_ADD_STR:
	DEC	HL		;
	DEC	HL		;
	DEC	HL		;
	LD	A,(HL)		;
	PUSH	HL		;
	PUSH	BC		;

	CALL	L_STRING

	POP	BC		;
	POP	HL		;
	INC	BC		;
	INC	BC		;
	INC	BC		;
	JP	RECLAIM_2		; jump back to exit via RECLAIM_2

; ___

mark_13C8:
L_NEW_STR:
	LD	A,$60		; prepare mask %01100000
	LD	HL,(DEST)	; 
	XOR	(HL)		;


; THE 'L_STRING' SUBROUTINE

;

mark_13CE:
L_STRING:
	PUSH	AF		;
	CALL	STK_FETCH
	EX	DE,HL		;
	ADD	HL,BC		;
	PUSH	HL		;
	INC	BC		;
	INC	BC		;
	INC	BC		;

	RST	_BC_SPACES
	EX	DE,HL		;
	POP	HL		;
	DEC	BC		;
	DEC	BC		;
	PUSH	BC		;
	LDDR			; Copy Bytes
	EX	DE,HL		;
	POP	BC		;
	DEC	BC		;
	LD	(HL),B		;
	DEC	HL		;
	LD	(HL),C		;
	POP	AF		;

mark_13E7:
L_FIRST:
	PUSH	AF		;
	CALL	REC_V80
	POP	AF		;
	DEC	HL		;
	LD	(HL),A		;
	LD	HL,(STKBOT)	; sv
	LD	(E_LINE),HL	; sv
	DEC	HL		;
	LD	(HL),$80	;
	RET			;


; THE 'STK_FETCH' SUBROUTINE

; This routine fetches a five-byte value from the calculator stack
; reducing the pointer to the end of the stack by five.
; For a floating-point number the exponent is in A and the mantissa
; is the thirty-two bits EDCB.
; For strings, the start of the string is in DE and the length in BC.
; A is unused.

mark_13F8:
STK_FETCH:
	LD	HL,(STKEND)	; load HL from system variable STKEND

	DEC	HL		;
	LD	B,(HL)		;
	DEC	HL		;
	LD	C,(HL)		;
	DEC	HL		;
	LD	D,(HL)		;
	DEC	HL		;
	LD	E,(HL)		;
	DEC	HL		;
	LD	A,(HL)		;

	LD	(STKEND),HL	; set system variable STKEND to lower value.
	RET			; return.


; THE 'DIM' COMMAND ROUTINE

; An array is created and initialized to zeros which is also the space
; character on the ZX81.

mark_1409:
DIM:
	CALL	LOOK_VARS

mark_140C:
D_RPORT_C:
	JP	NZ,REPORT_C

	CALL	SYNTAX_Z
	JR	NZ,D_RUN	; forward

	RES	6,C		;
	CALL	STK_VAR
	CALL	CHECK_END

mark_141C:
D_RUN:
	JR	C,D_LETTER	; forward

	PUSH	BC		;
	CALL	NEXT_ONE
	CALL	RECLAIM_2
	POP	BC		;

mark_1426:
D_LETTER:
	SET	7,C		;
	LD	B,$00		;
	PUSH	BC		;
	LD	HL,$0001	;
	BIT	6,C		;
	JR	NZ,D_SIZE	; forward

	LD	L,$05		;

mark_1434:
D_SIZE:
	EX	DE,HL		;

mark_1435:
D_NO_LOOP:
	RST	_NEXT_CHAR
	LD	H,$40		;
	CALL	INT_EXP1
	JP	C,REPORT_3

	POP	HL		;
	PUSH	BC		;
	INC	H		;
	PUSH	HL		;
	LD	H,B		;
	LD	L,C		;
	CALL	GET_HL_TIMES_DE
	EX	DE,HL		;

	RST	_GET_CHAR
	CP	ZX_COMMA	; $1A == 26
	JR	Z,D_NO_LOOP	; back

	CP	ZX_BRACKET_RIGHT; is it ')' ?
	JR	NZ,D_RPORT_C	; back if not


	RST	_NEXT_CHAR
	POP	BC		;
	LD	A,C		;
	LD	L,B		;
	LD	H,$00		;
	INC	HL		;
	INC	HL		;
	ADD	HL,HL		;
	ADD	HL,DE		;
	JP	C,REPORT_4

	PUSH	DE		;
	PUSH	BC		;
	PUSH	HL		;
	LD	B,H		;
	LD	C,L		;
	LD	HL,(E_LINE)	; sv
	DEC	HL		;
	CALL	MAKE_ROOM
	INC	HL		;
	LD	(HL),A	;
	POP	BC		;
	DEC	BC		;
	DEC	BC		;
	DEC	BC		;
	INC	HL		;
	LD	(HL),C		;
	INC	HL		;
	LD	(HL),B		;
	POP	AF		;
	INC	HL		;
	LD	(HL),A		;
	LD	H,D		;
	LD	L,E		;
	DEC	DE		;
	LD	(HL),0		;
	POP	BC		;
	LDDR			; Copy Bytes

mark_147F:
DIM_SIZES:
	POP	BC		;
	LD	(HL),B		;
	DEC	HL		;
	LD	(HL),C		;
	DEC	HL		;
	DEC	A		;
	JR	NZ,DIM_SIZES	; back

	RET			; return.


; THE 'RESERVE' ROUTINE

;
;

mark_1488:
RESERVE:
	LD	HL,(STKBOT)	; address STKBOT
	DEC	HL		; now last byte of workspace
	CALL	MAKE_ROOM
	INC	HL		;
	INC	HL		;
	POP	BC		;
	LD	(E_LINE),BC	; sv
	POP	BC		;
	EX	DE,HL		;
	INC	HL		;
	RET			;


; THE 'CLEAR' COMMAND ROUTINE

;
;

mark_149A:
CLEAR:
	LD	HL,(VARS)	; sv
	LD	(HL),$80	;
	INC	HL		;
	LD	(E_LINE),HL	; sv


; THE 'X_TEMP' SUBROUTINE

;
;

mark_14A3:
X_TEMP:
	LD	HL,(E_LINE)	; sv


; THE 'SET_STK' ROUTINES

;
;

mark_14A6:
SET_STK_B:
	LD	(STKBOT),HL	; sv

;

mark_14A9:
SET_STK_E:
	LD	(STKEND),HL	; sv
	RET			;


; THE 'CURSOR_IN' ROUTINE

; This routine is called to set the edit line to the minimum cursor/newline
; and to set STKEND, the start of free space, at the next position.

mark_14AD:
CURSOR_IN:
	LD	HL,(E_LINE)		; fetch start of edit line
	LD	(HL),ZX_CURSOR		; insert cursor character

	INC	HL			; point to next location.
	LD	(HL),ZX_NEWLINE		; insert NEWLINE character
	INC	HL			; point to next free location.

	LD	(IY+DF_SZ-RAMBASE),2	; set lower screen display file size

	JR	SET_STK_B		; exit via SET_STK_B above


; THE 'SET_MIN' SUBROUTINE

;
;

mark_14BC:
SET_MIN:
	LD	HL,$405D	; normal location of calculator's memory area
	LD	(MEM),HL	; update system variable MEM
	LD	HL,(STKBOT)	;
	JR	SET_STK_E		; back



; THE 'RECLAIM THE END_MARKER' ROUTINE


mark_14C7:
REC_V80:
	LD	DE,(E_LINE)	; sv
	JP	RECLAIM_1


; THE 'ALPHA' SUBROUTINE


mark_14CE:
ALPHA:
	CP	ZX_A		; $26
	JR	ALPHA_2		; skip forward



; THE 'ALPHANUM' SUBROUTINE


mark_14D2:
ALPHANUM:
	CP	ZX_0		;


mark_14D4:
ALPHA_2:
	CCF			; Complement Carry Flag
	RET	NC		;

	CP	$40		;
	RET			;



; THE 'DECIMAL TO FLOATING POINT' SUBROUTINE

;

mark_14D9:
DEC_TO_FP:
	CALL	INT_TO_FP		; gets first part
	CP	ZX_PERIOD		; is character a '.' ?
	JR	NZ,E_FORMAT	; forward if not


	RST	_FP_CALC	;;
	DEFB	__stk_one	;;
	DEFB	__st_mem_0	;;
	DEFB	__delete	;;
	DEFB	__end_calc	;;


mark_14E5:

NXT_DGT_1:
	RST	_NEXT_CHAR
	CALL	STK_DIGIT
	JR	C,E_FORMAT	; forward


	RST	_FP_CALC	;;
	DEFB	__get_mem_0	;;
	DEFB	__stk_ten	;;
if ORIGINAL
	DEFB	__division	;
	DEFB	$C0		;;st-mem-0
	DEFB	__multiply	;;
else
	DEFB	$04		;;+multiply
	DEFB	$C0		;;st-mem-0
	DEFB	$05		;;+division
endif
	DEFB	__addition	;;
	DEFB	__end_calc	;;

	JR	NXT_DGT_1		; loop back till exhausted

; ___

mark_14F5:
E_FORMAT:
	CP	ZX_E		; is character 'E' ?
	RET	NZ		; return if not

	LD	(IY+MEM_0_1st-RAMBASE),$FF	; initialize sv MEM_0_1st to $FF TRUE

	RST	_NEXT_CHAR
	CP	ZX_PLUS		; is character a '+' ?
	JR	Z,SIGN_DONE	; forward if so

	CP	ZX_MINUS		; is it a '-' ?
	JR	NZ,ST_E_PART	; forward if not

	INC	(IY+MEM_0_1st-RAMBASE)	; sv MEM_0_1st change to FALSE

mark_1508:
SIGN_DONE:
	RST	_NEXT_CHAR

mark_1509:
ST_E_PART:
	CALL	INT_TO_FP

	RST	_FP_CALC	;;		m, e.
	DEFB	__get_mem_0	;;		m, e, (1/0) TRUE/FALSE
	DEFB	__jump_true	;;
	DEFB	E_POSTVE - $	;;
	DEFB	__negate	;;		m, _e

mark_1511:
E_POSTVE:
	DEFB	__e_to_fp	;;		x.
	DEFB	__end_calc	;;		x.

	RET			; return.



; THE 'STK_DIGIT' SUBROUTINE

;

mark_1514:
STK_DIGIT:
	CP	ZX_0		;
	RET	C		;

	CP	ZX_A		; $26
	CCF			; Complement Carry Flag
	RET	C		;

	SUB	ZX_0		;


; THE 'STACK_A' SUBROUTINE

;


mark_151D:
STACK_A:
	LD	C,A		;
	LD	B,0		;


; THE 'STACK_BC' SUBROUTINE

; The ZX81 does not have an integer number format so the BC register contents
; must be converted to their full floating-point form.

mark_1520:
STACK_BC:
	LD	IY,ERR_NR	; re-initialize the system variables pointer.
	PUSH	BC		; save the integer value.

; now stack zero, five zero bytes as a starting point.

	RST	_FP_CALC	;;
	DEFB	__stk_zero	;;			0.
	DEFB	__end_calc	;;

	POP	BC		; restore integer value.

	LD	(HL),$91	; place $91 in exponent	65536.
				; this is the maximum possible value

	LD	A,B		; fetch hi-byte.
	AND	A		; test for zero.
	JR	NZ,STK_BC_2	; forward if not zero

	LD	(HL),A		; else make exponent zero again
	OR	C		; test lo-byte
	RET	Z		; return if BC was zero - done.

; else	there has to be a set bit if only the value one.

	LD	B,C		; save C in B.
	LD	C,(HL)		; fetch zero to C
	LD	(HL),$89	; make exponent $89		256.

mark_1536:
STK_BC_2:
	DEC	(HL)		; decrement exponent - halving number
	SLA	C		;	C<-76543210<-0
	RL	B		;	C<-76543210<-C
	JR	NC,STK_BC_2	; loop back if no carry

	SRL	B		;	0->76543210->C
	RR	C		;	C->76543210->C

	INC	HL		; address first byte of mantissa
	LD	(HL),B		; insert B
	INC	HL		; address second byte of mantissa
	LD	(HL),C		; insert C

	DEC	HL		; point to the
	DEC	HL		; exponent again
	RET			; return.


; THE 'INTEGER TO FLOATING POINT' SUBROUTINE

;
;

mark_1548:
INT_TO_FP:
	PUSH	AF		;

	RST	_FP_CALC	;;
	DEFB	__stk_zero	;;
	DEFB	__end_calc	;;

	POP	AF		;

mark_154D:
NXT_DGT_2:
	CALL	STK_DIGIT
	RET	C		;

	RST	_FP_CALC	;;
	DEFB	__exchange	;;
	DEFB	__stk_ten	;;
	DEFB	__multiply	;;
	DEFB	__addition	;;
	DEFB	__end_calc	;;

	RST	_NEXT_CHAR
	JR	NXT_DGT_2



; THE 'E_FORMAT TO FLOATING POINT' SUBROUTINE

; (Offset $38: 'e_to_fp')
; invoked from DEC_TO_FP and PRINT_FP.
; e.g. 2.3E4 is 23000.
; This subroutine evaluates xEm where m is a positive or negative integer.
; At a simple level x is multiplied by ten for every unit of m.
; If the decimal exponent m is negative then x is divided by ten for each unit.
; A short-cut is taken if the exponent is greater than seven and in this
; case the exponent is reduced by seven and the value is multiplied or divided
; by ten million.
; Note. for the ZX Spectrum an even cleverer method was adopted which involved
; shifting the bits out of the exponent so the result was achieved with six
; shifts at most. The routine below had to be completely re-written mostly
; in Z80 machine code.
; Although no longer operable, the calculator literal was retained for old
; times sake, the routine being invoked directly from a machine code CALL.
;
; On entry in the ZX81, m, the exponent, is the 'last value', and the
; floating-point decimal mantissa is beneath it.


mark_155A:
e_to_fp:
	RST	_FP_CALC	;;		x, m.
	DEFB	__duplicate	;;		x, m, m.
	DEFB	__less_0	;;		x, m, (1/0).
	DEFB	__st_mem_0	;;		x, m, (1/0).
	DEFB	__delete	;;		x, m.
	DEFB	__abs		;;		x, +m.

mark_1560:
E_LOOP:
	DEFB	__stk_one	;;		x, m,1.
	DEFB	__subtract	;;		x, m-1.
	DEFB	__duplicate	;;		x, m-1,m-1.
	DEFB	__less_0	;;		x, m-1, (1/0).
	DEFB	__jump_true	;;		x, m-1.
	DEFB	E_END - $	;;		x, m-1.

	DEFB	__duplicate	;;		x, m-1, m-1.
	DEFB	__stk_data	;;
	DEFB	$33		;;Exponent: $83, Bytes: 1

	DEFB	$40		;;(+00,+00,+00)	x, m-1, m-1, 6.
	DEFB	__subtract	;;		x, m-1, m-7.
	DEFB	__duplicate	;;		x, m-1, m-7, m-7.
	DEFB	__less_0	;;		x, m-1, m-7, (1/0).
	DEFB	__jump_true	;;		x, m-1, m-7.
	DEFB	E_LOW - $	;;

; but if exponent m is higher than 7 do a bigger chunk.
; multiplying (or dividing if negative) by 10 million - 1e7.

	DEFB	__exchange	;;		x, m-7, m-1.
	DEFB	__delete	;;		x, m-7.
	DEFB	__exchange	;;		m-7, x.
	DEFB	__stk_data	;;
	DEFB	$80		;;Bytes: 3
	DEFB	$48		;;Exponent $98
	DEFB	$18,$96,$80	;;(+00)		m-7, x, 10,000,000 (=f)
	DEFB	__jump		;;
	DEFB	E_CHUNK - $	;;

; ___

mark_157A:
E_LOW:
	DEFB	__delete	;;		x, m-1.
	DEFB	__exchange	;;		m-1, x.
	DEFB	__stk_ten	;;		m-1, x, 10 (=f).

mark_157D:
E_CHUNK:
	DEFB	__get_mem_0	;;		m-1, x, f, (1/0)
	DEFB	__jump_true	;;		m-1, x, f
	DEFB	E_DIVSN - $	;;

	DEFB	__multiply	;;		m-1, x*f.
	DEFB	__jump		;;
	DEFB	E_SWAP - $	;;

; ___

mark_1583:
E_DIVSN:
	DEFB	__division	;;		m-1, x/f (= new x).

mark_1584:
E_SWAP:
	DEFB	__exchange	;;		x, m-1 (= new m).
	DEFB	__jump		;;		x, m.
	DEFB	E_LOOP - $	;;

; ___

mark_1587:
E_END:
	DEFB	__delete	;;		x. (-1)
	DEFB	__end_calc	;;		x.

	RET			; return.


; THE 'FLOATING-POINT TO BC' SUBROUTINE

; The floating-point form on the calculator stack is compressed directly into
; the BC register rounding up if necessary.
; Valid range is 0 to 65535.4999

mark_158A:
FP_TO_BC:
	CALL	STK_FETCH		; exponent to A
				; mantissa to EDCB.
	AND	A		; test for value zero.
	JR	NZ,FPBC_NZRO	; forward if not

; else value is zero

	LD	B,A		; zero to B
	LD	C,A		; also to C
	PUSH	AF		; save the flags on machine stack
	JR	FPBC_END		; forward

; ___

; EDCB	=>	BCE

mark_1595:
FPBC_NZRO:
	LD	B,E		; transfer the mantissa from EDCB
	LD	E,C		; to BCE. Bit 7 of E is the 17th bit which
	LD	C,D		; will be significant for rounding if the
				; number is already normalized.

	SUB	$91		; subtract 65536
	CCF			; complement carry flag
	BIT	7,B		; test sign bit
	PUSH	AF		; push the result

	SET	7,B		; set the implied bit
	JR	C,FPBC_END	; forward with carry from SUB/CCF
				; number is too big.

	INC	A		; increment the exponent and
	NEG			; negate to make range $00 - $0F

	CP	$08		; test if one or two bytes
	JR	C,BIG_INT	; forward with two

	LD	E,C		; shift mantissa
	LD	C,B		; 8 places right
	LD	B,$00		; insert a zero in B
	SUB	$08		; reduce exponent by eight

mark_15AF:
BIG_INT:
	AND	A		; test the exponent
	LD	D,A		; save exponent in D.

	LD	A,E		; fractional bits to A
	RLCA			; rotate most significant bit to carry for
				; rounding of an already normal number.

	JR	Z,EXP_ZERO	; forward if exponent zero
				; the number is normalized

mark_15B5:
FPBC_NORM:
	SRL	B		;	0->76543210->C
	RR	C		;	C->76543210->C

	DEC	D		; decrement exponent

	JR	NZ,FPBC_NORM	; loop back till zero

mark_15BC:
EXP_ZERO:
	JR	NC,FPBC_END	; forward without carry to NO_ROUND	???

	INC	BC		; round up.
	LD	A,B		; test result
	OR	C		; for zero
	JR	NZ,FPBC_END	; forward if not to GRE_ZERO	???

	POP	AF		; restore sign flag
	SCF			; set carry flag to indicate overflow
	PUSH	AF		; save combined flags again

mark_15C6:
FPBC_END:
	PUSH	BC		; save BC value

; set HL and DE to calculator stack pointers.

	RST	_FP_CALC	;;
	DEFB	__end_calc	;;


	POP	BC		; restore BC value
	POP	AF		; restore flags
	LD	A,C		; copy low byte to A also.
	RET			; return


; THE 'FLOATING-POINT TO A' SUBROUTINE

;
;

mark_15CD:
FP_TO_A:
	CALL	FP_TO_BC
	RET	C		;

	PUSH	AF		;
	DEC	B		;
	INC	B		;
	JR	Z,FP_A_END	; forward if in range

	POP	AF		; fetch result
	SCF			; set carry flag signaling overflow
	RET			; return

mark_15D9:
FP_A_END:
	POP	AF		;
	RET			;



; THE 'PRINT A FLOATING-POINT NUMBER' SUBROUTINE

; prints 'last value' x on calculator stack.
; There are a wide variety of formats see Chapter 4.
; e.g. 
; PI		prints as	3.1415927
; .123		prints as	0.123
; .0123	prints as	.0123
; 999999999999	prints as	1000000000000
; 9876543210123 prints as	9876543200000

; Begin by isolating zero and just printing the '0' character
; for that case. For negative numbers print a leading '-' and
; then form the absolute value of x.

mark_15DB:
PRINT_FP:
	RST	_FP_CALC	;;		x.
	DEFB	__duplicate	;;		x, x.
	DEFB	__less_0	;;		x, (1/0).
	DEFB	__jump_true	;;
	DEFB	PF_NEGTVE - $	;;	 	x.

	DEFB	__duplicate	;;		x, x
	DEFB	__greater_0	;;		x, (1/0).
	DEFB	__jump_true	;;
	DEFB	PF_POSTVE - $	;;		x.

	DEFB	__delete	;;		.
	DEFB	__end_calc	;;		.

	LD	A,ZX_0		; load accumulator with character '0'

	RST	_PRINT_A
	RET			; return.				>>

; ___

mark_15EA:
PF_NEGTVE:
	DEFB	__abs		;;		+x.
	DEFB	__end_calc	;;		x.

	LD	A,ZX_MINUS	; load accumulator with '-'

	RST	_PRINT_A

	RST	_FP_CALC	;;		x.

mark_15F0:
PF_POSTVE:
	DEFB	__end_calc	;;		x.

; register HL addresses the exponent of the floating-point value.
; if positive, and point floats to left, then bit 7 is set.

	LD	A,(HL)		; pick up the exponent byte
	CALL	STACK_A		; places on calculator stack.

; now calculate roughly the number of digits, n, before the decimal point by
; subtracting a half from true exponent and multiplying by log to 
; the base 10 of 2. 
; The true number could be one higher than n, the integer result.

	RST	_FP_CALC	;;			x, e.
	DEFB	__stk_data	;;
	DEFB	$78		;;Exponent: $88, Bytes: 2
	DEFB	$00,$80		;;(+00,+00)		x, e, 128.5.
	DEFB	__subtract	;;			x, e -.5.
	DEFB	__stk_data	;;
	DEFB	$EF		;;Exponent: $7F, Bytes: 4
	DEFB	$1A,$20,$9A,$85 ;;			.30103 (log10 2)
	DEFB	__multiply	;;			x,
	DEFB	__int		;;
	DEFB	__st_mem_1	;;			x, n.


	DEFB	__stk_data	;;
	DEFB	$34		;;Exponent: $84, Bytes: 1
	DEFB	$00		;;(+00,+00,+00)		x, n, 8.

	DEFB	__subtract	;;			x, n-8.
	DEFB	__negate	;;			x, 8-n.
	DEFB	__e_to_fp	;;			x * (10^n)

; finally the 8 or 9 digit decimal is rounded.
; a ten-digit integer can arise in the case of, say, 999999999.5
; which gives 1000000000.

	DEFB	__stk_half	;;
	DEFB	__addition	;;
	DEFB	__int		;;			i.
	DEFB	__end_calc	;;

; If there were 8 digits then final rounding will take place on the calculator 
; stack above and the next two instructions insert a masked zero so that
; no further rounding occurs. If the result is a 9 digit integer then
; rounding takes place within the buffer.

	LD	HL,$406B	; address system variable MEM_2_5th
				; which could be the 'ninth' digit.
	LD	(HL),$90	; insert the value $90	10010000

; now starting from lowest digit lay down the 8, 9 or 10 digit integer
; which represents the significant portion of the number
; e.g. PI will be the nine-digit integer 314159265

	LD	B,10		; count is ten digits.

mark_1615:
PF_LOOP:
	INC	HL		; increase pointer

	PUSH	HL		; preserve buffer address.
	PUSH	BC		; preserve counter.

	RST	_FP_CALC	;;		i.
	DEFB	__stk_ten	;;		i, 10.
	DEFB	__n_mod_m	;;		i mod 10, i/10
	DEFB	__exchange	;;		i/10, remainder.
	DEFB	__end_calc	;;

	CALL	FP_TO_A		; $00-$09

	OR	$90		; make left hand nibble 9 

	POP	BC		; restore counter
	POP	HL		; restore buffer address.

	LD	(HL),A		; insert masked digit in buffer.
	DJNZ	PF_LOOP		; loop back for all ten 

; the most significant digit will be last but if the number is exhausted then
; the last one or two positions will contain zero ($90).

; e.g. for 'one' we have zero as estimate of leading digits.
; 1*10^8 100000000 as integer value
; 90 90 90 90 90	90 90 90 91 90 as buffer mem3/mem4 contents.


	INC	HL		; advance pointer to one past buffer 
	LD	BC,$0008	; set C to 8 ( B is already zero )
	PUSH	HL		; save pointer.

mark_162C:
PF_NULL:
	DEC	HL		; decrease pointer
	LD	A,(HL)		; fetch masked digit
	CP	$90		; is it a leading zero ?
	JR	Z,PF_NULL	; loop back if so

; at this point a significant digit has been found. carry is reset.

	SBC	HL,BC		; subtract eight from the address.
	PUSH	HL		; ** save this pointer too
	LD	A,(HL)		; fetch addressed byte
	ADD	A,$6B		; add $6B - forcing a round up ripple
				; if	$95 or over.
	PUSH	AF		; save the carry result.

; now enter a loop to round the number. After rounding has been considered
; a zero that has arisen from rounding or that was present at that position
; originally is changed from $90 to $80.

mark_1639:
PF_RND_LP:
	POP	AF		; retrieve carry from machine stack.
	INC	HL		; increment address
	LD	A,(HL)		; fetch new byte
	ADC	A,0		; add in any carry

	DAA			; decimal adjust accumulator
				; carry will ripple through the '9'

	PUSH	AF		; save carry on machine stack.
	AND	$0F		; isolate character 0 - 9 AND set zero flag
				; if zero.
	LD	(HL),A		; place back in location.
	SET	7,(HL)		; set bit 7 to show printable.
				; but not if trailing zero after decimal point.
	JR	Z,PF_RND_LP	; back if a zero
				; to consider further rounding and/or trailing
				; zero identification.

	POP	AF		; balance stack
	POP	HL		; ** retrieve lower pointer

; now insert 6 trailing zeros which are printed if before the decimal point
; but mark the end of printing if after decimal point.
; e.g. 9876543210123 is printed as 9876543200000
; 123.456001 is printed as 123.456

	LD	B,6		; the count is six.

mark_164B:
PF_ZERO_6:
	LD	(HL),$80	; insert a masked zero
	DEC	HL		; decrease pointer.
	DJNZ	PF_ZERO_6	; loop back for all six

; n-mod-m reduced the number to zero and this is now deleted from the calculator
; stack before fetching the original estimate of leading digits.


	RST	_FP_CALC	;;		0.
	DEFB	__delete	;;		.
	DEFB	__get_mem_1	;;		n.
	DEFB	__end_calc	;;		n.

	CALL	FP_TO_A
	JR	Z,PF_POS	; skip forward if positive

	NEG			; negate makes positive

mark_165B:
PF_POS:
	LD	E,A		; transfer count of digits to E
	INC	E		; increment twice 
	INC	E		; 
	POP	HL		; * retrieve pointer to one past buffer.

mark_165F:
GET_FIRST:
	DEC	HL		; decrement address.
	DEC	E		; decrement digit counter.
	LD	A,(HL)		; fetch masked byte.
	AND	$0F		; isolate right-hand nibble.
	JR	Z,GET_FIRST	; back with leading zero

; now determine if E-format printing is needed

	LD	A,E		; transfer now accurate number count to A.
	SUB	5		; subtract five
	CP	8		; compare with 8 as maximum digits is 13.
	JP	P,PF_E_FMT	; forward if positive to PF_E_FMT

	CP	$F6		; test for more than four zeros after point.
	JP	M,PF_E_FMT	; forward if so to PF_E_FMT

	ADD	A,6		; test for zero leading digits, e.g. 0.5
	JR	Z,PF_ZERO_1	; forward if so to PF_ZERO_1 

	JP	M,PF_ZEROS	; forward if more than one zero to PF_ZEROS

; else digits before the decimal point are to be printed

	LD	B,A		; count of leading characters to B.

mark_167B:
PF_NIB_LP:
	CALL	PF_NIBBLE
	DJNZ	PF_NIB_LP		; loop back for counted numbers

	JR	PF_DC_OUT		; forward to consider decimal part to PF_DC_OUT

; ___

mark_1682:
PF_E_FMT:
	LD	B,E		; count to B
	CALL	PF_NIBBLE		; prints one digit.
	CALL	PF_DC_OUT		; considers fractional part.

	LD	A,ZX_E		; 
	RST	_PRINT_A

	LD	A,B		; transfer exponent to A
	AND	A		; test the sign.
	JP	P,PF_E_POS	; forward if positive to PF_E_POS

	NEG			; negate the negative exponent.
	LD	B,A		; save positive exponent in B.

	LD	A,ZX_MINUS	; 
	JR	PF_E_SIGN		; skip forward to PF_E_SIGN

; ___

mark_1698:
PF_E_POS:
	LD	A,ZX_PLUS	; 

mark_169A:
PF_E_SIGN:
	RST	_PRINT_A

; now convert the integer exponent in B to two characters.
; it will be less than 99.

	LD	A,B		; fetch positive exponent.
	LD	B,$FF		; initialize left hand digit to minus one.

mark_169E:
PF_E_TENS:
	INC	B		; increment ten count
	SUB	10		; subtract ten from exponent
	JR	NC,PF_E_TENS	; loop back if greater than ten

	ADD	A,10		; reverse last subtraction
	LD	C,A		; transfer remainder to C

	LD	A,B		; transfer ten value to A.
	AND	A		; test for zero.
	JR	Z,PF_E_LOW	; skip forward if so to PF_E_LOW

	CALL	OUT_CODE		; prints as digit '1' - '9'

mark_16AD:
PF_E_LOW:
	LD	A,C		; low byte to A
	CALL	OUT_CODE		; prints final digit of the
				; exponent.
	RET			; return.				>>


; THE 'FLOATING POINT PRINT ZEROS' LOOP
; -------------------------------------
; This branch deals with zeros after decimal point.
; e.g.      .01 or .0000999
; Note. that printing to the ZX Printer destroys A and that A should be 
; initialized to '0' at each stage of the loop.
; Originally LPRINT .00001 printed as .0XYZ1

mark_16B2:
PF_ZEROS:
	NEG			; negate makes number positive 1 to 4.
	LD	B,A		; zero count to B.

	LD	A,ZX_PERIOD	; prepare character '.'
	RST	_PRINT_A


if ORIGINAL
	LD	A,ZX_0		; prepare a '0'
PFZROLP:
	RST	_PRINT_A
	DJNZ	PFZROLP		; obsolete loop back to PFZROLP
else
PF_ZRO_LP:
	LD	A,ZX_0		; prepare a '0' in the accumulator each time.
	RST	_PRINT_A
	DJNZ	PF_ZRO_LP	;+ New loop back to PF-ZRO-LP
endif

	JR	PF_FRAC_LP		; forward

; there is	a need to print a leading zero e.g. 0.1 but not with .01

mark_16BF:
PF_ZERO_1:
	LD	A,ZX_0		; prepare character '0'.
	RST	_PRINT_A

; this subroutine considers the decimal point and any trailing digits.
; if the next character is a marked zero, $80, then nothing more to print.

mark_16C2:
PF_DC_OUT:
	DEC	(HL)		; decrement addressed character
	INC	(HL)		; increment it again
	RET	PE		; return with overflow	(was 128) >>
				; as no fractional part

; else there is a fractional part so print the decimal point.

	LD	A,ZX_PERIOD		; prepare character '.'
	RST	_PRINT_A

; now enter a loop to print trailing digits

mark_16C8:
PF_FRAC_LP:
	DEC	(HL)		; test for a marked zero.
	INC	(HL)		;
	RET	PE		; return when digits exhausted		>>

	CALL	PF_NIBBLE
	JR	PF_FRAC_LP		; back for all fractional digits

; ___

; subroutine to print right-hand nibble

mark_16D0:
PF_NIBBLE:
	LD	A,(HL)		; fetch addressed byte
	AND	$0F		; mask off lower 4 bits
	CALL	OUT_CODE
	DEC	HL		; decrement pointer.
	RET			; return.



; THE 'PREPARE TO ADD' SUBROUTINE

; This routine is called twice to prepare each floating point number for
; addition, in situ, on the calculator stack.
; The exponent is picked up from the first byte which is then cleared to act
; as a sign byte and accept any overflow.
; If the exponent is zero then the number is zero and an early return is made.
; The now redundant sign bit of the mantissa is set and if the number is 
; negative then all five bytes of the number are twos-complemented to prepare 
; the number for addition.
; On the second invocation the exponent of the first number is in B.


mark_16D8:
PREP_ADD:
	LD	A,(HL)		; fetch exponent.
	LD	(HL),0		; make this byte zero to take any overflow and
				; default to positive.
	AND	A		; test stored exponent for zero.
	RET	Z		; return with zero flag set if number is zero.

	INC	HL		; point to first byte of mantissa.
	BIT	7,(HL)		; test the sign bit.
	SET	7,(HL)		; set it to its implied state.
	DEC	HL		; set pointer to first byte again.
	RET	Z		; return if bit indicated number is positive.>>

; if negative then all five bytes are twos complemented starting at LSB.

	PUSH	BC		; save B register contents.
	LD	BC,$0005	; set BC to five.
	ADD	HL,BC		; point to location after 5th byte.
	LD	B,C		; set the B counter to five.
	LD	C,A		; store original exponent in C.
	SCF			; set carry flag so that one is added.

; now enter a loop to twos_complement the number.
; The first of the five bytes becomes $FF to denote a negative number.

mark_16EC:
NEG_BYTE:
	DEC	HL		; point to first or more significant byte.
	LD	A,(HL)		; fetch to accumulator.
	CPL			; complement.
	ADC	A,0		; add in initial carry or any subsequent carry.
	LD	(HL),A		; place number back.
	DJNZ	NEG_BYTE		; loop back five times

	LD	A,C		; restore the exponent to accumulator.
	POP	BC		; restore B register contents.

	RET			; return.


; THE 'FETCH TWO NUMBERS' SUBROUTINE

; This routine is used by addition, multiplication and division to fetch
; the two five_byte numbers addressed by HL and DE from the calculator stack
; into the Z80 registers.
; The HL register may no longer point to the first of the two numbers.
; Since the 32-bit addition operation is accomplished using two Z80 16-bit
; instructions, it is important that the lower two bytes of each mantissa are
; in one set of registers and the other bytes all in the alternate set.
;
; In: HL = highest number, DE= lowest number
;
;	: alt':
;	:
; Out:
;	:H,B-C:C,B: num1
;	:L,D-E:D-E: num2

mark_16F7:
FETCH_TWO:
	PUSH	HL		; save HL 
	PUSH	AF		; save A - result sign when used from division.

	LD	C,(HL)		;
	INC	HL		;
	LD	B,(HL)		;
	LD	(HL),A		; insert sign when used from multiplication.
	INC	HL		;
	LD	A,C		; m1
	LD	C,(HL)		;
	PUSH	BC		; PUSH m2 m3

	INC	HL		;
	LD	C,(HL)		; m4
	INC	HL		;
	LD	B,(HL)		; m5	BC holds m5 m4

	EX	DE,HL		; make HL point to start of second number.

	LD	D,A		; m1
	LD	E,(HL)		;
	PUSH	DE		; PUSH m1 n1

	INC	HL		;
	LD	D,(HL)		;
	INC	HL		;
	LD	E,(HL)		;
	PUSH	DE		; PUSH n2 n3

	EXX			; - - - - - - -

	POP	DE		; POP n2 n3
	POP	HL		; POP m1 n1
	POP	BC		; POP m2 m3

	EXX			; - - - - - - -

	INC	HL		;
	LD	D,(HL)		;
	INC	HL		;
	LD	E,(HL)		; DE holds n4 n5

	POP	AF		; restore saved
	POP	HL		; registers.
	RET			; return.


; THE 'SHIFT ADDEND' SUBROUTINE

; The accumulator A contains the difference between the two exponents.
; This is the lowest of the two numbers to be added 

mark_171A:
SHIFT_FP:
	AND	A		; test difference between exponents.
	RET	Z		; return if zero. both normal.

	CP	33		; compare with 33 bits.
	JR	NC,ADDEND_0	; forward if greater than 32

	PUSH	BC		; preserve BC - part 
	LD	B,A		; shift counter to B.

; Now perform B right shifts on the addend	L'D'E'D E
; to bring it into line with the augend	H'B'C'C B

mark_1722:
ONE_SHIFT:
	EXX			; - - -
	SRA	L		;	76543210->C	bit 7 unchanged.
	RR	D		; C->76543210->C
	RR	E		; C->76543210->C
	EXX			; - - - 
	RR	D		; C->76543210->C
	RR	E		; C->76543210->C
	DJNZ	ONE_SHIFT		; loop back B times

	POP	BC		; restore BC
	RET	NC		; return if last shift produced no carry.	>>

; if carry flag was set then accuracy is being lost so round up the addend.

	CALL	ADD_BACK
	RET	NZ		; return if not FF 00 00 00 00

; this branch makes all five bytes of the addend zero and is made during
; addition when the exponents are too far apart for the addend bits to 
; affect the result.

mark_1736:
ADDEND_0:
	EXX			; select alternate set for more significant 
				; bytes.
	XOR	A		; clear accumulator.


; this entry point (from multiplication) sets four of the bytes to zero or if 
; continuing from above, during addition, then all five bytes are set to zero.

mark_1738:
ZEROS_4_OR_5:
	LD	L,0		; set byte 1 to zero.
	LD	D,A		; set byte 2 to A.
	LD	E,L		; set byte 3 to zero.
	EXX			; select main set 
	LD	DE,$0000	; set lower bytes 4 and 5 to zero.
	RET			; return.


; THE 'ADD_BACK' SUBROUTINE

; Called from SHIFT_FP above during addition and after normalization from
; multiplication.
; This is really a 32_bit increment routine which sets the zero flag according
; to the 32-bit result.
; During addition, only negative numbers like FF FF FF FF FF,
; the twos-complement version of xx 80 00 00 01 say 
; will result in a full ripple FF 00 00 00 00.
; FF FF FF FF FF when shifted right is unchanged by SHIFT_FP but sets the 
; carry invoking this routine.

mark_1741:
ADD_BACK:
	INC	E		;
	RET	NZ		;

	INC	D		;
	RET	NZ		;

	EXX			;
	INC	E		;
	JR	NZ,ALL_ADDED	; forward if no overflow

	INC	D		;

mark_174A:
ALL_ADDED:
	EXX			;
	RET			; return with zero flag set for zero mantissa.



; THE 'SUBTRACTION' OPERATION

; just switch the sign of subtrahend and do an add.

mark_174C:
SUBTRACT:
	LD	A,(DE)		; fetch exponent byte of second number the
				; subtrahend. 
	AND	A		; test for zero
	RET	Z		; return if zero - first number is result.

	INC	DE		; address the first mantissa byte.
	LD	A,(DE)		; fetch to accumulator.
	XOR	$80		; toggle the sign bit.
	LD	(DE),A		; place back on calculator stack.
	DEC	DE		; point to exponent byte.
				; continue into addition routine.


; THE 'ADDITION' OPERATION

; The addition operation pulls out all the stops and uses most of the Z80's
; registers to add two floating-point numbers.
; This is a binary operation and on entry, HL points to the first number
; and DE to the second.

mark_1755:
ADDITION:
	EXX			; - - -
	PUSH	HL		; save the pointer to the next literal.
	EXX			; - - -

	PUSH	DE		; save pointer to second number
	PUSH	HL		; save pointer to first number - will be the
				; result pointer on calculator stack.

	CALL	PREP_ADD
	LD	B,A		; save first exponent byte in B.
	EX	DE,HL		; switch number pointers.
	CALL	PREP_ADD
	LD	C,A		; save second exponent byte in C.
	CP	B		; compare the exponent bytes.
	JR	NC,SHIFT_LEN	; forward if second higher

	LD	A,B		; else higher exponent to A
	LD	B,C		; lower exponent to B
	EX	DE,HL		; switch the number pointers.

mark_1769:
SHIFT_LEN:
	PUSH	AF		; save higher exponent
	SUB	B		; subtract lower exponent

	CALL	FETCH_TWO
	CALL	SHIFT_FP

	POP	AF		; restore higher exponent.
	POP	HL		; restore result pointer.
	LD	(HL),A		; insert exponent byte.
	PUSH	HL		; save result pointer again.

; now perform the 32-bit addition using two 16-bit Z80 add instructions.

	LD	L,B		; transfer low bytes of mantissa individually
	LD	H,C		; to HL register

	ADD	HL,DE		; the actual binary addition of lower bytes

; now the two higher byte pairs that are in the alternate register sets.

	EXX			; switch in set 
	EX	DE,HL		; transfer high mantissa bytes to HL register.

	ADC	HL,BC		; the actual addition of higher bytes with
				; any carry from first stage.

	EX	DE,HL		; result in DE, sign bytes ($FF or $00) to HL

; now consider the two sign bytes

	LD	A,H		; fetch sign byte of num1

	ADC	A,L		; add including any carry from mantissa 
				; addition. 00 or 01 or FE or FF

	LD	L,A		; result in L.

; possible outcomes of signs and overflow from mantissa are
;
;	H +	L + carry =	L	RRA	XOR L	RRA

; 00 + 00		= 00	00	00
; 00 + 00 + carry	= 01	00	01	carry
; FF + FF		= FE C	FF	01	carry
; FF + FF + carry	= FF C	FF	00
; FF + 00		= FF	FF	00
; FF + 00 + carry	= 00 C	80	80

	RRA			; C->76543210->C
	XOR	L		; set bit 0 if shifting required.

	EXX			; switch back to main set
	EX	DE,HL		; full mantissa result now in D'E'D E registers.
	POP	HL		; restore pointer to result exponent on 
				; the calculator stack.

	RRA			; has overflow occurred ?
	JR	NC,TEST_NEG	; skip forward if not

; if the addition of two positive mantissas produced overflow or if the
; addition of two negative mantissas did not then the result exponent has to
; be incremented and the mantissa shifted one place to the right.

	LD	A,1		; one shift required.
	CALL	SHIFT_FP		; performs a single shift 
				; rounding any lost bit
	INC	(HL)		; increment the exponent.
	JR	Z,ADD_REP_6	; forward to ADD_REP_6 if the exponent
				; wraps round from FF to zero as number is too
				; big for the system.

; at this stage the exponent on the calculator stack is correct.

mark_1790:
TEST_NEG:
	EXX			; switch in the alternate set.
	LD	A,L		; load result sign to accumulator.
	AND	$80		; isolate bit 7 from sign byte setting zero
				; flag if positive.
	EXX			; back to main set.

	INC	HL		; point to first byte of mantissa
	LD	(HL),A		; insert $00 positive or $80 negative at 
				; position on calculator stack.

	DEC	HL		; point to exponent again.
	JR	Z,GO_NC_MLT	; forward if positive to GO_NC_MLT

; a negative number has to be twos-complemented before being placed on stack.

	LD	A,E		; fetch lowest (rightmost) mantissa byte.
	NEG			; Negate
	CCF			; Complement Carry Flag
	LD	E,A		; place back in register

	LD	A,D		; ditto
	CPL			;
	ADC	A,0		;
	LD	D,A		;

	EXX			; switch to higher (leftmost) 16 bits.

	LD	A,E		; ditto
	CPL			;
	ADC	A,0		;
	LD	E,A		;

	LD	A,D		; ditto
	CPL			;
	ADC	A,0		;
	JR	NC,END_COMPL	; forward without overflow to END_COMPL

; else entire mantissa is now zero.	00 00 00 00

	RRA			; set mantissa to 80 00 00 00
	EXX			; switch.
	INC	(HL)		; increment the exponent.

mark_17B3:
ADD_REP_6:
	JP	Z,REPORT_6	; jump forward if exponent now zero to REPORT_6
				; 'Number too big'

	EXX			; switch back to alternate set.

mark_17B7:
END_COMPL:
	LD	D,A		; put first byte of mantissa back in DE.
	EXX			; switch to main set.

mark_17B9:
GO_NC_MLT:
	XOR	A		; clear carry flag and
				; clear accumulator so no extra bits carried
				; forward as occurs in multiplication.

	JR	TEST_NORM		; forward to common code at TEST_NORM 
				; but should go straight to NORMALIZE.



; THE 'PREPARE TO MULTIPLY OR DIVIDE' SUBROUTINE

; this routine is called twice from multiplication and twice from division
; to prepare each of the two numbers for the operation.
; Initially the accumulator holds zero and after the second invocation bit 7
; of the accumulator will be the sign bit of the result.

mark_17BC:
PREP_MULTIPLY_OR_DIVIDE:
	SCF			; set carry flag to signal number is zero.
	DEC	(HL)		; test exponent
	INC	(HL)		; for zero.
	RET	Z		; return if zero with carry flag set.

	INC	HL		; address first mantissa byte.
	XOR	(HL)		; exclusive or the running sign bit.
	SET	7,(HL)		; set the implied bit.
	DEC	HL		; point to exponent byte.
	RET			; return.


; THE 'MULTIPLICATION' OPERATION

;
;

mark_17C6:
MULTIPLY:
	XOR	A		; reset bit 7 of running sign flag.
	CALL	PREP_MULTIPLY_OR_DIVIDE
	RET	C		; return if number is zero.
				; zero * anything = zero.

	EXX			; - - -
	PUSH	HL		; save pointer to 'next literal'
	EXX			; - - -

	PUSH	DE		; save pointer to second number 

	EX	DE,HL		; make HL address second number.

	CALL	PREP_MULTIPLY_OR_DIVIDE

	EX	DE,HL		; HL first number, DE - second number
	JR	C,ZERO_RESULT	; forward with carry to ZERO_RESULT
				; anything * zero = zero.

	PUSH	HL		; save pointer to first number.

	CALL	FETCH_TWO		; fetches two mantissas from
				; calc stack to B'C'C,B	D'E'D E
				; (HL will be overwritten but the result sign
				; in A is inserted on the calculator stack)

	LD	A,B		; transfer low mantissa byte of first number
	AND	A		; clear carry.
	SBC	HL,HL		; a short form of LD HL,$0000 to take lower
				; two bytes of result. (2 program bytes)
	EXX			; switch in alternate set
	PUSH	HL		; preserve HL
	SBC	HL,HL		; set HL to zero also to take higher two bytes
				; of the result and clear carry.
	EXX			; switch back.

	LD	B,33		; register B can now be used to count 33 shifts.
	JR	STRT_MLT		; forward to loop entry point STRT_MLT

; ___

; The multiplication loop is entered at	STRT_LOOP.

mark_17E7:
MLT_LOOP:
	JR	NC,NO_ADD	; forward if no carry

				; else add in the multiplicand.

	ADD	HL,DE		; add the two low bytes to result
	EXX			; switch to more significant bytes.
	ADC	HL,DE		; add high bytes of multiplicand and any carry.
	EXX			; switch to main set.

; in either case shift result right into B'C'C A

mark_17EE:
NO_ADD:
	EXX			; switch to alternate set
	RR	H		; C > 76543210 > C
	RR	L		; C > 76543210 > C
	EXX			;
	RR	H		; C > 76543210 > C
	RR	L		; C > 76543210 > C

mark_17F8:
STRT_MLT:
	EXX			; switch in alternate set.
	RR	B		; C > 76543210 > C
	RR	C		; C > 76543210 > C
	EXX			; now main set
	RR	C		; C > 76543210 > C
	RRA			; C > 76543210 > C
	DJNZ	MLT_LOOP		; loop back 33 timeS

;

	EX	DE,HL		;
	EXX			;
	EX	DE,HL		;
	EXX			;
	POP	BC		;
	POP	HL		;
	LD	A,B		;
	ADD	A,C		;
	JR	NZ,MAKE_EXPT	; forward

	AND	A		;

mark_180E:
MAKE_EXPT:
	DEC	A		;
	CCF			; Complement Carry Flag

mark_1810:
DIVN_EXPT:
	RLA			;
	CCF			; Complement Carry Flag
	RRA			;
	JP	P,OFLW1_CLR

	JR	NC,REPORT_6

	AND	A		;

mark_1819:
OFLW1_CLR:
	INC	A		;
	JR	NZ,OFLW2_CLR

	JR	C,OFLW2_CLR

	EXX			;
	BIT	7,D		;
	EXX			;
	JR	NZ,REPORT_6

mark_1824:
OFLW2_CLR:
	LD	(HL),A		;
	EXX			;
	LD	A,B		;
	EXX			;

; addition joins here with carry flag clear.

mark_1828:
TEST_NORM:
	JR	NC,NORMALIZE	; forward

	LD	A,(HL)		;
	AND	A		;

mark_182C:
NEAR_ZERO:
	LD	A,$80		; prepare to rescue the most significant bit 
				; of the mantissa if it is set.
	JR	Z,SKIP_ZERO	; skip forward

mark_1830:
ZERO_RESULT:
	XOR	A		; make mask byte zero signaling set five
				; bytes to zero.

mark_1831:
SKIP_ZERO:
	EXX			; switch in alternate set
	AND	D		; isolate most significant bit (if A is $80).

	CALL	ZEROS_4_OR_5		; sets mantissa without 
				; affecting any flags.

	RLCA			; test if MSB set. bit 7 goes to bit 0.
				; either $00 -> $00 or $80 -> $01
	LD	(HL),A		; make exponent $01 (lowest) or $00 zero
	JR	C,OFLOW_CLR	; forward if first case

	INC	HL		; address first mantissa byte on the
				; calculator stack.
	LD	(HL),A		; insert a zero for the sign bit.
	DEC	HL		; point to zero exponent
	JR	OFLOW_CLR		; forward

; ___

; this branch is common to addition and multiplication with the mantissa
; result still in registers D'E'D E .

mark_183F:
NORMALIZE:
	LD	B,32		; a maximum of thirty-two left shifts will be 
				; needed.

mark_1841:
SHIFT_ONE:
	EXX			; address higher 16 bits.
	BIT	7,D		; test the leftmost bit
	EXX			; address lower 16 bits.

	JR	NZ,NORML_NOW	; forward if leftmost bit was set

	RLCA			; this holds zero from addition, 33rd bit 
				; from multiplication.

	RL	E		; C < 76543210 < C
	RL	D		; C < 76543210 < C

	EXX			; address higher 16 bits.

	RL	E		; C < 76543210 < C
	RL	D		; C < 76543210 < C

	EXX			; switch to main set.

	DEC	(HL)		; decrement the exponent byte on the calculator
				; stack.

	JR	Z,NEAR_ZERO	; back if exponent becomes zero
				; it's just possible that the last rotation
				; set bit 7 of D. We shall see.

	DJNZ	SHIFT_ONE	; loop back

; if thirty-two left shifts were performed without setting the most significant 
; bit then the result is zero.

	JR	ZERO_RESULT	; back

; ___

mark_1859:
NORML_NOW:
	RLA			; for the addition path, A is always zero.
				; for the mult path, ...

	JR	NC,OFLOW_CLR	; forward

; this branch is taken only with multiplication.

	CALL	ADD_BACK

	JR	NZ,OFLOW_CLR	; forward

	EXX			;
	LD	D,$80		;
	EXX			;
	INC	(HL)		;
	JR	Z,REPORT_6	; forward

; now transfer the mantissa from the register sets to the calculator stack
; incorporating the sign bit already there.

mark_1868:
OFLOW_CLR:
	PUSH	HL		; save pointer to exponent on stack.
	INC	HL		; address first byte of mantissa which was 
				; previously loaded with sign bit $00 or $80.

	EXX			; - - -
	PUSH	DE		; push the most significant two bytes.
	EXX			; - - -

	POP	BC		; pop - true mantissa is now BCDE.

; now pick up the sign bit.

	LD	A,B		; first mantissa byte to A 
	RLA			; rotate out bit 7 which is set
	RL	(HL)		; rotate sign bit on stack into carry.
	RRA			; rotate sign bit into bit 7 of mantissa.

; and transfer mantissa from main registers to calculator stack.

	LD	(HL),A		;
	INC	HL		;
	LD	(HL),C		;
	INC	HL		;
	LD	(HL),D		;
	INC	HL		;
	LD	(HL),E		;

	POP	HL		; restore pointer to num1 now result.
	POP	DE		; restore pointer to num2 now STKEND.

	EXX			; - - -
	POP	HL		; restore pointer to next calculator literal.
	EXX			; - - -

	RET			; return.

; ___

mark_1880:
REPORT_6:
	RST	_ERROR_1
	DEFB	5		; Error Report: Arithmetic overflow.


; THE 'DIVISION' OPERATION

;	"Of all the arithmetic subroutines, division is the most complicated and
;	the least understood.	It is particularly interesting to note that the 
;	Sinclair programmer himself has made a mistake in his programming ( or has
;	copied over someone else's mistake!) for
;	PRINT PEEK 6352 [ $18D0 ] ('unimproved' ROM, 6351 [ $18CF ] )
;	should give 218 not 225."
;	- Dr. Ian Logan, Syntax magazine Jul/Aug 1982.
;	[ i.e. the jump should be made to div-34th ]

;	First check for division by zero.

mark_1882:
DIVISION:
	EX	DE,HL		; consider the second number first. 
	XOR	A		; set the running sign flag.
	CALL	PREP_MULTIPLY_OR_DIVIDE
	JR	C,REPORT_6	; back if zero
				; 'Arithmetic overflow'

	EX	DE,HL		; now prepare first number and check for zero.
	CALL	PREP_MULTIPLY_OR_DIVIDE
	RET	C		; return if zero, 0/anything is zero.

	EXX			; - - -
	PUSH	HL		; save pointer to the next calculator literal.
	EXX			; - - -

	PUSH	DE		; save pointer to divisor - will be STKEND.
	PUSH	HL		; save pointer to dividend - will be result.

	CALL	FETCH_TWO		; fetches the two numbers
				; into the registers H'B'C'C B
				;			L'D'E'D E
	EXX			; - - -
	PUSH	HL		; save the two exponents.

	LD	H,B		; transfer the dividend to H'L'H L
	LD	L,C		; 
	EXX			;
	LD	H,C		;
	LD	L,B		; 

	XOR	A		; clear carry bit and accumulator.
	LD	B,$DF		; count upwards from -33 decimal
	JR	DIVISION_START		; forward to mid-loop entry point

; ___

mark_18A2:
DIV_LOOP:
	RLA			; multiply partial quotient by two
	RL	C		; setting result bit from carry.
	EXX			;
	RL	C		;
	RL	B		;
	EXX			;

mark_18AB:
DIV_34TH:
	ADD	HL,HL		;
	EXX			;
	ADC	HL,HL		;
	EXX			;
	JR	C,SUBN_ONLY	; forward

mark_18B2:
DIVISION_START:
	SBC	HL,DE		; subtract divisor part.
	EXX			;
	SBC	HL,DE		;
	EXX			;
	JR	NC,NUM_RESTORE	; forward if subtraction goes

	ADD	HL,DE		; else restore
	EXX			;
	ADC	HL,DE		;
	EXX			;
	AND	A		; clear carry
	JR	COUNT_ONE		; forward

; ___

mark_18C2:
SUBN_ONLY:
	AND	A		;
	SBC	HL,DE		;
	EXX			;
	SBC	HL,DE		;
	EXX			;

mark_18C9:
NUM_RESTORE:
	SCF			; set carry flag

mark_18CA:
COUNT_ONE:
	INC	B		; increment the counter
	JP	M,DIV_LOOP	; back while still minus to DIV_LOOP

	PUSH	AF		;
	JR	Z,DIVISION_START	; back to DIV_START

; "This jump is made to the wrong place. No 34th bit will ever be obtained
; without first shifting the dividend. Hence important results like 1/10 and
; 1/1000 are not rounded up as they should be. Rounding up never occurs when
; it depends on the 34th bit. The jump should be made to div_34th above."
; - Dr. Frank O'Hara, "The Complete Spectrum ROM Disassembly", 1983,
; published by Melbourne House.
; (Note. on the ZX81 this would be JR Z,DIV_34TH)
;
; However if you make this change, then while (1/2=.5) will now evaluate as
; true, (.25=1/4), which did evaluate as true, no longer does.

	LD	E,A		;
	LD	D,C		;
	EXX			;
	LD	E,C		;
	LD	D,B		;

	POP	AF		;
	RR	B		;
	POP	AF		;
	RR	B		;

	EXX			;
	POP	BC		;
	POP	HL		;
	LD	A,B		;
	SUB	C		;
	JP	DIVN_EXPT		; jump back


; THE 'INTEGER TRUNCATION TOWARDS ZERO' SUBROUTINE

;

mark_18E4:
TRUNCATE:
	LD	A,(HL)		; fetch exponent
	CP	$81		; compare to +1
	JR	NC,T_GR_ZERO	; forward, if 1 or more

; else the number is smaller than plus or minus 1 and can be made zero.

	LD	(HL),$00	; make exponent zero.
	LD	A,$20		; prepare to set 32 bits of mantissa to zero.
	JR	NIL_BYTES	; forward

; ___

mark_18EF:
T_GR_ZERO:
	SUB	$A0		; subtract +32 from exponent
	RET	P		; return if result is positive as all 32 bits 
				; of the mantissa relate to the integer part.
				; The floating point is somewhere to the right 
				; of the mantissa

	NEG			; else negate to form number of rightmost bits 
				; to be blanked.

; for instance, disregarding the sign bit, the number 3.5 is held as 
; exponent $82 mantissa .11100000 00000000 00000000 00000000
; we need to set $82 - $A0 = $E2 NEG = $1E (thirty) bits to zero to form the 
; integer.
; The sign of the number is never considered as the first bit of the mantissa
; must be part of the integer.

mark_18F4:
NIL_BYTES:
	PUSH	DE		; save pointer to STKEND
	EX	DE,HL		; HL points at STKEND
	DEC	HL		; now at last byte of mantissa.
	LD	B,A		; Transfer bit count to B register.
	SRL	B		; divide by 
	SRL	B		; eight
	SRL	B		;
	JR	Z,BITS_ZERO	; forward if zero

; else the original count was eight or more and whole bytes can be blanked.

mark_1900:
BYTE_ZERO:
	LD	(HL),0		; set eight bits to zero.
	DEC	HL		; point to more significant byte of mantissa.
	DJNZ	BYTE_ZERO		; loop back

; now consider any residual bits.

mark_1905:
BITS_ZERO:
	AND	$07		; isolate the remaining bits
	JR	Z,IX_END	; forward if none

	LD	B,A		; transfer bit count to B counter.
	LD	A,$FF		; form a mask 11111111

mark_190C:
LESS_MASK:
	SLA	A		; 1 <- 76543210 <- o	slide mask leftwards.
	DJNZ	LESS_MASK		; loop back for bit count

	AND	(HL)		; lose the unwanted rightmost bits
	LD	(HL),A		; and place in mantissa byte.

mark_1912:
IX_END:
	EX	DE,HL		; restore result pointer from DE. 
	POP	DE		; restore STKEND from stack.
	RET			; return.


;   Up to this point all routine addresses have been maintained so that the
;   modified ROM is compatible with any machine-code software that uses ROM
;   routines.
;   The final section does not maintain address entry points as the routines
;   within are not generally called directly.

;**	FLOATING-POINT CALCULATOR **
;********************************
; As a general rule the calculator avoids using the IY register.
; Exceptions are val and str$.
; So an assembly language programmer who has disabled interrupts to use IY
; for other purposes can still use the calculator for mathematical
; purposes.

; THE 'TABLE OF CONSTANTS'

; The ZX81 has only floating-point number representation.
; Both the ZX80 and the ZX Spectrum have integer numbers in some form.


TAB_CNST:

if ORIGINAL
mark_1915:
				;	00 00 00 00 00
stk_zero:
	DEFB	$00		;;Bytes: 1
	DEFB	$B0		;;Exponent $00
	DEFB	$00		;;(+00,+00,+00)

mark_1918:
				;	81 00 00 00 00
stk_one:
	DEFB	$31		;;Exponent $81, Bytes: 1
	DEFB	$00		;;(+00,+00,+00)


mark_191A:
				;	80 00 00 00 00
stk_half:
	DEFB	$30		;;Exponent: $80, Bytes: 1
	DEFB	$00		;;(+00,+00,+00)


mark_191C:
				;	81 49 0F DA A2
stk_half_pi:
	DEFB	$F1		;;Exponent: $81, Bytes: 4
	DEFB	$49,$0F,$DA,$A2 ;;

mark_1921:
				;	84 20 00 00 00
stk_ten:
	DEFB	$34		;;Exponent: $84, Bytes: 1
	DEFB	$20		;;(+00,+00,+00)
else
;	This table has been modified so that the constants are held in their
;	uncompressed, ready-to-use, 5-byte form.

	DEFB	$00	; the value zero.
	DEFB	$00	;
	DEFB	$00	;
	DEFB	$00	;
	DEFB	$00	;

	DEFB	$81	; the floating point value 1.
	DEFB	$00	;
	DEFB	$00	;
	DEFB	$00	;
	DEFB	$00	;

	DEFB	$80	; the floating point value 1/2.
	DEFB	$00	;
	DEFB	$00	;
	DEFB	$00	;
	DEFB	$00	;

	DEFB	$81	; the floating point value pi/2.
	DEFB	$49	;
	DEFB	$0F	;
	DEFB	$DA	;
	DEFB	$A2	;

	DEFB	$84	; the floating point value ten.
	DEFB	$20	;
	DEFB	$00	;
	DEFB	$00	;
	DEFB	$00	;
endif


; THE 'TABLE OF ADDRESSES'

;
; starts with binary operations which have two operands and one result.
; three pseudo binary operations first.

if ORIGINAL
mark_1923:
else
endif

tbl_addrs:

	DEFW	jump_true		; $00 Address: $1C2F - jump_true
	DEFW	exchange		; $01 Address: $1A72 - exchange
	DEFW	delete			; $02 Address: $19E3 - delete

; true binary operations.

	DEFW	SUBTRACT		; $03 Address: $174C - subtract
	DEFW	MULTIPLY		; $04 Address: $176C - multiply
	DEFW	DIVISION		; $05 Address: $1882 - division
	DEFW	to_power		; $06 Address: $1DE2 - to_power
	DEFW	or			; $07 Address: $1AED - or

	DEFW	boolean_num_and_num		; $08 Address: $1AF3 - boolean_num_and_num
	DEFW	num_l_eql		; $09 Address: $1B03 - num_l_eql
	DEFW	num_gr_eql		; $0A Address: $1B03 - num_gr_eql
	DEFW	nums_neql		; $0B Address: $1B03 - nums_neql
	DEFW	num_grtr		; $0C Address: $1B03 - num_grtr
	DEFW	num_less		; $0D Address: $1B03 - num_less
	DEFW	nums_eql		; $0E Address: $1B03 - nums_eql
	DEFW	ADDITION		; $0F Address: $1755 - addition

	DEFW	strs_and_num		; $10 Address: $1AF8 - str_and_num
	DEFW	str_l_eql		; $11 Address: $1B03 - str_l_eql
	DEFW	str_gr_eql		; $12 Address: $1B03 - str_gr_eql
	DEFW	strs_neql		; $13 Address: $1B03 - strs_neql
	DEFW	str_grtr		; $14 Address: $1B03 - str_grtr
	DEFW	str_less		; $15 Address: $1B03 - str_less
	DEFW	strs_eql		; $16 Address: $1B03 - strs_eql
	DEFW	strs_add		; $17 Address: $1B62 - strs_add

; unary follow

	DEFW	neg		; $18
	DEFW	code		; $19
	DEFW	val		; $1A 
	DEFW	len		; $1B 
	DEFW	sin		; $1C
	DEFW	cos		; $1D
	DEFW	tan		; $1E
	DEFW	asn		; $1F
	DEFW	acs		; $20
	DEFW	atn		; $21
	DEFW	ln		; $22
	DEFW	exp		; $23
	DEFW	int		; $24
	DEFW	sqr		; $25
	DEFW	sgn		; $26
	DEFW	abs		; $27
	DEFW	PEEK		; $28 Address: $1A1B - peek		!!!!
	DEFW	usr_num		; $29
	DEFW	str_dollar	; $2A
	DEFW	chr_dollar	; $2B
	DEFW	not		; $2C

; end of true unary

	DEFW	duplicate	; $2D
	DEFW	n_mod_m		; $2E

	DEFW	jump		; $2F
	DEFW	stk_data	; $30

	DEFW	dec_jr_nz	; $31
	DEFW	less_0		; $32
	DEFW	greater_0	; $33
	DEFW	end_calc	; $34
	DEFW	get_argt	; $35
	DEFW	TRUNCATE	; $36
	DEFW	FP_CALC_2	; $37
	DEFW	e_to_fp		; $38

; the following are just the next available slots for the 128 compound literals
; which are in range $80 - $FF.

	DEFW	series_xx		; $39 : $80 - $9F.
	DEFW	stk_const_xx		; $3A : $A0 - $BF.
	DEFW	st_mem_xx		; $3B : $C0 - $DF.
	DEFW	get_mem_xx		; $3C : $E0 - $FF.

; Aside: 3D - 7F are therefore unused calculator literals.
;	39 - 7B would be available for expansion.


; THE 'FLOATING POINT CALCULATOR'

;
;

mark_199D:
CALCULATE:
	CALL	STACK_POINTERS	; is called to set up the
				; calculator stack pointers for a default
				; unary operation. HL = last value on stack.
				; DE = STKEND first location after stack.

; the calculate routine is called at this point by the series generator...

mark_19A0:
GEN_ENT_1:
	LD	A,B		; fetch the Z80 B register to A
	LD	(BERG),A	; and store value in system variable BERG.
				; this will be the counter for dec_jr_nz
				; or if used from FP_CALC2 the calculator
				; instruction.

; ... and again later at this point

mark_19A4:
GEN_ENT_2:
	EXX			; switch sets
	EX	(SP),HL		; and store the address of next instruction,
				; the return address, in H'L'.
				; If this is a recursive call then the H'L'
				; of the previous invocation goes on stack.
				; c.f. end_calc.
	EXX			; switch back to main set.

; this is the re-entry looping point when handling a string of literals.

mark_19A7:
RE_ENTRY:
	LD	(STKEND),DE	; save end of stack
	EXX			; switch to alt
	LD	A,(HL)		; get next literal
	INC	HL		; increase pointer'

; single operation jumps back to here

mark_19AE:
SCAN_ENT:
	PUSH	HL		; save pointer on stack	*
	AND	A		; now test the literal
	JP	P,FIRST_3D	; forward if in range $00 - $3D
				; anything with bit 7 set will be one of
				; 128 compound literals.

; compound literals have the following format.
; bit 7 set indicates compound.
; bits 6-5 the subgroup 0-3.
; bits 4-0 the embedded parameter $00 - $1F.
; The subgroup 0-3 needs to be manipulated to form the next available four
; address places after the simple literals in the address table.

	LD	D,A		; save literal in D
	AND	$60		; and with 01100000 to isolate subgroup
	RRCA			; rotate bits
	RRCA			; 4 places to right
	RRCA			; not five as we need offset * 2
	RRCA			; 00000xx0
	ADD	A,$72		; add ($39 * 2) to give correct offset.
				; alter above if you add more literals.
	LD	L,A		; store in L for later indexing.
	LD	A,D		; bring back compound literal
	AND	$1F		; use mask to isolate parameter bits
	JR	ENT_TABLE	; forward

; ___

; the branch was here with simple literals.

mark_19C2:
FIRST_3D:
	CP	$18		; compare with first unary operations.
	JR	NC,DOUBLE_A	; with unary operations

; it is binary so adjust pointers.

	EXX			;
	LD	BC,-5
	LD	D,H		; transfer HL, the last value, to DE.
	LD	E,L		;
	ADD	HL,BC		; subtract 5 making HL point to second
				; value.
	EXX			;

mark_19CE:
DOUBLE_A:
	RLCA			; double the literal
	LD	L,A		; and store in L for indexing

mark_19D0:
ENT_TABLE:
	LD	DE,tbl_addrs	; Address: tbl_addrs
	LD	H,$00		; prepare to index
	ADD	HL,DE		; add to get address of routine
	LD	E,(HL)		; low byte to E
	INC	HL		;
	LD	D,(HL)		; high byte to D

	LD	HL,RE_ENTRY
	EX	(SP),HL	; goes on machine stack
				; address of next literal goes to HL. *


	PUSH	DE		; now the address of routine is stacked.
	EXX			; back to main set
				; avoid using IY register.
	LD	BC,(STKEND+1)	; STKEND_hi
				; nothing much goes to C but BERG to B
				; and continue into next ret instruction
				; which has a dual identity



; THE 'DELETE' SUBROUTINE

; offset $02: 'delete'
; A simple return but when used as a calculator literal this
; deletes the last value from the calculator stack.
; On entry, as always with binary operations,
; HL=first number, DE=second number
; On exit, HL=result, DE=stkend.
; So nothing to do

mark_19E3:
delete:
	RET			; return - indirect jump if from above.


; THE 'SINGLE OPERATION' SUBROUTINE

; offset $37: 'FP_CALC_2'
; this single operation is used, in the first instance, to evaluate most
; of the mathematical and string functions found in BASIC expressions.

mark_19E4:
FP_CALC_2:
	POP	AF		; drop return address.
	LD	A,(BERG)	; load accumulator from system variable BERG
				; value will be literal eg. 'tan'
	EXX			; switch to alt
	JR	SCAN_ENT	; back
				; next literal will be end_calc in scanning


; THE 'TEST 5 SPACES' SUBROUTINE

; This routine is called from MOVE_FP, STK_CONST and STK_STORE to
; test that there is enough space between the calculator stack and the
; machine stack for another five_byte value. It returns with BC holding
; the value 5 ready for any subsequent LDIR.

mark_19EB:
TEST_5_SP:
	PUSH	DE		; save
	PUSH	HL		; registers
	LD	BC,5		; an overhead of five bytes
	CALL	TEST_ROOM	; tests free RAM raising
				; an error if not.
	POP	HL		; else restore
	POP	DE		; registers.
	RET			; return with BC set at 5.



; THE 'MOVE A FLOATING POINT NUMBER' SUBROUTINE

; offset $2D: 'duplicate'
; This simple routine is a 5-byte LDIR instruction
; that incorporates a memory check.
; When used as a calculator literal it duplicates the last value on the
; calculator stack.
; Unary so on entry HL points to last value, DE to stkend

mark_19F6:
duplicate:
MOVE_FP:
	CALL	TEST_5_SP	; test free memory
				; and sets BC to 5.
	LDIR			; copy the five bytes.
	RET			; return with DE addressing new STKEND
				; and HL addressing new last value.


; THE 'STACK LITERALS' SUBROUTINE

; offset $30: 'stk_data'
; When a calculator subroutine needs to put a value on the calculator
; stack that is not a regular constant this routine is called with a
; variable number of following data bytes that convey to the routine
; the floating point form as succinctly as is possible.

mark_19FC:
stk_data:
	LD	H,D		; transfer STKEND
	LD	L,E		; to HL for result.

mark_19FE:
STK_CONST:
	CALL	TEST_5_SP	; tests that room exists
				; and sets BC to $05.

	EXX			; switch to alternate set
	PUSH	HL		; save the pointer to next literal on stack
	EXX			; switch back to main set

	EX	(SP),HL	; pointer to HL, destination to stack.

if ORIGINAL
	PUSH	BC		; save BC - value 5 from test room ??.
else
;;	PUSH	BC		; save BC - value 5 from test room. No need.
endif
	LD	A,(HL)		; fetch the byte following 'stk_data'
	AND	$C0		; isolate bits 7 and 6
	RLCA			; rotate
	RLCA			; to bits 1 and 0	range $00 - $03.
	LD	C,A		; transfer to C
	INC	C		; and increment to give number of bytes
				; to read. $01 - $04
	LD	A,(HL)		; reload the first byte
	AND	$3F		; mask off to give possible exponent.
	JR	NZ,FORM_EXP	; forward to FORM_EXP if it was possible to
				; include the exponent.

; else byte is just a byte count and exponent comes next.

	INC	HL		; address next byte and
	LD	A,(HL)		; pick up the exponent ( - $50).

mark_1A14:
FORM_EXP:
	ADD	A,$50		; now add $50 to form actual exponent
	LD	(DE),A		; and load into first destination byte.
	LD	A,$05		; load accumulator with $05 and
	SUB	C		; subtract C to give count of trailing
				; zeros plus one.
	INC	HL		; increment source
	INC	DE		; increment destination


if ORIGINAL
	LD	B,$00		; prepare to copy. Note. B is zero.
	LDIR			; copy C bytes
	POP	BC		; restore 5 counter to BC.
else
	LDIR			; copy C bytes
endif

	EX	(SP),HL		; put HL on stack as next literal pointer
				; and the stack value - result pointer -
				; to HL.

	EXX			; switch to alternate set.
	POP	HL		; restore next literal pointer from stack
				; to H'L'.
	EXX			; switch back to main set.

	LD	B,A		; zero count to B
	XOR	A		; clear accumulator

mark_1A27:
STK_ZEROS:
	DEC	B		; decrement B counter
	RET	Z		; return if zero.		>>
				; DE points to new STKEND
				; HL to new number.

	LD	(DE),A		; else load zero to destination
	INC	DE		; increase destination
	JR	STK_ZEROS	; loop back until done.


; THE 'SKIP CONSTANTS' SUBROUTINE

; This routine traverses variable-length entries in the table of constants,
; stacking intermediate, unwanted constants onto a dummy calculator stack,
; in the first five bytes of the ZX81 ROM.

if ORIGINAL
mark_1A2D:
SKIP_CONS:
	AND	A		; test if initially zero.

mark_1A2E:
SKIP_NEXT:
	RET	Z		; return if zero.		>>

	PUSH	AF		; save count.
	PUSH	DE		; and normal STKEND

	LD	DE,$0000	; dummy value for STKEND at start of ROM
				; Note. not a fault but this has to be
				; moved elsewhere when running in RAM.
				;
	CALL	STK_CONST		; works through variable
				; length records.

	POP	DE		; restore real STKEND
	POP	AF		; restore count
	DEC	A		; decrease
	JR	SKIP_NEXT	; loop back
else
; Since the table now uses uncompressed values, some extra ROM space is 
; required for the table but much more is released by getting rid of routines
; like this.
endif


; THE 'MEMORY LOCATION' SUBROUTINE

; This routine, when supplied with a base address in HL and an index in A,
; will calculate the address of the A'th entry, where each entry occupies
; five bytes. It is used for addressing floating-point numbers in the
; calculator's memory area.

mark_1A3C:
LOC_MEM:
	LD	C,A		; store the original number $00-$1F.
	RLCA			; double.
	RLCA			; quadruple.
	ADD	A,C		; now add original value to multiply by five.

	LD	C,A		; place the result in C.
	LD	B,$00		; set B to 0.
	ADD	HL,BC		; add to form address of start of number in HL.

	RET			; return.


; THE 'GET FROM MEMORY AREA' SUBROUTINE

; offsets $E0 to $FF: 'get_mem_0', 'get_mem_1' etc.
; A holds $00-$1F offset.
; The calculator stack increases by 5 bytes.

mark_1A45:
get_mem_xx:

if ORIGINAL
	PUSH	DE		; save STKEND
	LD	HL,(MEM)	; MEM is base address of the memory cells.
else
				; Note. first two instructions have been swapped to create a subroutine.
	LD	HL,(MEM)	; MEM is base address of the memory cells.
INDEX_5:			; new label
	PUSH	DE		; save STKEND
endif
	CALL	LOC_MEM		; so that HL = first byte
	CALL	MOVE_FP		; moves 5 bytes with memory
				; check.
				; DE now points to new STKEND.
	POP	HL		; the original STKEND is now RESULT pointer.
	RET			; return.


; THE 'STACK A CONSTANT' SUBROUTINE


stk_const_xx:
if ORIGINAL

; offset $A0: 'stk_zero'
; offset $A1: 'stk_one'
; offset $A2: 'stk_half'
; offset $A3: 'stk_half_pi'
; offset $A4: 'stk_ten'
;
; This routine allows a one-byte instruction to stack up to 32 constants
; held in short form in a table of constants. In fact only 5 constants are
; required. On entry the A register holds the literal ANDed with $1F.
; It isn't very efficient and it would have been better to hold the
; numbers in full, five byte form and stack them in a similar manner
; to that which would be used later for semi-tone table values.

mark_1A51:

	LD	H,D		; save STKEND - required for result
	LD	L,E		;
	EXX			; swap
	PUSH	HL		; save pointer to next literal
	LD	HL,stk_zero	; Address: stk_zero - start of table of
				; constants
	EXX			;
	CALL	SKIP_CONS
	CALL	STK_CONST
	EXX			;
	POP	HL		; restore pointer to next literal.
	EXX			;
	RET			; return.
else
stk_con_x:
	LD	HL,TAB_CNST	; Address: Table of constants.

	JR	INDEX_5		; and join subroutine above.
endif




; THE 'STORE IN A MEMORY AREA' SUBROUTINE

; Offsets $C0 to $DF: 'st_mem_0', 'st_mem_1' etc.
; Although 32 memory storage locations can be addressed, only six
; $C0 to $C5 are required by the ROM and only the thirty bytes (6*5)
; required for these are allocated. ZX81 programmers who wish to
; use the floating point routines from assembly language may wish to
; alter the system variable MEM to point to 160 bytes of RAM to have
; use the full range available.
; A holds derived offset $00-$1F.
; Unary so on entry HL points to last value, DE to STKEND.

mark_1A63:
st_mem_xx:
	PUSH	HL		; save the result pointer.
	EX	DE,HL		; transfer to DE.
	LD	HL,(MEM)	; fetch MEM the base of memory area.
	CALL	LOC_MEM		; sets HL to the destination.
	EX	DE,HL		; swap - HL is start, DE is destination.

if ORIGINAL
	CALL	MOVE_FP
				; note. a short ld bc,5; ldir
				; the embedded memory check is not required
				; so these instructions would be faster!
else
	LD	C,5		;+ one extra byte but 
	LDIR			;+ faster and no memory check.
endif


	EX	DE,HL		; DE = STKEND
	POP	HL		; restore original result pointer
	RET			; return.


; THE 'EXCHANGE' SUBROUTINE

; offset $01: 'exchange'
; This routine exchanges the last two values on the calculator stack
; On entry, as always with binary operations,
; HL=first number, DE=second number
; On exit, HL=result, DE=stkend.

mark_1A72:
exchange:
	LD	B,$05		; there are five bytes to be swapped

; start of loop.

mark_1A74:
SWAP_BYTE:
	LD	A,(DE)		; each byte of second
if ORIGINAL
	LD	C,(HL)		; each byte of first
	EX	DE,HL		; swap pointers
else
	LD	C,A		;+
	LD	A,(HL)
endif
	LD	(DE),A		; store each byte of first
	LD	(HL),C		; store each byte of second
	INC	HL		; advance both
	INC	DE		; pointers.
	DJNZ	SWAP_BYTE	; loop back until all 5 done.

if ORIGINAL
	EX	DE,HL		; even up the exchanges so that DE addresses STKEND.
else
;	omit
endif
	RET			; return.


; THE 'SERIES GENERATOR' SUBROUTINE


; The ZX81 uses Chebyshev polynomials to generate approximations for
; SIN, ATN, LN and EXP. These are named after the Russian mathematician
; Pafnuty Chebyshev, born in 1821, who did much pioneering work on numerical
; series. As far as calculators are concerned, Chebyshev polynomials have an
; advantage over other series, for example the Taylor series, as they can
; reach an approximation in just six iterations for SIN, eight for EXP and
; twelve for LN and ATN. The mechanics of the routine are interesting but
; for full treatment of how these are generated with demonstrations in
; Sinclair BASIC see "The Complete Spectrum ROM Disassembly" by Dr Ian Logan
; and Dr Frank O'Hara, published 1983 by Melbourne House.

mark_1A7F:
series_xx:
	LD	B,A		; parameter $00 - $1F to B counter
	CALL	GEN_ENT_1
				; A recursive call to a special entry point
				; in the calculator that puts the B register
				; in the system variable BERG. The return
				; address is the next location and where
				; the calculator will expect its first
				; instruction - now pointed to by HL'.
				; The previous pointer to the series of
				; five-byte numbers goes on the machine stack.

; The initialization phase.

	DEFB	__duplicate	;;	x,x
	DEFB	__addition	;;	x+x
	DEFB	__st_mem_0	;;	x+x
	DEFB	__delete	;;	.
	DEFB	__stk_zero	;;	0
	DEFB	__st_mem_2	;;	0

; a loop is now entered to perform the algebraic calculation for each of
; the numbers in the series

mark_1A89:
G_LOOP:
	DEFB	__duplicate	;;	v,v.
	DEFB	__get_mem_0	;;	v,v,x+2
	DEFB	__multiply	;;	v,v*x+2
	DEFB	__get_mem_2	;;	v,v*x+2,v
	DEFB	__st_mem_1	;;
	DEFB	__subtract	;;
	DEFB	__end_calc	;;

; the previous pointer is fetched from the machine stack to H'L' where it
; addresses one of the numbers of the series following the series literal.

	CALL	stk_data		; is called directly to
				; push a value and advance H'L'.
	CALL	GEN_ENT_2		; recursively re-enters
				; the calculator without disturbing
				; system variable BERG
				; H'L' value goes on the machine stack and is
				; then loaded as usual with the next address.

	DEFB	__addition	;;
	DEFB	__exchange	;;
	DEFB	__st_mem_2	;;
	DEFB	__delete	;;

	DEFB	__dec_jr_nz	;;
	DEFB	$EE		;;back to G_LOOP, G_LOOP

; when the counted loop is complete the final subtraction yields the result
; for example SIN X.

	DEFB	__get_mem_1	;;
	DEFB	__subtract	;;
	DEFB	__end_calc	;;

	RET			; return with H'L' pointing to location
				; after last number in series.


; Handle unary minus (18)

; Unary so on entry HL points to last value, DE to STKEND.

mark_1AA0:
neg:
	LD A,	(HL)		; fetch exponent of last value on the
				; calculator stack.
	AND	A		; test it.
	RET	Z		; return if zero.

	INC	HL		; address the byte with the sign bit.
	LD	A,(HL)		; fetch to accumulator.
	XOR	$80		; toggle the sign bit.
	LD	(HL),A		; put it back.
	DEC	HL		; point to last value again.
	RET			; return.


; Absolute magnitude (27)

; This calculator literal finds the absolute value of the last value,
; floating point, on calculator stack.

mark_1AAA:
abs:
	INC	HL		; point to byte with sign bit.
	RES	7,(HL)		; make the sign positive.
	DEC	HL		; point to last value again.
	RET			; return.


; Signum (26)

; This routine replaces the last value on the calculator stack,
; which is in floating point form, with one if positive and with -minus one
; if negative. If it is zero then it is left as such.

mark_1AAF:
sgn:
	INC	HL		; point to first byte of 4-byte mantissa.
	LD	A,(HL)		; pick up the byte with the sign bit.
	DEC	HL		; point to exponent.
	DEC	(HL)		; test the exponent for
	INC	(HL)		; the value zero.

	SCF			; set the carry flag.
	CALL	NZ,FP_0_OR_1	; replaces last value with one
				; if exponent indicates the value is non-zero.
				; in either case mantissa is now four zeros.

	INC HL			; point to first byte of 4-byte mantissa.
	RLCA			; rotate original sign bit to carry.
	RR	(HL)		; rotate the carry into sign.
	DEC HL			; point to last value.
	RET			; return.



; Handle PEEK function (28)

; This function returns the contents of a memory address.
; The entire address space can be peeked including the ROM.

mark_1ABE:
PEEK:
	CALL	FIND_INT	; puts address in BC.
	LD	A,(BC)		; load contents into A register.

mark_1AC2:
IN_PK_STK:
	JP	STACK_A		; exit via STACK_A to put value on the
				; calculator stack.


; USR number (29)

; The USR function followed by a number 0-65535 is the method by which
; the ZX81 invokes machine code programs. This function returns the
; contents of the BC register pair.
; Note. that STACK_BC re-initializes the IY register to ERR_NR if a user-written
; program has altered it.

mark_1AC5:
usr_num:
	CALL	FIND_INT	; to fetch the
				; supplied address into BC.

	LD	HL,STACK_BC	; address: STACK_BC is
	PUSH	HL		; pushed onto the machine stack.
	PUSH	BC		; then the address of the machine code
				; routine.

	RET			; make an indirect jump to the routine
				; and, hopefully, to STACK_BC also.



; Greater than zero ($33)

; Test if the last value on the calculator stack is greater than zero.
; This routine is also called directly from the end-tests of the comparison
; routine.

mark_1ACE:
greater_0:
	LD	A,(HL)		; fetch exponent.
	AND	A		; test it for zero.
	RET	Z		; return if so.


	LD	A,$FF		; prepare XOR mask for sign bit
	JR	SIGN_TO_C	; forward to SIGN_TO_C
				; to put sign in carry
				; (carry will become set if sign is positive)
				; and then overwrite location with 1 or 0
				; as appropriate.


; Handle NOT operator ($2C)

; This overwrites the last value with 1 if it was zero else with zero
; if it was any other value.
;
; e.g. NOT 0 returns 1, NOT 1 returns 0, NOT -3 returns 0.
;
; The subroutine is also called directly from the end-tests of the comparison
; operator.

mark_1AD5:
not:
	LD	A,(HL)		; get exponent byte.
	NEG			; negate - sets carry if non-zero.
	CCF			; complement so carry set if zero, else reset.
	JR	FP_0_OR_1	; forward to FP_0_OR_1.


; Less than zero (32)

; Destructively test if last value on calculator stack is less than zero.
; Bit 7 of second byte will be set if so.

mark_1ADB:
less_0:
	XOR	A		; set xor mask to zero
				; (carry will become set if sign is negative).

; transfer sign of mantissa to Carry Flag.

mark_1ADC:
SIGN_TO_C:
	INC	HL		; address 2nd byte.
	XOR	(HL)		; bit 7 of HL will be set if number is negative.
	DEC	HL		; address 1st byte again.
	RLCA			; rotate bit 7 of A to carry.


; Zero or one

; This routine places an integer value zero or one at the addressed location
; of calculator stack or MEM area. The value one is written if carry is set on
; entry else zero.

mark_1AE0:
FP_0_OR_1:
	PUSH	HL		; save pointer to the first byte
	LD	B,$05		; five bytes to do.

mark_1AE3:
FP_loop:
	LD	(HL),$00	; insert a zero.
	INC	HL		;
	DJNZ	FP_loop		; repeat.

	POP	HL		;
	RET	NC		;

	LD	(HL),$81	; make value 1
	RET			; return.



; Handle OR operator (07)

; The Boolean OR operator. eg. X OR Y
; The result is zero if both values are zero else a non-zero value.
;
; e.g.	0 OR 0	returns 0.
;	-3 OR 0	returns -3.
;	0 OR -3 returns 1.
;	-3 OR 2	returns 1.
;
; A binary operation.
; On entry HL points to first operand (X) and DE to second operand (Y).

mark_1AED:
or:
	LD	A,(DE)		; fetch exponent of second number
	AND	A		; test it.
	RET	Z		; return if zero.

	SCF			; set carry flag
	JR	FP_0_OR_1	; back to FP_0_OR_1 to overwrite the first operand
				; with the value 1.



; Handle number AND number (08)

; The Boolean AND operator.
;
; e.g.	-3 AND 2	returns -3.
;	-3 AND 0	returns 0.
;		0 and -2 returns 0.
;		0 and 0	returns 0.
;
; Compare with OR routine above.

boolean_num_and_num:
	LD	A,(DE)		; fetch exponent of second number.
	AND	A		; test it.
	RET	NZ		; return if not zero.

	JR	FP_0_OR_1	; back to FP_0_OR_1 to overwrite the first operand
				; with zero for return value.


; Handle string AND number (10)

; e.g. "YOU WIN" AND SCORE>99 will return the string if condition is true
; or the null string if false.

strs_and_num:
	LD	A,(DE)		; fetch exponent of second number.
	AND	A		; test it.
	RET	NZ		; return if number was not zero - the string
				; is the result.

; if the number was zero (false) then the null string must be returned by
; altering the length of the string on the calculator stack to zero.

	PUSH	DE		; save pointer to the now obsolete number
				; (which will become the new STKEND)

	DEC	DE		; point to the 5th byte of string descriptor.
	XOR	A		; clear the accumulator.
	LD	(DE),A		; place zero in high byte of length.
	DEC	DE		; address low byte of length.
	LD	(DE),A		; place zero there - now the null string.

	POP	DE		; restore pointer - new STKEND.
	RET			; return.


; Perform comparison ($09-$0E, $11-$16)

; True binary operations.
;
; A single entry point is used to evaluate six numeric and six string
; comparisons. On entry, the calculator literal is in the B register and
; the two numeric values, or the two string parameters, are on the
; calculator stack.
; The individual bits of the literal are manipulated to group similar
; operations although the SUB 8 instruction does nothing useful and merely
; alters the string test bit.
; Numbers are compared by subtracting one from the other, strings are
; compared by comparing every character until a mismatch, or the end of one
; or both, is reached.
;
; Numeric Comparisons.

; The 'x>y' example is the easiest as it employs straight-thru logic.
; Number y is subtracted from x and the result tested for greater_0 yielding
; a final value 1 (true) or 0 (false).
; For 'x<y' the same logic is used but the two values are first swapped on the
; calculator stack.
; For 'x=y' NOT is applied to the subtraction result yielding true if the
; difference was zero and false with anything else.
; The first three numeric comparisons are just the opposite of the last three
; so the same processing steps are used and then a final NOT is applied.
;
; literal	Test	No sub 8        ExOrNot  1st RRCA	exch sub	?	End-Tests
; =========	====	== ======== === ======== ========	==== ===	=	=== === ===
; num_l_eql	x<=y	09 00000001 dec 00000000 00000000	---- x-y	?	--- >0? NOT
; num_gr_eql	x>=y	0A 00000010 dec 00000001 10000000c	swap y-x	?	--- >0? NOT
; nums_neql	x<>y	0B 00000011 dec 00000010 00000001	---- x-y	?	NOT --- NOT
; num_grtr	x>y	0C 00000100 -	00000100 00000010	---- x-y	?	--- >0? ---
; num_less	x<y	0D 00000101 -	00000101 10000010c	swap y-x	?	--- >0? ---
; nums_eql	x=y	0E 00000110 -	00000110 00000011	---- x-y	?	NOT --- ---
;
;								comp -> C/F
;								====	===
; str_l_eql	x$<=y$	11 00001001 dec 00001000 00000100	---- x$y$ 0	!or >0? NOT
; str_gr_eql	x$>=y$	12 00001010 dec 00001001 10000100c	swap y$x$ 0	!or >0? NOT
; strs_neql	x$<>y$	13 00001011 dec 00001010 00000101	---- x$y$ 0	!or >0? NOT
; str_grtr	x$>y$	14 00001100 -	00001100 00000110	---- x$y$ 0	!or >0? ---
; str_less	x$<y$	15 00001101 -	00001101 10000110c	swap y$x$ 0	!or >0? ---
; strs_eql	x$=y$	16 00001110 -	00001110 00000111	---- x$y$ 0	!or >0? ---
;
; String comparisons are a little different in that the eql/neql carry flag
; from the 2nd RRCA is, as before, fed into the first of the end tests but
; along the way it gets modified by the comparison process. The result on the
; stack always starts off as zero and the carry fed in determines if NOT is
; applied to it. So the only time the greater-0 test is applied is if the
; stack holds zero which is not very efficient as the test will always yield
; zero. The most likely explanation is that there were once separate end tests
; for numbers and strings.

; $1B03 SAME ADDRESS FOR MULTIPLE ROUTINES ???

num_l_eql:
num_gr_eql:
nums_neql:
num_grtr:
num_less:
nums_eql:
str_l_eql:
str_gr_eql:
strs_neql:
str_grtr:
str_less:
strs_eql:
num_lt_eql:
if ORIGINAL
mark_1B03:
	LD	A,B		; transfer literal to accumulator.
	SUB	$08		; subtract eight - which is not useful.
else
	LD	A,B		; transfer literal to accumulator.
;;	SUB	$08		; subtract eight - which is not useful.
endif
	BIT	2,A		; isolate '>', '<', '='.

	JR	NZ,EX_OR_NOT	; skip to EX_OR_NOT with these.

	DEC	A		; else make $00-$02, $08-$0A to match bits 0-2.

EX_OR_NOT:
if ORIGINAL
mark_1B0B:
endif
	RRCA			; the first RRCA sets carry for a swap.
	JR	NC,NUM_OR_STR	; forward to NUM_OR_STR with other 8 cases

; for the other 4 cases the two values on the calculator stack are exchanged.

	PUSH	AF		; save A and carry.
	PUSH	HL		; save HL - pointer to first operand.
				; (DE points to second operand).

	CALL	exchange		; routine exchange swaps the two values.
				; (HL = second operand, DE = STKEND)

	POP	DE		; DE = first operand
	EX	DE,HL		; as we were.
	POP	AF		; restore A and carry.

; Note. it would be better if the 2nd RRCA preceded the string test.
; It would save two duplicate bytes and if we also got rid of that sub 8
; at the beginning we wouldn't have to alter which bit we test.

NUM_OR_STR:
if ORIGINAL
mark_1B16:

	BIT	2,A		; test if a string comparison.
	JR	NZ,STRINGS	; forward to STRINGS if so.

; continue with numeric comparisons.

	RRCA			; 2nd RRCA causes eql/neql to set carry.
	PUSH	AF		; save A and carry
else
	RRCA			;+ causes 'eql/neql' to set carry.
	PUSH	AF		;+ save the carry flag.

	BIT	2,A		; test if a string comparison.
	JR	NZ,STRINGS	; forward to STRINGS if so.

endif

	CALL	SUBTRACT	; leaves result on stack.
	JR	END_TESTS	; forward to END_TESTS

; ___


STRINGS:
if ORIGINAL
mark_1B21:
	RRCA			; 2nd RRCA causes eql/neql to set carry.
	PUSH	AF		; save A and carry.
else
;;	RRCA			; 2nd RRCA causes eql/neql to set carry.
;;	PUSH	AF		; save A and carry.
endif
	CALL	STK_FETCH	; gets 2nd string params
	PUSH	DE		; save start2 *.
	PUSH	BC		; and the length.

	CALL	STK_FETCH	; gets 1st string
				; parameters - start in DE, length in BC.
	POP	HL		; restore length of second to HL.

; A loop is now entered to compare, by subtraction, each corresponding character
; of the strings. For each successful match, the pointers are incremented and
; the lengths decreased and the branch taken back to here. If both string
; remainders become null at the same time, then an exact match exists.

if ORIGINAL
mark_1B2C:
endif
BYTE_COMP:
	LD	A,H		; test if the second string
	OR	L		; is the null string and hold flags.

	EX	(SP),HL	; put length2 on stack, bring start2 to HL *.
	LD	A,B		; hi byte of length1 to A

	JR	NZ,SEC_PLUS	; forward to SEC_PLUS if second not null.

	OR	C		; test length of first string.

if ORIGINAL
mark_1B33:
endif

SECOND_LOW:
	POP	BC		; pop the second length off stack.
	JR	Z,BOTH_NULL	; forward if first string is also
				; of zero length.

; the true condition - first is longer than second (SECOND_LESS)

	POP	AF		; restore carry (set if eql/neql)
	CCF			; complement carry flag.
				; Note. equality becomes false.
				; Inequality is true. By swapping or applying
				; a terminal 'not', all comparisons have been
				; manipulated so that this is success path.
	JR	STR_TEST		; forward to leave via STR_TEST

; ___
; the branch was here with a match

if ORIGINAL
mark_1B3A:
endif

BOTH_NULL:
	POP	AF		; restore carry - set for eql/neql
	JR	STR_TEST		; forward to STR_TEST

; ___
; the branch was here when 2nd string not null and low byte of first is yet
; to be tested.


mark_1B3D:
SEC_PLUS:
	OR	C		; test the length of first string.
	JR	Z,FRST_LESS	; forward to FRST_LESS if length is zero.

; both strings have at least one character left.

	LD	A,(DE)		; fetch character of first string.
	SUB	(HL)		; subtract with that of 2nd string.
	JR	C,FRST_LESS	; forward to FRST_LESS if carry set

	JR	NZ,SECOND_LOW	; back to SECOND_LOW and then STR_TEST
				; if not exact match.

	DEC	BC		; decrease length of 1st string.
	INC	DE		; increment 1st string pointer.

	INC	HL		; increment 2nd string pointer.
	EX	(SP),HL	; swap with length on stack
	DEC	HL		; decrement 2nd string length
	JR	BYTE_COMP		; back to BYTE_COMP

; ___
;	the false condition.

mark_1B4D:
FRST_LESS:
	POP	BC		; discard length
	POP	AF		; pop A
	AND	A		; clear the carry for false result.

; ___
;	exact match and x$>y$ rejoin here

mark_1B50:
STR_TEST:
	PUSH	AF		; save A and carry

	RST	_FP_CALC	;;
	DEFB	__stk_zero	;;	an initial false value.
	DEFB	__end_calc	;;

;	both numeric and string paths converge here.

mark_1B54:
END_TESTS:
	POP	AF		; pop carry	- will be set if eql/neql
	PUSH	AF		; save it again.

	CALL	C,not	; sets true(1) if equal(0)
				; or, for strings, applies true result.
	CALL	greater_0		; ??????????


	POP	AF		; pop A
	RRCA			; the third RRCA - test for '<=', '>=' or '<>'.
	CALL	NC,not	; apply a terminal NOT if so.
	RET			; return.

; String concatenation ($17)

;	This literal combines two strings into one e.g. LET A$ = B$ + C$
;	The two parameters of the two strings to be combined are on the stack.

mark_1B62:
strs_add:
	CALL	STK_FETCH	; fetches string parameters
				; and deletes calculator stack entry.
	PUSH	DE		; save start address.
	PUSH	BC		; and length.

	CALL	STK_FETCH	; for first string
	POP	HL		; re-fetch first length
	PUSH	HL		; and save again
	PUSH	DE		; save start of second string
	PUSH	BC		; and its length.

	ADD	HL,BC		; add the two lengths.
	LD	B,H		; transfer to BC
	LD	C,L		; and create
	RST	_BC_SPACES	; BC_SPACES in workspace.
				; DE points to start of space.

	CALL	STK_STO_STR	; stores parameters
				; of new string updating STKEND.
	POP	BC		; length of first
	POP	HL		; address of start

if ORIGINAL
	LD	A,B		; test for
	OR	C		; zero length.
	JR	Z,OTHER_STR	; to OTHER_STR if null string
	LDIR			; copy string to workspace.
else
	CALL	COND_MV		;+ a conditional (NZ) ldir routine. 
endif

mark_1B7D:
OTHER_STR:
	POP	BC		; now second length
	POP	HL		; and start of string
if ORIGINAL
	LD	A,B		; test this one
	OR	C		; for zero length
	JR	Z,STACK_POINTERS	; skip forward to STACK_POINTERS if so as complete.

	LDIR			; else copy the bytes.
				; and continue into next routine which
				; sets the calculator stack pointers.
else
	CALL	COND_MV		;+ a conditional (NZ) ldir routine. 
endif


; Check stack pointers

;	Register DE is set to STKEND and HL, the result pointer, is set to five
;	locations below this.
;	This routine is used when it is inconvenient to save these values at the
;	time the calculator stack is manipulated due to other activity on the
;	machine stack.
;	This routine is also used to terminate the VAL routine for
;	the same reason and to initialize the calculator stack at the start of
;	the CALCULATE routine.

mark_1B85:
STACK_POINTERS:
	LD	HL,(STKEND)	; fetch STKEND value from system variable.
	LD	DE,-5
	PUSH	HL		; push STKEND value.

	ADD	HL,DE		; subtract 5 from HL.

	POP	DE		; pop STKEND to DE.
	RET			; return.


; Handle CHR$ (2B)

;	This function returns a single character string that is a result of
;	converting a number in the range 0-255 to a string e.g. CHR$ 38 = "A".
;	Note. the ZX81 does not have an ASCII character set.

mark_1B8F:
chr_dollar:
	CALL	FP_TO_A		; puts the number in A.

	JR	C,REPORT_Bd	; forward if overflow
	JR	NZ,REPORT_Bd	; forward if negative
if ORIGINAL
	PUSH	AF		; save the argument.
endif
	LD	BC,1		; one space required.
	RST	_BC_SPACES	; BC_SPACES makes DE point to start
if ORIGINAL
	POP	AF		; restore the number.
endif
	LD	(DE),A		; and store in workspace

if ORIGINAL
	CALL	STK_STO_STR	; stacks descriptor.

	EX	DE,HL		; make HL point to result and DE to STKEND.
	RET			; return.
else
	JR	str_STK	;+ relative jump to similar sequence in str$.
endif
; ___

mark_1BA2:
REPORT_Bd:
	RST	_ERROR_1
	DEFB	$0A		; Error Report: Integer out of range


; Handle VAL ($1A)

;	VAL treats the characters in a string as a numeric expression.
;	e.g. VAL "2.3" = 2.3, VAL "2+4" = 6, VAL ("2" + "4") = 24.

val:
if ORIGINAL
mark_1BA4:
	LD	HL,(CH_ADD)	; fetch value of system variable CH_ADD
else
	RST	_GET_CHAR	;+ shorter way to fetch CH_ADD.
endif
	PUSH	HL		; and save on the machine stack.

	CALL	STK_FETCH	; fetches the string operand
				; from calculator stack.

	PUSH	DE		; save the address of the start of the string.
	INC	BC		; increment the length for a carriage return.

	RST	_BC_SPACES	; BC_SPACES creates the space in workspace.
	POP	HL		; restore start of string to HL.
	LD	(CH_ADD),DE	; load CH_ADD with start DE in workspace.

	PUSH	DE		; save the start in workspace
	LDIR			; copy string from program or variables or
				; workspace to the workspace area.
	EX	DE,HL		; end of string + 1 to HL
	DEC	HL		; decrement HL to point to end of new area.
	LD	(HL),ZX_NEWLINE	; insert a carriage return at end.
				; ZX81 has a non-ASCII character set
	RES	7,(IY+FLAGS-RAMBASE)	; signal checking syntax.
	CALL	CLASS_6		; evaluates string
				; expression and checks for integer result.

	CALL	CHECK_2		; checks for carriage return.


	POP	HL		; restore start of string in workspace.

	LD	(CH_ADD),HL	; set CH_ADD to the start of the string again.
	SET	7,(IY+FLAGS-RAMBASE)	; signal running program.
	CALL	SCANNING	; evaluates the string
				; in full leaving result on calculator stack.

	POP	HL		; restore saved character address in program.
	LD	(CH_ADD),HL	; and reset the system variable CH_ADD.

	JR	STACK_POINTERS	; back to exit via STACK_POINTERS.
				; resetting the calculator stack pointers
				; HL and DE from STKEND as it wasn't possible
				; to preserve them during this routine.


; Handle STR$ (2A)

;	This function returns a string representation of a numeric argument.
;	The method used is to trick the PRINT_FP routine into thinking it
;	is writing to a collapsed display file when in fact it is writing to
;	string workspace.
;	If there is already a newline at the intended print position and the
;	column count has not been reduced to zero then the print routine
;	assumes that there is only 1K of RAM and the screen memory, like the rest
;	of dynamic memory, expands as necessary using calls to the ONE_SPACE
;	routine. The screen is character-mapped not bit-mapped.

mark_1BD5:
str_dollar:
	LD	BC,1		; create an initial byte in workspace
	RST	_BC_SPACES	; using BC_SPACES restart.

	LD	(HL),ZX_NEWLINE	; place a carriage return there.

	LD	HL,(S_POSN)	; fetch value of S_POSN column/line
	PUSH	HL		; and preserve on stack.

	LD	L,$FF		; make column value high to create a
				; contrived buffer of length 254.
	LD	(S_POSN),HL	; and store in system variable S_POSN.

	LD	HL,(DF_CC)	; fetch value of DF_CC
	PUSH	HL		; and preserve on stack also.

	LD	(DF_CC),DE	; now set DF_CC which normally addresses
				; somewhere in the display file to the start
				; of workspace.
	PUSH	DE		; save the start of new string.

	CALL	PRINT_FP

	POP	DE		; retrieve start of string.

	LD	HL,(DF_CC)	; fetch end of string from DF_CC.
	AND	A		; prepare for true subtraction.
	SBC	HL,DE		; subtract to give length.

	LD	B,H		; and transfer to the BC
	LD	C,L		; register.

	POP	HL		; restore original
	LD	(DF_CC),HL	; DF_CC value

	POP	HL		; restore original
	LD	(S_POSN),HL	; S_POSN values.

if ORIGINAL
else
str_STK:			; New entry-point to exploit similarities and save 3 bytes of code.
endif

	CALL	STK_STO_STR	; stores the string
				; descriptor on the calculator stack.

	EX	DE,HL		; HL = last value, DE = STKEND.
	RET			; return.



; THE 'CODE' FUNCTION

; (offset $19: 'code')
;	Returns the code of a character or first character of a string
;	e.g. CODE "AARDVARK" = 38	(not 65 as the ZX81 does not have an ASCII
;	character set).


mark_1C06:
code:
	CALL	STK_FETCH	; fetch and delete the string parameters.
				; DE points to the start, BC holds the length.
	LD	A,B		; test length
	OR	C		; of the string.
	JR	Z,STK_CODE	; skip with zero if the null string.

	LD	A,(DE)		; else fetch the first character.

mark_1C0E:
STK_CODE:
	JP	STACK_A		; jump back (with memory check)


; THE 'LEN' SUBROUTINE

; (offset $1b: 'len')
;	Returns the length of a string.
;	In Sinclair BASIC strings can be more than twenty thousand characters long
;	so a sixteen-bit register is required to store the length

mark_1C11:
len:
	CALL	STK_FETCH	; fetch and delete the
				; string parameters from the calculator stack.
				; register BC now holds the length of string.

	JP	STACK_BC	; jump back to save result on the
				; calculator stack (with memory check).


; THE 'DECREASE THE COUNTER' SUBROUTINE

; (offset $31: 'dec_jr_nz')
;	The calculator has an instruction that decrements a single-byte
;	pseudo-register and makes consequential relative jumps just like
;	the Z80's DJNZ instruction.

mark_1C17:
dec_jr_nz:
	EXX			; switch in set that addresses code

	PUSH	HL		; save pointer to offset byte
	LD	HL,BERG		; address BERG in system variables
	DEC	(HL)		; decrement it
	POP	HL		; restore pointer

	JR	NZ,JUMP_2	; to JUMP_2 if not zero

	INC	HL		; step past the jump length.
	EXX			; switch in the main set.
	RET			; return.

;	Note. as a general rule the calculator avoids using the IY register
;	otherwise the cumbersome 4 instructions in the middle could be replaced by
;	dec (iy+$xx) - using three instruction bytes instead of six.



; THE 'JUMP' SUBROUTINE

; (Offset $2F; 'jump')
;	This enables the calculator to perform relative jumps just like
;	the Z80 chip's JR instruction.
;	This is one of the few routines to be polished for the ZX Spectrum.
;	See, without looking at the ZX Spectrum ROM, if you can get rid of the
;	relative jump.

mark_1C23:
jump:
	EXX			;switch in pointer set
JUMP_2:
	LD	E,(HL)		; the jump byte 0-127 forward, 128-255 back.

if ORIGINAL
mark_1C24:
	XOR	A		; clear accumulator.
	BIT	7,E		; test if negative jump
	JR	Z,JUMP_3	; skip, if positive
	CPL			; else change to $FF.
else
				; Note. Elegance from the ZX Spectrum.
	LD	A,E		;+
	RLA			;+
	SBC	A,A		;+
endif

mark_1C2B:
JUMP_3:
	LD	D,A		; transfer to high byte.
	ADD	HL,DE		; advance calculator pointer forward or back.

	EXX			; switch out pointer set.
	RET			; return.


; THE 'JUMP ON TRUE' SUBROUTINE

; (Offset $00; 'jump_true')
;	This enables the calculator to perform conditional relative jumps
;	dependent on whether the last test gave a true result
;	On the ZX81, the exponent will be zero for zero or else $81 for one.

mark_1C2F:
jump_true:
	LD	A,(DE)		; collect exponent byte

	AND	A		; is result 0 or 1 ?
	JR	NZ,jump		; back to JUMP if true (1).

	EXX			; else switch in the pointer set.
	INC	HL		; step past the jump length.
	EXX			; switch in the main set.
	RET			; return.



; THE 'MODULUS' SUBROUTINE

; ( Offset $2E: 'n_mod_m' )
; ( i1, i2 -- i3, i4 )
;	The subroutine calculate N mod M where M is the positive integer, the
;	'last value' on the calculator stack and N is the integer beneath.
;	The subroutine returns the integer quotient as the last value and the
;	remainder as the value beneath.
;	e.g.	17 MOD 3 = 5 remainder 2
;	It is invoked during the calculation of a random number and also by
;	the PRINT_FP routine.

mark_1C37:
n_mod_m:
	RST	_FP_CALC	;;	17, 3.
	DEFB	__st_mem_0	;;	17, 3.
	DEFB	__delete	;;	17.
	DEFB	__duplicate	;;	17, 17.
	DEFB	__get_mem_0	;;	17, 17, 3.
	DEFB	__division	;;	17, 17/3.
	DEFB	__int		;;	17, 5.
	DEFB	__get_mem_0	;;	17, 5, 3.
	DEFB	__exchange	;;	17, 3, 5.
	DEFB	__st_mem_0	;;	17, 3, 5.
	DEFB	__multiply	;;	17, 15.
	DEFB	__subtract	;;	2.
	DEFB	__get_mem_0	;;	2, 5.
	DEFB	__end_calc	;;	2, 5.

	RET			; return.



; THE 'INTEGER' FUNCTION

; (offset $24: 'int')
;	This function returns the integer of x, which is just the same as truncate
;	for positive numbers. The truncate literal truncates negative numbers
;	upwards so that -3.4 gives -3 whereas the BASIC INT function has to
;	truncate negative numbers down so that INT -3.4 is 4.
;	It is best to work through using, say, plus or minus 3.4 as examples.

mark_1C46:
int:
	RST	_FP_CALC	;;		x.	(= 3.4 or -3.4).
	DEFB	__duplicate	;;		x, x.
	DEFB	__less_0	;;		x, (1/0)
	DEFB	__jump_true	;;		x, (1/0)
	DEFB	X_NEG - $	;; X_NEG

	DEFB	__truncate	;;		trunc 3.4 = 3.
	DEFB	__end_calc	;;		3.

	RET			; return with + int x on stack.


mark_1C4E:
X_NEG:
	DEFB	__duplicate	;;		-3.4, -3.4.
	DEFB	__truncate	;;		-3.4, -3.
	DEFB	__st_mem_0	;;		-3.4, -3.
	DEFB	__subtract	;;		-.4
	DEFB	__get_mem_0	;;		-.4, -3.
	DEFB	__exchange	;;		-3, -.4.
	DEFB	__not		;;			-3, (0).
	DEFB	__jump_true	;;		-3.
	DEFB	EXIT - $	;;		-3.

	DEFB	__stk_one	;;		-3, 1.
	DEFB	__subtract	;;		-4.

mark_1C59:
EXIT:
	DEFB	__end_calc	;;		-4.

	RET			; return.



; Exponential (23)

;
;

mark_1C5B:
exp:
	RST	_FP_CALC	;;
	DEFB	__stk_data	;;
	DEFB	$F1		;;Exponent: $81, Bytes: 4
	DEFB	$38,$AA,$3B,$29 ;;
	DEFB	__multiply	;;
	DEFB	__duplicate	;;
	DEFB	__int		;;
	DEFB	$C3		;;st_mem_3
	DEFB	__subtract	;;
	DEFB	__duplicate	;;
	DEFB	__addition	;;
	DEFB	__stk_one	;;
	DEFB	__subtract	;;
	DEFB	__series_08	;;
	DEFB	$13		;;Exponent: $63, Bytes: 1
	DEFB	$36		;;(+00,+00,+00)
	DEFB	$58		;;Exponent: $68, Bytes: 2
	DEFB	$65,$66	;;(+00,+00)
	DEFB	$9D		;;Exponent: $6D, Bytes: 3
	DEFB	$78,$65,$40	;;(+00)
	DEFB	$A2		;;Exponent: $72, Bytes: 3
	DEFB	$60,$32,$C9	;;(+00)
	DEFB	$E7		;;Exponent: $77, Bytes: 4
	DEFB	$21,$F7,$AF,$24 ;;
	DEFB	$EB		;;Exponent: $7B, Bytes: 4
	DEFB	$2F,$B0,$B0,$14 ;;
	DEFB	$EE		;;Exponent: $7E, Bytes: 4
	DEFB	$7E,$BB,$94,$58 ;;
	DEFB	$F1		;;Exponent: $81, Bytes: 4
	DEFB	$3A,$7E,$F8,$CF ;;
	DEFB	$E3		;;get_mem_3
	DEFB	__end_calc	;;

	CALL	FP_TO_A
	JR	NZ,N_NEGTV

	JR	C,REPORT_6b

	ADD	A,(HL)		;
	JR	NC,RESULT_OK


mark_1C99:
REPORT_6b:
	RST	_ERROR_1
	DEFB	$05		; Error Report: Number too big

mark_1C9B:
N_NEGTV:
	JR	C,RESULT_ZERO

	SUB	(HL)		;
	JR	NC,RESULT_ZERO

	NEG			; Negate

mark_1CA2:
RESULT_OK:
	LD	(HL),A		;
	RET			; return.


mark_1CA4:
RESULT_ZERO:
	RST	_FP_CALC	;;
	DEFB	__delete	;;
	DEFB	__stk_zero	;;
	DEFB	__end_calc	;;

	RET			; return.



; THE 'NATURAL LOGARITHM' FUNCTION

; (offset $22: 'ln')
;	Like the ZX81 itself, 'natural' logarithms came from Scotland.
;	They were devised in 1614 by well-traveled Scotsman John Napier who noted
;	"Nothing doth more molest and hinder calculators than the multiplications,
;	divisions, square and cubical extractions of great numbers".
;
;	Napier's logarithms enabled the above operations to be accomplished by 
;	simple addition and subtraction simplifying the navigational and 
;	astronomical calculations which beset his age.
;	Napier's logarithms were quickly overtaken by logarithms to the base 10
;	devised, in conjunction with Napier, by Henry Briggs a Cambridge-educated 
;	professor of Geometry at Oxford University. These simplified the layout
;	of the tables enabling humans to easily scale calculations.
;
;	It is only recently with the introduction of pocket calculators and
;	computers like the ZX81 that natural logarithms are once more at the fore,
;	although some computers retain logarithms to the base ten.
;	'Natural' logarithms are powers to the base 'e', which like 'pi' is a 
;	naturally occurring number in branches of mathematics.
;	Like 'pi' also, 'e' is an irrational number and starts 2.718281828...
;
;	The tabular use of logarithms was that to multiply two numbers one looked
;	up their two logarithms in the tables, added them together and then looked 
;	for the result in a table of antilogarithms to give the desired product.
;
;	The EXP function is the BASIC equivalent of a calculator's 'antiln' function 
;	and by picking any two numbers, 1.72 and 6.89 say,
;	10 PRINT EXP ( LN 1.72 + LN 6.89 ) 
;	will give just the same result as
;	20 PRINT 1.72 * 6.89.
;	Division is accomplished by subtracting the two logs.
;
;	Napier also mentioned "square and cubicle extractions". 
;	To raise a number to the power 3, find its 'ln', multiply by 3 and find the 
;	'antiln'.	e.g. PRINT EXP( LN 4 * 3 )	gives 64.
;	Similarly to find the n'th root divide the logarithm by 'n'.
;	The ZX81 ROM used PRINT EXP ( LN 9 / 2 ) to find the square root of the 
;	number 9. The Napieran square root function is just a special case of 
;	the 'to_power' function. A cube root or indeed any root/power would be just
;	as simple.

;	First test that the argument to LN is a positive, non-zero number.

mark_1CA9:
ln:
	RST	_FP_CALC	;;
	DEFB	__duplicate	;;
	DEFB	__greater_0	;;
	DEFB	__jump_true	;;
	DEFB	VALID - $		;;to VALID

	DEFB	__end_calc	;;


mark_1CAF:
REPORT_Ab:
	RST	_ERROR_1
	DEFB	$09		; Error Report: Invalid argument

VALID:
if ORIGINAL
mark_1CB1:
	DEFB	__stk_zero	;;		Note. not necessary.
	DEFB	__delete	;;
endif
	DEFB	__end_calc	;;
	LD	A,(HL)		;

	LD	(HL),$80	;
	CALL	STACK_A

	RST	_FP_CALC	;;
	DEFB	__stk_data	;;
	DEFB	$38		;;Exponent: $88, Bytes: 1
	DEFB	$00		;;(+00,+00,+00)
	DEFB	__subtract	;;
	DEFB	__exchange	;;
	DEFB	__duplicate	;;
	DEFB	__stk_data	;;
	DEFB	$F0		;;Exponent: $80, Bytes: 4
	DEFB	$4C,$CC,$CC,$CD ;;
	DEFB	__subtract	;;
	DEFB	__greater_0	;;
	DEFB	__jump_true	;;
	DEFB	GRE_8 - $		;;

	DEFB	__exchange	;;
	DEFB	__stk_one	;;
	DEFB	__subtract	;;
	DEFB	__exchange	;;
	DEFB	__end_calc	;;

	INC	(HL)		;

	RST	_FP_CALC	;;

mark_1CD2:
GRE_8:
	DEFB	__exchange	;;
	DEFB	__stk_data	;;
	DEFB	$F0		;;Exponent: $80, Bytes: 4
	DEFB	$31,$72,$17,$F8 ;;
	DEFB	__multiply	;;
	DEFB	__exchange	;;
	DEFB	__stk_half		;;
	DEFB	__subtract	;;
	DEFB	__stk_half		;;
	DEFB	__subtract	;;
	DEFB	__duplicate	;;
	DEFB	__stk_data	;;
	DEFB	$32		;;Exponent: $82, Bytes: 1
	DEFB	$20		;;(+00,+00,+00)
	DEFB	__multiply	;;
	DEFB	__stk_half		;;
	DEFB	__subtract	;;
	DEFB	__series_0C	;;
	DEFB	$11		;;Exponent: $61, Bytes: 1
	DEFB	$AC		;;(+00,+00,+00)
	DEFB	$14		;;Exponent: $64, Bytes: 1
	DEFB	$09		;;(+00,+00,+00)
	DEFB	$56		;;Exponent: $66, Bytes: 2
	DEFB	$DA,$A5		;;(+00,+00)
	DEFB	$59		;;Exponent: $69, Bytes: 2
	DEFB	$30,$C5		;;(+00,+00)
	DEFB	$5C		;;Exponent: $6C, Bytes: 2
	DEFB	$90,$AA		;;(+00,+00)
	DEFB	$9E		;;Exponent: $6E, Bytes: 3
	DEFB	$70,$6F,$61	;;(+00)
	DEFB	$A1		;;Exponent: $71, Bytes: 3
	DEFB	$CB,$DA,$96	;;(+00)
	DEFB	$A4		;;Exponent: $74, Bytes: 3
	DEFB	$31,$9F,$B4	;;(+00)
	DEFB	$E7		;;Exponent: $77, Bytes: 4
	DEFB	$A0,$FE,$5C,$FC ;;
	DEFB	$EA		;;Exponent: $7A, Bytes: 4
	DEFB	$1B,$43,$CA,$36 ;;
	DEFB	$ED		;;Exponent: $7D, Bytes: 4
	DEFB	$A7,$9C,$7E,$5E ;;
	DEFB	$F0		;;Exponent: $80, Bytes: 4
	DEFB	$6E,$23,$80,$93 ;;
	DEFB	__multiply	;;
	DEFB	__addition	;;
	DEFB	__end_calc	;;

	RET			; return.

if ORIGINAL
else
; ------------------------------
; THE NEW 'SQUARE ROOT' FUNCTION
; ------------------------------
; (Offset $25: 'sqr')
;	"If I have seen further, it is by standing on the shoulders of giants" -
;	Sir Isaac Newton, Cambridge 1676.
;	The sqr function has been re-written to use the Newton-Raphson method.
;	Joseph Raphson was a student of Sir Isaac Newton at Cambridge University
;	and helped publicize his work.
;	Although Newton's method is centuries old, this routine, appropriately, is 
;	based on a FORTH word written by Steven Vickers in the Jupiter Ace manual.
;	Whereas that method uses an initial guess of one, this one manipulates 
;	the exponent byte to obtain a better starting guess. 
;	First test for zero and return zero, if so, as the result.
;	If the argument is negative, then produce an error.
;
sqr:	RST	_FP_CALC	;; 		x
	DEFB	__st_mem_3	;;		x.	(seed for guess)
	DEFB	__end_calc	;;		x.

;	HL now points to exponent of argument on calculator stack.

	LD	A,(HL)		; Test for zero argument
	AND	A		; 

	RET	Z		; Return with zero on the calculator stack.

;	Test for a positive argument

	INC	HL		; Address byte with sign bit.
	BIT	7,(HL)		; Test the bit.

	JR	NZ,REPORT_Ab	; back to REPORT_A 
				; 'Invalid argument'
 
;	This guess is based on a Usenet discussion.
;	Halve the exponent to achieve a good guess.(accurate with .25 16 64 etc.)

	LD	HL,$4071	; Address first byte of mem-3

	LD	A,(HL)		; fetch exponent of mem-3
	XOR	$80		; toggle sign of exponent of mem-3
	SRA	A		; shift right, bit 7 unchanged.
	INC	A		;
	JR	Z,ASIS		; forward with say .25 -> .5
	JP	P,ASIS		; leave increment if value > .5
	DEC	A		; restore to shift only.
ASIS:	XOR	$80		; restore sign.
	LD	(HL),A	; and put back 'halved' exponent.

;	Now re-enter the calculator.

	RST	28H		;; FP-CALC		x

SLOOP:	DEFB	__duplicate	;;		x,x.
	DEFB	__get_mem_3	;;		x,x,guess
	DEFB	__st_mem_4	;;		x,x,guess
	DEFB	__division	;;		x,x/guess.
	DEFB	__get_mem_3	;;		x,x/guess,guess
	DEFB	__addition	;;		x,x/guess+guess
	DEFB	__stk_half	;;		x,x/guess+guess,.5
	DEFB	__multiply	;;		x,(x/guess+guess)*.5
	DEFB	__st_mem_3	;;		x,newguess
	DEFB	__get_mem_4	;;		x,newguess,oldguess
	DEFB	__subtract	;;		x,newguess-oldguess
	DEFB	__abs		;;		x,difference.
	DEFB	__greater_0	;;		x,(0/1).
	DEFB	__jump_true	;;		x.

	DEFB	SLOOP - $	;;		x.

	DEFB	__delete	;;		.
	DEFB	__get_mem_3	;;		retrieve final guess.
	DEFB	__end_calc	;;		sqr x.

	RET			; return with square root on stack

;	or in ZX81 BASIC
;
;	5 PRINT "NEWTON RAPHSON SQUARE ROOTS"
;	10 INPUT "NUMBER ";N
;	20 INPUT "GUESS ";G
;	30 PRINT " NUMBER "; N ;" GUESS "; G
;	40 FOR I = 1 TO 10
;	50	LET B = N/G
;	60	LET C = B+G
;	70	LET G = C/2
;	80	PRINT I; " VALUE "; G
;	90 NEXT I
;	100 PRINT "NAPIER METHOD"; SQR N
endif


; THE 'TRIGONOMETRIC' FUNCTIONS

;	Trigonometry is rocket science. It is also used by carpenters and pyramid
;	builders. 
;	Some uses can be quite abstract but the principles can be seen in simple
;	right-angled triangles. Triangles have some special properties -
;
;	1) The sum of the three angles is always PI radians (180 degrees).
;	Very helpful if you know two angles and wish to find the third.
;	2) In any right-angled triangle the sum of the squares of the two shorter
;	sides is equal to the square of the longest side opposite the right-angle.
;	Very useful if you know the length of two sides and wish to know the
;	length of the third side.
;	3) Functions sine, cosine and tangent enable one to calculate the length 
;	of an unknown side when the length of one other side and an angle is 
;	known.
;	4) Functions arcsin, arccosine and arctan enable one to calculate an unknown
;	angle when the length of two of the sides is known.


; THE 'REDUCE ARGUMENT' SUBROUTINE

; (offset $35: 'get_argt')
;
;	This routine performs two functions on the angle, in radians, that forms
;	the argument to the sine and cosine functions.
;	First it ensures that the angle 'wraps round'. That if a ship turns through 
;	an angle of, say, 3*PI radians (540 degrees) then the net effect is to turn 
;	through an angle of PI radians (180 degrees).
;	Secondly it converts the angle in radians to a fraction of a right angle,
;	depending within which quadrant the angle lies, with the periodicity 
;	resembling that of the desired sine value.
;	The result lies in the range -1 to +1.
;
;			90 deg.
; 
;			(pi/2)
;			II  +1    I
;			|
;		sin+	|\   |   /|	sin+
;		cos-	| \  |	/ |	cos+
;		tan-	|  \ | /  |	tan+
;			|   \|/)  |
;	180 deg. (pi) 0 |----+----|-- 0	(0)	0 degrees
;			|   /|\   |
;		sin-	|  / | \  |	sin-
;		cos-	| /  |  \ |	cos+
;		tan+	|/   |   \|	tan-
;			|
;			III -1	 IV
;			(3pi/2)
;
;			270 deg.

mark_1D18:
get_argt:
	RST	_FP_CALC	;;		X.
	DEFB	__stk_data	;;
	DEFB	$EE		;;Exponent: $7E, 
				;;Bytes: 4
	DEFB	$22,$F9,$83,$6E ;;		X, 1/(2*PI)
	DEFB	__multiply	;;		X/(2*PI) = fraction

	DEFB	__duplicate	;;
	DEFB	__stk_half	;;
	DEFB	__addition	;;
	DEFB	__int		;;

	DEFB	__subtract	;;	now range -.5 to .5

	DEFB	__duplicate	;;
	DEFB	__addition	;;	now range -1 to 1.
	DEFB	__duplicate	;;
	DEFB	__addition	;;	now range -2 to 2.

;	quadrant I (0 to +1) and quadrant IV (-1 to 0) are now correct.
;	quadrant II ranges +1 to +2.
;	quadrant III ranges -2 to -1.

	DEFB	__duplicate	;;	Y, Y.
	DEFB	__abs		;;	Y, abs(Y).	range 1 to 2
	DEFB	__stk_one	;;	Y, abs(Y), 1.
	DEFB	__subtract	;;	Y, abs(Y)-1.	range 0 to 1
	DEFB	__duplicate	;;	Y, Z, Z.
	DEFB	__greater_0	;;	Y, Z, (1/0).

	DEFB	__st_mem_0	;;	store as possible sign 
				;;	for cosine function.

	DEFB	__jump_true	;;
	DEFB	Z_PLUS - $	;;	with quadrants II and III

;	else the angle lies in quadrant I or IV and value Y is already correct.

	DEFB	__delete	;;	Y	delete test value.
	DEFB	__end_calc	;;	Y.

	RET			; return.	with Q1 and Q4 >>>

;	The branch was here with quadrants II (0 to 1) and III (1 to 0).
;	Y will hold -2 to -1 if this is quadrant III.

mark_1D35:
Z_PLUS:
	DEFB	__stk_one	;;	Y, Z, 1
	DEFB	__subtract	;;	Y, Z-1.	Q3 = 0 to -1
	DEFB	__exchange	;;	Z-1, Y.
	DEFB	__less_0	;;	Z-1, (1/0).
	DEFB	__jump_true	;;	Z-1.
	DEFB	YNEG - $	;; 
				;;if angle in quadrant III

;	else angle is within quadrant II (-1 to 0)

	DEFB	__negate	;	range +1 to 0


mark_1D3C:
YNEG:
	DEFB	__end_calc	;;	quadrants II and III correct.

	RET			; return.



; THE 'COSINE' FUNCTION

; (offset $1D: 'cos')
;	Cosines are calculated as the sine of the opposite angle rectifying the 
;	sign depending on the quadrant rules. 
;
;
;	    /|
;	 h /y|
;	  /  |o
;	 / x |
;	/----|
;	  a
;
;	The cosine of angle x is the adjacent side (a) divided by the hypotenuse 1.
;	However if we examine angle y then a/h is the sine of that angle.
;	Since angle x plus angle y equals a right-angle, we can find angle y by 
;	subtracting angle x from pi/2.
;	However it's just as easy to reduce the argument first and subtract the
;	reduced argument from the value 1 (a reduced right-angle).
;	It's even easier to subtract 1 from the angle and rectify the sign.
;	In fact, after reducing the argument, the absolute value of the argument
;	is used and rectified using the test result stored in mem-0 by 'get-argt'
;	for that purpose.

mark_1D3E:
cos:
	RST	_FP_CALC	;;	angle in radians.
	DEFB	__get_argt	;;	X	reduce -1 to +1

	DEFB	__abs		;;	ABS X	0 to 1
	DEFB	__stk_one	;;	ABS X, 1.
	DEFB	__subtract	;;		now opposite angle 
				;;		though negative sign.
	DEFB	__get_mem_0	;;		fetch sign indicator.
	DEFB	__jump_true	;;
	DEFB	C_ENT - $	;;fwd to C_ENT
				;;forward to common code if in QII or QIII 


	DEFB	__negate	;;		else make positive.
	DEFB	__jump		;;
	DEFB	C_ENT - $	;;fwd to C_ENT
				;;with quadrants QI and QIV 


; THE 'SINE' FUNCTION

; (offset $1C: 'sin')
;	This is a fundamental transcendental function from which others such as cos
;	and tan are directly, or indirectly, derived.
;	It uses the series generator to produce Chebyshev polynomials.
;
;
;	    /|
;	 1 / |
;	  /  |x
;	 /a  |
;	/----|
;	  y
;
;	The 'get-argt' function is designed to modify the angle and its sign 
;	in line with the desired sine value and afterwards it can launch straight
;	into common code.

mark_1D49:
sin:
	RST	_FP_CALC	;;	angle in radians
	DEFB	__get_argt	;;	reduce - sign now correct.

mark_1D4B:
C_ENT:
	DEFB	__duplicate	;;
	DEFB	__duplicate	;;
	DEFB	__multiply	;;
	DEFB	__duplicate	;;
	DEFB	__addition	;;
	DEFB	__stk_one	;;
	DEFB	__subtract	;;

	DEFB	__series_06	;;
	DEFB	$14		;;Exponent: $64, Bytes: 1
	DEFB	$E6		;;(+00,+00,+00)
	DEFB	$5C		;;Exponent: $6C, Bytes: 2
	DEFB	$1F,$0B		;;(+00,+00)
	DEFB	$A3		;;Exponent: $73, Bytes: 3
	DEFB	$8F,$38,$EE	;;(+00)
	DEFB	$E9		;;Exponent: $79, Bytes: 4
	DEFB	$15,$63,$BB,$23 ;;
	DEFB	$EE		;;Exponent: $7E, Bytes: 4
	DEFB	$92,$0D,$CD,$ED ;;
	DEFB	$F1		;;Exponent: $81, Bytes: 4
	DEFB	$23,$5D,$1B,$EA ;;

	DEFB	__multiply	;;
	DEFB	__end_calc	;;

	RET			; return.



; THE 'TANGENT' FUNCTION

; (offset $1E: 'tan')
;
;	Evaluates tangent x as	sin(x) / cos(x).
;
;
;	    /|
;	 h / |
;	  /  |o
;	 /x  |
;	/----|
;	   a
;
;	The tangent of angle x is the ratio of the length of the opposite side 
;	divided by the length of the adjacent side. As the opposite length can 
;	be calculates using sin(x) and the adjacent length using cos(x) then 
;	the tangent can be defined in terms of the previous two functions.

;	Error 6 if the argument, in radians, is too close to one like pi/2
;	which has an infinite tangent. e.g. PRINT TAN (PI/2)	evaluates as 1/0.
;	Similarly PRINT TAN (3*PI/2), TAN (5*PI/2) etc.

mark_1D6E:
tan:
	RST	_FP_CALC	;;	x.
	DEFB	__duplicate	;;	x, x.
	DEFB	__sin		;;	x, sin x.
	DEFB	__exchange	;;	sin x, x.
	DEFB	__cos		;;	sin x, cos x.
	DEFB	__division	;;	sin x/cos x (= tan x).
	DEFB	__end_calc	;;	tan x.

	RET			; return.


; THE 'ARCTAN' FUNCTION

; (Offset $21: 'atn')
;	The inverse tangent function with the result in radians.
;	This is a fundamental transcendental function from which others such as
;	asn and acs are directly, or indirectly, derived.
;	It uses the series generator to produce Chebyshev polynomials.

mark_1D76:
atn:
	LD	A,(HL)		; fetch exponent
	CP	$81		; compare to that for 'one'
	JR	C,SMALL	; forward, if less

	RST	_FP_CALC	;;		X.
	DEFB	__stk_one	;;
	DEFB	__negate	;;
	DEFB	__exchange	;;
	DEFB	__division	;;
	DEFB	__duplicate	;;
	DEFB	__less_0	;;
	DEFB	__stk_half_pi	;;
	DEFB	__exchange	;;
	DEFB	__jump_true	;;
	DEFB	CASES - $	;;

	DEFB	__negate	;;
	DEFB	__jump		;;
	DEFB	CASES - $	;;

; ___

mark_1D89:
SMALL:
	RST	_FP_CALC	;;
	DEFB	__stk_zero	;;

mark_1D8B:
CASES:
	DEFB	__exchange	;;
	DEFB	__duplicate	;;
	DEFB	__duplicate	;;
	DEFB	__multiply	;;
	DEFB	__duplicate	;;
	DEFB	__addition	;;
	DEFB	__stk_one	;;
	DEFB	__subtract	;;

	DEFB	__series_0C	;;
	DEFB	$10		;;Exponent: $60, Bytes: 1
	DEFB	$B2		;;(+00,+00,+00)
	DEFB	$13		;;Exponent: $63, Bytes: 1
	DEFB	$0E		;;(+00,+00,+00)
	DEFB	$55		;;Exponent: $65, Bytes: 2
	DEFB	$E4,$8D		;;(+00,+00)
	DEFB	$58		;;Exponent: $68, Bytes: 2
	DEFB	$39,$BC		;;(+00,+00)
	DEFB	$5B		;;Exponent: $6B, Bytes: 2
	DEFB	$98,$FD		;;(+00,+00)
	DEFB	$9E		;;Exponent: $6E, Bytes: 3
	DEFB	$00,$36,$75	;;(+00)
	DEFB	$A0		;;Exponent: $70, Bytes: 3
	DEFB	$DB,$E8,$B4	;;(+00)
	DEFB	$63		;;Exponent: $73, Bytes: 2
	DEFB	$42,$C4		;;(+00,+00)
	DEFB	$E6		;;Exponent: $76, Bytes: 4
	DEFB	$B5,$09,$36,$BE ;;
	DEFB	$E9		;;Exponent: $79, Bytes: 4
	DEFB	$36,$73,$1B,$5D ;;
	DEFB	$EC		;;Exponent: $7C, Bytes: 4
	DEFB	$D8,$DE,$63,$BE ;;
	DEFB	$F0		;;Exponent: $80, Bytes: 4
	DEFB	$61,$A1,$B3,$0C ;;

	DEFB	__multiply	;;
	DEFB	__addition	;;
	DEFB	__end_calc	;;

	RET			; return.



; THE 'ARCSIN' FUNCTION

; (Offset $1F: 'asn')
;	The inverse sine function with result in radians.
;	Derived from arctan function above.
;	Error A unless the argument is between -1 and +1 inclusive.
;	Uses an adaptation of the formula asn(x) = atn(x/sqr(1-x*x))
;
;
;		    /|
;		   / |
;		 1/  |x
;		 /a  |
;		/----|
;		  y
;
;	e.g. We know the opposite side (x) and hypotenuse (1) 
;	and we wish to find angle a in radians.
;	We can derive length y by Pythagoras and then use ATN instead. 
;	Since y*y + x*x = 1*1 (Pythagoras Theorem) then
;	y=sqr(1-x*x)			- no need to multiply 1 by itself.
;	So, asn(a) = atn(x/y)
;	or more fully,
;	asn(a) = atn(x/sqr(1-x*x))

;	Close but no cigar.

;	While PRINT ATN (x/SQR (1-x*x)) gives the same results as PRINT ASN x,
;	it leads to division by zero when x is 1 or -1.
;	To overcome this, 1 is added to y giving half the required angle and the 
;	result is then doubled. 
;	That is, PRINT ATN (x/(SQR (1-x*x) +1)) *2
;
;
;	.            /|
;	.          c/ |
;	.          /1 |x
;	. c	b /a  |
;	---------/----|
;	1	y
;
;	By creating an isosceles triangle with two equal sides of 1, angles c and 
;	c are also equal. If b+c+d = 180 degrees and b+a = 180 degrees then c=a/2.
;
;	A value higher than 1 gives the required error as attempting to find	the
;	square root of a negative number generates an error in Sinclair BASIC.

mark_1DC4:
asn:
	RST	_FP_CALC	;;	x.
	DEFB	__duplicate	;;	x, x.
	DEFB	__duplicate	;;	x, x, x.
	DEFB	__multiply	;;	x, x*x.
	DEFB	__stk_one	;;	x, x*x, 1.
	DEFB	__subtract	;;	x, x*x-1.
	DEFB	__negate	;;	x, 1-x*x.
	DEFB	__sqr		;;	x, sqr(1-x*x) = y.
	DEFB	__stk_one	;;	x, y, 1.
	DEFB	__addition	;;	x, y+1.
	DEFB	__division	;;	x/y+1.
	DEFB	__atn		;;	a/2	(half the angle)
	DEFB	__duplicate	;;	a/2, a/2.
	DEFB	__addition	;;	a.
	DEFB	__end_calc	;;	a.

	RET			; return.



; THE 'ARCCOS' FUNCTION

; (Offset $20: 'acs')
;	The inverse cosine function with the result in radians.
;	Error A unless the argument is between -1 and +1.
;	Result in range 0 to pi.
;	Derived from asn above which is in turn derived from the preceding atn. It 
;	could have been derived directly from atn using acs(x) = atn(sqr(1-x*x)/x).
;	However, as sine and cosine are horizontal translations of each other,
;	uses acs(x) = pi/2 - asn(x)

;	e.g. the arccosine of a known x value will give the required angle b in 
;	radians.
;	We know, from above, how to calculate the angle a using asn(x). 
;	Since the three angles of any triangle add up to 180 degrees, or pi radians,
;	and the largest angle in this case is a right-angle (pi/2 radians), then
;	we can calculate angle b as pi/2 (both angles) minus asn(x) (angle a).
; 
;;
;	    /|
;	 1 /b|
;	  /  |x
;	 /a  |
;	/----|
;	  y

mark_1DD4:
acs:
	RST	_FP_CALC	;;	x.
	DEFB	__asn		;;	asn(x).
	DEFB	__stk_half_pi	;;	asn(x), pi/2.
	DEFB	__subtract	;;	asn(x) - pi/2.
	DEFB	__negate	;;	pi/2 - asn(x) = acs(x).
	DEFB	__end_calc	;;	acs(x)

	RET			; return.

if ORIGINAL

; THE 'SQUARE ROOT' FUNCTION

; (Offset $25: 'sqr')
;	Error A if argument is negative.
;	This routine is remarkable for its brevity - 7 bytes.
;
;	The ZX81 code was originally 9K and various techniques had to be
;	used to shoe-horn it into an 8K Rom chip.

; This routine uses Napier's method for calculating square roots which was 
; devised in 1614 and calculates the value as EXP (LN 'x' * 0.5).
;
; This is a little on the slow side as it involves two polynomial series.
; A series of 12 for LN and a series of 8 for EXP.
; This was of no concern to John Napier since his tables were 'compiled forever'.

mark_1DDB:
sqr:
	RST	_FP_CALC	;;	x.
	DEFB	__duplicate	;;	x, x.
	DEFB	__not		;;	x, 1/0
	DEFB	__jump_true	;;	x, (1/0).
	DEFB	LAST - $	;; exit if argument zero
				;;		with zero result.

;	else continue to calculate as x ** .5

	DEFB	__stk_half	;;	x, .5.
	DEFB	__end_calc	;;	x, .5.

endif


; THE 'EXPONENTIATION' OPERATION

; (Offset $06: 'to_power')
;	This raises the first number X to the power of the second number Y.
;	As with the ZX80,
;	0 ** 0 = 1
;	0 ** +n = 0
;	0 ** -n = arithmetic overflow.

mark_1DE2:
to_power:
	RST	_FP_CALC	;;	X,Y.
	DEFB	__exchange	;;	Y,X.
	DEFB	__duplicate	;;	Y,X,X.
	DEFB	__not		;;	Y,X,(1/0).
	DEFB	__jump_true	;;
	DEFB	XISO - $	;;forward to XISO if X is zero.

;	else X is non-zero. function 'ln' will catch a negative value of X.

	DEFB	__ln		;;	Y, LN X.
	DEFB	__multiply	;;	Y * LN X
	DEFB	__end_calc	;;

	JP	exp		; jump back to EXP routine.	->

; ___

;	These routines form the three simple results when the number is zero.
;	begin by deleting the known zero to leave Y the power factor.

mark_1DEE:
XISO:
	DEFB	__delete	;;	Y.
	DEFB	__duplicate	;;	Y, Y.
	DEFB	__not		;;	Y, (1/0).
	DEFB	__jump_true	;;
	DEFB	ONE - $		;; if Y is zero.

;	the power factor is not zero. If negative then an error exists.

	DEFB	__stk_zero	;;	Y, 0.
	DEFB	__exchange	;;	0, Y.
	DEFB	__greater_0	;;	0, (1/0).
	DEFB	__jump_true	;;	0
	DEFB	LAST - $	;; if Y was any positive 
				;; number.

;	else force division by zero thereby raising an Arithmetic overflow error.
;	There are some one and two-byte alternatives but perhaps the most formal
;	might have been to use end_calc; rst 08; defb 05.

;	if ORIGINAL

; the SG ROM seems to want it the old way!
if 1
	DEFB	__stk_one	;;	0, 1.
	DEFB	__exchange	;;	1, 0.
	DEFB	__division	;;	1/0	>> error 
else
	DEFB	$34		;+ end-calc
REPORT_6c
	RST	08H		;+ ERROR-1
	DEFB	$05		;+ Error Report: Number too big
endif


; ___

mark_1DFB:
ONE:
	DEFB	__delete	;;	.
	DEFB	__stk_one	;;	1.

mark_1DFD:
LAST:
	DEFB	__end_calc	;;		last value 1 or 0.

	RET			; return.


; THE 'SPARE LOCATIONS'

SPARE:

if ORIGINAL
mark_1DFF:
	DEFB	$FF		; That's all folks.
else
mark_1DFE:
L1DFE:

;;	DEFB	$FF, $FF	; Two spare bytes.
	DEFB	$00, $00	; Two spare bytes (as per the Shoulders of Giants ROM)
endif



; THE 'ZX81 CHARACTER SET'


mark_1E00:
char_set:	; - begins with space character.

; $00 - Character: ' '		CHR$(0)

	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00000000

; $01 - Character: mosaic	CHR$(1)

	DEFB	%11110000
	DEFB	%11110000
	DEFB	%11110000
	DEFB	%11110000
	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00000000


; $02 - Character: mosaic	CHR$(2)

	DEFB	%00001111
	DEFB	%00001111
	DEFB	%00001111
	DEFB	%00001111
	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00000000


; $03 - Character: mosaic	CHR$(3)

	DEFB	%11111111
	DEFB	%11111111
	DEFB	%11111111
	DEFB	%11111111
	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00000000

; $04 - Character: mosaic	CHR$(4)

	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00000000
	DEFB	%11110000
	DEFB	%11110000
	DEFB	%11110000
	DEFB	%11110000

; $05 - Character: mosaic	CHR$(5)

	DEFB	%11110000
	DEFB	%11110000
	DEFB	%11110000
	DEFB	%11110000
	DEFB	%11110000
	DEFB	%11110000
	DEFB	%11110000
	DEFB	%11110000

; $06 - Character: mosaic	CHR$(6)

	DEFB	%00001111
	DEFB	%00001111
	DEFB	%00001111
	DEFB	%00001111
	DEFB	%11110000
	DEFB	%11110000
	DEFB	%11110000
	DEFB	%11110000

; $07 - Character: mosaic	CHR$(7)

	DEFB	%11111111
	DEFB	%11111111
	DEFB	%11111111
	DEFB	%11111111
	DEFB	%11110000
	DEFB	%11110000
	DEFB	%11110000
	DEFB	%11110000

; $08 - Character: mosaic	CHR$(8)

	DEFB	%10101010
	DEFB	%01010101
	DEFB	%10101010
	DEFB	%01010101
	DEFB	%10101010
	DEFB	%01010101
	DEFB	%10101010
	DEFB	%01010101
; $09 - Character: mosaic	CHR$(9)

	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00000000
	DEFB	%10101010
	DEFB	%01010101
	DEFB	%10101010
	DEFB	%01010101
; $0A - Character: mosaic	CHR$(10)

	DEFB	%10101010
	DEFB	%01010101
	DEFB	%10101010
	DEFB	%01010101
	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00000000

; $0B - Character: '"'		CHR$(11)

	DEFB	%00000000
	DEFB	%00100100
	DEFB	%00100100
	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00000000

; $0C - Character:	�		CHR$(12)

	DEFB	%00000000
	DEFB	%00011100
	DEFB	%00100010
	DEFB	%01111000
	DEFB	%00100000
	DEFB	%00100000
	DEFB	%01111110
	DEFB	%00000000

; $0D - Character: '$'		CHR$(13)

	DEFB	%00000000
	DEFB	%00001000
	DEFB	%00111110
	DEFB	%00101000
	DEFB	%00111110
	DEFB	%00001010
	DEFB	%00111110
	DEFB	%00001000

; $0E - Character: ':'		CHR$(14)

	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00010000
	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00010000
	DEFB	%00000000

; $0F - Character: '?'		CHR$(15)

	DEFB	%00000000
	DEFB	%00111100
	DEFB	%01000010
	DEFB	%00000100
	DEFB	%00001000
	DEFB	%00000000
	DEFB	%00001000
	DEFB	%00000000

; $10 - Character: '('		CHR$(16)

	DEFB	%00000000
	DEFB	%00000100
	DEFB	%00001000
	DEFB	%00001000
	DEFB	%00001000
	DEFB	%00001000
	DEFB	%00000100
	DEFB	%00000000

; $11 - Character: ')'		CHR$(17)

	DEFB	%00000000
	DEFB	%00100000
	DEFB	%00010000
	DEFB	%00010000
	DEFB	%00010000
	DEFB	%00010000
	DEFB	%00100000
	DEFB	%00000000

; $12 - Character: '>'		CHR$(18)

	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00010000
	DEFB	%00001000
	DEFB	%00000100
	DEFB	%00001000
	DEFB	%00010000
	DEFB	%00000000

; $13 - Character: '<'		CHR$(19)

	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00000100
	DEFB	%00001000
	DEFB	%00010000
	DEFB	%00001000
	DEFB	%00000100
	DEFB	%00000000

; $14 - Character: '='		CHR$(20)

	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00111110
	DEFB	%00000000
	DEFB	%00111110
	DEFB	%00000000
	DEFB	%00000000

; $15 - Character: '+'		CHR$(21)

	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00001000
	DEFB	%00001000
	DEFB	%00111110
	DEFB	%00001000
	DEFB	%00001000
	DEFB	%00000000

; $16 - Character: '-'		CHR$(22)

	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00111110
	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00000000

; $17 - Character: '*'		CHR$(23)

	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00010100
	DEFB	%00001000
	DEFB	%00111110
	DEFB	%00001000
	DEFB	%00010100
	DEFB	%00000000

; $18 - Character: '/'		CHR$(24)

	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00000010
	DEFB	%00000100
	DEFB	%00001000
	DEFB	%00010000
	DEFB	%00100000
	DEFB	%00000000

; $19 - Character: ';'		CHR$(25)

	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00010000
	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00010000
	DEFB	%00010000
	DEFB	%00100000

; $1A - Character: ','		CHR$(26)

	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00001000
	DEFB	%00001000
	DEFB	%00010000

; $1B - Character: '"'		CHR$(27)

	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00000000
	DEFB	%00011000
	DEFB	%00011000
	DEFB	%00000000

; $1C - Character: '0'		CHR$(28)

	DEFB	%00000000
	DEFB	%00111100
	DEFB	%01000110
	DEFB	%01001010
	DEFB	%01010010
	DEFB	%01100010
	DEFB	%00111100
	DEFB	%00000000

; $1D - Character: '1'		CHR$(29)

	DEFB	%00000000
	DEFB	%00011000
	DEFB	%00101000
	DEFB	%00001000
	DEFB	%00001000
	DEFB	%00001000
	DEFB	%00111110
	DEFB	%00000000

; $1E - Character: '2'		CHR$(30)

	DEFB	%00000000
	DEFB	%00111100
	DEFB	%01000010
	DEFB	%00000010
	DEFB	%00111100
	DEFB	%01000000
	DEFB	%01111110
	DEFB	%00000000

; $1F - Character: '3'		CHR$(31)

	DEFB	%00000000
	DEFB	%00111100
	DEFB	%01000010
	DEFB	%00001100
	DEFB	%00000010
	DEFB	%01000010
	DEFB	%00111100
	DEFB	%00000000

; $20 - Character: '4'		CHR$(32)

	DEFB	%00000000
	DEFB	%00001000
	DEFB	%00011000
	DEFB	%00101000
	DEFB	%01001000
	DEFB	%01111110
	DEFB	%00001000
	DEFB	%00000000

; $21 - Character: '5'		CHR$(33)

	DEFB	%00000000
	DEFB	%01111110
	DEFB	%01000000
	DEFB	%01111100
	DEFB	%00000010
	DEFB	%01000010
	DEFB	%00111100
	DEFB	%00000000

; $22 - Character: '6'		CHR$(34)

	DEFB	%00000000
	DEFB	%00111100
	DEFB	%01000000
	DEFB	%01111100
	DEFB	%01000010
	DEFB	%01000010
	DEFB	%00111100
	DEFB	%00000000

; $23 - Character: '7'		CHR$(35)

	DEFB	%00000000
	DEFB	%01111110
	DEFB	%00000010
	DEFB	%00000100
	DEFB	%00001000
	DEFB	%00010000
	DEFB	%00010000
	DEFB	%00000000

; $24 - Character: '8'		CHR$(36)

	DEFB	%00000000
	DEFB	%00111100
	DEFB	%01000010
	DEFB	%00111100
	DEFB	%01000010
	DEFB	%01000010
	DEFB	%00111100
	DEFB	%00000000

; $25 - Character: '9'		CHR$(37)

	DEFB	%00000000
	DEFB	%00111100
	DEFB	%01000010
	DEFB	%01000010
	DEFB	%00111110
	DEFB	%00000010
	DEFB	%00111100
	DEFB	%00000000

; $26 - Character: 'A'		CHR$(38)

	DEFB	%00000000
	DEFB	%00111100
	DEFB	%01000010
	DEFB	%01000010
	DEFB	%01111110
	DEFB	%01000010
	DEFB	%01000010
	DEFB	%00000000

; $27 - Character: 'B'		CHR$(39)

	DEFB	%00000000
	DEFB	%01111100
	DEFB	%01000010
	DEFB	%01111100
	DEFB	%01000010
	DEFB	%01000010
	DEFB	%01111100
	DEFB	%00000000

; $28 - Character: 'C'		CHR$(40)

	DEFB	%00000000
	DEFB	%00111100
	DEFB	%01000010
	DEFB	%01000000
	DEFB	%01000000
	DEFB	%01000010
	DEFB	%00111100
	DEFB	%00000000

; $29 - Character: 'D'		CHR$(41)

	DEFB	%00000000
	DEFB	%01111000
	DEFB	%01000100
	DEFB	%01000010
	DEFB	%01000010
	DEFB	%01000100
	DEFB	%01111000
	DEFB	%00000000

; $2A - Character: 'E'		CHR$(42)

	DEFB	%00000000
	DEFB	%01111110
	DEFB	%01000000
	DEFB	%01111100
	DEFB	%01000000
	DEFB	%01000000
	DEFB	%01111110
	DEFB	%00000000

; $2B - Character: 'F'		CHR$(43)

	DEFB	%00000000
	DEFB	%01111110
	DEFB	%01000000
	DEFB	%01111100
	DEFB	%01000000
	DEFB	%01000000
	DEFB	%01000000
	DEFB	%00000000

; $2C - Character: 'G'		CHR$(44)

	DEFB	%00000000
	DEFB	%00111100
	DEFB	%01000010
	DEFB	%01000000
	DEFB	%01001110
	DEFB	%01000010
	DEFB	%00111100
	DEFB	%00000000

; $2D - Character: 'H'		CHR$(45)

	DEFB	%00000000
	DEFB	%01000010
	DEFB	%01000010
	DEFB	%01111110
	DEFB	%01000010
	DEFB	%01000010
	DEFB	%01000010
	DEFB	%00000000

; $2E - Character: 'I'		CHR$(46)

	DEFB	%00000000
	DEFB	%00111110
	DEFB	%00001000
	DEFB	%00001000
	DEFB	%00001000
	DEFB	%00001000
	DEFB	%00111110
	DEFB	%00000000

; $2F - Character: 'J'		CHR$(47)

	DEFB	%00000000
	DEFB	%00000010
	DEFB	%00000010
	DEFB	%00000010
	DEFB	%01000010
	DEFB	%01000010
	DEFB	%00111100
	DEFB	%00000000

; $30 - Character: 'K'		CHR$(48)

	DEFB	%00000000
	DEFB	%01000100
	DEFB	%01001000
	DEFB	%01110000
	DEFB	%01001000
	DEFB	%01000100
	DEFB	%01000010
	DEFB	%00000000

; $31 - Character: 'L'		CHR$(49)

	DEFB	%00000000
	DEFB	%01000000
	DEFB	%01000000
	DEFB	%01000000
	DEFB	%01000000
	DEFB	%01000000
	DEFB	%01111110
	DEFB	%00000000

; $32 - Character: 'M'		CHR$(50)

	DEFB	%00000000
	DEFB	%01000010
	DEFB	%01100110
	DEFB	%01011010
	DEFB	%01000010
	DEFB	%01000010
	DEFB	%01000010
	DEFB	%00000000

; $33 - Character: 'N'		CHR$(51)

	DEFB	%00000000
	DEFB	%01000010
	DEFB	%01100010
	DEFB	%01010010
	DEFB	%01001010
	DEFB	%01000110
	DEFB	%01000010
	DEFB	%00000000

; $34 - Character: 'O'		CHR$(52)

	DEFB	%00000000
	DEFB	%00111100
	DEFB	%01000010
	DEFB	%01000010
	DEFB	%01000010
	DEFB	%01000010
	DEFB	%00111100
	DEFB	%00000000

; $35 - Character: 'P'		CHR$(53)

	DEFB	%00000000
	DEFB	%01111100
	DEFB	%01000010
	DEFB	%01000010
	DEFB	%01111100
	DEFB	%01000000
	DEFB	%01000000
	DEFB	%00000000

; $36 - Character: 'Q'		CHR$(54)

	DEFB	%00000000
	DEFB	%00111100
	DEFB	%01000010
	DEFB	%01000010
	DEFB	%01010010
	DEFB	%01001010
	DEFB	%00111100
	DEFB	%00000000

; $37 - Character: 'R'		CHR$(55)

	DEFB	%00000000
	DEFB	%01111100
	DEFB	%01000010
	DEFB	%01000010
	DEFB	%01111100
	DEFB	%01000100
	DEFB	%01000010
	DEFB	%00000000

; $38 - Character: 'S'		CHR$(56)

	DEFB	%00000000
	DEFB	%00111100
	DEFB	%01000000
	DEFB	%00111100
	DEFB	%00000010
	DEFB	%01000010
	DEFB	%00111100
	DEFB	%00000000

; $39 - Character: 'T'		CHR$(57)

	DEFB	%00000000
	DEFB	%11111110
	DEFB	%00010000
	DEFB	%00010000
	DEFB	%00010000
	DEFB	%00010000
	DEFB	%00010000
	DEFB	%00000000

; $3A - Character: 'U'		CHR$(58)

	DEFB	%00000000
	DEFB	%01000010
	DEFB	%01000010
	DEFB	%01000010
	DEFB	%01000010
	DEFB	%01000010
	DEFB	%00111100
	DEFB	%00000000

; $3B - Character: 'V'		CHR$(59)

	DEFB	%00000000
	DEFB	%01000010
	DEFB	%01000010
	DEFB	%01000010
	DEFB	%01000010
	DEFB	%00100100
	DEFB	%00011000
	DEFB	%00000000

; $3C - Character: 'W'		CHR$(60)

	DEFB	%00000000
	DEFB	%01000010
	DEFB	%01000010
	DEFB	%01000010
	DEFB	%01000010
	DEFB	%01011010
	DEFB	%00100100
	DEFB	%00000000

; $3D - Character: 'X'		CHR$(61)

	DEFB	%00000000
	DEFB	%01000010
	DEFB	%00100100
	DEFB	%00011000
	DEFB	%00011000
	DEFB	%00100100
	DEFB	%01000010
	DEFB	%00000000

; $3E - Character: 'Y'		CHR$(62)

	DEFB	%00000000
	DEFB	%10000010
	DEFB	%01000100
	DEFB	%00101000
	DEFB	%00010000
	DEFB	%00010000
	DEFB	%00010000
	DEFB	%00000000

; $3F - Character: 'Z'		CHR$(63)

	DEFB	%00000000
	DEFB	%01111110
	DEFB	%00000100
	DEFB	%00001000
	DEFB	%00010000
	DEFB	%00100000
	DEFB	%01111110
	DEFB	%00000000


