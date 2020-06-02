help: ## Display this help message
	@echo "Please use \`make <target>' where <target> is one of"
	@perl -nle'print $& if m{^[\.a-z%A-Z_-]+:.*?## .*$$}' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m  %-25s\033[0m %s\n", $$1, $$2}'

c1:c09_mbr.asm
	nasm -f bin c09_mbr.asm -o c09_mbr.bin
	nasm -f bin c09_1.asm -o c09_1.bin
	-rm c91.vhd
	dd if=/dev/zero of=mbr.img count=10000
	dd if=c09_mbr.bin of=mbr.img conv=notrunc
	dd if=c09_1.bin of=mbr.img seek=100  conv=notrunc
	VBoxManage convertfromraw mbr.img c91.vhd --format VHD

c2:c09_mbr.asm
	nasm -f bin c09_mbr.asm -o c09_mbr.bin
	nasm -f bin c09_2.asm -o c09_2.bin
	-rm c92.vhd
	dd if=/dev/zero of=mbr.img count=10000
	dd if=c09_mbr.bin of=mbr.img conv=notrunc
	dd if=c09_2.bin of=mbr.img seek=100  conv=notrunc
	VBoxManage convertfromraw mbr.img c92.vhd --format VHD