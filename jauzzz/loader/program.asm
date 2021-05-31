        ;文件名: program.asm
        ;文件说明: 一段 hello jauzzz 示例代码
        ;       用于展示加载器的加载过程
        ;       在实际的开机过程中/程序运行过程中，该段代码可以是内核代码或普通的应用程序代码

SECTION code vstart=0

        program_length dd program_end

        ; 简单测试一下，展示一个 感叹号
        mov ax, 0xb800
        mov es, ax

        mov bx, 0xbe0

        ;以下显示字符串"User program!"
        mov byte [es:bx],'U'
        mov byte [es:bx+1],0x24
        add bx, 2

        mov byte [es:bx],'s'
        mov byte [es:bx+1],0x24
        add bx, 2

        mov byte [es:bx],'e'
        mov byte [es:bx+1],0x24
        add bx, 2

        mov byte [es:bx],'r'
        mov byte [es:bx+1],0x24
        add bx, 2

        mov byte [es:bx],' '
        mov byte [es:bx+1],0x24
        add bx, 2

        mov byte [es:bx],'p'
        mov byte [es:bx+1],0x24
        add bx, 2

        mov byte [es:bx],'r'
        mov byte [es:bx+1],0x24
        add bx, 2

        mov byte [es:bx],'g'
        mov byte [es:bx+1],0x24
        add bx, 2

        mov byte [es:bx],'r'
        mov byte [es:bx+1],0x24
        add bx, 2

        mov byte [es:bx],'a'
        mov byte [es:bx+1],0x24
        add bx, 2

        mov byte [es:bx],'m'
        mov byte [es:bx+1],0x24
        add bx, 2

        mov byte [es:bx],'!'
        mov byte [es:bx+1],0x24
        add bx, 2

        jmp $


;===============================================================================
SECTION trail align=16
program_end: