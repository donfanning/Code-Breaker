cr              equ     0dh
lf              equ     0ah
paramarea       equ     80h
memloc1         equ    6fah
       
cseg            segment byte public
                assume  cs:cseg,ds:cseg,ss:cseg,es:cseg
                org     0
firstbyte       equ     $
                org     100h

fix             proc    far

start:
                jmp     begin

found           db      0
savesp          dw      0
savess          dw      0
savetempsp      dw      0
oldint21        dd      0

fix             endp

;---------------------------------------------------------------
; Redirect interrupt 21h through absolute memory access.
;---------------------------------------------------------------
redirect21      proc    near
                push    bx
                push    es
                xor     bx,bx
                push    bx
                pop     es
                or      bx,84h
                push    word ptr es:[bx]
                pop     word ptr cs:oldint21
                push    word ptr es:[bx+2]
                pop     word ptr cs:oldint21+2
                push    offset cs:newint21
                pop     word ptr es:[bx]
                push    cs
                pop     word ptr es:[bx+2]
                pop     es
                pop     bx
                ret
redirect21      endp

;---------------------------------------------------------------
; Redirect interrupt 21h back to original.
;---------------------------------------------------------------
unredirect21    proc    near
                push    bx
                push    es
                xor     bx,bx
                push    bx
                pop     es
                or      bx,84h
                push    word ptr cs:oldint21
                pop     word ptr es:[bx]
                push    word ptr cs:oldint21+2
                pop     word ptr es:[bx+2]
                pop     es
                pop     bx
                ret
unredirect21    endp

;---------------------------------------------------------------
; New interrupt 21h. Use to search for certain bytes in memory.
;---------------------------------------------------------------
newint21        proc    far
                cmp     byte ptr cs:found,1
                je      exitnewint21
                push    bp
                mov     bp,sp
                push    ds
                push    di
                mov     ds,[bp+4]
                mov     di,memloc1
                cmp     word ptr ds:[di],463bh
                jne     exitsearch
                cmp     word ptr ds:[di+2],75f4h
                jne     exitsearch
                cmp     word ptr ds:[di+4],8306h
                jne     exitsearch
                cmp     word ptr ds:[di+6],0fe7eh
                jne     exitsearch
                mov     word ptr ds:[di],9090h
                mov     word ptr ds:[di+2],9090h
                mov     word ptr ds:[di+4],9090h
                mov     word ptr ds:[di+6],9090h
                mov     byte ptr ds:[di+8],90h
                mov     byte ptr ds:[di+9],0ebh
                mov     byte ptr cs:found,1
exitsearch:
                pop     di
                pop     ds
                pop     bp
exitnewint21:
                jmp     dword ptr cs:oldint21
newint21        endp

;---------------------------------------------------------------
; Get a key from the keyboard.
;---------------------------------------------------------------
getkey          proc    near
                xor     ax,ax
                int     16h
                ret
getkey          endp

;---------------------------------------------------------------
; Write a string.
;---------------------------------------------------------------
writestr        proc    near
                push    ax                              ; save registers
                push    dx
                push    bp
                mov     bp,sp
                push    [bp+8]                          ; set dx=[bp+8]
                pop     dx
                mov     ah,9                            ; write string
                int     21h
                pop     bp                              ; restore registers
                pop     dx
                pop     ax
                ret     2
writestr        endp

;---------------------------------------------------------------
; Show error(s) that occurred during execution of program.
;---------------------------------------------------------------
showerror       proc    near
                push    ax
                cmp     ax,2
                je      em2
                cmp     ax,4
                je      em4
                cmp     ax,8
                je      em8
                push    offset error0
                jmp     writeerror
em2:
                push    offset error2
                jmp     writeerror
em4:
                push    offset error4
                jmp     writeerror
em8:
                push    offset error8
writeerror:
                call    writestr
                pop     ax
                ret
showerror       endp

;---------------------------------------------------------------
; Get and store parameters.
;---------------------------------------------------------------
getparam        proc    near
                push    bx
                push    cx
                push    si
                push    di
                xor     bx,bx
                or      cx,bx
                mov     cl,ds:paramarea[bx]
                or      cl,cl
                jz      exitgetparam
                add     cx,2
                mov     si,offset paramarea
                mov     di,offset cmd_buf
                rep     movsb
exitgetparam:
                pop     di
                pop     si
                pop     cx
                pop     bx
                ret
getparam        endp

;---------------------------------------------------------------
; Main execution block.
;---------------------------------------------------------------
begin:
                mov     savesp,sp
                mov     savess,ss
                mov     sp,offset userstackptr
                push    cs
                push    cs
                push    cs
                pop     ds
                pop     es
                pop     ss
                push    offset cs:credit
                call    writestr
                call    getkey
                call    redirect21
                call    getparam
                mov     bx,(offset lastbyte - firstbyte + 15) shr 4
                mov     ah,4ah
                int     21h
                jnc     executeprog
                push    offset fail4a
                call    writestr
                jmp     error
executeprog:
                push    cs
                pop     fcb1
                push    cs
                pop     fcb2
                push    cs
                pop     envstr
                mov     dx,offset filename
                mov     bx,offset paramblock
                mov     savetempsp,sp
                mov     ax,4b00h
                int     21h
                push    cs
                pop     ss
                mov     sp,savetempsp
                push    cs
                pop     ds
                push    cs
                pop     es
                jnc     exitprog
                push    offset fail4b
                call    writestr
error:
                call    showerror
exitprog:
                call    unredirect21
                mov     ss,savess
                mov     sp,savesp
                mov     ax,4c00h
                int     21h

credit          db      '  嬪様様様様様様様様様様様様様様様� PENT/�GRAM 突様様様様様様様様様様様様様様�',cr,lf
                db      '  � PENT/�GRAM PROUDLY PRESENTS - XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX   �',cr,lf
                db      '  � Memory patcher/loader v1.0 by Code Breaker                               �',cr,lf
                db      '  �                                                                          �',cr,lf
                db      '  � Greetings - The Rocketeer, Flip Boy, Fanfan, Dr. Insanity, Faceless      �',cr,lf
                db      '  �           - Viper, Silicon Soldier, all PTG members and everyone else... �',cr,lf
                db      '  �                                                                          �',cr,lf
                db      '  � Strike a key to start...                                                 �',cr,lf
                db      '  塒様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様余',cr,lf,'$'
fail4a          db      cr,lf,'  Unable to modify allocated memory blocks.$'
fail4b          db      cr,lf,'  Unable to load program.$'
error0          db      cr,lf,'  Unknown error code.$'
error2          db      cr,lf,'  ''       '' - not found.$'
error4          db      cr,lf,'  Too many files handles open.$'
error8          db      cr,lf,'  Insufficient memory.$'
filename        db      'hkmj.exe',0
paramblock      label   word
                dw      0
                dw      offset cmd_buf
fcb1            dw      ?
                dw      5ch
fcb2            dw      ?
                dw      6ch
envstr          dw      ?
cmd_buf         db      0
                db      ' '
cmd_txt         db      80h dup (?)
userstack       db      32 dup ('stack   ')
userstackptr    label   word
lastbyte        equ     $

cseg            ends
                end     start
