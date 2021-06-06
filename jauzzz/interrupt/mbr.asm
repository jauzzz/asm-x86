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

        xor di, di
        mov si, app_lba_start
        xor bx, bx

        ; TODO:我们假设用户程序比较小，就只有一个扇区那么大
        ;
        ; 现在我们得放开假设，用户程序不会只有一个扇区这么小的
        ; 那么我们就得计算出要加载多少个扇区，然后循环调用 read_hard_disk_0             
        ; 扇区数量 = 用户程序的大小 / 扇区大小（512 字节）
        ;
        ; 可是我们不知道用户程序的大小！
        ; 于是，我们有一个规定/协议，让用户程序在一个固定的位置提供一些信息，比如用户程序的大小
        ; 这样，加载器就可以得到这些信息，进行加载动作

        ; 而这些信息，由用户程序记录在自己头部
        ; 我们必须先将用户程序加载到内存中，才能获取到这些头部信息；
        ; 因此，我们先预取一个扇区的用户程序数据
        call read_hard_disk_0

        mov dx, [0x02]
        mov ax, [0x00]
        mov bx, 512
        div bx

        ; 商是 ax，余数是 dx
        cmp dx, 0
        jnz @1
        ; 如果余数不为 0，表明要读取的扇区数 = 商
        ; 而我们已经预读了一个扇区，所以还要读取的扇区数 = 商 - 1
        dec ax

    @1:
        ; 为什么有余数？
        ; 因为硬盘的读写是以扇区为单位的，读/写都是一个扇区，不能读/写多少字节
        ; 所以，如果程序大小，不是扇区大小的整数倍，就需要额外一个扇区来存储这些数据
        ;
        ; dx != 0，即余数不为 0，说明占用了一个额外的扇区，对应的要读取的扇区数 = 商 + 1
        ; 而我们之前已经预读了一个扇区，用来获取用户程序头部的信息，那么接下来，只需要判断商是否为 0？
        cmp ax, 0
        jz direct

        ; 下面要修改 ds 的值，所以先暂存一下
        push ds

        ; 如果 ax != 0，即还需要加载 ax 次扇区数据
        mov cx, ax

    @2:
        ; 计算参数 (di 不变、si+1、ds:bx + 512)
        
        ; 这里有一个问题是这样的，ds:bx + 512，需要考虑溢出情况：
        ;   - bx 是16位的，所能表示的最大值为 2^16 = 65536，即一个段的大小为 64KB
        ;   - 假设 bx + 512 > 65536，就会回绕到 0x0000 开始算，得到错误的结果
        ;   - 所以，为了避免溢出，可以计算段地址
        mov ax, ds
        add ax, 0x20
        mov ds, ax

        xor bx, bx
        inc si

        call read_hard_disk_0
        loop @2

        ; 恢复 ds 的值
        pop ds

        ; 进入这个步骤，表明读取完成
        call print_read_debug_msg
    
    direct:
        ; 计算用户程序入口点
        mov dx, [0x08]
        mov ax, [0x06]
        call calc_segment_base
        ; 回填修正后的入口点代码段基址
        mov [0x06], ax

        ; 打印段重定位开始的消息
        call print_realloc_debug_msg
        
        ; 开始处理段重定位表
        
        ; 需要重定位的项目数量
        mov cx, [0x0a]
        ; 重定位表首地址
        mov bx, 0x0c

    realloc:
        mov dx,[bx+0x02]                ;32位地址的高16位 
        mov ax,[bx]
        call calc_segment_base
        mov [bx],ax                     ;回填段的基址
        add bx,4                        ;下一个重定位项（每项占4个字节） 
        loop realloc

        ; 转移到用户程序
        jmp far [0x04]

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

;-------------------------------------------------------------------------------
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

;-------------------------------------------------------------------------------
print_realloc_debug_msg:
        ; 打印一个提示消息
        push si
        push bx

        ; 暂时指定光标标位置 = 0
        mov si, 160
        mov bx, realloc_msg

        call put_string
        pop bx
        pop si

;-------------------------------------------------------------------------------
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

;-------------------------------------------------------------------------------
put_char:
        ; 在显示缓冲区显示一个字符
        ; 参数：
        ;     cl: 字符

        mov byte [es:si], cl
        mov byte [es:si+1],0x07

        add si, 2

        ret

;-------------------------------------------------------------------------------
calc_segment_base:                       ;计算16位段地址
                                         ;输入：DX:AX=32位物理地址
                                         ;返回：AX=16位段基地址 
         push dx                          
         
         add ax,[cs:phy_base]
         adc dx,[cs:phy_base+0x02]
         shr ax,4
         ror dx,4
         and dx,0xf000
         or ax,dx
         
         pop dx
         
         ret
;-------------------------------------------------------------------------------
        phy_base dd 0x10000             ;用户程序被加载的物理起始地址

        read_msg db 'Finished read hard disk...'
                 db 0

        realloc_msg db 'Ready to realloc user program ss_segment...'
                    db 0

        jmup_far dw 0x0004, 0x0000

times 510-($-$$) db 0
                 db 0x55,0xaa
