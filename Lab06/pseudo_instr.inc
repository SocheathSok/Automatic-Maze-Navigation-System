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

LeftPaw:
 rcall TurnLeft
 rcall HitWall
 ret

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
