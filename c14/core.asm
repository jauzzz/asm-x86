         ;代码清单13-2
         ;文件名：c13_core.asm
         ;文件说明：保护模式微型核心程序 
         ;创建日期：2011-10-26 12:11

         ;以下常量定义部分。内核的大部分内容都应当固定 
         core_code_seg_sel     equ  0x38    ;内核代码段选择子
         core_data_seg_sel     equ  0x30    ;内核数据段选择子 
         sys_routine_seg_sel   equ  0x28    ;系统公共例程代码段的选择子 
         video_ram_seg_sel     equ  0x20    ;视频显示缓冲区的段选择子
         core_stack_seg_sel    equ  0x18    ;内核堆栈段选择子
         mem_0_4_gb_seg_sel    equ  0x08    ;整个0-4GB内存的段的选择子

;-------------------------------------------------------------------------------
SECTION header
         ;以下是系统核心的头部，用于加载核心程序 
         core_length      dd core_end       ;核心程序总长度#00

         sys_routine_seg  dd section.sys_routine.start
                                            ;系统公用例程段位置#04

         core_data_seg    dd section.core_data.start
                                            ;核心数据段位置#08

         core_code_seg    dd section.core_code.start
                                            ;核心代码段位置#0c


         core_entry       dd start          ;核心代码段入口点#10
                          dw core_code_seg_sel

header_end:

;===============================================================================
         [bits 32]
;===============================================================================
SECTION sys_routine vstart=0                ;系统公共例程代码段 
;-------------------------------------------------------------------------------
put_string:
        ; 字符串显示例程: 显示以0结尾的字符串
        ; 参数: DS:EBX = 字符串起始地址

        push ecx
        push es

        mov ecx, video_ram_seg_sel
        mov es, ecx
        
    .getc:
        mov cl, [ebx]
        ; 是否为0结尾
        or cl, cl
        jz .exit
        call put_char
        inc ebx
        jmp .getc
        
    .exit:
        pop es
        pop ecx

        retf

;-------------------------------------------------------------------------------
put_char:
        ; 显示当前字符串并推进字符
        ; 参数：cl = 字符串
        ;      ebx = 当前字符串索引

        push edx
        push eax
        push ebx
        push edi
        push esi
        push ecx

        ; 处理流程
        ;   1. 判断是否特殊字符 - 回车换行
        ;   2. 正常显示字符
        ;   3. 向前推进光标位置
        ;   4. 判断光标是否超出屏幕
        ;   5. 设置光标位置的新值

        ; 先获取光标位置
        ; BX=光标位置
        mov dx,0x3d4
        mov al,0x0e
        out dx,al
        inc dx                             ;0x3d5
        in al,dx                           ;高字
        mov ah,al

        dec dx                             ;0x3d4
        mov al,0x0f
        out dx,al
        inc dx                             ;0x3d5
        in al,dx                           ;低字
        mov bx,ax                          ;BX=代表光标位置的16位数

        ; 回车符: 0x0d, 将光标置于行首
        ; 换行符: 0x0a, 光标位置推进一行
        cmp cl, 0x0d
        jnz .put_0a
        
        ; 回车符处理
        mov ax,bx
        mov bl,80
        div bl
        mul bl
        mov bx,ax
        jmp .set_cursor

        ; 换行符处理
    .put_0a:
        cmp cl, 0x0a
        jnz .put_other

        add bx, 80
        jmp .roll_screen

    .put_other:
        ; 一个字符要占两个字节，即一个光标对应两个字节
        shl bx, 1
        mov [es:bx], cl

        ; 还原光标位置，并推进
        shr bx, 1
        inc bx

    .roll_screen:
        ; 光标位置超出屏幕时滚屏，并用黑底白字填充最后一行

        ; 是否超出屏幕
        cmp bx, 2000
        jl .set_cursor

        ; 滚屏：将屏幕整体上移一行
        push ds
        mov eax, video_ram_seg_sel
        mov ds, eax

        ; movsd: 根据方向标志位的值，将数据从 ESI 指向的内存位置复制到 EDI 指向的内存位置，并自动递增或递减 esi/edi 的值
        cld
        mov esi, 0xa0
        mov edi, 0x00
        mov ecx, 1920
        rep movsd

        pop ds

        mov bx, 3840
        mov ecx, 80
    .cls:
        mov word[es:bx],0x0720
        add bx,2
        loop .cls
        
        mov bx,1920

    .set_cursor:
        mov dx,0x3d4
        mov al,0x0e
        out dx,al
        inc dx                             ;0x3d5
        mov al,bh
        out dx,al
        dec dx                             ;0x3d4
        mov al,0x0f
        out dx,al
        inc dx                             ;0x3d5
        mov al,bl
        out dx,al

        pop ecx
        pop esi
        pop edi
        pop ebx
        pop eax
        pop edx

        ret

sys_routine_end:

;===============================================================================
SECTION core_data vstart=0                  ;系统核心的数据段
;-------------------------------------------------------------------------------
         

         message_1        db  '  If you seen this message,that means we '
                          db  'are now in protect mode,and the system '
                          db  'core is loaded,and the video display '
                          db  'routine works perfectly.',0x0d,0x0a,0

core_data_end:

;===============================================================================
SECTION core_code vstart=0
;-------------------------------------------------------------------------------
start:
         mov ecx,core_data_seg_sel           ;使ds指向核心数据段 
         mov ds,ecx

         mov ebx,message_1
         call sys_routine_seg_sel:put_string

         hlt

core_code_end:

;===============================================================================
SECTION core_trail
;-------------------------------------------------------------------------------
core_end: