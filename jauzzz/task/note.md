段描述符提供了：
- 段的合法性检查
- 段的偏移值合法性检查

但段描述符没有提供多个进程之间的隔离，进程（任务）A 可以使用非自身的描述符（包括系统的描述符）

为了实现隔离，每个任务都有自己的描述符表，称为 `局部描述符表 LDT(Local Descriptor Table)`
在系统中，会有很多个任务在进行，所以为了追踪和访问 LDT，处理器使用了 `局部描述符寄存器（LDTR Register）`

在一个多任务的环境中，当任务切换发生时，必须保护旧任务的运行状态，或者说是保护现场，保护的内容包括：
- 通用寄存器
- 段寄存器
- 栈指针寄存器 ESP
- 指令指针寄存器 EIP
- 状态寄存器 EFLAGS

为了保存任务的状态，并在下次重新执行时恢复它们，每个任务都要用一个额外的内存区域保存相关信息，称为 `任务状态段(TSS)`
任务状态段 TSS 具有固定的格式，最小尺寸是 104 字节，处理器固件能够识别 TSS 的每个元素，并在任务切换时读取其中信息
