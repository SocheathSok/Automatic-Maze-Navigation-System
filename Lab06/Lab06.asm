; ----------------------------------------
; Lab 6 - Whichway
; Version 2.5
; Date: December 8, 2018
; Written By : Socheath Sok
; Lab Hours  : Tuesday 3:00pm - 4:30pm
;  ----------------------------------------

	.INCLUDE <m328pdef.inc>

	; Pushbutton switch ports
	.EQU dff_Q = PD2 		   // Q output of debounce flip-flop (PD2)
	.EQU dff_clk = PD5 		   // clock of debounce flip-flop (PD5)
	.EQU S0 = 0b00 			   // state 0
	.EQU S1 = 0b01 			   // state 1
	.EQU S2 = 0b10 			   // state 2
	.EQU s3 = 0b11			   // state 3

	; true and false
	.EQU true = 0xFF
	.EQU false = 0x00

	.DSEG
	 room:  	 .BYTE   1       
	 dir:   	 .BYTE   1
	 next_state: .BYTE	 1
	 walk: 		 .BYTE 	 1
	 row: 		 .BYTE   1 //  row address
	 col: 		 .BYTE   1 //  column address
	 bees:		 .BYTE   1 //  number of bees
	 F:		 	 .BYTE	 1
	 T:		 	 .BYTE	 1
	 O:		 	 .BYTE	 1
	 total_bees: .BYTE 1 // total number of times bear was stung
	
	.CSEG
	.ORG 0x0000
	RST_VECT:
    rjmp reset                  
 	.ORG INT0addr 				
	jmp INT0_ISR
	.ORG 0x0150

	theBees: .DB 0x3F,0x06,0x5B,0x4F			//Bees look up table
		 	 .DB 0x66,0x6D,0x7D,0x07
		 	 .DB 0x7F,0x67,0x77,0x7C
		 	 .DB 0x39,0x5E,0x79,0x71
	
	.INCLUDE "spi_shield.inc"
	.INCLUDE "testbench.inc"    
	.INCLUDE "pseudo_instr.inc" 
	.INCLUDE "maze.inc"			

reset:
	ldi   r16,HIGH(RAMEND)     // Initializes Stack Pointer to RAMEND address 0x08ff
	out   SPH,r16              
	ldi   r16,LOW(RAMEND)
	out   SPL,r16              

	call  InitShield           // initialize GPIO Ports and SPI communications
	clr   spiLEDS              
	clr   spi7SEG              

	;Initialize pins for push-button debounce circuit | Table 13-1
	sbi DDRD, dff_clk 		   
	cbi DDRD, dff_Q 		   
	cbi PORTD, dff_Q 		   

	; Initialize External Interrupt 0
	cbi EIMSK, INT0 
	lds r16, EICRA 
	cbr r16, 0b00000001
	sbr r16, 0b00000010
	sts EICRA, r16 
	sbi EIMSK, INT0 

	;Initialize SRM Variables for row, column and bees
	clr   r16                  // set r16 to zero 
	sts   room, r16			   // no room at starting position
	sts	  F, r16
	sts   T, r16
	sts   O,r16
	sts	  total_bees,r16
	sts	  next_state,r16
	sts   col, r16			   // col = 0x00
	sts   bees, r16			   // bees = 0x00
	sts   walk, r16			   
	ldi   r16, 0x03            
	sts   dir, r16			   // starting dir = north
	ldi   r16, 0x14
	sts   row, r16			   // row = 0x14

	//Timer 1
	ldi r16,0x64 	
	sts	TCNT2,r16
	ldi r16,(1<<cs22)|(1<<cs21)|(1<<cs20) 
	sts TCCR2B,r16 			
	clr   spiLEDS              
	clr   spi7SEG              

	sei

loop:

    /* Moore FSM */
 	// state = next_state;
 	lds 	r17,next_state // r17 = current state
state_S0:
	cpi 	r17,S0
	brne 	state_S1
	lds		r24,room
	rcall	DrawRoom
	mov 	spi7seg,r24
	
	ldi		r16,S1
	sts 	next_state,r16
	rcall 	TakeAStep
 	rjmp 	end_switch 

state_S1:
	cpi		r17,S1
	brne	state_S2
	lds		r24,room
	rcall	DrawRoom
	mov		spi7seg,r24
	lds		r24,dir
	rcall	DrawDirection
	or		spi7seg,r24

	// next_state decoder
	lds r18, walk
	tst r18
	ldi r16, S0 // guess walk=false
	breq end_S1
	ldi r16, S2 // wrong guess, walk=true
end_S1:
	sts next_state, r16
	rjmp end_switch // break
state_S2:
	cpi 	r17,S2
	brne	state_s3
	
	ldi		r16,false
;	sts		walk,r16
	lds r20, dir // input arguments are dir, row and column
	lds r24, row
	lds r22, col
	rcall TakeAStep
	sts col, r22 	// update column after taking a step
	sts row, r24 	// update row after taking a step
	
	tst r24 		// check to see if bear is in the forest
	brmi Forest


	rcall EnterRoom // EnterRoom inputs are outputs from TakeAStep
	mov r22, r24	// save bees and room into temporary register r22
	andi r22, 0xF0  // erase the room value while keeping the number of bees
	swap r22 		// swap number of bees to the least significant nibble
	sts bees, r22 	// save number of bees in the room
	andi r24, 0x0F  // remove the number of bees from the room
	sts room, r24 	// save the unformatted room (i.e.as a number)

	lds r22, room
	lds r24, dir
	rcall MyWhichWay
	sts dir, r24


	rcall Draw_N_Count_Bees
	lds		r24,room
	rcall	DrawRoom
	mov		spi7seg,r24
	lds 	r24,room
	rcall 	IsHallway
	tst		r24
	breq 	NextState
	ldi		r16,S1
	sts		next_state,r16

NextState:
	ldi 	r16,S3
	sts 	next_state, r16
	rjmp 	end_switch
	
state_s3:
	clr 	spi7SEG
	lds 	r24,room
	rcall 	IsHallway
	tst 	r24
	breq 	OtherState
	ldi 	r16,S2
	sts 	next_state, r16
	rjmp 	end_switch
	
OtherState:
	ldi 	r16,s0
	sts 	next_state, r16
	rjmp 	end_switch

Forest :
	rcall InForest
end_switch:

//code to update discrete leds 
	bst		r16,1
	bld		r8,7
	bst		r17,0
	bld		r8,6
	
	lds 	r22, bees
	lds 	r24, room
	rcall 	IsHallway
	rcall 	TestIsHallway
	rcall	Delay
	call    WriteDisplay
	rjmp    loop


Draw_N_Count_Bees:
	push ZH
	push ZL
	push r16
	push r17

	ldi ZL,low(theBees<<1) 		// load starting address of theMaze into Z.
    ldi ZH,high(theBees<<1)
	
	lds		r16,bees			// load number of bees into r16
	lds		r17,total_bees
	add 	r17,r16
	sts 	total_bees,r17
	tst		r16			// determine number of bees
	breq	EndBees				// nothing happen if no bee
	add		ZL,r16				// shift the location based on # of bees
	lpm		r17,Z				// load vaule in Z to r17
	mov		spi7seg,r17			// display on 7-seg
	call    WriteDisplay
	rcall	delay				// each delay = 250ms
	rcall	delay	
EndBees:
	pop ZH
	pop ZL
	pop r16
	pop r17
	
	ret	





MyWhichWay:
	push r25
	push r26
	push r27

	lds	r24,dir
    rcall LeftPaw
   	tst r24
   	breq case0xx
case1xx:
   	lds r24,dir
    rcall HitWall
    tst r24
    breq case10x
case11x:
   	lds r24,dir
    rcall RightPaw
    tst r24
    breq case110
case111:
	rjmp TA
case110:
    rjmp TR
case10x:
	lds r24,dir
	rcall RightPaw
	tst r24
	breq case100
case101:
   	lds r24,dir
 	rjmp WhichEnd
case100:
	lds r25,F
	inc r25
	sts F,r25
	cpi r25,0x03
   	breq TR 
	lds r24,dir
    rjmp whichEnd
case0xx:
   	lds r24,dir
    rcall HitWall
    tst r24
    breq case00x
case01x:
   	lds r24,dir
    rcall RightPaw
    tst r24
    breq case010
case011:
    rjmp TL
case010:
	lds r26,T
	inc r26
	sts T,r26
	cpi r26,0x02
	breq TR
	rjmp TL
case00x:
   	lds r24,dir
	rcall RightPaw
    tst r24
	breq case000
case001:
	lds r27,O
   	inc r27
	sts O,r27
    cpi r27,0x02
	breq TL
	lds r24,dir
    rjmp WhichEnd
case000:
	lds r24,dir
	rjmp whichEnd

TL:
	lds r24,dir
	rcall TurnLeft
	rjmp WhichEnd
TR:	 
	lds r24,dir
	rcall TurnRight
	rjmp WhichEnd
TA:
	lds r24,dir
	rcall TurnAround
	rjmp WhichEnd

WhichEnd:
	pop r27
	pop r26
	pop r25
   
 ret



InForest:
   lds r24, total_bees
   rcall Hex_to_7SEG    
   mov r7, r24
   clr spiLEDS // all discrete LEDs off
   call WriteDisplay
   
   // Power-Down
   ldi r16, 0x05 // When bits SM2..0 are written to 010 (Table 9-1),
   out SMCR, r16 // and SE = 1 in the SMCR register (Section 9.11.1),
   sleep // with SLEEP the MCU enters Powerdown(Section 9.5)
   ret


Hex_to_7SEG:
	push ZH
	push ZL

	push r25
    cbr r24, 0xF0
    clr r25
    ldi ZL, low(theBees<<1)
    ldi ZH, high(theBees<<1)
    add ZL, r24
    adc ZH, r25
    lpm r24, Z
	pop r25

	pop ZL
	pop ZH
	ret
