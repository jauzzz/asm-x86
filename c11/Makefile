ASMFILE=mbr.asm

all:$(ASMFILE)
	nasm -f bin $(ASMFILE) -o mbr.bin
	-rm c11.vhd
	VBoxManage convertfromraw mbr.bin c11.vhd --format VHD --variant Fixed
