        ; 进入保护模式，然后加载内核

        core_base_address equ 0x00040000   ;常数，内核加载的起始内存地址 
        core_start_sector equ 0x00000001   ;常数，内核的起始逻辑扇区号 
        
        mov ax, cs
        mov ss, ax
        mov sp, 0x7c00

        mov eax, [cs:pgdt+0x7c00+0x02]
        xor edx, edx
        mov ebx, 16
        div ebx

        mov ds, eax
        mov ebx, edx

        ; 创建描述符
        ;
        
        ; 0# 描述符
        mov dword [ebx+0x00], 0x00
        mov dword [ebx+0x04], 0x00

        ; 1# 描述符，数据段描述符 (0 ~ 4GB)
        ; 基地址为0，段界限为0xFFFFF，粒度为 4KB
        mov dword [ebx+0x08], 0x0000ffff
        mov dword [ebx+0x0c], 0x00cf9200

        ; 2# 描述符，代码段描述符
        ;基地址为0x00007c00，界限0x1FF，粒度为1个字节
        mov dword [ebx+0x10], 0x7c0001ff
        mov dword [ebx+0x14], 0x00409800

        ; 3# 描述符，堆栈段描述符
        ; 基地址为0x00007C00，界限0xFFFFE，粒度为4KB
        mov dword [ebx+0x18], 0x7c00fffe
        mov dword [ebx+0x1c], 0x00cf9600

        ; 4# 描述符，显示缓冲区描述符
        ; 基地址为0x000B8000，界限0x07FFF，粒度为字节
        mov dword [ebx+0x20], 0x80007fff
        mov dword [ebx+0x24], 0x0040920b

        ; 初始化 GDTR
        mov word [cs:pgdt+0x7c00], 39

        lgdt [cs:pgdt+0x7c00]

        ; 打开 A20
        in al,0x92
        or al,0000_0010B
        out 0x92,al

        ; 关中断
        cli

        ; 设置 CR0 的 PE 位
        mov eax,cr0
        or eax,1
        mov cr0,eax

        ; 清空流水线并串行化处理器
        ; 可以通过 jmp 指令实现
        
        ; 这里已经进入了保护模式，访问 cs:ip 要通过段描述符的形式了
        jmp dword 0x0010:flush

        [bits 32]

    flush:
        ; 指向 0~4GB 数据段
        mov eax, 0x0008
        mov ds, eax

        mov eax, 0x0018
        mov ss, eax
        xor esp, esp

        ; 加载内核程序
        mov ebx, core_base_address
        mov eax, core_start_sector
        mov edi, ebx
        call read_hard_disk_0

        ; 判断程序大小
        mov eax, [edi]
        xor edx, edx
        mov ecx, 512
        div ecx

        or edx, edx
        jnz @1
        dec eax

    @1:
        or eax, eax
        jz setup
        
        ; 读取剩余扇区
        mov ecx, eax
        mov eax, core_start_sector
        inc eax

    @2:
        call read_hard_disk_0
        inc eax
        loop @2

    setup:
        mov esi, [0x7c00+pgdt+0x02]

        ; 建立内核的段描述符
        ; 公共例程段
        mov eax, [edi+0x04]                 ;公用例程代码段起始汇编地址
        mov ebx, [edi+0x08]                 ;核心数据段汇编地址
        sub ebx, eax
        dec ebx                             ;公用例程段界限 
        add eax, edi                        ;公用例程段基地址
        mov ecx, 0x00409800                 ;字节粒度的代码段描述符
        call make_gdt_descriptor
        mov [esi+0x28], eax
        mov [esi+0x2c], edx

        ; 内核数据段
        mov eax, [edi+0x08]                 ;核心数据段起始汇编地址
        mov ebx, [edi+0x0c]                 ;核心代码段汇编地址 
        sub ebx, eax
        dec ebx                             ;核心数据段界限
        add eax, edi                        ;核心数据段基地址
        mov ecx, 0x00409200                 ;字节粒度的数据段描述符 
        call make_gdt_descriptor
        mov [esi+0x30], eax
        mov [esi+0x34], edx

        ; 内核代码段
        mov eax, [edi+0x0c]                 ;核心代码段起始汇编地址
        mov ebx, [edi+0x00]                 ;程序总长度
        sub ebx, eax
        dec ebx                             ;核心代码段界限
        add eax, edi                        ;核心代码段基地址
        mov ecx, 0x00409800                 ;字节粒度的代码段描述符
        call make_gdt_descriptor
        mov [esi+0x38], eax
        mov [esi+0x3c], edx
        
        ; 修改 gdtr 的界限值并重新加载
        mov word [0x7c00+pgdt], 63
        lgdt [0x7c00+pgdt]

        ; 跳转到内核程序执行
        jmp far [edi+0x10]

;-------------------------------------------------------------------------------
read_hard_disk_0:                        ; 从硬盘读取一个逻辑扇区
                                         ; EAX=逻辑扇区号
                                         ; DS:EBX=目标缓冲区地址
                                         ; 返回：EBX=EBX+512 
         push eax
         push ecx
         push edx
      
         push eax
         
         mov dx, 0x1f2
         mov al, 1
         out dx, al                      ; 读取的扇区数

         inc dx                          ; 0x1f3
         pop eax
         out dx, al                      ; LBA地址7~0

         inc dx                          ; 0x1f4
         mov cl, 8
         shr eax, cl
         out dx, al                      ; LBA地址15~8

         inc dx                          ; 0x1f5
         shr eax, cl
         out dx, al                      ; LBA地址23~16

         inc dx                          ; 0x1f6
         shr eax, cl
         or al, 0xe0                     ; 第一硬盘  LBA地址27~24
         out dx, al

         inc dx                          ; 0x1f7
         mov al, 0x20                    ; 读命令
         out dx, al

  .waits:
         in al, dx
         and al, 0x88
         cmp al, 0x08
         jnz .waits                      ; 不忙，且硬盘已准备好数据传输 

         mov ecx, 256                    ; 总共要读取的字数
         mov dx, 0x1f0
  .readw:
         in ax, dx
         mov [ebx], ax
         add ebx, 2
         loop .readw

         pop edx
         pop ecx
         pop eax
      
         ret

;-------------------------------------------------------------------------------
make_gdt_descriptor:                     ; 构造描述符
                                         ; 输入：EAX=线性基地址
                                         ;      EBX=段界限
                                         ;      ECX=属性（各属性位都在原始
                                         ;      位置，其它没用到的位置0） 
                                         ; 返回：EDX:EAX=完整的描述符
         mov edx, eax
         shl eax, 16                     
         or ax, bx                       ; 描述符前32位(EAX)构造完毕
      
         and edx, 0xffff0000             ; 清除基地址中无关的位
         rol edx, 8
         bswap edx                       ; 装配基址的31~24和23~16  (80486+)
      
         xor bx, bx
         or edx, ebx                     ; 装配段界限的高4位
      
         or edx, ecx                     ; 装配属性 
      
         ret
      
;-------------------------------------------------------------------------------
         pgdt             dw 0
                          dd 0x00007e00
;-------------------------------------------------------------------------------                             
         times 510-($-$$) db 0
                          db 0x55,0xaa
