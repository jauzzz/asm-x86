        ;文件名: loader.asm
        ;文件说明: 硬盘主引导扇区代码 -- 实际上是一个加载器，该扇区代码会加载另外一个扇区的代码

        ; ====
        ; 加载: 将硬盘的代码，加载到内存中
        ;
        ;   1. 硬盘读取是以扇区为单位的
        ;   2. 加载硬盘代码，需要确认的参数有：
        ;       - 代码长度（即占用多少个扇区）
        ;       - 加载的目的物理内存地址（出于简单，不涉及内存分配的部分，值暂时在代码中给出）

        app_lba_start equ 100


SECTION mbr align=16 vstart=0x7c00

        ; call 之前初始化栈
        mov ax, 0
        mov ss, ax
        mov sp, ax

        ; 计算参数，调用 read_hard_disk_0
        xor di, di
        mov si, app_lba_start

        ; NOTE: 大端序/小端序
        ;       将一个多位数的低位放在较小的地址处，高位放在较大的地址处，则称小端序；反之则称大端序。
        ;
        ; NOTE: 这个地方要特别注意，要进行段声明
        ;       段声明中，有 vstart = 0x7c00，表明段内所有元素的偏移地址从 0x7c00 开始算
        ;
        ;       因为主引导程序的实际加载地址是 0x0000:0x7c00，如果没有该声明，那么引用一个标号时，需要手动加上落差 0x7c00
        mov ax, [cs:phy_base]
        mov dx, [cs:phy_base + 2]
        
        ; 物理地址要转换成段地址
        ; 换算方式：物理地址段地址 / 16
        mov bx, 16
        div bx
        mov ds, ax
        mov es, ax

        call print_read_debug_msg

        ; TODO:我们假设用户程序比较小，就只有一个扇区那么大
        ;
        ; 现在我们得放开假设，用户程序不会只有一个扇区这么小的
        ; 那么我们就得计算出要加载多少个扇区，然后循环调用 read_hard_disk_0
        ; 扇区数量 = 用户程序的大小 / 扇区大小（512 字节）
        ;
        ; 可是我们不知道用户程序的大小！
        ; 于是，我们有一个规定/协议，让用户程序在一个固定的位置提供一些信息，比如用户程序的大小
        ; 这样，加载器就可以得到这些信息，进行加载动作
        call read_hard_disk_0

        ; 调用用户程序（给 jmp 指令提供用户程序的 cs:ip）
        ; 我们需要在用户程序处，存储一个双字，记录用户程序的 cs:ip
        mov [cs:jmup_far+2], ds
        jmp far [cs:jmup_far]

    infi: jmp near infi

;-------------------------------------------------------------------------------
read_hard_disk_0:
        ; 读取一个扇区（到指定物理内存地址）
        ; 参数：
        ;     DI:SI = 扇区号（32位）
        ;     DS:BX = 目的物理内存地址（20位）
        
        ; 正式加载扇区
        push ax
        push bx
        push cx
        push dx

        mov dx,0x1f2
        mov al,1
        out dx,al                       ;读取的扇区数

        inc dx                          ;0x1f3
        mov ax,si
        out dx,al                       ;LBA地址7~0

        inc dx                          ;0x1f4
        mov al,ah
        out dx,al                       ;LBA地址15~8

        inc dx                          ;0x1f5
        mov ax,di
        out dx,al                       ;LBA地址23~16

        inc dx                          ;0x1f6
        mov al,0xe0                     ;LBA28模式，主盘
        or al,ah                        ;LBA地址27~24
        out dx,al

        inc dx                          ;0x1f7
        mov al,0x20                     ;读命令
        out dx,al

.waits:
        in al,dx
        and al,0x88
        cmp al,0x08
        jnz .waits                      ;不忙，且硬盘已准备好数据传输 

        mov cx,256                      ;总共要读取的字数
        mov dx,0x1f0
.readw:
        in ax,dx
        mov [bx],ax
        add bx,2
        loop .readw

        pop dx
        pop cx
        pop bx
        pop ax
      
        ret

print_read_debug_msg:
        ; 打印一个提示消息
        push si
        push bx

        ; 暂时指定光标标位置 = 0
        mov si, 0
        mov bx, read_msg

        call put_string
        pop bx
        pop si

put_string:
        ; 在显示缓冲区显示一个字符串
        ; 参数：
        ;     bx: 字符串的起始位置（暂时是在代码段里）
        ;     si: 在显示缓冲区显示的起始位置
        
        push ax
        push es
        push si

        mov ax, 0xb800
        mov es, ax

    .put:
        mov cl, [cs:bx]
        or cl, cl
        jz .exit
        call put_char
        ; 下一个字符
        inc bx
        jmp .put

    .exit:
        pop si
        pop es
        pop ax

        ret

put_char:
        ; 在显示缓冲区显示一个字符
        ; 参数：
        ;     cl: 字符

        mov byte [es:si], cl
        mov byte [es:si+1],0x07

        add si, 2

        ret

;-------------------------------------------------------------------------------
        phy_base dd 0x10000             ;用户程序被加载的物理起始地址

        read_msg db 'Ready to read hard disk...'
                 db 0

        jmup_far dw 0x0000, 0x0000

times 510-($-$$) db 0
                 db 0x55,0xaa
