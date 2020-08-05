all:c16_mbr.asm
	nasm -f bin c16_mbr.asm -o mbr.bin
	nasm -f bin c16_core.asm -o core.bin
	nasm -f bin c16.asm -o c16.bin
	-rm c16.vhd
	dd if=/dev/zero of=mbr.img count=10000
	dd if=mbr.bin of=mbr.img conv=notrunc
	dd if=core.bin of=mbr.img seek=1  conv=notrunc
	dd if=c16.bin of=mbr.img seek=50  conv=notrunc
	dd if=diskdata.txt of=mbr.img seek=100  conv=notrunc
	VBoxManage convertfromraw mbr.img c16.vhd --format VHD
