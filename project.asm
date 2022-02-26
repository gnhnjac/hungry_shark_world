IDEAL
MODEL compact
STACK 0100h

SHARK_WIDTH = 65
SHARK_HEIGHT = 33

PINK = 0EFh

TOTAL_SEEWEEDS = 700
MAX_FISH = 2500

CYCLES_RESET = 100

; NOTES

; Add eating sound and animation

; Create opening screen -> Start game, options, how to play, exit

; Rare golden fish give more points, different fish types -> different score, rarer = more points

; Fish Types -> Normal, 
;               Blinding (when you eat you only see 2 or 3 blocks outside your radius),
;               Health lowering (When you eat your health decreases instead of increases),
;               Granting speed, 
;               Health Shield

; Add power ups, etc...

DATASEG

;Marching squares

	rows db ?
	cols db ?
	
; Game Mechanics variables

	pixels db 59840 dup (?) ; Pixel world array
	pixels_temp db 640 dup (?)
	world_size dw 59840
	screen_size dw 50
	resx dw 20
	resy dw 20
	
	res2x dw ?
	res2y dw ?
	
	; (Width = 320/resolutionx, Height = 200/resolutiony, Screen_Size = W*H)
	wdth dw ?
	hght dw ?
	
	hwdth dw ? ; Half width
	hhght dw ? ; Half height
	
	; WIDTH AND HEIGHT ARE HOW MANY TOTAL GRID ELEMENTS THERE ARE IN THE SCREEN AND NOT WHAT THEIR SIZE IS.

	world_pos dw 0 ; Pointer to current position in world
	seed dw ?

	health db 100
	
	points dw 0
	
	highscore_buff db 5 dup(?) ; File buffer to read highscore file data
	
	byte_buff db 1 ; Byte buffer for byte by byte writes or reads

	TOTAL_FISH dw 2000 ; Medium
	
	LIFE_DEPLETE db 4 ; Medium
	
	LIFE_RESTORE db 10 ; Medium

	POINTS_MULTIPLIER db 2 ; Medium
	
	; HOLDS SEAWEED POSITIONS (For beauty has no functionality)
	; Word for world pos of each seaweed

	seaweed_pos dw TOTAL_SEEWEEDS dup(?)

	; HOLDS BIOME TL, BR (Double for each biome) (dd for each biomes tl x, y and br x, y)
	; TOTAL OF 3 SPECIAL BIOMES, EACH WORLD CONTAINS 4 (MAYBE NOT UNIQUE) BIOMES (SIZE AND LOCATION DEPENDS ON SEED)

	biome_pos dd 8 dup(?)

	; BIOME TYPES FOR EACH GENERATED BIOME

	; 0 = ICE CAVE (WHITE AND BLUE), 1 = PURPLE BLACK ALIEN VOID CAVE, 2 = GREEN SEWER CAVE

	biome_type db 4 dup(?)

; Cellular automata rules
	
	birth_limit db 4
	
	death_limit db 3
	
	num_of_steps db 7
	
	chance_for_black dw 5 ; (x / 9) 0 - 9 range

; Randomness and initialization variables
	
	primea dw 16193
	primeb dw 51977
	highscore_file db "high.txt",0
	
	
	RndCurrentPos dw 0
	
; BMP Small Variables
	
	SHARK_LEFT  db 'SharkL.bmp',0
	SHARK_RIGHT  db 'SharkR.bmp',0
	SHARK_UP  db 'SharkU.bmp',0
	SHARK_DOWN  db 'SharkD.bmp',0
	SEAWEED_PIC db 'seaweed.bmp',0
	ROCK_PIC db 'rock.bmp',0
	
	FISH_LEFT db 'FishL1.bmp', 0
	FISH_RIGHT db 'FishR1.bmp', 0
	FISH_UP db 'FishU1.bmp', 0
	FISH_DOWN db 'FishD1.bmp', 0
	
	MENU db 'menu.bmp', 0
	OPTIONS db 'options.bmp', 0
	GAMEOVER db 'gameover.bmp',0
	
	HEART db 'heart.bmp',0
	
	BmpLeft dw ?
	BmpTop dw ?
	BmpColSize dw ?
	BmpRowSize dw ?
	FileHandle dw ?
	
; BMP Big Variables
	
	Header 	   db 54 dup(0)
	
	Palette    db 400h dup (0)

	ScrLine    db 320 dup (0)  ; One picture line read buffer
	
; Movement Variables
	
	; 0-3 for slower shark movement, (every 3 "ticks")
	XPRESS db 0
	
	YPRESS db 0

	; Current shark rotation
	; 0 = left, 1 = up, 2 = right, 3 = down

	SHARK_ROT db 2

; Collision Variables
	
	; Shark position on screen
	SHARKX dw 0
	SHARKY dw 0
	
; Time Variables

	cycles db 0 ; 0-99 loop cycles counter
	
	hundredths db 0 ; 0-99 hundredths of second counter
	seconds db 0 ; 0-59 second counter (Start at whatever time is)
	
	game_seconds dw 0 ; 0-255 second counter (Start at 0)

; Administration variables
	
	isSeedCustom dw 0
	isOptions dw 0
	isStart dw 0
	isDone dw 0

	CustomSeed db "XX12345X"

; Text variables

	PointsMessage db "Points: $"

segment EXTRA para public
	
	; HOLDS FISH POSITIONS AND DIRECTIONS
	
	; Word for world pos of each fish
	fish_pos dw MAX_FISH dup(?)
	
	; Byte for direction of each fish
	; 0 = Left, 1 = Up, 2 = Right, 3 = Down
	fish_dir db MAX_FISH dup(0)

	; Byte for fish type	
	; 0 = NORMAL(1st fish png), 1 = ICE CAVE FISH(3rd fish png), 2 = ALIEN CAVE FISH(4th fish png), 3 = SEWER CAVE FISH(2nd fish png)
	fish_type db MAX_FISH dup(0)

ends

CODESEG
start:
	MOV ax, @data
	MOV ds, ax
	
	; Graphic mode
	mov ax, 13h 
	int 10h

back_to_start:
	mov [word ptr isDone], 0
	CALL draw_menu
	
	; Menu Loop Section
menu_loop:
	
	CALL menu_ops
	
	cmp [isDone], 1
	jz exit
	
	cmp [isStart], 1
	jnz menu_loop
	
	CALL init

	
	; Game Loop Section
game_loop:
	CALL movement
	
	CALL update_all
	
	CALL draw_gameui

	cmp [isDone], 1
	jnz game_loop
	
	
	CALL init_game_over
	CALL second_delay
	
	; Game over section
game_over_loop:

	CALL game_over_actions
	
	cmp [isDone], 1
	jnz game_over_loop
	
	jmp back_to_start
	
exit:

	mov ax, 2
	int 10h

	MOV ax, 4c00h
	INT 21h

proc show_mouse
	
	mov ax, 1
	int 33h
	
	ret
	
endp show_mouse

proc hide_mouse
	
	mov ax, 2
	int 33h
	
	ret
	
endp hide_mouse

proc draw_menu
	
	mov [BmpLeft], 0
	mov [BmpTop], 0
	mov [BmpColSize], 320
	mov [BmpRowSize], 200
	mov dx, offset MENU
	CALL OpenShowBmp
	
	CALL show_mouse
	
	ret
	
endp draw_menu

; initialize game over screen
proc init_game_over
	
	mov [isDone], 0
	
	CALL hide_mouse
	
	mov [BmpLeft], 0
	mov [BmpTop], 0
	mov [BmpColSize], 320
	mov [BmpRowSize], 200
	mov dx, offset GAMEOVER
	CALL OpenShowBmp
	
	CALL show_mouse
	
	; set text pos in screen
	mov ah, 2
    mov bh, 0
    mov dh, 17 ;ypos
    mov dl, 19 ;xpos
    int 10h
	
	mov ax, [points]
	CALL printAxDec
	
	; Print high score
	
	; set text pos in screen
	mov ah, 2
    mov bh, 0
    mov dh, 20 ;ypos
    mov dl, 24 ;xpos
    int 10h
	
	; Get high score from file
	
	; open file
	
	mov ah, 3dh
	mov al, 2
	mov dx, offset highscore_file
	int 21h
	
	mov [FileHandle], ax
	
	; read file
	
	; get file length
	push [FileHandle]
	CALL fileLen ; file len in si
	
	mov ah, 3fh
	mov bx, [FileHandle]
	mov cx, si
	mov dx, offset highscore_buff
	int 21h

	push offset highscore_buff
	push ax
	CALL toInt ; highscore now in ax
	
	cmp [points], ax ; compare current game points to high score
	jbe @@NOTNEWHIGHSCORE
	
	; change file pointer to start for write
	mov ah, 42h
	mov al, 0
	mov bx, [FileHandle]
	xor cx, cx
	xor dx, dx
	int 21h
	
	mov ax, [points]
	
	xor cx, cx ; points counter
	
	; Write new highscore to file (overrides old highscore which must have less or equal num of digits of new so no corruption of data
@@PUSH_DIGS_TO_STACK:
	
	mov bx, 10
	xor dx, dx
	div bx
	
	; dig in dx (%)
	
	add dx, '0' ; turn dx into number
	
	push dx
	
	inc cx ; inc points counter
	
	cmp ax, 0
	jnz @@PUSH_DIGS_TO_STACK
	
	; num of digs in cx
	
@@WRITE_DIGS:
	
	pop ax ; pop digit into ax
	mov [byte_buff], al ; mov digit into buffer
	
	push cx
	mov ah, 40h
	mov bx ,[FileHandle]
	mov cx, 1 ; write 1 byte
	mov dx, offset byte_buff
	int 21h
	pop cx
	
	loop @@WRITE_DIGS
	
	mov ax, [points]
	
@@NOTNEWHIGHSCORE:
	
	CALL printAxDec ; print highscore in right place
	
	; close file
	mov ah, 3Eh
	mov bx, [FileHandle]
	int 21h
	
	ret
	
endp init_game_over

proc game_over_actions
	
	mov ah, 1
	int 16h
	
	jz @@NO
	
	xor ah, ah
	int 16h
	
	mov [isDone], 1
	
@@NO:
	
	ret
	
endp game_over_actions

proc draw_options
	
	CALL hide_mouse
	
	mov [BmpLeft], 0
	mov [BmpTop], 0
	mov [BmpColSize], 320
	mov [BmpRowSize], 200
	mov dx, offset OPTIONS
	CALL OpenShowBmp
	
	CALL show_mouse
	
	ret

endp draw_options

; Performs all menu operations (options screen and performs their operations)
proc menu_ops
	
	mov ax, 3
	int 33h
	
	; cx = x*2, dx = y
	
	cmp bx, 1
	jz @@LEFT
	
	jmp @@END

@@LEFT:

	cmp [isOptions], 1
	jz @@OPTIONS
	
	; MENU
	
	shr cx, 1
	
	; Check if start
	cmp cx, 117
	jb @@NOTSTART
	cmp cx, 206
	ja @@NOTSTART
	cmp dx, 50
	jb @@NOTSTART
	cmp dx, 98
	ja @@NOTSTART
	
	jmp @@START
	
@@NOTSTART:

	cmp cx, 108
	jb @@NOTSTARTOPTIONS
	cmp cx, 213
	ja @@NOTSTARTOPTIONS
	cmp dx, 118
	jb @@NOTSTARTOPTIONS
	cmp dx, 135
	ja @@NOTSTARTOPTIONS
	
	jmp @@STARTOPTIONS
	
@@NOTSTARTOPTIONS:

	cmp cx, 135
	jb @@NOTEXIT
	cmp cx, 186
	ja @@NOTEXIT
	cmp dx, 155
	jb @@NOTEXIT
	cmp dx, 172
	ja @@NOTEXIT
	
	jmp @@EXIT
	
@@NOTEXIT:

	jmp @@END
	
@@START:
	
	CALL hide_mouse
	
	mov [isStart], 1
	
	jmp @@END

@@STARTOPTIONS:	

	mov [isOptions], 1
	
	CALL draw_options
	
	CALL second_delay
	
	jmp @@END

@@EXIT:

	mov [isDone], 1
	
	jmp @@END
	
@@OPTIONS:
	
	shr cx, 1

	cmp cx, 14
	jb @@NOTEASY
	cmp cx, 68
	ja @@NOTEASY
	cmp dx, 49
	jb @@NOTEASY
	cmp dx, 64
	ja @@NOTEASY
	
	; pressed on easy
	jmp @@EASY

@@NOTEASY:
	
	cmp cx, 87
	jb @@NOTMEDIUM
	cmp cx, 167
	ja @@NOTMEDIUM
	cmp dx, 49
	jb @@NOTMEDIUM
	cmp dx, 64
	ja @@NOTMEDIUM
	
	; pressed on medium
	jmp @@MEDIUM

@@NOTMEDIUM:
	
	cmp cx, 187
	jb @@NOTHARD
	cmp cx, 244
	ja @@NOTHARD
	cmp dx, 49
	jb @@NOTHARD
	cmp dx, 64
	ja @@NOTHARD
	
	; pressed on hard
	jmp @@HARD

@@NOTHARD:

	cmp cx, 14
	jb @@NOTSEED
	cmp cx, 302
	ja @@NOTSEED
	cmp dx, 128
	jb @@NOTSEED
	cmp dx, 151
	ja @@NOTSEED
	
	; pressed on set seed
	jmp @@SETSEED

@@NOTSEED:

	cmp cx, 123
	jb @@NOTRESET
	cmp cx, 198
	ja @@NOTRESET
	cmp dx, 162
	jb @@NOTRESET
	cmp dx, 189
	ja @@NOTRESET
	
	; pressed on reset
	jmp @@RESET

@@NOTRESET:

	cmp cx, 296
	jb @@JMPTOEND
	cmp cx, 316
	ja @@JMPTOEND
	cmp dx, 4
	jb @@JMPTOEND
	cmp dx, 24
	ja @@JMPTOEND
	
	; pressed on exit options
	CALL hide_mouse
	CALL draw_menu
	mov [isOptions], 0

@@JMPTOEND:
	jmp @@END

@@EASY:
	
	; Draw square around easy
	CALL draw_options
	CALL hide_mouse
	push 10
	push 45
	push 60 
	push 24
	push 2
	push 1
	CALL draw_erect
	CALL show_mouse
	
	mov [POINTS_MULTIPLIER], 1
	mov [LIFE_RESTORE], 12
	mov [LIFE_DEPLETE], 4
	mov [TOTAL_FISH], 2500
	jmp @@END

@@MEDIUM:
	; Draw square around medium
	CALL draw_options
	CALL hide_mouse
	push 82
	push 45
	push 88
	push 24
	push 2
	push 1
	CALL draw_erect
	CALL show_mouse
	
	mov [POINTS_MULTIPLIER], 2
	mov [LIFE_RESTORE], 12
	mov [LIFE_DEPLETE], 6
	mov [TOTAL_FISH], 2000
	jmp @@END

@@HARD:

	; Draw square around hard
	CALL draw_options
	CALL hide_mouse
	push 182
	push 45
	push 64
	push 24
	push 2
	push 1
	CALL draw_erect
	CALL show_mouse
	
	mov [POINTS_MULTIPLIER], 3
	mov [LIFE_RESTORE], 10
	mov [LIFE_DEPLETE], 8
	mov [TOTAL_FISH], 1500
	jmp @@END

@@SETSEED:
	
	; Read seed

	mov ah, 2
    mov bh, 0
    mov dh, 17 ;ypos
    mov dl, 2 ;xpos
    int 10h

	mov [CustomSeed], 6
	mov dx, offset CustomSeed
	mov ah, 0Ah
	int 21h

	push offset CustomSeed
	CALL parse_0ah

	mov [seed], ax

	mov [word ptr isSeedCustom], 1

	jmp @@END

@@RESET:
	
	CALL draw_options

	mov [word ptr isSeedCustom], 0

@@END:
	ret
	
endp menu_ops

; PARSES 0Ah int 21h CALL INTO AX
; P1: offset of thing to parse
proc parse_0ah
	
	push bp

	mov bp, sp

	off equ [bp+4]

	mov si, off
	add si, 2 ; For start of string

	xor ch, ch
	mov cl, [si-1]

	add si, cx
	dec si

	xor ax, ax ; Accumulator

	mov bx, 1

@@PARSE: 
	push ax
	xor ah, ah
	mov al, [si]
	sub al, '0'

	xor dx, dx
	mul bx

	mov dx, ax
	pop ax

	add ax, dx

	push ax
	mov ax, 10

	xor dx, dx
	mul bx

	mov bx, ax
	pop ax

	dec si

	loop @@PARSE

	pop bp

    ret 2
	
endp parse_0ah

; Parses string to int
; P1: offset of string to parse
; P2: number of bytes to parse into int
; RETURNS AX = answer
proc toInt
	
	push bp

	mov bp, sp

	off equ [bp+6]
	amt equ [bp+4]

	mov si, off

	mov cx, amt

	add si, cx
	dec si

	xor ax, ax ; Accumulator

	mov bx, 1

@@PARSE: 
	push ax
	xor ah, ah
	mov al, [si]
	sub al, '0'

	xor dx, dx
	mul bx

	mov dx, ax
	pop ax

	add ax, dx

	push ax
	mov ax, 10

	xor dx, dx
	mul bx

	mov bx, ax
	pop ax

	dec si

	loop @@PARSE

	pop bp

    ret 4
	
endp toInt

; Detects movements and escape
proc movement

	mov ah, 1
	int 16h
	
	jz @@NOESCAPE
	
	xor ah, ah
	int 16h
	
	cmp ah, 1Eh ; A
	jnz @@NOTL
	
	jmp @@L
	
@@NOTL:
	cmp ah, 11h ; W
	jnz @@NOTU
	
	jmp @@U
	
@@NOTU:
	cmp ah, 20h ; D
	jnz @@NOTR
	
	jmp @@R
	
@@NOTR:
	cmp ah, 1Fh ; S
	jnz @@NOPRESS
	
	jmp @@D
	
@@NOPRESS:
	
	; Detect if escape key pressed
	
	cmp ah, 1
	jnz @@NOESCAPE
	
	mov [isDone], 1
	
@@NOESCAPE:
	
	jmp @@RETURN
	
@@D:
	
	; Bot collision

	mov ax, [SHARKX]
	shr ax, 1
	push ax
	
	mov ax, [SHARKY]
	shr ax, 1
	push ax
	CALL coords_to_pix
	
	mov bx, [world_pos]
	add bx, ax
	
	add bx, 320 ; to the bottom of the shark
	
	cmp [pixels+bx+320], 1
	jz @@world_bot
	
	; Bot of world

	mov ax, [world_pos]
	add ax, 1600
	
	cmp ax, [world_size]
	jb @@CanMoveDown

	mov ax, [hght]
	dec ax
	cmp [SHARKY], ax
	jb @@CanScreenDown
	
	jmp @@RETURN

@@CanScreenDown:

	inc [SHARKY]
	
	mov [SHARK_ROT], 3
	mov dx, offset SHARK_DOWN
	jmp @@END

@@CanMoveDown:

	push [world_pos]
	CALL pix_to_coords
	cmp ax, 0
	jnz @@CanWorldDown
 	
 	mov ax, [hhght]
	cmp [SHARKY], ax
	jz @@CanWorldDown

	inc [SHARKY]

	mov [SHARK_ROT], 3
	mov dx, offset SHARK_DOWN
	jmp @@END

@@CanWorldDown:
	cmp [YPRESS], 0
	jge @@DONTRESETD
	
	mov [YPRESS], 0
	
@@DONTRESETD:
	
	inc [YPRESS]
	
	cmp [YPRESS], 3
	jnz @@world_bot
	
	mov [YPRESS], 0
	
	add [world_pos], 320
	
	mov [SHARK_ROT], 3
	mov dx, offset SHARK_DOWN
	jmp @@END
	
@@world_bot:
	
	jmp @@RETURN

@@U: 
	
	; Top collision
	
	mov ax, [SHARKX]
	shr ax, 1
	push ax
	
	mov ax, [SHARKY]
	shr ax, 1
	push ax
	CALL coords_to_pix
	
	mov bx, [world_pos]
	add bx, ax
	
	sub bx, 320 ; to the top of the shark
	
	cmp [pixels+bx], 1
	jz @@world_top
	
	push [world_pos]
	CALL pix_to_coords
	cmp ax, 0
	jnz @@CanMoveUp

	cmp [SHARKY], 1
	ja @@CanScreenUp
	
	jmp @@RETURN

@@CanScreenUp:
	dec [SHARKY]
	
	mov [SHARK_ROT], 1
	mov dx, offset SHARK_UP
	jmp @@END

@@CanMoveUp:
	
	mov ax, [world_pos]
	add ax, 1280
	
	cmp ax, [world_size]
	jb @@CanWorldUp
 	
 	mov ax, [hhght]
	cmp [SHARKY], ax
	jz @@CanWorldUp

	dec [SHARKY]

	mov [SHARK_ROT], 1
	mov dx, offset SHARK_UP
	jmp @@END

@@CanWorldUp:
	
	mov ax, [world_size]
	cmp [world_pos], ax
	ja @@world_top

	cmp [YPRESS], 0
	jle @@DONTRESETU
	
	mov [YPRESS], 0
	
@@DONTRESETU:
	
	dec [YPRESS]
	
	cmp [YPRESS], -3
	jnz @@world_top
	
	mov [YPRESS], 0
	
	sub [world_pos], 320
	
	mov [SHARK_ROT], 1
	mov dx, offset SHARK_UP
	jmp @@END
	
@@world_top:

	jmp @@RETURN

@@L:
	
	; Draw params
	
	mov [SHARK_ROT], 0

	; Left Collision

	mov ax, [SHARKX]
	shr ax, 1
	push ax
	
	mov ax, [SHARKY]
	shr ax, 1
	push ax
	CALL coords_to_pix
	
	mov bx, [world_pos]
	add bx, ax
	
	dec bx ; to the left of the shark
	
	cmp [pixels+bx], 1
	jz @@collide_left
	cmp [pixels+320+bx], 1
	jz @@collide_left
	
	; Reset move counter

	cmp [XPRESS], 0
	jle @@DONTRESETL
	
	mov [XPRESS], 0
	
@@DONTRESETL:

	dec [XPRESS]
	
	cmp [XPRESS], -3
	jnz @@collide_left
	
	mov [XPRESS], 0
	
	dec [world_pos]
	
	jmp @@END

@@collide_left:
	jmp @@RETURN

@@R:
	
	; Draw params

	mov [SHARK_ROT], 2

	mov ax, [SHARKX]
	shr ax, 1
	push ax
	
	mov ax, [SHARKY]
	shr ax, 1
	push ax
	CALL coords_to_pix
	
	mov bx, [world_pos]
	add bx, ax
	
	inc bx ; to the right of the shark
	
	cmp [pixels+bx], 1
	jz @@world_right
	cmp [pixels+bx+320], 1
	jz @@world_right
	
	; Reset move counter

	cmp [XPRESS], 0
	jge @@DONTRESETR
	
	mov [XPRESS], 0
	
@@DONTRESETR:
	
	inc [XPRESS]
	
	cmp [XPRESS], 3
	jnz @@RETURN
	
	mov [XPRESS], 0
	
	inc [world_pos]
	jmp @@END

@@world_right:

	jmp @@RETURN

@@END:
	
	CALL check_eat
	
	CALL draw_cave
	
	CALL draw_shark

@@RETURN:

	ret
	
endp movement

; Shark rotation in [SHARK_ROT]
; Draws shark sprite
proc draw_shark
	
	push ax
	push bx
	push dx
	
	cmp [SHARK_ROT], 0
	jz @@LEFTORRIGHT
	cmp [SHARK_ROT], 2
	jz @@LEFTORRIGHT
	
	xor dx, dx
	mov ax, [SHARKX]
	mov bx, [resx]
	mul bx
	sub ax, 9
	
	mov [BmpLeft], ax
	
	xor dx, dx
	mov ax, [SHARKY]
	mov bx, [resy]
	mul bx
	sub ax, 25
	
	mov [BmpTop], ax
	
	jmp @@DRAW
	
@@LEFTORRIGHT:
	
	xor dx, dx
	mov ax, [SHARKX]
	mov bx, [resx]
	mul bx
	sub ax, 25
	
	mov [BmpLeft], ax
	
	xor dx, dx
	mov ax, [SHARKY]
	mov bx, [resy]
	mul bx
	sub ax, 9
	
	mov [BmpTop], ax

@@DRAW:

	cmp [SHARK_ROT], 0
	jz @@L
	cmp [SHARK_ROT], 1
	jz @@U
	cmp [SHARK_ROT], 2
	jz @@R
	cmp [SHARK_ROT], 3
	jz @@D

@@L:
	mov [BmpColSize], SHARK_WIDTH
	mov [BmpRowSize], SHARK_HEIGHT
	mov dx, offset SHARK_LEFT
	jmp @@CONT
@@R:
	mov [BmpColSize], SHARK_WIDTH
	mov [BmpRowSize], SHARK_HEIGHT
	mov dx, offset SHARK_RIGHT
	jmp @@CONT
@@U:
	mov [BmpColSize], SHARK_HEIGHT
	mov [BmpRowSize], SHARK_WIDTH
	mov dx, offset SHARK_UP
	jmp @@CONT
@@D:
	mov [BmpColSize], SHARK_HEIGHT
	mov [BmpRowSize], SHARK_WIDTH
	mov dx, offset SHARK_DOWN
@@CONT:
	CALL OpenShowBmp
	
	pop dx
	pop bx
	pop ax
	
	ret
	
endp draw_Shark

; Draws game user interface
; (HEALTH REMAINING, POINTS, ...)
proc draw_gameui
	
	; DRAW HEALTH REMAINING
	
	push 8 ; x
	push 8 ; y
	push 102 ; w
	push 10 ; h
	push 2 ; border width
	push 00h ; color
	CALL draw_erect
	
	push 10
	push 10
	xor ah, ah
	mov al, [health]
	push ax
	push 8
	push 0Fh
	CALL draw_rect
	
	mov [BmpLeft], 120
	mov [BmpTop], 3
	
	mov [BmpColSize], 20
	mov [BmpRowSize], 20
	
	mov dx, offset HEART
	
	CALL OpenShowBmp
	
	mov ah, 2
    mov bh, 0
    mov dh, 3 ;ypos
    mov dl, 1 ;xpos
    int 10h
	
	mov dx, offset PointsMessage
	mov ah, 9
	int 21h
	
	mov ax, [points]
	CALL printAxDec
	
	ret
	
endp draw_gameui

; Updates:
; - game clock and cycles
; - all "do every second" functions
; - all "do every second" operations:
;                 - Decrement shark health
;                 - Update fish positions and redraw all
proc update_all
	
	inc [cycles]
	cmp [cycles], CYCLES_RESET
	jnz @@DONT_RESET_CYCLES
	
	mov [cycles], 0
	
@@DONT_RESET_CYCLES:
	
	mov ah, 2ch
	int 21h
	
	cmp [seconds], dh
	jz @@DONT_UPDATE_SECONDS
	
	; =======================
	; EVERY SECOND OPERATIONS
	; =======================
	
	; UPDATE FISH POSITIONS ON GRAPHICS
	CALL update_fish
	CALL draw_cave
	; REDRAW SHARK (in case fish overlaps it)
	
	CALL draw_shark
	
	; DECREMENT SHARK HEALTH
	
	mov al, [LIFE_DEPLETE]
	sub [health], al
	
	cmp [health], 0
	jg @@NOTDEAD
	
	mov [isDone], 1
	
@@NOTDEAD:
	
	inc [game_seconds]
	
	mov [seconds], dh
	
@@DONT_UPDATE_SECONDS:
	
	mov [hundredths], dl
	
	ret
	
endp update_all

proc sync_clock
	
	; AH = 2C
	; on return:
	; CH = hour (0-23)
	; CL = minutes (0-59)
	; DH = seconds (0-59)
	; DL = hundredths (0-99)
	; - retrieves DOS maintained clock time
	
	mov ah, 2ch
	int 21h
	
	mov al, dh
	
@@SYNC:
	
	mov ah, 2ch
	int 21h
	
	cmp al, dh
	jz @@SYNC
	
	mov [seconds], dh
	
	ret
	
endp sync_clock

proc second_delay
	
	; AH = 2C
	; on return:
	; CH = hour (0-23)
	; CL = minutes (0-59)
	; DH = seconds (0-59)
	; DL = hundredths (0-99)
	; - retrieves DOS maintained clock time
	
	mov ah, 2ch
	int 21h
	
	mov al, dh
	xor ah, ah
	
@@WAIT:
	
	mov ah, 2ch
	int 21h
	
	cmp al, dh
	jz @@WAIT
	
	inc ah
	cmp ah, 2
	jb @@WAIT
	
	ret
	
endp second_delay

; Updates fish positions
proc update_fish

	push bx
	push cx
	push dx
	
	; Temporary
	push es
	CALL es_to_extra
	
	mov cx, [TOTAL_FISH]
	
@@UPDATE:
	
	mov bx, cx
	dec bx
	add bx, offset fish_dir
	
	push bx
	mov bl, 0 ; min
	mov bh, 3 ; max
	CALL RandomByCs
	pop bx
	
	mov [es:bx], al
	
	mov bx, cx
	dec bx ; cx - 1 since cx start at full len and ends at 1
	shl bx, 1 ; times 2
	add bx, offset fish_pos
	
	push bx
	mov bx, [word ptr es:bx] ; Move fish pos in world to bx
	add bx, offset pixels ; In pixel array

	cmp al, 0
	jz @@LEFT
	
	cmp al, 1
	jz @@UP
	
	cmp al, 2
	jz @@RIGHT
	
	cmp al, 3
	jz @@DOWN
	
@@LEFT:
	
	mov al, [byte ptr bx-1]
	pop bx

	cmp al, 1
	jz @@CONTINUE ; If if it is a cave block dont move left
	
	dec [word ptr es:bx] ; mov fish pos left
	
	jmp @@CONTINUE
	
@@RIGHT:


	mov al, [byte ptr bx+1]
	pop bx

	cmp al, 1
	jz @@CONTINUE ; If if it is a cave block dont move right

	inc [word ptr es:bx] ; mov fish pos right
	
	jmp @@CONTINUE

@@UP:


	mov al, [byte ptr bx-320]
	pop bx

	cmp al, 1
	jz @@CONTINUE ; If if it is a cave block dont move up

	sub [word ptr es:bx], 320 ; mov fish pos up
	
	jmp @@CONTINUE

@@DOWN:


	mov al, [byte ptr bx+320]
	pop bx

	cmp al, 1
	jz @@CONTINUE ; If if it is a cave block dont move down

	add [word ptr es:bx], 320 ; mov fish pov down

@@CONTINUE:
	
	loop @@UPDATE
	
	; End temporary
	pop es
	
	pop dx
	pop cx
	pop bx
	
	ret
	
endp update_fish

; Moves es to extra data seg
proc es_to_extra
	
	mov ax, EXTRA
	mov es, ax
	
	ret
	
endp es_to_extra

; Moves es to drawing positions
proc es_to_draw
	
	mov ax, 0A000h
	mov es, ax

	ret

endp es_to_draw

; Checks if shark ate fish (same pos in world)
; IF HE ATE -> REMOVE FISH AND CREATE NEW ONE INSTEAD IN NEW RANDOM POS
proc check_eat
	
	; Temporary
	push es
	CALL es_to_extra
	
	mov cx, [TOTAL_FISH]
	
@@UPDATE:
	
	mov bx, cx
	dec bx ; cx - 1 since cx start at full len and ends at 1
	shl bx, 1 ; times 2
	add bx, offset fish_pos
	
	mov ax, [SHARKX]
	shr ax, 1
	push ax
	
	mov ax, [SHARKY]
	shr ax, 1
	push ax
	CALL coords_to_pix
	
	mov dx, [world_pos]
	add dx, ax
	
	cmp dx, [es:bx]
	jnz @@CONTINUE
	
	; EAT
	; increment points
	push bx
	mov bx, cx
	dec bx
	add bx, offset fish_type

	cmp [byte ptr es:bx], 0
	ja @@SPECIALFISH

	; normal fish

	mov al, 1

	jmp @@INCPOINTS

@@SPECIALFISH:

	mov al, 2

@@INCPOINTS:

	mov dl, [POINTS_MULTIPLIER]
	mul dl
	add [points], ax
	pop bx

	; RESTORE LIFE
	
	cmp [health], 84
	ja @@SET100
	
	mov al, [LIFE_RESTORE]
	add [health], al
	
	jmp @@CONT_CHECK
	
@@SET100:
	
	mov [health], 100
	
@@CONT_CHECK:

	CALL gen_eligable_fish_pos
	
	mov [es:bx], ax

	push cx ; FISH NUMBER
	push ax ; FISH POSITION
	CALL set_fish_type
	
@@CONTINUE:
	
	loop @@UPDATE
	
	; End temporary
	pop es
	
	ret
	
endp check_eat

; Sets fish biome, ES HAS TO BE POINTED TO EXTRA
; P1: Fish number, P2: Fish position
proc set_fish_type
	
	; 	; ; Byte for fish type	
; 	; ; 0 = NORMAL(1st fish png), 1 = ICE CAVE FISH(3rd fish png), 2 = ALIEN CAVE FISH(4th fish png), 3 = SEWER CAVE FISH(2nd fish png)
; 	; fish_type db MAX_FISH dup(0)
	
	push bp

	mov bp, sp

	num equ [bp+6]
	pos equ [bp+4]

	mov bx, num
	dec bx ; num - 1
	add bx, offset fish_type
	
	push pos
	CALL pix_to_coords ; dx = x, ax = y

	push cx
	
	mov cx, 4

@@CHECKIFINSPECIALBIOME:
	
	push bx

	mov bx, cx
	dec bx
	shl bx, 3 ; times 8 because double
	add bx, offset biome_pos
	
	cmp dx, [bx]
	jb @@NO
	cmp dx, [bx+4]
	ja @@NO

	cmp ax, [bx+2]
	jb @@NO
	cmp ax, [bx+6]
	ja @@NO
	
	mov bx, cx
	dec bx
	add bx, offset biome_type ;  0 = ICE CAVE (WHITE AND BLUE), 1 = PURPLE BLACK ALIEN VOID CAVE, 2 = GREEN SEWER CAVE
	
	mov dl, [bx]
	inc dl ; to make it compatible with fish type
	
	pop bx
	
	mov [es:bx], dl
	
	jmp @@FOUND
	
@@NO:

	pop bx
	
	loop @@CHECKIFINSPECIALBIOME

	; Means not in special biome

	mov [byte ptr es:bx], 0

@@FOUND:

	pop cx
	
	pop bp

	ret 4

endp set_fish_type

; RETURNS NEW FISH POSITION IN WORLD IN AX
proc gen_eligable_fish_pos

	push bx
	push dx

@@PLACE_FISH:

	push 0
	push [world_size]
	CALL seed_rand_64

	mov bx, ax
	add bx, offset pixels
	
	; radius check
	
	mov dl, 1
	; Middle
	cmp [bx], dl
	jz @@PLACE_FISH

	; Right
	cmp [bx+1], dl
	jz @@PLACE_FISH

	; Left
	cmp [bx-1], dl
	jz @@PLACE_FISH

	; Bot
	cmp [bx+320], dl
	jz @@PLACE_FISH

	; Top
	cmp [bx-320], dl
	jz @@PLACE_FISH

	; TL
	cmp [bx-321], dl
	jz @@PLACE_FISH
	; TR
	cmp [bx-319], dl
	jz @@PLACE_FISH
	
	; BR
	cmp [bx+321], dl
	jz @@PLACE_FISH
	; BL
	cmp [bx+319], dl
	jz @@PLACE_FISH

	pop dx
	pop bx

	ret

endp gen_eligable_fish_pos

proc init
	
	; Graphic mode
	mov ax, 13h 
	int 10h
	
	; set booleans to false
	mov [word ptr isOptions], 0
	mov [word ptr isDone], 0
	mov [word ptr isStart], 0
	
	mov [byte ptr health], 100
	
	mov [word ptr points], 0
	
	mov [word ptr world_pos], 0
	
	mov [word ptr SHARKX], 0
	mov [word ptr SHARKY], 0
	
	; Calculate Screen size over resolutionx for draw
	mov ax, 320
	mov bx, [resx]
	
	xor dx, dx
	div bx
	mov [wdth], ax
	
	mov bx, 2
	div bx
	mov [hwdth], ax
	
	; Calc res2x
	mov ax, [resx]
	shl ax, 1
	mov [res2x], ax
	
	; Calculate Screen size over resolutiony for draw
	mov ax, 200
	mov bx, [resy]
	
	xor dx, dx
	div bx
	mov [hght], ax
	
	mov bx, 2
	div bx
	mov [hhght], ax
	
	; Calc res2y
	mov ax, [resy]
	shl ax, 1
	mov [res2y], ax
	
	; Set shark position
	mov ax, [hwdth]
	mov [SHARKX], ax
	
	mov ax, [hhght]
	mov [SHARKY], ax
	
	cmp [word ptr isSeedCustom], 1
	jz @@SKIPRANDSEED

	; Generate random seed
	CALL rand
	mov al, dl
	
	mov ah, bl
	mov [seed], ax

@@SKIPRANDSEED:

	CALL init_rand ; Initializes pixel array with random values
	
	CALL automata ; Initializes pixels with cellular automata

	CALL gen_biomes ; Generate world biomes

	CALL gen_seaweed ; Generate seeweed in world

	CALL gen_fish ; Generate fish in world
	
	; Set tl in world (make sure you don't spawn inside cave block)
	CALL determine_start_pos
	
	; es points to graphics
	CALL es_to_draw
	
	; Draws cave grid

	CALL draw_cave
	
	; Draws shark
	
	mov [BmpLeft], 160-25
	mov [BmpTop], 100-9
	mov [BmpColSize], SHARK_WIDTH
	mov [BmpRowSize], SHARK_HEIGHT
	mov dx, offset SHARK_RIGHT
	CALL OpenShowBmp
	
	CALL sync_clock ; Synchronize internal clock ticks with program for perfect hundredths of second
	
	ret
	
endp init

; Obliterates data in dx and bx (returns 2 random numbers from 0-9)
proc rand

	push ax
	push cx
	
	MOV AH, 00h  ; interrupts to get system time        
	INT 1AH      ; CX:DX now hold number of clock ticks since midnight      

	mov  ax, dx
	xor  dx, dx
	mov  cx, 10    
	div  cx       ; here dx contains the remainder of the division - from 0 to 9
	
	mov bx, dx ; Move rand 1 to bl
	
	div cx ; here dx contains the remainder of the division - from 0 to 9
	
	pop cx
	pop ax
	
	; Random number 1 is in bl, random number 2 is in dl
	ret
endp rand

; Initializes pixel array with random values
proc init_rand
	
	mov cx, [world_size]
	xor si, si
	
rand_step:
	
	; Prime random algorithm: current_seed * primea + primeb = current_seed

	CALL seed_rand

	cmp dx, [chance_for_black]
	jbe zero_dot
one_dot:

	; Current pixel in si
	mov [pixels+si], 1
	
	jmp continue
zero_dot:
	
	; Current pixel in si
	mov [pixels+si], 0
	
continue:
	
	inc si
	loop rand_step
	
	ret
	
endp init_rand

proc automata
	
	xor cx, cx
	mov cl, [num_of_steps]
	
step:
	push cx
	xor si, si ; Pixels pointer

	push [world_size]
	CALL pix_to_coords
	
	mov cx, ax ; cx = Y
	
geny:
	
	push cx
	mov cx, 320
	xor bx, bx ; Pixels_Temp pointer
	
genx:
	
	push si
	CALL pix_to_coords
	
	push dx
	push ax
	CALL check_neighbors
	
	mov ah, [pixels+si]
	
	mov [pixels_temp+320+bx], ah
	
	cmp ah, 1 ; Check if cell is alive
	je alive_check
	
	; Dead check
	
	cmp al, [birth_limit]
	jbe next_gen
	
	mov [byte ptr pixels_temp+320+bx], 1
	
	jmp next_gen
	
alive_check:

	cmp al, [death_limit]
	jae next_gen
	
	mov [byte ptr pixels_temp+320+bx], 0

next_gen:
	inc si
	inc bx
	
	loop genx
	
	xor bx, bx ; Pixels_Temp pointer
	
	mov cx, 320 ; temp[0-320] to pixels[row-320+bx] temp[320-640] => temp[0-320]
	
replace320:
	
	cmp si, 320
	jz @@ITER0 ; ( don't do first step if in first iteration )
	
	cmp si, [world_size]
	jnz @@NOTFINAL
	
	mov ah, [pixels_temp+320+bx]
	
	mov [pixels+si+bx-320], ah
	
	jmp @@CONTINUE
	
@@NOTFINAL:
	
	mov ah, [pixels_temp+bx]
	
	mov [pixels+si+bx-640], ah

@@ITER0:
	mov ah, [pixels_temp+320+bx]
	
	mov [pixels_temp+bx], ah

@@CONTINUE:

	inc bx
	loop replace320

	pop cx
	loop geny

	pop cx
	loop step
	
	ret
	
endp automata
	
; CURRENT PIXEL NEEDS TO BE IN SI
; P1: X, P2: Y, OUTPUT: num of neighbors of cell in al
proc check_neighbors
	
	push bp
	mov bp, sp
	
	X equ [bp+6]
	Y equ [bp+4]
	
	; X = Neighbor, O = Cell
	; =================
	;	X     X     X
	;	X     O     X
	;	X     X     X
	; =================
	
	push bx
	push cx
	push dx
	push di
	
	xor ax, ax ; Living neighbor counter
	
	mov bx, X ; bx holds current X
	mov dx, Y ; dx holds current Y
	
	; Check if top available
	cmp dx, 0
	jz after_tr
	
	; Check if top left available
	cmp bx, 0
	jz after_tl
	
	add al, [pixels+si-321] ; Top Left

after_tl:
	
	add al, [pixels+si-320] ; Top Middle
	
after_tm:
	
	; Check if top right available
	cmp bx, 319
	jz after_tr
	
	add al, [pixels+si-319] ; Top Right

after_tr:
	
	; Check if bottom available
	mov di, si
	add di, 320
	cmp di, [world_size] ; Check if bottom left available 
	jae after_br
	
	; Check if bottom left available
	cmp bx, 0
	jz after_bl
	
	add al, [pixels+si+319] ; Bottom left

after_bl:
	
	add al, [pixels+si+320] ; Bottom Middle

after_bm:

	; Check if bottom right available
	
	cmp bx, 319
	jz after_br

	add al, [pixels+si+321] ; Bottom Right

after_br:

	; Check if middle left available
	cmp bx, 0
	jz after_ml
	
	add al, [pixels+si-1] ; Middle Left

after_ml:

	; Check if middle right available
	cmp bx, 319
	jz after_mr
	
	add al, [pixels+si+1] ; Middle Right

after_mr:
	
	pop di
	pop dx
	pop cx
	pop bx
	
	pop bp
	
	ret 4
	
endp check_neighbors

proc gen_biomes

	mov cx, 4

@@GEN:
	
	mov bx, cx
	sub bx, 1
	shl bx, 3 ; times 8 because double
	add bx, offset biome_pos

	CALL set_biome_coordinates
	
	mov bx, cx
	sub bx, 1
	add bx, offset biome_type

@@TRYAGAINTYPE:
	CALL seed_rand ; returns dx 0-9

	mov [bx], dl

	cmp dl, 2
	ja @@TRYAGAINTYPE

	loop @@GEN

	ret

endp gen_biomes

; BIOME COORDS POS IN MEMORY HAS TO BE IN BX
proc set_biome_coordinates
	
	push 0
	push 320-(100+45)/2
	CALL seed_rand_64 ; returns ax rand

	mov [bx], ax ;x1

	push 0
	push 186-(100+45)/2
	CALL seed_rand_64 ; returns ax rand
	
	mov [bx+2], ax ;y1
	
	push 45
	push 100
	CALL seed_rand_64 ; returns ax rand
	
	mov [bx+4], ax
	
	mov ax, [bx]
	add [bx+4], ax ; x2+x1
	
	push 45
	push 100
	CALL seed_rand_64 ; returns ax rand
	
	mov [bx+6], ax
	
	mov ax, [bx+2]
	add [bx+6], ax ; y2+y1
	
	ret
	
endp set_biome_coordinates

; Generates seaweed and rocks
proc gen_seaweed
	
	xor ax, ax ; How many seaweeds placed

@@AGAIN:
	mov bx, offset pixels ; World counter
	add bx, 320 ; Start from Y = 1

	mov cx, 186 ; 187 - 1

@@Y:
	
	push cx
	mov cx, 320 ; RESET X 

@@X:

	mov dl, 0
	cmp [bx], dl
	jnz @@NOT
	
	cmp [bx-1], dl
	jnz @@NOT
	
	cmp [bx+1], dl
	jnz @@NOT
	
	cmp [bx-320], dl
	jnz @@NOT
	
	cmp [bx+321], dl
	jz @@NOT

	cmp [bx+319], dl
	jz @@NOT

	cmp [bx+320], dl
	jz @@NOT

	; Roll dice to place seaweed there

	; Prime random algorithm: current_seed * primea + primeb = current_seed
	CALL seed_rand

	cmp dx, 1
	ja @@NOT


	; Made it through dice roll

	mov si, bx

	mov bx, ax
	shl bx, 1 ; times 2 because of data word
	add bx, offset seaweed_pos

	sub si, offset pixels
	mov [bx], si
	add si, offset pixels

	mov bx, si

	inc ax

	cmp ax, TOTAL_SEEWEEDS
	jz @@END

@@NOT:
	
	inc bx

	loop @@X

	pop cx

	loop @@Y

	jmp @@AGAIN

@@END:
	
	pop cx

	ret

endp gen_seaweed

proc gen_fish
	
	; Temporary
	push es
	CALL es_to_extra

	mov cx, [TOTAL_FISH]

@@PLACE_FISH:
	
	; Roll dice for fish world placement

	push bx

	mov bx, cx
	dec bx ; cx - 1 for no overflow
	shl bx, 1 ; times 2 because of data word
	add bx, offset fish_pos

	CALL gen_eligable_fish_pos

	mov [es:bx], ax
	
	push cx ; FISH NUMBER
	push ax ; FISH POSITION
	CALL set_fish_type
	
	pop bx

	loop @@PLACE_FISH

	; End temporary
	pop es
	
	ret

endp gen_fish

; DETERMINES START POSITION FOR SHARK
proc determine_start_pos
	
	mov ax, [SHARKX]
	shr ax, 1
	push ax
	
	mov ax, [SHARKY]
	shr ax, 1
	push ax
	CALL coords_to_pix
	
	mov bx, offset pixels
	add bx, ax
	
	mov al, 1

	jmp @@AGAIN

@@INC:
	
	inc [world_pos]
	inc bx
	
@@AGAIN:

	; Middle
	cmp [bx], al
	jz @@INC

	; Right
	cmp [bx+1], al
	jz @@INC

	; Left
	cmp [bx-1], al
	jz @@INC

	; Bot
	cmp [bx+320], al
	jz @@INC

	; Top
	cmp [bx-320], al
	jz @@INC

	; TL
	cmp [bx-321], al
	jz @@INC
	; TR
	cmp [bx-319], al
	jz @@INC
	
	; BR
	cmp [bx+321], al
	jz @@INC
	; BL
	cmp [bx+319], al
	jz @@INC

	ret
	
endp determine_start_pos

; Draws pixel grid
proc draw_grid
	
	mov cx, 187
	shr cx, 1
	mov si, 0
	xor dx, dx ; X counter
	xor bx, bx ; Y counter

@@Y:
	
	push cx
	push si
	mov cx, 160
	
@@X:
	; Current pixel in si
	mov al, [pixels+si]
	
	cmp al, 1
	jnz black
white:
	mov al, 0Fh
	jmp draw
black:
	mov al, 0
draw:

	; Draw rectangle according to resolution
	push dx
	push bx
	push 2;1
	push 2;1
	xor ah, ah
	push ax
	CALL draw_rect
	
	inc si
	add dx, 2

	loop @@X
	
	pop si
	pop cx
	
	xor dx, dx
	add bx, 2

	add si, 320

	loop @@Y
	
	ret

endp draw_grid

; DRAWS EMPTY RECTANGLE ON SCREEN

; P1: X, P2: Y, P3: W, P4: H, P5: Border Thickness, P5: Border Color
proc draw_erect
	
	push bp
	
	mov bp, sp
	
	X equ [bp+14]
	Y equ [bp+12]
	W equ [bp+10]
	H equ [bp+8]
	BThickness equ [bp+6]
	Color equ [bp+4]
	
	push ax
	
	push X
	push Y
	push W
	push BThickness
	push Color
	call draw_rect
	
	push X
	push Y
	push BThickness
	push H
	push Color
	call draw_rect
	
	push X
	mov ax, Y
	add ax, H
	push ax
	mov ax, W
	add ax, BThickness
	push ax
	push BThickness
	push Color
	call draw_rect
	
	mov ax, X
	add ax, W
	
	push ax
	push Y
	push BThickness
	push H
	push Color
	call draw_rect
	
	pop ax
	
	pop bp
	
	ret 12
	
endp draw_erect

; DRAWS RECTANGLE ON SCREEN

; P1: X, P2: Y, P3: WIDTH, P4: HEIGHT, P5: COLOR
proc draw_rect

	push bp
	
	mov bp, sp
	
	x equ [bp+12]
	y equ [bp+10]
	w equ [bp+8]
	h equ [bp+6]
	color equ [bp+4]
	
	push ax
	push cx
	push di
	
	push x
	push y
	call coords_to_pix
	
	mov di, ax
	
	mov ax, color
	
	mov cx, h
	
@@Y:
	
	push di
	push cx
	mov cx, w
	
@@X:
	
	stosb
	
	loop @@X
	
	pop cx
	pop di
	
	add di, 320
	
	loop @@Y
	
	pop di
	pop cx
	pop ax
	
	pop bp
	
	ret 10


endp draw_rect

; P1: pixel on screen, returns dx = x, ax = y
proc pix_to_coords
	
	push bp
	
	mov bp, sp
	
	pix equ [bp+4]
	
	
	push bx
	
	mov ax, pix
	
	; Get x coordinate
	mov bx, 320
	
	xor dx, dx
	div bx
	
	; dx contains modulo (x) ax contains rest (y)
	
	pop bx
	
	pop bp
	
	ret 2
	
endp pix_to_coords

; P1: x, P2: y, returns ax = pix
proc coords_to_pix
	push bp
	mov bp, sp
	
	x equ [bp+6]
	y equ [bp+4]
	
	push dx
	push bx
	
	mov ax, y
	
	mov bx, 320
	
	xor dx, dx
	mul bx
	
	add ax, x
	
	pop bx
	pop dx
	
	pop bp
	ret 4
endp coords_to_pix

; Prime random algorithm: current_seed * primea + primeb = current_seed
; Get 0-9 random number in dx according to seed
proc seed_rand
	
	push ax
	push bx
	
	mov ax, [seed]
	mov dx, [primea]
	mul dx
	add ax, [primeb]
	mov [seed], ax

	xor dx, dx
	mov bx, 10
	div bx
	
	pop bx
	pop ax
	
	ret
	
endp seed_rand

; Prime random algorithm: current_seed * primea + primeb = current_seed
; Get 0-65k (max ax) random number in ax according to seed
; P1: Min, P2: Max
proc seed_rand_64
	
	push bp

	mov bp, sp

	min equ [bp+6]
	max equ [bp+4]

	push dx

@@REROLL:
	mov ax, [seed]
	mov dx, [primea]
	mul dx
	add ax, [primeb]
	mov [seed], ax
	
	cmp ax, min
	jb @@REROLL
	
	cmp ax, max
	ja @@REROLL

	pop dx
	
	pop bp

	ret 4

endp seed_Rand_64

; Description  : get RND between any bl and bh includs (max 0 -255)
; Input        : 1. Bl = min (from 0) , BH , Max (till 255)
; 			     2. RndCurrentPos a  word variable,   help to get good rnd number
; 				 	Declre it at DATASEG :  RndCurrentPos dw ,0
;				 3. EndOfCsLbl: is label at the end of the program one line above END start		
; Output:        Al - rnd num from bl to bh  (example 50 - 150)
; More Info:
; 	Bl must be less than Bh 
; 	in order to get good random value again and agin the Code segment size should be 
; 	at least the number of times the procedure called at the same second ... 
; 	for example - if you call to this proc 50 times at the same second  - 
; 	Make sure the cs size is 50 bytes or more 
; 	(if not, make it to be more) 
proc RandomByCs
    push es
	push si
	push di
	
	mov ax, 40h
	mov	es, ax
	
	sub bh,bl  ; we will make rnd number between 0 to the delta between bl and bh
			   ; Now bh holds only the delta
	cmp bh,0
	jz @@ExitP
 
	mov di, [word RndCurrentPos]
	call MakeMask ; will put in si the right mask according the delta (bh) (example for 28 will put 31)
	
RandLoop: ;  generate random number 
	mov ax, [es:06ch] ; read timer counter
	mov ah, [byte cs:di] ; read one byte from memory (from semi random byte at cs)
	xor al, ah ; xor memory and counter
	
	; Now inc di in order to get a different number next time
	inc di
	cmp di,(EndOfCsLbl - start - 1)
	jb @@Continue
	mov di, offset start
@@Continue:
	mov [word RndCurrentPos], di
	
	and ax, si ; filter result between 0 and si (the nask)
	cmp al,bh    ;do again if  above the delta
	ja RandLoop
	
	add al,bl  ; add the lower limit to the rnd num
		 
@@ExitP:	
	pop di
	pop si
	pop es
	ret
endp RandomByCs

; Input        : 1. BX = min (from 0) , DX, Max (till 64k -1)
; 			     2. RndCurrentPos a  word variable,   help to get good rnd number
; 				 	Declre it at DATASEG :  RndCurrentPos dw ,0
;				 3. EndOfCsLbl: is label at the end of the program one line above END start		
; Output:        AX - rnd num from bx to dx  (example 50 - 1550)
; More Info:
; 	BX  must be less than DX 
; 	in order to get good random value again and again the Code segment size should be 
; 	at least the number of times the procedure called at the same second ... 
; 	for example - if you call to this proc 50 times at the same second  - 
; 	Make sure the cs size is 50 bytes or more 
; 	(if not, make it to be more) 
proc RandomByCsWord
    push es
	push si
	push di
 
	
	mov ax, 40h
	mov	es, ax
	
	sub dx,bx  ; we will make rnd number between 0 to the delta between bl and bh
			   ; Now bh holds only the delta
	cmp dx,0
	jz @@ExitP
	
	push bx
	
	mov di, [word RndCurrentPos]
	call MakeMaskWord ; will put in si the right mask according the delta (bh) (example for 28 will put 31)
	
@@RandLoop: ;  generate random number 
	mov bx, [es:06ch] ; read timer counter
	
	mov ax, [word cs:di] ; read one word from memory (from semi random bytes at cs)
	xor ax, bx ; xor memory and counter
	
	; Now inc di in order to get a different number next time
	inc di
	inc di
	cmp di,(EndOfCsLbl - start - 2)
	jb @@Continue
	mov di, offset start
@@Continue:
	mov [word RndCurrentPos], di
	
	and ax, si ; filter result between 0 and si (the nask)
	
	cmp ax,dx    ;do again if  above the delta
	ja @@RandLoop
	pop bx
	add ax,bx  ; add the lower limit to the rnd num
		 
@@ExitP:
	
	pop di
	pop si
	pop es
	ret
endp RandomByCsWord

; make mask acording to bh size 
; output Si = mask put 1 in all bh range
; example  if bh 4 or 5 or 6 or 7 si will be 7
; 		   if Bh 64 till 127 si will be 127
Proc MakeMask    
    push bx

	mov si,1
    
@@again:
	shr bh,1
	cmp bh,0
	jz @@EndProc
	
	shl si,1 ; add 1 to si at right
	inc si
	
	jmp @@again
	
@@EndProc:
    pop bx
	ret
endp  MakeMask

Proc MakeMaskWord    
    push dx
	
	mov si,1
    
@@again:
	shr dx,1
	cmp dx,0
	jz @@EndProc
	
	shl si,1 ; add 1 to si at right
	inc si
	
	jmp @@again
	
@@EndProc:
    pop dx
	ret
endp  MakeMaskWord

; Draws marching squares
proc draw_cave
	
	push ax
	push bx
	push cx
	push dx
	
	xor dx, dx ; X counter
	xor bx, bx ; Y counter
	
	mov cx, [hhght]

	mov si, [world_pos]
	
march_row:
	
	push cx
	push si
	mov cx, [hwdth]
	
march_col:
	
	xor ax, ax
	; Current pixel in si
    mov al, [pixels+si]
	shl al, 1 ; 00 | 01h - > 00 | 10h
    add al, [pixels+si+1] ; 00 | 10h - > 00 | 11h
	shl al, 1 ; 00 | 11h - > 01 | 10h
    add al, [pixels+si+321] ; 01 | 10h - > 01 | 11h
	shl al, 1 ; 01 | 11h - > 11 | 10h
    add al, [pixels+si+320]
    
    ; Algorithm Section
    ; =================
    ; 
	;	What you see before is byte shifting the bytes
	;	To fit the algorithm of marching squares
	;
    ; =================
	
    ; 0FCh = light Blue
    ; 0F->E->D->C0h = Descending brightness Blue

    push bx
    push dx

	push dx
	push bx

	CALL choose_cave_bg ; returns dx bg color, bx fg color

	push bx;049h;0FFh

	push dx;01
	push ax
	
	CALL march_switch

	pop dx
	pop bx

	cmp dx, 0
	jz @@SKIPSEAWEED

	push dx
	push bx
	push TOTAL_SEEWEEDS
	CALL draw_seaweed
	
	@@SKIPSEAWEED:
	push dx
	push bx
	push [TOTAL_FISH]
	CALL draw_fish
	
	add dx, [res2x]

	inc si
	loop march_col
	
	pop si
	
	add si, 320

	add bx, [res2y] ; INCREMENT Y
	
	xor dx, dx ; RESET X
	
	pop cx
	loop march_row
	
	pop dx
	pop cx
	pop bx
	pop ax
	
	ret

endp draw_cave

; CHOOSES CAVE BACKGROUND COLOR ACCORDING TO DEPTH
; CURRENT ITER WORLD POSITION IN SI
; RETURNS BG COLOR IN DX, FG COLOR IN BX
proc choose_cave_bg
	
	push ax
	push cx

	; CHECK IF SPECIAL BIOME

	; 	; HOLDS BIOME TL, BR (Double for each biome)
	; ; TOTAL OF 3 SPECIAL BIOMES, EACH WORLD CONTAINS 4 (MAYBE NOT UNIQUE) BIOMES (SIZE AND LOCATION DEPENDS ON SEED)

	; biome_pos dd 4 dup(?)

	; ; BIOME TYPES FOR EACH GENERATED BIOME

	; ; 0 = ICE CAVE (WHITE AND BLUE), 1 = PURPLE BLACK ALIEN VOID CAVE, 2 = GREEN SEWER CAVE

	; biome_type db 4 dup(?)

	push si
	CALL pix_to_coords ; dx = x, ax = y
	
	mov cx, 4

@@CHECK_IF_BIOME:

	mov bx, cx
	sub bx, 1
	shl bx, 3 ; times 8 because dd
	add bx, offset biome_pos

	cmp dx, [bx]
	jb @@CONT
	cmp dx, [bx+4]
	ja @@CONT
	cmp ax, [bx+2]
	jb @@CONT
	cmp ax, [bx+6]
	ja @@CONT

	 mov bx, cx
	 dec bx
	 add bx, offset biome_type

	 cmp [byte ptr bx], 0 ; Ice caves
	 jz @@ICE

	 cmp [byte ptr bx], 1 ; Alien caves
	 jz @@ALIEN

	 cmp [byte ptr bx], 2 ; Sewer caves
	 jz @@SEWER

@@ICE:

	mov bx, 09h
	mov dx, 0FFh
	jmp @@end

@@ALIEN:
	
	mov bx, 05h
	mov dx, 00h
	jmp @@end

@@SEWER:

	mov bx, 40h
	mov dx, 06h
	jmp @@end

@@CONT:

	loop @@CHECK_IF_BIOME

	push si
	CALL pix_to_coords

	; returns dx = x, ax = y
	; world height is 187

	cmp ax, 31 ; first 1/6 of cave
	jbe @@sixth

	cmp ax, 62
	jbe @@2sixths

	cmp ax, 93
	jbe @@3sixths

	cmp ax, 124
	jbe @@4sixths

	cmp ax, 155
	jbe @@5sixths

	cmp ax, 187
	jbe @@last

@@sixth:
	mov bx, 0F7h
	mov dx, 0F0h
	jmp @@end
@@2sixths:
	mov bx, 0F7h
	mov dx, 0E0h
	jmp @@end
@@3sixths:
	mov bx, 0F7h
	mov dx, 0D0h
	jmp @@end
@@4sixths:
	mov bx, 0F8h
	mov dx, 0C0h
	jmp @@end
@@5sixths:
	mov bx, 0F8h
	mov dx, 080h
	jmp @@end
@@last:
	mov bx, 0F8h
	mov dx, 00h
@@end:
	
	pop cx
	pop ax

	ret

endp choose_cave_bg

; Draws seaweed (if available) on the map
; CURRENT WORLD POS IN SI
; P1: X, P2: Y, P3: Seaweed amount
proc draw_seaweed
	
	push bp

	mov bp, sp

	x equ [bp+8]
	y equ [bp+6]
	len equ [bp+4]

	push ax
	push bx
	push cx
	push dx
	push si
	push [bmpLeft]
	push [bmpTop]
	push [BmpColSize]
	push [BmpRowSize]

	mov cx, len

@@CHECKWEED:

	mov bx, cx
	dec bx ; cx - 1 since cx start at full len and ends at 1
	shl bx, 1 ; times 2
	add bx, offset seaweed_pos

	cmp [bx], si
	jnz @@CONTCHECK

	; It is a seaweed

	xor dx, dx
	mov ax, si
	mov bx, 10
	div bx

	cmp dx, 3
	ja @@SEAWEED

	; Draw rock
	mov ax, x
	mov [bmpLeft], ax
	mov ax, y
	sub ax, 21
	mov [bmpTop], ax
	mov [BmpColSize], 40
	mov [BmpRowSize], 40
	mov dx, offset ROCK_PIC

	jmp @@DRAW

@@SEAWEED:
	
	; Draw seaweed
	mov ax, x
	mov [bmpLeft], ax
	mov ax, y
	sub ax, 61
	mov [bmpTop], ax
	mov [BmpColSize], 40
	mov [BmpRowSize], 80
	mov dx, offset SEAWEED_PIC

@@DRAW:
	CALL OpenShowBmp

@@CONTCHECK:

	loop @@CHECKWEED

	pop [BmpRowSize]
	pop [BmpColSize]
	pop [bmpTop]
	pop [bmpLeft]
	pop si
	pop dx
	pop cx
	pop bx
	pop ax

	pop bp

	ret 6

endp draw_seaweed

; Draws fish (if available) on the map
; CURRENT WORLD POS IN SI
; P1: X, P2: Y, P3: Fish amount
proc draw_fish
	
	push bp

	mov bp, sp

	x equ [bp+8]
	y equ [bp+6]
	len equ [bp+4]

	push ax
	push bx
	push cx
	push dx
	push si
	push [bmpLeft]
	push [bmpTop]
	push [BmpColSize]
	push [BmpRowSize]
	
	; Temporary
	push es
	CALL es_to_extra
	
	mov cx, len

@@CHECKFISH:

	mov bx, cx
	dec bx ; cx - 1 since cx start at full len and ends at 1
	shl bx, 1 ; times 2
	add bx, offset fish_pos

	cmp [es:bx], si
	jnz @@CONTCHECK
	
	; It is a fish
	
	; Draw fish
	mov ax, x
	mov [bmpLeft], ax
	mov ax, y
	mov [bmpTop], ax
	mov [BmpColSize], 40
	mov [BmpRowSize], 40
	
	mov bx, cx
	dec bx
	add bx, offset fish_dir
	
	push x
	push y

	; push fish direction
	xor ah, ah
	mov al, [byte ptr es:bx]
	push ax
	
	; push fish type
	mov bx, cx
	dec bx
	add bx, offset fish_type

	xor ah, ah
	mov al, [byte ptr es:bx]
	push ax
	
	CALL es_to_draw ; For fish draw
	
	CALL draw_single_fish
	
	CALL es_to_extra ; Return back
	
@@CONTCHECK:

	loop @@CHECKFISH
	
	; End temporary
	pop es
	
	pop [BmpRowSize]
	pop [BmpColSize]
	pop [bmpTop]
	pop [bmpLeft]
	pop si
	pop dx
	pop cx
	pop bx
	pop ax

	pop bp

	ret 6

endp draw_fish

; Draws a single fish sprite
; P1: X, P2: Y, P3: Dir, P4: Type
proc draw_single_fish
	
	push bp
	
	mov bp, sp
	
	x equ [bp+10]
	y equ [bp+8]
	dir equ [bp+6]
	fishtype equ [bp+4]

	; 0 = NORMAL(1st fish png), 1 = ICE CAVE FISH(3rd fish png), 2 = ALIEN CAVE FISH(4th fish png), 3 = SEWER CAVE FISH(2nd fish png)

	mov ax, fishtype
	add al, '0' ; num to ascii

	mov [FISH_LEFT+5], al
	mov [FISH_RIGHT+5], al
	mov [FISH_UP+5], al
	mov [FISH_DOWN+5], al

	mov ax, 0
	cmp dir, ax
	jz @@LEFT
	
	mov al, 1
	cmp dir, ax
	jz @@UP
	
	mov al, 2
	cmp dir, ax
	jz @@RIGHT
	
	mov al, 3
	cmp dir, ax
	jz @@DOWN
	
@@LEFT:

	mov dx, offset FISH_LEFT
	
	jmp @@DRAW

@@UP:

	mov dx, offset FISH_UP
	
	jmp @@DRAW
	
@@RIGHT:

	mov dx, offset FISH_RIGHT
	
	jmp @@DRAW
	
@@DOWN:

	mov dx, offset FISH_DOWN

@@DRAW:

	CALL OpenShowBmp
	 
	pop bp
	 
	ret 8
	
endp draw_single_fish

; SWITCH ALGORITHM FOR MARCHING SQUARES 0 BINARY - 15 BINARY AND DRAWS TO SCREEN

; P1: X, P2: Y, P3: FCOLOR, P4: BColor, P5: STATE
proc march_switch
	
	push bp
	
	mov bp, sp
	
	X equ [bp+12]
	Y equ [bp+10]
	Color equ [bp+8]
	BColor equ [bp+6]
	State equ [bp+4]
	
	push ax
	push bx
	push dx
	
	mov ax, State

	; Clear area
	push X
	push Y
	push [res2x]
	push [res2y]
	push BColor ; black
	call draw_rect
	
	cmp al, 0
	jnz after_zero
	
	jmp @@End

after_zero:
	cmp al, 15
	jnz after_15
	
	; White Square
	
	push X
	push Y
	push [res2x]
	push [res2y]
	push Color ; white
	call draw_rect
	
	jmp @@End
	
after_15:

	cmp al, 1
	
	jnz after1
	
	; Bottom Left Triangle
	
	push X
	
	mov dx, Y
	add dx, [resy]
	
	push dx
	push [resx]
	push [resy]
	push Color ; white
	push 3 ; bl
	call draw_rtriangle
	
	jmp @@End
	
after1:

	cmp al, 2
	
	jnz after2
	
	; Bottom Right Triangle
	
	mov dx, X
	add dx, [resx]
	
	push dx
	
	mov dx, Y
	add dx, [resy]
	
	push dx
	push [resx]
	push [resy]
	push Color ; white
	push 2 ; br
	call draw_rtriangle
	
	jmp @@End
	
after2:
	cmp al, 3
	
	jnz after3
	
	; Bottom rectangle
	
	push X
	
	mov dx, Y
	add dx, [resy]
	
	push dx
	
	push [res2x]
	push [resy]
	push Color ; white
	call draw_rect
	
	jmp @@End
	
after3:

	cmp al, 4
	
	jnz after4
	
	; Top Right Triangle
	
	mov dx, X
	add dx, [resx]
	
	push dx
	
	push Y
	push [resx]
	push [resy]
	push Color ; white
	push 1
	call draw_rtriangle
	
	jmp @@End
	
after4:
	cmp al, 5
	
	jnz after5
	
	; Square with Top Left And Bottom Right Triangle missing
	
	push X
	push Y
	push [res2x]
	push [res2y]
	push Color
	call draw_rect
	
	push X
	push Y
	push [resx]
	push [resy]
	push BColor ; white
	push 0 ; tl
	call draw_rtriangle
	
	mov dx, X
	add dx, [resx]
	
	push dx
	
	mov dx, Y
	add dx, [resy]
	
	push dx
	push [resx]
	push [resy]
	push BColor ; white
	push 2 ; br
	call draw_rtriangle
	
	jmp @@End
	
after5:
	cmp al, 6
	
	jnz after6
	
	; Right Rectangle
	
	mov dx, X
	add dx, [resx]
	
	push dx
	
	push Y
	
	push [resx]
	
	push [res2y]
	
	push Color ; white
	
	call draw_rect
	
	jmp @@End
	
after6:
	cmp al, 7
	
	jnz after7
	
	; Square with Top Left Missing
	
	push X
	push Y
	push [res2x]
	push [res2y]
	push Color ; white
	call draw_rect
	
	push X
	push Y
	push [resx]
	push [resy]
	push BColor ; black
	push 0 ; tl
	call draw_rtriangle
	
	jmp @@End
	
after7:
	cmp al, 8
	
	jnz after8
	
	; Top left triangle
	
	push X
	push Y
	push [resx]
	push [resy]
	push Color ; white
	push 0 ; tl
	call draw_rtriangle
	
	
	jmp @@End
	
after8:
	cmp al, 9
	
	jnz after9
	
	; Left Rectangle
	
	push X
	push Y
	push [resx]
	push [res2y]
	push Color ; white
	call draw_rect
	
	jmp @@End
	
after9:
	cmp al, 10
	
	jnz after10
	
	; Square with Top Right and Bottom Left Triangles missing
	
	push X
	push Y
	push [res2x]
	push [res2y]
	push Color
	call draw_rect
	
	push X
	
	mov dx, Y
	add dx, [resy]
	
	push dx
	
	push [resx]
	push [resy]
	push BColor
	push 3 ; bl
	call draw_rtriangle
	
	mov dx, X
	add dx, [resx]
	
	push dx
	
	push Y
	
	push [resx]
	push [resy]
	push BColor
	push 1 ; tr
	call draw_rtriangle
	
	jmp @@End
	
after10:
	cmp al, 11
	
	jnz after11
	
	; Full Rectangle with top right missing
	
	push X
	push Y
	push [res2x]
	push [res2y]
	push Color ; white
	call draw_rect
	
	mov dx, X
	add dx, [resx]
	
	push dx
	
	push Y
	
	push [resx]
	push [resy]
	push BColor ; black
	push 1 ; tr
	call draw_rtriangle
	
	jmp @@End
	
after11:

	cmp al, 12
	
	jnz after12
	
	; Top Rectangle
	
	push X
	push Y
	push [res2x]
	push [resy]
	push Color ; white
	call draw_rect
	
	jmp @@End
	
after12:
	cmp al, 13
	
	jnz after13
	
	; Full Rectangle with bottom right missing
	
	push X
	push Y
	push [res2x]
	push [res2y]
	push Color ; white
	call draw_rect
	
	mov dx, X
	add dx, [resx]
	
	push dx
	
	mov dx, Y
	add dx, [resy]
	
	push dx
	
	push [resx]
	push [resy]
	push BColor ; black
	push 2 ; br
	call draw_rtriangle
	
	
	jmp @@End
	
after13:
	
	; Full Rectangle with bottom left missing
	
	push X
	push Y
	push [res2x]
	push [res2y]
	push Color ; white
	call draw_rect
	
	push X
	
	mov dx, Y
	add dx, [resy]
	
	push dx
	
	push [resx]
	push [resy]
	push BColor ; black
	push 3 ; bl
	call draw_rtriangle
	
@@End:	
	
	pop dx
	pop bx
	pop ax
	
	pop bp

	ret 10
	
endp march_switch

; DRAWS A RIGHT TRIANGLE

; X and Y Map to top left of triangle (even if there isn't one)

; 0 - Top left 90 angle

; 1 - Top right 90 angle

; 2 - Bottom right 90 angle

; 3 - Bottom left 90 angle

; P1: X, P2: Y, P3: W, P4: H, P5: COLOR, P6: TRIANGLE TYPE (0-3)
proc draw_rtriangle
	
	push bp
	
	mov bp, sp
	
	X equ [bp+14]
	Y equ [bp+12]
	W equ [bp+10]
	H equ [bp+8]
	color equ [bp+6]
	triangle equ [bp+4]
	
	; Local variables
	WidthChange equ [bp-2]
	XChange equ [bp-4]
	
	sub sp, 4
	
	push ax
	push bx
	push cx
	push dx
	
	; Calculate width change
	mov ax, 1
	cmp triangle, ax
	jbe @@Neg_Change
	
@@Pos_Change:

	mov ax, 1
	
	jmp @@Continue
	
@@Neg_Change:
	
	mov ax, -1
	
@@Continue:
	
	mov WidthChange, ax
	
	; Calculate x change
	
	; Change start x if 1 or 2
	mov ax, 0
	cmp triangle, ax
	jz @@Neither
	
	mov ax, 3
	cmp triangle, ax
	jz @@Neither
	
	mov ax, 1
	cmp triangle, ax
	jz @@Pos_X_Change

@@Neg_X_Change:

	mov ax, -1
	
	jmp @@Continue2

@@Pos_X_Change:
	
	mov ax, 1
	
	jmp @@Continue2
	
@@Neither:
	
	mov ax, 0
	
@@Continue2:
	
	mov XChange, ax
	
	; Calculate W and X changes according to triangle
	mov ax, 3
	cmp triangle, ax
	jnz @@Continue3
	
	mov ax, 1
	mov W, ax
	
	jmp @@Continue4
	
@@Continue3:
	
	mov ax, 2
	cmp triangle, ax
	jnz @@Continue4
	
	mov ax, X
	add ax, W
	mov X, ax
	
	mov ax, 1
	mov W, ax
	
@@Continue4:
	
	mov bh, 0 ; Page 0
	mov ax, color
	mov ah, 0ch ; Interrupt number
		
	mov dx, Y
		
	mov cx, H	
	
@@Y:
	
	push cx
	mov cx, W
	
@@X:
	
	push cx
	
	add cx, X
	dec cx
	
	int 10h
	
	pop cx
	
	loop @@X
	
	pop cx
	
	inc dx
	
	; Change width
	push ax
	mov ax, W
	add ax, WidthChange
	mov W, ax
	pop ax
	
	; Change start x
	push ax
	mov ax, X
	add ax, XChange
	mov X, ax
	pop ax
	
	loop @@Y
	
	pop dx
	pop cx
	pop bx
	pop ax
	
	add sp, 4
	
	pop bp
	
	ret 12
	
endp draw_rtriangle

proc clearscrn
	
	push ax
	push bx
	push cx
	push dx

	xor cx, cx ; x counter
	xor dx, dx ; y counter
	
@@Y:

@@X:
	
	mov bh, 0 ; Page 0
	mov ah, 0ch 
	mov al, 0 ; Black
	int 10h
	
	inc cx
	
	cmp cx, 320
	jnz @@X
	
	xor cx, cx
	
	inc dx
	
	cmp dx, 200
	jnz @@Y
	
	pop dx
	pop cx
	pop bx
	pop ax
	ret
endp clearscrn

; input dx FileName
proc OpenShowBmp near
	
	call OpenBmpFile
	
	call ReadBmpHeader
	
	call ReadBmpPalette
	
	call CopyBmpPalette
	
	call  ShowBmp
	
	 
	call CloseBmpFile
	
	ret
endp OpenShowBmp

; input dx filename to open
proc OpenBmpFile	near						 
	mov ah, 3Dh
	xor al, al
	int 21h

	mov [FileHandle], ax

	ret
endp OpenBmpFile

; input [FileHandle]
proc CloseBmpFile near
	mov ah,3Eh
	mov bx, [FileHandle]
	int 21h
	ret
endp CloseBmpFile


; Read and skip first 54 bytes the Header
proc ReadBmpHeader	near					
	push cx
	push dx
	
	mov ah,3fh
	mov bx, [FileHandle]
	mov cx,54
	
	mov dx,offset Header
	int 21h
	
	pop dx
	pop cx
	ret
endp ReadBmpHeader

; Read BMP file color palette, 256 colors * 4 bytes (400h)
; 4 bytes for each color BGR (3 bytes) + null(transparency byte not supported)	
proc ReadBmpPalette near 		
	push cx
	push dx
	
	mov ah,3fh
	mov cx,400h
	
	mov dx,offset Palette
	int 21h
	
	pop dx
	pop cx
	
	ret
endp ReadBmpPalette


; Will move out to screen memory the pallete colors
; video ports are 3C8h for number of first color (usually Black, default)
; and 3C9h for all rest colors of the Pallete, one after the other
; in the bmp file pallete - each color is defined by BGR = Blue, Green and Red
proc CopyBmpPalette		near					
										
	push cx
	push dx
	
	mov si,offset Palette
	mov cx,256
	mov dx,3C8h
	mov al,0  ; black first							
	out dx,al ;3C8h
	inc dx	  ;3C9h
CopyNextColor:
	mov al,[si+2] 		; Red				
	shr al,2 			; divide by 4 Max (max is 63 and we have here max 255 ) (loosing color resolution).				
	out dx,al 						
	mov al,[si+1] 		; Green.				
	shr al,2            
	out dx,al 							
	mov al,[si] 		; Blue.				
	shr al,2            
	out dx,al 							
	add si,4 			; Point to next color.(4 bytes for each color BGR + null)				
								
	loop CopyNextColor
	
	pop dx
	pop cx
	
	ret
endp CopyBmpPalette

 
proc ShowBMP 
; BMP graphics are saved upside-down.
; Read the graphic line by line (BmpRowSize lines in VGA format),
; displaying the lines from bottom to top.
	push cx
	
	mov ax, 0A000h
	mov es, ax
	
	mov cx,[BmpRowSize]
	
 
	mov ax,[BmpColSize] ; row size must dived by 4 so if it less we must calculate the extra padding bytes
	xor dx,dx
	mov si,4
	div si
	cmp dx,0
	mov bp,0
	jz @@row_ok
	mov bp,4
	sub bp,dx

@@row_ok:	
	mov dx,[BmpLeft]
	
@@NextLine:
	push cx
	push dx
	
	mov di,cx  ; Current Row at the small bmp (each time -1)
	add di,[BmpTop] ; add the Y on entire screen
	
 
	; next 5 lines  di will be  = cx*320 + dx , point to the correct screen line
	mov cx,di
	shl cx,6
	shl di,8
	add di,cx
	add di,dx
	 
	; small Read one line
	mov ah,3fh
	mov cx,[BmpColSize]  
	add cx,bp  ; extra  bytes to each row must be divided by 4
	mov dx,offset ScrLine
	int 21h
	
	; Copy one line into video memory
	cld ; Clear direction flag, for movsb
	mov cx,[BmpColSize]  
	mov si,offset ScrLine
	
	;rep movsb ; Copy line to the screen
 @@DRAWLINE:
	
	cmp [byte ptr si], Pink
	jnz @@NOTCHARACTER
	
	inc si
	inc di
	jmp @@DontDraw
	
@@NOTCHARACTER:
	
	movsb ; Copy line to the screen
	
@@DontDraw:
	loop @@DRAWLINE
	
	pop dx
	pop cx
	
	loop @@NextLine
	
	pop cx
	ret
endp ShowBMP 

; P1: File handle, puts file length in si
proc fileLen
	
	push bp
	
	mov bp, sp
	
	handle equ [bp+4]
	
	push ax
	push bx
	push cx
	push dx
	
	mov bx, handle
	mov ah, 42h
	mov al, 2
	xor cx, cx
	xor dx, dx
	int 21h
	
	mov si, ax
	
	mov bx, handle
	mov ah, 42h
	mov al, 0
	xor cx, cx
	xor dx, dx
	int 21h
	
	pop dx
	pop cx
	pop bx
	pop ax
	
	pop bp
	
	ret 2
	
endp fileLen

proc printAxDec  
	   
       push bx
	   push dx
	   push cx
	           	   
       mov cx,0   ; will count how many time we did push 
       mov bx,10  ; the divider
   
put_next_to_stack:
       xor dx,dx
       div bx
       add dl,30h
	   ; dl is the current LSB digit 
	   ; we cant push only dl so we push all dx
       push dx    
       inc cx
       cmp ax,9   ; check if it is the last time to div
       jg put_next_to_stack

	   cmp ax,0
	   jz pop_next_from_stack  ; jump if ax was totally 0
       add al,30h  
	   mov dl, al    
  	   mov ah, 2h
	   int 21h        ; show first digit MSB
	       
pop_next_from_stack: 
       pop ax    ; remove all rest LIFO (reverse) (MSB to LSB)
	   mov dl, al
       mov ah, 2h
	   int 21h        ; show all rest digits
       loop pop_next_from_stack

	   pop cx
	   pop dx
	   pop bx
	   
       ret
endp printAxDec

EndOfCsLbl:

END start


