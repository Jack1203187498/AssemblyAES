#include<stdio.h>
#include<time.h>
#include<pthread.h>
#include<unistd.h>
#include<stdlib.h>
#include<sys/wait.h>
#include<sys/types.h>
#include<sys/shm.h>
#include<sys/ipc.h>
#include<sys/sem.h>
#include<string.h>
#define MAX 1600*8

extern void _begin(unsigned char *, unsigned char*);//在模式1和2里面初始化输入和密钥
extern unsigned char* _begintoencry();//模式1
extern unsigned char* _begintodecry();//模式2

extern void _speedbegin();//模式3、4
extern void _speedbeginen(unsigned char*, unsigned char*, unsigned char*, int round);//模式5
extern void _speedbegintest(unsigned char*, unsigned char*, unsigned char*, int round);//模式6

struct SharedMemory{
	int ptr;
	int count;
	int round;
	int finish;
	int pids;
	char input[MAX];
	char output[MAX];
};//共享内存

int count = 0;//多线程的数量
void thread_func(){
	_speedbegin();
	count++;
	return;
}

void output(char *msg, unsigned char *p){//输出16字节
	printf("%s:\t", msg);
	for(int i = 0; i < 16; i++){
		printf("%02X", p[i]);
	}
	printf("\n");
	return;
}

int main(int argc, char **argv){
	unsigned char key[16];
	unsigned char input[MAX];
	unsigned char *p = input;
	FILE *fp;
	char *filename_read = argv[1];
	char *filename_write = argv[2];
	char *filename_key = argv[3];
	int mode = atoi(argv[4]);
	unsigned int i = 0, count = 0, flag;
	if((fp=fopen(filename_key,"rb"))== NULL )
	{
		printf("Can not open %s!\n",filename_key);
		exit(0);
	}
	fread(key, 1, 16, fp);
	//读取明文文件，保存在input中
	if((fp=fopen(filename_read,"rb"))== NULL )
	{
		printf("Can not open %s!\n",filename_read);
		exit(0);
	}
	input[i] = fgetc(fp);
	i++;
	while(!feof(fp)){
		input[i] = fgetc(fp);
		i++;
	}
	fclose(fp);
	i -= 1;
	//检查文件流是否为16字节的倍数，若不是则在文件流末尾设置终结符FF并以0补全至16字节的倍数
	int round = i / 16;
	i = i % 16;
	if(i){	
		
		input[round * 16 + i] = 0xff;
		for(int j = round * 16 + i + 1; j < 16; j++){
			input[j] = 0x00;
		}
		round++;
	}
	/*
	mode:
	1:加密
	2:解密
	3:多进程快速加密测速，单纯循环加密，没有文件IO，也没有密钥IO
	4:多线程快速加密测速，状况同3
	5:多进程快速加密，可以加密文件，输出文件，输入密钥
	6:多进程快速加密文件测试，逻辑上与5基本相同，但是在汇编中始终加密同一个位置，目的是测试文件加密能够达到的速度，因为5中的文件不能很大，测速不够准确
	*/
	if(mode == 1 || mode == 2){
		fp=fopen(filename_write,"w+b");
		printf("Do you want to print plaintext, key, and ciphertext?(1 for yse/0 for no)  ");
		scanf("%d", &flag);
		printf("\n");
		for (int j = 0; j < round; j++){
			_begin(key, p);
			unsigned char *out = NULL;
			if(mode == 1){
				out = _begintoencry();
			} else {
				out = _begintodecry();
			}
			if (flag==1){
				if(mode == 1){
					output("Plain text", p);
					output("Cipher key", key);
					output("Encryed", out);
					printf("\n");
				}else{
					output("Encryed", p);
					output("Cipher key", key);
					output("Decrped", out);
					printf("\n");
				}
			}
			int write_in = 16;
			if(mode == 2){
				int k;
				for(k = 0; k < 16; k++){
					if(out[15-k])
						break;
				}
				if(k < 16 && out[15-k] == 0xff)
					write_in = 15 - k;
			}
			//for(int k = 0; k < 16; k++)
			//	fputc(*(out + k), fp);
			fwrite(out, 1, write_in, fp);
			p += 16;
		}
		fclose(fp);
	}else if(mode == 3){
		struct timespec start, end;
		clock_gettime(CLOCK_MONOTONIC, &start);
		key_t memory_key = ftok("/tmp", 66);
		if(memory_key < 0){
			printf("get memory key error\n");
			return -1;
		}
		int shmid = shmget(memory_key, sizeof(struct SharedMemory), IPC_CREAT | 0666);
		void *shm = shmat(shmid, 0, 0);
		struct SharedMemory *shared = (struct SharedMemory*)shm;
		shared->finish = 0;
		int pid;
		pid = fork();
		if(pid){
			int status;
		//	waitpid(pid, &status, 0);
			while(shared->finish != 8)
				usleep(100);
			clock_gettime(CLOCK_MONOTONIC, &end);
			double time = (double)(end.tv_sec-start.tv_sec)*1e9+end.tv_nsec-start.tv_nsec;
			time /= 1e9;
		//	sleep(1);
			printf("\ntime:%.3lfs, speed:%.2lfMB/s\n", time,
			(double)8 * 10000000*16/1024/1024/time );
			shmdt(shm);
			shmctl(shmid, IPC_RMID, 0);
		}else{
			fork();
			fork();
			fork();
			void *shm = shmat(shmid, 0, 0);
			struct SharedMemory *shared = (struct SharedMemory*)shm;
			_speedbegin();
			shared->finish++;
			shmdt(shm);
//			printf("over ");
		}
	}else if(mode == 4){
		clock_t start, end;
		start = clock();
		int all = 3;
		pthread_t tid[all];
		for(int i = 0; i < all; i++){
			pthread_create(&tid[i], NULL, (void*)thread_func, NULL);
		}
		for(int i = 0; i < all; i++){
			pthread_join(tid[i], NULL);
		}
		end = clock();
		double time = (double)(end - start)/CLOCKS_PER_SEC;
		printf("time:%.3lfs, speed:%.2lfMB/s\n", time,
			(double)all * 10000000*16/1024/1024/time );
		
	}else if(mode == 5){
		if(round < 8){
			printf("too small file!\n");
			return 0;
		}

		key_t memory_key = ftok("/tmp", 66);
		if(memory_key < 0){
			printf("get memory key error\n");
			return -1;
		}
		int shmid = shmget(memory_key, sizeof(struct SharedMemory), IPC_CREAT | 0666);
		void *shm = shmat(shmid, 0, 0);
		struct SharedMemory *shared = (struct SharedMemory*)shm;
		shared->count = 0;
		shared->finish = 0;
		for(int k = 0; k < round * 16; k++){
			shared->input[k] = input[k];
		}
		struct timespec start, end;
		///start = clock();
		clock_gettime(CLOCK_MONOTONIC, &start);
		int count_fork = 0;
		
		int pid;
		pid = fork();
		if(pid){
			int status;
			while(shared->finish != 8){
				usleep(100);
			}
			clock_gettime(CLOCK_MONOTONIC, &end);
			for(int k = 0; k < round; k++){
				output("out", &(shared->output[16 * k]));
			}
			fp = fopen(filename_write,"w+b");
			fwrite(shared->output, 1, round * 16, fp);	
			fclose(fp);
			double time = (double)(end.tv_sec-start.tv_sec)*1e9+end.tv_nsec-start.tv_nsec;
			time /= 1e9;
			printf("\ntime:%.3lfs, speed:%.2lfMB/s\n", time,
			(double)8 * 100*16/1024/1024/time );
			shmdt(shm);
			shmctl(shmid, IPC_RMID, 0);
		}else{
			fork();
			fork();
			fork();
			key_t memory_key = ftok("/tmp", 66);
			if(memory_key < 0){
				printf("get memory key error\n");
				return -1;
			}
			//int shmid = shmget(memory_key, sizeof(struct SharedMemory), IPC_CREAT | 0666);
			void *shm = shmat(shmid, 0, 0);
			struct SharedMemory *shared = (struct SharedMemory*)shm;
			int now = shared->count;
			shared->count += round / 8;
			unsigned char* in = &(shared->input[now * 16]);
			unsigned char* out = &(shared->output[now * 16]);
			//for(int k = 0; k < 100000; k++)
			if(now < 7 * (round / 8))
				_speedbeginen(in, key, out, round / 8);
			else
				_speedbeginen(in, key, out, round - round / 8 * 7);
			shared->finish++;
			shmdt(shm);
		}
	}else if(mode == 6){
		key_t memory_key = ftok("/tmp", 55);
		if(memory_key < 0){
			printf("get memory key error\n");
			return -1;
		}
		int shmid = shmget(memory_key, sizeof(struct SharedMemory), IPC_CREAT | 0666);
		void *shm = shmat(shmid, 0, 0);
		struct SharedMemory *shared = (struct SharedMemory*)shm;
		shared->count = 0;
		shared->finish = 0;
		for(int k = 0; k < 8 * 16; k++){
			shared->input[k] = input[k % 16];
		}
		struct timespec start, end;
		clock_gettime(CLOCK_MONOTONIC, &start);
		int pid;
		pid = fork();
		if(pid){
			int status;
			while(shared->finish != 8){
				usleep(100);
			}
			clock_gettime(CLOCK_MONOTONIC, &end);
			printf("%d\n", shared->count);
			double time = (double)(end.tv_sec-start.tv_sec)*1e9+end.tv_nsec-start.tv_nsec;
			time /= 1e9;
			//for(int k = 0; k < 10; k++){
			//	output("C", &(shared->output[k * 16]));
			//}
			printf("\ntime:%.3lfs, speed:%.2lfMB/s\n", time,
			(double)8 * 10000000*16/1024/1024/time );
			shmdt(shm);
			shmctl(shmid, IPC_RMID, 0);
		}else{
			fork();
			fork();
			fork();
			void *shm = shmat(shmid, 0, 0);
			struct SharedMemory *shared = (struct SharedMemory*)shm;
			int now = shared->count;
			shared->count++;
			unsigned char* in = &(shared->input[16 * now]);
			unsigned char* out = &(shared->output[16 * now]);
			_speedbegintest(in, key, out, 10000000);
			shared->finish++;
			shmdt(shm);
		}	
	}
	return 0;
}
