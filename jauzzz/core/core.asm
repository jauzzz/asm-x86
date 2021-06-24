        ; 内核程序：打印一些字符串，然后控制转移到用户程序
        ; QA: 为什么内核栈不需要初始化？

        ;以下常量定义部分。内核的大部分内容都应当固定 
        core_code_seg_sel     equ  0x38    ;内核代码段选择子
        core_data_seg_sel     equ  0x30    ;内核数据段选择子 
        sys_routine_seg_sel   equ  0x28    ;系统公共例程代码段的选择子 
        video_ram_seg_sel     equ  0x20    ;视频显示缓冲区的段选择子
        core_stack_seg_sel    equ  0x18    ;内核堆栈段选择子
        mem_0_4_gb_seg_sel    equ  0x08    ;整个0-4GB内存的段的选择子

;-------------------------------------------------------------------------------
        core_length         dd core_end

        sys_routine_seg     dd section.sys_routine.start
        core_data_seg       dd section.core_data.start
        core_code_seg       dd section.core_code.start
        core_entry          dd start
                            dw core_code_seg_sel

;===============================================================================
        [bits 32]
;===============================================================================
SECTION sys_routine vstart=0
;-------------------------------------------------------------------------------
         ;字符串显示例程
put_string:                                 ;显示0终止的字符串并移动光标 
                                            ;输入：DS:EBX=串地址
         push ecx
  .getc:
         mov cl,[ebx]
         or cl,cl
         jz .exit
         call put_char
         inc ebx
         jmp .getc

  .exit:
         pop ecx
         retf                               ;段间返回

;-------------------------------------------------------------------------------
put_char:                                   ;在当前光标处显示一个字符,并推进
                                            ;光标。仅用于段内调用 
                                            ;输入：CL=字符ASCII码 
         pushad

         ;以下取当前光标位置
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

         cmp cl,0x0d                        ;回车符？
         jnz .put_0a
         mov ax,bx
         mov bl,80
         div bl
         mul bl
         mov bx,ax
         jmp .set_cursor

  .put_0a:
         cmp cl,0x0a                        ;换行符？
         jnz .put_other
         add bx,80
         jmp .roll_screen

  .put_other:                               ;正常显示字符
         push es
         mov eax,video_ram_seg_sel          ;0xb8000段的选择子
         mov es,eax
         shl bx,1
         mov [es:bx],cl
         pop es

         ;以下将光标位置推进一个字符
         shr bx,1
         inc bx

  .roll_screen:
         cmp bx,2000                        ;光标超出屏幕？滚屏
         jl .set_cursor

         push ds
         push es
         mov eax,video_ram_seg_sel
         mov ds,eax
         mov es,eax
         cld
         mov esi,0xa0                       ;小心！32位模式下movsb/w/d 
         mov edi,0x00                       ;使用的是esi/edi/ecx 
         mov ecx,1920
         rep movsd
         mov bx,3840                        ;清除屏幕最底一行
         mov ecx,80                         ;32位程序应该使用ECX
  .cls:
         mov word[es:bx],0x0720
         add bx,2
         loop .cls

         pop es
         pop ds

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

         popad
         ret                                

;-------------------------------------------------------------------------------
read_hard_disk_0:                           ;从硬盘读取一个逻辑扇区
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
;汇编语言程序是极难一次成功，而且调试非常困难。这个例程可以提供帮助 
put_hex_dword:                              ;在当前光标处以十六进制形式显示
                                            ;一个双字并推进光标 
                                            ;输入：EDX=要转换并显示的数字
                                            ;输出：无
         pushad
         push ds
      
         mov ax,core_data_seg_sel           ;切换到核心数据段 
         mov ds,ax
      
         mov ebx,bin_hex                    ;指向核心数据段内的转换表
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
      
         pop ds
         popad
         retf
      
;-------------------------------------------------------------------------------
allocate_memory:                            ;分配内存
                                            ;输入：ECX=希望分配的字节数
                                            ;输出：ECX=起始线性地址 
         push ds
         push eax
         push ebx
      
         mov eax,core_data_seg_sel
         mov ds,eax
      
         mov eax,[ram_alloc]
         add eax,ecx                        ;下一次分配时的起始地址
      
         ;这里应当有检测可用内存数量的指令
          
         mov ecx,[ram_alloc]                ;返回分配的起始地址

         mov ebx,eax
         and ebx,0xfffffffc
         add ebx,4                          ;强制对齐 
         test eax,0x00000003                ;下次分配的起始地址最好是4字节对齐
         cmovnz eax,ebx                     ;如果没有对齐，则强制对齐 
         mov [ram_alloc],eax                ;下次从该地址分配内存
                                            ;cmovcc指令可以避免控制转移 
         pop ebx
         pop eax
         pop ds

         retf

;-------------------------------------------------------------------------------
set_up_gdt_descriptor:                      ;在GDT内安装一个新的描述符
                                            ;输入：EDX:EAX=描述符 
                                            ;输出：CX=描述符的选择子
         push eax
         push ebx
         push edx
      
         push ds
         push es
      
         mov ebx,core_data_seg_sel          ;切换到核心数据段
         mov ds,ebx

         sgdt [pgdt]                        ;以便开始处理GDT

         mov ebx,mem_0_4_gb_seg_sel
         mov es,ebx

         movzx ebx,word [pgdt]              ;GDT界限 
         inc bx                             ;GDT总字节数，也是下一个描述符偏移 
         add ebx,[pgdt+2]                   ;下一个描述符的线性地址 
      
         mov [es:ebx],eax
         mov [es:ebx+4],edx
      
         add word [pgdt],8                  ;增加一个描述符的大小   
      
         lgdt [pgdt]                        ;对GDT的更改生效 
       
         mov ax,[pgdt]                      ;得到GDT界限值
         xor dx,dx
         mov bx,8
         div bx                             ;除以8，去掉余数
         mov cx,ax                          
         shl cx,3                           ;将索引号移到正确位置 

         pop es
         pop ds

         pop edx
         pop ebx
         pop eax
      
         retf 
;-------------------------------------------------------------------------------
make_seg_descriptor:                        ;构造存储器和系统的段描述符
                                            ;输入：EAX=线性基地址
                                            ;      EBX=段界限
                                            ;      ECX=属性。各属性位都在原始
                                            ;          位置，无关的位清零 
                                            ;返回：EDX:EAX=描述符
         mov edx,eax
         shl eax,16
         or ax,bx                           ;描述符前32位(EAX)构造完毕

         and edx,0xffff0000                 ;清除基地址中无关的位
         rol edx,8
         bswap edx                          ;装配基址的31~24和23~16  (80486+)

         xor bx,bx
         or edx,ebx                         ;装配段界限的高4位

         or edx,ecx                         ;装配属性

         retf

;===============================================================================
SECTION core_data vstart=0
        pgdt            dw  0             ;用于设置和修改GDT 
                        dd  0

        ram_alloc       dd  0x00100000    ;下次分配内存时的起始地址

        ;符号地址检索表
        salt:
        salt_1          db  '@PrintString'
                    times 256-($-salt_1) db 0
                        dd  put_string
                        dw  sys_routine_seg_sel

        salt_2          db  '@ReadDiskData'
                    times 256-($-salt_2) db 0
                        dd  read_hard_disk_0
                        dw  sys_routine_seg_sel

        salt_3          db  '@PrintDwordAsHexString'
                    times 256-($-salt_3) db 0
                        dd  put_hex_dword
                        dw  sys_routine_seg_sel

        salt_4          db  '@TerminateProgram'
                    times 256-($-salt_4) db 0
                        dd  return_point
                        dw  core_code_seg_sel

        salt_item_len   equ $-salt_4
        salt_items      equ ($-salt)/salt_item_len

        message_1       db  '  If you seen this message,that means we '
                        db  'are now in protect mode,and the system '
                        db  'core is loaded,and the video display '
                        db  'routine works perfectly.',0x0d,0x0a,0

        message_5       db  '  Loading user program...',0

        do_status       db  'Done.',0x0d,0x0a,0

        message_6       db  0x0d,0x0a,0x0d,0x0a,0x0d,0x0a
                        db  '  User program terminated,control returned.',0

        ; put_hex_dword子过程用的查找表
        bin_hex         db '0123456789ABCDEF'

        core_buf   times 2048 db 0         ;内核用的缓冲区

        esp_pointer     dd 0              ;内核用来临时保存自己的栈指针     

        cpu_brnd0       db 0x0d,0x0a,'  ',0
        cpu_brand  times 52 db 0
        cpu_brnd1       db 0x0d,0x0a,0x0d,0x0a,0

;===============================================================================
SECTION core_code vstart=0
;-------------------------------------------------------------------------------
load_relocate_program:                      ;加载并重定位用户程序
                                            ;输入：ESI=起始逻辑扇区号
                                            ;返回：AX=指向用户程序头部的选择子

        push ebx
        push ecx
        push edx
        push esi
        push edi
      
        push ds
        push es

        ; TODO: 加载用户程序并重定向：
        ;   1. 加载到内存
        ;   2. 创建用户程序的 gdt
        ;   3. 回写用户程序的段描述符
        ;   4. 重定向用户程序的符号表（用户程序会使用内核的例程，在不知道内核例程地址的情况下）
        
        mov eax, core_data_seg_sel
        mov ds, eax

        ; 读取到内核缓冲区
        mov eax, esi
        mov ebx, core_buf
        call sys_routine_seg_sel:read_hard_disk_0

        ; 参数：要获取的内存空间的长度
        mov eax, [core_buf]                 ;程序尺寸
        mov ebx, eax
        and ebx, 0xfffffe00                 ;使之512字节对齐（能被512整除的数， 
        add ebx, 512                        ;低9位都为0 
        test eax, 0x000001ff                ;程序的大小正好是512的倍数吗? 
        cmovnz eax, ebx                     ;不是。使用凑整的结果 
        
        ; 请求分配内存
        mov ecx, eax
        call sys_routine_seg_sel:allocate_memory

        ; ebx -> 申请到的内存首地址
        ; 保存该首地址 
        mov ebx,ecx
        push ebx

        ; 计算总扇区数
        xor edx,edx
        mov ecx,512
        div ecx
        mov ecx,eax
    
        ; 切换DS到0-4GB的段
        mov eax,mem_0_4_gb_seg_sel
        mov ds,eax

        ; 起始扇区号
        mov eax,esi
    
    .b1:
        ; 循环读，直到读完整个用户程序
        call sys_routine_seg_sel:read_hard_disk_0
        inc eax
        loop .b1

        ; 至此，读取完用户程序，开始创建 gdt
        ; 恢复程序装载的首地址 
        pop edi

        ; 建立程序头部段描述符        
        mov eax, edi                        ;程序头部起始线性地址
        mov ebx, [edi+0x04]                 ;段长度
        dec ebx                             ;段界限 
        mov ecx, 0x00409200                 ;字节粒度的数据段描述符
        call sys_routine_seg_sel:make_seg_descriptor
        call sys_routine_seg_sel:set_up_gdt_descriptor
        mov [edi+0x04], cx

        ; 建立程序代码段描述符
        mov eax, edi
        add eax, [edi+0x14]                 ;代码起始线性地址
        mov ebx, [edi+0x18]                 ;段长度
        dec ebx                             ;段界限
        mov ecx, 0x00409800                 ;字节粒度的代码段描述符
        call sys_routine_seg_sel:make_seg_descriptor
        call sys_routine_seg_sel:set_up_gdt_descriptor
        mov [edi+0x14], cx

        ; 建立程序数据段描述符
        mov eax, edi
        add eax, [edi+0x1c]                 ;数据段起始线性地址
        mov ebx, [edi+0x20]                 ;段长度
        dec ebx                             ;段界限
        mov ecx, 0x00409200                 ;字节粒度的数据段描述符
        call sys_routine_seg_sel:make_seg_descriptor
        call sys_routine_seg_sel:set_up_gdt_descriptor
        mov [edi+0x1c], cx

        ; 建立程序栈段描述符
        mov ecx, [edi+0x0c]                 ;4KB的倍率 
        mov ebx, 0x000fffff
        sub ebx, ecx                        ;得到段界限
        mov eax, 4096
        mul dword [edi+0x0c]
        mov ecx, eax                        ;准备为堆栈分配内存 
        call sys_routine_seg_sel:allocate_memory
        add eax, ecx                        ;得到堆栈的高端物理地址 
        mov ecx, 0x00c09600                 ;4KB粒度的堆栈段描述符
        call sys_routine_seg_sel:make_seg_descriptor
        call sys_routine_seg_sel:set_up_gdt_descriptor
        mov [edi+0x08], cx

        ; 至此，用户程序描述符就建立完了
        ; 开始重定位 SALT 符号表

        ;es -> 用户程序头部 
        mov eax, [edi+0x04]
        mov es, eax
        mov eax, core_data_seg_sel
        mov ds, eax
    
        cld

        mov ecx, [es:0x24]                  ;用户程序的SALT条目数
        mov edi, 0x28                       ;用户程序内的SALT位于头部内0x2c处

    .b2:
        push ecx
        push edi
    
        mov ecx, salt_items
        mov esi, salt

    .b3:
        push edi
        push esi
        push ecx

        mov ecx, 64                         ;检索表中，每条目的比较次数 
        repe cmpsd                          ;每次比较4字节 
        jnz .b4
        mov eax, [esi]                      ;若匹配，esi恰好指向其后的地址数据
        mov [es:edi-256], eax               ;将字符串改写成偏移地址 
        mov ax, [esi+4]
        mov [es:edi-252], ax                ;以及段选择子 

    .b4:
        pop ecx
        pop esi
        add esi, salt_item_len
        pop edi                             ;从头比较 
        loop .b3

        pop edi
        add edi, 256
        pop ecx
        loop .b2

        mov ax, [es:0x04]

        pop es                             ;恢复到调用此过程前的es段 
        pop ds                             ;恢复到调用此过程前的ds段

        pop edi
        pop esi
        pop edx
        pop ecx
        pop ebx
    
        ret

;-------------------------------------------------------------------------------
start:
        ; 指向内核数据段
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

        mov ebx,cpu_brnd0
        call sys_routine_seg_sel:put_string
        mov ebx,cpu_brand
        call sys_routine_seg_sel:put_string
        mov ebx,cpu_brnd1
        call sys_routine_seg_sel:put_string

        ; 开始加载用户程序
        mov ebx,message_5
        call sys_routine_seg_sel:put_string

        ; 用户程序位于逻辑50扇区
        mov esi,50
        call load_relocate_program

        mov ebx,do_status
        call sys_routine_seg_sel:put_string

        ; 临时保存堆栈指针
        mov [esp_pointer], esp

        ; 通过用户程序头部选择子，将控制转移到用户程序
        mov ds, ax
        jmp far [0x10]

return_point:
        ; 恢复控制转移前的内核状态

        ; 使ds指向核心数据段
        mov eax,core_data_seg_sel
        mov ds,eax

        ; 切换回内核自己的堆栈
        mov eax,core_stack_seg_sel
        mov ss,eax
        mov esp,[esp_pointer]

        mov ebx,message_6
        call sys_routine_seg_sel:put_string

        ;这里可以放置清除用户程序各种描述符的指令
        ;也可以加载并启动其它程序
    
        hlt
;===============================================================================
SECTION core_trail
;-------------------------------------------------------------------------------
core_end:
