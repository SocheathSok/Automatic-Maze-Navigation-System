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
