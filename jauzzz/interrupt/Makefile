ASMFILE=mbr.asm
USERFILE=interrupt.asm

all:$(ASMFILE)
	nasm -f bin $(ASMFILE) -o mbr.bin
	nasm -f bin $(USERFILE) -o user.bin
	-rm interrupt.vhd
	dd if=/dev/zero of=mbr.img count=10000
	dd if=mbr.bin of=mbr.img conv=notrunc
	dd if=user.bin of=mbr.img seek=100  conv=notrunc
	VBoxManage convertfromraw mbr.img interrupt.vhd --format VHD --variant Fixed

clean:
	rm *.vhd
	rm *.bin
	rm *.img
