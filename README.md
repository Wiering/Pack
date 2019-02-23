# pack

This is a simple runlength packer for data in Pascal/Delphi. 
It was used a lot in DOS to save valuable memory when storing data on disk or inside of a program.
Data that has many repeating characters can be compressed well. This is often useful for graphics, palettes, levels and other data used in games.

Use **pack.exe** to compress a file:

``` pack  input-file  output-file ```

As a very simple example, suppose you have a file **level1.txt** that represents a level for a game

``` 
XXXXXXXXXXXXXXX
Xsx.....x.....X
X.xxxxx.x.x.x.X
X...x.x.....x.X
Xxx.x.xxxx.xx.X
X...x......x.fX
XXXXXXXXXXXXXXX
```
Pack it with the command: ```pack level1.txt level1.pck```

``` 
Old size: 119  New size: 79  Gain: 40 (33.6%)
``` 

The new (binary) file now looks something like this: 

```
OX.XsxE.xE.X.X.Exc.x.X.XÃ..xx..xX.XBxb.xCx.Bx.X.XC.xF.x.fX.OX
```

# bin2pas

The program **bin2pas** provides an easy way to get your packed file (or basically any file) right into your Pascal/Delphi code. It has the same syntax as pack:

``` bin2pas  input-file  output-file ```

So in this example, we can run: ``` bin2pas  level1.pck  level1.inc ```

This produces a new file **level1.inc**, which has the following contents:

```
procedure level1pck; assembler;
asm
  db  79, 88,  5, 13, 10, 88,115,120, 69, 46,  1,120, 69, 46,  5, 88
  db  13, 10, 88, 46, 69,120, 99, 46,120,  5, 46, 88, 13, 10, 88,199
  db  46, 46,120,120, 46, 46,120, 88,  3, 13, 10, 88, 66,120, 98, 46
  db 120, 67,120,  1, 46, 66,120,  5, 46, 88, 13, 10, 88, 67, 46,  1
  db 120, 70, 46,  6,120, 46,102, 88, 13, 10, 79, 88,  2, 13, 10
end;
```
You can include this file into your Pascal/Delphi code using the directive 

``` {$I level1.inc} ```

To reference the data, you can use ```@level1pck``` (as a pointer) or  ```@level1pck^``` (the actual data).

# unpack.inc

In your Pascal or Delphi code, you can include the code to unpack your data by using the directive

``` {$I UNPACK.INC}```

It contains two functions:
* ```procedure Unpack(p: Pointer)```
* ```function GetNextByte(): Byte```

In your code, start by calling **unpack** once and then use **GetNextByte** to get each next (uncompressed) byte of data. Note: You need to know the size of your data or have a way to recognize the end of the stream.

So in our example, you could have something like:

```
Unpack(@level1pck);
for j := 0 to LEVEL_SIZE_Y - 1 do
  for i := 0 to LEVEL_SIZE_X - 1 do
    case Chr(GetNextByte()) of
      'X': ...
```

Of course, this example is way too small for this to be beneficial. However, this system was used successfully in most games by Wiering Software, at least the ones written in Pascal/Delphi.


