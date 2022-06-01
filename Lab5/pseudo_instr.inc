; -------- Pseudo Instructions --------
; --------------------------
; ------- Turn Left --------
; Called from WhichWay subroutine 
; The input and output is register r24
; register SREG is modified by this subroutine
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
; --------------------------
; ------- Turn Right -------
; Called from WhichWay subroutine 
; The input and output is register r24
; register SREG is modified by this subroutine
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
; --------------------------
; ------- Turn Around -------
; Called from WhichWay subroutine 
; The input and output is register r24
; register SREG is modified by this subroutine
TurnAround:
 com r24		
 cbr r24,0xFC

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

RightPaw:
 rcall TurnRight
 rcall HitWall
 ret
Delay:
	push r15
	in r15, SREG
	push r16
	push r17
	ldi	r17,0x19
	wait:
		sbis TIFR2, TOV2
		rjmp wait
		sbi TIFR2, TOV2 // clear flag bit by writing a one (1)
		ldi r16,0x64 	// load value of 100 tics
		sts	TCNT2,r16
		rcall Pulse		//Check pulsests TCNT2,r16
		cpi r25,0x00
		breq EndLoop
		dec r17
		brne wait
	EndLoop:
	ldi r25,0x01
	pop r16
	pop r17
	out SREG, r15
	pop r15
ret

Pulse:
	cbi		PORTD,dff_clk		// clears clock
	sbi		PORTD,dff_clk		// sets clock
ret

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
