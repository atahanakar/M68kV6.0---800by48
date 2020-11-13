; C:\M68KV6.0 - 800BY48\PROGRAMS\DEBUGMONITORCODE\M68KUSERPROGRAM (DE1).C - Compiled by CC68K  Version 5.00 (c) 1991-2005  Peter J. Fondse
; #include <stdio.h>
; #include <string.h>
; #include <ctype.h>
; //IMPORTANT
; //
; // Uncomment one of the two #defines below
; // Define StartOfExceptionVectorTable as 08030000 if running programs from sram or
; // 0B000000 for running programs from dram
; //
; // In your labs, you will initially start by designing a system with SRam and later move to
; // Dram, so these constants will need to be changed based on the version of the system you have
; // building
; //
; // The working 68k system SOF file posted on canvas that you can use for your pre-lab
; // is based around Dram so #define accordingly before building
; #define StartOfExceptionVectorTable 0x08030000
; //#define StartOfExceptionVectorTable 0x0B000000
; /**********************************************************************************************
; **	Parallel port addresses
; **********************************************************************************************/
; #define PortA   *(volatile unsigned char *)(0x00400000)
; #define PortB   *(volatile unsigned char *)(0x00400002)
; #define PortC   *(volatile unsigned char *)(0x00400004)
; #define PortD   *(volatile unsigned char *)(0x00400006)
; #define PortE   *(volatile unsigned char *)(0x00400008)
; /*********************************************************************************************
; **	Hex 7 seg displays port addresses
; *********************************************************************************************/
; #define HEX_A        *(volatile unsigned char *)(0x00400010)
; #define HEX_B        *(volatile unsigned char *)(0x00400012)
; #define HEX_C        *(volatile unsigned char *)(0x00400014)    // de2 only
; #define HEX_D        *(volatile unsigned char *)(0x00400016)    // de2 only
; /**********************************************************************************************
; **	LCD display port addresses
; **********************************************************************************************/
; #define LCDcommand   *(volatile unsigned char *)(0x00400020)
; #define LCDdata      *(volatile unsigned char *)(0x00400022)
; /********************************************************************************************
; **	Timer Port addresses
; *********************************************************************************************/
; #define Timer1Data      *(volatile unsigned char *)(0x00400030)
; #define Timer1Control   *(volatile unsigned char *)(0x00400032)
; #define Timer1Status    *(volatile unsigned char *)(0x00400032)
; #define Timer2Data      *(volatile unsigned char *)(0x00400034)
; #define Timer2Control   *(volatile unsigned char *)(0x00400036)
; #define Timer2Status    *(volatile unsigned char *)(0x00400036)
; #define Timer3Data      *(volatile unsigned char *)(0x00400038)
; #define Timer3Control   *(volatile unsigned char *)(0x0040003A)
; #define Timer3Status    *(volatile unsigned char *)(0x0040003A)
; #define Timer4Data      *(volatile unsigned char *)(0x0040003C)
; #define Timer4Control   *(volatile unsigned char *)(0x0040003E)
; #define Timer4Status    *(volatile unsigned char *)(0x0040003E)
; /*********************************************************************************************
; **	RS232 port addresses
; *********************************************************************************************/
; #define RS232_Control     *(volatile unsigned char *)(0x00400040)
; #define RS232_Status      *(volatile unsigned char *)(0x00400040)
; #define RS232_TxData      *(volatile unsigned char *)(0x00400042)
; #define RS232_RxData      *(volatile unsigned char *)(0x00400042)
; #define RS232_Baud        *(volatile unsigned char *)(0x00400044)
; /*********************************************************************************************
; **	PIA 1 and 2 port addresses
; *********************************************************************************************/
; #define PIA1_PortA_Data     *(volatile unsigned char *)(0x00400050)         // combined data and data direction register share same address
; #define PIA1_PortA_Control *(volatile unsigned char *)(0x00400052)
; #define PIA1_PortB_Data     *(volatile unsigned char *)(0x00400054)         // combined data and data direction register share same address
; #define PIA1_PortB_Control *(volatile unsigned char *)(0x00400056)
; #define PIA2_PortA_Data     *(volatile unsigned char *)(0x00400060)         // combined data and data direction register share same address
; #define PIA2_PortA_Control *(volatile unsigned char *)(0x00400062)
; #define PIA2_PortB_data     *(volatile unsigned char *)(0x00400064)         // combined data and data direction register share same address
; #define PIA2_PortB_Control *(volatile unsigned char *)(0x00400066)
; /*********************************************************************************************************************************
; (( DO NOT initialise global variables here, do it main even if you want 0
; (( it's a limitation of the compiler
; (( YOU HAVE BEEN WARNED
; *********************************************************************************************************************************/
; unsigned int i, x, y, z, PortA_Count;
; unsigned char Timer1Count, Timer2Count, Timer3Count, Timer4Count ;
; /*******************************************************************************************
; ** Function Prototypes
; *******************************************************************************************/
; void Wait1ms(void);
; void Wait3ms(void);
; void Init_LCD(void) ;
; void LCDOutchar(int c);
; void LCDOutMess(char *theMessage);
; void LCDClearln(void);
; void LCDline1Message(char *theMessage);
; void LCDline2Message(char *theMessage);
; int sprintf(char *out, const char *format, ...) ;
; /*****************************************************************************************
; **	Interrupt service routine for Timers
; **
; **  Timers 1 - 4 share a common IRQ on the CPU  so this function uses polling to figure
; **  out which timer is producing the interrupt
; **
; *****************************************************************************************/
; void Timer_ISR()
; {
       section   code
       xdef      _Timer_ISR
_Timer_ISR:
; if(Timer1Status == 1) {         // Did Timer 1 produce the Interrupt?
       move.b    4194354,D0
       cmp.b     #1,D0
       bne.s     Timer_ISR_1
; Timer1Control = 3;      	// reset the timer to clear the interrupt, enable interrupts and allow counter to run
       move.b    #3,4194354
; PortA = Timer1Count++ ;     // increment an LED count on PortA with each tick of Timer 1
       move.b    _Timer1Count.L,D0
       addq.b    #1,_Timer1Count.L
       move.b    D0,4194304
Timer_ISR_1:
; }
; if(Timer2Status == 1) {         // Did Timer 2 produce the Interrupt?
       move.b    4194358,D0
       cmp.b     #1,D0
       bne.s     Timer_ISR_3
; Timer2Control = 3;      	// reset the timer to clear the interrupt, enable interrupts and allow counter to run
       move.b    #3,4194358
; PortC = Timer2Count++ ;     // increment an LED count on PortC with each tick of Timer 2
       move.b    _Timer2Count.L,D0
       addq.b    #1,_Timer2Count.L
       move.b    D0,4194308
Timer_ISR_3:
; }
; if(Timer3Status == 1) {         // Did Timer 3 produce the Interrupt?
       move.b    4194362,D0
       cmp.b     #1,D0
       bne.s     Timer_ISR_5
; Timer3Control = 3;      	// reset the timer to clear the interrupt, enable interrupts and allow counter to run
       move.b    #3,4194362
; HEX_A = Timer3Count++ ;     // increment a HEX count on Port HEX_A with each tick of Timer 3
       move.b    _Timer3Count.L,D0
       addq.b    #1,_Timer3Count.L
       move.b    D0,4194320
Timer_ISR_5:
; }
; if(Timer4Status == 1) {         // Did Timer 4 produce the Interrupt?
       move.b    4194366,D0
       cmp.b     #1,D0
       bne.s     Timer_ISR_7
; Timer4Control = 3;      	// reset the timer to clear the interrupt, enable interrupts and allow counter to run
       move.b    #3,4194366
; HEX_B = Timer4Count++ ;     // increment a HEX count on HEX_B with each tick of Timer 4
       move.b    _Timer4Count.L,D0
       addq.b    #1,_Timer4Count.L
       move.b    D0,4194322
Timer_ISR_7:
       rts
; }
; }
; /*****************************************************************************************
; **	Interrupt service routine for ACIA. This device has it's own dedicate IRQ level
; **  Add your code here to poll Status register and clear interrupt
; *****************************************************************************************/
; void ACIA_ISR()
; {}
       xdef      _ACIA_ISR
_ACIA_ISR:
       rts
; /***************************************************************************************
; **	Interrupt service routine for PIAs 1 and 2. These devices share an IRQ level
; **  Add your code here to poll Status register and clear interrupt
; *****************************************************************************************/
; void PIA_ISR()
; {}
       xdef      _PIA_ISR
_PIA_ISR:
       rts
; /***********************************************************************************
; **	Interrupt service routine for Key 2 on DE1 board. Add your own response here
; ************************************************************************************/
; void Key2PressISR()
; {}
       xdef      _Key2PressISR
_Key2PressISR:
       rts
; /***********************************************************************************
; **	Interrupt service routine for Key 1 on DE1 board. Add your own response here
; ************************************************************************************/
; void Key1PressISR()
; {}
       xdef      _Key1PressISR
_Key1PressISR:
       rts
; /************************************************************************************
; **   Delay Subroutine to give the 68000 something useless to do to waste 1 mSec
; ************************************************************************************/
; void Wait1ms(void)
; {
       xdef      _Wait1ms
_Wait1ms:
       move.l    D2,-(A7)
; int  i ;
; for(i = 0; i < 1000; i ++)
       clr.l     D2
Wait1ms_1:
       cmp.l     #1000,D2
       bge.s     Wait1ms_3
       addq.l    #1,D2
       bra       Wait1ms_1
Wait1ms_3:
       move.l    (A7)+,D2
       rts
; ;
; }
; /************************************************************************************
; **  Subroutine to give the 68000 something useless to do to waste 3 mSec
; **************************************************************************************/
; void Wait3ms(void)
; {
       xdef      _Wait3ms
_Wait3ms:
       move.l    D2,-(A7)
; int i ;
; for(i = 0; i < 3; i++)
       clr.l     D2
Wait3ms_1:
       cmp.l     #3,D2
       bge.s     Wait3ms_3
; Wait1ms() ;
       jsr       _Wait1ms
       addq.l    #1,D2
       bra       Wait3ms_1
Wait3ms_3:
       move.l    (A7)+,D2
       rts
; }
; /*********************************************************************************************
; **  Subroutine to initialise the LCD display by writing some commands to the LCD internal registers
; **  Sets it for parallel port and 2 line display mode (if I recall correctly)
; *********************************************************************************************/
; void Init_LCD(void)
; {
       xdef      _Init_LCD
_Init_LCD:
; LCDcommand = 0x0c ;
       move.b    #12,4194336
; Wait3ms() ;
       jsr       _Wait3ms
; LCDcommand = 0x38 ;
       move.b    #56,4194336
; Wait3ms() ;
       jsr       _Wait3ms
       rts
; }
; /*********************************************************************************************
; **  Subroutine to initialise the RS232 Port by writing some commands to the internal registers
; *********************************************************************************************/
; void Init_RS232(void)
; {
       xdef      _Init_RS232
_Init_RS232:
; RS232_Control = 0x15 ; //  %00010101 set up 6850 uses divide by 16 clock, set RTS low, 8 bits no parity, 1 stop bit, transmitter interrupt disabled
       move.b    #21,4194368
; RS232_Baud = 0x1 ;      // program baud rate generator 001 = 115k, 010 = 57.6k, 011 = 38.4k, 100 = 19.2, all others = 9600
       move.b    #1,4194372
       rts
; }
; /*********************************************************************************************************
; **  Subroutine to provide a low level output function to 6850 ACIA
; **  This routine provides the basic functionality to output a single character to the serial Port
; **  to allow the board to communicate with HyperTerminal Program
; **
; **  NOTE you do not call this function directly, instead you call the normal putchar() function
; **  which in turn calls _putch() below). Other functions like puts(), printf() call putchar() so will
; **  call _putch() also
; *********************************************************************************************************/
; int _putch( int c)
; {
       xdef      __putch
__putch:
       link      A6,#0
; while((RS232_Status & (char)(0x02)) != (char)(0x02))    // wait for Tx bit in status register or 6850 serial comms chip to be '1'
_putch_1:
       move.b    4194368,D0
       and.b     #2,D0
       cmp.b     #2,D0
       beq.s     _putch_3
       bra       _putch_1
_putch_3:
; ;
; RS232_TxData = (c & (char)(0x7f));                      // write to the data register to output the character (mask off bit 8 to keep it 7 bit ASCII)
       move.l    8(A6),D0
       and.l     #127,D0
       move.b    D0,4194370
; return c ;                                              // putchar() expects the character to be returned
       move.l    8(A6),D0
       unlk      A6
       rts
; }
; /*********************************************************************************************************
; **  Subroutine to provide a low level input function to 6850 ACIA
; **  This routine provides the basic functionality to input a single character from the serial Port
; **  to allow the board to communicate with HyperTerminal Program Keyboard (your PC)
; **
; **  NOTE you do not call this function directly, instead you call the normal getchar() function
; **  which in turn calls _getch() below). Other functions like gets(), scanf() call getchar() so will
; **  call _getch() also
; *********************************************************************************************************/
; int _getch( void )
; {
       xdef      __getch
__getch:
       link      A6,#-4
; char c ;
; while((RS232_Status & (char)(0x01)) != (char)(0x01))    // wait for Rx bit in 6850 serial comms chip status register to be '1'
_getch_1:
       move.b    4194368,D0
       and.b     #1,D0
       cmp.b     #1,D0
       beq.s     _getch_3
       bra       _getch_1
_getch_3:
; ;
; return (RS232_RxData & (char)(0x7f));                   // read received character, mask off top bit and return as 7 bit ASCII character
       move.b    4194370,D0
       and.l     #255,D0
       and.l     #127,D0
       unlk      A6
       rts
; }
; /******************************************************************************
; **  Subroutine to output a single character to the 2 row LCD display
; **  It is assumed the character is an ASCII code and it will be displayed at the
; **  current cursor position
; *******************************************************************************/
; void LCDOutchar(int c)
; {
       xdef      _LCDOutchar
_LCDOutchar:
       link      A6,#0
; LCDdata = (char)(c);
       move.l    8(A6),D0
       move.b    D0,4194338
; Wait1ms() ;
       jsr       _Wait1ms
       unlk      A6
       rts
; }
; /**********************************************************************************
; *subroutine to output a message at the current cursor position of the LCD display
; ************************************************************************************/
; void LCDOutMessage(char *theMessage)
; {
       xdef      _LCDOutMessage
_LCDOutMessage:
       link      A6,#-4
; char c ;
; while((c = *theMessage++) != 0)     // output characters from the string until NULL
LCDOutMessage_1:
       move.l    8(A6),A0
       addq.l    #1,8(A6)
       move.b    (A0),-1(A6)
       move.b    (A0),D0
       beq.s     LCDOutMessage_3
; LCDOutchar(c) ;
       move.b    -1(A6),D1
       ext.w     D1
       ext.l     D1
       move.l    D1,-(A7)
       jsr       _LCDOutchar
       addq.w    #4,A7
       bra       LCDOutMessage_1
LCDOutMessage_3:
       unlk      A6
       rts
; }
; /******************************************************************************
; *subroutine to clear the line by issuing 24 space characters
; *******************************************************************************/
; void LCDClearln(void)
; {
       xdef      _LCDClearln
_LCDClearln:
       move.l    D2,-(A7)
; int i ;
; for(i = 0; i < 24; i ++)
       clr.l     D2
LCDClearln_1:
       cmp.l     #24,D2
       bge.s     LCDClearln_3
; LCDOutchar(' ') ;       // write a space char to the LCD display
       pea       32
       jsr       _LCDOutchar
       addq.w    #4,A7
       addq.l    #1,D2
       bra       LCDClearln_1
LCDClearln_3:
       move.l    (A7)+,D2
       rts
; }
; /******************************************************************************
; **  Subroutine to move the LCD cursor to the start of line 1 and clear that line
; *******************************************************************************/
; void LCDLine1Message(char *theMessage)
; {
       xdef      _LCDLine1Message
_LCDLine1Message:
       link      A6,#0
; LCDcommand = 0x80 ;
       move.b    #128,4194336
; Wait3ms();
       jsr       _Wait3ms
; LCDClearln() ;
       jsr       _LCDClearln
; LCDcommand = 0x80 ;
       move.b    #128,4194336
; Wait3ms() ;
       jsr       _Wait3ms
; LCDOutMessage(theMessage) ;
       move.l    8(A6),-(A7)
       jsr       _LCDOutMessage
       addq.w    #4,A7
       unlk      A6
       rts
; }
; /******************************************************************************
; **  Subroutine to move the LCD cursor to the start of line 2 and clear that line
; *******************************************************************************/
; void LCDLine2Message(char *theMessage)
; {
       xdef      _LCDLine2Message
_LCDLine2Message:
       link      A6,#0
; LCDcommand = 0xC0 ;
       move.b    #192,4194336
; Wait3ms();
       jsr       _Wait3ms
; LCDClearln() ;
       jsr       _LCDClearln
; LCDcommand = 0xC0 ;
       move.b    #192,4194336
; Wait3ms() ;
       jsr       _Wait3ms
; LCDOutMessage(theMessage) ;
       move.l    8(A6),-(A7)
       jsr       _LCDOutMessage
       addq.w    #4,A7
       unlk      A6
       rts
; }
; /*********************************************************************************************************************************
; **  IMPORTANT FUNCTION
; **  This function install an exception handler so you can capture and deal with any 68000 exception in your program
; **  You pass it the name of a function in your code that will get called in response to the exception (as the 1st parameter)
; **  and in the 2nd parameter, you pass it the exception number that you want to take over (see 68000 exceptions for details)
; **  Calling this function allows you to deal with Interrupts for example
; ***********************************************************************************************************************************/
; void InstallExceptionHandler( void (*function_ptr)(), int level)
; {
       xdef      _InstallExceptionHandler
_InstallExceptionHandler:
       link      A6,#-4
; volatile long int *RamVectorAddress = (volatile long int *)(StartOfExceptionVectorTable) ;   // pointer to the Ram based interrupt vector table created in Cstart in debug monitor
       move.l    #134414336,-4(A6)
; RamVectorAddress[level] = (long int *)(function_ptr);                       // install the address of our function into the exception table
       move.l    -4(A6),A0
       move.l    12(A6),D0
       lsl.l     #2,D0
       move.l    8(A6),0(A0,D0.L)
       unlk      A6
       rts
; }
; /******************************************************************************************************************************
; * Start of user program
; ******************************************************************************************************************************/
; void main()
; {
       xdef      _main
_main:
       link      A6,#-200
       movem.l   D2/D3/D4/D5/A2/A3/A4/A5,-(A7)
       lea       _printf.L,A2
       lea       _scanf.L,A3
       lea       _InstallExceptionHandler.L,A4
       lea       -24(A6),A5
; unsigned int row, i=0, count=0, counter1=1;
       clr.l     -196(A6)
       clr.l     -192(A6)
       move.l    #1,-188(A6)
; char c, text[150];
; unsigned int *new_address=0;
       clr.l     -32(A6)
; unsigned int Start=0;
       clr.l     -28(A6)
; unsigned int End=0;
       clr.l     (A5)
; int PassFailFlag = 1 ;
       move.l    #1,-20(A6)
; int test=0;
       clr.l     -16(A6)
; int data_b,data_l,data_w;
; unsigned char *ptr_b =0x08020000;
       move.l    #134348800,D5
; unsigned char *ptr_w= 0x08020000;
       move.l    #134348800,D4
; unsigned char *ptr_l= 0x08020000;
       move.l    #134348800,D2
; unsigned int data;
; i = x = y = z = PortA_Count =0;
       clr.l     _PortA_Count.L
       clr.l     _z.L
       clr.l     _y.L
       clr.l     _x.L
       clr.l     -196(A6)
; Timer1Count = Timer2Count = Timer3Count = Timer4Count = 0;
       clr.b     _Timer4Count.L
       clr.b     _Timer3Count.L
       clr.b     _Timer2Count.L
       clr.b     _Timer1Count.L
; InstallExceptionHandler(PIA_ISR, 25) ;          // install interrupt handler for PIAs 1 and 2 on level 1 IRQ
       pea       25
       pea       _PIA_ISR.L
       jsr       (A4)
       addq.w    #8,A7
; InstallExceptionHandler(ACIA_ISR, 26) ;		    // install interrupt handler for ACIA on level 2 IRQ
       pea       26
       pea       _ACIA_ISR.L
       jsr       (A4)
       addq.w    #8,A7
; InstallExceptionHandler(Timer_ISR, 27) ;		// install interrupt handler for Timers 1-4 on level 3 IRQ
       pea       27
       pea       _Timer_ISR.L
       jsr       (A4)
       addq.w    #8,A7
; InstallExceptionHandler(Key2PressISR, 28) ;	    // install interrupt handler for Key Press 2 on DE1 board for level 4 IRQ
       pea       28
       pea       _Key2PressISR.L
       jsr       (A4)
       addq.w    #8,A7
; InstallExceptionHandler(Key1PressISR, 29) ;	    // install interrupt handler for Key Press 1 on DE1 board for level 5 IRQ
       pea       29
       pea       _Key1PressISR.L
       jsr       (A4)
       addq.w    #8,A7
; Timer1Data = 0x10;		// program time delay into timers 1-4
       move.b    #16,4194352
; Timer2Data = 0x20;
       move.b    #32,4194356
; Timer3Data = 0x15;
       move.b    #21,4194360
; Timer4Data = 0x25;
       move.b    #37,4194364
; Timer1Control = 3;		// write 3 to control register to Bit0 = 1 (enable interrupt from timers) 1 - 4 and allow them to count Bit 1 = 1
       move.b    #3,4194354
; Timer2Control = 3;
       move.b    #3,4194358
; Timer3Control = 3;
       move.b    #3,4194362
; Timer4Control = 3;
       move.b    #3,4194366
; Init_LCD();             // initialise the LCD display to use a parallel data interface and 2 lines of display
       jsr       _Init_LCD
; Init_RS232() ;          // initialise the RS232 port for use with hyper terminal
       jsr       _Init_RS232
; /*************************************************************************************************
; **  Test of scanf function
; *************************************************************************************************/
; scanflush() ;                       // flush any text that may have been typed ahead
       jsr       _scanflush
; //printf("\r\nEnter Integer,: ") ;
; //scanf("%d", &i) ;
; //printf("You entered %d", i) ;
; //sprintf(text, "Hello CPEN 412 Student") ; //Not needed
; //LCDLine1Message(text) ;
; //printf("\r\nHello CPEN 412 Student\r\nYour LEDs should be Flashing") ;
; //printf("\r\nYour LCD should be displaying") ;
; //MY CODE
; printf("\r \n Let's write to a memory.");
       pea       @m68kus~1_1.L
       jsr       (A2)
       addq.w    #4,A7
; printf(" \r\nEnter 8 for bytes, enter 16 for words, or enter 32 for long words: ");
       pea       @m68kus~1_2.L
       jsr       (A2)
       addq.w    #4,A7
; scanf("%d",&test);
       pea       -16(A6)
       pea       @m68kus~1_3.L
       jsr       (A3)
       addq.w    #8,A7
; // BYTE TEST
; if(test==8) {
       move.l    -16(A6),D0
       cmp.l     #8,D0
       bne       main_1
; printf("\r \n 0x55, 0xAA, 0xFF, 0x00 \n ");
       pea       @m68kus~1_4.L
       jsr       (A2)
       addq.w    #4,A7
; printf("\r Choose one of them (0,1,2,3):");
       pea       @m68kus~1_5.L
       jsr       (A2)
       addq.w    #4,A7
; scanf("%d",&data_b);
       pea       -12(A6)
       pea       @m68kus~1_3.L
       jsr       (A3)
       addq.w    #8,A7
; if(data_b==0) data=0x55;
       move.l    -12(A6),D0
       bne.s     main_3
       moveq     #85,D3
       bra.s     main_8
main_3:
; else if(data_b==1)data=0xAA;
       move.l    -12(A6),D0
       cmp.l     #1,D0
       bne.s     main_5
       move.l    #170,D3
       bra.s     main_8
main_5:
; else if(data_b==2) data=0xFF;
       move.l    -12(A6),D0
       cmp.l     #2,D0
       bne.s     main_7
       move.l    #255,D3
       bra.s     main_8
main_7:
; else              data=0x00;
       clr.l     D3
main_8:
; printf("\r \n You chose %x",data);
       move.l    D3,-(A7)
       pea       @m68kus~1_6.L
       jsr       (A2)
       addq.w    #8,A7
; printf("\r \n Enter a start address (EVEN): ");  //BYTE
       pea       @m68kus~1_7.L
       jsr       (A2)
       addq.w    #4,A7
; scanf("%d",&Start);
       pea       -28(A6)
       pea       @m68kus~1_3.L
       jsr       (A3)
       addq.w    #8,A7
; if(Start%2 ==0){
       move.l    -28(A6),-(A7)
       pea       2
       jsr       ULDIV
       move.l    4(A7),D0
       addq.w    #8,A7
       tst.l     D0
       bne       main_9
; *(ptr_b+Start)=data; // At this starting address we store this.
       move.l    D5,A0
       move.l    -28(A6),D0
       move.b    D3,0(A0,D0.L)
; printf("\r \n Start address is : %x data is: %x ",ptr_b+Start, *(ptr_b+Start));
       move.l    D5,A0
       move.l    -28(A6),D1
       move.b    0(A0,D1.L),D1
       and.l     #255,D1
       move.l    D1,-(A7)
       move.l    D5,D1
       add.l     -28(A6),D1
       move.l    D1,-(A7)
       pea       @m68kus~1_8.L
       jsr       (A2)
       add.w     #12,A7
; printf("\r \n Enter a finish address(EVEN): ");
       pea       @m68kus~1_9.L
       jsr       (A2)
       addq.w    #4,A7
; scanf("%d",&End);
       move.l    A5,-(A7)
       pea       @m68kus~1_3.L
       jsr       (A3)
       addq.w    #8,A7
; if(Start%2 ==0){
       move.l    -28(A6),-(A7)
       pea       2
       jsr       ULDIV
       move.l    4(A7),D0
       addq.w    #8,A7
       tst.l     D0
       bne       main_11
; *(ptr_b+End)=*(ptr_b+Start); //copy the value in the start addres
       move.l    D5,A0
       move.l    -28(A6),D0
       move.l    D5,A1
       move.l    (A5),D1
       move.b    0(A0,D0.L),0(A1,D1.L)
; printf("\r \n End address is : %x data is: %x",ptr_b+End, *(ptr_b+End));
       move.l    D5,A0
       move.l    (A5),D1
       move.b    0(A0,D1.L),D1
       and.l     #255,D1
       move.l    D1,-(A7)
       move.l    D5,D1
       add.l     (A5),D1
       move.l    D1,-(A7)
       pea       @m68kus~1_10.L
       jsr       (A2)
       add.w     #12,A7
       bra.s     main_12
main_11:
; } else
; printf ("Not even address.");
       pea       @m68kus~1_11.L
       jsr       (A2)
       addq.w    #4,A7
main_12:
       bra.s     main_10
main_9:
; }  else
; printf ("Not even address.");
       pea       @m68kus~1_11.L
       jsr       (A2)
       addq.w    #4,A7
main_10:
       bra       main_26
main_1:
; } //WORD TEST
; else if(test==16) {
       move.l    -16(A6),D0
       cmp.l     #16,D0
       bne       main_13
; printf("\r \n 0x5555, 0xAAAA, 0xFFFF, 0x0000");
       pea       @m68kus~1_12.L
       jsr       (A2)
       addq.w    #4,A7
; printf("\r \n Choose one of them (0,1,2,3):");
       pea       @m68kus~1_13.L
       jsr       (A2)
       addq.w    #4,A7
; scanf("%d",&data_w);
       pea       -4(A6)
       pea       @m68kus~1_3.L
       jsr       (A3)
       addq.w    #8,A7
; if(data_w==0)     data=0x5555;
       move.l    -4(A6),D0
       bne.s     main_15
       move.l    #21845,D3
       bra.s     main_20
main_15:
; else if(data_w==1)data=0xAAAA;
       move.l    -4(A6),D0
       cmp.l     #1,D0
       bne.s     main_17
       move.l    #43690,D3
       bra.s     main_20
main_17:
; else if(data_w==2)data=0xFFFF;
       move.l    -4(A6),D0
       cmp.l     #2,D0
       bne.s     main_19
       move.l    #65535,D3
       bra.s     main_20
main_19:
; else              data=0x0000;
       clr.l     D3
main_20:
; printf("\r \n You chose %x",data);
       move.l    D3,-(A7)
       pea       @m68kus~1_6.L
       jsr       (A2)
       addq.w    #8,A7
; printf("\r \n Enter a start address (EVEN): ");
       pea       @m68kus~1_7.L
       jsr       (A2)
       addq.w    #4,A7
; scanf("%d",&Start);
       pea       -28(A6)
       pea       @m68kus~1_3.L
       jsr       (A3)
       addq.w    #8,A7
; if(Start%2 ==0){
       move.l    -28(A6),-(A7)
       pea       2
       jsr       ULDIV
       move.l    4(A7),D0
       addq.w    #8,A7
       tst.l     D0
       bne       main_21
; *(ptr_w+Start)=data&0xFF;  // first bytes
       move.l    D3,D0
       and.l     #255,D0
       move.l    D4,A0
       move.l    -28(A6),D1
       move.b    D0,0(A0,D1.L)
; *(ptr_w+Start+1)=(data>>8)&0xFF; //second byte
       move.l    D3,D0
       lsr.l     #8,D0
       and.l     #255,D0
       move.l    D4,A0
       move.l    -28(A6),D1
       add.l     D1,A0
       move.b    D0,1(A0)
; printf("\r \n Starting addresses are : %x , %x datas stored in these addresses are: %x , %x",ptr_w+Start,ptr_w+Start+1,*(ptr_w+Start),*(ptr_w+Start+1));
       move.l    D4,A0
       move.l    -28(A6),D1
       add.l     D1,A0
       move.b    1(A0),D1
       and.l     #255,D1
       move.l    D1,-(A7)
       move.l    D4,A0
       move.l    -28(A6),D1
       move.b    0(A0,D1.L),D1
       and.l     #255,D1
       move.l    D1,-(A7)
       move.l    D4,D1
       add.l     -28(A6),D1
       addq.l    #1,D1
       move.l    D1,-(A7)
       move.l    D4,D1
       add.l     -28(A6),D1
       move.l    D1,-(A7)
       pea       @m68kus~1_14.L
       jsr       (A2)
       add.w     #20,A7
; printf("\r \n Enter a finish address(EVEN): ");
       pea       @m68kus~1_9.L
       jsr       (A2)
       addq.w    #4,A7
; scanf("%d",&End);
       move.l    A5,-(A7)
       pea       @m68kus~1_3.L
       jsr       (A3)
       addq.w    #8,A7
; if(End%2 ==0){
       move.l    (A5),-(A7)
       pea       2
       jsr       ULDIV
       move.l    4(A7),D0
       addq.w    #8,A7
       tst.l     D0
       bne       main_23
; *(ptr_w+End)=*(ptr_w+Start);  // first bytes
       move.l    D4,A0
       move.l    -28(A6),D0
       move.l    D4,A1
       move.l    (A5),D1
       move.b    0(A0,D0.L),0(A1,D1.L)
; *(ptr_w+End+1)=*(ptr_w+Start+1); //second byte
       move.l    D4,A0
       move.l    -28(A6),D0
       add.l     D0,A0
       move.l    D4,A1
       move.l    (A5),D0
       add.l     D0,A1
       move.b    1(A0),1(A1)
; printf("\r \n End addresses are : %x , %x datas stored in these addresses are: %x , %x",ptr_w+End,ptr_w+End+1,*(ptr_w+End),*(ptr_w+End+1));
       move.l    D4,A0
       move.l    (A5),D1
       add.l     D1,A0
       move.b    1(A0),D1
       and.l     #255,D1
       move.l    D1,-(A7)
       move.l    D4,A0
       move.l    (A5),D1
       move.b    0(A0,D1.L),D1
       and.l     #255,D1
       move.l    D1,-(A7)
       move.l    D4,D1
       add.l     (A5),D1
       addq.l    #1,D1
       move.l    D1,-(A7)
       move.l    D4,D1
       add.l     (A5),D1
       move.l    D1,-(A7)
       pea       @m68kus~1_15.L
       jsr       (A2)
       add.w     #20,A7
       bra.s     main_24
main_23:
; } else
; printf ("Not even address.");
       pea       @m68kus~1_11.L
       jsr       (A2)
       addq.w    #4,A7
main_24:
       bra.s     main_22
main_21:
; }  else
; printf ("Not even address.");
       pea       @m68kus~1_11.L
       jsr       (A2)
       addq.w    #4,A7
main_22:
       bra       main_26
main_13:
; }
; // LONG WORD TEST
; else if (test==32){
       move.l    -16(A6),D0
       cmp.l     #32,D0
       bne       main_25
; printf("\r \n55555555, AAAAAAAAA, FFFFFFFF, 00000000 \n");
       pea       @m68kus~1_16.L
       jsr       (A2)
       addq.w    #4,A7
; printf("\r Choose one of them (0,1,2,3):");
       pea       @m68kus~1_5.L
       jsr       (A2)
       addq.w    #4,A7
; scanf("%d",&data_l);
       pea       -8(A6)
       pea       @m68kus~1_3.L
       jsr       (A3)
       addq.w    #8,A7
; if(data_l==0)      data=0x55555555;
       move.l    -8(A6),D0
       bne.s     main_27
       move.l    #1431655765,D3
       bra.s     main_32
main_27:
; else if(data_l==1) data=0xAAAAAAAA;
       move.l    -8(A6),D0
       cmp.l     #1,D0
       bne.s     main_29
       move.l    #-1431655766,D3
       bra.s     main_32
main_29:
; else if(data_l==2) data=0xFFFFFFFF;
       move.l    -8(A6),D0
       cmp.l     #2,D0
       bne.s     main_31
       moveq     #-1,D3
       bra.s     main_32
main_31:
; else               data=0x00000000;
       clr.l     D3
main_32:
; printf("\r \n You chose %x",data);
       move.l    D3,-(A7)
       pea       @m68kus~1_6.L
       jsr       (A2)
       addq.w    #8,A7
; printf("\r \n Enter a start address (EVEN): ");
       pea       @m68kus~1_7.L
       jsr       (A2)
       addq.w    #4,A7
; scanf("%d",&Start);
       pea       -28(A6)
       pea       @m68kus~1_3.L
       jsr       (A3)
       addq.w    #8,A7
; if(Start%2 ==0){
       move.l    -28(A6),-(A7)
       pea       2
       jsr       ULDIV
       move.l    4(A7),D0
       addq.w    #8,A7
       tst.l     D0
       bne       main_33
; *(ptr_l+Start)=data&0xFF;  // first bytes
       move.l    D3,D0
       and.l     #255,D0
       move.l    D2,A0
       move.l    -28(A6),D1
       move.b    D0,0(A0,D1.L)
; *(ptr_l+Start+1)=(data>>8)&0xFF; //second byte
       move.l    D3,D0
       lsr.l     #8,D0
       and.l     #255,D0
       move.l    D2,A0
       move.l    -28(A6),D1
       add.l     D1,A0
       move.b    D0,1(A0)
; *(ptr_l+Start + 2)=data>>16; //third byte
       move.l    D3,D0
       lsr.l     #8,D0
       lsr.l     #8,D0
       move.l    D2,A0
       move.l    -28(A6),D1
       add.l     D1,A0
       move.b    D0,2(A0)
; *(ptr_l+Start + 3)=data>>24; //fourth byte
       move.l    D3,D0
       lsr.l     #8,D0
       lsr.l     #8,D0
       lsr.l     #8,D0
       move.l    D2,A0
       move.l    -28(A6),D1
       add.l     D1,A0
       move.b    D0,3(A0)
; printf("\r \n Starting addresses are : %x , %x , %x , %x ",ptr_l+Start,ptr_l+Start+1,ptr_l+Start+2,ptr_l+Start+3);
       move.l    D2,D1
       add.l     -28(A6),D1
       addq.l    #3,D1
       move.l    D1,-(A7)
       move.l    D2,D1
       add.l     -28(A6),D1
       addq.l    #2,D1
       move.l    D1,-(A7)
       move.l    D2,D1
       add.l     -28(A6),D1
       addq.l    #1,D1
       move.l    D1,-(A7)
       move.l    D2,D1
       add.l     -28(A6),D1
       move.l    D1,-(A7)
       pea       @m68kus~1_17.L
       jsr       (A2)
       add.w     #20,A7
; printf("\r \n Datas are: %x , %x , %x , %x  ",  *(ptr_l+Start),  *(ptr_l+Start+1),  *(ptr_l+Start+2),    *(ptr_l+Start+3));
       move.l    D2,A0
       move.l    -28(A6),D1
       add.l     D1,A0
       move.b    3(A0),D1
       and.l     #255,D1
       move.l    D1,-(A7)
       move.l    D2,A0
       move.l    -28(A6),D1
       add.l     D1,A0
       move.b    2(A0),D1
       and.l     #255,D1
       move.l    D1,-(A7)
       move.l    D2,A0
       move.l    -28(A6),D1
       add.l     D1,A0
       move.b    1(A0),D1
       and.l     #255,D1
       move.l    D1,-(A7)
       move.l    D2,A0
       move.l    -28(A6),D1
       move.b    0(A0,D1.L),D1
       and.l     #255,D1
       move.l    D1,-(A7)
       pea       @m68kus~1_18.L
       jsr       (A2)
       add.w     #20,A7
; printf("\r \n Enter a finish address(EVEN): ");
       pea       @m68kus~1_9.L
       jsr       (A2)
       addq.w    #4,A7
; scanf("%d",&End);
       move.l    A5,-(A7)
       pea       @m68kus~1_3.L
       jsr       (A3)
       addq.w    #8,A7
; if(End%2 ==0){
       move.l    (A5),-(A7)
       pea       2
       jsr       ULDIV
       move.l    4(A7),D0
       addq.w    #8,A7
       tst.l     D0
       bne       main_35
; *(ptr_l+End)=*(ptr_l+Start);  // first bytes
       move.l    D2,A0
       move.l    -28(A6),D0
       move.l    D2,A1
       move.l    (A5),D1
       move.b    0(A0,D0.L),0(A1,D1.L)
; *(ptr_l+End+1)=*(ptr_l+Start+1); //second byte
       move.l    D2,A0
       move.l    -28(A6),D0
       add.l     D0,A0
       move.l    D2,A1
       move.l    (A5),D0
       add.l     D0,A1
       move.b    1(A0),1(A1)
; *(ptr_l+End+2)=*(ptr_l+Start+2); //second byte
       move.l    D2,A0
       move.l    -28(A6),D0
       add.l     D0,A0
       move.l    D2,A1
       move.l    (A5),D0
       add.l     D0,A1
       move.b    2(A0),2(A1)
; *(ptr_l+End+3)=*(ptr_l+Start+3); //second byte
       move.l    D2,A0
       move.l    -28(A6),D0
       add.l     D0,A0
       move.l    D2,A1
       move.l    (A5),D0
       add.l     D0,A1
       move.b    3(A0),3(A1)
; printf("\r \n Finishing addresses are : %x , %x , %x , %x ",ptr_l+End,ptr_l+End+1,ptr_l+End+2,ptr_l+End+3);
       move.l    D2,D1
       add.l     (A5),D1
       addq.l    #3,D1
       move.l    D1,-(A7)
       move.l    D2,D1
       add.l     (A5),D1
       addq.l    #2,D1
       move.l    D1,-(A7)
       move.l    D2,D1
       add.l     (A5),D1
       addq.l    #1,D1
       move.l    D1,-(A7)
       move.l    D2,D1
       add.l     (A5),D1
       move.l    D1,-(A7)
       pea       @m68kus~1_19.L
       jsr       (A2)
       add.w     #20,A7
; printf("\r \n Datas are: %x , %x , %x , %x  ",  *(ptr_l+End),  *(ptr_l+End+1),  *(ptr_l+End+2),    *(ptr_l+End+3));
       move.l    D2,A0
       move.l    (A5),D1
       add.l     D1,A0
       move.b    3(A0),D1
       and.l     #255,D1
       move.l    D1,-(A7)
       move.l    D2,A0
       move.l    (A5),D1
       add.l     D1,A0
       move.b    2(A0),D1
       and.l     #255,D1
       move.l    D1,-(A7)
       move.l    D2,A0
       move.l    (A5),D1
       add.l     D1,A0
       move.b    1(A0),D1
       and.l     #255,D1
       move.l    D1,-(A7)
       move.l    D2,A0
       move.l    (A5),D1
       move.b    0(A0,D1.L),D1
       and.l     #255,D1
       move.l    D1,-(A7)
       pea       @m68kus~1_18.L
       jsr       (A2)
       add.w     #20,A7
       bra.s     main_36
main_35:
; }
; else printf ("Not even address.");
       pea       @m68kus~1_11.L
       jsr       (A2)
       addq.w    #4,A7
main_36:
       bra.s     main_34
main_33:
; }
; else printf ("Not even address.");
       pea       @m68kus~1_11.L
       jsr       (A2)
       addq.w    #4,A7
main_34:
       bra.s     main_26
main_25:
; }
; else
; printf("Invalid");
       pea       @m68kus~1_20.L
       jsr       (A2)
       addq.w    #4,A7
main_26:
; while(1){
main_37:
; };
       bra       main_37
; // programs should NOT exit as there is nothing to Exit TO !!!!!!
; // There is no OS - just press the reset button to end program and call debug
; }
       section   const
@m68kus~1_1:
       dc.b      13,32,10,32,76,101,116,39,115,32,119,114,105
       dc.b      116,101,32,116,111,32,97,32,109,101,109,111
       dc.b      114,121,46,0
@m68kus~1_2:
       dc.b      32,13,10,69,110,116,101,114,32,56,32,102,111
       dc.b      114,32,98,121,116,101,115,44,32,101,110,116
       dc.b      101,114,32,49,54,32,102,111,114,32,119,111,114
       dc.b      100,115,44,32,111,114,32,101,110,116,101,114
       dc.b      32,51,50,32,102,111,114,32,108,111,110,103,32
       dc.b      119,111,114,100,115,58,32,0
@m68kus~1_3:
       dc.b      37,100,0
@m68kus~1_4:
       dc.b      13,32,10,32,48,120,53,53,44,32,48,120,65,65
       dc.b      44,32,48,120,70,70,44,32,48,120,48,48,32,10
       dc.b      32,0
@m68kus~1_5:
       dc.b      13,32,67,104,111,111,115,101,32,111,110,101
       dc.b      32,111,102,32,116,104,101,109,32,40,48,44,49
       dc.b      44,50,44,51,41,58,0
@m68kus~1_6:
       dc.b      13,32,10,32,89,111,117,32,99,104,111,115,101
       dc.b      32,37,120,0
@m68kus~1_7:
       dc.b      13,32,10,32,69,110,116,101,114,32,97,32,115
       dc.b      116,97,114,116,32,97,100,100,114,101,115,115
       dc.b      32,40,69,86,69,78,41,58,32,0
@m68kus~1_8:
       dc.b      13,32,10,32,83,116,97,114,116,32,97,100,100
       dc.b      114,101,115,115,32,105,115,32,58,32,37,120,32
       dc.b      100,97,116,97,32,105,115,58,32,37,120,32,0
@m68kus~1_9:
       dc.b      13,32,10,32,69,110,116,101,114,32,97,32,102
       dc.b      105,110,105,115,104,32,97,100,100,114,101,115
       dc.b      115,40,69,86,69,78,41,58,32,0
@m68kus~1_10:
       dc.b      13,32,10,32,69,110,100,32,97,100,100,114,101
       dc.b      115,115,32,105,115,32,58,32,37,120,32,100,97
       dc.b      116,97,32,105,115,58,32,37,120,0
@m68kus~1_11:
       dc.b      78,111,116,32,101,118,101,110,32,97,100,100
       dc.b      114,101,115,115,46,0
@m68kus~1_12:
       dc.b      13,32,10,32,48,120,53,53,53,53,44,32,48,120
       dc.b      65,65,65,65,44,32,48,120,70,70,70,70,44,32,48
       dc.b      120,48,48,48,48,0
@m68kus~1_13:
       dc.b      13,32,10,32,67,104,111,111,115,101,32,111,110
       dc.b      101,32,111,102,32,116,104,101,109,32,40,48,44
       dc.b      49,44,50,44,51,41,58,0
@m68kus~1_14:
       dc.b      13,32,10,32,83,116,97,114,116,105,110,103,32
       dc.b      97,100,100,114,101,115,115,101,115,32,97,114
       dc.b      101,32,58,32,37,120,32,44,32,37,120,32,100,97
       dc.b      116,97,115,32,115,116,111,114,101,100,32,105
       dc.b      110,32,116,104,101,115,101,32,97,100,100,114
       dc.b      101,115,115,101,115,32,97,114,101,58,32,37,120
       dc.b      32,44,32,37,120,0
@m68kus~1_15:
       dc.b      13,32,10,32,69,110,100,32,97,100,100,114,101
       dc.b      115,115,101,115,32,97,114,101,32,58,32,37,120
       dc.b      32,44,32,37,120,32,100,97,116,97,115,32,115
       dc.b      116,111,114,101,100,32,105,110,32,116,104,101
       dc.b      115,101,32,97,100,100,114,101,115,115,101,115
       dc.b      32,97,114,101,58,32,37,120,32,44,32,37,120,0
@m68kus~1_16:
       dc.b      13,32,10,53,53,53,53,53,53,53,53,44,32,65,65
       dc.b      65,65,65,65,65,65,65,44,32,70,70,70,70,70,70
       dc.b      70,70,44,32,48,48,48,48,48,48,48,48,32,10,0
@m68kus~1_17:
       dc.b      13,32,10,32,83,116,97,114,116,105,110,103,32
       dc.b      97,100,100,114,101,115,115,101,115,32,97,114
       dc.b      101,32,58,32,37,120,32,44,32,37,120,32,44,32
       dc.b      37,120,32,44,32,37,120,32,0
@m68kus~1_18:
       dc.b      13,32,10,32,68,97,116,97,115,32,97,114,101,58
       dc.b      32,37,120,32,44,32,37,120,32,44,32,37,120,32
       dc.b      44,32,37,120,32,32,0
@m68kus~1_19:
       dc.b      13,32,10,32,70,105,110,105,115,104,105,110,103
       dc.b      32,97,100,100,114,101,115,115,101,115,32,97
       dc.b      114,101,32,58,32,37,120,32,44,32,37,120,32,44
       dc.b      32,37,120,32,44,32,37,120,32,0
@m68kus~1_20:
       dc.b      73,110,118,97,108,105,100,0
       section   bss
       xdef      _i
_i:
       ds.b      4
       xdef      _x
_x:
       ds.b      4
       xdef      _y
_y:
       ds.b      4
       xdef      _z
_z:
       ds.b      4
       xdef      _PortA_Count
_PortA_Count:
       ds.b      4
       xdef      _Timer1Count
_Timer1Count:
       ds.b      1
       xdef      _Timer2Count
_Timer2Count:
       ds.b      1
       xdef      _Timer3Count
_Timer3Count:
       ds.b      1
       xdef      _Timer4Count
_Timer4Count:
       ds.b      1
       xref      _scanf
       xref      ULDIV
       xref      _scanflush
       xref      _printf
