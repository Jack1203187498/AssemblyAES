#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(void)
{
	FILE *fp;
	char *filename = "3.txt";
	unsigned int ch;
	unsigned int input[4];
	unsigned int i=0, count = 0;
	if((fp=fopen(filename,"rb"))== NULL )
	{
		printf("Can not open %s!\n",filename);
		exit(0);
	}
	//printf("原字符\t二进制\n");
	ch=fgetc(fp);//取字符
	while(!feof(fp))
	{
		//printf("%02X", ch);
		input[i] = input[i] << 8;
		input[i] = input[i] + ch;
		count++;
		if (count%4==0){
			printf("%08X", input[i]);
			i++;
			i=i%4;	
			if(i==0){
				printf("\n");
			}
		}
	ch=fgetc(fp);
	}
	printf("\n%d", i);
	printf("\n%d\n", count%4);
	//printf("\n%08X\n", input[i]);
	if(i != 0 || count%4 != 0){
		printf("\n");
		input[i] = input[i] << 8;
		input[i] = input[i] + 0x10;
		count++;
		while(i != 3 || count%4 != 0){
			count++;
			input[i] = input[i] << 8;
		}
		for(int j=0;j<4;j++){
			printf("%08X", input[j]);	
		}
	}
	fclose(fp);
	return 0;
}
