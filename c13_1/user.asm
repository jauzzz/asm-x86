SECTION header vstart=0

    ; 程序总长度
    program_length  dd program_end          ;程序总长度#0x00

    head_len        dd header_end           ;程序头部的长度#0x04

    ; NOTE: 暂时不懂作用                        
    stack_seg       dd 0                    ;用于接收堆栈段选择子#0x08
    stack_len       dd 1                    ;程序建议的堆栈大小#0x0c
                                            ;以4KB为单位

    prgentry        dd start                ;程序入口#0x10 
    code_seg        dd section.code.start   ;代码段位置#0x14
    code_len        dd code_end             ;代码段长度#0x18

    data_seg        dd section.data.start   ;数据段位置#0x1c
    data_len        dd data_end             ;数据段长度#0x20

    ; 用来说明符号表的长度，以便于重定位
    salt_items      dd (header_end-salt)/256    ;#0x24

    salt:                                       ;#0x28
    PrintString         db '@PrintString'
                    times 256-($-PrintString) db 0

    ReadDiskData        db '@ReadDiskData'
                    times 256-($-ReadDiskData) db 0

    TerminateProgram    db  '@TerminateProgram'
                    times 256-($-TerminateProgram) db 0

header_end:

;===============================================================================
SECTION data vstart=0

    buffer times 1024 db  0         ;缓冲区

    message_1       db  0x0d,0x0a,0x0d,0x0a
                    db  '**********User program is runing**********'
                    db  0x0d,0x0a,0
    message_2       db  '  Disk data:',0x0d,0x0a,0

data_end:

;===============================================================================
    [bits 32]
;===============================================================================
SECTION code vstart=0
start:
    ; 首先显示一个字符串
    
    ; 由于是通过程序头部获取到用户程序入口点的，所以此时 ds 指向用户程序头部
    mov eax,ds
    mov fs,eax

    mov eax,[stack_seg]
    mov ss,eax
    mov esp,0

    mov eax,[data_seg]
    mov ds,eax

    ; TODO: 
    ;   - ds 需要指向用户程序数据段
    ;   - 为了使用 PrintString，要初始化栈段的值
    ;   - fs 需要指向用户程序头部
    mov ebx, message_1
    ; call put_string
    ;   实际上，put_string 是内核的一个方法
    ;   我们通过 call 调用，是一个远转移，需要提供 cs:ip
    ;   但用户程序本身是不值得的，所以需要由内核来告诉用户程序
    ;   内核将这些例程的调用地址，写在用户程序上，调用时，直接从程序上找地址
    ;   这个过程，称为符号地址重定位
    call far [fs:PrintString]

    ; 读取文本文件
    mov eax,100                         ;逻辑扇区号100
    mov ebx,buffer                      ;缓冲区偏移地址
    call far [fs:ReadDiskData]          ;段间调用
    
    mov ebx,message_2
    call far [fs:PrintString]

    mov ebx,buffer 
    call far [fs:PrintString]

    ; 将控制权返回到系统
    jmp far [fs:TerminateProgram]

code_end:

;===============================================================================
SECTION trail
;-------------------------------------------------------------------------------
program_end: