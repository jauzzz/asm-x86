ASMFILE=mbr.asm

all:$(ASMFILE)
	nasm -f bin $(ASMFILE) -o mbr.bin
	nasm -f bin core.asm -o core.bin
	nasm -f bin user.asm -o user.bin
	-rm core.vhd
	dd if=/dev/zero of=mbr.img count=10000
	dd if=mbr.bin of=mbr.img conv=notrunc
	dd if=core.bin of=mbr.img seek=1 conv=notrunc
	dd if=user.bin of=mbr.img seek=50 conv=notrunc
	dd if=diskdata.txt of=mbr.img seek=100  conv=notrunc
	VBoxManage convertfromraw mbr.img core.vhd --format VHD

clean:
	-rm *.vhd
	-rm *.bin
	-rm *.img
