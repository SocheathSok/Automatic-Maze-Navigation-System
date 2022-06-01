; ----------------------------------------
; Lab 5 - Take a Step and Animation
; Version 2.5
; Date: November 27, 2018
; Written By : Socheath Sok
; Lab Hours  : Monday 3:00pm - 4:30pm
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

	.CSEG
	.ORG 0x0000
	RST_VECT:
    rjmp reset                  
 	.ORG INT0addr 				
	jmp INT0_ISR
	.ORG 0x0100

	theBees:
	 .DB	0x00,0x06,0x5B,0x4F,0x66
	
	.ORG 0x0150                 
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
	;sts	  next_state,r16
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
	call    ReadSwitches       // read switches into r6

    // dir  = switch & 0x03;
	mov     r16, switch        // move switch to r17
    cbr     r16, 0xFC          // mask-out most significant 6 bits
    sts     dir, r16           // save formatted value to SRAM variable dir.

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
	rcall TakeAStep
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
	sts		walk,r16
	lds r20, dir // input arguments are dir, row and column
	lds r24, row
	lds r22, col
	rcall TakeAStep
	sts col, r22 	// update column after taking a step
	sts row, r24 	// update row after taking a step
	rcall EnterRoom // EnterRoom inputs are outputs from TakeAStep
	mov r22, r24	// save bees and room into temporary register r22
	andi r22, 0xF0  // erase the room value while keeping the number of bees
	swap r22 		// swap number of bees to the least significant nibble
	sts bees, r22 	// save number of bees in the room
	andi r24, 0x0F  // remove the number of bees from the room
	sts room, r24 	// save the unformatted room (i.e.as a number)

	rcall DrawBees
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


TakeAStep:    // based on direction as defined in Table 5.1
	push 	r16
	push 	r17

	mov		r16,spiLEDs
	cbr		r16,0x0F		// clear LED 3 to 0
	mov		spiLEDs,r16

	mov 	r17,r24
	lds 	r24,room
	rcall	DrawRoom		// obtain room value
	mov		r16,r24			
	lds		r24,dir
	rcall 	DrawDirection	// obtain dir value
	and 	r24,r16
	tst  	r24			
//	cpi		r24,0x00 			// compare room and dir
	brne 	nomove			
	mov 	r24,r17
;checksouth	
	cpi 	r20,south			// is the bear is facing south?
	brne	checkeast			// check east
	inc 	r24 				// row + 1
	rjmp	location
checkeast:
	cpi 	r20,east			// is the bear is facing east?
	brne 	checkwest 			// check west 
	inc		r22					// col + 1
	rjmp	location		
checkwest:
	cpi		r20,west			// is the bear is facing west?
	brne	checknorth			// check north
	dec 	r22					// col -1
	rjmp	location
checknorth:
	dec 	r24					// row -1
	rjmp	location

nomove:
	mov		r16,spiLEDs
	ori		r16,0x0F			// make Led[3:0] =1
	mov		spiLEDs,r16
	mov 	r24,r17

location:
	pop r17
	pop r16
	ret

EnterRoom:

 	push 	reg_F
	in 		reg_F, SREG			// for carry bit
	push ZH
	push ZL
	push r0
	push r1
	push r16
	
	// Step 1: Starting Address
    ldi ZL,low(theMaze<<1) 		
    ldi ZH,high(theMaze<<1)
   
    // Step 2: Calculate Byte Index
	ldi r16,0x14				// 20 = 0x14
	mul r24,r16					// row *20
	add r0,r22					// row*20 + col
	clr r16
	adc r1,r16					// add carry bit over to mul high byte
    
	// Step 3: Add Index to the Starting Address and load the stored value.
	add ZL,r0					// adding low bits
	adc ZH,r1					// adding high bits
    
	// load the room and bees from program memory 
    lpm r24,Z // load the room with # of bees in room indirect

	pop r16
	pop r1
	pop r0
	pop ZL
	pop ZH
	out SREG,reg_F
	pop reg_F
    ret

DrawBees:
	push ZH
	push ZL
	push r16
	push r17

	ldi ZL,low(theBees<<1) 		// load starting address of theMaze into Z.
    ldi ZH,high(theBees<<1)
	
	lds		r16,bees			// load number of bees into r16
	tst		r16			// determine number of bees
	breq	EndBees				// nothing happen if no bee
	add		ZL,r16				// shift the location based on # of bees
	lpm		r17,Z				// load vaule in Z to r17
	mov		spi7seg,r17			// display on 7-seg
	call    WriteDisplay
	rcall	delay				// each delay = 250ms
	rcall	delay	
	rcall 	delay
	rcall	delay
EndBees:
	pop ZH
	pop ZL
	pop r16
	pop r17
	
	ret	


IsHallway:
	tst r22
//	cpi r22,0x00				// is there bee in the room?
	brne answer_is_no
Horizontal:				// Horizontal hallway
	cpi r24,0x09		// room =0x09? ==> Horizontal hallway
	breq answer_is_yes	// branch to answer_is_yes
Vertical:				// Vertical hallway
	cpi r24,0x06		// room =0x06? ==> Vertical hallway
	breq answer_is_yes 	// branch to answer_is_yes
answer_is_no:
 	ldi r24, false 		// room is not a hallway or contains bees
 	rjmp endOfHallway
answer_is_yes:
	ldi r24, true
endOfHallway:
	ret

; ----- Test IsHallway -----

TestIsHallWay:
 	push r16
 	mov r16, spiLEDS
 	tst r24 			// test return value from isHallway
 	brne inHallway
 	sbr r16, 0b00010000 // Bear is not in hallway, so turn on LED 4
 	cbr r16, 0b00100000
 	rjmp doneHallway
inHallway:
 	sbr r16, 0b00100000 //Bear is in hallway, so turn on LED 5
 	cbr r16, 0b00010000
doneHallway:
 	mov spiLEDS, r16
 	pop r16
 	ret

