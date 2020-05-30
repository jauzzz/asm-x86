; 对于加载器来说，需要知道两个事情:
;   - 用户程序的硬盘地址（逻辑扇区号）
;   - 加载到内存的哪个物理地址（x86 的空闲内存范围是 0x10000 ~ 0x9FFFFF）

        app_lba_start equ 100       ; 声明常数（用户程序的起始逻辑扇区号）

; 当加载器知道了参数之后，就可以进行实际上的加载
; 加载器的工作内容有三个：
;   1. 从硬盘读取用户程序，并将其加载到内存中的指定位置
;   2. 重定位用户程序
;   3. 控制转移


;------------------------------ 程序初始化 ----------------------------------------
; 设置堆栈段和栈指针 
        mov ax,0
        mov ss,ax
        mov sp,ax
; 设置数据段
        mov dx, [cs:phy_base+0x02]
        mov ax, [cs:phy_base]
        mov bx, 16
        div bx
        mov ds,ax

; 计算需要读取多少扇区，调用硬盘读取子程序
; 在调用之前，需要初始化它的参数: si、di、bx
        xor di, di
        mov si, app_lba_start
        xor bx, bx

; 第一次读取
        call read_user_program

; 需要读取多少个扇区 = 程序长度 / 扇区大小
; 除数（程序长度）是32位，所以是一个32位除法
; 32位除法结果：AX存储除法操作的商，DX存储除法操作的余数
        mov dx, [2]
        mov ax, [0]
        mov bx, 512
        div bx
        cmp dx, 0
        jne @read
        dec ax, 1

read:
        ; 商为零的时候，读取完成，然后进行重定位操作
        cmp ax, 0
        jz realloc

        ; 由于会修改段的地址，需要将原来的段地址先压栈
        push ds

        ; 否则继续读取，次数为 ax
        mov cx, ax
read_1:
        ; 这里不能持续使用偏移地址 bx ，因为一个段的大小为 64 KB
        ; 假设用户程序大于 64 KB，bx 就会回到段的开头，覆盖掉原先的内容
        ; 所以每次读取，都构造一个新段，使得地址是连续的且不会因为超过段大小而出现问题
        
        mov ax, ds
        inc ax, 0x20
        mov ds, ax

        xor bx,bx   ; 由于是使用新段，所以偏移地址始终是 0
        inc si
        call read_user_program
        loop read_1

        ; 结束读取之后，恢复原始的段地址
        pop ds

direct:
        mov dx, [0x08]
        mov ax, [0x06]
        call calc_segment_base
        mov [0x06], ax

        mov cx, [0x0a]
        mov bx, [0x0c]

realloc:
        mov dx, [bx+0x02]
        mov ax, [bx]
        call calc_segment_base
        mov [bx], ax
        add bx, 4
        loop realloc

        ; 重定向结束之后，转移控制
        jmp far [0x04]

;------------------------------ 硬盘读取 ----------------------------------------
; 硬盘的读取以扇区为单位，一扇区 = 512 字节
; 不清楚用户程序的大小，所以将读取用户程序，写成过程
read_user_program:
        ; 过程调用协议（通过寄存器传递参数）
        ;   1. push 保护现场（保护现场的意思是，将过程可能会破坏的原有寄存器的值，保留一份，待过程结束时还原）
        ;   2. 过程执行
        ;   3. pop 恢复现场
        ;
        ; 此处约定
        ;   - 起始逻辑扇区号，存放在 si 和 di 中
        ;   - 内存的起始偏移地址，存放在 bx 中
        ;   
        

        ; --- 保护现场 ---
        push ax        
        push bx
        push cx
        push dx
        

        ; 硬盘的读写，通过硬盘控制器端口来进行
        ;   1. 设置要读取的扇区数量（写入 0x1f2 端口，这是个 8 位端口，所以每次只能读写 255 个扇区）
        ;   2. 设置起始 LBA 扇区号 （我们假设使用的是 LBA28 标准，所以扇区号占用 28 个比特，总大小为 128 GB，
        ;                          因此需要 4 个 8 位端口来表示，分别写入 0x1f3 ~ 0x1f6）
        ;   3. 向端口 0x1f7 写入 0x20，请求硬盘读
        ;   4. 等待读写操作完成
        ;   5. 连续取出数据
        

        ; --- 设置扇区数量 ---
        mov dx, 0x1f2
        mov al, 1
        out dx, al
        

        ; --- 设置起始 LBA 扇区号 ---
        ; 扇区 100 的 LBA28 值是：0000 0000 0000 0000 0000 0110 0100
        ; 一个硬盘的端口有 8 位，4 个端口为 32 位，那么还有 31~28 位是没有值的
        ; 这 4 位的值有特殊的规定：第 30 位的值表示扇区编址模式（LBA / CHS），第 28 位表示硬盘号（0表示主盘，1表示从盘）
        ; 对应到 CPU，参数 LBA扇区号 则需要 2 个 16 位的寄存器来表示（这里使用 si di）

        inc dx
        mov ax, si
        out dx, al

        inc dx
        mov al, ah
        out dx, al

        inc dx
        mov ax, di
        out dx, al

        inc dx
        mov al, 0xe0
        or al, ah
        out dx, al


        ; --- 向端口 0x1f7 写入 0x20，请求硬盘读 ---
        inc dx
        mov al, 0x20
        out dx, al


        ; --- 等待读写操作完成 ---
        ; 请求读之后，硬盘就会开始被读取，如何判断硬盘读取完成？
        ; 通过 端口 的数值来判断，当读写完成之后，会改变 0x1f7 端口
        ;
        ; 0x1f7 端口:
        ;   - 第 7 位：硬盘是否忙碌，1 为忙碌
        ;   - 第 3 位: 硬盘是否准备读写数据，1 为已准备
        ;   - 第 0 位: 前一个命令是否出错，1 为出错，出错原因存储为端口 0x1f1
        mov dx, 0x1f7

    .waits:
        in al, dx
        and al, 0x88
        cmp al, 0x88
        jnz .waits


        ; --- 连续取出数据 ---
        ; 设置循环的次数，初始化硬盘的数据端口，将硬盘数据从数据端口加载到内存地址
        ; 至此，就成功读取完了一个扇区
        mov cx, 256
        mov dx, 0x1f0

    .readw:
        in ax, dx
        mov [bx], ax
        add bx, 2
        loop .readw


        ; --- 恢复现场 ---
        pop dx
        pop cx
        pop bx
        pop ax
        
        
        ; 表示过程结束，返回到原过程
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

 times 510-($-$$) db 0
                  db 0x55,0xaa