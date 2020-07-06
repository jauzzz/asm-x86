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
put_string:                                 ; 字符串显示例程: 显示以0结尾的字符串
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
put_char:                                   ; 显示当前字符串并推进字符
                                            ; 参数：cl = 字符串
                                            ;      ebx = 当前字符串索引
                                            ;      es = 显示缓冲区

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

;-------------------------------------------------------------------------------
read_hard_disk_0:                           ; 从硬盘读取一个逻辑扇区
                                            ;EAX=逻辑扇区号
                                            ;DS:EBX=目标缓冲区地址
                                            ;返回：EBX=EBX+512
         push eax 
         push ecx
         push edx
      
         push eax
         
         mov dx,0x1f2
         mov al,1
         out dx,al                          ;读取的扇区数

         inc dx                             ;0x1f3
         pop eax
         out dx,al                          ;LBA地址7~0

         inc dx                             ;0x1f4
         mov cl,8
         shr eax,cl
         out dx,al                          ;LBA地址15~8

         inc dx                             ;0x1f5
         shr eax,cl
         out dx,al                          ;LBA地址23~16

         inc dx                             ;0x1f6
         shr eax,cl
         or al,0xe0                         ;第一硬盘  LBA地址27~24
         out dx,al

         inc dx                             ;0x1f7
         mov al,0x20                        ;读命令
         out dx,al

  .waits:
         in al,dx
         and al,0x88
         cmp al,0x08
         jnz .waits                         ;不忙，且硬盘已准备好数据传输 

         mov ecx,256                        ;总共要读取的字数
         mov dx,0x1f0
  .readw:
         in ax,dx
         mov [ebx],ax
         add ebx,2
         loop .readw

         pop edx
         pop ecx
         pop eax
      
         retf                               ;段间返回 

;-------------------------------------------------------------------------------
put_hex_dword:                              ; 打印一个双字
                                            ; 参数: edx=要打印的双字

        ;双字，32位，分别转换为字符串，显示
        pushad
        push ds

        ; 切换到核心数据段 
        mov ax, core_data_seg_sel
        mov ds, ax
        mov ecx, video_ram_seg_sel
        mov es, ecx
    
        ; 打印开始提示语
        mov ebx, debug_msg
        call sys_routine_seg_sel:put_string
        mov ebx, debug_prompt
        call sys_routine_seg_sel:put_string

        ; 指向核心数据段内的转换表
        mov ebx,bin_hex
        mov ecx,8
    
    .xlt:
        rol edx,4
        mov eax,edx
        and eax,0x0000000f
        xlat
    
        push ecx
        mov cl,al
        call put_char
        pop ecx
    
        loop .xlt
    
        ; 打印完成提示语
        mov ebx, debug_msg
        call sys_routine_seg_sel:put_string
        mov ebx, new_line
        call sys_routine_seg_sel:put_string

        pop ds
        popad
        retf

;-------------------------------------------------------------------------------
allocate_memory:                            ; 分配内存
                                            ; 参数：eax=要分配的内存长度
                                            ; 返回: eax=分配到的内存起始地址

        ; 现在采取简易的内存分配方法
        ; 在内核中定义一个空闲内存区域的起始地址，每次分配就以该起始地址为基准，分配对应长度的空间，并回写内核中的空闲内存起始地址的值

        push ds
        push ebx
        push edx        

        mov edx, core_data_seg_sel
        mov ds, edx
        
        mov edx, eax
        mov eax, [ram_alloc]
        
        ; 回写：强制作 4 字节的对齐
        add edx, eax

        mov ebx, edx
        and ebx,0xfffffffc
        add ebx,4 
        test edx,0x00000003
        cmovnz edx,ebx
        mov [ram_alloc], edx

        pop edx
        pop ebx
        pop ds

        retf
;-------------------------------------------------------------------------------
sys_routine_end:

;===============================================================================
SECTION core_data vstart=0                  ;系统核心的数据段
;-------------------------------------------------------------------------------
        
        ;下次分配内存时的起始地址
        ram_alloc       dd  0x00100000

        message_1       db  '  If you seen this message,that means we '
                        db  'are now in protect mode,and the system '
                        db  'core is loaded,and the video display '
                        db  'routine works perfectly.',0x0d,0x0a,0
        message_5       db  '  Loading user program...',0
        load_finish     db  'Done.',0x0d,0x0a,0

        ;内核用的缓冲区
        core_buf   times 2048 db 0

        cpu_brnd0       db 0x0d,0x0a,'  ',0
        cpu_brand  times 52 db 0
        cpu_brnd1       db 0x0d,0x0a,0x0d,0x0a,0

        debug_msg       db 0x0d,0x0a,'  ------------',0
        debug_prompt    db 0x0d,0x0a,'  EDX=',0
        new_line        db 0x0d,0x0a,'  ',0
        bin_hex         db '0123456789ABCDEF'

core_data_end:

;===============================================================================
SECTION core_code vstart=0
;-------------------------------------------------------------------------------
load_relocate_program:
        ; 加载并执行用户程序
        ; 参数: esi=用户程序扇区号

        ; 我们看到，缺乏了参数，加载目的内存地址
        ; 加载目的内存地址，现在由内核分配可用的内存地址
        ; 但是内核分配内存，需要参数，分配的内存总长度
        ; 这个值，也就是用户程序长度，在用户程序头部里
        ; 意味着，我们需要先加载用户程序的第一个扇区
        ; 因此，我们在内核建立一个缓冲区

        push eax
        push ebx
        push ecx
        push edx

        mov eax, esi
        mov ebx, core_buf
        call sys_routine_seg_sel:read_hard_disk_0

        ; 现在打印一下用户程序的总长度(一个双字)
        ; 用户程序长度: 000007BC = 1980
        mov edx, [core_buf]
        call sys_routine_seg_sel:put_hex_dword

        ; 现在请求分配内存
        ; 分配内存要进行 512字节 对齐
        ; 能被512整除的数，低9位都为0
        mov ebx, [core_buf]
        and ebx,0xfffffe00
        add ebx,512
        test eax,0x000001ff
        cmovnz eax,ebx

        call sys_routine_seg_sel:allocate_memory

        ; 将用户程序加载到分配到的空闲内存地址中
        mov ebx, eax
        mov eax, esi
        push eax

        ; 连续读取，这里缺少读取次数
        ; ecx = 读取次数 = 用户程序长度 / 512
        xor edx, edx
        mov eax, [core_buf]
        mov ecx, 512
        div ecx
        mov ecx, eax

        mov edx, ecx
        call sys_routine_seg_sel:put_hex_dword

        ; 切换到 0~4g 数据段
        mov eax, mem_0_4_gb_seg_sel
        mov ds, eax

        pop eax

    .read:
        call sys_routine_seg_sel:read_hard_disk_0
        inc eax
        loop .read

        pop edx
        pop ecx
        pop ebx
        pop eax

        ret

start:
        ;使ds指向核心数据段
        mov ecx, core_data_seg_sel           
        mov ds, ecx

        mov ebx, message_1
        call sys_routine_seg_sel:put_string

        ;显示处理器品牌信息 
        mov eax,0x80000002
        cpuid
        mov [cpu_brand + 0x00], eax
        mov [cpu_brand + 0x04], ebx
        mov [cpu_brand + 0x08], ecx
        mov [cpu_brand + 0x0c], edx
    
        mov eax,0x80000003
        cpuid
        mov [cpu_brand + 0x10], eax
        mov [cpu_brand + 0x14], ebx
        mov [cpu_brand + 0x18], ecx
        mov [cpu_brand + 0x1c], edx

        mov eax,0x80000004
        cpuid
        mov [cpu_brand + 0x20], eax
        mov [cpu_brand + 0x24], ebx
        mov [cpu_brand + 0x28], ecx
        mov [cpu_brand + 0x2c], edx

        mov ebx, cpu_brnd0
        call sys_routine_seg_sel:put_string
        mov ebx, cpu_brand
        call sys_routine_seg_sel:put_string
        mov ebx, cpu_brnd1
        call sys_routine_seg_sel:put_string

        ; 加载用户程序
        mov ebx, message_5
        call sys_routine_seg_sel:put_string

        ; 参数：用户程序所在的扇区
        mov esi, 50
        call load_relocate_program

        mov ebx, load_finish
        call sys_routine_seg_sel:put_string

        hlt

core_code_end:

;===============================================================================
SECTION core_trail
;-------------------------------------------------------------------------------
core_end: