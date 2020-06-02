ASMFILE=c05_mbr.asm

all:$(ASMFILE)
	nasm -f bin $(ASMFILE) -o mbr.bin
	-rm c5.vhd
	VBoxManage convertfromraw mbr.bin c5.vhd --format VHD --variant Fixed