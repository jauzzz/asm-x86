ASMFILE=boot.asm

all:$(ASMFILE)
	nasm -f bin $(ASMFILE) -o mbr.bin
	-rm boot.vhd
	VBoxManage convertfromraw mbr.bin boot.vhd --format VHD --variant Fixed