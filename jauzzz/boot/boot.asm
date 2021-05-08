        ;文件名: boot.asm
        ;文件说明: 硬盘主引导扇区代码 -- 显示hello world

        ; ====
        ; 开机实际上只做两件事：
        ;	1. 加载 BIOS ROM
        ;	2. 加载 操作系统(OS)
		;
		; BIOS ROM 的主要工作是：硬件的检测、诊断和初始化，并提供与外围设备交互的例程
		; OS 的主要工作是：管理硬件资源，提供程序运行环境
		;
		; 如何加载 BIOS ROM/OS ？
		; 	加载程序这个动作的本质就是，将 CS:IP 指向这个程序文本的第一行指令
		;   简单来说，就是这么两条指令：
		;		- mov cs, xxx 
		;		- mov ip, xxx
		; 	所以，对于加载这个动作来说，要确认的参数就是，对应指令的内存地址
		;
		; 实际上，BIOS ROM 和 OS 都是文本，存储在计算机里（可以是 ROM 或 RAM）
		;	- ROM: 非易失性存储器，电流断电不会影响所存储的数据
		;	- RAM: 易失性存储器，当电流断电后，所存储的数据便会消失
		;
		; 加载 BIOS:
		; 	开机的时候，RAM 是没有数据的，所以要从 ROM 里获取数据
		; 	通常划分一个特定区域，用于存储开机的指令，称为 BIOS ROM
		;	BIOS ROM 加载完，就会去加载 OS
		;   那么，也需要在 BIOS ROM 里，指明 OS 的指令地址
		;	而 OS 的程序文本，存储在硬盘里，所以需要先加载到内存
		;
		; 加载 OS:
		;	OS 的程序文本，存储在硬盘
		;	要获取 OS 的第一条指令，首先需要将硬盘里的 OS 程序文本加载到内存
		;	通常是从硬盘的 0 面 0 道 1 扇区 开始进行加载，这个扇区也称为主引导扇区
		; 	它是由操作系统提供的，以 `0x55 0xAA` 作为主引导扇区结束的有效标志
		;   如果是有效的，会将主扇区代码，加载到物理内存地址 0x7c00
		;
		; 主引导扇区的作用:
		;	1. 检测用来启动计算机的操作系统，并计算它的硬盘位置
		;   2. 将操作系统的自举代码加载到内存，跳转执行，直到操作系统完全启动


		; BIOS ROM 在 Virtual Box 已经内置，我们只需要编写 “主引导扇区代码”
		mov ax, 0xb800
		mov es, ax

		;以下显示字符串"Label offset:"
		mov byte [es:0x00],'H'
		mov byte [es:0x01],0x07
		mov byte [es:0x02],'e'
		mov byte [es:0x03],0x07
		mov byte [es:0x04],'l'
		mov byte [es:0x05],0x07
		mov byte [es:0x06],'l'
		mov byte [es:0x07],0x07
		mov byte [es:0x08],'o'
		mov byte [es:0x09],0x07
		mov byte [es:0x0a],' '
		mov byte [es:0x0b],0x07
		mov byte [es:0x0c],"w"
		mov byte [es:0x0d],0x07
		mov byte [es:0x0e],'o'
		mov byte [es:0x0f],0x07
		mov byte [es:0x10],'r'
		mov byte [es:0x11],0x07
		mov byte [es:0x12],'l'
		mov byte [es:0x13],0x07
		mov byte [es:0x14],'d'
		mov byte [es:0x15],0x07
		mov byte [es:0x16],'!'
		mov byte [es:0x17],0x07

	; 进入无限循环
	infi: jmp near infi

; 主引导扇区代码大小应该在一个扇区内，并且有有效的结束标志 0x55 0xaa
times 510-($-$$) db 0
				 db 0x55, 0xaa
