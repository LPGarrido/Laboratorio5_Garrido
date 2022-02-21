; Archivo:	main_tmr0.s
; Dispositivo:	PIC16F887
; Autor:	Christopher Chiroy
; Compilador:	pic-as (v2.35), MPLABX V6.00
;                
; Programa:	TMR0 y contador en PORTD con incrementos cada 50ms
; Hardware:	LEDs en el PORTD		
;
; Creado:	31 ene 2022
; Última modificación: 07 feb 2022
    
PROCESSOR 16F887
    
; PIC16F887 Configuration Bit Settings

; Assembly source line config statements

; CONFIG1
  CONFIG  FOSC = INTRC_NOCLKOUT ; Oscillator Selection bits (INTOSCIO oscillator: I/O function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = ON            ; Power-up Timer Enable bit (PWRT enabled)
  CONFIG  MCLRE = OFF           ; RE3/MCLR pin function select bit (RE3/MCLR pin function is digital input, MCLR internally tied to VDD)
  CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
  CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
  CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
  CONFIG  LVP = ON              ; Low Voltage Programming Enable bit (RB3/PGM pin has PGM function, low voltage programming enabled)

; CONFIG2
  CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
  CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)

// config statements should precede project file includes.
#include <xc.inc>

; -------------- MACROS --------------- 
  RESET_TMR0 MACRO TMR_VAR
    BANKSEL TMR0	    ; cambiamos de banco
    MOVLW   TMR_VAR
    MOVWF   TMR0	    ; configuramos tiempo de retardo
    BCF	    T0IF	    ; limpiamos bandera de interrupción
    ENDM
  
; ------- VARIABLES EN MEMORIA --------
PSECT udata_shr		    ; Memoria compartida
    W_TEMP:		DS 1
    STATUS_TEMP:	DS 1
    
PSECT udata_bank0
    contador:		DS 1
    valor:		DS 1	; Contiene valor a mostrar en los displays de 7-seg
    banderas:		DS 1	; Indica que display hay que encender
    centenas:		DS 1	; 
    decenas:		DS 1
    unidades:		DS 1
    display:		DS 3	; Representación de cada nibble en el display de 7-seg    
    
PSECT resVect, class=CODE, abs, delta=2
ORG 00h			    ; posición 0000h para el reset
;------------ VECTOR RESET --------------
resetVec:
    PAGESEL MAIN		; Cambio de pagina
    GOTO    MAIN
    
PSECT intVect, class=CODE, abs, delta=2
ORG 04h				; posición 0004h para interrupciones
;------- VECTOR INTERRUPCIONES ----------
PUSH:
    MOVWF   W_TEMP		; Guardamos W
    SWAPF   STATUS, W
    MOVWF   STATUS_TEMP		; Guardamos STATUS
    
ISR:
    BTFSC   T0IF		; Fue interrupción del TMR0? No=0 Si=1
    CALL    INT_TMR0		; Si -> Subrutina de interrupción de TMR0
    BTFSC   RBIF		; Fue interrupción del PORTB? No=0 Si=1
    CALL    INT_PORTB		; Si -> Subrutina de interrupción de PORTB
    
POP:
    SWAPF   STATUS_TEMP, W  
    MOVWF   STATUS		; Recuperamos el valor de reg STATUS
    SWAPF   W_TEMP, F	    
    SWAPF   W_TEMP, W		; Recuperamos valor de W
    RETFIE			; Regresamos a ciclo principal
    
    
PSECT code, delta=2, abs
ORG 100h			; posición 100h para el codigo
;------------- CONFIGURACION ------------
MAIN:
    CALL    CONFIG_IO		; Configuración de I/O
    CALL    CONFIG_RELOJ	; Configuración de Oscilador
    CALL    CONFIG_TMR0		; Configuración de TMR0
    CALL    CONFIG_INT		; Configuración de interrupciones
    BANKSEL PORTD		; Cambio a banco 00
    
LOOP:
    MOVF    contador,W
    MOVWF   valor
    CALL    OBTENER_DEC_CEN_UNI	; Guardamos nibble alto y bajo de valor
    CALL    SET_DISPLAY		; Guardamos los valores a enviar en PORTC para mostrar valor en hex
    CLRF    centenas
    CLRF    decenas
    CLRF    unidades
    GOTO    LOOP	    
    
;------------- SUBRUTINAS ---------------
CONFIG_RELOJ:
    BANKSEL OSCCON		; cambiamos a banco 1
    BSF	    OSCCON, 0		; SCS -> 1, Usamos reloj interno
    BSF	    OSCCON, 6
    BSF	    OSCCON, 5
    BCF	    OSCCON, 4		; IRCF<2:0> -> 110 4MHz
    RETURN
    
; Configuramos el TMR0 para obtener un retardo de 50ms
CONFIG_TMR0:
    BANKSEL OPTION_REG		; cambiamos de banco
    BCF	    T0CS		; TMR0 como temporizador
    BCF	    PSA			; prescaler a TMR0
    BSF	    PS2
    BSF	    PS1
    BSF	    PS0			; PS<2:0> -> 111 prescaler 1 : 256
    RESET_TMR0 217		; Reiniciamos TMR0 para 10ms
    RETURN 
    
 CONFIG_IO:
    BANKSEL ANSEL
    CLRF    ANSEL
    CLRF    ANSELH		; I/O digitales
    BANKSEL TRISC
    CLRF    TRISC		; PORTC como salida
    MOVLW   0xF8
    MOVWF   TRISD
    MOVLW   0xFF
    MOVWF   TRISB
    BCF	    OPTION_REG,7    ; PORTB pull-ups are enabled
    MOVLW   0x03	    
    MOVWF   WPUB	    ; Habilita RB0 y RB1 los pull-ups internos
    BANKSEL PORTC
    CLRF    PORTC		; Apagamos PORTC
    BCF	    PORTD, 0		; Apagamos RD0
    BCF	    PORTD, 1		; Apagamos RD1
    BCF	    PORTD, 2		; Apagamos RD2
    CLRF    banderas		; Limpiamos GPR
    CLRF    valor
    CLRF    contador
    RETURN
    
CONFIG_INT:
    BANKSEL IOCB		
    BSF	    IOCB0		; Habilitamos int. por cambio de estado en RB0
    BSF	    IOCB1		; Habilitamos int. por cambio de estado en RB1
    BANKSEL INTCON
    BSF	    GIE			; Habilitamos interrupciones
    BSF	    T0IE		; Habilitamos interrupcion TMR0
    BCF	    T0IF		; Limpiamos bandera de int. de TMR0
    BCF	    RBIF		; Limpiamos bandera de int. de PORTB
    RETURN
    
OBTENER_DEC_CEN_UNI:		;    Ejemplo:253
    CHECK_CEN:
    MOVLW   100			; W=100
    SUBWF   valor,W		; valor - 100		    
    BTFSS   STATUS,0		; Si W>f, C=0, ; W?f, C=1
    GOTO    CHECK_DEC
    MOVWF   valor
    INCF    centenas
    GOTO    CHECK_CEN
    
    CHECK_DEC:
    MOVLW   10			; W=10
    SUBWF   valor,W		; valor - 10		    
    BTFSS   STATUS,0		; Si W>f, C=0, ; W?f, C=1
    GOTO    CHECK_UNI
    MOVWF   valor
    INCF    decenas
    GOTO    CHECK_DEC
    
    CHECK_UNI:
    MOVLW   1			; W=1
    SUBWF   valor,W		; valor - 1		    
    BTFSS   STATUS,0		; Si W>f, C=0, ; W?f, C=1
    RETURN
    MOVWF   valor
    INCF    unidades
    GOTO    CHECK_UNI
    
    
SET_DISPLAY:
    MOVF    centenas, W		; Movemos centenas a W
    CALL    TABLA_7SEG		; Buscamos valor a cargar en PORTC
    MOVWF   display		; Guardamos en display
    
    MOVF    decenas, W		; Movemos centenas a W
    CALL    TABLA_7SEG		; Buscamos valor a cargar en PORTC
    MOVWF   display+1		; Guardamos en display
    
    MOVF    unidades, W		; Movemos centenas a W
    CALL    TABLA_7SEG		; Buscamos valor a cargar en PORTC
    MOVWF   display+2		; Guardamos en display
    
    RETURN
    
MOSTRAR_VOLOR:
    BCF	    PORTD, 0		; Apagamos display de centenas
    BCF	    PORTD, 1		; Apagamos display de decenas
    BCF	    PORTD, 2		; Apagamos display de decenas
    
    BTFSC   banderas,1		; B0=0
    GOTO    DISPLAY_2
    BTFSC   banderas,0		; B0=0. B1=0 DISPLAY_0, B1=1 DISPLAY_1
    GOTO    DISPLAY_1
    GOTO    DISPLAY_0		;
    
    DISPLAY_0:			
	MOVF    display, W	; Movemos display a W
	MOVWF   PORTC		; Movemos Valor de tabla a PORTC
	BSF	PORTD, 0	; Encendemos display de nibble bajo
	BSF	banderas,0	; Cambiamos bandera para cambiar el otro display en la siguiente interrupción
	BCF	banderas,1
    RETURN

    DISPLAY_1:			
	MOVF    display+1, W	; Movemos display a W
	MOVWF   PORTC		; Movemos Valor de tabla a PORTC
	BSF	PORTD, 1	; Encendemos display de nibble bajo
	BCF	banderas,0	; Cambiamos bandera para cambiar el otro display en la siguiente interrupción
	BSF	banderas,1
    RETURN
    
    DISPLAY_2:			
	MOVF    display+2, W	; Movemos display a W
	MOVWF   PORTC		; Movemos Valor de tabla a PORTC
	BSF	PORTD, 2	; Encendemos display de nibble bajo
	BCF	banderas,0	; Cambiamos bandera para cambiar el otro display en la siguiente interrupción
	BCF	banderas,1
    RETURN
    
INT_TMR0:
    RESET_TMR0 217		; Reiniciamos TMR0 para 10ms
    CALL    MOSTRAR_VOLOR	; Mostramos valor en hexadecimal en los displays
    RETURN
    
INT_PORTB:
    BTFSS   PORTB,0		
    INCF    contador
    BTFSS   PORTB,1
    DECF    contador
    BCF	    RBIF
    RETURN
    
    
    
ORG 200h
TABLA_7SEG:
    CLRF    PCLATH		; Limpiamos registro PCLATH
    BSF	    PCLATH, 1		; Posicionamos el PC en dirección 02xxh
    ANDLW   0x0F		; no saltar más del tamaño de la tabla
    ADDWF   PCL
    RETLW   00111111B	;0
    RETLW   00000110B	;1
    RETLW   01011011B	;2
    RETLW   01001111B	;3
    RETLW   01100110B	;4
    RETLW   01101101B	;5
    RETLW   01111101B	;6
    RETLW   00000111B	;7
    RETLW   01111111B	;8
    RETLW   01101111B	;9
    RETLW   01110111B	;A
    RETLW   01111100B	;b
    RETLW   00111001B	;C
    RETLW   01011110B	;d
    RETLW   01111001B	;E
    RETLW   01110001B	;F


