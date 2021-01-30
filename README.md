# AssemblyAES

the simple project of an AES implementation in 64bit Assembly language

## run

first use make to compile

then use like this

````
./aes txt out key mode
````
txt is the plain text to encrypt or the cipher text to decrypt

out is the file to save the result

mode is programmed as below:

1:encrypt, simple implementation of the AES

2:decrypt, simple implementation of the AES

3:multi-process encrypt, use matrix to accelerate, just conduct the encrypt round, so this is the fastest in theory

4:multi-thread encrypt, while because there is only one CPU, so this is not fast

5:multi-process encrypt, use matrix to accelerate AES, can encrypt the file and get the result, but because most of the time is wasted in the file IO process, so the speed is not that convictive

6:multi-process encrypt, use matrix to accelerate AES, the base logic is the same as 5, but this time we don't move the file pointer, which means this is not really a process for the result but for the speed, this speed is more convictive than 5

## 执行
首先使用make进行编译

相应的执行命令，因为最后的整合有一些不好看，所以相应的执行必须要满足如下命令格式：./aes 输入文件 输出文件 密钥文件 加密模式

````
./aes txt out key 1
````

其中，输入文件为输入的密文/明文，密钥文件为输出的明文/密文，密钥文件为加密使用的密钥，注意有些模式可能并不需要前面的参数，但是也是需要在执行命令时候有前面的参数（虽然是无用的）。


下面具体说明各种模式：

1:加密，普通的aes加密实现。

2:解密，普通的aes解密实现。

3:多进程快速加密测速，单纯循环加密，没有文件IO，也没有密钥IO，这个速度应该是最快的，但是参考价值没有下面的大。

4:多线程快速加密测速，状况同3，此外由于多个线程只能分配到一个CPU，而在不同线程之间调度又将花费时间，这个加密速度实际上并不快。

5:多进程快速加密，可以加密文件，输出文件，输入密钥，这里的加密速度较没有参考性，因为文件较小，主要时间用于创建进程和调用函数，实际加密的时间并不长。

6:多进程快速加密文件测试，逻辑上与5基本相同，但是在汇编中始终加密同一个位置，目的是测试文件加密能够达到的速度，因为5中的文件不能很大，测速不够准确，这个加密时间比较有参考价值，可以作为最后的加密时间。

