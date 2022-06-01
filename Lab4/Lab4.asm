; ----------------------------------------
; Lab 4
; Version 2.5
; Date: October 30, 2018
; Written By : Socheath Sok
; Lab Hours  : T/Th 3:00pm - 4:15pm
;  ----------------------------------------

	.INCLUDE <m328pdef.inc>
	; Pushbutton switch ports
	.EQU dff_Q = PD2 		   // Q output of debounce flip-flop (PD2)
	.EQU dff_clk = PD5 		   // clock of debounce flip-flop (PD5)
	.EQU S0 = 0b00 			   // state 0
	.EQU S1 = 0b01 			   // state 1
	.EQU S2 = 0b10 			   // state 2
	; true and false
	.EQU true = 0xFF
	.EQU false = 0x00

	.DSEG
	 room:  	 .BYTE   1       
	 dir:   	 .BYTE   1
	 next_state: .BYTE	 1
	 walk: 		 .BYTE 	 1

	.CSEG
	.ORG 0x0000
	
RST_VECT:
    rjmp reset                  // jump over IVT, plus INCLUDE code

; ----- Interrupt Vector Table (IVT) -----
 	.ORG INT0addr 				// 0x0002 External Interrupt Request 0
	jmp INT0_ISR 
	.ORG 0x0100                 // bypass IVT
	.INCLUDE "spi_shield.inc"
	.INCLUDE "testbench.inc"    // DrawRoom and DrawDirection
	.INCLUDE "pseudo_instr.inc" // Pseudo Instructions

reset:
	ldi   r17,HIGH(RAMEND)     // Initializes Stack Pointer to RAMEND address 0x08ff
	out   SPH,r17              // Outputs 0x08 to SPH
	ldi   r16,LOW(RAMEND)
	out   SPL,r16              // Outputs 0xFF to SPL

	call  InitShield           // initialize GPIO Ports and SPI communications
	clr   spiLEDS              // clear discrete LEDs
	clr   spi7SEG              // clear 7-segment display

;Initialize pins for push-button debounce circuit | Table 13-1
	sbi DDRD, dff_clk 		   // flip-flop clock | 1X = output from AVR
	cbi DDRD, dff_Q 		   // flip-flop Q | 00 = input to AVR w/o pull-up
	cbi PORTD, dff_Q 		   // flip-flop Q

; Initialize External Interrupt 0
	cbi EIMSK, INT0 // Disable INT0 interrupts (EIMSK I/O Address 0x1D)
	lds r17, EICRA // EICRA Memory Mapped Address 0x69
	cbr r17, 0b00000001
	sbr r17, 0b00000010
	sts EICRA, r17 // ISCO=[10] (falling edge)
	sbi EIMSK, INT0 // Enable INT0 interrupts

;Initialize SRM Variables	
	clr   r17                  // initalizes r17 to 0 and then stores data from r17 into variable room
	sts   room, r17
	ldi   r17, 0x03            // loads the hex number 3 into r17 and then stores that value into variable dir
	sts   dir, r17
	
//Timer 1
	ldi r16,0x0B
	sts TCNT1H,r16
	ldi r16,0xDC
	sts TCNT1L,r16
	ldi r16,(1<<CS11)|(1<<CS10) // prescale of 64
	sts TCCR1B,r16

	clr r19						//clears the next state variable 
	sts	next_state,r19 

;Initialize walk variable
	sts walk, r17			    // do not walk
	sei

loop:

	call    ReadSwitches       // read switches into r6

; dir  = switch & 0x03;
	mov     r17, switch        // move switch (r6) to temporary register r17
    cbr     r17, 0xFC          // mask-out most significant 6 bits
    sts     dir, r17           // save formatted value to SRAM variable dir.

/* Moore FSM */
; state = next_state;
 
 	lds 	r19,next_state // r19 = current state

state_S0:
	cpi 	r19,S0
	brne 	state_S1
	lds		r24,room
	rcall	DrawRoom
	mov 	spi7seg,r24

;rcall	WriteDisplay
	ldi		r18,S1
	sts 	next_state,r18
 	rjmp 	end_switch // break

state_S1:
	cpi		r19,S1
	brne	state_S2
	lds		r24,room
	rcall	DrawRoom
	mov		spi7seg,r24
	lds		r24,dir
	rcall	DrawDirection
	or		spi7seg,r24

;rcall	WriteDisplay
;next_state decoder
	lds r17, walk
	tst r17
	ldi r16, S0 // guess walk=false
	breq end_S1
	ldi r16, S2 // wrong guess, walk=true

end_S1:
	sts next_state, r16
	rjmp end_switch // break

state_S2:
	cpi 	r19,S2
	brne	end_switch
	
	ldi		r16,false
	sts		walk,r16
	rcall	TakeAStep

	lds		r24,room
	rcall	DrawRoom
	mov		spi7seg,r24
	ldi		r16,S1
	sts		next_state,r16

end_switch:

//code to update discrete leds 
	bst		r19,1
	bld		r8,7
	bst		r19,0
	bld		r8,6
	
	call 	WriteDisplay
	rcall	Delay
	rcall 	Pulse

	rjmp   loop

; ---- External Interrupt 0 Service Routine -----------------
; Called when a falling edge is asserted on the INT0 pin (PIND2)
; INTF0 flag automatically cleared by AVR on vector interrupt
; SRAM Variable room is modified by this ISR

INT0_ISR:
 	push reg_F
 	in reg_F,SREG
 	push r16
 	ldi r16, true
 	sts walk, r16
 	pop r16
 	out SREG,reg_F
 	pop reg_F
 	reti

TakeAStep:
 	push r16
 	call ReadSwitches // read switch values into r6
 	mov r16, switch // move switch (r6) to temp. register r16
 	cbr r16, 0x0F // mask-out least significant nibble
 	swap r16 // swap nibbles
 	sts room, r16 // save formatted value to SRAM variable room
 	pop r16
 	ret

Delay:
	push r16
wait:
	sbis 	TIFR1,TOV1
	rjmp 	wait
	sbi 	TIFR1,TOV1 			// clear flag bit by writing a one (1)
	ldi 	r16,0x0B 			// load value high byte 0x0B
	sts 	TCNT1H,r16
	ldi 	r16,0xDC 			// load value low byte 0xDC
	sts 	TCNT1L,r16
	pop 	r16
	ret

Pulse:
	cbi		PORTD,dff_clk		// clears clock
	sbi		PORTD,dff_clk		// sets clock
    ret
