; 引导程序：进入保护模式，然后加载内核
;
; 进入保护模式:
;   1. 更新全局描述符表和 gdtr
;   2. 打开 A20
;   3. 禁止中断
;   4. 打开 CR0
;   5. 刷新流水线
;   6. 32 位汇编声明
;
; 加载内核:
;   1. 从硬盘加载内核程序
;   2. 为内核创建对应的段描述符
;   3. 控制权转移到内核

    core_base_address equ 0x00040000   ;常数，内核加载的起始内存地址 
    core_start_sector equ 0x00000001   ;常数，内核的起始逻辑扇区号

    ; 开机时处于实模式
    ; 初始化栈段
    mov eax,cs
    mov ss,eax
    mov esp,0x7c00

    ; 更新全局描述符表和 gdtr
    ;   - 将 gdt 的物理地址转换为 段地址：偏移地址
    ;   - 注册段描述符
    ;   - 更新段界限
    ;   - 更新 gdtr 寄存器
    mov eax,[cs:pgdt+0x7c00+0x02]
    xor edx,edx
    mov ebx,16
    div ebx
    ; eax = 段地址，ebx = 偏移地址
    mov ds,eax
    mov ebx,edx

    ; 注册段描述符：
    ;   0. 空描述符
    ;   1. 数据段
    ;   2. 代码段

    ; 0#空描述符，这是一个规定
    mov dword [ebx+0x00],0x00
    mov dword [ebx+0x04],0x00

    ; 1#描述符，是数据段描述符 (0~4GB 的线性地址空间)
    ; 段描述符字段:
    ;   段基地址：0x00000000, 段界限：0x000FFFFF
    ;   G=1，D/B=1，L=0，AVL=0，P=1，DPL=00，S=1，TYPE=0010
    mov dword [ebx+0x08], 0x0000ffff
    mov dword [ebx+0x0c], 0x00cf9200

    ; 2#描述符，是代码段描述符（指向主引导程序）
    ; 段描述符字段:
    ;   段基地址：0x00007c00, 段界限：0x000001FF
    ;   G=0，D/B=1，L=0，AVL=0，P=1，DPL=00，S=1，TYPE=1000
    mov dword [ebx+0x10],0x7c0001ff
    mov dword [ebx+0x14],0x00409800

    ; 3#描述符，是堆栈描述符，从 0x6c00 ~ 0x7c00
    ; 段描述符字段:
    ;   段基地址：0x00007c00, 段界限：0x000FFFFE
    ;   G=1，D/B=1，L=0，AVL=0，P=1，DPL=00，S=1，TYPE=0110
    mov dword [ebx+0x18],0x7c00fffe
    mov dword [ebx+0x1c],0x00cf9600
        
    ; 4#描述符，是数据段描述符 (显示缓冲区)
    mov dword [ebx+0x20],0x8000ffff  
    mov dword [ebx+0x24],0x0040920b

    ; 描述符添加完毕，初始化全局描述符表寄存器 GDTR
    ; 更新全局描述符表段界限 = 描述符大小(8字节) * 描述符数量 - 1
    mov word [cs:pgdt+0x7c00],39

    lgdt [cs:pgdt+0x7c00]

    ; NOTE: 打开 A20
    in al,0x92
    out 0x92,al

    ; NOTE: 屏蔽中断
    ; 保护模式下的中断机制和实模式不同，因此中断向量表不再适用，应重新建立，同时禁止中断
    cli

    ; NOTE: 设置 CR0
    mov eax,cr0
    or eax,1
    mov cr0, eax

    ; NOTE: 此时已经进入了保护模式，但是还需要去“清空流水线”和“刷新段描述符缓存器的值”
    ; 可以通过一个跳转，实现这两个目的
    jmp dword 0x0010:flush

    ; NOTE: 此处是伪指令，通知编译器按照 32位操作数模式进行编译（因为已经进入了保护模式了）
    [bits 32]

flush:
    mov ecx,0x0020
    mov ds,ecx

    ; 以下在屏幕上显示"Core..." 
    mov byte [0x00],'C'
    mov byte [0x02],'o'
    mov byte [0x04],'r'
    mov byte [0x06],'e'
    mov byte [0x08],'.'
    mov byte [0x0a],'.'
    mov byte [0x0c],'.'

load:
    ; 要重新赋予段选择子
    mov ecx,0x0008
    mov ds,ecx

    mov ecx,0x0018
    mov ss,ecx
    xor esp,esp

    ; 从硬盘读取内核程序
    mov eax,core_start_sector
    mov ebx,core_base_address
    ; 记住起始地址
    mov edi,ebx
    call read_hard_disk_0

    ; 计算要读取多少个扇区
    ; 扇区数量 = 程序长度 / 扇区大小(512)
    mov eax,[edi]
    xor edx,edx
    mov ecx,512
    div ecx

    ; eax = 尚需读取的扇区数量, edx = 余数
    ; 根据余数计算，实际 eax 的值
    or edx,edx
    jnz @1
    dec eax

  @1:
    ; 是否读取完成
    or eax,eax
    jz setup

    ; 读取剩下的扇区
    mov ecx,eax
    mov eax,core_start_sector
    inc eax
  @2:
    call read_hard_disk_0
    inc eax
    loop @2

    ; 至此，内核应该是读取完成
    ; 准备为内核程序注册段描述符
    ;   - 内核代码段
    ;   - 内核数据段
    ;   - 内核例程段
setup:
    ; 需要访问 gdt
    mov esi,[0x7c00+pgdt+0x02]

    ; 建立内核例程段描述符
    mov eax,[edi+0x04]                 ;公用例程代码段起始汇编地址
    mov ebx,[edi+0x08]                 ;核心数据段汇编地址
    sub ebx,eax
    dec ebx                            ;公用例程段界限 
    add eax,edi                        ;公用例程段基地址
    mov ecx,0x00409800                 ;字节粒度的代码段描述符
    call make_gdt_descriptor
    mov [esi+0x28],eax
    mov [esi+0x2c],edx

    ;建立核心数据段描述符
    mov eax,[edi+0x08]                 ;核心数据段起始汇编地址
    mov ebx,[edi+0x0c]                 ;核心代码段汇编地址 
    sub ebx,eax
    dec ebx                            ;核心数据段界限
    add eax,edi                        ;核心数据段基地址
    mov ecx,0x00409200                 ;字节粒度的数据段描述符 
    call make_gdt_descriptor
    mov [esi+0x30],eax
    mov [esi+0x34],edx 

    ;建立核心代码段描述符
    mov eax,[edi+0x0c]                 ;核心代码段起始汇编地址
    mov ebx,[edi+0x00]                 ;程序总长度
    sub ebx,eax
    dec ebx                            ;核心代码段界限
    add eax,edi                        ;核心代码段基地址
    mov ecx,0x00409800                 ;字节粒度的代码段描述符
    call make_gdt_descriptor
    mov [esi+0x38],eax
    mov [esi+0x3c],edx

    mov word [0x7c00+pgdt],63          ;描述符表的界限
                                
    lgdt [0x7c00+pgdt]

    ; 控制转移到内核
    jmp far [edi+0x10]

;-------------------------------------------------------------------------------
read_hard_disk_0:                   ;从硬盘读取一个逻辑扇区
                                    ;EAX=逻辑扇区号
                                    ;DS:EBX=目标缓冲区地址
                                    ;返回：EBX=EBX+512 
    push eax 
    push ecx
    push edx

    push eax
    
    mov dx,0x1f2
    mov al,1
    out dx,al                       ;读取的扇区数

    inc dx                          ;0x1f3
    pop eax
    out dx,al                       ;LBA地址7~0

    inc dx                          ;0x1f4
    mov cl,8
    shr eax,cl
    out dx,al                       ;LBA地址15~8

    inc dx                          ;0x1f5
    shr eax,cl
    out dx,al                       ;LBA地址23~16

    inc dx                          ;0x1f6
    shr eax,cl
    or al,0xe0                      ;第一硬盘  LBA地址27~24
    out dx,al

    inc dx                          ;0x1f7
    mov al,0x20                     ;读命令
    out dx,al

  .waits:
    in al,dx
    and al,0x88
    cmp al,0x08
    jnz .waits                      ;不忙，且硬盘已准备好数据传输 

    mov ecx,256                     ;总共要读取的字数
    mov dx,0x1f0
  .readw:
    in ax,dx
    mov [ebx],ax
    add ebx,2
    loop .readw

    pop edx
    pop ecx
    pop eax

    ret

;-------------------------------------------------------------------------------
make_gdt_descriptor:                ;构造描述符
                                    ;输入：EAX=线性基地址
                                    ;     EBX=段界限
                                    ;     ECX=属性（各属性位都在原始
                                    ;      位置，其它没用到的位置0） 
                                    ;返回：EDX:EAX=完整的描述符
    mov edx,eax
    shl eax,16                     
    or ax,bx                        ;描述符前32位(EAX)构造完毕

    and edx,0xffff0000              ;清除基地址中无关的位
    rol edx,8
    bswap edx                       ;装配基址的31~24和23~16  (80486+)

    xor bx,bx
    or edx,ebx                      ;装配段界限的高4位

    or edx,ecx                      ;装配属性 

    ret

;-------------------------------------------------------------------------------

    pgdt         dw 0
                 dd 0x00007e00     ;GDT的物理地址

    times 510-($-$$) db 0
                     db 0x55,0xaa
