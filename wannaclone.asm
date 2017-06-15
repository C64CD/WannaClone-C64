;
; WANNACLONE
;

; Code and graphic conversion by T.M.R
; Music by Skywave/Cosine


; A simple example of EOR-based "encryption" written as a demonstration
; for 2600problems on the Atar Age forums.
; Coded for C64CrapDebunk.Wordpress.com

; Notes: this source is formatted for the ACME cross assembler from
; http://sourceforge.net/projects/acme-crossass/
; Compression is handled with Exomizer 2 which can be downloaded at
; http://hem.bredband.net/magli143/exo/

; build.bat will call both to create an assembled file and then the
; crunched release version.


; Memory Map
; $0801 - $1fff		program code/data
; $2000 - $3f3f		bitmap picture
; $4000 - $43e7		bitmap picture colour
; $4400 -		scrolling mesasage
; $6000 - $6fff		music


; Select an output filename
		!to "wannaclone.prg",cbm


; Yank in binary data
		* = $2000
		!binary "binary/bitmap.raw"

		* = $4000
		!binary "binary/bitmap_colour.raw"

		* = $4400
scroll_text	!binary "binary/scroll_text.raw"

		* = $6000
music		!binary "binary/yo_twist.prg",,2


; Constants
raster_1_pos	= $00
raster_2_pos	= $f1

; This is the initial value of the seed - if it's changed, the
; BlitzMax code's equivalent SeedInit needs to be updated
; accordingly!
seed_init	= $6a


; Label assignments
raster_num	= $50
scroll_x	= $51
scroll_pos	= $52		; two bytes used

seed		= $54
xor_count	= $55

scroll_line	= $07c0


; Add a BASIC startline
		* = $0801
		!word entry-2
		!byte $00,$00,$9e
		!text "2066"
		!byte $00,$00,$00


; Entry point for the code
		* = $0812
entry		sei

; Stop interrupts, disable the ROMS and set up NMI and IRQ interrupt pointers
		lda #$35
		sta $01

		lda #<nmi_int
		sta $fffa
		lda #>nmi_int
		sta $fffb

		lda #<irq_int
		sta $fffe
		lda #>irq_int
		sta $ffff

; Set the VIC-II up for a raster IRQ interrupt
		lda #$7f
		sta $dc0d
		sta $dd0d

		lda $dc0d
		lda $dd0d

		lda #raster_1_pos
		sta $d012

		lda #$1b
		sta $d011
		lda #$01
		sta $d019
		sta $d01a

; Empty the screen
		ldx #$00
screen_clear	lda $4000,x
		sta $0400,x
		lda $4100,x
		sta $0500,x
		lda $4200,x
		sta $0600,x
		lda $42c0,x
		sta $06c0,x

		lda #$07
		sta $d800,x
		sta $d900,x
		sta $da00,x
		sta $dae8,x
		inx
		bne screen_clear

; Clear label space and set some specific labels
		ldx #$50
		lda #$00
nuke_zp		sta $00,x
		inx
		bne nuke_zp

; Reset the scroller
		jsr scroll_reset

		ldx #$00
		lda #$20
scroll_clear	sta scroll_line,x
		inx
		cpx #$28
		bne scroll_clear

; Set up the music driver
		lda #$00
		jsr music+$908


; Restart the interrupts
		cli

; Infinite loop - all of the code is executing on the interrupt
		jmp *


; IRQ interrupt handler
irq_int		pha
		txa
		pha
		tya
		pha

		lda $d019
		and #$01
		sta $d019
		bne int_go
		jmp irq_exit

; An interrupt has triggered
int_go		lda raster_num
		cmp #$02
		bne *+$05
		jmp irq_rout2


; Raster split 1
irq_rout1	lda #$3b
		sta $d011
		lda #$07
		sta $d016
		lda #$18
		sta $d018

		lda #$00
		sta $d020
		lda #$02
		sta $d021

; Move scrolling message
		ldx scroll_x
		inx
		cpx #$04
		bne scr_xb

; Move the text line
		ldx #$00
scroll_mover	lda scroll_line+$01,x
		sta scroll_line+$00,x
		inx
		cpx #$26
		bne scroll_mover

; Decode and copy a new character to the scroller
		ldy #$00
scroll_mread	lda (scroll_pos),y
		tax
		sec
		sbc seed
		ldy xor_count
		eor music,y
		and #$7f
		bne scroll_okay

		jsr scroll_reset
		jmp scroll_mread-$02

scroll_okay	sta scroll_line+$26
		txa
		clc
		adc seed
		sta seed

		inc scroll_pos+$00
		bne *+$04
		inc scroll_pos+$01

		inc xor_count

		ldx #$00
scr_xb		stx scroll_x

; Play the music
		jsr music+$006

; Set interrupt handler for split 2
		lda #$02
		sta raster_num
		lda #raster_2_pos
		sta $d012

; Exit IRQ interrupt
		jmp irq_exit


; Raster split 2
irq_rout2	ldx #$0b
		dex
		bne *-$01
		nop

		lda scroll_x
		and #03
		asl
		eor #$07
		ldx #$1b
		ldy #$17
		stx $d011
		sty $d018
		sta $d016

; Set interrupt handler for split 1
		lda #$01
		sta raster_num
		lda #raster_1_pos
		sta $d012

; Exit interrupt
irq_exit	pla
		tay
		pla
		tax
		pla
nmi_int		rti


; Subroutine to reset the scrolling message
scroll_reset	lda #<scroll_text
		sta scroll_pos+$00
		lda #>scroll_text
		sta scroll_pos+$01

		lda #seed_init
		sta seed
		lda #$00
		sta xor_count
		rts
