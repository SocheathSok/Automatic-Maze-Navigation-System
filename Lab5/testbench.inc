; ----------------------------------------
; Testbench Utility
; Version 1.1
; ----------------------------------------

;directions (most significant 6 bits zero) 
.EQU south=0b00
.EQU east=0b01
.EQU west=0b10
.EQU north=0b11


; --------------------------
; --- Draw the Room ---
; input argument in r24 is the room
; return value in r24 is the room formatted
; for a 7-segment display
; No general purpose registers are modified,
; while SREG is modified by this subroutine.

DrawRoom:
	
	push   reg_F 			// moving this register onto the stack so
	in     reg_F,SREG       // it can be used to save the value in SREG
	push   r17

    mov    r17, r24         // move input to temporary register
	cbr    r24, 0b11111100  // room bits 1 and 0 are already aligned to segments b and a
    cbr    r17, 0b11110011
	swap   r17
    lsr    r17              // room bits 3 and 2 are now aligned to segments g and f
	or     r24, r17         // SW7:SW4 now mapped to 7 segment display
		
	pop    r17 				// restore original contents of r17
	out    SREG,reg_F
	pop    reg_F

	ret

; --------------------------
; --- Set Direction Bit ---
; The input argument in r24 is the direction
; and return value in r24 is the 7-segment display
; no registers are modified by this subroutine

DrawDirection:
	push  reg_F
	in    reg_F,SREG
	push  r16

    mov   r16, r24          ; move direction bear is facing into r16
    ldi   r24, 1<<seg_g     ; guess bear is facing south
    cpi   r16,south         ; if bear is facing south then we are done             
    breq  found
    ldi   r24, 1<<seg_f     ; guess bear is facing west
    cpi   r16,west          ; if bear is facing west then we are done             
    breq  found
	ldi   r24, 1<<seg_b     ; guess bear is facing east
    cpi   r16,east          ; if bear is facing east then we are done             
    breq  found
    ldi   r24, 1<<seg_a     ; bear is facing north

found:
	pop    r16
	out    SREG,reg_F
	pop    reg_F

	ret

