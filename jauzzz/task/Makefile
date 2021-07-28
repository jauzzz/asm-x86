all:mbr.asm
	nasm -f bin mbr.asm -o mbr.bin
	nasm -f bin core.asm -o core.bin
	nasm -f bin user.asm -o task.bin
	-rm task.vhd
	dd if=/dev/zero of=mbr.img count=10000
	dd if=mbr.bin of=mbr.img conv=notrunc
	dd if=core.bin of=mbr.img seek=1  conv=notrunc
	dd if=task.bin of=mbr.img seek=50  conv=notrunc
	dd if=diskdata.txt of=mbr.img seek=100  conv=notrunc
	VBoxManage convertfromraw mbr.img task.vhd --format VHD
