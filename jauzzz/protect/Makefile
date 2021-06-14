ASMFILE=protect.asm

all:$(ASMFILE)
	nasm -f bin $(ASMFILE) -o protect.bin
	-rm protect.vhd
	VBoxManage convertfromraw protect.bin protect.vhd --format VHD --variant Fixed

clean:
	rm *.vhd
	rm *.bin
	rm *.img
