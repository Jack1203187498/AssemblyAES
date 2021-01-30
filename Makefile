all:
	nasm -f elf64 aes.asm -o aes.o -O3
	nasm -f elf64 speed.asm -o speed.o -O3
	nasm -f elf64 speeden.asm -o speeden.o -O3
	nasm -f elf64 speedtest.asm -o speedtest.o -O3
	gcc -c test.c -o test.o -lpthread
	gcc -no-pie test.o aes.o speed.o speeden.o speedtest.o -o aes -lpthread -O3

clean:
	rm *.o
	rm aes
