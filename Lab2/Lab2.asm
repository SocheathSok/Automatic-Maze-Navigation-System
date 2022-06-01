
/* Lab.asm - Show a room
 * Version 2.5.4.
 * Written By   : Socheath Sok 
 * ID #         : 014470701
 * Date         : September 25 2018
 * Lab Section  : T/Th, 3 pm
 */

 .INCLUDE <m328pdef.inc>
 .DSEG
 dir: .BYTE 1

 .CSEG
 .ORG 0X0000

 RST_VECT:
 	rjmp reset

.ORG 0x0100
.INCLUDE "spi_shield.inc"

reset:
	ldi r16, low(RAMEND)	 // RAMEND address 0x08ff
	out SPL, r16 			 // stack Pointer Low SPL at i/o address 0x3d
	ldi r16, high(RAMEND)
	out SPH, r16			 // stack Pointer High SPH at i/o address 0x3e

	call InitShield

loop:
; SPI Software Wires
	call ReadSwitches  	   //read switches into r6
	mov spiLEDS, switch	   //wire switches to the 8 discrete LEDs
	
	mov r16, switch		   //move switcch r7 to temporary register r16
	cbr r16, 0xFC		   //mask-out significant 6 bits
	sts dir, r16 		   //save formatted value to SRAm variable dir
	
	bst switch, 7		   //wire switch 7 to segment g (south wall)
	bld spi7seg, seg_g
	bst switch, 6		   //wire switch 6 to segment f (west wall)
	bld spi7seg, seg_f
	bst switch, 5		   //wire switch 5 to segment b (east wall)
	bld spi7seg, seg_b
	bst switch, 4		   //wire switch 4 to segment a (north wall)
	bld spi7seg, seg_a
	
	call WriteDisplay 	   //write r7 to the 7 segment display
//	rjmp loop

;Lab 2 Direction Finder
	
	lds r16, dir 		   //load direction into temporary register r16
	clr spi7SEG 		   //start with all 7-segment off

; FACING NORTH

	mov r18,r16			//moves bit 0 into r18
	bst r16,1			//stores bit 1 into bit 0
	bld r17,0			//loads it to r17

	and r18,r17   		//B = A*B

	bst r18,0			//stores answer into t-bit
	bld spi7seg,seg_a	//loads answer to seg_a

; FACING SOUTH

	mov r18,r16			//moves bit 0 into r18
	bst r16,1			//stores bit 1 into bit 0
	bld r17,0			//loads it to r17
	
	com r17				//inverts A
	com r18				//inverts B
	and r18,r17			//B = /A*/B

	bst r18,0			//stores answer into t-bit
	bld spi7seg,seg_g	//loads answer to seg_g

; FACING WEST 

	mov r18,r16			//moves bit 0 into r18
	bst r16,1			//stores bit 1 into bit 0
	bld r17,0			//loads it to r17

	com r18				//inverts B
	and r18,r17			//B = A*/B

	bst r18,0			//stores answer into t-bit
	bld spi7seg,seg_f	//loads answer to seg_f

; FACING EAST 

	mov r18,r16			//moves bit 0 into r18
	bst r16,1			//stores bit 1 into bit 0
	bld r17,0			//loads it to r17

	com r17				//inverts A
	and r18,r17			//B = /A*B

	bst r18,0			//stores answer into t-bit
	bld spi7seg,seg_b	//loads answer to seg_b

call WriteDisplay
rjmp loop
