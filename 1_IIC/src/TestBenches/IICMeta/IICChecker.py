# -*- coding: UTF-8 -*-

IIC_CLOCK_INTERVAL= 128 # 当前IIC一个时钟周期的长度总共有128个外部时钟构成
ONE_HALF_IIC_CLOCK_INTERVAL = IIC_CLOCK_INTERVAL // 2
ONE_FOURTH_IIC_CLOCK_INTERVAL = IIC_CLOCK_INTERVAL // 4
THREE_FOURTH_IIC_CLOCK_INTERVAL = IIC_CLOCK_INTERVAL * 3 // 4
USING_DESIGN_IIC_CLOCK_INTERVAL = True # 是否开启IIC时钟周期检查
class IIC_Checker():
    IIC_SIG_START = 0
    IIC_SIG_STOP = 1
    IIC_SIG_BIT_1 = 2
    IIC_SIG_BIT_0 = 3

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
            return self._is_finished

        def is_scl_rising(self, input_scl):
            if self._prev_scl is None:
                return False
            return input_scl > self._prev_scl
        
        def is_scl_falling(self, input_scl):
            if self._prev_scl is None:
                return False
            return input_scl < self._prev_scl
        
        def is_sda_rising(self, input_sda):
            if self._prev_sda is None:
                return False
            return input_sda > self._prev_sda
        
        def is_sda_falling(self, input_sda):
            if self._prev_sda is None:
                return False
            return input_sda < self._prev_sda
        
        def is_scl_no_change(self, input_scl):
            return not self.is_scl_falling(input_scl) and not self.is_scl_rising(input_scl)
        
        def is_sda_no_change(self, input_sda):
            return not self.is_sda_falling(input_sda) and not self.is_sda_rising(input_sda)

        def is_bus_no_change(self, input_scl, input_sda):
            return self.is_scl_no_change(input_scl) and self.is_sda_no_change(input_sda)

        def is_one_fourth_iic_clock_interval(self):
            if not USING_DESIGN_IIC_CLOCK_INTERVAL:
                return True
            return self._update_tick_count == ONE_FOURTH_IIC_CLOCK_INTERVAL
        
        def is_one_half_iic_clock_interval(self):
            if not USING_DESIGN_IIC_CLOCK_INTERVAL:
                return True
            return self._update_tick_count == ONE_HALF_IIC_CLOCK_INTERVAL
        
        def is_three_fourth_iic_clock_interval(self):
            if not USING_DESIGN_IIC_CLOCK_INTERVAL:
                return True
            return self._update_tick_count == THREE_FOURTH_IIC_CLOCK_INTERVAL
        
        def is_three_fourth_iic_clock_interval_minus_one(self):
            if not USING_DESIGN_IIC_CLOCK_INTERVAL:
                return True
            return self._update_tick_count == THREE_FOURTH_IIC_CLOCK_INTERVAL - 1

        def is_one_first_iic_clock_interval_minus_one(self):
            if not USING_DESIGN_IIC_CLOCK_INTERVAL:
                return True
            return self._update_tick_count == IIC_CLOCK_INTERVAL - 1

        def pre_update(self, input_scl, input_sda):
            self._scl_rising_edge_count = self._scl_rising_edge_count + 1 if self.is_scl_rising(input_scl) else self._scl_rising_edge_count
            self._scl_falling_edge_count = self._scl_falling_edge_count + 1 if self.is_scl_falling(input_scl) else self._scl_falling_edge_count
            self._sda_rising_edge_count = self._sda_rising_edge_count + 1 if self.is_sda_rising(input_sda) else self._sda_rising_edge_count
            self._sda_falling_edge_count = self._sda_falling_edge_count + 1 if self.is_sda_falling(input_sda) else self._sda_falling_edge_count

        def post_update(self, input_scl, input_sda):
            self._prev_scl = input_scl
            self._prev_sda = input_sda
            self._update_tick_count += 1

        def update(self, input_scl, input_sda):
            raise RuntimeError("Unimplemented")
        
        def get_state_sig(self):
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
            self.half_half_scl_cycle_interval = 0
            self.scl_cycle = 0
        # scl，sda都处于高电平状态
        def is_in_state_1(self, input_scl, input_sda):
            return self._scl_rising_edge_count == 0 \
                and self._sda_rising_edge_count == 0 \
                and self._scl_falling_edge_count == 0 \
                and self._sda_falling_edge_count == 0 \
                and input_scl == 1 \
                and input_sda == 1 \
                and super().is_bus_no_change(input_scl, input_sda)
        # scl保持高电平，sda被拉低
        def is_change_to_state_2(self, input_scl, input_sda):
            return self._scl_rising_edge_count == 0 \
                and self._sda_rising_edge_count == 0 \
                and self._scl_falling_edge_count == 0 \
                and self._sda_falling_edge_count == 1 \
                and input_scl == 1 \
                and input_sda == 0 \
                and super().is_sda_falling(input_sda) \
                and not super().is_scl_falling(input_scl)
        # scl处于高电平，sda处于低电平
        def is_in_state_2(self, input_scl, input_sda):
            return self._scl_rising_edge_count == 0 \
                and self._sda_rising_edge_count == 0 \
                and self._scl_falling_edge_count == 0 \
                and self._sda_falling_edge_count == 1 \
                and input_scl == 1 \
                and input_sda == 0 \
                and super().is_bus_no_change(input_scl, input_sda)
        # scl被拉低，sda处于低电平
        def is_change_to_state_3(self, input_scl, input_sda):
            return self._scl_rising_edge_count == 0 \
                and self._sda_rising_edge_count == 0 \
                and self._scl_falling_edge_count == 1 \
                and self._sda_falling_edge_count == 1 \
                and input_scl == 0 \
                and input_sda == 0 \
                and not super().is_sda_falling(input_sda) \
                and super().is_scl_falling(input_scl)
        # scl和sda同时处于低电平
        def is_in_state_3(self, input_scl, input_sda):
            return self._scl_rising_edge_count == 0 \
                and self._sda_rising_edge_count == 0 \
                and self._scl_falling_edge_count == 1 \
                and self._sda_falling_edge_count == 1 \
                and input_scl == 0 \
                and input_sda == 0 \
                and super().is_bus_no_change(input_scl, input_sda)

        def get_state_sig(self):
            return IIC_Checker.IIC_SIG_START

        def update(self, input_scl, input_sda):
            self.pre_update(input_scl, input_sda)
            
            if self.is_in_state_1(input_scl, input_sda):
                pass
            elif self.is_change_to_state_2(input_scl, input_sda):
                if not super().is_one_fourth_iic_clock_interval():
                    return False
                self.scl_cycle = 0.25
                self.half_half_scl_cycle_interval += 1
            elif self.is_in_state_2(input_scl, input_sda):
                self.half_half_scl_cycle_interval += 1
            elif self.is_change_to_state_3(input_scl, input_sda):
                if not super().is_one_half_iic_clock_interval():
                    return False
                self.scl_cycle = 0.75
                self.half_half_scl_cycle_interval -= 1
            elif self.is_in_state_3(input_scl, input_sda):
                self.half_half_scl_cycle_interval -= 1
                if self.half_half_scl_cycle_interval == 0:
                    if not super().is_three_fourth_iic_clock_interval_minus_one():
                        return False
                    # finish!
                    self._is_finished = True
                    pass
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
            self.half_half_scl_cycle_interval = 0
            self.scl_cycle = 0
        # scl和sda同时处于低电平
        def is_in_state_1(self, input_scl, input_sda):
            return self._scl_rising_edge_count == 0 \
                and self._sda_rising_edge_count == 0 \
                and self._scl_falling_edge_count == 0 \
                and self._sda_falling_edge_count == 0 \
                and input_scl == 0 \
                and input_sda == 0 \
                and super().is_bus_no_change(input_scl, input_sda)
        # scl被拉高，sda处于低电平
        def is_change_to_state_2(self, input_scl, input_sda):
            return self._scl_rising_edge_count == 1 \
                and self._sda_rising_edge_count == 0 \
                and self._scl_falling_edge_count == 0 \
                and self._sda_falling_edge_count == 0 \
                and input_scl == 1 \
                and input_sda == 0 \
                and super().is_scl_rising(input_scl)
        # scl处于高电平，sda处于低电平
        def is_in_state_2(self, input_scl, input_sda):
            return self._scl_rising_edge_count == 1 \
                and self._sda_rising_edge_count == 0 \
                and self._scl_falling_edge_count == 0 \
                and self._sda_falling_edge_count == 0 \
                and input_scl == 1 \
                and input_sda == 0 \
                and super().is_bus_no_change(input_scl, input_sda)
        # scl处于高电平，sda被拉高
        def is_change_to_state_3(self, input_scl, input_sda):
            return self._scl_rising_edge_count == 1 \
                and self._sda_rising_edge_count == 1 \
                and self._scl_falling_edge_count == 0 \
                and self._sda_falling_edge_count == 0 \
                and input_scl == 1 \
                and input_sda == 1 \
                and super().is_sda_rising(input_sda)
        # scl和sda同时处于高电平
        def is_in_state_3(self, input_scl, input_sda):
            return self._scl_rising_edge_count == 1 \
                and self._sda_rising_edge_count == 1 \
                and self._scl_falling_edge_count == 0 \
                and self._sda_falling_edge_count == 0 \
                and input_scl == 1 \
                and input_sda == 1 \
                and super().is_bus_no_change(input_scl, input_sda)

        def get_state_sig(self):
            return IIC_Checker.IIC_SIG_STOP

        def update(self, input_scl, input_sda):
            self.pre_update(input_scl, input_sda)
            
            if self.is_in_state_1(input_scl, input_sda):
                pass
            elif self.is_change_to_state_2(input_scl, input_sda):
                if not super().is_one_fourth_iic_clock_interval():
                    return False
                self.scl_cycle = 0.25
                self.half_half_scl_cycle_interval += 1
            elif self.is_in_state_2(input_scl, input_sda):
                self.half_half_scl_cycle_interval += 1
            elif self.is_change_to_state_3(input_scl, input_sda):
                if not super().is_one_half_iic_clock_interval():
                    return False
                self.scl_cycle = 0.75
                self.half_half_scl_cycle_interval -= 1
            elif self.is_in_state_3(input_scl, input_sda):
                self.half_half_scl_cycle_interval -= 1
                if self.half_half_scl_cycle_interval == 0:
                    if not super().is_three_fourth_iic_clock_interval_minus_one():
                        return False
                    # finish!
                    self._is_finished = True
                    pass
            else:
                return False

            self.post_update(input_scl, input_sda)
            return True
        
        def pre_update(self, input_scl, input_sda):
            return super().pre_update(input_scl, input_sda)

        def post_update(self, input_scl, input_sda):
            return super().post_update(input_scl, input_sda)
        

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
                and self.is_scl_no_change(input_scl) \
                and self._scl_cycle_state == 0
        # scl被拉高
        def is_change_to_state_2(self, input_scl):
            return self._scl_rising_edge_count == 1 \
                and self._scl_falling_edge_count == 0 \
                and input_scl == 1 \
                and self.is_scl_rising(input_scl) \
                and self._scl_cycle_state == 0
        # scl处于高电平
        def is_in_state_2(self, input_scl, input_sda):
            return self._scl_rising_edge_count == 1 \
                and self._scl_falling_edge_count == 0 \
                and input_scl == 1 \
                and self.is_bus_no_change(input_scl, input_sda) \
                and self._scl_cycle_state == 1
        # scl被拉低
        def is_change_to_state_3(self, input_scl):
            return self._scl_rising_edge_count == 1 \
                and self._scl_falling_edge_count == 1 \
                and input_scl == 0 \
                and self.is_scl_falling(input_scl) \
                and self._scl_cycle_state == 1
        # scl处于低电平
        def is_in_state_3(self, input_scl, input_sda):
            return self._scl_rising_edge_count == 1 \
                and self._scl_falling_edge_count == 1 \
                and input_scl == 0 \
                and self.is_bus_no_change(input_scl, input_sda) \
                and self._scl_cycle_state == 2

        def get_state_sig(self):
            return IIC_Checker.IIC_SIG_BIT_1

        def update(self, input_scl, input_sda):
            self.pre_update(input_scl, input_sda)
            
            if self.is_in_state_1(input_scl):
                pass
            elif self.is_change_to_state_2(input_scl):
                if not super().is_one_fourth_iic_clock_interval():
                    return False
                self._scl_cycle_state = 1
                self.sda_high_count += input_sda
                self.half_scl_cycle_interval += 1
            elif self.is_in_state_2(input_scl, input_sda):
                self.sda_high_count += input_sda
                self.half_scl_cycle_interval += 1
            elif self.is_change_to_state_3(input_scl):
                if not super().is_three_fourth_iic_clock_interval():
                    return False
                self._scl_cycle_state = 2
                self.half_half_scl_cycle_interval = self.half_scl_cycle_interval // 2 - 1
            elif self.is_in_state_3(input_scl, input_sda):
                self.half_half_scl_cycle_interval -= 1
                if self.half_half_scl_cycle_interval == 0:
                    if not super().is_one_first_iic_clock_interval_minus_one():
                        return False
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