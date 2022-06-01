
/* Lab 1 - An Introduction ot Assembly
 * Version 2.5.4.
 * Written By   : Socheath Sok 
 * ID #         : 014470701
 * Date         : September 11 2018
 * Lab Section  : T/Th, 3 pm
 */

 .INCLUDE <m328pdef.inc>

 .CSEG
 .ORG 0X0000

 RST_VECT:
 	rjmp reset

.ORG 0x0100
.INCLUDE "spi_shield.inc"

reset:
	ldi r16, high(RAMEND) //IO[0x3e] = 0x08
	out SPH, r16
	ldi r16, low(RAMEND)  //IO[0x3d] = 0xff
	out SPL, r16
	
	call InitShield

loop:
	call ReadSwitches  //read switches into r6
	mov r7, r6     	   //wire swithces to the 7 segment display
	mov r8, r6
	call WriteDisplay  //write r7 to the 7 segment display
	rjmp loop


