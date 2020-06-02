ASMFILE=c07_mbr.asm

all:$(ASMFILE)
	nasm -f bin $(ASMFILE) -o mbr.bin
	-rm c7.vhd
	VBoxManage convertfromraw mbr.bin c7.vhd --format VHD --variant Fixed