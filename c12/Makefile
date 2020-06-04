ASMFILE=c12_mbr.asm

all:$(ASMFILE)
	nasm -f bin $(ASMFILE) -o mbr.bin
	-rm c12.vhd
	VBoxManage convertfromraw mbr.bin c12.vhd --format VHD --variant Fixed
