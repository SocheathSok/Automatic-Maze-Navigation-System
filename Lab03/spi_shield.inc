; SPI interface registers
.DEF spiLEDS=r8
.DEF spi7SEG=r7

; Switches
.DEF switch=r6

; Temporary storage of AVR Status REGister Flag bits
.DEF reg_F=r15

; 7-segment display
.EQU seg_a=0
.EQU seg_b=1
.EQU seg_c=2
.EQU seg_d=3
.EQU seq_e=4
.EQU seg_f=5
.EQU seg_g=6
.EQU seg_dp=7

InitShield:
; Disable interrupts and configure stack pointer for 328P
	cli

; Initialize Switches with Pull-up resistors and Test LEDs
	in		r16,DDRC		// input Port C Data Direction Register (0x07) for switches 5 to 0
	cbr		r16,0b00111111	// define bits 5 to 0 as input (clear bit register)
	out		DDRC,r16		// output

	in		r16,PORTC		// input Port C Register (0x08) for switches 5 to 0
	sbr		r16,0b00111111	// add pull-up resistors (PUR)
	out		PORTC,r16		// output

	in		r16,DDRD		// input Port D Data Direction Register (0x0A) for switches 7 to 6
	cbr		r16,0b11000000	// define bits 7 to 6 as input (clear)
	out		DDRD,r16		// output

	in		r16,PORTD		// input Port D Register (0x0B) for switches 7 to 6
	sbr		r16,0b11000000	// add pull-up resistors (PUR)
	out		PORTD,r16		// output

; Initialize SPI Port
	in		r16,DDRB		// Input from Port B Data Direction Register (DDRB) at i/o address 0x04
	sbr 	r16,0b00101111	// Set PB5, PB3, PB2 (SCK, MOSI, SS) and PB1, PB0 (TEST LEDs) as outputs
	out 	DDRB,r16		// Output to Port B Data Direction Register (DDRB) at i/o address 0x04

	ldi		r16,0b01010001	// Set SPCR Enable (SPE) bit 6, Master (MSTR) bit 4, clock rate fck/16 (SPR1 = 0,SPR0 = 1)
	out 	SPCR,r16		// Output to SPI Control Register (SPCR) at i/o address 0x2c

	cbi		PORTB,2			// Clear I/O Port B bit 2 (SS) at i/o address 0x05
	cbi		PORTB,1			// Clear I/O Port B bit 1 (TEST LED1)
	cbi		PORTB,0			// Clear I/O Port B bit 0 (TEST LED0)
	ret

ReadSwitches:
; SPI Software Wires
   push  r17
   push  r16

   in    r17, PINC       // input port C pins (0x06) into register r17
   in    r16, PIND       // input port D pins (0x09) into register r16

   cbr   r17, 0b11000000 // clear non-switch bits 7 and 6
   cbr   r16, 0b00111111 // clear non-switch bits 5 to 0

   or    r16, r17        // concatenate switches  SW7 - SW6 : SW5 - SW0
   mov   r6, r16         // move to standardized switch register

   pop   r16
   pop   r17
   ret

WriteDisplay:
; Save SREG
    push  reg_F
    in    reg_F, SREG
; Start transmission of data
	out 	SPDR,spiLEDS
	rcall	spiTxWait
	out		SPDR,spi7SEG
	rcall	spiTxWait
	sbi		PORTB,PB2		// strobe latches
	cbi		PORTB,PB2
; Restore SREG
	out   SREG, reg_F
	pop   reg_F
	ret

SpiTxWait:
	push	r16
; Wait for transmission complete
spiPolling:
	in		r16,SPSR
	bst		r16,SPIF
	brtc 	spiPolling
	pop		r16
	ret

; --------------------------
