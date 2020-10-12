

    ; NOTE: 初始化栈段
    mov eax, cs
    mov ss, eax
    mov sp, 0x7c00

    ; NOTE: 初始化全局描述符表、GDTR
    ; 假定，gdt 的物理地址为 0x00007e00，要将其转化为段地址：偏移地址，以便后续添加段描述符
    mov eax, [cs:pgdt+0x7c00+0x02]
    xor edx, edx
    mov ebx, 16
    div ebx
    ; eax = 段地址，ebx = 偏移地址
    mov ds, eax
    mov ebx, edx

    ; 添加段描述符：共添加 5 个段描述符
    ;   0. 空描述符
    ;   1. 数据段
    ;   2. 代码段
    ;   3. 代码段别名段（用作数据修改用）
    ;   4. 栈段

    ; 0#空描述符，这是一个规定
    mov dword [ebx+0x00], 0x00
    mov dword [ebx+0x04], 0x00

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
    mov dword [ebx+0x10], 0x7c0001ff
    mov dword [ebx+0x14], 0x00409800

    ; 3#描述符，是代码段的别名描述符，是一个数据段，作修改代码段内容使用
    ; 段描述符字段:
    ;   段基地址：0x00007c00, 段界限：0x000001FF
    ;   G=0，D/B=1，L=0，AVL=0，P=1，DPL=00，S=1，TYPE=0010
    mov dword [ebx+0x18], 0x7c0001ff
    mov dword [ebx+0x1c], 0x00409200

    ; 4#描述符，是堆栈描述符，从 0x6c00 ~ 0x7c00
    ; 段描述符字段:
    ;   段基地址：0x00007c00, 段界限：0x000FFFFE
    ;   G=1，D/B=1，L=0，AVL=0，P=1，DPL=00，S=1，TYPE=0110
    mov dword [ebx+0x20], 0x7c00fffe
    mov dword [ebx+0x24], 0x00cf9600

    ; 描述符添加完毕，初始化全局描述符表寄存器 GDTR
    ; 更新全局描述符表段界限 = 描述符大小(8字节) * 描述符数量 - 1
    mov word [cs:pgdt+0x7c00], 39

    lgdt [cs:pgdt+0x7c00]

    ; NOTE: 打开 A20
    in al, 0x92
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
    jmp dword 0x0010:flush

    ; NOTE: 此处是伪指令，通知编译器按照 32位操作数模式进行编译（因为已经进入了保护模式了）
    [bits 32]

flush:
    mov eax,0x0018                      
    mov ds,eax
      
    mov eax,0x0008                     ;加载数据段(0..4GB)选择子
    mov es,eax
    mov fs,eax
    mov gs,eax

    mov eax,0x0020                     ;0000 0000 0010 0000
    mov ss,eax
    xor esp,esp                        ;ESP <- 0

    mov dword [es:0x0b8000],0x072e0750 ;字符'P'、'.'及其显示属性
    mov dword [es:0x0b8004],0x072e074d ;字符'M'、'.'及其显示属性
    mov dword [es:0x0b8008],0x07200720 ;两个空白字符及其显示属性
    mov dword [es:0x0b800c],0x076b076f ;字符'o'、'k'及其显示属性

    ;开始冒泡排序 
    mov ecx,pgdt-string-1              ;遍历次数=串长度-1 
  @@1:
    push ecx                           ;32位模式下的loop使用ecx 
    xor bx,bx                          ;32位模式下，偏移量可以是16位，也可以 
  @@2:                                 ;是后面的32位 
    mov ax,[string+bx] 
    cmp ah,al                          ;ah中存放的是源字的高字节 
    jge @@3 
    xchg al,ah 
    mov [string+bx],ax 
  @@3:
    inc bx 
    loop @@2 
    pop ecx 
    loop @@1

    mov ecx,pgdt-string
    xor ebx,ebx                        ;偏移地址是32位的情况 
  @@4:                                 ;32位的偏移具有更大的灵活性
    mov ah,0x07
    mov al,[string+ebx]
    mov [es:0xb80a0+ebx*2],ax          ;演示0~4GB寻址。
    inc ebx
    loop @@4

    ; 已经禁止中断，不会再被唤醒
    hlt

;-------------------------------------------------------------------------------
    string           db 's0ke4or92xap3fv8giuzjcy5l1m7hd6bnqtw.'
;-------------------------------------------------------------------------------

    pgdt         dw 0
                 dd 0x00007e00     ;GDT的物理地址

    times 510-($-$$) db 0
                     db 0x55,0xaa
