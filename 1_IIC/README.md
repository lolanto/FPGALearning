# 介绍
这是IIC器件的原型设计。它由三部分构成：
1. IICMeta.v: 这部分控制bit以及开始/结束信号的传递，是真正控制IIC总线的器件
2. IIC_Master.v: IIC主机模块
3. IIC_Slave.v: IIC从机模块(TODO)

# IICMeta


# TODO
~~写完时钟延展的测试用例~~
~~单元测试不通过，表现为启动从钳低状态恢复的时候，时钟信号会从高电平转成低电平~~

~~理论上不应该拆一个IICMeta出来，而是直接做成IIC_Master以及IIC_Slave。因为前者既要控制sda，也要控制scl。~~
~~而后者只控制sda，scl的信息一直都是通过读取的方式完成的~~

~~给IIC_Master，IIC主机编写测试所有命令下的测试用例!~~
~~(感觉将IIC_Master和IIC_Meta合并，并没有多困难)~~

~~给IIC_Master增加时钟延展的支持功能!~~

2025/07/20
TODO
IIC Master的FSM有Complete -> Idle的状态变化，两个连续任务之间就会有2个时钟周期的间隔，尝试消除这个间隔
