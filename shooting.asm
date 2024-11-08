
stack segment para 'STACK'
	db 64 dup (' ')
stack ends

data segment para 'DATA'

	win_w dw 137h                               ;window widht
	win_h dw 0C0h                               ;window height
	time db 0h                                  ;saves time
	
	plr_x dw 9dh
	plr_y dw 90h
	
	plr_sz dw 08h
	plr_velo dw 08h

	blt_sz dw 03h								;bullet static properties
	blt_spd dw 02h
	max_bullets dw 10h

	blts_x dw 11h dup(0)						;bullet variable properties
	
	blts_y dw 11h dup(0)
	blts_dir db 11h dup(0)
	enm_sz dw 0dh
	enm_x dw 0h
	enm_y dw 0h
	enm_health db 0h

	game_fin db 'Game Finished $'

data ends

code segment para 'CODE'


	main proc far
		
		assume CS:CODE,DS:DATA,SS:STACK           ;makes int commands access DS
		push DS
		mov AX, 0
		push AX
		mov AX, DATA
		mov DS, AX
		pop AX
		pop AX

		mov AL, 13h
		int 10h										;sets to video mode

		mov AH, 0c0h								;sets black bg color
		int 10h
		
		call clrscr
		call mk_enm

		mov AH, 2ch                               ;get time
		int 21h                                   ;CH = hr, CL = min, DH = sec, DL = msec


		time_loop:
			mov AH, 2ch                               ;get time
			int 21h                                   ;CH = hr, CL = min, DH = sec, DL = msec
			
			cmp DL, time
			je time_loop
		
			mov time, DL                               ;update time

			cmp enm_health, 00h
			jne dont_make_enm
			call mk_enm

			dont_make_enm:
			
			call check_shoot
			call mv_plr
			call mv_enm
			call mv_blts
			call clrscr
			call draw_plr
			call draw_blts
			call draw_enm

			jmp time_loop

		ret

	main endp


	mk_enm proc near


		cont1:
			mov AH, 2ch                               ;get time
			int 21h                                   ;CH = hr, CL = min, DH = sec, DL = msec
			mov AX, 0h
			mov AL, DL
			mov BL, 5h
			mul BL
			mov enm_x, AX
			mov enm_y, 0h
			mov enm_health, 1h
		
		ret1:
			ret


	mk_enm endp


	mv_enm proc near

		mov CX, 0h

		mv_hz:
		mov AX, enm_x
		add AX, enm_sz
		cmp plr_x, AX
		ja mv_enm_r			;move enm right
		
		mov AX, enm_x
		sub AX, plr_sz
		cmp AX, plr_x
		ja mv_enm_l			;move enm left
		inc CX
		jmp mv_vt

		mv_enm_r:

			add enm_x, 01h
			jmp mv_vt

		mv_enm_l:

			sub enm_x, 01h
			jmp mv_vt
		
		mv_vt:
		
		mov AX, enm_y
		add AX, enm_sz
		cmp plr_y, AX
		ja mv_enm_d			;move enm down

		mov AX, enm_y
		sub AX, plr_sz
		cmp AX, plr_y
		ja mv_enm_u			;move enm up
		inc CX
		jmp ret8

		mv_enm_d:	

			add enm_y, 01h
			jmp ret8

		mv_enm_u:

			sub enm_y, 01h
			jmp ret8
	
		ret8:

		cmp CX, 2h
		je crashed
		ret

		crashed:

		mov AH, 02h
		mov BH, 00h
		mov DH, 24h
		mov DL, 06h
		int 10h

		mov AH, 09h
		lea DX, game_fin								;shows that game finished
		int 21h

		lq:
		mov AH, 01h                                       ;checks if there is any input
		int 16h
		jz lq

		call exit_game
		ret

	mv_enm endp


	exit_game proc near

		mov AH, 00h
		mov AL, 02h
		int 10h

		mov AH, 4ch
		int 21h

	exit_game endp


	free_blt_mem proc near
		mov blts_dir[BP], 00h
		mov blts_x[BP], 00h
		mov blts_y[BP], 00h
		ret
	free_blt_mem endp


	mv_blts proc near

		mov BP, 00h

		l2:
		cmp blts_dir[BP], 00h			;next itr if blt dir == 0
		je inc_loop2

		mov AX, win_h					;check if blt is outside screen
		cmp blts_y[BP], 7h
		jl free_blt_mem
		cmp blts_y[BP], AX
		jg free_blt_mem

		mov AX, win_w
		cmp blts_x[BP], 7h
		jnl abc
		call free_blt_mem

		abc:
		cmp blts_x[BP], AX
		jng def
		call free_blt_mem

		def:
		jmp mv_blt


		inc_loop2:
			inc BP
			cmp BP, max_bullets
			jle l2
		
		ret

		mv_blt:
			
			cmp enm_health, 0h
			je not_hit          ; If health is 0, skip the check

			; Check x-axis collision
			mov AX, enm_x
			cmp blts_x[BP], AX
			jb not_hit          ; Bullet's X is left of enemy, no hit

			mov AX, enm_x
			add AX, enm_sz
			cmp blts_x[BP], AX
			ja not_hit         ; Bullet's X is right of enemy + size, no hit

			; Check y-axis collision
			mov AX, enm_y
			cmp blts_y[BP], AX
			jb not_hit          ; Bullet's Y is above enemy, no hit

			mov AX, enm_y
			add AX, enm_sz
			cmp blts_y[BP], AX
			ja not_hit         ; Bullet's Y is below enemy + size, no hit

			; If we passed all checks, there's a hit
			call free_blt_mem   ; Free bullet memory if hit
			dec enm_health      ; Decrease enemy health
			jmp inc_loop2       ; Continue to the next iteration


			not_hit:

			cmp blts_dir[BP], 1h			;check direction of bullet
			je blt_up
			cmp blts_dir[BP], 2h
			je blt_dw
			cmp blts_dir[BP], 3h
			je blt_lf
			cmp blts_dir[BP], 4h
			je blt_rg	
			jmp inc_loop2

			blt_up:							;mvs bullet
				mov AX, blt_spd	
				sub blts_y[BP], AX
				jmp inc_loop2
			blt_dw:
				mov AX, blt_spd
				add blts_y[BP], AX
				jmp inc_loop2
			blt_lf:
				mov AX, blt_spd
				sub blts_x[BP], AX
				jmp inc_loop2
			blt_rg:
				mov AX, blt_spd
				add blts_x[BP], AX
				jmp inc_loop2


	mv_blts endp


	check_shoot proc near

		mov AH, 01h                                       ;checks if there is any input
		int 16h
		jnz cont10
		ret

		cont10:
		mov AH, 00h                                       ;reads the input
		int 16h


		mov BP, 10h
		l3:
		cmp blts_x[BP], 00h
		je cont3
		cmp BP, 00h
		je ret3
		dec BP
		jnz l3

		cont3:
		cmp AL, 69h                                      ;if i is pressed -> blt dir up
		je i_pressed
		cmp AL, 6Bh                                      ;if k is pressed -> blt dir down
		je k_pressed
		cmp AL, 6Ah                                      ;if j is pressed -> blt dir left
		je j_pressed
		cmp AL, 6Ch                                      ;if l is pressed -> blt dir right
		je l_pressed
		ret
		
		i_pressed:
			mov blts_dir[BP], 1h
			jmp end3

		k_pressed:
			mov blts_dir[BP], 2h
			jmp end3

		j_pressed:
			mov blts_dir[BP], 3h
			jmp end3

		l_pressed:
			mov blts_dir[BP], 4h
			jmp end3
	
		end3:
			mov AX, plr_x
			mov blts_x[BP], AX
			mov AX, plr_y
			mov blts_y[BP], AX
		ret3:
		ret

	check_shoot endp


	mv_plr proc near
	
		mov AH, 01h                                       ;checks if there is any input
		int 16h
		jnz cont4
		ret

		cont4:
		mov AH, 00h                                       ;reads the input
		int 16h

		cmp AL, 77h                                      ;if w is pressed -> mvs up
		je w_pressed
		cmp AL, 73h                                      ;if s is pressed -> mvs down
		je s_pressed
		cmp AL, 61h                                      ;if a is pressed -> mvs left
		je a_pressed
		cmp AL, 64h                                      ;if d is pressed -> mvs right
		je d_pressed
		jmp end4

		
		w_pressed:
			cmp plr_y, 10h                                  ;checks if plr_y < 05h
			jc end4

			mov AX, plr_velo                              ;mvs plr_y by plr_velo_y
			sub plr_y, AX
			jmp end4

		s_pressed:
			mov BX, win_h                                   ;checks if plr_y > win_h
			sub BX, plr_sz
			cmp BX, plr_y
			jc end4

			mov AX, plr_velo                              ;mvs plr_x by plr_velo_x
			add plr_y, AX
			jmp end4

		a_pressed:
			cmp plr_x, 10h                                  ;checks if plr_y < 05h
			jc end4
			mov AX, plr_velo                              ;mvs plr_x by plr_velo_x
			sub plr_x, AX
			jmp end4

		d_pressed:
			mov BX, win_w                                   ;checks if plr_x > win_w
			sub BX, plr_sz
			cmp BX, plr_x
			jc end4
		
			mov AX, plr_velo                              ;mvs plr_x by plr_velo_x
			add plr_x, AX
			jmp end4	

		end4:
			ret

	mv_plr endp


	clrscr proc near    ;clear screen

		mov AX, 0A000h   ; video memory segment is 0A000h
		mov ES, AX
		mov DI, 0       ; ES:0 is the start of the framebuffer
		mov CX, 07D00h   ; Store the total number of bytes required for mode 0Dh (320x200 at 16 colors)
		mov AX, 0h
		rep stosw       ; zero CX * 2 bytes at ES:DI

		ret

	clrscr endp
	

	draw_plr proc near
		mov CX, plr_x
		mov DX, plr_y 

		draw_plr_hz:

			mov AH, 0ch
			mov AL, 03h                             ;color blue
			mov BH, 00h
			int 10h									;draws a pixel

			inc CX
			mov AX, CX 
			sub AX, plr_x
			cmp AX, plr_sz
			jng draw_plr_hz                 ;makes one row
			
		mov CX, plr_x
		inc DX

		mov AX, DX
		sub AX, plr_y
		cmp AX, plr_sz
		jng draw_plr_hz                 ;makes the columns
			
		ret
	draw_plr endp


	draw_blts proc near
		mov BP, 00h

		l5:
		cmp blts_dir[BP], 00h				;next iteration if dir == 0
		je inc_loop5
		

		mov CX, blts_x[BP]
		mov DX, blts_y[BP]

		draw_blt_hz:

			mov AH, 0ch
			mov AL, 04h						;color red
			mov BH, 00h
			int 10h							;draws a pixel

			inc CX
			mov AX, CX
			sub AX, blts_x[BP]
			cmp AX, blt_sz
			jng draw_blt_hz                 ;makes one row
			
		mov CX, blts_x[BP]
		inc DX

		mov AX, DX
		sub AX, blts_y[BP]
		cmp AX, blt_sz
		jng draw_blt_hz                 ;makes the columns


		inc_loop5:
		inc BP
		cmp BP, max_bullets
		jle l5

		end5:
		ret
	draw_blts endp


	draw_enm proc near
		mov BP, 00h

		l6:
		cmp enm_health, 00h				;next iteration if dir == 0
		je ret6

		mov CX, enm_x
		mov DX, enm_y

		draw_enm_hz:

			mov AX, 7h						;color acc to BP
			mov AH, 0ch
			mov BH, 00h
			int 10h							;draw a pixel

			inc CX
			mov AX, CX
			sub AX, enm_x
			cmp AX, enm_sz
			jng draw_enm_hz                 ;makes one row

		mov CX, enm_x
		inc DX

		mov AX, DX
		sub AX, enm_y
		cmp AX, enm_sz
		jng draw_enm_hz                 ;makes the columns

		ret6:
		ret

	draw_enm endp


code ends
end
