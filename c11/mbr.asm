; 保护模式：提供了对内存访问的保护
;   1. 程序想要访问一段内存，需要先声明对它的使用
;   2. 不符合声明的内存区域，会被禁止访问
;
; 全局描述符表：
;   - 任一程序使用内存前需要先声明，这种声明存储在内存中，称为描述符
;   - 出于便利，将所有描述符存储在一个给定的区域，称为全局描述符表
;   - 开机时，处于实模式下，所以全局描述符表通常为 1MB 以下的内存范围
;
; 段访问检查：
;   1. 是否为合法的描述符（段描述符表的索引值，在全局描述符表范围内）
;   2. 是否符合描述符本身的定义（什么段、段界限范围内）
;
; 全局描述符表寄存器：
;   - 因为描述符表动态变化，描述符表的界限值也相应变化
;   - 为了性能考虑，将描述符的检查做成硬件检查
;
; 进入保护模式:
;   1. 初始化全局描述符表和全局描述符表寄存器
;   2. 打开 A20
;   3. 设置 CR0
;   4. 禁止中断
;   5. 清空流水线并串行化处理器
;


    ; NOTE: 初始化栈段
    mov ax, cs
    mov ss, ax
    mov sp, 0x7c00

    ; NOTE: 初始化全局描述符表、GDTR
    ; 假定，gdt 的物理地址为 0x00007e00，要将其转化为段地址：偏移地址，以便后续添加段描述符
    mov ax, [cs:gdt_base+0x7c00]
    mov dx, [cs:gdt_base+0x7c00+0x02]
    mov bx, 16
    div bx
    ; ax = 段地址，bx = 偏移地址
    mov ds, ax
    mov bx, dx

    ; 添加段描述符：共添加 4 个段描述符
    ;   1. 空描述符
    ;   2. 代码段
    ;   3. 数据段
    ;   4. 栈段

    ; #0 空描述符，这是一个规定
    mov dword [bx+0x00], 0x00
    mov dword [bx+0x04], 0x00

    ; 1#描述符，是代码段描述符
    ; 代码段的线性地址是 0x00007c00, 段界限为 0x001FF(512)，粒度是字节（G=0）, 即主引导程序的大小
    mov dword [bx+0x08], 0x7c0001ff
    mov dword [bx+0x0c], 0x00409800

    ; 2#描述符，是数据段描述符 (文本模式下的显示缓冲区)
    mov dword [bx+0x10],0x8000ffff     
    mov dword [bx+0x14],0x0040920b

    ; 3#描述符，是堆栈描述符 (从 0x7a00 到 0x7c00) 
    mov dword [bx+0x18],0x00007a00
    mov dword [bx+0x1c],0x00409600

    ; 描述符添加完毕，初始化全局描述符表寄存器 GDTR
    ; 更新全局描述符表段界限 = 描述符大小(8字节) * 描述符数量 - 1
    mov word [cs:gdt_size+0x7c00], 31

    lgdt [cs:gdt_size+0x7c00]

    ; NOTE: 打开 A20
    in al, 0x92
    or al, 0000_0010B
    out 0x92, al

    ; NOTE: 屏蔽中断
    ; 保护模式下的中断机制和实模式不同，因此中断向量表不再适用，应重新建立，同时禁止中断
    cli

    ; NOTE: 设置 CR0
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; NOTE: 此时已经进入了保护模式，但是还需要去“清空流水线”和“刷新段描述符缓存器的值”
    ; 可以通过一个跳转，实现这两个目的
    jmp dword 0x0008:flush

    ; NOTE: 此处是伪指令，通知编译器按照 32位操作数模式进行编译（因为已经进入了保护模式了）
    [bits 32]

flush:
    mov cx, 00000000000_10_000B
    mov ds, cx

    ;以下在屏幕上显示"Protect mode OK." 
    mov byte [0x00],'P'  
    mov byte [0x02],'r'
    mov byte [0x04],'o'
    mov byte [0x06],'t'
    mov byte [0x08],'e'
    mov byte [0x0a],'c'
    mov byte [0x0c],'t'
    mov byte [0x0e],' '
    mov byte [0x10],'m'
    mov byte [0x12],'o'
    mov byte [0x14],'d'
    mov byte [0x16],'e'
    mov byte [0x18],' '
    mov byte [0x1a],'O'
    mov byte [0x1c],'K'

    ; NOTE: 在进入了保护模式之后，需要重新设置 ss 和 sp
    mov cx,00000000000_11_000B         ;加载堆栈段选择子
    mov ss,cx
    mov esp,0x7c00

    mov ebp,esp                        ;保存堆栈指针 
    push byte '.'                      ;压入立即数（字节）

    sub ebp,4
    cmp ebp,esp
    jnz ghalt
    pop eax
    mov [0x1e],al

ghalt:
    ; 已经禁止中断，不会再被唤醒
    hlt

;-------------------------------------------------------------------------------

    gdt_size         dw 0
    gdt_base         dd 0x00007e00     ;GDT的物理地址

    times 510-($-$$) db 0
                     db 0x55,0xaa
