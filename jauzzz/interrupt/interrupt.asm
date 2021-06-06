        ;文件名: program.asm
        ;文件说明: 修改中断向量表 70 号为自定义的中断处理程序
        ;       - 计算机启动后，RTC 芯片的中断号默认是 0x70
        ;       - RTC (Real Time Clock)：时钟芯片
        ;
        ; NOTE: 中断机制的诞生
        ;    为了分享计算能力，处理器应该为多用户多任务提供硬件一级的支持。
        ;      - 在单处理器的系统中，允许同时有多个程序在内存中等待处理器的执行。
        ;      - 当一个程序正在等待输入输出时，允许另一个程序从处理器那里获得控制权
        ;
        ;    为了达到这个目的，需要做两件事情：
        ;      - 把多个程序调入内存（操作系统支持）
        ;      - 当一个程序执行时，能够知道别的程序在等待
        ;
        ;     于是，中断这个机制就诞生了。
        ;     中断，就是打断当前处理器的执行流程，去执行另外一些和当前工作不相干的指令，执行完后，返回到原流程。

SECTION header align=16 vstart=0

        program_length  dd program_end

        ;用户程序入口点
        code_entry      dw start                ;偏移地址[0x04]
                        dd section.code.start   ;段地址[0x06] 

        ; 需要一个额外的数据，段重定位表的长度，来确定有多少个段
        realloc_tbl_len dw (header_end-realloc_begin)/4

    realloc_begin:
        ; 段重定位表
        code_segment    dd section.code.start
        data_segment    dd section.data.start
        stack_segment   dd section.stack.start

header_end:

;===============================================================================
SECTION code align=16 vstart=0

new_int_0x70:
        ; 新的中断程序：给屏幕上显示的数字 + 1
        
        push ax
        push bx
        push cx
        push dx
        push es
        
        .w0:                                    
        mov al,0x0a                        ;阻断NMI。当然，通常是不必要的
        or al,0x80                          
        out 0x70,al
        in al,0x71                         ;读寄存器A
        test al,0x80                       ;测试第7位UIP 
        jnz .w0                            ;以上代码对于更新周期结束中断来说 
                                                ;是不必要的 
        xor al,al
        or al,0x80
        out 0x70,al
        in al,0x71                         ;读RTC当前时间(秒)
        push ax

        mov al,2
        or al,0x80
        out 0x70,al
        in al,0x71                         ;读RTC当前时间(分)
        push ax

        mov al,4
        or al,0x80
        out 0x70,al
        in al,0x71                         ;读RTC当前时间(时)
        push ax

        mov al,0x0c                        ;寄存器C的索引。且开放NMI 
        out 0x70,al
        in al,0x71                         ;读一下RTC的寄存器C，否则只发生一次中断
                                                ;此处不考虑闹钟和周期性中断的情况 
        mov ax,0xb800
        mov es,ax

        pop ax
        call bcd_to_ascii
        mov bx,12*160 + 36*2               ;从屏幕上的12行36列开始显示

        mov [es:bx],ah
        mov [es:bx+2],al                   ;显示两位小时数字

        mov al,':'
        mov [es:bx+4],al                   ;显示分隔符':'
        not byte [es:bx+5]                 ;反转显示属性 

        pop ax
        call bcd_to_ascii
        mov [es:bx+6],ah
        mov [es:bx+8],al                   ;显示两位分钟数字

        mov al,':'
        mov [es:bx+10],al                  ;显示分隔符':'
        not byte [es:bx+11]                ;反转显示属性

        pop ax
        call bcd_to_ascii
        mov [es:bx+12],ah
        mov [es:bx+14],al                  ;显示两位小时数字
        
        mov al,0x20                        ;中断结束命令EOI 
        out 0xa0,al                        ;向从片发送 
        out 0x20,al                        ;向主片发送 

        pop es
        pop dx
        pop cx
        pop bx
        pop ax

        iret

;-------------------------------------------------------------------------------
bcd_to_ascii:                            ;BCD码转ASCII
                                         ;输入：AL=bcd码
                                         ;输出：AX=ascii
        mov ah,al                          ;分拆成两个数字 
        and al,0x0f                        ;仅保留低4位 
        add al,0x30                        ;转换成ASCII 

        shr ah,4                           ;逻辑右移4位 
        and ah,0x0f                        
        add ah,0x30

        ret

;-------------------------------------------------------------------------------
start:
        ; NOTE:
        ;    所谓中断处理，归根结底就是处理器要执行一段与该中断有关的程序/指令
        ;    处理器可以识别 256 个中断，那么理论上就需要 256 段程序
        ;    处理器要求把这些程序的入口点集中放在物理内存 0x00000 ~ 0x003ff 共 1KB 的空间内，称为中断向量表(Interrupt Vector Table, IVT)
        ;
        ; 安装一个新的 70 号中断程序
        ; 要安装一个新的中断程序，就是把中断向量表中对应中断号的处理程序地址，改为新的中断程序的地址

        ; 调用方法，需要先初始化栈
        ; 那么问题来了，用户程序的栈地址是哪里呢？
        ; 我们读取用户程序到内存，并没有对用户程序的栈空间进行初始化/分配
        ; 
        ; 汇编里是如何对程序的栈进行分配的呢，是通过在程序里面定义一个栈段
        ; 所以我们现在给 iterrupt.asm 定义一个栈段，大小为 256 字节
        ; 然后栈段的空间就可以作为栈来使用
        ; 但还有一个问题，栈段需要有 ss:sp 来指定地址，sp 由标号 ss_pointer 表示，那么 ss 呢？
        ; 用户程序在加载到物理内存地址之后，ss 也会跟着变化
        ;   - QA: 如果不额外定义一个栈段，只是由标号 ss_segment 来表示栈空间的开始可以吗？
        ;   - QA: 假设额外定义栈段了，那么加载后的 ss 的值是多少呢？
        ; 
        ; NOTE:
        ;   如果不额外定义栈段，也是可以的。
        ;   有标号 ss_segment，在代码段中，那么就可以有 cs:ss_segment 算出栈段的初始地址（32位物理地址）
        ;   有标号 ss_pointer，就可以算出栈段的终止地址
        ;   进而可以计算出，栈段的段地址
        ;
        ;   但我们定义了栈段，加载后的 ss 的值是多少呢？
        ;   其实计算方式，跟上面的不额外定义栈段的方式是一样的。
        ;   那定不定义栈段有区别吗？
        ;   目前来说，是没区别的，只要段地址算对了，用户程序控制不往栈段里面改内容，实际上是一样的

        ; 在控制转移到用户程序之前，ds 指向的是用户程序的头部
        mov ax, [stack_segment]
        mov ss, ax
        mov sp, ss_pointer
        ; 下面需要用到 ds，所以也要修改 ds 的值
        mov ax, [data_segment]
        mov ds, ax

        mov bx,init_msg                    ;显示初始信息 
        call put_string

        mov bx,inst_msg                    ;显示安装信息 
        call put_string

        ; NOTE: 
        ; 这里有一些额外需要注意的地方：
        ;
        ; 中断是分为3种：
        ;       1. 外部硬件中断（分为可屏蔽中断、不可屏蔽中断）
        ;       2. 内部中断（由执行的指令引起的）
        ;       3. 软中断（由 int 指令引起的）
        ; 当中断发生时，处理器处理完当前这条指令，就会去响应中断
        ;
        ; 所以修改中断向量表时，要先禁止中断;
        ; 否则，当产生了要修改的中断号的中断时，就会产生错误

        ;计算0x70号中断在IVT中的偏移
        mov al, 0x70
        mov bl, 4
        mul bl
        mov bx, ax

        cli

        ; 现在可以安装 70号的自定义中断
        ; 找到中断向量表 70 号的位置，将自定义中断处理程序的地址替换过去
        push es
        mov ax, 0x0000
        mov es, ax

        mov word [es:bx], new_int_0x70
        
        mov ax, cs
        mov word [es:bx+2], ax

        pop es

        ; 设置 RTC 产生中断信号 0x7c0
        ; 下面是设置 RTC 更新周期结束中断，每当 RTC 更新了 CMOS RAM 的日期和时间后，发出中断。
        mov al,0x0b                        ;RTC寄存器B
        or al,0x80                         ;阻断NMI 
        out 0x70,al
        mov al,0x12                        ;设置寄存器B，禁止周期性中断，开放更 
        out 0x71,al                        ;新结束后中断，BCD码，24小时制 

        mov al,0x0c
        out 0x70,al
        in al,0x71                         ;读RTC寄存器C，复位未决的中断状态

        ; 让 8259 允许 RTC 中断
        in al,0xa1                         ;读8259从片的IMR寄存器 
        and al,0xfe                        ;清除bit 0(此位连接RTC)
        out 0xa1,al                        ;写回此寄存器 

        ; 重新开放中断
        sti

        mov bx,done_msg                    ;显示安装完成信息 
        call put_string

        mov bx,tips_msg                    ;显示提示信息
        call put_string

    .idle:
        ; 进入低功耗模式（会被 CPU 唤醒）
        hlt
        jmp .idle

;-------------------------------------------------------------------------------
put_string:                              ;显示串(0结尾)。
                                         ;输入：DS:BX=串地址
         mov cl,[bx]
         or cl,cl                        ;cl=0 ?
         jz .exit                        ;是的，返回主程序 
         call put_char
         inc bx                          ;下一个字符 
         jmp put_string

   .exit:
         ret

;-------------------------------------------------------------------------------
put_char:                                ;显示一个字符
                                         ;输入：cl=字符ascii
         push ax
         push bx
         push cx
         push dx
         push ds
         push es

         ;以下取当前光标位置
         mov dx,0x3d4
         mov al,0x0e
         out dx,al
         mov dx,0x3d5
         in al,dx                        ;高8位 
         mov ah,al

         mov dx,0x3d4
         mov al,0x0f
         out dx,al
         mov dx,0x3d5
         in al,dx                        ;低8位 
         mov bx,ax                       ;BX=代表光标位置的16位数

         cmp cl,0x0d                     ;回车符？
         jnz .put_0a                     ;不是。看看是不是换行等字符 
         mov ax,bx                       ; 
         mov bl,80                       
         div bl
         mul bl
         mov bx,ax
         jmp .set_cursor

 .put_0a:
         cmp cl,0x0a                     ;换行符？
         jnz .put_other                  ;不是，那就正常显示字符 
         add bx,80
         jmp .roll_screen

 .put_other:                             ;正常显示字符
         mov ax,0xb800
         mov es,ax
         shl bx,1
         mov [es:bx],cl

         ;以下将光标位置推进一个字符
         shr bx,1
         add bx,1

 .roll_screen:
         cmp bx,2000                     ;光标超出屏幕？滚屏
         jl .set_cursor

         mov ax,0xb800
         mov ds,ax
         mov es,ax
         cld
         mov si,0xa0
         mov di,0x00
         mov cx,1920
         rep movsw
         mov bx,3840                     ;清除屏幕最底一行
         mov cx,80
 .cls:
         mov word[es:bx],0x0720
         add bx,2
         loop .cls

         mov bx,1920

 .set_cursor:
         mov dx,0x3d4
         mov al,0x0e
         out dx,al
         mov dx,0x3d5
         mov al,bh
         out dx,al
         mov dx,0x3d4
         mov al,0x0f
         out dx,al
         mov dx,0x3d5
         mov al,bl
         out dx,al

         pop es
         pop ds
         pop dx
         pop cx
         pop bx
         pop ax

         ret
;-------------------------------------------------------------------------------
put_number:
        push bx
        push ax
        push es

        mov bx, 0xb800
        mov es, bx

        mov bx, 24*160

        mov al, [interrupt_num]
        call bcd_to_ascii

        mov [es:bx], ah
        mov [es:bx+2], al

        pop es
        pop ax
        pop bx

;===============================================================================
SECTION data align=16 vstart=0
        init_msg       db 'Starting...',0x0d,0x0a,0

        inst_msg       db 'Installing a new interrupt 70H...',0

        done_msg       db 'Done.',0x0d,0x0a,0

        tips_msg       db 'Clock is now working.',0

        interrupt_num  db 0
;===============================================================================
SECTION stack align=16 vstart=0
        resb 256

ss_pointer:

;===============================================================================
SECTION trail align=16
program_end: