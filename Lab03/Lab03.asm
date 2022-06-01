; ----------------------------------------
; Lab 3 - Pseudo-instructions
; Version 2.5.4
; Date: October 11, 2018
; Written By : Socheath Sok
; Lab Hours  : T/TH, 3 pm to 4:15 pm


	.INCLUDE <m328pdef.inc>
	
	.DSEG
	 room:  .BYTE   1       
	 dir:   .BYTE   1
	 turn:	.BYTE 	1

	.CSEG
	.ORG 0x0000
	RST_VECT:
    rjmp reset                 // jump over IVT, plus INCLUDE code
	.ORG 0x0100                // bypass IVT
	.INCLUDE "spi_shield.inc"
	.INCLUDE "testbench.inc"   // DrawRoom and DrawDirection

reset:
	ldi   r17,HIGH(RAMEND)     // Initializes Stack Pointer to RAMEND address 0x08ff
	out   SPH,r17              // Outputs 0x08 to SPH
	ldi   r16,LOW(RAMEND)
	out   SPL,r16              // Outputs 0xFF to SPL

	call  InitShield           // initialize GPIO Ports and SPI communications
	clr   spiLEDS              // clear discrete LEDs
	clr   spi7SEG              // clear 7-segment display

;Initialize SRM Variables	
	clr   r17                  // initalizes r17 to 0 and then stores data from r17 into variable room
	sts   room, r17
	ldi   r17, 0x03            // loads the hex number 3 into r17 and then stores that value into variable dir
	sts   dir, r17
	ldi	  r17, 0x00
	sts   turn, r17

loop:

	call    ReadSwitches       // read switches into r6
	
    // dir  = switch & 0x03;
	mov     r17, switch        // move switch (r6) to temporary register r17
    cbr     r17, 0xFC          // mask-out most significant 6 bits
    sts     dir, r17           // save formatted value to SRAM variable dir.

	/* Read Switches and update room and direction */
    // room = switch >> 4;   
	mov     r17, switch        // move switch (r6) to temp register r17
	cbr     r17, 0x0F          // mask-out least significant nibble 
    swap    r17                // swap nibbles
    sts     room, r17          // save formatted value to SRAM variable room.

    /* Draw Direction */
	lds     r24, dir           // calling argument dir is placed in r24.
	rcall   DrawDirection      // translate direction to 7 segment bit
	mov     spi7SEG, r24	   // Displays DrawDirection on the 7 segment display.
    call    WriteDisplay

    /* Room Builder */
	lds     r24, room          // calling argument room is placed in r24.
	rcall   DrawRoom		   // translate room to 7-seg bits
	mov     spi7SEG, r24       // return value, the room, is saved to 7 segment display register
	call    WriteDisplay       // display the room
	
	/* Turn */
	mov r17, switch
	lsr r17
	lsr r17
	cbr r17,0xFC
	sts turn,r17

	; Direction Finder
	lds r24, dir // load direction bear is facing into r24
	lds r22, turn // load direction bear is to turn into r22
	rcall WhichWay // change direction based on variable turn
	sts dir, r24 // save formatted value to SRAM variable dir.

	rcall TestHitwall
	rcall TestLeftPaw
	rcall TestRightPaw

	rjmp   loop

TurnLeft:
 	push r16

 	mov r16,r24	//use r24 as input
	 clr r24		//use r24 as output

 	bst r16,0		//store y bit 0 into T
 	bld r24,1		//load directive 1 from T

 	com r16		//store /x into T
 	bst r16,1
 	bld r24,0		//load directive 0 from T

 	pop r16

 	ret

TurnRight:
	 push r16

	 mov r16,r24	//use r24 as input
	 clr r24		//use r24 as output

	 bst r16,1		//store x bit 0 bit into T 
	 bld r24,0		//load directive 0 from T

	 com r16		//store /y into T bit
	 bst r16,0
	 bld r24,1		//load directive 1 from T

	 pop r16
	 ret

TurnAround:
	 com r24		
	 cbr r24,0xFC

	 ret
 
WhichWay:

	bst r22,1		//store bit 1 into SREG T bit
	brts cond_1x    //branch if T is set
	bst r22,0		//store bit 0 into SREG T bit
	brts cond_01	//branch if T is set
	
	cond_00:
	rjmp whichEnd	//branch if cndt 00 is set
	
	cond_01:
	rcall TurnRight //go to subroutine TurnRight if cndt 01
	rjmp whichEnd   //jump to whichEnd 
	
	cond_1x:
	bst r22,0
	brtc cond_10
	rjmp cond_11	//jump to whichEnd
	
	cond_10:		
	rcall TurnLeft	//go to subroutine TurnLeft if cndt 10
	rjmp whichEnd	//jump to whichEnd
	
	cond_11:
	rcall TurnAround //go to subroutine TurnAround if cndt 11
	rjmp whichEnd	//jump to whichEnd
	
	whichEnd:
	ret

HitWall:
	push r16
	
	rcall DrawDirection
	mov r16,r24
	mov r24,r22
	rcall DrawRoom
	and r24,r16
	pop r16
	ret

TestHitWall:
	lds r22, room
	lds r24, dir
	mov r16, spiLEDs
	rcall HitWall
	tst r24
	breq noWall
	sbr r16, 0b00100000 // set hit wall LED
	cbr r16, 0b00010000 // sequence to true
	rjmp overTheWall

noWall:
	sbr r16, 0b00010000
	cbr r16, 0b00100000

overTheWall:
	mov spiLEDs, r16
	ret

RightPaw:
	rcall TurnRight
	rcall HitWall
	ret

LeftPaw:
	rcall TurnLeft
	rcall HitWall
	ret

TestLeftPaw:
	lds r22, room
	lds r24, dir
	mov r16, spiLEDs
	rcall LeftPaw
	tst r24
	breq noLeft
	sbr r16, 0b00001000 // set hit wall LED
	cbr r16, 0b00000100 // sequence to true
	rjmp overLeft

noLeft:
	sbr r16, 0b00000100
	cbr r16, 0b00001000

overLeft:
	mov spiLEDs, r16
	ret

TestRightPaw:
	lds r22, room
	lds r24, dir
	mov r16, spiLEDs
	rcall RightPaw
	tst r24
	breq noRight
	sbr r16, 0b00000010 // set hit wall LED
	cbr r16, 0b00000001 // sequence to true
	rjmp overRight

noRight:
	sbr r16, 0b00000001
	cbr r16, 0b00000010

overRight:
	mov spiLEDs, r16
	ret

