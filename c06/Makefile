ASMFILE=c06_mbr.asm

all:$(ASMFILE)
	nasm -f bin $(ASMFILE) -o mbr.bin
	-rm c6.vhd
	VBoxManage convertfromraw mbr.bin c6.vhd --format VHD --variant Fixed