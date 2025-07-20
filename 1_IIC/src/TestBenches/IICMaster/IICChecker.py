# -*- coding: UTF-8 -*-

IIC_CLOCK_INTERVAL= 128 # 当前IIC一个时钟周期的长度总共有128个外部时钟构成
ONE_HALF_IIC_CLOCK_INTERVAL = IIC_CLOCK_INTERVAL // 2
ONE_FOURTH_IIC_CLOCK_INTERVAL = IIC_CLOCK_INTERVAL // 4
THREE_FOURTHS_IIC_CLOCK_INTERVAL = IIC_CLOCK_INTERVAL * 3 // 4
USING_DESIGN_IIC_CLOCK_INTERVAL = True # 是否开启IIC时钟周期检查

# 用户提供scl以及sda的信号序列，检查是否符合IIC协议
class IIC_Checker():
    IIC_SIG_START = 0
    IIC_SIG_STOP = 1
    IIC_SIG_BIT_1 = 2
    IIC_SIG_BIT_0 = 3

    # 检查器基类，定义了检查器的接口规范
    class Base_Checker():
        def __init__(self):
            self._prev_scl = None
            self._prev_sda = None
            self._scl_rising_edge_count = 0
            self._scl_falling_edge_count = 0
            self._sda_rising_edge_count = 0
            self._sda_falling_edge_count = 0
            self._is_finished = False
            self._update_tick_count = 0

        def is_finished(self):
            """检查器是否已经完成了检查"""
            return self._is_finished

        def is_scl_rising(self, input_scl):
            """检查当前输入的scl信号是否是上升沿"""
            if self._prev_scl is None:
                return False
            return input_scl > self._prev_scl
        
        def is_scl_falling(self, input_scl):
            """检查当前输入的scl信号是否是下降沿"""
            if self._prev_scl is None:
                return False
            return input_scl < self._prev_scl
        
        def is_sda_rising(self, input_sda):
            """检查当前输入的sda信号是否是上升沿"""
            if self._prev_sda is None:
                return False
            return input_sda > self._prev_sda
        
        def is_sda_falling(self, input_sda):
            """检查当前输入的sda信号是否是下降沿"""
            if self._prev_sda is None:
                return False
            return input_sda < self._prev_sda
        
        def is_scl_no_change(self, input_scl):
            """检查当前输入的scl信号是否没有变化"""
            return not self.is_scl_falling(input_scl) and not self.is_scl_rising(input_scl)
        
        def is_sda_no_change(self, input_sda):
            """检查当前输入的sda信号是否没有变化"""
            return not self.is_sda_falling(input_sda) and not self.is_sda_rising(input_sda)

        def is_bus_no_change(self, input_scl, input_sda):
            """检查当前输入的scl和sda信号是否都没有变化"""
            return self.is_scl_no_change(input_scl) and self.is_sda_no_change(input_sda)
        # 1/4 ################################################################################
        def is_begin_of_one_fourth_iic_clock_interval(self):
            """检查当前输入的时钟周期，是否处于IIC时钟周期的四分之一的开始"""
            if not USING_DESIGN_IIC_CLOCK_INTERVAL:
                return True
            return self._update_tick_count == 0

        def is_inside_one_fourth_iic_clock_interval(self):
            """检查当前输入的时钟周期，是否处于IIC时钟周期的四分之一"""
            if not USING_DESIGN_IIC_CLOCK_INTERVAL:
                return True
            return self._update_tick_count < ONE_FOURTH_IIC_CLOCK_INTERVAL
        
        def is_end_of_one_fourth_iic_clock_interval(self):
            """检查当前输入的时钟周期，是否已经达到了IIC时钟周期的四分之一的结束"""
            if not USING_DESIGN_IIC_CLOCK_INTERVAL:
                return True
            return self._update_tick_count == ONE_FOURTH_IIC_CLOCK_INTERVAL - 1
        # 2/4 ################################################################################
        def is_begin_of_two_fourths_iic_clock_interval(self):
            """检查当前输入的时钟周期，是否处于IIC时钟周期的四分之二的开始"""
            if not USING_DESIGN_IIC_CLOCK_INTERVAL:
                return True
            return self._update_tick_count == ONE_FOURTH_IIC_CLOCK_INTERVAL
        
        def is_inside_two_fourths_iic_clock_interval(self):
            """检查当前输入的时钟周期，是否处于IIC时钟周期的四分之二"""
            if not USING_DESIGN_IIC_CLOCK_INTERVAL:
                return True
            return self._update_tick_count < ONE_HALF_IIC_CLOCK_INTERVAL
        
        def is_end_of_two_fourths_iic_clock_interval(self):
            """检查当前输入的时钟周期，是否处于IIC时钟周期的四分之二的结束"""
            if not USING_DESIGN_IIC_CLOCK_INTERVAL:
                return True
            return self._update_tick_count == ONE_HALF_IIC_CLOCK_INTERVAL - 1
        # 3/4 ################################################################################
        def is_begin_of_three_fourths_iic_clock_interval(self):
            """检查当前输入的时钟周期，是否处于IIC时钟周期的四分之三的开始"""
            if not USING_DESIGN_IIC_CLOCK_INTERVAL:
                return True
            return self._update_tick_count == ONE_HALF_IIC_CLOCK_INTERVAL
        
        def is_inside_three_fourths_iic_clock_interval(self):
            """检查当前输入的时钟周期，是否处于IIC时钟周期的四分之三"""
            if not USING_DESIGN_IIC_CLOCK_INTERVAL:
                return True
            return self._update_tick_count < THREE_FOURTHS_IIC_CLOCK_INTERVAL
        
        def is_end_of_three_fourths_iic_clock_interval(self):
            """检查当前输入的时钟周期，是否处于IIC时钟周期的四分之三的结束"""
            if not USING_DESIGN_IIC_CLOCK_INTERVAL:
                return True
            return self._update_tick_count == THREE_FOURTHS_IIC_CLOCK_INTERVAL - 1
        # 4/4 ################################################################################
        def is_begin_of_four_fourths_iic_clock_interval(self):
            """检查当前输入的时钟周期，是否处于IIC时钟周期的四分之四的开始"""
            if not USING_DESIGN_IIC_CLOCK_INTERVAL:
                return True
            return self._update_tick_count == THREE_FOURTHS_IIC_CLOCK_INTERVAL
        def is_inside_four_fourths_iic_clock_interval(self):
            """检查当前输入的时钟周期，是否处于IIC时钟周期的四分之四"""
            if not USING_DESIGN_IIC_CLOCK_INTERVAL:
                return True
            return self._update_tick_count < IIC_CLOCK_INTERVAL
        def is_end_of_four_fourths_iic_clock_interval(self):
            """检查当前输入的时钟周期，是否处于IIC时钟周期的四分之四的结束"""
            if not USING_DESIGN_IIC_CLOCK_INTERVAL:
                return True
            return self._update_tick_count == IIC_CLOCK_INTERVAL - 1
        #####################################################################################

        def pre_update(self, input_scl, input_sda):
            """在更新之前，记录当前的scl和sda状态，并更新边沿计数"""
            self._scl_rising_edge_count = self._scl_rising_edge_count + 1 if self.is_scl_rising(input_scl) else self._scl_rising_edge_count
            self._scl_falling_edge_count = self._scl_falling_edge_count + 1 if self.is_scl_falling(input_scl) else self._scl_falling_edge_count
            self._sda_rising_edge_count = self._sda_rising_edge_count + 1 if self.is_sda_rising(input_sda) else self._sda_rising_edge_count
            self._sda_falling_edge_count = self._sda_falling_edge_count + 1 if self.is_sda_falling(input_sda) else self._sda_falling_edge_count

        def post_update(self, input_scl, input_sda):
            """在更新之后，记录当前的scl和sda状态，并重置更新计数"""
            self._prev_scl = input_scl
            self._prev_sda = input_sda
            self._update_tick_count += 1

        def update(self, input_scl, input_sda):
            raise RuntimeError("Unimplemented")
        
        def get_state_sig(self):
            """获取当前检查器的状态，不同检查器的返回的含义会不同"""
            raise RuntimeError("Unimplemented")

    class Start_Checker(Base_Checker):
        pass
    class Stop_State(Base_Checker):
        pass
    class Bit_Checker(Base_Checker):
        pass

    
    class Start_Checker(Base_Checker):
        def __init__(self):
            super().__init__()
        # scl，sda都处于高电平状态
        def is_in_state_1(self, input_scl, input_sda):
            return self._scl_rising_edge_count == 0 \
                and self._scl_falling_edge_count == 0 \
                and input_scl == 1 \
                and self._sda_rising_edge_count == 0 \
                and self._sda_falling_edge_count == 0 \
                and input_sda == 1 \
                and super().is_bus_no_change(input_scl, input_sda) \
                and super().is_inside_one_fourth_iic_clock_interval()
        # scl保持高电平，sda被拉低
        def is_change_to_state_2(self, input_scl, input_sda):
            return self._scl_rising_edge_count == 0 \
                and self._scl_falling_edge_count == 0 \
                and input_scl == 1 \
                and super().is_scl_no_change(input_scl) \
                and self._sda_rising_edge_count == 0 \
                and self._sda_falling_edge_count == 1 \
                and input_sda == 0 \
                and super().is_sda_falling(input_sda) \
                and super().is_begin_of_two_fourths_iic_clock_interval()
        # scl处于高电平，sda处于低电平
        def is_in_state_2(self, input_scl, input_sda):
            return self._scl_rising_edge_count == 0 \
                and self._scl_falling_edge_count == 0 \
                and input_scl == 1 \
                and self._sda_rising_edge_count == 0 \
                and self._sda_falling_edge_count == 1 \
                and input_sda == 0 \
                and super().is_bus_no_change(input_scl, input_sda) \
                and super().is_inside_two_fourths_iic_clock_interval()
        # scl被拉低，sda处于低电平
        def is_change_to_state_3(self, input_scl, input_sda):
            return self._scl_rising_edge_count == 0 \
                and self._scl_falling_edge_count == 1 \
                and input_scl == 0 \
                and super().is_scl_falling(input_scl) \
                and self._sda_rising_edge_count == 0 \
                and self._sda_falling_edge_count == 1 \
                and input_sda == 0 \
                and super().is_sda_no_change(input_sda) \
                and super().is_begin_of_three_fourths_iic_clock_interval()
        # scl和sda同时处于低电平
        def is_in_state_3(self, input_scl, input_sda):
            return self._scl_rising_edge_count == 0 \
                and self._sda_rising_edge_count == 0 \
                and input_scl == 0 \
                and self._scl_falling_edge_count == 1 \
                and self._sda_falling_edge_count == 1 \
                and input_sda == 0 \
                and super().is_bus_no_change(input_scl, input_sda) \
                and super().is_inside_three_fourths_iic_clock_interval()

        def get_state_sig(self):
            return IIC_Checker.IIC_SIG_START

        def update(self, input_scl, input_sda):
            self.pre_update(input_scl, input_sda)
            
            if self.is_in_state_1(input_scl, input_sda):
                pass
            elif self.is_change_to_state_2(input_scl, input_sda):
                pass
            elif self.is_in_state_2(input_scl, input_sda):
                pass
            elif self.is_change_to_state_3(input_scl, input_sda):
                pass
            elif self.is_in_state_3(input_scl, input_sda):
                if super().is_end_of_three_fourths_iic_clock_interval():
                    self._is_finished = True
            else:
                return False

            self.post_update(input_scl, input_sda)
            return True
        
        def pre_update(self, input_scl, input_sda):
            return super().pre_update(input_scl, input_sda)

        def post_update(self, input_scl, input_sda):
            return super().post_update(input_scl, input_sda)


    class Stop_Checker(Base_Checker):
        def __init__(self):
            super().__init__()
        # scl和sda同时处于低电平
        def is_in_state_1(self, input_scl, input_sda):
            return self._scl_rising_edge_count == 0 \
                and self._scl_falling_edge_count == 0 \
                and input_scl == 0 \
                and self._sda_rising_edge_count == 0 \
                and self._sda_falling_edge_count == 0 \
                and input_sda == 0 \
                and super().is_bus_no_change(input_scl, input_sda) \
                and super().is_inside_one_fourth_iic_clock_interval()
        # scl被拉高，sda处于低电平
        def is_change_to_state_2(self, input_scl, input_sda):
            return self._scl_rising_edge_count == 1 \
                and self._scl_falling_edge_count == 0 \
                and input_scl == 1 \
                and super().is_scl_rising(input_scl) \
                and self._sda_rising_edge_count == 0 \
                and self._sda_falling_edge_count == 0 \
                and input_sda == 0 \
                and super().is_sda_no_change(input_sda) \
                and super().is_begin_of_two_fourths_iic_clock_interval()
        # scl处于高电平，sda处于低电平
        def is_in_state_2(self, input_scl, input_sda):
            return self._scl_rising_edge_count == 1 \
                and self._scl_falling_edge_count == 0 \
                and input_scl == 1 \
                and self._sda_rising_edge_count == 0 \
                and self._sda_falling_edge_count == 0 \
                and input_sda == 0 \
                and super().is_bus_no_change(input_scl, input_sda) \
                and super().is_inside_two_fourths_iic_clock_interval()
        # scl处于高电平，sda被拉高
        def is_change_to_state_3(self, input_scl, input_sda):
            return self._scl_rising_edge_count == 1 \
                and self._scl_falling_edge_count == 0 \
                and input_scl == 1 \
                and super().is_scl_no_change(input_scl) \
                and self._sda_rising_edge_count == 1 \
                and self._sda_falling_edge_count == 0 \
                and input_sda == 1 \
                and super().is_sda_rising(input_sda) \
                and super().is_begin_of_three_fourths_iic_clock_interval()
        # scl和sda同时处于高电平
        def is_in_state_3(self, input_scl, input_sda):
            return self._scl_rising_edge_count == 1 \
                and self._scl_falling_edge_count == 0 \
                and input_scl == 1 \
                and self._sda_rising_edge_count == 1 \
                and self._sda_falling_edge_count == 0 \
                and input_sda == 1 \
                and super().is_bus_no_change(input_scl, input_sda)

        def get_state_sig(self):
            return IIC_Checker.IIC_SIG_STOP

        def update(self, input_scl, input_sda):
            self.pre_update(input_scl, input_sda)
            
            if self.is_in_state_1(input_scl, input_sda):
                pass
            elif self.is_change_to_state_2(input_scl, input_sda):
                pass
            elif self.is_in_state_2(input_scl, input_sda):
                pass
            elif self.is_change_to_state_3(input_scl, input_sda):
                pass
            elif self.is_in_state_3(input_scl, input_sda):
                if super().is_end_of_three_fourths_iic_clock_interval():
                    self._is_finished = True
            else:
                return False

            self.post_update(input_scl, input_sda)
            return True
        
        def pre_update(self, input_scl, input_sda):
            return super().pre_update(input_scl, input_sda)

        def post_update(self, input_scl, input_sda):
            return super().post_update(input_scl, input_sda)
    
    class Repeat_Start_Checker(Base_Checker):
        def __init__(self):
            super().__init__()
            self.half_scl_cycle_interval = 0
            self.half_half_scl_cycle_interval = 0
            self._scl_cycle_state = 0
            self.sda_high_count = 0
            self._state_sig = None
        # scl处于低电平，sda处于高电平
        def is_in_state_1(self, input_scl, input_sda):
            return self._scl_rising_edge_count == 0 \
                and self._scl_falling_edge_count == 0 \
                and input_scl == 0 \
                and self._sda_rising_edge_count == 0 \
                and self._sda_falling_edge_count == 0 \
                and input_sda == 1 \
                and super().is_bus_no_change(input_scl, input_sda) \
                and super().is_inside_one_fourth_iic_clock_interval()
        # scl被拉高，sda保持高电平
        def is_change_to_state_2(self, input_scl, input_sda):
            return self._scl_rising_edge_count == 1 \
                and self._scl_falling_edge_count == 0 \
                and input_scl == 1 \
                and super().is_scl_rising(input_scl) \
                and self._sda_rising_edge_count == 0 \
                and self._sda_falling_edge_count == 0 \
                and input_sda == 1 \
                and super().is_sda_no_change(input_sda) \
                and super().is_begin_of_two_fourths_iic_clock_interval()
        # scl处于高电平，sda保持高电平
        def is_in_state_2(self, input_scl, input_sda):
            return self._scl_rising_edge_count == 1 \
                and self._scl_falling_edge_count == 0 \
                and input_scl == 1 \
                and self._sda_rising_edge_count == 0 \
                and self._sda_falling_edge_count == 0 \
                and input_sda == 1 \
                and super().is_bus_no_change(input_scl, input_sda) \
                and super().is_inside_two_fourths_iic_clock_interval()
        # scl保持高电平，sda被拉低
        def is_change_to_state_3(self, input_scl, input_sda):
            return self._scl_rising_edge_count == 1 \
                and self._scl_falling_edge_count == 0 \
                and super().is_scl_no_change(input_scl) \
                and input_scl == 1 \
                and self._sda_falling_edge_count == 1 \
                and self._sda_rising_edge_count == 0 \
                and input_sda == 0 \
                and super().is_sda_falling(input_sda) \
                and super().is_begin_of_three_fourths_iic_clock_interval()
        # scl保持高电平，sda处于低电平
        def is_in_state_3(self, input_scl, input_sda):
            return self._scl_rising_edge_count == 1 \
                and self._scl_falling_edge_count == 0 \
                and input_scl == 1 \
                and self._sda_falling_edge_count == 1 \
                and self._sda_rising_edge_count == 0 \
                and input_sda == 0 \
                and super().is_bus_no_change(input_scl, input_sda) \
                and super().is_inside_three_fourths_iic_clock_interval()
        # scl被拉低，sda处于低电平
        def is_change_to_state_4(self, input_scl, input_sda):
            return self._scl_rising_edge_count == 1 \
                and self._scl_falling_edge_count == 1 \
                and input_scl == 0 \
                and super().is_scl_falling(input_scl) \
                and self._sda_rising_edge_count == 0 \
                and self._sda_falling_edge_count == 1 \
                and input_sda == 0 \
                and super().is_sda_no_change(input_sda) \
                and super().is_begin_of_four_fourths_iic_clock_interval()
        # scl处于低电平，sda处于低电平
        def is_in_state_4(self, input_scl, input_sda):
            return self._scl_rising_edge_count == 1 \
                and self._scl_falling_edge_count == 1 \
                and input_scl == 0 \
                and self._sda_rising_edge_count == 0 \
                and self._sda_falling_edge_count == 1 \
                and input_sda == 0 \
                and self.is_bus_no_change(input_scl, input_sda) \
                and super().is_inside_four_fourths_iic_clock_interval()

        def get_state_sig(self):
            return IIC_Checker.IIC_SIG_BIT_1

        def update(self, input_scl, input_sda):
            self.pre_update(input_scl, input_sda)
            
            if self.is_in_state_1(input_scl, input_sda):
                pass
            elif self.is_change_to_state_2(input_scl, input_sda):
                pass
            elif self.is_in_state_2(input_scl, input_sda):
                pass
            elif self.is_change_to_state_3(input_scl, input_sda):
                pass
            elif self.is_in_state_3(input_scl, input_sda):
                pass
            elif self.is_change_to_state_4(input_scl, input_sda):
                pass
            elif self.is_in_state_4(input_scl, input_sda):
                if super().is_end_of_four_fourths_iic_clock_interval():
                    self._is_finished = True
            else:
                return False

            self.post_update(input_scl, input_sda)
            return True
        
        def pre_update(self, input_scl, input_sda):
            return super().pre_update(input_scl, input_sda)

        def post_update(self, input_scl, input_sda):
            return super().post_update(input_scl, input_sda)

        def get_state_sig(self):
            return self._state_sig

    class Bit_Checker(Base_Checker):
        def __init__(self, expected_bit_value):
            super().__init__()
            self.half_scl_cycle_interval = 0
            self.half_half_scl_cycle_interval = 0
            self._scl_cycle_state = 0
            self.sda_high_count = 0
            self._state_sig = None
            self._expected_bit_value = expected_bit_value
        # scl处于低电平
        def is_in_state_1(self, input_scl):
            return self._scl_rising_edge_count == 0 \
                and self._scl_falling_edge_count == 0 \
                and input_scl == 0 \
                and super().is_scl_no_change(input_scl) \
                and super().is_inside_one_fourth_iic_clock_interval
        # scl被拉高
        def is_change_to_state_2(self, input_scl):
            return self._scl_rising_edge_count == 1 \
                and self._scl_falling_edge_count == 0 \
                and input_scl == 1 \
                and super().is_scl_rising(input_scl) \
                and super().is_begin_of_two_fourths_iic_clock_interval()
        # scl处于高电平
        def is_in_state_2(self, input_scl):
            return self._scl_rising_edge_count == 1 \
                and self._scl_falling_edge_count == 0 \
                and input_scl == 1 \
                and super().is_scl_no_change(input_scl) \
                and (super().is_inside_two_fourths_iic_clock_interval or super().is_inside_three_fourths_iic_clock_interval())
        # scl被拉低
        def is_change_to_state_3(self, input_scl):
            return self._scl_rising_edge_count == 1 \
                and self._scl_falling_edge_count == 1 \
                and input_scl == 0 \
                and super().is_scl_falling(input_scl) \
                and super().is_begin_of_four_fourths_iic_clock_interval()
        # scl处于低电平
        def is_in_state_3(self, input_scl):
            return self._scl_rising_edge_count == 1 \
                and self._scl_falling_edge_count == 1 \
                and input_scl == 0 \
                and super().is_scl_no_change(input_scl) \
                and super().is_inside_four_fourths_iic_clock_interval()

        def get_state_sig(self):
            return IIC_Checker.IIC_SIG_BIT_1

        def update(self, input_scl, input_sda):
            self.pre_update(input_scl, input_sda)
            
            if self.is_in_state_1(input_scl):
                pass
            elif self.is_change_to_state_2(input_scl):
                self.sda_high_count += input_sda
                self.half_scl_cycle_interval += 1
            elif self.is_in_state_2(input_scl):
                self.sda_high_count += input_sda
                self.half_scl_cycle_interval += 1
            elif self.is_change_to_state_3(input_scl):
                pass
            elif self.is_in_state_3(input_scl):
                if super().is_end_of_four_fourths_iic_clock_interval():
                    if self.sda_high_count / self.half_scl_cycle_interval > 0.98 and self._expected_bit_value == 1:
                        # Finished!
                        self._state_sig = IIC_Checker.IIC_SIG_BIT_1
                        self._is_finished = True
                    elif self.sda_high_count / self.half_scl_cycle_interval < 0.02 and self._expected_bit_value == 0:
                        self._state_sig = IIC_Checker.IIC_SIG_BIT_0
                        self._is_finished = True
                    else:
                        return False
            else:
                return False

            self.post_update(input_scl, input_sda)
            return True
        
        def pre_update(self, input_scl, input_sda):
            return super().pre_update(input_scl, input_sda)

        def post_update(self, input_scl, input_sda):
            return super().post_update(input_scl, input_sda)

        def get_state_sig(self):
            return self._state_sig


def try_to_match_iic_sigs(checkers: list[IIC_Checker.Base_Checker], sigs_of_scl, sigs_of_sda):
    """
    尝试匹配IIC信号序列，检查器列表中的检查器会依次处理scl和sda信号序列
    parameters:
        checkers: IIC_Checker.Base_Checker的子类列表，包含了所有需要处理的检查器
        sigs_of_scl: scl信号序列
        sigs_of_sda: sda信号序列
    Returns:
        None: 如果没有检查器可以处理当前的scl和sda信号序列
    Raises:
        一旦其中一个检查器检查失败，将会抛出异常(assert)
    """
    assert len(checkers) and len(sigs_of_scl) and(sigs_of_sda)
    current_checker = checkers.pop(0)
    sig_idx = 0
    while sig_idx < len(sigs_of_scl) and sig_idx < len(sigs_of_sda) and current_checker is not None:
        current_scl = sigs_of_scl[sig_idx]
        current_sda = sigs_of_sda[sig_idx]
        assert current_checker.update(current_scl, current_sda)
        if current_checker.is_finished():
            if len(checkers):
                current_checker = checkers.pop(0)
            else:
                current_checker = None
        sig_idx = sig_idx + 1