
user/_memdump:     file format elf64-littleriscv


Disassembly of section .text:

0000000000000000 <memdump>:
void
memdump(char *fmt, char *data)
{
  // Your code here.
// CASE 1: Character ('c') - 1 Byte
  while (*fmt != 0) {
   0:	00054783          	lbu	a5,0(a0)
   4:	cbf1                	beqz	a5,d8 <memdump+0xd8>
{
   6:	715d                	addi	sp,sp,-80
   8:	e486                	sd	ra,72(sp)
   a:	e0a2                	sd	s0,64(sp)
   c:	fc26                	sd	s1,56(sp)
   e:	f84a                	sd	s2,48(sp)
  10:	f44e                	sd	s3,40(sp)
  12:	f052                	sd	s4,32(sp)
  14:	ec56                	sd	s5,24(sp)
  16:	e85a                	sd	s6,16(sp)
  18:	e45e                	sd	s7,8(sp)
  1a:	e062                	sd	s8,0(sp)
  1c:	0880                	addi	s0,sp,80
  1e:	84aa                	mv	s1,a0
  20:	892e                	mv	s2,a1
  22:	02000a13          	li	s4,32
  26:	00001997          	auipc	s3,0x1
  2a:	b9298993          	addi	s3,s3,-1134 # bb8 <malloc+0x1ea>
   }

// CASE 6: Inline String ('S') - Uppercase
// The data on the belt IS the text itself.
    else if (*fmt == 'S') {
      printf("%s\n", data);            // Print the data directly as a string
  2e:	00001b17          	auipc	s6,0x1
  32:	abab0b13          	addi	s6,s6,-1350 # ae8 <malloc+0x11a>
      printf("%p\n", (void *)val);   // Move 8 bytes
  36:	00001c17          	auipc	s8,0x1
  3a:	aaac0c13          	addi	s8,s8,-1366 # ae0 <malloc+0x112>
      printf("%d\n", val);        // Print short
  3e:	00001a97          	auipc	s5,0x1
  42:	a9aa8a93          	addi	s5,s5,-1382 # ad8 <malloc+0x10a>
      printf("%c\n", val);       // Print char
  46:	00001b97          	auipc	s7,0x1
  4a:	a8ab8b93          	addi	s7,s7,-1398 # ad0 <malloc+0x102>
  4e:	a819                	j	64 <memdump+0x64>
  50:	00094583          	lbu	a1,0(s2)
  54:	855e                	mv	a0,s7
  56:	0c5000ef          	jal	91a <printf>
      data += 1;                 // Move 1 byte
  5a:	0905                	addi	s2,s2,1
      data += 8;                       // Move past the buffer (Lab assumes 8 bytes)
    }
    fmt++;
  5c:	0485                	addi	s1,s1,1
  while (*fmt != 0) {
  5e:	0004c783          	lbu	a5,0(s1)
  62:	cfb9                	beqz	a5,c0 <memdump+0xc0>
    if (*fmt == 'c') {
  64:	fad7879b          	addiw	a5,a5,-83
  68:	0ff7f713          	zext.b	a4,a5
  6c:	feea68e3          	bltu	s4,a4,5c <memdump+0x5c>
  70:	00271793          	slli	a5,a4,0x2
  74:	97ce                	add	a5,a5,s3
  76:	439c                	lw	a5,0(a5)
  78:	97ce                	add	a5,a5,s3
  7a:	8782                	jr	a5
      printf("%d\n", val);       // Move 4 bytes
  7c:	00092583          	lw	a1,0(s2)
  80:	8556                	mv	a0,s5
  82:	099000ef          	jal	91a <printf>
      data += 4;
  86:	0911                	addi	s2,s2,4
  88:	bfd1                	j	5c <memdump+0x5c>
      printf("%d\n", val);        // Print short
  8a:	00091583          	lh	a1,0(s2)
  8e:	8556                	mv	a0,s5
  90:	08b000ef          	jal	91a <printf>
      data += 2;                  // Move 2 bytes
  94:	0909                	addi	s2,s2,2
  96:	b7d9                	j	5c <memdump+0x5c>
      printf("%p\n", (void *)val);   // Move 8 bytes
  98:	00093583          	ld	a1,0(s2)
  9c:	8562                	mv	a0,s8
  9e:	07d000ef          	jal	91a <printf>
      data += 8;
  a2:	0921                	addi	s2,s2,8
  a4:	bf65                	j	5c <memdump+0x5c>
    printf("%s\n", str_val);         // Move 8 bytes (size of the pointer)
  a6:	00093583          	ld	a1,0(s2)
  aa:	855a                	mv	a0,s6
  ac:	06f000ef          	jal	91a <printf>
    data += 8;
  b0:	0921                	addi	s2,s2,8
  b2:	b76d                	j	5c <memdump+0x5c>
      printf("%s\n", data);            // Print the data directly as a string
  b4:	85ca                	mv	a1,s2
  b6:	855a                	mv	a0,s6
  b8:	063000ef          	jal	91a <printf>
      data += 8;                       // Move past the buffer (Lab assumes 8 bytes)
  bc:	0921                	addi	s2,s2,8
  be:	bf79                	j	5c <memdump+0x5c>
  }

}
  c0:	60a6                	ld	ra,72(sp)
  c2:	6406                	ld	s0,64(sp)
  c4:	74e2                	ld	s1,56(sp)
  c6:	7942                	ld	s2,48(sp)
  c8:	79a2                	ld	s3,40(sp)
  ca:	7a02                	ld	s4,32(sp)
  cc:	6ae2                	ld	s5,24(sp)
  ce:	6b42                	ld	s6,16(sp)
  d0:	6ba2                	ld	s7,8(sp)
  d2:	6c02                	ld	s8,0(sp)
  d4:	6161                	addi	sp,sp,80
  d6:	8082                	ret
  d8:	8082                	ret

00000000000000da <main>:
{
  da:	dc010113          	addi	sp,sp,-576
  de:	22113c23          	sd	ra,568(sp)
  e2:	22813823          	sd	s0,560(sp)
  e6:	22913423          	sd	s1,552(sp)
  ea:	23213023          	sd	s2,544(sp)
  ee:	21313c23          	sd	s3,536(sp)
  f2:	21413823          	sd	s4,528(sp)
  f6:	0480                	addi	s0,sp,576
  if(argc == 1){
  f8:	4785                	li	a5,1
  fa:	00f50f63          	beq	a0,a5,118 <main+0x3e>
  fe:	892e                	mv	s2,a1
  } else if(argc == 2){
 100:	4789                	li	a5,2
 102:	0ef50f63          	beq	a0,a5,200 <main+0x126>
    printf("Usage: memdump [format]\n");
 106:	00001517          	auipc	a0,0x1
 10a:	a8a50513          	addi	a0,a0,-1398 # b90 <malloc+0x1c2>
 10e:	00d000ef          	jal	91a <printf>
    exit(1);
 112:	4505                	li	a0,1
 114:	3d2000ef          	jal	4e6 <exit>
    printf("Example 1:\n");
 118:	00001517          	auipc	a0,0x1
 11c:	9d850513          	addi	a0,a0,-1576 # af0 <malloc+0x122>
 120:	7fa000ef          	jal	91a <printf>
    int a[2] = { 61810, 2025 };
 124:	67bd                	lui	a5,0xf
 126:	17278793          	addi	a5,a5,370 # f172 <base+0xd162>
 12a:	dcf42023          	sw	a5,-576(s0)
 12e:	7e900793          	li	a5,2025
 132:	dcf42223          	sw	a5,-572(s0)
    memdump("ii", (char*) a);
 136:	dc040593          	addi	a1,s0,-576
 13a:	00001517          	auipc	a0,0x1
 13e:	9c650513          	addi	a0,a0,-1594 # b00 <malloc+0x132>
 142:	ebfff0ef          	jal	0 <memdump>
    printf("Example 2:\n");
 146:	00001517          	auipc	a0,0x1
 14a:	9c250513          	addi	a0,a0,-1598 # b08 <malloc+0x13a>
 14e:	7cc000ef          	jal	91a <printf>
    memdump("S", "a string");
 152:	00001597          	auipc	a1,0x1
 156:	9c658593          	addi	a1,a1,-1594 # b18 <malloc+0x14a>
 15a:	00001517          	auipc	a0,0x1
 15e:	9ce50513          	addi	a0,a0,-1586 # b28 <malloc+0x15a>
 162:	e9fff0ef          	jal	0 <memdump>
    printf("Example 3:\n");
 166:	00001517          	auipc	a0,0x1
 16a:	9ca50513          	addi	a0,a0,-1590 # b30 <malloc+0x162>
 16e:	7ac000ef          	jal	91a <printf>
    char *s = "another";
 172:	00001797          	auipc	a5,0x1
 176:	9ce78793          	addi	a5,a5,-1586 # b40 <malloc+0x172>
 17a:	dcf43423          	sd	a5,-568(s0)
    memdump("s", (char *) &s);
 17e:	dc840593          	addi	a1,s0,-568
 182:	00001517          	auipc	a0,0x1
 186:	9c650513          	addi	a0,a0,-1594 # b48 <malloc+0x17a>
 18a:	e77ff0ef          	jal	0 <memdump>
    example.ptr = "hello";
 18e:	00001797          	auipc	a5,0x1
 192:	9c278793          	addi	a5,a5,-1598 # b50 <malloc+0x182>
 196:	dcf43823          	sd	a5,-560(s0)
    example.num1 = 1819438967;
 19a:	6c7277b7          	lui	a5,0x6c727
 19e:	f7778793          	addi	a5,a5,-137 # 6c726f77 <base+0x6c724f67>
 1a2:	dcf42c23          	sw	a5,-552(s0)
    example.num2 = 100;
 1a6:	06400793          	li	a5,100
 1aa:	dcf41e23          	sh	a5,-548(s0)
    example.byte = 'z';
 1ae:	07a00793          	li	a5,122
 1b2:	dcf40f23          	sb	a5,-546(s0)
    strcpy(example.bytes, "xyzzy");
 1b6:	00001597          	auipc	a1,0x1
 1ba:	9a258593          	addi	a1,a1,-1630 # b58 <malloc+0x18a>
 1be:	ddf40513          	addi	a0,s0,-545
 1c2:	0a0000ef          	jal	262 <strcpy>
    printf("Example 4:\n");
 1c6:	00001517          	auipc	a0,0x1
 1ca:	99a50513          	addi	a0,a0,-1638 # b60 <malloc+0x192>
 1ce:	74c000ef          	jal	91a <printf>
    memdump("pihcS", (char*) &example);
 1d2:	dd040593          	addi	a1,s0,-560
 1d6:	00001517          	auipc	a0,0x1
 1da:	99a50513          	addi	a0,a0,-1638 # b70 <malloc+0x1a2>
 1de:	e23ff0ef          	jal	0 <memdump>
    printf("Example 5:\n");
 1e2:	00001517          	auipc	a0,0x1
 1e6:	99650513          	addi	a0,a0,-1642 # b78 <malloc+0x1aa>
 1ea:	730000ef          	jal	91a <printf>
    memdump("sccccc", (char*) &example);
 1ee:	dd040593          	addi	a1,s0,-560
 1f2:	00001517          	auipc	a0,0x1
 1f6:	99650513          	addi	a0,a0,-1642 # b88 <malloc+0x1ba>
 1fa:	e07ff0ef          	jal	0 <memdump>
 1fe:	a0b1                	j	24a <main+0x170>
    memset(data, '\0', sizeof(data));
 200:	20000613          	li	a2,512
 204:	4581                	li	a1,0
 206:	dd040513          	addi	a0,s0,-560
 20a:	0ca000ef          	jal	2d4 <memset>
    int n = 0;
 20e:	4481                	li	s1,0
    while(n < sizeof(data)){
 210:	4601                	li	a2,0
      int nn = read(0, data + n, sizeof(data) - n);
 212:	20000993          	li	s3,512
    while(n < sizeof(data)){
 216:	1ff00a13          	li	s4,511
      int nn = read(0, data + n, sizeof(data) - n);
 21a:	40c9863b          	subw	a2,s3,a2
 21e:	dd040793          	addi	a5,s0,-560
 222:	009785b3          	add	a1,a5,s1
 226:	4501                	li	a0,0
 228:	2d6000ef          	jal	4fe <read>
      if(nn <= 0)
 22c:	00a05963          	blez	a0,23e <main+0x164>
      n += nn;
 230:	0095063b          	addw	a2,a0,s1
 234:	0006049b          	sext.w	s1,a2
    while(n < sizeof(data)){
 238:	8626                	mv	a2,s1
 23a:	fe9a70e3          	bgeu	s4,s1,21a <main+0x140>
    memdump(argv[1], data);
 23e:	dd040593          	addi	a1,s0,-560
 242:	00893503          	ld	a0,8(s2)
 246:	dbbff0ef          	jal	0 <memdump>
  exit(0);
 24a:	4501                	li	a0,0
 24c:	29a000ef          	jal	4e6 <exit>

0000000000000250 <start>:
//
// wrapper so that it's OK if main() does not call exit().
//
void
start()
{
 250:	1141                	addi	sp,sp,-16
 252:	e406                	sd	ra,8(sp)
 254:	e022                	sd	s0,0(sp)
 256:	0800                	addi	s0,sp,16
  extern int main();
  main();
 258:	e83ff0ef          	jal	da <main>
  exit(0);
 25c:	4501                	li	a0,0
 25e:	288000ef          	jal	4e6 <exit>

0000000000000262 <strcpy>:
}

char*
strcpy(char *s, const char *t)
{
 262:	1141                	addi	sp,sp,-16
 264:	e422                	sd	s0,8(sp)
 266:	0800                	addi	s0,sp,16
  char *os;

  os = s;
  while((*s++ = *t++) != 0)
 268:	87aa                	mv	a5,a0
 26a:	0585                	addi	a1,a1,1
 26c:	0785                	addi	a5,a5,1
 26e:	fff5c703          	lbu	a4,-1(a1)
 272:	fee78fa3          	sb	a4,-1(a5)
 276:	fb75                	bnez	a4,26a <strcpy+0x8>
    ;
  return os;
}
 278:	6422                	ld	s0,8(sp)
 27a:	0141                	addi	sp,sp,16
 27c:	8082                	ret

000000000000027e <strcmp>:

int
strcmp(const char *p, const char *q)
{
 27e:	1141                	addi	sp,sp,-16
 280:	e422                	sd	s0,8(sp)
 282:	0800                	addi	s0,sp,16
  while(*p && *p == *q)
 284:	00054783          	lbu	a5,0(a0)
 288:	cb91                	beqz	a5,29c <strcmp+0x1e>
 28a:	0005c703          	lbu	a4,0(a1)
 28e:	00f71763          	bne	a4,a5,29c <strcmp+0x1e>
    p++, q++;
 292:	0505                	addi	a0,a0,1
 294:	0585                	addi	a1,a1,1
  while(*p && *p == *q)
 296:	00054783          	lbu	a5,0(a0)
 29a:	fbe5                	bnez	a5,28a <strcmp+0xc>
  return (uchar)*p - (uchar)*q;
 29c:	0005c503          	lbu	a0,0(a1)
}
 2a0:	40a7853b          	subw	a0,a5,a0
 2a4:	6422                	ld	s0,8(sp)
 2a6:	0141                	addi	sp,sp,16
 2a8:	8082                	ret

00000000000002aa <strlen>:

uint
strlen(const char *s)
{
 2aa:	1141                	addi	sp,sp,-16
 2ac:	e422                	sd	s0,8(sp)
 2ae:	0800                	addi	s0,sp,16
  int n;

  for(n = 0; s[n]; n++)
 2b0:	00054783          	lbu	a5,0(a0)
 2b4:	cf91                	beqz	a5,2d0 <strlen+0x26>
 2b6:	0505                	addi	a0,a0,1
 2b8:	87aa                	mv	a5,a0
 2ba:	86be                	mv	a3,a5
 2bc:	0785                	addi	a5,a5,1
 2be:	fff7c703          	lbu	a4,-1(a5)
 2c2:	ff65                	bnez	a4,2ba <strlen+0x10>
 2c4:	40a6853b          	subw	a0,a3,a0
 2c8:	2505                	addiw	a0,a0,1
    ;
  return n;
}
 2ca:	6422                	ld	s0,8(sp)
 2cc:	0141                	addi	sp,sp,16
 2ce:	8082                	ret
  for(n = 0; s[n]; n++)
 2d0:	4501                	li	a0,0
 2d2:	bfe5                	j	2ca <strlen+0x20>

00000000000002d4 <memset>:

void*
memset(void *dst, int c, uint n)
{
 2d4:	1141                	addi	sp,sp,-16
 2d6:	e422                	sd	s0,8(sp)
 2d8:	0800                	addi	s0,sp,16
  char *cdst = (char *) dst;
  int i;
  for(i = 0; i < n; i++){
 2da:	ca19                	beqz	a2,2f0 <memset+0x1c>
 2dc:	87aa                	mv	a5,a0
 2de:	1602                	slli	a2,a2,0x20
 2e0:	9201                	srli	a2,a2,0x20
 2e2:	00a60733          	add	a4,a2,a0
    cdst[i] = c;
 2e6:	00b78023          	sb	a1,0(a5)
  for(i = 0; i < n; i++){
 2ea:	0785                	addi	a5,a5,1
 2ec:	fee79de3          	bne	a5,a4,2e6 <memset+0x12>
  }
  return dst;
}
 2f0:	6422                	ld	s0,8(sp)
 2f2:	0141                	addi	sp,sp,16
 2f4:	8082                	ret

00000000000002f6 <strchr>:

char*
strchr(const char *s, char c)
{
 2f6:	1141                	addi	sp,sp,-16
 2f8:	e422                	sd	s0,8(sp)
 2fa:	0800                	addi	s0,sp,16
  for(; *s; s++)
 2fc:	00054783          	lbu	a5,0(a0)
 300:	cb99                	beqz	a5,316 <strchr+0x20>
    if(*s == c)
 302:	00f58763          	beq	a1,a5,310 <strchr+0x1a>
  for(; *s; s++)
 306:	0505                	addi	a0,a0,1
 308:	00054783          	lbu	a5,0(a0)
 30c:	fbfd                	bnez	a5,302 <strchr+0xc>
      return (char*)s;
  return 0;
 30e:	4501                	li	a0,0
}
 310:	6422                	ld	s0,8(sp)
 312:	0141                	addi	sp,sp,16
 314:	8082                	ret
  return 0;
 316:	4501                	li	a0,0
 318:	bfe5                	j	310 <strchr+0x1a>

000000000000031a <gets>:

char*
gets(char *buf, int max)
{
 31a:	711d                	addi	sp,sp,-96
 31c:	ec86                	sd	ra,88(sp)
 31e:	e8a2                	sd	s0,80(sp)
 320:	e4a6                	sd	s1,72(sp)
 322:	e0ca                	sd	s2,64(sp)
 324:	fc4e                	sd	s3,56(sp)
 326:	f852                	sd	s4,48(sp)
 328:	f456                	sd	s5,40(sp)
 32a:	f05a                	sd	s6,32(sp)
 32c:	ec5e                	sd	s7,24(sp)
 32e:	1080                	addi	s0,sp,96
 330:	8baa                	mv	s7,a0
 332:	8a2e                	mv	s4,a1
  int i, cc;
  char c;

  for(i=0; i+1 < max; ){
 334:	892a                	mv	s2,a0
 336:	4481                	li	s1,0
    cc = read(0, &c, 1);
    if(cc < 1)
      break;
    buf[i++] = c;
    if(c == '\n' || c == '\r')
 338:	4aa9                	li	s5,10
 33a:	4b35                	li	s6,13
  for(i=0; i+1 < max; ){
 33c:	89a6                	mv	s3,s1
 33e:	2485                	addiw	s1,s1,1
 340:	0344d663          	bge	s1,s4,36c <gets+0x52>
    cc = read(0, &c, 1);
 344:	4605                	li	a2,1
 346:	faf40593          	addi	a1,s0,-81
 34a:	4501                	li	a0,0
 34c:	1b2000ef          	jal	4fe <read>
    if(cc < 1)
 350:	00a05e63          	blez	a0,36c <gets+0x52>
    buf[i++] = c;
 354:	faf44783          	lbu	a5,-81(s0)
 358:	00f90023          	sb	a5,0(s2)
    if(c == '\n' || c == '\r')
 35c:	01578763          	beq	a5,s5,36a <gets+0x50>
 360:	0905                	addi	s2,s2,1
 362:	fd679de3          	bne	a5,s6,33c <gets+0x22>
    buf[i++] = c;
 366:	89a6                	mv	s3,s1
 368:	a011                	j	36c <gets+0x52>
 36a:	89a6                	mv	s3,s1
      break;
  }
  buf[i] = '\0';
 36c:	99de                	add	s3,s3,s7
 36e:	00098023          	sb	zero,0(s3)
  return buf;
}
 372:	855e                	mv	a0,s7
 374:	60e6                	ld	ra,88(sp)
 376:	6446                	ld	s0,80(sp)
 378:	64a6                	ld	s1,72(sp)
 37a:	6906                	ld	s2,64(sp)
 37c:	79e2                	ld	s3,56(sp)
 37e:	7a42                	ld	s4,48(sp)
 380:	7aa2                	ld	s5,40(sp)
 382:	7b02                	ld	s6,32(sp)
 384:	6be2                	ld	s7,24(sp)
 386:	6125                	addi	sp,sp,96
 388:	8082                	ret

000000000000038a <stat>:

int
stat(const char *n, struct stat *st)
{
 38a:	1101                	addi	sp,sp,-32
 38c:	ec06                	sd	ra,24(sp)
 38e:	e822                	sd	s0,16(sp)
 390:	e04a                	sd	s2,0(sp)
 392:	1000                	addi	s0,sp,32
 394:	892e                	mv	s2,a1
  int fd;
  int r;

  fd = open(n, O_RDONLY);
 396:	4581                	li	a1,0
 398:	18e000ef          	jal	526 <open>
  if(fd < 0)
 39c:	02054263          	bltz	a0,3c0 <stat+0x36>
 3a0:	e426                	sd	s1,8(sp)
 3a2:	84aa                	mv	s1,a0
    return -1;
  r = fstat(fd, st);
 3a4:	85ca                	mv	a1,s2
 3a6:	198000ef          	jal	53e <fstat>
 3aa:	892a                	mv	s2,a0
  close(fd);
 3ac:	8526                	mv	a0,s1
 3ae:	160000ef          	jal	50e <close>
  return r;
 3b2:	64a2                	ld	s1,8(sp)
}
 3b4:	854a                	mv	a0,s2
 3b6:	60e2                	ld	ra,24(sp)
 3b8:	6442                	ld	s0,16(sp)
 3ba:	6902                	ld	s2,0(sp)
 3bc:	6105                	addi	sp,sp,32
 3be:	8082                	ret
    return -1;
 3c0:	597d                	li	s2,-1
 3c2:	bfcd                	j	3b4 <stat+0x2a>

00000000000003c4 <atoi>:

int
atoi(const char *s)
{
 3c4:	1141                	addi	sp,sp,-16
 3c6:	e422                	sd	s0,8(sp)
 3c8:	0800                	addi	s0,sp,16
  int n;

  n = 0;
  while('0' <= *s && *s <= '9')
 3ca:	00054683          	lbu	a3,0(a0)
 3ce:	fd06879b          	addiw	a5,a3,-48
 3d2:	0ff7f793          	zext.b	a5,a5
 3d6:	4625                	li	a2,9
 3d8:	02f66863          	bltu	a2,a5,408 <atoi+0x44>
 3dc:	872a                	mv	a4,a0
  n = 0;
 3de:	4501                	li	a0,0
    n = n*10 + *s++ - '0';
 3e0:	0705                	addi	a4,a4,1
 3e2:	0025179b          	slliw	a5,a0,0x2
 3e6:	9fa9                	addw	a5,a5,a0
 3e8:	0017979b          	slliw	a5,a5,0x1
 3ec:	9fb5                	addw	a5,a5,a3
 3ee:	fd07851b          	addiw	a0,a5,-48
  while('0' <= *s && *s <= '9')
 3f2:	00074683          	lbu	a3,0(a4)
 3f6:	fd06879b          	addiw	a5,a3,-48
 3fa:	0ff7f793          	zext.b	a5,a5
 3fe:	fef671e3          	bgeu	a2,a5,3e0 <atoi+0x1c>
  return n;
}
 402:	6422                	ld	s0,8(sp)
 404:	0141                	addi	sp,sp,16
 406:	8082                	ret
  n = 0;
 408:	4501                	li	a0,0
 40a:	bfe5                	j	402 <atoi+0x3e>

000000000000040c <memmove>:

void*
memmove(void *vdst, const void *vsrc, int n)
{
 40c:	1141                	addi	sp,sp,-16
 40e:	e422                	sd	s0,8(sp)
 410:	0800                	addi	s0,sp,16
  char *dst;
  const char *src;

  dst = vdst;
  src = vsrc;
  if (src > dst) {
 412:	02b57463          	bgeu	a0,a1,43a <memmove+0x2e>
    while(n-- > 0)
 416:	00c05f63          	blez	a2,434 <memmove+0x28>
 41a:	1602                	slli	a2,a2,0x20
 41c:	9201                	srli	a2,a2,0x20
 41e:	00c507b3          	add	a5,a0,a2
  dst = vdst;
 422:	872a                	mv	a4,a0
      *dst++ = *src++;
 424:	0585                	addi	a1,a1,1
 426:	0705                	addi	a4,a4,1
 428:	fff5c683          	lbu	a3,-1(a1)
 42c:	fed70fa3          	sb	a3,-1(a4)
    while(n-- > 0)
 430:	fef71ae3          	bne	a4,a5,424 <memmove+0x18>
    src += n;
    while(n-- > 0)
      *--dst = *--src;
  }
  return vdst;
}
 434:	6422                	ld	s0,8(sp)
 436:	0141                	addi	sp,sp,16
 438:	8082                	ret
    dst += n;
 43a:	00c50733          	add	a4,a0,a2
    src += n;
 43e:	95b2                	add	a1,a1,a2
    while(n-- > 0)
 440:	fec05ae3          	blez	a2,434 <memmove+0x28>
 444:	fff6079b          	addiw	a5,a2,-1
 448:	1782                	slli	a5,a5,0x20
 44a:	9381                	srli	a5,a5,0x20
 44c:	fff7c793          	not	a5,a5
 450:	97ba                	add	a5,a5,a4
      *--dst = *--src;
 452:	15fd                	addi	a1,a1,-1
 454:	177d                	addi	a4,a4,-1
 456:	0005c683          	lbu	a3,0(a1)
 45a:	00d70023          	sb	a3,0(a4)
    while(n-- > 0)
 45e:	fee79ae3          	bne	a5,a4,452 <memmove+0x46>
 462:	bfc9                	j	434 <memmove+0x28>

0000000000000464 <memcmp>:

int
memcmp(const void *s1, const void *s2, uint n)
{
 464:	1141                	addi	sp,sp,-16
 466:	e422                	sd	s0,8(sp)
 468:	0800                	addi	s0,sp,16
  const char *p1 = s1, *p2 = s2;
  while (n-- > 0) {
 46a:	ca05                	beqz	a2,49a <memcmp+0x36>
 46c:	fff6069b          	addiw	a3,a2,-1
 470:	1682                	slli	a3,a3,0x20
 472:	9281                	srli	a3,a3,0x20
 474:	0685                	addi	a3,a3,1
 476:	96aa                	add	a3,a3,a0
    if (*p1 != *p2) {
 478:	00054783          	lbu	a5,0(a0)
 47c:	0005c703          	lbu	a4,0(a1)
 480:	00e79863          	bne	a5,a4,490 <memcmp+0x2c>
      return *p1 - *p2;
    }
    p1++;
 484:	0505                	addi	a0,a0,1
    p2++;
 486:	0585                	addi	a1,a1,1
  while (n-- > 0) {
 488:	fed518e3          	bne	a0,a3,478 <memcmp+0x14>
  }
  return 0;
 48c:	4501                	li	a0,0
 48e:	a019                	j	494 <memcmp+0x30>
      return *p1 - *p2;
 490:	40e7853b          	subw	a0,a5,a4
}
 494:	6422                	ld	s0,8(sp)
 496:	0141                	addi	sp,sp,16
 498:	8082                	ret
  return 0;
 49a:	4501                	li	a0,0
 49c:	bfe5                	j	494 <memcmp+0x30>

000000000000049e <memcpy>:

void *
memcpy(void *dst, const void *src, uint n)
{
 49e:	1141                	addi	sp,sp,-16
 4a0:	e406                	sd	ra,8(sp)
 4a2:	e022                	sd	s0,0(sp)
 4a4:	0800                	addi	s0,sp,16
  return memmove(dst, src, n);
 4a6:	f67ff0ef          	jal	40c <memmove>
}
 4aa:	60a2                	ld	ra,8(sp)
 4ac:	6402                	ld	s0,0(sp)
 4ae:	0141                	addi	sp,sp,16
 4b0:	8082                	ret

00000000000004b2 <sbrk>:

char *
sbrk(int n) {
 4b2:	1141                	addi	sp,sp,-16
 4b4:	e406                	sd	ra,8(sp)
 4b6:	e022                	sd	s0,0(sp)
 4b8:	0800                	addi	s0,sp,16
  return sys_sbrk(n, SBRK_EAGER);
 4ba:	4585                	li	a1,1
 4bc:	0b2000ef          	jal	56e <sys_sbrk>
}
 4c0:	60a2                	ld	ra,8(sp)
 4c2:	6402                	ld	s0,0(sp)
 4c4:	0141                	addi	sp,sp,16
 4c6:	8082                	ret

00000000000004c8 <sbrklazy>:

char *
sbrklazy(int n) {
 4c8:	1141                	addi	sp,sp,-16
 4ca:	e406                	sd	ra,8(sp)
 4cc:	e022                	sd	s0,0(sp)
 4ce:	0800                	addi	s0,sp,16
  return sys_sbrk(n, SBRK_LAZY);
 4d0:	4589                	li	a1,2
 4d2:	09c000ef          	jal	56e <sys_sbrk>
}
 4d6:	60a2                	ld	ra,8(sp)
 4d8:	6402                	ld	s0,0(sp)
 4da:	0141                	addi	sp,sp,16
 4dc:	8082                	ret

00000000000004de <fork>:
# generated by usys.pl - do not edit
#include "kernel/syscall.h"
.global fork
fork:
 li a7, SYS_fork
 4de:	4885                	li	a7,1
 ecall
 4e0:	00000073          	ecall
 ret
 4e4:	8082                	ret

00000000000004e6 <exit>:
.global exit
exit:
 li a7, SYS_exit
 4e6:	4889                	li	a7,2
 ecall
 4e8:	00000073          	ecall
 ret
 4ec:	8082                	ret

00000000000004ee <wait>:
.global wait
wait:
 li a7, SYS_wait
 4ee:	488d                	li	a7,3
 ecall
 4f0:	00000073          	ecall
 ret
 4f4:	8082                	ret

00000000000004f6 <pipe>:
.global pipe
pipe:
 li a7, SYS_pipe
 4f6:	4891                	li	a7,4
 ecall
 4f8:	00000073          	ecall
 ret
 4fc:	8082                	ret

00000000000004fe <read>:
.global read
read:
 li a7, SYS_read
 4fe:	4895                	li	a7,5
 ecall
 500:	00000073          	ecall
 ret
 504:	8082                	ret

0000000000000506 <write>:
.global write
write:
 li a7, SYS_write
 506:	48c1                	li	a7,16
 ecall
 508:	00000073          	ecall
 ret
 50c:	8082                	ret

000000000000050e <close>:
.global close
close:
 li a7, SYS_close
 50e:	48d5                	li	a7,21
 ecall
 510:	00000073          	ecall
 ret
 514:	8082                	ret

0000000000000516 <kill>:
.global kill
kill:
 li a7, SYS_kill
 516:	4899                	li	a7,6
 ecall
 518:	00000073          	ecall
 ret
 51c:	8082                	ret

000000000000051e <exec>:
.global exec
exec:
 li a7, SYS_exec
 51e:	489d                	li	a7,7
 ecall
 520:	00000073          	ecall
 ret
 524:	8082                	ret

0000000000000526 <open>:
.global open
open:
 li a7, SYS_open
 526:	48bd                	li	a7,15
 ecall
 528:	00000073          	ecall
 ret
 52c:	8082                	ret

000000000000052e <mknod>:
.global mknod
mknod:
 li a7, SYS_mknod
 52e:	48c5                	li	a7,17
 ecall
 530:	00000073          	ecall
 ret
 534:	8082                	ret

0000000000000536 <unlink>:
.global unlink
unlink:
 li a7, SYS_unlink
 536:	48c9                	li	a7,18
 ecall
 538:	00000073          	ecall
 ret
 53c:	8082                	ret

000000000000053e <fstat>:
.global fstat
fstat:
 li a7, SYS_fstat
 53e:	48a1                	li	a7,8
 ecall
 540:	00000073          	ecall
 ret
 544:	8082                	ret

0000000000000546 <link>:
.global link
link:
 li a7, SYS_link
 546:	48cd                	li	a7,19
 ecall
 548:	00000073          	ecall
 ret
 54c:	8082                	ret

000000000000054e <mkdir>:
.global mkdir
mkdir:
 li a7, SYS_mkdir
 54e:	48d1                	li	a7,20
 ecall
 550:	00000073          	ecall
 ret
 554:	8082                	ret

0000000000000556 <chdir>:
.global chdir
chdir:
 li a7, SYS_chdir
 556:	48a5                	li	a7,9
 ecall
 558:	00000073          	ecall
 ret
 55c:	8082                	ret

000000000000055e <dup>:
.global dup
dup:
 li a7, SYS_dup
 55e:	48a9                	li	a7,10
 ecall
 560:	00000073          	ecall
 ret
 564:	8082                	ret

0000000000000566 <getpid>:
.global getpid
getpid:
 li a7, SYS_getpid
 566:	48ad                	li	a7,11
 ecall
 568:	00000073          	ecall
 ret
 56c:	8082                	ret

000000000000056e <sys_sbrk>:
.global sys_sbrk
sys_sbrk:
 li a7, SYS_sbrk
 56e:	48b1                	li	a7,12
 ecall
 570:	00000073          	ecall
 ret
 574:	8082                	ret

0000000000000576 <pause>:
.global pause
pause:
 li a7, SYS_pause
 576:	48b5                	li	a7,13
 ecall
 578:	00000073          	ecall
 ret
 57c:	8082                	ret

000000000000057e <uptime>:
.global uptime
uptime:
 li a7, SYS_uptime
 57e:	48b9                	li	a7,14
 ecall
 580:	00000073          	ecall
 ret
 584:	8082                	ret

0000000000000586 <putc>:

static char digits[] = "0123456789ABCDEF";

static void
putc(int fd, char c)
{
 586:	1101                	addi	sp,sp,-32
 588:	ec06                	sd	ra,24(sp)
 58a:	e822                	sd	s0,16(sp)
 58c:	1000                	addi	s0,sp,32
 58e:	feb407a3          	sb	a1,-17(s0)
  write(fd, &c, 1);
 592:	4605                	li	a2,1
 594:	fef40593          	addi	a1,s0,-17
 598:	f6fff0ef          	jal	506 <write>
}
 59c:	60e2                	ld	ra,24(sp)
 59e:	6442                	ld	s0,16(sp)
 5a0:	6105                	addi	sp,sp,32
 5a2:	8082                	ret

00000000000005a4 <printint>:

static void
printint(int fd, long long xx, int base, int sgn)
{
 5a4:	715d                	addi	sp,sp,-80
 5a6:	e486                	sd	ra,72(sp)
 5a8:	e0a2                	sd	s0,64(sp)
 5aa:	fc26                	sd	s1,56(sp)
 5ac:	0880                	addi	s0,sp,80
 5ae:	84aa                	mv	s1,a0
  char buf[20];
  int i, neg;
  uint x;

  neg = 0;
  if(sgn && xx < 0){
 5b0:	c299                	beqz	a3,5b6 <printint+0x12>
 5b2:	0805c963          	bltz	a1,644 <printint+0xa0>
    neg = 1;
    x = -xx;
  } else {
    x = xx;
 5b6:	2581                	sext.w	a1,a1
  neg = 0;
 5b8:	4881                	li	a7,0
 5ba:	fb840693          	addi	a3,s0,-72
  }

  i = 0;
 5be:	4701                	li	a4,0
  do{
    buf[i++] = digits[x % base];
 5c0:	2601                	sext.w	a2,a2
 5c2:	00000517          	auipc	a0,0x0
 5c6:	67e50513          	addi	a0,a0,1662 # c40 <digits>
 5ca:	883a                	mv	a6,a4
 5cc:	2705                	addiw	a4,a4,1
 5ce:	02c5f7bb          	remuw	a5,a1,a2
 5d2:	1782                	slli	a5,a5,0x20
 5d4:	9381                	srli	a5,a5,0x20
 5d6:	97aa                	add	a5,a5,a0
 5d8:	0007c783          	lbu	a5,0(a5)
 5dc:	00f68023          	sb	a5,0(a3)
  }while((x /= base) != 0);
 5e0:	0005879b          	sext.w	a5,a1
 5e4:	02c5d5bb          	divuw	a1,a1,a2
 5e8:	0685                	addi	a3,a3,1
 5ea:	fec7f0e3          	bgeu	a5,a2,5ca <printint+0x26>
  if(neg)
 5ee:	00088c63          	beqz	a7,606 <printint+0x62>
    buf[i++] = '-';
 5f2:	fd070793          	addi	a5,a4,-48
 5f6:	00878733          	add	a4,a5,s0
 5fa:	02d00793          	li	a5,45
 5fe:	fef70423          	sb	a5,-24(a4)
 602:	0028071b          	addiw	a4,a6,2

  while(--i >= 0)
 606:	02e05a63          	blez	a4,63a <printint+0x96>
 60a:	f84a                	sd	s2,48(sp)
 60c:	f44e                	sd	s3,40(sp)
 60e:	fb840793          	addi	a5,s0,-72
 612:	00e78933          	add	s2,a5,a4
 616:	fff78993          	addi	s3,a5,-1
 61a:	99ba                	add	s3,s3,a4
 61c:	377d                	addiw	a4,a4,-1
 61e:	1702                	slli	a4,a4,0x20
 620:	9301                	srli	a4,a4,0x20
 622:	40e989b3          	sub	s3,s3,a4
    putc(fd, buf[i]);
 626:	fff94583          	lbu	a1,-1(s2)
 62a:	8526                	mv	a0,s1
 62c:	f5bff0ef          	jal	586 <putc>
  while(--i >= 0)
 630:	197d                	addi	s2,s2,-1
 632:	ff391ae3          	bne	s2,s3,626 <printint+0x82>
 636:	7942                	ld	s2,48(sp)
 638:	79a2                	ld	s3,40(sp)
}
 63a:	60a6                	ld	ra,72(sp)
 63c:	6406                	ld	s0,64(sp)
 63e:	74e2                	ld	s1,56(sp)
 640:	6161                	addi	sp,sp,80
 642:	8082                	ret
    x = -xx;
 644:	40b005bb          	negw	a1,a1
    neg = 1;
 648:	4885                	li	a7,1
    x = -xx;
 64a:	bf85                	j	5ba <printint+0x16>

000000000000064c <vprintf>:
}

// Print to the given fd. Only understands %d, %x, %p, %c, %s.
void
vprintf(int fd, const char *fmt, va_list ap)
{
 64c:	711d                	addi	sp,sp,-96
 64e:	ec86                	sd	ra,88(sp)
 650:	e8a2                	sd	s0,80(sp)
 652:	e0ca                	sd	s2,64(sp)
 654:	1080                	addi	s0,sp,96
  char *s;
  int c0, c1, c2, i, state;

  state = 0;
  for(i = 0; fmt[i]; i++){
 656:	0005c903          	lbu	s2,0(a1)
 65a:	28090663          	beqz	s2,8e6 <vprintf+0x29a>
 65e:	e4a6                	sd	s1,72(sp)
 660:	fc4e                	sd	s3,56(sp)
 662:	f852                	sd	s4,48(sp)
 664:	f456                	sd	s5,40(sp)
 666:	f05a                	sd	s6,32(sp)
 668:	ec5e                	sd	s7,24(sp)
 66a:	e862                	sd	s8,16(sp)
 66c:	e466                	sd	s9,8(sp)
 66e:	8b2a                	mv	s6,a0
 670:	8a2e                	mv	s4,a1
 672:	8bb2                	mv	s7,a2
  state = 0;
 674:	4981                	li	s3,0
  for(i = 0; fmt[i]; i++){
 676:	4481                	li	s1,0
 678:	4701                	li	a4,0
      if(c0 == '%'){
        state = '%';
      } else {
        putc(fd, c0);
      }
    } else if(state == '%'){
 67a:	02500a93          	li	s5,37
      c1 = c2 = 0;
      if(c0) c1 = fmt[i+1] & 0xff;
      if(c1) c2 = fmt[i+2] & 0xff;
      if(c0 == 'd'){
 67e:	06400c13          	li	s8,100
        printint(fd, va_arg(ap, int), 10, 1);
      } else if(c0 == 'l' && c1 == 'd'){
 682:	06c00c93          	li	s9,108
 686:	a005                	j	6a6 <vprintf+0x5a>
        putc(fd, c0);
 688:	85ca                	mv	a1,s2
 68a:	855a                	mv	a0,s6
 68c:	efbff0ef          	jal	586 <putc>
 690:	a019                	j	696 <vprintf+0x4a>
    } else if(state == '%'){
 692:	03598263          	beq	s3,s5,6b6 <vprintf+0x6a>
  for(i = 0; fmt[i]; i++){
 696:	2485                	addiw	s1,s1,1
 698:	8726                	mv	a4,s1
 69a:	009a07b3          	add	a5,s4,s1
 69e:	0007c903          	lbu	s2,0(a5)
 6a2:	22090a63          	beqz	s2,8d6 <vprintf+0x28a>
    c0 = fmt[i] & 0xff;
 6a6:	0009079b          	sext.w	a5,s2
    if(state == 0){
 6aa:	fe0994e3          	bnez	s3,692 <vprintf+0x46>
      if(c0 == '%'){
 6ae:	fd579de3          	bne	a5,s5,688 <vprintf+0x3c>
        state = '%';
 6b2:	89be                	mv	s3,a5
 6b4:	b7cd                	j	696 <vprintf+0x4a>
      if(c0) c1 = fmt[i+1] & 0xff;
 6b6:	00ea06b3          	add	a3,s4,a4
 6ba:	0016c683          	lbu	a3,1(a3)
      c1 = c2 = 0;
 6be:	8636                	mv	a2,a3
      if(c1) c2 = fmt[i+2] & 0xff;
 6c0:	c681                	beqz	a3,6c8 <vprintf+0x7c>
 6c2:	9752                	add	a4,a4,s4
 6c4:	00274603          	lbu	a2,2(a4)
      if(c0 == 'd'){
 6c8:	05878363          	beq	a5,s8,70e <vprintf+0xc2>
      } else if(c0 == 'l' && c1 == 'd'){
 6cc:	05978d63          	beq	a5,s9,726 <vprintf+0xda>
        printint(fd, va_arg(ap, uint64), 10, 1);
        i += 1;
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'd'){
        printint(fd, va_arg(ap, uint64), 10, 1);
        i += 2;
      } else if(c0 == 'u'){
 6d0:	07500713          	li	a4,117
 6d4:	0ee78763          	beq	a5,a4,7c2 <vprintf+0x176>
        printint(fd, va_arg(ap, uint64), 10, 0);
        i += 1;
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'u'){
        printint(fd, va_arg(ap, uint64), 10, 0);
        i += 2;
      } else if(c0 == 'x'){
 6d8:	07800713          	li	a4,120
 6dc:	12e78963          	beq	a5,a4,80e <vprintf+0x1c2>
        printint(fd, va_arg(ap, uint64), 16, 0);
        i += 1;
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'x'){
        printint(fd, va_arg(ap, uint64), 16, 0);
        i += 2;
      } else if(c0 == 'p'){
 6e0:	07000713          	li	a4,112
 6e4:	14e78e63          	beq	a5,a4,840 <vprintf+0x1f4>
        printptr(fd, va_arg(ap, uint64));
      } else if(c0 == 'c'){
 6e8:	06300713          	li	a4,99
 6ec:	18e78e63          	beq	a5,a4,888 <vprintf+0x23c>
        putc(fd, va_arg(ap, uint32));
      } else if(c0 == 's'){
 6f0:	07300713          	li	a4,115
 6f4:	1ae78463          	beq	a5,a4,89c <vprintf+0x250>
        if((s = va_arg(ap, char*)) == 0)
          s = "(null)";
        for(; *s; s++)
          putc(fd, *s);
      } else if(c0 == '%'){
 6f8:	02500713          	li	a4,37
 6fc:	04e79563          	bne	a5,a4,746 <vprintf+0xfa>
        putc(fd, '%');
 700:	02500593          	li	a1,37
 704:	855a                	mv	a0,s6
 706:	e81ff0ef          	jal	586 <putc>
        // Unknown % sequence.  Print it to draw attention.
        putc(fd, '%');
        putc(fd, c0);
      }

      state = 0;
 70a:	4981                	li	s3,0
 70c:	b769                	j	696 <vprintf+0x4a>
        printint(fd, va_arg(ap, int), 10, 1);
 70e:	008b8913          	addi	s2,s7,8
 712:	4685                	li	a3,1
 714:	4629                	li	a2,10
 716:	000ba583          	lw	a1,0(s7)
 71a:	855a                	mv	a0,s6
 71c:	e89ff0ef          	jal	5a4 <printint>
 720:	8bca                	mv	s7,s2
      state = 0;
 722:	4981                	li	s3,0
 724:	bf8d                	j	696 <vprintf+0x4a>
      } else if(c0 == 'l' && c1 == 'd'){
 726:	06400793          	li	a5,100
 72a:	02f68963          	beq	a3,a5,75c <vprintf+0x110>
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'd'){
 72e:	06c00793          	li	a5,108
 732:	04f68263          	beq	a3,a5,776 <vprintf+0x12a>
      } else if(c0 == 'l' && c1 == 'u'){
 736:	07500793          	li	a5,117
 73a:	0af68063          	beq	a3,a5,7da <vprintf+0x18e>
      } else if(c0 == 'l' && c1 == 'x'){
 73e:	07800793          	li	a5,120
 742:	0ef68263          	beq	a3,a5,826 <vprintf+0x1da>
        putc(fd, '%');
 746:	02500593          	li	a1,37
 74a:	855a                	mv	a0,s6
 74c:	e3bff0ef          	jal	586 <putc>
        putc(fd, c0);
 750:	85ca                	mv	a1,s2
 752:	855a                	mv	a0,s6
 754:	e33ff0ef          	jal	586 <putc>
      state = 0;
 758:	4981                	li	s3,0
 75a:	bf35                	j	696 <vprintf+0x4a>
        printint(fd, va_arg(ap, uint64), 10, 1);
 75c:	008b8913          	addi	s2,s7,8
 760:	4685                	li	a3,1
 762:	4629                	li	a2,10
 764:	000bb583          	ld	a1,0(s7)
 768:	855a                	mv	a0,s6
 76a:	e3bff0ef          	jal	5a4 <printint>
        i += 1;
 76e:	2485                	addiw	s1,s1,1
        printint(fd, va_arg(ap, uint64), 10, 1);
 770:	8bca                	mv	s7,s2
      state = 0;
 772:	4981                	li	s3,0
        i += 1;
 774:	b70d                	j	696 <vprintf+0x4a>
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'd'){
 776:	06400793          	li	a5,100
 77a:	02f60763          	beq	a2,a5,7a8 <vprintf+0x15c>
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'u'){
 77e:	07500793          	li	a5,117
 782:	06f60963          	beq	a2,a5,7f4 <vprintf+0x1a8>
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'x'){
 786:	07800793          	li	a5,120
 78a:	faf61ee3          	bne	a2,a5,746 <vprintf+0xfa>
        printint(fd, va_arg(ap, uint64), 16, 0);
 78e:	008b8913          	addi	s2,s7,8
 792:	4681                	li	a3,0
 794:	4641                	li	a2,16
 796:	000bb583          	ld	a1,0(s7)
 79a:	855a                	mv	a0,s6
 79c:	e09ff0ef          	jal	5a4 <printint>
        i += 2;
 7a0:	2489                	addiw	s1,s1,2
        printint(fd, va_arg(ap, uint64), 16, 0);
 7a2:	8bca                	mv	s7,s2
      state = 0;
 7a4:	4981                	li	s3,0
        i += 2;
 7a6:	bdc5                	j	696 <vprintf+0x4a>
        printint(fd, va_arg(ap, uint64), 10, 1);
 7a8:	008b8913          	addi	s2,s7,8
 7ac:	4685                	li	a3,1
 7ae:	4629                	li	a2,10
 7b0:	000bb583          	ld	a1,0(s7)
 7b4:	855a                	mv	a0,s6
 7b6:	defff0ef          	jal	5a4 <printint>
        i += 2;
 7ba:	2489                	addiw	s1,s1,2
        printint(fd, va_arg(ap, uint64), 10, 1);
 7bc:	8bca                	mv	s7,s2
      state = 0;
 7be:	4981                	li	s3,0
        i += 2;
 7c0:	bdd9                	j	696 <vprintf+0x4a>
        printint(fd, va_arg(ap, uint32), 10, 0);
 7c2:	008b8913          	addi	s2,s7,8
 7c6:	4681                	li	a3,0
 7c8:	4629                	li	a2,10
 7ca:	000be583          	lwu	a1,0(s7)
 7ce:	855a                	mv	a0,s6
 7d0:	dd5ff0ef          	jal	5a4 <printint>
 7d4:	8bca                	mv	s7,s2
      state = 0;
 7d6:	4981                	li	s3,0
 7d8:	bd7d                	j	696 <vprintf+0x4a>
        printint(fd, va_arg(ap, uint64), 10, 0);
 7da:	008b8913          	addi	s2,s7,8
 7de:	4681                	li	a3,0
 7e0:	4629                	li	a2,10
 7e2:	000bb583          	ld	a1,0(s7)
 7e6:	855a                	mv	a0,s6
 7e8:	dbdff0ef          	jal	5a4 <printint>
        i += 1;
 7ec:	2485                	addiw	s1,s1,1
        printint(fd, va_arg(ap, uint64), 10, 0);
 7ee:	8bca                	mv	s7,s2
      state = 0;
 7f0:	4981                	li	s3,0
        i += 1;
 7f2:	b555                	j	696 <vprintf+0x4a>
        printint(fd, va_arg(ap, uint64), 10, 0);
 7f4:	008b8913          	addi	s2,s7,8
 7f8:	4681                	li	a3,0
 7fa:	4629                	li	a2,10
 7fc:	000bb583          	ld	a1,0(s7)
 800:	855a                	mv	a0,s6
 802:	da3ff0ef          	jal	5a4 <printint>
        i += 2;
 806:	2489                	addiw	s1,s1,2
        printint(fd, va_arg(ap, uint64), 10, 0);
 808:	8bca                	mv	s7,s2
      state = 0;
 80a:	4981                	li	s3,0
        i += 2;
 80c:	b569                	j	696 <vprintf+0x4a>
        printint(fd, va_arg(ap, uint32), 16, 0);
 80e:	008b8913          	addi	s2,s7,8
 812:	4681                	li	a3,0
 814:	4641                	li	a2,16
 816:	000be583          	lwu	a1,0(s7)
 81a:	855a                	mv	a0,s6
 81c:	d89ff0ef          	jal	5a4 <printint>
 820:	8bca                	mv	s7,s2
      state = 0;
 822:	4981                	li	s3,0
 824:	bd8d                	j	696 <vprintf+0x4a>
        printint(fd, va_arg(ap, uint64), 16, 0);
 826:	008b8913          	addi	s2,s7,8
 82a:	4681                	li	a3,0
 82c:	4641                	li	a2,16
 82e:	000bb583          	ld	a1,0(s7)
 832:	855a                	mv	a0,s6
 834:	d71ff0ef          	jal	5a4 <printint>
        i += 1;
 838:	2485                	addiw	s1,s1,1
        printint(fd, va_arg(ap, uint64), 16, 0);
 83a:	8bca                	mv	s7,s2
      state = 0;
 83c:	4981                	li	s3,0
        i += 1;
 83e:	bda1                	j	696 <vprintf+0x4a>
 840:	e06a                	sd	s10,0(sp)
        printptr(fd, va_arg(ap, uint64));
 842:	008b8d13          	addi	s10,s7,8
 846:	000bb983          	ld	s3,0(s7)
  putc(fd, '0');
 84a:	03000593          	li	a1,48
 84e:	855a                	mv	a0,s6
 850:	d37ff0ef          	jal	586 <putc>
  putc(fd, 'x');
 854:	07800593          	li	a1,120
 858:	855a                	mv	a0,s6
 85a:	d2dff0ef          	jal	586 <putc>
 85e:	4941                	li	s2,16
    putc(fd, digits[x >> (sizeof(uint64) * 8 - 4)]);
 860:	00000b97          	auipc	s7,0x0
 864:	3e0b8b93          	addi	s7,s7,992 # c40 <digits>
 868:	03c9d793          	srli	a5,s3,0x3c
 86c:	97de                	add	a5,a5,s7
 86e:	0007c583          	lbu	a1,0(a5)
 872:	855a                	mv	a0,s6
 874:	d13ff0ef          	jal	586 <putc>
  for (i = 0; i < (sizeof(uint64) * 2); i++, x <<= 4)
 878:	0992                	slli	s3,s3,0x4
 87a:	397d                	addiw	s2,s2,-1
 87c:	fe0916e3          	bnez	s2,868 <vprintf+0x21c>
        printptr(fd, va_arg(ap, uint64));
 880:	8bea                	mv	s7,s10
      state = 0;
 882:	4981                	li	s3,0
 884:	6d02                	ld	s10,0(sp)
 886:	bd01                	j	696 <vprintf+0x4a>
        putc(fd, va_arg(ap, uint32));
 888:	008b8913          	addi	s2,s7,8
 88c:	000bc583          	lbu	a1,0(s7)
 890:	855a                	mv	a0,s6
 892:	cf5ff0ef          	jal	586 <putc>
 896:	8bca                	mv	s7,s2
      state = 0;
 898:	4981                	li	s3,0
 89a:	bbf5                	j	696 <vprintf+0x4a>
        if((s = va_arg(ap, char*)) == 0)
 89c:	008b8993          	addi	s3,s7,8
 8a0:	000bb903          	ld	s2,0(s7)
 8a4:	00090f63          	beqz	s2,8c2 <vprintf+0x276>
        for(; *s; s++)
 8a8:	00094583          	lbu	a1,0(s2)
 8ac:	c195                	beqz	a1,8d0 <vprintf+0x284>
          putc(fd, *s);
 8ae:	855a                	mv	a0,s6
 8b0:	cd7ff0ef          	jal	586 <putc>
        for(; *s; s++)
 8b4:	0905                	addi	s2,s2,1
 8b6:	00094583          	lbu	a1,0(s2)
 8ba:	f9f5                	bnez	a1,8ae <vprintf+0x262>
        if((s = va_arg(ap, char*)) == 0)
 8bc:	8bce                	mv	s7,s3
      state = 0;
 8be:	4981                	li	s3,0
 8c0:	bbd9                	j	696 <vprintf+0x4a>
          s = "(null)";
 8c2:	00000917          	auipc	s2,0x0
 8c6:	2ee90913          	addi	s2,s2,750 # bb0 <malloc+0x1e2>
        for(; *s; s++)
 8ca:	02800593          	li	a1,40
 8ce:	b7c5                	j	8ae <vprintf+0x262>
        if((s = va_arg(ap, char*)) == 0)
 8d0:	8bce                	mv	s7,s3
      state = 0;
 8d2:	4981                	li	s3,0
 8d4:	b3c9                	j	696 <vprintf+0x4a>
 8d6:	64a6                	ld	s1,72(sp)
 8d8:	79e2                	ld	s3,56(sp)
 8da:	7a42                	ld	s4,48(sp)
 8dc:	7aa2                	ld	s5,40(sp)
 8de:	7b02                	ld	s6,32(sp)
 8e0:	6be2                	ld	s7,24(sp)
 8e2:	6c42                	ld	s8,16(sp)
 8e4:	6ca2                	ld	s9,8(sp)
    }
  }
}
 8e6:	60e6                	ld	ra,88(sp)
 8e8:	6446                	ld	s0,80(sp)
 8ea:	6906                	ld	s2,64(sp)
 8ec:	6125                	addi	sp,sp,96
 8ee:	8082                	ret

00000000000008f0 <fprintf>:

void
fprintf(int fd, const char *fmt, ...)
{
 8f0:	715d                	addi	sp,sp,-80
 8f2:	ec06                	sd	ra,24(sp)
 8f4:	e822                	sd	s0,16(sp)
 8f6:	1000                	addi	s0,sp,32
 8f8:	e010                	sd	a2,0(s0)
 8fa:	e414                	sd	a3,8(s0)
 8fc:	e818                	sd	a4,16(s0)
 8fe:	ec1c                	sd	a5,24(s0)
 900:	03043023          	sd	a6,32(s0)
 904:	03143423          	sd	a7,40(s0)
  va_list ap;

  va_start(ap, fmt);
 908:	fe843423          	sd	s0,-24(s0)
  vprintf(fd, fmt, ap);
 90c:	8622                	mv	a2,s0
 90e:	d3fff0ef          	jal	64c <vprintf>
}
 912:	60e2                	ld	ra,24(sp)
 914:	6442                	ld	s0,16(sp)
 916:	6161                	addi	sp,sp,80
 918:	8082                	ret

000000000000091a <printf>:

void
printf(const char *fmt, ...)
{
 91a:	711d                	addi	sp,sp,-96
 91c:	ec06                	sd	ra,24(sp)
 91e:	e822                	sd	s0,16(sp)
 920:	1000                	addi	s0,sp,32
 922:	e40c                	sd	a1,8(s0)
 924:	e810                	sd	a2,16(s0)
 926:	ec14                	sd	a3,24(s0)
 928:	f018                	sd	a4,32(s0)
 92a:	f41c                	sd	a5,40(s0)
 92c:	03043823          	sd	a6,48(s0)
 930:	03143c23          	sd	a7,56(s0)
  va_list ap;

  va_start(ap, fmt);
 934:	00840613          	addi	a2,s0,8
 938:	fec43423          	sd	a2,-24(s0)
  vprintf(1, fmt, ap);
 93c:	85aa                	mv	a1,a0
 93e:	4505                	li	a0,1
 940:	d0dff0ef          	jal	64c <vprintf>
}
 944:	60e2                	ld	ra,24(sp)
 946:	6442                	ld	s0,16(sp)
 948:	6125                	addi	sp,sp,96
 94a:	8082                	ret

000000000000094c <free>:
static Header base;
static Header *freep;

void
free(void *ap)
{
 94c:	1141                	addi	sp,sp,-16
 94e:	e422                	sd	s0,8(sp)
 950:	0800                	addi	s0,sp,16
  Header *bp, *p;

  bp = (Header*)ap - 1;
 952:	ff050693          	addi	a3,a0,-16
  for(p = freep; !(bp > p && bp < p->s.ptr); p = p->s.ptr)
 956:	00001797          	auipc	a5,0x1
 95a:	6aa7b783          	ld	a5,1706(a5) # 2000 <freep>
 95e:	a02d                	j	988 <free+0x3c>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
      break;
  if(bp + bp->s.size == p->s.ptr){
    bp->s.size += p->s.ptr->s.size;
 960:	4618                	lw	a4,8(a2)
 962:	9f2d                	addw	a4,a4,a1
 964:	fee52c23          	sw	a4,-8(a0)
    bp->s.ptr = p->s.ptr->s.ptr;
 968:	6398                	ld	a4,0(a5)
 96a:	6310                	ld	a2,0(a4)
 96c:	a83d                	j	9aa <free+0x5e>
  } else
    bp->s.ptr = p->s.ptr;
  if(p + p->s.size == bp){
    p->s.size += bp->s.size;
 96e:	ff852703          	lw	a4,-8(a0)
 972:	9f31                	addw	a4,a4,a2
 974:	c798                	sw	a4,8(a5)
    p->s.ptr = bp->s.ptr;
 976:	ff053683          	ld	a3,-16(a0)
 97a:	a091                	j	9be <free+0x72>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
 97c:	6398                	ld	a4,0(a5)
 97e:	00e7e463          	bltu	a5,a4,986 <free+0x3a>
 982:	00e6ea63          	bltu	a3,a4,996 <free+0x4a>
{
 986:	87ba                	mv	a5,a4
  for(p = freep; !(bp > p && bp < p->s.ptr); p = p->s.ptr)
 988:	fed7fae3          	bgeu	a5,a3,97c <free+0x30>
 98c:	6398                	ld	a4,0(a5)
 98e:	00e6e463          	bltu	a3,a4,996 <free+0x4a>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
 992:	fee7eae3          	bltu	a5,a4,986 <free+0x3a>
  if(bp + bp->s.size == p->s.ptr){
 996:	ff852583          	lw	a1,-8(a0)
 99a:	6390                	ld	a2,0(a5)
 99c:	02059813          	slli	a6,a1,0x20
 9a0:	01c85713          	srli	a4,a6,0x1c
 9a4:	9736                	add	a4,a4,a3
 9a6:	fae60de3          	beq	a2,a4,960 <free+0x14>
    bp->s.ptr = p->s.ptr->s.ptr;
 9aa:	fec53823          	sd	a2,-16(a0)
  if(p + p->s.size == bp){
 9ae:	4790                	lw	a2,8(a5)
 9b0:	02061593          	slli	a1,a2,0x20
 9b4:	01c5d713          	srli	a4,a1,0x1c
 9b8:	973e                	add	a4,a4,a5
 9ba:	fae68ae3          	beq	a3,a4,96e <free+0x22>
    p->s.ptr = bp->s.ptr;
 9be:	e394                	sd	a3,0(a5)
  } else
    p->s.ptr = bp;
  freep = p;
 9c0:	00001717          	auipc	a4,0x1
 9c4:	64f73023          	sd	a5,1600(a4) # 2000 <freep>
}
 9c8:	6422                	ld	s0,8(sp)
 9ca:	0141                	addi	sp,sp,16
 9cc:	8082                	ret

00000000000009ce <malloc>:
  return freep;
}

void*
malloc(uint nbytes)
{
 9ce:	7139                	addi	sp,sp,-64
 9d0:	fc06                	sd	ra,56(sp)
 9d2:	f822                	sd	s0,48(sp)
 9d4:	f426                	sd	s1,40(sp)
 9d6:	ec4e                	sd	s3,24(sp)
 9d8:	0080                	addi	s0,sp,64
  Header *p, *prevp;
  uint nunits;

  nunits = (nbytes + sizeof(Header) - 1)/sizeof(Header) + 1;
 9da:	02051493          	slli	s1,a0,0x20
 9de:	9081                	srli	s1,s1,0x20
 9e0:	04bd                	addi	s1,s1,15
 9e2:	8091                	srli	s1,s1,0x4
 9e4:	0014899b          	addiw	s3,s1,1
 9e8:	0485                	addi	s1,s1,1
  if((prevp = freep) == 0){
 9ea:	00001517          	auipc	a0,0x1
 9ee:	61653503          	ld	a0,1558(a0) # 2000 <freep>
 9f2:	c915                	beqz	a0,a26 <malloc+0x58>
    base.s.ptr = freep = prevp = &base;
    base.s.size = 0;
  }
  for(p = prevp->s.ptr; ; prevp = p, p = p->s.ptr){
 9f4:	611c                	ld	a5,0(a0)
    if(p->s.size >= nunits){
 9f6:	4798                	lw	a4,8(a5)
 9f8:	08977a63          	bgeu	a4,s1,a8c <malloc+0xbe>
 9fc:	f04a                	sd	s2,32(sp)
 9fe:	e852                	sd	s4,16(sp)
 a00:	e456                	sd	s5,8(sp)
 a02:	e05a                	sd	s6,0(sp)
  if(nu < 4096)
 a04:	8a4e                	mv	s4,s3
 a06:	0009871b          	sext.w	a4,s3
 a0a:	6685                	lui	a3,0x1
 a0c:	00d77363          	bgeu	a4,a3,a12 <malloc+0x44>
 a10:	6a05                	lui	s4,0x1
 a12:	000a0b1b          	sext.w	s6,s4
  p = sbrk(nu * sizeof(Header));
 a16:	004a1a1b          	slliw	s4,s4,0x4
        p->s.size = nunits;
      }
      freep = prevp;
      return (void*)(p + 1);
    }
    if(p == freep)
 a1a:	00001917          	auipc	s2,0x1
 a1e:	5e690913          	addi	s2,s2,1510 # 2000 <freep>
  if(p == SBRK_ERROR)
 a22:	5afd                	li	s5,-1
 a24:	a081                	j	a64 <malloc+0x96>
 a26:	f04a                	sd	s2,32(sp)
 a28:	e852                	sd	s4,16(sp)
 a2a:	e456                	sd	s5,8(sp)
 a2c:	e05a                	sd	s6,0(sp)
    base.s.ptr = freep = prevp = &base;
 a2e:	00001797          	auipc	a5,0x1
 a32:	5e278793          	addi	a5,a5,1506 # 2010 <base>
 a36:	00001717          	auipc	a4,0x1
 a3a:	5cf73523          	sd	a5,1482(a4) # 2000 <freep>
 a3e:	e39c                	sd	a5,0(a5)
    base.s.size = 0;
 a40:	0007a423          	sw	zero,8(a5)
    if(p->s.size >= nunits){
 a44:	b7c1                	j	a04 <malloc+0x36>
        prevp->s.ptr = p->s.ptr;
 a46:	6398                	ld	a4,0(a5)
 a48:	e118                	sd	a4,0(a0)
 a4a:	a8a9                	j	aa4 <malloc+0xd6>
  hp->s.size = nu;
 a4c:	01652423          	sw	s6,8(a0)
  free((void*)(hp + 1));
 a50:	0541                	addi	a0,a0,16
 a52:	efbff0ef          	jal	94c <free>
  return freep;
 a56:	00093503          	ld	a0,0(s2)
      if((p = morecore(nunits)) == 0)
 a5a:	c12d                	beqz	a0,abc <malloc+0xee>
  for(p = prevp->s.ptr; ; prevp = p, p = p->s.ptr){
 a5c:	611c                	ld	a5,0(a0)
    if(p->s.size >= nunits){
 a5e:	4798                	lw	a4,8(a5)
 a60:	02977263          	bgeu	a4,s1,a84 <malloc+0xb6>
    if(p == freep)
 a64:	00093703          	ld	a4,0(s2)
 a68:	853e                	mv	a0,a5
 a6a:	fef719e3          	bne	a4,a5,a5c <malloc+0x8e>
  p = sbrk(nu * sizeof(Header));
 a6e:	8552                	mv	a0,s4
 a70:	a43ff0ef          	jal	4b2 <sbrk>
  if(p == SBRK_ERROR)
 a74:	fd551ce3          	bne	a0,s5,a4c <malloc+0x7e>
        return 0;
 a78:	4501                	li	a0,0
 a7a:	7902                	ld	s2,32(sp)
 a7c:	6a42                	ld	s4,16(sp)
 a7e:	6aa2                	ld	s5,8(sp)
 a80:	6b02                	ld	s6,0(sp)
 a82:	a03d                	j	ab0 <malloc+0xe2>
 a84:	7902                	ld	s2,32(sp)
 a86:	6a42                	ld	s4,16(sp)
 a88:	6aa2                	ld	s5,8(sp)
 a8a:	6b02                	ld	s6,0(sp)
      if(p->s.size == nunits)
 a8c:	fae48de3          	beq	s1,a4,a46 <malloc+0x78>
        p->s.size -= nunits;
 a90:	4137073b          	subw	a4,a4,s3
 a94:	c798                	sw	a4,8(a5)
        p += p->s.size;
 a96:	02071693          	slli	a3,a4,0x20
 a9a:	01c6d713          	srli	a4,a3,0x1c
 a9e:	97ba                	add	a5,a5,a4
        p->s.size = nunits;
 aa0:	0137a423          	sw	s3,8(a5)
      freep = prevp;
 aa4:	00001717          	auipc	a4,0x1
 aa8:	54a73e23          	sd	a0,1372(a4) # 2000 <freep>
      return (void*)(p + 1);
 aac:	01078513          	addi	a0,a5,16
  }
}
 ab0:	70e2                	ld	ra,56(sp)
 ab2:	7442                	ld	s0,48(sp)
 ab4:	74a2                	ld	s1,40(sp)
 ab6:	69e2                	ld	s3,24(sp)
 ab8:	6121                	addi	sp,sp,64
 aba:	8082                	ret
 abc:	7902                	ld	s2,32(sp)
 abe:	6a42                	ld	s4,16(sp)
 ac0:	6aa2                	ld	s5,8(sp)
 ac2:	6b02                	ld	s6,0(sp)
 ac4:	b7f5                	j	ab0 <malloc+0xe2>
