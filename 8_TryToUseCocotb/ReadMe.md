# 环境配置
liunx命令行环境：cygwin以及msys2，目的是安装一系列windows上使用的linux命令功能(e.g. make)
python即pip; (略)
cocotb: pip install cocotb

# 执行命令
基础命令： make
生成波形图： make WAVES=1
    生成的波形图在sim_build目录下的fst文件，可以直接给gtkwave显示